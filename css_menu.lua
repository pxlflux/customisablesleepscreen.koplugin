-- Assembles the top-level settings menu and its submenus.

local UIManager = require("ui/uimanager")

local _               = require("plugin_gettext")
local config          = require("config")
local SETTINGS        = config.SETTINGS
local USER_CONFIG     = config.USER_CONFIG

local meta            = package.loaded["customisablesleepscreen/_meta"] or require("_meta")
local PATCH_VERSION   = meta.version
local PATCH_NAME      = meta.fullname
local GITHUB_REPO     = meta.github

local presets_data_mod       = require("presets")
local initializePresetSystem = presets_data_mod.getPresetObj
local PRELOADED_PRESETS      = presets_data_mod.PRELOADED_PRESETS

local h                = require("menu_helpers")
local getSetting       = h.getSetting
local createRadioItem  = h.createRadioItem
local createSpinDialog = h.createSpinDialog

local presets_mod               = require("menu_presets")
local buildPresetManagementMenu = presets_mod.buildPresetManagementMenu

local sections_mod      = require("menu_sections")
local buildContentsMenu = sections_mod.buildContentsMenu

local appearance_mod            = require("menu_appearance")
local buildDisplayModesMenu     = appearance_mod.buildDisplayModesMenu
local buildLayoutAndSpacingMenu = appearance_mod.buildLayoutAndSpacingMenu
local buildColorsIconsBarsMenu  = appearance_mod.buildColorsIconsBarsMenu
local buildFontsAndTextMenu     = appearance_mod.buildFontsAndTextMenu
local buildBackgroundMenu       = appearance_mod.buildBackgroundMenu

local function buildAdvancedMenu()
    return {
        {
            text      = _("Delete all custom presets"),
            help_text = _("Permanently removes all custom presets you've created. The built-in 'Default' preset will remain. This cannot be undone."),
            separator = true,
            keep_menu_open = true,
            callback = function()
                local ConfirmBox  = require("ui/widget/confirmbox")
                local InfoMessage = require("ui/widget/infomessage")
                local box = ConfirmBox:new {
                    text        = _("Are you sure you want to delete all custom presets? (built-in presets will remain)"),
                    ok_text     = _("Delete"),
                    cancel_text = _("Cancel"),
                    ok_callback = function()
                        local preset_obj       = initializePresetSystem()
                        local filtered_presets = {}
                        for preset_name, preset_data in pairs(PRELOADED_PRESETS) do
                            filtered_presets[preset_name] = preset_data
                        end
                        G_reader_settings:saveSetting(SETTINGS.PRESETS, filtered_presets)
                        if preset_obj then preset_obj.presets = filtered_presets end
                        local last = G_reader_settings:readSetting(SETTINGS.LAST_LOADED_PRESET)
                        if last and not filtered_presets[last] then
                            if preset_obj then
                                preset_obj.loadPreset(filtered_presets["Default"], "Default")
                            end
                        end
                        UIManager:show(InfoMessage:new {
                            text    = _("All custom presets deleted. Built-in presets remain."),
                            timeout = 2,
                        })
                    end,
                }
                UIManager:show(box)
            end,
        },
        {
            text      = _("Sleep screen orientation"),
            help_text = _("Force the sleep screen to display in a specific orientation, regardless of how the device is held."),
            sub_item_table = {
                createRadioItem(
                    _("Auto (follow device)"),
                    _("Use whatever orientation the device is currently in."),
                    SETTINGS.SLEEP_ORIENTATION, "auto"
                ),
                createRadioItem(
                    _("Force portrait"),
                    _("Always display the sleep screen in portrait mode."),
                    SETTINGS.SLEEP_ORIENTATION, "portrait"
                ),
                createRadioItem(
                    _("Force landscape"),
                    _("Always display the sleep screen in landscape mode."),
                    SETTINGS.SLEEP_ORIENTATION, "landscape"
                ),
                createRadioItem(
                    _("Force upside-down portrait"),
                    _("Always display the sleep screen in inverted portrait mode."),
                    SETTINGS.SLEEP_ORIENTATION, "uportrait"
                ),
                createRadioItem(
                    _("Force upside-down landscape"),
                    _("Always display the sleep screen in inverted landscape mode."),
                    SETTINGS.SLEEP_ORIENTATION, "ulandscape"
                ),
            },
        },
        {
            text      = _("Battery time calculation"),
            help_text = _("Method used to estimate remaining battery life."),
            sub_item_table = {
                createRadioItem(
                    _("Since last charge"),
                    _("Uses combined awake and sleeping battery drain since last charge"),
                    SETTINGS.BATT_STAT_TYPE, "discharging"
                ),
                createRadioItem(
                    _("Awake since last charge"),
                    _("Uses only active reading battery drain (more conservative estimate)"),
                    SETTINGS.BATT_STAT_TYPE, "awake"
                ),
                createRadioItem(
                    _("Sleeping since last charge"),
                    _("Uses only sleep mode battery drain"),
                    SETTINGS.BATT_STAT_TYPE, "sleeping"
                ),
                createRadioItem(
                    _("Manual calculation"),
                    _("Use a custom battery drain rate (1-10% per hour)"),
                    SETTINGS.BATT_STAT_TYPE, "manual"
                ),
                {
                    text = _("Set manual drain rate"),
                    enabled_func = function()
                        return (getSetting("BATT_STAT_TYPE") or USER_CONFIG.BATT_STAT_TYPE) == "manual"
                    end,
                    keep_menu_open = true,
                    callback = function()
                        createSpinDialog(
                            _("Battery drain rate (% per hour)"),
                            getSetting("BATT_MANUAL_RATE") or USER_CONFIG.BATT_MANUAL_RATE,
                            1, 10, 0.5,
                            function(val) G_reader_settings:saveSetting(SETTINGS.BATT_MANUAL_RATE, val) end,
                            _("Typical devices drain 1-5% per hour while reading"),
                            "%.1f"
                        )
                    end,
                    separator = true,
                },
            },
        },
        {
            text      = _("Daily statistics scope"),
            help_text = _("Controls whether today's reading time and page count applies to the current book only, or all books read today. Note: reading streak and weekly goal achievement always reflect all books regardless of this setting."),
            sub_item_table = {
                createRadioItem(
                    _("All books"),
                    _("Today's reading time and page count across all books read today"),
                    SETTINGS.GOAL_STAT_SCOPE, "all"
                ),
                createRadioItem(
                    _("Current book only"),
                    _("Today's reading time and page count for the current book only"),
                    SETTINGS.GOAL_STAT_SCOPE, "book"
                ),
            },
        },
        {
            text      = _("Show in file manager (outside of book)"),
            help_text = _("When enabled, the customisable sleep screen will display in file manager using the last saved book data."),
            checked_func = function()
                local val = G_reader_settings:readSetting(SETTINGS.SHOW_IN_FILEMANAGER)
                return val == nil or val == true
            end,
            callback = function()
                G_reader_settings:flipNilOrTrue(SETTINGS.SHOW_IN_FILEMANAGER)
            end,
        },
        {
            text      = _("Hide built-in presets (except Default)"),
            help_text = _("Hide the built-in presets from the preset list, keeping only the Default preset and your custom presets visible."),
            checked_func = function()
                return G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS)
            end,
            callback = function()
                G_reader_settings:saveSetting(
                    SETTINGS.HIDE_PRELOADED_PRESETS,
                    not G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS)
                )
                UIManager:show(require("ui/widget/infomessage"):new {
                    text    = _("Setting saved. Preset list will update when you reopen this menu."),
                    timeout = 2,
                })
            end,
        },
    }
end

local function getCustomisableSleepScreenSettingsMenu(hide_presets)
    local menu_table = {}

    if not hide_presets then
        menu_table[#menu_table + 1] = {
            text      = _("Presets"),
            help_text = _("Save, load, and manage presets."),
            sub_item_table_func = function()
                return buildPresetManagementMenu()
            end,
            separator = true,
        }
    end

    menu_table[#menu_table + 1] = { text = _("Display modes"),         help_text = _("Global appearance settings."),                                           sub_item_table = buildDisplayModesMenu()     }
    menu_table[#menu_table + 1] = { text = _("Contents"),              help_text = _("Control which sections appear and what information they display."),      sub_item_table = buildContentsMenu()         }
    menu_table[#menu_table + 1] = { text = _("Layout & Spacing"),      help_text = _("Adjust the spatial settings of the information box."),                   sub_item_table = buildLayoutAndSpacingMenu() }
    menu_table[#menu_table + 1] = { text = _("Colours, Icons & Bars"), help_text = _("Customise section colours, icon appearance, and progress bar styling."), sub_item_table = buildColorsIconsBarsMenu()  }
    menu_table[#menu_table + 1] = { text = _("Fonts & Text"),          help_text = _("Configure text appearance."),                                            sub_item_table = buildFontsAndTextMenu()     }
    menu_table[#menu_table + 1] = { text = _("Background"),            help_text = _("Choose what appears behind the information box."),                       sub_item_table = buildBackgroundMenu()       }
    menu_table[#menu_table + 1] = { text = _("Advanced"),              help_text = _("Advanced configuration options."),                                       sub_item_table = buildAdvancedMenu()         }

    menu_table[#menu_table + 1] = {
        text           = _("About"),
        keep_menu_open = true,
        callback = function()
            UIManager:show(require("ui/widget/infomessage"):new {
                text = string.format(
                    _("%s\nVersion: %s\n\nFor updates and issues:\ngithub.com/%s"),
                    PATCH_NAME, PATCH_VERSION, GITHUB_REPO
                ),
                timeout = 5,
            })
        end,
    }

    return menu_table
end

return {
    getCustomisableSleepScreenSettingsMenu = getCustomisableSleepScreenSettingsMenu,
    buildPresetManagementMenu              = buildPresetManagementMenu,
}
