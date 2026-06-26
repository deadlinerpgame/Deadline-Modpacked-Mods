require "BuildingObjects/ISBuildingObject"

WFSprinklerData = WFSprinklerData or {}
WFSprinklerData.waterCursor = nil

WFWaterCursor = ISBuildingObject:derive("WFWaterCursor")

function WFWaterCursor:create(x, y, z, north, sprite)
    self:hideTooltip()
    local plant = CFarmingSystem.instance:getLuaObjectAt(x, y, z)
    if not plant or plant.state ~= "seeded" or plant.waterLvl >= 100 then return nil end
    ISFarmingMenu.walkToPlant(self.character, self.barrel:getSquare())
    local water = WFSprinklerUtilities.getWaterUsedForPlant(self.barrel, plant)
    ISTimedActionQueue.add(WFSprinklerWaterAction:new(self.character, self.barrel, plant, water, math.max(10, water * 2)))
end

function WFWaterCursor:render(x, y, z, square)
    if not WFWaterCursor.floorSprite then
        WFWaterCursor.floorSprite = IsoSprite.new()
        WFWaterCursor.floorSprite:LoadFramesNoDirPageSimple('media/ui/FloorTileCursor.png')
    end
    local hc = getCore():getGoodHighlitedColor()
    if not self:isValid(square) then
        hc = getCore():getBadHighlitedColor()
    end
    self.sq = square
    WFWaterCursor.floorSprite:RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)

    self:renderTooltip()
end

-- Called by IsoCell.setDrag()
function WFWaterCursor:deactivate()
    self:hideTooltip()
end

function WFWaterCursor:hideTooltip()
    if self.tooltip then
        self.tooltip:removeFromUIManager()
        self.tooltip:setVisible(false)
        self.tooltip = nil
    end
end

function WFWaterCursor:renderTooltip()
    if not self.tooltip then
        self.tooltip = ISWorldObjectContextMenu.addToolTip()
        self.tooltip:setVisible(true)
        self.tooltip:addToUIManager()
        self.tooltip.followMouse = not self.joyfocus
        self.tooltip.maxLineWidth = 1000
    else
        local x = self.sq:getX()
        local y = self.sq:getY()
        local z = self.sq:getZ()
        local bx = self.barrel:getSquare():getX()
        local by = self.barrel:getSquare():getY()
        local bz = self.barrel:getSquare():getZ()
        if z ~= bz or not WFSprinklerUtilities.isSquareInRange(x, y, bx, by, 3) then
            self.tooltip.description = "Out of range."
        else
            local plant = CFarmingSystem.instance:getLuaObjectAt(x, y, z)
            if plant and plant.state == "seeded" then
                if plant.waterLvl < 100 then
                    local water = WFSprinklerUtilities.getWaterUsedForPlant(self.barrel, plant)
                    self.tooltip.description = "Water " .. getText("Farming_" .. plant.typeOfSeed) .. " ("..water.." units)"
                else
                    self.tooltip.description = "Plant is already watered."
                end
            else
                self.tooltip.description = "Nothing to water here."
            end
        end
    end
end

function WFWaterCursor.IsVisible()
    return WFSprinklerData.waterCursor and getCell():getDrag(0) == WFSprinklerData.waterCursor
end

function WFWaterCursor:isValid(square)
    local sx = square:getX()
    local sy = square:getY()
    local sz = square:getZ()
    local bx = self.barrel:getSquare():getX()
    local by = self.barrel:getSquare():getY()
    local bz = self.barrel:getSquare():getZ()
    return sz == bz and WFSprinklerUtilities.isSquareInRange(sx, sy, bx, by, 3) and WFSprinklerUtilities.isWaterablePlant(sx, sy, sz)
end

function WFWaterCursor:new(character, barrel)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o.character = character
    o.player = character:getPlayerNum()
    o.barrel = barrel
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.skipWalk2 = true
    return o
end
