require 'Items/ProceduralDistributions'

local function AdjustDist(category, name, newval)
    for i, v in ipairs(ProceduralDistributions["list"][category].items) do
        if v == name then
            ProceduralDistributions["list"][category].items[i + 1] = newval
            break
        end
    end
end

local function RemoveDist(category, name)
    for i, v in ipairs(ProceduralDistributions["list"][category].items) do
        if v == name then
            table.remove(ProceduralDistributions["list"][category].items, i)
            table.remove(ProceduralDistributions["list"][category].items, i)
            break
        end
    end
end

if getActivatedMods():contains("funnyikeasharkie") then
    require "Items/blahajDistributions"
    RemoveDist("CrateToys", "Base.BlahajPlushie")
    RemoveDist("CrateToys", "Base.SmallhajPlushie")
    RemoveDist("DaycareShelves", "Base.BlahajPlushie")
    RemoveDist("DaycareShelves", "Base.SmallhajPlushie")
    RemoveDist("WardrobeChild", "Base.BlahajPlushie")
    RemoveDist("WardrobeChild", "Base.SmallhajPlushie")

    AdjustDist("GigamartToys", "Base.BlahajPlushie", 1)
    AdjustDist("GigamartToys", "Base.SmallhajPlushie", 0.5)
end