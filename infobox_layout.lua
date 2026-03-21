-- Assembles the infobox widget from its sections and positions it on screen.

local Blitbuffer      = require("ffi/blitbuffer")
local logger          = require("logger")
local Device          = require("device")
local AlphaContainer  = require("ui/widget/container/alphacontainer")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local OverlapGroup    = require("ui/widget/overlapgroup")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")

local render                     = require("infobox_render")
local getSetting                 = render.getSetting
local setupRenderingContext      = render.setupRenderingContext
local applyProgressWidgetPatch   = render.applyProgressWidgetPatch
local restoreProgressWidgetPatch = render.restoreProgressWidgetPatch

local sections_mod        = require("infobox_sections")
local buildBookSection    = sections_mod.buildBookSection
local buildChapterSection = sections_mod.buildChapterSection
local buildGoalSection    = sections_mod.buildGoalSection
local buildBatterySection = sections_mod.buildBatterySection
local buildMessageSection = sections_mod.buildMessageSection

local bg_mod                = require("infobox_background")
local buildBackgroundWidget = bg_mod.buildBackgroundWidget
local buildDimmingLayer     = bg_mod.buildDimmingLayer

local Screen = Device.screen

local function calculateWidgetPosition(border_wrap, layout)
    local screen_size  = Screen:getSize()
    local widget_size  = border_wrap:getSize()

    local border_size   = layout.border_size
    local border_size_2 = layout.border_size_2
    local pos           = layout.pos
    local margin        = layout.margin

    local total_border_size = border_size + (border_size > 0 and border_size_2 or 0)

    local x_off, y_off = 0, 0

    if pos:find("center") or pos == "middle_center" then
        x_off = (screen_size.w - widget_size.w) / 2
    elseif pos:find("right") then
        x_off = screen_size.w - widget_size.w
    else
        x_off = 0
    end

    if pos:find("middle") or pos == "center" then
        y_off = (screen_size.h - widget_size.h) / 2
    elseif pos:find("top") then
        y_off = margin
    else
        y_off = screen_size.h - widget_size.h - margin
    end

    if total_border_size > 0 then
        if pos == "top" or pos == "top_left" or pos == "top_center" or pos == "top_right" then
            y_off = y_off - total_border_size
        end
        if pos == "bottom" or pos == "bottom_left" or pos == "bottom_center" or pos == "bottom_right" then
            y_off = y_off + total_border_size
        end
        if pos == "top_left" or pos == "middle_left" or pos == "bottom_left" then
            x_off = x_off - total_border_size
        end
        if pos == "top_right" or pos == "middle_right" or pos == "bottom_right" then
            x_off = x_off + total_border_size
        end
    end

    return x_off, y_off
end

local function wrapSectionWithBorders(section, colors, layout)
    local border_size   = layout.border_size
    local border_size_2 = layout.border_size_2
    local opacity       = layout.opacity

    local wrapped = FrameContainer:new {
        padding    = 0,
        bordersize = border_size,
        color      = colors.border,
        background = colors.bg,
        section,
    }

    if border_size > 0 and border_size_2 > 0 then
        wrapped = FrameContainer:new {
            padding    = 0,
            bordersize = border_size_2,
            color      = colors.border_2,
            background = Blitbuffer.COLOR_TRANSPARENT,
            wrapped,
        }
    end

    if opacity < 255 then
        return AlphaContainer:new { alpha = opacity / 255, wrapped }
    end

    return wrapped
end

local function buildInfoBox(ui, state, book_data)
    applyProgressWidgetPatch()
    local ok, result = pcall(function()
        local has_ui = (ui and ui.document)

        local title_face, subtitle_face, colors, color_config = setupRenderingContext()

        local layout = {
            border_size    = getSetting("BORDER_SIZE"),
            border_size_2  = getSetting("BORDER_SIZE_2"),
            opacity        = getSetting("OPACITY"),
            pos            = getSetting("POS"),
            margin         = getSetting("MARGIN"),
            box_width_pct  = getSetting("BOX_WIDTH_PCT"),
            gaps_enabled   = getSetting("SECTION_GAPS_ENABLED"),
            gap_size       = getSetting("SECTION_GAP_SIZE"),
            bar_height     = getSetting("BAR_HEIGHT"),
            icon_size      = getSetting("ICON_SIZE"),
            section_padding = getSetting("SECTION_PADDING"),
            icon_text_gap  = getSetting("ICON_TEXT_GAP"),
            show_icons     = getSetting("SHOW_ICONS") ~= false,
            show_bars      = getSetting("SHOW_BARS") ~= false,
            icon_use_bar_color = getSetting("ICON_USE_BAR_COLOR"),
            icon_set       = getSetting("ICON_SET"),
            text_align     = getSetting("TEXT_ALIGN"),
            show_titles    = getSetting("SHOW_TITLES") ~= false,
            show_subtitles = getSetting("SHOW_SUBTITLES") ~= false,
        }

        local total_width = math.floor(Screen:getWidth() * (layout.box_width_pct / 100))

        local section_builders = {
            book    = buildBookSection,
            chapter = buildChapterSection,
            goal    = buildGoalSection,
            battery = buildBatterySection,
            message = buildMessageSection,
        }

        local section_order = getSetting("SECTION_ORDER")
        if not section_order or type(section_order) ~= "table" or #section_order == 0 then
            section_order = { "book", "chapter", "goal", "battery", "message" }
        end

        local built_sections = {}
        for i, key in ipairs(section_order) do
            local builder = section_builders[key]
            if builder then
                local ok2, section = pcall(builder, ui, state, book_data, has_ui, total_width,
                                            colors, color_config, title_face, subtitle_face, layout)
                if ok2 then
                    if section then
                        built_sections[#built_sections + 1] = section
                    end
                else
                    logger.warn("[Customisable Sleep Screen] section failed: " .. tostring(key) .. " error: " .. tostring(section))
                end
            end
        end

        local border_wrap

        if layout.gaps_enabled then
            local wrapped_sections = {}
            for i, section in ipairs(built_sections) do
                wrapped_sections[#wrapped_sections + 1] = wrapSectionWithBorders(section, colors, layout)
                if i < #built_sections then
                    wrapped_sections[#wrapped_sections + 1] = VerticalSpan:new { width = layout.gap_size }
                end
            end
            local sections_group = VerticalGroup:new(wrapped_sections)
            sections_group.align = "left"
            border_wrap = sections_group
        else
            local sections_group = VerticalGroup:new(built_sections)
            sections_group.align = "left"

            border_wrap = FrameContainer:new {
                padding    = 0,
                bordersize = layout.border_size,
                color      = colors.border,
                background = colors.bg,
                sections_group,
            }

            if layout.border_size > 0 and layout.border_size_2 > 0 then
                border_wrap = FrameContainer:new {
                    padding    = 0,
                    bordersize = layout.border_size_2,
                    color      = colors.border_2,
                    background = Blitbuffer.COLOR_TRANSPARENT,
                    border_wrap,
                }
            end
        end

        local x_off, y_off = calculateWidgetPosition(border_wrap, layout)
        local dimming_layer = buildDimmingLayer()
        local bg_widget     = buildBackgroundWidget(ui, book_data)
        local screen_size   = Screen:getSize()

        local final_widget = layout.gaps_enabled and border_wrap
            or (layout.opacity >= 255 and border_wrap
            or AlphaContainer:new { alpha = layout.opacity / 255, border_wrap })

        return OverlapGroup:new {
            dimen = screen_size,
            bg_widget or HorizontalSpan:new { width = screen_size.w },
            dimming_layer,
            OverlapGroup:new {
                dimen = screen_size,
                VerticalGroup:new {
                    VerticalSpan:new { width = y_off },
                    HorizontalGroup:new {
                        HorizontalSpan:new { width = x_off },
                        FrameContainer:new { bordersize = 0, padding = 0, final_widget },
                    },
                },
            },
        }
    end)
    if ok then
        return result
    else
        restoreProgressWidgetPatch()
        logger.warn("[Customisable Sleep Screen] buildInfoBox error: " .. tostring(result))
        return nil
    end
end

return {
    calculateWidgetPosition = calculateWidgetPosition,
    wrapSectionWithBorders  = wrapSectionWithBorders,
    buildInfoBox            = buildInfoBox,
}
