if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC.Buffs = {}

WRC.Buffs.AmountsPerMessage = {
    boredom = 3,
    hunger = 0.001,
    thirst = 0.001,
    stressSmokes = 0.002,
    unhappyness = 0.002
}
WRC.Buffs.DelayBetweenBuffs = 30 -- seconds
WRC.Buffs.LastApplied = 0

function WRC.Buffs.IsAutoCleanEnabled()
    local md = getPlayer():getModData()
    return md["WRC_Buffs_AutoCleanEnabled"] or false
end

function WRC.Buffs.SetAutoCleanEnabled(enabled)
    local md = getPlayer():getModData()
    md["WRC_Buffs_AutoCleanEnabled"] = enabled
    if enabled then
        WRC.Buffs.DoAutoClean()
    end
end

function WRC.Buffs.IsPlayersNearby()
    local players = getOnlinePlayers()
    for i=0,players:size()-1 do
        local otherPlayer = players:get(i)
        if WRC.CanSeePlayer(otherPlayer, false, 15) then
            return true
        end
    end
    return false
end

local function normalizeValue(initial, adjustment)
    local value = math.max(initial - adjustment, adjustment)
    return math.floor(value * 10000) / 10000
end

function WRC.Buffs.ApplyRpBuffs()
    if not SandboxVars.WastelandRpChat.EnableBuffs then
        return
    end

    local player = getPlayer()

    local ts = getTimestamp()
    if WRC.Buffs.LastApplied + WRC.Buffs.DelayBetweenBuffs > ts then
        return
    end
    WRC.Buffs.LastApplied = ts

    local stats = player:getStats()
    local bodyDamage = player:getBodyDamage()
    local apm = WRC.Buffs.AmountsPerMessage
    local multiplier = getGameTime():getMultiplier()

    local boredom = bodyDamage:getBoredomLevel()
    if boredom > apm.boredom then
        print("boredom: " .. apm.boredom * multiplier)
        local boredomNew = normalizeValue(boredom, apm.boredom * multiplier)
        bodyDamage:setBoredomLevel(boredomNew)
    end

    local hunger = stats:getHunger()
    if hunger > apm.hunger then
        local hungerNew = normalizeValue(hunger, apm.hunger * multiplier)
        stats:setHunger(hungerNew)
    end

    local thirst = stats:getThirst()
    if thirst > apm.thirst then
        local thirstNew = normalizeValue(thirst, apm.thirst * multiplier)
        stats:setThirst(thirstNew)
    end

    local stressSmokes = stats:getStressFromCigarettes()
    if stressSmokes > apm.stressSmokes then
        local stressSmokesNew = normalizeValue(stressSmokes, apm.stressSmokes * multiplier)
        stats:setStressFromCigarettes(stressSmokesNew)
    end

    local unhappyness = bodyDamage:getUnhappynessLevel()
    if unhappyness > apm.unhappyness then
        local unhappynessNew = normalizeValue(unhappyness, apm.unhappyness * multiplier)
        bodyDamage:setUnhappynessLevel(unhappynessNew)
    end
end

function WRC.Buffs.DoAutoClean()
    if not WRC.Buffs.IsAutoCleanEnabled() then
        return
    end

    WRC.Buffs.DoClean()
end

local function syncVisuals(player)
    sendVisual(player)
    triggerEvent("OnClothingUpdated", player)
    player:resetModel()
end

local function setBodyPartDirt(player, bodyPartStr, amount)
    if bodyPartStr then
        local bodyPartType = BodyPartType.FromString(bodyPartStr)
        local part = BloodBodyPartType.FromIndex(bodyPartType:index())
        player:getHumanVisual():setDirt(part, amount)
        return
    end

    for i=0,BloodBodyPartType.MAX:index()-1 do
        local part = BloodBodyPartType.FromIndex(i)
        player:getHumanVisual():setDirt(part, amount)
    end
end

local function setBodyPartBlood(player, bodyPartStr, amount)
    if bodyPartStr then
        local bodyPartType = BodyPartType.FromString(bodyPartStr)
        local part = BloodBodyPartType.FromIndex(bodyPartType:index())
        player:getHumanVisual():setBlood(part, amount)
        return
    end

    for i=0,BloodBodyPartType.MAX:index()-1 do
        local part = BloodBodyPartType.FromIndex(i)
        player:getHumanVisual():setBlood(part, amount)
    end
end

function WRC.Buffs.DoAddDirt(bodyPartStr)
    local player = getPlayer()
    setBodyPartDirt(player, bodyPartStr, 1)
    syncVisuals(player)
end

function WRC.Buffs.DoAddBlood(bodyPartStr)
    local player = getPlayer()
    setBodyPartBlood(player, bodyPartStr, 1)
    syncVisuals(player)
end

function WRC.Buffs.DoClean()
    local player = getPlayer()

    setBodyPartBlood(player, nil, 0)
    setBodyPartDirt(player, nil, 0)

    local wornClothing = player:getWornItems()
    for i=0,wornClothing:size()-1 do
        local item = wornClothing:get(i):getItem()
        if item:hasBlood() or item:hasDirt() then
            item:getVisual():removeBlood()
            item:getVisual():removeDirt()
        end
    end

    syncVisuals(player)
end

-- only debug

if getDebug() then
    function WRC.DebugBuffs()
        WRC.Buffs.LastApplied = 0
        WRC.Buffs.ApplyRpBuffs()
    end
end
