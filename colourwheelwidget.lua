-- Colour picker widget used in the appearance settings menus.

local Blitbuffer       = require("ffi/blitbuffer")
local Device           = require("device")
local Font             = require("ui/font")
local FocusManager     = require("ui/widget/focusmanager")
local Geom             = require("ui/geometry")
local GestureRange     = require("ui/gesturerange")
local Size             = require("ui/size")
local UIManager        = require("ui/uimanager")
local Button           = require("ui/widget/button")
local InputDialog      = require("ui/widget/inputdialog")
local TextWidget       = require("ui/widget/textwidget")
local TitleBar         = require("ui/widget/titlebar")
local HorizontalGroup  = require("ui/widget/horizontalgroup")
local HorizontalSpan   = require("ui/widget/horizontalspan")
local VerticalGroup    = require("ui/widget/verticalgroup")
local VerticalSpan     = require("ui/widget/verticalspan")
local CenterContainer  = require("ui/widget/container/centercontainer")
local FrameContainer   = require("ui/widget/container/framecontainer")
local WidgetContainer  = require("ui/widget/container/widgetcontainer")
local MovableContainer = require("ui/widget/container/movablecontainer")

local Screen = Device.screen

local logger = require("logger")
local _      = require("plugin_gettext")

local ColorPreview = WidgetContainer:extend {}

function ColorPreview:paintTo(bb, x, y)
    bb:paintRectRGB32(x, y, self.dimen.w, self.dimen.h,
        Blitbuffer.ColorRGB32(self.r, self.g, self.b, 0xFF))
end

local ColorWheelWidget = FocusManager:extend {
    title_text           = _("Pick a colour"),
    width                = nil,
    width_factor         = 0.6,
    hue                  = 0,
    saturation           = 1,
    value                = 1,
    invert_in_night_mode = true,
    cancel_text          = _("Cancel"),
    ok_text              = _("Apply"),
    callback             = nil,
    cancel_callback      = nil,
    close_callback       = nil,
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
    radius               = 0,
    hue                  = 0,
    saturation           = 1,
    value                = 1,
    invert_in_night_mode = true,
}

function ColorWheel:init()
    self.radius = math.floor(self.dimen.w / 2)
    self.dimen  = Geom:new {
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
                local sat   = dist / self.radius

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
    local sel_dist  = self.saturation * self.radius
    local sel_x     = cx + math.floor(math.cos(sel_angle) * sel_dist + 0.5)
    local sel_y     = cy + math.floor(math.sin(sel_angle) * sel_dist + 0.5)

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

    self.hue        = (math.deg(math.atan2(dy, dx)) + 360) % 360
    self.saturation = math.min(1, dist / self.radius)

    if self.update_callback then
        self.update_callback()
    end

    return true
end

function ColorWheelWidget:init()
    self.screen_width  = Screen:getWidth()
    self.screen_height = Screen:getHeight()
    local success, face = pcall(Font.getFace, Font, "ffont")
    if success and face then
        self.medium_font_face = face
    else
        logger.warn("[Customisable Sleep Screen] ffont failed to load in ColorWheelWidget, using cfont")
        local _, fallback_face = pcall(Font.getFace, Font, "cfont")
        self.medium_font_face = fallback_face or Font:getFace("cfont", 16)
    end

    local success2, face2 = pcall(Font.getFace, Font, "infofont", 20)
    if success2 and face2 then
        self.hex_font_face = face2
    else
        logger.warn("[Customisable Sleep Screen] infofont failed to load, using cfont")
        local _, fallback_face2 = pcall(Font.getFace, Font, "cfont", 20)
        self.hex_font_face = fallback_face2 or Font:getFace("cfont", 16)
    end

    if not self.width then
        self.width = math.floor(
            math.min(self.screen_width, self.screen_height) * self.width_factor
        )
    end

    self.inner_width  = self.width - 2 * Size.padding.large
    self.button_width = math.floor(self.inner_width / 4)

    if Device:isTouchDevice() then
        self.ges_events = {
            TapColorWheel = {
                GestureRange:new {
                    ges   = "tap",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = self.screen_width,
                        h = self.screen_height,
                    },
                },
            },
            PanColorWheel = {
                GestureRange:new {
                    ges   = "pan",
                    range = Geom:new {
                        x = 0, y = 0,
                        w = self.screen_width,
                        h = self.screen_height,
                    },
                },
            },
        }
    end

    self:_buildUI()
end

function ColorWheelWidget:_buildUI()
    local wheel_size = self.width - 2 * Size.padding.large

    self.color_wheel = ColorWheel:new {
        dimen = Geom:new {
            w = wheel_size,
            h = wheel_size,
        },
        hue                  = self.hue,
        saturation           = self.saturation,
        value                = self.value,
        invert_in_night_mode = self.invert_in_night_mode,
        update_callback = function()
            self.hue        = self.color_wheel.hue
            self.saturation = self.color_wheel.saturation
            self:update()
        end,
    }

    local title_bar = TitleBar:new {
        width            = self.width,
        title            = self.title_text,
        with_bottom_line = true,
        close_button     = true,
        close_callback   = function()
            self:onCancel()
        end,
        show_parent = self,
    }

    local value_minus = Button:new {
        text        = "−",
        enabled     = self.value > 0,
        width       = self.button_width,
        show_parent = self,
        callback    = function()
            self.value = math.max(0, self.value - 0.1)
            self:update()
        end,
    }

    local value_plus = Button:new {
        text        = "＋",
        enabled     = self.value < 1,
        width       = self.button_width,
        show_parent = self,
        callback    = function()
            self.value = math.min(1, self.value + 0.1)
            self:update()
        end,
    }

    self.value_label = TextWidget:new {
        text = string.format(_("Brightness: %d%%"), math.floor(self.value * 100)),
        face = self.medium_font_face,
    }

    local value_group = HorizontalGroup:new {
        align = "center",
        value_minus,
        HorizontalSpan:new { width = Size.padding.large },
        self.value_label,
        HorizontalSpan:new { width = Size.padding.large },
        value_plus,
    }

    local r, g, b  = hsvToRgb(self.hue, self.saturation, self.value)
    local hex_text = string.format("#%02X%02X%02X", r, g, b)

    local preview_size = math.floor(wheel_size / 4)

    local night_mode = self.invert_in_night_mode and G_reader_settings:isTrue("night_mode")
    local preview_r, preview_g, preview_b = r, g, b
    if night_mode then
        preview_r = 255 - r
        preview_g = 255 - g
        preview_b = 255 - b
    end

    self.color_preview = FrameContainer:new {
        bordersize = Size.border.thick,
        margin     = 0,
        padding    = 0,
        ColorPreview:new {
            dimen = Geom:new { w = preview_size, h = preview_size },
            r = preview_r, g = preview_g, b = preview_b,
        },
    }

    self.hex_label = TextWidget:new {
        text = hex_text,
        face = self.hex_font_face,
    }

    local preview_group = HorizontalGroup:new {
        align = "center",
        self.color_preview,
        HorizontalSpan:new { width = Size.padding.large },
        self.hex_label,
    }

    local input_button = Button:new {
        text        = _("Enter hex"),
        width       = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback    = function()
            local input_dialog
            input_dialog = InputDialog:new {
                title      = _("Enter hex colour code"),
                input      = hex_text,
                input_hint = "#000000",
                buttons    = {
                    {
                        {
                            text     = _("Cancel"),
                            callback = function()
                                UIManager:close(input_dialog)
                            end,
                        },
                        {
                            text             = _("Apply"),
                            is_enter_default = true,
                            callback         = function()
                                local text = input_dialog:getInputText()
                                if text and text:match("^#%x%x%x%x%x%x$") then
                                    local r = tonumber(text:sub(2, 3), 16) / 255
                                    local g = tonumber(text:sub(4, 5), 16) / 255
                                    local b = tonumber(text:sub(6, 7), 16) / 255

                                    local max   = math.max(r, g, b)
                                    local min   = math.min(r, g, b)
                                    local delta = max - min

                                    self.value      = max
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
                                else
                                    UIManager:show(require("ui/widget/infomessage"):new {
                                        text    = _("Invalid hex code. Use format: #RRGGBB"),
                                        timeout = 2,
                                    })
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
        text        = self.cancel_text,
        width       = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback    = function()
            self:onCancel()
        end,
    }

    local ok_button = Button:new {
        text        = self.ok_text,
        width       = math.floor(self.width / 3) - Size.padding.large,
        show_parent = self,
        callback    = function()
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
                h = self.value_label:getSize().h + Size.padding.default,
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
        radius     = Size.radius.window,
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

function ColorWheelWidget:update()
    if not self.frame then
        self:_buildUI()
        return
    end

    local r, g, b  = hsvToRgb(self.hue, self.saturation, self.value)
    local hex_text = string.format("#%02X%02X%02X", r, g, b)

    local night_mode = self.invert_in_night_mode and G_reader_settings:isTrue("night_mode")
    local preview_r, preview_g, preview_b = r, g, b
    if night_mode then
        preview_r = 255 - r
        preview_g = 255 - g
        preview_b = 255 - b
    end

    self.color_wheel.hue        = self.hue
    self.color_wheel.saturation = self.saturation
    self.color_wheel.value      = self.value

    self.value_label:setText(
        string.format(_("Brightness: %d%%"), math.floor(self.value * 100)))

    self.hex_label:setText(hex_text)

    local preview = self.color_preview[1]
    if preview then
        preview.r = preview_r
        preview.g = preview_g
        preview.b = preview_b
    end

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
        local hex     = string.format("#%02X%02X%02X", r, g, b)
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

return ColorWheelWidget
