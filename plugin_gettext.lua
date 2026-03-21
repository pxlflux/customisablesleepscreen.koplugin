-- Loads plugin translations and falls back to KOReader's gettext if unavailable.

local util    = require("util")
local GetText = require("gettext")
local logger  = require("logger")

local full_source_path = debug.getinfo(1, "S").source
if full_source_path:sub(1, 1) == "@" then
    full_source_path = full_source_path:sub(2)
end
local lib_path    = util.splitFilePathName(full_source_path)
local plugin_path = lib_path:gsub("/+", "/"):gsub("[\\/]l10n[\\/]", "")

local NewGetText = {
    dirname = string.format("%s/l10n", plugin_path),
}

local REGIONAL_LANGS = { pt_BR = true, zh_CN = true }

local function normaliseLang(lang)
    if not lang or lang == "C" or lang == "POSIX" then return nil end
    local full = lang:match("^([a-z]+_[A-Z]+)")
    if full and REGIONAL_LANGS[full] then return full end
    return lang:match("^([a-z]+)") or lang
end

local SUPPORTED_LANGS = {
    de = true, es = true, fr = true, it = true,
    ja = true, ko = true, nl = true, pl = true, 
    pt_BR = true, ru = true, vi = true, zh_CN = true,
}

local _notice_shown_key = "customisable_ss_lang_notice_shown"

local function changeLang(new_lang)
    local original_l10n_dirname     = GetText.dirname
    local original_context          = GetText.context
    local original_translation      = GetText.translation
    local original_wrapUntranslated = GetText.wrapUntranslated
    local original_current_lang     = GetText.current_lang

    GetText.dirname = NewGetText.dirname

    local ok, err = pcall(GetText.changeLang, new_lang)
    if ok then
        if (GetText.translation and next(GetText.translation) ~= nil) or
           (GetText.context    and next(GetText.context)    ~= nil) then
            NewGetText = util.tableDeepCopy(GetText)

            if NewGetText.translation and original_translation then
                for k in pairs(NewGetText.translation) do
                    if original_translation[k] and original_translation[k] == NewGetText.translation[k] then
                        NewGetText.translation[k] = nil
                    end
                end
            end
        end
    else
        logger.warn("CustomisableSleepScreen: failed to load translation for",
                   new_lang, "—", err)
    end

    GetText.context          = original_context
    GetText.translation      = original_translation
    GetText.dirname          = original_l10n_dirname
    GetText.wrapUntranslated = original_wrapUntranslated
    GetText.current_lang     = original_current_lang
end

local function createProxy(new_gettext, gettext)
    if not (new_gettext.wrapUntranslated
            and new_gettext.translation
            and new_gettext.current_lang) then

        local wrapper = {}
        setmetatable(wrapper, {
            __call = function(_, msgid) return msgid end,
        })
        wrapper.ngettext = function(singular, plural, n)
            n = tonumber(n) or 0
            return n == 1 and singular or plural
        end
        return wrapper
    end

    local function getCompareStr(key, args)
        if     key == "gettext"   then return args[1]
        elseif key == "pgettext"  then return args[2]
        elseif key == "ngettext"  then
            return (new_gettext.getPlural and new_gettext.getPlural(args[3]) == 0)
                   and args[1] or args[2]
        elseif key == "npgettext" then
            return (new_gettext.getPlural and new_gettext.getPlural(args[4]) == 0)
                   and args[2] or args[3]
        end
    end

    local mt = {
        __index = function(_, key)
            local value    = new_gettext[key]
            if type(value) ~= "function" then return value end
            local fallback = gettext[key]
            return function(...)
                local args   = { ... }
                local msgstr = value(...)
                local cmp    = getCompareStr(key, args)
                if msgstr and cmp and msgstr == cmp and type(fallback) == "function" then
                    msgstr = fallback(...)
                end
                return msgstr
            end
        end,
        __call = function(_, msgid)
            local msgstr = new_gettext(msgid)
            if msgstr == msgid then msgstr = gettext(msgid) end
            return msgstr
        end,
    }

    local proxy = setmetatable({}, mt)

    proxy.ngettext = function(singular, plural, n)
        n = tonumber(n) or 0
        local msgstr
        local entry = NewGetText.translation and NewGetText.translation[singular]
        if type(entry) == "table" then
            local plural_form = (NewGetText.getPlural and NewGetText.getPlural(n)) or 0
            msgstr = entry[plural_form] or entry[0]
        elseif type(entry) == "string" then
            msgstr = entry
        end
        if type(msgstr) == "table" then
            msgstr = msgstr[0] or msgstr[1] or nil
        end

        if not msgstr then
            if gettext.ngettext then
                local ok, result = pcall(gettext.ngettext, gettext, singular, plural, n)
                if ok and result then msgstr = result end
            end
        end
        if type(msgstr) == "table" then
            msgstr = msgstr[0] or msgstr[1] or nil
        end
        if not msgstr then
            msgstr = n == 1 and singular or plural
        end
        return msgstr
    end

    return proxy
end

local sys_lang  = GetText.current_lang
               or G_reader_settings:readSetting("language")
local base_lang = normaliseLang(sys_lang)

if base_lang and SUPPORTED_LANGS[base_lang] then
    changeLang(base_lang)
end

if base_lang and base_lang ~= "en" and not SUPPORTED_LANGS[base_lang] then
    local _notice_shown_key = "customisable_ss_lang_notice_shown_" .. base_lang
    if not G_reader_settings:readSetting(_notice_shown_key) then
        pcall(function()
            local UIManager   = require("ui/uimanager")
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:scheduleIn(2, function()
                pcall(function()
                    UIManager:show(InfoMessage:new {
                        text = string.format(
                            "Customisable Sleep Screen:\nNo translation available for '%s'.\nDisplaying in English.",
                            sys_lang or base_lang),
                        timeout = 5,
                    })
                    G_reader_settings:saveSetting(_notice_shown_key, true)
                end)
            end)
        end)
    end
end

return createProxy(NewGetText, GetText)
