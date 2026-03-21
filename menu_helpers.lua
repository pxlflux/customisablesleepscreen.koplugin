-- Shared factory functions for building common menu item types.

local logger      = require("logger")
local Device      = require("device")
local UIManager   = require("ui/uimanager")

local _           = require("plugin_gettext")
local config      = require("config")
local USER_CONFIG = config.USER_CONFIG
local SETTINGS    = config.SETTINGS
local getSetting  = config.getSetting

local Screen = Device.screen

local function getActivePresetData()
    local ok, presets_mod = pcall(require, "presets")
    if not ok then return nil, nil end
    local preset_name = G_reader_settings:readSetting(SETTINGS.LAST_LOADED_PRESET)
    if not preset_name then return nil, nil end
    local preset_obj = presets_mod.getPresetObj()
    if not preset_obj or not preset_obj.presets then return nil, nil end
    local preset_data = preset_obj.presets[preset_name]
    return preset_data, preset_name
end

local function getColourWheelWidget()
    return require("colourwheelwidget")
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
    local max   = math.max(r, g, b)
    local min   = math.min(r, g, b)
    local delta = max - min
    local v     = max
    local s     = max > 0 and delta / max or 0
    local h     = 0
    if delta > 0 then
        if     max == r then h = 60 * (((g - b) / delta) % 6)
        elseif max == g then h = 60 * (((b - r) / delta) + 2)
        else                 h = 60 * (((r - g) / delta) + 4) end
    end
    if h < 0 then h = h + 360 end
    return h, s, v
end

local function createToggleItem(text, help_text, setting_key, default_value, separator)
    return {
        text      = text,
        help_text = help_text,
        checked_func = function()
            local val = G_reader_settings:readSetting(setting_key)
            return val == nil and (default_value or false) or val
        end,
        callback = function()
            local current = G_reader_settings:readSetting(setting_key)
            if current == nil then current = default_value or false end
            G_reader_settings:saveSetting(setting_key, not current)
        end,
        separator = separator,
    }
end

local function createFlipNilOrTrueItem(text, help_text, setting_key, separator)
    return {
        text      = text,
        help_text = help_text,
        checked_func = function()
            local val = G_reader_settings:readSetting(setting_key)
            return val == nil or val == true
        end,
        callback = function()
            G_reader_settings:flipNilOrTrue(setting_key)
        end,
        separator = separator,
    }
end

local function createFlipNilOrFalseItem(text, help_text, setting_key, separator)
    return {
        text      = text,
        help_text = help_text,
        checked_func = function()
            return G_reader_settings:isTrue(setting_key)
        end,
        callback = function()
            G_reader_settings:flipNilOrFalse(setting_key)
        end,
        separator = separator,
    }
end

local function createRadioItem(text, help_text, setting_key, value, enabled_func)
    return {
        text         = text,
        help_text    = help_text,
        enabled_func = enabled_func,
        checked_func = function()
            return G_reader_settings:readSetting(setting_key) == value
        end,
        callback = function()
            G_reader_settings:saveSetting(setting_key, value)
        end,
        radio = true,
    }
end

local function createColorMenuItem(name, setting_key, default_value)
    return {
        text           = name,
        keep_menu_open = true,
        callback = function()
            local current_color = G_reader_settings:readSetting(setting_key) or default_value
            local h, s, v = hexToHSV(current_color)
            local wheel = getColourWheelWidget():new({
                title_text = name,
                hue = h, saturation = s, value = v,
                callback = function(hex)
                    G_reader_settings:saveSetting(setting_key, hex)
                    UIManager:setDirty(nil, "ui")
                end,
                cancel_callback = function() UIManager:setDirty(nil, "ui") end,
            })
            UIManager:show(wheel)
        end,
    }
end

local RESET_STRINGS = {
    ["layout & spacing"] = {
        menu    = _("Reset layout & spacing settings to default"),
        confirm = _("Are you sure you want to reset layout & spacing settings?"),
        done    = _("Layout & spacing settings reset to defaults"),
    },
    ["contents"] = {
        menu    = _("Reset contents settings to default"),
        confirm = _("Are you sure you want to reset contents settings?"),
        done    = _("Contents settings reset to defaults"),
    },
    ["colours, icons & bars"] = {
        menu    = _("Reset colours, icons & bars settings to default"),
        confirm = _("Are you sure you want to reset colours, icons & bars settings?"),
        done    = _("Colours, icons & bars settings reset to defaults"),
    },
    ["fonts & text"] = {
        menu    = _("Reset fonts & text settings to default"),
        confirm = _("Are you sure you want to reset fonts & text settings?"),
        done    = _("Fonts & text settings reset to defaults"),
    },
    ["background"] = {
        menu    = _("Reset background settings to default"),
        confirm = _("Are you sure you want to reset background settings?"),
        done    = _("Background settings reset to defaults"),
    },
}

local function createResetMenuItem(section_name, settings_to_delete)
    local strings = RESET_STRINGS[section_name]
    if not strings then
        logger.warn("[CSS] createResetMenuItem: unknown section '" .. section_name .. "'")
        return nil
    end
    return {
        text           = strings.menu,
        help_text      = _("Reset the settings in this part of the menu to their defaults."),
        separator      = true,
        keep_menu_open = true,
        callback = function()
            local ConfirmBox  = require("ui/widget/confirmbox")
            local InfoMessage = require("ui/widget/infomessage")

            local active_preset, preset_name = getActivePresetData()
            local source_label = preset_name and ("'" .. preset_name .. "' preset") or _("factory defaults")

            local box = ConfirmBox:new {
                text        = strings.confirm .. "\n\n" .. string.format(_("Values will be restored from: %s"), source_label),
                ok_text     = _("Reset"),
                cancel_text = _("Cancel"),
                ok_callback = function()
                    local active_preset, preset_name = getActivePresetData()
                    if active_preset then

                        for _, setting_key in ipairs(settings_to_delete) do
                            local preset_val = active_preset[setting_key]
                            if preset_val ~= nil then
                                G_reader_settings:saveSetting(setting_key, preset_val)
                            else
                                G_reader_settings:delSetting(setting_key)
                            end
                        end
                    else
                        for _, setting_key in ipairs(settings_to_delete) do
                            G_reader_settings:delSetting(setting_key)
                        end
                    end
                    UIManager:show(InfoMessage:new {
                        text    = strings.done .. " (" .. source_label .. ")",
                        timeout = 2,
                    })
                end,
            }
            UIManager:show(box)
        end,
    }
end

local function createSpinDialog(title, current_value, min_val, max_val, step, on_save, info_text, precision, hold_step)
    local SpinWidget = require("ui/widget/spinwidget")
    UIManager:show(SpinWidget:new {
        title_text      = title,
        info_text       = info_text,
        value           = tonumber(current_value) or min_val,
        value_min       = min_val,
        value_max       = max_val,
        value_step      = step or 1,
        value_hold_step = hold_step or (step or 1) * 5,
        precision       = precision,
        callback = function(spin)
            on_save(spin.value)
        end,
    })
end

local function createTextInputDialog(title, current_value, on_save)
    local InputDialog = require("ui/widget/inputdialog")
    local box
    box = InputDialog:new {
        title  = title,
        input  = current_value,
        width  = Screen:getWidth() * 0.8,
        buttons = {{
            { text = _("Cancel"), callback = function() UIManager:close(box) end },
            { text = _("Save"), is_enter_default = true, callback = function()
                on_save(box:getInputText())
                UIManager:close(box)
            end },
        }},
    }
    UIManager:show(box)
    box:onShowKeyboard()
end

local function createNumericRadioMenu(setting_key, min_val, max_val, step, suffix, get_current_func)
    local options = {}
    suffix = suffix or ""
    local key_name = nil
    for k, v in pairs(SETTINGS) do
        if v == setting_key then key_name = k; break end
    end
    get_current_func = get_current_func or function()
        return getSetting(key_name or setting_key)
    end
    for val = min_val, max_val, step do
        options[#options + 1] = {
            text         = tostring(val) .. suffix,
            radio        = true,
            checked_func = function() return get_current_func() == val end,
            callback     = function() G_reader_settings:saveSetting(setting_key, val) end,
        }
    end
    return options
end

local function buildNumericMenu(setting_key, options)
    local sub_menu = {}
    for i, opt in ipairs(options) do
        sub_menu[i] = {
            text         = opt.text,
            checked_func = function() return getSetting(setting_key) == opt.val end,
            callback     = function() G_reader_settings:saveSetting(SETTINGS[setting_key], opt.val) end,
            radio        = true,
        }
    end
    return sub_menu
end

return {
    getSetting               = getSetting,
    hexToHSV                 = hexToHSV,
    getColourWheelWidget      = getColourWheelWidget,
    createToggleItem         = createToggleItem,
    createFlipNilOrTrueItem  = createFlipNilOrTrueItem,
    createFlipNilOrFalseItem = createFlipNilOrFalseItem,
    createRadioItem          = createRadioItem,
    createColorMenuItem      = createColorMenuItem,
    createResetMenuItem      = createResetMenuItem,
    createSpinDialog         = createSpinDialog,
    createTextInputDialog    = createTextInputDialog,
    createNumericRadioMenu   = createNumericRadioMenu,
    buildNumericMenu         = buildNumericMenu,
}
