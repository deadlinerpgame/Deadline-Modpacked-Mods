require "BuildingObjects/ISBuildingObject"

local RemoveCursor = ISBuildingObject:derive("WF_RemoveCursor")

function RemoveCursor:create(x, y, z, north, sprite)
	local sq = getWorld():getCell():getGridSquare(x, y, z)
	if not sq then return end
	local plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq)
	if not plant then return end
	ISFarmingMenu.onShovel(nil, plant, self.character, sq)
end

function RemoveCursor:new(character)
	local o = {}
	setmetatable(o, self)
	self.__index = self
    o.character = character
	o.skipBuildAction = true
    o.noNeedHammer = true
	return o
end

function RemoveCursor:isValid(square)
	if not ISFarmingMenu.getShovel(self.character) then
		return false
	end
	if not CFarmingSystem.instance:getLuaObjectOnSquare(square) then
		return false
	end
	return true
end

function RemoveCursor:render(x, y, z, square)
    if not RemoveCursor.floorSprite then
        RemoveCursor.floorSprite = IsoSprite.new()
        RemoveCursor.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local hc = getCore():getGoodHighlitedColor()
    if not self:isValid(square) then
        hc = getCore():getBadHighlitedColor()
    end
    self.sq = square
    RemoveCursor.floorSprite:RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
end

function RemoveCursor:getAPrompt()
    if self.canBeBuild then
        return getText("ContextMenu_Remove")
    end
end

function RemoveCursor:getLBPrompt()
	return nil
end

function RemoveCursor:getRBPrompt()
	return nil
end

local function createCursor(playerIdx)
	local playerObj = getSpecificPlayer(playerIdx)
	local cursor = RemoveCursor:new(playerObj)
	getCell():setDrag(cursor, playerIdx)
end

local function OnFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end

	local menuItem = context:getOptionFromName(getText("ContextMenu_Remove"))
	if menuItem and menuItem.onSelect == ISFarmingMenu.onShovel then
		menuItem.target = playerIdx
		menuItem.onSelect = createCursor
	end
end

Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)