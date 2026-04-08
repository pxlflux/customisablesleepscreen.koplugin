-- Shared rendering utilities: fonts, colours, text layout, and the progress bar patch.

local Blitbuffer         = require("ffi/blitbuffer")
local logger             = require("logger")
local util               = require("util")
local Device             = require("device")
local Font               = require("ui/font")
local ProgressWidget     = require("ui/widget/progresswidget")
local TextWidget         = require("ui/widget/textwidget")
local TextWidget_paintTo = TextWidget.paintTo

local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS
local getSetting  = config.getSetting

local Screen = Device.screen

local function clamp(val, mn, mx)
    return math.max(mn, math.min(mx, val))
end

local font_cache  = {}
local color_cache = {}

local function patchedTextWidgetPaintTo(self, bb, x, y)
    self:updateSize()
    if self._is_empty then return end

    if not self.use_xtext or not self._fgcolor_rgb then
        return TextWidget_paintTo(self, bb, x, y)
    end

    if not self._xshaping then
        self._xshaping = self._xtext:shapeLine(self._shape_start, self._shape_end,
                                               self._shape_idx_to_substitute_with_ellipsis)
    end

    local text_width = bb:getWidth() - x
    if self.max_width and self.max_width < text_width then
        text_width = self.max_width
    end

    local RenderText = require("ui/rendertext")
    local pen_x   = 0
    local baseline = self.forced_baseline or self._baseline_h
    for i, xglyph in ipairs(self._xshaping) do
        if pen_x >= text_width then break end
        local face  = self.face.getFallbackFont(xglyph.font_num)
        local glyph = RenderText:getGlyphByIndex(face, xglyph.glyph, self.bold)
        local gw = glyph.bb:getWidth()
        local gh = glyph.bb:getHeight()
        local gx = x + pen_x + glyph.l + xglyph.x_offset
        local gy = y + baseline - glyph.t - xglyph.y_offset
        bb:colorblitFromRGB32(glyph.bb, gx, gy, 0, 0, gw, gh, self._fgcolor_rgb)
        pen_x = pen_x + xglyph.x_advance
    end
end

local function applyTextWidgetPatch()
    TextWidget.paintTo = patchedTextWidgetPaintTo
end

local function restoreTextWidgetPatch()
    TextWidget.paintTo = TextWidget_paintTo
end

local ProgressWidget_paintTo = ProgressWidget.paintTo

local function patchedProgressWidgetPaintTo(self, bb, x, y)
    local my_size = self:getSize()
    if not self.dimen then
        self.dimen = require("ui/geometry"):new({ x = x, y = y, w = my_size.w, h = my_size.h })
    else
        self.dimen.x = x
        self.dimen.y = y
    end
    if self.dimen.w == 0 or self.dimen.h == 0 then return end

    local BD          = require("ui/bidi")
    local _mirrored_ui = BD.mirroredUILayout()
    local fill_width  = my_size.w - 2 * (self.margin_h + self.bordersize)
    local fill_y      = y + self.margin_v + self.bordersize
    local fill_height = my_size.h - 2 * (self.margin_v + self.bordersize)

    if self.radius == 0 then
        bb:paintRect(x, y, my_size.w, my_size.h, self.bordercolor)
        bb:paintRectRGB32(x + self.margin_h + self.bordersize, fill_y,
            math.ceil(fill_width), math.ceil(fill_height), self.bgcolor)
    else
        bb:paintRectRGB32(x, y, my_size.w, my_size.h, self.bgcolor)
        bb:paintBorder(math.floor(x), math.floor(y), my_size.w, my_size.h,
            self.bordersize, self.bordercolor, self.radius)
    end

    if self.percentage >= 0 and self.percentage <= 1 then
        local fill_x = x + self.margin_h + self.bordersize
        if self.fill_from_right or (_mirrored_ui and not self.fill_from_right) then
            fill_x = fill_x + (fill_width * (1 - self.percentage))
            fill_x = math.floor(fill_x)
        end
        bb:paintRectRGB32(fill_x, fill_y,
            math.ceil(fill_width * self.percentage), math.ceil(fill_height), self.fillcolor)
    end

    if self.ticks and self.last and self.last > 0 then
        for _, tick in ipairs(self.ticks) do
            local tick_x = fill_width * (tick / self.last)
            if _mirrored_ui then tick_x = fill_width - tick_x end
            tick_x = math.floor(tick_x)
            bb:paintRect(x + self.margin_h + self.bordersize + tick_x,
                fill_y, self.tick_width, math.ceil(fill_height), self.bordercolor)
        end
    end
end

local function applyProgressWidgetPatch()
    applyTextWidgetPatch()
    font_cache  = {}
    color_cache = {}
    ProgressWidget.paintTo = patchedProgressWidgetPaintTo
    local ok, RenderText = pcall(require, "ui/rendertext")
    if ok and RenderText and RenderText.clearGlyphCache then
        RenderText:clearGlyphCache()
    end
end

local function restoreProgressWidgetPatch()
    restoreTextWidgetPatch()
    ProgressWidget.paintTo = ProgressWidget_paintTo
end

local function getCachedColor(hex)
    if not hex then return Blitbuffer.COLOR_BLACK end
    if not color_cache[hex] then
        local r = tonumber(hex:sub(2, 3), 16) or 0
        local g = tonumber(hex:sub(4, 5), 16) or 0
        local b = tonumber(hex:sub(6, 7), 16) or 0
        color_cache[hex] = Blitbuffer.ColorRGB32(r, g, b, 0xFF)
    end
    return color_cache[hex]
end

local function getBBColor(setting_key, default_hex)
    local hex = G_reader_settings:readSetting(setting_key) or default_hex
    return getCachedColor(hex)
end

local function getColors(is_mono, mono_hex, mono_color)
    if is_mono then
        return {
            book_hex    = mono_hex, chapter_hex = mono_hex,
            goal_hex    = mono_hex, message_hex = mono_hex,
            book        = mono_color, chapter = mono_color,
            goal        = mono_color, message = mono_color,
        }
    end
    return {
        book_hex    = getSetting("COLOR_BOOK_FILL"),
        chapter_hex = getSetting("COLOR_CHAPTER_FILL"),
        goal_hex    = getSetting("COLOR_GOAL_FILL"),
        message_hex = getSetting("COLOR_MESSAGE_FILL"),
        book    = getBBColor(SETTINGS.COLOR_BOOK_FILL,    USER_CONFIG.COLOR_BOOK_FILL),
        chapter = getBBColor(SETTINGS.COLOR_CHAPTER_FILL, USER_CONFIG.COLOR_CHAPTER_FILL),
        goal    = getBBColor(SETTINGS.COLOR_GOAL_FILL,    USER_CONFIG.COLOR_GOAL_FILL),
        message = getBBColor(SETTINGS.COLOR_MESSAGE_FILL, USER_CONFIG.COLOR_MESSAGE_FILL),
    }
end

local function resolveFontPath(font_name)
    if not font_name or font_name == "cfont" then return nil end
    if font_name:match("^%.?/") then return font_name end
    local ok_cre, cre_mod = pcall(require, "document/credocument")
    if not ok_cre then return font_name end
    local ok_eng, engine = pcall(function() return cre_mod:engineInit() end)
    if not (ok_eng and engine and engine.getFontFaceFilenameAndFaceIndex) then return font_name end
    local path = engine.getFontFaceFilenameAndFaceIndex(font_name)
    return path or font_name
end

local function getCachedFont(font_name, size)
    local key = (font_name or "cfont") .. ":" .. size
    if not font_cache[key] then
        local resolved = resolveFontPath(font_name)
        local ok, face = pcall(Font.getFace, Font, resolved, size)
        if ok and face then
            font_cache[key] = face
        else
            logger.warn("[Customisable Sleep Screen] Font '" .. tostring(font_name) .. "' failed, falling back to cfont")
            font_cache[key] = Font:getFace("cfont", size) or Font:getFace("cfont", 20)
        end
    end
    return font_cache[key]
end

local function blendHex(hex, r2, g2, b2, t)
    local r1 = tonumber(hex:sub(2, 3), 16) or 0
    local g1 = tonumber(hex:sub(4, 5), 16) or 0
    local b1 = tonumber(hex:sub(6, 7), 16) or 0
    local r = math.floor(r1 * (1 - t) + r2 * t + 0.5)
    local g = math.floor(g1 * (1 - t) + g2 * t + 0.5)
    local b = math.floor(b1 * (1 - t) + b2 * t + 0.5)
    return Blitbuffer.ColorRGB32(r, g, b, 0xFF)
end

local function setupRenderingContext()
    local title_face    = getCachedFont(getSetting("FONT_FACE_TITLE"),    Screen:scaleBySize(getSetting("FONT_SIZE_TITLE")))
    local subtitle_face = getCachedFont(getSetting("FONT_FACE_SUBTITLE"), Screen:scaleBySize(getSetting("FONT_SIZE_SUBTITLE")))

    local dark    = G_reader_settings:isTrue(SETTINGS.DARK_MODE)
    local is_mono = G_reader_settings:isTrue(SETTINGS.MONOCHROME)

    local color_dark_hex  = getSetting("COLOR_DARK")
    local color_light_hex = getSetting("COLOR_LIGHT")
    local mono_hex   = dark and color_dark_hex or color_light_hex
    local mono_color = getCachedColor(mono_hex)

    local color_config          = getColors(is_mono, mono_hex, mono_color)
    color_config.is_mono    = is_mono
    color_config.mono_color = mono_color
    color_config.mono_hex   = mono_hex

    local bg_hex = dark and getSetting("COLOR_BOX_BG_DARK") or getSetting("COLOR_BOX_BG")
    local colors = {
        bg       = getCachedColor(dark and getSetting("COLOR_BOX_BG_DARK")  or getSetting("COLOR_BOX_BG")),
        text     = getCachedColor(dark and getSetting("COLOR_TEXT_DARK")    or getSetting("COLOR_TEXT")),
        subtext  = getCachedColor(dark and getSetting("COLOR_TEXT_DARK")    or getSetting("COLOR_TEXT")),
        bar_bg   = dark and blendHex(bg_hex, 255, 255, 255, 0.18)           or blendHex(bg_hex, 0, 0, 0, 0.18),
        border   = getCachedColor(dark and getSetting("COLOR_TEXT_DARK")    or getSetting("COLOR_TEXT")),
        border_2 = getCachedColor(dark and getSetting("COLOR_BOX_BG_DARK")  or getSetting("COLOR_BOX_BG")),
    }

    return title_face, subtitle_face, colors, color_config
end

local function getTextWidth(text, face)
    if not face or not text or text == "" then return 0 end
    if face.getAdvance then return face:getAdvance(text) end
    local tw = TextWidget:new { text = text, face = face }
    local w  = tw:getSize().w
    tw:free()
    return w
end

local function wrapText(text, face, max_width)
    if not text or text == "" or not face then return {} end
    local lines, current_line, current_width = {}, {}, 0
    local space_width = getTextWidth(" ", face)

    if util.hasCJKChar(text) then
        local current_line_text = ""
        local current_w = 0
        for _, char in ipairs(util.splitToChars(text)) do
            local cw = getTextWidth(char, face)
            if current_w + cw > max_width and current_line_text ~= "" then
                lines[#lines + 1] = current_line_text
                current_line_text = char
                current_w = cw
            else
                current_line_text = current_line_text .. char
                current_w = current_w + cw
            end
        end
        if current_line_text ~= "" then lines[#lines + 1] = current_line_text end
        return lines
    end

    for word in text:gmatch("%S+") do
        local ww = getTextWidth(word, face)
        if #current_line == 0 then
            current_line[1] = word
            current_width   = ww
        elseif current_width + space_width + ww <= max_width then
            current_line[#current_line + 1] = word
            current_width = current_width + space_width + ww
        else
            lines[#lines + 1] = table.concat(current_line, " ")
            current_line  = { word }
            current_width = ww
        end
    end
    if #current_line > 0 then lines[#lines + 1] = table.concat(current_line, " ") end
    return lines
end

local function createMultiLineText(text, face, color, max_width, allow_multiline, alignment, bold)
    if allow_multiline == nil then allow_multiline = true end
    if not alignment then alignment = "left" end
    if not text or text == "" then
        return TextWidget:new { text = "", face = face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = color, bold = bold }
    end
    if not allow_multiline then
        local ellipsis = "…"
        if getTextWidth(text, face) <= max_width then
            return TextWidget:new { text = text, face = face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = color, bold = bold }
        end
        local words, current_text, best_text = {}, "", ""
        for word in text:gmatch("%S+") do words[#words + 1] = word end
        for _, word in ipairs(words) do
            local test = current_text == "" and word or current_text .. " " .. word
            if getTextWidth(test .. ellipsis, face) <= max_width then
                current_text = test
                best_text    = current_text
            else
                break
            end
        end
        return TextWidget:new { text = best_text .. ellipsis, face = face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = color, bold = bold }
    end
    local lines = wrapText(text, face, max_width)
    if #lines == 1 then
        return TextWidget:new { text = lines[1], face = face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = color, bold = bold }
    end
    local tg = require("ui/widget/verticalgroup"):new { align = alignment }
    for _, line in ipairs(lines) do
        tg[#tg + 1] = TextWidget:new { text = line, face = face, fgcolor = Blitbuffer.COLOR_BLACK, _fgcolor_rgb = color, bold = bold }
    end
    return tg
end

return {
    applyProgressWidgetPatch   = applyProgressWidgetPatch,
    restoreProgressWidgetPatch = restoreProgressWidgetPatch,
    applyTextWidgetPatch       = applyTextWidgetPatch,
    restoreTextWidgetPatch     = restoreTextWidgetPatch,
    getCachedFont              = getCachedFont,
    getCachedColor             = getCachedColor,
    getColors                  = getColors,
    getBBColor                 = getBBColor,
    setupRenderingContext      = setupRenderingContext,
    getTextWidth               = getTextWidth,
    wrapText                   = wrapText,
    createMultiLineText        = createMultiLineText,
    clamp                      = clamp,
    getSetting                 = getSetting,
}
