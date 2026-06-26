---@class WAT_BasementZoneManager
--- Manages basement data, teleport zones, and voice portals on the client side
WAT_BasementZoneManager = WAT_BasementZoneManager or {
    basementsData = {},
    tps = {},
    voicePortals = {},
    gridConfig = {
        startX = 10000,
        startY = 10000,
        spacingX = 50,
        spacingY = 50,
        maxX = 20,
        maxY = 20
    },
    initialized = false
}

--- Performs instant teleport when player enters a zone
--- @param self table The zone object
--- @param player IsoPlayer The player entering the zone
local function doInstantTp(self, player)
    -- Check safehouse permissions if needed
    if self.checkForSH then
        -- Check WastelandSafezone permissions
        if WSZ_Client then
            local x, y, z = player:getX(), player:getY(), player:getZ()
            local perms = WSZ_Client.getPermissionsAt(x, y, z)
            if perms and not perms.canViewItems then
                return
            end
        end
        -- Check vanilla safehouse permissions
        local sh = SafeHouse.getSafeHouse(player:getSquare())
        if sh and not sh:playerAllowed(player) and not WL_Utils.isStaff(player) then
            return
        end
    end
    WL_Utils.teleportPlayerToCoords(player, self.tpTo.x, self.tpTo.y, self.tpTo.z)
end

--- Updates all teleport zones based on current basement data
function WAT_BasementZoneManager.updateTeleports()
    for k, v in pairs(WAT_BasementZoneManager.basementsData) do
        -- Remove existing zones for this basement
        if WAT_BasementZoneManager.tps[k] then
            WL_TriggerZones.removeZone(WAT_BasementZoneManager.tps[k][1])
            WAT_BasementZoneManager.tps[k][1]:delete()
            WL_TriggerZones.removeZone(WAT_BasementZoneManager.tps[k][2])
            WAT_BasementZoneManager.tps[k][2]:delete()
            WAT_BasementZoneManager.tps[k] = nil
        end

        -- Remove existing voice portal for this basement
        if WAT_BasementZoneManager.voicePortals[k] then
            WAT_BasementZoneManager.voicePortals[k].unregister()
            WAT_BasementZoneManager.voicePortals[k] = nil
        end

        -- Create zone 1: House entrance -> Basement arrival
        -- outX1/Y1/Z1 = where player steps to go IN (house side)
        -- inX1/Y1/Z1 = where player appears IN basement
        local zone1 = WL_Zone:new(v.outX1, v.outY1, v.outZ1, v.outX1, v.outY1, v.outZ1)
        zone1.mapDisabled = not getDebug()
        zone1.allowGods = true
        zone1.checkForSH = true
        zone1.tpTo = {x = v.inX1, y = v.inY1, z = v.inZ1}
        zone1.onPlayerEnteredZone = doInstantTp

        -- Create zone 2: Basement exit -> House arrival
        -- outX2/Y2/Z2 = where player steps to go OUT (basement side)
        -- inX2/Y2/Z2 = where player appears back in house
        local zone2 = WL_Zone:new(v.outX2, v.outY2, v.outZ2, v.outX2, v.outY2, v.outZ2)
        zone2.mapDisabled = not getDebug()
        zone2.allowGods = true
        zone2.checkForSH = false
        zone2.tpTo = {x = v.inX2, y = v.inY2, z = v.inZ2}
        zone2.onPlayerEnteredZone = doInstantTp

        -- Register zones
        WL_TriggerZones.addZone(zone1)
        WL_TriggerZones.addZone(zone2)

        -- Create voice portal for communication between house and basement
        if WRC_VoicePortal then
            local voicePortal = WRC_VoicePortal:register(
                {x = v.outX1, y = v.outY1, z = v.outZ1},
                {x = v.inX1,  y = v.inY1,  z = v.inZ1},
                {
                    loud = "You hear loud chatter from above.",
                    shout = "You hear shouting from above."
                },
                {
                    loud = "You hear loud chatter from below.",
                    shout = "You hear shouting from below."
                }
            )
            WAT_BasementZoneManager.voicePortals[k] = voicePortal
        end

        WAT_BasementZoneManager.tps[k] = {zone1, zone2}
    end

    -- Clean up zones for basements that no longer exist
    for k, _ in pairs(WAT_BasementZoneManager.tps) do
        if not WAT_BasementZoneManager.basementsData[k] then
            for _, zone in pairs(WAT_BasementZoneManager.tps[k]) do
                WL_TriggerZones.removeZone(zone)
                zone:delete()
            end
            WAT_BasementZoneManager.tps[k] = nil
        end
    end

    -- Clean up voice portals for basements that no longer exist
    for k, _ in pairs(WAT_BasementZoneManager.voicePortals) do
        if not WAT_BasementZoneManager.basementsData[k] then
            WAT_BasementZoneManager.voicePortals[k].unregister()
            WAT_BasementZoneManager.voicePortals[k] = nil
        end
    end
end

--- Removes a basement by key
--- @param key string The basement key (e.g., "0,0")
function WAT_BasementZoneManager.removeBasement(key)
    sendClientCommand(getPlayer(), 'WAT', 'removeBasement', {key = key})
end

--- Gets a basement by key
--- @param key string The basement key
--- @return table|nil The basement data or nil if not found
function WAT_BasementZoneManager.getBasement(key)
    return WAT_BasementZoneManager.basementsData[key]
end

--- Gets all basements
--- @return table The basements data table
function WAT_BasementZoneManager.getAllBasements()
    return WAT_BasementZoneManager.basementsData
end

--- Gets basements near a position
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param distance number Maximum distance
--- @return table Array of nearby basements
function WAT_BasementZoneManager.getBasementsNear(x, y, distance)
    local nearby = {}
    for key, basement in pairs(WAT_BasementZoneManager.basementsData) do
        -- Check distance to entrance
        local dx1 = basement.outX1 - x
        local dy1 = basement.outY1 - y
        local dist1 = math.sqrt(dx1 * dx1 + dy1 * dy1)

        -- Check distance to basement arrival
        local dx2 = basement.inX1 - x
        local dy2 = basement.inY1 - y
        local dist2 = math.sqrt(dx2 * dx2 + dy2 * dy2)

        if dist1 <= distance or dist2 <= distance then
            table.insert(nearby, basement)
        end
    end
    return nearby
end

--- Finds the next available grid position for a template
--- @param gridConfig table The grid configuration from a template
--- @return string|nil key The grid key (e.g., "0,0") or nil if no position available
--- @return table|nil position The world position {x, y} or nil if no position available
function WAT_BasementZoneManager.findNextGridPosition(gridConfig)
    if not gridConfig then return nil, nil end

    for y = 0, (gridConfig.maxY or 20) - 1 do
        for x = 0, (gridConfig.maxX or 20) - 1 do
            local key = x .. "," .. y
            if not WAT_BasementZoneManager.basementsData[key] then
                local rx = (gridConfig.startX or 10000) + (x * (gridConfig.spacingX or 50))
                local ry = (gridConfig.startY or 10000) + (y * (gridConfig.spacingY or 50))
                return key, {x = rx, y = ry}
            end
        end
    end

    return nil, nil
end

--- Gets the current global grid configuration
--- @return table The grid configuration
function WAT_BasementZoneManager.getGridConfig()
    return WAT_BasementZoneManager.gridConfig
end

--- Updates the global grid configuration
--- @param gridConfig table The new grid configuration
function WAT_BasementZoneManager.setGridConfig(gridConfig)
    if gridConfig then
        WAT_BasementZoneManager.gridConfig = gridConfig
    end
end

--- Requests the grid configuration from the server
function WAT_BasementZoneManager.requestGridConfig()
    sendClientCommand(getPlayer(), "WAT", "requestGridConfig", {})
end

-- Initialize event handlers
if not WAT_BasementZoneManager.initialized then
    -- Request basement data when global mod data is initialized
    Events.OnInitGlobalModData.Add(function()
        ModData.request("WAT_Basements")
    end)

    -- Handle receiving basement data from server
    Events.OnReceiveGlobalModData.Add(function(key, data)
        if key == "WAT_Basements" then
            WAT_BasementZoneManager.basementsData = data or {}
            WAT_BasementZoneManager.updateTeleports()
        end
    end)

    -- Handle receiving grid config from server
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "WAT" then return end
        
        if command == "gridConfigData" and args.gridConfig then
            WAT_BasementZoneManager.setGridConfig(args.gridConfig)
        end
    end)

    WAT_BasementZoneManager.initialized = true
end