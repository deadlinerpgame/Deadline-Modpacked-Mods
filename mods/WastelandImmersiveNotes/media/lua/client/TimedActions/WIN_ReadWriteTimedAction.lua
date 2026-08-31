require "TimedActions/ISBaseTimedAction"
require "WIN_Utils"

WIN_ReadWriteTimedAction = ISBaseTimedAction:derive("WIN_WriteTimedAction");

local PLAYER_NEWSPAPER_FULL_TYPE = "Base.WIN_PlayerNewspaper"
local BOREDOM_HALO_INTERVAL_MS = 30000
local BOREDOM_REDUCTION_PER_INTERVAL = 2.0

local function showBoredomReductionHalo(character)
    if not HaloTextHelper then
        return
    end

    HaloTextHelper.addTextWithArrow(
        character,
        getText("IGUI_HaloNote_Boredom"),
        false,
        HaloTextHelper.getColorGreen()
    )
end

local function reduceBoredom(character)
    local bodyDamage = character:getBodyDamage()
    local boredomLevel = bodyDamage:getBoredomLevel()
    if boredomLevel > 0 then
        bodyDamage:setBoredomLevel(math.max(0, boredomLevel - BOREDOM_REDUCTION_PER_INTERVAL))
    end
end

function WIN_ReadWriteTimedAction:isValid() return true end

function WIN_ReadWriteTimedAction:update()
    if self.reducesBoredom then
        local currentTimeMs = getTimestampMs()
        if currentTimeMs >= self.nextBoredomHaloAtMs then
            reduceBoredom(self.character)
            showBoredomReductionHalo(self.character)
            self.nextBoredomHaloAtMs = currentTimeMs + BOREDOM_HALO_INTERVAL_MS
        end
    end
end

function WIN_ReadWriteTimedAction:waitToStart() return false end

function WIN_ReadWriteTimedAction:start()
    self.character:playSound("NotebookOpening")
    self.reducesBoredom = not self.writingImplement and self.bookItem == PLAYER_NEWSPAPER_FULL_TYPE

    if self.reducesBoredom then
        local currentTimeMs = getTimestampMs()
        self.nextBoredomHaloAtMs = currentTimeMs + BOREDOM_HALO_INTERVAL_MS
    end

    if WIN_Utils.isBook(self.bookItem) then
        self.bookItem = "Base.Journal"
    end

    if WIN_Utils.isPaperSheet(self.bookItem) then
        self.bookItem = "Base.Newspaper"
    end

    self:setOverrideHandModels(self.writingImplement, self.bookItem)
    if self.writingImplement then
        self:setActionAnim("WriteInBook")
    else
        self:setActionAnim(CharacterActionAnims.Read)
        if WIN_Utils.isBook(self.bookItem) then
            self:setAnimVariable("ReadType", "book")
        elseif self.bookItem == "Base.Newspaper" or self.bookItem == "Base.MapInHand" then
            self:setAnimVariable("ReadType", "newspaper")
        end
    end
end

function WIN_ReadWriteTimedAction:stop()
    if WIN_Utils.isBook(self.bookItem) then
        self.character:playSound("CloseBook")
    end
    ISBaseTimedAction.stop(self)
end

function WIN_ReadWriteTimedAction:perform()
    ISBaseTimedAction.perform(self)
end

function WIN_ReadWriteTimedAction:new(character, bookItem, writingImplement)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.maxTime = -1
    o.useProgressBar = false
    o.forceProgressBar = false
    o.stopOnWalk = false
    o.stopOnRun = true
    o.bookItem = bookItem
    o.writingImplement = writingImplement
    o.reducesBoredom = false
    o.nextBoredomHaloAtMs = 0
    if o.character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end
