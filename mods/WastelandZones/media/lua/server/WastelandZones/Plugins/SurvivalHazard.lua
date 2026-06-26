---@class WastelandZones.Classes.SurvivalHazard: WastelandZones.Classes.Plugin
local SurvivalHazard = WastelandZones.Classes.SurvivalHazard or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.SurvivalHazard")
if not WastelandZones.Classes.SurvivalHazard then
    WastelandZones.Classes.SurvivalHazard = SurvivalHazard
end

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function getWornItems(player)
    local worn = {}
    local inv = player:getInventory()
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if player:isEquippedClothing(item) then
            worn[#worn + 1] = item:getFullType()
        end
    end
    return worn
end

---@return WastelandZones.Classes.SurvivalHazard
function SurvivalHazard:new()
    local o = SurvivalHazard.parentClass.new(self)
    o.type = "SurvivalHazard"
    o.priority = 40
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function SurvivalHazard:buildPanel(zone, panel, data)
    local maskOptions = {
        "Gas mask hazmat immunity"
    }

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 4, margin = {10, 20, 10, 10}, rows = {
        { type = "label", id = "damageRateLabel", width = "inherit", height = 18, text = "Damage rate" },
        { type = "textbox", id = "damageRateInput", width = "inherit", height = 24, text = tostring(tonumber(data.damageRate) or 0) },
        { type = "tickbox", id = "maskTick", width = "inherit", height = 18, options = maskOptions, selected = { data.damagePreventMaskToggle == true } },
        { type = "label", id = "itemsLabel", width = "inherit", height = 18, text = "Damage prevent items (; separated full types)" },
        { type = "textbox", id = "itemsInput", width = "inherit", height = 24, text = tostring(data.damagePreventItems or "") }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.damageRateLabel = panel.elements.damageRateLabel
    panel.damageRateInput = panel.elements.damageRateInput
    panel.maskTick = panel.elements.maskTick
    panel.itemsLabel = panel.elements.itemsLabel
    panel.itemsInput = panel.elements.itemsInput
end

---@param panel ISUIElement
---@return table
function SurvivalHazard:getSaveData(panel)
    return {
        damageRate = tonumber(panel.damageRateInput:getText()) or 0,
        damagePreventMaskToggle = panel.maskTick:isSelected(1),
        damagePreventItems = trim(panel.itemsInput:getText())
    }
end

---@param data table
---@return table
function SurvivalHazard:serialize(data)
    local ret = {}
    if (tonumber(data.damageRate) or 0) > 0 then ret.damageRate = tonumber(data.damageRate) or 0 end
    if data.damagePreventMaskToggle then ret.damagePreventMaskToggle = true end
    if trim(data.damagePreventItems) ~= "" then ret.damagePreventItems = trim(data.damagePreventItems) end
    return ret
end

---@param data table
---@return table
function SurvivalHazard:deserialize(data)
    return {
        damageRate = tonumber(data.damageRate) or 0,
        damagePreventMaskToggle = data.damagePreventMaskToggle == true,
        damagePreventItems = tostring(data.damagePreventItems or "")
    }
end

---@param player IsoPlayer
---@param data table
---@return boolean
function SurvivalHazard:hasPrevention(player, data)
    if data.damagePreventMaskToggle and WM_Utils.getEfficiency(player) >= 1 then
        return true
    end

    local items = {}
    for item in string.gmatch(tostring(data.damagePreventItems or ""), "([^;]+)") do
        local v = trim(item)
        if v ~= "" then
            items[#items + 1] = v
        end
    end

    if #items == 0 then
        return false
    end

    local wornItems = getWornItems(player)
    for i = 1, #items do
        for j = 1, #wornItems do
            if items[i] == wornItems[j] then
                return true
            end
        end
    end

    return false
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function SurvivalHazard:onPlayerInsideTick(zone, player, data)
    if (data.damageRate or 0) <= 0 then return end
    if self:hasPrevention(player, data) then return end
    player:getBodyDamage():ReduceGeneralHealth((data.damageRate or 0) / 100)
end

WastelandZones.Plugins:register(SurvivalHazard:new())
