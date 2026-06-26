---
--- WIT_WetBugFix.lua
--- 28/10/2024
---
local function checkAndFixBuggedClothing()
    local player = getPlayer()
    local inventoryItems = player:getInventory():getItems()

    for i = 0, inventoryItems:size() - 1 do
        local item = inventoryItems:get(i)
        if item and instanceof(item, "Clothing") and player:isEquippedClothing(item) then
            local wetness = item:getWetness()
            if wetness and tostring(wetness) == "nan" then
                item:setWetness(1)
                item:updateWetness()
                print("WET BUG: Bugged item fixed. Item: " .. item:getName() .. " set to 1")
            end
        end
    end

    if tostring(player:getBodyDamage():getWetness()) == "nan" then
        player:getBodyDamage():setTemperature(20)
        player:getBodyDamage():setWetness(0)
        player:getBodyDamage():getThermoregulator():reset()
        player:getBodyDamage():UpdateWetness()
        player:getStats():setThirst(0.7)
        player:getNutrition():setCalories(1000)
        print("WET BUG: Player Body Fixed")
    end
    if tostring(player:getNutrition():getCalories()) == "nan" then
        player:getNutrition():setCalories(1000)
        print("WET BUG: Player Nutrition Fixed")
    end
end

Events.EveryOneMinute.Add(checkAndFixBuggedClothing)
