---@class WastelandZones.Utils
local Utils = WastelandZones.Utils

---@class WastelandZones.Utils.IndoorAreaSearcher
local IndoorAreaSearcher = Utils.IndoorAreaSearcher or {}
Utils.IndoorAreaSearcher = IndoorAreaSearcher

local MIN_Z = Utils.MIN_Z
local MAX_Z = Utils.MAX_Z
local normalizeInteger = Utils.normalizeInteger
local makePointKey = Utils.makePointKey
local setOccupied = Utils.setOccupied

local AreaCubePacking = Utils.AreaCubePacking

local NEIGHBOR_OFFSETS = {
    { 1, 0, 0 },
    { -1, 0, 0 },
    { 0, 1, 0 },
    { 0, -1, 0 },
    { 0, 0, 1 },
    { 0, 0, -1 }
}

---@param square IsoGridSquare|nil
---@return boolean
local function isIndoorSquare(square)
    return square ~= nil and not square:isOutside()
end

---@param x integer
---@param y integer
---@param z integer
---@return WastelandZones.Classes.Area[]
function IndoorAreaSearcher.searchFromPoint(x, y, z)
    local cell = getCell()
    if not cell then
        return {}
    end

    local startX = normalizeInteger(x, 0)
    local startY = normalizeInteger(y, 0)
    local startZ = normalizeInteger(z, MIN_Z)

    if startZ < MIN_Z then startZ = MIN_Z end
    if startZ > MAX_Z then startZ = MAX_Z end

    local startSquare = cell:getGridSquare(startX, startY, startZ)
    if not isIndoorSquare(startSquare) then
        return {}
    end

    local queue = {
        { x = startX, y = startY, z = startZ }
    }
    local queued = {
        [makePointKey(startX, startY, startZ)] = true
    }
    local visited = {}
    local occupied = {}
    local head = 1

    while head <= #queue do
        local point = queue[head]
        head = head + 1

        local pointKey = makePointKey(point.x, point.y, point.z)
        if not visited[pointKey] then
            visited[pointKey] = true

            local square = cell:getGridSquare(point.x, point.y, point.z)
            if isIndoorSquare(square) then
                setOccupied(occupied, point.x, point.y, point.z, true)

                for i = 1, #NEIGHBOR_OFFSETS do
                    local offset = NEIGHBOR_OFFSETS[i]
                    local nx = point.x + offset[1]
                    local ny = point.y + offset[2]
                    local nz = point.z + offset[3]

                    if nz >= MIN_Z and nz <= MAX_Z then
                        local neighborKey = makePointKey(nx, ny, nz)
                        if not queued[neighborKey] and not visited[neighborKey] then
                            queue[#queue + 1] = { x = nx, y = ny, z = nz }
                            queued[neighborKey] = true
                        end
                    end
                end
            end
        end
    end

    return AreaCubePacking.packOccupied(occupied)
end

---@param square IsoGridSquare|nil
---@return WastelandZones.Classes.Area[]
function IndoorAreaSearcher.searchFromSquare(square)
    if not square then
        return {}
    end

    return IndoorAreaSearcher.searchFromPoint(square:getX(), square:getY(), square:getZ())
end

---@param player IsoPlayer|nil
---@return WastelandZones.Classes.Area[]
function IndoorAreaSearcher.searchFromPlayer(player)
    local targetPlayer = player or getPlayer()
    if not targetPlayer then
        return {}
    end

    return IndoorAreaSearcher.searchFromSquare(targetPlayer:getSquare())
end

return IndoorAreaSearcher
