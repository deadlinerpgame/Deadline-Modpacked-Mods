local function dupTable(tbl)
    local newTbl = {}
    for k, v in pairs(tbl) do
        newTbl[k] = v
    end
    return newTbl
end

local function calculateSquaredDistance(x1, y1, x2, y2)
    return (x2 - x1)^2 + (y2 - y1)^2
end

local function findNearestNeighborIndex(current, all)
    local minDistance = math.huge
    local nearestNeighborIndex = nil

    for i, obj in ipairs(all) do
        local distance = calculateSquaredDistance(current.x, current.y, obj.x, obj.y)
        if distance < minDistance then
            minDistance = distance
            nearestNeighborIndex = i
        end
    end

    return nearestNeighborIndex
end

---Uses the nearest neighbor algorithm to solve the TSP
---@param all table<number, {x: number, y: number}>
---@return table<number, {x: number, y: number}>
local function TSP_NearestNeighbor(all)
    all = dupTable(all)
    local toVisit = {}

    -- Start from the first object in the list
    local current = table.remove(all, 1)
    table.insert(toVisit, current)

    -- Loop until all objects are visited
    while #all > 0 do
        local nearestNeighborIndex = findNearestNeighborIndex(current, all)
        local nextObject = table.remove(all, nearestNeighborIndex)
        table.insert(toVisit, nextObject)
        current = nextObject
    end

    return toVisit
end

return {
    NearestNeighbor = TSP_NearestNeighbor
}