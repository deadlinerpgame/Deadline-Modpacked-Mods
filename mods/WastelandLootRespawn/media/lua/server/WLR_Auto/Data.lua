if isClient() then return end

local Json = require "WLR_Auto_json"
require "WLR_NetworkConstants"

WLR_Auto = WLR_Auto or {}

--- @class ChunkCache
--- @field definitionId string
--- @field lastRespawn number
--- @field ready boolean

--- @class WLR_Auto.Data
--- @field definitions table<string, WLR_Auto.Definition>
--- @field chunkCache table<string, ChunkCache>
WLR_Auto.Data = WLR_Auto.Data or WLBaseObject:derive("Data")

--- @return WLR_Auto.Data
function WLR_Auto.Data:new()
    local o = self:super()
    o.definitions = {}
    o.chunkCache = {}
    return o
end

--- @param self WLR_Auto.Data
function WLR_Auto.Data:loadDefinitions()
    local fileReaderObj = getFileReader("WastelandAutoLootRespawnConfig.json", false)
    local json = ""
    if fileReaderObj then
        local line = fileReaderObj:readLine()
        while line ~= nil do
            json = json .. line
            line = fileReaderObj:readLine()
        end
        fileReaderObj:close()
    end

    if json and json ~= "" then
        local decoded = Json.Decode(json)
        if decoded then
            local enabledCount = 0
            for _, definitionData in ipairs(decoded) do
                local definition = WLR_Auto.Definition:new(definitionData)
                if definition.enabled then
                    self.definitions[definition.id] = definition
                    enabledCount = enabledCount + 1
                end
            end
            WLR_Auto.InfoLog("Loaded " .. enabledCount .. " zone definitions")
        end
    else
        WLR_Auto.InfoLog("No config found, creating default")
        local defaultConfig = WLR_Auto.Definition.GetDefaultConfig()
        local fileWriterObj = getFileWriter("WastelandAutoLootRespawnConfig.json", true, false)
        fileWriterObj:write(Json.Encode(defaultConfig))
        fileWriterObj:close()
    end
end

--- @param self WLR_Auto.Data
--- @param rawData table<string, table<string, ChunkCache>>
function WLR_Auto.Data:loadChunkCache(rawData)
    self.chunkCache = rawData
    local count = 0
    local readyCount = 0
    for _, chunk in pairs(self.chunkCache) do
        count = count + 1
        if chunk.ready then
            readyCount = readyCount + 1
        end
    end
    WLR_Auto.InfoLog("Loaded chunk cache: " .. count .. " chunks (" .. readyCount .. " ready)")
end

--- @param self WLR_Auto.Data
function WLR_Auto.Data:forceAll()
    for _, chunk in pairs(self.chunkCache) do
        chunk.ready = true
    end
end

--- @param self WLR_Auto.Data
--- @param range WLR_Auto.Range
--- @return WLR_Auto.Definition|nil
function WLR_Auto.Data:getDefinitionsReadyInChunk(range)
    local chunkCache = self:_getChunkCache(range)
    if chunkCache and ((chunkCache.ready and ZombRand(2) == 0) or WLR_Auto.Config.AlwaysRespawn) then
        local definition = self.definitions[chunkCache.definitionId]
        if definition then
            WLR_Auto.DebugLog("WLR_Auto.Data:getDefinitionsReadyInChunk() - (" .. tostring(range) .. ") respawn is ready: " .. definition.id)
            chunkCache.ready = false
            chunkCache.lastRespawn = getTimestamp()
            return definition
        end
    end
    return nil
end

--- @param self WLR_Auto.Data
function WLR_Auto.Data:checkForNeededRespawn()
    local currentTime = getTimestamp()
    for chunk, chunkCache in pairs(self.chunkCache) do
        if not chunkCache.ready then
            local definition = self.definitions[chunkCache.definitionId]
            if not definition then
                WLR_Auto.TraceLog("WLR_Auto.Data:checkForNeededRespawn() - Removing chunkCache: " .. tostring(chunk))
                self.chunkCache[chunk] = nil
            else
                local timeSinceLastRespawn = currentTime - chunkCache.lastRespawn
                if timeSinceLastRespawn >= definition.frequencyHours * 60 * 60 then
                    WLR_Auto.TraceLog("WLR_Auto.Data:checkForNeededRespawn() - Chunk is due for respawn: " .. tostring(chunk))
                    chunkCache.definitionId = definition.id
                    chunkCache.ready = true
                end
            end
        end
    end
end

--- @param self WLR_Auto.Data
--- @param range WLR_Auto.Range
--- @return ChunkCache|nil
function WLR_Auto.Data:_getChunkCache(range)
    local key = self:_getChunkKey(range.x1, range.y1)
    if self.chunkCache[key] then
        return self.chunkCache[key]
    end

    local definition = self:_getFirstDefinitionInChunk(range)
    if definition then
        WLR_Auto.TraceLog("WLR_Auto.Data:_getCachedChunk() - Creating new chunkCache: " .. key)
        local cache = {
            definitionId = definition.id,
            lastRespawn = getTimestamp(), -- If never respawned, assume now
            ready = false,
        }
        self.chunkCache[key] = cache
        return cache
    else
        WLR_Auto.TraceLog("WLR_Auto.Data:_getCachedChunk() - No definition found for chunk: " .. key)
    end
    return nil
end

--- @param self WLR_Auto.Data
--- @param range WLR_Auto.Range
--- @return WLR_Auto.Definition|nil
function WLR_Auto.Data:_getFirstDefinitionInChunk(range)
    for _, definition in pairs(self.definitions) do
        if definition:intersects(range) then
            return definition
        end
    end
    return nil
end

--- @param self WLR_Auto.Data
function WLR_Auto.Data:_getChunkKey(x, y)
    return tostring(x) .. "," .. tostring(y)
end

--- Broadcast zone definitions to all admin clients
--- @param self WLR_Auto.Data
function WLR_Auto.Data:broadcastZoneDefinitionsToAdmins()
    local definitionsData = {}
    for id, definition in pairs(self.definitions) do
        definitionsData[id] = {
            id = definition.id,
            enabled = definition.enabled,
            x1 = definition.range.x1,
            y1 = definition.range.y1,
            x2 = definition.range.x2,
            y2 = definition.range.y2,
            containerChance = definition.containerChance,
            itemChance = definition.itemChance,
            frequencyHours = definition.frequencyHours,
            itemCountToIgnore = definition.itemCountToIgnore,
            ignoredCategories = definition.ignoredCategories,
            ignoredItems = definition.ignoredItems,
            gasFillChance = definition.gasFillChance,
            gasFillRange = definition.gasFillRange
        }
    end
    
    -- Send to all admin players
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player:getAccessLevel() == "Admin" then
            sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_DEFINITIONS, definitionsData)
        end
    end
    
    WLR_Auto.DebugLog("Broadcasted " .. tostring(#definitionsData) .. " zone definitions to admins")
end

--- Send zone definitions to a specific admin client
--- @param self WLR_Auto.Data
--- @param player IsoPlayer
function WLR_Auto.Data:sendZoneDefinitionsToAdmin(player)
    if not player:getAccessLevel() == "Admin" then
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " requested zone definitions")
        return
    end
    
    local definitionsData = {}
    for id, definition in pairs(self.definitions) do
        definitionsData[id] = {
            id = definition.id,
            enabled = definition.enabled,
            x1 = definition.range.x1,
            y1 = definition.range.y1,
            x2 = definition.range.x2,
            y2 = definition.range.y2,
            containerChance = definition.containerChance,
            itemChance = definition.itemChance,
            frequencyHours = definition.frequencyHours,
            itemCountToIgnore = definition.itemCountToIgnore,
            ignoredCategories = definition.ignoredCategories,
            ignoredItems = definition.ignoredItems,
            gasFillChance = definition.gasFillChance,
            gasFillRange = definition.gasFillRange
        }
    end
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_DEFINITIONS, definitionsData)
    WLR_Auto.DebugLog("Sent " .. tostring(#definitionsData) .. " zone definitions to " .. player:getUsername())
end


--- Send chunk status to a specific admin client
--- @param self WLR_Auto.Data
--- @param player IsoPlayer
function WLR_Auto.Data:sendChunkStatusToAdmin(player)
    if not player:getAccessLevel() == "Admin" then
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " requested chunk status")
        return
    end
    
    local chunkStatusData = {}
    local currentTime = getTimestamp()
    
    for chunkKey, chunkCache in pairs(self.chunkCache) do
        local definition = self.definitions[chunkCache.definitionId]
        if definition then
            local nextRespawnTime = chunkCache.lastRespawn + (definition.frequencyHours * 60 * 60)
            chunkStatusData[chunkKey] = {
                definitionId = chunkCache.definitionId,
                lastRespawn = chunkCache.lastRespawn,
                nextRespawn = nextRespawnTime,
                ready = chunkCache.ready,
                active = definition.enabled
            }
        end
    end
    
    -- Split data into batches to avoid network message size limits
    local batchSize = 100 -- Adjust this value based on testing
    local chunks = {}
    local chunkCount = 0
    
    -- Convert to array for easier batching
    for chunkKey, chunkData in pairs(chunkStatusData) do
        chunkCount = chunkCount + 1
        chunks[chunkCount] = {key = chunkKey, data = chunkData}
    end
    
    local totalBatches = math.ceil(chunkCount / batchSize)
    local batchId = tostring(getTimestamp()) .. "_" .. player:getUsername()
    
    WLR_Auto.DebugLog("Sending " .. chunkCount .. " chunks in " .. totalBatches .. " batches to " .. player:getUsername())
    
    for batchNum = 1, totalBatches do
        local startIdx = (batchNum - 1) * batchSize + 1
        local endIdx = math.min(batchNum * batchSize, chunkCount)
        
        local batchData = {}
        for i = startIdx, endIdx do
            local chunk = chunks[i]
            batchData[chunk.key] = chunk.data
        end
        
        local message = {
            chunks = batchData,
            batch_id = batchId,
            batch_num = totalBatches,
            batch_current = batchNum
        }
        
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.CHUNK_STATUS, message)
        WLR_Auto.TraceLog("Sent batch " .. batchNum .. "/" .. totalBatches .. " (" .. (endIdx - startIdx + 1) .. " chunks)")
    end
end

--- Reload configuration from JSON and broadcast to admin clients
--- @param self WLR_Auto.Data
--- @param requestingPlayer IsoPlayer
function WLR_Auto.Data:reloadAndBroadcastConfig(requestingPlayer)
    if not requestingPlayer:getAccessLevel() == "Admin" then
        sendServerCommand(requestingPlayer, "WLR_Auto", WLR_NetworkConstants.Messages.CONFIG_RELOAD, {
            success = false,
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. requestingPlayer:getUsername() .. " attempted config reload")
        return
    end
    
    WLR_Auto.InfoLog("Config reload requested by " .. requestingPlayer:getUsername())
    
    -- Clear existing definitions
    self.definitions = {}
    
    -- Reload definitions from JSON
    self:loadDefinitions()
    
    -- Broadcast updated definitions to all admin clients
    self:broadcastZoneDefinitionsToAdmins()
    -- Chunk status broadcasting removed - must be requested manually
    
    -- Send success response to requesting admin
    sendServerCommand(requestingPlayer, "WLR_Auto", WLR_NetworkConstants.Messages.CONFIG_RELOAD, {
        success = true,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.InfoLog("Config reloaded and broadcasted to admins")
end

--- Force respawn for a specific chunk (admin only)
--- @param self WLR_Auto.Data
--- @param chunkKey string
--- @param player IsoPlayer
function WLR_Auto.Data:forceChunkRespawn(chunkKey, player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.FORCE_RESPAWN, {
            success = false,
            chunkKey = chunkKey,
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted force respawn")
        return
    end
    
    local chunkCache = self.chunkCache[chunkKey]
    if chunkCache then
        chunkCache.ready = true
        chunkCache.lastRespawn = getTimestamp()
        
        -- Update mod data
        ModData.add(WLR_Auto._modDataChunkCacheKey, self.chunkCache)
        
        -- Chunk status broadcasting removed - must be requested manually
        
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.FORCE_RESPAWN, {
            success = true,
            chunkKey = chunkKey,
            timestamp = getTimestamp()
        })
        
        WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " forced respawn for chunk: " .. chunkKey)
    else
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.FORCE_RESPAWN, {
            success = false,
            chunkKey = chunkKey,
            error = "Chunk not found"
        })
        WLR_Auto.DebugLog("Force respawn failed: chunk not found: " .. chunkKey)
    end
end

--- Create a new zone (admin only)
--- @param self WLR_Auto.Data
--- @param zoneData table
--- @param player IsoPlayer
function WLR_Auto.Data:createZone(zoneData, player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "createZone",
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted zone creation")
        return
    end
    
    if not zoneData or not zoneData.id then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "createZone",
            error = "Invalid zone data"
        })
        return
    end
    
    -- Check if zone already exists
    if self.definitions[zoneData.id] then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "createZone",
            error = "Zone ID already exists"
        })
        return
    end
    
    -- Create new definition
    local definition = WLR_Auto.Definition:new(zoneData)
    self.definitions[definition.id] = definition
    
    -- Write to JSON file
    self:writeDefinitionsToFile()
    
    -- Broadcast updated definitions to all admin clients
    self:broadcastZoneDefinitionsToAdmins()
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
        success = true,
        operation = "createZone",
        zoneId = definition.id,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " created zone: " .. definition.id)
end

--- Update an existing zone (admin only)
--- @param self WLR_Auto.Data
--- @param zoneData table
--- @param player IsoPlayer
function WLR_Auto.Data:updateZone(zoneData, player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "updateZone",
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted zone update")
        return
    end
    
    if not zoneData or not zoneData.id then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "updateZone",
            error = "Invalid zone data"
        })
        return
    end
    
    -- Check if zone exists
    if not self.definitions[zoneData.id] then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "updateZone",
            error = "Zone not found"
        })
        return
    end
    
    -- Update definition
    local definition = WLR_Auto.Definition:new(zoneData)
    self.definitions[definition.id] = definition
    
    -- Write to JSON file
    self:writeDefinitionsToFile()
    
    -- Broadcast updated definitions to all admin clients
    self:broadcastZoneDefinitionsToAdmins()
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
        success = true,
        operation = "updateZone",
        zoneId = definition.id,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " updated zone: " .. definition.id)
end

--- Delete a zone (admin only)
--- @param self WLR_Auto.Data
--- @param args table
--- @param player IsoPlayer
function WLR_Auto.Data:deleteZone(args, player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "deleteZone",
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted zone deletion")
        return
    end
    
    if not args or not args.zoneId then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "deleteZone",
            error = "Missing zoneId parameter"
        })
        return
    end
    
    local zoneId = args.zoneId
    
    -- Check if zone exists
    if not self.definitions[zoneId] then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "deleteZone",
            error = "Zone not found"
        })
        return
    end
    
    -- Remove definition
    self.definitions[zoneId] = nil
    
    -- Clean up chunk cache for this zone
    for chunkKey, chunkCache in pairs(self.chunkCache) do
        if chunkCache.definitionId == zoneId then
            self.chunkCache[chunkKey] = nil
        end
    end
    
    -- Write to JSON file
    self:writeDefinitionsToFile()
    
    -- Update mod data
    ModData.add(WLR_Auto._modDataChunkCacheKey, self.chunkCache)
    
    -- Broadcast updated definitions to all admin clients
    self:broadcastZoneDefinitionsToAdmins()
    -- Chunk status broadcasting removed - must be requested manually
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
        success = true,
        operation = "deleteZone",
        zoneId = zoneId,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " deleted zone: " .. zoneId)
end

--- Respawn all ready chunks (admin only)
--- @param self WLR_Auto.Data
--- @param player IsoPlayer
function WLR_Auto.Data:respawnAllReady(player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "respawnAllReady",
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted respawn all")
        return
    end
    
    local respawnedCount = 0
    
    for chunkKey, chunkCache in pairs(self.chunkCache) do
        if chunkCache.ready then
            chunkCache.ready = true -- Force ready state
            respawnedCount = respawnedCount + 1
        end
    end
    
    -- Update mod data
    ModData.add(WLR_Auto._modDataChunkCacheKey, self.chunkCache)
    
    -- Chunk status broadcasting removed - must be requested manually
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
        success = true,
        operation = "respawnAllReady",
        count = respawnedCount,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " forced respawn for " .. respawnedCount .. " chunks")
end

--- Respawn all ready chunks in a specific zone (admin only)
--- @param self WLR_Auto.Data
--- @param zoneId string
--- @param player IsoPlayer
function WLR_Auto.Data:respawnAllReadyInZone(zoneId, player)
    if not player:getAccessLevel() == "Admin" then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "respawnAllReadyInZone",
            error = "Access denied - admin privileges required"
        })
        WLR_Auto.DebugLog("Access denied: " .. player:getUsername() .. " attempted zone respawn")
        return
    end
    
    if not self.definitions[zoneId] then
        sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
            success = false,
            operation = "respawnAllReadyInZone",
            error = "Zone not found"
        })
        return
    end
    
    local respawnedCount = 0
    
    for chunkKey, chunkCache in pairs(self.chunkCache) do
        if chunkCache.definitionId == zoneId and chunkCache.ready then
            chunkCache.ready = true -- Force ready state
            respawnedCount = respawnedCount + 1
        end
    end
    
    -- Update mod data
    ModData.add(WLR_Auto._modDataChunkCacheKey, self.chunkCache)
    
    -- Chunk status broadcasting removed - must be requested manually
    
    sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
        success = true,
        operation = "respawnAllReadyInZone",
        zoneId = zoneId,
        count = respawnedCount,
        timestamp = getTimestamp()
    })
    
    WLR_Auto.DebugLog("Admin " .. player:getUsername() .. " forced respawn for " .. respawnedCount .. " chunks in zone: " .. zoneId)
end

--- Write zone definitions to JSON file
--- @param self WLR_Auto.Data
function WLR_Auto.Data:writeDefinitionsToFile()
    local definitionsArray = {}
    
    for _, definition in pairs(self.definitions) do
        local definitionData = {
            id = definition.id,
            enabled = definition.enabled,
            x1 = definition.range.x1,
            y1 = definition.range.y1,
            x2 = definition.range.x2,
            y2 = definition.range.y2,
            containerChance = definition.containerChance,
            itemChance = definition.itemChance,
            frequencyHours = definition.frequencyHours,
            itemCountToIgnore = definition.itemCountToIgnore,
            chanceLocked = definition.chanceLocked,
            ignoredCategories = definition.ignoredCategories,
            ignoredItems = definition.ignoredItems,
            gasFillChance = definition.gasFillChance,
            gasFillRange = definition.gasFillRange
        }
        table.insert(definitionsArray, definitionData)
    end
    
    local Json = require "WLR_Auto_json"
    local jsonString = Json.Encode(definitionsArray)
    
    local fileWriterObj = getFileWriter("WastelandAutoLootRespawnConfig.json", true, false)
    if fileWriterObj then
        fileWriterObj:write(jsonString)
        fileWriterObj:close()
        WLR_Auto.DebugLog("Wrote " .. #definitionsArray .. " zone definitions to config file")
    else
        WLR_Auto.DebugLog("Failed to write zone definitions to file")
    end
end

