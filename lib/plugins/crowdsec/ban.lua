local utils = require "plugins.crowdsec.utils"


local M = {_TYPE='module', _NAME='ban.funcs', _VERSION='1.0-0'}

M.template_str = ""
M.redirect_location = ""
M.ret_code = 403


function M.New(template_path, redirect_location, ret_code)
    M.redirect_location = redirect_location

    ret_code_ok = false
    if ret_code ~= nil and ret_code ~= 0 and ret_code ~= "" then
        ret_code_ok = true
        M.ret_code = ret_code
    end

    template_file_ok = false
    if (template_path ~= nil and template_path ~= "" and utils.file_exist(template_path) == true) then
        M.template_str = utils.read_file(template_path)
        if M.template_str ~= nil then
            template_file_ok = true
        end
    end

    if template_file_ok == false and (M.redirect_location == nil or M.redirect_location == "") then
        core.Alert("BAN_TEMPLATE_PATH and REDIRECT_LOCATION variable are empty, will return HTTP " .. M.ret_code  .. " for ban decisions")
    end

    return nil
end



function M.ReplyBan(applet)
    if M.redirect_location ~= "" then
        applet:set_status(302)
        applet:add_header("location", M.redirect_location)
        applet:start_response()
        applet:send()
    elseif M.template_str ~= "" and utils.accept_html(applet) == true then
        local response = M.template_str
        applet:set_status(200)
        applet:add_header("content-length", string.len(response))
        applet:add_header("content-type", "text/html")
        applet:start_response()
        applet:send(response)
    else
        applet:set_status(M.ret_code)
        applet:start_response()
        applet:send("Access forbidden")
    end
end

return M