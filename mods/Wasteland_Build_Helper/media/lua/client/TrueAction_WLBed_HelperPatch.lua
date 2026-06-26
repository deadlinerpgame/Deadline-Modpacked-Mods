require "TrueActionsSetting"

-- ######################################################################################################
-- Patches the True Actions modification to support custom tiles
-- Requires Original Mod 2487022075 (https://steamcommunity.com/sharedfiles/filedetails/?id=2487022075)
-- Original Coding by iBrRus (https://steamcommunity.com/id/ibrrus)
-- Coded by CrystalChris (https://steamcommunity.com/id/404cucknotfound/) and cassieartn
-- Edited by it's moe for WastelandRP, all code and credits go to CrystalChris and iBrRus, I just used this to add tile support.
-- ######################################################################################################

----------------------------
-- @@@@@@@ WL Build Helper @@@@@@
----------------------------

-- wl_build_helper
TrueActions.WorldLieObject["wl_build_helpers_9"] = {{side = "L", dir = "E", x = 0.12, y = 1.6},{side = "R", dir = "E", x = 0.12, y = 1.6-1.8},}
TrueActions.WorldLieObject["wl_build_helpers_8"] = {{side = "R", dir = "S", x = 0.8, y = 0.1},{side = "L", dir = "S", x = 0.8-1.1, y = 0.1},}
TrueActions.WorldSeatObject["wl_build_helpers_10"] = {0.4, 0.8};
TrueActions.WorldSeatObject["wl_build_helpers_11"] = {0.8, 0.4};