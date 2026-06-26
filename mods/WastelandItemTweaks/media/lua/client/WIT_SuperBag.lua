if WIT_SuperBag then
    Events.OnFillWorldObjectContextMenu.Remove(WIT_SuperBag.OnFillWorldObjectContextMenu)
end

WIT_SuperBag = {}

function WIT_SuperBag.IsSuperBag(item)
    if not instanceof(item, "InventoryItem") then return false end
    local modData = item:getModData()
    return modData["WIT_SuperBag"]
end

function WIT_SuperBag.MakeSuperBag(item)
    local modData = item:getModData()
    modData["WIT_SuperBag"] = getTimestamp()
    item:setName("Super Bag")
    item:setCapacity(5000)
    item:setCustomName(true)
    item:setWeightReduction(100)
end

function WIT_SuperBag.CheckItem(item)
    local modData = item:getModData()
    if not modData["WIT_SuperBag"] then
        return
    end

    local timeRemaining = SandboxVars.WastelandItemTweaks.SuperBagLifespan - (getTimestamp() - modData["WIT_SuperBag"])

    if timeRemaining < 0 then
        item:setName("Super Bag - Expired")
        item:setCapacity(1)
        item:setWeightReduction(0)
        modData["WIT_SuperBag"] = nil
        WL_Utils.addErrorToChat("Super Bag has expired!")
    else
        local timeRemaining = WL_Utils.toHumanReadableTime(timeRemaining*1000)
        item:setName("Super Bag - " .. timeRemaining .. " remaining")
    end
end

function WIT_SuperBag.CheckPlayerInventory()
    local player = getPlayer()
    for i=0,player:getInventory():getItems():size()-1 do
        local item = player:getInventory():getItems():get(i)
        if WIT_SuperBag.IsSuperBag(item) then
            WIT_SuperBag.CheckItem(item)
        end
    end
end

function WIT_SuperBag.OnFillWorldObjectContextMenu(playerIdx, context, wo, test)
    if test then return end

    local player = getSpecificPlayer(playerIdx)
    if not WL_Utils.canModerate(player) then return end

    local wlAdminMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local spawnerSubmenu = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdminMenu, "Spawn")
    spawnerSubmenu:addOption("Super Bag", player, function()
        local item = InventoryItemFactory.CreateItem("Base.Plasticbag")
        WIT_SuperBag.MakeSuperBag(item)
        local square = player:getCurrentSquare()
        square:AddWorldInventoryItem(item, 0.5, 0.5, 0)
    end)
end

-- ISInventoryTransferAction.WIT_SuperBag_TransferItem = ISInventoryTransferAction.WIT_SuperBag_TransferItem or ISInventoryTransferAction.transferItem
-- function ISInventoryTransferAction:transferItem(item)
--     if WIT_SuperBag.IsSuperBag(item) then
--         if self.destContainer ~= self.character:getInventory() then
--             WL_Utils.addErrorToChat("Super Bags can not be moved out of your main inventory.")
--             return
--         end
--         if self.destContainer ~= self.character:getInventory() and not WL_Utils.canModerate(self.character) then
--             WL_Utils.addErrorToChat("Super Bags can not be moved out of your main inventory.")
--             return
--         end
--     end
--     self:WIT_SuperBag_TransferItem(item)
-- end

ISInventoryTransferAction.WIT_SuperBag_new = ISInventoryTransferAction.WIT_SuperBag_new or ISInventoryTransferAction.new
function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
    local action = ISInventoryTransferAction:WIT_SuperBag_new(character, item, srcContainer, destContainer, time)

    if WIT_SuperBag.IsSuperBag(item) and not WL_Utils.isStaff(character) then
        if destContainer ~= character:getInventory() then
            WL_Utils.addErrorToChat("Super Bags can not be moved out of your main inventory.")
            action.isValid = function() return false end
        end
        if destContainer ~= character:getInventory() and not WL_Utils.canModerate(character) then
            WL_Utils.addErrorToChat("Super Bags can not be moved out of your main inventory.")
            action.isValid = function() return false end
        end
    end

    if (action.destContainer and WIT_SuperBag.IsSuperBag(action.destContainer:getContainingItem())) or
       (action.srcContainer and WIT_SuperBag.IsSuperBag(action.srcContainer:getContainingItem())) then
        action.maxTime = 1
    end

    return action
end


Events.OnFillWorldObjectContextMenu.Add(WIT_SuperBag.OnFillWorldObjectContextMenu)
Events.EveryOneMinute.Add(WIT_SuperBag.CheckPlayerInventory)