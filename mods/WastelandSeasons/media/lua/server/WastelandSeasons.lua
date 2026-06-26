if isClient() then return end

WastelandSeasons = WastelandSeasons or {}

if WastelandSeasons.SERVER_INITIALIZED then
    Events.OnClientCommand.Remove(WastelandSeasons.OnClientCommand)
    Events.EveryHours.Remove(WastelandSeasons.CheckHourly)
    Events.OnInitGlobalModData.Remove(WastelandSeasons.OnInitGlobalModData)
    Events.EveryOneMinutes.Remove(WastelandSeasons.DoTriggerWeather)
end

local EVENT_DEFS_KEY = "WastelandSeasonsEventDefs"
local EVENT_DEFINITION_VERSION = WastelandSeasons.EVENT_DEFINITION_VERSION or 1
local STAFF_ALERT_HOURS = WastelandSeasons.DEFAULT_WARNING_HOURS or { 12, 6, 3, 2, 1 }

local FLOAT_GLOBAL_LIGHT_INTENSITY = 1
local FLOAT_PRECIPITATION_INTENSITY = 3
local FLOAT_FOG_INTENSITY = 5
local FLOAT_WIND_INTENSITY = 6
local COLOR_GLOBAL_LIGHT = 0
local BOOL_IS_SNOW = 0

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTableDeep(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for key, nestedValue in pairs(value) do
        out[key] = copyTableDeep(nestedValue)
    end
    return out
end

local function appendError(errors, message)
    errors[#errors + 1] = tostring(message)
end

local function hasEntries(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    for _, _ in pairs(tbl) do
        return true
    end
    return false
end

local function buildLookup(values)
    local out = {}
    for i = 1, #values do
        out[values[i]] = true
    end
    return out
end

local VALID_SEASONS = buildLookup(WastelandSeasons.SEASON_NAMES or { "Spring", "Early Summer", "Late Summer", "Autumn", "Winter" })
local VALID_PRECIPITATION = buildLookup(WastelandSeasons.PRECIPITATION_TYPES or { "none", "lightrain", "mediumrain", "heavyrain", "lightsnow", "mediumsnow", "heavysnow" })
local VALID_TRIGGERS = buildLookup(WastelandSeasons.TRIGGER_TYPES or { "blizzard", "tropicalstorm" })
local VALID_HARM_TYPES = buildLookup(WastelandSeasons.HARM_TYPES or { "none", "radiation", "acid" })
local VALID_TEMP_MODES = buildLookup(WastelandSeasons.TEMP_MODES or { "none", "adjust", "target" })

local function copyArray(values)
    local out = {}
    for i = 1, #values do
        out[i] = values[i]
    end
    return out
end

local function isValidEventId(id)
    return type(id) == "string" and string.match(id, "^[%a][%w_%-]*$") ~= nil
end

local function normalizeBoolean(value, defaultValue)
    if value == nil then
        return defaultValue == true
    end
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end

    local lowered = string.lower(trim(value))
    if lowered == "true" or lowered == "1" or lowered == "yes" or lowered == "on" then
        return true
    end
    if lowered == "false" or lowered == "0" or lowered == "no" or lowered == "off" then
        return false
    end
    return defaultValue == true
end

local function normalizeInteger(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return nil
    end
    return math.floor(numeric)
end

local function normalizeNumber(value)
    local numeric = tonumber(value)
    if numeric == nil then
        return nil
    end
    return numeric
end

local function normalizeRange(value, fieldName, errors, minAllowed, defaultMin, defaultMax)
    local minValue = nil
    local maxValue = nil
    if type(value) == "table" then
        minValue = normalizeInteger(value[1])
        maxValue = normalizeInteger(value[2])
    end

    if minValue == nil then
        appendError(errors, fieldName .. " minimum must be a whole number.")
        minValue = defaultMin
    end
    if maxValue == nil then
        appendError(errors, fieldName .. " maximum must be a whole number.")
        maxValue = defaultMax
    end

    if minValue < minAllowed then
        appendError(errors, fieldName .. " minimum must be at least " .. tostring(minAllowed) .. ".")
        minValue = minAllowed
    end
    if maxValue < minValue then
        appendError(errors, fieldName .. " maximum must be greater than or equal to the minimum.")
        maxValue = minValue
    end

    return { minValue, maxValue }
end

local function normalizeSeasons(value, errors)
    local source = type(value) == "table" and value or nil
    local dedupe = {}
    local out = {}
    if source then
        for i = 1, #source do
            local seasonName = trim(source[i])
            if seasonName ~= "" then
                if VALID_SEASONS[seasonName] then
                    if not dedupe[seasonName] then
                        dedupe[seasonName] = true
                        out[#out + 1] = seasonName
                    end
                else
                    appendError(errors, "Invalid season '" .. seasonName .. "'.")
                end
            end
        end
    end

    if #out == 0 then
        out = copyArray(WastelandSeasons.SEASON_NAMES or { "Spring", "Early Summer", "Late Summer", "Autumn", "Winter" })
    end
    return out
end

local function normalizeMessageValue(value, label, errors)
    if value == nil then
        return nil
    end

    if type(value) == "string" or type(value) == "number" then
        local text = trim(value)
        if text == "" then
            return nil
        end
        return text
    end

    if type(value) ~= "table" then
        appendError(errors, label .. " must be a string or an array of strings.")
        return nil
    end

    local out = {}
    for i = 1, #value do
        local entryText = trim(value[i])
        if entryText ~= "" then
            out[#out + 1] = entryText
        end
    end

    if #out == 0 then
        return nil
    end
    if #out == 1 then
        return out[1]
    end
    return out
end

local function normalizeMessages(messages, errors)
    local out = {}
    if type(messages) ~= "table" then
        return out
    end

    local startMessage = normalizeMessageValue(messages.start, "Start message", errors)
    if startMessage ~= nil then
        out.start = startMessage
    end

    local endMessage = normalizeMessageValue(messages["end"], "End message", errors)
    if endMessage ~= nil then
        out["end"] = endMessage
    end

    for key, value in pairs(messages) do
        if key ~= "start" and key ~= "end" then
            local hour = normalizeInteger(key)
            if hour ~= nil and hour >= 1 then
                local normalizedValue = normalizeMessageValue(value, "Message hour " .. tostring(hour), errors)
                if normalizedValue ~= nil then
                    out[hour] = normalizedValue
                end
            else
                appendError(errors, "Message key '" .. tostring(key) .. "' must be start, end, or a positive hour value.")
            end
        end
    end

    return out
end

local function normalizeTempMode(rawEvent)
    local mode = trim(rawEvent.tempMode)
    if mode == "" then
        if rawEvent.tempAdjust ~= nil then
            mode = "adjust"
        elseif rawEvent.tempTarget ~= nil then
            mode = "target"
        else
            mode = "none"
        end
    end
    return mode
end

local function normalizeDayColor(value, errors)
    if value == nil or type(value) ~= "table" then
        return nil
    end

    local channels = { "r", "g", "b", "a" }
    local out = {}
    local hasAny = false
    for i = 1, #channels do
        local channel = channels[i]
        local rawValue = value[channel]
        local textValue = trim(rawValue)
        local numeric = nil
        if textValue ~= "" then
            numeric = normalizeNumber(rawValue)
            hasAny = true
        end

        out[channel] = numeric
    end

    if not hasAny then
        return nil
    end

    for i = 1, #channels do
        local channel = channels[i]
        local numeric = out[channel]
        if numeric == nil then
            appendError(errors, "Day color channel '" .. channel .. "' must be numeric.")
            numeric = 0
        end
        if numeric < 0 or numeric > 1 then
            appendError(errors, "Day color channel '" .. channel .. "' must be between 0 and 1.")
            if numeric < 0 then
                numeric = 0
            else
                numeric = 1
            end
        end
        out[channel] = numeric
    end
    return out
end

local function normalizeOptionalNumber(value, fieldName, errors, minValue, maxValue)
    if value == nil or trim(value) == "" then
        return nil
    end

    local numeric = normalizeNumber(value)
    if numeric == nil then
        appendError(errors, fieldName .. " must be numeric.")
        return nil
    end
    if minValue ~= nil and numeric < minValue then
        appendError(errors, fieldName .. " must be at least " .. tostring(minValue) .. ".")
        numeric = minValue
    end
    if maxValue ~= nil and numeric > maxValue then
        appendError(errors, fieldName .. " must be at most " .. tostring(maxValue) .. ".")
        numeric = maxValue
    end
    return numeric
end

local function normalizeEventDefinition(rawEvent, fallbackId)
    local errors = {}
    local normalized = {}
    rawEvent = type(rawEvent) == "table" and rawEvent or {}

    local eventId = trim(rawEvent.id or fallbackId)
    if eventId == "" then
        appendError(errors, "Event id is required.")
    elseif not isValidEventId(eventId) then
        appendError(errors, "Event id must start with a letter and only contain letters, numbers, underscores, or hyphens.")
    else
        normalized.id = eventId
    end

    local eventName = trim(rawEvent.name)
    if eventName == "" then
        appendError(errors, "Event name is required.")
        eventName = eventId ~= "" and eventId or "Unnamed Event"
    end
    normalized.name = eventName

    normalized.enabled = normalizeBoolean(rawEvent.enabled, true)

    local chance = normalizeNumber(rawEvent.chance)
    if chance == nil then
        appendError(errors, "Chance must be numeric.")
        chance = 0
    elseif chance < 0 then
        appendError(errors, "Chance must be zero or greater.")
        chance = 0
    end
    normalized.chance = chance

    normalized.seasons = normalizeSeasons(rawEvent.seasons, errors)
    normalized.leadupHours = normalizeRange(rawEvent.leadupHours, "Lead-up hours", errors, 0, 1, 1)
    normalized.durationHours = normalizeRange(rawEvent.durationHours, "Duration hours", errors, 1, 1, 1)

    local tempMode = normalizeTempMode(rawEvent)
    if not VALID_TEMP_MODES[tempMode] then
        appendError(errors, "Temp mode must be none, adjust, or target.")
        tempMode = "none"
    end
    normalized.tempMode = tempMode

    if tempMode == "adjust" then
        normalized.tempAdjust = normalizeRange(rawEvent.tempAdjust, "Temp adjust", errors, -999, 0, 0)
        normalized.tempTarget = nil
    elseif tempMode == "target" then
        normalized.tempTarget = normalizeNumber(rawEvent.tempTarget)
        if normalized.tempTarget == nil then
            appendError(errors, "Temp target must be numeric when temp mode is target.")
            normalized.tempTarget = 0
        end
        normalized.tempAdjust = nil
    else
        normalized.tempAdjust = nil
        normalized.tempTarget = nil
    end

    local precipitation = trim(rawEvent.precipitation)
    if precipitation == "" or precipitation == "unchanged" then
        normalized.precipitation = nil
    elseif VALID_PRECIPITATION[precipitation] then
        normalized.precipitation = precipitation
    else
        appendError(errors, "Precipitation must be one of the supported precipitation values.")
        normalized.precipitation = nil
    end

    normalized.wind = normalizeOptionalNumber(rawEvent.wind, "Wind", errors, 0, 1)
    normalized.fog = normalizeOptionalNumber(rawEvent.fog, "Fog", errors, 0, 1)
    normalized.dayColor = normalizeDayColor(rawEvent.dayColor, errors)

    local trigger = trim(rawEvent.trigger)
    if trigger == "" or trigger == "none" then
        normalized.trigger = nil
    elseif VALID_TRIGGERS[trigger] then
        normalized.trigger = trigger
    else
        appendError(errors, "Trigger must be one of the supported storm triggers.")
        normalized.trigger = nil
    end

    local harmType = trim(rawEvent.harmType)
    if harmType == "" or harmType == "none" then
        normalized.harmType = nil
        normalized.harmRate = nil
    else
        if VALID_HARM_TYPES[harmType] then
            normalized.harmType = harmType
        else
            appendError(errors, "Harm type must be none, radiation, or acid.")
            normalized.harmType = nil
        end
        normalized.harmRate = normalizeOptionalNumber(rawEvent.harmRate, "Harm rate", errors, 0, 1000)
        if normalized.harmType ~= nil and normalized.harmRate == nil then
            appendError(errors, "Harm rate is required when harm type is set.")
            normalized.harmRate = 0
        end
    end

    normalized.messages = normalizeMessages(rawEvent.messages, errors)
    return normalized, errors
end

local function sortDefinitions(definitions)
    table.sort(definitions, function(left, right)
        local leftName = string.lower(trim(left.name or left.id))
        local rightName = string.lower(trim(right.name or right.id))
        if leftName == rightName then
            return string.lower(trim(left.id)) < string.lower(trim(right.id))
        end
        return leftName < rightName
    end)
end

local function findDefinitionIndex(definitions, eventId)
    for i = 1, #definitions do
        if definitions[i].id == eventId then
            return i
        end
    end
    return nil
end

local function definitionIdExists(definitions, eventId, ignoreId)
    for i = 1, #definitions do
        local definition = definitions[i]
        if definition.id == eventId and definition.id ~= ignoreId then
            return true
        end
    end
    return false
end

function WastelandSeasons.GetCurrentSeason()
    local season = getClimateManager():getSeason():getSeason()
    if season == 1 then
        return "Spring"
    elseif season == 2 then
        return "Early Summer"
    elseif season == 3 then
        return "Late Summer"
    elseif season == 4 then
        return "Autumn"
    elseif season == 5 then
        return "Winter"
    end
    return "Unknown"
end

function WastelandSeasons.SavePublic()
    ModData.add("WastelandSeasonsPublic", WastelandSeasons.Public)
    ModData.transmit("WastelandSeasonsPublic")
end

function WastelandSeasons.Save()
    ModData.add("WastelandSeasons", WastelandSeasons.Data)
end

function WastelandSeasons.SaveEventDefinitions()
    WastelandSeasons.EventDefsData.version = EVENT_DEFINITION_VERSION
    WastelandSeasons.EventDefsData.definitions = WastelandSeasons.EventDefinitions
    ModData.add(EVENT_DEFS_KEY, WastelandSeasons.EventDefsData)
end

function WastelandSeasons.RebuildEventDefinitionCache()
    WastelandSeasons.EventDefinitions = WastelandSeasons.EventDefinitions or {}
    WastelandSeasons.EventDefinitionsById = {}
    for i = 1, #WastelandSeasons.EventDefinitions do
        local definition = WastelandSeasons.EventDefinitions[i]
        WastelandSeasons.EventDefinitionsById[definition.id] = definition
    end
end

function WastelandSeasons.SeedEventDefinitionsFromLegacy()
    local seeded = {}
    for eventId, legacyEvent in pairs(WastelandSeasons.LegacyEvents or {}) do
        local normalizedEvent = normalizeEventDefinition(legacyEvent, eventId)
        if normalizedEvent.id ~= nil then
            seeded[#seeded + 1] = normalizedEvent
        end
    end
    sortDefinitions(seeded)
    WastelandSeasons.EventDefinitions = seeded
    WastelandSeasons.SaveEventDefinitions()
    WastelandSeasons.RebuildEventDefinitionCache()
end

function WastelandSeasons.LoadEventDefinitions()
    WastelandSeasons.EventDefsData = ModData.getOrCreate(EVENT_DEFS_KEY)
    if type(WastelandSeasons.EventDefsData.definitions) ~= "table" or #WastelandSeasons.EventDefsData.definitions == 0 then
        WastelandSeasons.SeedEventDefinitionsFromLegacy()
        return
    end

    local definitions = {}
    local seenIds = {}
    for i = 1, #WastelandSeasons.EventDefsData.definitions do
        local normalizedEvent, errors = normalizeEventDefinition(WastelandSeasons.EventDefsData.definitions[i])
        if normalizedEvent.id ~= nil then
            if not seenIds[normalizedEvent.id] then
                seenIds[normalizedEvent.id] = true
                if #errors > 0 then
                    print("[Wasteland Seasons] Normalized stored definition '" .. normalizedEvent.id .. "' with issues: " .. table.concat(errors, " | "))
                end
                definitions[#definitions + 1] = normalizedEvent
            else
                print("[Wasteland Seasons] Dropping duplicate stored definition id '" .. normalizedEvent.id .. "'.")
            end
        end
    end

    if #definitions == 0 then
        WastelandSeasons.SeedEventDefinitionsFromLegacy()
        return
    end

    sortDefinitions(definitions)
    WastelandSeasons.EventDefinitions = definitions
    WastelandSeasons.SaveEventDefinitions()
    WastelandSeasons.RebuildEventDefinitionCache()
end

function WastelandSeasons.GetEventDefinitionById(eventId)
    if not eventId then
        return nil
    end
    return WastelandSeasons.EventDefinitionsById and WastelandSeasons.EventDefinitionsById[eventId] or nil
end

function WastelandSeasons.GetActiveEventSnapshot()
    if type(WastelandSeasons.Data.activeEventSnapshot) ~= "table" then
        return nil
    end
    return WastelandSeasons.Data.activeEventSnapshot
end

function WastelandSeasons.RestoreActiveSnapshotIfNeeded()
    if WastelandSeasons.GetActiveEventSnapshot() ~= nil then
        return
    end
    if not WastelandSeasons.Data.scheduledEvent then
        return
    end

    local definition = WastelandSeasons.GetEventDefinitionById(WastelandSeasons.Data.scheduledEvent)
    if definition then
        WastelandSeasons.Data.activeEventSnapshot = copyTableDeep(definition)
        WastelandSeasons.Save()
        return
    end

    print("[Wasteland Seasons] Clearing scheduled event because no active snapshot or definition exists for '" .. tostring(WastelandSeasons.Data.scheduledEvent) .. "'.")
    WastelandSeasons.Data.scheduledEvent = nil
    WastelandSeasons.Data.scheduledEventStart = nil
    WastelandSeasons.Data.scheduledEventEnd = nil
    WastelandSeasons.Data.scheduledEventEndOverride = nil
    WastelandSeasons.Data.activeEventSnapshot = nil
    WastelandSeasons.Save()
end

local function getRandomRangeValue(range)
    if type(range) ~= "table" then
        return 0
    end

    local minValue = normalizeInteger(range[1]) or 0
    local maxValue = normalizeInteger(range[2]) or minValue
    if maxValue <= minValue then
        return minValue
    end
    return ZombRand(minValue, maxValue + 1)
end

local function getRuntimeStormInfo()
    local runtimeStormType = nil
    local runtimeStormDuration = nil
    local snapshot = WastelandSeasons.GetActiveEventSnapshot()
    if snapshot and snapshot.trigger and WastelandSeasons.Data.scheduledEventEnd and WastelandSeasons.Data.scheduledEventEnd > 0 and (WastelandSeasons.Data.scheduledEventStart or 0) <= 0 then
        runtimeStormType = snapshot.trigger
        runtimeStormDuration = WastelandSeasons.Data.scheduledEventEnd
    end

    if WastelandSeasons.Data.manualStormType then
        runtimeStormType = WastelandSeasons.Data.manualStormType
        runtimeStormDuration = WastelandSeasons.Data.manualStormDuration
    end

    return runtimeStormType, runtimeStormDuration
end

function WastelandSeasons.BuildAdminPayload()
    local snapshot = WastelandSeasons.GetActiveEventSnapshot()
    local stormType, stormDuration = getRuntimeStormInfo()
    return {
        schemaVersion = EVENT_DEFINITION_VERSION,
        definitions = copyTableDeep(WastelandSeasons.EventDefinitions or {}),
        runtime = {
            scheduledEvent = WastelandSeasons.Data.scheduledEvent,
            scheduledEventStart = WastelandSeasons.Data.scheduledEventStart,
            scheduledEventEnd = WastelandSeasons.Data.scheduledEventEnd,
            scheduledEventEndOverride = WastelandSeasons.Data.scheduledEventEndOverride,
            adjustedTemp = WastelandSeasons.Data.adjustedTemp,
            setPrecipitation = WastelandSeasons.Data.setPrecipitation,
            clearPrecipitation = WastelandSeasons.Data.clearPrecipitation == true,
            stormType = stormType,
            stormDuration = stormDuration,
            manualStormType = WastelandSeasons.Data.manualStormType,
            manualStormDuration = WastelandSeasons.Data.manualStormDuration,
            activeEventSnapshot = copyTableDeep(snapshot),
            harmType = WastelandSeasons.Public.harmType,
            harmRate = WastelandSeasons.Public.harmRate,
        }
    }
end

function WastelandSeasons.SendAdminData(player)
    sendServerCommand(player, "WastelandSeasons", "AdminData", WastelandSeasons.BuildAdminPayload())
end

function WastelandSeasons.SendAdminError(player, message)
    sendServerCommand(player, "WastelandSeasons", "AdminError", { message = tostring(message or "Unknown error") })
end

function WastelandSeasons.CreateActiveSnapshot(definition)
    return copyTableDeep(definition)
end

function WastelandSeasons.SetScheduledEvent(definition, startHours, durationOverride)
    WastelandSeasons.Data.scheduledEvent = definition.id
    WastelandSeasons.Data.scheduledEventStart = math.max(normalizeInteger(startHours) or 0, 0)
    WastelandSeasons.Data.scheduledEventEnd = nil
    WastelandSeasons.Data.scheduledEventEndOverride = normalizeInteger(durationOverride)
    WastelandSeasons.Data.activeEventSnapshot = WastelandSeasons.CreateActiveSnapshot(definition)
    WastelandSeasons.Save()
end

function WastelandSeasons.ClearScheduledEventState()
    WastelandSeasons.Data.scheduledEvent = nil
    WastelandSeasons.Data.scheduledEventStart = nil
    WastelandSeasons.Data.scheduledEventEnd = nil
    WastelandSeasons.Data.scheduledEventEndOverride = nil
    WastelandSeasons.Data.activeEventSnapshot = nil
    WastelandSeasons.Data.adjustedTemp = nil
end

function WastelandSeasons.RollEvent()
    local currentSeason = WastelandSeasons.GetCurrentSeason()
    local possibleEvents = {}
    for i = 1, #WastelandSeasons.EventDefinitions do
        local event = WastelandSeasons.EventDefinitions[i]
        local useEvent = event.enabled == true and event.chance and event.chance > 0
        if useEvent then
            useEvent = false
            for seasonIndex = 1, #event.seasons do
                if event.seasons[seasonIndex] == currentSeason then
                    useEvent = true
                    break
                end
            end
        end
        if useEvent then
            possibleEvents[#possibleEvents + 1] = { id = event.id, chance = event.chance }
        end
    end

    local selectedEvent = WL_Utils.weightedRandom(possibleEvents, "chance")
    if not selectedEvent then
        return
    end

    local definition = WastelandSeasons.GetEventDefinitionById(selectedEvent.id)
    if not definition then
        return
    end

    local startHours = getRandomRangeValue(definition.leadupHours)
    WastelandSeasons.SetScheduledEvent(definition, startHours, nil)
    print("[Wasteland Seasons] Scheduled event " .. definition.name .. " to start in " .. tostring(startHours) .. " hours")
end

function WastelandSeasons.TryAddEvent()
    if SandboxVars.WastelandSeasons.EnableEvents then
        local roll = ZombRand(SandboxVars.WastelandSeasons.EventChance)
        print("[Wasteland Seasons] Rolled " .. tostring(roll) .. " for event chance " .. tostring(SandboxVars.WastelandSeasons.EventChance))
        if roll == 0 then
            WastelandSeasons.RollEvent()
        end
    end
end

function WastelandSeasons.SendEnv(message)
    if type(message) == "table" then
        local index = ZombRand(1, #message + 1)
        message = message[index]
    end
    if trim(message) == "" then
        return
    end
    sendServerCommand("WastelandSeasons", "env", { message })
end

function WastelandSeasons.AlertStaffWeatherEventUpcoming()
    local snapshot = WastelandSeasons.GetActiveEventSnapshot()
    local startHours = WastelandSeasons.Data.scheduledEventStart
    if not snapshot or not startHours then
        return
    end

    local shouldAlert = false
    for i = 1, #STAFF_ALERT_HOURS do
        if STAFF_ALERT_HOURS[i] == startHours then
            shouldAlert = true
            break
        end
    end
    if not shouldAlert then
        return
    end

    local message = "<RGB:1,1,1>[Weather Event] " .. snapshot.name .. " starting in " .. tostring(startHours) .. " hours."
    local allPlayers = getOnlinePlayers()
    if allPlayers:size() == 0 then
        return
    end

    for i = 0, allPlayers:size() - 1 do
        local player = allPlayers:get(i)
        if WL_Utils.isStaff(player) then
            sendServerCommand(player, "WRC", "StaffChat", { "Weather Event", message })
        end
    end
end

function WastelandSeasons.TriggerWeather(triggerType, durationHours)
    local resolvedTrigger = triggerType or WastelandSeasons.Data.trigger
    if not resolvedTrigger then
        return
    end

    if resolvedTrigger == "clear" then
        getClimateManager():stopWeatherAndThunder()
        print("[Wasteland Seasons] Cleared weather")
    else
        local totalDuration = normalizeNumber(durationHours)
        if totalDuration == nil then
            totalDuration = normalizeNumber(WastelandSeasons.Data.scheduledEventEnd)
        end
        if totalDuration == nil then
            return
        end

        local actualDuration = math.max(totalDuration - 3.0, 1.0)
        if resolvedTrigger == "blizzard" then
            getClimateManager():triggerCustomWeatherStage(WeatherPeriod.STAGE_BLIZZARD, actualDuration)
            print("[Wasteland Seasons] Triggered blizzard for " .. tostring(actualDuration) .. " hours")
        elseif resolvedTrigger == "tropicalstorm" then
            getClimateManager():triggerCustomWeatherStage(WeatherPeriod.STAGE_TROPICAL_STORM, actualDuration)
            print("[Wasteland Seasons] Triggered tropical storm for " .. tostring(actualDuration) .. " hours")
        end
    end

    getClimateManager():updateEveryTenMins()
    if triggerType == nil then
        WastelandSeasons.Data.trigger = nil
        WastelandSeasons.Save()
    end
end

function WastelandSeasons.DoTriggerWeather()
    WastelandSeasons.TriggerWeather()
    Events.EveryOneMinutes.Remove(WastelandSeasons.DoTriggerWeather)
end

function WastelandSeasons.DoWind()
    local clim = getClimateManager()
    if WastelandSeasons.Data.setWind ~= nil then
        clim:getClimateFloat(FLOAT_WIND_INTENSITY):setEnableAdmin(true)
        clim:getClimateFloat(FLOAT_WIND_INTENSITY):setAdminValue(WastelandSeasons.Data.setWind)
        print("[Wasteland Seasons] Set wind to " .. tostring(WastelandSeasons.Data.setWind))
        getClimateManager():updateEveryTenMins()
    elseif WastelandSeasons.Data.clearWind then
        clim:getClimateFloat(FLOAT_WIND_INTENSITY):setEnableAdmin(false)
        WastelandSeasons.Data.clearWind = nil
        WastelandSeasons.Save()
        print("[Wasteland Seasons] Cleared wind")
        getClimateManager():updateEveryTenMins()
    end
end

function WastelandSeasons.DoFog()
    local clim = getClimateManager()
    if WastelandSeasons.Data.setFog ~= nil then
        clim:getClimateFloat(FLOAT_FOG_INTENSITY):setEnableAdmin(true)
        clim:getClimateFloat(FLOAT_FOG_INTENSITY):setAdminValue(WastelandSeasons.Data.setFog)
        print("[Wasteland Seasons] Set fog to " .. tostring(WastelandSeasons.Data.setFog))
        getClimateManager():updateEveryTenMins()
    elseif WastelandSeasons.Data.clearFog then
        clim:getClimateFloat(FLOAT_FOG_INTENSITY):setEnableAdmin(false)
        WastelandSeasons.Data.clearFog = nil
        WastelandSeasons.Save()
        print("[Wasteland Seasons] Cleared fog")
        getClimateManager():updateEveryTenMins()
    end
end

function WastelandSeasons.DoDayColor()
    local clim = getClimateManager()
    if WastelandSeasons.Data.setDayColor ~= nil then
        local color = WastelandSeasons.Data.setDayColor
        clim:getClimateFloat(FLOAT_GLOBAL_LIGHT_INTENSITY):setEnableAdmin(true)
        clim:getClimateColor(COLOR_GLOBAL_LIGHT):setEnableAdmin(true)
        clim:getClimateColor(COLOR_GLOBAL_LIGHT):setAdminValueExterior(color.r, color.g, color.b, color.a)
        clim:getClimateColor(COLOR_GLOBAL_LIGHT):setAdminValueInterior(color.r, color.g, color.b, color.a)
        print("[Wasteland Seasons] Set day color to " .. tostring(color.r) .. ", " .. tostring(color.g) .. ", " .. tostring(color.b) .. ", " .. tostring(color.a))
        getClimateManager():updateEveryTenMins()
    elseif WastelandSeasons.Data.clearDayColor then
        clim:getClimateFloat(FLOAT_GLOBAL_LIGHT_INTENSITY):setEnableAdmin(false)
        clim:getClimateColor(COLOR_GLOBAL_LIGHT):setEnableAdmin(false)
        WastelandSeasons.Data.clearDayColor = nil
        WastelandSeasons.Save()
        print("[Wasteland Seasons] Cleared day color")
        getClimateManager():updateEveryTenMins()
    end
end

function WastelandSeasons.DoPrecipitation()
    local clim = getClimateManager()
    if WastelandSeasons.Data.setPrecipitation then
        if WastelandSeasons.Data.setPrecipitation == "none" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(0)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(false)
            print("[Wasteland Seasons] Set precipitation to none")
        elseif WastelandSeasons.Data.setPrecipitation == "lightrain" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(0.3)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(false)
            print("[Wasteland Seasons] Set precipitation to light rain")
        elseif WastelandSeasons.Data.setPrecipitation == "mediumrain" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(0.6)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(false)
            print("[Wasteland Seasons] Set precipitation to medium rain")
        elseif WastelandSeasons.Data.setPrecipitation == "heavyrain" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(1)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(false)
            print("[Wasteland Seasons] Set precipitation to heavy rain")
        elseif WastelandSeasons.Data.setPrecipitation == "lightsnow" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(0.3)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(true)
            print("[Wasteland Seasons] Set precipitation to light snow")
        elseif WastelandSeasons.Data.setPrecipitation == "mediumsnow" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(0.6)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(true)
            print("[Wasteland Seasons] Set precipitation to medium snow")
        elseif WastelandSeasons.Data.setPrecipitation == "heavysnow" then
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(true)
            clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setAdminValue(1)
            clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(true)
            clim:getClimateBool(BOOL_IS_SNOW):setAdminValue(true)
            print("[Wasteland Seasons] Set precipitation to heavy snow")
        end
        getClimateManager():updateEveryTenMins()
    elseif WastelandSeasons.Data.clearPrecipitation then
        clim:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableAdmin(false)
        clim:getClimateBool(BOOL_IS_SNOW):setEnableAdmin(false)
        WastelandSeasons.Data.clearPrecipitation = nil
        WastelandSeasons.Save()
        print("[Wasteland Seasons] Cleared precipitation")
        getClimateManager():updateEveryTenMins()
    end
end

function WastelandSeasons.DoHarm(harmType, rate)
    WastelandSeasons.Public.harmType = harmType
    WastelandSeasons.Public.harmRate = rate
    WastelandSeasons.SavePublic()
end

function WastelandSeasons.WriteTemps()
    local fileWriter = getFileWriter("PzWebStats/weatherchange.txt", true, false)
    if not fileWriter then
        return
    end

    if WastelandSeasons.Data.adjustedTemp then
        fileWriter:writeln(tostring(SandboxVars.WastelandSeasons.BaseTempMin + WastelandSeasons.Data.adjustedTemp))
        fileWriter:writeln(tostring(SandboxVars.WastelandSeasons.BaseTempMax + WastelandSeasons.Data.adjustedTemp))
        print("[Wasteland Seasons] Adjusted temp " .. tostring(WastelandSeasons.Data.adjustedTemp))
    else
        fileWriter:writeln(tostring(SandboxVars.WastelandSeasons.BaseTempMin))
        fileWriter:writeln(tostring(SandboxVars.WastelandSeasons.BaseTempMax))
        print("[Wasteland Seasons] Reset temp")
    end
    fileWriter:close()
end

function WastelandSeasons.ProcessCurrentEvent()
    local event = WastelandSeasons.GetActiveEventSnapshot()
    if not event then
        WastelandSeasons.ClearScheduledEventState()
        WastelandSeasons.Save()
        return
    end

    if WastelandSeasons.Data.scheduledEventStart ~= nil and WastelandSeasons.Data.scheduledEventStart > 0 then
        WastelandSeasons.Data.scheduledEventStart = WastelandSeasons.Data.scheduledEventStart - 1
        print("[Wasteland Seasons] Event " .. event.name .. " starting in " .. tostring(WastelandSeasons.Data.scheduledEventStart) .. " hours")
        WastelandSeasons.AlertStaffWeatherEventUpcoming()

        if WastelandSeasons.Data.scheduledEventStart > 0 then
            if event.messages and event.messages[WastelandSeasons.Data.scheduledEventStart] then
                WastelandSeasons.SendEnv(event.messages[WastelandSeasons.Data.scheduledEventStart])
            end
        else
            WastelandSeasons.Data.scheduledEventStart = 0
            if WastelandSeasons.Data.scheduledEventEndOverride then
                WastelandSeasons.Data.scheduledEventEnd = WastelandSeasons.Data.scheduledEventEndOverride
                WastelandSeasons.Data.scheduledEventEndOverride = nil
            else
                WastelandSeasons.Data.scheduledEventEnd = getRandomRangeValue(event.durationHours)
            end

            if event.tempMode == "adjust" and event.tempAdjust then
                WastelandSeasons.Data.adjustedTemp = getRandomRangeValue(event.tempAdjust)
                WastelandSeasons.WriteTemps()
            elseif event.tempMode == "target" and event.tempTarget ~= nil then
                local dayMax = getClimateManager():getClimateForecaster():getForecast():getTemperature():getTotalMax()
                WastelandSeasons.Data.adjustedTemp = math.floor(event.tempTarget - dayMax)
                WastelandSeasons.WriteTemps()
            else
                WastelandSeasons.Data.adjustedTemp = 0
            end

            if event.precipitation then
                WastelandSeasons.Data.setPrecipitation = event.precipitation
                WastelandSeasons.Data.clearPrecipitation = false
                WastelandSeasons.DoPrecipitation()
            end
            if event.wind ~= nil then
                WastelandSeasons.Data.setWind = event.wind
                WastelandSeasons.Data.clearWind = false
                WastelandSeasons.DoWind()
            end
            if event.fog ~= nil then
                WastelandSeasons.Data.setFog = event.fog
                WastelandSeasons.Data.clearFog = false
                WastelandSeasons.DoFog()
            end
            if event.dayColor ~= nil then
                WastelandSeasons.Data.setDayColor = copyTableDeep(event.dayColor)
                WastelandSeasons.Data.clearDayColor = false
                WastelandSeasons.DoDayColor()
            end
            if event.trigger then
                WastelandSeasons.Data.trigger = event.trigger
                WastelandSeasons.TriggerWeather()
            end
            if event.harmType and event.harmRate then
                WastelandSeasons.DoHarm(event.harmType, event.harmRate)
            end
            if event.messages and event.messages.start then
                WastelandSeasons.SendEnv(event.messages.start)
            end
            print("[Wasteland Seasons] Event " .. event.name .. " starting for " .. tostring(WastelandSeasons.Data.scheduledEventEnd) .. " hours")
        end
    elseif WastelandSeasons.Data.scheduledEventEnd and WastelandSeasons.Data.scheduledEventEnd > 0 then
        WastelandSeasons.Data.scheduledEventEnd = WastelandSeasons.Data.scheduledEventEnd - 1
        print("[Wasteland Seasons] Event " .. event.name .. " ending in " .. tostring(WastelandSeasons.Data.scheduledEventEnd) .. " hours")
        if WastelandSeasons.Data.scheduledEventEnd <= 0 then
            if event.trigger then
                WastelandSeasons.Data.trigger = "clear"
                WastelandSeasons.TriggerWeather()
            end
            if event.precipitation then
                WastelandSeasons.Data.setPrecipitation = nil
                WastelandSeasons.Data.clearPrecipitation = true
                WastelandSeasons.DoPrecipitation()
            end
            if event.fog ~= nil then
                WastelandSeasons.Data.setFog = nil
                WastelandSeasons.Data.clearFog = true
                WastelandSeasons.DoFog()
            end
            if event.wind ~= nil then
                WastelandSeasons.Data.setWind = nil
                WastelandSeasons.Data.clearWind = true
                WastelandSeasons.DoWind()
            end
            if event.dayColor ~= nil then
                WastelandSeasons.Data.setDayColor = nil
                WastelandSeasons.Data.clearDayColor = true
                WastelandSeasons.DoDayColor()
            end
            if event.harmType then
                WastelandSeasons.DoHarm("none", 0)
            end
            if event.messages and event.messages["end"] then
                WastelandSeasons.SendEnv(event.messages["end"])
            end

            WastelandSeasons.ClearScheduledEventState()
            WastelandSeasons.Data.clearPrecipitation = true
            WastelandSeasons.Data.trigger = nil
            WastelandSeasons.Save()
            WastelandSeasons.WriteTemps()
            print("[Wasteland Seasons] Event " .. event.name .. " ending")
        end
    else
        WastelandSeasons.ClearScheduledEventState()
    end

    WastelandSeasons.Save()
end

function WastelandSeasons.CheckHourly()
    WastelandSeasons.TriggerWeather()

    if WastelandSeasons.Data.manualStormDuration and WastelandSeasons.Data.manualStormDuration > 0 then
        WastelandSeasons.Data.manualStormDuration = WastelandSeasons.Data.manualStormDuration - 1
        if WastelandSeasons.Data.manualStormDuration <= 0 then
            WastelandSeasons.Data.manualStormDuration = nil
            WastelandSeasons.Data.manualStormType = nil
        end
    end

    local gameTime = getGameTime()
    if gameTime:getMonth() == 11 and gameTime:getDay() == 24 then
        if WastelandSeasons.Data.scheduledEvent then
            if WastelandSeasons.Data.scheduledEventStart and WastelandSeasons.Data.scheduledEventStart > 0 then
                WastelandSeasons.ClearScheduledEventState()
                WastelandSeasons.Save()
            else
                WastelandSeasons.Data.scheduledEventEnd = 1
                WastelandSeasons.ProcessCurrentEvent()
            end
            print("[Wasteland Seasons] Force cancelled current event for Christmas")
        end
    end

    if WastelandSeasons.Data.scheduledEvent then
        WastelandSeasons.RestoreActiveSnapshotIfNeeded()
        if WastelandSeasons.GetActiveEventSnapshot() then
            WastelandSeasons.ProcessCurrentEvent()
        else
            WastelandSeasons.ClearScheduledEventState()
            if WastelandSeasons.Data.setPrecipitation then
                WastelandSeasons.Data.clearPrecipitation = true
            end
            WastelandSeasons.Save()
        end
    else
        WastelandSeasons.TryAddEvent()
    end

    if gameTime:getMonth() == 11 and gameTime:getDay() == 24 then
        WastelandSeasons.Data.setPrecipitation = "mediumsnow"
        WastelandSeasons.Data.clearPrecipitation = false
        WastelandSeasons.Save()
        WastelandSeasons.DoPrecipitation()
    elseif gameTime:getMonth() == 11 and gameTime:getDay() == 25 then
        WastelandSeasons.Data.setPrecipitation = nil
        WastelandSeasons.Data.clearPrecipitation = true
        WastelandSeasons.Save()
        WastelandSeasons.DoPrecipitation()
    end
end

function WastelandSeasons.OnInitGlobalModData()
    WastelandSeasons.Data = ModData.getOrCreate("WastelandSeasons")
    WastelandSeasons.Public = ModData.getOrCreate("WastelandSeasonsPublic")
    WastelandSeasons.LoadEventDefinitions()
    WastelandSeasons.RestoreActiveSnapshotIfNeeded()

    WastelandSeasons.DoPrecipitation()
    WastelandSeasons.DoWind()
    WastelandSeasons.DoFog()
    WastelandSeasons.DoDayColor()
    if WastelandSeasons.Data.trigger then
        Events.EveryOneMinutes.Add(WastelandSeasons.DoTriggerWeather)
    end
end

local function validateAndPrepareDefinition(existingId, rawEvent)
    local normalizedEvent, errors = normalizeEventDefinition(rawEvent)
    if normalizedEvent.id == nil then
        return nil, errors
    end

    if definitionIdExists(WastelandSeasons.EventDefinitions, normalizedEvent.id, existingId) then
        appendError(errors, "An event with id '" .. normalizedEvent.id .. "' already exists.")
    end

    if #errors > 0 then
        return nil, errors
    end
    return normalizedEvent, nil
end

local function collectErrorMessage(errors)
    if not errors or #errors == 0 then
        return "Unknown validation error."
    end
    return "Could not save event:\n - " .. table.concat(errors, "\n - ")
end

function WastelandSeasons.OnClientCommand(module, command, sendingPlayer, args)
    if module ~= "WastelandSeasons" then
        return
    end
    if not sendingPlayer or not WL_Utils.isStaff(sendingPlayer) then
        return
    end

    if command == "RequestAdminData" or command == "RequestData" then
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "CreateEvent" then
        local normalizedEvent, errors = validateAndPrepareDefinition(nil, args and args.event)
        if not normalizedEvent then
            WastelandSeasons.SendAdminError(sendingPlayer, collectErrorMessage(errors))
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        WastelandSeasons.EventDefinitions[#WastelandSeasons.EventDefinitions + 1] = normalizedEvent
        sortDefinitions(WastelandSeasons.EventDefinitions)
        WastelandSeasons.RebuildEventDefinitionCache()
        WastelandSeasons.SaveEventDefinitions()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " created event " .. normalizedEvent.id)
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "UpdateEvent" then
        local existingId = trim(args and args.existingId)
        if existingId == "" then
            WastelandSeasons.SendAdminError(sendingPlayer, "Missing existing event id for update.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        local existingIndex = findDefinitionIndex(WastelandSeasons.EventDefinitions, existingId)
        if not existingIndex then
            WastelandSeasons.SendAdminError(sendingPlayer, "Could not find event '" .. existingId .. "' to update.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        local normalizedEvent, errors = validateAndPrepareDefinition(existingId, args and args.event)
        if not normalizedEvent then
            WastelandSeasons.SendAdminError(sendingPlayer, collectErrorMessage(errors))
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        WastelandSeasons.EventDefinitions[existingIndex] = normalizedEvent
        sortDefinitions(WastelandSeasons.EventDefinitions)
        WastelandSeasons.RebuildEventDefinitionCache()
        WastelandSeasons.SaveEventDefinitions()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " updated event " .. existingId .. " -> " .. normalizedEvent.id)
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "DeleteEvent" then
        local eventId = trim(args and (args.id or args.eventId or args[1]))
        if eventId == "" then
            WastelandSeasons.SendAdminError(sendingPlayer, "Missing event id to delete.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        local existingIndex = findDefinitionIndex(WastelandSeasons.EventDefinitions, eventId)
        if not existingIndex then
            WastelandSeasons.SendAdminError(sendingPlayer, "Could not find event '" .. eventId .. "' to delete.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        table.remove(WastelandSeasons.EventDefinitions, existingIndex)
        WastelandSeasons.RebuildEventDefinitionCache()
        WastelandSeasons.SaveEventDefinitions()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " deleted event " .. eventId)
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "CancelEvent" then
        if WastelandSeasons.Data.scheduledEvent then
            if WastelandSeasons.Data.scheduledEventStart and WastelandSeasons.Data.scheduledEventStart > 0 then
                WastelandSeasons.ClearScheduledEventState()
                WastelandSeasons.Save()
            else
                WastelandSeasons.Data.scheduledEventEnd = 1
                WastelandSeasons.ProcessCurrentEvent()
            end
            print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " cancelled current event")
        end
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ScheduleEvent" then
        local eventId = trim(args and (args.eventId or args.id or args[1]))
        local startHours = normalizeInteger(args and (args.startHours or args[2])) or 0
        local durationHours = normalizeInteger(args and (args.durationHours or args[3]))
        local definition = WastelandSeasons.GetEventDefinitionById(eventId)
        if not definition then
            WastelandSeasons.SendAdminError(sendingPlayer, "Could not find event '" .. eventId .. "' to schedule.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        WastelandSeasons.SetScheduledEvent(definition, startHours + 1, durationHours)
        WastelandSeasons.ProcessCurrentEvent()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " scheduled event " .. definition.id)
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ForceEvent" then
        if WastelandSeasons.Data.scheduledEvent then
            WastelandSeasons.Data.scheduledEventStart = 1
            WastelandSeasons.ProcessCurrentEvent()
        end
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ForcePrecipitation" then
        local precipitation = trim(args and (args.precipitation or args[1]))
        if precipitation == "" or not VALID_PRECIPITATION[precipitation] then
            WastelandSeasons.SendAdminError(sendingPlayer, "Invalid precipitation value.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        WastelandSeasons.Data.setPrecipitation = precipitation
        WastelandSeasons.Data.clearPrecipitation = false
        WastelandSeasons.Save()
        WastelandSeasons.DoPrecipitation()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " forced precipitation to " .. precipitation)
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ClearPrecipitation" then
        WastelandSeasons.Data.setPrecipitation = nil
        WastelandSeasons.Data.clearPrecipitation = true
        WastelandSeasons.Save()
        WastelandSeasons.DoPrecipitation()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " cleared precipitation")
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ForceStorm" then
        local storm = trim(args and (args.storm or args[1]))
        local duration = normalizeInteger(args and (args.durationHours or args[2])) or 1
        if storm == "" or not VALID_TRIGGERS[storm] then
            WastelandSeasons.SendAdminError(sendingPlayer, "Invalid storm trigger value.")
            WastelandSeasons.SendAdminData(sendingPlayer)
            return
        end

        WastelandSeasons.Data.manualStormType = storm
        WastelandSeasons.Data.manualStormDuration = duration
        WastelandSeasons.Save()
        WastelandSeasons.TriggerWeather(storm, duration)
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " forced trigger to " .. storm .. " for " .. tostring(duration) .. " hours")
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "ClearStorm" then
        WastelandSeasons.Data.manualStormType = nil
        WastelandSeasons.Data.manualStormDuration = nil
        WastelandSeasons.Data.trigger = "clear"
        WastelandSeasons.Save()
        WastelandSeasons.TriggerWeather()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " cleared storm")
        WastelandSeasons.SendAdminData(sendingPlayer)
        return
    end

    if command == "WriteTemps" then
        WastelandSeasons.WriteTemps()
        print("[Wasteland Seasons] " .. sendingPlayer:getUsername() .. " wrote temps")
        WastelandSeasons.SendAdminData(sendingPlayer)
    end
end

Events.OnClientCommand.Add(WastelandSeasons.OnClientCommand)
Events.EveryHours.Add(WastelandSeasons.CheckHourly)
Events.OnInitGlobalModData.Add(WastelandSeasons.OnInitGlobalModData)

WastelandSeasons.SERVER_INITIALIZED = true
