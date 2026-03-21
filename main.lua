-- Plugin entry point. Hooks into the KOReader screensaver and menu systems.

local _plugin_dir = (debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$") or ".") .. "/"

if not package.path:find(_plugin_dir, 1, true) then
    package.path = _plugin_dir .. "?.lua;" .. package.path
end

local logger                = require("logger")
local util                  = require("util")
local Device                = require("device")
local Dispatcher            = require("dispatcher")
local Screensaver           = require("ui/screensaver")
local UIManager             = require("ui/uimanager")
local ScreenSaverWidget     = require("ui/widget/screensaverwidget")
local WidgetContainer       = require("ui/widget/container/widgetcontainer")

local _           = require("plugin_gettext")
local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS
local meta        = require("_meta")

if not package.loaded["customisablesleepscreen/_meta"] then
    package.loaded["customisablesleepscreen/_meta"] = meta
end

local PATCH_VERSION = meta.version
local Screen        = Device.screen

local function getReaderUI()
    return package.loaded["apps/reader/readerui"]
end

local function getInfobox()
    return require("infobox")
end

local function getMenu()
    return require("css_menu")
end

local CustomisableSleepScreen = WidgetContainer:extend {
    name             = "customisablesleepscreen",
    _hooks_installed = false,
}

local function parseVersion(v)
    if not v then return 0, 0, 0 end
    local a, b, c = v:match("^(%d+)%.(%d+)%.(%d+)$")
    return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0
end

local function versionLessThan(v, major, minor, patch)
    local a, b, c = parseVersion(v)
    if a ~= major then return a < major end
    if b ~= minor then return b < minor end
    return c < patch
end

local function runMigrations(saved_version)
    if saved_version == nil or versionLessThan(saved_version, 2, 0, 0) then
        G_reader_settings:saveSetting(SETTINGS.MESSAGE_SOURCE,     USER_CONFIG.MESSAGE_SOURCE)
        G_reader_settings:saveSetting(SETTINGS.MSG_HEADER,         USER_CONFIG.MSG_HEADER)
        G_reader_settings:saveSetting(SETTINGS.ICON_SET,           USER_CONFIG.ICON_SET)
        G_reader_settings:saveSetting(SETTINGS.FONT_FACE_TITLE,    USER_CONFIG.FONT_FACE_TITLE)
        G_reader_settings:saveSetting(SETTINGS.FONT_FACE_SUBTITLE, USER_CONFIG.FONT_FACE_SUBTITLE)

        local presets_mod    = require("presets")
        local stored_presets = G_reader_settings:readSetting(SETTINGS.PRESETS) or {}
        stored_presets["Default"] = presets_mod.getDefaultSettings()
        G_reader_settings:saveSetting(SETTINGS.PRESETS, stored_presets)
        local cached = require("presets").getPresetObj()
        if cached then
            cached.presets["Default"] = presets_mod.getDefaultSettings()
        end
    end
end

function CustomisableSleepScreen:init()
    local saved_version = G_reader_settings:readSetting(SETTINGS.VERSION)
    if saved_version ~= PATCH_VERSION then
        runMigrations(saved_version)
        G_reader_settings:saveSetting(SETTINGS.VERSION, PATCH_VERSION)

        local settings_to_init_if_missing = {
            "FONT_FACE_TITLE", "FONT_FACE_SUBTITLE", "FONT_SIZE_TITLE",
            "FONT_SIZE_SUBTITLE", "BATT_STAT_TYPE", "TEXT_ALIGN", "MSG_SHOW_FULL_BAR",
            "OPACITY", "MARGIN", "GOAL_STAT_SCOPE", "POS", "BG_TYPE",
            "MESSAGE_SOURCE", "BG_COVER_FILL_COLOR",
        }
        for _, key in ipairs(settings_to_init_if_missing) do
            if not G_reader_settings:readSetting(SETTINGS[key]) then
                G_reader_settings:saveSetting(SETTINGS[key], USER_CONFIG[key])
            end
        end
        G_reader_settings:flush()
    end

    local function installBundledFonts()
        local lfs         = require("libs/libkoreader-lfs")
        local DataStorage = require("datastorage")
        local Font        = require("ui/font")

        local src_root = _plugin_dir .. "fonts"
        if lfs.attributes(src_root, "mode") ~= "directory" then return end

        local dst_dir = DataStorage:getDataDir() .. "/fonts"
        if lfs.attributes(dst_dir, "mode") ~= "directory" then
            lfs.mkdir(dst_dir)
        end

        local style_suffixes = {
            "%-Regular$",      "%-Bold$",           "%-Italic$",         "%-BoldItalic$",
            "%-Light$",        "%-Medium$",          "%-SemiBold$",       "%-ExtraBold$",
            "%-Thin$",         "%-Black$",           "%-ExtraLight$",     "%-LightItalic$",
            "%-MediumItalic$", "%-SemiBoldItalic$",  "%-BoldItalicalt$",
            "_Regular$",       "_Bold$",             "_Italic$",
        }
        local function filenameToFamilyName(filename)
            local base = filename:match("^(.+)%.[^%.]+$") or filename
            for _, suffix in ipairs(style_suffixes) do
                base = base:gsub(suffix, "")
            end

            base = base:gsub("(%l)(%u)", "%1 %2")
                       :gsub("(%u+)(%u%l)", "%1 %2")
            return base
        end

        local installed = {}

        local function processFont(src_path, filename)
            local ext = filename:match("%.([^%.]+)$")
            if not ext or not (ext == "ttf" or ext == "otf" or ext == "ttc") then return end

            local dst_path = dst_dir .. "/" .. filename

            if lfs.attributes(dst_path, "mode") ~= "file" then
                local src_f = io.open(src_path, "rb")
                if src_f then
                    local data = src_f:read("*a")
                    src_f:close()
                    local dst_f = io.open(dst_path, "wb")
                    if dst_f then
                        dst_f:write(data)
                        dst_f:close()
                    end
                end
            end

            local family    = filenameToFamilyName(filename)
            local is_regular = filename:lower():match("regular") ~= nil
            if not installed[family] or is_regular then
                installed[family] = filename
            end
        end

        local function walkFonts(dir)
            if lfs.attributes(dir, "mode") ~= "directory" then return end
            for entry in lfs.dir(dir) do
                if entry ~= "." and entry ~= ".." and not entry:match("^%.") then
                    local full = dir .. "/" .. entry
                    local mode = lfs.attributes(full, "mode")
                    if mode == "file" then
                        processFont(full, entry)
                    elseif mode == "directory" then
                        walkFonts(full)
                    end
                end
            end
        end

        walkFonts(src_root)

        if Font.fontmap and next(installed) then
            for family, path in pairs(installed) do
                if not Font.fontmap[family] then
                    Font.fontmap[family] = path
                end
            end
        end

        local ok_fl, FontList = pcall(require, "fontlist")
        if ok_fl and FontList then
            FontList.font_list = nil
        end

    end
    pcall(installBundledFonts)

    if Dispatcher and Dispatcher.registerAction then
        Dispatcher:registerAction("customisable_ss_settings", {
            category = "none",
            event    = "ShowCustomisableSleepScreenSettings",
            title    = _("Customisable sleep screen settings"),
            general  = true,
        })
        Dispatcher:registerAction("customisable_ss_presets", {
            category = "none",
            event    = "ShowCustomisableSleepScreenPresets",
            title    = _("Customisable sleep screen presets"),
            general  = true,
        })
        Dispatcher:registerAction("cycle_customisable_ss_presets", {
            category = "none",
            event    = "CycleCustomisableSleepScreenPresets",
            title    = _("Cycle through customisable sleep screen presets"),
            general  = true,
        })
    end

    self.ui.menu:registerToMainMenu(self)

    if not CustomisableSleepScreen._hooks_installed then
        self:_installScreensaverHook()
        CustomisableSleepScreen._hooks_installed = true
    end

    local self_ref = self
    self.onShowCustomisableSleepScreenSettings = function() return self_ref:_onShowSettings() end
    self.onShowCustomisableSleepScreenPresets  = function() return self_ref:_onShowPresets()  end
    self.onCycleCustomisableSleepScreenPresets = function() return self_ref:_onCyclePresets() end
end

function CustomisableSleepScreen:addToMainMenu(menu_items)
    menu_items.customisable_sleep_screen = {
        text         = _("Customisable sleep screen"),
        sorting_hint = "screen",
        checked_func = function()
            return G_reader_settings:readSetting(SETTINGS.TYPE) == "customisable_ss"
        end,
        sub_item_table_func = function()
            local ok, menu_mod = pcall(require, "css_menu")
            local settings_items = (ok and type(menu_mod) == "table")
                and (function()
                    local ok2, items = pcall(menu_mod.getCustomisableSleepScreenSettingsMenu)
                    if not ok2 then
                        logger.warn("[CSS] addToMainMenu: settings build failed: " .. tostring(items))
                    end
                    return ok2 and items or nil
                end)()
                or nil

            local enable_item = {
                text = _("Enable customisable sleep screen"),
                checked_func = function()
                    return G_reader_settings:readSetting(SETTINGS.TYPE) == "customisable_ss"
                end,
                callback = function()
                    if G_reader_settings:readSetting(SETTINGS.TYPE) == "customisable_ss" then
                        G_reader_settings:saveSetting(SETTINGS.TYPE, "disable")
                    else
                        G_reader_settings:saveSetting(SETTINGS.TYPE, "customisable_ss")
                    end
                end,
                separator = true,
            }

            if not settings_items then
                return { enable_item }
            end

            table.insert(settings_items, 1, enable_item)
            return settings_items
        end,
    }
end

function CustomisableSleepScreen:onCloseWidget()
    if CustomisableSleepScreen._hooks_installed then
        self._screensaver_hook:revert()
        CustomisableSleepScreen._hooks_installed = false
    end

    local ok, ib = pcall(require, "infobox")
    if ok then
        ib.freeTrackedBBs()
        ib.restorePatches()
    end

    G_reader_settings:flush()
end

function CustomisableSleepScreen:onSuspend()
    G_reader_settings:flush()
end

function CustomisableSleepScreen:_installScreensaverHook()
    self._screensaver_hook = util.wrapMethod(Screensaver, "show", function(ss_self)

        if ss_self.prefix and ss_self.prefix ~= "" then
            ss_self.screensaver_type = "message"
            ss_self.show_message = true
            return self._screensaver_hook:raw_call(ss_self)
        end

        local screensaver_type = G_reader_settings:readSetting("screensaver_type")
        if screensaver_type ~= "customisable_ss" then
            return self._screensaver_hook:raw_call(ss_self)
        end

        local ib = getInfobox()

        if ss_self.screensaver_widget then
            UIManager:close(ss_self.screensaver_widget)
            ss_self.screensaver_widget = nil
        end
        ib.freeTrackedBBs()
        collectgarbage("collect")

        local ReaderUI = getReaderUI()
        local ui       = ReaderUI and ReaderUI.instance
        local widget   = nil

        if ui and ui.document then

            if ui.statistics and ui.statistics.id_curr_book then
                local avg_time_before = ui.statistics.avg_time
                pcall(function() ui.statistics:insertDB(ui.statistics.id_curr_book) end)
                ui.statistics.avg_time = avg_time_before
            end

            if ui.doc_settings then
                pcall(function() ui.doc_settings:flush() end)
            end

            local state     = ui.view and ui.view.state
            local book_data = ib.collectBookData(ui, state)

            if book_data then
                ib.saveLastBookData(book_data)
                widget = ib.buildInfoBox(ui, state, book_data)
            end
        else
            local render_ref = require("infobox_render")
            local show_in_fm = render_ref.getSetting("SHOW_IN_FILEMANAGER")
            if not show_in_fm then
                return self._screensaver_hook:raw_call(ss_self)
            end
            local book_data = ib.loadLastBookData()
            if book_data then
                widget = ib.buildInfoBox(nil, nil, book_data)
            end
        end

        if not widget then return self._screensaver_hook:raw_call(ss_self) end

        Device.screen_saver_mode = true
        UIManager:setIgnoreTouchInput(false)

        ss_self.screensaver_widget = ScreenSaverWidget:new {
            widget            = widget,
            covers_fullscreen = true,
        }
        ss_self.screensaver_widget.modal    = true
        ss_self.screensaver_widget.dithered = true
        UIManager:show(ss_self.screensaver_widget, "full")

        local screensaver_delay = G_reader_settings:readSetting("screensaver_delay")
        if screensaver_delay == "gesture" and ui then
            local ScreenSaverLockWidget = require("ui/widget/screensaverlockwidget")
            ss_self.screensaver_lock_widget = ScreenSaverLockWidget:new { ui = ui }
            ss_self.screensaver_lock_widget.showWaitForGestureMessage = function(this)
                this.is_infomessage_visible = true
            end
            UIManager:show(ss_self.screensaver_lock_widget)
        end
    end)
end

function CustomisableSleepScreen:_onShowSettings()

    local ok, menu_mod = pcall(require, "css_menu")
    if not ok then
        logger.warn("[Customisable Sleep Screen] css_menu load error: " .. tostring(menu_mod))
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new { text = "CSS: menu load failed — check crash.log", timeout = 5 })
        return true
    end
    local ok2, result = pcall(menu_mod.getCustomisableSleepScreenSettingsMenu, true)
    if not ok2 then
        logger.warn("[Customisable Sleep Screen] settings build error: " .. tostring(result))
        local InfoMessage = require("ui/widget/infomessage")
        UIManager:show(InfoMessage:new { text = "CSS: settings build failed — check crash.log", timeout = 5 })
        return true
    end
    local menu_widget = require("ui/widget/menu"):new {
        title              = _("Customisable sleep screen settings"),
        item_table         = result,
        width              = Screen:getWidth(),
        height             = Screen:getHeight(),
        is_enable_shortcut = false,
    }
    UIManager:show(menu_widget)

    return true
end

function CustomisableSleepScreen:_onShowPresets()
    local ok, result = pcall(function()
        return getMenu().buildPresetManagementMenu(true)
    end)
    if not ok then
        logger.warn("[Customisable Sleep Screen] presets build error: " .. tostring(result))
        return true
    end
    local menu_widget = require("ui/widget/menu"):new {
        title              = _("Customisable sleep screen presets"),
        item_table         = result,
        width              = Screen:getWidth(),
        height             = Screen:getHeight(),
        is_enable_shortcut = false,
    }
    UIManager:show(menu_widget)
    return true
end

function CustomisableSleepScreen:_onCyclePresets()
    local Presets = require("ui/presets")
    return Presets.cycleThroughPresets(require("presets").getPresetObj(), true)
end

return CustomisableSleepScreen
