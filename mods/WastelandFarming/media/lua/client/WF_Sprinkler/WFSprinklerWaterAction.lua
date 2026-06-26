require "TimedActions/ISBaseTimedAction"

WFSprinklerWaterAction = ISBaseTimedAction:derive("WFSprinklerWaterAction")

local groundHighlighter	= GroundHighlighter:new()
groundHighlighter:setColor(0.25, 0.25, 1, 0.5)
groundHighlighter:enableXray(true, false)

function WFSprinklerWaterAction:isValid()
    if not self.barrel or self.barrel:getObjectIndex() == -1 or self.barrel:getWaterAmount() == 0 then return false end
    if not self.targetPlant or self.targetPlant.waterLvl >= 100 then return false end
    return true
end

function WFSprinklerWaterAction:waitToStart()
	self.character:faceLocation(self.targetSq:getX(), self.targetSq:getY())
	return self.character:shouldBeTurning()
end

function WFSprinklerWaterAction:update()
	self.character:faceLocation(self.targetSq:getX(), self.targetSq:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function WFSprinklerWaterAction:start()
	local x = self.targetSq:getX()
	local y = self.targetSq:getY()
	groundHighlighter:highlightSquare(x, y, x, y, self.targetSq:getZ())
	self.sound = self.character:playSound("WaterCrops")
	ISBaseTimedAction.start(self)
end

function WFSprinklerWaterAction:stop()
	groundHighlighter:remove()

	if self.sound and self.sound ~= 0 then
		self.character:getEmitter():stopOrTriggerSound(self.sound)
	end

	self.character:getPathFindBehavior2():cancel()
	self.character:setPath2(nil)

	ISBaseTimedAction.stop(self)
end

function WFSprinklerWaterAction:perform()
    groundHighlighter:remove()

	if self.sound and self.sound ~= 0 then
		self.character:getEmitter():stopOrTriggerSound(self.sound)
	end

	local waterAmount = math.min(self.maxAmount, 100 - self.targetPlant.waterLvl, WFSprinklerUtilities.getUsableWaterInBarrel(self.barrel))
	local barrelUsedWater = WFSprinklerUtilities.getWaterAmountFromUsed(waterAmount)
	-- update barrel
	local index = self.barrel:getObjectIndex()
    local args = {x=self.barrel:getX(), y=self.barrel:getY(), z=self.barrel:getZ(), units=barrelUsedWater, index=index}
    sendClientCommand(self.character, 'object', 'takeWater', args)

	-- update plant
	local args = { x = self.targetSq:getX(), y = self.targetSq:getY(), z = self.targetSq:getZ(), uses = math.ceil(waterAmount / 5) }
	CFarmingSystem.instance:sendCommand(self.character, 'water', args)

    -- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self)
end

function WFSprinklerWaterAction:new(character, barrel, targetPlant, maxAmount, time)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
    o.barrel = barrel
	o.sq = barrel:getSquare()
	o.targetSq = targetPlant:getObject():getSquare()
	o.targetPlant = targetPlant
	o.stopOnWalk = true
	o.stopOnRun = true
	o.maxTime = time
	o.maxAmount = maxAmount
	if character:isTimedActionInstant() then
		o.maxTime = 1
	end
	return o
end