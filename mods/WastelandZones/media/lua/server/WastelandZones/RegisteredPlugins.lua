require("WLBaseObject")

---@class WastelandZones.Classes.RegisteredPlugins: WLBaseObject
---@field plugins table<string, WastelandZones.Classes.Plugin>
local RegisteredPlugins = WastelandZones.Classes.RegisteredPlugins or WLBaseObject:derive("WastelandZones.Classes.RegisteredPlugins")
if not WastelandZones.Classes.RegisteredPlugins then
    WastelandZones.Classes.RegisteredPlugins = RegisteredPlugins
end

---@return WastelandZones.Classes.RegisteredPlugins
function RegisteredPlugins:new()
    local o = RegisteredPlugins.parentClass.new(self)
    o.plugins = {}
    return o
end

---@param plugin WastelandZones.Classes.Plugin
function RegisteredPlugins:register(plugin)
    self.plugins[plugin.type] = plugin
end

---@return table<string, WastelandZones.Classes.Plugin>
function RegisteredPlugins:getAll()
    return self.plugins
end

---@param type string
---@return WastelandZones.Classes.Plugin|any
function RegisteredPlugins:get(type)
    return self.plugins[type]
end
