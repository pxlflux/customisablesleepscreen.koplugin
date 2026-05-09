-- Menu items for display modes, layout, colours, fonts, and background.

local logger    = require("logger")
local UIManager = require("ui/uimanager")

local _           = require("gettext")
local config      = require("css_config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS

local PluginStore = require("css_settings").plugin()

local h                        = require("css_menu_helpers")
local getSetting               = h.getSetting
local createToggleItem         = h.createToggleItem
local createFlipNilOrFalseItem = h.createFlipNilOrFalseItem
local createRadioItem          = h.createRadioItem
local createColorMenuItem      = h.createColorMenuItem
local createResetMenuItem      = h.createResetMenuItem
local createSpinDialog         = h.createSpinDialog
local buildNumericMenu         = h.buildNumericMenu
local hexToHSV                 = h.hexToHSV
local getColourWheelWidget     = h.getColourWheelWidget

local cre
local function getCre()
    if not cre then
        local ok, mod = pcall(require, "document/credocument")
        cre = ok and mod or false
    end
    return cre or nil
end

local _cre_engine = nil
local function getCachedCreEngine()
    if _cre_engine ~= nil then return _cre_engine or nil end
    local cre_mod = getCre()
    if not cre_mod then _cre_engine = false; return nil end
    local ok, eng = pcall(function() return cre_mod:engineInit() end)
    _cre_engine = (ok and eng and eng.getFontFaces) and eng or false
    return _cre_engine or nil
end

local _plugin_dir = (debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$") or ".") .. "/"
local function getAvailableIconSets()
    local lfs        = require("libs/libkoreader-lfs")
    local icon_sets  = {}
    local base_path = _plugin_dir .. "icons"
    pcall(function()
        for file in lfs.dir(base_path) do
            if file ~= "." and file ~= ".." then
                local attr = lfs.attributes(base_path .. "/" .. file)
                if attr and attr.mode == "directory" then
                    icon_sets[#icon_sets + 1] = file
                end
            end
        end
    end)
    table.sort(icon_sets)
    return icon_sets
end

local function buildPositionMenu()
    local options = {
        { text = _("Top left"),      val = "top_left"      },
        { text = _("Top centre"),    val = "top_center"    },
        { text = _("Top right"),     val = "top_right"     },
        { text = _("Middle left"),   val = "middle_left"   },
        { text = _("Centre"),        val = "center"        },
        { text = _("Middle right"),  val = "middle_right"  },
        { text = _("Bottom left"),   val = "bottom_left"   },
        { text = _("Bottom centre"), val = "bottom_center" },
        { text = _("Bottom right"),  val = "bottom_right"  },
    }
    return buildNumericMenu("POS", options)
end

local function buildDisplayModesMenu()
    return {
        createToggleItem(_("Dark mode"),
            _("Inverts the colour scheme. Text becomes white and backgrounds becomes black. Useful for reading in low-light conditions. Can be combined with monochrome mode."),
            SETTINGS.DARK_MODE, false),
        createToggleItem(_("Monochrome mode"),
            _("Suitable for B&W e-readers. Assigns one colour to all sections using monochrome light or monochrome dark hex values. Overwrites individual assigned section colours. Can be combined with dark mode."),
            SETTINGS.MONOCHROME, false),
    }
end

local function buildLayoutAndSpacingMenu()
    return {
        createResetMenuItem("layout & spacing", {
            SETTINGS.SECTION_GAPS_ENABLED, SETTINGS.SECTION_GAP_SIZE,
            SETTINGS.POS, SETTINGS.BOX_WIDTH_PCT, SETTINGS.OPACITY,
            SETTINGS.BORDER_SIZE, SETTINGS.BORDER_SIZE_2,
            SETTINGS.SECTION_PADDING, SETTINGS.SECTION_PADDING_TOP, SETTINGS.SECTION_PADDING_BOTTOM,
            SETTINGS.SECTION_PADDING_LEFT, SETTINGS.SECTION_PADDING_RIGHT, SETTINGS.ICON_TEXT_GAP,
            SETTINGS.SLEEP_ORIENTATION,
            SETTINGS.SECTION_RADIUS, 
            SETTINGS.POS_OFFSET_X, SETTINGS.POS_OFFSET_Y,
        }),
        {
            text = _("Section gaps"),
            help_text = _("Add transparent gaps between sections to make each appear as a separate box"),
            sub_item_table = {
                {
                    text      = _("Enable section gaps"),
                    checked_func = function() return getSetting("SECTION_GAPS_ENABLED") end,
                    callback = function()
                        PluginStore:saveSetting(SETTINGS.SECTION_GAPS_ENABLED,
                            not getSetting("SECTION_GAPS_ENABLED"))
                    end,
                },
                {
                    text      = _("Section gap size"),
                    help_text = _("Spacing between sections when gaps are enabled."),
                    enabled_func   = function() return getSetting("SECTION_GAPS_ENABLED") end,
                    keep_menu_open = true,

                    callback = function()
                        local Device = require("device")
                        local enabled_sections = 0
                        for _, key in ipairs({ "SHOW_BOOK", "SHOW_CHAP", "SHOW_GOAL", "SHOW_BATT", "SHOW_MSG" }) do
                            if getSetting(key) ~= false then enabled_sections = enabled_sections + 1 end
                        end
                        local gaps_between = math.max(enabled_sections - 1, 1)
                        local section_height_estimate = 250
                        local usable_height = Device.screen:getHeight() - (enabled_sections * section_height_estimate)
                        local max_gap = math.floor(math.max(usable_height, 100) / gaps_between)

                        createSpinDialog(
                            _("Section gap size (pixels)"),
                            getSetting("SECTION_GAP_SIZE") or USER_CONFIG.SECTION_GAP_SIZE,
                            0, max_gap, 5,
                            function(val) PluginStore:saveSetting(SETTINGS.SECTION_GAP_SIZE, val) end,
                            _("10–20px gives a subtle separation. 30–50px makes sections feel like distinct cards.")
                        )
                    end,
                },
            }
        },
        { text = _("Position"),       sub_item_table = buildPositionMenu(),    help_text = _("Screen location where the information box appears.") },
        {
            text      = _("Position offset"),
            help_text = _("Nudge the box from its anchor position. Useful for pushing rounded corners off-screen."),
            sub_item_table = {
                {
                    text           = _("Horizontal offset (px)"),
                    keep_menu_open = true,
                    callback = function()
                        local Device = require("device")
                        local box_width = math.floor(Device.screen:getWidth() * ((getSetting("BOX_WIDTH_PCT") or 60) / 100))
                        local max_offset = math.floor(box_width * 0.2)
                        createSpinDialog(
                            _("Horizontal offset (px)"),
                            getSetting("POS_OFFSET_X") or 0,
                            -max_offset, max_offset, 5,
                            function(val) PluginStore:saveSetting(SETTINGS.POS_OFFSET_X, val) end,
                            _("Nudges the box left (-) or right (+) from its anchor. Useful for pushing rounded corners off-screen."),
                            "%d", 25
                        )
                    end,
                },
                {
                    text           = _("Vertical offset (px)"),
                    keep_menu_open = true,
                    callback = function()
                        local Device = require("device")
                        local box_height = math.floor(Device.screen:getHeight() * 0.4)
                        local max_offset = math.floor(box_height * 0.2)
                        createSpinDialog(
                            _("Vertical offset (px)"),
                            getSetting("POS_OFFSET_Y") or 0,
                            -max_offset, max_offset, 5,
                            function(val) PluginStore:saveSetting(SETTINGS.POS_OFFSET_Y, val) end,
                            _("Nudges the box up (+) or down (-) from its anchor. Useful for pushing rounded corners off-screen."),
                            "%d", 25
                        )
                    end,
                },
            },
        },
        {
            text           = _("Width"),
            help_text      = _("Horizontal width of the information box as a percentage of screen width."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Box width (%)"),
                    getSetting("BOX_WIDTH_PCT") or USER_CONFIG.BOX_WIDTH_PCT,
                    30, 100, 5,
                    function(val) PluginStore:saveSetting(SETTINGS.BOX_WIDTH_PCT, val) end,
                    _("60–70% suits portrait screens."), "%d", 10
                )
            end,
        },
        {
            text           = _("Opacity"),
            help_text      = _("Transparency of the information box."),
            keep_menu_open = true,
            callback = function()
                local current_alpha = getSetting("OPACITY") or USER_CONFIG.OPACITY
                createSpinDialog(
                    _("Opacity (%)"),
                    math.floor((current_alpha / 255) * 100),
                    50, 100, 5,
                    function(val)
                        local alpha = math.floor((val / 100) * 255)
                        PluginStore:saveSetting(SETTINGS.OPACITY, alpha)
                    end,
                    _("75% is semi-transparent. 100% is fully opaque."),
                    "%d", 5
                )
            end,
        },
        {
            text           = _("Border size"),
            help_text      = _("Thickness of the primary border around sections."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Border size (px)"),
                    getSetting("BORDER_SIZE") or USER_CONFIG.BORDER_SIZE,
                    0, 15, 1,
                    function(val) PluginStore:saveSetting(SETTINGS.BORDER_SIZE, val) end,
                    _("0 for no border. 1–2px is subtle, 4–6px is bold and visible."), "%d", 5
                )
            end,
        },
        {
            text           = _("Border trim size"),
            help_text      = _("Secondary decorative border surrounding the primary border."),
            enabled_func   = function() return getSetting("BORDER_SIZE") > 0 end,
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Border trim size (px)"),
                    getSetting("BORDER_SIZE_2") or USER_CONFIG.BORDER_SIZE_2,
                    0, 15, 1,
                    function(val) PluginStore:saveSetting(SETTINGS.BORDER_SIZE_2, val) end,
                    _("0 for no trim. 1–2px is subtle, 4–6px is a bold decorative outline around the primary border."), "%d", 5
                )
            end,
        },
        {
            text           = _("Corner radius"),
            help_text      = _("Round the corners of the info box. Also moves progress bars inline with the text when active."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Corner radius (px)"),
                    getSetting("SECTION_RADIUS") or 0,
                    0, 300, 5,
                    function(val) PluginStore:saveSetting(SETTINGS.SECTION_RADIUS, val) end,
                    _("0 for square corners. 15–30px for softly rounded. 150px+ for a pill-shaped box (depending on the section box height)."),
                    "%d", 25
                )
            end,
        },
        {
            text      = _("Internal padding"),
            help_text = _("Space between section borders and their content, configurable per side."),
            sub_item_table = {
                {
                    text           = _("Top"),
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Internal padding - top (px)"),
                            getSetting("SECTION_PADDING_TOP") or USER_CONFIG.SECTION_PADDING_TOP,
                            0, 100, 1,
                            function(val) PluginStore:saveSetting(SETTINGS.SECTION_PADDING_TOP, val) end,
                            _("Space above section content."),
                            "%d", 5
                        )
                    end,
                },
                {
                    text           = _("Bottom"),
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Internal padding - bottom (px)"),
                            getSetting("SECTION_PADDING_BOTTOM") or USER_CONFIG.SECTION_PADDING_BOTTOM,
                            0, 100, 1,
                            function(val) PluginStore:saveSetting(SETTINGS.SECTION_PADDING_BOTTOM, val) end,
                            _("Space below section content."),
                            "%d", 5
                        )
                    end,
                },
                {
                    text           = _("Left"),
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Internal padding - left (px)"),
                            getSetting("SECTION_PADDING_LEFT") or USER_CONFIG.SECTION_PADDING_LEFT,
                            0, 100, 1,
                            function(val) PluginStore:saveSetting(SETTINGS.SECTION_PADDING_LEFT, val) end,
                            _("Space to the left of section content. Increase when using large corner radii."),
                            "%d", 5
                        )
                    end,
                },
                {
                    text           = _("Right"),
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Internal padding - right (px)"),
                            getSetting("SECTION_PADDING_RIGHT") or USER_CONFIG.SECTION_PADDING_RIGHT,
                            0, 100, 1,
                            function(val) PluginStore:saveSetting(SETTINGS.SECTION_PADDING_RIGHT, val) end,
                            _("Space to the right of section content. Increase when using large corner radii."),
                            "%d", 5
                        )
                    end,
                },
                {
                    text           = _("Set all sides equally"),
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Internal padding - all sides (px)"),
                            getSetting("SECTION_PADDING") or USER_CONFIG.SECTION_PADDING,
                            0, 100, 1,
                            function(val)
                                PluginStore:saveSetting(SETTINGS.SECTION_PADDING_TOP,    val)
                                PluginStore:saveSetting(SETTINGS.SECTION_PADDING_BOTTOM, val)
                                PluginStore:saveSetting(SETTINGS.SECTION_PADDING_LEFT,   val)
                                PluginStore:saveSetting(SETTINGS.SECTION_PADDING_RIGHT,  val)
                            end,
                            _("Sets top, bottom, left and right padding to the same value in one step."),
                            "%d", 5
                        )
                    end,
                },
            },
        },
        {
            text           = _("Icon to text gap"),
            help_text      = _("Horizontal spacing between section icons and their accompanying text."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Icon to text gap (px)"),
                    getSetting("ICON_TEXT_GAP") or USER_CONFIG.ICON_TEXT_GAP,
                    0, 50, 5,
                    function(val) PluginStore:saveSetting(SETTINGS.ICON_TEXT_GAP, val) end,
                    _("8–12px gives comfortable breathing room between icon and text. 0 is flush."),
                    "%d", 10
                )
            end,
        },
    }
end

local function buildIconSetMenu()
    local icon_sets = getAvailableIconSets()
    if #icon_sets == 0 then
        return {{ text = _("No icon sets found in customisablesleepscreen.koplugin/icons/"), enabled = false }}
    end
    local options = {}
    for i, set_name in ipairs(icon_sets) do
        options[#options + 1] = { text = set_name, val = set_name }
    end
    return buildNumericMenu("ICON_SET", options)
end

local function buildColorsIconsBarsMenu()
    return {
        createResetMenuItem("colours, icons & bars", {
            SETTINGS.COLOR_BOOK_FILL,       SETTINGS.COLOR_CHAPTER_FILL,
            SETTINGS.COLOR_GOAL_FILL,       SETTINGS.BATT_HIGH_COLOR,
            SETTINGS.BATT_MED_COLOR,        SETTINGS.BATT_LOW_COLOR,
            SETTINGS.BATT_CHARGING_COLOR,   SETTINGS.COLOR_MESSAGE_FILL,
            SETTINGS.COLOR_LIGHT,           SETTINGS.COLOR_DARK,
            SETTINGS.ICON_USE_BAR_COLOR,    SETTINGS.ICON_SET,
            SETTINGS.ICON_SIZE,             SETTINGS.BAR_HEIGHT,
            SETTINGS.SHOW_ICONS,            SETTINGS.SHOW_BARS,
            SETTINGS.MSG_SHOW_FULL_BAR,     SETTINGS.COLOR_BOX_BG,
            SETTINGS.COLOR_BOX_BG_DARK,     SETTINGS.COLOR_TEXT,
            SETTINGS.COLOR_TEXT_DARK,       SETTINGS.BAR_INLINE,
            SETTINGS.BAR_INLINE_WIDTH_PCT,  SETTINGS.BAR_BORDER_SIZE,
        }),
        {
            text      = _("Colours (progress bars)"),
            help_text = _("Set the progress bar colours for each section."),
            sub_item_table = (function()
                local menu_items = {}
                menu_items[#menu_items + 1] = createToggleItem(
                    _("Use saved colours for icon fill"),
                    _("When enabled, icons will match the colour of their section's progress bar."),
                    SETTINGS.ICON_USE_BAR_COLOR, USER_CONFIG.ICON_USE_BAR_COLOR, true)
                local color_items = {
                    { _("Book section"),                 SETTINGS.COLOR_BOOK_FILL,     USER_CONFIG.COLOR_BOOK_FILL     },
                    { _("Chapter section"),              SETTINGS.COLOR_CHAPTER_FILL,  USER_CONFIG.COLOR_CHAPTER_FILL  },
                    { _("Daily goal section"),           SETTINGS.COLOR_GOAL_FILL,     USER_CONFIG.COLOR_GOAL_FILL     },
                    { _("Battery section (High)"),       SETTINGS.BATT_HIGH_COLOR,     USER_CONFIG.BATT_HIGH_COLOR     },
                    { _("Battery section (Med)"),        SETTINGS.BATT_MED_COLOR,      USER_CONFIG.BATT_MED_COLOR      },
                    { _("Battery section (Low)"),        SETTINGS.BATT_LOW_COLOR,      USER_CONFIG.BATT_LOW_COLOR      },
                    { _("Battery section (Charging)"),   SETTINGS.BATT_CHARGING_COLOR, USER_CONFIG.BATT_CHARGING_COLOR },
                    { _("Message section"),              SETTINGS.COLOR_MESSAGE_FILL,  USER_CONFIG.COLOR_MESSAGE_FILL  },
                }
                for _, item in ipairs(color_items) do
                    menu_items[#menu_items + 1] = createColorMenuItem(item[1], item[2], item[3])
                end
                return menu_items
            end)(),
        },
        {
            text      = _("Colours (modes)"),
            help_text = _("Configure colours for monochrome mode, infobox background, and text. Light and dark correspond to the current dark mode setting. Monochrome replaces all colours with that single chosen color."),
            sub_item_table = (function()
                local menu_items = {}
                local color_items = {
                    { _("Monochrome mode (light)"),      SETTINGS.COLOR_LIGHT,         USER_CONFIG.COLOR_LIGHT         },
                    { _("Monochrome mode (dark)"),       SETTINGS.COLOR_DARK,          USER_CONFIG.COLOR_DARK          },
                    { _("Background (light)"),           SETTINGS.COLOR_BOX_BG,        USER_CONFIG.COLOR_BOX_BG        },
                    { _("Background (dark)"),            SETTINGS.COLOR_BOX_BG_DARK,   USER_CONFIG.COLOR_BOX_BG_DARK   },
                    { _("Text (light)"),                 SETTINGS.COLOR_TEXT,          USER_CONFIG.COLOR_TEXT          },
                    { _("Text (dark)"),                  SETTINGS.COLOR_TEXT_DARK,     USER_CONFIG.COLOR_TEXT_DARK     },
                }
                for _, item in ipairs(color_items) do
                    menu_items[#menu_items + 1] = createColorMenuItem(item[1], item[2], item[3])
                end
                return menu_items
            end)(),
        },
        { text = _("Icon set"),            help_text = _("Choose from different icon styles."),
          sub_item_table = buildIconSetMenu() },
        {
            text           = _("Icon size"),
            help_text      = _("Size of section icons."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Icon size (px)"),
                    getSetting("ICON_SIZE") or USER_CONFIG.ICON_SIZE,
                    16, 128, 4,
                    function(val) PluginStore:saveSetting(SETTINGS.ICON_SIZE, val) end,
                    _("32–48px suits most layouts."), "%d", 16
                )
            end,
        },
        {
            text           = _("Progress bar height"),
            help_text      = _("Thickness of the horizontal progress bars shown in each section."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Bar height (px)"),
                    getSetting("BAR_HEIGHT") or USER_CONFIG.BAR_HEIGHT,
                    2, 40, 4,
                    function(val) PluginStore:saveSetting(SETTINGS.BAR_HEIGHT, val) end,
                    _("4–8px is subtle. 12–16px is standard. 20+px is heavy."), "%d", 8
                )
            end,
        },
        {
            text      = _("Show icons"),
            help_text = _("Display decorative icons at the start of each section."),
            checked_func = function() return getSetting("SHOW_ICONS") ~= false end,
            callback = function()
                PluginStore:saveSetting(SETTINGS.SHOW_ICONS, not (getSetting("SHOW_ICONS") ~= false))
            end,
        },
        {
            text      = _("Show progress bars"),
            help_text = _("Display horizontal progress bars showing completion percentage."),
            checked_func = function() return getSetting("SHOW_BARS") ~= false end,
            callback = function()
                PluginStore:saveSetting(SETTINGS.SHOW_BARS, not (getSetting("SHOW_BARS") ~= false))
            end,
        },
        {
            text      = _("Show decorative bar on message section"),
            help_text = _("Displays a purely decorative progress bar under the message section, matching the message section colour and the progress bars in other sections."),
            enabled_func = function()
                return getSetting("SHOW_BARS") ~= false
            end,
            checked_func = function()
                local val = PluginStore:readSetting(SETTINGS.MSG_SHOW_FULL_BAR)
                return val == nil and false or val
            end,
            callback = function()
                local current = PluginStore:readSetting(SETTINGS.MSG_SHOW_FULL_BAR)
                if current == nil then current = false end
                PluginStore:saveSetting(SETTINGS.MSG_SHOW_FULL_BAR, not current)
            end,
        },
        {
            text      = _("Inline progress bars"),
            help_text = _("Progress bars sit inside the text area rather than spanning the full section width. Automatically enabled when corner radius > 0."),
            sub_item_table = {
                {
                    text      = _("Enable inline bars"),
                    help_text = _("When section gaps are enabled and corner radius > 0, inline bars are automatically enabled."),
                    checked_func = function()
                        return PluginStore:isTrue(SETTINGS.BAR_INLINE)
                            or (getSetting("SECTION_GAPS_ENABLED") and (getSetting("SECTION_RADIUS") or 0) > 0)
                    end,
                    callback = function()
                        if getSetting("SECTION_GAPS_ENABLED") and (getSetting("SECTION_RADIUS") or 0) > 0 then
                            UIManager:show(require("ui/widget/infomessage"):new {
                                text    = _("Inline bars are force-enabled because section gaps and corner radius are both set. Set corner radius to 0 or disable section gaps to toggle inline bars independently."),
                                timeout = 3,
                            })
                            return
                        end
                        PluginStore:saveSetting(SETTINGS.BAR_INLINE,
                            not PluginStore:isTrue(SETTINGS.BAR_INLINE))
                    end,
                },
                {
                    text           = _("Inline bar border size"),
                    help_text      = _("Thickness of the border around the inline progress bar."),
                    enabled_func = function()
                        return PluginStore:isTrue(SETTINGS.BAR_INLINE)
                            or (getSetting("SECTION_RADIUS") or 0) > 0
                    end,
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Inline bar border size (px)"),
                            getSetting("BAR_BORDER_SIZE") or USER_CONFIG.BAR_BORDER_SIZE,
                            0, 10, 1,
                            function(val) PluginStore:saveSetting(SETTINGS.BAR_BORDER_SIZE, val) end,
                            _("0 for no border. 1–2px adds a subtle outline around the bar."),
                            "%d", 2
                        )
                    end,
                },
                {
                    text      = _("Bar width"),
                    help_text = _("Width of the inline progress bar as a percentage of the available text column. Alignment follows the text alignment setting."),
                    enabled_func = function()
                        return PluginStore:isTrue(SETTINGS.BAR_INLINE)
                            or (getSetting("SECTION_RADIUS") or 0) > 0
                    end,
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Inline bar width (%)"),
                            getSetting("BAR_INLINE_WIDTH_PCT") or 100,
                            10, 100, 5,
                            function(val) PluginStore:saveSetting(SETTINGS.BAR_INLINE_WIDTH_PCT, val) end,
                            _("100% fills the text column. The bar is aligned to match your text alignment setting."),
                            "%d"
                        )
                    end,
                },
            },
        },
    }
end

local function buildFontFaceMenu(setting_key)
    local Font     = require("ui/font")
    local sub_menu = {}
    sub_menu[1] = {
        text = "System Default (cfont)",
        checked_func = function()
            return (PluginStore:readSetting(setting_key) or "cfont") == "cfont"
        end,
        callback = function() PluginStore:saveSetting(setting_key, "cfont") end,
        radio    = true,
    }

    local font_list  = {}
    local cre_engine = getCachedCreEngine()
    if cre_engine and cre_engine.getFontFaces then
        local faces = cre_engine.getFontFaces()
        for i, font_name in ipairs(faces) do
            local font_path = cre_engine.getFontFaceFilenameAndFaceIndex(font_name)
            if font_path then table.insert(font_list, { name = font_name, path = font_path }) end
        end
        table.sort(font_list, function(a, b) return a.name < b.name end)
    end

    for i, font_data in ipairs(font_list) do
        sub_menu[#sub_menu + 1] = {
            text = font_data.name,
            font_func = function(size)
                local success, face = pcall(Font.getFace, Font, font_data.path, size)
                if success and face then
                    return face
                else
                    logger.warn("[Customisable Sleep Screen] Font preview failed for " .. font_data.path .. ", using cfont")
                    return Font:getFace("cfont", size)
                end
            end,
            checked_func = function()
                return (PluginStore:readSetting(setting_key) or "cfont") == font_data.name
            end,
            callback = function() PluginStore:saveSetting(setting_key, font_data.name) end,
            radio    = true,
        }
    end
    return sub_menu
end

local function buildFontsAndTextMenu()
    return {
        createResetMenuItem("fonts & text", {
            SETTINGS.FONT_FACE_TITLE,   SETTINGS.FONT_SIZE_TITLE,
            SETTINGS.FONT_FACE_SUBTITLE, SETTINGS.FONT_SIZE_SUBTITLE,
            SETTINGS.TEXT_ALIGN,        SETTINGS.BOOK_MULTILINE,
            SETTINGS.CHAP_MULTILINE,    SETTINGS.CLEAN_CHAP,
            SETTINGS.ALL_TITLES_BOLD,
        }),
        { text = _("Title font face"),    help_text = _("Choose the font face for the main heading text in each section"),       sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_TITLE)    },
        {
            text           = _("Title font size"),
            help_text      = _("Choose the font size for the main heading text in each section."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Title font size"),
                    getSetting("FONT_SIZE_TITLE") or USER_CONFIG.FONT_SIZE_TITLE,
                    5, 30, 1,
                    function(val) PluginStore:saveSetting(SETTINGS.FONT_SIZE_TITLE, val) end,
                    _("10–12px works well for most screens."), "%d", 5
                )
            end,
        },
        { text = _("Subtitle font face"), help_text = _("Choose the font face for the information below the main heading text."), sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_SUBTITLE) },
        {
            text           = _("Subtitle font size"),
            help_text      = _("Choose the font size for the information below the main heading text."),
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Subtitle font size"),
                    getSetting("FONT_SIZE_SUBTITLE") or USER_CONFIG.FONT_SIZE_SUBTITLE,
                    5, 25, 1,
                    function(val) PluginStore:saveSetting(SETTINGS.FONT_SIZE_SUBTITLE, val) end,
                    _("9–11px works well for most screens."), "%d", 5
                )
            end,
        },
        {
            text      = _("Text alignment"),
            help_text = _("Horizontal alignment of all text within sections."),
            sub_item_table = {
                createRadioItem(_("Left"),   nil, SETTINGS.TEXT_ALIGN, "left"),
                createRadioItem(_("Centre"), nil, SETTINGS.TEXT_ALIGN, "center"),
                createRadioItem(_("Right"),  nil, SETTINGS.TEXT_ALIGN, "right"),
            },
        },
        createToggleItem(_("Book multiline titles"),    _("If deselected book titles will be truncated to a single line with an ellipsis"),    SETTINGS.BOOK_MULTILINE, USER_CONFIG.BOOK_MULTILINE),
        createToggleItem(_("Chapter multiline titles"), _("If deselected chapter titles will be truncated to a single line with an ellipsis"), SETTINGS.CHAP_MULTILINE, USER_CONFIG.CHAP_MULTILINE),
        createToggleItem(_("Clean chapter titles"),
            _("Removes structural prefixes like 'Chapter 5:' or 'Part II' from chapter titles " ..
            "and normalises capitalisation. Only works correctly with English chapter titles " ..
            "- disable for non-English books."),
            SETTINGS.CLEAN_CHAP, USER_CONFIG.CLEAN_CHAP),
        createFlipNilOrFalseItem(_("Make titles bold"),
            _("Display the section titles in bold font weight for extra emphasis."),
            SETTINGS.ALL_TITLES_BOLD),
    }
end

local function buildBackgroundTypeMenu()
    local options = {
        { text = _("No background"),            val = "transparent" },
        { text = _("Book cover"),               val = "cover"       },
        { text = _("Solid colour"),             val = "solid"       },
        { text = _("Random image from folder"), val = "folder"      },
    }
    local sub_menu = buildNumericMenu("BG_TYPE", options)

    sub_menu[#sub_menu + 1] = {
        text      = _("Stretch book cover to fill"),
        help_text = _("When disabled, book cover will be scaled to fit within the screen while preserving aspect ratio."),
        enabled_func = function()
            local bg_type = getSetting("BG_TYPE")
            return bg_type == "cover" or bg_type == "folder" or bg_type == nil
        end,
        checked_func = function()
            local stretch = getSetting("BG_STRETCH")
            return stretch == nil and USER_CONFIG.BG_STRETCH or stretch
        end,
        callback = function()
            local current = getSetting("BG_STRETCH")
            if current == nil then current = USER_CONFIG.BG_STRETCH end
            PluginStore:saveSetting(SETTINGS.BG_STRETCH, not current)
        end,
    }

    sub_menu[#sub_menu + 1] = {
        text      = _("Cover fill colour"),
        help_text = _("Background colour for non-stretched covers."),
        enabled_func = function()
            local bg_type = getSetting("BG_TYPE")
            local stretch = getSetting("BG_STRETCH")
            return (bg_type == "cover" or bg_type == "folder" or bg_type == nil) and not stretch
        end,
        keep_menu_open = true,
        callback = function()
            local current_color = getSetting("BG_COVER_FILL_COLOR")
            if current_color == "black" then current_color = "#000000"
            elseif current_color == "white" then current_color = "#ffffff"
            end
            local h, s, v = hexToHSV(current_color)
            local wheel = getColourWheelWidget():new({
                title_text = _("Pick cover fill colour"),
                hue = h, saturation = s, value = v,
                callback = function(hex)
                    PluginStore:saveSetting(SETTINGS.BG_COVER_FILL_COLOR, hex)
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function() UIManager:setDirty(nil, "ui") end,
            })
            UIManager:show(wheel)
        end,
    }

    sub_menu[#sub_menu + 1] = {
        text      = _("Cover alignment"),
        help_text = _("Horizontal alignment of the cover image when not stretched."),
        enabled_func = function()
            local bg_type = getSetting("BG_TYPE")
            local stretch = getSetting("BG_STRETCH")
            return (bg_type == "cover" or bg_type == "folder" or bg_type == nil) and not stretch
        end,
        sub_item_table = {
            createRadioItem(_("Left"),   nil, SETTINGS.BG_COVER_ALIGN, "left"),
            createRadioItem(_("Centre"), nil, SETTINGS.BG_COVER_ALIGN, "center"),
            createRadioItem(_("Right"),  nil, SETTINGS.BG_COVER_ALIGN, "right"),
        },
    }

    sub_menu[#sub_menu + 1] = {
        text           = _("Solid background colour"),
        enabled_func   = function() return getSetting("BG_TYPE") == "solid" end,
        keep_menu_open = true,
        callback = function()
            local current_color = getSetting("BG_SOLID_COLOR")
            local h, s, v = hexToHSV(current_color)
            local wheel = getColourWheelWidget():new({
                title_text = _("Pick background colour"),
                hue = h, saturation = s, value = v,
                callback = function(hex)
                    PluginStore:saveSetting(SETTINGS.BG_SOLID_COLOR, hex)
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function() UIManager:setDirty(nil, "ui") end,
            })
            UIManager:show(wheel)
        end,
    }

    sub_menu[#sub_menu + 1] = {
        text           = _("Background folder path"),
        enabled_func   = function() return getSetting("BG_TYPE") == "folder" end,
        keep_menu_open = true,
        callback = function()
            local lfs         = require("libs/libkoreader-lfs")
            local PathChooser = require("ui/widget/pathchooser")
            local FileChooser = require("ui/widget/filechooser")
            local Menu_orig   = require("ui/widget/menu")

            local was_hidden             = FileChooser.show_hidden
            local was_lock_home          = G_reader_settings:readSetting("lock_home_folder")
            local was_updateItems        = FileChooser.updateItems
            local was_recalculateDimen   = FileChooser._recalculateDimen
            local was_updateItemsBuildUI = FileChooser._updateItemsBuildUI
            local was_onCloseWidget      = FileChooser.onCloseWidget

            FileChooser.show_hidden         = true
            FileChooser.updateItems         = Menu_orig.updateItems
            FileChooser._recalculateDimen   = Menu_orig._recalculateDimen
            FileChooser._updateItemsBuildUI = Menu_orig._updateItemsBuildUI
            FileChooser.onCloseWidget       = Menu_orig.onCloseWidget
            G_reader_settings:saveSetting("lock_home_folder", false)

            local function restoreFileChooser()
                FileChooser.show_hidden         = was_hidden
                FileChooser.updateItems         = was_updateItems
                FileChooser._recalculateDimen   = was_recalculateDimen
                FileChooser._updateItemsBuildUI = was_updateItemsBuildUI
                FileChooser.onCloseWidget       = was_onCloseWidget
                G_reader_settings:saveSetting("lock_home_folder", was_lock_home)
            end

            UIManager:show(PathChooser:new {
                select_directory = true,
                select_file      = false,
                show_files       = false,
                path             = getSetting("BG_FOLDER") or "/",
                onConfirm = function(dir_path)
                    restoreFileChooser()
                    PluginStore:saveSetting(SETTINGS.BG_FOLDER, dir_path)
                    local valid_extensions = { "%.png$", "%.jpg$", "%.jpeg$" }
                    local has_images = false
                    pcall(function()
                        local scan_path = dir_path:gsub("/$", "")
                        for entry in lfs.dir(scan_path) do
                            local lower = entry:lower()
                            for _, ext in ipairs(valid_extensions) do
                                if lower:match(ext) then
                                    has_images = true
                                    break
                                end
                            end
                            if has_images then break end
                        end
                    end)
                    if not has_images then
                        UIManager:show(require("ui/widget/infomessage"):new {
                            text    = _("No images found in the selected folder. No background will be shown."),
                            timeout = 3,
                        })
                    end
                end,
                onCancel = function()
                    restoreFileChooser()
                end,
            })
        end,
    }

    return sub_menu
end

local function buildBackgroundMenu()
    return {
        createResetMenuItem("background", {
            SETTINGS.BG_DIMMING, SETTINGS.BG_DIMMING_COLOR,
            SETTINGS.BG_TYPE,    SETTINGS.BG_FOLDER,
            SETTINGS.BG_STRETCH, SETTINGS.BG_COVER_FILL_COLOR,
            SETTINGS.BG_SOLID_COLOR, SETTINGS.BG_COVER_ALIGN,
        }),
        { text = _("Background type"),    sub_item_table = buildBackgroundTypeMenu(), help_text = _("Choose what appears behind the information box.") },
        {
            text      = _("Background overlay"),
            help_text = _("Add a colour layer over the background to reduce contrast."),
            sub_item_table = (function()
                local sub = {
                    {
                        text           = _("Overlay colour"),
                        keep_menu_open = true,
                        callback = function()
                            local current_color = getSetting("BG_DIMMING_COLOR")
                            local h, s, v = hexToHSV(current_color)
                            local wheel = getColourWheelWidget():new({
                                title_text = _("Background overlay colour"),
                                hue = h, saturation = s, value = v,
                                callback = function(hex)
                                    PluginStore:saveSetting(SETTINGS.BG_DIMMING_COLOR, hex)
                                    UIManager:setDirty(nil, "ui")
                                end,
                                cancel_callback = function() UIManager:setDirty(nil, "ui") end,
                            })
                            UIManager:show(wheel)
                        end,
                    },
                    {
                        text           = _("Overlay opacity"),
                        keep_menu_open = true,
                        callback = function()
                            local current_alpha = getSetting("BG_DIMMING") or USER_CONFIG.BG_DIMMING
                            createSpinDialog(
                                _("Overlay opacity (%)"),
                                math.floor((current_alpha / 255) * 100),
                                0, 100, 5,
                                function(val)
                                    local alpha = math.floor((val / 100) * 255)
                                    PluginStore:saveSetting(SETTINGS.BG_DIMMING, alpha)
                                end,
                                _("0% is no overlay. 20–40% adds a soft tint. 100% is fully opaque."),
                                "%d", 10
                            )
                        end,
                    },
                }
                return sub
            end)(),
        },
    }
end

return {
    buildDisplayModesMenu     = buildDisplayModesMenu,
    buildLayoutAndSpacingMenu = buildLayoutAndSpacingMenu,
    buildColorsIconsBarsMenu  = buildColorsIconsBarsMenu,
    buildFontsAndTextMenu     = buildFontsAndTextMenu,
    buildBackgroundMenu       = buildBackgroundMenu,
}
