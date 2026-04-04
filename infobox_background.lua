-- Builds the background widget (cover, folder image, or solid colour) and dimming overlay.

local _plugin_dir = (debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$") or ".") .. "/"

local ffi         = require("ffi")
local Blitbuffer  = require("ffi/blitbuffer")
local util        = require("util")
local Device      = require("device")
local RenderImage = require("ui/renderimage")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget    = require("ui/widget/imagewidget")

local render     = require("infobox_render")
local getSetting = render.getSetting

require("random")

local Screen = Device.screen

local _active_blitbuffers = {}

local function trackBB(bb)
    if bb then table.insert(_active_blitbuffers, bb) end
    return bb
end

local function freeTrackedBBs()
    for _, bb in ipairs(_active_blitbuffers) do
        if bb and bb.free then pcall(bb.free, bb) end
    end
    _active_blitbuffers = {}
end

local function scaleImageToFit(bb, target_w, target_h, stretch, fill_color)
    if not bb then return nil end
    local src_w, src_h = bb:getWidth(), bb:getHeight()
    if src_w <= 0 or src_h <= 0 then
        if bb.free then pcall(bb.free, bb) end
        return nil
    end

    if src_w == target_w and src_h == target_h then
        return trackBB(bb)
    end

    local final_bb

    if stretch then
        final_bb = RenderImage:scaleBlitBuffer(bb, target_w, target_h, true)
    else
        local scale    = math.min(target_w / src_w, target_h / src_h)
        local scaled_w = math.floor(src_w * scale)
        local scaled_h = math.floor(src_h * scale)
        local scaled   = RenderImage:scaleBlitBuffer(bb, scaled_w, scaled_h, false)

        fill_color = fill_color or "black"
        local bg_color = (fill_color == "white") and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK

        local canvas = Blitbuffer.new(target_w, target_h, bb:getType())
        canvas:fill(bg_color)
        local x_off = math.floor((target_w - scaled_w) / 2)
        local y_off = math.floor((target_h - scaled_h) / 2)
        canvas:blitFrom(scaled, x_off, y_off, 0, 0, scaled_w, scaled_h)
        if scaled ~= bb and scaled.free then pcall(scaled.free, scaled) end
        final_bb = canvas
    end

    if final_bb ~= bb and bb.free then pcall(bb.free, bb) end
    return trackBB(final_bb)
end

local function buildBackground(ui)
    if not (ui and ui.document) then return nil end
    local screen_size = Screen:getSize()
    local ok, cover_bb = pcall(function()
        if ui.document.getCoverPageImage then
            local ok2, img = pcall(ui.document.getCoverPageImage, ui.document)
            if ok2 and img then return img end
        end
        return nil
    end)
    if not (ok and cover_bb) then return nil end
    local stretch    = getSetting("BG_STRETCH")
    local fill_color = getSetting("BG_COVER_FILL_COLOR")
    local scaled_bb  = scaleImageToFit(cover_bb, screen_size.w, screen_size.h, stretch, fill_color)
    if not scaled_bb then return nil end
    return ImageWidget:new {
        image  = scaled_bb,
        width  = screen_size.w,
        height = screen_size.h,
        alpha  = true,
    }
end

local function isValidImageFile(filepath)
    local f = io.open(filepath, "rb")
    if not f then return false end
    local header = f:read(8)
    f:close()
    if not header or #header < 2 then return false end
    if header:sub(1, 2) == "\xFF\xD8" then return true end
    if header:sub(1, 4) == "\x89PNG"  then return true end
    return false
end

local function getRandomImageFromFolder(folder)
    if not folder or folder == "" then return nil end
    folder = folder:gsub("/$", "")

    local screen_size  = Screen:getSize()
    local valid_images = {}

    util.findFiles(folder, function(filepath, filename)
        local lower = filename:lower()
        if (lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$"))
           and isValidImageFile(filepath) then
            valid_images[#valid_images + 1] = filepath
        end
    end, false)

    if #valid_images == 0 then return nil end

    local is_landscape = screen_size.w > screen_size.h
    if is_landscape then
        local landscape_images = {}
        for _, fp in ipairs(valid_images) do
            if fp:lower():match("%.landscape%.") then
                landscape_images[#landscape_images + 1] = fp
            end
        end
        if #landscape_images > 0 then valid_images = landscape_images end
    else
        local portrait_images = {}
        for _, fp in ipairs(valid_images) do
            if not fp:lower():match("%.landscape%.") then
                portrait_images[#portrait_images + 1] = fp
            end
        end
        if #portrait_images > 0 then valid_images = portrait_images end
    end

    local tried = {}
    for attempt = 1, math.min(3, #valid_images) do
        local idx
        repeat
            idx = math.random(#valid_images)
        until not tried[idx]
        tried[idx] = true

        local random_file = valid_images[idx]
        local ok, image_bb = pcall(function()
            return RenderImage:renderImageFile(random_file, screen_size.w, screen_size.h)
        end)

        if ok and image_bb then
            local stretch    = getSetting("BG_STRETCH")
            local fill_color = getSetting("BG_COVER_FILL_COLOR")
            local scaled_bb  = scaleImageToFit(image_bb, screen_size.w, screen_size.h, stretch, fill_color)
            if not scaled_bb then return nil end
            return ImageWidget:new {
                image  = scaled_bb,
                width  = screen_size.w,
                height = screen_size.h,
                alpha  = true,
            }
        end
    end

    return nil
end

local function buildBackgroundWidget(ui, book_data)
    local screen_size = Screen:getSize()
    local bg_type     = getSetting("BG_TYPE")

    if bg_type == "transparent" then return nil end

    if bg_type == "solid" then
        local solid_color = getSetting("BG_SOLID_COLOR")
        local r = tonumber(solid_color:sub(2, 3), 16) or 44
        local g = tonumber(solid_color:sub(4, 5), 16) or 62
        local b = tonumber(solid_color:sub(6, 7), 16) or 80
        local tiny_bb = Blitbuffer.new(1, 1, Blitbuffer.TYPE_BBRGB24)
        local color   = ffi.new("ColorRGB24", r, g, b)
        tiny_bb:setPixel(0, 0, color)
        local scaled_bb = trackBB(RenderImage:scaleBlitBuffer(tiny_bb, screen_size.w, screen_size.h, true))
        tiny_bb:free()
        return ImageWidget:new {
            image  = scaled_bb,
            width  = screen_size.w,
            height = screen_size.h,
        }
    end

    if bg_type == "folder" then
        local folder = getSetting("BG_FOLDER")
        if folder and folder:match("^@plugin/") then
            folder = _plugin_dir .. folder:sub(9)
        end
        local img = getRandomImageFromFolder(folder)
        if img then return img end
        return nil
    end

    if ui and ui.document then
        return buildBackground(ui)
    end

    if book_data and book_data.cover_path then
        local cover_path = book_data.cover_path
        if util.fileExists(cover_path) then
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
                local stretch    = getSetting("BG_STRETCH")
                local fill_color = getSetting("BG_COVER_FILL_COLOR")
                local scaled_bb  = scaleImageToFit(cover_bb, screen_size.w, screen_size.h, stretch, fill_color)
                return ImageWidget:new {
                    image  = scaled_bb,
                    width  = screen_size.w,
                    height = screen_size.h,
                    alpha  = true,
                }
            end
        end
    end

    return nil
end

local function buildDimmingLayer()
    local screen_size = Screen:getSize()
    local dim_val     = getSetting("BG_DIMMING")

    if dim_val > 0 then

        local dim_color_hex = getSetting("BG_DIMMING_COLOR")
        local r = tonumber(dim_color_hex:sub(2, 3), 16) or 0
        local g = tonumber(dim_color_hex:sub(4, 5), 16) or 0
        local b = tonumber(dim_color_hex:sub(6, 7), 16) or 0

        local tiny_bb = Blitbuffer.new(1, 1, Blitbuffer.TYPE_BBRGB24)
        local color   = ffi.new("ColorRGB24", r, g, b)
        tiny_bb:setPixel(0, 0, color)

        local dim_bb = trackBB(RenderImage:scaleBlitBuffer(tiny_bb, screen_size.w, screen_size.h, true))

        local dim_image = ImageWidget:new {
            image  = dim_bb,
            width  = screen_size.w,
            height = screen_size.h,
        }

        local AlphaContainer = require("ui/widget/container/alphacontainer")
        local dimming_layer = AlphaContainer:new {
            alpha = dim_val / 255,
            dim_image,
        }

        tiny_bb:free()
        return dimming_layer
    else
        return HorizontalSpan:new { width = 0 }
    end
end

return {
    trackBB               = trackBB,
    freeTrackedBBs        = freeTrackedBBs,
    scaleImageToFit       = scaleImageToFit,
    buildBackgroundWidget = buildBackgroundWidget,
    buildDimmingLayer     = buildDimmingLayer,
}
