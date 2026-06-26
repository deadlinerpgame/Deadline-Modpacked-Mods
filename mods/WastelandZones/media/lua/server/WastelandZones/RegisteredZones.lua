require("WLBaseObject")

---@class WastelandZones.Classes.RegisteredZones: WLBaseObject
---@field zones table<string, WastelandZones.Classes.Zone>
---@field cellSize integer
---@field spatialIndex table<number, table<number, table<string, WastelandZones.Classes.Zone>>>
---@field largeZones table<string, WastelandZones.Classes.Zone>
---@field zoneCells table<string, {x:integer,y:integer}[]>
---@field saveDirty boolean
---@field saveDebounceTicks integer
---@field saveTicksRemaining integer
---@field expiryTickInterval integer
---@field expiryTicksRemaining integer
---@field expiringZoneIds string[]
---@field expiringZoneIndexById table<string, integer>
local RegisteredZones = WastelandZones.Classes.RegisteredZones or WLBaseObject:derive("WastelandZones.Classes.RegisteredZones")
if not WastelandZones.Classes.RegisteredZones then
    WastelandZones.Classes.RegisteredZones = RegisteredZones
end

local DEFAULT_CELL_SIZE = 64
local MAX_INDEXED_CELLS = 25
local DEFAULT_EXPIRY_TICK_INTERVAL = 60

---@return WastelandZones.Classes.RegisteredZones
function RegisteredZones:new()
    local o = RegisteredZones.parentClass.new(self)
    o.zones = {}
    o.cellSize = DEFAULT_CELL_SIZE
    o.spatialIndex = {}
    o.largeZones = {}
    o.zoneCells = {}
    o.saveDirty = false
    o.saveDebounceTicks = 120
    o.saveTicksRemaining = -1
    o.expiryTickInterval = DEFAULT_EXPIRY_TICK_INTERVAL
    o.expiryTicksRemaining = 0
    o.expiringZoneIds = {}
    o.expiringZoneIndexById = {}

    if isServer() then
        Events.OnTick.Add(function() o:_onTickServer() end)
    end

    return o
end

---@param zone WastelandZones.Classes.Zone|nil
---@return boolean
function RegisteredZones:_shouldTrackZoneForExpiry(zone)
    if not zone then return false end
    return zone.enabled == true
        and zone.lifespan > 0
        and zone.enabledAt > 0
end

---@param id string
---@return nil
function RegisteredZones:_addExpiringZone(id)
    if self.expiringZoneIndexById[id] then
        return
    end

    self.expiringZoneIds[#self.expiringZoneIds + 1] = id
    self.expiringZoneIndexById[id] = #self.expiringZoneIds
end

---@param id string
---@return nil
function RegisteredZones:_removeExpiringZone(id)
    local removeIndex = self.expiringZoneIndexById[id]
    if not removeIndex then
        return
    end

    local ids = self.expiringZoneIds
    local lastIndex = #ids
    local lastId = ids[lastIndex]

    ids[removeIndex] = lastId
    ids[lastIndex] = nil
    self.expiringZoneIndexById[id] = nil

    if lastId and lastId ~= id then
        self.expiringZoneIndexById[lastId] = removeIndex
    end
end

---@param zone WastelandZones.Classes.Zone|nil
---@return nil
function RegisteredZones:_syncExpiringZoneTracking(zone)
    if not zone or not zone.id then return end

    if self:_shouldTrackZoneForExpiry(zone) then
        self:_addExpiringZone(zone.id)
    else
        self:_removeExpiringZone(zone.id)
    end
end

---@return nil
function RegisteredZones:_processExpiringZones()
    local ids = self.expiringZoneIds
    if #ids == 0 then
    end

    local nowTs = WL_Utils.getTimestamp()
    local Zone = WastelandZones.Classes.Zone

    for i = #ids, 1, -1 do
        local zoneId = ids[i]
        local zone = self.zones[zoneId]

        if not zone then
            self:_removeExpiringZone(zoneId)
        elseif not self:_shouldTrackZoneForExpiry(zone) then
            self:_removeExpiringZone(zoneId)
        else
            local isExpired = zone:isExpired(nowTs)

            if isExpired then
                local zoneData = zone:serialize()
                zoneData.enabled = false
                zoneData.enabledAt = 0
                local newZone = Zone:deserialize(zoneData)
                self:set(newZone)
                WastelandZones.Network:transmitZone(newZone)
            end
        end
    end
end

---@return nil
function RegisteredZones:_onTickServer()
    if self.expiryTicksRemaining > 0 then
        self.expiryTicksRemaining = self.expiryTicksRemaining - 1
    else
        self.expiryTicksRemaining = self.expiryTickInterval
        self:_processExpiringZones()
    end

    if self.saveDirty then
        if self.saveTicksRemaining > 0 then
            self.saveTicksRemaining = self.saveTicksRemaining - 1
            return
        end

        self:flushSave()
    end
end

---@return nil
function RegisteredZones:flushSave()
    if isClient() then
        print("WastelandZones.RegisteredZones:flushSave is server only")
        return
    end

    if not self.saveDirty then
        return
    end

    self.saveDirty = false
    self.saveTicksRemaining = -1

    local data = self:getAllSerialized()
    WastelandZones.Storage:save(data)
end

---@param value number
---@return integer
function RegisteredZones:_getCellCoord(value)
    return math.floor(value / self.cellSize)
end

---@param cellX integer
---@param cellY integer
---@param create boolean
---@return table<string, WastelandZones.Classes.Zone>|nil
function RegisteredZones:_getCellBucket(cellX, cellY, create)
    local xBuckets = self.spatialIndex[cellX]
    if not xBuckets then
        if not create then return nil end
        xBuckets = {}
        self.spatialIndex[cellX] = xBuckets
    end

    local bucket = xBuckets[cellY]
    if not bucket and create then
        bucket = {}
        xBuckets[cellY] = bucket
    end

    return bucket
end

---@param bounds {x1:number,y1:number,z1:number,x2:number,y2:number,z2:number}|nil
---@return boolean
function RegisteredZones:_isBoundsIndexable(bounds)
    if not bounds then return false end
    if bounds.x1 == math.huge or bounds.y1 == math.huge or bounds.z1 == math.huge then return false end
    if bounds.x2 == -math.huge or bounds.y2 == -math.huge or bounds.z2 == -math.huge then return false end
    if bounds.x1 > bounds.x2 or bounds.y1 > bounds.y2 or bounds.z1 > bounds.z2 then return false end
    return true
end

---@param map table|nil
---@return boolean
function RegisteredZones:_isEmptyMap(map)
    if not map then return true end
    for _, _ in pairs(map) do
        return false
    end
    return true
end

---@param cellX integer
---@param cellY integer
function RegisteredZones:_clearCellBucket(cellX, cellY)
    local xBuckets = self.spatialIndex[cellX]
    if not xBuckets then return end

    local bucket = xBuckets[cellY]
    if bucket and self:_isEmptyMap(bucket) then
        xBuckets[cellY] = nil
    end

    if self:_isEmptyMap(xBuckets) then
        self.spatialIndex[cellX] = nil
    end
end

---@param id string
function RegisteredZones:_unindexZone(id)
    self.largeZones[id] = nil

    local cells = self.zoneCells[id]
    if not cells then return end

    for i = 1, #cells do
        local cell = cells[i]
        local bucket = self:_getCellBucket(cell.x, cell.y, false)
        if bucket then
            bucket[id] = nil
            self:_clearCellBucket(cell.x, cell.y)
        end
    end

    self.zoneCells[id] = nil
end

---@param zone WastelandZones.Classes.Zone
function RegisteredZones:_indexZone(zone)
    if not zone or not zone.id then return end

    self:_unindexZone(zone.id)

    local bounds = zone.bounds
    if not self:_isBoundsIndexable(bounds) then
        return
    end

    local minCellX = self:_getCellCoord(bounds.x1)
    local maxCellX = self:_getCellCoord(bounds.x2)
    local minCellY = self:_getCellCoord(bounds.y1)
    local maxCellY = self:_getCellCoord(bounds.y2)

    local cellCountX = (maxCellX - minCellX) + 1
    local cellCountY = (maxCellY - minCellY) + 1
    local totalCells = cellCountX * cellCountY

    if totalCells > MAX_INDEXED_CELLS then
        self.largeZones[zone.id] = zone
        return
    end

    local cells = {}
    self.zoneCells[zone.id] = cells

    for cellX = minCellX, maxCellX do
        for cellY = minCellY, maxCellY do
            local bucket = self:_getCellBucket(cellX, cellY, true)
            bucket[zone.id] = zone
            cells[#cells + 1] = { x = cellX, y = cellY }
        end
    end
end

---@return table<string, WastelandZones.Classes.Zone>
function RegisteredZones:getAll()
    return self.zones
end

---@param id string
---@return WastelandZones.Classes.Zone|nil
function RegisteredZones:get(id)
    return self.zones[id]
end

---@param x number
---@param y number
---@param z number
---@return table<string, WastelandZones.Classes.Zone>
function RegisteredZones:getAllAt(x, y, z)
    local matches = {}

    if x == nil or y == nil or z == nil then
        return matches
    end

    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)

    local cellX = self:_getCellCoord(x)
    local cellY = self:_getCellCoord(y)
    local bucket = self:_getCellBucket(cellX, cellY, false)

    if bucket then
        for zoneId, zone in pairs(bucket) do
            if zone:isPointIn(x, y, z) then
                matches[zoneId] = zone
            end
        end
    end

    for zoneId, zone in pairs(self.largeZones) do
        if zone:isPointIn(x, y, z) then
            matches[zoneId] = zone
        end
    end

    return matches
end

---@param player IsoPlayer
---@return table<string, WastelandZones.Classes.Zone>
function RegisteredZones:getAllFor(player)
    if not player then return {} end
    return self:getAllAt(player:getX(), player:getY(), player:getZ())
end

---@param x number
---@param y number
---@param z number
---@param range number
---@return table<string, WastelandZones.Classes.Zone>
function RegisteredZones:getAllNear(x, y, z, range)
    local matches = {}

    if x == nil or y == nil or z == nil then
        return matches
    end

    local nearRange = math.max(0, range or 0)
    local minCellX = self:_getCellCoord(x - nearRange)
    local maxCellX = self:_getCellCoord(x + nearRange)
    local minCellY = self:_getCellCoord(y - nearRange)
    local maxCellY = self:_getCellCoord(y + nearRange)

    local candidates = {}

    for cellX = minCellX, maxCellX do
        local xBuckets = self.spatialIndex[cellX]
        if xBuckets then
            for cellY = minCellY, maxCellY do
                local bucket = xBuckets[cellY]
                if bucket then
                    for zoneId, zone in pairs(bucket) do
                        candidates[zoneId] = zone
                    end
                end
            end
        end
    end

    for zoneId, zone in pairs(self.largeZones) do
        candidates[zoneId] = zone
    end

    for zoneId, zone in pairs(candidates) do
        if zone:isPointNear(x, y, z, nearRange) then
            matches[zoneId] = zone
        end
    end

    return matches
end

---@param zonesData table<string, table>
function RegisteredZones:bulkSet(zonesData)
    if not zonesData then return end
    print("WastelandZones.RegisteredZones:bulkSet Starting")
    local Zone = WastelandZones.Classes.Zone
    local events = WastelandZones.Events

    if events and events.invalidateServerRuntimeCaches then
        events:invalidateServerRuntimeCaches()
    end

    -- Unregister all existing zones
    for _, zone in pairs(self.zones) do
        zone:onDestroyed()
        events:unregisterZone(zone)
    end

    self.zones = {}
    self.spatialIndex = {}
    self.largeZones = {}
    self.zoneCells = {}
    self.expiringZoneIds = {}
    self.expiringZoneIndexById = {}

    local importStartMs = getTimestampMs()
    local deserializeMs = 0
    local onCreatedMs = 0
    local indexZoneMs = 0
    local registerZoneMs = 0

    -- Register new zones
    for id, zoneData in pairs(zonesData) do
        local stepStartMs = getTimestampMs()
        local zone = Zone:deserialize(zoneData)
        deserializeMs = deserializeMs + (getTimestampMs() - stepStartMs)

        stepStartMs = getTimestampMs()
        zone:onCreated()
        onCreatedMs = onCreatedMs + (getTimestampMs() - stepStartMs)

        self.zones[id] = zone
        self:_syncExpiringZoneTracking(zone)

        stepStartMs = getTimestampMs()
        self:_indexZone(zone)
        indexZoneMs = indexZoneMs + (getTimestampMs() - stepStartMs)

        stepStartMs = getTimestampMs()
        events:registerZone(zone)
        registerZoneMs = registerZoneMs + (getTimestampMs() - stepStartMs)
    end

    local totalImportMs = getTimestampMs() - importStartMs

    print("WastelandZones.RegisteredZones:bulkSet import timing | total time to import all zones: " .. tostring(totalImportMs) .. "ms")
    print("WastelandZones.RegisteredZones:bulkSet import timing | time in deserialize: " .. tostring(deserializeMs) .. "ms")
    print("WastelandZones.RegisteredZones:bulkSet import timing | time in onCreated: " .. tostring(onCreatedMs) .. "ms")
    print("WastelandZones.RegisteredZones:bulkSet import timing | time in _indexZone: " .. tostring(indexZoneMs) .. "ms")
    print("WastelandZones.RegisteredZones:bulkSet import timing | time in registerZone: " .. tostring(registerZoneMs) .. "ms")

    local totalZones = 0
    for _, _ in pairs(self.zones) do
        totalZones = totalZones + 1
    end

    local largeZoneCount = 0
    for _, _ in pairs(self.largeZones) do
        largeZoneCount = largeZoneCount + 1
    end

    print("WastelandZones.RegisteredZones:bulkSet Done | Total zones: " .. tostring(totalZones) .. " | # Large Zones: " .. tostring(largeZoneCount))
end

---@param zone WastelandZones.Classes.Zone
function RegisteredZones:set(zone)
    if not zone or not zone.id then return end
    local events = WastelandZones.Events

    local existing = self.zones[zone.id]
    if existing then
        self:_unindexZone(existing.id)
    end

    self.zones[zone.id] = zone
    self:_syncExpiringZoneTracking(zone)
    self:_indexZone(zone)

    if existing then
        zone:onRecreated(existing)
        events:reregisterZone(existing, zone)
    else
        zone:onCreated()
        events:registerZone(zone)
    end

    if isServer() then
        self:triggerSave()
    end

    if not isServer() then
        if WastelandZones.Classes.ZoneEditorWindow and
           WastelandZones.Classes.ZoneEditorWindow.instance and
           WastelandZones.Classes.ZoneEditorWindow.instance.originalZone and
           WastelandZones.Classes.ZoneEditorWindow.instance.originalZone.id == zone.id then
            WastelandZones.Classes.ZoneEditorWindow.instance:reloadZone(zone)
        end
    end
end

---@param id string
function RegisteredZones:remove(id)
    local events = WastelandZones.Events

    if events and events.invalidateServerRuntimeCaches then
        events:invalidateServerRuntimeCaches()
    end

    local zone = self.zones[id]
    if zone then
        events:unregisterZone(zone)
        self:_removeExpiringZone(zone.id)
        self:_unindexZone(zone.id)
        zone:onDestroyed()
    end

    self.zones[id] = nil

    if events and events.invalidateServerRuntimeCaches then
        events:invalidateServerRuntimeCaches()
    end

    if isServer() then
        self:triggerSave()
    end
end

---@return table<string, table>
function RegisteredZones:getAllSerialized()
    local data = {}
    for id, zone in pairs(self.zones) do
        data[id] = zone:serialize()
    end
    return data
end

---@return nil
function RegisteredZones:triggerSave()
    if isClient() then print("WastelandZones.RegisteredZones:triggerSave is server only") return end
    self.saveDirty = true
    self.saveTicksRemaining = self.saveDebounceTicks
end
