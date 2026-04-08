-- Builds each infobox section widget: book, chapter, goal, battery, and message.

local _plugin_dir = (debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$") or ".") .. "/"

local Blitbuffer      = require("ffi/blitbuffer")
local util            = require("util")
local datetime        = require("datetime")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local ProgressWidget  = require("ui/widget/progresswidget")
local TextWidget      = require("ui/widget/textwidget")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")

local _        = require("plugin_gettext")
local ngettext = function(singular, plural, n)
    return _.ngettext(singular, plural, n)
end

local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS

local render              = require("infobox_render")
local getSetting          = render.getSetting
local getCachedColor      = render.getCachedColor
local clamp               = render.clamp
local getTextWidth        = render.getTextWidth
local wrapText            = render.wrapText
local createMultiLineText = render.createMultiLineText

local bookdata           = require("infobox_bookdata")
local safeGet            = bookdata.safeGet
local cleanChapterTitle  = bookdata.cleanChapterTitle
local getChapterCount    = bookdata.getChapterCount
local getRandomHighlight = bookdata.getRandomHighlight
local getCurrentPage     = bookdata.getCurrentPage
local getDocPages        = bookdata.getDocPages
local addQuotationMarks  = bookdata.addQuotationMarks
local getDisplayPage     = bookdata.getDisplayPage

local bg_mod  = require("infobox_background")
local trackBB = bg_mod.trackBB

local function getRandomCustomQuote()
    local ok, quotes = pcall(dofile, _plugin_dir .. "custom_quotes.lua")
    if not ok or type(quotes) ~= "table" or #quotes == 0 then return nil end
    local entry = quotes[math.random(#quotes)]
    if type(entry) == "string" then
        return { text = entry, author = nil, book = nil }
    elseif type(entry) == "table" and type(entry.text) == "string" then
        return { text = entry.text, author = entry.author, book = entry.book }
    end
    return nil
end

local Screen = Device.screen

local MONTHS_LONG = {
    _("January"),   _("February"), _("March"),    _("April"),
    _("May"),       _("June"),     _("July"),      _("August"),
    _("September"), _("October"),  _("November"),  _("December"),
}

local function getOrdinalSuffix(day_num)
    local m10, m100 = day_num % 10, day_num % 100
    if     m10 == 1 and m100 ~= 11 then return _("st")
    elseif m10 == 2 and m100 ~= 12 then return _("nd")
    elseif m10 == 3 and m100 ~= 13 then return _("rd")
    else                                 return _("th") end
end

local function getMonthName(month_num)
    return MONTHS_LONG[month_num]
end

local function formatDuration(secs)
    if not secs or secs <= 0 then return nil end
    local total_minutes = math.floor(tonumber(secs) / 60 + 0.5)
    local hours         = math.floor(total_minutes / 60)
    local minutes       = total_minutes % 60
    if hours > 0 then
        local hr_text = ngettext("hr", "hrs", tonumber(hours))
        if minutes > 0 then
            local min_text = ngettext("min", "mins", tonumber(minutes))
            return string.format("%d %s %d %s", hours, hr_text, minutes, min_text)
        end
        return string.format("%d %s", hours, hr_text)
    elseif minutes > 0 then
        local min_text = ngettext("min", "mins", tonumber(minutes))
        return string.format("%d %s", minutes, min_text)
    end
    return _("< 1 min")
end

local function formatBatteryTime(hours_left)
    if hours_left > 0 then
        local hour_text = ngettext("hr", "hrs", hours_left)
        return string.format(_("~%d %s left"), hours_left, hour_text)
    else
        return _("~<1 hr left")
    end
end

local function formatDate()
    local month_num = tonumber(os.date("%m"))
    local day_num   = tonumber(os.date("%d"))
    local suffix    = getOrdinalSuffix(day_num)
    local month_str = getMonthName(month_num)
    local day_str   = string.format("%d%s", day_num, suffix)

    local lang = (G_reader_settings:readSetting("language") or "en"):match("^([a-z]+)") or "en"
    if lang == "ja" or lang == "ko" or lang == "zh" then
        return month_str .. day_str
    else
        return day_str .. " " .. month_str
    end
end

local function expandMessage(str)
    if not str or str == "" then return "" end

    local function ordinalStr(n)
        return n .. getOrdinalSuffix(n)
    end

    local t         = os.date("*t")
    local month_str = getMonthName(t.month)
    local day_str   = ordinalStr(t.day)
    local lang      = (G_reader_settings:readSetting("language") or "en"):match("^([a-z]+)") or "en"
    local long_date
    if lang == "ja" or lang == "ko" or lang == "zh" then
        long_date = month_str .. day_str
    else
        long_date = day_str .. " " .. month_str
    end

    local pwr          = Device:getPowerDevice()
    local batt_perc    = Device:hasBattery() and pwr:getCapacity() or 0
    local charging_sym = pwr:isCharging() and " ⚡" or ""
    local replacements = {
        ["%%d"] = long_date,
        ["%%t"] = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock")),
        ["%%y"] = os.date("%Y"),
        ["%%b"] = batt_perc .. "%%" .. charging_sym,
        ["%%r"] = " · ",
    }
    for token, value in pairs(replacements) do str = str:gsub(token, value) end
    return str
end

local function createMultiLineSubtitle(lines, subtitle_face, subtext_color)
    local subtitle = VerticalGroup:new { align = "left" }
    for i, line in ipairs(lines) do
        subtitle[#subtitle + 1] = TextWidget:new {
            text         = line,
            face         = subtitle_face,
            fgcolor      = Blitbuffer.COLOR_BLACK,
            _fgcolor_rgb = subtext_color,
        }
    end
    return subtitle
end

local function getSettingWithDefault(setting_key, default_value)
    local val = G_reader_settings:readSetting(setting_key)
    return val == nil and default_value or val
end

local function getBatteryDisplayInfo()
    local batt_perc       = Device:hasBattery() and Device:getPowerDevice():getCapacity() or 0
    local is_charging     = Device:getPowerDevice():isCharging()
    local batt_stat_type  = getSetting("BATT_STAT_TYPE")
    local battery_hours_left = 0

    if batt_stat_type == "manual" then
        local manual_rate    = getSetting("BATT_MANUAL_RATE")
        battery_hours_left   = math.floor(batt_perc / math.max(manual_rate, 0.1))
    else
        local battery_time_seconds = nil
        local BatteryStat = package.loaded["plugins.batterystat.main"]
        if BatteryStat then
            local stat_obj = BatteryStat.stat
            if stat_obj then
                if type(stat_obj.accumulate) == "function" then
                    pcall(function() stat_obj:accumulate() end)
                end
                local selected_stat = stat_obj[batt_stat_type]
                if selected_stat and type(selected_stat.remainingTime) == "function" then
                    local ok, remaining = pcall(function() return selected_stat:remainingTime() end)
                    if ok and type(remaining) == "number" and remaining > 0 then
                        battery_time_seconds = remaining
                    end
                end
            end
        end

        if not battery_time_seconds then
            local ok_time,     time_module   = pcall(require, "ui/time")
            local ok_settings, LuaSettings   = pcall(require, "luasettings")
            if ok_time and ok_settings then
                local ok_open, batt_settings = pcall(LuaSettings.open, LuaSettings,
                    require("datastorage"):getSettingsDir() .. "/battery_stats.lua")
                if ok_open and batt_settings then
                    local stat_data = batt_settings:readSetting(batt_stat_type)
                    if stat_data and type(stat_data.percentage) == "number"
                       and type(stat_data.time) == "number"
                       and stat_data.time > 0
                       and stat_data.percentage > 0 then
                        local time_seconds    = time_module.to_s(stat_data.time)
                        local rate_per_second = stat_data.percentage / time_seconds
                        if rate_per_second > 0 then
                            local calculated_time = batt_perc / rate_per_second
                            if calculated_time < 864000 then
                                battery_time_seconds = calculated_time
                            end
                        end
                    end
                end
            end
        end

        local SECONDS_PER_HOUR = 3600
        if battery_time_seconds and battery_time_seconds > 0 then
            battery_hours_left = math.floor(battery_time_seconds / SECONDS_PER_HOUR + 0.5)
        else
            local manual_rate  = getSetting("BATT_MANUAL_RATE")
            battery_hours_left = math.floor(batt_perc / math.max(manual_rate, 0.1) + 0.5)
        end
    end

    return { percent = batt_perc, is_charging = is_charging, hours_left = battery_hours_left }
end

local function getBatteryColor(batt_perc, is_charging, color_config)
    if color_config.is_mono then
        return color_config.mono_color, color_config.mono_hex
    end
    local color_hex
    if is_charging then
        color_hex = getSetting("BATT_CHARGING_COLOR")
    elseif batt_perc >= 70 then
        color_hex = getSetting("BATT_HIGH_COLOR")
    elseif batt_perc >= 30 then
        color_hex = getSetting("BATT_MED_COLOR")
    else
        color_hex = getSetting("BATT_LOW_COLOR")
    end
    return getCachedColor(color_hex), color_hex
end

local function getBatteryIcon(batt_perc, is_charging)
    if     is_charging    then return "custom_battery_charging"
    elseif batt_perc >= 70 then return "custom_battery_high"
    elseif batt_perc >= 30 then return "custom_battery_mid"
    else                        return "custom_battery_low" end
end

local function buildSection(total_width, title, subtitle, icon_name, progress, colors, bar_height,
                             allow_title_multiline, allow_subtitle_multiline, title_face, subtitle_face,
                             text_align, title_bold, layout)
    local icon_size  = Screen:scaleBySize(clamp(layout and layout.icon_size or getSetting("ICON_SIZE"), 16, 128))
    local padding    = Screen:scaleBySize(layout and layout.section_padding or getSetting("SECTION_PADDING"))
    local icon_gap   = Screen:scaleBySize(layout and layout.icon_text_gap or getSetting("ICON_TEXT_GAP"))
    local show_icons = layout and layout.show_icons or getSetting("SHOW_ICONS") ~= false

    local text_width = total_width - (2 * padding)
    if show_icons then text_width = text_width - icon_size - icon_gap end

    local header_widgets = {}

    if show_icons then
        local icon_widget
        local use_bar_color = layout and layout.icon_use_bar_color or getSetting("ICON_USE_BAR_COLOR")
        local icon_set      = layout and layout.icon_set or getSetting("ICON_SET")
        local base_path     = _plugin_dir .. "icons/" .. icon_set .. "/" .. icon_name
        local icon_path, is_svg = nil, false

        if util.fileExists(base_path .. ".svg") then
            icon_path = base_path .. ".svg"; is_svg = true
        elseif util.fileExists(base_path .. ".png") then
            icon_path = base_path .. ".png"
        elseif util.fileExists(base_path .. ".jpg") then
            icon_path = base_path .. ".jpg"
        elseif util.fileExists(base_path .. ".jpeg") then
            icon_path = base_path .. ".jpeg"
        end

        if icon_path then
            local RenderImage = require("ui/renderimage")
            local ImageWidget = require("ui/widget/imagewidget")
            if is_svg and use_bar_color then
                local color_hex = colors.fill_hex
                local ok, result = pcall(function()
                    local f = io.open(icon_path, "rb")
                    if not f then error("Could not open icon") end
                    local svg_content = f:read("*all")
                    f:close()
                    svg_content = svg_content:gsub('currentColor', color_hex)
                    local temp_path = "/tmp/temp_icon_" .. icon_name .. ".svg"
                    local temp_f = io.open(temp_path, "wb")
                    if not temp_f then error("Could not write temp icon") end
                    temp_f:write(svg_content)
                    temp_f:close()
                    local render_ok, bb = pcall(RenderImage.renderSVGImageFile, RenderImage, temp_path, icon_size, icon_size)
                    os.remove(temp_path)
                    if not render_ok then error("SVG fail") end
                    return trackBB(bb)
                end)
                if ok and result then
                    icon_widget = ImageWidget:new { image = result, width = icon_size, height = icon_size, alpha = true }
                end
            else
                local ok, bb = pcall(function()
                    if is_svg then
                        return trackBB(RenderImage:renderSVGImageFile(icon_path, icon_size, icon_size))
                    else
                        return trackBB(RenderImage:renderImageFile(icon_path, icon_size, icon_size))
                    end
                end)
                if ok and bb then
                    icon_widget = ImageWidget:new { image = bb, width = icon_size, height = icon_size, alpha = true }
                end
            end
        end

        if not icon_widget then icon_widget = HorizontalSpan:new { width = icon_size } end

        header_widgets[#header_widgets + 1] = FrameContainer:new {
            padding    = 0,
            bordersize = 0,
            background = colors.bg,
            icon_widget,
        }
        header_widgets[#header_widgets + 1] = HorizontalSpan:new { width = icon_gap }
    end

    if not text_align then text_align = layout and layout.text_align or getSetting("TEXT_ALIGN") end

    local title_widget, subtitle_widget

    if allow_title_multiline and text_align ~= "left" then
        local title_lines = wrapText(title, title_face, text_width)
        title_widget = VerticalGroup:new { align = "left" }
        for i, line in ipairs(title_lines) do
            local line_w = getTextWidth(line, title_face)
            local pad    = 0
            if     text_align == "center" then pad = (text_width - line_w) / 2
            elseif text_align == "right"  then pad = text_width - line_w end
            title_widget[#title_widget + 1] = HorizontalGroup:new {
                HorizontalSpan:new { width = pad },
                TextWidget:new { text = line, face = title_face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = colors.text, bold = title_bold },
            }
        end
    else
        title_widget = createMultiLineText(title, title_face, colors.text, text_width, allow_title_multiline, "left", title_bold)
        if text_align ~= "left" and title_widget.getSize then
            local title_w = title_widget:getSize().w
            local pad = text_align == "center" and (text_width - title_w) / 2 or (text_width - title_w)
            title_widget = HorizontalGroup:new { HorizontalSpan:new { width = pad }, title_widget }
        end
    end

    if type(subtitle) == "table" then
        subtitle_widget = VerticalGroup:new { align = "left" }
        for i = 1, #subtitle do
            local child = subtitle[i]
            if child.text then
                local wrapped_lines = wrapText(child.text, subtitle_face, text_width)
                for j, wrapped_line in ipairs(wrapped_lines) do
                    if text_align == "left" then
                        subtitle_widget[#subtitle_widget + 1] = TextWidget:new {
                            text         = wrapped_line,
                            face         = subtitle_face,
                            fgcolor      = Blitbuffer.COLOR_BLACK,
                            _fgcolor_rgb = colors.subtext,
                        }
                    else
                        local line_w = getTextWidth(wrapped_line, subtitle_face)
                        local pad    = 0
                        if     text_align == "center" then pad = (text_width - line_w) / 2
                        elseif text_align == "right"  then pad = text_width - line_w end
                        subtitle_widget[#subtitle_widget + 1] = HorizontalGroup:new {
                            HorizontalSpan:new { width = pad },
                            TextWidget:new { text = wrapped_line, face = subtitle_face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = colors.subtext },
                        }
                    end
                end
            end
        end
    elseif allow_subtitle_multiline and text_align ~= "left" then
        local subtitle_lines = wrapText(subtitle, subtitle_face, text_width)
        subtitle_widget = VerticalGroup:new { align = "left" }
        for i, line in ipairs(subtitle_lines) do
            local line_w = getTextWidth(line, subtitle_face)
            local pad    = 0
            if     text_align == "center" then pad = (text_width - line_w) / 2
            elseif text_align == "right"  then pad = text_width - line_w end
            subtitle_widget[#subtitle_widget + 1] = HorizontalGroup:new {
                HorizontalSpan:new { width = pad },
                TextWidget:new { text = line, face = subtitle_face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = colors.subtext },
            }
        end
    else
        subtitle_widget = createMultiLineText(subtitle, subtitle_face, colors.subtext, text_width, allow_subtitle_multiline, "left")
        if text_align ~= "left" and subtitle_widget.getSize then
            local subtitle_w = subtitle_widget:getSize().w
            local pad = text_align == "center" and (text_width - subtitle_w) / 2 or (text_width - subtitle_w)
            subtitle_widget = HorizontalGroup:new { HorizontalSpan:new { width = pad }, subtitle_widget }
        end
    end

    local show_titles    = layout and layout.show_titles    or getSetting("SHOW_TITLES") ~= false
    local show_subtitles = layout and layout.show_subtitles or getSetting("SHOW_SUBTITLES") ~= false

    local text_group
    if show_titles and show_subtitles and subtitle then
        text_group = VerticalGroup:new { align = "left", width = text_width,
            title_widget, VerticalSpan:new { width = Screen:scaleBySize(0) }, subtitle_widget }
    elseif show_titles and not show_subtitles then
        text_group = VerticalGroup:new { align = "left", width = text_width, title_widget }
    elseif not show_titles and show_subtitles and subtitle then
        text_group = VerticalGroup:new { align = "left", width = text_width, subtitle_widget }
    else
        text_group = VerticalGroup:new { align = "left", width = text_width, title_widget }
    end

    header_widgets[#header_widgets + 1] = text_group

    local header_container = FrameContainer:new {
        width      = total_width,
        bordersize = 0,
        padding    = padding,
        background = colors.bg,
        HorizontalGroup:new(header_widgets),
    }

    local section_group = VerticalGroup:new { align = "left", width = total_width, header_container }

    local show_bars         = layout and layout.show_bars or getSetting("SHOW_BARS") ~= false
    local scaled_bar_height = Screen:scaleBySize(bar_height)

    if show_bars then
        section_group[#section_group + 1] = ProgressWidget:new {
            width      = total_width,
            height     = scaled_bar_height,
            bgcolor    = colors.bar_bg,
            fillcolor  = colors.fill,
            percentage = clamp(progress or 0, 0, 1),
            show_perc  = false,
            bordersize = 0,
            padding    = 0,
            margin_h   = 0,
            margin_v   = 0,
        }
    else
        section_group[#section_group + 1] = FrameContainer:new {
            width      = total_width,
            height     = scaled_bar_height,
            bordersize = 0,
            padding    = 0,
            background = Blitbuffer.COLOR_TRANSPARENT,
            HorizontalSpan:new { width = total_width },
        }
    end

    return section_group
end

local function buildBookSection(ui, state, book_data, has_ui, total_width, colors, color_config, title_face, subtitle_face, layout)
    if getSetting("SHOW_BOOK") == false then return nil end

    local book_title, page_now, page_total, avg_time, authors

    if has_ui then
        book_title = safeGet(ui, "doc_props", "display_title") or _("Untitled")
        authors    = safeGet(ui, "doc_props", "authors") or _("Unknown Author")
        page_now   = getDisplayPage(ui, state)
        page_total = getDocPages(ui)
        avg_time   = safeGet(ui, "statistics", "avg_time") or 0
    else
        book_title = book_data.title   or _("Untitled")
        authors    = book_data.authors or _("Unknown Author")
        page_now   = book_data.display_page or book_data.page or 1
        page_total = book_data.doc_pages or 1
        avg_time   = book_data.avg_time  or 0
    end

    local progress       = page_now / page_total
    local show_book_time = getSettingWithDefault(SETTINGS.SHOW_BOOK_TIME_REMAINING, true)
    local time_left_str  = nil
    if show_book_time and avg_time > 0 then
        local pages_left
        if has_ui and ui.document and ui.document.getTotalPagesLeft then
            local ok, left = pcall(ui.document.getTotalPagesLeft, ui.document, page_now)
            pages_left = (ok and left) or (page_total - page_now)
        else
            pages_left = page_total - page_now
        end
        time_left_str = formatDuration(avg_time * pages_left)
    end

    local progress_line = string.format("%d%%", math.floor(progress * 100 + 0.5))
    if time_left_str then
        progress_line = progress_line .. " · " .. string.format(_("%s left"), time_left_str)
    end

    local subtitle_lines = {}
    if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_SERIES) and book_data and book_data.series then
        local series_text = book_data.series
        if book_data.series_index then
            series_text = series_text .. " #" .. book_data.series_index
        end
        table.insert(subtitle_lines, series_text)
    end
    if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR) then table.insert(subtitle_lines, authors) end
    if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES)  then
        table.insert(subtitle_lines, string.format(_("Page %d of %d"), page_now, page_total))
    end
    table.insert(subtitle_lines, progress_line)

    local book_subtitle = createMultiLineSubtitle(subtitle_lines, subtitle_face, colors.subtext)

    local allow_multiline = getSettingWithDefault(SETTINGS.BOOK_MULTILINE, USER_CONFIG.BOOK_MULTILINE)

    return buildSection(
        total_width, book_title, book_subtitle, "custom_book", progress,
        { bg = colors.bg, text = colors.text, subtext = colors.subtext, bar_bg = colors.bar_bg,
          fill = color_config.book, fill_hex = color_config.book_hex },
        layout and layout.bar_height or getSetting("BAR_HEIGHT"), allow_multiline, true, title_face, subtitle_face,
        nil, getSetting("BOOK_TITLE_BOLD"), layout
    )
end

local function buildChapterSection(ui, state, book_data, has_ui, total_width, colors, color_config, title_face, subtitle_face, layout)
    if getSetting("SHOW_CHAP") == false then return nil end

    local chap_title, c_done, c_tot, pages_left, avg_time
    local current_chap_num, total_chapters
    local page_now

    if has_ui then
        page_now = getDisplayPage(ui, state)
        if ui.toc and ui.toc.toc and #ui.toc.toc > 0 then
            local raw          = ui.toc:getTocTitleByPage(page_now) or ""
            local should_clean = getSettingWithDefault(SETTINGS.CLEAN_CHAP, USER_CONFIG.CLEAN_CHAP)
            chap_title = should_clean and cleanChapterTitle(raw) or (raw ~= "" and raw or _("No Chapter"))
            c_done     = (ui.toc:getChapterPagesDone(page_now) or 0) + 1
            c_tot      = ui.toc:getChapterPageCount(page_now) or 1
            pages_left = ui.toc:getChapterPagesLeft(page_now) or 0
            avg_time   = safeGet(ui, "statistics", "avg_time") or 0
            current_chap_num, total_chapters = getChapterCount(ui, page_now)
        else
            chap_title = _("No Chapter"); c_done = 1; c_tot = 1; pages_left = 0
            avg_time   = safeGet(ui, "statistics", "avg_time") or 0
        end
    elseif book_data and book_data.chapter then
        chap_title       = book_data.chapter
        c_done           = book_data.chapter_pages_done  or 1
        c_tot            = book_data.chapter_pages_total or 1
        pages_left       = book_data.chapter_pages_left  or 0
        avg_time         = book_data.avg_time or 0
        current_chap_num = book_data.current_chapter_num
        total_chapters   = book_data.total_chapters
    else
        return nil
    end

    local chap_progress  = c_done / math.max(c_tot, 1)
    local show_chap_time = getSettingWithDefault(SETTINGS.SHOW_CHAP_TIME_REMAINING, true)
    local time_left      = nil
    if show_chap_time and avg_time > 0 then
        local chap_pages_left
        if has_ui and ui.toc and ui.toc.getChapterPagesLeft then
            local ok, left = pcall(ui.toc.getChapterPagesLeft, ui.toc, page_now, true)
            chap_pages_left = (ok and left) or pages_left
        else
            chap_pages_left = pages_left
        end
        time_left = formatDuration(avg_time * chap_pages_left)
    end

    local chap_sub = string.format("%d%%", math.floor(chap_progress * 100 + 0.5))
    if time_left then chap_sub = chap_sub .. " · " .. string.format(_("%s left"), time_left) end

    local subtitle_lines  = {}
    local show_chap_count = getSetting("SHOW_CHAP_COUNT")
    local show_chap_pages = getSetting("SHOW_CHAP_PAGES")

    if show_chap_count and current_chap_num and total_chapters then
        table.insert(subtitle_lines, string.format(_("Chapter %d of %d"), current_chap_num, total_chapters))
    end
    if show_chap_pages then
        table.insert(subtitle_lines, string.format(_("Page %d of %d"), c_done, c_tot))
    end
    table.insert(subtitle_lines, chap_sub)

    local final_subtitle = #subtitle_lines > 1
        and createMultiLineSubtitle(subtitle_lines, subtitle_face, colors.subtext)
        or chap_sub

    local allow_multiline = getSettingWithDefault(SETTINGS.CHAP_MULTILINE, USER_CONFIG.CHAP_MULTILINE)

    return buildSection(
        total_width, chap_title, final_subtitle, "custom_chapter", chap_progress,
        { bg = colors.bg, text = colors.text, subtext = colors.subtext, bar_bg = colors.bar_bg,
          fill = color_config.chapter, fill_hex = color_config.chapter_hex },
        layout and layout.bar_height or getSetting("BAR_HEIGHT"), allow_multiline, true, title_face, subtitle_face, nil, false, layout
    )
end

local function buildGoalSection(ui, state, book_data, has_ui, total_width, colors, color_config, title_face, subtitle_face, layout)
    if getSetting("SHOW_GOAL") == false then return nil end

    local book_id = nil
    if has_ui then
        book_id = safeGet(ui, "statistics", "id_curr_book")
    elseif book_data then
        book_id = book_data.id_curr_book
    end

    local show_streak      = getSetting("SHOW_GOAL_STREAK")
    local show_achievement = getSetting("SHOW_GOAL_ACHIEVEMENT")
    local goal_type        = getSetting("GOAL_TYPE") or USER_CONFIG.GOAL_TYPE or "pages"

    local day_dur, day_pages
    local current_streak         = 0
    local days_met, days_in_week = 0, 0

    if book_data and book_data.day_duration ~= nil then
        day_dur      = book_data.day_duration
        day_pages    = book_data.day_pages or 0
        current_streak  = book_data.streak or 0
        days_met        = book_data.days_met or 0
        days_in_week    = book_data.days_in_week or 1
    else
        local stats_mod    = require("stats")
        day_dur, day_pages = stats_mod.getDailyStats(has_ui and ui.statistics or nil, book_id)
        day_pages          = day_pages or 0
        if show_streak then
            current_streak = stats_mod.getCurrentDailyStreak()
        end
        if show_achievement then
            days_met, days_in_week = stats_mod.getWeeklyGoalAchievement(day_pages)
        end
    end

    local goal_title_type = getSetting("GOAL_TITLE_TYPE") or USER_CONFIG.GOAL_TITLE_TYPE or "time"
    local goal_title
    do
        local time_str  = formatDuration(day_dur) or _("0 mins")
        local pages_str = tostring(day_pages or 0)
        local goal_title_type = getSetting("GOAL_TITLE_TYPE") or USER_CONFIG.GOAL_TITLE_TYPE or "time"

        if goal_title_type == "pages" then
            local page_word = ngettext("page", "pages", day_pages or 0)
            goal_title = string.format(_("%s %s read today"), pages_str, page_word)
            
        elseif goal_title_type == "both" then
            local page_word = (day_pages == 1) and _("pg") or _("pgs")
            goal_title = string.format(_("%s %s & %s read today"), pages_str, page_word, time_str)
            
        else
            goal_title = string.format(_("%s read today"), time_str)
        end
    end
    local subtitle_lines = {}
    local goal_achieved, goal_progress, icon

    if goal_type == "time" then
        local daily_goal_minutes = getSetting("DAILY_GOAL_MINUTES") or USER_CONFIG.DAILY_GOAL_MINUTES or 30
        local goal_seconds       = daily_goal_minutes * 60
        local day_dur_safe       = day_dur or 0

        goal_achieved = day_dur_safe >= goal_seconds
        goal_progress = goal_seconds > 0 and (day_dur_safe / goal_seconds) or 0
        local goal_pct = math.floor(goal_progress * 100)

        if show_streak then
            table.insert(subtitle_lines, string.format(_("%d day streak"), current_streak))
        end
        if show_achievement then
            table.insert(subtitle_lines, string.format(_("%d/%d days met this week"), days_met, days_in_week))
        end

        local show_detail = getSettingWithDefault(SETTINGS.SHOW_GOAL_PAGES, USER_CONFIG.SHOW_GOAL_PAGES)
        if show_detail then
            local done_str   = formatDuration(day_dur_safe) or _("0 mins")
            local h          = math.floor(daily_goal_minutes / 60)
            local m          = daily_goal_minutes % 60
            local target_str
            if h > 0 and m > 0 then
                target_str = string.format("%d %s %d %s",
                    h, ngettext("hr", "hrs", h), m, ngettext("min", "mins", m))
            elseif h > 0 then
                target_str = string.format("%d %s", h, ngettext("hr", "hrs", h))
            else
                target_str = string.format("%d %s", daily_goal_minutes, ngettext("min", "mins", daily_goal_minutes))
            end
            local status = goal_achieved and _("Achieved!") or (goal_pct .. "%")
            table.insert(subtitle_lines, string.format("%s · %s %s", status, target_str, _("goal")))
        else
            table.insert(subtitle_lines, goal_achieved
                and _("Goal achieved!")
                or string.format(_("%d%% of goal"), goal_pct))
        end

    else
        local daily_goal = getSetting("DAILY_GOAL") or USER_CONFIG.DAILY_GOAL

        goal_achieved = day_pages >= daily_goal
        goal_progress = daily_goal > 0 and (day_pages / daily_goal) or 0
        local goal_pct = math.floor(goal_progress * 100)

        if show_streak then
            table.insert(subtitle_lines, string.format(_("%d day streak"), current_streak))
        end
        if show_achievement then
            table.insert(subtitle_lines, string.format(_("%d/%d days met this week"), days_met, days_in_week))
        end

        local show_goal_pages = getSettingWithDefault(SETTINGS.SHOW_GOAL_PAGES, USER_CONFIG.SHOW_GOAL_PAGES)
        if show_goal_pages then
            local status = goal_achieved and _("Achieved!") or (goal_pct .. "%")
            table.insert(subtitle_lines, string.format("%s · %s", status,
                string.format(_("%d page goal"), daily_goal)))
        else
            table.insert(subtitle_lines, goal_achieved
                and _("Goal achieved!")
                or string.format(_("%d%% of goal"), goal_pct))
        end
    end

    local goal_subtitle = #subtitle_lines > 1
        and createMultiLineSubtitle(subtitle_lines, subtitle_face, colors.subtext)
        or subtitle_lines[1]

    icon = goal_achieved and "custom_trophy" or "custom_goal"

    return buildSection(
        total_width, goal_title, goal_subtitle, icon, clamp(goal_progress, 0, 1),
        { bg = colors.bg, text = colors.text, subtext = colors.subtext, bar_bg = colors.bar_bg,
          fill = color_config.goal, fill_hex = color_config.goal_hex },
        layout and layout.bar_height or getSetting("BAR_HEIGHT"), true, true, title_face, subtitle_face, nil, false, layout
    )
end

local function buildBatterySection(ui, state, book_data, has_ui, total_width, colors, color_config, title_face, subtitle_face, layout)
    if getSetting("SHOW_BATT") == false then return nil end

    local batt_info          = getBatteryDisplayInfo()
    local batt_perc          = batt_info.percent
    local is_charging        = batt_info.is_charging
    local battery_hours_left = batt_info.hours_left

    local batt_fill, batt_fill_hex = getBatteryColor(batt_perc, is_charging, color_config)
    local battery_icon             = getBatteryIcon(batt_perc, is_charging)

    local show_batt_date     = getSettingWithDefault(SETTINGS.SHOW_BATT_DATE,          USER_CONFIG.SHOW_BATT_DATE)
    local show_batt_time     = getSettingWithDefault(SETTINGS.SHOW_BATT_TIME,          true)
    local show_time_separate = getSettingWithDefault(SETTINGS.SHOW_BATT_TIME_SEPARATE, USER_CONFIG.SHOW_BATT_TIME_SEPARATE)
    local show_rate          = G_reader_settings:isTrue(SETTINGS.SHOW_BATT_RATE)

    local time_fmt        = G_reader_settings:isTrue("twelve_hour_clock") and "%I:%M %p" or "%H:%M"
    local current_display = show_batt_date and formatDate() or os.date(time_fmt):gsub("^0", "")
    local charging_symbol = is_charging and "⚡" or ""

    local battery_top_line
    local subtitle_lines = {}

    if show_time_separate then
        battery_top_line = string.format("%d%% %s", batt_perc, charging_symbol)
        table.insert(subtitle_lines, current_display)
        if show_rate then
            local consumption_rate = require("stats").getBatteryConsumptionRate()
            if consumption_rate and consumption_rate > 0 then
                table.insert(subtitle_lines, string.format(_("~%.1f%%/hour"), consumption_rate))
            else
                table.insert(subtitle_lines, _("Rate unavailable"))
            end
        end
        if show_batt_time then
            table.insert(subtitle_lines, formatBatteryTime(battery_hours_left))
        end
    else
        if show_batt_time then
            battery_top_line = string.format("%d%% %s · %s", batt_perc, charging_symbol, current_display)
            if show_rate then
                local consumption_rate = require("stats").getBatteryConsumptionRate()
                if consumption_rate and consumption_rate > 0 then
                    table.insert(subtitle_lines, string.format(_("~%.1f%%/hour"), consumption_rate))
                else
                    table.insert(subtitle_lines, _("Rate unavailable"))
                end
            end
            table.insert(subtitle_lines, formatBatteryTime(battery_hours_left))
        else
            battery_top_line = string.format("%d%% %s", batt_perc, charging_symbol)
            table.insert(subtitle_lines, current_display)
            if show_rate then
                local consumption_rate = require("stats").getBatteryConsumptionRate()
                if consumption_rate and consumption_rate > 0 then
                    table.insert(subtitle_lines, string.format(_("~%.1f%%/hour"), consumption_rate))
                else
                    table.insert(subtitle_lines, _("Rate unavailable"))
                end
            end
        end
    end

    local battery_subtitle = #subtitle_lines > 1
        and createMultiLineSubtitle(subtitle_lines, subtitle_face, colors.subtext)
        or (#subtitle_lines == 1 and subtitle_lines[1] or nil)

    return buildSection(
        total_width, battery_top_line, battery_subtitle, battery_icon, batt_perc / 100,
        { bg = colors.bg, text = colors.text, subtext = colors.subtext, bar_bg = colors.bar_bg,
          fill = batt_fill, fill_hex = batt_fill_hex },
        layout and layout.bar_height or getSetting("BAR_HEIGHT"), true, true, title_face, subtitle_face, nil, false, layout
    )
end

local function buildMessageSection(ui, state, book_data, has_ui, total_width, colors, color_config, title_face, subtitle_face, layout)
    if getSetting("SHOW_MSG") == false then return nil end

    local message_source = getSetting("MESSAGE_SOURCE") or "custom"
    local message_text

    if message_source == "none" then
        return nil
    elseif message_source == "koreader" then
        if not G_reader_settings:isTrue(SETTINGS.SHOW_MSG_GLOBAL) then return nil end
        message_text = util.trim(G_reader_settings:readSetting(SETTINGS.MSG_TEXT) or "")
        if message_text ~= "" then
            if has_ui and ui.bookinfo and ui.bookinfo.expandString then
                message_text = ui.bookinfo:expandString(message_text) or message_text
            end
        else
            message_text = _("No message set")
        end
    elseif message_source == "custom" then
        local custom_msg = getSetting("CUSTOM_MESSAGE")
        if custom_msg and util.trim(custom_msg) ~= "" then
            message_text = expandMessage(custom_msg)
        else
            return nil
        end
    elseif message_source == "custom_quotes" then
        local quote = getRandomCustomQuote()
        if quote then
            local show_attribution = getSetting("SHOW_QUOTE_ATTRIBUTION")
            if show_attribution and (quote.author or quote.book) then
                local attribution_parts = {}
                if quote.author then table.insert(attribution_parts, quote.author) end
                if quote.book   then table.insert(attribution_parts, quote.book)   end
                message_text = createMultiLineSubtitle(
                    { addQuotationMarks(quote.text), table.concat(attribution_parts, ", ") },
                    subtitle_face, colors.subtext)
            else
                message_text = addQuotationMarks(quote.text)
            end
        else
            message_text = _("No custom quotes found. Add quotes to custom_quotes.lua.")
        end
    elseif message_source == "highlight" then
        local cover_path = has_ui and ui.document.file or (book_data and book_data.cover_path)
        if cover_path then
            local highlight_data = getRandomHighlight(nil, cover_path)
            if highlight_data and highlight_data.text then
                if getSetting("SHOW_HIGHLIGHT_LOCATION") then
                    local location_parts = {}
                    if highlight_data.chapter then
                        table.insert(location_parts, highlight_data.chapter)
                    end
                    if highlight_data.page then
                        table.insert(location_parts, string.format(_("pg. %s"),
                            tostring(highlight_data.page)))
                    end
                    if #location_parts > 0 then
                        message_text = createMultiLineSubtitle(
                            { highlight_data.text, table.concat(location_parts, ", ") },
                            subtitle_face, colors.subtext)
                    else
                        message_text = highlight_data.text
                    end
                else
                    message_text = highlight_data.text
                end
            else
                message_text = _("No highlights found")
            end
        else
            message_text = _("No highlights found")
        end
    elseif not message_text or message_text == "" then
        message_text = _("No message set")
    end

    local raw_header = getSetting("MSG_HEADER")
    local default_headers = {
        custom        = _("Sleeping"),
        highlight     = _("Highlights"),
        custom_quotes = _("Quotations"),
        koreader      = _("Message"),
    }
    local header_text = (raw_header and util.trim(raw_header) ~= "")
        and expandMessage(raw_header)
        or default_headers[message_source]
        or _("Message")

    local show_full_bar = getSetting("MSG_SHOW_FULL_BAR")

    return buildSection(
        total_width, header_text, message_text, "custom_message",
        show_full_bar and 1 or 0,
        { bg = colors.bg, text = colors.text, subtext = colors.subtext, bar_bg = colors.bar_bg,
          fill = color_config.message, fill_hex = color_config.message_hex },
        show_full_bar and (layout and layout.bar_height or getSetting("BAR_HEIGHT")) or 0,
        true, true, title_face, subtitle_face, nil, false, layout
    )
end

return {
    buildSection        = buildSection,
    buildBookSection    = buildBookSection,
    buildChapterSection = buildChapterSection,
    buildGoalSection    = buildGoalSection,
    buildBatterySection = buildBatterySection,
    buildMessageSection = buildMessageSection,
}
