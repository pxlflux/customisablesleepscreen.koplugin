-- Built-in preset definitions and preset save/load logic.

local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS

local PRESET_EXCLUDED_KEYS = {
    TYPE                   = true,
    PRESETS                = true,
    SHOW_MSG_GLOBAL        = true,
    MSG_TEXT               = true,
    VERSION                = true,
    LAST_BOOK_STATE        = true,
    LAST_LOADED_PRESET     = true,
    CYCLE_INDEX            = true,
    SHOW_IN_FILEMANAGER    = true,
    HIDE_PRELOADED_PRESETS = true,
    DEBUG                  = true,
    BATT_STAT_TYPE         = true,
    BATT_MANUAL_RATE       = true,
}

local function buildPreset(overrides)
    local preset = {}

    for config_key, default_value in pairs(USER_CONFIG) do
        if not PRESET_EXCLUDED_KEYS[config_key] then
            local settings_key = SETTINGS[config_key]
            if settings_key then
                preset[settings_key] = default_value
            end
        end
    end

    for settings_key, value in pairs(overrides) do
        preset[settings_key] = value
    end

    return preset
end

local PRELOADED_PRESETS = {
    ["Default"] = buildPreset({}),

    ["Catppuccin"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.SHOW_BOOK_TIME_REMAINING] = false,
        [SETTINGS.SHOW_BATT_TIME]           = false,
        [SETTINGS.SHOW_GOAL_PAGES]          = false,
        [SETTINGS.MAX_HIGHLIGHT_LENGTH]     = 125,
        [SETTINGS.BOX_WIDTH_PCT]            = 55,
        [SETTINGS.POS]                      = "middle_right",
        [SETTINGS.OPACITY]                  = 229,
        [SETTINGS.BORDER_SIZE]              = 4,
        [SETTINGS.BORDER_SIZE_2]            = 8,
        [SETTINGS.SECTION_PADDING]          = 8,
        [SETTINGS.COLOR_BOOK_FILL]          = "#CBA6F7",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#EBA0AC",
        [SETTINGS.COLOR_GOAL_FILL]          = "#F2CDCD",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#F5C2E7",
        [SETTINGS.BATT_HIGH_COLOR]          = "#A6E3A1",
        [SETTINGS.BATT_MED_COLOR]           = "#FAB387",
        [SETTINGS.BATT_LOW_COLOR]           = "#F38BA8",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#74C7EC",
        [SETTINGS.COLOR_DARK]               = "#BAC2E8",
        [SETTINGS.COLOR_LIGHT]              = "#5C5F77",
        [SETTINGS.COLOR_BOX_BG]             = "#EFF1F5",
        [SETTINGS.COLOR_BOX_BG_DARK]        = "#1E1E2E",
        [SETTINGS.COLOR_TEXT]               = "#4C4F69",
        [SETTINGS.COLOR_TEXT_DARK]          = "#B4BEFE",
        [SETTINGS.ICON_SET]                 = "Fluent",
        [SETTINGS.ICON_SIZE]                = 48,
        [SETTINGS.BAR_HEIGHT]               = 8,
        [SETTINGS.FONT_FACE_TITLE]          = "Poppins",
        [SETTINGS.FONT_SIZE_TITLE]          = 9,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Poppins",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 8,
        [SETTINGS.TEXT_ALIGN]               = "right",
        [SETTINGS.BG_DIMMING]               = 0,
        [SETTINGS.BG_TYPE]                  = "folder",
        [SETTINGS.BG_FOLDER]                = "@plugin/wallpapers/catppuccin",
        [SETTINGS.MSG_SHOW_FULL_BAR]        = true,
        [SETTINGS.SHOW_HIGHLIGHT_LOCATION]  = true,
    }),

    ["Comic"] = buildPreset({
        [SETTINGS.SHOW_CHAP]                = false,
        [SETTINGS.SHOW_BOOK_AUTHOR]         = true,
        [SETTINGS.SHOW_BOOK_SERIES]         = true,
        [SETTINGS.SHOW_BOOK_PAGES]          = true,
        [SETTINGS.GOAL_TYPE]                = "time",
        [SETTINGS.DAILY_GOAL_MINUTES]       = 60,
        [SETTINGS.SHOW_GOAL_STREAK]         = true,
        [SETTINGS.GOAL_TITLE_TYPE]          = "time",
        [SETTINGS.SHOW_BATT_RATE]           = true,
        [SETTINGS.SHOW_BATT_DATE]           = true,
        [SETTINGS.MESSAGE_SOURCE]           = "custom_quotes",
        [SETTINGS.MSG_HEADER]               = "",
        [SETTINGS.SECTION_GAPS_ENABLED]     = true,
        [SETTINGS.SECTION_GAP_SIZE]         = 25,
        [SETTINGS.POS]                      = "middle_right",
        [SETTINGS.BOX_WIDTH_PCT]            = 45,
        [SETTINGS.OPACITY]                  = 255,
        [SETTINGS.BORDER_SIZE]              = 5,
        [SETTINGS.ICON_TEXT_GAP]            = 8,
        [SETTINGS.MARGIN]                   = 0,
        [SETTINGS.SLEEP_ORIENTATION]        = "landscape",
        [SETTINGS.COLOR_BOOK_FILL]          = "#4ECDC4",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#FF6B6B",
        [SETTINGS.COLOR_GOAL_FILL]          = "#FFE66D",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#C7CEEA",
        [SETTINGS.BATT_HIGH_COLOR]          = "#7FD99F",
        [SETTINGS.BATT_MED_COLOR]           = "#F38181",
        [SETTINGS.BATT_LOW_COLOR]           = "#FF6B6B",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#4ECDC4",
        [SETTINGS.ICON_SET]                 = "Comic",
        [SETTINGS.ICON_SIZE]                = 72,
        [SETTINGS.BAR_HEIGHT]               = 16,
        [SETTINGS.FONT_FACE_TITLE]          = "Bangers",
        [SETTINGS.FONT_SIZE_TITLE]          = 11,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Bangers",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 9,
        [SETTINGS.TEXT_ALIGN]               = "right",
        [SETTINGS.BG_DIMMING]               = 0,
        [SETTINGS.BG_STRETCH]               = false,
        [SETTINGS.BG_COVER_FILL_COLOR]      = "white",
        [SETTINGS.BG_COVER_ALIGN]           = "left",
    }),

    ["Kobo"] = buildPreset({
        [SETTINGS.SHOW_BOOK_AUTHOR]         = true,
        [SETTINGS.SHOW_BOOK_PAGES]          = true,
        [SETTINGS.SHOW_CHAP]                = false,
        [SETTINGS.SHOW_GOAL]                = false,
        [SETTINGS.SHOW_BATT]                = false,
        [SETTINGS.SECTION_ORDER]            = { "book", "chapter", "message", "goal", "battery" },
        [SETTINGS.SECTION_GAPS_ENABLED]     = true,
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.POS]                      = "bottom_left",
        [SETTINGS.BOX_WIDTH_PCT]            = 45,
        [SETTINGS.OPACITY]                  = 255,
        [SETTINGS.BORDER_SIZE]              = 1,
        [SETTINGS.BORDER_SIZE_2]            = 8,
        [SETTINGS.SECTION_PADDING]          = 8,
        [SETTINGS.ICON_TEXT_GAP]            = 8,
        [SETTINGS.MARGIN]                   = 150,
        [SETTINGS.MONOCHROME]               = true,
        [SETTINGS.BAR_HEIGHT]               = 16,
        [SETTINGS.SHOW_ICONS]               = false,
        [SETTINGS.SHOW_BARS]                = false,
        [SETTINGS.FONT_FACE_TITLE]          = "Literata",
        [SETTINGS.FONT_SIZE_TITLE]          = 9,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Literata",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 8,
        [SETTINGS.BOOK_TITLE_BOLD]          = true,
        [SETTINGS.CUSTOM_MESSAGE]           = "%d",
        [SETTINGS.BG_DIMMING]               = 0,
    }),

    ["Minimal"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.MONOCHROME]               = true,
        [SETTINGS.SHOW_CHAP]                = false,
        [SETTINGS.SHOW_CHAP_COUNT]          = true,
        [SETTINGS.SHOW_CHAP_PAGES]          = true,
        [SETTINGS.SHOW_GOAL]                = false,
        [SETTINGS.SHOW_GOAL_ACHIEVEMENT]    = true,
        [SETTINGS.SHOW_GOAL_STREAK]         = true,
        [SETTINGS.SHOW_BATT]                = false,
        [SETTINGS.SHOW_BATT_RATE]           = true,
        [SETTINGS.SHOW_BATT_TIME_SEPARATE]  = true,
        [SETTINGS.SECTION_ORDER]            = { "message", "book", "chapter", "goal", "battery" },
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.POS]                      = "top_center",
        [SETTINGS.BOX_WIDTH_PCT]            = 55,
        [SETTINGS.OPACITY]                  = 178,
        [SETTINGS.BORDER_SIZE]              = 1,
        [SETTINGS.BORDER_SIZE_2]            = 5,
        [SETTINGS.SECTION_PADDING]          = 8,
        [SETTINGS.MARGIN]                   = 175,
        [SETTINGS.TEXT_ALIGN]               = "center",
        [SETTINGS.COLOR_DARK]               = "#5B9BD5",
        [SETTINGS.ICON_USE_BAR_COLOR]       = false,
        [SETTINGS.ICON_SIZE]                = 96,
        [SETTINGS.SHOW_ICONS]               = false,
        [SETTINGS.FONT_FACE_TITLE]          = "Google Sans",
        [SETTINGS.FONT_SIZE_TITLE]          = 20,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Google Sans",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 13,
        [SETTINGS.MESSAGE_SOURCE]           = "custom",
        [SETTINGS.MSG_HEADER]               = "%t",
        [SETTINGS.CUSTOM_MESSAGE]           = "%d",
    }),

    ["Night"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.SHOW_GOAL]                = false,
        [SETTINGS.SECTION_GAPS_ENABLED]     = true,
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.POS]                      = "middle_right",
        [SETTINGS.BOX_WIDTH_PCT]            = 55,
        [SETTINGS.OPACITY]                  = 229,
        [SETTINGS.BORDER_SIZE_2]            = 1,
        [SETTINGS.MARGIN]                   = 125,
        [SETTINGS.COLOR_BOOK_FILL]          = "#667BC6",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#DA7297",
        [SETTINGS.COLOR_GOAL_FILL]          = "#FFEAA7",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#9575CD",
        [SETTINGS.BATT_HIGH_COLOR]          = "#81C784",
        [SETTINGS.BATT_MED_COLOR]           = "#FFB74D",
        [SETTINGS.BATT_LOW_COLOR]           = "#E57373",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#64B5F6",
        [SETTINGS.ICON_SET]                 = "Silhouette",
        [SETTINGS.ICON_SIZE]                = 32,
        [SETTINGS.BAR_HEIGHT]               = 8,
        [SETTINGS.FONT_FACE_TITLE]          = "Atkinson Hyperlegible Next",
        [SETTINGS.FONT_SIZE_TITLE]          = 11,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Atkinson Hyperlegible Next",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 9,
        [SETTINGS.CUSTOM_MESSAGE]           = "%d",
    }),

    ["Nord"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.SHOW_HIGHLIGHT_LOCATION]  = true,
        [SETTINGS.MAX_HIGHLIGHT_LENGTH]     = 125,
        [SETTINGS.SECTION_GAPS_ENABLED]     = true,
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.SECTION_PADDING]          = 8,
        [SETTINGS.POS]                      = "middle_left",
        [SETTINGS.BOX_WIDTH_PCT]            = 50,
        [SETTINGS.TEXT_ALIGN]               = "right",
        [SETTINGS.COLOR_BOOK_FILL]          = "#8FBCBB",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#5E81AC",
        [SETTINGS.COLOR_GOAL_FILL]          = "#B48EAD",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#D8DEE9",
        [SETTINGS.BATT_HIGH_COLOR]          = "#A3BE8C",
        [SETTINGS.BATT_MED_COLOR]           = "#D08770",
        [SETTINGS.BATT_LOW_COLOR]           = "#BF616A",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#88C0D0",
        [SETTINGS.COLOR_DARK]               = "#D8DEE9",
        [SETTINGS.COLOR_LIGHT]              = "#4C566A",
        [SETTINGS.COLOR_BOX_BG]             = "#ECEFF4",
        [SETTINGS.COLOR_BOX_BG_DARK]        = "#2E3440",
        [SETTINGS.COLOR_TEXT]               = "#2E3440",
        [SETTINGS.COLOR_TEXT_DARK]          = "#ECEFF4",
        [SETTINGS.ICON_SET]                 = "Circle",
        [SETTINGS.ICON_SIZE]                = 56,
        [SETTINGS.ICON_TEXT_GAP]            = 8,
        [SETTINGS.FONT_FACE_TITLE]          = "Jost",
        [SETTINGS.FONT_SIZE_TITLE]          = 9,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Jost",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 8,
        [SETTINGS.BG_DIMMING]               = 0,
        [SETTINGS.BG_TYPE]                  = "folder",
        [SETTINGS.BG_FOLDER]                = "@plugin/wallpapers/nord",
    }),

    ["Pixel"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.SHOW_BOOK_PAGES]          = true,
        [SETTINGS.SHOW_BOOK_TIME_REMAINING] = false,
        [SETTINGS.SHOW_CHAP_COUNT]          = true,
        [SETTINGS.SHOW_CHAP_PAGES]          = true,
        [SETTINGS.SHOW_CHAP_TIME_REMAINING] = false,
        [SETTINGS.SHOW_GOAL_ACHIEVEMENT]    = true,
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.BOX_WIDTH_PCT]            = 65,
        [SETTINGS.OPACITY]                  = 229,
        [SETTINGS.BORDER_SIZE]              = 3,
        [SETTINGS.BORDER_SIZE_2]            = 1,
        [SETTINGS.MARGIN]                   = 25,
        [SETTINGS.TEXT_ALIGN]               = "right",
        [SETTINGS.COLOR_BOOK_FILL]          = "#5B9BD5",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#ED7D3A",
        [SETTINGS.COLOR_GOAL_FILL]          = "#FFC000",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#7030A0",
        [SETTINGS.BATT_HIGH_COLOR]          = "#70AD47",
        [SETTINGS.BATT_MED_COLOR]           = "#FFC000",
        [SETTINGS.BATT_LOW_COLOR]           = "#C00000",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#00B0F0",
        [SETTINGS.ICON_SET]                 = "Pixel",
        [SETTINGS.FONT_FACE_TITLE]          = "Pixelify Sans",
        [SETTINGS.FONT_SIZE_TITLE]          = 10,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Pixelify Sans",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 9,
        [SETTINGS.MESSAGE_SOURCE]           = "custom",
        [SETTINGS.MSG_HEADER]               = "GAME SAVED",
        [SETTINGS.CUSTOM_MESSAGE]           = "Press START to continue your reading adventure!",
        [SETTINGS.BG_DIMMING]               = 0,
        [SETTINGS.BG_TYPE]                  = "solid",
        [SETTINGS.BG_SOLID_COLOR]           = "#0F0F1B",
    }),

    ["Sketch"] = buildPreset({
        [SETTINGS.SHOW_BOOK_PAGES]          = true,
        [SETTINGS.SHOW_BOOK_TIME_REMAINING] = false,
        [SETTINGS.SHOW_CHAP_PAGES]          = true,
        [SETTINGS.SHOW_CHAP_TIME_REMAINING] = false,
        [SETTINGS.SHOW_GOAL]                = false,
        [SETTINGS.SHOW_MSG]                 = false,
        [SETTINGS.SECTION_ORDER]            = { "book", "chapter", "message", "goal", "battery" },
        [SETTINGS.SECTION_GAP_SIZE]         = 25,
        [SETTINGS.OPACITY]                  = 255,
        [SETTINGS.BORDER_SIZE]              = 3,
        [SETTINGS.SECTION_PADDING]          = 24,
        [SETTINGS.ICON_TEXT_GAP]            = 32,
        [SETTINGS.COLOR_BOOK_FILL]          = "#B4A7D6",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#FFD4B2",
        [SETTINGS.COLOR_GOAL_FILL]          = "#FFF4A3",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#E8D4F0",
        [SETTINGS.BATT_HIGH_COLOR]          = "#B8E6B8",
        [SETTINGS.BATT_MED_COLOR]           = "#FFE8B8",
        [SETTINGS.BATT_LOW_COLOR]           = "#FFB3BA",
        [SETTINGS.BATT_CHARGING_COLOR]      = "#A7D8DE",
        [SETTINGS.ICON_SET]                 = "Doodle",
        [SETTINGS.ICON_SIZE]                = 56,
        [SETTINGS.BAR_HEIGHT]               = 16,
        [SETTINGS.BOOK_TITLE_BOLD]          = true,
        [SETTINGS.FONT_FACE_TITLE]          = "Caveat",
        [SETTINGS.FONT_SIZE_TITLE]          = 13,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "Caveat",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 11,
        [SETTINGS.MESSAGE_SOURCE]           = "custom",
        [SETTINGS.MSG_HEADER]               = "Today's Note",
        [SETTINGS.BG_DIMMING]               = 26,
        [SETTINGS.BG_DIMMING_COLOR]         = "#FFF8DC",
    }),

    ["Terminal"] = buildPreset({
        [SETTINGS.DARK_MODE]                = true,
        [SETTINGS.MONOCHROME]               = true,
        [SETTINGS.SHOW_BOOK_AUTHOR]         = true,
        [SETTINGS.SHOW_BOOK_PAGES]          = true,
        [SETTINGS.SHOW_CHAP_PAGES]          = true,
        [SETTINGS.SHOW_GOAL_STREAK]         = true,
        [SETTINGS.BOOK_MULTILINE]           = false,
        [SETTINGS.CHAP_MULTILINE]           = false,
        [SETTINGS.SECTION_GAP_SIZE]         = 20,
        [SETTINGS.POS]                      = "top_center",
        [SETTINGS.BOX_WIDTH_PCT]            = 50,
        [SETTINGS.OPACITY]                  = 229,
        [SETTINGS.SECTION_PADDING]          = 8,
        [SETTINGS.MARGIN]                   = 25,
        [SETTINGS.COLOR_BOOK_FILL]          = "#8FAADC",
        [SETTINGS.COLOR_CHAPTER_FILL]       = "#CDB4DB",
        [SETTINGS.COLOR_GOAL_FILL]          = "#F4D35E",
        [SETTINGS.COLOR_MESSAGE_FILL]       = "#9CADCE",
        [SETTINGS.COLOR_DARK]               = "#61cf5a",
        [SETTINGS.ICON_SET]                 = "Silhouette",
        [SETTINGS.ICON_SIZE]                = 24,
        [SETTINGS.BAR_HEIGHT]               = 4,
        [SETTINGS.SHOW_ICONS]               = false,
        [SETTINGS.FONT_FACE_TITLE]          = "JetBrains Mono",
        [SETTINGS.FONT_SIZE_TITLE]          = 9,
        [SETTINGS.FONT_FACE_SUBTITLE]       = "JetBrains Mono",
        [SETTINGS.FONT_SIZE_SUBTITLE]       = 8,
        [SETTINGS.SHOW_MSG]                 = false,
        [SETTINGS.CUSTOM_MESSAGE]           = "%d",
        [SETTINGS.BG_DIMMING]               = 204,
    }),
}

local function getAllSettingKeys()
    local keys = {}
    for key_name, setting_key in pairs(SETTINGS) do
        if not PRESET_EXCLUDED_KEYS[key_name] then
            keys[#keys + 1] = setting_key
        end
    end
    return keys
end

local function getDefaultSettings()
    local defaults = {}
    for key_name, setting_key in pairs(SETTINGS) do
        if not PRESET_EXCLUDED_KEYS[key_name] then
            defaults[setting_key] = USER_CONFIG[key_name]
        end
    end
    return defaults
end

local function captureCurrentSettings()
    local snapshot = {}
    local defaults = getDefaultSettings()

    for i, setting_key in ipairs(getAllSettingKeys()) do
        local value = G_reader_settings:readSetting(setting_key)

        if value ~= nil then
            snapshot[setting_key] = value
        elseif defaults[setting_key] ~= nil then
            snapshot[setting_key] = defaults[setting_key]
        end
    end
    return snapshot
end

local preset_obj = nil

local function migratePreloadedPresets()
    local presets        = G_reader_settings:readSetting(SETTINGS.PRESETS, {})
    local hide_preloaded = G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS)

    for name, preset_data in pairs(PRELOADED_PRESETS) do
        if name ~= "Default" then
            if not hide_preloaded then
                presets[name] = preset_data
            end
        end
    end

    G_reader_settings:saveSetting(SETTINGS.PRESETS, presets)
    G_reader_settings:saveSetting("customisable_ss_presets_migrated", true)
end

local function initializePresetSystem()
    if preset_obj then return preset_obj end

    preset_obj = {
        presets         = G_reader_settings:readSetting(SETTINGS.PRESETS, {}),
        cycle_index     = G_reader_settings:readSetting(SETTINGS.CYCLE_INDEX, 0),
        dispatcher_name = "load_customisable_ss_preset",

        saveCycleIndex = function(this)
            G_reader_settings:saveSetting(SETTINGS.CYCLE_INDEX, this.cycle_index)
        end,

        buildPreset = function()
            return captureCurrentSettings()
        end,

        loadPreset = function(preset, preset_name)
            for _, setting_key in ipairs(getAllSettingKeys()) do
                G_reader_settings:delSetting(setting_key)
            end
            for setting_key, value in pairs(preset) do
                G_reader_settings:saveSetting(setting_key, value)
            end
            if preset_name then
                G_reader_settings:saveSetting(SETTINGS.LAST_LOADED_PRESET, preset_name)
            end
        end,
    }

    local dirty = false
    if not preset_obj.presets["Default"] then
        preset_obj.presets["Default"] = getDefaultSettings()
        dirty = true
    end
    if not G_reader_settings:readSetting(SETTINGS.LAST_LOADED_PRESET) then
        G_reader_settings:saveSetting(SETTINGS.LAST_LOADED_PRESET, "Default")
    end

    migratePreloadedPresets()

    if dirty then
        G_reader_settings:saveSetting(SETTINGS.PRESETS, preset_obj.presets)
    end

    return preset_obj
end

return {
    PRELOADED_PRESETS       = PRELOADED_PRESETS,
    getAllSettingKeys        = getAllSettingKeys,
    getDefaultSettings      = getDefaultSettings,
    captureCurrentSettings  = captureCurrentSettings,
    getPresetObj            = initializePresetSystem,
    migratePreloadedPresets = migratePreloadedPresets,
}
