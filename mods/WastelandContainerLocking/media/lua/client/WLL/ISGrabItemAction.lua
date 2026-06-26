local original_ISGrabItemAction_new = ISGrabItemAction.new
function ISGrabItemAction:new(character, item, time)
    local result = original_ISGrabItemAction_new(self, character, item, time)

    local inventoryItem = item and item:getItem()
    local container = inventoryItem:getContainer()

    local canTake = WLL.CanTakeFromContainer(character, container)
    if not canTake then
        WLL.ShowError(character, "Can't take from that container.")
        return {ignoreAction = true}
    end

    if WLL.Frozen.IsFrozen(container) then
        if result:isValid() then
            WLL.ShowError(character, "This container is frozen and cannot be accessed.")
            return {ignoreAction = true}
        end
    end

    return result
end

local original_ISGrabItemAction_start = ISGrabItemAction.start
function ISGrabItemAction:start()
    local result = original_ISGrabItemAction_start(self)

    local inventoryItem = self.item and self.item:getItem()
    local container = inventoryItem:getContainer()

    local canTake = WLL.CanTakeFromContainer(self.character, container)
    if not canTake then
        WLL.ShowError(self.character, "Can't take from that container.")
        self:forceStop()
        return 
    end
    if WLL.Frozen.IsFrozen(container) then
        WLL.ShowError(self.character, "This container is frozen and cannot be accessed.")
        self:forceStop()
        return
    end

    return result
end
