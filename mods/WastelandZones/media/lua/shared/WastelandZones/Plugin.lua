require("WLBaseObject")

---@class WastelandZones.Classes.Plugin: WLBaseObject
---@field type string
---@field isEditable boolean
---@field events table<string, boolean>
local Plugin = WastelandZones.Classes.Plugin or WLBaseObject:derive("WastelandZones.Classes.Plugin")
if not WastelandZones.Classes.Plugin then
    WastelandZones.Classes.Plugin = Plugin
end

local possibleEvents = {
    "onCreated",
    "onDestroyed",
    "onRecreated",
    "onPlayerEnter",
    "onPlayerExit",
    "onPlayerInsideTick",
    "onPlayerInsideOneSecond",
    "onPlayerInsideTenSeconds",
    "onPlayerInsideOneMinute",
    "onServerTick",
    "onServerZombieBatch"
}

---@return WastelandZones.Classes.Plugin
function Plugin:new()
    local o = Plugin.parentClass.new(self)
    o.type = "BasePlugin"
    o.isEditable = true
    o.events = {}
    
    -- autoregister events based on which functions are overridden
    for _, event in ipairs(possibleEvents) do
        o.events[event] = self[event] ~= Plugin[event]
    end
    
    return o
end

local function setElementEnabled(element, enabled)    
    if not element then
        print("No element provided to setElementEnabled")
        return
    end

    element.disabled = not enabled

    if element.setEnable then
        element:setEnable(enabled)
    end

    if element.setEditable then
        element:setEditable(enabled)
    end

    if element.disableOption and element.options then
        for k, v in pairs(element.options) do
            element:disableOption(v, not enabled)
        end
    end
end

local function setChildrenEnabledRecursive(parent, enabled)
    if not parent or not parent.children then
        return
    end

    for id, child in pairs(parent.children) do
        if child then
            setElementEnabled(child, enabled)
            if child.children then
                setChildrenEnabledRecursive(child, enabled)
            end
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement
---@param data table|nil
function Plugin:buildPanel(zone, panel, data) end

---@param panel ISUIElement
---@return table|nil
function Plugin:getSaveData(panel) end

---@param panel ISUIElement
function Plugin:disablePanel(panel)
    setChildrenEnabledRecursive(panel, false)
end
---@param panel ISUIElement
function Plugin:enablePanel(panel)
    setChildrenEnabledRecursive(panel, true)
end
---@param data table|nil
---@return table|nil
function Plugin:serialize(data) return data end

---@param data table|nil
---@return table|nil
function Plugin:deserialize(data) return data end

---@param zone WastelandZones.Classes.Zone|string
---@param functionName string
---@param args table|nil
function Plugin:sendCommandToServer(zone, functionName, args)
    local zoneId = zone
    if type(zone) == "table" then
        zoneId = zone.id
    end

    WastelandZones.Network:triggerZonePluginServer(zoneId, self.type, functionName, args)
end

---@param zone WastelandZones.Classes.Zone|string
---@param functionName string
---@param args table|nil
function Plugin:broadcastCommandToClients(zone, functionName, args)
    local zoneId = zone
    if type(zone) == "table" then
        zoneId = zone.id
    end

    WastelandZones.Network:triggerZonePlugin(zoneId, self.type, functionName, args)
end

---@param player IsoPlayer
---@param zone WastelandZones.Classes.Zone|string
---@param functionName string
---@param args table|nil
function Plugin:sendCommandToClient(player, zone, functionName, args)
    local zoneId = zone
    if type(zone) == "table" then
        zoneId = zone.id
    end

    WastelandZones.Network:triggerZonePluginForPlayer(player, zoneId, self.type, functionName, args)
end

---@param zone WastelandZones.Classes.Zone
---@param data table|nil
function Plugin:onCreated(zone, data) end

---@param zone WastelandZones.Classes.Zone
---@param data table|nil
function Plugin:onDestroyed(zone, data) end

---@param oldZone WastelandZones.Classes.Zone|nil
---@param newZone WastelandZones.Classes.Zone
---@param oldData table|nil
---@param newData table
function Plugin:onRecreated(oldZone, newZone, oldData, newData) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerEnter(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerExit(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerInsideTick(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerInsideOneSecond(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerInsideTenSeconds(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table|nil
function Plugin:onPlayerInsideOneMinute(zone, player, data) end

---@param zone WastelandZones.Classes.Zone
---@param data table|nil
---@param runtime table|nil
function Plugin:onServerTick(zone, data, runtime) end

---@param zone WastelandZones.Classes.Zone
---@param zombieBatch IsoZombie[]|table
---@param data table|nil
---@param runtime table|nil
function Plugin:onServerZombieBatch(zone, zombieBatch, data, runtime) end

--- EXAMPLE Client Command Handler (from client to server)
-- ---@param zone WastelandZones.Classes.Zone
-- ---@param player IsoPlayer
-- ---@param data table|nil The plugin data for this zone
-- ---@param args table|nil The args for the command
-- function Plugin:clientCommand(zone, player, data, args) end

--- EXAMPLE Server Command Handler (from server to client)
-- ---@param zone WastelandZones.Classes.Zone
-- ---@param data table|nil The plugin data for this zone
-- ---@param args table|nil The args for the command
-- function Plugin:serverCommand(zone, data, args) end
