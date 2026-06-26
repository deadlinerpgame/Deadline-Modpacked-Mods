require "WL_SimpleLootTable"

WWP_WorkplaceTimedAction = ISBaseTimedAction:derive("WWP_WorkplaceTimedAction")

function WWP_WorkplaceTimedAction:isValid()
    if not self.zone:isInZone(self.character:getX(), self.character:getY(), self.character:getZ()) then
        self.character:setHaloNote("You need to be inside your workplace to do that", 250, 20, 60, 300.0)
        return false
    end

    if not WWP_PlayerStats.hasPointsAvailable(self.character, self.wpAction.work) then
        self.character:setHaloNote("You need " .. tostring(self.wpAction.work) ..
                " work points to do that\n" .. WWP_PlayerStats.getWorkPointsRemainingString(self.character),
                250, 20, 60, 300.0)
        return false
    end
    return true
end

function WWP_WorkplaceTimedAction:start()
    if self.wpAction.sound then
        self.sound = self.character:getEmitter():playSound(self.wpAction.sound)
    end
    local anim = self.wpAction.animation or "Loot"
    self:setActionAnim(anim)
end

function WWP_WorkplaceTimedAction:stop()
    if self.sound and self.sound ~= 0 then
        self.character:getEmitter():stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function WWP_WorkplaceTimedAction:waitToStart()
    return false
end

function WWP_WorkplaceTimedAction:perform()
    if self.sound and self.sound ~= 0 then
        self.character:getEmitter():stopOrTriggerSound(self.sound)
    end

    WWP_PlayerStats.deductWorkPoints(self.character, self.wpAction.work)
    self.character:setHaloNote(self.wpAction.name .. " completed\n" ..  WWP_PlayerStats.getWorkPointsRemainingString(self.character),
            124, 252, 0, 300.0)

    local modifier = 1.0
    if self.wpAction.skill then
        modifier = (getPlayer():getPerkLevel(self.wpAction.skill) / 10)
    end

    local actualRollsMax =  WWP_PayrollProcessor.randomRound(self.wpAction.rollsMax * modifier)
    actualRollsMax = math.max(actualRollsMax, self.wpAction.rollsMin)
    WL_SimpleLootTable.roll(self.wpAction.items, actualRollsMax, self.wpAction.multiplier)

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WWP_WorkplaceTimedAction:new(player, wpAction, zone)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = player -- need this for ISBaseTimedAction
    o.stopOnWalk = true
    o.wpAction = wpAction
    o.stopOnRun = true
    o.zone = zone
    o.maxTime = wpAction.time or 1000
    if player:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
