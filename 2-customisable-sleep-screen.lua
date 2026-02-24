local PATCH_VERSION = "1.1.0"
local PATCH_NAME = "Customisable Sleep Screen"
local GITHUB_REPO = "pxlflux/koreader-patches"

local Font              = require("ui/font")
local Blitbuffer        = require("ffi/blitbuffer")
local ffi               = require("ffi")
local TextWidget        = require("ui/widget/textwidget")
local VerticalGroup     = require("ui/widget/verticalgroup")
local Device            = require("device")
local SQ3               = require("lua-ljsqlite3/init")
local DataStorage       = require("datastorage")
local _                 = require("gettext")
local RenderImage       = require("ui/renderimage")
local ImageWidget       = require("ui/widget/imagewidget")
local IconWidget        = require("ui/widget/iconwidget")
local FrameContainer    = require("ui/widget/container/framecontainer")
local HorizontalGroup   = require("ui/widget/horizontalgroup")
local HorizontalSpan    = require("ui/widget/horizontalspan")
local VerticalSpan      = require("ui/widget/verticalspan")
local ProgressWidget    = require("ui/widget/progresswidget")
local AlphaContainer    = require("ui/widget/container/alphacontainer")
local util              = require("util")
local OverlapGroup      = require("ui/widget/overlapgroup")
local InputDialog       = require("ui/widget/inputdialog")
local UIManager         = require("ui/uimanager")
local ReaderUI          = require("apps/reader/readerui")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local Dispatcher        = require("dispatcher")
local Event             = require("ui/event")
local cre               = require("document/credocument")

local Button            = require("ui/widget/button")
local CenterContainer   = require("ui/widget/container/centercontainer")
local FocusManager      = require("ui/widget/focusmanager")
local Geom              = require("ui/geometry")
local GestureRange      = require("ui/gesturerange")
local MovableContainer  = require("ui/widget/container/movablecontainer")
local Size              = require("ui/size")
local TitleBar          = require("ui/widget/titlebar")
local WidgetContainer   = require("ui/widget/container/widgetcontainer")

math.randomseed(os.time() + os.clock())
math.random(); math.random(); math.random()

ffi.cdef[[
    typedef struct { uint32_t d_ino; int32_t d_off; uint16_t d_reclen; uint8_t d_type; char d_name[256]; } dirent_t;
    void *opendir(const char *name);
    dirent_t *readdir(void *dirp);
    int closedir(void *dirp);
]]

local Screen = Device.screen
local STATISTICS_DB_PATH = DataStorage:getSettingsDir() .. "/statistics.sqlite3"

-------------------------------------------------------------------------
-- Config & Settings
-------------------------------------------------------------------------

local USER_CONFIG = {
    DARK_MODE                = false,
    MONOCHROME               = false,

    SHOW_BOOK                = true,
    SHOW_CHAP                = true,
    SHOW_GOAL                = true,
    SHOW_BATT                = true,
    SHOW_MSG                 = true,
    SECTION_ORDER            = {"book", "chapter", "goal", "battery", "message"},
    SHOW_BOOK_AUTHOR         = false,
    SHOW_BOOK_PAGES          = false,
    SHOW_BOOK_TIME_REMAINING = true,
    SHOW_CHAP_COUNT          = false,
    SHOW_CHAP_PAGES          = false,
    SHOW_CHAP_TIME_REMAINING = true,
    DAILY_GOAL               = 50,
    SHOW_GOAL_STREAK         = false,
    SHOW_GOAL_ACHIEVEMENT    = false,
    SHOW_GOAL_PAGES          = true,
    SHOW_BATT_TIME_SEPARATE  = false,
    SHOW_BATT_RATE           = false,
    SHOW_BATT_TIME           = true,
    SHOW_BATT_DATE           = false,
    MESSAGE_SOURCE           = "custom",
    MSG_HEADER               = "Sleeping",
    CUSTOM_MESSAGE           = "Books are a uniquely portable magic.",
    MAX_HIGHLIGHT_LENGTH     = 200,
    HIGHLIGHT_ADD_QUOTES     = true,
    SHOW_HIGHLIGHT_LOCATION  = false,
    SHOW_TITLES              = true,
    SHOW_SUBTITLES           = true,

    SECTION_GAPS_ENABLED     = false,
    SECTION_GAP_SIZE         = 20,
    POS                      = "center",
    BOX_WIDTH_PCT            = 60,
    OPACITY                  = 217,
    BORDER_SIZE              = 0,
    BORDER_SIZE_2            = 0,
    SECTION_PADDING          = 12,
    ICON_TEXT_GAP            = 16,
    MARGIN                   = 40,

    COLOR_BOOK_FILL          = "#82A9D9",
    COLOR_CHAPTER_FILL       = "#F2C2CF",
    COLOR_GOAL_FILL          = "#F9E480",
    BATT_HIGH_COLOR          = "#A1D9A3",
    BATT_MED_COLOR           = "#FDCB92",
    BATT_LOW_COLOR           = "#FF9B9B",
    BATT_CHARGING_COLOR      = "#82CFFF",
    COLOR_MESSAGE_FILL       = "#99A7D9",
    COLOR_LIGHT              = "#999999",
    COLOR_DARK               = "#E0E0E0",
    ICON_USE_BAR_COLOR       = true,
    ICON_SET                 = "default",
    ICON_SIZE                = 40,
    BAR_HEIGHT               = 12,
    SHOW_ICONS               = true,
    SHOW_BARS                = true,

    FONT_FACE_TITLE          = "cfont",
    FONT_SIZE_TITLE          = 10,
    FONT_FACE_SUBTITLE       = "cfont",
    FONT_SIZE_SUBTITLE       = 9,
    TEXT_ALIGN               = "left",
    BOOK_MULTILINE           = true,
    CHAP_MULTILINE           = true,
    CLEAN_CHAP               = true,
    BOOK_TITLE_BOLD          = false,

    BG_DIMMING               = 128,
    BG_DIMMING_COLOR         = "#000000",
    BG_TYPE                  = "cover",
    BG_FOLDER                = "/mnt/onboard/.adds/koreader/wallpaper",
    BG_SOLID_COLOR           = "#2C3E50",
    
    SHOW_IN_FILEMANAGER      = true,
    HIDE_PRELOADED_PRESETS   = false,
    BATT_STAT_TYPE           = "awake",
    BATT_MANUAL_RATE         = 2.5,
    DEBUG                    = false
}

local SETTINGS = {
    TYPE                     = "screensaver_type",
    SHOW_MSG_GLOBAL          = "screensaver_show_message",
    MSG_TEXT                 = "screensaver_message",

    VERSION                  = "customisable_ss_version",

    LAST_BOOK_STATE          = "customisable_ss_last_book_state",

    DARK_MODE                = "customisable_ss_dark_mode",
    MONOCHROME               = "customisable_ss_monochrome",

    SHOW_BOOK                = "customisable_ss_show_book",
    SHOW_CHAP                = "customisable_ss_show_chap",
    SHOW_GOAL                = "customisable_ss_show_goal",
    SHOW_BATT                = "customisable_ss_show_batt",
    SHOW_MSG                 = "customisable_ss_show_message",
    SECTION_ORDER            = "customisable_ss_section_order",
    SHOW_BOOK_AUTHOR         = "customisable_ss_show_book_author",
    SHOW_BOOK_PAGES          = "customisable_ss_show_book_pages",
    SHOW_BOOK_TIME_REMAINING = "customisable_ss_show_book_time_remaining",
    SHOW_CHAP_COUNT          = "customisable_ss_show_chap_count",
    SHOW_CHAP_PAGES          = "customisable_ss_show_chap_pages",
    SHOW_CHAP_TIME_REMAINING = "customisable_ss_show_chap_time_remaining",
    DAILY_GOAL               = "customisable_ss_daily_goal",
    SHOW_GOAL_STREAK         = "customisable_ss_show_goal_streak",
    SHOW_GOAL_ACHIEVEMENT    = "customisable_ss_show_goal_achievement",
    SHOW_GOAL_PAGES          = "customisable_ss_show_goal_pages",
    SHOW_BATT_TIME_SEPARATE  = "customisable_ss_show_batt_time_separate",
    SHOW_BATT_DATE           = "customisable_ss_show_batt_date",
    SHOW_BATT_RATE           = "customisable_ss_show_batt_rate",
    SHOW_BATT_TIME           = "customisable_ss_show_batt_time",
    MESSAGE_SOURCE           = "customisable_ss_message_source",
    MSG_HEADER               = "customisable_ss_message_header",
    CUSTOM_MESSAGE           = "customisable_ss_custom_message",
    MAX_HIGHLIGHT_LENGTH     = "customisable_ss_max_highlight_length",
    HIGHLIGHT_ADD_QUOTES     = "customisable_ss_highlight_add_quotes",
    SHOW_HIGHLIGHT_LOCATION  = "customisable_ss_show_highlight_location",
    SHOW_TITLES              = "customisable_ss_show_titles",
    SHOW_SUBTITLES           = "customisable_ss_show_subtitles",

    SECTION_GAPS_ENABLED     = "customisable_ss_section_gaps_enabled",
    SECTION_GAP_SIZE         = "customisable_ss_section_gap_size",
    POS                      = "customisable_ss_position",
    BOX_WIDTH_PCT            = "customisable_ss_box_width_pct",
    OPACITY                  = "customisable_ss_opacity",
    BORDER_SIZE              = "customisable_ss_border_size",
    BORDER_SIZE_2            = "customisable_ss_border_size_2",
    SECTION_PADDING          = "customisable_ss_section_padding",
    ICON_TEXT_GAP            = "customisable_ss_icon_text_gap",
    MARGIN                   = "customisable_ss_margin",

    COLOR_BOOK_FILL          = "customisable_ss_color_book",
    COLOR_CHAPTER_FILL       = "customisable_ss_color_chapter",
    COLOR_GOAL_FILL          = "customisable_ss_color_goal",
    BATT_HIGH_COLOR          = "customisable_ss_batt_high",
    BATT_MED_COLOR           = "customisable_ss_batt_med",
    BATT_LOW_COLOR           = "customisable_ss_batt_low",
    BATT_CHARGING_COLOR      = "customisable_ss_batt_charging",
    COLOR_MESSAGE_FILL       = "customisable_ss_color_message",
    COLOR_DARK               = "customisable_ss_color_dark",
    COLOR_LIGHT              = "customisable_ss_color_light",
    ICON_USE_BAR_COLOR       = "customisable_ss_icon_use_bar_color",
    ICON_SET                 = "customisable_ss_icon_set",
    ICON_SIZE                = "customisable_ss_icon_size",
    BAR_HEIGHT               = "customisable_ss_bar_height",
    SHOW_ICONS               = "customisable_ss_show_icons",
    SHOW_BARS                = "customisable_ss_show_bars",

    FONT_FACE_TITLE          = "customisable_ss_font_face_title",
    FONT_SIZE_TITLE          = "customisable_ss_font_size_title",
    FONT_FACE_SUBTITLE       = "customisable_ss_font_face_subtitle",
    FONT_SIZE_SUBTITLE       = "customisable_ss_font_size_subtitle",
    TEXT_ALIGN               = "customisable_ss_text_align",
    BOOK_MULTILINE           = "customisable_ss_book_multiline",
    CHAP_MULTILINE           = "customisable_ss_chap_multiline",
    CLEAN_CHAP               = "customisable_ss_clean_chapters",
    BOOK_TITLE_BOLD          = "customisable_ss_book_title_bold",

    BG_DIMMING               = "customisable_ss_bg_dimming",
    BG_DIMMING_COLOR         = "customisable_ss_bg_dimming_color",
    BG_TYPE                  = "customisable_ss_bg_type",
    BG_FOLDER                = "customisable_ss_bg_folder",
    BG_SOLID_COLOR           = "customisable_ss_bg_solid_color",
    
    PRESETS                  = "customisable_ss_presets",
    ACTIVE_PRESET            = "customisable_ss_active_preset",
    SHOW_IN_FILEMANAGER      = "customisable_ss_show_in_filemanager",
    HIDE_PRELOADED_PRESETS   = "customisable_ss_hide_preloaded_presets",
    BATT_STAT_TYPE           = "customisable_ss_batt_stat_type",
    BATT_MANUAL_RATE         = "customisable_ss_batt_manual_rate",
    DEBUG                    = "customisable_ss_debug",
}

local PRELOADED_PRESETS = {
    ["Comic"] = {
        ["customisable_ss_bar_height"] = 16,
        ["customisable_ss_batt_charging"] = "#4ECDC4",
        ["customisable_ss_batt_high"] = "#7FD99F",
        ["customisable_ss_batt_low"] = "#FF6B6B",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#F38181",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 51,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = true,
        ["customisable_ss_border_size"] = 6,
        ["customisable_ss_border_size_2"] = 0,
        ["customisable_ss_box_width_pct"] = 75,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#4ECDC4",
        ["customisable_ss_color_chapter"] = "#FF6B6B",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#FFE66D",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#C7CEEA",
        ["customisable_ss_custom_message"] = "Books are a uniquely portable magic",
        ["customisable_ss_daily_goal"] = 60,
        ["customisable_ss_dark_mode"] = false,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Bangers",
        ["customisable_ss_font_face_title"] = "Bangers",
        ["customisable_ss_font_size_subtitle"] = 10,
        ["customisable_ss_font_size_title"] = 13,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "Comic",
        ["customisable_ss_icon_size"] = 96,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = false,
        ["customisable_ss_margin"] = 50,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "POW!",
        ["customisable_ss_message_source"] = "custom",
        ["customisable_ss_monochrome"] = false,
        ["customisable_ss_opacity"] = 255,
        ["customisable_ss_position"] = "center",
        ["customisable_ss_section_gap_size"] = 30,
        ["customisable_ss_section_gaps_enabled"] = true,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "goal",
            [4] = "battery",
            [5] = "message",
        },
        ["customisable_ss_section_padding"] = 12,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = true,
        ["customisable_ss_show_book_pages"] = true,
        ["customisable_ss_show_book_time_remaining"] = false,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = true,
        ["customisable_ss_show_chap_pages"] = false,
        ["customisable_ss_show_chap_time_remaining"] = false,
        ["customisable_ss_show_goal"] = false,
        ["customisable_ss_show_goal_achievement"] = true,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = true,
        ["customisable_ss_show_icons"] = true,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "center",
    },
    ["Default"] = {
        ["customisable_ss_bar_height"] = 12,
        ["customisable_ss_batt_charging"] = "#82CFFF",
        ["customisable_ss_batt_high"] = "#A1D9A3",
        ["customisable_ss_batt_low"] = "#FF9B9B",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FDCB92",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 77,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = false,
        ["customisable_ss_border_size"] = 0,
        ["customisable_ss_border_size_2"] = 0,
        ["customisable_ss_box_width_pct"] = 60,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#82A9D9",
        ["customisable_ss_color_chapter"] = "#F2C2CF",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#F9E480",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#99A7D9",
        ["customisable_ss_custom_message"] = "Books are a uniquely portable magic",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = false,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Zilla Slab",
        ["customisable_ss_font_face_title"] = "Zilla Slab",
        ["customisable_ss_font_size_subtitle"] = 9,
        ["customisable_ss_font_size_title"] = 10,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "default",
        ["customisable_ss_icon_size"] = 48,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 40,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "Highlights",
        ["customisable_ss_message_source"] = "highlight",
        ["customisable_ss_monochrome"] = false,
        ["customisable_ss_opacity"] = 217,
        ["customisable_ss_position"] = "center",
        ["customisable_ss_section_gap_size"] = 22,
        ["customisable_ss_section_gaps_enabled"] = false,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "goal",
            [4] = "battery",
            [5] = "message",
        },
        ["customisable_ss_section_padding"] = 12,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = false,
        ["customisable_ss_show_book_pages"] = false,
        ["customisable_ss_show_book_time_remaining"] = true,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = false,
        ["customisable_ss_show_chap_pages"] = false,
        ["customisable_ss_show_chap_time_remaining"] = true,
        ["customisable_ss_show_goal"] = true,
        ["customisable_ss_show_goal_achievement"] = false,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = false,
        ["customisable_ss_show_icons"] = true,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "left",
    },
    ["Kobo"] = {
        ["customisable_ss_bar_height"] = 16,
        ["customisable_ss_batt_charging"] = "#82CFFF",
        ["customisable_ss_batt_high"] = "#A1D9A3",
        ["customisable_ss_batt_low"] = "#FF9B9B",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FDCB92",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 0,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = true,
        ["customisable_ss_border_size"] = 1,
        ["customisable_ss_border_size_2"] = 8,
        ["customisable_ss_box_width_pct"] = 45,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#82A9D9",
        ["customisable_ss_color_chapter"] = "#F2C2CF",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#F9E480",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#99A7D9",
        ["customisable_ss_custom_message"] = "%d",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = false,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Literata",
        ["customisable_ss_font_face_title"] = "Literata",
        ["customisable_ss_font_size_subtitle"] = 8,
        ["customisable_ss_font_size_title"] = 9,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "default",
        ["customisable_ss_icon_size"] = 48,
        ["customisable_ss_icon_text_gap"] = 8,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 150,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "Highlights",
        ["customisable_ss_message_source"] = "highlight",
        ["customisable_ss_monochrome"] = true,
        ["customisable_ss_opacity"] = 255,
        ["customisable_ss_position"] = "bottom_left",
        ["customisable_ss_section_gap_size"] = 20,
        ["customisable_ss_section_gaps_enabled"] = true,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "message",
            [4] = "goal",
            [5] = "battery",
        },
        ["customisable_ss_section_padding"] = 8,
        ["customisable_ss_show_bars"] = false,
        ["customisable_ss_show_batt"] = false,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = true,
        ["customisable_ss_show_book_pages"] = true,
        ["customisable_ss_show_book_time_remaining"] = true,
        ["customisable_ss_show_chap"] = false,
        ["customisable_ss_show_chap_count"] = false,
        ["customisable_ss_show_chap_pages"] = false,
        ["customisable_ss_show_chap_time_remaining"] = true,
        ["customisable_ss_show_goal"] = false,
        ["customisable_ss_show_goal_achievement"] = false,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = false,
        ["customisable_ss_show_icons"] = false,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "left",
    },
    ["Minimal"] = {
        ["customisable_ss_bar_height"] = 12,
        ["customisable_ss_batt_charging"] = "#82CFFF",
        ["customisable_ss_batt_high"] = "#A1D9A3",
        ["customisable_ss_batt_low"] = "#FF9B9B",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FDCB92",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 77,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = false,
        ["customisable_ss_border_size"] = 1,
        ["customisable_ss_border_size_2"] = 5,
        ["customisable_ss_box_width_pct"] = 55,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#82A9D9",
        ["customisable_ss_color_chapter"] = "#F2C2CF",
        ["customisable_ss_color_dark"] = "#5B9BD5",
        ["customisable_ss_color_goal"] = "#F9E480",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#99A7D9",
        ["customisable_ss_custom_message"] = "%d",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = true,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Google Sans",
        ["customisable_ss_font_face_title"] = "Google Sans",
        ["customisable_ss_font_size_subtitle"] = 13,
        ["customisable_ss_font_size_title"] = 20,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "default",
        ["customisable_ss_icon_size"] = 96,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = false,
        ["customisable_ss_margin"] = 175,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "%t",
        ["customisable_ss_message_source"] = "custom",
        ["customisable_ss_monochrome"] = true,
        ["customisable_ss_opacity"] = 178,
        ["customisable_ss_position"] = "top_center",
        ["customisable_ss_section_gap_size"] = 20,
        ["customisable_ss_section_gaps_enabled"] = false,
        ["customisable_ss_section_order"] = {
            [1] = "message",
            [2] = "book",
            [3] = "chapter",
            [4] = "goal",
            [5] = "battery",
        },
        ["customisable_ss_section_padding"] = 8,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = false,
        ["customisable_ss_show_batt_rate"] = true,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = true,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = false,
        ["customisable_ss_show_book_pages"] = false,
        ["customisable_ss_show_book_time_remaining"] = true,
        ["customisable_ss_show_chap"] = false,
        ["customisable_ss_show_chap_count"] = true,
        ["customisable_ss_show_chap_pages"] = true,
        ["customisable_ss_show_chap_time_remaining"] = true,
        ["customisable_ss_show_goal"] = false,
        ["customisable_ss_show_goal_achievement"] = true,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = true,
        ["customisable_ss_show_icons"] = false,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "center",
    },
    ["Night"] = {
        ["customisable_ss_bar_height"] = 8,
        ["customisable_ss_batt_charging"] = "#64B5F6",
        ["customisable_ss_batt_high"] = "#81C784",
        ["customisable_ss_batt_low"] = "#E57373",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FFB74D",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 204,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = false,
        ["customisable_ss_border_size"] = 0,
        ["customisable_ss_border_size_2"] = 1,
        ["customisable_ss_box_width_pct"] = 55,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#667BC6",
        ["customisable_ss_color_chapter"] = "#DA7297",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#FFEAA7",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#9575CD",
        ["customisable_ss_custom_message"] = "%d",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = true,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Atkinson Hyperlegible Next",
        ["customisable_ss_font_face_title"] = "Atkinson Hyperlegible Next",
        ["customisable_ss_font_size_subtitle"] = 9,
        ["customisable_ss_font_size_title"] = 11,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "Silhouette",
        ["customisable_ss_icon_size"] = 32,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 125,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "Highlights",
        ["customisable_ss_message_source"] = "highlight",
        ["customisable_ss_monochrome"] = false,
        ["customisable_ss_opacity"] = 230,
        ["customisable_ss_position"] = "middle_right",
        ["customisable_ss_section_gap_size"] = 20,
        ["customisable_ss_section_gaps_enabled"] = true,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "goal",
            [4] = "battery",
            [5] = "message",
        },
        ["customisable_ss_section_padding"] = 12,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = false,
        ["customisable_ss_show_book_pages"] = false,
        ["customisable_ss_show_book_time_remaining"] = true,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = false,
        ["customisable_ss_show_chap_pages"] = false,
        ["customisable_ss_show_chap_time_remaining"] = true,
        ["customisable_ss_show_goal"] = false,
        ["customisable_ss_show_goal_achievement"] = false,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = false,
        ["customisable_ss_show_icons"] = true,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "left",
    },
    ["Pixel"] = {
        ["customisable_ss_bar_height"] = 12,
        ["customisable_ss_batt_charging"] = "#00B0F0",
        ["customisable_ss_batt_high"] = "#70AD47",
        ["customisable_ss_batt_low"] = "#C00000",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FFC000",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 255,
        ["customisable_ss_bg_dimming_color"] = "#0F0F1B",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = false,
        ["customisable_ss_border_size"] = 3,
        ["customisable_ss_border_size_2"] = 1,
        ["customisable_ss_box_width_pct"] = 65,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#5B9BD5",
        ["customisable_ss_color_chapter"] = "#ED7D3A",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#FFC000",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#7030A0",
        ["customisable_ss_custom_message"] = "Press START to continue your reading adventure!",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = true,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Pixelify Sans",
        ["customisable_ss_font_face_title"] = "Pixelify Sans",
        ["customisable_ss_font_size_subtitle"] = 9,
        ["customisable_ss_font_size_title"] = 10,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "Pixel",
        ["customisable_ss_icon_size"] = 48,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 25,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "GAME SAVED",
        ["customisable_ss_message_source"] = "custom",
        ["customisable_ss_monochrome"] = false,
        ["customisable_ss_opacity"] = 229,
        ["customisable_ss_position"] = "center",
        ["customisable_ss_section_gap_size"] = 20,
        ["customisable_ss_section_gaps_enabled"] = false,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "goal",
            [4] = "battery",
            [5] = "message",
        },
        ["customisable_ss_section_padding"] = 12,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = false,
        ["customisable_ss_show_book_pages"] = true,
        ["customisable_ss_show_book_time_remaining"] = false,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = true,
        ["customisable_ss_show_chap_pages"] = true,
        ["customisable_ss_show_chap_time_remaining"] = false,
        ["customisable_ss_show_goal"] = true,
        ["customisable_ss_show_goal_achievement"] = true,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = false,
        ["customisable_ss_show_icons"] = true,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = true,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "right",
    },
    ["Sketch"] = {
        ["customisable_ss_bar_height"] = 16,
        ["customisable_ss_batt_charging"] = "#A7D8DE",
        ["customisable_ss_batt_high"] = "#B8E6B8",
        ["customisable_ss_batt_low"] = "#FFB3BA",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FFE8B8",
        ["customisable_ss_batt_stat_type"] = "awake",
        ["customisable_ss_bg_dimming"] = 26,
        ["customisable_ss_bg_dimming_color"] = "#FFF8DC",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = true,
        ["customisable_ss_book_title_bold"] = true,
        ["customisable_ss_border_size"] = 3,
        ["customisable_ss_border_size_2"] = 0,
        ["customisable_ss_box_width_pct"] = 60,
        ["customisable_ss_chap_multiline"] = true,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#B4A7D6",
        ["customisable_ss_color_chapter"] = "#FFD4B2",
        ["customisable_ss_color_dark"] = "#E0E0E0",
        ["customisable_ss_color_goal"] = "#FFF4A3",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#E8D4F0",
        ["customisable_ss_custom_message"] = "Books are a uniquely portable magic",
        ["customisable_ss_daily_goal"] = 35,
        ["customisable_ss_dark_mode"] = false,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "Caveat",
        ["customisable_ss_font_face_title"] = "Caveat",
        ["customisable_ss_font_size_subtitle"] = 11,
        ["customisable_ss_font_size_title"] = 13,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "Doodle",
        ["customisable_ss_icon_size"] = 56,
        ["customisable_ss_icon_text_gap"] = 32,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 40,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "Today's Note",
        ["customisable_ss_message_source"] = "custom",
        ["customisable_ss_monochrome"] = false,
        ["customisable_ss_opacity"] = 255,
        ["customisable_ss_position"] = "center",
        ["customisable_ss_section_gap_size"] = 25,
        ["customisable_ss_section_gaps_enabled"] = false,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "message",
            [4] = "goal",
            [5] = "battery",
        },
        ["customisable_ss_section_padding"] = 24,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = false,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = false,
        ["customisable_ss_show_book_pages"] = true,
        ["customisable_ss_show_book_time_remaining"] = false,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = false,
        ["customisable_ss_show_chap_pages"] = true,
        ["customisable_ss_show_chap_time_remaining"] = false,
        ["customisable_ss_show_goal"] = false,
        ["customisable_ss_show_goal_achievement"] = false,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = false,
        ["customisable_ss_show_icons"] = true,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = false,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "left",
    },
    ["Terminal"] = {
        ["customisable_ss_bar_height"] = 4,
        ["customisable_ss_batt_charging"] = "#82CFFF",
        ["customisable_ss_batt_high"] = "#A1D9A3",
        ["customisable_ss_batt_low"] = "#FF9B9B",
        ["customisable_ss_batt_manual_rate"] = 2.5,
        ["customisable_ss_batt_med"] = "#FDCB92",
        ["customisable_ss_batt_stat_type"] = "manual",
        ["customisable_ss_bg_dimming"] = 204,
        ["customisable_ss_bg_dimming_color"] = "#000000",
        ["customisable_ss_bg_type"] = "cover",
        ["customisable_ss_book_multiline"] = false,
        ["customisable_ss_book_title_bold"] = false,
        ["customisable_ss_border_size"] = 0,
        ["customisable_ss_border_size_2"] = 0,
        ["customisable_ss_box_width_pct"] = 50,
        ["customisable_ss_chap_multiline"] = false,
        ["customisable_ss_clean_chapters"] = true,
        ["customisable_ss_color_book"] = "#8FAADC",
        ["customisable_ss_color_chapter"] = "#CDB4DB",
        ["customisable_ss_color_dark"] = "#61cf5a",
        ["customisable_ss_color_goal"] = "#F4D35E",
        ["customisable_ss_color_light"] = "#999999",
        ["customisable_ss_color_message"] = "#9CADCE",
        ["customisable_ss_custom_message"] = "%d",
        ["customisable_ss_daily_goal"] = 50,
        ["customisable_ss_dark_mode"] = true,
        ["customisable_ss_debug"] = false,
        ["customisable_ss_font_face_subtitle"] = "JetBrains Mono",
        ["customisable_ss_font_face_title"] = "JetBrains Mono",
        ["customisable_ss_font_size_subtitle"] = 8,
        ["customisable_ss_font_size_title"] = 9,
        ["customisable_ss_highlight_add_quotes"] = true,
        ["customisable_ss_icon_set"] = "Silhouette",
        ["customisable_ss_icon_size"] = 24,
        ["customisable_ss_icon_text_gap"] = 16,
        ["customisable_ss_icon_use_bar_color"] = true,
        ["customisable_ss_margin"] = 25,
        ["customisable_ss_max_highlight_length"] = 200,
        ["customisable_ss_message_header"] = "Highlights",
        ["customisable_ss_message_source"] = "highlight",
        ["customisable_ss_monochrome"] = true,
        ["customisable_ss_opacity"] = 230,
        ["customisable_ss_position"] = "top_center",
        ["customisable_ss_section_gap_size"] = 20,
        ["customisable_ss_section_gaps_enabled"] = false,
        ["customisable_ss_section_order"] = {
            [1] = "book",
            [2] = "chapter",
            [3] = "goal",
            [4] = "battery",
            [5] = "message",
        },
        ["customisable_ss_section_padding"] = 8,
        ["customisable_ss_show_bars"] = true,
        ["customisable_ss_show_batt"] = true,
        ["customisable_ss_show_batt_rate"] = true,
        ["customisable_ss_show_batt_time"] = true,
        ["customisable_ss_show_batt_time_separate"] = false,
        ["customisable_ss_show_book"] = true,
        ["customisable_ss_show_book_author"] = true,
        ["customisable_ss_show_book_pages"] = true,
        ["customisable_ss_show_book_time_remaining"] = true,
        ["customisable_ss_show_chap"] = true,
        ["customisable_ss_show_chap_count"] = false,
        ["customisable_ss_show_chap_pages"] = true,
        ["customisable_ss_show_chap_time_remaining"] = true,
        ["customisable_ss_show_goal"] = true,
        ["customisable_ss_show_goal_achievement"] = false,
        ["customisable_ss_show_goal_pages"] = true,
        ["customisable_ss_show_goal_streak"] = true,
        ["customisable_ss_show_icons"] = false,
        ["customisable_ss_show_in_filemanager"] = true,
        ["customisable_ss_show_message"] = false,
        ["customisable_ss_show_subtitles"] = true,
        ["customisable_ss_show_titles"] = true,
        ["customisable_ss_text_align"] = "left",
    },
}

-------------------------------------------------------------------------
-- Caches & Utility Vars
-------------------------------------------------------------------------

local font_cache = setmetatable({}, {__mode = "v"})

local color_cache = setmetatable({}, {__mode = "v"})

local settings_cache_timestamp = 0
local cached_settings = nil

-------------------------------------------------------------------------
-- Utility Functions
-------------------------------------------------------------------------

local function log_memory(label)
    if G_reader_settings:isTrue(SETTINGS.DEBUG) then
        local mem = collectgarbage("count")
        print(string.format("[Customisable Sleep Screen] %s: %.2f KB", label, mem))
    end
end

local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function safe_get(obj, ...)
    for i, key in ipairs({...}) do
        if not obj then return nil end
        obj = obj[key]
    end
    return obj
end

-------------------------------------------------------------------------
-- Settings Helper
-------------------------------------------------------------------------

local function getSetting(key)
    local value = G_reader_settings:readSetting(SETTINGS[key])
    if value == nil then
        return USER_CONFIG[key]
    end
    return value
end

-------------------------------------------------------------------------
-- Cache Management
-------------------------------------------------------------------------

local function getCachedFont(path, size)
    local key = path .. ":" .. size
    if not font_cache[key] then
        local success, face = pcall(Font.getFace, Font, path, size)
        if success and face then
            font_cache[key] = face
        else
            font_cache[key] = Font:getFace("cfont", size)
        end
    end
    return font_cache[key]
end

local function getCachedColor(hex)
    if not hex then return Blitbuffer.COLOR_BLACK end
    if not color_cache[hex] then
        local success, color = pcall(function() return Blitbuffer.colorFromString(hex) end)
        color_cache[hex] = success and color or Blitbuffer.COLOR_BLACK
    end
    return color_cache[hex]
end

local function getBBColor(setting_key, default_hex)
    local hex = G_reader_settings:readSetting(setting_key) or default_hex
    return getCachedColor(hex)
end

local function getSettingsCache()
    local now = os.time()
    if not cached_settings or (now - settings_cache_timestamp) > 3600 then
        cached_settings = {
            dark = G_reader_settings:isTrue(SETTINGS.DARK_MODE),
            is_mono = G_reader_settings:isTrue(SETTINGS.MONOCHROME),
            
            show_book = getSetting("SHOW_BOOK"),
            show_chap = getSetting("SHOW_CHAP"),
            show_goal = getSetting("SHOW_GOAL"),
            show_batt = getSetting("SHOW_BATT"),
            show_msg = getSetting("SHOW_MSG"),
            section_order = getSetting("SECTION_ORDER"),

            show_book_author = G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR),
            show_book_pages = G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES),
            book_multiline = getSetting("BOOK_MULTILINE"),
            book_title_bold = getSetting("BOOK_TITLE_BOLD"),

            show_chap_count = getSetting("SHOW_CHAP_COUNT"),
            show_chap_pages = getSetting("SHOW_CHAP_PAGES"),
            chap_multiline = getSetting("CHAP_MULTILINE"),
            clean_chap = getSetting("CLEAN_CHAP"),

            show_goal_streak = getSetting("SHOW_GOAL_STREAK"),
            show_goal_achievement = getSetting("SHOW_GOAL_ACHIEVEMENT"),
            show_goal_pages = getSetting("SHOW_GOAL_PAGES"),

            show_batt_time = getSetting("SHOW_BATT_TIME"),
            show_batt_time_separate = getSetting("SHOW_BATT_TIME_SEPARATE"),
            show_batt_rate = G_reader_settings:isTrue(SETTINGS.SHOW_BATT_RATE),

            message_source = getSetting("MESSAGE_SOURCE"),
            max_highlight_length = getSetting("MAX_HIGHLIGHT_LENGTH"),
            show_titles = getSetting("SHOW_TITLES"),
            show_subtitles = getSetting("SHOW_SUBTITLES"),

            gaps_enabled = getSetting("SECTION_GAPS_ENABLED"),
            gap_size = getSetting("SECTION_GAP_SIZE"),
            pos = getSetting("POS"),
            box_width_pct = clamp(getSetting("BOX_WIDTH_PCT"), 20, 100),
            opacity = clamp(getSetting("OPACITY"), 0, 255),
            border_size = Screen:scaleBySize(clamp(getSetting("BORDER_SIZE"), 0, 10)),
            border_size_2 = Screen:scaleBySize(clamp(getSetting("BORDER_SIZE_2"), 0, 10)),
            section_padding = Screen:scaleBySize(getSetting("SECTION_PADDING")),
            icon_text_gap = Screen:scaleBySize(getSetting("ICON_TEXT_GAP")),
            margin = Screen:scaleBySize(getSetting("MARGIN")),

            color_dark_hex = getSetting("COLOR_DARK"),
            color_light_hex = getSetting("COLOR_LIGHT"),
            batt_high_color = getSetting("BATT_HIGH_COLOR"),
            batt_med_color = getSetting("BATT_MED_COLOR"),
            batt_low_color = getSetting("BATT_LOW_COLOR"),
            batt_charging_color = getSetting("BATT_CHARGING_COLOR"),

            icon_use_bar_color = getSetting("ICON_USE_BAR_COLOR"),
            icon_set = getSetting("ICON_SET"),
            icon_size = Screen:scaleBySize(clamp(getSetting("ICON_SIZE"), 16, 128)),
            custom_bar_height = getSetting("BAR_HEIGHT"),
            show_icons = getSetting("SHOW_ICONS") ~= false,
            show_bars = getSetting("SHOW_BARS") ~= false,

            title_face_name = getSetting("FONT_FACE_TITLE"),
            title_size = getSetting("FONT_SIZE_TITLE"),
            subtitle_face_name = getSetting("FONT_FACE_SUBTITLE"),
            subtitle_size = getSetting("FONT_SIZE_SUBTITLE"),
            text_align = getSetting("TEXT_ALIGN"),

            dim_val = clamp(getSetting("BG_DIMMING"), 0, 255),
            dim_color_hex = getSetting("BG_DIMMING_COLOR"),
        }
        settings_cache_timestamp = now
    end
    return cached_settings
end

local function invalidateSettingsCache()
    cached_settings = nil
end

local function getColors(is_mono, mono_hex, mono_color)
    if is_mono then
        return {
            book_hex = mono_hex,
            chapter_hex = mono_hex,
            goal_hex = mono_hex,
            message_hex = mono_hex,
            
            book = mono_color,
            chapter = mono_color,
            goal = mono_color,
            message = mono_color,
        }
    else
        return {
            book_hex = getSetting("COLOR_BOOK_FILL"),
            chapter_hex = getSetting("COLOR_CHAPTER_FILL"),
            goal_hex = getSetting("COLOR_GOAL_FILL"),
            message_hex = getSetting("COLOR_MESSAGE_FILL"),
            
            book = getBBColor(SETTINGS.COLOR_BOOK_FILL, USER_CONFIG.COLOR_BOOK_FILL),
            chapter = getBBColor(SETTINGS.COLOR_CHAPTER_FILL, USER_CONFIG.COLOR_CHAPTER_FILL),
            goal = getBBColor(SETTINGS.COLOR_GOAL_FILL, USER_CONFIG.COLOR_GOAL_FILL),
            message = getBBColor(SETTINGS.COLOR_MESSAGE_FILL, USER_CONFIG.COLOR_MESSAGE_FILL),
        }
    end
end

-------------------------------------------------------------------------
-- Colour Utilities
-------------------------------------------------------------------------

local ProgressWidget_paintTo = ProgressWidget.paintTo
function ProgressWidget:paintTo(bb, x, y)
    local my_size = self:getSize()
    if not self.dimen then
        self.dimen = require("ui/geometry"):new({
            x = x, y = y, w = my_size.w, h = my_size.h,
        })
    else
        self.dimen.x = x
        self.dimen.y = y
    end
    if self.dimen.w == 0 or self.dimen.h == 0 then return end

    local BD = require("ui/bidi")
    local _mirroredUI = BD.mirroredUILayout()
    local fill_width = my_size.w - 2 * (self.margin_h + self.bordersize)
    local fill_y = y + self.margin_v + self.bordersize
    local fill_height = my_size.h - 2 * (self.margin_v + self.bordersize)

    if self.radius == 0 then
        bb:paintRect(x, y, my_size.w, my_size.h, self.bordercolor)
        bb:paintRectRGB32(
            x + self.margin_h + self.bordersize,
            fill_y,
            math.ceil(fill_width),
            math.ceil(fill_height),
            self.bgcolor
        )
    else
        bb:paintRectRGB32(x, y, my_size.w, my_size.h, self.bgcolor)
        bb:paintBorder(
            math.floor(x), math.floor(y),
            my_size.w, my_size.h,
            self.bordersize, self.bordercolor, self.radius
        )
    end

    if self.percentage >= 0 and self.percentage <= 1 then
        local fill_x = x + self.margin_h + self.bordersize
        if self.fill_from_right or (_mirroredUI and not self.fill_from_right) then
            fill_x = fill_x + (fill_width * (1 - self.percentage))
            fill_x = math.floor(fill_x)
        end

        bb:paintRectRGB32(
            fill_x, fill_y,
            math.ceil(fill_width * self.percentage),
            math.ceil(fill_height),
            self.fillcolor
        )
    end

    if self.ticks and self.last and self.last > 0 then
        for i, tick in ipairs(self.ticks) do
            local tick_x = fill_width * (tick / self.last)
            if _mirroredUI then tick_x = fill_width - tick_x end
            tick_x = math.floor(tick_x)
            bb:paintRect(
                x + self.margin_h + self.bordersize + tick_x,
                fill_y, self.tick_width,
                math.ceil(fill_height), self.bordercolor
            )
        end
    end
end

local function blitbufferColorToHex(color)
    if not color then
        return "#FFFFFF"
    end
    
    local color_str = tostring(color)
    if color_str:match("^#%x%x%x%x%x%x$") then
        return color_str
    end
    
    if type(color) == "cdata" then
        local color_num = tonumber(color)
        if color_num then
            local r = bit.band(bit.rshift(color_num, 16), 0xFF)
            local g = bit.band(bit.rshift(color_num, 8), 0xFF)
            local b = bit.band(color_num, 0xFF)
            local hex = string.format("#%02X%02X%02X", r, g, b)
            return hex
        end
    end
    
    if type(color) == "table" then
        if color.r and color.g and color.b then
            local hex = string.format("#%02X%02X%02X", color.r, color.g, color.b)
            return hex
        end
    end
    
    return "#FFFFFF"
end

-------------------------------------------------------------------------
-- Text Processing
-------------------------------------------------------------------------

local function getTextWidth(text, face)
    if not face or not text or text == "" then return 0 end
    
    if face.getAdvance then
        return face:getAdvance(text)
    end
    
    local temp_widget = TextWidget:new{ text = text, face = face }
    local w = temp_widget:getSize().w
    temp_widget:free()
    return w
end

local function wrapText(text, face, max_width)
    if not text or text == "" or not face then return {} end
    
    local lines = {}
    local current_line = {}
    local current_width = 0
    local space_width = getTextWidth(" ", face)
    
    for word in text:gmatch("%S+") do
        local word_width = getTextWidth(word, face)
        
        if #current_line == 0 then
            current_line[1] = word
            current_width = word_width
        elseif current_width + space_width + word_width <= max_width then
            current_line[#current_line + 1] = word
            current_width = current_width + space_width + word_width
        else
            lines[#lines + 1] = table.concat(current_line, " ")
            current_line = { word }
            current_width = word_width
        end
    end
    
    if #current_line > 0 then
        lines[#lines + 1] = table.concat(current_line, " ")
    end
    
    return lines
end

local function createMultiLineText(text, face, color, max_width, allow_multiline, alignment, bold)
    if allow_multiline == nil then allow_multiline = true end
    if not alignment then alignment = "left" end
    if not text or text == "" then
        return TextWidget:new{ text = "", face = face, fgcolor = color, bold = bold }
    end
    
    if not allow_multiline then
        local ellipsis = "…"
        if getTextWidth(text, face) <= max_width then
            return TextWidget:new{ text = text, face = face, fgcolor = color, bold = bold}
        end
        
        local words = {}
        for word in text:gmatch("%S+") do words[#words + 1] = word end
        
        local current_text = ""
        local best_text = ""
        for i, word in ipairs(words) do
            local test_text = current_text == "" and word or current_text .. " " .. word
            if getTextWidth(test_text .. ellipsis, face) <= max_width then
                current_text = test_text
                best_text = current_text
            else
                break
            end
        end
        return TextWidget:new{ text = best_text .. ellipsis, face = face, fgcolor = color, bold = bold }
    end
    
    local lines = wrapText(text, face, max_width)
    if #lines == 1 then
        return TextWidget:new{ text = lines[1], face = face, fgcolor = color, bold = bold}
    else
        local text_group = VerticalGroup:new{ align = alignment }
        for i, line in ipairs(lines) do
            text_group[#text_group + 1] = TextWidget:new{ text = line, face = face, fgcolor = color, bold = bold }
        end
        return text_group
    end
end

local function truncateText(text, max_length)
    if not max_length or max_length <= 0 then
        return text
    end
    
    if #text <= max_length then
        return text
    end
    
    local truncated = text:sub(1, max_length)
    local last_space = truncated:match("^.*() ")
    
    if last_space and last_space > max_length * 0.7 then
        truncated = text:sub(1, last_space - 1)
    end
    
    return truncated .. "..."
end

local function cleanChapterTitle(raw_title)
    if not raw_title or raw_title == "" then return "No Chapter" end
    
    local structural = " chapter ch part pt one two three four five six seven eight nine ten " ..
                      "eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen " ..
                      "twenty thirty forty fifty sixty seventy eighty ninety hundred and "
    local roman_except = { did=1, mix=1, mill=1, dim=1, lid=1, vim=1, civil=1, mild=1, livid=1 }
    
    local has_content = false
    for word in raw_title:gmatch("[%w%d]+") do
        local low = word:lower()
        local is_roman = #word <= 4 and low:match("^[ivxlcdm]+$") and not roman_except[low]
        local is_structural = structural:find(" " .. low .. " ", 1, true) or word:match("^%d+$") or is_roman
        
        if not is_structural then
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
        cleaned = cleaned:lower():gsub("(%a)([%w']*)", function(first, rest)
            return first:upper() .. rest
        end)
    end
    
    return cleaned:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^[:%.%-%s]+", "")
end

local function expandMessage(str)
    if not str or str == "" then
        return ""
    end

    local function ordinal(n)
        local mod10 = n % 10
        local mod100 = n % 100

        if mod10 == 1 and mod100 ~= 11 then
            return n .. "st"
        elseif mod10 == 2 and mod100 ~= 12 then
            return n .. "nd"
        elseif mod10 == 3 and mod100 ~= 13 then
            return n .. "rd"
        else
            return n .. "th"
        end
    end

    local t = os.date("*t")
    local long_date = string.format(
        "%s %s",
        ordinal(t.day),
        os.date("%B")
    )

    local pwr = Device:getPowerDevice()
    local batt_perc = Device:hasBattery() and pwr:getCapacity() or 0
    local charging_symbol = pwr:isCharging() and " ⚡" or ""
    local replacements = {
        ["%%d"] = long_date,
        ["%%t"] = os.date("%H:%M"),
        ["%%y"] = os.date("%Y"),
        ["%%b"] = batt_perc .. "%%" .. charging_symbol,
        ["%%r"] = " · ",
    }

    for token, value in pairs(replacements) do
        str = str:gsub(token, value)
    end

    return str
end

-------------------------------------------------------------------------
-- Text Formatting
-------------------------------------------------------------------------

local function formatDuration(secs)
    if not secs or secs <= 0 then return nil end
    
    local function plural(val, unit)
        return val .. " " .. unit .. (val == 1 and "" or "s")
    end

    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)

    if h > 0 then 
        return plural(h, "hr") .. (m > 0 and " " .. plural(m, "min") or "")
    end

    return m > 0 and plural(m, "min") or "<1 min"
end

-------------------------------------------------------------------------
-- Data Gathering
-------------------------------------------------------------------------

local function getDailyStats(stats_source)
    local book_id = safe_get(stats_source, "id_curr_book")
    if not book_id then return 0, 0 end
    
    book_id = tonumber(book_id)
    if not book_id or book_id < 1 then return 0, 0 end

    local duration, pages = 0, 0

    local now = os.date("*t")
    now.hour, now.min, now.sec = 0, 0, 0
    local start_today = os.time(now)

    local ok_conn, conn = pcall(SQ3.open, STATISTICS_DB_PATH, SQ3.OPEN_READONLY)
    if not ok_conn or not conn then return 0, 0 end

    local sql = string.format("SELECT SUM(duration), COUNT(DISTINCT page) FROM page_stat WHERE start_time >= %d AND id_book = %d", start_today, book_id)

    local ok = pcall(function()
        local stmt = conn:prepare(sql)
        if stmt then
            local row = stmt:step()
            if row then
                duration = tonumber(row[1]) or 0
                pages = tonumber(row[2]) or 0
            end
            stmt:finalize()
        end
    end)
    
    conn:close()
    return duration, pages
end

local function getCurrentDailyStreak()
    local streak = 0
    
    local ok_conn, conn = pcall(SQ3.open, STATISTICS_DB_PATH, SQ3.OPEN_READONLY)
    if not ok_conn or not conn then return 0 end
    
    local dates = {}
    local sql = "SELECT DISTINCT date(start_time, 'unixepoch', 'localtime') as d FROM page_stat ORDER BY d DESC"
    
    pcall(function()
        local stmt = conn:prepare(sql)
        if stmt then
            for row in stmt:rows() do
                dates[#dates + 1] = row[1]
            end
            stmt:finalize()
        end
    end)
    
    conn:close()
    
    if #dates == 0 then return 0 end
    
    local today = os.date("%Y-%m-%d")
    local yesterday = os.date("%Y-%m-%d", os.time() - 86400)
    
    if dates[1] ~= today and dates[1] ~= yesterday then
        return 0
    end
    
    streak = 1
    for i = 2, #dates do
        local prev_date = dates[i - 1]
        local curr_date = dates[i]
        
        local year = tonumber(prev_date:sub(1,4))
        local month = tonumber(prev_date:sub(6,7))
        local day = tonumber(prev_date:sub(9,10))
        
        if year and month and day then
            local prev_time = os.time({
                year = year,
                month = month,
                day = day,
            })
            local expected_prev = os.date("%Y-%m-%d", prev_time - 86400)
            
            if curr_date == expected_prev then
                streak = streak + 1
            else
                break
            end
        else
            break
        end
    end
    
    return streak
end

local function getWeeklyGoalAchievement()
    local daily_goal = getSetting("DAILY_GOAL")
    local days_met = 0
    local days_read = 0
    
    local ok_conn, conn = pcall(SQ3.open, STATISTICS_DB_PATH, SQ3.OPEN_READONLY)
    if not ok_conn or not conn then return 0, 0 end
    
    local now = os.time()
    local now_t = os.date("*t", now)
    local days_since_monday = (now_t.wday + 5) % 7
    local start_of_week = now - (days_since_monday * 86400) - (now_t.hour * 3600 + now_t.min * 60 + now_t.sec)
    
    local sql = [[
        SELECT date(start_time, 'unixepoch', 'localtime') as read_date,
               COUNT(DISTINCT page) as pages_read
        FROM page_stat
        WHERE start_time >= ?
        GROUP BY read_date
        ORDER BY read_date ASC
    ]]
    
    pcall(function()
        local stmt = conn:prepare(sql)
        if stmt then
            stmt:bind(1, start_of_week)
            
            for row in stmt:rows() do
                local pages = tonumber(row[2]) or 0
                days_read = days_read + 1
                if pages >= daily_goal then
                    days_met = days_met + 1
                end
            end
            stmt:finalize()
        end
    end)
    
    conn:close()
    
    local days_in_week = math.min(7, days_since_monday + 1)
    
    return days_met, days_in_week
end

local function getBatteryConsumptionRate()
    local batt_stat_type = getSetting("BATT_STAT_TYPE")
    if batt_stat_type == "manual" then
        return getSetting("BATT_MANUAL_RATE")
    end
    
    local ok_time, time_module = pcall(require, "ui/time")
    local ok_settings, LuaSettings = pcall(require, "luasettings")
    
    if not (ok_time and ok_settings) then return nil end
    
    local ok_open, batt_settings = pcall(LuaSettings.open, LuaSettings, 
        DataStorage:getSettingsDir() .. "/battery_stats.lua")
    
    if not ok_open or not batt_settings then return nil end
    
    local stat_data = batt_settings:readSetting(batt_stat_type)
    if stat_data and type(stat_data.percentage) == "number" 
       and type(stat_data.time) == "number" 
       and stat_data.time > 0 
       and stat_data.percentage > 0 then
        local time_seconds = time_module.to_s(stat_data.time)
        local rate_per_second = stat_data.percentage / time_seconds
        if rate_per_second > 0 then
            return rate_per_second * 3600
        end
    end
    
    return nil
end

local function addQuotationMarks(text)
    if not text or text == "" then
        return text
    end
    
    local add_quotes = G_reader_settings:readSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES)
    if add_quotes == nil then
        add_quotes = USER_CONFIG.HIGHLIGHT_ADD_QUOTES
    end
    
    if not add_quotes then
        return text
    end
    
    local trimmed = text:match("^%s*(.-)%s*$")
    
    if not trimmed or trimmed == "" then
        return text
    end
    
    local quote_patterns = {
        {open = '"',  close = '"'},
        {open = "'",  close = "'"},
        {open = "“",  close = "”"},
        {open = "‘",  close = "’"},
        {open = "«",  close = "»"},
        {open = "„",  close = "“"},
    }
    
    local content = trimmed
    for _, quotes in ipairs(quote_patterns) do
        local open_escaped = quotes.open:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        local close_escaped = quotes.close:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
        
        if content:match("^" .. open_escaped) and content:match(close_escaped .. "$") then
            content = content:gsub("^" .. open_escaped, "")
            content = content:gsub(close_escaped .. "$", "")
            content = content:match("^%s*(.-)%s*$") or content
            break
        end
    end
    
    local leading_space = text:match("^(%s*)")
    local trailing_space = text:match("(%s*)$")
    
    return leading_space .. "“" .. content .. "”" .. trailing_space
end

local function getRandomHighlight(ui)

    if not ui or not ui.document or not ui.document.file then 
        return nil 
    end
    
    local book_path = ui.document.file
    local lfs = require("libs/libkoreader-lfs")
    
    local filename = book_path:match("([^/]+)$")
    local parent_dir = book_path:match("(.*/)")
    
    local base_name = filename:gsub("%.[^.]+$", "")
    
    local sdr_dir = nil
    
    if parent_dir and base_name then
        local expected_sdr = base_name .. ".sdr"
        
        for entry in lfs.dir(parent_dir) do
            if entry == expected_sdr then
                sdr_dir = parent_dir .. entry
                break
            end
        end
    end
    
    if not sdr_dir then
        return nil
    end
    
    local metadata_pattern = "^metadata%..+%.lua$"
    local metadata_files = {}
    
    for entry in lfs.dir(sdr_dir) do
        if entry and entry:match(metadata_pattern) then
            metadata_files[#metadata_files + 1] = sdr_dir .. "/" .. entry
        end
    end
    
    if #metadata_files == 0 then
        return nil
    end
    
    local all_highlights = {}
    for _, metadata_file in ipairs(metadata_files) do
        
        local ok, metadata = pcall(function()
            local fn, err = loadfile(metadata_file)
            if not fn then error(err) end
            return fn()
        end)
        
        if ok and type(metadata) == "table" then
            
            local annotations = metadata.annotations or metadata.bookmarks or {}
            
            if type(annotations) == "table" then
                for idx, ann in pairs(annotations) do
                    if type(ann) == "table" then
                        local text = ann.text or ann.note or ann.notes or ann.highlighted_text
                        if type(text) == "string" and text ~= "" then
                            text = text:gsub("\n", " ")
                            text = text:match("^%s*(.-)%s*$") or text
                            
                            if #text >= 20 then
                                local page_num = ann.pageno or ann.page_no or ann.drawer_args and ann.drawer_args.page
                                
                                all_highlights[#all_highlights + 1] = {
                                    text = text,
                                    page = page_num,
                                    chapter = ann.chapter
                                }
                            end
                        end
                    end
                end
            end
        end
    end
    
    if #all_highlights == 0 then return nil end
    
    local random_index = math.random(#all_highlights)
    
    local selected_highlight = all_highlights[random_index]
    
    local highlight_text = selected_highlight.text
    local max_length = G_reader_settings:readSetting(SETTINGS.MAX_HIGHLIGHT_LENGTH)
    if max_length then
        highlight_text = truncateText(highlight_text, max_length)
    end
    
    highlight_text = addQuotationMarks(highlight_text)
    
    return {
        text = highlight_text,
        page = selected_highlight.page,
        chapter = selected_highlight.chapter
    }
end

local function getChapterCount(ui, current_page)
    if not ui or not ui.toc then return nil, nil end
    
    local toc_items = ui.toc.toc
    if not toc_items or #toc_items == 0 then return nil, nil end
    
    local chapter_patterns = {
        "^chapter%s+%d+",
        "^ch%.?%s*%d+",
        "^%d+%.%s+",
        "^%d+$",
        "chapter%s+[ivxlcdm]+",
    }
    
    local chapter_indices = {}
    for i = 1, #toc_items do
        local title = (toc_items[i].title or ""):lower()
        local is_chapter = false
        
        for _, pattern in ipairs(chapter_patterns) do
            if title:match(pattern) then
                is_chapter = true
                break
            end
        end
        
        if is_chapter then
            table.insert(chapter_indices, {index = i, page = toc_items[i].page})
        end
    end
    
    if #chapter_indices > 0 then
        local current_chapter_num = nil
        for i, item in ipairs(chapter_indices) do
            if item.page <= current_page then
                current_chapter_num = i
            else
                break
            end
        end
        
        return current_chapter_num or 1, #chapter_indices
    end
    
    local exclude_terms = {
        "prologue", "epilogue", "preface", "foreword", "afterword",
        "introduction", "dedication", "acknowledgment", "acknowledgement",
        "appendix", "glossary", "bibliography", "index", "notes",
        "table of contents", "contents", "cover", "title page",
        "about the author", "about the book", "copyright",
        "part %d", "part one", "part two", "part three",
        "book %d", "book one", "book two", "book three",
    }
    
    local filtered_items = {}
    for i = 1, #toc_items do
        local title = (toc_items[i].title or ""):lower()
        local should_exclude = false
        
        for _, term in ipairs(exclude_terms) do
            if title:find(term, 1, true) then
                should_exclude = true
                break
            end
        end
        
        if not should_exclude then
            table.insert(filtered_items, {index = i, page = toc_items[i].page})
        end
    end
    
    if #filtered_items == 0 then
        local current_chapter_index = nil
        for i = 1, #toc_items do
            if toc_items[i].page <= current_page then
                current_chapter_index = i
            else
                break
            end
        end
        
        return current_chapter_index or 1, #toc_items
    end
    
    local current_chapter_num = nil
    for i, item in ipairs(filtered_items) do
        if item.page <= current_page then
            current_chapter_num = i
        else
            break
        end
    end
    
    return current_chapter_num or 1, #filtered_items
end

-------------------------------------------------------------------------
-- Preset System
-------------------------------------------------------------------------

local function getAllSettingKeys()
    local keys = {}
    for key_name, setting_key in pairs(SETTINGS) do
        if key_name ~= "TYPE" 
           and key_name ~= "PRESETS" 
           and key_name ~= "ACTIVE_PRESET"
           and key_name ~= "SHOW_MSG_GLOBAL"
           and key_name ~= "MSG_TEXT" then
            keys[#keys + 1] = setting_key
        end
    end
    return keys
end

local function getDefaultSettings()
    local defaults = {}

    defaults[SETTINGS.DARK_MODE]                    = USER_CONFIG.DARK_MODE
    defaults[SETTINGS.MONOCHROME]                   = USER_CONFIG.MONOCHROME

    defaults[SETTINGS.SHOW_BOOK]                    = USER_CONFIG.SHOW_BOOK
    defaults[SETTINGS.SHOW_CHAP]                    = USER_CONFIG.SHOW_CHAP
    defaults[SETTINGS.SHOW_GOAL]                    = USER_CONFIG.SHOW_GOAL
    defaults[SETTINGS.SHOW_BATT]                    = USER_CONFIG.SHOW_BATT
    defaults[SETTINGS.SHOW_MSG]                     = USER_CONFIG.MONOCHROME
    defaults[SETTINGS.SECTION_ORDER]                = USER_CONFIG.SECTION_ORDER
    defaults[SETTINGS.SHOW_BOOK_AUTHOR]             = USER_CONFIG.SHOW_BOOK_AUTHOR        
    defaults[SETTINGS.SHOW_BOOK_PAGES]              = USER_CONFIG.SHOW_BOOK_PAGES 
    defaults[SETTINGS.SHOW_BOOK_TIME_REMAINING]     = USER_CONFIG.SHOW_BOOK_TIME_REMAINING
    defaults[SETTINGS.SHOW_CHAP_COUNT]              = USER_CONFIG.SHOW_CHAP_COUNT         
    defaults[SETTINGS.SHOW_CHAP_PAGES]              = USER_CONFIG.SHOW_CHAP_PAGES 
    defaults[SETTINGS.SHOW_CHAP_TIME_REMAINING]     = USER_CONFIG.SHOW_CHAP_TIME_REMAINING
    defaults[SETTINGS.DAILY_GOAL]                   = USER_CONFIG.DAILY_GOAL    
    defaults[SETTINGS.SHOW_GOAL_STREAK]             = USER_CONFIG.SHOW_GOAL_STREAK     
    defaults[SETTINGS.SHOW_GOAL_ACHIEVEMENT]        = USER_CONFIG.SHOW_GOAL_ACHIEVEMENT
    defaults[SETTINGS.SHOW_GOAL_PAGES]              = USER_CONFIG.SHOW_GOAL_PAGES
    defaults[SETTINGS.SHOW_BATT_TIME_SEPARATE]      = USER_CONFIG.SHOW_BATT_TIME_SEPARATE
    defaults[SETTINGS.SHOW_BATT_DATE]               = USER_CONFIG.SHOW_BATT_DATE
    defaults[SETTINGS.SHOW_BATT_RATE]               = USER_CONFIG.SHOW_BATT_RATE   
    defaults[SETTINGS.SHOW_BATT_TIME]               = USER_CONFIG.SHOW_BATT_TIME           
    defaults[SETTINGS.MESSAGE_SOURCE]               = USER_CONFIG.MESSAGE_SOURCE           
    defaults[SETTINGS.MSG_HEADER]                   = USER_CONFIG.MSG_HEADER            
    defaults[SETTINGS.CUSTOM_MESSAGE]               = USER_CONFIG.CUSTOM_MESSAGE           
    defaults[SETTINGS.MAX_HIGHLIGHT_LENGTH]         = USER_CONFIG.MAX_HIGHLIGHT_LENGTH
    defaults[SETTINGS.HIGHLIGHT_ADD_QUOTES]         = USER_CONFIG.HIGHLIGHT_ADD_QUOTES  
    defaults[SETTINGS.SHOW_HIGHLIGHT_LOCATION]      = USER_CONFIG.SHOW_HIGHLIGHT_LOCATION  
    defaults[SETTINGS.SHOW_TITLES]                  = USER_CONFIG.SHOW_TITLES      
    defaults[SETTINGS.SHOW_SUBTITLES]               = USER_CONFIG.SHOW_SUBTITLES

    defaults[SETTINGS.SECTION_GAPS_ENABLED]         = USER_CONFIG.SECTION_GAPS_ENABLED
    defaults[SETTINGS.SECTION_GAP_SIZE]             = USER_CONFIG.SECTION_GAP_SIZE
    defaults[SETTINGS.POS]                          = USER_CONFIG.POS
    defaults[SETTINGS.BOX_WIDTH_PCT]                = USER_CONFIG.BOX_WIDTH_PCT
    defaults[SETTINGS.OPACITY]                      = USER_CONFIG.OPACITY
    defaults[SETTINGS.BORDER_SIZE]                  = USER_CONFIG.BORDER_SIZE
    defaults[SETTINGS.BORDER_SIZE_2]                = USER_CONFIG.BORDER_SIZE_2
    defaults[SETTINGS.SECTION_PADDING]              = USER_CONFIG.SECTION_PADDING
    defaults[SETTINGS.ICON_TEXT_GAP]                = USER_CONFIG.ICON_TEXT_GAP
    defaults[SETTINGS.MARGIN]                       = USER_CONFIG.MARGIN

    defaults[SETTINGS.COLOR_BOOK_FILL]              = USER_CONFIG.COLOR_BOOK_FILL
    defaults[SETTINGS.COLOR_CHAPTER_FILL]           = USER_CONFIG.COLOR_CHAPTER_FILL
    defaults[SETTINGS.COLOR_GOAL_FILL]              = USER_CONFIG.COLOR_GOAL_FILL
    defaults[SETTINGS.BATT_HIGH_COLOR]              = USER_CONFIG.BATT_HIGH_COLOR
    defaults[SETTINGS.BATT_MED_COLOR]               = USER_CONFIG.BATT_MED_COLOR
    defaults[SETTINGS.BATT_LOW_COLOR]               = USER_CONFIG.BATT_LOW_COLOR
    defaults[SETTINGS.BATT_CHARGING_COLOR]          = USER_CONFIG.BATT_CHARGING_COLOR
    defaults[SETTINGS.COLOR_MESSAGE_FILL]           = USER_CONFIG.COLOR_MESSAGE_FILL
    defaults[SETTINGS.COLOR_LIGHT]                  = USER_CONFIG.COLOR_LIGHT
    defaults[SETTINGS.COLOR_DARK]                   = USER_CONFIG.COLOR_DARK
    defaults[SETTINGS.ICON_USE_BAR_COLOR]           = USER_CONFIG.ICON_USE_BAR_COLOR
    defaults[SETTINGS.ICON_SET]                     = USER_CONFIG.ICON_SET
    defaults[SETTINGS.ICON_SIZE]                    = USER_CONFIG.ICON_SIZE
    defaults[SETTINGS.BAR_HEIGHT]                   = USER_CONFIG.BAR_HEIGHT
    defaults[SETTINGS.SHOW_ICONS]                   = USER_CONFIG.SHOW_ICONS
    defaults[SETTINGS.SHOW_BARS]                    = USER_CONFIG.SHOW_BARS

    defaults[SETTINGS.FONT_FACE_TITLE]              = USER_CONFIG.FONT_FACE_TITLE
    defaults[SETTINGS.FONT_SIZE_TITLE]              = USER_CONFIG.FONT_SIZE_TITLE
    defaults[SETTINGS.FONT_FACE_SUBTITLE]           = USER_CONFIG.FONT_FACE_SUBTITLE
    defaults[SETTINGS.FONT_SIZE_SUBTITLE]           = USER_CONFIG.FONT_SIZE_SUBTITLE
    defaults[SETTINGS.TEXT_ALIGN]                   = USER_CONFIG.TEXT_ALIGN
    defaults[SETTINGS.BOOK_MULTILINE]               = USER_CONFIG.BOOK_MULTILINE
    defaults[SETTINGS.CHAP_MULTILINE]               = USER_CONFIG.CHAP_MULTILINE
    defaults[SETTINGS.CLEAN_CHAP]                   = USER_CONFIG.CLEAN_CHAP
    defaults[SETTINGS.BOOK_TITLE_BOLD]              = USER_CONFIG.BOOK_TITLE_BOLD
   
    defaults[SETTINGS.BG_DIMMING]                   = USER_CONFIG.BG_DIMMING
    defaults[SETTINGS.BG_DIMMING_COLOR]             = USER_CONFIG.BG_DIMMING_COLOR
    defaults[SETTINGS.BG_TYPE]                      = USER_CONFIG.BG_TYPE
    defaults[SETTINGS.BG_FOLDER]                    = USER_CONFIG.BG_FOLDER
    defaults[SETTINGS.BG_SOLID_COLOR]               = USER_CONFIG.BG_SOLID_COLOR

    defaults[SETTINGS.SHOW_IN_FILEMANAGER]          = USER_CONFIG.SHOW_IN_FILEMANAGER
    defaults[SETTINGS.HIDE_PRELOADED_PRESETS]       = USER_CONFIG.HIDE_PRELOADED_PRESETS
    defaults[SETTINGS.BATT_STAT_TYPE]               = USER_CONFIG.BATT_STAT_TYPE
    defaults[SETTINGS.BATT_MANUAL_RATE]             = USER_CONFIG.BATT_MANUAL_RATE
    defaults[SETTINGS.DEBUG]                        = USER_CONFIG.DEBUG
    
    return defaults
end

local function captureCurrentSettings()
    local snapshot = {}
    local defaults = getDefaultSettings()
    
    for _, setting_key in ipairs(getAllSettingKeys()) do
        local value = G_reader_settings:readSetting(setting_key)

        if value ~= nil then
            snapshot[setting_key] = value
        elseif defaults[setting_key] ~= nil then
            snapshot[setting_key] = defaults[setting_key]
        end
    end
    return snapshot
end

local function getPresets()
    local presets = G_reader_settings:readSetting(SETTINGS.PRESETS) or {}
    
    if not presets["Default"] then
        presets["Default"] = getDefaultSettings()
        G_reader_settings:saveSetting(SETTINGS.PRESETS, presets)
    end
    
    return presets
end

local function savePreset(preset_name, settings_snapshot)
    if not preset_name or preset_name == "" then return false end
    
    local presets = getPresets()
    presets[preset_name] = settings_snapshot or captureCurrentSettings()
    
    G_reader_settings:saveSetting(SETTINGS.PRESETS, presets)
    return true
end

local function loadPreset(preset_name)
    local presets = getPresets()
    local preset = presets[preset_name]
    
    if not preset then return false end
    
    for setting_key, value in pairs(preset) do
        G_reader_settings:saveSetting(setting_key, value)
    end
    
    G_reader_settings:saveSetting(SETTINGS.ACTIVE_PRESET, preset_name)
    invalidateSettingsCache()
    
    return true
end

local function deletePreset(preset_name)
    if preset_name == "Default" then return false end
    
    local presets = getPresets()
    local was_active = G_reader_settings:readSetting(SETTINGS.ACTIVE_PRESET) == preset_name
    
    presets[preset_name] = nil
    G_reader_settings:saveSetting(SETTINGS.PRESETS, presets)
    
    if was_active then
        loadPreset("Default")
    end
    
    return true
end

local function updateActivePreset()
    local active_preset = G_reader_settings:readSetting(SETTINGS.ACTIVE_PRESET)
    if active_preset then
        savePreset(active_preset, captureCurrentSettings())
    end
end

local function getActivePresetName()
    local active = G_reader_settings:readSetting(SETTINGS.ACTIVE_PRESET)
    if not active or active == "None" then
        return "Default"
    end
    return active
end

-------------------------------------------------------------------------
-- Book Data Management
-------------------------------------------------------------------------

local function collectBookData(ui, state)
    if not (ui and ui.document) then return nil end
    
    local data = {}
    
    data.title = safe_get(ui, "doc_props", "display_title") or "Untitled"
    data.authors = safe_get(ui, "doc_props", "authors") or "Unknown Author"
    data.page = safe_get(state, "page") or 1
    data.doc_pages = safe_get(ui, "doc_settings", "data", "doc_pages") or 1
    data.cover_path = safe_get(ui, "document", "file")
    
    if ui.toc then
        local raw_chapter = ui.toc:getTocTitleByPage(data.page) or ""
        local should_clean = G_reader_settings:readSetting(SETTINGS.CLEAN_CHAP)
        if should_clean == nil then should_clean = USER_CONFIG.CLEAN_CHAP end
        data.chapter = should_clean and cleanChapterTitle(raw_chapter) or raw_chapter
        
        data.chapter_pages_done = (ui.toc:getChapterPagesDone(data.page) or 0) + 1
        data.chapter_pages_total = ui.toc:getChapterPageCount(data.page) or 1
        data.chapter_pages_left = ui.toc:getChapterPagesLeft(data.page) or 0
        
        local current_chap, total_chaps = getChapterCount(ui, data.page)
        data.current_chapter_num = current_chap
        data.total_chapters = total_chaps
    end
    
    if ui.statistics then
        data.avg_time = safe_get(ui, "statistics", "avg_time") or 0
        data.id_curr_book = safe_get(ui, "statistics", "id_curr_book")
        
        local day_dur, day_pages = getDailyStats(ui.statistics)
        data.day_duration = day_dur
        data.day_pages = day_pages
    end
    
    if Device:hasBattery() then
        data.battery_percent = Device:getPowerDevice():getCapacity() or 0
        data.battery_charging = Device:getPowerDevice():isCharging()
    end
    
    data.timestamp = os.time()
    
    return data
end

local function saveLastBookData(data)
    if data then
        G_reader_settings:saveSetting(SETTINGS.LAST_BOOK_STATE, data)
    end
end

local function loadLastBookData()
    return G_reader_settings:readSetting(SETTINGS.LAST_BOOK_STATE)
end

-------------------------------------------------------------------------
-- Resource Utilities
-------------------------------------------------------------------------

local function getAvailableIconSets()
    local icon_sets = {}
    local base_path = "icons/customisable-sleep-screen-iconsets"
    
    local dir = ffi.C.opendir(base_path)
    if dir ~= nil then
        local read_ok = pcall(function()
            local entry = ffi.C.readdir(dir)
            while entry ~= nil do
                local name = ffi.string(entry.d_name)
                if name ~= "." and name ~= ".." and entry.d_type == 4 then
                    icon_sets[#icon_sets + 1] = name
                end
                entry = ffi.C.readdir(dir)
            end
        end)
        ffi.C.closedir(dir)
    end
    
    table.sort(icon_sets)
    return icon_sets
end

-------------------------------------------------------------------------
-- Background Images (modified with orientation filter)
-------------------------------------------------------------------------

local function getRandomImageFromFolder(folder_path)
    if not folder_path or folder_path == "" then return nil end
    folder_path = folder_path:gsub("/$", "")
    
    local screen_size = Screen:getSize()
    local w, h = screen_size.w, screen_size.h
    local is_landscape = w > h

    local valid_images = {}
    local dir = ffi.C.opendir(folder_path)
    
    if dir ~= nil then
        local read_ok = pcall(function()
            local entry = ffi.C.readdir(dir)
            while entry ~= nil do
                local name = ffi.string(entry.d_name)
                if name ~= "." and name ~= ".." then
                    local lower = name:lower()

                    -- Is it a valid image?
                    local is_image = lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$")
                    if is_image then
                        local is_landscape_image = lower:match("%.landscape%.") ~= nil

                        -- Filter according to orientation
                        if is_landscape then
                            -- Only .landscape images
                            if is_landscape_image then
                                valid_images[#valid_images + 1] = folder_path .. "/" .. name
                            end
                        else
                            -- Only regular images (no .landscape)
                            if not is_landscape_image then
                                valid_images[#valid_images + 1] = folder_path .. "/" .. name
                            end
                        end
                    end
                end
                entry = ffi.C.readdir(dir)
            end
        end)
        
        ffi.C.closedir(dir)
        
        if not read_ok then
            return nil
        end
    end
    
    if #valid_images == 0 then return nil end
    
    math.randomseed(os.time() + os.clock())
    math.random(); math.random()
    
    local tried = {}
    for i = 1, 3 do
        local idx
        repeat
            idx = math.random(#valid_images)
        until not tried[idx] or i > #valid_images
        
        tried[idx] = true
        local random_file = valid_images[idx]
        
        local ok, image_bb = pcall(function()
            return RenderImage:renderImageFile(random_file, screen_size.w, screen_size.h)
        end)
        
        if ok and image_bb then
            return ImageWidget:new({
                image = image_bb,
                width = screen_size.w,
                height = screen_size.h,
                alpha = true,
            })
        end
    end
    return nil
end

local function buildBackground(ui)
    local bg_type = G_reader_settings:readSetting(SETTINGS.BG_TYPE)
    
    if bg_type == "folder" then
        local folder = G_reader_settings:readSetting(SETTINGS.BG_FOLDER)
        local img = getRandomImageFromFolder(folder)
        if img then 
            return img 
        end
    end
    
    if not (ui and ui.document and ui.bookinfo) then return nil end
    local cover_bb = ui.bookinfo:getCoverImage(ui.document)
    if not cover_bb then return nil end
    
    local screen_size = Screen:getSize()
    local final_bb
    
    if cover_bb:getWidth() == screen_size.w and cover_bb:getHeight() == screen_size.h then
        final_bb = cover_bb
    else
        final_bb = RenderImage:scaleBlitBuffer(cover_bb, screen_size.w, screen_size.h, true)
        if final_bb ~= cover_bb and cover_bb.free then
            cover_bb:free()
        end
    end

    return ImageWidget:new({
        image = final_bb,
        width = screen_size.w,
        height = screen_size.h,
        alpha = true,
    })
end

------------------------------------------------------------
-- UI Widget
------------------------------------------------------------

local ColorWheelWidget = FocusManager:extend {
    title_text = "Pick a colour",
    width = nil,
    width_factor = 0.6,
    hue = 0,
    saturation = 1,
    value = 1,
    invert_in_night_mode = true,
    cancel_text = "Cancel",
    ok_text = "Apply",
    callback = nil,
    cancel_callback = nil,
    close_callback = nil,
}

local function hsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c

    local r, g, b
    if h < 60 then
        r, g, b = c, x, 0
    elseif h < 120 then
        r, g, b = x, c, 0
    elseif h < 180 then
        r, g, b = 0, c, x
    elseif h < 240 then
        r, g, b = 0, x, c
    elseif h < 300 then
        r, g, b = x, 0, c
    else
        r, g, b = c, 0, x
    end

    return
        math.floor((r + m) * 255 + 0.5),
        math.floor((g + m) * 255 + 0.5),
        math.floor((b + m) * 255 + 0.5)
end

local ColorWheel = WidgetContainer:extend {
    radius = 0,
    hue = 0,
    saturation = 1,
    value = 1,
    invert_in_night_mode = true,
}

function ColorWheel:init()
    self.radius = math.floor(self.dimen.w / 2)
    self.dimen = Geom:new {
        x = 0,
        y = 0,
        w = self.dimen.w,
        h = self.dimen.h,
    }
    self.night_mode = self.invert_in_night_mode and G_reader_settings:isTrue("night_mode")
end

function ColorWheel:paintTo(bb, x, y)
    self.dimen.x = x
    self.dimen.y = y

    local cx = x + self.radius
    local cy = y + self.radius

    for py = -self.radius, self.radius do
        for px = -self.radius, self.radius do
            local dist = math.sqrt(px * px + py * py)
            if dist <= self.radius then
                local angle = (math.deg(math.atan2(py, px)) + 360) % 360
                local sat = dist / self.radius

                local r, g, b = hsvToRgb(angle, sat, self.value)

                if self.night_mode then
                    r = 255 - r
                    g = 255 - g
                    b = 255 - b
                end

                local color
                if bb:getType() == Blitbuffer.TYPE_BBRGB32 then
                    color = Blitbuffer.ColorRGB32(r, g, b, 0xFF)
                elseif bb:getType() == Blitbuffer.TYPE_BBRGB24 then
                    color = Blitbuffer.ColorRGB24(r, g, b)
                elseif bb:getType() == Blitbuffer.TYPE_BBRGB16 then
                    color = Blitbuffer.ColorRGB24(r, g, b)
                else
                    color = Blitbuffer.Color8(math.floor((r * 0.299 + g * 0.587 + b * 0.114) + 0.5))
                end
                bb:setPixel(cx + px, cy + py, color)
            end
        end
    end

    local sel_angle = math.rad(self.hue)
    local sel_dist = self.saturation * self.radius
    local sel_x = cx + math.floor(math.cos(sel_angle) * sel_dist + 0.5)
    local sel_y = cy + math.floor(math.sin(sel_angle) * sel_dist + 0.5)

    for py = -4, 4 do
        for px = -4, 4 do
            local d = px * px + py * py
            if d <= 16 then
                bb:setPixelClamped(sel_x + px, sel_y + py, Blitbuffer.COLOR_WHITE)
            end
            if d <= 9 then
                bb:setPixelClamped(sel_x + px, sel_y + py, Blitbuffer.COLOR_BLACK)
            end
        end
    end
end

function ColorWheel:updateColor(ges_pos)
    if not self.dimen then
        return false
    end

    local cx = self.dimen.x + self.radius
    local cy = self.dimen.y + self.radius
    local dx = ges_pos.x - cx
    local dy = ges_pos.y - cy

    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > self.radius then
        return false
    end

    self.hue = (math.deg(math.atan2(dy, dx)) + 360) % 360
    self.saturation = math.min(1, dist / self.radius)

    if self.update_callback then
        self.update_callback()
    end

    return true
end

function ColorWheelWidget:init()
    self.screen_width = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    self.medium_font_face = Font:getFace("ffont")

    if not self.width then
        self.width = math.floor(
            math.min(self.screen_width, self.screen_height) * self.width_factor
        )
    end

    self.inner_width = self.width - 2 * Size.padding.large
    self.button_width = math.floor(self.inner_width / 4)

    if Device:isTouchDevice() then
        self.ges_events = {
            TapColorWheel = {
                GestureRange:new {
                    ges = "tap",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = self.screen_width,
                        h = self.screen_height,
                    }
                }
            },
            PanColorWheel = {
                GestureRange:new {
                    ges = "pan",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = self.screen_width,
                        h = self.screen_height,
                    }
                }
            },
        }
    end

    self:update()
end

function ColorWheelWidget:update()
    local wheel_size = self.width - 2 * Size.padding.large

    self.color_wheel = ColorWheel:new {
        dimen = Geom:new {
            w = wheel_size,
            h = wheel_size,
        },
        hue = self.hue,
        saturation = self.saturation,
        value = self.value,
        invert_in_night_mode = self.invert_in_night_mode,
        update_callback = function()
            self.hue = self.color_wheel.hue
            self.saturation = self.color_wheel.saturation
            self:update()
        end,
    }

    local title_bar = TitleBar:new {
        width = self.width,
        title = self.title_text,
        with_bottom_line = true,
        close_button = true,
        close_callback = function()
            self:onCancel()
        end,
        show_parent = self,
    }

    local value_minus = Button:new {
        text = "−",
        enabled = self.value > 0,
        width = self.button_width,
        show_parent = self,
        callback = function()
            self.value = math.max(0, self.value - 0.1)
            self:update()
        end,
    }

    local value_plus = Button:new {
        text = "＋",
        enabled = self.value < 1,
        width = self.button_width,
        show_parent = self,
        callback = function()
            self.value = math.min(1, self.value + 0.1)
            self:update()
        end,
    }

    local value_label = TextWidget:new {
        text = string.format("Brightness: %d%%", math.floor(self.value * 100)),
        face = self.medium_font_face,
    }

    local value_group = HorizontalGroup:new {
        align = "center",
        value_minus,
        HorizontalSpan:new { width = Size.padding.large },
        value_label,
        HorizontalSpan:new { width = Size.padding.large },
        value_plus,
    }

    local r, g, b = hsvToRgb(self.hue, self.saturation, self.value)
    local hex_text = string.format("#%02X%02X%02X", r, g, b)

    local preview_size = math.floor(wheel_size / 4)

    local night_mode = self.invert_in_night_mode and G_reader_settings:isTrue("night_mode")
    local preview_r, preview_g, preview_b = r, g, b

    if night_mode then
        preview_r = 255 - r
        preview_g = 255 - g
        preview_b = 255 - b
    end

    local ColorPreview = WidgetContainer:extend {
        dimen = Geom:new {
            w = preview_size,
            h = preview_size,
        },
    }

    function ColorPreview:paintTo(bb, x, y)
        bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h,
            Blitbuffer.ColorRGB32(preview_r, preview_g, preview_b, 0xFF))
    end

    self.color_preview = FrameContainer:new {
        bordersize = Size.border.thick,
        margin = 0,
        padding = 0,
        ColorPreview:new {},
    }

    local hex_label = TextWidget:new {
        text = hex_text,
        face = Font:getFace("infofont", 20),
    }

    local preview_group = HorizontalGroup:new {
        align = "center",
        self.color_preview,
        HorizontalSpan:new { width = Size.padding.large },
        hex_label,
    }

    local input_button = Button:new {
        text = "Enter hex",
        width = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback = function()
            local input_dialog
            input_dialog = InputDialog:new {
                title = "Enter colour code",
                input = hex_text,
                input_hint = "#000000",
                buttons = {
                    {
                        {
                            text = "Cancel",
                            callback = function()
                                UIManager:close(input_dialog)
                            end,
                        },
                        {
                            text = "Apply",
                            is_enter_default = true,
                            callback = function()
                                local text = input_dialog:getInputText()
                                if text and text:match("^#%x%x%x%x%x%x$") then
                                    local r = tonumber(text:sub(2,3), 16) / 255
                                    local g = tonumber(text:sub(4,5), 16) / 255
                                    local b = tonumber(text:sub(6,7), 16) / 255
                                    
                                    local max = math.max(r, g, b)
                                    local min = math.min(r, g, b)
                                    local delta = max - min
                                    
                                    self.value = max
                                    self.saturation = (max > 0) and (delta / max) or 0
                                    
                                    if delta > 0 then
                                        if max == r then
                                            self.hue = 60 * (((g - b) / delta) % 6)
                                        elseif max == g then
                                            self.hue = 60 * (((b - r) / delta) + 2)
                                        else
                                            self.hue = 60 * (((r - g) / delta) + 4)
                                        end
                                    else
                                        self.hue = 0
                                    end
                                    
                                    if self.hue < 0 then
                                        self.hue = self.hue + 360
                                    end
                                    
                                    UIManager:close(input_dialog)
                                    self:update()
                                end
                            end,
                        },
                    },
                },
            }
            UIManager:show(input_dialog)
            input_dialog:onShowKeyboard()
        end,
    }

    local cancel_button = Button:new {
        text = self.cancel_text,
        width = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback = function()
            self:onCancel()
        end,
    }

    local ok_button = Button:new {
        text = self.ok_text,
        width = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback = function()
            self:onApply()
        end,
    }

    local button_row = HorizontalGroup:new {
        align = "center",
        cancel_button,
        HorizontalSpan:new { width = Size.padding.small },
        input_button,
        HorizontalSpan:new { width = Size.padding.small },
        ok_button,
    }

    local vgroup = VerticalGroup:new {
        align = "center",
        title_bar,
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = value_label:getSize().h + Size.padding.default,
            },
            value_group,
        },
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = wheel_size + Size.padding.large * 2,
            },
            self.color_wheel,
        },
        VerticalSpan:new { width = Size.padding.large },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = preview_size + Size.padding.default,
            },
            preview_group,
        },
        VerticalSpan:new { width = Size.padding.large * 2 },
        CenterContainer:new {
            dimen = Geom:new {
                w = self.width,
                h = Size.item.height_default,
            },
            button_row,
        },
        VerticalSpan:new { width = Size.padding.default },
    }

    self.frame = FrameContainer:new {
        radius = Size.radius.window,
        bordersize = Size.border.window,
        background = Blitbuffer.COLOR_WHITE,
        vgroup,
    }

    self.movable = MovableContainer:new {
        self.frame,
    }

    self[1] = CenterContainer:new {
        dimen = Geom:new {
            x = 0, y = 0,
            w = self.screen_width,
            h = self.screen_height,
        },
        self.movable,
    }

    UIManager:setDirty(self, "ui")
end

function ColorWheelWidget:onTapColorWheel(arg, ges_ev)
    if not self.color_wheel.dimen or not self.frame.dimen then
        return true
    end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        if self.color_wheel:updateColor(ges_ev.pos) then
            self:update()
        end
        return true
    elseif not ges_ev.pos:intersectWith(self.frame.dimen) and ges_ev.ges == "tap" then
        self:onCancel()
        return true
    end
    return false
end

function ColorWheelWidget:onPanColorWheel(arg, ges_ev)
    if not self.color_wheel.dimen then
        return false
    end

    if ges_ev.pos:intersectWith(self.color_wheel.dimen) then
        if self.color_wheel:updateColor(ges_ev.pos) then
            self:update()
        end
        return true
    end
    return false
end

function ColorWheelWidget:onApply()
    UIManager:close(self)
    if self.callback then
        local r, g, b = hsvToRgb(self.hue, self.saturation, self.value)
        local hex = string.format("#%02X%02X%02X", r, g, b)
        self.callback(hex)
    end
    if self.close_callback then
        self.close_callback()
    end
    return true
end

function ColorWheelWidget:onCancel()
    UIManager:close(self)
    if self.cancel_callback then
        self.cancel_callback()
    end
    if self.close_callback then
        self.close_callback()
    end
    return true
end

function ColorWheelWidget:onShow()
    UIManager:setDirty(self, "ui")
    return true
end

-------------------------------------------------------------------------
-- UI Builders
-------------------------------------------------------------------------

local function buildSection(total_width, title, subtitle, icon_name, progress, colors, bar_height, 
                           allow_title_multiline, allow_subtitle_multiline, title_face, subtitle_face, text_align, title_bold)
    local icon_size = Screen:scaleBySize(clamp(getSetting("ICON_SIZE"), 16, 128))
    local padding = Screen:scaleBySize(getSetting("SECTION_PADDING"))
    local icon_gap = Screen:scaleBySize(getSetting("ICON_TEXT_GAP"))
    local show_icons = G_reader_settings:readSetting(SETTINGS.SHOW_ICONS) ~= false
    
    local text_width = total_width - (2 * padding)
    if show_icons then
        text_width = text_width - icon_size - icon_gap
    end
    
    local header_widgets = {}

    if show_icons then
        local icon_widget
        local use_bar_color = G_reader_settings:readSetting(SETTINGS.ICON_USE_BAR_COLOR)
        if use_bar_color == nil then use_bar_color = USER_CONFIG.ICON_USE_BAR_COLOR end

        local icon_set = getSetting("ICON_SET")
        local base_path = "icons/customisable-sleep-screen-iconsets/" .. icon_set .. "/" .. icon_name
        
        local icon_path = nil
        local is_svg = false
        if io.open(base_path .. ".svg", "r") then
            icon_path = base_path .. ".svg"
            is_svg = true
        elseif io.open(base_path .. ".png", "r") then
            icon_path = base_path .. ".png"
        elseif io.open(base_path .. ".jpg", "r") then
            icon_path = base_path .. ".jpg"
        end

        if icon_path then
            if is_svg and use_bar_color then
                local color_hex = colors.fill_hex
                local ok, result = pcall(function()
                    local f = io.open(icon_path, "rb")
                    if not f then error("Could not open icon") end
                    local svg_content = f:read("*all")
                    f:close()

                    svg_content = svg_content:gsub('fill%s*=%s*"[^"]*"', 'fill="' .. color_hex .. '"')
                    svg_content = svg_content:gsub("fill%s*=%s*'[^']*'", "fill='" .. color_hex .. "'")
                    svg_content = svg_content:gsub('currentColor', color_hex)

                    local temp_path = "/tmp/temp_icon_" .. icon_name .. ".svg"
                    local temp_f = io.open(temp_path, "wb")
                    temp_f:write(svg_content)
                    temp_f:close()
                    
                    local render_ok, bb = pcall(RenderImage.renderSVGImageFile, RenderImage, temp_path, icon_size, icon_size)
                    os.remove(temp_path)
                    if not render_ok then error("SVG fail") end
                    return bb
                end)

                if ok and result then
                    icon_widget = ImageWidget:new{ image = result, width = icon_size, height = icon_size, alpha = true }
                end
            else
                local ok, bb = pcall(function()
                    if is_svg then
                        return RenderImage:renderSVGImageFile(icon_path, icon_size, icon_size)
                    else
                        return RenderImage:renderImageFile(icon_path, icon_size, icon_size)
                    end
                end)
                if ok and bb then
                    icon_widget = ImageWidget:new{ image = bb, width = icon_size, height = icon_size, alpha = true }
                end
            end
        end

        if not icon_widget then
            icon_widget = IconWidget:new{
                icon = icon_name,
                width = icon_size,
                height = icon_size,
                fgcolor = use_bar_color and colors.fill or colors.text,
                alpha = true,
            }
        end
        
        header_widgets[#header_widgets + 1] = FrameContainer:new{
            padding = 0,
            bordersize = 0,
            background = colors.bg,
            icon_widget
        }
        header_widgets[#header_widgets + 1] = HorizontalSpan:new{ 
            width = icon_gap
        }
    end

    if not text_align then
        text_align = getSetting("TEXT_ALIGN")
    end

    local title_widget, subtitle_widget

    if allow_title_multiline and text_align ~= "left" then
        local title_lines = wrapText(title, title_face, text_width)
        title_widget = VerticalGroup:new{ align = "left" }
        for i, line in ipairs(title_lines) do
            local line_w = getTextWidth(line, title_face)
            local padding = 0
            if text_align == "center" then
                padding = (text_width - line_w) / 2
            elseif text_align == "right" then
                padding = text_width - line_w
            end
            
            local line_container = HorizontalGroup:new{
                HorizontalSpan:new{ width = padding },
                TextWidget:new{ text = line, face = title_face, fgcolor = colors.text, bold = title_bold }
            }
            title_widget[#title_widget + 1] = line_container
        end
    else
        title_widget = createMultiLineText(title, title_face, colors.text, text_width, allow_title_multiline, "left", title_bold)
        if text_align ~= "left" and title_widget.getSize then
            local title_w = title_widget:getSize().w
            local padding = text_align == "center" and (text_width - title_w) / 2 or (text_width - title_w)
            title_widget = HorizontalGroup:new{
                HorizontalSpan:new{ width = padding },
                title_widget
            }
        end
    end

    if type(subtitle) == "table" then
        subtitle_widget = VerticalGroup:new{ align = "left" }
        for i = 1, #subtitle do
            local child = subtitle[i]
            if child.text then
                local wrapped_lines = wrapText(child.text, subtitle_face, text_width)
                
                for j, wrapped_line in ipairs(wrapped_lines) do
                    if text_align == "left" then
                        subtitle_widget[#subtitle_widget + 1] = TextWidget:new{ 
                            text = wrapped_line, 
                            face = subtitle_face, 
                            fgcolor = colors.subtext 
                        }
                    else
                        local line_w = getTextWidth(wrapped_line, subtitle_face)
                        local padding = 0
                        if text_align == "center" then
                            padding = (text_width - line_w) / 2
                        elseif text_align == "right" then
                            padding = text_width - line_w
                        end
                        
                        local line_container = HorizontalGroup:new{
                            HorizontalSpan:new{ width = padding },
                            TextWidget:new{ text = wrapped_line, face = subtitle_face, fgcolor = colors.subtext }
                        }
                        subtitle_widget[#subtitle_widget + 1] = line_container
                    end
                end
            end
        end
    elseif allow_subtitle_multiline and text_align ~= "left" then
        local subtitle_lines = wrapText(subtitle, subtitle_face, text_width)
        subtitle_widget = VerticalGroup:new{ align = "left" }
        for i, line in ipairs(subtitle_lines) do
            local line_w = getTextWidth(line, subtitle_face)
            local padding = 0
            if text_align == "center" then
                padding = (text_width - line_w) / 2
            elseif text_align == "right" then
                padding = text_width - line_w
            end
            
            local line_container = HorizontalGroup:new{
                HorizontalSpan:new{ width = padding },
                TextWidget:new{ text = line, face = subtitle_face, fgcolor = colors.subtext }
            }
            subtitle_widget[#subtitle_widget + 1] = line_container
        end
    else
        subtitle_widget = createMultiLineText(subtitle, subtitle_face, colors.subtext, text_width, allow_subtitle_multiline, "left", use_text_bar_color, colors.fill)
        if text_align ~= "left" and subtitle_widget.getSize then
            local subtitle_w = subtitle_widget:getSize().w
            local padding = text_align == "center" and (text_width - subtitle_w) / 2 or (text_width - subtitle_w)
            subtitle_widget = HorizontalGroup:new{
                HorizontalSpan:new{ width = padding },
                subtitle_widget
            }
        end
    end

    local show_titles = G_reader_settings:readSetting(SETTINGS.SHOW_TITLES)
    if show_titles == nil then show_titles = true end
    
    local show_subtitles = G_reader_settings:readSetting(SETTINGS.SHOW_SUBTITLES)
    if show_subtitles == nil then show_subtitles = true end
    
    local text_group
    if show_titles and show_subtitles and subtitle then
        text_group = VerticalGroup:new{
            align = "left",
            width = text_width,
            title_widget,
            VerticalSpan:new{ width = Screen:scaleBySize(0) },
            subtitle_widget,
        }
    elseif show_titles and not show_subtitles then
        text_group = VerticalGroup:new{
            align = "left",
            width = text_width,
            title_widget,
        }
    elseif not show_titles and show_subtitles and subtitle then
        text_group = VerticalGroup:new{
            align = "left",
            width = text_width,
            subtitle_widget,
        }
    else
        text_group = VerticalGroup:new{
            align = "left",
            width = text_width,
            title_widget,
        }
    end
    
    header_widgets[#header_widgets + 1] = text_group
    
    local header_container = FrameContainer:new{
        width = total_width,
        bordersize = 0,
        padding = padding,
        background = colors.bg,
        HorizontalGroup:new(header_widgets)
    }

    local section_group = VerticalGroup:new{
        align = "left",
        width = total_width,
        header_container
    }

    local show_bars = G_reader_settings:readSetting(SETTINGS.SHOW_BARS) ~= false
    local scaled_bar_height = Screen:scaleBySize(bar_height)

    if show_bars then
        section_group[#section_group + 1] = ProgressWidget:new{
            width = total_width,
            height = scaled_bar_height,
            bgcolor = colors.bar_bg,
            fillcolor = colors.fill,
            percentage = clamp(progress or 0, 0, 1),
            show_perc = false,
            bordersize = 0,
            padding = 0,
            margin_h = 0,
            margin_v = 0,
        }
    else
        section_group[#section_group + 1] = FrameContainer:new{
            width = total_width,
            height = scaled_bar_height,
            bordersize = 0,
            padding = 0,
            background = Blitbuffer.COLOR_TRANSPARENT,
            HorizontalSpan:new{ width = total_width }
        }
    end

    return section_group
end

-------------------------------------------------------------------------
-- Extracted Utilities
-------------------------------------------------------------------------

local function resolveFont(font_name)
    if font_name == "cfont" or font_name == nil or font_name == "" then
        return "cfont"
    end
    
    if font_name:match("/") or font_name:match("%.ttf$") or font_name:match("%.otf$") or font_name:match("%.ttc$") then
        return font_name
    end
    
    local available_fonts = Font.fontmap or {}
    
    if available_fonts[font_name] then
        return font_name
    end
    
    local cre_engine = cre:engineInit()
    if cre_engine and cre_engine.getFontFaceFilenameAndFaceIndex then
        local font_path = cre_engine.getFontFaceFilenameAndFaceIndex(font_name)
        if font_path then
            return font_path
        end
    end
    
    return "cfont"
end

local function setupRenderingContext()
    local settings_cache = getSettingsCache()

    local title_path = resolveFont(settings_cache.title_face_name)
    local subtitle_path = resolveFont(settings_cache.subtitle_face_name)

    local title_face = getCachedFont(title_path, Screen:scaleBySize(settings_cache.title_size))
    local subtitle_face = getCachedFont(subtitle_path, Screen:scaleBySize(settings_cache.subtitle_size))

    local dark = G_reader_settings:isTrue(SETTINGS.DARK_MODE)
    local is_mono = G_reader_settings:isTrue(SETTINGS.MONOCHROME)

    local color_dark_hex = getSetting("COLOR_DARK")
    local color_light_hex = getSetting("COLOR_LIGHT")
    local mono_hex = dark and color_dark_hex or color_light_hex
    local mono_color = getCachedColor(mono_hex)

    local color_config = getColors(is_mono, mono_hex, mono_color)
    
    color_config.is_mono = is_mono
    color_config.mono_color = mono_color
    color_config.mono_hex = mono_hex

    local colors = {
        bg      = dark and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
        text    = dark and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        subtext = dark and Blitbuffer.COLOR_GRAY_E or Blitbuffer.COLOR_GRAY_3,
        bar_bg  = dark and Blitbuffer.COLOR_GRAY_3 or Blitbuffer.COLOR_GRAY_E,
        border  = dark and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK,
        border_2 = dark and Blitbuffer.COLOR_BLACK or Blitbuffer.COLOR_WHITE,
    }

    return title_face, subtitle_face, colors, color_config, settings_cache
end

local function getBatteryDisplayInfo()
    local batt_perc = Device:hasBattery() and Device:getPowerDevice():getCapacity() or 0
    local is_charging = Device:getPowerDevice():isCharging()
    local batt_stat_type = getSetting("BATT_STAT_TYPE")
    
    local battery_hours_left = 0
    
    if batt_stat_type == "manual" then
        local manual_rate = getSetting("BATT_MANUAL_RATE")
        battery_hours_left = math.floor(batt_perc / math.max(manual_rate, 0.1))
    else
        local battery_time_seconds = nil
        
        local BatteryStat = package.loaded["plugins.batterystat.main"]
        if BatteryStat then
            local stat_obj = type(BatteryStat.stat) == "function" and BatteryStat:stat() or BatteryStat
            
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
            local ok_time, time_module = pcall(require, "ui/time")
            local ok_settings, LuaSettings = pcall(require, "luasettings")
            
            if ok_time and ok_settings then
                local ok_open, batt_settings = pcall(LuaSettings.open, LuaSettings, 
                    DataStorage:getSettingsDir() .. "/battery_stats.lua")
                
                if ok_open and batt_settings then
                    local stat_data = batt_settings:readSetting(batt_stat_type)
                    if stat_data and type(stat_data.percentage) == "number" 
                       and type(stat_data.time) == "number" 
                       and stat_data.time > 0 
                       and stat_data.percentage > 0 then
                        local time_seconds = time_module.to_s(stat_data.time)
                        local rate_per_second = stat_data.percentage / time_seconds
                        if rate_per_second > 0.01 then
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
            battery_hours_left = math.floor(battery_time_seconds / SECONDS_PER_HOUR)
        else
            local manual_rate = getSetting("BATT_MANUAL_RATE")
            battery_hours_left = math.floor(batt_perc / math.max(manual_rate, 0.1))
        end
    end
    
    return {
        percent = batt_perc,
        is_charging = is_charging,
        hours_left = battery_hours_left,
    }
end

local function calculateWidgetPosition(border_wrap, settings_cache)
    local screen_size = Screen:getSize()
    local widget_size = border_wrap:getSize()
    
    local total_border_size = settings_cache.border_size + (settings_cache.border_size > 0 and settings_cache.border_size_2 or 0)
    
    local x_off = 0
    local y_off = 0
    
    if settings_cache.pos:find("center") or settings_cache.pos == "middle_center" then
        x_off = (screen_size.w - widget_size.w) / 2
    elseif settings_cache.pos:find("right") then
        x_off = screen_size.w - widget_size.w
    else
        x_off = 0
    end

    if settings_cache.pos:find("middle") or settings_cache.pos == "center" then
        y_off = (screen_size.h - widget_size.h) / 2
    elseif settings_cache.pos:find("top") then
        y_off = settings_cache.margin
    else
        y_off = screen_size.h - widget_size.h - settings_cache.margin
    end
    
    if total_border_size > 0 then
        if settings_cache.pos == "top" or settings_cache.pos == "top_left" or 
           settings_cache.pos == "top_center" or settings_cache.pos == "top_right" then
            y_off = y_off - total_border_size
        end
        
        if settings_cache.pos == "bottom" or settings_cache.pos == "bottom_left" or 
           settings_cache.pos == "bottom_center" or settings_cache.pos == "bottom_right" then
            y_off = y_off + total_border_size
        end
        
        if settings_cache.pos == "top_left" or settings_cache.pos == "middle_left" or 
           settings_cache.pos == "bottom_left" then
            x_off = x_off - total_border_size
        end
        
        if settings_cache.pos == "top_right" or settings_cache.pos == "middle_right" or 
           settings_cache.pos == "bottom_right" then
            x_off = x_off + total_border_size
        end
    end
    
    return x_off, y_off
end

local function buildDimmingLayer(settings_cache)
    local screen_size = Screen:getSize()
    
    if settings_cache.dim_val > 0 then
        if G_reader_settings:isTrue(SETTINGS.DEBUG) then
            log_memory("BEFORE Dimming Layer")
        end
        
        local dim_color_hex = getSetting("BG_DIMMING_COLOR")
        
        local r = tonumber(dim_color_hex:sub(2, 3), 16) or 0
        local g = tonumber(dim_color_hex:sub(4, 5), 16) or 0
        local b = tonumber(dim_color_hex:sub(6, 7), 16) or 0
        
        local tiny_bb = Blitbuffer.new(1, 1, Blitbuffer.TYPE_BBRGB24)
        local color = ffi.new("ColorRGB24", r, g, b)
        tiny_bb:setPixel(0, 0, color)
        
        local dim_bb = RenderImage:scaleBlitBuffer(tiny_bb, screen_size.w, screen_size.h, true)
        
        if G_reader_settings:isTrue(SETTINGS.DEBUG) then
            log_memory("AFTER Scaling Dimming Layer")
        end

        local dim_image = ImageWidget:new{
            image = dim_bb,
            width = screen_size.w,
            height = screen_size.h,
        }
        
        local dimming_layer = AlphaContainer:new{
            alpha = settings_cache.dim_val / 255,
            dim_image
        }
        
        tiny_bb:free()

        if G_reader_settings:isTrue(SETTINGS.DEBUG) then
            log_memory("AFTER Dimming Layer Complete")
        end
        
        return dimming_layer
    else
        return HorizontalSpan:new{ width = 0 }
    end
end

local function buildBackgroundWidget(ui, book_data)
    local screen_size = Screen:getSize()
    local bg_type = G_reader_settings:readSetting(SETTINGS.BG_TYPE)
    
    if bg_type == "transparent" then
        return nil
    end

    if bg_type == "solid" then
        local solid_color = G_reader_settings:readSetting(SETTINGS.BG_SOLID_COLOR)
        if solid_color == nil then
            solid_color = USER_CONFIG.BG_SOLID_COLOR
        end
        
        local r = tonumber(solid_color:sub(2, 3), 16) or 44
        local g = tonumber(solid_color:sub(4, 5), 16) or 62
        local b = tonumber(solid_color:sub(6, 7), 16) or 80
        
        local tiny_bb = Blitbuffer.new(1, 1, Blitbuffer.TYPE_BBRGB24)
        local color = ffi.new("ColorRGB24", r, g, b)
        tiny_bb:setPixel(0, 0, color)
        
        local scaled_bb = RenderImage:scaleBlitBuffer(tiny_bb, screen_size.w, screen_size.h, true)
        
        tiny_bb:free()
        
        return ImageWidget:new{
            image = scaled_bb,
            width = screen_size.w,
            height = screen_size.h,
        }
    end

    if bg_type == "folder" then
        local folder = G_reader_settings:readSetting(SETTINGS.BG_FOLDER)
        return getRandomImageFromFolder(folder)
    end
    
    if ui and ui.document then
        return buildBackground(ui)
    end
    
    if book_data and book_data.cover_path then
        local lfs = require("libs/libkoreader-lfs")
        local cover_path = book_data.cover_path
        local attrs = lfs and lfs.attributes(cover_path, "mode")
        
        if attrs == "file" then
            local ok, cover_bb = pcall(function()
                local DocumentRegistry = require("document/documentregistry")
                local doc = DocumentRegistry:openDocument(cover_path)
                if not doc then return nil end
                
                local cover = nil
                if doc.getCoverPageImage then
                    local ok_cover, img = pcall(doc.getCoverPageImage, doc)
                    if ok_cover then cover = img end
                end
                doc:close()
                return cover
            end)
            
            if ok and cover_bb then
                local scaled_bb = RenderImage:scaleBlitBuffer(cover_bb, screen_size.w, screen_size.h, true)
                return ImageWidget:new{
                    image = scaled_bb,
                    width = screen_size.w,
                    height = screen_size.h,
                    alpha = true,
                }
            end
        end
    end
    
    return nil
end

-------------------------------------------------------------------------
-- Main Builder
-------------------------------------------------------------------------

local function buildInfoBox(ui, state, book_data)

    local has_ui = (ui and ui.document)
    
    local title_face, subtitle_face, colors, color_config, settings_cache = setupRenderingContext()
    
    local total_width = math.floor(Screen:getWidth() * (settings_cache.box_width_pct / 100))
    local section_list = {}
    
    local section_builders = {
        book = function()
            if G_reader_settings:readSetting(SETTINGS.SHOW_BOOK) ~= false then
                local book_title, page_now, page_total, avg_time, authors
                
                if has_ui then
                    book_title = safe_get(ui, "doc_props", "display_title") or "Untitled"
                    authors = safe_get(ui, "doc_props", "authors") or "Unknown Author"
                    page_now = safe_get(state, "page") or 1
                    page_total = safe_get(ui, "doc_settings", "data", "doc_pages") or 1
                    avg_time = safe_get(ui, "statistics", "avg_time") or 0
                else
                    book_title = book_data.title or "Untitled"
                    authors = book_data.authors or "Unknown Author"
                    page_now = book_data.page or 1
                    page_total = book_data.doc_pages or 1
                    avg_time = book_data.avg_time or 0
                end
                
                local time_left_str = formatDuration(avg_time * (page_total - page_now))
                local progress_line = string.format("%d%%%s", math.floor(page_now / page_total * 100),
                    time_left_str and " · " .. time_left_str .. " left" or "")
                
                local book_subtitle
                if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR) or G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES) then
                    book_subtitle = VerticalGroup:new{ align = "left" }
                    
                    if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR) then
                        book_subtitle[#book_subtitle+1] = TextWidget:new{
                            text = authors, face = subtitle_face, fgcolor = colors.subtext
                        }
                    end

                    if G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES) then
                        local page_str = string.format("Page %d of %d", page_now, page_total)
                        book_subtitle[#book_subtitle+1] = TextWidget:new{
                            text = page_str, face = subtitle_face, fgcolor = colors.subtext
                        }
                    end

                    book_subtitle[#book_subtitle+1] = TextWidget:new{
                        text = progress_line, face = subtitle_face, fgcolor = colors.subtext
                    }
                else
                    book_subtitle = progress_line
                end

                local allow_multiline = G_reader_settings:readSetting(SETTINGS.BOOK_MULTILINE)
                if allow_multiline == nil then allow_multiline = USER_CONFIG.BOOK_MULTILINE end
                
                return buildSection(total_width, book_title, book_subtitle, "custom_book", 
                    page_now / page_total, 
                    {bg=colors.bg, text=colors.text, subtext=colors.subtext, bar_bg=colors.bar_bg, 
                     fill=color_config.book, fill_hex=color_config.book_hex}, 
                    settings_cache.custom_bar_height, allow_multiline, true, title_face, subtitle_face, nil, settings_cache.book_title_bold)
            end
        end,
        
        chapter = function()
            if G_reader_settings:readSetting(SETTINGS.SHOW_CHAP) ~= false then
                local chap_title, c_done, c_tot, pages_left, avg_time
                local current_chap_num, total_chapters
                
                if has_ui and ui.toc then
                    local page_now = safe_get(state, "page") or 1
                    local raw = ui.toc:getTocTitleByPage(page_now) or ""
                    local should_clean = G_reader_settings:readSetting(SETTINGS.CLEAN_CHAP)
                    if should_clean == nil then should_clean = USER_CONFIG.CLEAN_CHAP end
                    chap_title = should_clean and cleanChapterTitle(raw) or raw
                    
                    c_done = (ui.toc:getChapterPagesDone(page_now) or 0) + 1
                    c_tot = ui.toc:getChapterPageCount(page_now) or 1
                    pages_left = ui.toc:getChapterPagesLeft(page_now) or 0
                    avg_time = safe_get(ui, "statistics", "avg_time") or 0
                    
                    current_chap_num, total_chapters = getChapterCount(ui, page_now)
                elseif book_data and book_data.chapter then
                    chap_title = book_data.chapter
                    c_done = book_data.chapter_pages_done or 1
                    c_tot = book_data.chapter_pages_total or 1
                    pages_left = book_data.chapter_pages_left or 0
                    avg_time = book_data.avg_time or 0
                    current_chap_num = book_data.current_chapter_num
                    total_chapters = book_data.total_chapters
                else
                    return nil
                end
                
                local chap_progress = c_done / math.max(c_tot, 1)
                local time_left = formatDuration(avg_time * pages_left)
                local chap_sub = string.format("%d%%%s", math.floor(chap_progress * 100), 
                    time_left and " · " .. time_left .. " left" or "")
                
                local final_subtitle = chap_sub
                local show_chap_count = G_reader_settings:readSetting(SETTINGS.SHOW_CHAP_COUNT)
                local show_chap_pages = G_reader_settings:readSetting(SETTINGS.SHOW_CHAP_PAGES)
                
                if show_chap_count or show_chap_pages then
                    final_subtitle = VerticalGroup:new{ align = "left" }
                    
                    if show_chap_count and current_chap_num and total_chapters then
                        final_subtitle[#final_subtitle+1] = TextWidget:new{
                            text = string.format("Chapter %d of %d", current_chap_num, total_chapters),
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                    
                    if show_chap_pages then
                        final_subtitle[#final_subtitle+1] = TextWidget:new{
                            text = string.format("Page %d of %d", c_done, c_tot),
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                    
                    final_subtitle[#final_subtitle+1] = TextWidget:new{
                        text = chap_sub,
                        face = subtitle_face, 
                        fgcolor = colors.subtext
                    }
                end
                
                local allow_multiline = G_reader_settings:readSetting(SETTINGS.CHAP_MULTILINE)
                if allow_multiline == nil then allow_multiline = USER_CONFIG.CHAP_MULTILINE end
                
                return buildSection(total_width, chap_title, final_subtitle, "custom_chapter", 
                    chap_progress, 
                    {bg=colors.bg, text=colors.text, subtext=colors.subtext, bar_bg=colors.bar_bg, 
                    fill=color_config.chapter, fill_hex=color_config.chapter_hex},
                    settings_cache.custom_bar_height, allow_multiline, true, title_face, subtitle_face, nil, false)
            end
        end,

        goal = function()
            if G_reader_settings:readSetting(SETTINGS.SHOW_GOAL) ~= false then
                local day_dur, day_pages
                
                if has_ui and ui.statistics then
                    day_dur, day_pages = getDailyStats(ui.statistics)
                else
                    day_dur = book_data and book_data.day_duration or 0
                    day_pages = book_data and book_data.day_pages or 0
                end
                
                local daily_goal = G_reader_settings:readSetting(SETTINGS.DAILY_GOAL) or USER_CONFIG.DAILY_GOAL
                local goal_title = (formatDuration(day_dur) or "0 mins") .. " read today"
                
                local show_streak = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_STREAK)
                local show_achievement = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_ACHIEVEMENT)
                
                local current_streak = 0
                local days_met, days_in_week = 0, 0
                
                if show_streak then
                    current_streak = getCurrentDailyStreak()
                end
                
                if show_achievement then
                    days_met, days_in_week = getWeeklyGoalAchievement()
                end
                
                local goal_subtitle
                if (show_streak and current_streak >= 2) or (show_achievement and days_in_week > 0) then
                    goal_subtitle = VerticalGroup:new{ align = "left" }
                    
                    if show_streak and current_streak >= 2 then
                        local streak_text = string.format("%d day%s read in a row", 
                            current_streak, 
                            current_streak == 1 and "" or "s")
                        goal_subtitle[#goal_subtitle+1] = TextWidget:new{
                            text = streak_text,
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                    
                    if show_achievement and days_in_week > 0 then
                        local achievement_text = string.format("Met goal %d/%d days this week", 
                            days_met, days_in_week)
                        goal_subtitle[#goal_subtitle+1] = TextWidget:new{
                            text = achievement_text,
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end

                    local show_goal_pages = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_PAGES)
                    if show_goal_pages == nil then show_goal_pages = USER_CONFIG.SHOW_GOAL_PAGES end
                    
                    if show_goal_pages then
                        goal_subtitle[#goal_subtitle+1] = TextWidget:new{
                            text = string.format("%s · %d/%d page goal",
                                day_pages >= daily_goal and "Achieved!" or math.floor((day_pages / daily_goal) * 100) .. "%",
                                day_pages, daily_goal),
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    else
                        goal_subtitle[#goal_subtitle+1] = TextWidget:new{
                            text = string.format("%s",
                                day_pages >= daily_goal and "Goal achieved!" or math.floor((day_pages / daily_goal) * 100) .. "% of goal"),
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                else
                    local show_goal_pages = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_PAGES)
                    if show_goal_pages == nil then show_goal_pages = USER_CONFIG.SHOW_GOAL_PAGES end
                    
                    if show_goal_pages then
                        goal_subtitle = string.format("%s · %d/%d page goal",
                            day_pages >= daily_goal and "Achieved!" or math.floor((day_pages / daily_goal) * 100) .. "%",
                            day_pages, daily_goal)
                    else
                        goal_subtitle = string.format("%s",
                            day_pages >= daily_goal and "Goal achieved!" or math.floor((day_pages / daily_goal) * 100) .. "% of goal")
                    end
                end
                
                local icon = day_pages >= daily_goal and "custom_trophy" or "custom_goal"
                
                return buildSection(total_width, goal_title, goal_subtitle, icon,
                    day_pages / daily_goal,
                    {bg=colors.bg, text=colors.text, subtext=colors.subtext, bar_bg=colors.bar_bg, 
                    fill=color_config.goal, fill_hex=color_config.goal_hex},
                    settings_cache.custom_bar_height, true, true, title_face, subtitle_face, nil, false)
            end
        end,

        battery = function()
            if G_reader_settings:readSetting(SETTINGS.SHOW_BATT) ~= false then
                local batt_info = getBatteryDisplayInfo()
                local batt_perc = batt_info.percent
                local is_charging = batt_info.is_charging
                local battery_hours_left = batt_info.hours_left
                
                local batt_fill, batt_fill_hex
                if color_config.is_mono then
                    batt_fill = color_config.mono_color
                    batt_fill_hex = color_config.mono_hex
                else
                    local b_high = getSetting("BATT_HIGH_COLOR")
                    local b_med = getSetting("BATT_MED_COLOR")
                    local b_low = getSetting("BATT_LOW_COLOR")
                    local b_charging = getSetting("BATT_CHARGING_COLOR")
                    
                    if is_charging then
                        batt_fill_hex = b_charging
                    elseif batt_perc >= 70 then
                        batt_fill_hex = b_high
                    elseif batt_perc >= 30 then
                        batt_fill_hex = b_med
                    else
                        batt_fill_hex = b_low
                    end
                    batt_fill = getCachedColor(batt_fill_hex)
                end
                
                local battery_icon
                if is_charging then
                    battery_icon = "custom_battery_charging"
                elseif batt_perc >= 70 then
                    battery_icon = "custom_battery_high"
                elseif batt_perc >= 30 then
                    battery_icon = "custom_battery_mid"
                else
                    battery_icon = "custom_battery_low"
                end

                local show_batt_date = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_DATE)
                if show_batt_date == nil then show_batt_date = USER_CONFIG.SHOW_BATT_DATE end
                
                local time_fmt = G_reader_settings:isTrue("twelve_hour_clock") and "%I:%M %p" or "%H:%M"
                local show_batt_time = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME)
                if show_batt_time == nil then show_batt_time = true end
                
                local show_time_separate = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME_SEPARATE)
                if show_time_separate == nil then show_time_separate = USER_CONFIG.SHOW_BATT_TIME_SEPARATE end
                
                local battery_top_line, battery_bottom_line, battery_time_line
                local charging_symbol = is_charging and "⚡" or ""
                
                local function formatDate()
                    local day = tonumber(os.date("%d"))
                    local suffix
                    if day == 1 or day == 21 or day == 31 then
                        suffix = "st"
                    elseif day == 2 or day == 22 then
                        suffix = "nd"
                    elseif day == 3 or day == 23 then
                        suffix = "rd"
                    else
                        suffix = "th"
                    end
                    return string.format("%d%s %s", day, suffix, os.date("%b"))
                end
                
                local current_display = show_batt_date and formatDate() or os.date(time_fmt):gsub("^0", "")

                if show_time_separate then
                    battery_top_line = string.format("%d%% %s", batt_perc, charging_symbol)
                    battery_time_line = current_display
                    if show_batt_time then
                        battery_bottom_line = battery_hours_left > 0 
                            and string.format("Approx. %d %s left", battery_hours_left, battery_hours_left == 1 and "hr" or "hrs")
                            or "Approx. <1 hr left"
                    else
                        battery_bottom_line = nil
                    end
                else
                    if show_batt_time then
                        battery_top_line = string.format("%d%% %s · %s", batt_perc, charging_symbol, current_display)
                        battery_bottom_line = battery_hours_left > 0 
                            and string.format("Approx. %d %s left", battery_hours_left, battery_hours_left == 1 and "hr" or "hrs")
                            or "Approx. <1 hr left"
                    else
                        battery_top_line = string.format("%d%% %s", batt_perc, charging_symbol)
                        battery_bottom_line = current_display
                    end
                end
                
                local battery_subtitle
                local show_rate = G_reader_settings:isTrue(SETTINGS.SHOW_BATT_RATE)
                
                if show_rate then
                    battery_subtitle = VerticalGroup:new{ align = "left" }
                    
                    local consumption_rate = getBatteryConsumptionRate()

                    if battery_time_line then
                        battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                            text = battery_time_line,
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                    
                    if consumption_rate and consumption_rate > 0 then
                        battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                            text = string.format("~%.1f%% per hour", consumption_rate),
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    else
                        battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                            text = "Rate unavailable",
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                    end
                    
                    battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                        text = battery_bottom_line or "",
                        face = subtitle_face, 
                        fgcolor = colors.subtext
                    }
                else
                    if battery_time_line then
                        battery_subtitle = VerticalGroup:new{ align = "left" }
                        battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                            text = battery_time_line,
                            face = subtitle_face, 
                            fgcolor = colors.subtext
                        }
                        if battery_bottom_line then
                            battery_subtitle[#battery_subtitle+1] = TextWidget:new{
                                text = battery_bottom_line,
                                face = subtitle_face, 
                                fgcolor = colors.subtext
                            }
                        end
                    else
                        battery_subtitle = battery_bottom_line
                    end
                end
                
                return buildSection(total_width, battery_top_line, battery_subtitle, battery_icon, 
                    batt_perc / 100, 
                    {bg=colors.bg, text=colors.text, subtext=colors.subtext, bar_bg=colors.bar_bg, 
                    fill=batt_fill, fill_hex=batt_fill_hex},
                    settings_cache.custom_bar_height, true, true, title_face, subtitle_face, nil, false)
            end
        end,

        message = function()
            if G_reader_settings:readSetting(SETTINGS.SHOW_MSG) ~= false 
            and G_reader_settings:isTrue(SETTINGS.SHOW_MSG_GLOBAL) then
                
                local message_text
                local message_source = G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) or "custom"
                local empty_message_koreader = "No message set"
                
                if message_source == "none" then
                    return nil
                elseif message_source == "custom" then
                    local custom_msg = G_reader_settings:readSetting(SETTINGS.CUSTOM_MESSAGE)
                    if custom_msg and util.trim(custom_msg) ~= "" then
                        message_text = expandMessage(custom_msg)
                    else
                        return nil
                    end
                elseif message_source == "highlight" then
                    if has_ui then
                        local highlight_data = getRandomHighlight(ui)
                        
                        if highlight_data and highlight_data.text then
                            if G_reader_settings:readSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION) then
                                local location_parts = {}
                                if highlight_data.chapter then
                                    table.insert(location_parts, highlight_data.chapter)
                                end
                                if highlight_data.page then
                                    table.insert(location_parts, "pg. " .. tostring(highlight_data.page))
                                end
                                
                                if #location_parts > 0 then
                                    message_text = VerticalGroup:new{ align = "left" }
                                    message_text[#message_text+1] = TextWidget:new{
                                        text = highlight_data.text,
                                        face = subtitle_face,
                                        fgcolor = colors.subtext
                                    }
                                    message_text[#message_text+1] = TextWidget:new{
                                        text = "— " .. table.concat(location_parts, ", "),
                                        face = subtitle_face,
                                        fgcolor = colors.subtext
                                    }
                                else
                                    message_text = highlight_data.text
                                end
                            else
                                message_text = highlight_data.text
                            end
                        else
                            message_text = "No highlights found"
                        end
                    else
                        message_text = "Open a book to see highlights"
                    end
                else
                    message_text = util.trim(G_reader_settings:readSetting(SETTINGS.MSG_TEXT) or "")
                    if message_text ~= "" then
                        if has_ui and ui.bookinfo and ui.bookinfo.expandString then
                            message_text = ui.bookinfo:expandString(message_text) or message_text
                        end
                    else
                        message_text = empty_message_koreader
                    end
                end

                local raw_header = G_reader_settings:readSetting(SETTINGS.MSG_HEADER)
                if not raw_header or util.trim(raw_header) == "" then
                    header_text = _("Message header is empty.")
                else
                    header_text = expandMessage(raw_header)
                end
                
                return buildSection(total_width,
                    header_text,
                    message_text,
                    "custom_message",
                    0,
                    {bg=colors.bg, text=colors.text, subtext=colors.subtext, bar_bg=colors.bar_bg, 
                    fill=color_config.message, fill_hex=color_config.message_hex},
                    0, true, true, title_face, subtitle_face, nil, false)
            end
        end,
    }

    local section_order = settings_cache.section_order
    if not section_order or type(section_order) ~= "table" or #section_order == 0 then
        section_order = {"book", "chapter", "goal", "battery", "message"}
    end

    local built_sections = {}
    for i, key in ipairs(section_order) do
        local builder = section_builders[key]
        if builder then
            local section = builder()
            if section then 
                built_sections[#built_sections + 1] = section
            end
        end
    end

    local border_wrap
    local sections_group
    
    if settings_cache.gaps_enabled then

        local wrapped_sections = {}
        
        for i, section in ipairs(built_sections) do
            local section_container = FrameContainer:new{
                padding = 0,
                bordersize = settings_cache.border_size,
                color = colors.border,
                background = colors.bg,
                VerticalGroup:new{
                    align = "left",
                    section
                }
            }
            
            if settings_cache.border_size > 0 and settings_cache.border_size_2 > 0 then
                section_container = FrameContainer:new{
                    padding = 0,
                    bordersize = settings_cache.border_size_2,
                    color = colors.border_2,
                    background = Blitbuffer.COLOR_TRANSPARENT,
                    section_container
                }
            end
            
            if settings_cache.opacity < 255 then
                section_container = AlphaContainer:new{
                    alpha = settings_cache.opacity / 255,
                    section_container
                }
            end
            
            wrapped_sections[#wrapped_sections + 1] = section_container
            
            if i < #built_sections then
                wrapped_sections[#wrapped_sections + 1] = VerticalSpan:new{ 
                    width = settings_cache.gap_size 
                }
            end
        end
        
        sections_group = VerticalGroup:new(wrapped_sections)
        sections_group.align = "left"
        border_wrap = sections_group
        
    else
        sections_group = VerticalGroup:new(built_sections)
        sections_group.align = "left"

        border_wrap = FrameContainer:new{
            padding = 0,
            bordersize = settings_cache.border_size,
            color = colors.border,
            background = colors.bg,
            sections_group
        }

        if settings_cache.border_size > 0 and settings_cache.border_size_2 > 0 then
            border_wrap = FrameContainer:new{
                padding = 0,
                bordersize = settings_cache.border_size_2,
                color = colors.border_2,
                background = Blitbuffer.COLOR_TRANSPARENT,
                border_wrap
            }
        end
    end

    local x_off, y_off = calculateWidgetPosition(border_wrap, settings_cache)
    
    local dimming_layer = buildDimmingLayer(settings_cache)
    
    local bg_widget = buildBackgroundWidget(ui, book_data)
    local screen_size = Screen:getSize()
    
    local final_widget
    
    if settings_cache.gaps_enabled then
        final_widget = border_wrap
        
    elseif settings_cache.opacity >= 255 then
        final_widget = border_wrap
        
    else
        final_widget = AlphaContainer:new{
            alpha = settings_cache.opacity / 255,
            border_wrap
        }
    end

    return OverlapGroup:new{
        dimen = screen_size,
        bg_widget or HorizontalSpan:new{ width = screen_size.w },
        dimming_layer,
        OverlapGroup:new{
            dimen = screen_size,
            VerticalGroup:new{
                VerticalSpan:new{ width = y_off },
                HorizontalGroup:new{
                    HorizontalSpan:new{ width = x_off },
                    FrameContainer:new{
                        bordersize = 0,
                        padding = 0,
                        settings_cache.gaps_enabled and final_widget or AlphaContainer:new{ 
                            alpha = settings_cache.opacity / 255, 
                            border_wrap 
                        }
                    }
                }
            }
        }
    }
end

local function hexToHSV(hex)
    hex = hex:gsub("#", "")

    local r, g, b
    if #hex == 6 then
        r = tonumber(hex:sub(1, 2), 16) / 255
        g = tonumber(hex:sub(3, 4), 16) / 255
        b = tonumber(hex:sub(5, 6), 16) / 255
    else
        return 0, 1, 1
    end

    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local delta = max - min

    local v = max

    local s = 0
    if max > 0 then
        s = delta / max
    end

    local h = 0
    if delta > 0 then
        if max == r then
            h = 60 * (((g - b) / delta) % 6)
        elseif max == g then
            h = 60 * (((b - r) / delta) + 2)
        else
            h = 60 * (((r - g) / delta) + 4)
        end
    end

    if h < 0 then
        h = h + 360
    end

    return h, s, v
end

-------------------------------------------------------------------------
-- Menu Builders
-------------------------------------------------------------------------

local function buildBackgroundTypeMenu()
    local options = {
        { text = "No background", val = "transparent" },
        { text = "Book cover", val = "cover" },
        { text = "Solid colour", val = "solid" },
        { text = "Random image from folder", val = "folder" }
    }
    local sub_menu = {}
    
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function()
                return (getSetting("BG_TYPE")) == opt.val
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.BG_TYPE, opt.val); invalidateSettingsCache() end,
            radio = true,
        }
    end

    sub_menu[#sub_menu + 1] = {
        text = _("Solid background colour"),
        enabled_func = function() return G_reader_settings:readSetting(SETTINGS.BG_TYPE) == "solid" end,
        keep_menu_open = true,
        callback = function()
            local current_color = getSetting("BG_SOLID_COLOR")
            local h, s, v = hexToHSV(current_color)
            local wheel
            wheel = ColorWheelWidget:new({
                title_text = _("Pick background colour"),
                hue = h,
                saturation = s,
                value = v,
                callback = function(hex)
                    G_reader_settings:saveSetting(SETTINGS.BG_SOLID_COLOR, hex)
                    invalidateSettingsCache()
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function()
                    UIManager:setDirty(nil, "ui")
                end,
            })
            UIManager:show(wheel)
        end,
    }

    sub_menu[#sub_menu + 1] = {
        text = _("Background folder path"),
        enabled_func = function() return G_reader_settings:readSetting(SETTINGS.BG_TYPE) == "folder" end,
        keep_menu_open = true,
        callback = function()
            local InfoMessage = require("ui/widget/infomessage")
            local box
            box = InputDialog:new{
                title = _("Background image folder"),
                input = getSetting("BG_FOLDER"),
                input_hint = "/path/to/images",
                width = Screen:getWidth() * 0.8,
                buttons = {{
                    {text = "Cancel", callback = function() UIManager:close(box) end},
                    {text = "Save", callback = function()
                        local path = box:getInputValue()
                        if path and path ~= "" then
                            path = path:gsub("/$", "")

                            local has_images = false
                            local dir = ffi.C.opendir(path)
                            if dir ~= nil then
                                local ent = ffi.C.readdir(dir)
                                while ent ~= nil do
                                    local filename = ffi.string(ent.d_name)
                                    if filename ~= "." and filename ~= ".." then
                                        local lower = filename:lower()
                                        if lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") then
                                            has_images = true
                                            break
                                        end
                                    end
                                    ent = ffi.C.readdir(dir)
                                end
                                ffi.C.closedir(dir)
                            end

                            G_reader_settings:saveSetting(SETTINGS.BG_FOLDER, path)
                            invalidateSettingsCache()
                            
                            UIManager:show(InfoMessage:new{
                                text = has_images and "Folder path saved successfully!"
                                                or "Warning: No images found.\nPath saved but will fall back to cover.",
                                timeout = has_images and 2 or 4,
                            })
                        end
                        UIManager:close(box)
                    end}
                }}
            }
            UIManager:show(box)
        end,
    }

    return sub_menu
end

local function buildBarHeightMenu()
    local options = {
        { text = _("Hairline (4)"), val = 4 },
        { text = _("Narrow (8)"), val = 8 },
        { text = _("Standard (12)"), val = 12 },
        { text = _("Bold (16)"), val = 16 },
        { text = _("Chunky (20)"), val = 20 },
        { text = _("Heavy (24)"), val = 24 },
    }
    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function()
                return (getSetting("BAR_HEIGHT")) == opt.val
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.BAR_HEIGHT, opt.val); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildBorderSizeMenu()
    local options = {
        { text = _("No border (0)"), val = 0 },
        { text = _("Hairline (1)"), val = 1 },
        { text = _("Clean (2)"), val = 2 },
        { text = _("Defined (3)"), val = 3 },
        { text = _("Bold (4)"), val = 4 },
        { text = _("Heavy (5)"), val = 5 },
        { text = _("Framed (6)"), val = 6 },
        { text = _("Thick (7)"), val = 7 },
        { text = _("Chunky (8)"), val = 8 },
    }
    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function()
                return (getSetting("BORDER_SIZE")) == opt.val
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.BORDER_SIZE, opt.val); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildBorderSize2Menu()
    local options = {
        { text = _("No second border (0)"), val = 0 },
        { text = _("Hairline (1)"), val = 1 },
        { text = _("Clean (2)"), val = 2 },
        { text = _("Defined (3)"), val = 3 },
        { text = _("Bold (4)"), val = 4 },
        { text = _("Heavy (5)"), val = 5 },
        { text = _("Framed (6)"), val = 6 },
        { text = _("Thick (7)"), val = 7 },
        { text = _("Chunky (8)"), val = 8 },
    }
    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            enabled_func = function()
                return (getSetting("BORDER_SIZE")) > 0
            end,
            checked_func = function()
                return (G_reader_settings:readSetting(SETTINGS.BORDER_SIZE_2) or USER_CONFIG.BORDER_SIZE_2) == opt.val
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.BORDER_SIZE_2, opt.val); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildDimmingMenu()
    local options = {
        { text = _("Off"), val = 0 },
        { text = _("10%"), val = 26 },
        { text = _("20%"), val = 51 },
        { text = _("30%"), val = 77 },
        { text = _("40%"), val = 102 },
        { text = _("50%"), val = 128 },
        { text = _("60%"), val = 153 },
        { text = _("70%"), val = 179 },
        { text = _("80%"), val = 204 },
        { text = _("90%"), val = 230 },
        { text = _("100%"), val = 255 },
    }

    local sub_menu = {}

    sub_menu[#sub_menu + 1] = {
        text = _("Overlay colour"),
        keep_menu_open = true,
        separator = true,
        callback = function()
            local current_color = getSetting("BG_DIMMING_COLOR")
            local h, s, v = hexToHSV(current_color)
            local wheel = ColorWheelWidget:new({
                title_text = _("Background overlay colour"),
                hue = h,
                saturation = s,
                value = v,
                callback = function(hex)
                    G_reader_settings:saveSetting(SETTINGS.BG_DIMMING_COLOR, hex)
                    invalidateSettingsCache()
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function()
                    UIManager:setDirty(nil, "ui")
                end,
            })
            UIManager:show(wheel)
        end,
    }

    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function()
                return (getSetting("BG_DIMMING")) == opt.val
            end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.BG_DIMMING, opt.val)
                invalidateSettingsCache()
            end,
            radio = true,
        }
    end

    return sub_menu
end

local function buildFontFaceMenu(setting_key)
    local sub_menu = {}
    
    sub_menu[#sub_menu + 1] = {
        text = "System Default (cfont)",
        checked_func = function()
            return (G_reader_settings:readSetting(setting_key) or "cfont") == "cfont"
        end,
        callback = function()
            G_reader_settings:saveSetting(setting_key, "cfont")
            invalidateSettingsCache()
        end,
        radio = true,
    }
    
    local font_list = {}
    local cre_engine = cre:engineInit()
    if cre_engine and cre_engine.getFontFaces then
        local faces = cre_engine.getFontFaces()
        for _, font_name in ipairs(faces) do
            local font_path = cre_engine.getFontFaceFilenameAndFaceIndex(font_name)
            if font_path then
                table.insert(font_list, {name = font_name, path = font_path})
            end
        end
        table.sort(font_list, function(a, b) return a.name < b.name end)
    end
    
    for i, font_data in ipairs(font_list) do
        sub_menu[#sub_menu + 1] = {
            text = font_data.name,
            font_func = function(size) return Font:getFace(font_data.path, size) end,
            checked_func = function()
                return (G_reader_settings:readSetting(setting_key) or "cfont") == font_data.path
            end,
            callback = function()
                G_reader_settings:saveSetting(setting_key, font_data.path)
                invalidateSettingsCache()
            end,
            radio = true,
        }
    end
    
    return sub_menu
end

local function buildIconSetMenu()
    local icon_sets = getAvailableIconSets()
    local sub_menu = {}
    
    if #icon_sets == 0 then
        return {
            {
                text = _("No icon sets found in icons/customisable-sleep-screen-iconsets/"),
                enabled = false,
            }
        }
    end
    
    for i, set_name in ipairs(icon_sets) do
        sub_menu[#sub_menu + 1] = {
            text = set_name,
            radio = true,
            checked_func = function()
                return (getSetting("ICON_SET")) == set_name
            end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.ICON_SET, set_name)
                invalidateSettingsCache()
            end,
        }
    end
    
    return sub_menu
end

local function buildIconTextGapMenu()
    local options = {
        { text = _("Touching (0)"), val = 0 },
        { text = _("Tight (8)"), val = 8 },
        { text = _("Balanced (16)"), val = 16 },
        { text = _("Relaxed (24)"), val = 24 },
        { text = _("Wide (32)"), val = 32 },
        { text = _("Extra Wide (48)"), val = 48 },
    }

    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function() 
                return (getSetting("ICON_TEXT_GAP")) == opt.val 
            end,
            callback = function() 
                G_reader_settings:saveSetting(SETTINGS.ICON_TEXT_GAP, opt.val)
                invalidateSettingsCache() 
            end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildMarginMenu()
    local options = {
        { text = _("No margin (0)"), val = 0 },
        { text = _("XX-Small (25)"), val = 25 },
        { text = _("X-Small (50)"), val = 50 },
        { text = _("Small (75)"), val = 75 },
        { text = _("Medium (100)"), val = 100 },
        { text = _("Large (125)"), val = 125 },
        { text = _("X-Large (150)"), val = 150 },
        { text = _("XX-Large (175)"), val = 175 },
    }
    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function()
                return (getSetting("MARGIN")) == opt.val
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.MARGIN, opt.val); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildOpacityMenu()
    local levels = {}
    for pct = 0, 90, 10 do
        levels[#levels + 1] = { text = pct .. "%", val = math.floor(pct * 255 / 100) }
    end
    levels[#levels + 1] = { text = _("Opaque"), val = 255 }
    
    local sub_menu = {}
    for i, l in ipairs(levels) do
        sub_menu[#sub_menu + 1] = {
            text = l.text,
            checked_func = function() return getSetting("OPACITY") == l.val end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.OPACITY, l.val); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildPaddingMenu()
    local options = {
        { text = _("Flush (0)"), val = 0 },
        { text = _("Tight (8)"), val = 8 },
        { text = _("Standard (12)"), val = 12 },
        { text = _("Balanced (16)"), val = 16 },
        { text = _("Spacious (24)"), val = 24 },
        { text = _("Extra Large (32)"), val = 32 },
    }

    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[#sub_menu + 1] = {
            text = opt.text,
            checked_func = function() 
                return (getSetting("SECTION_PADDING")) == opt.val 
            end,
            callback = function() 
                G_reader_settings:saveSetting(SETTINGS.SECTION_PADDING, opt.val)
                invalidateSettingsCache() 
            end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildPositionMenu()
    local pos_list = {"top_left", "top_center", "top_right", "middle_left", "center", 
                      "middle_right", "bottom_left", "bottom_center", "bottom_right"}
    local sub_menu = {}
    for i, p in ipairs(pos_list) do
        sub_menu[#sub_menu + 1] = {
            text = p:gsub("_", " "):gsub("^%l", string.upper),
            checked_func = function()
                return (getSetting("POS")) == p
            end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.POS, p); invalidateSettingsCache() end,
            radio = true,
        }
    end
    return sub_menu
end

local function buildPresetManagementMenu(hide_save_options)
    local InfoMessage = require("ui/widget/infomessage")
    local ConfirmBox = require("ui/widget/confirmbox")

    local menu_table = {}
    
    menu_table[#menu_table + 1] = {
        text = _("Active preset: ") .. getActivePresetName(),
        enabled = false,
        separator = true,
    }
    
    if not hide_save_options then
        menu_table[#menu_table + 1] = {
            text = _("Save current settings as new preset"),
            keep_menu_open = true,
            callback = function()
                local box
                box = InputDialog:new{
                    title = _("Enter preset name"),
                    width = Screen:getWidth() * 0.8,
                    buttons = {{
                        {text = _("Cancel"), callback = function() UIManager:close(box) end},
                        {text = _("Save"), callback = function()
                            local name = box:getInputValue()
                            if name and name ~= "" then
                                if savePreset(name) then
                                    G_reader_settings:saveSetting(SETTINGS.ACTIVE_PRESET, name)
                                    UIManager:close(box)
                                    UIManager:show(InfoMessage:new{
                                        text = string.format(_("Preset '%s' saved successfully!"), name),
                                        timeout = 2,
                                    })
                                end
                            else
                                UIManager:show(InfoMessage:new{
                                    text = _("Please enter a valid preset name"),
                                    timeout = 2,
                                })
                            end
                        end}
                    }}
                }
                UIManager:show(box)
                box:onShowKeyboard()
            end,
        }

        menu_table[#menu_table + 1] = {
            text = _("Update active preset with current settings"),
            enabled_func = function()
                local active = getActivePresetName()
                if active == "None" then return false end
                if PRELOADED_PRESETS[active] then return false end
                return true
            end,
            keep_menu_open = true,
            callback = function()
                local active = getActivePresetName()
                
                if PRELOADED_PRESETS[active] then
                    UIManager:show(InfoMessage:new{
                        text = _("Cannot modify built-in presets"),
                        timeout = 2,
                    })
                    return
                end
                
                local confirm_box
                confirm_box = ConfirmBox:new{
                    text = string.format(_("Overwrite preset '%s' with current settings?"), active),
                    ok_text = _("Update"),
                    cancel_text = _("Cancel"),
                    ok_callback = function()
                        updateActivePreset()
                        UIManager:close(confirm_box)
                        UIManager:show(InfoMessage:new{
                            text = string.format(_("Preset '%s' updated!"), active),
                            timeout = 2,
                        })
                    end,
                }
                UIManager:show(confirm_box)
            end,
            separator = true,
        }
    end

    local user_presets = getPresets()
    local all_preset_names = {}
    
    local hide_preloaded = G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS)
    
    for name, i in pairs(PRELOADED_PRESETS) do
        if name == "Default" or not hide_preloaded then
            all_preset_names[#all_preset_names + 1] = {name = name, is_preloaded = true}
        end
    end
    
    for name, i in pairs(user_presets) do
        if not PRELOADED_PRESETS[name] then
            all_preset_names[#all_preset_names + 1] = {name = name, is_preloaded = false}
        end
    end
    
    table.sort(all_preset_names, function(a, b)
        if a.is_preloaded ~= b.is_preloaded then
            return a.is_preloaded
        end
        
        if a.is_preloaded and b.is_preloaded then
            if a.name == "Default" then return true end
            if b.name == "Default" then return false end
        end
        
        return a.name < b.name
    end)
    
    local added_separator = false
    local added_preloaded_separator = false
    
    local preloaded_count = 0
    for i, preset_info in ipairs(all_preset_names) do
        if preset_info.is_preloaded then
            preloaded_count = preloaded_count + 1
        end
    end

    for i, preset_info in ipairs(all_preset_names) do
        local preset_name = preset_info.name
        local is_preloaded = preset_info.is_preloaded
        
        if not added_preloaded_separator and is_preloaded and (not hide_preloaded or preloaded_count > 1) then
            menu_table[#menu_table + 1] = {
                text = _("──── Built-in Presets ────"),
                enabled = false,
            }
            added_preloaded_separator = true
        end
        
        if not added_separator and not is_preloaded then
            menu_table[#menu_table + 1] = {
                text = _("──── Your Custom Presets ────"),
                enabled = false,
            }
            added_separator = true
        end
        
        local display_name = preset_name
        
        menu_table[#menu_table + 1] = {
            text = display_name,
            radio = true,
            checked_func = function()
                return getActivePresetName() == preset_name
            end,
            keep_menu_open = true,
            callback = function()

                local preset_data = is_preloaded and PRELOADED_PRESETS[preset_name] or user_presets[preset_name]
                
                if preset_data then
                    for setting_key, value in pairs(preset_data) do
                        G_reader_settings:saveSetting(setting_key, value)
                    end
                    G_reader_settings:saveSetting(SETTINGS.ACTIVE_PRESET, preset_name)
                    invalidateSettingsCache()
                    
                    UIManager:show(InfoMessage:new{
                        text = string.format(_("Loaded preset '%s'"), preset_name),
                        timeout = 2,
                    })
                end
            end,

            hold_callback = (not is_preloaded) and function()
                local hold_menu = {
                    {
                        text = _("Rename this preset"),
                        callback = function()
                            local rename_box
                            rename_box = InputDialog:new{
                                title = _("Rename preset"),
                                input = preset_name,
                                width = Screen:getWidth() * 0.8,
                                buttons = {{
                                    {text = _("Cancel"), callback = function() UIManager:close(rename_box) end},
                                    {text = _("Rename"), callback = function()
                                        local new_name = rename_box:getInputValue()
                                        if new_name and new_name ~= "" and new_name ~= preset_name then
                                            local presets_table = G_reader_settings:readSetting(SETTINGS.PRESETS) or {}
                                            presets_table[new_name] = presets_table[preset_name]
                                            presets_table[preset_name] = nil
                                            
                                            G_reader_settings:saveSetting(SETTINGS.PRESETS, presets_table)
                                            G_reader_settings:flush()
                                            
                                            if getActivePresetName() == preset_name then
                                                G_reader_settings:saveSetting(SETTINGS.ACTIVE_PRESET, new_name)
                                                G_reader_settings:flush()
                                            end
                                            
                                            UIManager:close(rename_box)
                                            UIManager:close(UIManager:getTopmostVisibleWidget())
                                            
                                            UIManager:show(InfoMessage:new{
                                                text = _("Preset renamed successfully"),
                                                timeout = 2,
                                            })
                                        end
                                    end}
                                }}
                            }
                            UIManager:show(rename_box)
                            rename_box:onShowKeyboard()
                        end,
                    },
                    {
                        text = _("Delete this preset"),
                        callback = function()
                            local delete_box
                            delete_box = ConfirmBox:new{
                                text = string.format(_("Delete preset '%s'?"), preset_name),
                                ok_text = _("Delete"),
                                cancel_text = _("Cancel"),
                                ok_callback = function()
                                    if deletePreset(preset_name) then
                                        UIManager:close(delete_box)
                                        UIManager:close(UIManager:getTopmostVisibleWidget())
                                        
                                        UIManager:show(InfoMessage:new{
                                            text = _("Preset deleted"),
                                            timeout = 2,
                                        })
                                    end
                                end,
                            }
                            UIManager:show(delete_box)
                        end,
                    },
                }
                
                local ButtonDialog = require("ui/widget/buttondialog")
                UIManager:show(ButtonDialog:new{
                    title = _("Preset: ") .. preset_name,
                    buttons = {hold_menu}
                })
            end or nil,
        }
    end

    return menu_table
end

local function buildSectionOrderMenu()
    local section_names = {
        { key = "book", label = _("Book info"), setting = SETTINGS.SHOW_BOOK },
        { key = "chapter", label = _("Chapter info"), setting = SETTINGS.SHOW_CHAP },
        { key = "goal", label = _("Daily info"), setting = SETTINGS.SHOW_GOAL },
        { key = "battery", label = _("Device info"), setting = SETTINGS.SHOW_BATT },
        { key = "message", label = _("Custom message"), setting = SETTINGS.SHOW_MSG },
    }
    
    local default_order = USER_CONFIG.SECTION_ORDER
    local sub_menu = {}
    
    local function is_section_visible(setting_key)
        if setting_key == SETTINGS.SHOW_MSG then
            return G_reader_settings:readSetting(setting_key) ~= false 
                   and G_reader_settings:isTrue(SETTINGS.SHOW_MSG_GLOBAL)
        end
        return G_reader_settings:readSetting(setting_key) ~= false
    end
    
    local function count_visible_sections()
        local count = 0
        for _, section in ipairs(section_names) do
            if is_section_visible(section.setting) then
                count = count + 1
            end
        end
        return count
    end
    
    for i, section in ipairs(section_names) do
        local move_options = {}
        
        local function get_max_positions()
            return count_visible_sections()
        end
        
        for pos = 1, 5 do 
            move_options[#move_options + 1] = {
                text = string.format(_("Position %d"), pos),
                radio = true,
                
                checked_func = function()
                    local order = G_reader_settings:readSetting(SETTINGS.SECTION_ORDER) or default_order
                    local visible_counter = 0
                    for _, key in ipairs(order) do
                        local section_info
                        for _, s in ipairs(section_names) do
                            if s.key == key then section_info = s; break end
                        end
                        
                        if section_info and is_section_visible(section_info.setting) then
                            visible_counter = visible_counter + 1
                            if key == section.key then
                                return visible_counter == pos
                            end
                        end
                    end
                    return false
                end,

                enabled_func = function()
                    if not is_section_visible(section.setting) then return false end
                    return pos <= count_visible_sections()
                end,

                callback = function()
                    local order = G_reader_settings:readSetting(SETTINGS.SECTION_ORDER) or {table.unpack(default_order)}
                    
                    local current_idx
                    for idx, key in ipairs(order) do
                        if key == section.key then current_idx = idx; break end
                    end
                    
                    if not current_idx then return end
                    
                    local visible_counter = 0
                    local target_idx = nil
                    for idx, key in ipairs(order) do
                        local section_info
                        for _, s in ipairs(section_names) do
                            if s.key == key then section_info = s; break end
                        end
                        
                        if section_info and is_section_visible(section_info.setting) then
                            visible_counter = visible_counter + 1
                            if visible_counter == pos then
                                target_idx = idx
                                break
                            end
                        end
                    end
                    
                    if target_idx and target_idx ~= current_idx then
                        table.remove(order, current_idx)
                        table.insert(order, target_idx, section.key)
                        G_reader_settings:saveSetting(SETTINGS.SECTION_ORDER, order)
                        invalidateSettingsCache()
                    end
                end,
                keep_menu_open = true,
            }
        end

        sub_menu[#sub_menu + 1] = {
            text = section.label,
            enabled_func = function()
                return is_section_visible(section.setting)
            end,
            help_text_func = function()
                return not is_section_visible(section.setting) and _("Make visible to rearrange") or nil
            end,
            sub_item_table = move_options
        }
    end
    
    return sub_menu
end

local function buildVisibilityMenu()
    local items = {
        { text = _("Book info"), key = SETTINGS.SHOW_BOOK },
        { text = _("Chapter info"), key = SETTINGS.SHOW_CHAP },
        { text = _("Daily info"), key = SETTINGS.SHOW_GOAL },
        { text = _("Device info "), key = SETTINGS.SHOW_BATT },
        { text = _("Custom message"), key = SETTINGS.SHOW_MSG },
    }
    
    local sub_menu = {}

    for i, item in ipairs(items) do
        sub_menu[#sub_menu + 1] = {
            text = item.text,
            toggle = true,
            enabled_func = function()
                return true
            end,
            checked_func = function()
                local val = G_reader_settings:readSetting(item.key) ~= false
                return val
            end,
            callback = function()
                local current = G_reader_settings:readSetting(item.key) ~= false
                G_reader_settings:saveSetting(item.key, not current)
                invalidateSettingsCache()
            end,
        }
    end
    return sub_menu
end

-------------------------------------------------------------------------
-- Menu Configuration
-------------------------------------------------------------------------

local function getCustomisableSleepScreenSettingsMenu(hide_presets)
    local menu_table = {}
    
    if not hide_presets then
        menu_table[#menu_table + 1] = {
            text = _("Presets"),
            sub_item_table_func = function()
                return buildPresetManagementMenu()
            end,
            separator = true,
        }
    end
    
    menu_table[#menu_table + 1] = {
        text = _("Display modes"),
        sub_item_table = {
            {
                text = _("Dark mode"),
                checked_func = function() return G_reader_settings:isTrue(SETTINGS.DARK_MODE) end,
                callback = function() 
                    G_reader_settings:saveSetting(SETTINGS.DARK_MODE, not G_reader_settings:isTrue(SETTINGS.DARK_MODE))
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Monochrome mode"),
                checked_func = function() return G_reader_settings:isTrue(SETTINGS.MONOCHROME) end,
                callback = function() 
                    G_reader_settings:saveSetting(SETTINGS.MONOCHROME, not G_reader_settings:isTrue(SETTINGS.MONOCHROME))
                    invalidateSettingsCache()
                end,
            },
        }
    }
    menu_table[#menu_table + 1] = {
        text = _("Contents"),
        sub_item_table = {
            {
                text = _("Reset contents settings to default"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    
                    local box = ConfirmBox:new{
                        text = _("Are you sure you want to reset contents settings?"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS.SHOW_BOOK)
                            G_reader_settings:delSetting(SETTINGS.SHOW_CHAP)
                            G_reader_settings:delSetting(SETTINGS.SHOW_GOAL)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BATT)
                            G_reader_settings:delSetting(SETTINGS.SHOW_MSG)
                            G_reader_settings:delSetting(SETTINGS.SECTION_ORDER)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BOOK_AUTHOR)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BOOK_PAGES)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BOOK_TIME_REMAINING)
                            G_reader_settings:delSetting(SETTINGS.SHOW_CHAP_COUNT)
                            G_reader_settings:delSetting(SETTINGS.SHOW_CHAP_PAGES)
                            G_reader_settings:delSetting(SETTINGS.SHOW_CHAP_TIME_REMAINING)
                            G_reader_settings:delSetting(SETTINGS.DAILY_GOAL)
                            G_reader_settings:delSetting(SETTINGS.SHOW_GOAL_STREAK)
                            G_reader_settings:delSetting(SETTINGS.SHOW_GOAL_ACHIEVEMENT)
                            G_reader_settings:delSetting(SETTINGS.SHOW_GOAL_PAGES)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BATT_TIME_SEPARATE)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BATT_DATE)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BATT_RATE)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BATT_TIME)
                            G_reader_settings:delSetting(SETTINGS.MESSAGE_SOURCE)
                            G_reader_settings:delSetting(SETTINGS.MSG_HEADER)
                            G_reader_settings:delSetting(SETTINGS.CUSTOM_MESSAGE)
                            G_reader_settings:delSetting(SETTINGS.MAX_HIGHLIGHT_LENGTH)
                            G_reader_settings:delSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES)
                            G_reader_settings:delSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION)
                            G_reader_settings:delSetting(SETTINGS.SHOW_TITLES)
                            G_reader_settings:delSetting(SETTINGS.SHOW_SUBTITLES)
                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Contents settings reset to defaults"),
                                timeout = 1
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            { text = _("Displayed sections"), sub_item_table = buildVisibilityMenu() },
            { text = _("Section order"), sub_item_table = buildSectionOrderMenu() },
            {
                text = _("Book section"),
                sub_item_table = {
                    {
                        text = _("Show book author"),
                        checked_func = function() 
                            return G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR) 
                        end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_AUTHOR)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_BOOK_AUTHOR, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show book pages (pg x of x)"),
                        checked_func = function() return G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES) end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_BOOK_PAGES)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_BOOK_PAGES, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show book time remaining"),
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_BOOK_TIME_REMAINING)
                            return val == nil or val == true
                        end,
                        callback = function()
                            G_reader_settings:flipNilOrTrue(SETTINGS.SHOW_BOOK_TIME_REMAINING)
                            invalidateSettingsCache()
                        end,
                    },
                },
            },
            {
                text = _("Chapter section"),
                sub_item_table = {
                    {
                        text = _("Show chapter count (ch x of x)"),
                        checked_func = function() return G_reader_settings:isTrue(SETTINGS.SHOW_CHAP_COUNT) end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_CHAP_COUNT)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_CHAP_COUNT, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show chapter pages (pg x of x)"),
                        checked_func = function() return G_reader_settings:isTrue(SETTINGS.SHOW_CHAP_PAGES) end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_CHAP_PAGES)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_CHAP_PAGES, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show chapter time remaining"),
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_CHAP_TIME_REMAINING)
                            return val == nil or val == true
                        end,
                        callback = function()
                            G_reader_settings:flipNilOrTrue(SETTINGS.SHOW_CHAP_TIME_REMAINING)
                            invalidateSettingsCache()
                        end,
                    },
                },
            },
            {
                text = _("Reading goal section"),
                sub_item_table = {
                    {
                        text = _("Daily page goal"),
                        keep_menu_open = true,
                        callback = function()
                            local box
                            box = InputDialog:new{
                                title = _("Daily page goal"),
                                input = tostring(G_reader_settings:readSetting(SETTINGS.DAILY_GOAL) or 50),
                                type = "number",
                                width = Screen:getWidth() * 0.8,
                                buttons = {{
                                    {text = _("Cancel"), callback = function() UIManager:close(box) end},
                                    {text = _("Save"), callback = function()
                                        local val = tonumber(box:getInputValue())
                                        if val and val > 1000 then
                                            UIManager:show(require("ui/widget/infomessage"):new{
                                                text = _("Please enter a realistic daily page goal"),
                                                timeout = 2
                                            })
                                        elseif val and val > 0 then 
                                            G_reader_settings:saveSetting(SETTINGS.DAILY_GOAL, val)
                                            invalidateSettingsCache()
                                            UIManager:close(box)
                                        else
                                            UIManager:show(require("ui/widget/infomessage"):new{
                                                text = _("Please enter a number greater than 0"),
                                                timeout = 2
                                            })
                                        end
                                    end}
                                }}
                            }
                            UIManager:show(box)
                        end,
                    },
                    {
                        text = _("Show current reading streak"),
                        checked_func = function() 
                            return G_reader_settings:isTrue(SETTINGS.SHOW_GOAL_STREAK) 
                        end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_GOAL_STREAK)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_GOAL_STREAK, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show weekly goal achievement"),
                        checked_func = function() 
                            return G_reader_settings:isTrue(SETTINGS.SHOW_GOAL_ACHIEVEMENT) 
                        end,
                        callback = function()
                            local current = G_reader_settings:isTrue(SETTINGS.SHOW_GOAL_ACHIEVEMENT)
                            G_reader_settings:saveSetting(SETTINGS.SHOW_GOAL_ACHIEVEMENT, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show pages read out of daily goal"),
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_PAGES)
                            return val == nil or val == true
                        end,
                        callback = function()
                            G_reader_settings:flipNilOrTrue(SETTINGS.SHOW_GOAL_PAGES)
                            invalidateSettingsCache()
                        end,
                    },
                },
            },
            {
                text = _("Battery & time section"),
                sub_item_table = {
                    {
                        text = _("Show current date/time on separate line"),
                        help_text_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME)
                            if val == false then
                                return _("Enable 'Show battery time remaining' to use this option")
                            end
                            return nil
                        end,
                        enabled_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME)
                            return val == nil or val == true
                        end,
                        checked_func = function()
                            return G_reader_settings:isTrue(SETTINGS.SHOW_BATT_TIME_SEPARATE)
                        end,
                        callback = function()
                            G_reader_settings:flipNilOrFalse(SETTINGS.SHOW_BATT_TIME_SEPARATE)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show date instead of time"),
                        help_text = _("Display current date (e.g., '29th Jan') instead of time in battery section"),
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_DATE)
                            return val == nil and USER_CONFIG.SHOW_BATT_DATE or val
                        end,
                        callback = function()
                            local current = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_DATE)
                            if current == nil then current = USER_CONFIG.SHOW_BATT_DATE end
                            G_reader_settings:saveSetting(SETTINGS.SHOW_BATT_DATE, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show battery consumption rate"),
                        checked_func = function()
                            return G_reader_settings:isTrue(SETTINGS.SHOW_BATT_RATE)
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.SHOW_BATT_RATE, 
                                not G_reader_settings:isTrue(SETTINGS.SHOW_BATT_RATE))
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show battery time remaining"),
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME)
                            return val == nil or val == true
                        end,
                        callback = function()
                            local current = G_reader_settings:readSetting(SETTINGS.SHOW_BATT_TIME)
                            if current == nil then current = true end
                            G_reader_settings:saveSetting(SETTINGS.SHOW_BATT_TIME, not current)
                            invalidateSettingsCache()
                        end,
                        separator = true,
                    },
                },
            },                        
            {
                text = _("Message section"),
                sub_item_table = {
                    {
                        text = _("Custom message"),
                        help_text = _("Use a separate custom message just for Customisable Sleep Screen"),
                        checked_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "custom"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.MESSAGE_SOURCE, "custom")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Book highlights"),
                        help_text = _("Show a random highlight from the current book"),
                        checked_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "highlight"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.MESSAGE_SOURCE, "highlight")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("KOReader sleep message"),
                        help_text = _("Uses KOReaders own sleep screen message function. Enable 'Add custom message to sleep screen' to use this (Settings → Screen → Sleep screen → Sleep screen message)."),
                        enabled_func = function()
                            return G_reader_settings:isTrue(SETTINGS.SHOW_MSG_GLOBAL)
                        end,
                        checked_func = function()
                            return (G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) or "koreader") == "koreader"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.MESSAGE_SOURCE, "koreader")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Message header"),
                        keep_menu_open = true,
                        callback = function()
                            local current_header = getSetting("MSG_HEADER")
                            local box
                            box = InputDialog:new{
                                title = _("Change custom message header"),
                                input = current_header,
                                width = Screen:getWidth() * 0.8,
                                buttons = {{
                                    {
                                        text = _("Cancel"),
                                        callback = function()
                                            UIManager:close(box)
                                        end,
                                    },
                                    {
                                        text = _("Save"),
                                        callback = function()
                                            local new_header = box:getInputValue()
                                            G_reader_settings:saveSetting(SETTINGS.MSG_HEADER, new_header)
                                            invalidateSettingsCache()
                                            UIManager:close(box)
                                        end,
                                    },
                                }},
                            }
                            UIManager:show(box)
                            box:onShowKeyboard()
                        end,
                    },
                    {
                        text = _("Edit custom message"),
                        enabled_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "custom"
                        end,
                        keep_menu_open = true,
                        callback = function()
                            local current_message = G_reader_settings:readSetting(SETTINGS.CUSTOM_MESSAGE) or ""
                            
                            local input_dialog
                            input_dialog = InputDialog:new{
                                title = _("Custom Customisable Sleep Screen message"),
                                input = current_message,
                                input_type = "text",
                                width = Screen:getWidth() * 0.8,
                                buttons = {
                                    {
                                        {
                                            text = _("Cancel"),
                                            callback = function()
                                                UIManager:close(input_dialog)
                                            end,
                                        },
                                        {
                                            text = _("Save"),
                                            is_enter_default = true,
                                            callback = function()
                                                G_reader_settings:saveSetting(SETTINGS.CUSTOM_MESSAGE, input_dialog:getInputText())
                                                UIManager:close(input_dialog)
                                            end,
                                        },
                                    },
                                },
                            }
                            UIManager:show(input_dialog)
                            input_dialog:onShowKeyboard()
                        end,
                    },
                    {
                        text = _("Book highlight maximum length"),
                        help_text = _("Maximum characters for highlights (0 = no limit). Longer highlights will be truncated."),
                        enabled_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "highlight"
                        end,
                        keep_menu_open = true,
                        callback = function()
                            local SpinWidget = require("ui/widget/spinwidget")
                            local current_value = G_reader_settings:readSetting(SETTINGS.MAX_HIGHLIGHT_LENGTH) or 0
                            
                            local spin_widget = SpinWidget:new{
                                value = current_value > 0 and current_value or USER_CONFIG.MAX_HIGHLIGHT_LENGTH,
                                value_min = 0,
                                value_max = 1000,
                                value_step = 25,
                                value_hold_step = 100,
                                title_text = _("Maximum highlight length"),
                                info_text = _("Set to 0 for no limit"),
                                callback = function(spin)
                                    G_reader_settings:saveSetting(SETTINGS.MAX_HIGHLIGHT_LENGTH, spin.value)
                                end,
                            }
                            UIManager:show(spin_widget)
                        end,
                    },
                    {
                        text = _("Normalize highlight quotes"),
                        help_text = _("Wrap highlights in uniform curly double quotes, stripping any existing quote styles"),
                        enabled_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "highlight"
                        end,
                        checked_func = function()
                            local setting = G_reader_settings:readSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES)
                            if setting == nil then
                                return USER_CONFIG.HIGHLIGHT_ADD_QUOTES
                            end
                            return setting
                        end,
                        callback = function()
                            local current = G_reader_settings:readSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES)
                            if current == nil then 
                                current = USER_CONFIG.HIGHLIGHT_ADD_QUOTES 
                            end
                            G_reader_settings:saveSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES, not current)
                            invalidateSettingsCache()
                        end,
                    },
                    {
                        text = _("Show highlight location"),
                        help_text = _("Display chapter and page number below the highlight text"),
                        enabled_func = function()
                            return G_reader_settings:readSetting(SETTINGS.MESSAGE_SOURCE) == "highlight"
                        end,
                        checked_func = function()
                            return G_reader_settings:readSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION)
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION, 
                                not G_reader_settings:readSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION))
                            invalidateSettingsCache()
                        end,
                    },
                },
            },
            {
                text = _("Show titles (top line)"),
                help_text = _("Show or hide all title text across all sections. Cannot hide both titles and subtitles."),
                checked_func = function()
                    return G_reader_settings:readSetting(SETTINGS.SHOW_TITLES) ~= false
                end,
                callback = function()
                    local current_titles = G_reader_settings:readSetting(SETTINGS.SHOW_TITLES)
                    local current_subtitles = G_reader_settings:readSetting(SETTINGS.SHOW_SUBTITLES)
                    
                    if current_titles == false then
                        G_reader_settings:saveSetting(SETTINGS.SHOW_TITLES, true)
                    else
                        if current_subtitles == false then
                            local InfoMessage = require("ui/widget/infomessage")
                            UIManager:show(InfoMessage:new{
                                text = _("Cannot hide both titles and subtitles. At least one must be visible."),
                                timeout = 3,
                            })
                            return
                        else
                            G_reader_settings:saveSetting(SETTINGS.SHOW_TITLES, false)
                        end
                    end
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Show subtitles (bottom lines)"),
                help_text = _("Show or hide all subtitle text across all sections. Cannot hide both titles and subtitles."),
                checked_func = function()
                    return G_reader_settings:readSetting(SETTINGS.SHOW_SUBTITLES) ~= false
                end,
                callback = function()
                    local current_titles = G_reader_settings:readSetting(SETTINGS.SHOW_TITLES)
                    local current_subtitles = G_reader_settings:readSetting(SETTINGS.SHOW_SUBTITLES)
                    
                    if current_subtitles == false then
                        G_reader_settings:saveSetting(SETTINGS.SHOW_SUBTITLES, true)
                    else
                        if current_titles == false then
                            local InfoMessage = require("ui/widget/infomessage")
                            UIManager:show(InfoMessage:new{
                                text = _("Cannot hide both titles and subtitles. At least one must be visible."),
                                timeout = 3,
                            })
                            return
                        else
                            G_reader_settings:saveSetting(SETTINGS.SHOW_SUBTITLES, false)
                        end
                    end
                    invalidateSettingsCache()
                end,
            },
        }
    }
    menu_table[#menu_table + 1] = {
        text = _("Layout & Spacing"),
        sub_item_table = {
            {
                text = _("Reset layout & spacing settings to default"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    local box = ConfirmBox:new{
                        text = _("Are you sure you want to reset layout & spacing settings?"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS.SECTION_GAPS_ENABLED)
                            G_reader_settings:delSetting(SETTINGS.SECTION_GAP_SIZE)
                            G_reader_settings:delSetting(SETTINGS.POS)
                            G_reader_settings:delSetting(SETTINGS.BOX_WIDTH_PCT)
                            G_reader_settings:delSetting(SETTINGS.OPACITY)
                            G_reader_settings:delSetting(SETTINGS.BORDER_SIZE)
                            G_reader_settings:delSetting(SETTINGS.BORDER_SIZE_2)
                            G_reader_settings:delSetting(SETTINGS.SECTION_PADDING)
                            G_reader_settings:delSetting(SETTINGS.ICON_TEXT_GAP)
                            G_reader_settings:delSetting(SETTINGS.MARGIN)
                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Layout & spacing settings reset to defaults"),
                                timeout = 1
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            {
                text = _("Enable section gaps"),
                help_text = _("Add transparent gaps between sections to make each appear as a separate box"),
                checked_func = function()
                    local enabled = G_reader_settings:readSetting(SETTINGS.SECTION_GAPS_ENABLED)
                    if enabled == nil then enabled = USER_CONFIG.SECTION_GAPS_ENABLED end
                    return enabled
                end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.SECTION_GAPS_ENABLED)
                    if current == nil then current = USER_CONFIG.SECTION_GAPS_ENABLED end
                    G_reader_settings:saveSetting(SETTINGS.SECTION_GAPS_ENABLED, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Section gap size"),
                enabled_func = function()
                    local enabled = G_reader_settings:readSetting(SETTINGS.SECTION_GAPS_ENABLED)
                    if enabled == nil then enabled = USER_CONFIG.SECTION_GAPS_ENABLED end
                    return enabled
                end,
                keep_menu_open = true,
                callback = function()
                    local current_gap = G_reader_settings:readSetting(SETTINGS.SECTION_GAP_SIZE) or USER_CONFIG.SECTION_GAP_SIZE
                    local box
                    box = InputDialog:new{
                        title = _("Gap size between sections (0-300 pixels)"),
                        input = tostring(current_gap),
                        input_hint = "20",
                        type = "number",
                        width = Screen:getWidth() * 0.8,
                        buttons = {{
                            {text = _("Cancel"), callback = function() UIManager:close(box) end},
                            {text = _("Save"), callback = function()
                                local val = tonumber(box:getInputValue())
                                if val and val >= 0 and val <= 1200 then
                                    G_reader_settings:saveSetting(SETTINGS.SECTION_GAP_SIZE, val)
                                    invalidateSettingsCache()
                                    UIManager:close(box)
                                else
                                    local InfoMessage = require("ui/widget/infomessage")
                                    UIManager:show(InfoMessage:new{
                                        text = _("Please enter a value between 0 and 1200"),
                                        timeout = 2,
                                    })
                                end
                            end}
                        }}
                    }
                    UIManager:show(box)
                    box:onShowKeyboard()
                end,
            },
            { text = _("Position"), sub_item_table = buildPositionMenu() },
            {
                text = _("Width"),
                sub_item_table = (function()
                    local options = {}
                    for pct = 40, 100, 5 do
                        options[#options + 1] = {
                            text = string.format("%d%%", pct),
                            radio = true,
                            checked_func = function()
                                local current = getSetting("BOX_WIDTH_PCT")
                                return current == pct
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(SETTINGS.BOX_WIDTH_PCT, pct)
                                invalidateSettingsCache()
                            end,
                        }
                    end
                    return options
                end)(),
            },
            { text = _("Opacity"), sub_item_table = buildOpacityMenu() },
            { text = _("Border size"), sub_item_table = buildBorderSizeMenu() },
            { text = _("Border trim size"), sub_item_table = buildBorderSize2Menu(), help_text = _("Only active when first border is enabled. Creates an opposite-colored border around the first border for decoration.") },
            { text = _("Internal padding"), sub_item_table = buildPaddingMenu() },
            { text = _("Icon to text gap"), sub_item_table = buildIconTextGapMenu() },
            { text = _("Y-axis margin (top/bottom left/right pos)"), sub_item_table = buildMarginMenu() },
        }
    }
    menu_table[#menu_table + 1] = {
        text = _("Colours, Icons & Bars"),
        sub_item_table = {
            {
                text = _("Reset colours, icons & bars settings to default"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    
                    local box = ConfirmBox:new{
                        text = _("Are you sure you want to reset colours, icons & bars settings?"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS.COLOR_BOOK_FILL)
                            G_reader_settings:delSetting(SETTINGS.COLOR_CHAPTER_FILL)
                            G_reader_settings:delSetting(SETTINGS.COLOR_GOAL_FILL)
                            G_reader_settings:delSetting(SETTINGS.BATT_HIGH_COLOR)
                            G_reader_settings:delSetting(SETTINGS.BATT_MED_COLOR)
                            G_reader_settings:delSetting(SETTINGS.BATT_LOW_COLOR)
                            G_reader_settings:delSetting(SETTINGS.BATT_CHARGING_COLOR)
                            G_reader_settings:delSetting(SETTINGS.COLOR_MESSAGE_FILL)
                            G_reader_settings:delSetting(SETTINGS.COLOR_LIGHT)
                            G_reader_settings:delSetting(SETTINGS.COLOR_DARK)
                            G_reader_settings:delSetting(SETTINGS.ICON_USE_BAR_COLOR)
                            G_reader_settings:delSetting(SETTINGS.ICON_SET)
                            G_reader_settings:delSetting(SETTINGS.ICON_SIZE)
                            G_reader_settings:delSetting(SETTINGS.BAR_HEIGHT)
                            G_reader_settings:delSetting(SETTINGS.SHOW_ICONS)
                            G_reader_settings:delSetting(SETTINGS.SHOW_BARS)

                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Colours, icons & bars settings reset to defaults"),
                                timeout = 1
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            {
                text = _("Colours"),
                sub_item_table = (function()
                    local menu_items = {}
                    local color_items = {
                        { name = _("Book section"), key = SETTINGS.COLOR_BOOK_FILL, default = USER_CONFIG.COLOR_BOOK_FILL },
                        { name = _("Chapter section"), key = SETTINGS.COLOR_CHAPTER_FILL, default = USER_CONFIG.COLOR_CHAPTER_FILL },
                        { name = _("Reading goal section"), key = SETTINGS.COLOR_GOAL_FILL, default = USER_CONFIG.COLOR_GOAL_FILL },
                        { name = _("Battery section (High)"), key = SETTINGS.BATT_HIGH_COLOR, default = USER_CONFIG.BATT_HIGH_COLOR },
                        { name = _("Battery section (Med)"), key = SETTINGS.BATT_MED_COLOR, default = USER_CONFIG.BATT_MED_COLOR },
                        { name = _("Battery section (Low)"), key = SETTINGS.BATT_LOW_COLOR, default = USER_CONFIG.BATT_LOW_COLOR },
                        { name = _("Battery section (Charging)"), key = SETTINGS.BATT_CHARGING_COLOR, default = USER_CONFIG.BATT_CHARGING_COLOR },
                        { name = _("Message section"), key = SETTINGS.COLOR_MESSAGE_FILL, default = USER_CONFIG.COLOR_MESSAGE_FILL },
                        { name = _("Monochrome mode light"), key = SETTINGS.COLOR_LIGHT, default = USER_CONFIG.COLOR_LIGHT },
                        { name = _("Monochrome mode dark"), key = SETTINGS.COLOR_DARK, default = USER_CONFIG.COLOR_DARK },
                    }

                    menu_items[#menu_items + 1] = {
                        text = _("Use saved colours for icon fill"),
                        separator = true,
                        checked_func = function()
                            local val = G_reader_settings:readSetting(SETTINGS.ICON_USE_BAR_COLOR)
                            return val == nil and USER_CONFIG.ICON_USE_BAR_COLOR or val
                        end,
                        callback = function()
                            local current = G_reader_settings:readSetting(SETTINGS.ICON_USE_BAR_COLOR)
                            if current == nil then current = USER_CONFIG.ICON_USE_BAR_COLOR end
                            G_reader_settings:saveSetting(SETTINGS.ICON_USE_BAR_COLOR, not current)
                            invalidateSettingsCache()
                        end,
                    }

                    for i, item in ipairs(color_items) do
                        menu_items[#menu_items + 1] = {
                            text = item.name,
                            keep_menu_open = true,
                            callback = function()
                                local current_color = G_reader_settings:readSetting(item.key) or item.default
                                local h, s, v = hexToHSV(current_color)
                                local wheel = ColorWheelWidget:new({
                                    title_text = item.name,
                                    hue = h,
                                    saturation = s,
                                    value = v,
                                    callback = function(hex)
                                        G_reader_settings:saveSetting(item.key, hex)
                                        invalidateSettingsCache()
                                        UIManager:setDirty(nil, "ui")
                                    end,
                                    cancel_callback = function()
                                        UIManager:setDirty(nil, "ui")
                                    end,
                                })
                                UIManager:show(wheel)
                            end
                        }
                    end
                    return menu_items
                end)(),
            },
            {
                text = _("Icon set"),
                sub_item_table = buildIconSetMenu(),
            },
            {
                text = _("Icon size"),
                subtext = (getSetting("ICON_SIZE") or 0) .. " px",
                sub_item_table = (function()
                    local _sub_items = {}
                    for size = 24, 96, 8 do
                        table.insert(_sub_items, {
                            text = size .. " px",
                            radio = true,
                            checked_func = function()
                                return getSetting("ICON_SIZE") == size
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(SETTINGS.ICON_SIZE, size)
                                invalidateSettingsCache()
                            end,
                        })
                    end
                    return _sub_items
                end)(),
            },
            { text = _("Progress bar height"), sub_item_table = buildBarHeightMenu() },
            {
                text = _("Show icons"),
                checked_func = function() return G_reader_settings:readSetting(SETTINGS.SHOW_ICONS) ~= false end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.SHOW_ICONS) ~= false
                    G_reader_settings:saveSetting(SETTINGS.SHOW_ICONS, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Show progress bars"),
                checked_func = function() return G_reader_settings:readSetting(SETTINGS.SHOW_BARS) ~= false end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.SHOW_BARS) ~= false
                    G_reader_settings:saveSetting(SETTINGS.SHOW_BARS, not current)
                    invalidateSettingsCache()
                end,
            },
        }
    }
    menu_table[#menu_table + 1] = {
        text = _("Fonts & Text"),
        sub_item_table = {
            {
                text = _("Reset fonts & text settings to default"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    
                    local box = ConfirmBox:new{
                        text = _("Are you sure you want to reset fonts & texts settings?"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS.FONT_FACE_TITLE)
                            G_reader_settings:delSetting(SETTINGS.FONT_SIZE_TITLE)
                            G_reader_settings:delSetting(SETTINGS.FONT_FACE_SUBTITLE)
                            G_reader_settings:delSetting(SETTINGS.FONT_SIZE_SUBTITLE)
                            G_reader_settings:delSetting(SETTINGS.TEXT_ALIGN)
                            G_reader_settings:delSetting(SETTINGS.BOOK_MULTILINE)
                            G_reader_settings:delSetting(SETTINGS.CHAP_MULTILINE)
                            G_reader_settings:delSetting(SETTINGS.CLEAN_CHAP)
                            G_reader_settings:delSetting(SETTINGS.BOOK_TITLE_BOLD)
                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Fonts & texts settings reset to defaults"),
                                timeout = 1
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            {
                text = _("Title font face"),
                sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_TITLE),
            },
            {
                text = _("Title font size"),
                sub_item_table = (function()
                    local options = {}
                    for i = 5, 20 do
                        options[#options + 1] = {
                            text = tostring(i),
                            radio = true,
                            checked_func = function()
                                local current = getSetting("FONT_SIZE_TITLE")
                                return current == i
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(SETTINGS.FONT_SIZE_TITLE, i)
                                invalidateSettingsCache()
                            end,
                        }
                    end
                    return options
                end)(),
            },
            {
                text = _("Subtitle font face"),
                sub_item_table = buildFontFaceMenu(SETTINGS.FONT_FACE_SUBTITLE),
            },
            {
                text = _("Subtitle font size"),
                sub_item_table = (function()
                    local options = {}
                    for i = 5, 20 do
                        options[#options + 1] = {
                            text = tostring(i),
                            radio = true,
                            checked_func = function()
                                local current = getSetting("FONT_SIZE_SUBTITLE")
                                return current == i
                            end,
                            callback = function()
                                G_reader_settings:saveSetting(SETTINGS.FONT_SIZE_SUBTITLE, i)
                                invalidateSettingsCache()
                            end,
                        }
                    end
                    return options
                end)(),
            },
            {
                text = _("Text alignment"),
                sub_item_table = {
                    {
                        text = _("Left"),
                        checked_func = function()
                            return (getSetting("TEXT_ALIGN")) == "left"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.TEXT_ALIGN, "left")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Center"),
                        checked_func = function()
                            return (getSetting("TEXT_ALIGN")) == "center"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.TEXT_ALIGN, "center")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Right"),
                        checked_func = function()
                            return (getSetting("TEXT_ALIGN")) == "right"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.TEXT_ALIGN, "right")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                },
            },
            {
                text = _("Book multiline titles"),
                help_text = _("If deselected book titles will be truncated to a single line with an ellipsis"),
                checked_func = function()
                    local val = G_reader_settings:readSetting(SETTINGS.BOOK_MULTILINE)
                    return val == nil and USER_CONFIG.BOOK_MULTILINE or val
                end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.BOOK_MULTILINE)
                    if current == nil then current = USER_CONFIG.BOOK_MULTILINE end
                    G_reader_settings:saveSetting(SETTINGS.BOOK_MULTILINE, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Chapter multiline titles"),
                help_text = _("If deselected chapter titles will be truncated to a single line with an ellipsis"),
                checked_func = function()
                    local val = G_reader_settings:readSetting(SETTINGS.CHAP_MULTILINE)
                    return val == nil and USER_CONFIG.CHAP_MULTILINE or val
                end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.CHAP_MULTILINE)
                    if current == nil then current = USER_CONFIG.CHAP_MULTILINE end
                    G_reader_settings:saveSetting(SETTINGS.CHAP_MULTILINE, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Clean chapter titles"),
                help_text = _("Removes redundant prefixes like 'Chapter 5:' from chapter titles, leaving only the chapter name. If no chapter name is present then returns as is."),
                checked_func = function()
                    local val = G_reader_settings:readSetting(SETTINGS.CLEAN_CHAP)
                    return val == nil and USER_CONFIG.CLEAN_CHAP or val
                end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.CLEAN_CHAP)
                    if current == nil then current = USER_CONFIG.CLEAN_CHAP end
                    G_reader_settings:saveSetting(SETTINGS.CLEAN_CHAP, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Make book title bold"),
                checked_func = function()
                    return G_reader_settings:isTrue(SETTINGS.BOOK_TITLE_BOLD)
                end,
                callback = function()
                    G_reader_settings:flipNilOrFalse(SETTINGS.BOOK_TITLE_BOLD)
                    invalidateSettingsCache()
                end,
            },
        }
    }
    menu_table[#menu_table + 1] = {
        text = _("Background"),
        sub_item_table = {
            {
                text = _("Reset background settings to default"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    
                    local box = ConfirmBox:new{
                        text = _("Are you sure you want to reset background settings?"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            G_reader_settings:delSetting(SETTINGS.BG_DIMMING)
                            G_reader_settings:delSetting(SETTINGS.BG_DIMMING_COLOR)
                            G_reader_settings:delSetting(SETTINGS.BG_TYPE)
                            G_reader_settings:delSetting(SETTINGS.BG_FOLDER)
                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Background settings reset to defaults"),
                                timeout = 1
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            { text = _("Background type"), sub_item_table = buildBackgroundTypeMenu() },
            { text = _("Background overlay"), sub_item_table = buildDimmingMenu() },
        }
    }

    menu_table[#menu_table + 1] = {
        text = _("Advanced"),
        sub_item_table = {
            {
                text = _("Reset all settings to default"),
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    local box
                    box = ConfirmBox:new{
                        text = _("Are you sure you want to reset all Customisable Sleep Screen settings to their defaults? (Don't worry, user saved presets are preserved)"),
                        ok_text = _("Reset"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()
                            for key_name, setting_key in pairs(SETTINGS) do
                                if key_name ~= "TYPE" 
                                and key_name ~= "PRESETS" 
                                and key_name ~= "ACTIVE_PRESET" then
                                    G_reader_settings:delSetting(setting_key)
                                end
                            end
                            invalidateSettingsCache()
                            UIManager:show(InfoMessage:new{
                                text = _("Settings reset. Re-open sleep screen to see changes."),
                                timeout = 2,
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            {
                text = _("Delete all presets"),
                separator = true,
                keep_menu_open = true,
                callback = function()
                    local ConfirmBox = require("ui/widget/confirmbox")
                    local InfoMessage = require("ui/widget/infomessage")
                    local box
                    box = ConfirmBox:new{
                        text = _("Are you sure you want to delete all presets? This will keep the 'Default' preset but remove all custom presets."),
                        ok_text = _("Delete"),
                        cancel_text = _("Cancel"),
                        ok_callback = function()

                            local defaults_only = {
                                ["Default"] = getDefaultSettings()
                            }
                            G_reader_settings:saveSetting(SETTINGS.PRESETS, defaults_only)
                            G_reader_settings:delSetting(SETTINGS.ACTIVE_PRESET)
                            
                            UIManager:show(InfoMessage:new{
                                text = _("All custom presets deleted. Only 'Default' preset remains."),
                                timeout = 2,
                            })
                        end,
                    }
                    UIManager:show(box)
                end,
            },
            {
                text = _("Battery time calculation"),
                sub_item_table = {
                    {
                        text = _("Since last charge"),
                        help_text = _("Uses combined awake and sleeping battery drain since last charge"),
                        checked_func = function()
                            return (getSetting("BATT_STAT_TYPE")) == "discharging"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.BATT_STAT_TYPE, "discharging")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Awake since last charge"),
                        help_text = _("Uses only active reading battery drain (more conservative estimate)"),
                        checked_func = function()
                            return (getSetting("BATT_STAT_TYPE")) == "awake"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.BATT_STAT_TYPE, "awake")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Sleeping since last charge"),
                        help_text = _("Uses only sleep mode battery drain"),
                        checked_func = function()
                            return (getSetting("BATT_STAT_TYPE")) == "sleeping"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.BATT_STAT_TYPE, "sleeping")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Manual calculation"),
                        help_text = _("Use a custom battery drain rate (1-10% per hour)"),
                        checked_func = function()
                            return (getSetting("BATT_STAT_TYPE")) == "manual"
                        end,
                        callback = function()
                            G_reader_settings:saveSetting(SETTINGS.BATT_STAT_TYPE, "manual")
                            invalidateSettingsCache()
                        end,
                        radio = true,
                    },
                    {
                        text = _("Set manual drain rate"),
                        enabled_func = function()
                            return (G_reader_settings:readSetting(SETTINGS.BATT_STAT_TYPE) or USER_CONFIG.BATT_STAT_TYPE) == "manual"
                        end,
                        keep_menu_open = true,
                        callback = function()
                            local current_rate = G_reader_settings:readSetting(SETTINGS.BATT_MANUAL_RATE) or USER_CONFIG.BATT_MANUAL_RATE
                            local box
                            box = InputDialog:new{
                                title = _("Battery drain rate per hour (1.0% - 10.0%)"),
                                input = string.format("%.1f", current_rate),
                                input_hint = "2.5",
                                type = "number",
                                width = Screen:getWidth() * 0.8,
                                buttons = {{
                                    {text = _("Cancel"), callback = function() UIManager:close(box) end},
                                    {text = _("Save"), callback = function()
                                        local val = tonumber(box:getInputValue())
                                        if val and val >= 1 and val <= 10 then
                                            G_reader_settings:saveSetting(SETTINGS.BATT_MANUAL_RATE, val)
                                            invalidateSettingsCache()
                                            UIManager:close(box)
                                        else
                                            local InfoMessage = require("ui/widget/infomessage")
                                            UIManager:show(InfoMessage:new{
                                                text = _("Please enter a value between 1% - 10%"),
                                                timeout = 2,
                                            })
                                        end
                                    end}
                                }}
                            }
                            UIManager:show(box)
                            box:onShowKeyboard()
                        end,
                        separator = true,
                    },
                }
            },
            {
                text = _("Show in file manager (outside of book)"),
                help_text = _("Display Customisable Sleep Screen even when no book is open"),
                checked_func = function()
                    local val = G_reader_settings:readSetting(SETTINGS.SHOW_IN_FILEMANAGER)
                    return val == nil or val == true
                end,
                callback = function()
                    local current = G_reader_settings:readSetting(SETTINGS.SHOW_IN_FILEMANAGER)
                    if current == nil then current = true end
                    G_reader_settings:saveSetting(SETTINGS.SHOW_IN_FILEMANAGER, not current)
                    invalidateSettingsCache()
                end,
            },
            {
                text = _("Hide built-in presets (except Default)"),
                help_text = _("When enabled, only the Default preset and your custom presets will be shown"),
                checked_func = function() 
                    return G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS) 
                end,
                callback = function()
                    G_reader_settings:saveSetting(SETTINGS.HIDE_PRELOADED_PRESETS, 
                        not G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS))
                    invalidateSettingsCache()
                    
                    local InfoMessage = require("ui/widget/infomessage")
                    UIManager:show(InfoMessage:new{
                        text = _("Setting saved. Preset list will update when you reopen this menu."),
                        timeout = 2,
                    })
                end,
            },
            {
                text = _("Enable memory logging"),
                help_text = _("Logs memory usage to console for performance monitoring"),
                checked_func = function() 
                    return G_reader_settings:isTrue(SETTINGS.DEBUG) 
                end,
                callback = function()
                    G_reader_settings:saveSetting(SETTINGS.DEBUG, 
                        not G_reader_settings:isTrue(SETTINGS.DEBUG))
                    invalidateSettingsCache()
                end,
            },
        }
    }

    menu_table[#menu_table + 1] = {
        text = _("About"),
        keep_menu_open = true,
        callback = function()
            local InfoMessage = require("ui/widget/infomessage")
            UIManager:show(InfoMessage:new{
                text = string.format(_("%s\nVersion: %s\n\nFor updates and issues:\ngithub.com/%s"), 
                    PATCH_NAME, PATCH_VERSION, GITHUB_REPO),
                timeout = 5,
            })
        end,
    }
    
    return menu_table
end

-------------------------------------------------------------------------
-- Hooks & Integration
-------------------------------------------------------------------------

local Screensaver = require("ui/screensaver")
local orig_show = Screensaver.show

Screensaver.show = function(self)
    local screensaver_type = G_reader_settings:readSetting("screensaver_type")
    if screensaver_type ~= "customisable_ss" then return orig_show(self) end

    local saved_version = G_reader_settings:readSetting(SETTINGS.VERSION)
    if saved_version ~= PATCH_VERSION then
        G_reader_settings:saveSetting(SETTINGS.VERSION, PATCH_VERSION)

        if not G_reader_settings:readSetting(SETTINGS.FONT_FACE_TITLE) then
            G_reader_settings:saveSetting(SETTINGS.FONT_FACE_TITLE, USER_CONFIG.FONT_FACE_TITLE)
        end
        if not G_reader_settings:readSetting(SETTINGS.FONT_FACE_SUBTITLE) then
            G_reader_settings:saveSetting(SETTINGS.FONT_FACE_SUBTITLE, USER_CONFIG.FONT_FACE_SUBTITLE)
        end
        if not G_reader_settings:readSetting(SETTINGS.FONT_SIZE_TITLE) then
            G_reader_settings:saveSetting(SETTINGS.FONT_SIZE_TITLE, USER_CONFIG.FONT_SIZE_TITLE)
        end
        if not G_reader_settings:readSetting(SETTINGS.FONT_SIZE_SUBTITLE) then
            G_reader_settings:saveSetting(SETTINGS.FONT_SIZE_SUBTITLE, USER_CONFIG.FONT_SIZE_SUBTITLE)
        end
        
        invalidateSettingsCache()
    end

    local ui = ReaderUI.instance
    local widget = nil
    
    if ui and ui.document then
        collectgarbage("collect")
        log_memory("START Screensaver Trigger")
        
        local state = ui.view and ui.view.state
        local book_data = collectBookData(ui, state)
        
        if book_data then
            saveLastBookData(book_data)
            widget = buildInfoBox(ui, state)
        end
    else
        local show_in_fm = G_reader_settings:readSetting(SETTINGS.SHOW_IN_FILEMANAGER)
        if show_in_fm == nil then show_in_fm = true end
        if not show_in_fm then
            return orig_show(self)
        end
        
        local book_data = loadLastBookData()
        if book_data then
            log_memory("START Screensaver Trigger (from saved data)")
            widget = buildInfoBox(nil, nil, book_data)
        end
    end

    if not widget then
        return orig_show(self)
    end

    if self.screensaver_widget then
        UIManager:close(self.screensaver_widget)
        self.screensaver_widget = nil
    end

    Device.screen_saver_mode = true

    log_memory("AFTER Widget Build")

    self.screensaver_widget = ScreenSaverWidget:new{ widget = widget, covers_fullscreen = true }
    UIManager:show(self.screensaver_widget, "full")

    log_memory("END Screensaver Displayed")
end

local orig_dofile = dofile
_G.dofile = function(filepath)
    local result = orig_dofile(filepath)
    if filepath and filepath:match("screensaver_menu%.lua$") then
        local menu = result[1].sub_item_table
        
        table.insert(menu, 6, {
            text = _("Customisable sleep screen"),
            checked_func = function() return G_reader_settings:readSetting(SETTINGS.TYPE) == "customisable_ss" end,
            callback = function() G_reader_settings:saveSetting(SETTINGS.TYPE, "customisable_ss"); invalidateSettingsCache() end,
            radio = true,
        })

        table.insert(menu, 7, {
            id = "customisable_ss_settings", 
            text = _("Customisable sleep screen settings"),
            enabled_func = function() return G_reader_settings:readSetting(SETTINGS.TYPE) == "customisable_ss" end,
            separator = true,
            sub_item_table = getCustomisableSleepScreenSettingsMenu()
        })
    end
    return result
end

if Dispatcher and Dispatcher.registerAction then
    Dispatcher:registerAction("customisable_ss_settings", {
        category = "none",
        event = "ShowCustomisableSleepScreenSettings",
        title = _("Customisable sleep screen settings"),
        general = true,
    })

    Dispatcher:registerAction("customisable_ss_presets", {
        category = "none",
        event = "ShowCustomisableSleepScreenPresets",
        title = _("Customisable sleep screen presets"),
        general = true,
    })
end

local orig_ReaderUI_registerKeyEvents = ReaderUI.registerKeyEvents
ReaderUI.registerKeyEvents = function(self)
    if orig_ReaderUI_registerKeyEvents then
        orig_ReaderUI_registerKeyEvents(self)
    end
    
    self.onShowCustomisableSleepScreenSettings = function(this)
        if not this.menu then return true end
        
        log_memory("BEFORE Opening Settings Menu")

        local Menu = require("ui/widget/menu")
        local menu_widget = Menu:new{
            title = _("Customisable sleep screen settings"),
            item_table = getCustomisableSleepScreenSettingsMenu(true),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            is_enable_shortcut = false,
        }
        
        UIManager:show(menu_widget)
        
        log_memory("AFTER Opening Settings Menu")

        return true
    end

    self.onShowCustomisableSleepScreenPresets = function(this)
        if not this.menu then return true end
        
        local Menu = require("ui/widget/menu")
        local menu_widget = Menu:new{
            title = _("Customisable sleep screen presets"),
            item_table = buildPresetManagementMenu(true),
            width = Screen:getWidth(),
            height = Screen:getHeight(),
            is_enable_shortcut = false,
        }
        
        UIManager:show(menu_widget)
        
        return true
    end
end
