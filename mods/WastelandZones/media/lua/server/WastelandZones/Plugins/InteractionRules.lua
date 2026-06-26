---@class WastelandZones.Classes.InteractionRules: WastelandZones.Classes.Plugin
local InteractionRules = WastelandZones.Classes.InteractionRules or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.InteractionRules")
if not WastelandZones.Classes.InteractionRules then
    WastelandZones.Classes.InteractionRules = InteractionRules
end

local runtime = {
    thumpChunksByZone = {}
}

---@param modId string
---@return boolean
local function isModActive(modId)
    local activated = getActivatedMods()
    return activated and activated:contains(modId)
end

---@param square IsoGridSquare|nil
local function topUpWaterOnSquare(square)
    if not square then return end
    local objects = square:getObjects()
    if not objects then return end

    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        local sprite = obj and obj:getSprite() or nil
        local props = sprite and sprite:getProperties() or nil
        local canBeFilled = (obj and obj:hasModData() and obj:getModData().canBeWaterPiped) or (props and props:Is(IsoFlagType.waterPiped))

        if canBeFilled then
            obj:setWaterAmount(obj:getWaterMax())
        end
    end
end

---@param x number
---@param y number
---@param z number
---@return table<string, WastelandZones.Classes.Zone>|nil
local function getZonesAt(x, y, z)
    local zonesRegistry = WastelandZones and WastelandZones.Zones
    if not zonesRegistry then
        return nil
    end

    return zonesRegistry:getAllAt(x, y, z)
end

---@param x number
---@param y number
---@param z number
---@param key string
---@return boolean
local function isInteractionRuleAt(x, y, z, key)
    local zones = getZonesAt(x, y, z)
    if not zones then
        return false
    end

    for _, zone in pairs(zones) do
        local pluginData = zone.plugins and zone.plugins.InteractionRules
        if pluginData and pluginData[key] == true then
            return true
        end
    end

    return false
end

---@return {key:string,label:string}[]
local function buildVisibleTickEntries()
    local entries = {
        { key = "noFishing", label = "No fishing" },
        { key = "noThump", label = "No thump" },
        { key = "unlimitedWater", label = "Unlimited water" }
    }

    if isModActive("WastelandRpChat") then
        entries[#entries + 1] = { key = "isQuiet", label = "Quiet RP chat" }
    end

    if isModActive("WastelandWorldSaver") then
        entries[#entries + 1] = { key = "noDeforest", label = "No deforest" }
        entries[#entries + 1] = { key = "noBuild", label = "No build" }
        entries[#entries + 1] = { key = "noPickup", label = "No pickup" }
        entries[#entries + 1] = { key = "isScrapZone", label = "Scrap zone" }
    end

    if isModActive("WastelandSkillKeeper") then
        entries[#entries + 1] = { key = "freeDeathZone", label = "Free death zone" }
    end

    if isModActive("WastelandContainerLocks") then
        entries[#entries + 1] = { key = "lockedMannequins", label = "Locked mannequins" }
    end

    return entries
end

---@param x number
---@param y number
---@param z number
---@param key string
---@return boolean
function InteractionRules.getIsInteractionRuleZone(x, y, z, key)
    return isInteractionRuleAt(x, y, z, key)
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsNoDeforestZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "noDeforest")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsNoBuildZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "noBuild")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsNoPickupZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "noPickup")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsLockedMannequinsZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "lockedMannequins")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsUnlimitedWaterZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "unlimitedWater")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsQuietZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "isQuiet")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsScrapZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "isScrapZone")
end

---@param x number
---@param y number
---@param z number
---@return boolean
function InteractionRules.getIsFreeDeathZone(x, y, z)
    return isInteractionRuleAt(x, y, z, "freeDeathZone")
end

---@return WastelandZones.Classes.InteractionRules
function InteractionRules:new()
    local o = InteractionRules.parentClass.new(self)
    o.type = "InteractionRules"
    o.priority = 70
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function InteractionRules:buildPanel(zone, panel, data)
    local normalizedData = self:deserialize(data or {})
    local entries = buildVisibleTickEntries()
    local tickBoxOptions = {}
    local tickBoxState = {}
    local tickBoxKeys = {}

    for i = 1, #entries do
        local entry = entries[i]
        tickBoxOptions[i] = entry.label
        tickBoxState[i] = normalizedData[entry.key] == true
        tickBoxKeys[i] = entry.key
    end

    panel.existingData = normalizedData
    panel.tickboxKeys = tickBoxKeys

    local tickBoxHeight = 18 * (#tickBoxOptions > 0 and #tickBoxOptions or 1)
    if #tickBoxOptions == 0 then
        tickBoxOptions = { "No interaction options available (missing related mods)" }
        tickBoxState = { false }
    end

    panel.layout = { type = "rows", width = "inherit", height = "auto", margin = {10, 20, 10, 10}, rows = {
        { type = "tickbox", id = "tickboxes", width = "inherit", height = tickBoxHeight, options = tickBoxOptions, selected = tickBoxState }
    }}
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.tickboxes = panel.elements.tickboxes
end

---@param panel ISUIElement
---@return table
function InteractionRules:getSaveData(panel)
    local existing = panel.existingData or {}
    local ret = {
        noFishing = existing.noFishing == true,
        noThump = existing.noThump == true,
        noDeforest = existing.noDeforest == true,
        noBuild = existing.noBuild == true,
        noPickup = existing.noPickup == true,
        lockedMannequins = existing.lockedMannequins == true,
        unlimitedWater = existing.unlimitedWater == true,
        isQuiet = existing.isQuiet == true,
        isScrapZone = existing.isScrapZone == true,
        freeDeathZone = existing.freeDeathZone == true
    }

    local keys = panel.tickboxKeys or {}
    for i = 1, #keys do
        ret[keys[i]] = panel.tickboxes:isSelected(i)
    end

    return ret
end

if not isServer() then
    Events.OnPreFillWorldObjectContextMenu.Add(function(playerIdx, context, worldObjects)
        if not worldObjects or #worldObjects == 0 then return end

        local square = worldObjects[1]:getSquare()
        if not square then return end

        local x = square:getX()
        local y = square:getY()
        local z = square:getZ()

        if not InteractionRules.getIsUnlimitedWaterZone(x, y, z) then return end
        topUpWaterOnSquare(square)
    end)
end

---@param data table
---@return table
function InteractionRules:deserialize(data)
    return {
        noFishing = data.noFishing == true,
        noThump = data.noThump == true,
        noDeforest = data.noDeforest == true,
        noBuild = data.noBuild == true,
        noPickup = data.noPickup == true,
        lockedMannequins = data.lockedMannequins == true,
        unlimitedWater = data.unlimitedWater == true,
        isQuiet = data.isQuiet == true,
        isScrapZone = data.isScrapZone == true,
        freeDeathZone = data.freeDeathZone == true
    }
end

---@param data table
---@return table
function InteractionRules:serialize(data)
    local ret = {}
    if data.noFishing then ret.noFishing = true end
    if data.noThump then ret.noThump = true end
    if data.noDeforest then ret.noDeforest = true end
    if data.noBuild then ret.noBuild = true end
    if data.noPickup then ret.noPickup = true end
    if data.lockedMannequins then ret.lockedMannequins = true end
    if data.unlimitedWater then ret.unlimitedWater = true end
    if data.isQuiet then ret.isQuiet = true end
    if data.isScrapZone then ret.isScrapZone = true end
    if data.freeDeathZone then ret.freeDeathZone = true end
    return ret
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param enabled boolean
function InteractionRules:_applyNoThumpToZone(zone, player, enabled)
    -- Lightweight local reconciliation: update thumpability of loaded IsoThumpable objects inside zone bounds.
    -- Limited to a chunk window around the triggering player; unloaded chunks and empty z-stacks are skipped.
    local bounds = zone and zone.bounds
    if not bounds or not player then return end

    local cell = getCell()
    if not cell then return end

    local CHUNK = 10
    local R = 7
    local px = math.floor(player:getX() / CHUNK)
    local py = math.floor(player:getY() / CHUNK)

    local boundsCxMin = math.floor(bounds.x1 / CHUNK)
    local boundsCxMax = math.floor(bounds.x2 / CHUNK)
    local boundsCyMin = math.floor(bounds.y1 / CHUNK)
    local boundsCyMax = math.floor(bounds.y2 / CHUNK)

    local cxMin = math.max(boundsCxMin, px - R)
    local cxMax = math.min(boundsCxMax, px + R)
    local cyMin = math.max(boundsCyMin, py - R)
    local cyMax = math.min(boundsCyMax, py + R)

    local bx1 = math.floor(bounds.x1)
    local bx2 = math.floor(bounds.x2)
    local by1 = math.floor(bounds.y1)
    local by2 = math.floor(bounds.y2)
    local zMin = math.floor(bounds.z1)
    local zMax = math.floor(bounds.z2)
    local canZSkip = (zMax - zMin) >= 2

    local touched = 0

    for cx = cxMin, cxMax do
        local chunkX0 = cx * CHUNK
        local x0 = chunkX0 > bx1 and chunkX0 or bx1
        local cxEnd = chunkX0 + CHUNK - 1
        local x1 = cxEnd < bx2 and cxEnd or bx2
        for cy = cyMin, cyMax do
            -- Corner probe at lowest z; if not loaded there, skip the whole 10x10 stack.
            local cornerLow = cell:getGridSquare(chunkX0, cy * CHUNK, 0)
            if cornerLow then
                local chunkY0 = cy * CHUNK
                local y0 = chunkY0 > by1 and chunkY0 or by1
                local cyEnd = chunkY0 + CHUNK - 1
                local y1 = cyEnd < by2 and cyEnd or by2

                for y = y0, y1 do
                    for x = x0, x1 do
                        local emptyStreak = 0
                        for z = zMin, zMax do
                            if canZSkip and emptyStreak >= 2 then break end
                            if zone:isPointIn(x, y, z) then
                                local square = cell:getGridSquare(x, y, z)
                                if square then
                                    local objects = square:getObjects()
                                    local n = objects:size()
                                    if n == 0 then
                                        emptyStreak = emptyStreak + 1
                                    else
                                        emptyStreak = 0
                                        for i = 0, n - 1 do
                                            local obj = objects:get(i)
                                            if obj and instanceof(obj, "IsoThumpable") then
                                                local isThumpable = obj:isThumpable()
                                                if enabled and isThumpable then
                                                    obj:setIsThumpable(false)
                                                elseif (not enabled) and (not isThumpable) then
                                                    obj:setIsThumpable(true)
                                                end
                                            end
                                        end
                                        touched = touched + 1
                                    end
                                else
                                    emptyStreak = emptyStreak + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    runtime.thumpChunksByZone[zone.id] = { touchedSquares = touched, state = enabled }
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function InteractionRules:onPlayerInsideTick(zone, player, data)
    if data.noFishing then
        local ui = ISFishingUI.instance and ISFishingUI.instance[player:getPlayerNum() + 1]
        if ui and ui:getIsVisible() then
            ui:setVisible(false)
            ui:removeFromUIManager()
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function InteractionRules:onPlayerInsideOneMinute(zone, player, data)
    if data.noThump then
        local cache = runtime.thumpChunksByZone[zone.id]
        if not cache or cache.state ~= true then
            self:_applyNoThumpToZone(zone, player, true)
        end
    else
        local cache = runtime.thumpChunksByZone[zone.id]
        if cache and cache.state == true then
            self:_applyNoThumpToZone(zone, player, false)
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function InteractionRules:onPlayerExit(zone, player, data)
    runtime.thumpChunksByZone[zone.id] = nil
end

WastelandZones.Plugins:register(InteractionRules:new())
