--[[--
Translator plugin use iciba service

--]]--

local logger = require("logger")
local translator = require("ui/translator")
-- local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InputContainer = require("ui/widget/container/inputcontainer")
local _ = require("gettext")
local md5 = require("ffi/sha2").md5
local JSON = require("json")

local function http_request(s_url, method, headers, request)
    local socket = require("socket")
    local socketutil = require("socketutil")
    local http = require("socket.http")
    local ltn12 = require("ltn12")

    local sink = {}
    if request == nil then
        request = {}
    end
    socketutil:set_timeout()

    request["url"] = s_url
    request["method"] = method
    request["sink"] = ltn12.sink.table(sink)
    request["headers"] = headers

    http.TIMEOUT = 5
    http.USERAGENT = "Mozilla/5.0 (X11; Linux i686 (x86_64)) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/56.0.2950.0 Iron Safari/537.36"
    local httpRequest = http.request

    local code, response_headers, status = socket.skip(
        1, httpRequest(request))

    socketutil:reset_timeout()
    if response_headers == nil then
        return {
            code = code,
            response_headers = response_headers,
            status = status,
            response_body = nil
        }
    end
    local xml = table.concat(sink)

    return {
        code = code,
        response_headers = response_headers,
        status = status,
        response_body = xml
    }
end
local Iciba = InputContainer:new {
}

function Iciba:init()
end

--[[--
Returns decoded JSON table from translate server.

@string text
@string target_lang
@string source_lang
@treturn string result, or nil
--]]


function Iciba:loadPageByIciba(text, target_lang, source_lang)
  local sign = md5("6key_cibaifanyicjbysdlove1" .. text):sub(1, 16)
  logger.dbg("sign", sign)
  local api_url = 'https://ifanyi.iciba.com/index.php'
  local params = string.format(
      "c=%s&m=%s&client=6&auth_user=key_ciba&sign=%s",
      "trans", "fy", sign)
  local query = string.format(
      "from=%s&q=%s&to=%s",
      source_lang, text, target_lang)
    local ltn12 = require("ltn12")
    local headers = {}
    headers['content-type'] = 'application/x-www-form-urlencoded'
    logger.dbg("query", query)
    headers["content-length"] = string.len(query)
    local request = {
        source = ltn12.source.string(query)
    }

    local s_url = api_url .. "?" .. params
    local resp = http_request(s_url, "POST", headers, request)
    local ok, api_result = pcall(JSON.decode, resp.response_body, JSON.decode.simple)
    if ok and api_result then
        logger.dbg("translator json:", api_result)
    else
        logger.warn("translator error:", api_result)
    end
-- translator json: {
--     ["status"] = 1,
--     ["content"] = {
--         ["ciba_use"] = "以上结果来自词霸AI实验室。",
--         ["ciba_out"] = "",
--         ["err_no"] = 0,
--         ["ttsLan"] = 8,
--         ["ttsLanFrom"] = 1,
--         ["from"] = "en",
--         ["to"] = "zh",
--         ["vendor"] = "ciba",
--         ["version"] = "v2.20.220425.1:wh.ciba.v0.3.15.220415.1.gs",
--         ["out"] = "如果你点击并按住一个选项或菜单项（字体重量、行距等）
-- ，您可以将其值设置为默认值。新值将只应用于从现在开始打开的文档。以前打
-- 开的文档将保留它们的设置。您可以将默认值标识为菜单中的STAR或指示器周围
-- 的黑色边框",
--         ["reqid"] = "211399d4-f97f-4fda-838c-0d3f49f0bbc8",
--     },
-- }
    local resultAlternative = {}
    local translateResult = {}
            table.insert(translateResult,
                { api_result.content.out, text }
            )
    local resultAsGoogleTranslate = {}
    resultAsGoogleTranslate[1] = translateResult
    resultAsGoogleTranslate[6] = resultAlternative
    logger.dbg("translator json as google translate format:", resultAsGoogleTranslate)
    return resultAsGoogleTranslate
end
table.insert(translator.trans_servers, "https://ifanyi.iciba.com")
translator.trans_funcs["https://ifanyi.iciba.com"] = Iciba.loadPageByIciba

return Iciba
