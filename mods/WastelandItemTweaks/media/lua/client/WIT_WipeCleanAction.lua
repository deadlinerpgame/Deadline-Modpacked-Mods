---
--- WIT_WipeCleanAction.lua
--- 04/06/2025
--- 

require "TimedActions/ISBaseTimedAction"

WIT_WipeCleanAction = ISBaseTimedAction:derive("WIT_WipeCleanAction")

function WIT_WipeCleanAction:isValid()
    return self.item and self.character:getInventory():contains(self.item)
end

function WIT_WipeCleanAction:start()
    if self.item:getBloodLevel() <= 0 then
        self:forceComplete()
    else
        self.item:setJobType("Wipe Clean")
        self.item:setJobDelta(0.0)
        self:setActionAnim("Loot")
        self:setAnimVariable("LootPosition", "")
        self:setOverrideHandModels(self.item, nil)
        self.sound = self.character:playSound("WaterCrops")
    end
end

function WIT_WipeCleanAction:update()
    self.item:setJobDelta(self:getJobDelta())
end

function WIT_WipeCleanAction:stop()
    if self.item then
        self.item:setJobDelta(0.0)
    end
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function WIT_WipeCleanAction:perform()
    self.item:setJobDelta(0.0)
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    local grime = self.item:getBloodLevel()
    if grime > 0 then
        self.item:setBloodLevel(math.max(0, grime - 0.1))
        self.water:setUsedDelta(self.water:getUsedDelta() - (self.water:getUseDelta() * 0.015))
        if self.rag and self.attempt == 1 then
            local playerInv = self.character:getInventory()
            if playerInv:contains(self.rag) then
                playerInv:Remove(self.rag)
                playerInv:AddItem("Base.RippedSheetsDirty")
            end
        end
        self.character:getXp():AddXP(Perks.Maintenance, 2)
        ISTimedActionQueue.add(WIT_WipeCleanAction:new(self.character, self.item, self.water, self.rag, self.attempt + 1))
    end
    ISBaseTimedAction.perform(self)
end

function WIT_WipeCleanAction:new(character, item, water, rag, attempt)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.item = item
    o.water = water
    o.rag = rag
    o.attempt = attempt or 1
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 150
    return o
end
