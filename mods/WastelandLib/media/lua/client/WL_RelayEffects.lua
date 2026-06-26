WL_RelayEffects = WL_RelayEffects or {}

local function clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(value, maxValue))
end

function WL_RelayEffects.applyEffects(player, effectData)
    if not player then return end
    if not effectData then return end
    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    if effectData.stress then
   --     local currentStress = WL_Stress.getTotal(player)
        WL_Stress.adjust(effectData.stress, player)
    --    local newStress = WL_Stress.getTotal(player)
    --    print("WL_RelayEffects.applyEffects stress current=" .. tostring(currentStress) .. " delta=" .. tostring(effectData.stress) .. " new=" .. tostring(newStress))
    end
    if effectData.unhappiness then
        local currentUnhappiness = bodyDamage:getUnhappynessLevel()
        local newUnhappiness = clamp(currentUnhappiness + effectData.unhappiness, 0, 100)
        bodyDamage:setUnhappynessLevel(newUnhappiness)
    end
    if effectData.boredom then
        local currentBoredom = bodyDamage:getBoredomLevel()
        local newBoredom = clamp(currentBoredom + effectData.boredom, 0, 100)
        bodyDamage:setBoredomLevel(newBoredom)
    end
end
