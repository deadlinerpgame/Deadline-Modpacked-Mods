function ISRadioAction:performAddMedia()
    if self:isValidAddMedia() and self.secondaryItem then
        self.deviceData:addMediaItem(self.secondaryItem);
        if self.secondaryItem:getModData().WWP_ATS_Applied then
            self.device:getModData().WWP_ATS_Applied = self.secondaryItem:getModData().WWP_ATS_Applied
            self.device:getModData().WWP_ATS_AppliedTo = self.secondaryItem:getModData().WWP_ATS_AppliedTo
        end
    end
end

function ISRadioAction:performRemoveMedia()
    if self:isValidRemoveMedia() and self.character:getInventory() then
        local item = self.deviceData:removeMediaItem(self.character:getInventory());
        if self.device:getModData().WWP_ATS_Applied then
            item:getModData().WWP_ATS_Applied = self.device:getModData().WWP_ATS_Applied
            item:getModData().WWP_ATS_AppliedTo = self.device:getModData().WWP_ATS_AppliedTo

            self.device:getModData().WWP_ATS_Applied = nil
            self.device:getModData().WWP_ATS_AppliedTo = nil
        end
    end
end

local ISReadABook_new = ISReadABook.new
function ISReadABook:new(playerObj, item, time)
    local o = ISReadABook_new(self, playerObj, item, time)
    o.WWP_ATS_Applied = item:getModData().WWP_ATS_Applied
    o.WWP_ATS_AppliedTo = item:getModData().WWP_ATS_AppliedTo
    o.WWP_ATS_ItemType = item:getFullType()
    return o;
end

local ISReadABook_perform = ISReadABook.perform
function ISReadABook:perform()
    ISReadABook_perform(self)
    if self.WWP_ATS_Applied then
        local item = self.character:getInventory():FindAndReturn(self.WWP_ATS_ItemType)
        if item then
            item:getModData().WWP_ATS_Applied = self.WWP_ATS_Applied
            item:getModData().WWP_ATS_AppliedTo = self.WWP_ATS_AppliedTo
        end
    end
end
