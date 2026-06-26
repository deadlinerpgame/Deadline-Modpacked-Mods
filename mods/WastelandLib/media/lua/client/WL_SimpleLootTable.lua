require "WL_Utils"

--- Utilities for simple weighted loot tables.
---
--- A simple loot table is a dictionary where each key is an item type and each
--- value is that item's relative weight:
---
---     {
---         ["Base.ScrapMetal"] = 10,
---         ["Base.Nails"] = 5,
---         ["Base.Screws"] = 1,
---     }
---
--- Higher weights are more likely to be selected. For example, an item with
--- weight 10 is twice as likely to be selected as an item with weight 5.
---
--- This helper is intended for small, direct loot rewards where each roll picks
--- exactly one item and immediately adds it to the local player's inventory.
---
--- @class WL_SimpleLootTable
WL_SimpleLootTable = WL_SimpleLootTable or {}

--- Sums all item weights in a simple loot table.
---
--- @param lootTable table<string, number> Item type to relative weight.
--- @return number totalWeight Sum of all weights in the table.
function WL_SimpleLootTable.getTotalWeight(lootTable)
    local totalWeight = 0
    for _, weight in pairs(lootTable) do
        totalWeight = totalWeight + weight
    end

    return totalWeight
end

local function rollToInventory(lootTable, quantity, totalWeight)
    local randomNumber = ZombRand(1, totalWeight + 1)
    local cumulativeWeight = 0
    for itemType, weight in pairs(lootTable) do
        cumulativeWeight = cumulativeWeight + weight
        if randomNumber <= cumulativeWeight then
            return WL_Utils.addItemToInventory(itemType, quantity)
        end
    end

    return nil
end

--- Rolls a simple loot table and adds each selected item to the local player's inventory.
---
--- The quantity is passed through to WL_Utils.addItemToInventory. If quantity is
--- nil, one item is added. If quantity is 2 or more, that many copies of the
--- selected item are added for each successful roll.
---
--- @param lootTable table<string, number> Item type to relative weight.
--- @param numberOfRolls number|nil Number of independent weighted rolls to perform. Defaults to 1.
--- @param quantity number|nil Number of copies of the selected item to add.
function WL_SimpleLootTable.roll(lootTable, numberOfRolls, quantity)
    local totalWeight = WL_SimpleLootTable.getTotalWeight(lootTable)
    if totalWeight <= 0 then
        return
    end

    numberOfRolls = numberOfRolls or 1

    for i = 1, numberOfRolls do
        rollToInventory(lootTable, quantity, totalWeight)
    end
end
