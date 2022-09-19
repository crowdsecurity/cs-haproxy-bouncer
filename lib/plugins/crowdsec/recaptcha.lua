local json = require "json"
local template = require "plugins.crowdsec.template"
local utils = require "plugins.crowdsec.utils"


local M = {_TYPE='module', _NAME='recaptcha.funcs', _VERSION='1.0-0'}

local recaptcha_verify_path = "/recaptcha/api/siteverify"

M._VERIFY_STATE = "to_verify"
M._VALIDATED_STATE = "validated"


M.State = {}
M.State["1"] = M._VERIFY_STATE
M.State["2"] = M._VALIDATED_STATE

M.SecretKey = ""
M.SiteKey = ""
M.Template = ""


function M.GetStateID(state)
    for k, v in pairs(M.State) do
        if v == state then
            return tonumber(k)
        end
    end
    return nil
end

function M.New(siteKey, secretKey, TemplateFilePath)

    if siteKey == nil or siteKey == "" then
      return "no recaptcha site key provided, can't use recaptcha"
    end
    M.SiteKey = siteKey

    if secretKey == nil or secretKey == "" then
      return "no recaptcha secret key provided, can't use recaptcha"
    end
    M.SecretKey = secretKey

    if core.backends["captcha_verifier"] == nil then
      return "no verifier backend provided, can't use recaptcha"
    end
    if core.backends["captcha_verifier"].servers["captcha_verifier"] == nil then
      return "no verifier backend provided, can't use recaptcha"
    end

    if TemplateFilePath == nil then
      return "CAPTCHA_TEMPLATE_PATH variable is empty, will ban without template"
    end
    if utils.file_exist(TemplateFilePath) == false then
      return "captcha template file doesn't exist, can't use recaptcha"
    end

    local captcha_template = utils.read_file(TemplateFilePath)
    if captcha_template == nil then
        return "Template file " .. TemplateFilePath .. "not found."
    end
    M.Template = captcha_template

    return nil
end

function M.GetTemplate(template_data)
  template_data["recaptcha_site_key"] =  M.SiteKey
  local view = template.compile(M.Template, template_data)
  return view
end

local function table_to_encoded_url(args)
    local params = {}
    for k, v in pairs(args) do table.insert(params, k .. '=' .. v) end
    return table.concat(params, "&")
end

function M.Validate(g_captcha_res, remote_ip)
    local body = {
        secret   = M.SecretKey,
        response = g_captcha_res,
        remoteip = remote_ip
    }

    local verifier_ip = core.backends["captcha_verifier"].servers["captcha_verifier"]:get_addr()
    local data = table_to_encoded_url(body)
    local status, res = pcall(function()
      return core.httpclient():post{
          url="https://"..verifier_ip..recaptcha_verify_path,
          body=data,
          headers={
              ["Host"] = {"www.recaptcha.net"},
              ["Content-Type"] = {"application/x-www-form-urlencoded"},
          },
          timeout=2000
      }
    end)
    if status == false then
      core.Alert("error verifying captcha: "..res.."; verifier: "..verifier_ip)
      return false, res
    end

    if res.status ~= 200 then
      core.Alert("error verifying captcha: "..res.status..","..res.body.."; verifier: "..verifier_ip)
      return false, res.body
    end
    local result = json.decode(res.body)

    if result.success == false then
      for k, v in pairs(result["error-codes"]) do
        if v == "invalid-input-secret" then
          core.Alert("reCaptcha secret key is invalid")
          return true, nil
        end
      end 
    end

    return result.success, nil
end

-- Service implementation
-- respond with captcha template
function M.ReplyCaptcha(applet)
  -- block if accept is not text/html to avoid serving html when the client expect image or json
  if utils.accept_html(applet) == false then
    applet:set_status(403)
    applet:start_response()
    applet:send("Access forbidden")
    return
  end

  local redirect_uri = applet.path
  if applet.method:lower() ~= "get" then
    redirect_uri = "/"
  end
  local response = M.GetTemplate({["redirect_uri"]=redirect_uri})
  applet:set_status(200)
  applet:add_header("content-length", string.len(response))
  applet:add_header("content-type", "text/html")
  applet:start_response()
  applet:send(response)
end

return M