require "ISUI/ISUIElement"

WastelandZones.Utils = WastelandZones.Utils or {}

local AreaOutliner = WastelandZones.Utils.AreaOutliner or {}
WastelandZones.Utils.AreaOutliner = AreaOutliner

local Utils = WastelandZones.Utils

---@class WastelandZones.Utils.AreaOutliner.RenderElement: ISUIElement
---@field owner WastelandZones.Utils.AreaOutliner
local RenderElement = ISUIElement:derive("WastelandZones.Utils.AreaOutliner.RenderElement")
local DEFAULT_MAX_RANGE = 50
local DEFAULT_RECLIP_MARGIN = 25
local DEFAULT_COLOR = { r = 1, g = 1, b = 1, a = 1 }
local DEFAULT_TILE_LINES_COLOR = { r = 1, g = 1, b = 1, a = 0.2 }
local DEFAULT_Z_DIFF_COLORS = {
    { r = 0.85, g = 0.85, b = 0.85, a = 1 },
    { r = 0.73, g = 0.73, b = 0.73, a = 1 },
    { r = 0.61, g = 0.61, b = 0.61, a = 1 },
    { r = 0.50, g = 0.50, b = 0.50, a = 1 },
    { r = 0.40, g = 0.40, b = 0.40, a = 1 },
    { r = 0.31, g = 0.31, b = 0.31, a = 1 }
}
local AUTO_Z_DIFF_DARKEN_FACTORS = { 1.00, 0.6, 0.4, 0.2, 0.1, 0.1 }

local createArea = Utils.createArea
local lessPoint = Utils.lessPoint
local makeEdgeKey = Utils.makeEdgeKey

local function addOutputEdge(out, x1, y1, z1, x2, y2, z2)
    if not lessPoint(x1, y1, z1, x2, y2, z2) then
        x1, x2 = x2, x1
        y1, y2 = y2, y1
        z1, z2 = z2, z1
    end

    out[#out + 1] = {
        x1 = x1,
        y1 = y1,
        z1 = z1,
        x2 = x2,
        y2 = y2,
        z2 = z2
    }
end

local function buildCuboidEdges(area)
    local out = {}
    local x1 = area.x1
    local y1 = area.y1
    local z1 = area.z1
    local x2 = area.x2 + 1
    local y2 = area.y2 + 1
    local z2 = area.z2 + 1

    -- X axis edges
    addOutputEdge(out, x1, y1, z1, x2, y1, z1)
    addOutputEdge(out, x1, y2, z1, x2, y2, z1)
    addOutputEdge(out, x1, y1, z2, x2, y1, z2)
    addOutputEdge(out, x1, y2, z2, x2, y2, z2)

    -- Y axis edges
    addOutputEdge(out, x1, y1, z1, x1, y2, z1)
    addOutputEdge(out, x2, y1, z1, x2, y2, z1)
    addOutputEdge(out, x1, y1, z2, x1, y2, z2)
    addOutputEdge(out, x2, y1, z2, x2, y2, z2)

    -- Z axis edges
    addOutputEdge(out, x1, y1, z1, x1, y1, z2)
    addOutputEdge(out, x2, y1, z1, x2, y1, z2)
    addOutputEdge(out, x1, y2, z1, x1, y2, z2)
    addOutputEdge(out, x2, y2, z1, x2, y2, z2)

    return out
end

local function addEdge(edgeMap, ax, ay, az, bx, by, bz, normal)
    if not lessPoint(ax, ay, az, bx, by, bz) then
        ax, bx = bx, ax
        ay, by = by, ay
        az, bz = bz, az
    end

    local edgeKey = makeEdgeKey(ax, ay, az, bx, by, bz)
    local edge = edgeMap[edgeKey]
    if not edge then
        edge = {
            x1 = ax,
            y1 = ay,
            z1 = az,
            x2 = bx,
            y2 = by,
            z2 = bz,
            normals = {}
        }
        edgeMap[edgeKey] = edge
    end

    edge.normals[normal] = true
end

local function addFace(edgeMap, normal, x1, y1, z1, x2, y2, z2, x3, y3, z3, x4, y4, z4)
    addEdge(edgeMap, x1, y1, z1, x2, y2, z2, normal)
    addEdge(edgeMap, x2, y2, z2, x3, y3, z3, normal)
    addEdge(edgeMap, x3, y3, z3, x4, y4, z4, normal)
    addEdge(edgeMap, x4, y4, z4, x1, y1, z1, normal)
end

local function canDrawInScreenRect(sx1, sy1, sx2, sy2, sL, sT, sW, sH)
    local sR = sL + sW
    local sB = sT + sH

    if sx1 < sL and sx2 < sL then return false end
    if sx1 > sR and sx2 > sR then return false end
    if sy1 < sT and sy2 < sT then return false end
    if sy1 > sB and sy2 > sB then return false end
    return true
end

local function clampColorComponent(value, defaultValue)
    local n = tonumber(value)
    if n == nil then
        n = defaultValue
    end

    if n < 0 then
        return 0
    end

    if n > 1 then
        return 1
    end

    return n
end

local function copyColor(color)
    return {
        r = color.r,
        g = color.g,
        b = color.b,
        a = color.a
    }
end

local function normalizeColorEntry(entry)
    if type(entry) ~= "table" then
        return nil
    end

    local r = entry.r
    if r == nil then r = entry[1] end

    local g = entry.g
    if g == nil then g = entry[2] end

    local b = entry.b
    if b == nil then b = entry[3] end

    local a = entry.a
    if a == nil then a = entry[4] end

    if r == nil or g == nil or b == nil then
        return nil
    end

    return {
        r = clampColorComponent(r, 1),
        g = clampColorComponent(g, 1),
        b = clampColorComponent(b, 1),
        a = clampColorComponent(a, 1)
    }
end

local function buildDarkenedColorTable(r, g, b, a)
    local out = {}
    for i = 1, #AUTO_Z_DIFF_DARKEN_FACTORS do
        local factor = AUTO_Z_DIFF_DARKEN_FACTORS[i]
        out[#out + 1] = {
            r = clampColorComponent(r * factor, 1),
            g = clampColorComponent(g * factor, 1),
            b = clampColorComponent(b * factor, 1),
            a = clampColorComponent(a, 1)
        }
    end

    return out
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param owner WastelandZones.Utils.AreaOutliner
---@return WastelandZones.Utils.AreaOutliner.RenderElement
function RenderElement:new(x, y, width, height, owner)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.owner = owner
    return o
end

function RenderElement:render()
    if self.owner then
        self.owner:render(self)
    end
end

---@class WastelandZones.Utils.AreaOutliner
---@field color {r:number,g:number,b:number,a:number}
---@field enabled boolean
---@field showAllZLevels boolean
---@field floorGridEnabled boolean
---@field tileLinesColor {r:number,g:number,b:number,a:number}
---@field tileLinesColorCustom boolean
---@field zDiffColors table[]|nil
---@field zDiffColorsCustom boolean
---@field areas table[]
---@field edges table[]
---@field maxRange integer
---@field reclipMargin integer
---@field clipBounds table|nil
---@field clipCenterX integer|nil
---@field clipCenterY integer|nil
---@field clipCenterZ integer|nil
---@field currentZSliceEdgesCache table<number, table[]>
---@field element WastelandZones.Utils.AreaOutliner.RenderElement|nil
---@return WastelandZones.Utils.AreaOutliner
function AreaOutliner:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.color = copyColor(DEFAULT_COLOR)
    o.enabled = true
    o.showAllZLevels = true
    o.floorGridEnabled = true
    o.tileLinesColor = copyColor(DEFAULT_TILE_LINES_COLOR)
    o.tileLinesColorCustom = false
    o.zDiffColors = nil
    o.zDiffColorsCustom = false
    o.areas = {}
    o.edges = {}
    o.maxRange = DEFAULT_MAX_RANGE
    o.reclipMargin = DEFAULT_RECLIP_MARGIN
    o.clipBounds = nil
    o.clipCenterX = nil
    o.clipCenterY = nil
    o.clipCenterZ = nil
    o.currentZSliceEdgesCache = {}

    o.element = RenderElement:new(0, 0, 0, 0, o)
    o.element:initialise()
    o.element:addToUIManager()

    return o
end

---@param r number
---@param g number
---@param b number
---@param a number
function AreaOutliner:setColor(r, g, b, a)
    self.color.r = clampColorComponent(r, DEFAULT_COLOR.r)
    self.color.g = clampColorComponent(g, DEFAULT_COLOR.g)
    self.color.b = clampColorComponent(b, DEFAULT_COLOR.b)
    self.color.a = clampColorComponent(a, DEFAULT_COLOR.a)

    if self.zDiffColorsCustom == false then
        self.zDiffColors = buildDarkenedColorTable(self.color.r, self.color.g, self.color.b, 1)
    end

    if self.tileLinesColorCustom == false then
        -- Desaturate the color for tile lines by default, since they can be visually noisy.
        self.tileLinesColor.r = self.color.r * 0.2 + 0.8
        self.tileLinesColor.g = self.color.g * 0.2 + 0.8
        self.tileLinesColor.b = self.color.b * 0.2 + 0.8
        self.tileLinesColor.a = DEFAULT_TILE_LINES_COLOR.a
    end
end

---@param enabled boolean
function AreaOutliner:setEnabled(enabled)
    self.enabled = enabled and true or false
end

---@param enabled boolean
function AreaOutliner:setShowAllZLevels(enabled)
    local value = enabled and true or false
    if self.showAllZLevels == value then
        return
    end

    self.showAllZLevels = value
    self.edges = {}
    self.clipBounds = nil
    self.clipCenterX = nil
    self.clipCenterY = nil
    self.clipCenterZ = nil
    self.currentZSliceEdgesCache = {}
end

---@param enabled boolean
function AreaOutliner:setFloorGridEnabled(enabled)
    self.floorGridEnabled = enabled and true or false
end

---@param r number
---@param g number
---@param b number
---@param a number
function AreaOutliner:setTileLinesColor(r, g, b, a)
    self.tileLinesColor.r = clampColorComponent(r, DEFAULT_TILE_LINES_COLOR.r)
    self.tileLinesColor.g = clampColorComponent(g, DEFAULT_TILE_LINES_COLOR.g)
    self.tileLinesColor.b = clampColorComponent(b, DEFAULT_TILE_LINES_COLOR.b)
    self.tileLinesColor.a = clampColorComponent(a, DEFAULT_TILE_LINES_COLOR.a)
    self.tileLinesColorCustom = true
end

---@deprecated Use AreaOutliner:setTileLinesColor() instead.
---@param r number
---@param g number
---@param b number
---@param a number
function AreaOutliner:setZOutlineColor(r, g, b, a)
    self:setTileLinesColor(r, g, b, a)
end

---@param tbl table[]|nil
function AreaOutliner:setZDiffColors(tbl)
    if type(tbl) ~= "table" then
        self.zDiffColors = nil
        self.zDiffColorsCustom = false
        return
    end

    local out = {}
    for i = 1, #tbl do
        local color = normalizeColorEntry(tbl[i])
        if color then
            out[#out + 1] = color
        end
    end

    if #out == 0 then
        self.zDiffColors = nil
        self.zDiffColorsCustom = false
        return
    end

    self.zDiffColors = out
    self.zDiffColorsCustom = true
end

---@param range number
function AreaOutliner:setMaxRange(range)
    local value = math.floor(tonumber(range) or DEFAULT_MAX_RANGE)
    if value < 0 then
        value = 0
    end
    self.maxRange = value
    self.clipBounds = nil
    self.clipCenterX = nil
    self.clipCenterY = nil
    self.clipCenterZ = nil
    self.currentZSliceEdgesCache = {}
end

---@param margin number
function AreaOutliner:setReclipMargin(margin)
    local value = math.floor(tonumber(margin) or DEFAULT_RECLIP_MARGIN)
    if value < 0 then
        value = 0
    end
    self.reclipMargin = value
end

---@param centerX number|nil
---@param centerY number|nil
---@param centerZ number|nil
function AreaOutliner:_recull(centerX, centerY, centerZ)
    self.edges, self.clipBounds = self:_buildEdges(self.areas, centerX, centerY, centerZ)
    self.clipCenterX = centerX
    self.clipCenterY = centerY
    self.clipCenterZ = centerZ
    self.currentZSliceEdgesCache = {}
end

---@return table[]
function AreaOutliner:_getZDiffColorsForRender()
    if self.zDiffColors and #self.zDiffColors > 0 then
        return self.zDiffColors
    end

    return DEFAULT_Z_DIFF_COLORS
end

---@param z1 integer
---@param z2 integer
---@param playerZ integer
---@return {r:number,g:number,b:number,a:number}
function AreaOutliner:_getZDiffColorForEndpoints(z1, z2, playerZ)
    if z1 == playerZ and z2 == playerZ then
        return self.color
    elseif z1 == playerZ and z2 == playerZ + 1 then
        return self.color
    elseif z1 == playerZ + 1 and z2 == playerZ + 1 then
        return self.color
    end
    local d1 = math.abs(z1 - playerZ)
    local d2 = math.abs(z2 - playerZ)
    local band = math.max(d1, d2)

    local colors = self:_getZDiffColorsForRender()
    local index = band + 1
    if index < 1 then
        index = 1
    end
    if index > #colors then
        index = #colors
    end

    return colors[index]
end

---@param z integer
---@return table[]
function AreaOutliner:_buildCurrentZFaceSliceEdges(z)
    local bounds = self.clipBounds
    if not bounds then
        return {}
    end

    if z < bounds.minZ or z > bounds.maxZ then
        return {}
    end

    local clippedAreas = self:_clipAreasToPlayerRange(self.areas, bounds.cx, bounds.cy, bounds.cz)
    if #clippedAreas == 0 then
        return {}
    end

    local occupied = self:_buildOccupiedLookup(clippedAreas)
    local zRows = occupied[z]
    if not zRows then
        return {}
    end

    local out = {}
    for y, row in pairs(zRows) do
        for x, isOccupied in pairs(row) do
            if isOccupied == true then
                local xp = x + 1
                local yp = y + 1

                -- Every tile on this Z contributes all four tile-boundary lines.
                -- Shared borders are merged by _mergeCollinearEdges() below.
                addOutputEdge(out, x, y, z, xp, y, z)
                addOutputEdge(out, xp, y, z, xp, yp, z)
                addOutputEdge(out, xp, yp, z, x, yp, z)
                addOutputEdge(out, x, yp, z, x, y, z)
            end
        end
    end

    return self:_mergeCollinearEdges(out)
end

---@param z integer
---@return table[]
function AreaOutliner:_getCurrentZSliceEdges(z)
    local cached = self.currentZSliceEdgesCache[z]
    if cached then
        return cached
    end

    local built = self:_buildCurrentZFaceSliceEdges(z)
    self.currentZSliceEdgesCache[z] = built
    return built
end

---@param areas table[]
---@param centerX number|nil
---@param centerY number|nil
---@param centerZ number|nil
---@return table[], table|nil
function AreaOutliner:_clipAreasToPlayerRange(areas, centerX, centerY, centerZ)
    if not areas or #areas == 0 then
        return {}, nil
    end

    local px = centerX
    local py = centerY
    local pz = centerZ
    if px == nil or py == nil or pz == nil then
        local player = getPlayer()
        if not player then
            return {}, nil
        end

        px = math.floor(player:getX())
        py = math.floor(player:getY())
        pz = math.floor(player:getZ())
    end

    local range = math.floor(tonumber(self.maxRange) or DEFAULT_MAX_RANGE)
    if range < 0 then
        range = 0
    end

    local minX = px - range
    local maxX = px + range
    local minY = py - range
    local maxY = py + range
    local minZ = pz - range
    local maxZ = pz + range

    if self.showAllZLevels == false then
        minZ = pz
        maxZ = pz
    end

    local clipped = {}
    for i = 1, #areas do
        local area = areas[i]
        local x1 = math.max(area.x1, minX)
        local y1 = math.max(area.y1, minY)
        local z1 = math.max(area.z1, minZ)
        local x2 = math.min(area.x2, maxX)
        local y2 = math.min(area.y2, maxY)
        local z2 = math.min(area.z2, maxZ)

        if x1 <= x2 and y1 <= y2 and z1 <= z2 then
            clipped[#clipped + 1] = createArea(x1, y1, z1, x2, y2, z2)
        end
    end

    return clipped, {
        minX = minX,
        maxX = maxX,
        minY = minY,
        maxY = maxY,
        minZ = minZ,
        maxZ = maxZ,
        cx = px,
        cy = py,
        cz = pz
    }
end

---@param areas table[]
---@return table
function AreaOutliner:_buildOccupiedLookup(areas)
    local occupied = {}

    for i = 1, #areas do
        local area = areas[i]
        for z = area.z1, area.z2 do
            local zRows = occupied[z]
            if not zRows then
                zRows = {}
                occupied[z] = zRows
            end

            for y = area.y1, area.y2 do
                local row = zRows[y]
                if not row then
                    row = {}
                    zRows[y] = row
                end

                for x = area.x1, area.x2 do
                    row[x] = true
                end
            end
        end
    end

    return occupied
end

---@param occupied table
---@param x integer
---@param y integer
---@param z integer
---@return boolean
function AreaOutliner:_hasOccupied(occupied, x, y, z)
    local zRows = occupied[z]
    if not zRows then
        return false
    end

    local row = zRows[y]
    if not row then
        return false
    end

    return row[x] == true
end

---@param edges table[]
---@return table[]
function AreaOutliner:_mergeCollinearEdges(edges)
    local groups = {}

    for i = 1, #edges do
        local edge = edges[i]
        local axis = nil
        local fixedA = nil
        local fixedB = nil
        local startCoord = nil
        local endCoord = nil

        if edge.y1 == edge.y2 and edge.z1 == edge.z2 and edge.x1 ~= edge.x2 then
            axis = "x"
            fixedA = edge.y1
            fixedB = edge.z1
            startCoord = edge.x1
            endCoord = edge.x2
        elseif edge.x1 == edge.x2 and edge.z1 == edge.z2 and edge.y1 ~= edge.y2 then
            axis = "y"
            fixedA = edge.x1
            fixedB = edge.z1
            startCoord = edge.y1
            endCoord = edge.y2
        elseif edge.x1 == edge.x2 and edge.y1 == edge.y2 and edge.z1 ~= edge.z2 then
            axis = "z"
            fixedA = edge.x1
            fixedB = edge.y1
            startCoord = edge.z1
            endCoord = edge.z2
        end

        if axis then
            local key = axis .. ":" .. tostring(fixedA) .. ":" .. tostring(fixedB)
            local group = groups[key]
            if not group then
                group = {}
                groups[key] = group
            end

            group[#group + 1] = {
                axis = axis,
                fixedA = fixedA,
                fixedB = fixedB,
                s = startCoord,
                e = endCoord
            }
        else
            local key = "other:" .. tostring(i)
            groups[key] = {
                {
                    axis = "other",
                    x1 = edge.x1,
                    y1 = edge.y1,
                    z1 = edge.z1,
                    x2 = edge.x2,
                    y2 = edge.y2,
                    z2 = edge.z2
                }
            }
        end
    end

    local merged = {}
    for _, group in pairs(groups) do
        if group[1].axis == "other" then
            for j = 1, #group do
                local e = group[j]
                addOutputEdge(merged, e.x1, e.y1, e.z1, e.x2, e.y2, e.z2)
            end
        else
            table.sort(group, function(a, b)
                if a.s ~= b.s then
                    return a.s < b.s
                end
                return a.e < b.e
            end)

            local current = {
                axis = group[1].axis,
                fixedA = group[1].fixedA,
                fixedB = group[1].fixedB,
                s = group[1].s,
                e = group[1].e
            }

            for j = 2, #group do
                local seg = group[j]
                if seg.s <= current.e then
                    if seg.e > current.e then
                        current.e = seg.e
                    end
                else
                    if current.axis == "x" then
                        addOutputEdge(merged, current.s, current.fixedA, current.fixedB, current.e, current.fixedA, current.fixedB)
                    elseif current.axis == "y" then
                        addOutputEdge(merged, current.fixedA, current.s, current.fixedB, current.fixedA, current.e, current.fixedB)
                    else
                        addOutputEdge(merged, current.fixedA, current.fixedB, current.s, current.fixedA, current.fixedB, current.e)
                    end

                    current.s = seg.s
                    current.e = seg.e
                end
            end

            if current.axis == "x" then
                addOutputEdge(merged, current.s, current.fixedA, current.fixedB, current.e, current.fixedA, current.fixedB)
            elseif current.axis == "y" then
                addOutputEdge(merged, current.fixedA, current.s, current.fixedB, current.fixedA, current.e, current.fixedB)
            else
                addOutputEdge(merged, current.fixedA, current.fixedB, current.s, current.fixedA, current.fixedB, current.e)
            end
        end
    end

    return merged
end

---@param areas table[]
---@param centerX number|nil
---@param centerY number|nil
---@param centerZ number|nil
---@return table[], table|nil
function AreaOutliner:_buildEdges(areas, centerX, centerY, centerZ)
    local clippedAreas, clipBounds = self:_clipAreasToPlayerRange(areas, centerX, centerY, centerZ)
    if #clippedAreas == 0 then
        return {}, clipBounds
    end

    if #clippedAreas == 1 then
        return buildCuboidEdges(clippedAreas[1]), clipBounds
    end

    local edgeMap = {}
    local occupied = self:_buildOccupiedLookup(clippedAreas)

    for i = 1, #clippedAreas do
        local area = clippedAreas[i]
        for z = area.z1, area.z2 do
            local zp = z + 1
            for y = area.y1, area.y2 do
                local yp = y + 1
                for x = area.x1, area.x2 do
                    local xp = x + 1

                    if self:_hasOccupied(occupied, x - 1, y, z) == false then
                        addFace(edgeMap, "xn",
                            x, y, z,
                            x, yp, z,
                            x, yp, zp,
                            x, y, zp
                        )
                    end

                    if self:_hasOccupied(occupied, xp, y, z) == false then
                        addFace(edgeMap, "xp",
                            xp, y, z,
                            xp, y, zp,
                            xp, yp, zp,
                            xp, yp, z
                        )
                    end

                    if self:_hasOccupied(occupied, x, y - 1, z) == false then
                        addFace(edgeMap, "yn",
                            x, y, z,
                            x, y, zp,
                            xp, y, zp,
                            xp, y, z
                        )
                    end

                    if self:_hasOccupied(occupied, x, yp, z) == false then
                        addFace(edgeMap, "yp",
                            x, yp, z,
                            xp, yp, z,
                            xp, yp, zp,
                            x, yp, zp
                        )
                    end

                    if self:_hasOccupied(occupied, x, y, z - 1) == false then
                        addFace(edgeMap, "zn",
                            x, y, z,
                            xp, y, z,
                            xp, yp, z,
                            x, yp, z
                        )
                    end

                    if self:_hasOccupied(occupied, x, y, zp) == false then
                        addFace(edgeMap, "zp",
                            x, y, zp,
                            x, yp, zp,
                            xp, yp, zp,
                            xp, y, zp
                        )
                    end
                end
            end
        end
    end

    local out = {}
    for _, edge in pairs(edgeMap) do
        local normalCount = 0
        for _ in pairs(edge.normals) do
            normalCount = normalCount + 1
            if normalCount > 1 then
                break
            end
        end

        if normalCount > 1 then
            out[#out + 1] = {
                x1 = edge.x1,
                y1 = edge.y1,
                z1 = edge.z1,
                x2 = edge.x2,
                y2 = edge.y2,
                z2 = edge.z2
            }
        end
    end

    local merged = self:_mergeCollinearEdges(out)

    table.sort(merged, function(a, b)
        if a.z1 ~= b.z1 then return a.z1 < b.z1 end
        if a.y1 ~= b.y1 then return a.y1 < b.y1 end
        if a.x1 ~= b.x1 then return a.x1 < b.x1 end
        if a.z2 ~= b.z2 then return a.z2 < b.z2 end
        if a.y2 ~= b.y2 then return a.y2 < b.y2 end
        return a.x2 < b.x2
    end)

    return merged, clipBounds
end

---@param px integer
---@param py integer
---@param pz integer
---@return boolean
function AreaOutliner:_shouldReclipAtPosition(px, py, pz)
    if not self.areas or #self.areas == 0 then
        return false
    end

    local bounds = self.clipBounds
    if not bounds then
        return true
    end

    local margin = math.floor(tonumber(self.reclipMargin) or DEFAULT_RECLIP_MARGIN)
    if margin < 0 then
        margin = 0
    end

    local range = math.floor(tonumber(self.maxRange) or DEFAULT_MAX_RANGE)
    if range < 0 then
        range = 0
    end

    if margin > range then
        margin = range
    end

    local innerMinX = bounds.minX + margin
    local innerMaxX = bounds.maxX - margin
    local innerMinY = bounds.minY + margin
    local innerMaxY = bounds.maxY - margin
    local innerMinZ = bounds.minZ + margin
    local innerMaxZ = bounds.maxZ - margin

    local hasInnerX = innerMinX < innerMaxX
    local hasInnerY = innerMinY < innerMaxY
    local hasInnerZ = innerMinZ < innerMaxZ

    if hasInnerX and (px <= innerMinX or px >= innerMaxX) then
        return true
    end

    if hasInnerY and (py <= innerMinY or py >= innerMaxY) then
        return true
    end

    if hasInnerZ and (pz <= innerMinZ or pz >= innerMaxZ) then
        return true
    end

    if px <= bounds.minX or px >= bounds.maxX
    or py <= bounds.minY or py >= bounds.maxY
    or pz < bounds.minZ or pz > bounds.maxZ then
        return true
    end

    return false
end

---@param areas table[]
function AreaOutliner:setAreas(areas)
    self.areas = areas or {}
    self.edges = {}
    self.clipBounds = nil
    self.clipCenterX = nil
    self.clipCenterY = nil
    self.clipCenterZ = nil
    self.currentZSliceEdgesCache = {}
end

---@param element ISUIElement
function AreaOutliner:render(element)
    if self.enabled == false then
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    if self:_shouldReclipAtPosition(px, py, pz) then
        self:_recull(px, py, pz)
    end

    local playerNum = player:getPlayerNum()
    local sL = getPlayerScreenLeft(playerNum)
    local sT = getPlayerScreenTop(playerNum)
    local sW = getPlayerScreenWidth(playerNum)
    local sH = getPlayerScreenHeight(playerNum)

    local baseAlpha = self.color.a
    for i = 1, #self.edges do
        local edge = self.edges[i]
        if edge.x1 == edge.x2 and edge.y1 == edge.y2 and edge.z1 ~= edge.z2 then
            local zStart = edge.z1
            local zEnd = edge.z2
            if zStart > zEnd then
                zStart, zEnd = zEnd, zStart
            end

            local runStart = nil
            local runEnd = nil
            local runColor = nil

            local function flushRun()
                if runStart == nil or runEnd == nil or runColor == nil then
                    return
                end

                local segmentAlpha = baseAlpha * runColor.a
                if segmentAlpha > 0 then
                    local sx1 = math.floor(isoToScreenX(playerNum, edge.x1, edge.y1, runStart))
                    local sy1 = math.floor(isoToScreenY(playerNum, edge.x1, edge.y1, runStart))
                    local sx2 = math.floor(isoToScreenX(playerNum, edge.x2, edge.y2, runEnd))
                    local sy2 = math.floor(isoToScreenY(playerNum, edge.x2, edge.y2, runEnd))

                    if sx1 and sy1 and sx2 and sy2
                    and canDrawInScreenRect(sx1, sy1, sx2, sy2, sL, sT, sW, sH) then
                        element:drawLine2(sx1, sy1, sx2, sy2, segmentAlpha, runColor.r, runColor.g, runColor.b)
                        element:drawLine2(sx2, sy2, sx1, sy1, segmentAlpha, runColor.r, runColor.g, runColor.b)
                    end
                end
            end

            for z = zStart, zEnd - 1 do
                local zDiffColor = self:_getZDiffColorForEndpoints(z, z + 1, pz)

                if runColor == nil then
                    runStart = z
                    runEnd = z + 1
                    runColor = zDiffColor
                elseif zDiffColor == runColor then
                    runEnd = z + 1
                else
                    flushRun()
                    runStart = z
                    runEnd = z + 1
                    runColor = zDiffColor
                end
            end

            flushRun()
        else
            local zDiffColor = self:_getZDiffColorForEndpoints(edge.z1, edge.z2, pz)
            local edgeAlpha = baseAlpha * zDiffColor.a

            if edgeAlpha > 0 then
                local sx1 = math.floor(isoToScreenX(playerNum, edge.x1, edge.y1, edge.z1))
                local sy1 = math.floor(isoToScreenY(playerNum, edge.x1, edge.y1, edge.z1))
                local sx2 = math.floor(isoToScreenX(playerNum, edge.x2, edge.y2, edge.z2))
                local sy2 = math.floor(isoToScreenY(playerNum, edge.x2, edge.y2, edge.z2))

                if sx1 and sy1 and sx2 and sy2
                and canDrawInScreenRect(sx1, sy1, sx2, sy2, sL, sT, sW, sH) then
                    element:drawLine2(sx1, sy1, sx2, sy2, edgeAlpha, zDiffColor.r, zDiffColor.g, zDiffColor.b)
                    element:drawLine2(sx2, sy2, sx1, sy1, edgeAlpha, zDiffColor.r, zDiffColor.g, zDiffColor.b)
                end
            end
        end
    end

    if self.floorGridEnabled then
        local sliceEdges = self:_getCurrentZSliceEdges(pz)
        if #sliceEdges > 0 then
            local tileLines = self.tileLinesColor
            local tileLinesAlpha = baseAlpha * tileLines.a

            if tileLinesAlpha > 0 then
                for i = 1, #sliceEdges do
                    local edge = sliceEdges[i]
                    local sx1 = math.floor(isoToScreenX(playerNum, edge.x1, edge.y1, edge.z1))
                    local sy1 = math.floor(isoToScreenY(playerNum, edge.x1, edge.y1, edge.z1))
                    local sx2 = math.floor(isoToScreenX(playerNum, edge.x2, edge.y2, edge.z2))
                    local sy2 = math.floor(isoToScreenY(playerNum, edge.x2, edge.y2, edge.z2))

                    if sx1 and sy1 and sx2 and sy2
                    and canDrawInScreenRect(sx1, sy1, sx2, sy2, sL, sT, sW, sH) then
                        element:drawLine2(sx1, sy1, sx2, sy2, tileLinesAlpha, tileLines.r, tileLines.g, tileLines.b)
                        element:drawLine2(sx2, sy2, sx1, sy1, tileLinesAlpha, tileLines.r, tileLines.g, tileLines.b)
                    end
                end
            end
        end
    end
end

function AreaOutliner:cleanup()
    if self.element then
        self.element.owner = nil
        self.element:removeFromUIManager()
        self.element = nil
    end

    self.edges = {}
    self.areas = {}
    self.clipBounds = nil
    self.clipCenterX = nil
    self.clipCenterY = nil
    self.clipCenterZ = nil
    self.currentZSliceEdgesCache = {}
end
