---
--- WIN_WDCIntegration.lua
--- Optional Wasteland Dice Combat integration for handwriting comparisons.
---

WIN_WDCIntegration = {}
WIN_WDCIntegration.INVESTIGATION_REQUIRED = 4
WIN_WDCIntegration.DECEPTION_REQUIRED = 8
local WDC_MOD_ID = "WastelandDiceCombat"

local function getAbilityModifier(player, ability)
    return WDC_Modifiers.getAbilityModifier(player, ability)
end

function WIN_WDCIntegration.isActive()
    return getActivatedMods():contains(WDC_MOD_ID)
end

function WIN_WDCIntegration.hasSufficientInvestigation(player)
    return getAbilityModifier(player, WDC_Ability.Investigation) >= WIN_WDCIntegration.INVESTIGATION_REQUIRED
end

function WIN_WDCIntegration.hasSufficientDeception(player)
    return getAbilityModifier(player, WDC_Ability.Deception) >= WIN_WDCIntegration.DECEPTION_REQUIRED
end
