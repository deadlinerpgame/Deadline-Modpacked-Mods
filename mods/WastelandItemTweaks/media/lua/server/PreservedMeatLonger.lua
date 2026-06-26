if getActivatedMods():contains("FoodPreservationPlus") then
    local item = getScriptManager():getItem("Base.SaltedMeat")
    item:DoParam("DaysFresh = 14")
    item:DoParam("DaysTotallyRotten = 28")

    item = getScriptManager():getItem("Base.SmokedMeat")
    item:DoParam("DaysFresh = 28")
    item:DoParam("DaysTotallyRotten = 56")
end