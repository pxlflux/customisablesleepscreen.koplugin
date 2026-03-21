-- Public interface for the infobox: delegates to the infobox sub-modules.

local render     = require("infobox_render")
local bookdata   = require("infobox_bookdata")
local bg_mod     = require("infobox_background")
local layout_mod = require("infobox_layout")

return {
    buildInfoBox         = layout_mod.buildInfoBox,
    freeTrackedBBs       = bg_mod.freeTrackedBBs,
    collectBookData      = bookdata.collectBookData,
    saveLastBookData     = bookdata.saveLastBookData,
    loadLastBookData     = bookdata.loadLastBookData,
    restorePatches       = render.restoreProgressWidgetPatch,
}
