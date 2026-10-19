-- Left the old code for context
--[[
local function isWorldSink(sink)
    return sink:hasWater() and sink:getProperties():Is(IsoFlagType.waterPiped) and not sink:getUsesExternalWaterSource()
end

local function isPlumbedSink(sink)
    return sink:hasWater() and sink:getProperties():Is(IsoFlagType.waterPiped) and sink:getUsesExternalWaterSource()
end

local original_ISWorldObjectContextMenu_doFillWaterMenu = ISWorldObjectContextMenu.doFillWaterMenu

ISWorldObjectContextMenu.doFillWaterMenu = function(sink, playerNum, context)
        if isWorldSink(sink) and not sink:isTaintedWater() then
            sink:setTaintedWater(true)
            sink:transmitCompleteItemToServer()
        elseif isPlumbedSink(sink) and sink:isTaintedWater() then
            sink:setTaintedWater(false)
            sink:transmitCompleteItemToServer()
        end

    original_ISWorldObjectContextMenu_doFillWaterMenu(sink, playerNum, context)
end
 ]]

require "ISUI/ISWorldObjectContextMenu"

local cachedZoneText
local cleanWaterZones = {}

-- Sandbox format: X,Y,radius;X,Y,radius like 1000,500,50;2000,1000;30 for: free water 50 tiles around 1000,500 and 30 tiles around 2000,1000
local function isInCleanWaterZone(square, zoneText)
    if cachedZoneText ~= zoneText then
        cachedZoneText = zoneText
        cleanWaterZones = {}
        for entry in string.gmatch(zoneText, "[^;]+") do
            local x, y, radius = string.match(entry, "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
            if x then
                radius = tonumber(radius)
                cleanWaterZones[#cleanWaterZones + 1] = {
                    x = tonumber(x), y = tonumber(y), radiusSquared = radius * radius,
                }
            end
        end
    end

    if #cleanWaterZones == 0 then return false end
    local x, y = square:getX(), square:getY()
    for i = 1, #cleanWaterZones do
        local zone = cleanWaterZones[i]
        local dx = x - zone.x
        local dy = y - zone.y
        if dx * dx + dy * dy <= zone.radiusSquared then
            return true
        end
    end
    return false
end

local function refillCleanWater(sink)
    local maximum = sink:getWaterMax()
    if maximum <= 0 then maximum = 100 end
    local needsRefill = sink:getWaterAmount() ~= maximum
    if needsRefill or sink:isTaintedWater() then
        if needsRefill then sink:setWaterAmount(maximum) end
        sink:setTaintedWater(false)
        sink:transmitModData()
    end
end

local originalFetch = ISWorldObjectContextMenu.fetch

ISWorldObjectContextMenu.fetch = function(object, player, doSquare)
    local square = object:getSquare()
    if square and square:isInARoom() then
        local properties = object:getProperties()
        if properties and properties:Is(IsoFlagType.waterPiped) then
            local options = SandboxVars.WastelandBadWater
            if options and isInCleanWaterZone(square, options.CleanWaterZones or "") then
                refillCleanWater(object)
            end
        end
    end

    return originalFetch(object, player, doSquare)
end
