---@class WastelandZones.Classes.MessagingHints: WastelandZones.Classes.Plugin
local MessagingHints = WastelandZones.Classes.MessagingHints or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.MessagingHints")
if not WastelandZones.Classes.MessagingHints then
    WastelandZones.Classes.MessagingHints = MessagingHints
end
---@class WastelandZones.Classes.MessagingHintsWarning: WastelandZones.Classes.Plugin
local MessagingHintsWarning = WastelandZones.Classes.MessagingHintsWarning or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.MessagingHintsWarning")
if not WastelandZones.Classes.MessagingHintsWarning then
    WastelandZones.Classes.MessagingHintsWarning = MessagingHintsWarning
end

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ensureRuntime()
    WastelandZones.Runtime = WastelandZones.Runtime or {}
    WastelandZones.Runtime.playerZoneRpHints = WastelandZones.Runtime.playerZoneRpHints or {}
    return WastelandZones.Runtime.playerZoneRpHints
end

---@return WastelandZones.Classes.MessagingHints
function MessagingHints:new()
    local o = MessagingHints.parentClass.new(self)
    o.type = "MessagingHints"
    o.priority = 90
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function MessagingHints:buildPanel(zone, panel, data)
    -- local inCarsOptions = {
    --     "In car warning enabled (stored only)"
    -- }

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 4, margin = {10, 20, 10, 10}, rows = {
        { type = "label", id = "warningBufferLabel", width = "inherit", height = 18, text = "Warning buffer" },
        { type = "textbox", id = "warningBufferInput", width = "inherit", height = 24, text = tostring(tonumber(data.warningBuffer) or 0) },
        { type = "label", id = "warningMessageLabel", width = "inherit", height = 18, text = "Warning message (stored only)" },
        { type = "textbox", id = "warningMessageInput", width = "inherit", height = 24, text = tostring(data.warningMessage or "") },
        { type = "label", id = "enterMessageLabel", width = "inherit", height = 18, text = "Enter message" },
        { type = "textbox", id = "enterMessageInput", width = "inherit", height = 24, text = tostring(data.enterMessage or "") },
        { type = "label", id = "exitMessageLabel", width = "inherit", height = 18, text = "Exit message" },
        { type = "textbox", id = "exitMessageInput", width = "inherit", height = 24, text = tostring(data.exitMessage or "") },
        -- { type = "tickbox", id = "inCarsToggle", width = "inherit", height = 18, options = inCarsOptions, selected = { data.inCars == true } },
        -- { type = "label", id = "inCarsMessageLabel", width = "inherit", height = 18, text = "In car warning message (stored only)" },
        -- { type = "textbox", id = "inCarsMessageInput", width = "inherit", height = 24, text = tostring(data.inCarsMessage or "") },
        { type = "label", id = "rpTextLabel", width = "inherit", height = 18, text = "RP hint text" },
        { type = "textbox", id = "rpTextInput", width = "inherit", height = 40, multipleLine = true, maxLines = 4, text = tostring(data.rpText or "") }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)

    panel.warningBufferLabel = panel.elements.warningBufferLabel
    panel.warningBufferInput = panel.elements.warningBufferInput
    panel.warningMessageLabel = panel.elements.warningMessageLabel
    panel.warningMessageInput = panel.elements.warningMessageInput
    panel.enterMessageLabel = panel.elements.enterMessageLabel
    panel.enterMessageInput = panel.elements.enterMessageInput
    panel.exitMessageLabel = panel.elements.exitMessageLabel
    panel.exitMessageInput = panel.elements.exitMessageInput
    -- panel.inCarsToggle = panel.elements.inCarsToggle
    -- panel.inCarsMessageLabel = panel.elements.inCarsMessageLabel
    -- panel.inCarsMessageInput = panel.elements.inCarsMessageInput
    panel.rpTextLabel = panel.elements.rpTextLabel
    panel.rpTextInput = panel.elements.rpTextInput
end

---@param panel ISUIElement
---@return table
function MessagingHints:getSaveData(panel)
    return {
        warningBuffer = math.floor(tonumber(panel.warningBufferInput:getText()) or 0),
        warningMessage = trim(panel.warningMessageInput:getText()),
        enterMessage = trim(panel.enterMessageInput:getText()),
        exitMessage = trim(panel.exitMessageInput:getText()),
        -- inCars = panel.inCarsToggle:isSelected(1),
        -- inCarsMessage = trim(panel.inCarsMessageInput:getText()),
        rpText = trim(panel.rpTextInput:getText())
    }
end

---@param data table
---@return table
function MessagingHints:serialize(data)
    local ret = {}
    if (tonumber(data.warningBuffer) or 0) > 0 then ret.warningBuffer = math.floor(tonumber(data.warningBuffer) or 0) end
    if trim(data.warningMessage) ~= "" then ret.warningMessage = trim(data.warningMessage) end
    if trim(data.enterMessage) ~= "" then ret.enterMessage = trim(data.enterMessage) end
    if trim(data.exitMessage) ~= "" then ret.exitMessage = trim(data.exitMessage) end
    -- if data.inCars then ret.inCars = true end
    -- if trim(data.inCarsMessage) ~= "" then ret.inCarsMessage = trim(data.inCarsMessage) end
    if trim(data.rpText) ~= "" then ret.rpText = trim(data.rpText) end
    return ret
end

---@param data table
---@return table
function MessagingHints:deserialize(data)
    return {
        warningBuffer = math.floor(tonumber(data.warningBuffer) or 0),
        warningMessage = tostring(data.warningMessage or ""),
        enterMessage = tostring(data.enterMessage or ""),
        exitMessage = tostring(data.exitMessage or ""),
        -- inCars = data.inCars == true,
        -- inCarsMessage = tostring(data.inCarsMessage or ""),
        rpText = tostring(data.rpText or "")
    }
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param text string|nil
function MessagingHints:_setRpHint(zone, player, text)
    local all = ensureRuntime()
    local playerNum = player:getPlayerNum()
    all[playerNum] = all[playerNum] or {}
    if trim(text) == "" then
        all[playerNum][zone.id] = nil
    else
        all[playerNum][zone.id] = text
    end
end

---@param zone WastelandZones.Classes.Zone
---@param data table
function MessagingHints:onCreated(zone, data)
    if not isServer() and data and data.warningBuffer and data.warningBuffer > 0 then
        local warningZone = WastelandZones.Classes.Zone:temporary(
            zone.name .. " - Warning Buffer",
            zone:getExpandedAreasFast(data.warningBuffer),
            {
                MessagingHintsWarning = {
                    warningMessage = data.warningMessage
                }
            }
        )
        data.warningZoneId = warningZone.id
        WastelandZones.Zones:set(warningZone)
    end
end

---@param zone WastelandZones.Classes.Zone
---@param data table
function MessagingHints:onDestroyed(zone, data)
    if data and data.warningZoneId then
        WastelandZones.Zones:remove(data.warningZoneId)
    end
end

---@param oldZone WastelandZones.Classes.Zone|nil
---@param newZone WastelandZones.Classes.Zone
---@param oldData table|nil
---@param newData table
function MessagingHints:onRecreated(oldZone, newZone, oldData, newData)
    if oldData and oldData.warningZoneId then
        newData.warningZoneId = oldData.warningZoneId
    else
        self:onCreated(newZone, newData)
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function MessagingHints:onPlayerEnter(zone, player, data)
    if data.enterMessage and data.enterMessage ~= "" then
        player:addLineChatElement(data.enterMessage, 255, 0, 0)
    end
    self:_setRpHint(zone, player, data.rpText)
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function MessagingHints:onPlayerExit(zone, player, data)
    if data.exitMessage and data.exitMessage ~= "" then
        player:addLineChatElement(data.exitMessage, 255, 0, 0)
    end
    self:_setRpHint(zone, player, nil)
end

---@return WastelandZones.Classes.MessagingHintsWarning
function MessagingHintsWarning:new()
    local o = MessagingHintsWarning.parentClass.new(self)
    o.type = "MessagingHintsWarning"
    o.isEditable = false
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function MessagingHintsWarning:onPlayerEnter(zone, player, data)
    if data.warningMessage and data.warningMessage ~= "" then
        player:addLineChatElement(data.warningMessage, 255, 0, 0)
    end
end

WastelandZones.Plugins:register(MessagingHints:new())
WastelandZones.Plugins:register(MessagingHintsWarning:new())
