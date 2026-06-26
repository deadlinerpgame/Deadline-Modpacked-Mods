require("WLBaseObject")

---@class WastelandZones.Classes.Area: WLBaseObject
---@field x1 integer
---@field y1 integer
---@field z1 integer
---@field x2 integer
---@field y2 integer
---@field z2 integer
local Area = WastelandZones.Classes.Area or WLBaseObject:derive("WastelandZones.Classes.Area")
if not WastelandZones.Classes.Area then
    WastelandZones.Classes.Area = Area
end

local Utils = WastelandZones.Utils
local MIN_Z = Utils.MIN_Z
local MAX_Z = Utils.MAX_Z
local normalizeInteger = Utils.normalizeInteger

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return WastelandZones.Classes.Area
function Area:new(x1, y1, z1, x2, y2, z2)
    local o = Area.parentClass.new(self)
    o.x1 = normalizeInteger(x1, 0)
    o.y1 = normalizeInteger(y1, 0)
    o.z1 = normalizeInteger(z1, 0)
    o.x2 = normalizeInteger(x2, 0)
    o.y2 = normalizeInteger(y2, 0)
    o.z2 = normalizeInteger(z2, 0)
    return o
end

---@param data number[]
---@return WastelandZones.Classes.Area
function Area:deserialize(data)
    local o = Area.parentClass.new(self)
    o.x1 = normalizeInteger(data[1], 0)
    o.y1 = normalizeInteger(data[2], 0)
    o.z1 = normalizeInteger(data[3], 0)
    o.x2 = normalizeInteger(data[4], 0)
    o.y2 = normalizeInteger(data[5], 0)
    o.z2 = normalizeInteger(data[6], 0)
    return o
end

---@return number[]
function Area:serialize()
    return {
        normalizeInteger(self.x1, 0),
        normalizeInteger(self.y1, 0),
        normalizeInteger(self.z1, 0),
        normalizeInteger(self.x2, 0),
        normalizeInteger(self.y2, 0),
        normalizeInteger(self.z2, 0)
    }
end

---@return WastelandZones.Classes.Area
function Area:raiseTop()
    local z2 = self.z2 + 1
    if z2 > MAX_Z then
        z2 = MAX_Z
    end

    return Area:new(self.x1, self.y1, self.z1, self.x2, self.y2, z2)
end

---@return WastelandZones.Classes.Area
function Area:lowerBottom()
    local z1 = self.z1 - 1
    if z1 < MIN_Z then
        z1 = MIN_Z
    end

    return Area:new(self.x1, self.y1, z1, self.x2, self.y2, self.z2)
end

---@return WastelandZones.Classes.Area
function Area:lowerTop()
    local z2 = self.z2 - 1
    if z2 < self.z1 then
        z2 = self.z1
    end

    return Area:new(self.x1, self.y1, self.z1, self.x2, self.y2, z2)
end

---@return WastelandZones.Classes.Area
function Area:raiseBottom()
    local z1 = self.z1 + 1
    if z1 > self.z2 then
        z1 = self.z2
    end

    return Area:new(self.x1, self.y1, z1, self.x2, self.y2, self.z2)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Area:getExpandedAreas(amount)
    local delta = normalizeInteger(amount, 0)
    if delta < 0 then
        return self:getContractedAreas(-delta)
    end

    return {
        Area:new(
            self.x1 - delta,
            self.y1 - delta,
            self.z1,
            self.x2 + delta,
            self.y2 + delta,
            self.z2
        )
    }
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Area:getContractedAreas(amount)
    local delta = normalizeInteger(amount, 0)
    if delta < 0 then
        return self:getExpandedAreas(-delta)
    end

    local x1 = self.x1 + delta
    local y1 = self.y1 + delta
    local x2 = self.x2 - delta
    local y2 = self.y2 - delta

    if x1 > x2 or y1 > y2 then
        return {}
    end

    return {
        Area:new(x1, y1, self.z1, x2, y2, self.z2)
    }
end

---@param x number
---@param y number
---@param z number
---@return boolean
function Area:isPointIn(x, y, z)
    return x >= self.x1 and x <= self.x2
        and y >= self.y1 and y <= self.y2
        and z >= self.z1 and z <= self.z2
end

---@param player IsoPlayer
---@return boolean
function Area:isPlayerIn(player)
    if not player then return false end
    return self:isPointIn(player:getX(), player:getY(), player:getZ())
end

---@param x number
---@param y number
---@param z number
---@param range number
---@return boolean
function Area:isPointNear(x, y, z, range)
    return x >= self.x1 - range and x <= self.x2 + range
        and y >= self.y1 - range and y <= self.y2 + range
        and z >= self.z1 - range and z <= self.z2 + range
end

---@param player IsoPlayer
---@param range number
---@return boolean
function Area:isPlayerNear(player, range)
    if not player then return false end
    return self:isPointNear(player:getX(), player:getY(), player:getZ(), range)
end

---@param x number
---@param y number
---@param z number
---@return integer, integer, integer
function Area:findNearestPointOutsideFrom(x, y, z)
    local nx = x
    local ny = y
    local nz = z

    if not self:isPointIn(nx, ny, nz) then
        return nx, ny, nz
    end

    local leftDist = nx - self.x1 + 1
    local rightDist = self.x2 - nx + 1
    local topDist = ny - self.y1 + 1
    local bottomDist = self.y2 - ny + 1
    local downDist = nz - self.z1 + 1
    local upDist = self.z2 - nz + 1

    local bestDir = "left"
    local bestDist = leftDist

    if rightDist < bestDist then
        bestDir = "right"
        bestDist = rightDist
    end
    if topDist < bestDist then
        bestDir = "top"
        bestDist = topDist
    end
    if bottomDist < bestDist then
        bestDir = "bottom"
        bestDist = bottomDist
    end
    if downDist < bestDist then
        bestDir = "down"
        bestDist = downDist
    end
    if upDist < bestDist then
        bestDir = "up"
    end

    if bestDir == "left" then
        return self.x1 - 1, ny, nz
    end
    if bestDir == "right" then
        return self.x2 + 1, ny, nz
    end
    if bestDir == "top" then
        return nx, self.y1 - 1, nz
    end
    if bestDir == "bottom" then
        return nx, self.y2 + 1, nz
    end
    if bestDir == "down" then
        return nx, ny, self.z1 - 1
    end
    return nx, ny, self.z2 + 1
end

---@param x number
---@param y number
---@param z number
---@return integer, integer, integer
function Area:findNearestPointInsideFrom(x, y, z)
    local nx = x
    local ny = y
    local nz = z

    if nx < self.x1 then nx = self.x1 end
    if nx > self.x2 then nx = self.x2 end
    if ny < self.y1 then ny = self.y1 end
    if ny > self.y2 then ny = self.y2 end
    if nz < self.z1 then nz = self.z1 end
    if nz > self.z2 then nz = self.z2 end

    return nx, ny, nz
end

---@param player IsoPlayer
---@return integer|nil, integer|nil, integer|nil
function Area:findNearestPointOutsideFromPlayer(player)
    if not player then return nil, nil, nil end
    return self:findNearestPointOutsideFrom(player:getX(), player:getY(), player:getZ())
end

---@param player IsoPlayer
---@return integer|nil, integer|nil, integer|nil
function Area:findNearestPointInsideFromPlayer(player)
    if not player then return nil, nil, nil end
    return self:findNearestPointInsideFrom(player:getX(), player:getY(), player:getZ())
end

---@return integer, integer, integer
function Area:center()
    return normalizeInteger((self.x1 + self.x2) / 2, 0), normalizeInteger((self.y1 + self.y2) / 2, 0), normalizeInteger((self.z1 + self.z2) / 2, 0)
end
