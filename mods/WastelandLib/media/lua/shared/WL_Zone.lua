---
--- WL_Zone.lua
--- Superclass for zone types to derive from.
---
--- Zones are cubes with an X, Y and Z location. We usually call them to check if a player is inside one, has recently
--- entered or left one, or has clicked inside of one.
---
--- 17/10/2023
---

require "WLBaseObject"

--- @class WL_Zone
WL_Zone = WLBaseObject:derive("WL_Zone")

WL_Zone.allZones = {}

--- Creates a zone from a table of keys to avoid coordinate mix ups.
--- See WL_Zone:toCoordinatesTable() which can be used for saving a zone's coordinate data.
---@param zoneCoordinates table of 6 coordinates defining the zone
---@return table a new WL_Zone based on the coordinates
function WL_Zone.createFromTable(zoneCoordinates)
    return WL_Zone:new(zoneCoordinates.startX, zoneCoordinates.startY, zoneCoordinates.startZ, zoneCoordinates.endX,
            zoneCoordinates.endY, zoneCoordinates.endZ)
end

function WL_Zone:new(x1, y1, z1, x2, y2, z2)  -- constructor of instance
    local o = WL_Zone.parentClass.new(self)  -- call inherited constructor
    o.mapType = "Other"
    o.mapColor = {1.0, 0.3, 0.3}
    o.mapDisabled = false
    o.minX = math.floor(math.min(x1, x2))
    o.minY = math.floor(math.min(y1, y2))
    o.minZ = math.floor(math.min(z1, z2))
    o.maxX = math.floor(math.max(x1, x2))
    o.maxY = math.floor(math.max(y1, y2))
    o.maxZ = math.floor(math.max(z1, z2))
    table.insert(WL_Zone.allZones, o)
    return o
end

function WL_Zone:delete()
    for i, zone in ipairs(WL_Zone.allZones) do
        if zone == self then
            table.remove(WL_Zone.allZones, i)
            return
        end
    end
end

function WL_Zone:getMapType()
    return self.mapType
end

function WL_Zone:getMapColor()
    return self.mapColor
end

function WL_Zone:getMapName()
    return "Zone from " .. self.minX .. "," .. self.minY .. "," .. self.minZ .. " to " .. self.maxX .. "," .. self.maxY .. "," .. self.maxZ
end

--- To be called when a player enters the zone bounds
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @see WL_TriggerZones
function WL_Zone:onPlayerEnteredZone(player) end

--- To be called when a player exits the zone bounds
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @see WL_TriggerZones
function WL_Zone:onPlayerExitedZone(player) end

--- To be called when a player has remained inside the zone bounds for a minute, and each minute after
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @param player IsoPlayer remaining
--- @param minutesPassed number of minutes that the player has been inside the zone
--- @see WL_TriggerZones
function WL_Zone:onPlayerStayedForMinute(player, minutesPassed) end

function WL_Zone:getCenterPoint()
    local midX = math.floor((self.minX + self.maxX) / 2)
    local midY = math.floor((self.minY + self.maxY) / 2)
    local midZ = math.floor((self.minZ + self.maxZ) / 2)
    return { x = midX, y = midY, z = midZ }
end

function WL_Zone:getSize()
    return (self.maxX - self.minX) * (self.maxY - self.minY) * (self.maxZ - self.minZ)
end

function WL_Zone:isInZone(x, y, z)
    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)
    if x >= self.minX and x <= (self.maxX) and y >= self.minY and y <= (self.maxY) and z >= (self.minZ) and z <= (self.maxZ) then
        return true
    end
    return false
end

function WL_Zone:isNearZone(x, y, z, range)
    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)
    if x >= self.minX-range and x <= (self.maxX+range) and y >= self.minY-range and y <= (self.maxY+range) and z >= (self.minZ-range) and z <= (self.maxZ+range) then
        return true
    end
    return false
end

function WL_Zone:isPlayerInZone(player)
    return self:isInZone(player:getX(), player:getY(), player:getZ())
end

function WL_Zone:isPlayerNearZone(player, range)
    return self:isNearZone(player:getX(), player:getY(), player:getZ(), range)
end

-- Given a point inside the zone, return the closest point outside the zone
-- This does not actually check if the Z level is inside the zone or not, only uses it for the return values
function WL_Zone:getClosestPointOutsideZone(x, y, z)
    -- if you are already outside the zone, you are already at the closest point to you outside the zone
    if not self:isInZone(x, y, z) then
        return x, y, z
    end
    local cX = x
    local cY = y
    if x-self.minX < self.maxX-x then
        cX = self.minX - 1
    else
        cX = self.maxX + 1
    end
    if y-self.minY < self.maxY-y then
        cY = self.minY - 1
    else
        cY = self.maxY + 1
    end
    if math.abs(x-cX) < math.abs(y-cY) then
        return cX, y, z
    else
        return x, cY, z
    end
end

-- Given a point outside the zone, return the closest point inside the zone
-- This does not actually check if the Z level is inside the zone or not, only uses it for the return values
function WL_Zone:getClosestPointInsideZone(x, y, z)
    -- if you are already inside the zone, you are already at the closest point to you inside the zone
    if self:isInZone(x, y, z) then
        return x, y, z
    end
    local cX = x
    local cY = y
    if cX < self.minX then
        cX = self.minX -- Coming from negative side, use .00
    elseif cX > self.maxX then
        cX = self.maxX + 0.99 -- Coming from positive side, use .99
    end
    if cY < self.minY then
        cY = self.minY -- Coming from negative side, use .00
    elseif cY > self.maxY then
        cY = self.maxY + 0.99 -- Coming from positive side, use .99
    end
    return cX, cY, z
end

function WL_Zone:setArea(x1, y1, x2, y2, z1, z2)
    self.minX = math.floor(math.min(x1, x2))
    self.minY = math.floor(math.min(y1, y2))
    self.maxX = math.floor(math.max(x1, x2))
    self.maxY = math.floor(math.max(y1, y2))
    self.minZ = math.floor(math.min(z1, z2))
    self.maxZ = math.floor(math.max(z1, z2))
end

--- Similar to setArea but takes the data from a table with named parameters for ease of use.
--- See WL_Zone:toCoordinatesTable() for the counterpart
function WL_Zone:setAreaFromTable(zoneCoordinates)
    self.minX = math.floor(zoneCoordinates.startX)
    self.minY = math.floor(zoneCoordinates.startY)
    self.maxX = math.floor(zoneCoordinates.endX)
    self.maxY = math.floor(zoneCoordinates.endY)
    self.minZ = math.floor(zoneCoordinates.startZ)
    self.maxZ = math.floor(zoneCoordinates.endZ)
end

--- Converts to a table of key to coordinate numbers. This is the counterpart of WL_Zone:setAreaFromTable
---@return table a simple serialised table of coordinates for a zone
function WL_Zone:toCoordinatesTable()
    return {
        startX = self.minX,
        startY = self.minY,
        startZ = self.minZ,
        endX = self.maxX,
        endY = self.maxY,
        endZ = self.maxZ,
    }
end