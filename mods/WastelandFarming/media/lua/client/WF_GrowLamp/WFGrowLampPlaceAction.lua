WFGrowLampPlaceAction = ISBaseTimedAction:derive("WFGrowLampPlaceAction")

function WFGrowLampPlaceAction:isValid()
    if not self.character:getInventory():contains(self.growLamp) then
        return false
    end
    return WFGrowLampUtilities.isValidSquareForLamp(self.square)
end

function WFGrowLampPlaceAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function WFGrowLampPlaceAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function WFGrowLampPlaceAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function WFGrowLampPlaceAction:perform()
    self.character:getInventory():Remove(self.growLamp)
    WFGrowLampUtilities.doPlaceGrowLamp(self.square)
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WFGrowLampPlaceAction:new(character, growLamp, square)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.square = square
    o.growLamp = growLamp
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 100
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
