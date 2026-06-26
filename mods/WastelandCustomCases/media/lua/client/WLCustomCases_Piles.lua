WLCustomCases = WLCustomCases or {}
WLCustomCases.Piles = WLCustomCases.Piles or {}

local Piles = WLCustomCases.Piles

local fastPileTypes = {
    ["WLCustomCases.Log_Pile"] = true,
    ["WLCustomCases.Stone_Pile"] = true,
    ["WLCustomCases.Plank_Pile"] = true,
    ["WLCustomCases.Brick_Pile"] = true,
    ["WLCustomCases.Metal_Pile"] = true,
    ["WLCustomCases.BaggedItems_Pile"] = true,
    ["WLCustomCases.CarParts_Pile"] = true,
    ["WLCustomCases.PropaneTank_Pile"] = true,
}

function Piles.IsFastPileItem(item)
    if not item then
        return false
    end
    return fastPileTypes[item:getFullType()] == true
end
