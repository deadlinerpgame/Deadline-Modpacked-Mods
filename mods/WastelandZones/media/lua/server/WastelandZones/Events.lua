require("WLBaseObject")

---@class WastelandZones.Classes.Events: WLBaseObject
---@field eventZoneMap table<string, table<string, WastelandZones.Classes.Zone>>
---@field playerZonesIn table<integer, table<string, boolean>>
---@field playerZonesByEvent table<string, table<integer, table<string, boolean>>>
---@field serverRuntime table
local EventsClass = WastelandZones.Classes.Events or WLBaseObject:derive("WastelandZones.Classes.Events")
if not WastelandZones.Classes.Events then
    WastelandZones.Classes.Events = EventsClass
end

local DEFAULT_SERVER_RUNTIME_CONFIG = {
    zombieIntervalTicks = 20,
    maxZombiesPerZombieRun = 200,
    maxZonesTouchedPerZombieRun = 64,
    maxPluginBatchOpsPerZombieRun = 256
}

---@return WastelandZones.Classes.Events
function EventsClass:new()
    local o = EventsClass.parentClass.new(self)
    EventsClass.registerEvents(o)
    o.eventZoneMap = {
        onPlayerInsideTick = {},
        onPlayerInsideOneSecond = {},
        onPlayerInsideTenSeconds = {},
        onPlayerInsideOneMinute = {},
        onServerTick = {},
        onServerZombieBatch = {}
    }
    o.playerZonesIn = {}
    o.playerZonesByEvent = {
        onPlayerInsideTick = {},
        onPlayerInsideOneSecond = {},
        onPlayerInsideTenSeconds = {},
        onPlayerInsideOneMinute = {}
    }
    o.clientRuntime = {
        lastRealEventTs = 0
    }
    o.serverRuntime = {
        tickCounter = 0,
        lastZombieRunTick = -1,
        zombieCursor = 0,
        cacheDirty = true,
        hookZonesByLane = {
            onServerTick = {},
            onServerZombieBatch = {}
        },
        pendingZombieBatches = {},
        deferredActions = {},
        metrics = {},
        config = {
            zombieIntervalTicks = DEFAULT_SERVER_RUNTIME_CONFIG.zombieIntervalTicks,
            maxZombiesPerZombieRun = DEFAULT_SERVER_RUNTIME_CONFIG.maxZombiesPerZombieRun,
            maxZonesTouchedPerZombieRun = DEFAULT_SERVER_RUNTIME_CONFIG.maxZonesTouchedPerZombieRun,
            maxPluginBatchOpsPerZombieRun = DEFAULT_SERVER_RUNTIME_CONFIG.maxPluginBatchOpsPerZombieRun
        }
    }
    return o
end

---@param map table|nil
---@return boolean
function EventsClass:_isEmptyMap(map)
    if not map then return true end
    for _, _ in pairs(map) do
        return false
    end
    return true
end

---@param eventName string
---@param playerNum integer
---@param zoneId string
function EventsClass:_addPlayerZoneToEvent(eventName, playerNum, zoneId)
    local perEvent = self.playerZonesByEvent[eventName]
    if not perEvent then return end

    local zones = perEvent[playerNum]
    if not zones then
        zones = {}
        perEvent[playerNum] = zones
    end

    zones[zoneId] = true
end

---@param eventName string
---@param playerNum integer
---@param zoneId string
function EventsClass:_removePlayerZoneFromEvent(eventName, playerNum, zoneId)
    local perEvent = self.playerZonesByEvent[eventName]
    if not perEvent then return end

    local zones = perEvent[playerNum]
    if not zones then return end

    zones[zoneId] = nil
    if self:_isEmptyMap(zones) then
        perEvent[playerNum] = nil
    end
end

---@param playerNum integer
---@param zoneId string
function EventsClass:_addPlayerZoneEventMembership(playerNum, zoneId)
    if self.eventZoneMap.onPlayerInsideTick[zoneId] then
        self:_addPlayerZoneToEvent("onPlayerInsideTick", playerNum, zoneId)
    end
    if self.eventZoneMap.onPlayerInsideOneSecond[zoneId] then
        self:_addPlayerZoneToEvent("onPlayerInsideOneSecond", playerNum, zoneId)
    end
    if self.eventZoneMap.onPlayerInsideTenSeconds[zoneId] then
        self:_addPlayerZoneToEvent("onPlayerInsideTenSeconds", playerNum, zoneId)
    end
    if self.eventZoneMap.onPlayerInsideOneMinute[zoneId] then
        self:_addPlayerZoneToEvent("onPlayerInsideOneMinute", playerNum, zoneId)
    end
end

---@param playerNum integer
---@param zoneId string
function EventsClass:_removePlayerZoneEventMembership(playerNum, zoneId)
    self:_removePlayerZoneFromEvent("onPlayerInsideTick", playerNum, zoneId)
    self:_removePlayerZoneFromEvent("onPlayerInsideOneSecond", playerNum, zoneId)
    self:_removePlayerZoneFromEvent("onPlayerInsideTenSeconds", playerNum, zoneId)
    self:_removePlayerZoneFromEvent("onPlayerInsideOneMinute", playerNum, zoneId)
end

---@param eventName string
function EventsClass:_forEachPlayerZoneEvent(eventName)
    local perEvent = self.playerZonesByEvent[eventName]
    local zonesById = self.eventZoneMap[eventName]
    if not perEvent or not zonesById then return end

    for playerNum, zoneIds in pairs(perEvent) do
        local player = getSpecificPlayer(playerNum)
        if player then
            for zoneId, _ in pairs(zoneIds) do
                local zone = zonesById[zoneId]
                if zone and zone.enabled == true and zone[eventName] then
                    zone[eventName](zone, player)
                end
            end
        end
    end
end

---@param zone WastelandZones.Classes.Zone
function EventsClass:registerZone(zone)
    if zone.enabled ~= true then
        self:invalidateServerRuntimeCaches()
        return
    end

    if zone:needsEvent("onPlayerInsideTick") then
        self.eventZoneMap.onPlayerInsideTick[zone.id] = zone
    end
    if zone:needsEvent("onPlayerInsideOneSecond") then
        self.eventZoneMap.onPlayerInsideOneSecond[zone.id] = zone
    end
    if zone:needsEvent("onPlayerInsideTenSeconds") then
        self.eventZoneMap.onPlayerInsideTenSeconds[zone.id] = zone
    end
    if zone:needsEvent("onPlayerInsideOneMinute") then
        self.eventZoneMap.onPlayerInsideOneMinute[zone.id] = zone
    end

    if zone:needsEvent("onServerTick") then
        self.eventZoneMap.onServerTick[zone.id] = zone
    end
    if zone:needsEvent("onServerZombieBatch") then
        self.eventZoneMap.onServerZombieBatch[zone.id] = zone
    end

    self:invalidateServerRuntimeCaches()
end

---@param zone WastelandZones.Classes.Zone
function EventsClass:unregisterZone(zone)
    self.eventZoneMap.onPlayerInsideTick[zone.id] = nil
    self.eventZoneMap.onPlayerInsideOneSecond[zone.id] = nil
    self.eventZoneMap.onPlayerInsideTenSeconds[zone.id] = nil
    self.eventZoneMap.onPlayerInsideOneMinute[zone.id] = nil
    self.eventZoneMap.onServerTick[zone.id] = nil
    self.eventZoneMap.onServerZombieBatch[zone.id] = nil

    for playerNum, zones in pairs(self.playerZonesIn) do
        if zones[zone.id] then
            zone:onPlayerExit(getSpecificPlayer(playerNum))
            zones[zone.id] = nil
            self:_removePlayerZoneEventMembership(playerNum, zone.id)
        end
    end

    self:invalidateServerRuntimeCaches()
end

function EventsClass:reregisterZone(oldZone, newZone)
    self.eventZoneMap.onPlayerInsideTick[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideOneSecond[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideTenSeconds[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideOneMinute[oldZone.id] = nil
    self.eventZoneMap.onServerTick[oldZone.id] = nil
    self.eventZoneMap.onServerZombieBatch[oldZone.id] = nil
    self:registerZone(newZone)
end

function EventsClass:replaceZone(oldZone, newZone)
    if oldZone.id ~= newZone.id then
        error("EventsClass:replaceZone() zone ID mismatch")
    end
    
    self.eventZoneMap.onPlayerInsideTick[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideOneSecond[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideTenSeconds[oldZone.id] = nil
    self.eventZoneMap.onPlayerInsideOneMinute[oldZone.id] = nil
    self.eventZoneMap.onServerTick[oldZone.id] = nil
    self.eventZoneMap.onServerZombieBatch[oldZone.id] = nil

    self:registerZone(newZone)
end


function EventsClass:invalidateServerRuntimeCaches()
    if not self.serverRuntime then
        return
    end

    self.serverRuntime.cacheDirty = true
end

function EventsClass:_rebuildServerRuntimeCachesIfNeeded()
    local runtime = self.serverRuntime
    if not runtime or not runtime.cacheDirty then
        return
    end

    runtime.hookZonesByLane.onServerTick = {}
    runtime.hookZonesByLane.onServerZombieBatch = {}

    for _, zone in pairs(self.eventZoneMap.onServerTick) do
        runtime.hookZonesByLane.onServerTick[#runtime.hookZonesByLane.onServerTick + 1] = zone
    end

    for _, zone in pairs(self.eventZoneMap.onServerZombieBatch) do
        runtime.hookZonesByLane.onServerZombieBatch[#runtime.hookZonesByLane.onServerZombieBatch + 1] = zone
    end

    runtime.cacheDirty = false
end

---@param action fun():any
---@return boolean
function EventsClass:_queueDeferredAction(action)
    if type(action) ~= "function" then
        return false
    end

    local runtime = self.serverRuntime
    runtime.deferredActions[#runtime.deferredActions + 1] = action
    return true
end

function EventsClass:_applyDeferredActions()
    local runtime = self.serverRuntime
    if not runtime then return end

    for i = 1, #runtime.deferredActions do
        local ok, err = pcall(runtime.deferredActions[i])
        if not ok then
            print("WastelandZones.Events: deferred action failed - " .. tostring(err))
        end
    end

    runtime.deferredActions = {}
end

---@param lane string
---@param metrics table
---@return table
function EventsClass:_newServerLaneRuntime(lane, metrics)
    local owner = self
    local runtime = self.serverRuntime
    return {
        lane = lane,
        metrics = metrics,
        config = runtime.config,
        defer = function(_, action)
            return owner:_queueDeferredAction(action)
        end,
        deferZombieRemoval = function(_, zombie)
            return owner:_queueDeferredAction(function()
                if zombie and not zombie:isDead() then
                    zombie:removeFromWorld()
                    zombie:removeFromSquare()
                end
            end)
        end
    }
end

---@param zone WastelandZones.Classes.Zone
---@param plugin WastelandZones.Classes.Plugin
---@param lane string
---@param runtimeLane table
---@return boolean
function EventsClass:_dispatchPluginForLane(zone, plugin, lane, runtimeLane)
    local pluginType = plugin and plugin.type or "unknown"
    local pluginData = zone.plugins[pluginType]
    plugin[lane](plugin, zone, pluginData, runtimeLane)
    return true
end

---@param lane string
function EventsClass:_runServerLane(lane)
    local runtime = self.serverRuntime
    local zones = runtime.hookZonesByLane[lane]
    if not zones or #zones == 0 then
        return
    end

    local metrics = {
        zonesVisited = 0,
        pluginOps = 0,
        lane = lane
    }
    runtime.metrics[lane] = metrics

    local runtimeLane = self:_newServerLaneRuntime(lane, metrics)
    for i = 1, #zones do
        local zone = zones[i]
        if zone.enabled == true then
            metrics.zonesVisited = metrics.zonesVisited + 1

            local plugins = zone.events[lane]
            if plugins and #plugins > 0 then
                for j = 1, #plugins do
                    self:_dispatchPluginForLane(zone, plugins[j], lane, runtimeLane)
                    metrics.pluginOps = metrics.pluginOps + 1
                end
            end
        end
    end
end

---@param batch {zone:WastelandZones.Classes.Zone,zombies:IsoZombie[],nextPluginIndex:integer|nil}
---@param runtimeLane table
---@param pluginOpBudget integer
---@return integer, boolean
function EventsClass:_runServerZombieBatchForBatch(batch, runtimeLane, pluginOpBudget)
    local zone = batch.zone
    if not zone then
        return 0, true
    end

    if zone.enabled ~= true then
        return 0, true
    end

    local plugins = zone.events.onServerZombieBatch
    if not plugins or #plugins == 0 then
        return 0, true
    end

    local used = 0
    local nextPluginIndex = batch.nextPluginIndex or 1

    while nextPluginIndex <= #plugins and used < pluginOpBudget do
        local plugin = plugins[nextPluginIndex]
        local pluginType = plugin and plugin.type or "unknown"
        local pluginData = zone.plugins[pluginType]
        plugin.onServerZombieBatch(plugin, zone, batch.zombies, pluginData, runtimeLane)

        used = used + 1
        nextPluginIndex = nextPluginIndex + 1
    end

    batch.nextPluginIndex = nextPluginIndex
    local done = nextPluginIndex > #plugins
    return used, done
end

function EventsClass:_runServerZombieLane()
    local runtime = self.serverRuntime
    local config = runtime.config
    local maxPluginOps = math.max(1, config.maxPluginBatchOpsPerZombieRun or DEFAULT_SERVER_RUNTIME_CONFIG.maxPluginBatchOpsPerZombieRun)
    local maxZonesTouched = math.max(1, config.maxZonesTouchedPerZombieRun or DEFAULT_SERVER_RUNTIME_CONFIG.maxZonesTouchedPerZombieRun)
    local maxZombies = math.max(1, config.maxZombiesPerZombieRun or DEFAULT_SERVER_RUNTIME_CONFIG.maxZombiesPerZombieRun)

    local metrics = {
        lane = "onServerZombieBatch",
        zombiesScanned = 0,
        zonesTouched = 0,
        pendingBatchesBefore = #runtime.pendingZombieBatches,
        pendingBatchesAfter = 0,
        pluginOps = 0,
        zoneBudgetCutoff = false
    }
    runtime.metrics.onServerZombieBatch = metrics

    local cell = getCell()
    if not cell then
        return
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return
    end

    local zombieCount = zombies:size()
    if zombieCount <= 0 then
        runtime.zombieCursor = 0
        return
    end

    local toScan = math.min(zombieCount, maxZombies)
    local startIndex = runtime.zombieCursor
    local scanned = 0

    local zoneBatchesById = {}
    local zoneOrder = {}

    while scanned < toScan and scanned < zombieCount do
        local idx = (startIndex + scanned) % zombieCount
        local zombie = zombies:get(idx)
        scanned = scanned + 1

        if zombie then
            local matches = WastelandZones.Zones:getAllAt(zombie:getX(), zombie:getY(), zombie:getZ())
            for zoneId, zone in pairs(matches) do
                if zone.enabled == true and self.eventZoneMap.onServerZombieBatch[zoneId] then
                    local batch = zoneBatchesById[zoneId]
                    if not batch then
                        if metrics.zonesTouched >= maxZonesTouched then
                            metrics.zoneBudgetCutoff = true
                            break
                        end

                        batch = {
                            zone = zone,
                            zombies = {},
                            nextPluginIndex = 1
                        }
                        zoneBatchesById[zoneId] = batch
                        zoneOrder[#zoneOrder + 1] = batch
                        metrics.zonesTouched = metrics.zonesTouched + 1
                    end

                    batch.zombies[#batch.zombies + 1] = zombie
                end
            end

            if metrics.zoneBudgetCutoff then
                break
            end
        end
    end

    metrics.zombiesScanned = scanned
    runtime.zombieCursor = (startIndex + scanned) % zombieCount

    for i = 1, #zoneOrder do
        runtime.pendingZombieBatches[#runtime.pendingZombieBatches + 1] = zoneOrder[i]
    end

    local runtimeLane = self:_newServerLaneRuntime("onServerZombieBatch", metrics)
    local queue = runtime.pendingZombieBatches
    local queueIndex = 1

    while queueIndex <= #queue and metrics.pluginOps < maxPluginOps do
        local batch = queue[queueIndex]
        local budgetLeft = maxPluginOps - metrics.pluginOps
        local used, done = self:_runServerZombieBatchForBatch(batch, runtimeLane, budgetLeft)
        metrics.pluginOps = metrics.pluginOps + used

        if done then
            table.remove(queue, queueIndex)
        else
            break
        end
    end

    metrics.pendingBatchesAfter = #runtime.pendingZombieBatches
end

function EventsClass:_runServerScheduler()
    self:_rebuildServerRuntimeCachesIfNeeded()

    self:_runServerLane("onServerTick")

    local runtime = self.serverRuntime
    local interval = runtime.config.zombieIntervalTicks or DEFAULT_SERVER_RUNTIME_CONFIG.zombieIntervalTicks
    if interval < 1 then interval = 1 end

    if (runtime.tickCounter % interval) == 0 and runtime.lastZombieRunTick ~= runtime.tickCounter then
        runtime.lastZombieRunTick = runtime.tickCounter
        self:_runServerZombieLane()
    end

    self:_applyDeferredActions()
end

function EventsClass:_EveryTickClient()
    local player = getPlayer()
    if not player then return end
    
    local playerNum = player:getPlayerNum()
    self.playerZonesIn[playerNum] = self.playerZonesIn[playerNum] or {}
    local currentZones = self.playerZonesIn[playerNum]

    local candidateZones = WastelandZones.Zones:getAllFor(player)

    for zoneId, _ in pairs(currentZones) do
        local zone = WastelandZones.Zones:get(zoneId)
        if not candidateZones[zoneId] or not zone or zone.enabled ~= true then
            currentZones[zoneId] = nil
            self:_removePlayerZoneEventMembership(playerNum, zoneId)
            if zone and zone.enabled == true then
                zone:onPlayerExit(player)
            end
        end
    end

    for zoneId, zone in pairs(candidateZones) do
        if zone.enabled == true and not currentZones[zoneId] then
            currentZones[zoneId] = true
            self:_addPlayerZoneEventMembership(playerNum, zoneId)
            zone:onPlayerEnter(player)
        end
    end

    self:_forEachPlayerZoneEvent("onPlayerInsideTick")

    local runtime = self.clientRuntime
    local currentTs = getTimestamp()
    local lastTs = runtime.lastRealEventTs or 0
    if currentTs <= 0 or currentTs == lastTs then
        return
    end

    local deltaTs = currentTs - lastTs
    runtime.lastRealEventTs = currentTs
    if lastTs <= 0 or deltaTs <= 0 then
        return
    end

    self:_forEachPlayerZoneEvent("onPlayerInsideOneSecond")
    if (currentTs % 10) < deltaTs then
        self:_forEachPlayerZoneEvent("onPlayerInsideTenSeconds")
    end
    if (currentTs % 60) < deltaTs then
        self:_forEachPlayerZoneEvent("onPlayerInsideOneMinute")
    end
end

function EventsClass:_EveryTickServer()
    local runtime = self.serverRuntime
    runtime.tickCounter = runtime.tickCounter + 1
    self:_runServerScheduler()
end

---@param instance WastelandZones.Classes.Events
function EventsClass.registerEvents(instance)
    if not isServer() then
        Events.OnTick.Add(function() instance:_EveryTickClient() end)
    end

    if not isClient() then
        Events.OnTick.Add(function() instance:_EveryTickServer() end)
    end
end
