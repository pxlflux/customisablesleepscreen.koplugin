-- Public interface for the infobox: delegates to the infobox sub-modules.

local render     = require("css_infobox_render")
local bookdata   = require("css_infobox_bookdata")
local bg_mod     = require("css_infobox_background")
local layout_mod = require("css_infobox_layout")

return {
    buildInfoBox         = layout_mod.buildInfoBox,
    freeTrackedBBs       = bg_mod.freeTrackedBBs,
    collectBookData      = bookdata.collectBookData,
    saveLastBookData     = bookdata.saveLastBookData,
    loadLastBookData     = bookdata.loadLastBookData,
    restorePatches       = render.restoreProgressWidgetPatch,
}
