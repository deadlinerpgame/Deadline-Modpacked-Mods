--[=[ Disabled: only farming plots and tending remain active.
function OnCraftSprinkler()
    getPlayer():getXp():AddXP(Perks.Farming, 2)
    getPlayer():getXp():AddXP(Perks.Woodwork, 2)
    getPlayer():getXp():AddXP(Perks.MetalWelding, 5)
end

function OnCraftGrowLamp()
    getPlayer():getXp():AddXP(Perks.Farming, 2)
    getPlayer():getXp():AddXP(Perks.Woodwork, 2)
end
]=]
