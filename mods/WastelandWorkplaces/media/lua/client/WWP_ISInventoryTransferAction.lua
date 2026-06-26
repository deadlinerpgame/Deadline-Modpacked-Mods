if not isClient() then return end

local original_WWP_ISInventoryTransferAction_transferItem = ISInventoryTransferAction.transferItem
function ISInventoryTransferAction:transferItem(item)
    local sourceIsSelf = self.srcContainer:isInCharacterInventory(self.character)
    local destIsSelf = self.destContainer:isInCharacterInventory(self.character)
    if sourceIsSelf == destIsSelf then
        return original_WWP_ISInventoryTransferAction_transferItem(self, item)
    end
    if sourceIsSelf then
        local isoObject = self.destContainer:getParent()
        local x, y, z
        if isoObject then
            x = isoObject:getX()
            y = isoObject:getY()
            z = isoObject:getZ()
        elseif self.destContainer:getType() == "floor" then
            x = self.character:getX()
            y = self.character:getY()
            z = self.character:getZ()
        elseif self.destContainer:getContainingItem() and self.destContainer:getContainingItem():getWorldItem() then
            local worldItem = self.destContainer:getContainingItem():getWorldItem()
            x = worldItem:getSquare():getX()
            y = worldItem:getSquare():getY()
            z = worldItem:getSquare():getZ()
        else
            return original_WWP_ISInventoryTransferAction_transferItem(self, item)
        end
        
        local workplaces = WWP_WorkplaceZone.getZonesAt(x, y, z)
        for _, workplace in ipairs(workplaces) do
            workplace:onPlayerPutItem(self.character, self.item)
        end
        if isoObject and isoObject:getModData() and isoObject:getModData().WWP_AutoATSContainer and #workplaces > 0 then
            self.item:getModData().WWP_ATS_Applied = true
            self.item:getModData().WWP_ATS_AppliedTo = workplaces[1].id
        end
    elseif destIsSelf then
        local isoObject = self.srcContainer:getParent()
        local x, y, z
        if isoObject then
            x = isoObject:getX()
            y = isoObject:getY()
            z = isoObject:getZ()
        elseif self.srcContainer:getType() == "floor" then
            x = self.character:getX()
            y = self.character:getY()
            z = self.character:getZ()
        elseif self.srcContainer:getContainingItem() and self.srcContainer:getContainingItem():getWorldItem() then
            local worldItem = self.srcContainer:getContainingItem():getWorldItem()
            x = worldItem:getSquare():getX()
            y = worldItem:getSquare():getY()
            z = worldItem:getSquare():getZ()
        else
            return original_WWP_ISInventoryTransferAction_transferItem(self, item)
        end
        local workplaces = WWP_WorkplaceZone.getZonesAt(x, y, z)
        for _, workplace in ipairs(workplaces) do
            workplace:onPlayerTakeItem(self.character, self.item)
        end
    end

    return original_WWP_ISInventoryTransferAction_transferItem(self, item)
end