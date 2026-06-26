
WLLPickLockAction = ISBaseTimedAction:derive("WLLPickLockAction")

local LOCKPICK_LOOP_SOUND = "WLL_LockpickLoop"
local LOCKPICK_SUCCESS_SOUND = "WLL_LockpickSuccess"
local LOCKPICK_FAIL_SOUND = "WLL_LockpickFail"

function WLLPickLockAction:isValid()
    if not WLL.BaseLock.PlayerCanPickLock(self.player) then return false end
    if not self.container then return false end
    if not self.system.IsLocked(self.container) then return false end
    return true
end

function WLLPickLockAction:start()
    self:setActionAnim("Loot")
    self.paperclip = self.player:getInventory():FindAndReturn("Paperclip")
    self.screwdriver = self.player:getInventory():FindAndReturn("Screwdriver")
    self.player:setPrimaryHandItem(self.paperclip)
    self.player:setSecondaryHandItem(self.screwdriver)
    self.sound = self.character:getEmitter():playSoundImpl(LOCKPICK_LOOP_SOUND, nil)
end

function WLLPickLockAction:waitToStart()
    if self.sq then
        self.character:faceLocation(self.sq:getX(), self.sq:getY())
        return self.character:shouldBeTurning()
    end
    return false
end

function WLLPickLockAction:update()
    if self.sq then
        self.character:faceLocation(self.sq:getX(), self.sq:getY())
        self.character:setMetabolicTarget(Metabolics.LightWork)
    end
    if not WLL.BaseLock.PlayerCanPickLock(self.player, self.paperclip, self.screwdriver) then
        self:forceStop()
    end
end

function WLLPickLockAction:stop()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function WLLPickLockAction:perform()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end

    local chance = 20
    chance = chance + self.player:getPerkLevel(Perks.Sneak) * 5
    -- if unhappy or stressed, reduce chance
    if self.player:getMoodles():getMoodleLevel(MoodleType.Unhappy) >= 1 then
        chance = chance - 10
    end
    if self.player:getMoodles():getMoodleLevel(MoodleType.Stressed) >= 1 then
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
        self.system.ClearLock(self.container)
        self.player:getXp():AddXP(Perks.Sneak, 15)
        local brokenLock = InventoryItemFactory.CreateItem("ScrapMetal")
        brokenLock:setName("Broken Lock")
        brokenLock:setCustomName(true)
        self.player:getInventory():AddItem(brokenLock) -- lock now goes into hands instead of ground
        WLL.ShowInfo(self.player, "You picked the lock, rendering it unusable.")
        self.player:getEmitter():playSoundImpl(LOCKPICK_SUCCESS_SOUND, nil)
        ISInventoryPage.OnContainerUpdate()
    else
        self.player:getXp():AddXP(Perks.Sneak, 5)
        WLL.ShowInfo(self.player, "You failed to pick the lock.")
        self.player:getEmitter():playSoundImpl(LOCKPICK_FAIL_SOUND, nil)
        if WLL.BaseLock.PlayerCanPickLock(self.player) then
            ISTimedActionQueue.add(WLLPickLockAction:new(self.player, self.system, self.container))
        end
    end

    -- needed to remove from queue / start next.
    ISBaseTimedAction.perform(self)
end

function WLLPickLockAction:new(player, system, container)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.character = player -- need this for ISBaseTimedAction
    o.system = system
    o.container = container
    o.sq = WLL.BaseLock.GetSquareForContainer(container)
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 900
    if player:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
