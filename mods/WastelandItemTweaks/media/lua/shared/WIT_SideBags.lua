---
--- WIT_SideBags.lua
--- 23/10/2025
--- 

require "WL_Utils"

local sidebags = {
    "Base.CBX_Sumk_1_L",
    "Base.CBX_Sumk_1_R",
    "Base.CBX_Sumk_1M_L",
    "Base.CBX_Sumk_1M_R",
    "Base.CBX_Sumk_2_L",
    "Base.CBX_Sumk_2_R",
    "Base.CBX_Sumk_3_L",
    "Base.CBX_Sumk_3_R",
    "Base.CBX_Sumk_4_L",
    "Base.CBX_Sumk_4_R",
    "Base.CBX_Sumk_5_L",
    "Base.CBX_Sumk_5_R"
}

for _, sidebag in ipairs(sidebags) do
    local item = ScriptManager.instance:getItem(sidebag)
    if item then
        WL_Utils.setItemProperties(sidebag, {
            ["Capacity"] = "15",
            ["WeightReduction"] = "70"
        })
    end
end

local function fixSideBags()
    if not isClient() then return end
    local player = getPlayer()
    local inventoryItems = player:getInventory():getItems()

    for i = 0, inventoryItems:size() - 1 do
        local item = inventoryItems:get(i)
        if item then
            for _, sidebag in ipairs(sidebags) do
                if item:getFullType() == sidebag then
                    local capacity = item:getCapacity()
                    local weightReduction = item:getWeightReduction()
                    if capacity ~= 15 then
                        item:setCapacity(15)
                    end
                    if weightReduction ~= 70 then
                        item:setWeightReduction(70)
                    end
                end
            end
        end
    end
end

Events.OnClothingUpdated.Add(fixSideBags)