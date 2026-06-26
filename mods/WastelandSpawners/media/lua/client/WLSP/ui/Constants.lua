---
--- constants.lua
--- UI Constants for WLSP (Wasteland Spawners)
--- Centralizes fonts, colors, scaling, and other UI-related constants
---

WLSP_UI_Constants = WLSP_UI_Constants or {}

-- Font Heights
WLSP_UI_Constants.FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
WLSP_UI_Constants.FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
WLSP_UI_Constants.FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

-- Scaling
WLSP_UI_Constants.SCALE = WLSP_UI_Constants.FONT_HGT_SMALL / 19
function WLSP_UI_Constants.scale(px)
    return px * WLSP_UI_Constants.SCALE
end

-- Basic UI Colors
WLSP_UI_Constants.COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
WLSP_UI_Constants.COLOR_LABEL = { r = 1, g = 1, b = 1, a = 1 }
WLSP_UI_Constants.COLOR_HEADER = { r = 1, g = 1, b = 0, a = 1 }

-- Highlight Colors (used for both UI labels and in-world ground highlighters)
-- All colors use alpha = 1.0 (fully opaque)
WLSP_UI_Constants.COLOR_SPAWN_POINT = { r = 0.3, g = 1.0, b = 0.3, a = 1 }      -- Green - Spawn position
WLSP_UI_Constants.COLOR_TARGET = { r = 1.0, g = 0.3, b = 0.3, a = 1 }           -- Red - Target location
WLSP_UI_Constants.COLOR_SPAWN_AREA = { r = 1.0, g = 1.0, b = 0.0, a = 1 }       -- Yellow - Spawn area/radius/ring
WLSP_UI_Constants.COLOR_PLAYER_CONDITION = { r = 0.3, g = 0.5, b = 1.0, a = 1 } -- Blue - Player condition areas
WLSP_UI_Constants.COLOR_ZOMBIE_CONDITION = { r = 1.0, g = 0.5, b = 1.0, a = 1 } -- Magenta - Zombie condition areas
WLSP_UI_Constants.COLOR_PER_PLAYER_AREA = { r = 0.7, g = 0.3, b = 1.0, a = 1 }  -- Purple - Per player in area
WLSP_UI_Constants.COLOR_TRIGGER = { r = 0.3, g = 0.9, b = 0.9, a = 1 }          -- Cyan - Trigger areas
