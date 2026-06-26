if isServer() then return end

-- Main initialization file for WLR Map Overlay System
-- This file ensures proper loading order and integration of all map components

require "WLR_ClientSync"
require "WLR_MapOverlay"
require "WLR_MapControls"

-- Initialize the WLR Map System
WLR_MapSystem = WLR_MapSystem or {}

--- Initialize the map overlay system
function WLR_MapSystem.Init()
    print("WLR_MapSystem: Initializing map overlay system")
    
    -- Ensure client sync is initialized
    if not WLR_ClientSync.IsInitialized() then
        WLR_ClientSync.Init()
    end
    
    -- Set up event handlers for real-time updates
    WLR_MapSystem.SetupEventHandlers()
    
    print("WLR_MapSystem: Map overlay system initialized")
end

--- Set up event handlers for real-time map updates
function WLR_MapSystem.SetupEventHandlers()
    -- Handle zone definition updates
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "WLR_Auto" then return end
        
        if command == "zoneDefinitions" then
            WLR_MapSystem.OnZoneDefinitionsUpdated(args)
        elseif command == "chunkStatus" then
            WLR_MapSystem.OnChunkStatusUpdated(args)
        end
    end)
end

--- Handle zone definitions update
--- @param data table
function WLR_MapSystem.OnZoneDefinitionsUpdated(data)
    print("WLR_MapSystem: Zone definitions updated, refreshing map display")
    
    -- Trigger custom event for UI components
    triggerEvent("WLR_ZoneDefinitionsUpdated", data)
    
    -- Force map redraw
    WLR_MapSystem.RefreshMapDisplay()
end

--- Handle chunk status update
--- @param data table
function WLR_MapSystem.OnChunkStatusUpdated(data)
    print("WLR_MapSystem: Chunk status updated, refreshing map display")
    
    -- Trigger custom event for UI components
    triggerEvent("WLR_ChunkStatusUpdated", data)
    
    -- Force map redraw
    WLR_MapSystem.RefreshMapDisplay()
end

--- Force refresh of map display
function WLR_MapSystem.RefreshMapDisplay()
    local worldMap = WLR_MapSystem.GetWorldMap()
    if worldMap and worldMap:isVisible() then
        -- Force redraw by toggling visibility
        worldMap:setVisible(false)
        worldMap:setVisible(true)
    end
end

--- Get the current world map instance
--- @return ISWorldMap|nil
function WLR_MapSystem.GetWorldMap()
    return ISWorldMap_instance or nil
end

--- Check if the map overlay system is available for the current player
--- @return boolean
function WLR_MapSystem.IsAvailable()
    local player = getPlayer()
    return player and isAdmin() and WLR_ClientSync.IsInitialized()
end

--- Get current overlay settings
--- @return table|nil
function WLR_MapSystem.GetOverlaySettings()
    local worldMap = WLR_MapSystem.GetWorldMap()
    if worldMap and worldMap.wlrOverlaySettings then
        return worldMap.wlrOverlaySettings
    end
    return nil
end

--- Update overlay settings
--- @param settings table
function WLR_MapSystem.UpdateOverlaySettings(settings)
    local worldMap = WLR_MapSystem.GetWorldMap()
    if worldMap then
        worldMap.wlrOverlaySettings = worldMap.wlrOverlaySettings or {}
        for key, value in pairs(settings) do
            worldMap.wlrOverlaySettings[key] = value
        end
        WLR_MapSystem.RefreshMapDisplay()
    end
end

--- Debug function to print current system status
function WLR_MapSystem.PrintStatus()
    print("=== WLR Map System Status ===")
    print("Available: " .. tostring(WLR_MapSystem.IsAvailable()))
    print("Client Sync Initialized: " .. tostring(WLR_ClientSync.IsInitialized()))
    
    local player = getPlayer()
    if player then
        print("Player is Admin: " .. tostring(isAdmin()))
    end
    
    local zoneCount = 0
    local chunkCount = 0
    
    for _ in pairs(WLR_ClientSync.GetZoneDefinitions()) do
        zoneCount = zoneCount + 1
    end
    
    for _ in pairs(WLR_ClientSync.GetChunkStatus()) do
        chunkCount = chunkCount + 1
    end
    
    print("Zone Definitions: " .. zoneCount)
    print("Chunk Status Entries: " .. chunkCount)
    
    local settings = WLR_MapSystem.GetOverlaySettings()
    if settings then
        print("Overlay Settings:")
        for key, value in pairs(settings) do
            print("  " .. key .. ": " .. tostring(value))
        end
    else
        print("No overlay settings found")
    end
    print("=============================")
end

-- Initialize when player is fully connected
WL_PlayerReady.Add(function ()
    WLR_MapSystem.Init()
end)

-- Console command for debugging
if getDebug() then
    Events.OnKeyPressed.Add(function(key)
        -- Ctrl+Shift+L to print WLR map system status (debug only)
        if key == Keyboard.KEY_L and isCtrlKeyDown() and isShiftKeyDown() then
            WLR_MapSystem.PrintStatus()
        end
    end)
end