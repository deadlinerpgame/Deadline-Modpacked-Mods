---
--- Constants.lua
--- UI Constants for WLZA (Zombie Attractors)
--- Centralizes fonts, colors, scaling, and other UI-related constants
---

WLZA_UI_Constants = WLZA_UI_Constants or {}

-- Font Heights
WLZA_UI_Constants.FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
WLZA_UI_Constants.FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
WLZA_UI_Constants.FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

-- Scaling
WLZA_UI_Constants.SCALE = WLZA_UI_Constants.FONT_HGT_SMALL / 19
function WLZA_UI_Constants.scale(px)
    return px * WLZA_UI_Constants.SCALE
end

-- Basic UI Colors
WLZA_UI_Constants.COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
WLZA_UI_Constants.COLOR_LABEL = { r = 1, g = 1, b = 1, a = 1 }
WLZA_UI_Constants.COLOR_HEADER = { r = 1, g = 1, b = 0, a = 1 }

-- Highlight Colors (used for both UI labels and in-world ground highlighters)
-- All colors use alpha = 1.0 (fully opaque)
WLZA_UI_Constants.COLOR_ATTRACTOR_POINT = { r = 0.3, g = 1.0, b = 0.3, a = 1 }  -- Green - Attractor position
WLZA_UI_Constants.COLOR_INSIDE_RANGE = { r = 1.0, g = 0.3, b = 0.3, a = 1 }    -- Red - Inside min/max range
WLZA_UI_Constants.COLOR_MIN_RANGE = { r = 1.0, g = 1.0, b = 0.0, a = 1 }        -- Yellow - Min range circle
WLZA_UI_Constants.COLOR_MAX_RANGE = { r = 1.0, g = 0.6, b = 0.0, a = 1 }        -- Orange - Max range circle