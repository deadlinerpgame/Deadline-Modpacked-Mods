
WLLPickDooorLockAction = ISBaseTimedAction:derive("WLLPickDooorLockAction")

local LOCKPICK_LOOP_SOUND = "WLL_LockpickLoop"
local LOCKPICK_SUCCESS_SOUND = "WLL_LockpickSuccess"
local LOCKPICK_FAIL_SOUND = "WLL_LockpickFail"

function WLLPickDooorLockAction:isValid()
    if not WLL.DoorLock.PlayerCanPickDoorLock(self.player) then return false end
    if not self.door then return false end
    if not WLL.DoorLock.HasLock(self.door) then return false end
    return true
end

function WLLPickDooorLockAction:start()
    self:setActionAnim("Loot")
    self.paperclip = self.player:getInventory():FindAndReturn("Paperclip")
    self.screwdriver = self.player:getInventory():FindAndReturn("Screwdriver")
    self.player:setPrimaryHandItem(self.paperclip)
    self.player:setSecondaryHandItem(self.screwdriver)
    self.sound = self.character:getEmitter():playSoundImpl(LOCKPICK_LOOP_SOUND, nil)
end

function WLLPickDooorLockAction:waitToStart()
    if self.sq then
        self.character:faceLocation(self.sq:getX(), self.sq:getY())
        return self.character:shouldBeTurning()
    end
    return false
end

function WLLPickDooorLockAction:update()
    if self.sq then
        self.character:faceLocation(self.sq:getX(), self.sq:getY())
        self.character:setMetabolicTarget(Metabolics.LightWork)
    end
    if not WLL.BaseLock.PlayerCanPickLock(self.player, self.paperclip, self.screwdriver) then
        self:forceStop()
    end
end

function WLLPickDooorLockAction:stop()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function WLLPickDooorLockAction:perform()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end

    local chance = 20
    chance = chance + self.player:getPerkLevel(Perks.Sneak) * 5
    -- if unhappy or stressed, reduce chance
    if self.player:getMoodles():getMoodleLevel(MoodleType.Unhappy) >= 1 then
        print("unhappy")
        chance = chance - 10
    end
    if self.player:getMoodles():getMoodleLevel(MoodleType.Stressed) >= 1 then
        print("stressed")
        chance = chance - 10
    end
    -- if crouching, give 1% bonus
    if self.player:isProne() then
        chance = chance + 1
    end

    chance = 100 - chance

    local roll = ZombRand(100)
    if getDebug() then
        WLL.ShowInfo(self.player, "DEBUG: Rolled " .. (roll) .. " of 100, need " .. chance)
    end
    local success = roll >= chance

    self.character:removeFromHands(self.paperclip)
    self.character:getInventory():Remove(self.paperclip)

    if success then
        WLL.ShowInfo(self.player, "You picked the lock and unlocked the door.")
        self.player:getXp():AddXP(Perks.Sneak, 20)
        self.door:setLockedByKey(false)
        self.door:setIsLocked(false)
        if instanceof(self.door, "IsoDoor") then
            self.door:setLocked(false)
        end
        self.player:getEmitter():playSoundImpl(LOCKPICK_SUCCESS_SOUND, nil)
    else
        self.player:getXp():AddXP(Perks.Sneak, 5)
        WLL.ShowInfo(self.player, "You failed to pick the lock.")
        self.player:getEmitter():playSoundImpl(LOCKPICK_FAIL_SOUND, nil)
        ISTimedActionQueue.add(WLLPickDooorLockAction:new(self.player, self.door))
    end

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WLLPickDooorLockAction:new(player, door)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.character = player -- need this for ISBaseTimedAction
    o.door = door
    o.sq = door:getSquare()
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 900
    if player:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
