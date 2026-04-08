-- Menu items for display modes, layout, colours, fonts, and background.

local logger    = require("logger")
local UIManager = require("ui/uimanager")

local _           = require("plugin_gettext")
local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS

local h                        = require("menu_helpers")
local getSetting               = h.getSetting
local createToggleItem         = h.createToggleItem
local createFlipNilOrFalseItem = h.createFlipNilOrFalseItem
local createRadioItem          = h.createRadioItem
local createColorMenuItem      = h.createColorMenuItem
local createResetMenuItem      = h.createResetMenuItem
local createSpinDialog         = h.createSpinDialog
local createNumericRadioMenu   = h.createNumericRadioMenu
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

local NUMERIC_MENU_CONFIGS = {
    BAR_HEIGHT = {
        { text = _("Hairline"),  val = 4  },
        { text = _("Narrow"),    val = 8  },
        { text = _("Standard"),  val = 12 },
        { text = _("Bold"),      val = 16 },
        { text = _("Chunky"),    val = 20 },
        { text = _("Heavy"),     val = 24 },
    },
    BORDER_SIZE = {
        { text = _("No border"), val = 0 }, { text = _("Hairline"), val = 1 },
        { text = _("Clean"),     val = 2 }, { text = _("Defined"),  val = 3 },
        { text = _("Bold"),      val = 4 }, { text = _("Heavy"),    val = 5 },
        { text = _("Framed"),    val = 6 }, { text = _("Thick"),    val = 7 },
        { text = _("Chunky"),    val = 8 },
    },
    BORDER_SIZE_2 = {
        { text = _("No second border"), val = 0 }, { text = _("Hairline"), val = 1 },
        { text = _("Clean"),            val = 2 }, { text = _("Defined"),  val = 3 },
        { text = _("Bold"),             val = 4 }, { text = _("Heavy"),    val = 5 },
        { text = _("Framed"),           val = 6 }, { text = _("Thick"),    val = 7 },
        { text = _("Chunky"),           val = 8 },
    },
    ICON_TEXT_GAP = {
        { text = _("Touching"),    val = 0  }, { text = _("Tight"),      val = 8  },
        { text = _("Balanced"),    val = 16 }, { text = _("Relaxed"),    val = 24 },
        { text = _("Wide"),        val = 32 }, { text = _("Extra Wide"), val = 48 },
    },
    MARGIN = {
        { text = _("No margin"), val = 0   }, { text = _("XX-Small"), val = 25  },
        { text = _("X-Small"),   val = 50  }, { text = _("Small"),    val = 75  },
        { text = _("Medium"),    val = 100 }, { text = _("Large"),    val = 125 },
        { text = _("X-Large"),   val = 150 }, { text = _("XX-Large"), val = 175 },
    },
    SECTION_PADDING = {
        { text = _("Flush"),     val = 0  }, { text = _("Tight"),       val = 8  },
        { text = _("Standard"),  val = 12 }, { text = _("Balanced"),    val = 16 },
        { text = _("Spacious"),  val = 24 }, { text = _("Extra Large"), val = 32 },
    },
}

local function buildBarHeightMenu()   return buildNumericMenu("BAR_HEIGHT",      NUMERIC_MENU_CONFIGS.BAR_HEIGHT)      end
local function buildBorderSizeMenu()  return buildNumericMenu("BORDER_SIZE",     NUMERIC_MENU_CONFIGS.BORDER_SIZE)     end
local function buildBorderSize2Menu() return buildNumericMenu("BORDER_SIZE_2",   NUMERIC_MENU_CONFIGS.BORDER_SIZE_2)   end
local function buildIconTextGapMenu() return buildNumericMenu("ICON_TEXT_GAP",   NUMERIC_MENU_CONFIGS.ICON_TEXT_GAP)   end
local function buildMarginMenu()      return buildNumericMenu("MARGIN",          NUMERIC_MENU_CONFIGS.MARGIN)          end
local function buildPaddingMenu()     return buildNumericMenu("SECTION_PADDING", NUMERIC_MENU_CONFIGS.SECTION_PADDING) end

local function buildOpacityMenu()
    local levels = {}
    for pct = 50, 90, 10 do
        levels[#levels + 1] = { text = pct .. "%", val = math.floor(pct * 255 / 100) }
    end
    levels[#levels + 1] = { text = _("Opaque"), val = 255 }
    return buildNumericMenu("OPACITY", levels)
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
            SETTINGS.SECTION_PADDING, SETTINGS.ICON_TEXT_GAP, 
            SETTINGS.MARGIN, SETTINGS.SLEEP_ORIENTATION,
        }),
        {
            text = _("Section gaps"),
            help_text = _("Add transparent gaps between sections to make each appear as a separate box"),
            sub_item_table = {
                {
                    text      = _("Enable section gaps"),
                    checked_func = function() return getSetting("SECTION_GAPS_ENABLED") end,
                    callback = function()
                        G_reader_settings:saveSetting(SETTINGS.SECTION_GAPS_ENABLED,
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
                            function(val) G_reader_settings:saveSetting(SETTINGS.SECTION_GAP_SIZE, val) end
                        )
                    end,
                },
            }
        },
        { text = _("Position"),       sub_item_table = buildPositionMenu(),    help_text = _("Screen location where the information box appears.") },
        { text = _("Width"),          sub_item_table = createNumericRadioMenu(SETTINGS.BOX_WIDTH_PCT, 40, 100, 5, "%"),
          help_text = _("Horizontal width of the information box as a percentage of screen width.") },
        { text = _("Opacity"),        sub_item_table = buildOpacityMenu(),     help_text = _("Transparency of the information box.") },
        { text = _("Border size"),    sub_item_table = buildBorderSizeMenu(),  help_text = _("Thickness of the primary border around sections.") },
        {
            text      = _("Border trim size"),
            enabled_func = function() return getSetting("BORDER_SIZE") > 0 end,
            sub_item_table = buildBorderSize2Menu(),
            help_text = _("Secondary decorative border surrounding the primary border."),
        },
        { text = _("Internal padding"),  sub_item_table = buildPaddingMenu(),     help_text = _("Space between section borders and their content.") },
        { text = _("Icon to text gap"),  sub_item_table = buildIconTextGapMenu(), help_text = _("Horizontal spacing between section icons and their accompanying text.") },
        { text = _("Y-axis margin (top/bottom left/right pos)"), sub_item_table = buildMarginMenu(),
          help_text = _("Vertical offset from the top or bottom edge when positioned at the top centre, bottom centre, top left, bottom left, top right or bottom right.") },
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

local function buildDimmingMenu()
    local options = {
        { text = _("Off"), val = 0   }, { text = "10%", val = 26  }, { text = "20%", val = 51  },
        { text = "30%",    val = 77  }, { text = "40%", val = 102 }, { text = "50%", val = 128 },
        { text = "60%",    val = 153 }, { text = "70%", val = 179 }, { text = "80%", val = 204 },
        { text = "90%",    val = 230 }, { text = "100%", val = 255 },
    }
    local sub_menu = buildNumericMenu("BG_DIMMING", options)
    table.insert(sub_menu, 1, {
        text           = _("Overlay colour"),
        keep_menu_open = true,
        separator      = true,
        callback = function()
            local current_color = getSetting("BG_DIMMING_COLOR")
            local h, s, v = hexToHSV(current_color)
            local wheel = getColourWheelWidget():new({
                title_text = _("Background overlay colour"),
                hue = h, saturation = s, value = v,
                callback = function(hex)
                    G_reader_settings:saveSetting(SETTINGS.BG_DIMMING_COLOR, hex)
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function() UIManager:setDirty(nil, "ui") end,
            })
            UIManager:show(wheel)
        end,
    })
    return sub_menu
end

local function buildColorsIconsBarsMenu()
    return {
        createResetMenuItem("colours, icons & bars", {
            SETTINGS.COLOR_BOOK_FILL,    SETTINGS.COLOR_CHAPTER_FILL,
            SETTINGS.COLOR_GOAL_FILL,    SETTINGS.BATT_HIGH_COLOR,
            SETTINGS.BATT_MED_COLOR,     SETTINGS.BATT_LOW_COLOR,
            SETTINGS.BATT_CHARGING_COLOR, SETTINGS.COLOR_MESSAGE_FILL,
            SETTINGS.COLOR_LIGHT,        SETTINGS.COLOR_DARK,
            SETTINGS.ICON_USE_BAR_COLOR, SETTINGS.ICON_SET,
            SETTINGS.ICON_SIZE,          SETTINGS.BAR_HEIGHT,
            SETTINGS.SHOW_ICONS,         SETTINGS.SHOW_BARS,
            SETTINGS.MSG_SHOW_FULL_BAR,  SETTINGS.COLOR_BOX_BG,
            SETTINGS.COLOR_BOX_BG_DARK,  SETTINGS.COLOR_TEXT,
            SETTINGS.COLOR_TEXT_DARK,
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
        { text = _("Icon size"),           help_text = _("Size of section icons."),
          subtext = (getSetting("ICON_SIZE") or 0) .. " px",
          sub_item_table = createNumericRadioMenu(SETTINGS.ICON_SIZE, 24, 96, 8, " px") },
        { text = _("Progress bar height"), help_text = _("Thickness of the horizontal progress bars shown in each section."),
          sub_item_table = buildBarHeightMenu() },
        {
            text      = _("Show icons"),
            help_text = _("Display decorative icons at the start of each section."),
            checked_func = function() return getSetting("SHOW_ICONS") ~= false end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.SHOW_ICONS, not (getSetting("SHOW_ICONS") ~= false))
            end,
        },
        {
            text      = _("Show progress bars"),
            help_text = _("Display horizontal progress bars showing completion percentage."),
            checked_func = function() return getSetting("SHOW_BARS") ~= false end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.SHOW_BARS, not (getSetting("SHOW_BARS") ~= false))
            end,
        },
        {
            text      = _("Show decorative bar on message section"),
            help_text = _("Displays a purely decorative progress bar under the message section, matching the message section colour and the progress bars in other sections."),
            enabled_func = function()
                return getSetting("SHOW_BARS") ~= false
            end,
            checked_func = function()
                local val = G_reader_settings:readSetting(SETTINGS.MSG_SHOW_FULL_BAR)
                return val == nil and false or val
            end,
            callback = function()
                local current = G_reader_settings:readSetting(SETTINGS.MSG_SHOW_FULL_BAR)
                if current == nil then current = false end
                G_reader_settings:saveSetting(SETTINGS.MSG_SHOW_FULL_BAR, not current)
            end,
        },
    }
end

local function buildFontFaceMenu(setting_key)
    local Font     = require("ui/font")
    local sub_menu = {}
    sub_menu[1] = {
        text = "System Default (cfont)",
        checked_func = function()
            return (G_reader_settings:readSetting(setting_key) or "cfont") == "cfont"
        end,
        callback = function() G_reader_settings:saveSetting(setting_key, "cfont") end,
        radio    = true,
    }

    local font_list  = {}
    local cre_mod    = getCre()
    local cre_engine
    if cre_mod then
        local ok, eng = pcall(function() return cre_mod:engineInit() end)
        cre_engine = ok and eng or nil
    end
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
                return (G_reader_settings:readSetting(setting_key) or "cfont") == font_data.name
            end,
            callback = function() G_reader_settings:saveSetting(setting_key, font_data.name) end,
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
            SETTINGS.BOOK_TITLE_BOLD,
        }),
        { text = _("Title font face"),    help_text = _("Choose the font face for the main heading text in each section"),       sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_TITLE)    },
        { text = _("Title font size"),    help_text = _("Choose the font size for the main heading text in each section"),       sub_item_table = createNumericRadioMenu(SETTINGS.FONT_SIZE_TITLE, 5, 20, 1) },
        { text = _("Subtitle font face"), help_text = _("Choose the font face for the information below the main heading text."), sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_SUBTITLE) },
        { text = _("Subtitle font size"), help_text = _("Choose the font size for the information below the main heading text."), sub_item_table = createNumericRadioMenu(SETTINGS.FONT_SIZE_SUBTITLE, 5, 20, 1) },
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
        createFlipNilOrFalseItem(_("Make book title bold"),
            _("Display the book title in bold font weight for extra emphasis."),
            SETTINGS.BOOK_TITLE_BOLD),
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
            G_reader_settings:saveSetting(SETTINGS.BG_STRETCH, not current)
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
                    G_reader_settings:saveSetting(SETTINGS.BG_COVER_FILL_COLOR, hex)
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
                    G_reader_settings:saveSetting(SETTINGS.BG_SOLID_COLOR, hex)
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
            local was_hidden  = FileChooser.show_hidden
            FileChooser.show_hidden = true
            UIManager:show(PathChooser:new {
                select_directory = true,
                path             = getSetting("BG_FOLDER"),
                onConfirm = function(dir_path)
                    FileChooser.show_hidden = was_hidden
                    G_reader_settings:saveSetting(SETTINGS.BG_FOLDER, dir_path)
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
        { text = _("Background overlay"), sub_item_table = buildDimmingMenu(),        help_text = _("Add a colour layer over the background to reduce contrast.") },
    }
end

return {
    buildDisplayModesMenu     = buildDisplayModesMenu,
    buildLayoutAndSpacingMenu = buildLayoutAndSpacingMenu,
    buildColorsIconsBarsMenu  = buildColorsIconsBarsMenu,
    buildFontsAndTextMenu     = buildFontsAndTextMenu,
    buildBackgroundMenu       = buildBackgroundMenu,
}
