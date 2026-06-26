if isClient() then return end

local Json = require "WLR_Auto_json"

WLR_Auto = WLR_Auto or {}

--- @class WLR_Auto.Definition
--- @field id string
--- @field enabled boolean
--- @field range WLR_Auto.Range
--- @field containerChance number
--- @field itemChance number
--- @field itemCountToIgnore number
--- @field frequencyHours number
--- @field ignoredCategories table<string, boolean>
--- @field ignoredItems table<string, boolean>
--- @field gasFillChance number
--- @field gasFillRange number[]|nil
WLR_Auto.Definition = WLR_Auto.Definition or WLBaseObject:derive("Definition")

--- @param src table
--- @return WLR_Auto.Definition
function WLR_Auto.Definition:new(src)
    local o = self:super()
    o.id = src.id or getRandomUUID()
    o.enabled = src.enabled
    o.range = WLR_Auto.Range:new(src.x1, src.y1, src.x2, src.y2)
    o.containerChance = src.containerChance ~= nil and src.containerChance or 1.0
    o.itemChance = src.itemChance ~= nil and src.itemChance or 1.0
    o.chanceLocked = src.chanceLocked ~= nil and src.chanceLocked or 500
    o.itemCountToIgnore = src.itemCountToIgnore or 10
    o.frequencyHours = src.frequencyHours or 168 -- 7 days
    o.ignoredCategories = src.ignoredCategories or {}
    o.ignoredItems = src.ignoredItems or {}
    o.gasFillChance = src.gasFillChance or 0
    o.gasFillRange = src.gasFillRange or {0, 0}
    return o
end

--- @param self WLR_Auto.Definition
--- @param range WLR_Auto.Range
--- @return boolean
function WLR_Auto.Definition:intersects(range)
    return range:intersects(self.range)
end

--- @param self WLR_Auto.Definition
--- @param range WLR_Auto.Range
--- @return WLR_Auto.Range
function WLR_Auto.Definition:getOverlap(range)
    return range:intersection(self.range)
end

function WLR_Auto.Definition.GetDefaultConfig()
    return {
        {
            id = "Muldraugh",
            enabled = false,
            x1 = 10550,
            y1 = 9150,
            x2 = 11050,
            y2 = 10700,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "West Point",
            enabled = false,
            x1 = 10850,
            y1 = 6600,
            x2 = 12200,
            y2 = 7100,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "Rosewood",
            enabled = false,
            x1 = 7950,
            y1 = 11200,
            x2 = 8500,
            y2 = 11850,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "March Ridge",
            enabled = false,
            x1 = 9750,
            y1 = 12560,
            x2 = 10500,
            y2 = 13150,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "Riverside",
            enabled = false,
            x1 = 5700,
            y1 = 5200,
            x2 = 6850,
            y2 = 5650,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "LV",
            enabled = false,
            x1 = 11950,
            y1 = 1100,
            x2 = 14400,
            y2 = 3900,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "Dixie",
            enabled = false,
            x1 = 11400,
            y1 = 8750,
            x2 = 11900,
            y2 = 9000,
            containerChance = 1.0,
            itemChance = 1.0,
            frequencyHours = 168,
            itemCountToIgnore = 10,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        }, {
            id = "Global",
            enabled = false,
            x1 = 3000,
            y1 = 1000,
            x2 = 15000,
            y2 = 13500,
            containerChance = 0.2,
            itemChance = 0.2,
            frequencyHours = 168,
            itemCountToIgnore = 5,
            chanceLocked = 500,
            ignoredCategories = {},
            ignoredItems = {},
            gasFillChance = 10,
            gasFillRange = {0, 5},
        },
    }
end