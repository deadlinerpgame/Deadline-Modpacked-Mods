ISClothingTransferAction = ISBaseTimedAction:derive("ISClothingTransferAction")

function ISClothingTransferAction:isValid()
    return true
end

function ISClothingTransferAction:waitToStart()
    return false
end

function ISClothingTransferAction:start()
    local function hasContainerSpace(container, item)
        local freeSpace
        if self.organized then
            freeSpace = (container:getCapacity() * 1.3) - container:getContentsWeight()
        else
            freeSpace = container:getCapacity() - container:getContentsWeight()
        end
        return freeSpace >= item:getWeight()
    end

    local nearbyContainers = self.validContainers
    if not nearbyContainers or #nearbyContainers == 0 then
        self.character:Say("No valid containers found nearby.")
        return
    end

    for _, item in ipairs(self.itemsToRemove) do
        local itemStored = false

        for _, container in ipairs(nearbyContainers) do
            if hasContainerSpace(container, item) then
                ISTimedActionQueue.add(ISInventoryTransferAction:new(self.character, item, self.playerInventory, container))
                print("Item stored in container: " .. tostring(container:getType()))
                itemStored = true
                break
            end
        end

        if not itemStored then
            self.character:getInventory():AddItem(item)
            self.character:Say("No space in containers, keeping some items in inventory.")
        end
    end
    self.maxTime = 1
end

function ISClothingTransferAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISClothingTransferAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISClothingTransferAction:new(character, itemsToRemove, validContainers, playerInventory)
    local o = ISBaseTimedAction.new(self, character)
    o.character = character
    if character:HasTrait("Organized") then
        o.organized = true
    end
    o.itemsToRemove = itemsToRemove
    o.validContainers = validContainers
    o.playerInventory = playerInventory
    o.maxTime = 1
    return o
end
