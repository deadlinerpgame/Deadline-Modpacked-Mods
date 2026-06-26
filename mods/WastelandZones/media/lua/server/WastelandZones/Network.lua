require("WLBaseObject")

---@class WastelandZones.Classes.Network: WLBaseObject
---@field receivedInitialZones boolean|nil
local Network = WastelandZones.Classes.Network or WLBaseObject:derive("WastelandZones.Classes.Network")
if not WastelandZones.Classes.Network then
    WastelandZones.Classes.Network = Network
end

---@return WastelandZones.Classes.Network
function Network:new()
    local o = Network.parentClass.new(self)
    if not isClient() then
        Events.OnClientCommand.Add(function (module, command, player, args)
            if module == "WastelandZones" then
                o:_receiveClientCommand(player, command, args)
            end
        end)
    end
    if not isServer() then
        Events.OnServerCommand.Add(function (module, command, args)
            if module == "WastelandZones" then
                o:_receiveServerCommand(command, args)
            end
        end)
    end
    return o
end

-- Client Only Functions
if not isServer() then
    ---@param command string
    ---@param args table|nil
    function Network:_receiveServerCommand(command, args)
        if self["_" .. command] then
            self["_" .. command](self, args)
        else
            print("WastelandZones.Network: Unknown server command received - " .. tostring(command))
        end
    end

    ---@param player IsoPlayer|nil
    ---@param zone WastelandZones.Classes.Zone
    function Network:saveZone(player, zone)
        local data = zone:serialize()
        sendClientCommand(player, "WastelandZones", "saveZone", data)
    end

    ---@param player IsoPlayer|nil
    ---@param id string
    function Network:removeZone(player, id)
        sendClientCommand(player, "WastelandZones", "removeZone", { id = id })
    end

    ---@param player IsoPlayer|nil
    function Network:requestAllZones(player)
        sendClientCommand(player, "WastelandZones", "requestAllZones", {})
    end

    ---@param data table
    function Network:_transmitZone(data)
        local zone = WastelandZones.Classes.Zone:deserialize(data)
        WastelandZones.Zones:set(zone)
    end

    ---@param data {id:string}
    function Network:_transmitRemoval(data)
        WastelandZones.Zones:remove(data.id)
    end

    ---@param data {zones:table<string,table>}
    function Network:_transmitAllZonesTo(data)
        local count = 0
        if data.zones then
            for _,_ in pairs(data.zones) do
                count = count + 1
            end
        end
        print("[WastelandZones] Received " .. count .. " zones from server.")
        WastelandZones.Zones:bulkSet(data.zones)
        self.receivedInitialZones = true
    end

    ---@param data {zoneId:string,pluginType:string,functionName:string,args:table|nil}
    function Network:_zonePluginTrigger(data)
        local zone = WastelandZones.Zones:get(data.zoneId)
        local plugin = WastelandZones.Plugins:get(data.pluginType)
        local handler = plugin[data.functionName]
        local pluginData = zone.plugins[data.pluginType]
        handler(plugin, zone, pluginData, data.args)
    end

    ---@param zoneId string
    ---@param pluginType string
    ---@param functionName string
    ---@param args table|nil
    function Network:triggerZonePluginServer(zoneId, pluginType, functionName, args)
        sendClientCommand("WastelandZones", "zonePluginServerTrigger", {
            zoneId = tostring(zoneId or ""),
            pluginType = tostring(pluginType or ""),
            functionName = tostring(functionName or ""),
            args = args or {}
        })
    end
end

if not isClient() then
    -- Server Only Functions

    ---@param player IsoPlayer
    ---@param command string
    ---@param args table|nil
    function Network:_receiveClientCommand(player, command, args)
        if self["_" .. command] then
            self["_" .. command](self, player, args)
        else
            print("WastelandZones.Network: Unknown client command received - " .. tostring(command))
        end
    end

    ---@param zone WastelandZones.Classes.Zone
    function Network:transmitZone(zone)
        local data = zone:serialize()
        sendServerCommand("WastelandZones", "transmitZone", data)
    end

    ---@param id string
    function Network:transmitRemoval(id)
        sendServerCommand("WastelandZones", "transmitRemoval", { id = id })
    end

    ---@param player IsoPlayer
    function Network:transmitAllZonesTo(player)
        local zonesData = WastelandZones.Zones:getAllSerialized()
        sendServerCommand(player, "WastelandZones", "transmitAllZonesTo", { zones = zonesData })
    end

    ---@param zoneId string
    ---@param pluginType string
    ---@param functionName string
    ---@param args table|nil
    function Network:triggerZonePlugin(zoneId, pluginType, functionName, args)
        sendServerCommand("WastelandZones", "zonePluginTrigger", {
            zoneId = tostring(zoneId or ""),
            pluginType = tostring(pluginType or ""),
            functionName = tostring(functionName or ""),
            args = args or {}
        })
    end

    ---@param player IsoPlayer
    ---@param zoneId string
    ---@param pluginType string
    ---@param functionName string
    ---@param args table|nil
    function Network:triggerZonePluginForPlayer(player, zoneId, pluginType, functionName, args)
        if not player then
            return
        end

        sendServerCommand(player, "WastelandZones", "zonePluginTrigger", {
            zoneId = tostring(zoneId or ""),
            pluginType = tostring(pluginType or ""),
            functionName = tostring(functionName or ""),
            args = args or {}
        })
    end

    ---@param player IsoPlayer
    ---@param data {zoneId:string,pluginType:string,functionName:string,args:table|nil}
    function Network:_zonePluginServerTrigger(player, data)
        local zone = WastelandZones.Zones:get(data.zoneId)
        local plugin = WastelandZones.Plugins:get(data.pluginType)
        local handler = plugin[data.functionName]
        local pluginData = zone.plugins[data.pluginType]
        handler(plugin, zone, player, pluginData, data.args)
    end

    ---@param player IsoPlayer
    ---@param data table
    function Network:_saveZone(player, data)
        local zone = WastelandZones.Classes.Zone:deserialize(data)
        WastelandZones.Zones:set(zone)
        self:transmitZone(zone)
    end

    ---@param player IsoPlayer
    ---@param data {id:string}
    function Network:_removeZone(player, data)
        WastelandZones.Zones:remove(data.id)
        self:transmitRemoval(data.id)
    end

    ---@param player IsoPlayer
    function Network:_requestAllZones(player)
        self:transmitAllZonesTo(player)
    end
end
