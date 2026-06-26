WFGrowLampPickupAction = ISBaseTimedAction:derive("WFGrowLampPickupAction")

function WFGrowLampPickupAction:isValid()
    return WFGrowLampUtilities.isGrowLamp(self.growLamp)
end

function WFGrowLampPickupAction:waitToStart()
    self.character:faceThisObject(self.growLamp)
    return self.character:shouldBeTurning()
end

function WFGrowLampPickupAction:update()
    self.character:faceThisObject(self.growLamp)
    self.character:setMetabolicTarget(Metabolics.HeavyDomestic)
end

function WFGrowLampPickupAction:start()
    self:setActionAnim("Loot")
    self.character:SetVariable("LootPosition", "Low")
    self.character:reportEvent("EventLootItem")
end

function WFGrowLampPickupAction:perform()
    self.character:getInventory():AddItem("wastelandfarming.GrowLamp")
    WFGrowLampUtilities.doRemoveGrowLamp(self.character, self.growLamp)
    local sq = self.growLamp:getSquare()
    local obj = sq:getObjects():get(0)
    for i = 0, sq:getObjects():size() - 1 do
        obj = sq:getObjects():get(i)
        if WFGrowLampUtilities.isGrowLampLight(obj) then
            sq:RemoveTileObject(obj)
        end
    end
    sq:RemoveTileObject(self.growLamp)
    IsoGenerator.updateGenerator(sq)
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WFGrowLampPickupAction:new(character, growLamp)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.growLamp = growLamp
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 300
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
