package.path = package.path .. ";./?.lua"

local json = require "json"
local config = require "plugins.crowdsec.config"
local recaptcha = require "plugins.crowdsec.recaptcha"
local ban = require "plugins.crowdsec.ban"
local utils = require "plugins.crowdsec.utils"

local runtime = {}

-- Called after the configuration is parsed.
-- Loads the configuration
local function init()
    configFile = os.getenv("CROWDSEC_CONFIG")
    local conf, err = config.loadConfig(configFile)
    if conf == nil then
        core.Alert(err)
        return nil
    end
    runtime.conf = conf
    runtime.fallback = runtime.conf["FALLBACK_REMEDIATION"] or "ban"

    if core.backends["crowdsec"] == nil then
        error("no crowdsec backend provided: crowdsec connection must be provided as backend named crowdsec")
    end
    if core.backends["crowdsec"].servers["crowdsec"] == nil then
        error("no crowdsec backend provided: crowdsec connection must be provided as backend named crowdsec having a server named crowdsec")
    end
    
    runtime.captcha_ok = true
    local err = recaptcha.New(runtime.conf["SITE_KEY"], runtime.conf["SECRET_KEY"], runtime.conf["CAPTCHA_TEMPLATE_PATH"])
    if err ~= nil then
      core.Alert("error loading recaptcha plugin: " .. err)
      runtime.captcha_ok = false
    end

    if runtime.conf["REDIRECT_LOCATION"] ~= "" then
        table.insert(runtime.conf["EXCLUDE_LOCATION"], runtime.conf["REDIRECT_LOCATION"])
    end
    local err = ban.New(runtime.conf["BAN_TEMPLATE_PATH"], runtime.conf["REDIRECT_LOCATION"], runtime.conf["RET_CODE"])
    if err ~= nil then
      core.Alert("error loading ban plugin: " .. err)
    end

    runtime.map = Map.new(conf["MAP_PATH"], Map._ip)
end
 
local function urldecode(str)
    str = string.gsub (str, "+", " ")
    str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end)
    return str
end

local function remediate_allow(txn)
    txn:set_var("req.remediation", nil)
    return nil
end

local function remediate_fallback(txn)
    txn:set_var("req.remediation", runtime.fallback)
    return nil
end

-- Called in live mode
-- interrogate Crowdsec in realtime to get a decision
local function get_live_remediation(txn, source_ip)
    local link = "http://" .. core.backends["crowdsec"].servers["crowdsec"]:get_addr() .. "/v1/decisions?ip=" .. source_ip

    core.Debug("Fetching decision for ip="..source_ip)
    local response = core.httpclient():get{
        url=link,
        headers={
            ["X-Api-Key"]={runtime.conf["API_KEY"]},
            ["Connection"]={"keep-alive"},
            ["User-Agent"]={"crowdsec-haproxy-bouncer/v1.0.0"}
        },
        timeout=2*60*1000
    }
    core.Info("Response: "..tostring(response.status).." ("..response.body..")")
    if response == nil then
        core.Alert("Got error fetching decisions from Crowdsec (unknown)")
        return nil
    end
    if response.status ~= 200 then
        core.Alert("Got error fetching decisions from Crowdsec: "..tostring(response.status).." ("..response.body..")")
        return nil
    end
    local body = response.body
    core.Debug("Decision fetched ip="..source_ip.."="..tostring(body))

    if body == "null" then
        -- ip unknown
        return nil
    end

    local decisions = json.decode(body)

    return decisions[1].type
end

-- Called for each request
-- check the blocklists and decide of the remediation
local function allow(txn)
    if runtime.conf["ENABLED"] == "false" then
        return remediate_allow(txn)
    end

    local source_ip = txn.f:src()

    core.Debug("Request from "..source_ip)

    local remediation = nil
    if runtime.conf["MODE"] == "stream" then
        remediation = runtime.map:lookup(source_ip)
    else
        remediation = get_live_remediation(txn, source_ip)
    end

    if remediation == nil then
        return remediate_allow(txn)
    end

    core.Debug("Active decision "..tostring(remediation).." for "..source_ip)

    -- whitelists
    if utils.table_len(runtime.conf["EXCLUDE_LOCATION"]) > 0 then
        for k, v in pairs(runtime.conf["EXCLUDE_LOCATION"]) do
            if txn.sf:path() == v then
                return remediate_allow(txn)
            end
            local uri_to_check = v
            if utils.ends_with(uri_to_check, "/") == false then
                uri_to_check = uri_to_check .. "/"
            end
            if utils.starts_with(txn.sf:path(), uri_to_check) then
                return remediate_allow(txn)
            end
        end
    end
    
    -- captcha
    if remediation == "captcha" then
        if runtime.captcha_ok == false then
            return remediate_fallback(txn)
        end
        local stk = core.frontends[txn.f:fe_name()].stktable
        if stk == nil then
            core.Alert("Stick table not defined in frontend "..txn.f:fe_name()..". Cannot cache captcha verifications")
            return remediate_fallback(txn)
        end
        if stk:lookup(source_ip) ~= nil then
            return remediate_allow(txn)
        end
        -- captcha response ?
        local recaptcha_resp = txn.sf:req_body_param("g-recaptcha-response")
        if recaptcha_resp ~= "" then
            valid, err = recaptcha.Validate(recaptcha_resp, source_ip)
            if err then
                core.Alert("error validating captcha: "..err.."; validator: "..core.backends["captcha_verifier"].servers["captcha_verifier"]:get_addr())
            end
            if valid then
                -- valid, redirect to redirectUri
                txn:set_var("req.redirect_uri", urldecode(txn.sf:req_body_param("redirect_uri")))
                remediation = "captcha-allow"
            end
        end
    end

    txn:set_var("req.remediation", remediation)
end

-- Called from task
-- load decisions from LAPI
local function refresh_decisions(is_startup)
    core.Debug("Stream Query with startup "..tostring(is_startup))
    -- TODO: get protocol from config
    local link = "http://" .. core.backends["crowdsec"].servers["crowdsec"]:get_addr() .. "/v1/decisions/stream?startup=" .. tostring(is_startup)

    core.Debug("Start fetching decisions: startup="..tostring(is_startup))
    local response = core.httpclient():get{
        url=link,
        headers={
            ["X-Api-Key"]={runtime.conf["API_KEY"]},
            ["Connection"]={"keep-alive"},
            ["User-Agent"]={"crowdsec-haproxy-bouncer/v1.0.0"}
        },
        timeout=2*60*1000
    }
    if response == nil then
        core.Alert("Got error fetching decisions from Crowdsec (unknown)")
        return false
    end
    if response.status ~= 200 then
        core.Alert("Got error fetching decisions from Crowdsec: "..response.status.." ("..response.body..")")
        return false
    end
    local body = response.body
    core.Debug("Decisions fetched: startup="..tostring(is_startup))

    local decisions = json.decode(body)

    if decisions.deleted == nil and decisions.new == nil then
        return true
    end

    -- process deleted decisions
    if type(decisions.deleted) == "table" then
      if not is_startup then
        for i, decision in pairs(decisions.deleted) do
            core.Debug("Delete decision "..decision.value)
            core.del_map(runtime.conf["MAP_PATH"], decision.value)
        end
      end
    end
  
    -- process new decisions
    if type(decisions.new) == "table" then
      for i, decision in pairs(decisions.new) do
        if runtime.conf["BOUNCING_ON_TYPE"] == decision.type or runtime.conf["BOUNCING_ON_TYPE"] == "all" then
            core.Debug("Add decision "..decision.value)
            core.set_map(runtime.conf["MAP_PATH"], decision.value, decision.type)
        end
      end
    end
  
    return true
end

-- Task
-- refresh decisions periodically
local function refresh_decisions_task()
    if runtime.conf["ENABLED"] == "false" then
        return
    end

    if runtime.conf["MODE"] ~= "stream" then
        return
    end

    local is_first_fetch = true
    while true do
        local succes = refresh_decisions(is_first_fetch)
        if succes then
            is_first_fetch = false
        end
        core.sleep(runtime.conf["UPDATE_FREQUENCY"])
    end
end

-- Registers
core.register_init(init)
core.register_action("crowdsec_allow", { 'tcp-req', 'tcp-res', 'http-req', 'http-res' }, allow, 0)
core.register_service("reply_captcha", "http", recaptcha.ReplyCaptcha)
core.register_service("reply_ban", "http", ban.ReplyBan)
core.register_task(refresh_decisions_task)
