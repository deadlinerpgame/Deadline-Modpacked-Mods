require("WastelandZones/Network")
require("WastelandZones/RegisteredPlugins")
require("WastelandZones/RegisteredZones")
require("WastelandZones/Events")

if not WastelandZones.Plugins then
    WastelandZones.Plugins = WastelandZones.Classes.RegisteredPlugins:new()
end

if not WastelandZones.Zones then
    WastelandZones.Zones = WastelandZones.Classes.RegisteredZones:new()
end

if not WastelandZones.Network then
    WastelandZones.Network = WastelandZones.Classes.Network:new()
end

if not WastelandZones.Events then
    WastelandZones.Events = WastelandZones.Classes.Events:new()
end

-- Server Only Modules
if not isClient() then
    require("WastelandZones/Storage")
    require("WastelandZones/WEZMigrater")

    if not WastelandZones.WEZMigrater then
        WastelandZones.WEZMigrater = WastelandZones.Classes.WEZMigrater:new()
    end

    if not WastelandZones.Storage then
        WastelandZones.Storage = WastelandZones.Classes.Storage:new()
        Events.OnInitGlobalModData.Add(function()
            print("[WastelandZones] Loading zones from storage...")
            local data = WastelandZones.Storage:load()
            local count = 0
            if data then 
                for _,_ in pairs(data) do
                    count = count + 1
                end
            end
            print("[WastelandZones] Loaded " .. count .. " zones from storage")
            WastelandZones.Zones:bulkSet(data)
            WastelandZones.WEZMigrater:run()
        end)
    end
end

-- Client Only Modules
if not isServer() then
    local lastTry = 0
    local function getZonesRetry()
        if WastelandZones.Network.receivedInitialZones then
            print("[WastelandZones] Successfully received initial zones from server.")
            Events.OnTick.Remove(getZonesRetry)
        end
        
        if lastTry + 60000 < getTimestampMs() then
            lastTry = getTimestampMs()
            print("[WastelandZones] Requesting zones from server...")
            WastelandZones.Network:requestAllZones(getPlayer())
        end
    end
    
    Events.OnInitGlobalModData.Add(function()
        Events.OnTick.Add(getZonesRetry)
    end)


    function WastelandZones.debugPrint()
        local allZones = WastelandZones.Zones:getAll()
        print("WastelandZones - Current Zones:")
        for id, zone in pairs(allZones) do
            print("---------------------------")
            print(WL_Utils.tableToString(zone))
        end
    end
end
