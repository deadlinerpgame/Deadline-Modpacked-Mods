---@class WastelandZones.Classes.ProtectionRules: WastelandZones.Classes.Plugin
local ProtectionRules = WastelandZones.Classes.ProtectionRules or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.ProtectionRules")
if not WastelandZones.Classes.ProtectionRules then
    WastelandZones.Classes.ProtectionRules = ProtectionRules
end

local runtime = {
    healthEligible = {}
}

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

---@return WastelandZones.Classes.ProtectionRules
function ProtectionRules:new()
    local o = ProtectionRules.parentClass.new(self)
    o.type = "ProtectionRules"
    o.priority = 30
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function ProtectionRules:buildPanel(zone, panel, data)
    local tickBoxOptions = {
        "No damage mode",
        "Require healthy on enter",
        "Heal while inside"
    }

    local tickBoxState = {
        data.noDamage == true,
        data.requireHealthyOnEnter ~= false,
        data.healWhileInside ~= false
    }

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 4, margin = {10, 20, 10, 10}, rows = {
        { type = "tickbox", id = "tickboxes", width = "inherit", height = 18 * 3, options = tickBoxOptions, selected = tickBoxState },
        { type = "label", id = "injuredLabel", width = "inherit", height = 18, text = "Injured enter message" },
        { type = "textbox", id = "injuredInput", width = "inherit", height = 24, text = tostring(data.injuredEnterMessage or "Injured, Event zone will not protect") },
        { type = "label", id = "healthyLabel", width = "inherit", height = 18, text = "Healthy enter message" },
        { type = "textbox", id = "healthyInput", width = "inherit", height = 24, text = tostring(data.healthyEnterMessage or "No Damage Zone") }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.tickboxes = panel.elements.tickboxes
    panel.injuredLabel = panel.elements.injuredLabel
    panel.injuredInput = panel.elements.injuredInput
    panel.healthyLabel = panel.elements.healthyLabel
    panel.healthyInput = panel.elements.healthyInput
end

---@param panel ISUIElement|any
---@return table
function ProtectionRules:getSaveData(panel)
    return {
        noDamage = panel.tickboxes:isSelected(1),
        requireHealthyOnEnter = panel.tickboxes:isSelected(2),
        healWhileInside = panel.tickboxes:isSelected(3),
        injuredEnterMessage = trim(panel.injuredInput:getText()),
        healthyEnterMessage = trim(panel.healthyInput:getText())
    }
end

---@param data table
---@return table
function ProtectionRules:serialize(data)
    local ret = {}
    if data.noDamage then ret.noDamage = true end
    if data.requireHealthyOnEnter == false then ret.requireHealthyOnEnter = false end
    if data.healWhileInside == false then ret.healWhileInside = false end
    if trim(data.injuredEnterMessage) ~= "" and trim(data.injuredEnterMessage) ~= "Injured, Event zone will not protect" then
        ret.injuredEnterMessage = trim(data.injuredEnterMessage)
    end
    if trim(data.healthyEnterMessage) ~= "" and trim(data.healthyEnterMessage) ~= "No Damage Zone" then
        ret.healthyEnterMessage = trim(data.healthyEnterMessage)
    end
    return ret
end

---@param data table
---@return table
function ProtectionRules:deserialize(data)
    return {
        noDamage = data.noDamage == true,
        requireHealthyOnEnter = data.requireHealthyOnEnter ~= false,
        healWhileInside = data.healWhileInside ~= false,
        injuredEnterMessage = tostring(data.injuredEnterMessage or "Injured, Event zone will not protect"),
        healthyEnterMessage = tostring(data.healthyEnterMessage or "No Damage Zone")
    }
end

---@param player IsoPlayer
---@return boolean
function ProtectionRules:isHealthy(player)
    local bodyDamage = player:getBodyDamage()
    local bodyParts = bodyDamage and bodyDamage:getBodyParts()
    if not bodyParts then return true end

    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        if bodyPart and bodyPart:HasInjury() then
            return false
        end
    end
    return true
end

---@param player IsoPlayer
---@param zone WastelandZones.Classes.Zone
---@param eligible boolean
function ProtectionRules:setEligibility(player, zone, eligible)
    local playerNum = player:getPlayerNum()
    runtime.healthEligible[playerNum] = runtime.healthEligible[playerNum] or {}
    runtime.healthEligible[playerNum][zone.id] = eligible == true
end

---@param player IsoPlayer
---@param zone WastelandZones.Classes.Zone
---@return boolean
function ProtectionRules:getEligibility(player, zone)
    local playerMap = runtime.healthEligible[player:getPlayerNum()]
    if not playerMap then return false end
    return playerMap[zone.id] == true
end

---@param player IsoPlayer
---@param zone WastelandZones.Classes.Zone
function ProtectionRules:clearEligibility(player, zone)
    local playerNum = player:getPlayerNum()
    local playerMap = runtime.healthEligible[playerNum]
    if not playerMap then return end
    playerMap[zone.id] = nil
end

---@param player IsoPlayer
function ProtectionRules:restoreFullHealth(player)
    local bodyDamage = player:getBodyDamage()
    if not bodyDamage then return end
    bodyDamage:setOverallBodyHealth(100)

    local bodyParts = bodyDamage:getBodyParts()
    if not bodyParts then return end
    for i = 0, bodyParts:size() - 1 do
        local bodyPart = bodyParts:get(i)
        bodyPart:SetHealth(100)
        bodyPart:setBurnTime(0)
        bodyPart:SetBitten(false)
        bodyPart:setBleedingTime(0)
        bodyPart:setScratched(false, true)
        bodyPart:setScratchTime(0)
        bodyPart:setCut(false, true)
        bodyPart:setCutTime(0)
        bodyPart:setDeepWounded(false)
        bodyPart:setDeepWoundTime(0)
        bodyPart:setInfectedWound(false)
        bodyPart:SetInfected(false)
        bodyPart:setHaveBullet(false, 0)
        bodyPart:setHaveGlass(false)
        bodyPart:setFractureTime(0)
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function ProtectionRules:onPlayerEnter(zone, player, data)
    if not data.noDamage then return end

    local eligible = true
    if data.requireHealthyOnEnter then
        eligible = self:isHealthy(player)
    end
    self:setEligibility(player, zone, eligible)

    local note = eligible and (data.healthyEnterMessage or "No Damage Zone") or (data.injuredEnterMessage or "Injured, Event zone will not protect")
    if trim(note) ~= "" then
        if eligible then
            player:setHaloNote(note, 0, 255, 0, 60.0)
        else
            player:setHaloNote(note, 255, 0, 0, 60.0)
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function ProtectionRules:onPlayerInsideTick(zone, player, data)
    if not data.noDamage then return end
    if not data.healWhileInside then return end
    if not self:getEligibility(player, zone) then return end
    self:restoreFullHealth(player)
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function ProtectionRules:onPlayerExit(zone, player, data)
    self:clearEligibility(player, zone)
end

WastelandZones.Plugins:register(ProtectionRules:new())
