require "scavenging/WWP_TileScavengingData"
require "WL_SimpleLootTable"

local RECENTLY_SEARCHED_TEXT = "You searched here recently."
local SEARCH_COMPLETE_TEXT = "Search complete."

WWP_ScavengeTileAction = ISBaseTimedAction:derive("WWP_ScavengeTileAction")

function WWP_ScavengeTileAction:isValid()
    if not WWP_PlayerStats.hasPointsAvailable(self.character, self.scavengeType.workPoints) then
        self.character:setHaloNote("You need " .. tostring(self.scavengeType.workPoints) ..
                " work points to do that\n" .. WWP_PlayerStats.getWorkPointsRemainingString(self.character),
                250, 20, 60, 300.0)
        return false
    end

    if self.character:getPrimaryHandItem() or self.character:getSecondaryHandItem() then
        return false
    end

    return self.square and self.isoObject and self.isoObject:getSquare() == self.square
end

function WWP_ScavengeTileAction:start()
    if self.scavengeType.sound then
        self.sound = self.character:playSound(self.scavengeType.sound)
    end
    addSound(self.character, self.character:getX(), self.character:getY(), self.character:getZ(), 10, 1)
    local anim = self.scavengeType.animation or "Loot"
    self:setActionAnim(anim)
end

function WWP_ScavengeTileAction:stop()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end
    ISBaseTimedAction.stop(self)
end

function WWP_ScavengeTileAction:waitToStart()
    self.character:faceThisObject(self.isoObject)
    return self.character:shouldBeTurning()
end

function WWP_ScavengeTileAction:update()
    self.character:faceThisObject(self.isoObject)
end

function WWP_ScavengeTileAction:getLootTableRolls()
    if self.scavengeType.skill then
        local modifier = self.character:getPerkLevel(self.scavengeType.skill) / 10
        local rolls = WWP_PayrollProcessor.randomRound(self.scavengeType.rollsMax * modifier)
        return math.max(rolls, self.scavengeType.rollsMin)
    end

    return self.scavengeType.lootTableRolls
end

function WWP_ScavengeTileAction:perform()
    if self.sound and self.sound ~= 0 then
        self.character:stopOrTriggerSound(self.sound)
    end

    if WWP_TileScavengingData.isRecentlySearched(self.character, self.square) then
        self.character:setHaloNote(RECENTLY_SEARCHED_TEXT, 250, 20, 60, 300.0)
        ISBaseTimedAction.perform(self)
        return
    end

    WWP_PlayerStats.deductWorkPoints(self.character, self.scavengeType.workPoints)
    WWP_TileScavengingData.markSearched(self.character, self.square)
    self.character:setHaloNote(SEARCH_COMPLETE_TEXT .. "\n" .. WWP_PlayerStats.getWorkPointsRemainingString(self.character),
            124, 252, 0, 300.0)
    WL_SimpleLootTable.roll(self.scavengeType.items, self:getLootTableRolls(), self.scavengeType.multiplier)

    ISBaseTimedAction.perform(self)
end

function WWP_ScavengeTileAction:new(player, scavengeType, square, isoObject)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = player
    o.stopOnWalk = true
    o.stopOnRun = true
    o.scavengeType = scavengeType
    o.square = square
    o.isoObject = isoObject
    o.maxTime = scavengeType.time or 1000
    if player:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end
