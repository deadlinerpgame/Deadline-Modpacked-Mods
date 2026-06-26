require("WLBaseObject")

---@class WastelandZones.Classes.Zone: WLBaseObject
---@field id string
---@field name string
---@field enabled boolean
---@field lifespan number
---@field enabledAt number
---@field isClientTemporary boolean
---@field plugins table<string, table>
---@field areas WastelandZones.Classes.Area[]
---@field flattenedAreas WastelandZones.Classes.Area[]|nil
---@field events table<string, WastelandZones.Classes.Plugin[]>
---@field bounds {x1:number,y1:number,z1:number,x2:number,y2:number,z2:number}
---@field center {x:number,y:number,z:number}
local Zone = WastelandZones.Classes.Zone or WLBaseObject:derive("WastelandZones.Classes.Zone")
if not WastelandZones.Classes.Zone then
    WastelandZones.Classes.Zone = Zone
end

local Utils = WastelandZones.Utils
local MIN_Z = Utils.MIN_Z
local MAX_Z = Utils.MAX_Z
local hasEntries = Utils.hasEntries
local setOccupied = Utils.setOccupied
local isOccupied = Utils.isOccupied
local occupiedToAreaDataList = Utils.occupiedToAreaDataList
local normalizeInteger = Utils.normalizeInteger
local collectAreaDataTrusted = Utils.collectAreaDataTrusted
local packAndInstantiateAreas = Utils.packAndInstantiateAreas
local instantiateAreas = Utils.instantiateAreas
local buildOccupiedFromAreaData = Utils.buildOccupiedFromTrustedAreas

local function erodeOccupied(occupied, checks)
    local eroded = {}

    for z, zRows in pairs(occupied) do
        for y, yRow in pairs(zRows) do
            for x in pairs(yRow) do
                local keep = true
                for i = 1, #checks do
                    local check = checks[i]
                    if not isOccupied(occupied, x + check.dx, y + check.dy, z) then
                        keep = false
                        break
                    end
                end

                if keep then
                    setOccupied(eroded, x, y, z, true)
                end
            end
        end
    end

    return eroded
end

---@return WastelandZones.Classes.Zone
function Zone:new()
    local o = Zone.parentClass.new(self)
    o.id = getRandomUUID()
    o.name = "Unnamed Zone"
    o.enabled = true
    o.lifespan = 0
    o.enabledAt = WL_Utils.getTimestamp()
    o.isClientTemporary = false
    o.plugins = {}
    o.areas = {}
    o.flattenedAreas = nil
    o.events = {
        onCreated = {},
        onDestroyed = {},
        onRecreated = {},
        onPlayerEnter = {},
        onPlayerExit = {},
        onPlayerInsideTick = {},
        onPlayerInsideOneSecond = {},
        onPlayerInsideTenSeconds = {},
        onPlayerInsideOneMinute = {},
        onServerTick = {},
        onServerZombieBatch = {}
    }

    -- data for convience, not serialized
    o.bounds = { x1 = math.huge, y1 = math.huge, z1 = math.huge, x2 = -math.huge, y2 = -math.huge, z2 = -math.huge }
    o.center = { x = 0, y = 0, z = 0 }
    return o
end

---@param name string|nil
---@param areas WastelandZones.Classes.Area[]|nil @Expected Area objects (for example from zone:getExpandedAreas()).
---@param plugins table<string, table>|nil @Full plugin map keyed by plugin type.
---@note Returns an initialized temporary client-only zone object; does not auto-register to WastelandZones.Zones.
---@return WastelandZones.Classes.Zone
function Zone:temporary(name, areas, plugins)
    local o = self:new()
    o.isClientTemporary = true

    local safeName = tostring(name or "")
    if safeName == "" then
        safeName = "Unnamed Zone"
    end
    o.name = safeName

    -- Expects Area objects (for example from zone:getExpandedAreas()).
    -- Invalid entries are ignored to keep helper usage safe.
    o.areas = {}
    if type(areas) == "table" then
        for i = 1, #areas do
            local area = areas[i]
            if area and area.isPointIn and area.serialize then
                o.areas[#o.areas + 1] = area
            end
        end
    end

    o.plugins = type(plugins) == "table" and plugins or {}
    o:init()
    return o
end

---@param data {id:string|nil,name:string|nil,enabled:boolean|nil,lifespan:number|nil,enabledAt:number|nil,areas:table[]|nil,plugins:table<string,table>|nil}
---@return WastelandZones.Classes.Zone
function Zone:deserialize(data)
    local Plugins = WastelandZones.Plugins
    
    local o = self:new()
    if data.id then
        o.id = data.id
    end
    if data.name then
        o.name = data.name
    end
    if data.enabled ~= nil then
        o.enabled = data.enabled
    end
    if data.lifespan ~= nil then
        o.lifespan = tonumber(data.lifespan) or 0
    end
    if data.enabledAt ~= nil then
        o.enabledAt = tonumber(data.enabledAt) or 0
    end

    for _, areaData in ipairs(data.areas or {}) do
        local area = WastelandZones.Classes.Area:deserialize(areaData)
        table.insert(o.areas, area)
    end

    local rawPlugins = data.plugins or {}
    for type, pluginData in pairs(rawPlugins) do
        local plugin = Plugins:get(type)
        if plugin then
            o.plugins[type] = plugin:deserialize(pluginData)
        else
            print("WastelandZones: Failed to load plugin of type " .. type)
        end
    end

    o:init()
    return o
end

---@return nil
function Zone:init()
    self:calcBounds()
    self.flattenedAreas = nil
    self:setEventHandlers()
end

---@return WastelandZones.Classes.Area[]
function Zone:buildFlattenedAreas()
    local areaDataList = collectAreaDataTrusted(self.areas)
    if #areaDataList == 0 then
        return {}
    end

    local occupied2D = {}
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        for y = area.y1, area.y2 do
            local row = occupied2D[y]
            if not row then
                row = {}
                occupied2D[y] = row
            end

            for x = area.x1, area.x2 do
                row[x] = true
            end
        end
    end

    local flattenedAreaData = {}
    for y, row in pairs(occupied2D) do
        for x in pairs(row) do
            flattenedAreaData[#flattenedAreaData + 1] = {
                x1 = x,
                y1 = y,
                z1 = MIN_Z,
                x2 = x,
                y2 = y,
                z2 = MIN_Z
            }
        end
    end

    return packAndInstantiateAreas(flattenedAreaData)
end

---@return WastelandZones.Classes.Area[]
function Zone:getFlattenedAreas()
    local flattenedAreas = self.flattenedAreas
    if flattenedAreas then
        return flattenedAreas
    end

    flattenedAreas = self:buildFlattenedAreas()
    self.flattenedAreas = flattenedAreas
    return flattenedAreas
end

---@return nil
function Zone:setEventHandlers()
    local Plugins = WastelandZones.Plugins
    
    for t, _ in pairs(self.plugins) do
        local plugin = Plugins:get(t)
        if plugin then
            for eventType, enabled in pairs(plugin.events) do
                if enabled then
                    table.insert(self.events[eventType], plugin)
                end
            end
        end
    end
end

---@return {id:string,name:string,enabled:boolean,lifespan:number,enabledAt:number,areas:table[],plugins:table<string,table>}
function Zone:serialize()
    local Plugins = WastelandZones.Plugins
    local data = {
        id = self.id,
        name = self.name,
        enabled = self.enabled,
        lifespan = self.lifespan,
        enabledAt = self.enabledAt,
        areas = {},
        plugins = {},
    }

    for _, area in ipairs(self.areas) do
        table.insert(data.areas, area:serialize())
    end

    for type, pluginData in pairs(self.plugins) do
        data.plugins[type] = Plugins:get(type):serialize(pluginData)
    end

    return data
end

---@param enabled boolean
---@return nil
function Zone:setEnabled(enabled)
    if enabled then
        self.enabled = true
        self.enabledAt = WL_Utils.getTimestamp()
    else
        self.enabled = false
        self.enabledAt = 0
    end
end

---@param seconds number
---@return nil
function Zone:setLifespan(seconds)
    local lifespan = tonumber(seconds) or 0
    if lifespan < 0 then
        lifespan = 0
    end
    self.lifespan = lifespan
end

---@return nil
function Zone:refreshEnabledAtNow()
    self.enabledAt = WL_Utils.getTimestamp()
end

---@param nowTs number
---@return boolean
function Zone:isExpired(nowTs)
    if not nowTs then
        return false
    end

    return self.enabled == true
        and self.lifespan > 0
        and self.enabledAt > 0
        and nowTs >= self.enabledAt + self.lifespan
end

---@param x number
---@param y number
---@param z number
---@return boolean
function Zone:isPointIn(x, y, z)
    if x < self.bounds.x1 or x > self.bounds.x2
        or y < self.bounds.y1 or y > self.bounds.y2
        or z < self.bounds.z1 or z > self.bounds.z2 then
        return false
    end
    for _, area in ipairs(self.areas) do
        if area:isPointIn(x, y, z) then
            return true
        end
    end
    return false
end

---@param player IsoPlayer
---@return boolean
function Zone:isPlayerIn(player)
    if not player then return false end
    for _, area in ipairs(self.areas) do
        if area:isPlayerIn(player) then
            return true
        end
    end
    return false
end

---@param x number
---@param y number
---@param z number
---@param range number
---@return boolean
function Zone:isPointNear(x, y, z, range)
    if x < self.bounds.x1 - range or x > self.bounds.x2 + range
        or y < self.bounds.y1 - range or y > self.bounds.y2 + range
        or z < self.bounds.z1 - range or z > self.bounds.z2 + range then
        return false
    end
    for _, area in ipairs(self.areas) do
        if area:isPointNear(x, y, z, range) then
            return true
        end
    end
    return false
end

---@param player IsoPlayer
---@param range number
---@return boolean
function Zone:isPlayerNear(player, range)
    if not player then return false end
    local x, y, z = player:getX(), player:getY(), player:getZ()
    return self:isPointNear(x, y, z, range)
end

---@param x number
---@param y number
---@param z number
---@return integer, integer, integer
function Zone:findNearestPointOutsideFrom(x, y, z)
    local nx = math.floor(x)
    local ny = math.floor(y)
    local nz = math.floor(z)

    if not self:isPointIn(nx, ny, nz) then
        return nx, ny, nz
    end

    local bestX, bestY, bestZ = nil, nil, nil
    local bestDistSq = math.huge

    local function tryDirection(startX, startY, startZ, dx, dy, dz)
        local cx, cy, cz = startX, startY, startZ
        while self:isPointIn(cx, cy, cz) do
            cx = cx + dx
            cy = cy + dy
            cz = cz + dz
        end

        local ddx = cx - nx
        local ddy = cy - ny
        local ddz = cz - nz
        local distSq = ddx * ddx + ddy * ddy + ddz * ddz

        if distSq < bestDistSq then
            bestDistSq = distSq
            bestX, bestY, bestZ = cx, cy, cz
        end
    end

    for _, area in ipairs(self.areas) do
        if area:isPointIn(nx, ny, nz) then
            tryDirection(area.x1 - 1, ny, nz, -1, 0, 0)
            tryDirection(area.x2 + 1, ny, nz, 1, 0, 0)
            tryDirection(nx, area.y1 - 1, nz, 0, -1, 0)
            tryDirection(nx, area.y2 + 1, nz, 0, 1, 0)
            tryDirection(nx, ny, area.z1 - 1, 0, 0, -1)
            tryDirection(nx, ny, area.z2 + 1, 0, 0, 1)
        end
    end

    if bestX ~= nil then
        return bestX, bestY, bestZ
    end
    return nx, ny, nz
end

---@param x number
---@param y number
---@param z number
---@return integer, integer, integer
function Zone:findNearestPointInsideFrom(x, y, z)
    local nx = math.floor(x)
    local ny = math.floor(y)
    local nz = math.floor(z)

    if self:isPointIn(nx, ny, nz) then
        return nx, ny, nz
    end

    local bestX, bestY, bestZ = nil, nil, nil
    local bestDistSq = math.huge

    for _, area in ipairs(self.areas) do
        local cx, cy, cz = area:findNearestPointInsideFrom(nx, ny, nz)
        local dx = cx - nx
        local dy = cy - ny
        local dz = cz - nz
        local distSq = dx * dx + dy * dy + dz * dz

        if distSq < bestDistSq then
            bestDistSq = distSq
            bestX, bestY, bestZ = cx, cy, cz
        end
    end

    if bestX ~= nil then
        return bestX, bestY, bestZ
    end
    return nx, ny, nz
end

---@param player IsoPlayer
---@return integer|nil, integer|nil, integer|nil
function Zone:findNearestPointOutsideFromPlayer(player)
    if not player then return nil, nil, nil end
    return self:findNearestPointOutsideFrom(player:getX(), player:getY(), player:getZ())
end

---@param player IsoPlayer
---@return integer|nil, integer|nil, integer|nil
function Zone:findNearestPointInsideFromPlayer(player)
    if not player then return nil, nil, nil end
    return self:findNearestPointInsideFrom(player:getX(), player:getY(), player:getZ())
end

---@return {x1:number,y1:number,z1:number,x2:number,y2:number,z2:number}
function Zone:calcBounds()
    local minX, minY, minZ = math.huge, math.huge, math.huge
    local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

    for _, area in ipairs(self.areas) do
        if area.x1 < minX then minX = area.x1 end
        if area.y1 < minY then minY = area.y1 end
        if area.z1 < minZ then minZ = area.z1 end
        if area.x2 > maxX then maxX = area.x2 end
        if area.y2 > maxY then maxY = area.y2 end
        if area.z2 > maxZ then maxZ = area.z2 end
    end
    local bounds = { x1 = minX, y1 = minY, z1 = minZ, x2 = maxX, y2 = maxY, z2 = maxZ }
    self.bounds = bounds
    self.center = {x = (bounds.x1 + bounds.x2) / 2, y = (bounds.y1 + bounds.y2) / 2, z = (bounds.z1 + bounds.z2) / 2 }
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedAreas(amount)
    local delta = math.floor(tonumber(amount) or 0)
    if delta < 0 then
        return self:getContractedAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local sourceAreas = collectAreaDataTrusted(self.areas)
    local expanded = {}
    for i = 1, #sourceAreas do
        local area = sourceAreas[i]
        expanded[#expanded + 1] = {
            x1 = area.x1 - delta,
            y1 = area.y1 - delta,
            z1 = area.z1,
            x2 = area.x2 + delta,
            y2 = area.y2 + delta,
            z2 = area.z2
        }
    end

    return packAndInstantiateAreas(expanded)
end

---Fast variant of getExpandedAreas that skips area packing.
---Output rectangles may overlap (one per source area), which is harmless for
---proximity/isPointNear consumers. Use this when you do not need a canonical
---packed representation and the saved packing cost matters (e.g. bulkSet).
---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedAreasFast(amount)
    local delta = math.floor(tonumber(amount) or 0)
    if delta < 0 then
        return self:getContractedAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local sourceAreas = collectAreaDataTrusted(self.areas)
    local expanded = {}
    for i = 1, #sourceAreas do
        local area = sourceAreas[i]
        expanded[#expanded + 1] = {
            x1 = area.x1 - delta,
            y1 = area.y1 - delta,
            z1 = area.z1,
            x2 = area.x2 + delta,
            y2 = area.y2 + delta,
            z2 = area.z2
        }
    end

    return instantiateAreas(expanded)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getContractedAreas(amount)
    local delta = math.floor(tonumber(amount) or 0)
    if delta < 0 then
        return self:getExpandedAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)

    local occupied = buildOccupiedFromAreaData(areaDataList)
    local checks = {
        { dx = -1, dy = 0 },
        { dx = 1, dy = 0 },
        { dx = 0, dy = -1 },
        { dx = 0, dy = 1 }
    }

    for _ = 1, delta do
        occupied = erodeOccupied(occupied, checks)
        if not hasEntries(occupied) then
            break
        end
    end

    local contracted = occupiedToAreaDataList(occupied)
    return packAndInstantiateAreas(contracted)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getRaisedTopAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getLoweredTopAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        area.z2 = math.min(MAX_Z, area.z2 + delta)
    end

    return instantiateAreas(areaDataList)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getLoweredTopAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getRaisedTopAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        area.z2 = area.z2 - delta
        if area.z2 < area.z1 then
            area.z2 = area.z1
        end
    end

    return instantiateAreas(areaDataList)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getRaisedBottomAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getLoweredBottomAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        area.z1 = area.z1 + delta
        if area.z1 > area.z2 then
            area.z1 = area.z2
        end
    end

    return instantiateAreas(areaDataList)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getLoweredBottomAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getRaisedBottomAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        area.z1 = math.max(MIN_Z, area.z1 - delta)
    end

    return instantiateAreas(areaDataList)
end

---@param dx number|nil
---@param dy number|nil
---@param dz number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedAreas(dx, dy, dz)
    local moveX = normalizeInteger(dx, 0)
    local moveY = normalizeInteger(dy, 0)
    local moveZ = normalizeInteger(dz, 0)
    if moveX == 0 and moveY == 0 and moveZ == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        local area = areaDataList[i]
        area.x1 = area.x1 + moveX
        area.x2 = area.x2 + moveX
        area.y1 = area.y1 + moveY
        area.y2 = area.y2 + moveY

        if moveZ > 0 then
            local lift = math.min(moveZ, MAX_Z - area.z2)
            area.z1 = area.z1 + lift
            area.z2 = area.z2 + lift
        elseif moveZ < 0 then
            local drop = math.min(-moveZ, area.z1 - MIN_Z)
            area.z1 = area.z1 - drop
            area.z2 = area.z2 - drop
        end
    end

    return instantiateAreas(areaDataList)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedNorthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(0, -delta, 0)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedSouthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(0, delta, 0)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedWestAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(-delta, 0, 0)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedEastAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(delta, 0, 0)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedUpAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(0, 0, delta)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getMovedDownAreas(amount)
    local delta = normalizeInteger(amount, 1)
    return self:getMovedAreas(0, 0, -delta)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedNorthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getContractedNorthAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        areaDataList[i].y1 = areaDataList[i].y1 - delta
    end
    return packAndInstantiateAreas(areaDataList)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedSouthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getContractedSouthAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        areaDataList[i].y2 = areaDataList[i].y2 + delta
    end
    return packAndInstantiateAreas(areaDataList)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedWestAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getContractedWestAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        areaDataList[i].x1 = areaDataList[i].x1 - delta
    end
    return packAndInstantiateAreas(areaDataList)
end

---@param amount number
---@return WastelandZones.Classes.Area[]
function Zone:getExpandedEastAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getContractedEastAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    for i = 1, #areaDataList do
        areaDataList[i].x2 = areaDataList[i].x2 + delta
    end
    return packAndInstantiateAreas(areaDataList)
end

local function contractByDirection(areaDataList, dx, dy, steps)
    local occupied = buildOccupiedFromAreaData(areaDataList)
    local checks = { { dx = dx, dy = dy } }

    for _ = 1, steps do
        occupied = erodeOccupied(occupied, checks)
        if not hasEntries(occupied) then
            break
        end
    end

    return occupiedToAreaDataList(occupied)
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getContractedNorthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getExpandedNorthAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    return packAndInstantiateAreas(contractByDirection(areaDataList, 0, -1, delta))
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getContractedSouthAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getExpandedSouthAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    return packAndInstantiateAreas(contractByDirection(areaDataList, 0, 1, delta))
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getContractedWestAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getExpandedWestAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    return packAndInstantiateAreas(contractByDirection(areaDataList, -1, 0, delta))
end

---@param amount number|nil
---@return WastelandZones.Classes.Area[]
function Zone:getContractedEastAreas(amount)
    local delta = normalizeInteger(amount, 1)
    if delta < 0 then
        return self:getExpandedEastAreas(-delta)
    end
    if delta == 0 then
        return self.areas
    end

    local areaDataList = collectAreaDataTrusted(self.areas)
    return packAndInstantiateAreas(contractByDirection(areaDataList, 1, 0, delta))
end

---@return WastelandZones.Classes.Area[]
function Zone:getLeveledTopAreas()
    local areaDataList = collectAreaDataTrusted(self.areas)
    if #areaDataList == 0 then
        return {}
    end

    local highestTop = -math.huge
    for i = 1, #areaDataList do
        local z2 = areaDataList[i].z2
        if z2 > highestTop then
            highestTop = z2
        end
    end

    for i = 1, #areaDataList do
        areaDataList[i].z2 = highestTop
    end

    return instantiateAreas(areaDataList)
end

---@return WastelandZones.Classes.Area[]
function Zone:getLeveledBottomAreas()
    local areaDataList = collectAreaDataTrusted(self.areas)
    if #areaDataList == 0 then
        return {}
    end

    local lowestBottom = math.huge
    for i = 1, #areaDataList do
        local z1 = areaDataList[i].z1
        if z1 < lowestBottom then
            lowestBottom = z1
        end
    end

    for i = 1, #areaDataList do
        areaDataList[i].z1 = lowestBottom
    end

    return instantiateAreas(areaDataList)
end

---@return WastelandZones.Classes.Area[]
function Zone:getRemovedAllAreas()
    return {}
end

---@return WastelandZones.Classes.Area[]
function Zone:getClearedAreas()
    return self:getRemovedAllAreas()
end

---@return nil
function Zone:onCreated()
    for _, plugin in ipairs(self.events.onCreated) do
        plugin:onCreated(self, self.plugins[plugin.type])
    end
end

---@return nil
function Zone:onDestroyed()
    for _, plugin in ipairs(self.events.onDestroyed) do
        plugin:onDestroyed(self, self.plugins[plugin.type])
    end
end

---@return nil
function Zone:onRecreated(oldZone)
    for _, plugin in ipairs(self.events.onRecreated) do
        plugin:onRecreated(oldZone, self, oldZone.plugins[plugin.type], self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerEnter(player)
    for _, plugin in ipairs(self.events.onPlayerEnter) do
        plugin:onPlayerEnter(self, player, self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerExit(player)
    for _, plugin in ipairs(self.events.onPlayerExit) do
        plugin:onPlayerExit(self, player, self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerInsideTick(player)
    for _, plugin in ipairs(self.events.onPlayerInsideTick) do
        plugin:onPlayerInsideTick(self, player, self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerInsideOneSecond(player)
    for _, plugin in ipairs(self.events.onPlayerInsideOneSecond) do
        plugin:onPlayerInsideOneSecond(self, player, self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerInsideTenSeconds(player)
    for _, plugin in ipairs(self.events.onPlayerInsideTenSeconds) do
        plugin:onPlayerInsideTenSeconds(self, player, self.plugins[plugin.type])
    end
end

---@param player IsoPlayer
function Zone:onPlayerInsideOneMinute(player)
    for _, plugin in ipairs(self.events.onPlayerInsideOneMinute) do
        plugin:onPlayerInsideOneMinute(self, player, self.plugins[plugin.type])
    end
end

---@param runtime table|nil
function Zone:onServerTick(runtime)
    for _, plugin in ipairs(self.events.onServerTick) do
        plugin:onServerTick(self, self.plugins[plugin.type], runtime)
    end
end

---@param zombieBatch IsoZombie[]|table
---@param runtime table|nil
function Zone:onServerZombieBatch(zombieBatch, runtime)
    for _, plugin in ipairs(self.events.onServerZombieBatch) do
        plugin:onServerZombieBatch(self, zombieBatch, self.plugins[plugin.type], runtime)
    end
end

---@param eventType string
---@return boolean
function Zone:needsEvent(eventType)
    return #self.events[eventType] > 0
end
