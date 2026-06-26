---
--- WWP_Factions
--- 2025-12-14
---

require "WLPP_System"
require "WWP_Faction"
require "WL_AFK_Kicker"

WWP_Factions = {}

---Gets the faction and rank for a player, or nil if they have none
---@param player IsoPlayer The player to get the faction rank for
---@return table|nil faction The faction definition table from WWP_Faction
---@return number|nil rank The player's rank in the faction (Usually from 1 to 5)
function WWP_Factions.getFactionRank(player)
    if not player then error("player is nil") end
    if not WL_Profile then return nil, nil end
    local profileIDs = WL_Profile:getProfilesForPlayer(player:getUsername()) or {}
    for _, profileID in ipairs(profileIDs) do
        local profileDef = WL_Profile:getProfileDefinition(profileID)
       if profileDef and WWP_Faction[profileDef.name] then
            local rank = WL_Profile:getProfileValue(player:getUsername(), profileID)
            return WWP_Faction[profileDef.name], tonumber(rank)
       end
    end
    return nil, nil
end

function WWP_Factions.doFactionPay()
    if not WWP_Options.workForFaction then return end
    if WL_AFK_Kicker.hasBeenAfk(300) then
        return end
    local player = getPlayer()
    local faction, rank = WWP_Factions.getFactionRank(player)
    if not faction or not rank then
        return end

    if not WWP_PlayerStats.hasPointsAvailable(player, WWP_PayrollProcessor.DEFAULT_WORK_POINTS_PER_TICK) then
        return end

    if faction and WWP_PlayerStats.hasPointsAvailable(player, WWP_PayrollProcessor.DEFAULT_WORK_POINTS_PER_TICK)then
        local salary = faction.salaries[rank] or 1
        WWP_PayrollProcessor.payRegularSalary(player, salary, faction.name .. " Grade " .. tostring(rank))
    end
end

WL_RealTimeEvents.EveryXMinutes(5, WWP_Factions.doFactionPay)