require("WLBaseObject")

---@class WastelandZones.Classes.WEZMigrater: WLBaseObject
---@field markerKey string
---@field legacyFileName string
local WEZMigrater = WastelandZones.Classes.WEZMigrater or WLBaseObject:derive("WastelandZones.Classes.WEZMigrater")
if not WastelandZones.Classes.WEZMigrater then
    WastelandZones.Classes.WEZMigrater = WEZMigrater
end

local Json = require "json"

local Area = WastelandZones.Classes.Area
local Zone = WastelandZones.Classes.Zone

local LEGACY_DEFAULTS = {
    mapType = "Event Zone",
    mapColor = { 0.3, 0.8, 0.8 },

    teleportX = 0,
    teleportY = 0,
    teleportZ = 0,

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

    warningBuffer = 0,
    warningMessage = "",
    enterMessage = "",
    exitMessage = "",
    inCars = false,
    inCarsMessage = "",
    rpText = "",

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

    noRiftZone = false,
    riftSpawnChance = 0,
    riftMinCount = 1,
    riftMaxCount = 5,
    riftMinRate = 0.5,
    riftMaxRate = 1,

    isNonThumpable = false,
    carTime = 1440
}

local UNSUPPORTED_FIELDS = {
    "mapType",
    "mapColor",
    "spawnInterval",
    "spawnCount",
    "spawnMax",
    "spawnRange",
    "spawnCatchup",
    "spawnCheckPlayers",
    "spawnPlayerRange",
    "isPlayerGatedToggle",
    "playerItemNameGated",
    "moodleIncrease",
    "moodleIncreaseRate",
    "isNonThumpable",
    "carTime"
}

local RIFT_FIELDS = {
    "noRiftZone",
    "riftSpawnChance",
    "riftMinCount",
    "riftMaxCount",
    "riftMinRate",
    "riftMaxRate"
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function toNumber(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    return n
end

local function toInt(value, fallback)
    local n = toNumber(value, fallback)
    if n == nil then
        return nil
    end
    return math.floor(n)
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function tableHasEntries(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    for _, _ in pairs(tbl) do
        return true
    end
    return false
end

local function deepCopy(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, nestedValue in pairs(value) do
        out[key] = deepCopy(nestedValue)
    end
    return out
end

local function mergeWithDefaults(defaults, source)
    local out = deepCopy(defaults)
    if type(source) ~= "table" then
        return out
    end

    for key, value in pairs(source) do
        if type(value) == "table" and type(out[key]) == "table" then
            out[key] = mergeWithDefaults(out[key], value)
        else
            out[key] = value
        end
    end

    return out
end

local function valuesEqual(a, b)
    local ta = type(a)
    local tb = type(b)
    if ta ~= tb then
        return false
    end

    if ta ~= "table" then
        return a == b
    end

    for key, valueA in pairs(a) do
        if not valuesEqual(valueA, b[key]) then
            return false
        end
    end

    for key, _ in pairs(b) do
        if a[key] == nil then
            return false
        end
    end

    return true
end

local function sortStrings(values)
    table.sort(values, function(a, b)
        return tostring(a) < tostring(b)
    end)
end

local function toCsv(values)
    if #values == 0 then
        return "(none)"
    end
    return table.concat(values, ", ")
end

local function normalizeItemList(raw)
    local source = tostring(raw or "")
    source = source:gsub(",", ";")
    local out = {}
    for piece in source:gmatch("([^;]+)") do
        local v = trim(piece)
        if v ~= "" then
            out[#out + 1] = v
        end
    end
    return table.concat(out, ";")
end

---@return WastelandZones.Classes.WEZMigrater
function WEZMigrater:new()
    local o = WEZMigrater.parentClass.new(self)
    o.markerKey = "WZ_WEZ_Migrated_v1"
    o.legacyFileName = "WastelandEventZones.json"
    return o
end

---@param message string
function WEZMigrater:_log(message)
    print("[WastelandZones][WEZMigrater] " .. tostring(message))
end

---@return table
function WEZMigrater:_getDefaults()
    return LEGACY_DEFAULTS
end

---@param zoneData table
---@return table
function WEZMigrater:_inflateZone(zoneData)
    return mergeWithDefaults(self:_getDefaults(), zoneData)
end

---@return table|nil, string
function WEZMigrater:_loadLegacyZonesFromDisk()
    local reader = getFileReader(self.legacyFileName, true)
    if not reader then
        return nil, "missing"
    end

    local json = ""
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end
        json = json .. line
    end
    reader:close()

    if trim(json) == "" then
        return {}, "empty"
    end

    local decoded = nil
    local ok, err = pcall(function()
        decoded = Json.Decode(json)
    end)
    if not ok then
        return nil, "decode_failed: " .. tostring(err)
    end

    if type(decoded) ~= "table" then
        return nil, "decode_failed: decoded payload is not a table"
    end

    return decoded, "ok"
end

---@param zoneValues table
---@param defaults table
---@return string[]
function WEZMigrater:_collectUnsupportedFields(zoneValues, defaults)
    local fields = {}

    for i = 1, #UNSUPPORTED_FIELDS do
        local field = UNSUPPORTED_FIELDS[i]
        if not valuesEqual(zoneValues[field], defaults[field]) then
            fields[#fields + 1] = field
        end
    end

    local hasRiftPlugin = WastelandZones.Plugins and WastelandZones.Plugins:get("RiftZones") ~= nil
    if not hasRiftPlugin then
        for i = 1, #RIFT_FIELDS do
            local field = RIFT_FIELDS[i]
            if not valuesEqual(zoneValues[field], defaults[field]) then
                fields[#fields + 1] = field
            end
        end
    end

    sortStrings(fields)
    return fields
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildZombieControl(zoneValues)
    local sprinters = toInt(clamp(toNumber(zoneValues.percentageSprinters, 0), 0, 100), 0)
    local fast = toInt(clamp(toNumber(zoneValues.percentageFastShamblers, 0), 0, 100), 0)
    local slow = toInt(clamp(toNumber(zoneValues.percentageSlowShamblers, 0), 0, 100), 0)
    local adjust = sprinters > 0 or fast > 0 or slow > 0

    local out = {
        preventZombies = zoneValues.preventZombies == true,
        killZombies = zoneValues.killZombies == true,
        adjustZombies = adjust,
        percentageSprinters = sprinters,
        percentageFastShamblers = fast,
        percentageSlowShamblers = slow
    }

    if out.preventZombies or out.killZombies or out.adjustZombies then
        return out
    end

    return nil
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildAccessControl(zoneValues)
    local out = {
        staffOnly = zoneValues.isAdminOnly == true,
        gateByPlayerName = zoneValues.isPlayerGated == true,
        allowedNamesCsv = trim(zoneValues.playersGated),
        gateByItem = zoneValues.isPlayerGatedItem == true,
        requiredItemFullType = trim(zoneValues.playerItemGated)
    }

    if out.staffOnly or out.gateByPlayerName or out.gateByItem or out.allowedNamesCsv ~= "" or out.requiredItemFullType ~= "" then
        return out
    end

    return nil
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildContainmentTeleport(zoneValues)
    local teleportX = toInt(zoneValues.teleportX, 0)
    local teleportY = toInt(zoneValues.teleportY, 0)
    local teleportZ = toInt(zoneValues.teleportZ, 0)
    local teleportEnabled = teleportX ~= 0 and teleportY ~= 0

    local out = {
        jailEnabled = zoneValues.isJail == true,
        teleportEnabled = teleportEnabled,
        teleportX = teleportX,
        teleportY = teleportY,
        teleportZ = teleportZ,
        staffBypass = true
    }

    if out.jailEnabled or out.teleportEnabled or teleportX ~= 0 or teleportY ~= 0 or teleportZ ~= 0 then
        return out
    end

    return nil
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildProtectionRules(zoneValues)
    if zoneValues.noDamage ~= true then
        return nil
    end

    return {
        noDamage = true,
        requireHealthyOnEnter = true,
        healWhileInside = true
    }
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildSurvivalHazard(zoneValues)
    local damageRate = toNumber(zoneValues.damageRate, 0) or 0
    local out = {
        damageRate = damageRate,
        damagePreventMaskToggle = zoneValues.damagePreventToggle == true,
        damagePreventItems = normalizeItemList(zoneValues.damagePreventItems)
    }

    if out.damageRate > 0 or out.damagePreventMaskToggle or out.damagePreventItems ~= "" then
        return out
    end

    return nil
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildInteractionRules(zoneValues)
    local out = {
        noFishing = zoneValues.noFishing == true,
        noThump = zoneValues.noThump == true,
        isQuiet = zoneValues.isQuiet == true,
        isScrapZone = zoneValues.isScrapZone == true,
        freeDeathZone = zoneValues.freeDeathZone == true,
        noDeforest = zoneValues.noDeforest == true,
        noBuild = zoneValues.noBuild == true,
        noPickup = zoneValues.noPickup == true,
        lockedMannequins = zoneValues.lockedMannequins == true,
        unlimitedWater = zoneValues.unlimitedWater == true
    }

    for _, value in pairs(out) do
        if value then
            return out
        end
    end

    return nil
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildPlayerNeeds(zoneValues)
    if zoneValues.isRpZone ~= true then
        return nil
    end

    return {
        needs = {
            { key = "Boredom", min = 0, adjustment = -100, max = 100 },
            { key = "Hunger", min = 0, adjustment = -100, max = 100 },
            { key = "Thirst", min = 0, adjustment = -100, max = 100 },
            { key = "Unhappiness", min = 0, adjustment = -100, max = 100 }
        }
    }
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildMessagingHints(zoneValues)
    local out = {
        warningBuffer = toInt(zoneValues.warningBuffer, 0),
        warningMessage = tostring(zoneValues.warningMessage or ""),
        enterMessage = tostring(zoneValues.enterMessage or ""),
        exitMessage = tostring(zoneValues.exitMessage or ""),
        inCars = zoneValues.inCars == true,
        inCarsMessage = tostring(zoneValues.inCarsMessage or ""),
        rpText = tostring(zoneValues.rpText or "")
    }

    if out.warningBuffer > 0 or out.inCars
        or out.warningMessage ~= ""
        or out.enterMessage ~= ""
        or out.exitMessage ~= ""
        or out.inCarsMessage ~= ""
        or out.rpText ~= "" then
        return out
    end

    return nil
end

---@return number
function WEZMigrater:_getClimateMaxWind()
    local climate = getClimateManager and getClimateManager() or nil
    if not climate then
        return 0
    end

    local maxWind = climate.getMaxWindspeedKph and climate:getMaxWindspeedKph() or nil
    return toNumber(maxWind, 0) or 0
end

---@param zoneValues table
---@return table|nil
function WEZMigrater:_buildWeatherOverride(zoneValues)
    local windEnabled = zoneValues.weatherWindEnabled == true
    local cloudsEnabled = zoneValues.weatherCloudsEnabled == true
    local fogEnabled = zoneValues.weatherFogEnabled == true
    local precipitationEnabled = zoneValues.weatherPrecipitationEnabled == true
    local temperatureEnabled = zoneValues.weatherTemperatureEnabled == true
    local darknessEnabled = zoneValues.weatherDarknessEnabled == true
    local desaturationEnabled = zoneValues.weatherDesaturationEnabled == true
    local lightEnabled = zoneValues.weatherLightEnabled == true

    if not windEnabled and not cloudsEnabled and not fogEnabled and not precipitationEnabled
        and not temperatureEnabled and not darknessEnabled and not desaturationEnabled and not lightEnabled then
        return nil
    end

    local wind = toNumber(zoneValues.weatherWind, 0) or 0
    if windEnabled then
        local maxWind = self:_getClimateMaxWind()
        if maxWind > 0 then
            wind = wind / maxWind
        end
    end

    return {
        transitionTicks = toInt(zoneValues.weatherTransitionTicks, 600),
        windEnabled = windEnabled,
        wind = wind,
        cloudsEnabled = cloudsEnabled,
        clouds = toNumber(zoneValues.weatherClouds, 0) or 0,
        fogEnabled = fogEnabled,
        fog = toNumber(zoneValues.weatherFog, 0) or 0,
        precipitationEnabled = precipitationEnabled,
        precipitation = toNumber(zoneValues.weatherPrecipitation, 0) or 0,
        precipitationIsSnow = zoneValues.weatherPrecipitationIsSnow == true,
        temperatureEnabled = temperatureEnabled,
        temperature = toNumber(zoneValues.weatherTemperature, 0) or 0,
        darknessEnabled = darknessEnabled,
        darkness = toNumber(zoneValues.weatherDarkness, 0) or 0,
        desaturationEnabled = desaturationEnabled,
        desaturation = toNumber(zoneValues.weatherDesaturation, 0) or 0,
        lightEnabled = lightEnabled,
        lightExtR = toNumber(zoneValues.weatherLightExtR, 0) or 0,
        lightExtG = toNumber(zoneValues.weatherLightExtG, 0) or 0,
        lightExtB = toNumber(zoneValues.weatherLightExtB, 0) or 0,
        lightExtA = toNumber(zoneValues.weatherLightExtA, 0) or 0,
        lightIntR = toNumber(zoneValues.weatherLightIntR, 0) or 0,
        lightIntG = toNumber(zoneValues.weatherLightIntG, 0) or 0,
        lightIntB = toNumber(zoneValues.weatherLightIntB, 0) or 0,
        lightIntA = toNumber(zoneValues.weatherLightIntA, 0) or 0
    }
end

---@param zoneValues table
---@param defaults table
---@return table|nil
function WEZMigrater:_buildRiftZones(zoneValues, defaults)
    local hasRiftPlugin = WastelandZones.Plugins and WastelandZones.Plugins:get("RiftZones") ~= nil
    if not hasRiftPlugin then
        return nil
    end

    local noSpawn = zoneValues.noRiftZone == true
    local chance = clamp(toNumber(zoneValues.riftSpawnChance, 0) or 0, 0, 100)
    local minCount = math.max(1, toInt(zoneValues.riftMinCount, 1))
    local maxCount = math.max(minCount, toInt(zoneValues.riftMaxCount, minCount))
    local minRate = math.max(0, toNumber(zoneValues.riftMinRate, 0.5) or 0.5)
    local maxRate = math.max(minRate, toNumber(zoneValues.riftMaxRate, minRate) or minRate)

    local shouldInclude = noSpawn
        or chance > 0
        or not valuesEqual(minCount, defaults.riftMinCount)
        or not valuesEqual(maxCount, defaults.riftMaxCount)
        or not valuesEqual(minRate, defaults.riftMinRate)
        or not valuesEqual(maxRate, defaults.riftMaxRate)

    if not shouldInclude then
        return nil
    end

    return {
        enabled = true,
        noSpawn = noSpawn,
        riftSpawnChance = chance,
        riftMinCount = minCount,
        riftMaxCount = maxCount,
        riftMinRate = minRate,
        riftMaxRate = maxRate
    }
end

---@param zoneValues table
---@param defaults table
---@return table<string, table>
function WEZMigrater:_buildPlugins(zoneValues, defaults)
    local plugins = {}

    local zombieControl = self:_buildZombieControl(zoneValues)
    if zombieControl then plugins.ZombieControl = zombieControl end

    local accessControl = self:_buildAccessControl(zoneValues)
    if accessControl then plugins.AccessControl = accessControl end

    local containmentTeleport = self:_buildContainmentTeleport(zoneValues)
    if containmentTeleport then plugins.ContainmentTeleport = containmentTeleport end

    local protectionRules = self:_buildProtectionRules(zoneValues)
    if protectionRules then plugins.ProtectionRules = protectionRules end

    local survivalHazard = self:_buildSurvivalHazard(zoneValues)
    if survivalHazard then plugins.SurvivalHazard = survivalHazard end

    local interactionRules = self:_buildInteractionRules(zoneValues)
    if interactionRules then plugins.InteractionRules = interactionRules end

    local playerNeeds = self:_buildPlayerNeeds(zoneValues)
    if playerNeeds then plugins.PlayerNeeds = playerNeeds end

    local messagingHints = self:_buildMessagingHints(zoneValues)
    if messagingHints then plugins.MessagingHints = messagingHints end

    local weatherOverride = self:_buildWeatherOverride(zoneValues)
    if weatherOverride then plugins.WeatherOverride = weatherOverride end

    local riftZones = self:_buildRiftZones(zoneValues, defaults)
    if riftZones then
        plugins.RiftZones = riftZones
    end

    return plugins
end

---@param rawSourceZones table
---@return table[]
function WEZMigrater:_collectSourceZones(rawSourceZones)
    local items = {}
    for sourceKey, zoneData in pairs(rawSourceZones) do
        if type(zoneData) == "table" then
            local sourceId = trim(zoneData.id)
            if sourceId == "" then
                sourceId = trim(sourceKey)
            end
            items[#items + 1] = {
                sourceKey = sourceKey,
                sourceId = sourceId,
                zoneData = zoneData
            }
        end
    end

    table.sort(items, function(a, b)
        local aId = tostring(a.sourceId or "")
        local bId = tostring(b.sourceId or "")
        if aId == bId then
            return tostring(a.sourceKey) < tostring(b.sourceKey)
        end
        return aId < bId
    end)

    return items
end

---@param values table
---@return WastelandZones.Classes.Area|nil, string|nil
function WEZMigrater:_buildArea(values)
    local minX = toInt(values.minX, nil)
    local minY = toInt(values.minY, nil)
    local minZ = toInt(values.minZ, nil)
    local maxX = toInt(values.maxX, nil)
    local maxY = toInt(values.maxY, nil)
    local maxZ = toInt(values.maxZ, nil)

    if minX == nil or minY == nil or minZ == nil or maxX == nil or maxY == nil or maxZ == nil then
        return nil, "missing or invalid WEZ bounds"
    end

    local x1 = math.min(minX, maxX)
    local y1 = math.min(minY, maxY)
    local z1 = math.min(minZ, maxZ)
    local x2 = math.max(minX, maxX)
    local y2 = math.max(minY, maxY)
    local z2 = math.max(minZ, maxZ)

    return Area:new(x1, y1, z1, x2, y2, z2), nil
end

---@param key string
---@return table
function WEZMigrater:_getMarkerData(key)
    local data = ModData.getOrCreate(key)
    if type(data) ~= "table" then
        data = {}
    end
    return data
end

---@return boolean
function WEZMigrater:_isAlreadyMigrated()
    local marker = self:_getMarkerData(self.markerKey)
    return marker.done == true
end

---@param summary table
function WEZMigrater:_setMarker(summary)
    local marker = self:_getMarkerData(self.markerKey)
    marker.done = true
    marker.at = getTimestamp()
    marker.sourceCount = summary.sourceCount
    marker.migratedCount = summary.migratedCount
    marker.skippedCount = summary.skippedCount
    marker.failedCount = summary.failedCount
    ModData.add(self.markerKey, marker)
end

---@param zoneValues table
---@param sourceId string
---@param createdThisRun table<string, boolean>
---@return WastelandZones.Classes.Zone|nil, string|nil, string|nil, string[]
function WEZMigrater:_convertOneZone(zoneValues, sourceId, createdThisRun)
    local defaults = self:_getDefaults()
    local unsupported = self:_collectUnsupportedFields(zoneValues, defaults)

    local area, areaErr = self:_buildArea(zoneValues)
    if not area then
        return nil, areaErr, nil, unsupported
    end

    local targetId = trim(zoneValues.id)
    if targetId == "" then
        targetId = trim(sourceId)
    end
    if targetId == "" then
        targetId = getRandomUUID()
    end

    local conflictNote = nil
    local existing = WastelandZones.Zones:get(targetId)
    if existing and not createdThisRun[targetId] then
        local oldId = targetId
        targetId = getRandomUUID()
        conflictNote = "zone id conflict on '" .. tostring(oldId) .. "', generated '" .. tostring(targetId) .. "'"
    end

    local zoneName = tostring(zoneValues.name or "")
    if zoneName == "" then
        zoneName = "Unnamed Zone"
    end

    local zone = Zone:new()
    zone.id = targetId
    zone.name = zoneName
    zone.areas = { area }
    zone.plugins = self:_buildPlugins(zoneValues, defaults)
    zone:init()

    return zone, nil, conflictNote, unsupported
end

---@return boolean, string
function WEZMigrater:_cleanupLegacyData()
    local ok, err = pcall(function()
        if type(WEZ_EventZones) == "table" then
            for key, _ in pairs(WEZ_EventZones) do
                WEZ_EventZones[key] = nil
            end
        else
            WEZ_EventZones = {}
        end

        if type(WEZ_EventZoneSpawnTimes) == "table" then
            for key, _ in pairs(WEZ_EventZoneSpawnTimes) do
                WEZ_EventZoneSpawnTimes[key] = nil
            end
        end

        if type(WEZ_ThumpZones) == "table" then
            for key, _ in pairs(WEZ_ThumpZones) do
                WEZ_ThumpZones[key] = nil
            end
        end

        if type(WEZ_UpdateZombieTrackZones) == "function" then
            WEZ_UpdateZombieTrackZones()
        end

        local keys = {
            "WEZ_EventZoneSpawnTimes",
            "WEZ_WEZ_ThumpZones"
        }
        for i = 1, #keys do
            local key = keys[i]
            local data = ModData.getOrCreate(key)
            if type(data) ~= "table" then
                data = {}
            end
            for entry, _ in pairs(data) do
                data[entry] = nil
            end
            ModData.add(key, data)
        end

        local writer = getFileWriter(self.legacyFileName, true, false)
        if not writer then
            error("failed to open legacy file writer")
        end
        writer:write("{}")
        writer:close()
    end)

    if not ok then
        return false, tostring(err)
    end

    return true, "ok"
end

---@return nil
function WEZMigrater:run()
    if isClient() then
        return
    end

    -- if self:_isAlreadyMigrated() then
    --     return
    -- end

    local rawSourceZones, loadStatus = self:_loadLegacyZonesFromDisk()
    if loadStatus == "missing" then
        return
    end

    if loadStatus ~= "ok" and loadStatus ~= "empty" then
        self:_log("migration aborted: failed to load legacy data from '" .. tostring(self.legacyFileName) .. "': " .. tostring(loadStatus))
        return
    end

    if type(rawSourceZones) ~= "table" then
        self:_log("migration aborted: legacy payload missing or invalid")
        return
    end

    local sourceZones = self:_collectSourceZones(rawSourceZones)
    local summary = {
        sourceCount = #sourceZones,
        migratedCount = 0,
        skippedCount = 0,
        failedCount = 0,
        unsupportedTotal = 0,
        unsupportedByZone = {},
        legacyDeleteStatus = "pending"
    }

    local createdThisRun = {}

    for i = 1, #sourceZones do
        local source = sourceZones[i]

        local converted, err = pcall(function()
            local expanded = self:_inflateZone(source.zoneData)
            local zone, zoneErr, conflictNote, unsupported = self:_convertOneZone(expanded, source.sourceId, createdThisRun)

            if unsupported and #unsupported > 0 then
                local groupKey = source.sourceId ~= "" and source.sourceId or tostring(source.sourceKey)
                summary.unsupportedByZone[groupKey] = unsupported
                summary.unsupportedTotal = summary.unsupportedTotal + #unsupported
            end

            if not zone then
                summary.skippedCount = summary.skippedCount + 1
                self:_log("zone skipped: sourceId='" .. tostring(source.sourceId) .. "' reason='" .. tostring(zoneErr) .. "'")
                return
            end

            WastelandZones.Zones:set(zone)
            createdThisRun[zone.id] = true
            summary.migratedCount = summary.migratedCount + 1

            local pluginKeys = {}
            for pluginType, _ in pairs(zone.plugins) do
                pluginKeys[#pluginKeys + 1] = tostring(pluginType)
            end
            sortStrings(pluginKeys)

            local unsupportedCsv = "(none)"
            local zoneKey = source.sourceId ~= "" and source.sourceId or tostring(source.sourceKey)
            if summary.unsupportedByZone[zoneKey] then
                unsupportedCsv = toCsv(summary.unsupportedByZone[zoneKey])
            end

            self:_log("zone migrated: sourceId='" .. tostring(source.sourceId)
                .. "' name='" .. tostring(zone.name)
                .. "' targetId='" .. tostring(zone.id)
                .. "' plugins=" .. toCsv(pluginKeys)
                .. " unsupported=" .. unsupportedCsv)

            if conflictNote then
                self:_log("zone note: sourceId='" .. tostring(source.sourceId) .. "' " .. conflictNote)
            end
        end)

        if not converted then
            summary.failedCount = summary.failedCount + 1
            self:_log("zone failed: sourceId='" .. tostring(source.sourceId) .. "' error='" .. tostring(err) .. "'")
        end
    end

    WastelandZones.Zones:flushSave()

    local deleted, deleteErr = self:_cleanupLegacyData()
    if deleted then
        summary.legacyDeleteStatus = "ok"
    else
        summary.legacyDeleteStatus = "failed: " .. tostring(deleteErr)
    end

    if deleted then
        self:_setMarker(summary)
    end

    self:_log("summary source=" .. tostring(summary.sourceCount)
        .. " migrated=" .. tostring(summary.migratedCount)
        .. " skipped=" .. tostring(summary.skippedCount)
        .. " failed=" .. tostring(summary.failedCount)
        .. " unsupportedTotal=" .. tostring(summary.unsupportedTotal)
        .. " legacyDeleteStatus='" .. tostring(summary.legacyDeleteStatus) .. "'")

    if tableHasEntries(summary.unsupportedByZone) then
        for zoneId, fields in pairs(summary.unsupportedByZone) do
            self:_log("unsupported zone='" .. tostring(zoneId) .. "' fields=" .. toCsv(fields))
        end
    end
end
