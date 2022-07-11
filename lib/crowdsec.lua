package.path = package.path .. ";./?.lua"

local config = require "plugins.crowdsec.config"
local json = require "json"
local http = require "http"
local recaptcha = require "plugins.crowdsec.recaptcha"

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
    -- TODO: check crowdsec & captcha_verifier backends config

    runtime.captcha_ok = true
    local err = recaptcha.New(runtime.conf["SITE_KEY"], runtime.conf["SECRET_KEY"], runtime.conf["CAPTCHA_TEMPLATE_PATH"])
    if err ~= nil then
      core.Alert("error loading recaptcha plugin: " .. err)
      runtime.captcha_ok = false
    end

    runtime.map = Map.new(conf["MAP_PATH"], Map._ip)
end
  
-- Called for each request
-- check the blocklists and decide of the remediation
local function allow(txn)
    local source_ip = txn.f:src()

    core.Debug("Request from "..source_ip)

    local remediation = runtime.map:lookup(source_ip)

    if remediation == "captcha" then
        local stk = core.frontends[txn.f:fe_name()].stktable
        if stk == nil then
            core.Alert("Stick table not defined in frontend "..txn.f:fe_name()..". Cannot cache captcha verifications")
            txn:set_var("req.remediation", "ban")
            return nil
        end
        if stk:lookup(source_ip) ~= nil then
            txn:set_var("req.remediation", nil)
            return nil
        end
        -- captcha response ?
        local recaptcha_resp = txn.sf:req_body_param("g-recaptcha-response")
        if recaptcha_resp ~= "" then
            valid, err = recaptcha.Validate(recaptcha_resp, source_ip, core.backends["captcha_verifier"].servers["captcha_verifier"]:get_addr())
            if err then
                core.Alert("error validating captcha: "..err.."; validator: "..core.backends["captcha_verifier"].servers["captcha_verifier"]:get_addr())
            end
            if valid then
                -- valid, redirect to redirectUri
                -- TODO: get correct redirect uri from query param if provided
                remediation = "captcha-allow"
            else
                remediation = "ban"
            end
        end
    end

    txn:set_var("req.remediation", remediation)
end

-- Service implementation
-- respond with captcha template
local function reply_captcha(applet)
    -- TODO: still ban if accept is not text/html to avoid serving html when the client expect image or json
    -- TODO: replace redirectUri in template with actual request_uri
    response = recaptcha.GetTemplate()
    applet:set_status(200)
    applet:add_header("content-length", string.len(response))
    applet:add_header("content-type", "text/html")
    applet:start_response()
    applet:send(response)
end

-- Called from task
-- load decisions from LAPI
local function refresh_decisions(is_startup)
    core.Debug("Stream Query with startup "..tostring(is_startup))
    -- TODO: get protocol from config
    local link = "http://" .. core.backends["crowdsec"].servers["crowdsec"]:get_addr() .. "/v1/decisions/stream?startup=" .. tostring(is_startup)

    core.Debug("Start fetching decisions: startup="..tostring(is_startup))
    response, err = http.get{url=link, headers={
            ["X-Api-Key"]=runtime.conf["API_KEY"],
            ["Connection"]="keep-alive",
            ["User-Agent"]="HAProxy"
        }}
    if err then
        core.Alert("Got error "..err)
        return false
    end
    core.Debug("Decisions fetched: startup="..tostring(is_startup))

    local body = response.content
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
core.register_service("reply_captcha", "http", reply_captcha)
core.register_task(refresh_decisions_task)
