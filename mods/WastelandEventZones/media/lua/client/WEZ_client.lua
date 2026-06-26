if not isClient() then return end

require "WEZ_EventZone"

local Commands = {}

local lastTry = 0
local didGetIntialZones = false

local function checkForInitialZones()
    if didGetIntialZones then
        Events.OnTick.Remove(checkForInitialZones);
        return
    end
    if getTimestampMs() - lastTry < 2000 then return end
    lastTry = getTimestampMs()
    sendClientCommand(getPlayer(), "WastelandEventZones", "GetZones", {})
end

local function processServerCommand(module, command, args)
    if module ~= "WastelandEventZones" then return end
    if not Commands[command] then return end
    Commands[command](args)
end

function Commands.SyncZone(args)
    if WEZ_EventZones[args.id] then
        local allValues = WEZ_EventZoneDefaults.getAllValues(args)
        for k,v in pairs(allValues) do
            WEZ_EventZones[args.id][k] = v
        end
    else
        WEZ_EventZones[args.id] = WEZ_EventZone:loadFrom(args)
    end
    -- Invalidate weather cache for this zone when it's updated
    if WEZ_MonitorPlayer and WEZ_MonitorPlayer.weatherApplied then
        WEZ_MonitorPlayer.weatherApplied[args.id] = nil
    end
    WEZ_UpdateZombieTrackZones()
end

function Commands.SyncZones(args)
    didGetIntialZones = true

    if args == nil then
        -- Clear weather overrides for all zones before clearing them
        if WEZ_MonitorPlayer then
            for id, zone in pairs(WEZ_EventZones) do
                -- If player was in this zone, clear weather overrides
                if WEZ_MonitorPlayer.zonesIn[id] then
                    local transitionTicks = zone.weatherTransitionTicks or 600
                    WL_WeatherOverride.UnsetAllOverrides("zone_" .. id, transitionTicks)
                    -- Show exit message if player was in the zone
                    local player = getPlayer()
                    if player then
                        WEZ_MonitorPlayer.showExitZone(player, zone)
                    end
                end
            end
            -- Clear all tracking data
            WEZ_MonitorPlayer.zonesIn = {}
            WEZ_MonitorPlayer.weatherApplied = {}
        end
        WEZ_EventZones = {}
        return
    end

    local seenZoneIds = {}
    for _, zone in pairs(args) do
        seenZoneIds[zone.id] = true
        if WEZ_EventZones[zone.id] then
            for k,v in pairs(zone) do
                WEZ_EventZones[zone.id][k] = v
            end
        else
            WEZ_EventZones[zone.id] = WEZ_EventZone:loadFrom(zone)
        end
        -- Invalidate weather cache for this zone when it's updated
        if WEZ_MonitorPlayer and WEZ_MonitorPlayer.weatherApplied then
            WEZ_MonitorPlayer.weatherApplied[zone.id] = nil
        end
    end
    for id, zone in pairs(WEZ_EventZones) do
        if not seenZoneIds[id] then
            -- Clear weather overrides for deleted zones
            if WEZ_MonitorPlayer then
                -- Clear weather cache
                if WEZ_MonitorPlayer.weatherApplied then
                    WEZ_MonitorPlayer.weatherApplied[id] = nil
                end
                -- If player was in this zone, clear weather overrides and remove from zonesIn
                if WEZ_MonitorPlayer.zonesIn[id] then
                    WEZ_MonitorPlayer.zonesIn[id] = nil
                    -- Clear weather overrides with the zone's transition time
                    local transitionTicks = zone.weatherTransitionTicks or 600
                    WL_WeatherOverride.UnsetAllOverrides("zone_" .. id, transitionTicks)
                    -- Show exit message if player was in the zone
                    local player = getPlayer()
                    if player then
                        WEZ_MonitorPlayer.showExitZone(player, zone)
                    end
                end
            end
            WEZ_EventZones[id].parentClass.delete(WEZ_EventZones[id]) -- TODO: Improve this API
            WEZ_EventZones[id] = nil
        end
    end
    WEZ_UpdateZombieTrackZones()
end

Events.OnServerCommand.Add(processServerCommand)
Events.OnInitWorld.Add(function()
    Events.OnTick.Add(checkForInitialZones)
end)
