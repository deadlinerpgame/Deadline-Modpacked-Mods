local original_ISInventoryTransferAction_new = ISInventoryTransferAction.new
function ISInventoryTransferAction:new (character, item, srcContainer, destContainer, time)
    local result = original_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)

    local canTake = WLL.CanTakeFromContainer(character, srcContainer)
    local canPut = WLL.CanPutIntoContainer(character, destContainer)

    if not canTake then
        WLL.ShowError(character, "Can't take from that container.")
        return {ignoreAction = true}
    end

    if not canPut then
        WLL.ShowError(character, "Can't put into that container.")
        return {ignoreAction = true}
    end

    if WLL.Frozen.IsFrozen(srcContainer) then
        -- Duplicate items when moving from a locked container
        if result:isValid() and destContainer:isInCharacterInventory(character) then
            local duplicate = WL_Utils.cloneItem(item)
            if duplicate then
                destContainer:AddItem(duplicate)
                return {ignoreAction = true}
            else
                WLL.ShowError(character, "Failed to create duplicate item in the destination container.")
                return {ignoreAction = true}
            end
        else
            WLL.ShowError(character, "Failed to create duplicate item in the destination container.")
            return {ignoreAction = true}
        end
    end

    if WLL.Frozen.IsFrozen(destContainer) then
        -- Disallow moving items into a locked container
        WLL.ShowError(character, "This container is frozen.")
        return {ignoreAction = true}
    end

    return result
end