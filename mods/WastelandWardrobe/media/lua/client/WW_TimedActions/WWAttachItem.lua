WWAttachItem = ISBaseTimedAction:derive("WWAttachItem")

function WWAttachItem.doAttach(player, hotbar, item, slot, slotIndex, slotDef)
        if hotbar.replacements and hotbar.replacements[item:getAttachmentType()] then
            slot = hotbar.replacements[item:getAttachmentType()];
        end
        hotbar:setAttachAnim(item, slotDef);
        table.insert(ISTimedActionQueue.queues[player].queue, 1, ISAttachItemHotbar:new(hotbar.chr, item, slot, slotIndex, slotDef))
        -- first remove the current equipped one if needed
        if hotbar.attachedItems[slotIndex] then
            table.insert(ISTimedActionQueue.queues[player].queue, 1, ISDetachItemHotbar:new(hotbar.chr, hotbar.attachedItems[slotIndex]))
            -- ISTimedActionQueue.add(ISDetachItemHotbar:new(hotbar.chr, hotbar.attachedItems[slotIndex]));
        end
        -- ISTimedActionQueue.add(ISAttachItemHotbar:new(hotbar.chr, item, slot, slotIndex, slotDef));
end

function WWAttachItem:perform()
    local hotbar = getPlayerHotbar(self.player:getPlayerNum())
    hotbar:refresh()
    for slotIndex, slot in pairs(hotbar.availableSlot) do
        local slotDef = slot.def;
        if slotDef.type == self.slotType then
            for i, v in pairs(slotDef.attachments) do
                if self.item:getAttachmentType() == i then
                    print("Attaching " .. self.item:getType() ..  " to slot: " .. slotIndex)
                    WWAttachItem.doAttach(self.player, hotbar, self.item, v, slotIndex, slotDef)
                    ISBaseTimedAction.perform(self)
                    return
                end
            end
        end
    end
    print("No slot found for " .. self.item:getType() .. " at " .. self.slotType)
    print("My Attachment Type is: " .. self.item:getAttachmentType())
    ISBaseTimedAction.perform(self)
end

function WWAttachItem:new(player, item, slotType)
    local o = ISBaseTimedAction.new(self, player)
    o.player = player
    o.item = item
    o.slotType = slotType
    o.maxTime = 1
    return o
end
