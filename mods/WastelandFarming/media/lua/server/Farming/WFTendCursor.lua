WFTendCursor = ISBuildingObject:derive("WFTendCursor")

local function predicateNotBroken(item)
    return not item:isBroken()
end

function WFTendCursor:isValid(square)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(square)
    if not plant then return false end
    if not plant:isAlive() then return false end

    if ISFarmingMenu.cheat then return true end

    local scissors = self.character:getInventory():getFirstTypeEvalRecurse("Scissors", predicateNotBroken)
    if not scissors then return false end
    if not plant.lastTendHour then return true end
    if plant.lastTendHour + 22 > CFarmingSystem.instance.hoursElapsed then return false end
    return true
end

function WFTendCursor:create(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    ISFarmingMenu.walkToPlant(self.character, sq)
    local scissors = self.character:getInventory():getFirstTypeEvalRecurse("Scissors", predicateNotBroken)
    if not scissors then return end
	ISWorldObjectContextMenu.equip(self.character, self.character:getPrimaryHandItem(), scissors, true)
    ISTimedActionQueue.add(ISPlantInfoAction:new(self.character, CFarmingSystem.instance:getLuaObjectOnSquare(sq)))
    ISTimedActionQueue.add(WFTending.TendAction:new(self.character, sq, scissors))
end

function WFTendCursor:render(x, y, z, square)
    if not WFTendCursor.floorSprite then
        WFTendCursor.floorSprite = IsoSprite.new()
        WFTendCursor.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local hc = getCore():getGoodHighlitedColor()
    if not self:isValid(square) then
        hc = getCore():getBadHighlitedColor()
    end
    self.sq = square
    WFTendCursor.floorSprite:RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
end

function WFTendCursor:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.noNeedHammer = true
    o.skipBuildAction = true
    return o
end