-- Translation loader

local logger = require("logger")
local _dir   = (debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$") or ".") .. "/"

local function parsePluralExpression(expr)
    local function translateTernary(s)
        local function findQuestion(str)
            local depth = 0
            for i = 1, #str do
                local c = str:sub(i, i)
                if c == "(" then
                    depth = depth + 1
                elseif c == ")" then
                    depth = depth - 1
                elseif c == "?" and depth == 0 then
                    return i
                end
            end
            return nil
        end

        local q = findQuestion(s)
        if not q then
            return s
        end

        local depth = 0
        local colon = nil
        for i = q + 1, #s do
            local c = s:sub(i, i)
            if c == "(" then
                depth = depth + 1
            elseif c == ")" then
                depth = depth - 1
            elseif c == ":" and depth == 0 then
                colon = i
                break
            end
        end

        if not colon then
            return s
        end

        local cond = s:sub(1, q - 1)
        local truthy = s:sub(q + 1, colon - 1)
        local falsy = s:sub(colon + 1)
        return "(" .. translateTernary(cond) .. " and (" .. translateTernary(truthy) .. ") or (" .. translateTernary(falsy) .. "))"
    end

    expr = expr:gsub("!=", "~=")
    expr = expr:gsub("&&", " and ")
    expr = expr:gsub("%|%|", " or ")
    expr = expr:gsub("!%s*", "not ")
    expr = translateTernary(expr)

    local loadfunc = loadstring or load
    local fn, err = loadfunc("return function(n) return " .. expr .. " end")
    if not fn then return nil end

    local ok, pluralFn = pcall(fn)
    if not ok or type(pluralFn) ~= "function" then return nil end
    return pluralFn
end

local function parsePO(path)
    local f = io.open(path, "r")
    if not f then return nil end

    local map = {}
    local pluralizer = nil
    local entry = {
        msgid = nil,
        msgid_plural = nil,
        msgstrs = {},
    }
    local current_field = nil

    local function flush()
        if not entry.msgid then
            entry = { msgid = nil, msgid_plural = nil, msgstrs = {} }
            current_field = nil
            return
        end

        if entry.msgid == "" then
            local header = entry.msgstrs[0] or ""
            for line in header:gmatch("([^\n]*)\n?") do
                local plural_line = line:match("^Plural%-Forms:%s*(.-)%s*$")
                if plural_line then
                    pluralizer = parsePluralExpression(plural_line)
                    break
                end
            end
        else
            if entry.msgid_plural then
                local trans = {}
                for idx, str in pairs(entry.msgstrs) do
                    if str and str ~= "" then
                        trans[idx] = str
                    end
                end
                if next(trans) then
                    map[entry.msgid] = trans
                end
            else
                local str = entry.msgstrs[0]
                if str and str ~= "" then
                    map[entry.msgid] = str
                end
            end
        end

        entry = { msgid = nil, msgid_plural = nil, msgstrs = {} }
        current_field = nil
    end

    local function unescape(s)
        return s:gsub("\\n", "\n"):gsub("\\t", "\t"):gsub('\\"', '"'):gsub("\\\\", "\\")
    end

    for line in f:lines() do
        local text = line:match("^%s*(.-)%s*$")
        if text == "" then
            flush()
        elseif text:match("^#") then
        elseif text:match('^msgid%s+"') then
            flush()
            entry.msgid = unescape(text:match('^msgid%s+"(.*)"') or "")
            current_field = "msgid"
        elseif text:match('^msgid_plural%s+"') then
            entry.msgid_plural = unescape(text:match('^msgid_plural%s+"(.*)"') or "")
            current_field = "msgid_plural"
        elseif text:match('^msgstr%[%d+%]%s+"') then
            local idx = tonumber(text:match('^msgstr%[(%d+)%]%s+"'))
            entry.msgstrs[idx] = unescape(text:match('^msgstr%[%d+%]%s+"(.*)"') or "")
            current_field = "msgstr" .. idx
        elseif text:match('^msgstr%s+"') then
            entry.msgstrs[0] = unescape(text:match('^msgstr%s+"(.*)"') or "")
            current_field = "msgstr0"
        elseif text:match('^"') and current_field then
            local cont = unescape(text:match('^"(.*)"') or "")
            if current_field == "msgid" then
                entry.msgid = entry.msgid .. cont
            elseif current_field == "msgid_plural" then
                entry.msgid_plural = entry.msgid_plural .. cont
            else
                local idx = tonumber(current_field:match("^msgstr(%d+)$"))
                if idx then
                    entry.msgstrs[idx] = (entry.msgstrs[idx] or "") .. cont
                end
            end
        end
    end
    flush()
    f:close()
    return map, pluralizer
end

local function detectLang()
    local lang = G_reader_settings and G_reader_settings:readSetting("language")
    if type(lang) == "string" and lang ~= "" then return lang end
    local lc = os.getenv("LANG") or os.getenv("LC_ALL") or os.getenv("LC_MESSAGES") or ""
    lang = lc:match("^([a-zA-Z_]+)")
    return lang or "en"
end

local _translations = nil

local function loadTranslations()
    local lang = detectLang()
    if lang == "en" or lang:match("^en_") then return nil end

    local function try(name)
        local path = _dir .. "l10n/" .. name .. ".po"
        local entries, pluralizer = parsePO(path)
        if entries and next(entries) then
            local n = 0; for _ in pairs(entries) do n = n + 1 end
            logger.info("simpleui i18n: loaded " .. path .. " — " .. n .. " strings")
            return { entries = entries, plural = pluralizer }
        end
    end

    return try(lang) or (function()
        local prefix = lang:match("^([a-zA-Z]+)")
        if prefix and prefix ~= lang then return try(prefix) end
    end)()
end

local _installed = false

local function install()
    if _installed then return end

    _translations = loadTranslations()
    if not _translations then return end

    local orig_gettext = package.loaded["gettext"]
    if not orig_gettext then
        local ok, gt = pcall(require, "gettext")
        if not ok or not gt then
            logger.warn("simpleui i18n: cannot load gettext, translations disabled")
            return
        end
        orig_gettext = gt
    end

    local function translate(msgid)
        if not _translations then return nil end
        local entry = _translations.entries[msgid]
        if type(entry) == "string" then
            return entry
        elseif type(entry) == "table" then
            return entry[0] or entry[1]
        end
        return nil
    end

    local function ngettext(msgid, msgid_plural, n)
        if _translations then
            local entry = _translations.entries[msgid]
            if type(entry) == "table" then
                local idx = 0
                if _translations.plural then
                    idx = _translations.plural(n) or 0
                else
                    idx = (n == 1) and 0 or 1
                end
                local translated = entry[idx]
                if translated then return translated end
            elseif type(entry) == "string" and n == 1 then
                return entry
            end
        end

        if type(orig_gettext) == "table" and type(orig_gettext.ngettext) == "function" then
            return orig_gettext.ngettext(msgid, msgid_plural, n)
        end

        local fallback = (n == 1) and msgid or msgid_plural
        return orig_gettext(fallback)
    end

    local wrapper
    local mt = getmetatable(orig_gettext)
    if mt and mt.__call then
        wrapper = setmetatable({ ngettext = ngettext }, {
            __call = function(_, msgid)
                local t = translate(msgid)
                if t then return t end
                return orig_gettext(msgid)
            end,
            __index = orig_gettext,
        })
    elseif type(orig_gettext) == "function" then
        wrapper = setmetatable({ ngettext = ngettext }, {
            __call = function(_, msgid)
                local t = translate(msgid)
                if t then return t end
                return orig_gettext(msgid)
            end,
        })

        for k, v in pairs(orig_gettext) do
            wrapper[k] = v
        end
    else
        logger.warn("simpleui i18n: unexpected gettext type: " .. type(orig_gettext))
        return
    end

    package.loaded["gettext"] = wrapper
    _installed = true
    logger.info("simpleui i18n: installed wrapper for language: " .. detectLang())
end

local function uninstall()
    if not _installed then return end
    package.loaded["gettext"] = nil
    pcall(require, "gettext")
    _installed    = false
    _translations = nil
    logger.info("simpleui i18n: uninstalled")
end

return {
    install   = install,
    uninstall = uninstall,
    getLang   = detectLang,
}
