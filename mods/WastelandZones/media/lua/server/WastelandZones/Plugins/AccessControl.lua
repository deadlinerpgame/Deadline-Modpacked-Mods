---@class WastelandZones.Classes.AccessControl: WastelandZones.Classes.Plugin
local AccessControl = WastelandZones.Classes.AccessControl or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.AccessControl")
if not WastelandZones.Classes.AccessControl then
    WastelandZones.Classes.AccessControl = AccessControl
end

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function splitCsv(value)
    local out = {}
    local src = tostring(value or "")
    for part in src:gmatch("([^,]+)") do
        local v = trim(part)
        if v ~= "" then
            out[#out + 1] = string.lower(v)
        end
    end
    return out
end

local function parseRequiredItemSpec(value)
    local spec = trim(value)
    if spec == "" then
        return nil, nil
    end

    local colon = string.find(spec, ":", 1, true)
    if not colon then
        return spec, nil
    end

    local fullType = trim(string.sub(spec, 1, colon - 1))
    local itemName = trim(string.sub(spec, colon + 1))

    if fullType == "" then
        return nil, nil
    end

    if itemName == "" then
        itemName = nil
    end

    return fullType, itemName
end

---@return WastelandZones.Classes.AccessControl
function AccessControl:new()
    local o = AccessControl.parentClass.new(self)
    o.type = "AccessControl"
    o.priority = 10
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function AccessControl:buildPanel(zone, panel, data)
    local options = {
        "Staff Only",
        "Gate by Player",
        "Gate by Item",
        "Block by Item"
    }

    local tickboxValues = {
        data.staffOnly == true,
        data.gateByPlayerName == true,
        data.gateByItem == true,
        data.blockByItem == true
    }

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 8, margin = {10, 20, 10, 10}, rows = {
        { type = "tickbox", id = "tickboxes", width = "inherit", height = 18*(#options), options = options, selected = tickboxValues },
        { type = "columns", width = "inherit", height = 20, columns = {
            {type = "label", width = "30%", text = "Allowed names"},
            {type = "textbox", id = "allowedNamesCsv", width = "70%", text = tostring(data.allowedNamesCsv or "")}
        }},
        { type = "columns", width = "inherit", height = 20, columns = {
            {type = "label", width = "30%", text = "Required item full type"},
            {type = "textbox", id = "requiredItemFullType", width = "70%", text = tostring(data.requiredItemFullType or "")}
        }},
        { type = "columns", width = "inherit", height = 20, columns = {
            {type = "label", width = "30%", text = "Blocked items"},
            {type = "textbox", id = "blockedItemSpecsCsv", width = "70%", text = tostring(data.blockedItemSpecsCsv or "")}
        }},
        { type = "columns", width = "inherit", height = 20, columns = {
            {type = "label", width = "30%", text = "Deny message"},
            {type = "textbox", id = "denyMessage", width = "70%", text = tostring(data.denyMessage or "You are not allowed in this zone")}
        }}
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)

end

---@param panel ISUIElement
---@return table
function AccessControl:getSaveData(panel)
    return {
        staffOnly = panel.elements.tickboxes:isSelected(1),
        gateByPlayerName = panel.elements.tickboxes:isSelected(2),
        allowedNamesCsv = trim(panel.elements.allowedNamesCsv:getText()),
        gateByItem = panel.elements.tickboxes:isSelected(3),
        blockByItem = panel.elements.tickboxes:isSelected(4),
        requiredItemFullType = trim(panel.elements.requiredItemFullType:getText()),
        blockedItemSpecsCsv = trim(panel.elements.blockedItemSpecsCsv:getText()),
        denyMessage = trim(panel.elements.denyMessage:getText())
    }
end

---@param data table
---@return table
function AccessControl:serialize(data)
    local ret = {}
    if data.staffOnly then ret.staffOnly = true end
    if data.gateByPlayerName then ret.gateByPlayerName = true end
    if trim(data.allowedNamesCsv) ~= "" then ret.allowedNamesCsv = trim(data.allowedNamesCsv) end
    if data.gateByItem then ret.gateByItem = true end
    if data.blockByItem then ret.blockByItem = true end
    if trim(data.requiredItemFullType) ~= "" then ret.requiredItemFullType = trim(data.requiredItemFullType) end
    if trim(data.blockedItemSpecsCsv) ~= "" then ret.blockedItemSpecsCsv = trim(data.blockedItemSpecsCsv) end
    if trim(data.denyMessage) ~= "" and trim(data.denyMessage) ~= "You are not allowed in this zone" then
        ret.denyMessage = trim(data.denyMessage)
    end
    return ret
end

---@param data table
---@return table
function AccessControl:deserialize(data)
    return {
        staffOnly = data.staffOnly == true,
        gateByPlayerName = data.gateByPlayerName == true,
        allowedNamesCsv = tostring(data.allowedNamesCsv or ""),
        gateByItem = data.gateByItem == true,
        blockByItem = data.blockByItem == true,
        requiredItemFullType = tostring(data.requiredItemFullType or ""),
        blockedItemSpecsCsv = tostring(data.blockedItemSpecsCsv or ""),
        denyMessage = tostring(data.denyMessage or "You are not allowed in this zone")
    }
end

---@param player IsoPlayer
---@param requiredItemSpec string
---@return boolean
function AccessControl:_playerHasRequiredItem(player, requiredItemSpec)
    local wantedFullType, wantedName = parseRequiredItemSpec(requiredItemSpec)
    if not wantedFullType then return false end

    local inv = player:getInventory()

    if wantedName then
        local wantedNameLower = string.lower(wantedName)
        if inv:containsEvalRecurse(function(item)
            if item:getFullType() ~= wantedFullType then
                return false
            end

            return string.lower(trim(item:getName())) == wantedNameLower
        end) then
            return true
        end

        return false
    end

    if inv:containsTypeRecurse(wantedFullType) then
        return true
    end

    return false
end

---@param player IsoPlayer
---@param blockedItemSpecsCsv string
---@return boolean
function AccessControl:_playerHasAnyBlockedItem(player, blockedItemSpecsCsv)
    local src = tostring(blockedItemSpecsCsv or "")
    for part in src:gmatch("([^,]+)") do
        local spec = trim(part)
        if spec ~= "" and self:_playerHasRequiredItem(player, spec) then
            return true
        end
    end

    return false
end

---@param player IsoPlayer
---@param data table
---@return boolean, string|nil
function AccessControl:isPlayerAllowed(player, data)
    if not player then
        return false, "Not allowed"
    end

    if WL_Utils.isStaff(player) then
        return true, nil
    end 

    if data.staffOnly and not WL_Utils.isStaff(player) then
        return false, trim(data.denyMessage) ~= "" and data.denyMessage or "Staff only"
    end

    if data.gateByPlayerName then
        local allowed = splitCsv(data.allowedNamesCsv)
        local hasAny = #allowed > 0
        local nameSet = {}
        for i = 1, #allowed do
            nameSet[allowed[i]] = true
        end

        local user = string.lower(trim(player:getUsername()))
        local display = string.lower(trim(player:getDisplayName()))
        if hasAny and (not nameSet[user]) and (not nameSet[display]) then
            return false, trim(data.denyMessage) ~= "" and data.denyMessage or "Name not allowed"
        end
    end

    if data.blockByItem then
        local blockedSpecs = trim(data.blockedItemSpecsCsv)
        if blockedSpecs ~= "" and self:_playerHasAnyBlockedItem(player, blockedSpecs) then
            return false, trim(data.denyMessage) ~= "" and data.denyMessage or "Blocked item present"
        end
    end

    if data.gateByItem then
        local requiredSpec = trim(data.requiredItemFullType)
        if requiredSpec ~= "" and not self:_playerHasRequiredItem(player, requiredSpec) then
            return false, trim(data.denyMessage) ~= "" and data.denyMessage or "Required item missing"
        end
    end

    return true, nil
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function AccessControl:onPlayerEnter(zone, player, data)
    local allowed, reason = self:isPlayerAllowed(player, data)
    if allowed then return end

    local x, y, z = zone:findNearestPointOutsideFromPlayer(player)
    WL_Utils.teleportPlayerToCoords(player, x, y, z)

    local note = reason or data.denyMessage or "Not allowed"
    player:setHaloNote(note, 255, 0, 0, 60.0)
end

WastelandZones.Plugins:register(AccessControl:new())
