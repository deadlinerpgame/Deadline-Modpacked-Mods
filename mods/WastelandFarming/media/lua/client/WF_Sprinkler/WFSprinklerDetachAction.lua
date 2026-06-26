require "TimedActions/ISBaseTimedAction"

WFSprinklerDetachAction = ISBaseTimedAction:derive("WFSprinklerDetachAction")

function WFSprinklerDetachAction:isValid()
    if self.sprinkler:getObjectIndex() == -1 then return false end
    return true
end

function WFSprinklerDetachAction:waitToStart()
    self.character:faceLocation(self.sq:getX(), self.sq:getY())
    return self.character:shouldBeTurning()
end

function WFSprinklerDetachAction:update()
    self.character:faceLocation(self.sq:getX(), self.sq:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function WFSprinklerDetachAction:perform()
    self.sq:transmitRemoveItemFromSquare(self.sprinkler)
    self.sprinkler:removeFromWorld()
    self.sprinkler:removeFromSquare()
    self.sprinkler:setSquare(nil)
    self.character:getInventory():AddItem("wastelandfarming.SprinklerCrafted")
    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WFSprinklerDetachAction:new(character, sprinkler, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.sprinkler = sprinkler
    o.sq = sprinkler:getSquare()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end