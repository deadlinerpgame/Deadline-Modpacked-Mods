---@class WastelandZones.Classes.ZombieControl: WastelandZones.Classes.Plugin
local ZombieControl = WastelandZones.Classes.ZombieControl or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.ZombieControl")
if not WastelandZones.Classes.ZombieControl then
    WastelandZones.Classes.ZombieControl = ZombieControl
end

local SPEED_SPRINTER = 1
local SPEED_FAST_SHAMBLER = 2
local SPEED_SLOW_SHAMBLER = 3

local RECONSIDER_DISTANCE = 40

local function toNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then return fallback or 0 end
    return n
end

local function clamp(n, low, high)
    if n < low then return low end
    if n > high then return high end
    return n
end

local function toRatioInt(v)
    return math.floor(clamp(toNumber(v, 0), 0, 100))
end

local function normalizeRatioTriplet(sprinters, fastShamblers, slowShamblers)
    local s = toRatioInt(sprinters)
    local f = toRatioInt(fastShamblers)
    local w = toRatioInt(slowShamblers)

    local total = s + f + w
    if total > 100 then
        local overflow = total - 100
        local cut = math.min(overflow, w)
        w = w - cut
        overflow = overflow - cut

        if overflow > 0 then
            cut = math.min(overflow, f)
            f = f - cut
            overflow = overflow - cut
        end

        if overflow > 0 then
            s = math.max(0, s - overflow)
        end
    end

    return s, f, w
end

local function buildRatioPayload(data)
    local s, f, w = normalizeRatioTriplet(data.percentageSprinters, data.percentageFastShamblers, data.percentageSlowShamblers)
    return {
        percentageSprinters = s,
        percentageFastShamblers = f,
        percentageSlowShamblers = w,
        percentageDefault = 100 - (s + f + w)
    }
end

local function findField(o, fname)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if tostring(f) == fname then
            return f
        end
    end
end

local speedField
local defaultSpeed

local function ensureZombieSpeedAccess()
    if not speedField then
        speedField = findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.speedType")
    end

    if defaultSpeed == nil then
        local option = getSandboxOptions() and getSandboxOptions():getOptionByName("ZombieLore.Speed")
        if option and option.asConfigOption then
            defaultSpeed = tonumber(option:asConfigOption():getValueAsLuaString())
        end

        if defaultSpeed == nil then
            defaultSpeed = SPEED_SLOW_SHAMBLER
        end
    end
end

local function getZombieSpeed(isoZombie)
    ensureZombieSpeedAccess()
    if not speedField then return nil end
    return getClassFieldVal(isoZombie, speedField)
end

local function updateZombieSpeed(isoZombie, targetSpeed)
    ensureZombieSpeedAccess()

    local options = getSandboxOptions()
    if not options then return end

    options:set("ZombieLore.Speed", targetSpeed)
    isoZombie:makeInactive(true)
    isoZombie:makeInactive(false)
    options:set("ZombieLore.Speed", defaultSpeed)
end

local function removeZombieNow(isoZombie)
    if not isoZombie then return end
    isoZombie:removeFromWorld()
    isoZombie:removeFromSquare()
end

local function queueZombieDespawn(runtime, isoZombie)
    if not isoZombie or isoZombie:isDead() then return end

    local modData = isoZombie:getModData()
    if modData.WZ_ZC_PendingDespawn then return end
    modData.WZ_ZC_PendingDespawn = true

    if runtime and runtime.defer then
        runtime:defer(function()
            if isoZombie then
                removeZombieNow(isoZombie)
            end
        end)
        return
    end

    removeZombieNow(isoZombie)
end

local function queueZombieKill(runtime, isoZombie)
    if not isoZombie or isoZombie:isDead() then return end

    local modData = isoZombie:getModData()
    if modData.WZ_ZC_PendingKill then return end
    modData.WZ_ZC_PendingKill = true

    local function doKill()
        if not isoZombie or isoZombie:isDead() then return end
        local cell = getCell()
        local fakeZombie = cell and cell:getFakeZombieForHit() or nil
        isoZombie:Kill(fakeZombie)
        print("[WastelandZones] ZombieControl plugin killed a zombie (ID " .. isoZombie:getOnlineID() .. ")")
    end

    if runtime and runtime.defer then
        runtime:defer(doKill)
    else
        doKill()
    end
end

local function shouldConsiderZombie(isoZombie, modData)
    local square = isoZombie:getSquare()
    if not square then return false end
    if not modData.WZ_ZC_WasConsidered then return true end

    local x = square:getX()
    local y = square:getY()

    local lastX = modData.WZ_ZC_LastX or 0
    local lastY = modData.WZ_ZC_LastY or 0
    local dx = math.abs(x - lastX)
    local dy = math.abs(y - lastY)

    return dx >= RECONSIDER_DISTANCE or dy >= RECONSIDER_DISTANCE
end

local function chooseTargetSpeedFromRatios(ratios)
    ensureZombieSpeedAccess()

    local roll = ZombRand(100) + 1
    local sprinters = ratios.percentageSprinters or 0
    local fast = ratios.percentageFastShamblers or 0
    local slow = ratios.percentageSlowShamblers or 0

    if roll <= sprinters then
        return SPEED_SPRINTER
    end

    if roll <= sprinters + fast then
        return SPEED_FAST_SHAMBLER
    end

    if roll <= sprinters + fast + slow then
        return SPEED_SLOW_SHAMBLER
    end

    return defaultSpeed
end

---@return WastelandZones.Classes.ZombieControl
function ZombieControl:new()
    local o = ZombieControl.parentClass.new(self)
    o.type = "ZombieControl"
    o.priority = 15
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function ZombieControl:buildPanel(zone, panel, data)
    local ratios = buildRatioPayload(data)

    panel._wzRatioOrder = { "percentageSprinters", "percentageFastShamblers", "percentageSlowShamblers" }
    panel._wzRatioLabels = {
        percentageSprinters = "Sprinters",
        percentageFastShamblers = "Fast Shamblers",
        percentageSlowShamblers = "Slow Shamblers"
    }

    local rows = {
        { type = "tickbox", id = "tickboxes", width = "inherit", height = 18 * 3, options = { "No Zombie Zone (despawn)", "Kill Zombie Zone (kill zombies)", "Adjust zombies by ratios" }, selected = { data.preventZombies == true, data.killZombies == true, data.adjustZombies == true } },
        { type = "label", id = "ratioHelpLabel", width = "inherit", height = 18, text = "Speed ratios (sprinter + fast + slow + default always equals 100%)" },
        { type = "gap", width = "inherit", height = 4 }
    }

    for i = 1, #panel._wzRatioOrder do
        local key = panel._wzRatioOrder[i]
        rows[#rows + 1] = { type = "columns", id = "ratioRow_" .. key, width = "inherit", height = 24, pad = 8, columns = {
            { type = "label", id = "ratioLabel_" .. key, width = 110, text = panel._wzRatioLabels[key] },
            { type = "sliderpanel", id = "ratioSlider_" .. key, width = "*", minValue = 0, maxValue = 100, stepValue = 1, shiftValue = 1, currentValue = toRatioInt(ratios[key]), doButtons = false },
            { type = "label", id = "ratioValue_" .. key, width = 30, text = tostring(toRatioInt(ratios[key])) }
        }}
    end

    rows[#rows + 1] = { type = "columns", id = "defaultRatioRow", width = "inherit", height = 20, pad = 8, columns = {
        { type = "label", id = "defaultRatioLabel", width = 110, text = "Default (sandbox):", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
        { type = "label", id = "defaultRatioValueLabel", width = 30, text = tostring(ratios.percentageDefault) },
        { type = "gap", width = "*" }
    }}

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 6, margin = { 10, 20, 10, 10 }, rows = rows }
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)
    panel.tickboxes = panel.elements.tickboxes
    panel.ratioHelpLabel = panel.elements.ratioHelpLabel
    panel.defaultRatioLabel = panel.elements.defaultRatioLabel
    panel.defaultRatioValueLabel = panel.elements.defaultRatioValueLabel
    panel.rows = {}

    local function refreshRatioUi(_panel)
        local total = 0
        for i = 1, #_panel._wzRatioOrder do
            local key = _panel._wzRatioOrder[i]
            local row = _panel.rows[key]
            local v = toRatioInt(row.slider:getCurrentValue())
            total = total + v
            row.valueLabel:setName(tostring(v))
        end

        local defaultRatio = 100 - total
        if defaultRatio < 0 then
            defaultRatio = 0
        end
        _panel.defaultRatioValueLabel:setName(tostring(defaultRatio))
    end

    local function enforceRatioConstraint(_panel, changedKey)
        local values = {}
        local total = 0

        for i = 1, #_panel._wzRatioOrder do
            local key = _panel._wzRatioOrder[i]
            local row = _panel.rows[key]
            local v = toRatioInt(row.slider:getCurrentValue())
            values[key] = v
            total = total + v
        end

        if total > 100 and changedKey then
            local overflow = total - 100
            values[changedKey] = math.max(0, values[changedKey] - overflow)
            total = 0
            for i = 1, #_panel._wzRatioOrder do
                local key = _panel._wzRatioOrder[i]
                total = total + values[key]
            end
        end

        if total > 100 then
            local overflow = total - 100
            local passOrder = { "percentageSlowShamblers", "percentageFastShamblers", "percentageSprinters" }
            for i = 1, #passOrder do
                if overflow <= 0 then break end
                local key = passOrder[i]
                local cut = math.min(overflow, values[key])
                values[key] = values[key] - cut
                overflow = overflow - cut
            end
        end

        for i = 1, #_panel._wzRatioOrder do
            local key = _panel._wzRatioOrder[i]
            _panel.rows[key].slider:setCurrentValue(values[key], true)
        end

        refreshRatioUi(_panel)
    end

    local function onRatioSliderChanged(rowState, _newValue)
        local _panel = rowState and rowState.panel or nil
        if not _panel or _panel._wzRatioUpdating then return end

        _panel._wzRatioUpdating = true
        enforceRatioConstraint(_panel, rowState.key)
        _panel._wzRatioUpdating = false
    end

    for i = 1, #panel._wzRatioOrder do
        local key = panel._wzRatioOrder[i]
        local rowState = {
            panel = panel,
            key = key,
            slider = panel.elements["ratioSlider_" .. key],
            valueLabel = panel.elements["ratioValue_" .. key]
        }

        rowState.slider.target = rowState
        rowState.slider.onValueChange = onRatioSliderChanged
        rowState.slider.onChange = onRatioSliderChanged
        rowState.slider:setDoButtons(false)
        rowState.slider:setValues(0, 100, 1, 1, true)
        rowState.slider:setCurrentValue(toRatioInt(ratios[key]), true)
        rowState.valueLabel:setName(tostring(toRatioInt(ratios[key])))

        panel.rows[key] = rowState
    end

    panel._wzRatioUpdating = true
    enforceRatioConstraint(panel, nil)
    panel._wzRatioUpdating = false
end

---@param panel ISUIElement
---@return table
function ZombieControl:getSaveData(panel)
    local s = toRatioInt(panel.rows.percentageSprinters.slider:getCurrentValue())
    local f = toRatioInt(panel.rows.percentageFastShamblers.slider:getCurrentValue())
    local w = toRatioInt(panel.rows.percentageSlowShamblers.slider:getCurrentValue())
    s, f, w = normalizeRatioTriplet(s, f, w)

    return {
        preventZombies = panel.tickboxes:isSelected(1),
        killZombies = panel.tickboxes:isSelected(2),
        adjustZombies = panel.tickboxes:isSelected(3),
        percentageSprinters = s,
        percentageFastShamblers = f,
        percentageSlowShamblers = w
    }
end

---@param data table
---@return table
function ZombieControl:serialize(data)
    local ratios = buildRatioPayload(data)
    local ret = {}

    if data.preventZombies then ret.preventZombies = true end
    if data.killZombies then ret.killZombies = true end
    if data.adjustZombies then ret.adjustZombies = true end

    if ratios.percentageSprinters > 0 then ret.percentageSprinters = ratios.percentageSprinters end
    if ratios.percentageFastShamblers > 0 then ret.percentageFastShamblers = ratios.percentageFastShamblers end
    if ratios.percentageSlowShamblers > 0 then ret.percentageSlowShamblers = ratios.percentageSlowShamblers end

    return ret
end

---@param data table
---@return table
function ZombieControl:deserialize(data)
    local ratios = buildRatioPayload(data)

    return {
        preventZombies = data.preventZombies == true,
        killZombies = data.killZombies == true,
        adjustZombies = data.adjustZombies == true,
        percentageSprinters = ratios.percentageSprinters,
        percentageFastShamblers = ratios.percentageFastShamblers,
        percentageSlowShamblers = ratios.percentageSlowShamblers
    }
end


---@param isoZombie IsoZombie
---@param ratios table
function ZombieControl:_considerZombieSpeed(isoZombie, ratios)
    if not isoZombie or isoZombie:isDead() then return end

    local modData = isoZombie:getModData()
    if shouldConsiderZombie(isoZombie, modData) then
        local square = isoZombie:getSquare()
        if not square then return end

        local target = chooseTargetSpeedFromRatios(ratios)
        modData.WZ_ZC_AssignedSpeed = target
        modData.WZ_ZC_LastX = math.floor(square:getX())
        modData.WZ_ZC_LastY = math.floor(square:getY())
        modData.WZ_ZC_WasConsidered = true
    end

    local target = modData.WZ_ZC_AssignedSpeed
    if target ~= nil then
        local current = getZombieSpeed(isoZombie)
        if current ~= target then
            updateZombieSpeed(isoZombie, target)
            return target
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param zombieBatch IsoZombie[]
---@param data table
---@param runtime table|nil
function ZombieControl:onServerZombieBatch(zone, zombieBatch, data, runtime)
    if isClient() then return end
    if not data then return end
    if not zombieBatch or #zombieBatch == 0 then return end

    local doDespawn = data.preventZombies == true
    local doKill = data.killZombies == true
    local doAdjust = data.adjustZombies == true
    local adjustments = {}
    local wasAdjustments = false

    if not doDespawn and not doAdjust then
        return
    end

    local ratios = buildRatioPayload(data)

    for i = 1, #zombieBatch do
        local isoZombie = zombieBatch[i]
        if isoZombie and not isoZombie:isDead() then
            if doDespawn then
                queueZombieDespawn(runtime, isoZombie)
            elseif doAdjust then
                local target = self:_considerZombieSpeed(isoZombie, ratios)
                if target then
                    adjustments[isoZombie:getOnlineID()] = target
                    wasAdjustments = true
                end
            end
        end
    end

    if wasAdjustments then
        WastelandZones.Network:triggerZonePlugin(zone.id, self.type, "_doAdjustments", adjustments)
    end
end

local missedAdjustments = {}
function ZombieControl:_doAdjustments(zone, data, adjustments)
    local cell = getCell()
    if not cell then return end
    
    local isoZombies = cell:getZombieList()
    if not isoZombies then return end

    local idSet = {}
    for id, _ in pairs(adjustments) do
        idSet[id] = false
    end

    for i = 0, isoZombies:size() - 1 do
        local isoZombie = isoZombies:get(i)
        if isoZombie and not isoZombie:isDead() and not isoZombie:getModData().ParanoidDelusions then
            local target = adjustments[isoZombie:getOnlineID()]
            local modData = isoZombie:getModData()
            modData.WZ_ZC_WasConsidered = true
            modData.WZ_ZC_AssignedSpeed = target
            if target then
                updateZombieSpeed(isoZombie, target)
                idSet[isoZombie:getOnlineID()] = true
            end
        end
    end

    local foundCount = 0
    local missedCount = 0
    for id, found in pairs(idSet) do
        if found then
            foundCount = foundCount + 1
        else
            missedCount = missedCount + 1
            missedAdjustments[id] = {getTimestampMs(), adjustments[id]}
        end
    end
    print(string.format("[WastelandZones] ZombieControl plugin applied %d speed adjustments, missed %d zombies", foundCount, missedCount))
end

if isClient() then
    local CLIENT_CHECK_INTERVAL_MS = 3000
    local PROXIMITY_RANGE = 300
    local KC_TYPE = "ZombieControl"

    local function hasAnyZones()
        for _ in pairs(WastelandZones.Zones.zones) do
            return true
        end
        return false
    end

    local function hasAnyMissedAdjustments()
        for _ in pairs(missedAdjustments) do
            return true
        end
        return false
    end

    local function anyControlZoneNear()
        local player = getSpecificPlayer(0)
        if not player then return false end
        local nearby = WastelandZones.Zones:getAllNear(player:getX(), player:getY(), player:getZ(), PROXIMITY_RANGE)
        for _, zone in pairs(nearby) do
            if zone.plugins and zone.plugins[KC_TYPE] then
                return true
            end
        end
        return false
    end

    local lastCheck = 0
    local function checkZombiesModData()
        local nowTs = getTimestampMs()
        if nowTs - lastCheck < CLIENT_CHECK_INTERVAL_MS then return end
        lastCheck = nowTs

        local hasMissed = hasAnyMissedAdjustments()

        if not hasMissed and not hasAnyZones() then return end
        if not hasMissed and not anyControlZoneNear() then return end

        local cell = getCell()
        if not cell then return end

        local isoZombies = cell:getZombieList()
        if not isoZombies then return end

        -- --- @type WastelandZones.Classes.ZombieControl
        -- local plugin = WastelandZones.Plugins:get("ZombieControl")

        for i = 0, isoZombies:size() - 1 do
            local isoZombie = isoZombies:get(i)
            if isoZombie and not isoZombie:isDead() and not isoZombie:getModData().ParanoidDelusions then
                local modData = isoZombie:getModData()
                if modData.WZ_ZC_WasConsidered and modData.WZ_ZC_AssignedSpeed then
                    local current = getZombieSpeed(isoZombie)
                    if current ~= modData.WZ_ZC_AssignedSpeed then
                        updateZombieSpeed(isoZombie, modData.WZ_ZC_AssignedSpeed)
                    end
                elseif missedAdjustments[isoZombie:getOnlineID()] then
                    local current = getZombieSpeed(isoZombie)
                    local target = missedAdjustments[isoZombie:getOnlineID()][2]
                    if current ~= target then
                        updateZombieSpeed(isoZombie, target)
                    end
                    missedAdjustments[isoZombie:getOnlineID()] = nil
                    print("[WastelandZones] ZombieControl plugin applied missed speed adjustment")
                end
                ---@type WastelandZones.Classes.Zone[]
                local zones = WastelandZones.Zones:getAllAt(isoZombie:getX(), isoZombie:getY(), isoZombie:getZ())
                if zones then
                    for _, zone in pairs(zones) do
                        local pluginData = zone.plugins["ZombieControl"]
                        if pluginData and pluginData.killZombies then
                            queueZombieKill(nil, isoZombie)
                        end
                    end
                end
            end
        end

        local countMissedPruned = 0
        for id, adj in pairs(missedAdjustments) do
            if getTimestampMs() - adj[1] > 60000 then
                missedAdjustments[id] = nil
                countMissedPruned = countMissedPruned + 1
            end
        end
        if countMissedPruned > 0 then
            print(string.format("[WastelandZones] ZombieControl plugin pruned %d missed adjustments", countMissedPruned))
        end
    end

    Events.OnTick.Add(checkZombiesModData)
end

WastelandZones.Plugins:register(ZombieControl:new())
