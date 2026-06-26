---@class WastelandZones.Classes.PlayerNeeds: WastelandZones.Classes.Plugin
local PlayerNeeds = WastelandZones.Classes.PlayerNeeds or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.PlayerNeeds")
if not WastelandZones.Classes.PlayerNeeds then
    WastelandZones.Classes.PlayerNeeds = PlayerNeeds
end

local NEED_ORDER = {
    { key = "Boredom", label = "Boredom" },
    { key = "Hunger", label = "Hunger" },
    { key = "Thirst", label = "Thirst" },
    { key = "Fatigue", label = "Fatigue" },
    { key = "Stress", label = "Stress" },
    { key = "Panic", label = "Panic" },
    { key = "Pain", label = "Pain" },
    { key = "Unhappiness", label = "Unhappiness" }
}

local NEEDS_BY_KEY = {}
for i = 1, #NEED_ORDER do
    NEEDS_BY_KEY[NEED_ORDER[i].key] = NEED_ORDER[i]
end

local function clamp(n, low, high)
    if n < low then return low end
    if n > high then return high end
    return n
end

local function toNumber(v, fallback)
    local n = tonumber(v)
    if n == nil then return fallback or 0 end
    return n
end

local function normalizePercentNeed(v)
    return clamp(toNumber(v, 0), 0, 100)
end

local NEED_ACCESSORS = {
    Boredom = {
        get = function(stats, bd) return bd:getBoredomLevel() end,
        set = function(stats, bd, v) bd:setBoredomLevel(normalizePercentNeed(v)) end
    },
    Hunger = {
        get = function(stats, bd) return stats:getHunger() * 100 end,
        set = function(stats, bd, v) stats:setHunger(normalizePercentNeed(v) / 100) end
    },
    Thirst = {
        get = function(stats, bd) return stats:getThirst() * 100 end,
        set = function(stats, bd, v) stats:setThirst(normalizePercentNeed(v) / 100) end
    },
    Fatigue = {
        get = function(stats, bd) return stats:getFatigue() * 100 end,
        set = function(stats, bd, v) stats:setFatigue(normalizePercentNeed(v) / 100) end
    },
    Stress = {
        get = function(stats, bd) return stats:getStress() * 100 end,
        set = function(stats, bd, v) stats:setStress(normalizePercentNeed(v) / 100) end
    },
    Panic = {
        get = function(stats, bd) return stats:getPanic() end,
        set = function(stats, bd, v) stats:setPanic(normalizePercentNeed(v)) end
    },
    Pain = {
        get = function(stats, bd) return stats:getPain() end,
        set = function(stats, bd, v) stats:setPain(normalizePercentNeed(v)) end
    },
    Unhappiness = {
        get = function(stats, bd) return bd:getUnhappynessLevel() end,
        set = function(stats, bd, v) bd:setUnhappynessLevel(normalizePercentNeed(v)) end
    }
}

local function normalizeNeedRow(row, key)
    local minValue = toNumber(row and row.min, 0)
    local maxValue = toNumber(row and row.max, 100)
    if minValue > maxValue then
        minValue, maxValue = maxValue, minValue
    end

    return {
        key = key,
        min = minValue,
        adjustment = clamp(toNumber(row and row.adjustment, 0), -100, 100),
        max = maxValue
    }
end

local function buildNeedMap(rows)
    local byKey = {}
    for i = 1, #(rows or {}) do
        local row = rows[i]
        if row and NEEDS_BY_KEY[row.key] then
            byKey[row.key] = row
        end
    end
    return byKey
end

local function onAdjustmentChanged(rowState, newValue)
    if rowState and rowState.adjustmentValueLabel then
        rowState.adjustmentValueLabel:setName(string.format("%.1f", toNumber(newValue, 0)))
    end
end

---@return WastelandZones.Classes.PlayerNeeds
function PlayerNeeds:new()
    local o = PlayerNeeds.parentClass.new(self)
    o.type = "PlayerNeeds"
    o.priority = 55
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function PlayerNeeds:buildPanel(zone, panel, data)
    local existingByKey = buildNeedMap(data.needs)
    local rows = {}

    for i = 1, #NEED_ORDER do
        local need = NEED_ORDER[i]
        rows[#rows + 1] = { type = "label", id = "needLabel_" .. need.key, width = "inherit", height = 18, text = need.label }
        rows[#rows + 1] = { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "label", id = "minLabel_" .. need.key, width = 24, text = "Min", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
            { type = "textbox", id = "minInput_" .. need.key, width = 56, text = "0", onlyNumbers = true },
            { type = "label", id = "pressureLabel_" .. need.key, width = 56, text = "Pressure", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
            { type = "sliderpanel", id = "adjustmentSlider_" .. need.key, width = "*", minValue = -5, maxValue = 5, stepValue = 0.1, shiftValue = 1, currentValue = 0, doButtons = false },
            { type = "label", id = "adjustmentValueLabel_" .. need.key, width = 34, text = "0.0" },
            { type = "label", id = "maxLabel_" .. need.key, width = 24, text = "Max", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
            { type = "textbox", id = "maxInput_" .. need.key, width = 56, text = "100", onlyNumbers = true }
        }}
        if i < #NEED_ORDER then
            rows[#rows + 1] = { type = "gap", width = "inherit", height = 10 }
        end
    end

    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 4, margin = { 10, 20, 10, 10 }, rows = rows }
    panel.elements = LayoutManager:applyLayout(panel, panel.layout)

    panel.rows = {}
    for i = 1, #NEED_ORDER do
        local need = NEED_ORDER[i]
        local existing = normalizeNeedRow(existingByKey[need.key], need.key)

        local rowState = {
            key = need.key,
            minInput = panel.elements["minInput_" .. need.key],
            adjustmentSlider = panel.elements["adjustmentSlider_" .. need.key],
            adjustmentValueLabel = panel.elements["adjustmentValueLabel_" .. need.key],
            maxInput = panel.elements["maxInput_" .. need.key]
        }

        rowState.minInput:setOnlyNumbers(true)
        rowState.maxInput:setOnlyNumbers(true)
        rowState.minInput:setText(tostring(existing.min))
        rowState.maxInput:setText(tostring(existing.max))

        rowState.adjustmentSlider.target = rowState
        rowState.adjustmentSlider.onValueChange = onAdjustmentChanged
        rowState.adjustmentSlider.onChange = onAdjustmentChanged
        rowState.adjustmentSlider:setDoButtons(false)
        rowState.adjustmentSlider:setValues(-5, 5, 0.1, 1, true)
        rowState.adjustmentSlider:setCurrentValue(existing.adjustment, true)
        rowState.adjustmentValueLabel:setName(string.format("%.1f", rowState.adjustmentSlider:getCurrentValue()))

        panel.rows[#panel.rows + 1] = rowState
    end
end

---@param panel ISUIElement
---@return table
function PlayerNeeds:getSaveData(panel)
    local rows = {}
    local uiRows = panel.rows or {}

    for i = 1, #uiRows do
        local row = uiRows[i]
        rows[#rows + 1] = normalizeNeedRow({
            min = toNumber(row.minInput:getText(), 0),
            adjustment = row.adjustmentSlider:getCurrentValue(),
            max = toNumber(row.maxInput:getText(), 100)
        }, row.key)
    end

    return { needs = rows }
end

---@param data table
---@return table
function PlayerNeeds:serialize(data)
    local ret = { needs = {} }
    local rowsByKey = buildNeedMap(data.needs)

    for i = 1, #NEED_ORDER do
        local key = NEED_ORDER[i].key
        local row = normalizeNeedRow(rowsByKey[key], key)
        if row.min ~= 0 or row.max ~= 100 or row.adjustment ~= 0 then
            ret.needs[#ret.needs + 1] = row
        end
    end

    if #ret.needs == 0 then
        ret.needs = nil
    end

    return ret
end

---@param data table
---@return table
function PlayerNeeds:deserialize(data)
    local rows = {}
    for i = 1, #(data.needs or {}) do
        local row = data.needs[i]
        if row and NEEDS_BY_KEY[row.key] then
            rows[#rows + 1] = normalizeNeedRow(row, row.key)
        end
    end
    return { needs = rows }
end

---@param player IsoPlayer
---@param row {key:string,min:number,adjustment:number,max:number}
function PlayerNeeds:applyNeed(player, row)
    local accessor = NEED_ACCESSORS[row.key]
    if not accessor then return end

    local adjustment = clamp(toNumber(row.adjustment, 0), -100, 100)
    if adjustment == 0 then return end

    local minValue = toNumber(row.min, 0)
    local maxValue = toNumber(row.max, 100)
    if minValue > maxValue then
        minValue, maxValue = maxValue, minValue
    end

    local stats = player:getStats()
    local bd = player:getBodyDamage()
    local currentValue = toNumber(accessor.get(stats, bd), 0)

    local newValue = currentValue + adjustment
    if adjustment > 0 then
        if currentValue >= maxValue then return end
        if newValue > maxValue then
            newValue = maxValue
        end
    else
        if currentValue <= minValue then return end
        if newValue < minValue then
            newValue = minValue
        end
    end

    accessor.set(stats, bd, newValue)
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function PlayerNeeds:onPlayerInsideOneSecond(zone, player, data)
    local rows = data.needs or {}
    for i = 1, #rows do
        local row = rows[i]
        self:applyNeed(player, row)
    end
end

WastelandZones.Plugins:register(PlayerNeeds:new())
