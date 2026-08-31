WIT_HairDyeRecipeFix = {}

function WIT_HairDyeRecipeFix.OnTest(item)
    if not item:isHairDye() then
        return true
    end

    local usedDelta = item:getUsedDelta()
    return usedDelta == 1 or usedDelta == 0.5
end
