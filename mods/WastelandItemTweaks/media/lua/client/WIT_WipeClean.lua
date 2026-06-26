---
--- WIT_WipeClean.lua
--- 04/06/2025
---

require "WL_Utils"

local lastWeaponCondition = {}
local lastWeaponEquipped  = {}

local function checkWeaponCondition(player)
    if not player or player:isDead() then return end

    local weapon = player:getPrimaryHandItem()
    local username = player:getUsername()

    local lastID = lastWeaponEquipped[username]
    local newID = weapon and weapon:IsWeapon() and (username .. "_" .. weapon:getFullType()) or nil

    if lastID and lastID ~= newID then
        lastWeaponCondition[lastID] = nil
    end
    lastWeaponEquipped[username] = newID

    if not weapon or not weapon:IsWeapon() then return end

    if not lastWeaponCondition[newID] then
        lastWeaponCondition[newID] = weapon:getCondition()
        return
    end

    local currentCondition = weapon:getCondition()
    local previousCondition = lastWeaponCondition[newID]

    if currentCondition < previousCondition then
        local grime = weapon:getBloodLevel()
        local cleanFactor = math.max(0, 1 - (grime / 100))

        local playerMaintenance = player:getPerkLevel(Perks.Maintenance) or 0
        local weaponRepairs = weapon:getHaveBeenRepaired() or 1

        local maintenanceFactor = math.max(0.02, math.min(playerMaintenance * 0.02, 0.20))
        local repairPenalty = math.min(weaponRepairs * 0.01, 0.05)

        local chanceToRepair = (maintenanceFactor - repairPenalty) * cleanFactor
        chanceToRepair = math.max(0, math.min(chanceToRepair, 0.20))

        local chance = ZombRandFloat(0, 1)

        if chance < chanceToRepair then
            weapon:setCondition(previousCondition)
            HaloTextHelper.addText(player, "Weapon Did Not Lose Condition", HaloTextHelper.getColorGreen())
        end
    end

    lastWeaponCondition[newID] = weapon:getCondition()
end

local function CleanWeaponContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()
        

    local function searchInv(search, itemType)
        local items = playerInv:getItems()
        if search == "item" then
            return playerInv:FindAndReturn(itemType)
        elseif search == "water" then
            return playerInv:FindAndReturnWaterItem(0.1)
        end
        return false
    end

    items = ISInventoryPane.getActualItems(items)
    if #items == 1 then
        local item = items[1]
        if not item:IsWeapon() or item:isRanged() then return end
        if item:getBloodLevel() > 0 then
            if not searchInv("item", "Base.RippedSheets") then
                WL_ContextMenuUtils.missingRequirement(context, "Wipe Clean", "You need one Ripped Sheet in your main inventory to wipe this weapon clean.", nil, "Item_RippedSheets")
                return
            end
            if not searchInv("water") then
                WL_ContextMenuUtils.missingRequirement(context, "Wipe Clean", "You don't have enough water in your main inventory to wipe this weapon clean.", nil, "Item_WaterBottleFull")
                return
            end
            local water = searchInv("water")
            local rag = searchInv("item", "Base.RippedSheets")
            local option = context:addOption("Wipe Clean", playerObj, function()
                ISTimedActionQueue.add(WIT_WipeCleanAction:new(playerObj, item, water, rag))
            end)
            WL_ContextMenuUtils.addToolTip(option, "Wipe Clean", "Wipe the grime off your weapon to reduce condition loss.\nUses a small amount of Water and one Ripped Sheet.", "Item_RippedSheets")
        elseif item:getBloodLevel() <= 0 then
            WL_ContextMenuUtils.missingRequirement(context, "Wipe Clean", "This weapon is already clean", nil, "Item_RippedSheet")
        end
    end
end

Events.OnPlayerUpdate.Add(checkWeaponCondition)
Events.OnFillInventoryObjectContextMenu.Add(CleanWeaponContextMenu)
