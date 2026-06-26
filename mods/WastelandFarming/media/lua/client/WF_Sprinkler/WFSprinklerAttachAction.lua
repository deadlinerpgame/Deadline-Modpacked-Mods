require "TimedActions/ISBaseTimedAction"

WFSprinklerAttachAction = ISBaseTimedAction:derive("WFSprinklerAttachAction")

function WFSprinklerAttachAction:isValid()
    if not self.object or not self.object:getWaterMax() then return false end
    if not self.character:getInventory():contains(self.item) then return false end
    return true
end

function WFSprinklerAttachAction:waitToStart()
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
	return self.character:shouldBeTurning()
end

function WFSprinklerAttachAction:update()
	self.character:faceLocation(self.sq:getX(), self.sq:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function WFSprinklerAttachAction:getSprinklSprite()
    local barrelSprite = self.object:getSprite():getName()
    if barrelSprite == "crafted_01_24" or barrelSprite == "crafted_01_25" or
       barrelSprite == "crafted_01_28" or barrelSprite == "crafted_01_29" then
        return "Sprinkl_0"
    elseif barrelSprite == "carpentry_02_52" or barrelSprite == "carpentry_02_53" then
        return "Sprinkl_1"
    elseif barrelSprite == "carpentry_02_54" or barrelSprite == "carpentry_02_55" then
        return "Sprinkl_2"
    end

    return "Sprinkl_0" -- fallback to something
end

function WFSprinklerAttachAction:perform()
    local sprite = self:getSprinklSprite()
    local obj = IsoObject.new(self.sq, sprite, "WFSprinkler")

    self.sq:AddTileObject(obj)
    obj:transmitCompleteItemToServer()
    self.character:getInventory():DoRemoveItem(self.item)
    -- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function WFSprinklerAttachAction:new(character, item, barrel, time)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
    o.object = barrel
    o.sq = barrel:getSquare()
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = time
	if character:isTimedActionInstant() then
		o.maxTime = 1
	end
	return o
end