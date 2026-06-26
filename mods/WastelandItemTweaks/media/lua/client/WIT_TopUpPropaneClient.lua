---
--- WIT_TopUpPropaneClient.lua
--- 12/11/2024 (Modified for proper transfer-then-refill logic)
--- 

require "TimedActions/ISBaseTimedAction"
require "ISInventoryTransferAction"
require "WL_Utils"

WIT_TopUpPropane = ISBaseTimedAction:derive("WIT_TopUpPropane")

function WIT_TopUpPropane:isValid()
    return self.sourceItem and self.targetItem and self.sourceItem:getUsedDelta() > 0 and self.targetItem:getUsedDelta() < 1
end

function WIT_TopUpPropane:start()
    self.sourceStart = self.sourceItem:getUsedDelta() * 16
    self.targetStart = self.targetItem:getUsedDelta() * 40
    local add = self.sourceStart
    local take = math.min(add, 40 - self.targetStart)
    self.sourceTarget = (self.sourceStart - take) / 16
    self.targetTarget = (self.targetStart + take) / 40
    self.action:setTime(take * 50)
    self:setActionAnim("refuelgascan")
    self.sound = self.character:playSound("CanisterAddFuelSiphon")

    self.originalContainer = self.originalContainer or self.targetItem:getContainer()
    self.character:setPrimaryHandItem(self.targetItem)
    self.character:setSecondaryHandItem(self.sourceItem)
end

function WIT_TopUpPropane:update()
    local progress = self:getJobDelta()
    local currentSourceDelta = self.sourceStart - (self.sourceStart - self.sourceTarget * 16) * progress
    local currentTargetDelta = self.targetStart + (self.targetTarget * 40 - self.targetStart) * progress
    self.sourceItem:setUsedDelta(currentSourceDelta / 16)
    self.targetItem:setUsedDelta(currentTargetDelta / 40)
end

function WIT_TopUpPropane:stop()
    self.character:stopOrTriggerSound(self.sound)
    self.sourceItem:setJobDelta(0)
    self.character:setPrimaryHandItem(nil)
    self.character:setSecondaryHandItem(nil)

    ISBaseTimedAction.stop(self)
end

function WIT_TopUpPropane:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.sourceItem:setJobDelta(0)
    self.sourceItem:setUsedDelta(self.sourceTarget)
    self.targetItem:setUsedDelta(self.targetTarget)

    if (self.originalContainer and self.originalContainer ~= self.character:getInventory()) then
        local nextStep = ISInventoryTransferAction:new(self.character, self.targetItem, self.character:getInventory(), self.originalContainer, 1)
        ISTimedActionQueue.addAfter(self, nextStep)
        local nextStep2 = ISInventoryTransferAction:new(self.character, self.sourceItem, self.character:getInventory(), self.originalContainer, 1)
        ISTimedActionQueue.addAfter(nextStep, nextStep2)
    end

    ISBaseTimedAction.perform(self)
end

function WIT_TopUpPropane:new(character, sourceItem, targetItem, time, originalContainer)
    local o = ISBaseTimedAction.new(self, character)
    o.sourceItem = sourceItem
    o.targetItem = targetItem
    o.character = character
    o.maxTime = time
    o.originalContainer = originalContainer
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

local function getNearbyContainers(player)
    local containers = {}
    table.insert(containers, player:getInventory())
    local playerNum = player and player:getPlayerNum() or -1
    local lootContainers = getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks
    for i, lootContainer in ipairs(lootContainers) do
        table.insert(containers, lootContainer.inventory)
    end
    local playerSquare = player:getSquare()
    if playerSquare then
        for i = 0, playerSquare:getObjects():size() - 1 do
            local obj = playerSquare:getObjects():get(i)
            if obj:getContainer() then
                table.insert(containers, obj:getContainer())
            end
        end
    end
    return containers
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerIdx, context, items)
    items = ISInventoryPane.getActualItems(items)
    local player = getSpecificPlayer(playerIdx)
    local containers = getNearbyContainers(player)

    local sourceItems = {}
    local targetItem
    local optionAdded = false

    for _, container in ipairs(containers) do
        for i = 0, container:getItems():size() - 1 do
            local item = container:getItems():get(i)
            if item:getType() == "PropaneTank" and item:getUsedDelta() > 0 then
                table.insert(sourceItems, item)
            elseif item:getType() == "LargePropaneTank" and item:getUsedDelta() < 1 then
                targetItem = targetItem or item
            end
        end
    end

    table.sort(sourceItems, function(a, b) return a:getUsedDelta() < b:getUsedDelta() end)
    local sourceItem = sourceItems[1]

    if items[1]:getType() == "PropaneTank" or items[1]:getType() == "LargePropaneTank" then
        if sourceItem and targetItem and not optionAdded then
            context:addOption("Pour Propane into Industrial Propane Tank", player, function()
                local originalContainer = targetItem:getContainer()
                local sourceItemContainer = sourceItem:getContainer()
                if originalContainer ~= player:getInventory() then
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(player, targetItem, originalContainer, player:getInventory()))
                end
                if sourceItemContainer ~= player:getInventory() then
                    ISTimedActionQueue.add(ISInventoryTransferAction:new(player, sourceItem, sourceItemContainer, player:getInventory()))
                end
                ISTimedActionQueue.add(WIT_TopUpPropane:new(player, sourceItem, targetItem, 50, originalContainer))
            end, sourceItem)
            optionAdded = true
        elseif sourceItem and not targetItem and not optionAdded then
            WL_ContextMenuUtils.missingRequirement(context, "Pour Propane into Industrial Propane Tank", "No Industrial Propane Tanks with space are nearby.", nil, "Item_PropaneTank")
            optionAdded = true
        end

        if targetItem and sourceItem and not optionAdded then
            context:addOption("Pour Propane into Industrial Propane Tank", player, function()
                ISTimedActionQueue.add(WIT_TopUpPropane:new(player, sourceItem, targetItem, 50, originalContainer))
            end, targetItem)
            optionAdded = true
        elseif targetItem and not sourceItem and not optionAdded and items[1] == targetItem then
            WL_ContextMenuUtils.missingRequirement(context, "Pour Propane into Industrial Propane Tank", "No Propane Tanks with Propane are nearby.", nil, "Item_PropaneTank")
            optionAdded = true
        end
    end
end)