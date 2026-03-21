-- Collects book data from the active document and persists it for offline display.

local util   = require("util")
local Device = require("device")

local _        = require("plugin_gettext")
local config   = require("config")
local SETTINGS = config.SETTINGS

local stats_mod  = require("stats")
local getAllStats = stats_mod.getAllStats

local render     = require("infobox_render")
local getSetting = render.getSetting

require("random")

local function safeGet(obj, ...)
    for _, key in ipairs({ ... }) do
        if type(obj) ~= "table" then return nil end
        obj = obj[key]
    end
    return obj
end

local function truncateText(text, max_length)
    if not max_length or max_length <= 0 or #text <= max_length then return text end
    local truncated  = text:sub(1, max_length)
    local last_space = truncated:match("^.*() ")
    if last_space and last_space > max_length * 0.7 then
        truncated = text:sub(1, last_space - 1)
    end
    return truncated .. "..."
end

local function cleanChapterTitle(raw_title)
    if not raw_title or raw_title == "" then return _("No Chapter") end
    local structural = " chapter ch part pt one two three four five six seven eight nine ten " ..
                       "eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen " ..
                       "twenty thirty forty fifty sixty seventy eighty ninety hundred and "
    local roman_except = { did = 1, mix = 1, mill = 1, dim = 1, lid = 1, vim = 1, civil = 1, mild = 1, livid = 1 }
    local has_content = false
    for word in raw_title:gmatch("[%w%d]+") do
        local low      = word:lower()
        local is_roman = #word <= 4 and low:match("^[ivxlcdm]+$") and not roman_except[low]
        if not (structural:find(" " .. low .. " ", 1, true) or word:match("^%d+$") or is_roman) then
            has_content = true
            break
        end
    end
    local cleaned = raw_title
    if has_content then
        cleaned = raw_title:gsub("^%s*[Cc]hap[ter%.]*%s+%d+[%.%s%-:]*", "")
                           :gsub("^%s*[Pp]art%s+%d+[%.%s%-:]*", "")
                           :gsub("^%s*%d+[%.%s%-:]+", "")
    end
    if cleaned == cleaned:upper() and cleaned:match("%a") then
        cleaned = cleaned:lower():gsub("(%a)([%w']*)", function(f, r) return f:upper() .. r end)
    end
    return cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^[:%.%-%s]+", "")
end

local function addQuotationMarks(text)
    if not text or text == "" then return text end
    if not getSetting("HIGHLIGHT_ADD_QUOTES") then return text end
    local trimmed = util.trim(text)
    if not trimmed or trimmed == "" then return text end
    local quote_patterns = {
        { open = '"',          close = '"'          },
        { open = "'",          close = "'"          },
        { open = "\u{201C}",   close = "\u{201D}"   },
        { open = "\u{2018}",   close = "\u{2019}"   },
        { open = "«",          close = "»"          },
        { open = "„",          close = "\u{201C}"   },
    }
    local content = trimmed
    for _, q in ipairs(quote_patterns) do
        local oe = q.open:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        local ce = q.close:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        if content:match("^" .. oe) and content:match(ce .. "$") then
            content = content:gsub("^" .. oe, ""):gsub(ce .. "$", "")
            content = util.trim(content) or content
            break
        end
    end
    local ls = text:match("^(%s*)")
    local ts = text:match("(%s*)$")
    return ls .. "\u{201C}" .. content .. "\u{201D}" .. ts
end

local function getRandomHighlight(ui, book_path_override)
    if book_path_override then
    elseif not ui or not ui.document or not ui.document.file then return nil end

    local book_path  = book_path_override or ui.document.file
    local DocSettings = require("docsettings")

    local doc_settings = DocSettings:open(book_path)
    local annotations  = doc_settings:readSetting("annotations") or {}
    doc_settings:close()

    local all_highlights = {}
    for _, ann in pairs(annotations) do
        if type(ann) == "table" and ann.drawer then
            local text = ann.text or ann.note
            if type(text) == "string" and text ~= "" then
                text = util.cleanupSelectedText(text)
                if #text >= 20 then
                    all_highlights[#all_highlights + 1] = {
                        text    = text,
                        page    = ann.pageno,
                        chapter = ann.chapter,
                    }
                end
            end
        end
    end

    if #all_highlights == 0 then return nil end

    local sel = all_highlights[math.random(#all_highlights)]
    local ht  = addQuotationMarks(sel.text)
    local max_length = getSetting("MAX_HIGHLIGHT_LENGTH")
    if max_length then
        ht = truncateText(ht, max_length)
        if getSetting("HIGHLIGHT_ADD_QUOTES") and not ht:match("\u{201D}$") then
            ht = ht .. "\u{201D}"
        end
    end
    return { text = ht, page = sel.page, chapter = sel.chapter }
end

local function getChapterCount(ui, current_page)
    if not ui or not ui.toc then return nil, nil end
    local toc_items = ui.toc.toc
    if not toc_items or #toc_items == 0 then return nil, nil end

    local exclude = {
        "prologue", "epilogue", "preface", "foreword", "afterword",
        "dedication", "acknowledgment", "acknowledgements", "appendix", "glossary",
        "bibliography", "table of contents", "contents", "landing page",
        "about the author", "about the book", "about the publisher",
        "copyright", "by the same author", "also by", "praise for",
        "follow penguin", "visit us online", "newsletter", "connect with", "stay in touch",
        "author's note", "note on", "further reading",
        "readers guide", "bonus content", "biographical", "colophon", "epigraph",
        "cast of characters", "if you liked", "other titles", "endpapers",
        "part one", "part two", "part three", "part four", "part five", "part six",
        "part seven", "part eight", "part nine", "part ten",
        "book one", "book two", "book three", "book four", "book five",
    }

    local exclude_patterns = {
        "^part %d",
        "^book %d",
        "^part [ivxlcdm]",
        "^cover",            
        "^title page$",
        "^title$",
        "^index$",           
        "^notes$",
        "^map$",
        "^maps$",
        "^insert$",
        "^praise$",
        "^excerpt$",
        "^by %a",            
        "^image$",           
        "^introduction",    
    }

    local function isExcluded(title)
        local low = title:lower()
        for _, term in ipairs(exclude) do
            if low:find(term, 1, true) then return true end
        end
        for _, pat in ipairs(exclude_patterns) do
            if low:match(pat) then return true end
        end
        return false
    end

    local number_words = {
        one=1, two=1, three=1, four=1, five=1, six=1, seven=1, eight=1, nine=1, ten=1,
        eleven=1, twelve=1, thirteen=1, fourteen=1, fifteen=1, sixteen=1, seventeen=1,
        eighteen=1, nineteen=1, twenty=1, thirty=1, forty=1, fifty=1, sixty=1,
        seventy=1, eighty=1, ninety=1, hundred=1,
        first=1, second=1, third=1, fourth=1, fifth=1, sixth=1, seventh=1, eighth=1,
        ninth=1, tenth=1, eleventh=1, twelfth=1, thirteenth=1, fourteenth=1,
        fifteenth=1, sixteenth=1, seventeenth=1, eighteenth=1, nineteenth=1,
        twentieth=1, thirtieth=1, fortieth=1, fiftieth=1,
    }

    local function isNumberWord(title)
        local low = title:lower()
        local stripped = low:match("^the%s+(.+)") or low
        local first = stripped:match("^(%a+)")
        return first ~= nil and number_words[first] ~= nil
    end

    local MONTHS = "jan%.?|feb%.?|mar%.?|apr%.?|may|jun%.?|jul%.?|aug%.?|sep%.?|oct%.?|nov%.?|dec%.?"

    local chapter_patterns = {
        "^chapter%s+%d+",           
        "^ch%.?%s*%d+",             
        "^%d+%.%s+",                
        "^%d+$",                    
        "^%d+%s+%a+",               
        "chapter%s+[ivxlcdm]+",     
        "^[ivxlcdm]+$",             
        "^[ivxlcdm]+%s+%a+",        
        "^chapter%s+%a+",          
        "^(" .. MONTHS .. ")%.?%s+%d+",
        "%((" .. MONTHS .. ")%.?%s+%d+%)",
    }

    local chapter_indices = {}
    for i = 1, #toc_items do
        local title = toc_items[i].title or ""
        if not isExcluded(title) then
            local low = title:lower()
            local matched = false
            for _, pat in ipairs(chapter_patterns) do
                if low:match(pat) then
                    matched = true
                    break
                end
            end
            if not matched and isNumberWord(title) then
                matched = true
            end
            if matched then
                table.insert(chapter_indices, { index = i, page = toc_items[i].page })
            end
        end
    end

    if #chapter_indices > 0 then
        local cur = nil
        for i, item in ipairs(chapter_indices) do
            if item.page <= current_page then cur = i else break end
        end
        return cur or 1, #chapter_indices
    end

    local filtered = {}
    for i = 1, #toc_items do
        if not isExcluded(toc_items[i].title or "") then
            table.insert(filtered, { index = i, page = toc_items[i].page })
        end
    end

    if #filtered == 0 then
        for i = 1, #toc_items do
            filtered[#filtered + 1] = { index = i, page = toc_items[i].page }
        end
    end

    local cur = nil
    for i, item in ipairs(filtered) do
        if item.page <= current_page then cur = i else break end
    end
    return cur or 1, #filtered
end

local function collectBookData(ui, state)
    if not (ui and ui.document) then return nil end
    local data      = {}
    data.title      = util.htmlToPlainTextIfHtml(safeGet(ui, "doc_props", "display_title") or _("Untitled"))
    data.authors    = safeGet(ui, "doc_props", "authors") or _("Unknown Author")
    data.page       = (ui.document and ui.document:getCurrentPage()) or safeGet(state, "page") or 1
    data.doc_pages  = safeGet(ui, "doc_settings", "data", "doc_pages") or 1
    data.cover_path = safeGet(ui, "document", "file")
    if ui.toc then
        local raw = util.htmlToPlainTextIfHtml(ui.toc:getTocTitleByPage(data.page) or "")
        data.chapter              = getSetting("CLEAN_CHAP") and cleanChapterTitle(raw) or raw
        data.chapter_pages_done   = (ui.toc:getChapterPagesDone(data.page) or 0) + 1
        data.chapter_pages_total  = ui.toc:getChapterPageCount(data.page) or 1
        data.chapter_pages_left   = ui.toc:getChapterPagesLeft(data.page) or 0
        data.current_chapter_num, data.total_chapters = getChapterCount(ui, data.page)
    end
    if ui.statistics then
        data.avg_time     = safeGet(ui, "statistics", "avg_time") or 0
        data.id_curr_book = safeGet(ui, "statistics", "id_curr_book")

        local scope   = getSetting("GOAL_STAT_SCOPE") or "all"
        local book_id = (scope == "book") and tonumber(data.id_curr_book) or nil
        if book_id and book_id < 1 then book_id = nil end

        local stats           = getAllStats(book_id)
        data.day_duration     = stats.duration
        data.day_pages        = stats.pages
        data.streak           = stats.streak
        data.days_met         = stats.days_met
        data.days_in_week     = stats.days_in_week
    end
    if Device:hasBattery() then
        data.battery_percent  = Device:getPowerDevice():getCapacity() or 0
        data.battery_charging = Device:getPowerDevice():isCharging()
    end
    data.timestamp = os.time()
    return data
end

local function saveLastBookData(data)
    if data then G_reader_settings:saveSetting(SETTINGS.LAST_BOOK_STATE, data) end
end

local function loadLastBookData()
    return G_reader_settings:readSetting(SETTINGS.LAST_BOOK_STATE)
end

return {
    safeGet              = safeGet,
    cleanChapterTitle    = cleanChapterTitle,
    truncateText         = truncateText,
    addQuotationMarks    = addQuotationMarks,
    getRandomHighlight   = getRandomHighlight,
    getChapterCount      = getChapterCount,
    collectBookData      = collectBookData,
    saveLastBookData     = saveLastBookData,
    loadLastBookData     = loadLastBookData,
}
