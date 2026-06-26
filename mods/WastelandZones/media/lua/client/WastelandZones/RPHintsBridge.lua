if not isClient() then return end

if not getActivatedMods():contains("WastelandRpHints") then
    return
end

---@class WastelandZones.RPHintsSystem
---@field name string
local RPHintsSystem = {}
RPHintsSystem.name = "WastelandZones"

---@return string[]
function RPHintsSystem.GetHints()
    local hints = {}
    local runtime = WastelandZones and WastelandZones.Runtime
    local byPlayer = runtime and runtime.playerZoneRpHints
    local player = getPlayer()
    if not player or not byPlayer then
        return hints
    end

    local perZone = byPlayer[player:getPlayerNum()]
    if not perZone then
        return hints
    end

    for _, hint in pairs(perZone) do
        if hint and hint ~= "" then
            hints[#hints + 1] = hint
        end
    end

    return hints
end

WRH.RegisterSystem(RPHintsSystem)
