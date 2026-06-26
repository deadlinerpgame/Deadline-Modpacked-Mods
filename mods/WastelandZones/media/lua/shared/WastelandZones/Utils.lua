---@class WastelandZones.Utils
local Utils = WastelandZones.Utils

Utils.MIN_Z = 0
Utils.MAX_Z = 8

---@param value any
---@param fallback number|nil
---@return integer
function Utils.floorNumber(value, fallback)
    return math.floor(tonumber(value) or fallback or 0)
end

---@param value any
---@param fallback number|nil
---@return integer
function Utils.normalizeInteger(value, fallback)
    return Utils.floorNumber(value, fallback)
end

---@param value any
---@param minValue number
---@param maxValue number
---@param fallback number|nil
---@return number
function Utils.clampNumber(value, minValue, maxValue, fallback)
    local n = tonumber(value)
    if n == nil then
        n = tonumber(fallback) or minValue
    end

    if n < minValue then
        return minValue
    end
    if n > maxValue then
        return maxValue
    end
    return n
end

---@param value any
---@return integer
function Utils.clampZ(value)
    return Utils.floorNumber(Utils.clampNumber(value, Utils.MIN_Z, Utils.MAX_Z, Utils.MIN_Z), Utils.MIN_Z)
end

---@param area table|nil
---@param minZ number|nil
---@param maxZ number|nil
---@return {x1:integer,y1:integer,z1:integer,x2:integer,y2:integer,z2:integer}
function Utils.normalizeAreaData(area, minZ, maxZ)
    local zMin = Utils.floorNumber(minZ, Utils.MIN_Z)
    local zMax = Utils.floorNumber(maxZ, Utils.MAX_Z)

    if zMin > zMax then
        zMin, zMax = zMax, zMin
    end

    local x1 = Utils.floorNumber(area and area.x1, 0)
    local y1 = Utils.floorNumber(area and area.y1, 0)
    local z1 = Utils.floorNumber(area and area.z1, 0)
    local x2 = Utils.floorNumber(area and area.x2, 0)
    local y2 = Utils.floorNumber(area and area.y2, 0)
    local z2 = Utils.floorNumber(area and area.z2, 0)

    z1 = Utils.floorNumber(Utils.clampNumber(z1, zMin, zMax, zMin), zMin)
    z2 = Utils.floorNumber(Utils.clampNumber(z2, zMin, zMax, zMin), zMin)

    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    if z1 > z2 then z1, z2 = z2, z1 end

    return {
        x1 = x1,
        y1 = y1,
        z1 = z1,
        x2 = x2,
        y2 = y2,
        z2 = z2
    }
end

---@param x1 number
---@param y1 number
---@param z1 number
---@param x2 number
---@param y2 number
---@param z2 number
---@return WastelandZones.Classes.Area
function Utils.createArea(x1, y1, z1, x2, y2, z2)
    return WastelandZones.Classes.Area:new(x1, y1, z1, x2, y2, z2)
end

---@param area table
---@param minZ number|nil
---@param maxZ number|nil
---@return WastelandZones.Classes.Area|table
function Utils.createAreaFromData(area, minZ, maxZ)
    local normalized = Utils.normalizeAreaData(area, minZ, maxZ)
    return Utils.createArea(normalized.x1, normalized.y1, normalized.z1, normalized.x2, normalized.y2, normalized.z2)
end

---@param tbl table
---@return boolean
function Utils.hasEntries(tbl)
    for _ in pairs(tbl) do
        return true
    end
    return false
end

---@param tbl table
---@param key any
---@return table
function Utils.ensure(tbl, key)
    local child = tbl[key]
    if not child then
        child = {}
        tbl[key] = child
    end
    return child
end

---@param occupied table
---@param x integer
---@param y integer
---@param z integer
---@param value boolean
function Utils.setOccupied(occupied, x, y, z, value)
    if value then
        local zRows = Utils.ensure(occupied, z)
        local yRow = Utils.ensure(zRows, y)
        yRow[x] = true
        return
    end

    local zRows = occupied[z]
    if not zRows then
        return
    end

    local yRow = zRows[y]
    if not yRow then
        return
    end

    yRow[x] = nil
    if not Utils.hasEntries(yRow) then
        zRows[y] = nil
    end

    if not Utils.hasEntries(zRows) then
        occupied[z] = nil
    end
end

---@param occupied table
---@param x integer
---@param y integer
---@param z integer
---@return boolean
function Utils.isOccupied(occupied, x, y, z)
    local zRows = occupied[z]
    if not zRows then
        return false
    end

    local yRow = zRows[y]
    if not yRow then
        return false
    end

    return yRow[x] == true
end

---@param occupied table
---@param area table
---@param value boolean
---@param minZ number|nil
---@param maxZ number|nil
---@param assumeNormalized boolean|nil
function Utils.applyAreaToOccupied(occupied, area, value, minZ, maxZ, assumeNormalized)
    local target = area
    if not assumeNormalized then
        target = Utils.normalizeAreaData(area, minZ, maxZ)
    end

    for z = target.z1, target.z2 do
        for y = target.y1, target.y2 do
            for x = target.x1, target.x2 do
                Utils.setOccupied(occupied, x, y, z, value)
            end
        end
    end
end

---@param occupied table
---@param area table
---@param value boolean
function Utils.applyTrustedAreaToOccupied(occupied, area, value)
    for z = area.z1, area.z2 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                Utils.setOccupied(occupied, x, y, z, value)
            end
        end
    end
end

---@param areas table[]
---@param minZ number|nil
---@param maxZ number|nil
---@param assumeNormalized boolean|nil
---@return table
function Utils.buildOccupiedFromAreas(areas, minZ, maxZ, assumeNormalized)
    local occupied = {}
    if assumeNormalized then
        for i = 1, #areas do
            Utils.applyTrustedAreaToOccupied(occupied, areas[i], true)
        end
        return occupied
    end

    for i = 1, #areas do
        Utils.applyAreaToOccupied(occupied, areas[i], true, minZ, maxZ, false)
    end
    return occupied
end

---@param areas table[]
---@return table
function Utils.buildOccupiedFromTrustedAreas(areas)
    local occupied = {}
    for i = 1, #areas do
        Utils.applyTrustedAreaToOccupied(occupied, areas[i], true)
    end
    return occupied
end

---@param occupied table
---@return table[]
function Utils.occupiedToAreaDataList(occupied)
    local out = {}
    for z, zRows in pairs(occupied) do
        for y, yRow in pairs(zRows) do
            for x in pairs(yRow) do
                out[#out + 1] = {
                    x1 = x,
                    y1 = y,
                    z1 = z,
                    x2 = x,
                    y2 = y,
                    z2 = z
                }
            end
        end
    end

    table.sort(out, function(a, b)
        if a.z1 ~= b.z1 then return a.z1 < b.z1 end
        if a.y1 ~= b.y1 then return a.y1 < b.y1 end
        return a.x1 < b.x1
    end)

    return out
end

---@param areas table[]
---@param minZ number|nil
---@param maxZ number|nil
---@return table[]
function Utils.collectNormalizedAreaData(areas, minZ, maxZ)
    local out = {}
    for i = 1, #areas do
        out[#out + 1] = Utils.normalizeAreaData(areas[i], minZ, maxZ)
    end
    return out
end

---@param areas table[]
---@return table[]
function Utils.collectAreaDataTrusted(areas)
    local out = {}
    for i = 1, #areas do
        local area = areas[i]
        out[#out + 1] = {
            x1 = area.x1,
            y1 = area.y1,
            z1 = area.z1,
            x2 = area.x2,
            y2 = area.y2,
            z2 = area.z2
        }
    end
    return out
end

---@param areaDataList table[]
---@return table[]
function Utils.packAreaData(areaDataList)
    -- Shortcut for single area packing
    if #areaDataList == 1 then
        return areaDataList
    end
    return Utils.AreaCubePacking.packAreas(areaDataList)
end

---@param areaDataList table[]
---@return WastelandZones.Classes.Area[]
function Utils.instantiateAreas(areaDataList)
    local areas = {}
    for i = 1, #areaDataList do
        local areaData = areaDataList[i]
        areas[#areas + 1] = Utils.createArea(areaData.x1, areaData.y1, areaData.z1, areaData.x2, areaData.y2, areaData.z2)
    end
    return areas
end

---@param areaDataList table[]
---@return WastelandZones.Classes.Area[]
function Utils.packAndInstantiateAreas(areaDataList)
    return Utils.instantiateAreas(Utils.packAreaData(areaDataList))
end

---@param ax number
---@param ay number
---@param az number
---@param bx number
---@param by number
---@param bz number
---@return boolean
function Utils.lessPoint(ax, ay, az, bx, by, bz)
    if ax ~= bx then return ax < bx end
    if ay ~= by then return ay < by end
    return az < bz
end

---@param x number
---@param y number
---@param z number
---@return string
function Utils.makePointKey(x, y, z)
    return tostring(x) .. ":" .. tostring(y) .. ":" .. tostring(z)
end

---@param ax number
---@param ay number
---@param az number
---@param bx number
---@param by number
---@param bz number
---@return string
function Utils.makeEdgeKey(ax, ay, az, bx, by, bz)
    return Utils.makePointKey(ax, ay, az) .. "|" .. Utils.makePointKey(bx, by, bz)
end
