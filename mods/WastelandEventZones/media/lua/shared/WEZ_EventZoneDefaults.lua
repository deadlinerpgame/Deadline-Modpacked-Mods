WEZ_EventZoneDefaults = {}

WEZ_EventZoneDefaults.values = {
    mapType = "Event Zone",
    mapColor = {0.3, 0.8, 0.8},

    -- general
    teleportX = 0,
    teleportY = 0,
    teleportZ = 0,

    -- zombies
    preventZombies = false,
    killZombies = false,
    percentageSprinters = 0,
    percentageFastShamblers = 0,
    percentageSlowShamblers = 0,
    spawnInterval = 0,
    spawnCount = 0,
    spawnMax = 0,
    spawnRange = 0,
    spawnCatchup = false,
    spawnCheckPlayers = false,
    spawnPlayerRange = 0,
    noThump = false,

    -- players
    isAdminOnly = false,
    isPlayerGated = false,
    isPlayerGatedItem = false,
    isJail = false,
    isRpZone = false,
    noDamage = false,
    noFishing = false,
    isQuiet = false,
    isScrapZone = false,
    noDeforest = false,
    noBuild = false,
    noPickup = false,
    lockedMannequins = false,
    freeDeathZone = false,
    unlimitedWater = false,
    damageRate = 0,
    damagePreventToggle = false,
    damagePreventItems = "",
    moodleIncrease = 1,
    moodleIncreaseRate = 0,

    -- messages
    warningBuffer = 0,
    warningMessage = "",
    enterMessage = "",
    exitMessage = "",
    inCars = false,
    inCarsMessage = "",
    rpText = "",

    -- weather
    weatherTransitionTicks = 600,
    weatherWind = 0,
    weatherWindEnabled = false,
    weatherClouds = 0,
    weatherCloudsEnabled = false,
    weatherFog = 0,
    weatherFogEnabled = false,
    weatherPrecipitation = 0,
    weatherPrecipitationEnabled = false,
    weatherPrecipitationIsSnow = false,
    weatherTemperature = 0,
    weatherTemperatureEnabled = false,
    weatherDarkness = 0,
    weatherDarknessEnabled = false,
    weatherDesaturation = 0,
    weatherDesaturationEnabled = false,
    weatherLightExtR = 0,
    weatherLightExtG = 0,
    weatherLightExtB = 0,
    weatherLightExtA = 0,
    weatherLightIntR = 0,
    weatherLightIntG = 0,
    weatherLightIntB = 0,
    weatherLightIntA = 0,
    weatherLightEnabled = false,

    -- rifts
    noRiftZone = false,
    riftSpawnChance = 0,
    riftMinCount = 1,
    riftMaxCount = 5,
    riftMinRate = 0.5,
    riftMaxRate = 1,
    
    isNonThumpable = false,
    carTime = 1440,
    
}

local function isTableEmpty(t)
    if #t ~= 0 then
        return false
    end
    for _, _ in pairs(t) do
        return false
    end
    return true
end

--- gets the unique values in an object recursively compared to the defaults
function WEZ_EventZoneDefaults.getUniqueValues(obj, compareTo)
    compareTo = compareTo or WEZ_EventZoneDefaults.values
    local uniqueValues = {}

    for key, value in pairs(obj) do
        if type(value) == "table" then
            local subUniqueValues = WEZ_EventZoneDefaults.getUniqueValues(value, compareTo[key])
            -- Only add subUniqueValues if they are not empty
            if not isTableEmpty(subUniqueValues) then
                uniqueValues[key] = subUniqueValues
            end
        elseif WEZ_EventZoneDefaults.values[key] ~= value then
            uniqueValues[key] = value
        end
    end

    return uniqueValues
end

--- gets all values in an object, including defaults, recursively
function WEZ_EventZoneDefaults.getAllValues(obj, compareTo)
    compareTo = compareTo or WEZ_EventZoneDefaults.values
    local allValues = {}

    for key, value in pairs(compareTo) do
        if type(value) == "table" then
            if obj[key] and type(obj[key]) == "table" then
                allValues[key] = WEZ_EventZoneDefaults.getAllValues(obj[key], value)
            else
                allValues[key] = WEZ_EventZoneDefaults.getAllValues({}, value)
            end
        else
            if obj[key] == nil then
                allValues[key] = value
            else
                allValues[key] = obj[key]
            end
        end
    end

    for key, value in pairs(obj) do
        if not allValues[key] then
            allValues[key] = value
        end
    end

    return allValues
end
