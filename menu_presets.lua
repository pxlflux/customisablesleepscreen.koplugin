-- Preset management menu: save, load, and organise presets.

local UIManager  = require("ui/uimanager")
local ConfirmBox = require("ui/widget/confirmbox")
local Presets    = require("ui/presets")

local _        = require("plugin_gettext")
local config   = require("config")
local SETTINGS = config.SETTINGS

local presets_mod            = require("presets")
local initializePresetSystem = presets_mod.getPresetObj
local PRELOADED_PRESETS      = presets_mod.PRELOADED_PRESETS

local function buildPresetManagementMenu(hide_save_options)
    local preset_obj = initializePresetSystem()

    if not preset_obj._loadPreset_wrapped then
        local original_loadPreset = preset_obj.loadPreset
        preset_obj.loadPreset = function(preset, preset_name)
            original_loadPreset(preset, preset_name)
            if not preset_name then
                for name, data in pairs(preset_obj.presets) do
                    if data == preset then preset_name = name; break end
                end
            end
            if preset_name then
                G_reader_settings:saveSetting(SETTINGS.LAST_LOADED_PRESET, preset_name)
            end
        end
        preset_obj._loadPreset_wrapped = true
    end

    local menu_items = {}

    local current_preset_name = _("None")
    local last_loaded = G_reader_settings:readSetting(SETTINGS.LAST_LOADED_PRESET)
    if last_loaded and preset_obj.presets[last_loaded] then
        current_preset_name = last_loaded
    end

    if not hide_save_options then
        menu_items[#menu_items + 1] = {
            text      = _("Active preset: ") .. current_preset_name,
            enabled   = false,
            separator = true,
        }
    end

    local preset_menu_items = Presets.genPresetMenuItemTable(
        preset_obj, _("Save current settings as new preset"), nil)

    for i, item in ipairs(preset_menu_items) do
        if item.callback and item.separator then
            if not hide_save_options then
                menu_items[#menu_items + 1] = {
                    text           = _("Save current settings as new preset"),
                    separator      = true,
                    keep_menu_open = true,
                    callback = function(touchmenu_instance)
                        local po = initializePresetSystem()
                        Presets.editPresetName({}, po, function(entered_name)
                            po.presets[entered_name] = po.buildPreset()
                            G_reader_settings:saveSetting(SETTINGS.PRESETS, po.presets)
                            po.loadPreset(po.presets[entered_name], entered_name)
                            if touchmenu_instance then
                                touchmenu_instance.item_table = buildPresetManagementMenu(hide_save_options)
                                touchmenu_instance:updateItems()
                            end
                        end)
                    end,
                }
            end
        elseif item.text and not item.separator then
            local original_callback = item.callback
            if original_callback then
                item.callback = function(touchmenu_instance)
                    original_callback(touchmenu_instance)
                    if touchmenu_instance then
                        touchmenu_instance.item_table = buildPresetManagementMenu(hide_save_options)
                        touchmenu_instance:updateItems()
                    end
                end
            end
            if item.hold_callback then
                local held_preset_name = item.text
                item.hold_callback = function(touchmenu_instance, menu_item)
                    local last_before = G_reader_settings:readSetting(SETTINGS.LAST_LOADED_PRESET)
                    local po          = initializePresetSystem()

                    local function refreshMenu()
                        if touchmenu_instance then
                            UIManager:scheduleIn(0.1, function()
                                touchmenu_instance.item_table = buildPresetManagementMenu(hide_save_options)
                                touchmenu_instance:updateItems()
                            end)
                        end
                    end

                    UIManager:show(ConfirmBox:new {
                        text         = string.format(_("What would you like to do with preset '%s'?"), held_preset_name),
                        icon         = "notice-question",
                        ok_text      = _("Update"),
                        ok_callback  = function()
                            UIManager:show(ConfirmBox:new {
                                text = string.format(_("Are you sure you want to overwrite preset '%s' with current settings?"), held_preset_name),
                                ok_callback = function()
                                    po.presets[held_preset_name] = po.buildPreset()
                                    G_reader_settings:saveSetting(SETTINGS.PRESETS, po.presets)
                                    UIManager:show(require("ui/widget/infomessage"):new {
                                        text    = string.format(_("Preset '%s' was updated with current settings"), held_preset_name),
                                        timeout = 2,
                                    })
                                    refreshMenu()
                                end,
                            })
                        end,
                        other_buttons_first = true,
                        other_buttons = {
                            {
                                {
                                    text = _("Delete"),
                                    callback = function()
                                        UIManager:show(ConfirmBox:new {
                                            text        = string.format(_("Are you sure you want to delete preset '%s'?"), held_preset_name),
                                            ok_text     = _("Delete"),
                                            ok_callback = function()
                                                po.presets[held_preset_name] = nil
                                                G_reader_settings:saveSetting(SETTINGS.PRESETS, po.presets)
                                                if last_before == held_preset_name then
                                                    local default_data = po.presets["Default"]
                                                        or presets_mod.getDefaultSettings()
                                                    po.loadPreset(default_data, "Default")
                                                end
                                                refreshMenu()
                                            end,
                                        })
                                    end,
                                },
                                {
                                    text = _("Rename"),
                                    callback = function()
                                        Presets.editPresetName({
                                            title               = _("Enter new preset name"),
                                            initial_value       = held_preset_name,
                                            confirm_button_text = _("Rename"),
                                        }, po, function(new_name)
                                            po.presets[new_name] = po.presets[held_preset_name]
                                            po.presets[held_preset_name] = nil
                                            G_reader_settings:saveSetting(SETTINGS.PRESETS, po.presets)
                                            if last_before == held_preset_name then
                                                G_reader_settings:saveSetting(SETTINGS.LAST_LOADED_PRESET, new_name)
                                            end
                                            refreshMenu()
                                        end)
                                    end,
                                },
                            },
                        },
                    })
                end
            end
        end
    end

    local builtin_presets = {}
    local custom_presets  = {}
    local default_item    = nil

    for i, item in ipairs(preset_menu_items) do
        if item.separator and item.callback then

        elseif item.text then
            local preset_name = item.text
            local is_builtin  = PRELOADED_PRESETS[preset_name] ~= nil
            if is_builtin then
                item.hold_callback        = nil
                item.hold_may_update_menu = nil
            end
            if preset_name == "Default" then
                default_item = item
            elseif is_builtin then
                table.insert(builtin_presets, item)
            else
                table.insert(custom_presets, item)
            end
        end
    end

    local hide_preloaded = G_reader_settings:isTrue(SETTINGS.HIDE_PRELOADED_PRESETS)

    if (default_item or #builtin_presets > 0) and not hide_preloaded then
        menu_items[#menu_items + 1] = { text = _("[ Built-in Presets ]"), enabled = false }
        if default_item then menu_items[#menu_items + 1] = default_item end
        table.sort(builtin_presets, function(a, b) return a.text < b.text end)
        for i, item in ipairs(builtin_presets) do menu_items[#menu_items + 1] = item end
    elseif default_item then
        menu_items[#menu_items + 1] = { text = _("[ Built-in Presets ]"), enabled = false }
        menu_items[#menu_items + 1] = default_item
    end

    if #custom_presets > 0 then
        menu_items[#menu_items + 1] = { text = _("[ Your Custom Presets ]"), enabled = false }
        table.sort(custom_presets, function(a, b) return a.text < b.text end)
        for i, item in ipairs(custom_presets) do menu_items[#menu_items + 1] = item end
    end

    return menu_items
end

return {
    buildPresetManagementMenu = buildPresetManagementMenu,
}
