-- Menu items for the Contents section: controls which data each section displays.

local UIManager = require("ui/uimanager")

local _           = require("plugin_gettext")
local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS

local h                       = require("menu_helpers")
local getSetting              = h.getSetting
local createToggleItem        = h.createToggleItem
local createFlipNilOrTrueItem = h.createFlipNilOrTrueItem
local createRadioItem         = h.createRadioItem
local createSpinDialog        = h.createSpinDialog
local createTextInputDialog   = h.createTextInputDialog
local createResetMenuItem     = h.createResetMenuItem

local DAILY_GOAL_DEFAULT = USER_CONFIG.DAILY_GOAL

local function buildSectionOrderMenu()
    local section_labels = {
        book    = _("Book info"),
        chapter = _("Chapter info"),
        goal    = _("Daily info"),
        battery = _("Battery info"),
        message = _("Message info"),
    }

    local label_to_key = {}
    for k, v in pairs(section_labels) do label_to_key[v] = k end

    return {
        {
            text           = _("Reorder sections"),
            keep_menu_open = true,
            callback = function()
                local SortWidget = require("ui/widget/sortwidget")

                local saved      = getSetting("SECTION_ORDER") or {}
                local defaults   = USER_CONFIG.SECTION_ORDER
                local item_table = {}
                for i = 1, #defaults do
                    local key     = saved[i] or defaults[i]
                    item_table[i] = { text = section_labels[key] or key }
                end

                UIManager:show(SortWidget:new {
                    title      = _("Section order"),
                    item_table = item_table,
                    callback   = function(self)
                        local new_order = {}
                        for i, item in ipairs(self.item_table) do
                            new_order[i] = label_to_key[item.text] or item.text
                        end
                        G_reader_settings:saveSetting(SETTINGS.SECTION_ORDER, new_order)
                    end,
                })
            end,
        },
    }
end

local function buildVisibilityMenu()
    local items = {
        { text = _("Book info"),      key = SETTINGS.SHOW_BOOK },
        { text = _("Chapter info"),   key = SETTINGS.SHOW_CHAP },
        { text = _("Daily info"),     key = SETTINGS.SHOW_GOAL },
        { text = _("Battery info"),   key = SETTINGS.SHOW_BATT },
        { text = _("Message info"),   key = SETTINGS.SHOW_MSG  },
    }

    local function countVisibleSections()
        local count = 0
        for i, item in ipairs(items) do
            if G_reader_settings:readSetting(item.key) ~= false then count = count + 1 end
        end
        return count
    end

    local sub_menu = {}
    for i, item in ipairs(items) do
        sub_menu[#sub_menu + 1] = {
            text   = item.text,
            toggle = true,
            enabled_func = function()
                local is_current_enabled = G_reader_settings:readSetting(item.key) ~= false
                if is_current_enabled then return countVisibleSections() > 1 end
                return true
            end,
            checked_func = function()
                return G_reader_settings:readSetting(item.key) ~= false
            end,
            callback = function()
                local current      = G_reader_settings:readSetting(item.key) ~= false
                local visible_count = countVisibleSections()
                if current and visible_count <= 1 then
                    UIManager:show(require("ui/widget/infomessage"):new {
                        text    = _("At least one section must remain visible."),
                        timeout = 2,
                    })
                    return
                end
                G_reader_settings:saveSetting(item.key, not current)
            end,
        }
    end
    return sub_menu
end

local function buildBookSectionContentMenu()
    return {
        createToggleItem(_("Show book author"),
            _("Display the author name below the book title."),
            SETTINGS.SHOW_BOOK_AUTHOR, false),
        createToggleItem(_("Show series name"),
            _("Display the book's series name and index below the title."),
            SETTINGS.SHOW_BOOK_SERIES, false),
        createToggleItem(_("Show book pages (pg x of x)"),
            _("Display total page count for the entire book."),
            SETTINGS.SHOW_BOOK_PAGES, false),
        createFlipNilOrTrueItem(_("Show book time remaining"),
            _("Estimated reading time left to finish the book, based on your average reading speed."),
            SETTINGS.SHOW_BOOK_TIME_REMAINING),
    }
end

local function buildChapterSectionContentMenu()
    return {
        createToggleItem(_("Show chapter count (ch x of x)"),
            _("Display current chapter number and total chapters (e.g., 'Chapter 5 of 12')."),
            SETTINGS.SHOW_CHAP_COUNT, false),
        createToggleItem(_("Show chapter pages (pg x of x)"),
            _("Display the number of pages in the current chapter."),
            SETTINGS.SHOW_CHAP_PAGES, false),
        createFlipNilOrTrueItem(_("Show chapter time remaining"),
            _("Estimated time to finish the current chapter, based on your reading speed."),
            SETTINGS.SHOW_CHAP_TIME_REMAINING),
    }
end

local function buildGoalSectionContentMenu()
    local function isTimeGoal()
        return (getSetting("GOAL_TYPE") or USER_CONFIG.GOAL_TYPE or "pages") == "time"
    end

    return {
        {
            text      = _("Title Line"),
            help_text = _("Choose what the top line of the daily info section displays."),
            sub_item_table = {
                createRadioItem(
                    _("Pages read today"),
                    _("e.g. '35 pages read today'"),
                    SETTINGS.GOAL_TITLE_TYPE, "pages"
                ),
                createRadioItem(
                    _("Time read today"),
                    _("e.g. '42 mins read today'"),
                    SETTINGS.GOAL_TITLE_TYPE, "time"
                ),
                createRadioItem(
                    _("Pages and time read today"),
                    _("e.g. '35 pgs & 42 mins read today'"),
                    SETTINGS.GOAL_TITLE_TYPE, "both"
                ),
            },
        },
        {
            text      = _("Goal type"),
            help_text = _("Choose whether your daily goal tracks pages read or time spent reading."),
            sub_item_table = {
                {
                    text         = _("Page goal"),
                    help_text    = _("Track daily progress by number of pages read."),
                    checked_func = function()
                        local val = G_reader_settings:readSetting(SETTINGS.GOAL_TYPE)
                        return val == nil or val == "pages"
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(SETTINGS.GOAL_TYPE, "pages")
                    end,
                    radio = true,
                },
                {
                    text         = _("Time goal"),
                    help_text    = _("Track daily progress by minutes spent reading."),
                    checked_func = function()
                        return G_reader_settings:readSetting(SETTINGS.GOAL_TYPE) == "time"
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(SETTINGS.GOAL_TYPE, "time")
                    end,
                    radio = true,
                },
            },
        },
        {
            text           = _("Daily page goal"),
            help_text      = _("Set how many pages you aim to read each day."),
            enabled_func   = function() return not isTimeGoal() end,
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Daily page goal"),
                    getSetting("DAILY_GOAL") or DAILY_GOAL_DEFAULT,
                    1, 1000, 5,
                    function(val) G_reader_settings:saveSetting(SETTINGS.DAILY_GOAL, val) end,
                    nil, nil, 25
                )
            end,
        },
        {   
            text           = _("Daily time goal"),
            help_text      = _("Set how many minutes you aim to read each day."),
            enabled_func   = function() return isTimeGoal() end,
            keep_menu_open = true,
            callback = function()
                createSpinDialog(
                    _("Daily time goal (minutes)"),
                    getSetting("DAILY_GOAL_MINUTES") or USER_CONFIG.DAILY_GOAL_MINUTES,
                    1, 480, 5,
                    function(val) G_reader_settings:saveSetting(SETTINGS.DAILY_GOAL_MINUTES, val) end,
                    nil, nil, 15
                )
            end,
        },
        createToggleItem(_("Show current reading streak"),
            _("Display consecutive days you've met your reading goal."),
            SETTINGS.SHOW_GOAL_STREAK, false),
        createToggleItem(_("Show weekly progress"),
            _("Days this week you have met your reading goal, shown as completed days out of the current weekday (Monday = 1... Sunday = 7). For example: Thursday with goals met on Monday and Tuesday will show 2/4."),
            SETTINGS.SHOW_GOAL_ACHIEVEMENT, false),
        {   
            text      = _("Show daily goal"),
            help_text = _("Target page mode: e.g. 50 page goal. Target time mode: e.g. 1hr 15min time goal."),
            checked_func = function()
                local val = G_reader_settings:readSetting(SETTINGS.SHOW_GOAL_PAGES)
                return val == nil or val == true
            end,
            callback = function()
                G_reader_settings:flipNilOrTrue(SETTINGS.SHOW_GOAL_PAGES)
            end,
        },
    }
end

local function buildBatterySectionContentMenu()
    return {
        {
            text      = _("Show current time/date on separate line"),
            help_text = _("Display time/date on its own line below battery percentage instead of inline."),
            help_text_func = function()
                local val = getSetting("SHOW_BATT_TIME")
                if val == false then return _("Enable 'Show battery time remaining' to use this option") end
                return nil
            end,
            enabled_func = function()
                local val = getSetting("SHOW_BATT_TIME")
                return val == nil or val == true
            end,
            checked_func = function() return G_reader_settings:isTrue(SETTINGS.SHOW_BATT_TIME_SEPARATE) end,
            callback     = function() G_reader_settings:flipNilOrFalse(SETTINGS.SHOW_BATT_TIME_SEPARATE) end,
        },
        {
            text      = _("Show date instead of time"),
            help_text = _("Display current date (e.g. '29th Jan') instead of time in battery section"),
            checked_func = function() return getSetting("SHOW_BATT_DATE") end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.SHOW_BATT_DATE, not getSetting("SHOW_BATT_DATE"))
            end,
        },
        createToggleItem(_("Show battery consumption rate"),
            _("Display battery drain percentage per hour based on recent usage or manual input (see advanced menu)"),
            SETTINGS.SHOW_BATT_RATE, false),
        createFlipNilOrTrueItem(_("Show battery time remaining"),
            _("Estimated hours and minutes until battery is depleted, based on current drain rate."),
            SETTINGS.SHOW_BATT_TIME, true),
    }
end

local function buildMessageSectionContentMenu()
    return {
        createRadioItem(_("Custom message"),
            _("Use a separate custom message just for Customisable Sleep Screen"),
            SETTINGS.MESSAGE_SOURCE, "custom"),
        createRadioItem(_("Book highlights"),
            _("Show a random highlight from the current book"),
            SETTINGS.MESSAGE_SOURCE, "highlight"),
        createRadioItem(_("Custom quotes"),
            _("Show a random quote from the custom_quotes.lua file in the plugin folder."),
            SETTINGS.MESSAGE_SOURCE, "custom_quotes"),
        createRadioItem(_("KOReader sleep message"),
            _("Uses KOReaders own sleep screen message function. Enable 'Add custom message to sleep screen' to use this (Settings → Screen → Sleep screen → Sleep screen message)."),
            SETTINGS.MESSAGE_SOURCE, "koreader",
            function() return G_reader_settings:isTrue(SETTINGS.SHOW_MSG_GLOBAL) end),
        {
            text           = _("Message header"),
            help_text      = _("Custom header text displayed above the message. Supports variables: %d, %y, %t, %b, %r."),
            keep_menu_open = true,
            callback = function()
                createTextInputDialog(_("Change custom message header"), getSetting("MSG_HEADER"),
                    function(value) G_reader_settings:saveSetting(SETTINGS.MSG_HEADER, value) end)
            end,
        },
        {
            text           = _("Edit custom message"),
            help_text      = _("Write your custom message text. Only active when 'Custom message' is selected. Supports variables: %d, %y, %t, %b, %r."),
            enabled_func   = function() return getSetting("MESSAGE_SOURCE") == "custom" end,
            keep_menu_open = true,
            callback = function()
                createTextInputDialog(_("Custom Customisable Sleep Screen message"),
                    getSetting("CUSTOM_MESSAGE") or "",
                    function(value) G_reader_settings:saveSetting(SETTINGS.CUSTOM_MESSAGE, value) end)
            end,
        },
        {
            text           = _("Book highlight maximum length"),
            help_text      = _("Maximum characters to display for highlights (0 = no limit)."),
            enabled_func   = function() return getSetting("MESSAGE_SOURCE") == "highlight" end,
            keep_menu_open = true,
            callback = function()
                local current_value = getSetting("MAX_HIGHLIGHT_LENGTH") or 0
                createSpinDialog(
                    _("Maximum highlight length"),
                    current_value > 0 and current_value or USER_CONFIG.MAX_HIGHLIGHT_LENGTH,
                    0, 1000, 25,
                    function(val) G_reader_settings:saveSetting(SETTINGS.MAX_HIGHLIGHT_LENGTH, val) end,
                    _("Set to 0 for no limit"),
                    nil, 100
                )
            end,
        },
        {
            text      = _("Add quotation marks to highlights"),
            help_text = _("Wraps all highlights in curly double quotes, removing any pre-existing quotation marks."),
            enabled_func = function() return getSetting("MESSAGE_SOURCE") == "highlight" end,
            checked_func = function()
                local setting = getSetting("HIGHLIGHT_ADD_QUOTES")
                return setting == nil and USER_CONFIG.HIGHLIGHT_ADD_QUOTES or setting
            end,
            callback = function()
                local current = getSetting("HIGHLIGHT_ADD_QUOTES")
                if current == nil then current = USER_CONFIG.HIGHLIGHT_ADD_QUOTES end
                G_reader_settings:saveSetting(SETTINGS.HIGHLIGHT_ADD_QUOTES, not current)
            end,
        },
        {
            text      = _("Show highlight location"),
            help_text = _("Display the chapter title and page number where the highlight is found, shown below the highlight text."),
            enabled_func = function() return getSetting("MESSAGE_SOURCE") == "highlight" end,
            checked_func = function() return getSetting("SHOW_HIGHLIGHT_LOCATION") end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.SHOW_HIGHLIGHT_LOCATION,
                    not getSetting("SHOW_HIGHLIGHT_LOCATION"))
            end,
        },
        {
            text         = _("Show quote attribution"),
            help_text    = _("Display the author and book name below the quote, if provided in custom_quotes.lua."),
            enabled_func = function() return getSetting("MESSAGE_SOURCE") == "custom_quotes" end,
            checked_func = function() return getSetting("SHOW_QUOTE_ATTRIBUTION") end,
            callback = function()
                G_reader_settings:saveSetting(SETTINGS.SHOW_QUOTE_ATTRIBUTION,
                    not getSetting("SHOW_QUOTE_ATTRIBUTION"))
            end,
        },
    }
end

local function buildTitleSubtitleToggles()
    return {
        {
            text      = _("Show titles (top line)"),
            help_text = _("Display the main heading text in each section. At least one of titles or subtitles must be visible."),
            checked_func = function() return getSetting("SHOW_TITLES") ~= false end,
            callback = function()
                local current_titles    = getSetting("SHOW_TITLES")
                local current_subtitles = getSetting("SHOW_SUBTITLES")
                if current_titles == false then
                    G_reader_settings:saveSetting(SETTINGS.SHOW_TITLES, true)
                else
                    if current_subtitles == false then
                        UIManager:show(require("ui/widget/infomessage"):new {
                            text    = _("Cannot hide both titles and subtitles. At least one must be visible."),
                            timeout = 3,
                        })
                        return
                    else
                        G_reader_settings:saveSetting(SETTINGS.SHOW_TITLES, false)
                    end
                end
            end,
        },
        {
            text      = _("Show subtitles (bottom lines)"),
            help_text = _("Display information below main heading text in each section. At least one of titles or subtitles must be visible."),
            checked_func = function() return getSetting("SHOW_SUBTITLES") ~= false end,
            callback = function()
                local current_titles    = getSetting("SHOW_TITLES")
                local current_subtitles = getSetting("SHOW_SUBTITLES")
                if current_subtitles == false then
                    G_reader_settings:saveSetting(SETTINGS.SHOW_SUBTITLES, true)
                else
                    if current_titles == false then
                        UIManager:show(require("ui/widget/infomessage"):new {
                            text    = _("Cannot hide both titles and subtitles. At least one must be visible."),
                            timeout = 3,
                        })
                        return
                    else
                        G_reader_settings:saveSetting(SETTINGS.SHOW_SUBTITLES, false)
                    end
                end
            end,
        },
    }
end

local function buildContentsMenu()
    local menu = {
        createResetMenuItem("contents", {
            SETTINGS.SHOW_BOOK,                SETTINGS.SHOW_CHAP,
            SETTINGS.SHOW_GOAL,                SETTINGS.SHOW_BATT,
            SETTINGS.SHOW_MSG,                 SETTINGS.SECTION_ORDER,
            SETTINGS.SHOW_BOOK_AUTHOR,         SETTINGS.SHOW_BOOK_PAGES,
            SETTINGS.SHOW_BOOK_TIME_REMAINING, SETTINGS.SHOW_CHAP_COUNT,
            SETTINGS.SHOW_CHAP_PAGES,          SETTINGS.SHOW_CHAP_TIME_REMAINING,
            SETTINGS.DAILY_GOAL,               SETTINGS.GOAL_TYPE,
            SETTINGS.DAILY_GOAL_MINUTES,       SETTINGS.SHOW_GOAL_STREAK,         
            SETTINGS.SHOW_GOAL_ACHIEVEMENT,    SETTINGS.SHOW_GOAL_PAGES,
            SETTINGS.GOAL_TITLE_TYPE,         
            SETTINGS.SHOW_BATT_TIME_SEPARATE,  SETTINGS.SHOW_BATT_DATE,           
            SETTINGS.SHOW_BATT_RATE,           SETTINGS.SHOW_BATT_TIME,           
            SETTINGS.MESSAGE_SOURCE,           SETTINGS.MSG_HEADER,               
            SETTINGS.CUSTOM_MESSAGE,           SETTINGS.MAX_HIGHLIGHT_LENGTH,     
            SETTINGS.HIGHLIGHT_ADD_QUOTES,     SETTINGS.SHOW_HIGHLIGHT_LOCATION,  
            SETTINGS.SHOW_TITLES,              SETTINGS.SHOW_SUBTITLES,
        }),
        { text = _("Displayed sections"),
          sub_item_table = buildVisibilityMenu(),
          help_text = _("Toggle which sections show on the sleep screen. At least one must be visible.") },
        buildSectionOrderMenu()[1],
        { text = _("[ Section Content ]"), enabled = false },
        { text = _("Book section"),                help_text = _("Configure book-specific details."),          sub_item_table = buildBookSectionContentMenu()    },
        { text = _("Chapter section"),             help_text = _("Configure chapter-specific details"),        sub_item_table = buildChapterSectionContentMenu() },
        { text = _("Daily goal section"),          help_text = _("Configure reading goal details"),            sub_item_table = buildGoalSectionContentMenu()    },
        { text = _("Battery section"),             help_text = _("Configure battery & time/date details"),     sub_item_table = buildBatterySectionContentMenu() },
        { text = _("Message section"),             help_text = _("Configure message-specific details"),        sub_item_table = buildMessageSectionContentMenu() },
    }
    for i, item in ipairs(buildTitleSubtitleToggles()) do
        menu[#menu + 1] = item
    end
    return menu
end

return {
    buildContentsMenu              = buildContentsMenu,
    buildVisibilityMenu            = buildVisibilityMenu,
    buildSectionOrderMenu          = buildSectionOrderMenu,
    buildBookSectionContentMenu    = buildBookSectionContentMenu,
    buildChapterSectionContentMenu = buildChapterSectionContentMenu,
    buildGoalSectionContentMenu    = buildGoalSectionContentMenu,
    buildBatterySectionContentMenu = buildBatterySectionContentMenu,
    buildMessageSectionContentMenu = buildMessageSectionContentMenu,
    buildTitleSubtitleToggles      = buildTitleSubtitleToggles,
}
