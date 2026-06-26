---@class WastelandZones.Utils
local Utils = WastelandZones.Utils

---@class WastelandZones.Utils.AreaCubePacking
local AreaCubePacking = Utils.AreaCubePacking or {}
Utils.AreaCubePacking = AreaCubePacking

local hasEntries = Utils.hasEntries
local setOccupied = Utils.setOccupied
local createArea = Utils.createArea

local function applyTrustedArea(occupied, area, value)
    for z = area.z1, area.z2 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                setOccupied(occupied, x, y, z, value)
            end
        end
    end
end

local function applyBoundaryArea(occupied, area, value)
    local normalized = Utils.normalizeAreaData(area, Utils.MIN_Z, Utils.MAX_Z)
    applyTrustedArea(occupied, normalized, value)
end

local function findSeed(rows)
    local seedY = nil
    local seedX = nil

    for y, row in pairs(rows) do
        for x in pairs(row) do
            if seedY == nil or y < seedY or (y == seedY and x < seedX) then
                seedY = y
                seedX = x
            end
        end
    end

    return seedX, seedY
end

local function rowHasRange(row, x1, x2)
    if not row then
        return false
    end

    for x = x1, x2 do
        if not row[x] then
            return false
        end
    end

    return true
end

local function canExpandDown(rows, x1, x2, y)
    local row = rows[y]
    return rowHasRange(row, x1, x2)
end

local function canExpandRight(rows, y1, y2, x)
    for y = y1, y2 do
        local row = rows[y]
        if not row or not row[x] then
            return false
        end
    end

    return true
end

local function findLargestSquare(rows, x1, y1)
    local seedRow = rows[y1]
    local maxWidth = 1
    while seedRow and seedRow[x1 + maxWidth] do
        maxWidth = maxWidth + 1
    end

    local maxHeight = 1
    while rows[y1 + maxHeight] and rows[y1 + maxHeight][x1] do
        maxHeight = maxHeight + 1
    end

    local maxSize = maxWidth
    if maxHeight < maxSize then
        maxSize = maxHeight
    end

    for size = maxSize, 1, -1 do
        local x2 = x1 + size - 1
        local y2 = y1 + size - 1
        local full = true

        for y = y1, y2 do
            if not rowHasRange(rows[y], x1, x2) then
                full = false
                break
            end
        end

        if full then
            return x2, y2
        end
    end

    return x1, y1
end

local function packLayer(rows, z)
    local packed = {}

    while true do
        local x1, y1 = findSeed(rows)
        if x1 == nil then
            break
        end

        local x2, y2 = findLargestSquare(rows, x1, y1)

        while true do
            local nextX = x2 + 1
            local nextY = y2 + 1
            local expandRight = canExpandRight(rows, y1, y2, nextX)
            local expandDown = canExpandDown(rows, x1, x2, nextY)

            if not expandRight and not expandDown then
                break
            end

            if expandRight and expandDown then
                local width = x2 - x1 + 1
                local height = y2 - y1 + 1
                local rightDiff = math.abs((width + 1) - height)
                local downDiff = math.abs(width - (height + 1))

                if rightDiff <= downDiff then
                    x2 = nextX
                else
                    y2 = nextY
                end
            elseif expandRight then
                x2 = nextX
            else
                y2 = nextY
            end
        end

        packed[#packed + 1] = {
            x1 = x1,
            y1 = y1,
            z1 = z,
            x2 = x2,
            y2 = y2,
            z2 = z
        }

        for y = y1, y2 do
            local row = rows[y]
            if row then
                for x = x1, x2 do
                    row[x] = nil
                end
                if not hasEntries(row) then
                    rows[y] = nil
                end
            end
        end
    end

    return packed
end

---@param occupied table
---@return table[]
function AreaCubePacking.packOccupied(occupied)
    local flatRects = {}

    for z, zRows in pairs(occupied) do
        local working = {}
        for y, row in pairs(zRows) do
            local newRow = {}
            for x in pairs(row) do
                newRow[x] = true
            end
            if hasEntries(newRow) then
                working[y] = newRow
            end
        end

        if hasEntries(working) then
            local layerRects = packLayer(working, z)
            for i = 1, #layerRects do
                flatRects[#flatRects + 1] = layerRects[i]
            end
        end
    end

    table.sort(flatRects, function(a, b)
        if a.z1 ~= b.z1 then return a.z1 < b.z1 end
        if a.y1 ~= b.y1 then return a.y1 < b.y1 end
        if a.x1 ~= b.x1 then return a.x1 < b.x1 end
        if a.y2 ~= b.y2 then return a.y2 < b.y2 end
        return a.x2 < b.x2
    end)

    local merged = {}
    local openByXY = {}

    for i = 1, #flatRects do
        local rect = flatRects[i]
        local key = table.concat({ rect.x1, rect.y1, rect.x2, rect.y2 }, ":")
        local open = openByXY[key]

        if open and (open.z2 + 1) == rect.z1 then
            open.z2 = rect.z1
        else
            local area = createArea(rect.x1, rect.y1, rect.z1, rect.x2, rect.y2, rect.z2)
            merged[#merged + 1] = area
            openByXY[key] = area
        end
    end

    table.sort(merged, function(a, b)
        if a.z1 ~= b.z1 then return a.z1 < b.z1 end
        if a.y1 ~= b.y1 then return a.y1 < b.y1 end
        if a.x1 ~= b.x1 then return a.x1 < b.x1 end
        if a.z2 ~= b.z2 then return a.z2 < b.z2 end
        if a.y2 ~= b.y2 then return a.y2 < b.y2 end
        return a.x2 < b.x2
    end)

    return merged
end

---@param areas table[]
---@return table[]
function AreaCubePacking.packAreas(areas)
    local occupied = {}
    for i = 1, #areas do
        applyTrustedArea(occupied, areas[i], true)
    end
    return AreaCubePacking.packOccupied(occupied)
end

---@param areas table[]
---@return table[]
function AreaCubePacking.packAreasBoundary(areas)
    local occupied = {}
    for i = 1, #areas do
        applyBoundaryArea(occupied, areas[i], true)
    end
    return AreaCubePacking.packOccupied(occupied)
end

---@param areas table[]
---@param operation 'add'|'remove'|string
---@param area table
---@return table[]
function AreaCubePacking.apply(areas, operation, area)
    local occupied = {}

    for i = 1, #areas do
        applyTrustedArea(occupied, areas[i], true)
    end

    if operation == "remove" then
        applyTrustedArea(occupied, area, false)
    else
        applyTrustedArea(occupied, area, true)
    end

    return AreaCubePacking.packOccupied(occupied)
end

---@param areas table[]
---@param operation 'add'|'remove'|string
---@param area table
---@return table[]
function AreaCubePacking.applyBoundary(areas, operation, area)
    local occupied = {}

    for i = 1, #areas do
        applyBoundaryArea(occupied, areas[i], true)
    end

    if operation == "remove" then
        applyBoundaryArea(occupied, area, false)
    else
        applyBoundaryArea(occupied, area, true)
    end

    return AreaCubePacking.packOccupied(occupied)
end
