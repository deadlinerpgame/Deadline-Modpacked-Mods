if isServer() then return end

require "WLR_NetworkConstants"

WLR_ClientSync = WLR_ClientSync or {}

-- Client-side data cache
WLR_ClientSync.Data = {
    zoneDefinitions = {},
    chunkStatus = {},
    lastUpdate = 0,
    isInitialized = false,
    receivedData = false,
    -- Batch collection for chunk status
    chunkStatusBatches = {},
    -- Batch timeout tracking
    batchTimeouts = {}
}

--- Initialize the client sync system
function WLR_ClientSync.Init()
    WLR_ClientSync.Data.zoneDefinitions = {}
    WLR_ClientSync.Data.chunkStatus = {}
    WLR_ClientSync.Data.lastUpdate = getTimestamp()
    WLR_ClientSync.Data.isInitialized = true
    
    -- Request initial zone definitions from server if player is admin
    local player = getPlayer()
    if player and isAdmin() then
        WLR_ClientSync.RequestZoneDefinitions()
        -- Chunk status must now be requested manually
    end
end

--- Request zone definitions from server
function WLR_ClientSync.RequestZoneDefinitions()
    sendClientCommand(getPlayer(), "WLR_Auto", "requestZoneDefinitions", {})
end

--- Request chunk status from server
function WLR_ClientSync.RequestChunkStatus()
    sendClientCommand(getPlayer(), "WLR_Auto", "requestChunkStatus", {})
end

--- Request config reload from server (admin only)
function WLR_ClientSync.RequestConfigReload()
    sendClientCommand(getPlayer(), "WLR_Auto", "reloadConfig", {})
end

--- Request force respawn for specific chunk (admin only)
--- @param chunkKey string
function WLR_ClientSync.RequestForceChunkRespawn(chunkKey)
    sendClientCommand(getPlayer(), "WLR_Auto", "forceChunkRespawn", { chunkKey = chunkKey })
end

--- Get all zone definitions
--- @return table<string, table>
function WLR_ClientSync.GetZoneDefinitions()
    return WLR_ClientSync.Data.zoneDefinitions
end

--- Get zone definition by ID
--- @param id string
--- @return table|nil
function WLR_ClientSync.GetZoneDefinition(id)
    return WLR_ClientSync.Data.zoneDefinitions[id]
end

--- Get all chunk status data
--- @return table<string, table>
function WLR_ClientSync.GetChunkStatus()
    return WLR_ClientSync.Data.chunkStatus
end

--- Get chunk status by chunk key
--- @param chunkKey string
--- @return table|nil
function WLR_ClientSync.GetChunkStatusByKey(chunkKey)
    return WLR_ClientSync.Data.chunkStatus[chunkKey]
end

--- Get chunk status by coordinates
--- @param x number
--- @param y number
--- @return table|nil
function WLR_ClientSync.GetChunkStatusByCoords(x, y)
    local chunkKey = tostring(x) .. "," .. tostring(y)
    return WLR_ClientSync.Data.chunkStatus[chunkKey]
end

--- Check if a zone contains specific coordinates
--- @param zoneDefinition table
--- @param x number
--- @param y number
--- @return boolean
function WLR_ClientSync.IsPointInZone(zoneDefinition, x, y)
    return x >= zoneDefinition.x1 and x <= zoneDefinition.x2 and 
           y >= zoneDefinition.y1 and y <= zoneDefinition.y2
end

--- Get all zones that contain specific coordinates
--- @param x number
--- @param y number
--- @return table
function WLR_ClientSync.GetZonesAtPoint(x, y)
    local zones = {}
    for id, zone in pairs(WLR_ClientSync.Data.zoneDefinitions) do
        if WLR_ClientSync.IsPointInZone(zone, x, y) then
            table.insert(zones, zone)
        end
    end
    return zones
end

--- Get chunks within a zone
--- @param zoneId string
--- @return table
function WLR_ClientSync.GetChunksInZone(zoneId)
    local chunks = {}
    local zone = WLR_ClientSync.Data.zoneDefinitions[zoneId]
    if not zone then return chunks end
    
    for chunkKey, chunkData in pairs(WLR_ClientSync.Data.chunkStatus) do
        if chunkData.definitionId == zoneId then
            chunks[chunkKey] = chunkData
        end
    end
    return chunks
end

--- Check if client data is initialized
--- @return boolean
function WLR_ClientSync.IsInitialized()
    return WLR_ClientSync.Data.isInitialized
end

--- Clean up expired batch collections (called periodically)
function WLR_ClientSync.CleanupExpiredBatches()
    local currentTime = getTimestamp()
    local batchTimeout = 30 -- 30 seconds timeout for batch collection
    
    for batchId, timeoutInfo in pairs(WLR_ClientSync.Data.batchTimeouts) do
        if currentTime - timeoutInfo.startTime > batchTimeout then
            print("WLR_ClientSync: Batch collection timed out for batch_id: " .. batchId .. " (received " .. timeoutInfo.receivedCount .. "/" .. timeoutInfo.totalBatches .. " batches)")
            
            -- Clean up expired batch data
            WLR_ClientSync.Data.chunkStatusBatches[batchId] = nil
            WLR_ClientSync.Data.batchTimeouts[batchId] = nil
        end
    end
end

--- Get last update timestamp
--- @return number
function WLR_ClientSync.GetLastUpdate()
    return WLR_ClientSync.Data.lastUpdate
end

-- Register custom events
LuaEventManager.AddEvent("WLR_ZoneDefinitionsUpdated")
LuaEventManager.AddEvent("WLR_ChunkStatusUpdated")
LuaEventManager.AddEvent("WLR_ConfigReloadResponse")
LuaEventManager.AddEvent("WLR_ForceRespawnResponse")
LuaEventManager.AddEvent("WLR_ZoneOperationResponse")

--- Handle server commands
Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "WLR_Auto" then return end
    
    if command == WLR_NetworkConstants.Messages.ZONE_DEFINITIONS then
        WLR_ClientSync.Data.zoneDefinitions = args
        WLR_ClientSync.Data.lastUpdate = getTimestamp()
        WLR_ClientSync.Data.receivedData = true
        print("WLR_ClientSync: Received zone definitions update")
        
        -- Trigger event for GUI updates
        triggerEvent("WLR_ZoneDefinitionsUpdated", args)
        
    elseif command == WLR_NetworkConstants.Messages.CHUNK_STATUS then
        -- Handle batched chunk status messages
        if args.batch_id and args.batch_num and args.batch_current then
            -- This is a batched message
            local batchId = args.batch_id
            local totalBatches = args.batch_num
            local currentBatch = args.batch_current
            local chunks = args.chunks
            
            print("WLR_ClientSync: Received chunk status batch " .. currentBatch .. "/" .. totalBatches .. " (batch_id: " .. batchId .. ")")
            
            -- Initialize batch collection if needed
            if not WLR_ClientSync.Data.chunkStatusBatches[batchId] then
                WLR_ClientSync.Data.chunkStatusBatches[batchId] = {
                    totalBatches = totalBatches,
                    receivedBatches = {},
                    chunks = {}
                }
                -- Track timeout for this batch collection
                WLR_ClientSync.Data.batchTimeouts[batchId] = {
                    startTime = getTimestamp(),
                    totalBatches = totalBatches,
                    receivedCount = 0
                }
            end
            
            local batchCollection = WLR_ClientSync.Data.chunkStatusBatches[batchId]
            
            -- Store this batch's chunks
            for chunkKey, chunkData in pairs(chunks) do
                batchCollection.chunks[chunkKey] = chunkData
            end
            
            -- Mark this batch as received
            batchCollection.receivedBatches[currentBatch] = true
            
            -- Update timeout tracking
            if WLR_ClientSync.Data.batchTimeouts[batchId] then
                WLR_ClientSync.Data.batchTimeouts[batchId].receivedCount = WLR_ClientSync.Data.batchTimeouts[batchId].receivedCount + 1
            end
            
            -- Check if we have all batches
            local receivedCount = 0
            for i = 1, totalBatches do
                if batchCollection.receivedBatches[i] then
                    receivedCount = receivedCount + 1
                end
            end
            
            if receivedCount == totalBatches then
                -- All batches received, update the main chunk status
                WLR_ClientSync.Data.chunkStatus = batchCollection.chunks
                WLR_ClientSync.Data.lastUpdate = getTimestamp()
                
                -- Clean up batch collection and timeout tracking
                WLR_ClientSync.Data.chunkStatusBatches[batchId] = nil
                WLR_ClientSync.Data.batchTimeouts[batchId] = nil
                
                print("WLR_ClientSync: Completed chunk status update from " .. totalBatches .. " batches (" .. receivedCount .. " chunks total)")
                
                -- Trigger event for GUI updates
                triggerEvent("WLR_ChunkStatusUpdated", WLR_ClientSync.Data.chunkStatus)
            else
                print("WLR_ClientSync: Waiting for more batches (" .. receivedCount .. "/" .. totalBatches .. " received)")
            end
        else
            -- Legacy single message (fallback)
            WLR_ClientSync.Data.chunkStatus = args
            WLR_ClientSync.Data.lastUpdate = getTimestamp()
            print("WLR_ClientSync: Received chunk status update (legacy format)")
            
            -- Trigger event for GUI updates
            triggerEvent("WLR_ChunkStatusUpdated", args)
        end
        
    elseif command == WLR_NetworkConstants.Messages.CONFIG_RELOAD then
        if args.success then
            print("WLR_ClientSync: Configuration reloaded successfully")
            -- Request updated zone definitions only
            WLR_ClientSync.RequestZoneDefinitions()
            -- Chunk status must be requested manually
        else
            print("WLR_ClientSync: Configuration reload failed - " .. (args.error or "Unknown error"))
        end
        
        -- Trigger event for GUI updates
        triggerEvent("WLR_ConfigReloadResponse", args)
        
    elseif command == WLR_NetworkConstants.Messages.FORCE_RESPAWN then
        if args.success then
            print("WLR_ClientSync: Force respawn successful for chunk " .. args.chunkKey)
        else
            print("WLR_ClientSync: Force respawn failed for chunk " .. (args.chunkKey or "unknown") .. " - " .. (args.error or "Unknown error"))
        end
        
        -- Trigger event for GUI updates
        triggerEvent("WLR_ForceRespawnResponse", args)
        
    elseif command == WLR_NetworkConstants.Messages.ZONE_OPERATION then
        if args.success then
            local operation = args.operation or "unknown"
            if operation == "createZone" then
                print("WLR_ClientSync: Zone created successfully: " .. (args.zoneId or "unknown"))
                -- Request updated zone definitions
                WLR_ClientSync.RequestZoneDefinitions()
            elseif operation == "updateZone" then
                print("WLR_ClientSync: Zone updated successfully: " .. (args.zoneId or "unknown"))
                -- Request updated zone definitions
                WLR_ClientSync.RequestZoneDefinitions()
            elseif operation == "deleteZone" then
                print("WLR_ClientSync: Zone deleted successfully: " .. (args.zoneId or "unknown"))
                -- Request updated zone definitions only
                WLR_ClientSync.RequestZoneDefinitions()
                -- Chunk status must be requested manually
            elseif operation == "respawnAllReady" then
                print("WLR_ClientSync: Respawned " .. (args.count or 0) .. " ready chunks")
                -- Chunk status must be requested manually
            elseif operation == "respawnAllReadyInZone" then
                print("WLR_ClientSync: Respawned " .. (args.count or 0) .. " ready chunks in zone " .. (args.zoneId or "unknown"))
                -- Chunk status must be requested manually
            end
        else
            print("WLR_ClientSync: Zone operation failed (" .. (args.operation or "unknown") .. ") - " .. (args.error or "Unknown error"))
        end
        
        -- Trigger event for GUI updates
        triggerEvent("WLR_ZoneOperationResponse", args)
    end
end)


WL_PlayerReady.Add(function(player)
    -- Initialize client sync when player is ready
    if not WLR_ClientSync.Data.isInitialized then
        WLR_ClientSync.Init()
    end
end)

-- Re-request data when player gains admin privileges (if applicable)
-- Also perform periodic cleanup of expired batches
local lastCleanupTime = 0
local didRequest = false
Events.OnPlayerUpdate.Add(function()
    if WLR_ClientSync.Data.isInitialized then
        if isAdmin() then
            -- Check if we need to request initial zone definitions (in case player just became admin)
            if not WLR_ClientSync.Data.receivedData and not didRequest then
                WLR_ClientSync.RequestZoneDefinitions()
                didRequest = true
                -- Chunk status must be requested manually
            end
        else
            -- If player is no longer admin, clear data
            WLR_ClientSync.Data.zoneDefinitions = {}
            WLR_ClientSync.Data.chunkStatus = {}
            WLR_ClientSync.Data.receivedData = false
            -- Also clear any pending batches
            WLR_ClientSync.Data.chunkStatusBatches = {}
            WLR_ClientSync.Data.batchTimeouts = {}
        end
        
        -- Periodic cleanup of expired batches (every 10 seconds)
        local currentTime = getTimestamp()
        if currentTime - lastCleanupTime > 10 then
            WLR_ClientSync.CleanupExpiredBatches()
            lastCleanupTime = currentTime
        end
    end
end)