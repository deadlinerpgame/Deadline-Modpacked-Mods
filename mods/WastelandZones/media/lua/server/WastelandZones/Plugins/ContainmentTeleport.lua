---@class WastelandZones.Classes.ContainmentTeleport: WastelandZones.Classes.Plugin
local ContainmentTeleport = WastelandZones.Classes.ContainmentTeleport or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.ContainmentTeleport")
if not WastelandZones.Classes.ContainmentTeleport then
    WastelandZones.Classes.ContainmentTeleport = ContainmentTeleport
end

local function toInt(value, fallback)
    local n = tonumber(value)
    if not n then return fallback or 0 end
    return math.floor(n)
end

---@return WastelandZones.Classes.ContainmentTeleport
function ContainmentTeleport:new()
    local o = ContainmentTeleport.parentClass.new(self)
    o.type = "ContainmentTeleport"
    o.priority = 20
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function ContainmentTeleport:buildPanel(zone, panel, data)
    local tickBoxOptions = {
        "Jail containment",
        "Teleport while inside",
        "Staff bypass"
    }

    local tickBoxState = {
        data.jailEnabled == true,
        data.teleportEnabled == true,
        data.staffBypass ~= false
    }

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 8, margin = {10, 20, 10, 10}, rows = {
        { type = "tickbox", id = "tickboxes", width = "inherit", height = 18 * 3, options = tickBoxOptions, selected = tickBoxState },
        { type = "label", id = "teleportPointLabel", width = "inherit", height = 18, text = "Teleport Point" },
        { type = "element", id = "teleportPointHost", width = "inherit", height = 48 }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.tickboxes = panel.elements.tickboxes
    panel.teleportPointLabel = panel.elements.teleportPointLabel

    local host = panel.elements.teleportPointHost
    local picker = panel.teleportPointInput
    if not picker then
        picker = WL_PointPicker:new(0, 0, host.width, host.height)
        picker:initialise()
        WL_PointPicker:addToolTip(picker, "Pick the coordinates players are teleported to while inside this zone.")
        host:addChild(picker)
        panel.teleportPointInput = picker
    elseif picker.parent ~= host then
        host:addChild(picker)
    end

    picker:setX(0)
    picker:setY(0)
    picker:setWidth(host.width)
    picker:setHeight(host.height)
    picker:setValue({ x = toInt(data.teleportX, 0), y = toInt(data.teleportY, 0), z = toInt(data.teleportZ, 0) })
end

---@param panel ISUIElement
---@return table
function ContainmentTeleport:getSaveData(panel)
    local teleportPoint = panel.teleportPointInput:getValue()
    return {
        jailEnabled = panel.elements.tickboxes:isSelected(1),
        teleportEnabled = panel.elements.tickboxes:isSelected(2),
        teleportX = toInt(teleportPoint.x, 0),
        teleportY = toInt(teleportPoint.y, 0),
        teleportZ = toInt(teleportPoint.z, 0),
        staffBypass = panel.elements.tickboxes:isSelected(3)
    }
end

---@param data table
---@return table
function ContainmentTeleport:serialize(data)
    local ret = {}
    if data.jailEnabled then ret.jailEnabled = true end
    if data.teleportEnabled then ret.teleportEnabled = true end
    if toInt(data.teleportX, 0) ~= 0 then ret.teleportX = toInt(data.teleportX, 0) end
    if toInt(data.teleportY, 0) ~= 0 then ret.teleportY = toInt(data.teleportY, 0) end
    if toInt(data.teleportZ, 0) ~= 0 then ret.teleportZ = toInt(data.teleportZ, 0) end
    if data.staffBypass == false then ret.staffBypass = false end
    return ret
end

---@param data table
---@return table
function ContainmentTeleport:deserialize(data)
    return {
        jailEnabled = data.jailEnabled == true,
        teleportEnabled = data.teleportEnabled == true,
        teleportX = toInt(data.teleportX, 0),
        teleportY = toInt(data.teleportY, 0),
        teleportZ = toInt(data.teleportZ, 0),
        staffBypass = data.staffBypass ~= false
    }
end

---@param player IsoPlayer
---@param data table
---@return boolean
function ContainmentTeleport:_isStaffBypassed(player, data)
    return data.staffBypass and WL_Utils.isStaff(player)
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function ContainmentTeleport:onPlayerInsideTick(zone, player, data)
    if not data.teleportEnabled then return end
    if self:_isStaffBypassed(player, data) then return end

    local tx = toInt(data.teleportX, 0)
    local ty = toInt(data.teleportY, 0)
    local tz = toInt(data.teleportZ, 0)
    local px = math.floor(player:getX())
    local py = math.floor(player:getY())
    local pz = math.floor(player:getZ())

    if px == tx and py == ty and pz == tz then
        return
    end

    WL_Utils.teleportPlayerToCoords(player, tx, ty, tz)
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function ContainmentTeleport:onPlayerExit(zone, player, data)
    if not data.jailEnabled then return end
    if self:_isStaffBypassed(player, data) then return end

    local x, y, z = zone:findNearestPointInsideFromPlayer(player)
    WL_Utils.teleportPlayerToCoords(player, x, y, z)
end

WastelandZones.Plugins:register(ContainmentTeleport:new())
