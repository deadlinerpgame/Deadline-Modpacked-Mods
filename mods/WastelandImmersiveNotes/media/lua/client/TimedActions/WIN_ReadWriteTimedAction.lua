require "TimedActions/ISBaseTimedAction"
require "WIN_Utils"

WIN_ReadWriteTimedAction = ISBaseTimedAction:derive("WIN_WriteTimedAction");

function WIN_ReadWriteTimedAction:isValid() return true end

function WIN_ReadWriteTimedAction:update() end

function WIN_ReadWriteTimedAction:waitToStart() return false end

function WIN_ReadWriteTimedAction:start()
    self.character:playSound("NotebookOpening")
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
    if o.character:isTimedActionInstant() then o.maxTime = 1 end
    return o
end