---@class WastelandZones.Classes.Sounds: WastelandZones.Classes.Plugin
local Sounds = WastelandZones.Classes.Sounds or WastelandZones.Classes.Plugin:derive("WastelandZones.Classes.Plugins.Sounds")
if not WastelandZones.Classes.Sounds then
    WastelandZones.Classes.Sounds = Sounds
end

local runtime = {
    server = {
        byZone = {},
        lastEvalByZone = {}
    },
    client = {
        byZone = {},
        lastFadeEvalMs = 0
    }
}

local ensureServerZoneState

local FADE_DURATION_MS = 5000
local CLIENT_FADE_EVAL_INTERVAL_MS = 100
local AMBIANCE_TRACK_FALLBACK_MS = 30000
local DEBUG_LOGS_ENABLED = false

local function getRuntimeSideTag()
    if isClient() then
        return "Client"
    end
    return "Server"
end

local function toZoneIdLabel(zoneOrId)
    local zoneId = zoneOrId
    if type(zoneOrId) == "table" then
        zoneId = zoneOrId.id
    end
    return tostring(zoneId or "nil")
end

local function logSounds(message)
    if not DEBUG_LOGS_ENABLED then
        return
    end

    print(string.format("[WastelandZones][Sounds][%s] %s", getRuntimeSideTag(), tostring(message)))
end

local function trim(s)
    return tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function tableContains(list, value)
    for i = 1, #(list or {}) do
        if list[i] == value then
            return true
        end
    end
    return false
end

local function normalizeSoundList(raw)
    local out = {}
    if type(raw) ~= "table" then
        return out
    end

    for i = 1, #raw do
        local v = trim(raw[i])
        if v ~= "" then
            out[#out + 1] = v
        end
    end
    return out
end

local function toNumber(value, fallback)
    local n = tonumber(value)
    if not n then
        return fallback or 0
    end
    return n
end

local function clamp(n, low, high)
    if n < low then return low end
    if n > high then return high end
    return n
end

local function toVolume(value, fallback)
    return clamp(toNumber(value, fallback or 1), 0, 1)
end

local function toVolumeRange(minValue, maxValue, defaultMin, defaultMax)
    local minV = toVolume(minValue, defaultMin or 1)
    local maxV = toVolume(maxValue, defaultMax or 1)
    if minV > maxV then
        minV, maxV = maxV, minV
    end
    return minV, maxV
end

local function chooseRandomVolume(minValue, maxValue, defaultMin, defaultMax)
    local minV, maxV = toVolumeRange(minValue, maxValue, defaultMin or 1, defaultMax or 1)
    if minV == maxV then
        return minV
    end

    local t = ZombRand(1001) / 1000

    return minV + ((maxV - minV) * t)
end

local function secondsToMs(seconds, fallbackSeconds)
    local n = tonumber(seconds)
    if not n or n <= 0 then
        n = tonumber(fallbackSeconds) or 0
    end
    if n < 0 then n = 0 end
    return math.floor(n * 1000)
end

local soundLibraryCache = nil

local function buildSoundLibraryCache()
    if soundLibraryCache then
        return soundLibraryCache
    end

    local library = WSB_SoundLibrary or {}
    local durationsLibrary = WSB_SoundLibrary_Durations or {}
    local trueMusicLengths = WZ_TrueMusic_SongLengths or {}
    local categories = {}
    local byCategory = {}
    local categoryBySound = {}
    local durationBySound = {}

    for soundName, seconds in pairs(durationsLibrary) do
        local name = trim(soundName)
        local n = tonumber(seconds)
        if name ~= "" and n and n > 0 then
            durationBySound[name] = n
        end
    end

    for soundName, seconds in pairs(trueMusicLengths) do
        local name = trim(soundName)
        local n = tonumber(seconds)
        if name ~= "" and n and n > 0 then
            durationBySound[name] = n
        end
    end

    for category, sounds in pairs(library) do
        if type(category) == "string" and type(sounds) == "table" then
            categories[#categories + 1] = category
            local sortedSounds = {}
            for i = 1, #sounds do
                local soundName = trim(sounds[i])
                if soundName ~= "" then
                    sortedSounds[#sortedSounds + 1] = soundName
                    if not categoryBySound[soundName] then
                        categoryBySound[soundName] = category
                    end
                end
            end
            table.sort(sortedSounds)
            byCategory[category] = sortedSounds
        end
    end

    local trueMusicCategory = "TrueMusic"
    local trueMusicSounds = byCategory[trueMusicCategory] or {}
    local trueMusicSeen = {}

    for i = 1, #trueMusicSounds do
        trueMusicSeen[trueMusicSounds[i]] = true
    end

    for soundName, _ in pairs(trueMusicLengths) do
        local name = trim(soundName)
        if name ~= "" and not trueMusicSeen[name] then
            trueMusicSounds[#trueMusicSounds + 1] = name
            trueMusicSeen[name] = true
        end
    end

    if #trueMusicSounds > 0 then
        table.sort(trueMusicSounds)
        byCategory[trueMusicCategory] = trueMusicSounds

        if not tableContains(categories, trueMusicCategory) then
            categories[#categories + 1] = trueMusicCategory
        end

        for i = 1, #trueMusicSounds do
            local soundName = trueMusicSounds[i]
            categoryBySound[soundName] = trueMusicCategory
        end
    end

    table.sort(categories)
    soundLibraryCache = {
        categories = categories,
        byCategory = byCategory,
        categoryBySound = categoryBySound,
        durationBySound = durationBySound
    }
    return soundLibraryCache
end

local function toDelayMs(minSeconds, maxSeconds, defaultMin, defaultMax)
    local minS = math.floor(toNumber(minSeconds, defaultMin or 30))
    local maxS = math.floor(toNumber(maxSeconds, defaultMax or 90))
    minS = clamp(minS, 1, 24 * 60 * 60)
    maxS = clamp(maxS, 1, 24 * 60 * 60)
    if minS > maxS then
        minS, maxS = maxS, minS
    end

    if maxS == minS then
        return minS * 1000
    end

    return (ZombRand((maxS - minS) + 1) + minS) * 1000
end

---@param value number
---@param pct number
---@return number
local function fadeByPercent(value, pct)
    local current = tonumber(value) or 0
    return clamp(current * (1 - pct), 0, 100)
end

local function chooseRandom(items)
    if not items or #items == 0 then return nil end
    if #items == 1 then return items[1] end

    local idx = ZombRand(#items) + 1
    return items[idx]
end

local function toTimestampOrZero(value)
    local n = math.floor(toNumber(value, 0))
    if n < 0 then
        return 0
    end
    return n
end

local function areDesiredSoundStatesEqual(a, b)
    local aSound = trim(a and a.soundName)
    local bSound = trim(b and b.soundName)
    if aSound ~= bSound then return false end
    if toTimestampOrZero(a and a.startedAtMs) ~= toTimestampOrZero(b and b.startedAtMs) then return false end
    if toTimestampOrZero(a and a.expiresAtMs) ~= toTimestampOrZero(b and b.expiresAtMs) then return false end
    if math.abs(toVolume(a and a.volume, 1) - toVolume(b and b.volume, 1)) > 0.0001 then return false end
    return true
end

local function cloneDesiredSoundState(value)
    local soundName = trim(value and value.soundName)
    if soundName == "" then
        return {
            soundName = nil,
            startedAtMs = 0,
            expiresAtMs = 0,
            volume = 1
        }
    end

    return {
        soundName = soundName,
        startedAtMs = toTimestampOrZero(value.startedAtMs),
        expiresAtMs = toTimestampOrZero(value.expiresAtMs),
        volume = toVolume(value.volume, 1)
    }
end

local function buildServerUnifiedState(zone, data, nowMs)
    local zoneState = ensureServerZoneState(zone.id)
    local playlist = zoneState.playlist
    local ambiance = zoneState.ambiance

    local playlistSoundName = trim(playlist.soundName)
    local playlistState = {
        soundName = nil,
        startedAtMs = 0,
        expiresAtMs = 0,
        volume = toVolume(data.playlistVolume, 1)
    }

    if data.playlistEnabled == true and playlistSoundName ~= "" and playlist.expiresAtMs > nowMs then
        playlistState.soundName = playlistSoundName
        playlistState.startedAtMs = toTimestampOrZero(playlist.startedAtMs)
        playlistState.expiresAtMs = toTimestampOrZero(playlist.expiresAtMs)
    end

    local ambianceState = {
        zoneWide = data.ambianceZoneWide == true,
        enabled = data.ambianceEnabled == true,
        soundName = nil,
        startedAtMs = 0,
        expiresAtMs = 0,
        volume = 1
    }

    if ambianceState.enabled and ambianceState.zoneWide then
        local activeSoundName = trim(ambiance.activeSoundName)
        local activeExpiresAtMs = toTimestampOrZero(ambiance.activeExpiresAtMs)
        if activeSoundName ~= "" and activeExpiresAtMs > nowMs then
            ambianceState.soundName = activeSoundName
            ambianceState.startedAtMs = toTimestampOrZero(ambiance.activeStartedAtMs)
            ambianceState.expiresAtMs = activeExpiresAtMs
            ambianceState.volume = toVolume(ambiance.activeVolume, 1)
        end
    end

    return {
        playlist = playlistState,
        ambiance = ambianceState
    }
end

local function areUnifiedStatesEqual(a, b)
    if not a and not b then return true end
    if not a or not b then return false end

    if not areDesiredSoundStatesEqual(a.playlist, b.playlist) then
        return false
    end

    local aAmb = a.ambiance or {}
    local bAmb = b.ambiance or {}
    if (aAmb.enabled == true) ~= (bAmb.enabled == true) then
        return false
    end
    if (aAmb.zoneWide == true) ~= (bAmb.zoneWide == true) then
        return false
    end

    return areDesiredSoundStatesEqual(aAmb, bAmb)
end

local function cloneUnifiedState(value)
    local state = value or {}
    local ambiance = state.ambiance or {}
    local ambianceSoundState = cloneDesiredSoundState(ambiance)
    return {
        playlist = cloneDesiredSoundState(state.playlist),
        ambiance = {
            enabled = ambiance.enabled == true,
            zoneWide = ambiance.zoneWide == true,
            soundName = ambianceSoundState.soundName,
            startedAtMs = ambianceSoundState.startedAtMs,
            expiresAtMs = ambianceSoundState.expiresAtMs,
            volume = ambianceSoundState.volume
        }
    }
end

local function playSoundLocally(soundName, volume)
    local player = getPlayer()
    if not player then
        logSounds("playSoundLocally skipped: getPlayer() returned nil")
        return nil
    end
    if not soundName or soundName == "" then
        logSounds("playSoundLocally skipped: soundName is empty")
        return nil
    end

    local emitter = player:getEmitter()
    if not emitter then
        logSounds(string.format("playSoundLocally skipped for sound=%s: player emitter is nil", tostring(soundName)))
        return nil
    end
    local handle = emitter:playSoundImpl(soundName, nil)
    if volume then
        emitter:setVolume(handle, volume)
    end
    logSounds(string.format("playSoundLocally sound=%s handle=%s volume=%.3f", tostring(soundName), tostring(handle), toVolume(volume, 1)))
    return handle
end

local function stopLocalSound(handle)
    if not handle then return end
    local player = getPlayer()
    if not player then return end
    local emitter = player:getEmitter()
    if not emitter then return end
    emitter:stopSoundLocal(handle)
end

local function setLocalSoundVolume(handle, volume)
    if not handle then return end
    local player = getPlayer()
    if not player then return end
    local emitter = player:getEmitter()
    if not emitter then return end
    emitter:setVolume(handle, toVolume(volume, 1))
end

local function getClientFadeHandles(zoneState)
    zoneState.fadingHandles = zoneState.fadingHandles or {}
    return zoneState.fadingHandles
end

local function getClientAmbianceHandles(zoneState)
    zoneState.ambiance = zoneState.ambiance or { active = {} }
    zoneState.ambiance.active = zoneState.ambiance.active or {}
    return zoneState.ambiance.active
end

local function getClientZoneWideAmbianceState(zoneState)
    zoneState.ambiance = zoneState.ambiance or {}
    zoneState.ambiance.desired = zoneState.ambiance.desired or {
        enabled = false,
        zoneWide = false,
        soundName = nil,
        startedAtMs = 0,
        expiresAtMs = 0,
        volume = 1
    }
    return zoneState.ambiance
end

local function addClientFadeHandle(zoneState, handle, startVolume, fadeDurationMs)
    if not zoneState or not handle then return end

    local nowMs = getTimestampMs()
    local fades = getClientFadeHandles(zoneState)
    local durationMs = math.max(1, math.floor(toNumber(fadeDurationMs, FADE_DURATION_MS)))
    local volume = toVolume(startVolume, 1)

    for i = 1, #fades do
        local fade = fades[i]
        if fade.handle == handle then
            fade.startVolume = volume
            fade.startedAtMs = nowMs
            fade.fadeDurationMs = durationMs
            return
        end
    end

    fades[#fades + 1] = {
        handle = handle,
        startVolume = volume,
        startedAtMs = nowMs,
        fadeDurationMs = durationMs
    }
end

local function trackClientAmbianceHandle(zoneState, handle, volume, durationMs, nowMs)
    if not zoneState or not handle then return end

    local trackedDurationMs = math.floor(toNumber(durationMs, 0))
    if trackedDurationMs <= 0 then
        trackedDurationMs = AMBIANCE_TRACK_FALLBACK_MS
    end

    local active = getClientAmbianceHandles(zoneState)
    active[#active + 1] = {
        handle = handle,
        volume = toVolume(volume, 1),
        expiresAtMs = nowMs + trackedDurationMs
    }
end

local function fadeOutClientZoneSounds(zoneState, fadeDurationMs)
    if not zoneState then return end

    local playlist = zoneState.playlist
    if playlist and playlist.handle then
        addClientFadeHandle(zoneState, playlist.handle, playlist.activeVolume or playlist.volume, fadeDurationMs)
        playlist.handle = nil
        playlist.activeSound = nil
        playlist.activeVolume = nil
    end

    local activeAmbiance = getClientAmbianceHandles(zoneState)
    for i = 1, #activeAmbiance do
        local active = activeAmbiance[i]
        addClientFadeHandle(zoneState, active.handle, active.volume, fadeDurationMs)
    end

    local ambianceState = getClientZoneWideAmbianceState(zoneState)
    if ambianceState.zoneWideHandle then
        addClientFadeHandle(zoneState, ambianceState.zoneWideHandle, ambianceState.zoneWideActiveVolume or 1, fadeDurationMs)
        ambianceState.zoneWideHandle = nil
        ambianceState.zoneWideActiveSound = nil
        ambianceState.zoneWideActiveVolume = nil
    end

    zoneState.ambiance.active = {}
end

local function cleanupClientAmbianceHandles(zoneState, nowMs)
    local activeAmbiance = getClientAmbianceHandles(zoneState)
    for i = #activeAmbiance, 1, -1 do
        local active = activeAmbiance[i]
        local expiresAtMs = toNumber(active.expiresAtMs, 0)
        if expiresAtMs > 0 and nowMs >= expiresAtMs then
            table.remove(activeAmbiance, i)
        end
    end
end

local function updateClientZoneFadeHandles(zoneState, nowMs)
    local fades = getClientFadeHandles(zoneState)
    for i = #fades, 1, -1 do
        local fade = fades[i]
        local elapsedMs = nowMs - toNumber(fade.startedAtMs, nowMs)
        local durationMs = math.max(1, math.floor(toNumber(fade.fadeDurationMs, FADE_DURATION_MS)))
        local pct = clamp(elapsedMs / durationMs, 0, 1)
        local volume = toVolume(toNumber(fade.startVolume, 1) * (1 - pct), 0)
        setLocalSoundVolume(fade.handle, volume)

        if pct >= 1 then
            stopLocalSound(fade.handle)
            table.remove(fades, i)
        end
    end
end

local function evaluateClientFades(nowMs)
    local byZone = runtime.client.byZone
    for _, zoneState in pairs(byZone) do
        cleanupClientAmbianceHandles(zoneState, nowMs)
        updateClientZoneFadeHandles(zoneState, nowMs)
    end
end

local function onClientFadeTick()
    if not isClient() then return end

    local nowMs = getTimestampMs()
    local lastEvalMs = toNumber(runtime.client.lastFadeEvalMs, 0)
    if nowMs - lastEvalMs < CLIENT_FADE_EVAL_INTERVAL_MS then
        return
    end

    runtime.client.lastFadeEvalMs = nowMs
    evaluateClientFades(nowMs)
end

local function ensureClientZoneState(zoneId)
    local byZone = runtime.client.byZone
    local state = byZone[zoneId]
    if state then
        return state
    end

    state = {
        playlist = {
            soundName = nil,
            startedAtMs = 0,
            expiresAtMs = 0,
            handle = nil,
            activeSound = nil,
            activeVolume = nil,
            volume = 1
        },
        ambiance = {
            active = {},
            desired = {
                enabled = false,
                zoneWide = false,
                soundName = nil,
                startedAtMs = 0,
                expiresAtMs = 0,
                volume = 1
            },
            zoneWideHandle = nil,
            zoneWideActiveSound = nil,
            zoneWideActiveVolume = nil
        },
        fadingHandles = {},
        perPlayerAmbiance = {
            nextAtMs = 0
        }
    }
    byZone[zoneId] = state
    return state
end

ensureServerZoneState = function(zoneId)
    local byZone = runtime.server.byZone
    local state = byZone[zoneId]
    if state then
        return state
    end

    state = {
        playlist = {
            soundName = nil,
            startedAtMs = 0,
            expiresAtMs = 0,
            nextAtMs = 0,
            nextIndex = 1
        },
        ambiance = {
            nextAtMs = 0,
            activeSoundName = nil,
            activeStartedAtMs = 0,
            activeExpiresAtMs = 0,
            activeVolume = 1
        },
        subscribers = {},
        lastBroadcastState = nil
    }
    byZone[zoneId] = state
    return state
end

---@param username string
---@return IsoPlayer|nil
local function getOnlinePlayerByUsername(username)
    local target = trim(username)
    if target == "" then
        return nil
    end

    local onlinePlayers = getOnlinePlayers()
    if not onlinePlayers then
        return nil
    end

    local size = onlinePlayers:size()
    for i = 0, size - 1 do
        local onlinePlayer = onlinePlayers:get(i)
        if onlinePlayer and trim(onlinePlayer:getUsername()) == target then
            return onlinePlayer
        end
    end

    return nil
end

---@param zoneState table
---@param username string
---@return boolean
local function addZoneSubscriber(zoneState, username)
    local name = trim(username)
    if name == "" then
        return false
    end

    local subscribers = zoneState.subscribers
    for i = 1, #subscribers do
        if subscribers[i] == name then
            return false
        end
    end

    subscribers[#subscribers + 1] = name
    return true
end

---@param zoneState table
---@param username string
---@return boolean
local function removeZoneSubscriber(zoneState, username)
    local name = trim(username)
    if name == "" then
        return false
    end

    local subscribers = zoneState.subscribers
    for i = #subscribers, 1, -1 do
        if subscribers[i] == name then
            table.remove(subscribers, i)
            return true
        end
    end

    return false
end

---@param self WastelandZones.Classes.Sounds
---@param zone WastelandZones.Classes.Zone
---@param functionName string
---@param args table
function Sounds:_sendToZoneSubscribers(zone, functionName, args)
    local zoneState = ensureServerZoneState(zone.id)
    local subscribers = zoneState.subscribers
    for i = #subscribers, 1, -1 do
        local username = subscribers[i]
        local onlinePlayer = getOnlinePlayerByUsername(username)
        if onlinePlayer then
            self:sendCommandToClient(onlinePlayer, zone, functionName, args)
        else
            logSounds(string.format("_sendToZoneSubscribers zone=%s dropping offline subscriber username=%s", toZoneIdLabel(zone), tostring(username)))
            table.remove(subscribers, i)
        end
    end
end

---@param self WastelandZones.Classes.Sounds
---@param zone WastelandZones.Classes.Zone
---@param data table
---@param player IsoPlayer
function Sounds:_sendCurrentSoundStateToPlayer(zone, data, player)
    local nowMs = getTimestampMs()
    local unifiedState = buildServerUnifiedState(zone, data, nowMs)
    self:sendCommandToClient(player, zone, "receiveSoundData", {
        state = unifiedState
    })
    logSounds(string.format("_sendCurrentSoundStateToPlayer zone=%s username=%s sent unified state", toZoneIdLabel(zone), tostring(player:getUsername())))
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param nowMs number
---@param force boolean|nil
function Sounds:_broadcastUnifiedStateIfChanged(zone, data, nowMs, force)
    local zoneState = ensureServerZoneState(zone.id)
    local nextState = buildServerUnifiedState(zone, data, nowMs)
    if force == true or not areUnifiedStatesEqual(zoneState.lastBroadcastState, nextState) then
        self:_sendToZoneSubscribers(zone, "receiveSoundData", {
            state = nextState
        })
        zoneState.lastBroadcastState = cloneUnifiedState(nextState)
        logSounds(string.format("_broadcastUnifiedStateIfChanged zone=%s sent unified state", toZoneIdLabel(zone)))
    end
end

local function isPlayerInZone(zone)
    local player = getPlayer()
    if not player or not zone then
        return false
    end
    return zone:isPlayerIn(player)
end

---@return WastelandZones.Classes.Sounds
function Sounds:new()
    local o = Sounds.parentClass.new(self)
    o.type = "Sounds"
    o.priority = 60
    return o
end

---@param zone WastelandZones.Classes.Zone
---@param panel ISUIElement|any
---@param data table
function Sounds:buildPanel(zone, panel, data)
    local libraryData = buildSoundLibraryCache()
    local categories = libraryData.categories
    local byCategory = libraryData.byCategory
    local categoryBySound = libraryData.categoryBySound

    local function setupCategoryCombo(combo)
        combo:clear()
        combo:addOption("Select Category")
        for i = 1, #categories do
            local category = categories[i]
            combo:addOptionWithData(category, category)
        end
        combo.selected = 1
    end

    local function populateSoundCombo(categoryCombo, soundCombo, allowNone)
        soundCombo:clear()
        if allowNone then
            soundCombo:addOptionWithData("(None)", nil)
        else
            soundCombo:addOption("Select Sound")
        end

        local selectedCategory = categoryCombo:getOptionData(categoryCombo.selected)
        local sounds = selectedCategory and byCategory[selectedCategory] or nil
        for i = 1, #(sounds or {}) do
            local soundName = sounds[i]
            soundCombo:addOptionWithData(soundName, soundName)
        end
        soundCombo.selected = 1
    end

    local function selectSoundInCombos(categoryCombo, soundCombo, soundName, allowNone)
        local selectedSound = trim(soundName)
        if selectedSound == "" then
            if allowNone then
                soundCombo.selected = 1
            end
            return
        end

        local category = categoryBySound[selectedSound]
        if not category then
            if allowNone then
                soundCombo:addOptionWithData("(Existing) " .. selectedSound, selectedSound)
            else
                soundCombo:addOptionWithData(selectedSound, selectedSound)
            end
            soundCombo.selected = #soundCombo.options
            return
        end

        for i = 1, #categoryCombo.options do
            if categoryCombo.options[i].data == category then
                categoryCombo.selected = i
                break
            end
        end

        populateSoundCombo(categoryCombo, soundCombo, allowNone)

        for i = 1, #soundCombo.options do
            if soundCombo.options[i].data == selectedSound then
                soundCombo.selected = i
                return
            end
        end
    end

    local function buildStringList(listBox, values)
        listBox:clear()
        for i = 1, #(values or {}) do
            local v = values[i]
            listBox:addItem(v, v)
        end
    end

    local function applyCompactListStyling(listBox)
        listBox.itemheight = 16
        listBox.doDrawItem = function(_list, y, item, alt)
            if _list.selected == item.index then
                _list:drawRect(0, y, _list:getWidth(), _list.itemheight - 1, 0.3, 0.4, 0.4, 0.9)
            elseif alt then
                _list:drawRect(0, y, _list:getWidth(), _list.itemheight - 1, 0.1, 0.2, 0.2, 0.2)
            end

            _list:drawText(tostring(item.text or ""), 4, y + 1, 0.9, 0.9, 0.9, 1, UIFont.Small)
            return y + _list.itemheight
        end
    end

    local function getComboSelectedSound(soundCombo)
        if not soundCombo or not soundCombo.selected or soundCombo.selected < 1 then
            return ""
        end
        local selectedSound = soundCombo:getOptionData(soundCombo.selected)
        return trim(selectedSound)
    end

    panel._getComboSelectedSound = getComboSelectedSound

    local function bindVolumeSlider(slider, valueLabel, minValue, maxValue, step, stepSize, initialValue)
        local rowState = {}
        rowState.valueLabel = valueLabel
        rowState.slider = slider

        local function onVolumeChanged(state, _newValue)
            state.valueLabel:setName(string.format("%.2f", state.slider:getCurrentValue()))
        end

        slider.target = rowState
        slider.onChange = onVolumeChanged
        slider:setDoButtons(false)
        slider:setValues(minValue, maxValue, step, stepSize, true)
        slider:setCurrentValue(initialValue, true)
        onVolumeChanged(rowState, initialValue)
    end

    local savedAmbianceMinVolume, savedAmbianceMaxVolume = toVolumeRange(data.ambianceMinVolume, data.ambianceMaxVolume, 1, 1)
    panel.layout = { type = "rows", width = "inherit", height = "auto", pad = 6, margin = { 10, 20, 10, 10 }, rows = {
        { type = "label", id = "enterSoundLabel", width = "inherit", height = 18, text = "Enter sound" },
        { type = "columns", width = "inherit", height = 24, pad = 8, columns = {
            { type = "combobox", id = "enterSoundCategoryCombo", width = 140 },
            { type = "combobox", id = "enterSoundCombo", width = "*" }
        }},
        { type = "gap", width = "inherit", height = 6 },

        { type = "label", id = "exitSoundLabel", width = "inherit", height = 18, text = "Exit sound" },
        { type = "columns", width = "inherit", height = 24, pad = 8, columns = {
            { type = "combobox", id = "exitSoundCategoryCombo", width = 140 },
            { type = "combobox", id = "exitSoundCombo", width = "*" }
        }},
        { type = "gap", width = "inherit", height = 6 },

        { type = "tickbox", id = "noSoundsTickbox", width = "inherit", height = 20, options = { "No sounds" }, selected = { data.noSounds == true } },
        { type = "tickbox", id = "playlistEnabledTickbox", width = "inherit", height = 20, options = { "Enable playlist" }, selected = { data.playlistEnabled == true } },
        { type = "tickbox", id = "playlistRandomTickbox", width = "inherit", height = 20, options = { "Playlist random order (off = sequential)" }, selected = { data.playlistRandom ~= false } },

        { type = "label", id = "playlistSongsLabel", width = "inherit", height = 18, text = "Playlist sounds" },
        { type = "columns", width = "inherit", height = 24, pad = 8, columns = {
            { type = "combobox", id = "playlistCategoryCombo", width = 140 },
            { type = "combobox", id = "playlistSoundCombo", width = "*" },
            { type = "button", id = "playlistAddButton", width = 52, text = "Add", target = panel, onClick = function(_panel)
                local soundName = getComboSelectedSound(_panel.elements.playlistSoundCombo)
                if soundName == "" then return end
                if tableContains(_panel.playlistSelections, soundName) then return end
                _panel.playlistSelections[#_panel.playlistSelections + 1] = soundName
                buildStringList(_panel.elements.playlistList, _panel.playlistSelections)
            end }
        }},
        { type = "scrollinglistbox", id = "playlistList", width = "inherit", height = 96 },
        { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "button", id = "playlistRemoveButton", width = "*", text = "Remove Selected", target = panel, onClick = function(_panel)
                local row = _panel.elements.playlistList.selected
                if not row or row < 1 then return end
                local item = _panel.elements.playlistList.items[row]
                if not item or not item.item then return end
                table.remove(_panel.playlistSelections, row)
                buildStringList(_panel.elements.playlistList, _panel.playlistSelections)
            end },
            { type = "button", id = "playlistClearButton", width = "*", text = "Clear", target = panel, onClick = function(_panel)
                _panel.playlistSelections = {}
                buildStringList(_panel.elements.playlistList, _panel.playlistSelections)
            end }
        }},

        { type = "label", id = "playlistVolumeLabel", width = "inherit", height = 18, text = "Playlist volume" },
        { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "sliderpanel", id = "playlistVolumeSlider", width = "*", minValue = 0, maxValue = 1, stepValue = 0.01, shiftValue = 0.1, currentValue = toVolume(data.playlistVolume, 1), doButtons = false },
            { type = "label", id = "playlistVolumeValueLabel", width = 38, text = "1.00" }
        }},

        { type = "tickbox", id = "ambianceEnabledTickbox", width = "inherit", height = 20, options = { "Ambiance enabled" }, selected = { data.ambianceEnabled == true } },
        { type = "tickbox", id = "ambianceZoneWideTickbox", width = "inherit", height = 20, options = { "Ambiance zone-wide (off = per-player)" }, selected = { data.ambianceZoneWide == true } },

        { type = "label", id = "ambianceSoundsLabel", width = "inherit", height = 18, text = "Ambiance sounds" },
        { type = "columns", width = "inherit", height = 24, pad = 8, columns = {
            { type = "combobox", id = "ambianceCategoryCombo", width = 140 },
            { type = "combobox", id = "ambianceSoundCombo", width = "*" },
            { type = "button", id = "ambianceAddButton", width = 52, text = "Add", target = panel, onClick = function(_panel)
                local soundName = getComboSelectedSound(_panel.elements.ambianceSoundCombo)
                if soundName == "" then return end
                if tableContains(_panel.ambianceSelections, soundName) then return end
                _panel.ambianceSelections[#_panel.ambianceSelections + 1] = soundName
                buildStringList(_panel.elements.ambianceList, _panel.ambianceSelections)
            end }
        }},
        { type = "scrollinglistbox", id = "ambianceList", width = "inherit", height = 96 },
        { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "button", id = "ambianceRemoveButton", width = "*", text = "Remove Selected", target = panel, onClick = function(_panel)
                local row = _panel.elements.ambianceList.selected
                if not row or row < 1 then return end
                local item = _panel.elements.ambianceList.items[row]
                if not item or not item.item then return end
                table.remove(_panel.ambianceSelections, row)
                buildStringList(_panel.elements.ambianceList, _panel.ambianceSelections)
            end },
            { type = "button", id = "ambianceClearButton", width = "*", text = "Clear", target = panel, onClick = function(_panel)
                _panel.ambianceSelections = {}
                buildStringList(_panel.elements.ambianceList, _panel.ambianceSelections)
            end }
        }},

        { type = "label", id = "ambianceDelayLabel", width = "inherit", height = 18, text = "Ambiance delay min/max seconds" },
        { type = "columns", width = "inherit", height = 24, pad = 10, columns = {
            { type = "textbox", id = "ambianceDelayMinInput", width = 90, text = tostring(math.floor(toNumber(data.ambianceMinDelaySeconds, 30))), onlyNumbers = true },
            { type = "textbox", id = "ambianceDelayMaxInput", width = 90, text = tostring(math.floor(toNumber(data.ambianceMaxDelaySeconds, 90))), onlyNumbers = true },
            { type = "gap", width = "*" }
        }},

        { type = "label", id = "ambianceVolumeLabel", width = "inherit", height = 18, text = "Ambiance volume min/max" },
        { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "label", id = "ambianceMinVolumeText", width = 24, text = "Min", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
            { type = "sliderpanel", id = "ambianceMinVolumeSlider", width = "*", minValue = 0, maxValue = 1, stepValue = 0.01, shiftValue = 0.1, currentValue = savedAmbianceMinVolume, doButtons = false },
            { type = "label", id = "ambianceMinVolumeValueLabel", width = 38, text = "1.00" }
        }},
        { type = "columns", width = "inherit", height = 24, pad = 6, columns = {
            { type = "label", id = "ambianceMaxVolumeText", width = 24, text = "Max", color = { r = 0.9, g = 0.9, b = 0.9, a = 1 } },
            { type = "sliderpanel", id = "ambianceMaxVolumeSlider", width = "*", minValue = 0, maxValue = 1, stepValue = 0.01, shiftValue = 0.1, currentValue = savedAmbianceMaxVolume, doButtons = false },
            { type = "label", id = "ambianceMaxVolumeValueLabel", width = 38, text = "1.00" }
        }}
    }}

    panel.elements = LayoutManager:applyLayout(panel, panel.layout)

    setupCategoryCombo(panel.elements.enterSoundCategoryCombo)
    populateSoundCombo(panel.elements.enterSoundCategoryCombo, panel.elements.enterSoundCombo, true)
    panel.elements.enterSoundCategoryCombo.onChange = function()
        populateSoundCombo(panel.elements.enterSoundCategoryCombo, panel.elements.enterSoundCombo, true)
    end
    selectSoundInCombos(panel.elements.enterSoundCategoryCombo, panel.elements.enterSoundCombo, data.enterSound, true)

    setupCategoryCombo(panel.elements.exitSoundCategoryCombo)
    populateSoundCombo(panel.elements.exitSoundCategoryCombo, panel.elements.exitSoundCombo, true)
    panel.elements.exitSoundCategoryCombo.onChange = function()
        populateSoundCombo(panel.elements.exitSoundCategoryCombo, panel.elements.exitSoundCombo, true)
    end
    selectSoundInCombos(panel.elements.exitSoundCategoryCombo, panel.elements.exitSoundCombo, data.exitSound, true)

    setupCategoryCombo(panel.elements.playlistCategoryCombo)
    populateSoundCombo(panel.elements.playlistCategoryCombo, panel.elements.playlistSoundCombo, false)
    panel.elements.playlistCategoryCombo.onChange = function()
        populateSoundCombo(panel.elements.playlistCategoryCombo, panel.elements.playlistSoundCombo, false)
    end

    setupCategoryCombo(panel.elements.ambianceCategoryCombo)
    populateSoundCombo(panel.elements.ambianceCategoryCombo, panel.elements.ambianceSoundCombo, false)
    panel.elements.ambianceCategoryCombo.onChange = function()
        populateSoundCombo(panel.elements.ambianceCategoryCombo, panel.elements.ambianceSoundCombo, false)
    end

    applyCompactListStyling(panel.elements.playlistList)
    panel.playlistSelections = normalizeSoundList(data.playlistSounds)
    buildStringList(panel.elements.playlistList, panel.playlistSelections)

    applyCompactListStyling(panel.elements.ambianceList)
    panel.ambianceSelections = normalizeSoundList(data.ambianceSounds)
    buildStringList(panel.elements.ambianceList, panel.ambianceSelections)

    panel.elements.ambianceDelayMinInput:setOnlyNumbers(true)
    panel.elements.ambianceDelayMaxInput:setOnlyNumbers(true)

    bindVolumeSlider(panel.elements.playlistVolumeSlider, panel.elements.playlistVolumeValueLabel, 0, 1, 0.01, 0.1, toVolume(data.playlistVolume, 1))
    bindVolumeSlider(panel.elements.ambianceMinVolumeSlider, panel.elements.ambianceMinVolumeValueLabel, 0, 1, 0.01, 0.1, savedAmbianceMinVolume)
    bindVolumeSlider(panel.elements.ambianceMaxVolumeSlider, panel.elements.ambianceMaxVolumeValueLabel, 0, 1, 0.01, 0.1, savedAmbianceMaxVolume)

end

---@param panel ISUIElement
---@return table
function Sounds:getSaveData(panel)
    local enterSound = panel._getComboSelectedSound(panel.elements.enterSoundCombo)
    local exitSound = panel._getComboSelectedSound(panel.elements.exitSoundCombo)

    local playlistSelections = normalizeSoundList(panel.playlistSelections)
    local ambianceSelections = normalizeSoundList(panel.ambianceSelections)

    return {
        noSounds = panel.elements.noSoundsTickbox:isSelected(1) == true,
        playlistEnabled = panel.elements.playlistEnabledTickbox:isSelected(1) == true,
        playlistRandom = panel.elements.playlistRandomTickbox:isSelected(1) == true,
        ambianceEnabled = panel.elements.ambianceEnabledTickbox:isSelected(1) == true,
        ambianceZoneWide = panel.elements.ambianceZoneWideTickbox:isSelected(1) == true,
        enterSound = enterSound,
        exitSound = exitSound,
        playlistSounds = playlistSelections,
        playlistVolume = toVolume(panel.elements.playlistVolumeSlider:getCurrentValue(), 1),
        ambianceSounds = ambianceSelections,
        ambianceMinVolume = toVolume(panel.elements.ambianceMinVolumeSlider:getCurrentValue(), 1),
        ambianceMaxVolume = toVolume(panel.elements.ambianceMaxVolumeSlider:getCurrentValue(), 1),
        ambianceMinDelaySeconds = math.floor(toNumber(panel.elements.ambianceDelayMinInput:getText(), 30)),
        ambianceMaxDelaySeconds = math.floor(toNumber(panel.elements.ambianceDelayMaxInput:getText(), 90))
    }
end

---@param data table
---@return table
function Sounds:serialize(data)
    local ret = {}

    local playlistSounds = normalizeSoundList(data.playlistSounds)
    local ambianceSounds = normalizeSoundList(data.ambianceSounds)

    if data.noSounds then ret.noSounds = true end
    if data.playlistEnabled then ret.playlistEnabled = true end
    if data.playlistRandom == false then ret.playlistRandom = false end
    if data.ambianceEnabled then ret.ambianceEnabled = true end
    if data.ambianceZoneWide then ret.ambianceZoneWide = true end
    if trim(data.enterSound) ~= "" then ret.enterSound = trim(data.enterSound) end
    if trim(data.exitSound) ~= "" then ret.exitSound = trim(data.exitSound) end
    if #playlistSounds > 0 then ret.playlistSounds = playlistSounds end
    local playlistVolume = toVolume(data.playlistVolume, 1)
    if playlistVolume ~= 1 then ret.playlistVolume = playlistVolume end
    if #ambianceSounds > 0 then ret.ambianceSounds = ambianceSounds end
    local ambianceMinVolume, ambianceMaxVolume = toVolumeRange(data.ambianceMinVolume, data.ambianceMaxVolume, 1, 1)
    if ambianceMinVolume ~= 1 then ret.ambianceMinVolume = ambianceMinVolume end
    if ambianceMaxVolume ~= 1 then ret.ambianceMaxVolume = ambianceMaxVolume end

    local aMin = math.floor(toNumber(data.ambianceMinDelaySeconds, 30))
    local aMax = math.floor(toNumber(data.ambianceMaxDelaySeconds, 90))

    if aMin ~= 30 then ret.ambianceMinDelaySeconds = aMin end
    if aMax ~= 90 then ret.ambianceMaxDelaySeconds = aMax end

    return ret
end

---@param data table
---@return table
function Sounds:deserialize(data)
    local ambianceMinVolume, ambianceMaxVolume = toVolumeRange(data.ambianceMinVolume, data.ambianceMaxVolume, 1, 1)
    local playlistSounds = normalizeSoundList(data.playlistSounds)
    local ambianceSounds = normalizeSoundList(data.ambianceSounds)

    return {
        noSounds = data.noSounds == true,
        playlistEnabled = data.playlistEnabled == true,
        playlistRandom = data.playlistRandom ~= false,
        ambianceEnabled = data.ambianceEnabled == true,
        ambianceZoneWide = data.ambianceZoneWide == true,
        enterSound = tostring(data.enterSound or ""),
        exitSound = tostring(data.exitSound or ""),
        playlistSounds = playlistSounds,
        playlistVolume = toVolume(data.playlistVolume, 1),
        ambianceSounds = ambianceSounds,
        ambianceMinVolume = ambianceMinVolume,
        ambianceMaxVolume = ambianceMaxVolume,
        ambianceMinDelaySeconds = math.floor(toNumber(data.ambianceMinDelaySeconds, 30)),
        ambianceMaxDelaySeconds = math.floor(toNumber(data.ambianceMaxDelaySeconds, 90))
    }
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param soundName string
---@param fallbackSeconds number|nil
---@return number
function Sounds:_getSoundDurationMs(zone, data, soundName, fallbackSeconds)
    local name = trim(soundName)
    if name == "" then
        logSounds(string.format("_getSoundDurationMs zone=%s: empty soundName, fallbackSeconds=%s", toZoneIdLabel(zone), tostring(fallbackSeconds)))
        return secondsToMs(fallbackSeconds, 0)
    end

    local seconds = nil
    local cache = buildSoundLibraryCache()
    if cache and type(cache.durationBySound) == "table" then
        seconds = tonumber(cache.durationBySound[name])
    end

    local durationMs = secondsToMs(seconds, fallbackSeconds)
    logSounds(string.format("_getSoundDurationMs zone=%s sound=%s seconds=%s durationMs=%d", toZoneIdLabel(zone), name, tostring(seconds), durationMs))
    return durationMs
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param args table
function Sounds:receiveSoundData(zone, data, args)
    if not args or not zone then return end
    local zoneId = zone.id
    local zoneState = ensureClientZoneState(zoneId)
    local unifiedState = args.state or {}
    local playlistState = cloneDesiredSoundState(unifiedState.playlist)
    local ambianceUnified = unifiedState.ambiance or {}
    local ambianceState = cloneDesiredSoundState(ambianceUnified)
    local clientAmbiance = getClientZoneWideAmbianceState(zoneState)

    zoneState.playlist.soundName = playlistState.soundName
    zoneState.playlist.startedAtMs = playlistState.startedAtMs
    zoneState.playlist.expiresAtMs = playlistState.expiresAtMs
    zoneState.playlist.volume = playlistState.volume

    clientAmbiance.desired.enabled = ambianceUnified.enabled == true
    clientAmbiance.desired.zoneWide = ambianceUnified.zoneWide == true
    clientAmbiance.desired.soundName = ambianceState.soundName
    clientAmbiance.desired.startedAtMs = ambianceState.startedAtMs
    clientAmbiance.desired.expiresAtMs = ambianceState.expiresAtMs
    clientAmbiance.desired.volume = ambianceState.volume

    logSounds(string.format(
        "receiveSoundData zone=%s playlist=%s ambiance=%s ambianceZoneWide=%s",
        toZoneIdLabel(zoneId),
        tostring(zoneState.playlist.soundName),
        tostring(clientAmbiance.desired.soundName),
        tostring(clientAmbiance.desired.zoneWide)
    ))

    if not isPlayerInZone(zone) then
        fadeOutClientZoneSounds(zoneState, FADE_DURATION_MS)
    end
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@return table, table
function Sounds:_getServerPlaylistState(zone, data)
    local zoneState = ensureServerZoneState(zone.id)
    local playlist = zoneState.playlist
    local sounds = data.playlistSounds
    if type(sounds) ~= "table" then
        sounds = {}
    end
    if #sounds <= 0 then
        playlist.nextIndex = 1
    elseif playlist.nextIndex < 1 or playlist.nextIndex > #sounds then
        playlist.nextIndex = 1
    end
    return playlist, sounds
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param nowMs number
function Sounds:_runServerPlaylist(zone, data, nowMs)
    local playlist, sounds = self:_getServerPlaylistState(zone, data)
    if data.playlistEnabled ~= true or #sounds == 0 then
        if playlist.soundName then
            logSounds(string.format("_runServerPlaylist zone=%s clearing active playlist sound=%s", toZoneIdLabel(zone), tostring(playlist.soundName)))
            playlist.soundName = nil
            playlist.startedAtMs = 0
            playlist.expiresAtMs = 0
            playlist.nextAtMs = 0
            playlist.nextIndex = 1
        end
        return
    end

    if playlist.nextAtMs <= 0 then
        playlist.nextAtMs = nowMs
    end

    if nowMs < playlist.nextAtMs then
        return
    end

    local soundName = nil
    if data.playlistRandom == false then
        local nextIndex = playlist.nextIndex
        if nextIndex < 1 or nextIndex > #sounds then
            nextIndex = 1
        end

        soundName = sounds[nextIndex]
        nextIndex = nextIndex + 1
        if nextIndex > #sounds then
            nextIndex = 1
        end
        playlist.nextIndex = nextIndex
    else
        soundName = chooseRandom(sounds)
    end

    if not soundName or soundName == "" then
        logSounds(string.format("_runServerPlaylist zone=%s selected empty sound; retrying in 1000ms", toZoneIdLabel(zone)))
        playlist.nextAtMs = nowMs + 1000
        return
    end

    local soundDurationMs = self:_getSoundDurationMs(zone, data, soundName, 0)

    playlist.soundName = soundName
    playlist.startedAtMs = nowMs
    playlist.expiresAtMs = nowMs + soundDurationMs
    playlist.nextAtMs = playlist.expiresAtMs + 1000

    logSounds(string.format(
        "_runServerPlaylist zone=%s start sound=%s volume=%.3f startedAtMs=%d expiresAtMs=%d nextAtMs=%d",
        toZoneIdLabel(zone),
        tostring(soundName),
        toVolume(data.playlistVolume, 1),
        playlist.startedAtMs,
        playlist.expiresAtMs,
        playlist.nextAtMs
    ))

    return
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param nowMs number
function Sounds:_runServerAmbianceZoneWide(zone, data, nowMs)
    local zoneState = ensureServerZoneState(zone.id)
    local ambiance = zoneState.ambiance

    if ambiance.activeSoundName and ambiance.activeExpiresAtMs > 0 and nowMs >= ambiance.activeExpiresAtMs then
        ambiance.activeSoundName = nil
        ambiance.activeStartedAtMs = 0
        ambiance.activeExpiresAtMs = 0
        ambiance.activeVolume = 1
    end

    if not data.ambianceEnabled then
        ambiance.nextAtMs = 0
        ambiance.activeSoundName = nil
        ambiance.activeStartedAtMs = 0
        ambiance.activeExpiresAtMs = 0
        ambiance.activeVolume = 1
        return
    end
    
    if not data.ambianceZoneWide then
        ambiance.nextAtMs = 0
        ambiance.activeSoundName = nil
        ambiance.activeStartedAtMs = 0
        ambiance.activeExpiresAtMs = 0
        ambiance.activeVolume = 1
        return
    end

    local sounds = data.ambianceSounds
    if type(sounds) ~= "table" then
        sounds = {}
    end
    if #sounds == 0 then
        ambiance.nextAtMs = 0
        ambiance.activeSoundName = nil
        ambiance.activeStartedAtMs = 0
        ambiance.activeExpiresAtMs = 0
        ambiance.activeVolume = 1
        return
    end

    if ambiance.nextAtMs <= 0 then
        ambiance.nextAtMs = nowMs + toDelayMs(data.ambianceMinDelaySeconds, data.ambianceMaxDelaySeconds, 30, 90)
        logSounds(string.format("_runServerAmbianceZoneWide zone=%s scheduled first ambiance at %d", toZoneIdLabel(zone), ambiance.nextAtMs))
    end

    if nowMs < ambiance.nextAtMs then
        return
    end

    local soundName = chooseRandom(sounds)
    if not soundName or soundName == "" then
        logSounds(string.format("_runServerAmbianceZoneWide zone=%s selected empty ambiance sound; retrying in 1000ms", toZoneIdLabel(zone)))
        ambiance.nextAtMs = nowMs + 1000
        return
    end
    local durationMs = self:_getSoundDurationMs(zone, data, soundName, 0)
    local delayMs = toDelayMs(data.ambianceMinDelaySeconds, data.ambianceMaxDelaySeconds, 30, 90)
    local volume = chooseRandomVolume(data.ambianceMinVolume, data.ambianceMaxVolume, 1, 1)

    ambiance.activeSoundName = soundName
    ambiance.activeStartedAtMs = nowMs
    ambiance.activeExpiresAtMs = nowMs + durationMs
    ambiance.activeVolume = volume
    ambiance.nextAtMs = nowMs + durationMs + delayMs

    logSounds(string.format(
        "_runServerAmbianceZoneWide zone=%s pulse sound=%s volume=%.3f durationMs=%d delayMs=%d nextAtMs=%d",
        toZoneIdLabel(zone),
        tostring(soundName),
        volume,
        durationMs,
        delayMs,
        ambiance.nextAtMs
    ))

end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
---@param args table|nil
function Sounds:onClientSubscriptionCommand(zone, player, data, args)
    if isClient() then return end
    if not zone or not player then return end

    local zoneState = ensureServerZoneState(zone.id)
    local username = trim(player:getUsername())
    local action = trim(args and args.action)

    if username == "" then
        return
    end

    if action == "unsubscribe" then
        local removed = removeZoneSubscriber(zoneState, username)
        logSounds(string.format("onClientSubscriptionCommand zone=%s username=%s action=unsubscribe removed=%s", toZoneIdLabel(zone), username, tostring(removed)))
        return
    end

    if action == "subscribe" then
        local added = addZoneSubscriber(zoneState, username)
        logSounds(string.format("onClientSubscriptionCommand zone=%s username=%s action=subscribe added=%s", toZoneIdLabel(zone), username, tostring(added)))
        self:_sendCurrentSoundStateToPlayer(zone, data, player)
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function Sounds:onPlayerEnter(zone, player, data)
    if not isClient() then return end
    if not player or player ~= getPlayer() then return end

    logSounds(string.format("onPlayerEnter zone=%s", toZoneIdLabel(zone)))

    local enterSound = trim(data.enterSound)
    if enterSound ~= "" then
        playSoundLocally(enterSound)
        logSounds(string.format("onPlayerEnter zone=%s played enterSound=%s", toZoneIdLabel(zone), enterSound))
    end

    local zoneState = ensureClientZoneState(zone.id)
    if zoneState.perPlayerAmbiance.nextAtMs <= 0 then
        zoneState.perPlayerAmbiance.nextAtMs = getTimestampMs() + toDelayMs(data.ambianceMinDelaySeconds, data.ambianceMaxDelaySeconds, 30, 90)
        logSounds(string.format("onPlayerEnter zone=%s initialized per-player ambiance nextAtMs=%d", toZoneIdLabel(zone), zoneState.perPlayerAmbiance.nextAtMs))
    end

    self:sendCommandToServer(zone, "onClientSubscriptionCommand", {
        action = "subscribe"
    })
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function Sounds:onPlayerExit(zone, player, data)
    if not isClient() then return end
    if not player or player ~= getPlayer() then return end

    logSounds(string.format("onPlayerExit zone=%s", toZoneIdLabel(zone)))

    local exitSound = trim(data.exitSound)
    if exitSound ~= "" then
        playSoundLocally(exitSound)
        logSounds(string.format("onPlayerExit zone=%s played exitSound=%s", toZoneIdLabel(zone), exitSound))
    end

    local zoneState = ensureClientZoneState(zone.id)
    fadeOutClientZoneSounds(zoneState, FADE_DURATION_MS)

    self:sendCommandToServer(zone, "onClientSubscriptionCommand", {
        action = "unsubscribe"
    })

    if data.noSounds and data.originals then
        logSounds(string.format("onPlayerExit zone=%s restoring original global audio sliders", toZoneIdLabel(zone)))
        getCore():setOptionSoundVolume(data.originals.sound or 50)
        getCore():setOptionMusicVolume(data.originals.music or 50)
        getCore():setOptionAmbientVolume(data.originals.ambient or 50)
        getCore():setOptionJumpScareVolume(data.originals.jumpScare or 50)
        getCore():setOptionVehicleEngineVolume(data.originals.vehicleEngine or 50)
        data.originals = nil
        data.current = nil
        data.soundFadeStartMs = nil
    end
end

---@param zone WastelandZones.Classes.Zone
---@param player IsoPlayer
---@param data table
function Sounds:onPlayerInsideTick(zone, player, data)
    if not isClient() then return end
    if not player or player ~= getPlayer() then return end

    local nowMs = getTimestampMs()
    local zoneState = ensureClientZoneState(zone.id)
    cleanupClientAmbianceHandles(zoneState, nowMs)
    updateClientZoneFadeHandles(zoneState, nowMs)

    if data.noSounds then
        if not data.originals then
            data.originals = {
                sound = getCore():getOptionSoundVolume(),
                music = getCore():getOptionMusicVolume(),
                ambient = getCore():getOptionAmbientVolume(),
                jumpScare = getCore():getOptionJumpScareVolume(),
                vehicleEngine = getCore():getOptionVehicleEngineVolume()
            }
            data.soundFadeStartMs = nowMs

            logSounds(string.format(
                "onPlayerInsideTick zone=%s noSounds fade init originals sound=%s music=%s ambient=%s jumpScare=%s vehicleEngine=%s",
                toZoneIdLabel(zone),
                tostring(data.originals.sound),
                tostring(data.originals.music),
                tostring(data.originals.ambient),
                tostring(data.originals.jumpScare),
                tostring(data.originals.vehicleEngine)
            ))

            data.current = {
                sound = data.originals.sound,
                music = data.originals.music,
                ambient = data.originals.ambient,
                jumpScare = data.originals.jumpScare,
                vehicleEngine = data.originals.vehicleEngine
            }
        end

        data.current = data.current or {
            sound = getCore():getOptionSoundVolume(),
            music = getCore():getOptionMusicVolume(),
            ambient = getCore():getOptionAmbientVolume(),
            jumpScare = getCore():getOptionJumpScareVolume(),
            vehicleEngine = getCore():getOptionVehicleEngineVolume()
        }

        data.soundFadeStartMs = data.soundFadeStartMs or nowMs
        local elapsedMs = nowMs - data.soundFadeStartMs
        local fadePct = clamp(elapsedMs / FADE_DURATION_MS, 0, 1)

        data.current.sound = fadeByPercent(data.originals.sound, fadePct)
        data.current.music = fadeByPercent(data.originals.music, fadePct)
        data.current.ambient = fadeByPercent(data.originals.ambient, fadePct)
        data.current.jumpScare = fadeByPercent(data.originals.jumpScare, fadePct)
        data.current.vehicleEngine = fadeByPercent(data.originals.vehicleEngine, fadePct)

        if getCore():getOptionSoundVolume() ~= data.current.sound then
            getCore():setOptionSoundVolume(data.current.sound)
        end
        if getCore():getOptionMusicVolume() ~= data.current.music then
            getCore():setOptionMusicVolume(data.current.music)
        end
        if getCore():getOptionAmbientVolume() ~= data.current.ambient then
            getCore():setOptionAmbientVolume(data.current.ambient)
        end
        if getCore():getOptionJumpScareVolume() ~= data.current.jumpScare then
            getCore():setOptionJumpScareVolume(data.current.jumpScare)
        end
        if getCore():getOptionVehicleEngineVolume() ~= data.current.vehicleEngine then
            getCore():setOptionVehicleEngineVolume(data.current.vehicleEngine)
        end
    elseif data.originals then
        logSounds(string.format("onPlayerInsideTick zone=%s noSounds disabled, restoring original global audio sliders", toZoneIdLabel(zone)))
        getCore():setOptionSoundVolume(data.originals.sound or 50)
        getCore():setOptionMusicVolume(data.originals.music or 50)
        getCore():setOptionAmbientVolume(data.originals.ambient or 50)
        getCore():setOptionJumpScareVolume(data.originals.jumpScare or 50)
        getCore():setOptionVehicleEngineVolume(data.originals.vehicleEngine or 50)
        data.originals = nil
        data.current = nil
        data.soundFadeStartMs = nil
    end

    local playlist = zoneState.playlist
    local playlistVolume = toVolume(playlist.volume, toVolume(data.playlistVolume, 1))

    if playlist.soundName and playlist.soundName ~= "" then
        if playlist.expiresAtMs > 0 and nowMs >= playlist.expiresAtMs then
            if playlist.handle then
                stopLocalSound(playlist.handle)
                logSounds(string.format("onPlayerInsideTick zone=%s playlist expired sound=%s handle=%s", toZoneIdLabel(zone), tostring(playlist.soundName), tostring(playlist.handle)))
                playlist.handle = nil
                playlist.activeSound = nil
                playlist.activeVolume = nil
            end
        elseif playlist.activeSound ~= playlist.soundName or not playlist.handle then
            if playlist.handle then
                stopLocalSound(playlist.handle)
            end
            playlist.handle = playSoundLocally(playlist.soundName, playlistVolume)
            playlist.activeSound = playlist.soundName
            playlist.activeVolume = playlistVolume
            logSounds(string.format("onPlayerInsideTick zone=%s playlist started sound=%s volume=%.3f handle=%s", toZoneIdLabel(zone), tostring(playlist.soundName), playlistVolume, tostring(playlist.handle)))
        elseif playlist.handle and math.abs(toNumber(playlist.activeVolume, -1) - playlistVolume) > 0.001 then
            setLocalSoundVolume(playlist.handle, playlistVolume)
            playlist.activeVolume = playlistVolume
            logSounds(string.format("onPlayerInsideTick zone=%s playlist volume updated sound=%s volume=%.3f handle=%s", toZoneIdLabel(zone), tostring(playlist.soundName), playlistVolume, tostring(playlist.handle)))
        end
    end

    local zoneWideAmbiance = getClientZoneWideAmbianceState(zoneState)
    local desiredAmbiance = zoneWideAmbiance.desired
    if desiredAmbiance.zoneWide == true then
        if desiredAmbiance.enabled == true and trim(desiredAmbiance.soundName) ~= "" then
            local desiredSoundName = trim(desiredAmbiance.soundName)
            local desiredVolume = toVolume(desiredAmbiance.volume, 1)
            if desiredAmbiance.expiresAtMs > 0 and nowMs >= desiredAmbiance.expiresAtMs then
                if zoneWideAmbiance.zoneWideHandle then
                    stopLocalSound(zoneWideAmbiance.zoneWideHandle)
                    zoneWideAmbiance.zoneWideHandle = nil
                    zoneWideAmbiance.zoneWideActiveSound = nil
                    zoneWideAmbiance.zoneWideActiveVolume = nil
                end
            elseif zoneWideAmbiance.zoneWideActiveSound ~= desiredSoundName or not zoneWideAmbiance.zoneWideHandle then
                if zoneWideAmbiance.zoneWideHandle then
                    stopLocalSound(zoneWideAmbiance.zoneWideHandle)
                end
                zoneWideAmbiance.zoneWideHandle = playSoundLocally(desiredSoundName, desiredVolume)
                zoneWideAmbiance.zoneWideActiveSound = desiredSoundName
                zoneWideAmbiance.zoneWideActiveVolume = desiredVolume
                logSounds(string.format("onPlayerInsideTick zone=%s zone-wide ambiance started sound=%s volume=%.3f handle=%s", toZoneIdLabel(zone), tostring(desiredSoundName), desiredVolume, tostring(zoneWideAmbiance.zoneWideHandle)))
            elseif zoneWideAmbiance.zoneWideHandle and math.abs(toNumber(zoneWideAmbiance.zoneWideActiveVolume, -1) - desiredVolume) > 0.001 then
                setLocalSoundVolume(zoneWideAmbiance.zoneWideHandle, desiredVolume)
                zoneWideAmbiance.zoneWideActiveVolume = desiredVolume
            end
        elseif zoneWideAmbiance.zoneWideHandle then
            addClientFadeHandle(zoneState, zoneWideAmbiance.zoneWideHandle, zoneWideAmbiance.zoneWideActiveVolume or 1, FADE_DURATION_MS)
            zoneWideAmbiance.zoneWideHandle = nil
            zoneWideAmbiance.zoneWideActiveSound = nil
            zoneWideAmbiance.zoneWideActiveVolume = nil
        end

        return
    end

    if zoneWideAmbiance.zoneWideHandle then
        addClientFadeHandle(zoneState, zoneWideAmbiance.zoneWideHandle, zoneWideAmbiance.zoneWideActiveVolume or 1, FADE_DURATION_MS)
        zoneWideAmbiance.zoneWideHandle = nil
        zoneWideAmbiance.zoneWideActiveSound = nil
        zoneWideAmbiance.zoneWideActiveVolume = nil
    end

    local sounds = data.ambianceSounds
    if type(sounds) ~= "table" then
        sounds = {}
    end
    if #sounds == 0 then
        return
    end

    local perPlayerState = zoneState.perPlayerAmbiance
    if perPlayerState.nextAtMs <= 0 then
        perPlayerState.nextAtMs = nowMs + toDelayMs(data.ambianceMinDelaySeconds, data.ambianceMaxDelaySeconds, 30, 90)
        logSounds(string.format("onPlayerInsideTick zone=%s per-player ambiance nextAtMs initialized to %d", toZoneIdLabel(zone), perPlayerState.nextAtMs))
    end

    if nowMs < perPlayerState.nextAtMs then
        return
    end

    local delayMs = toDelayMs(data.ambianceMinDelaySeconds, data.ambianceMaxDelaySeconds, 30, 90)
    local soundName = chooseRandom(sounds)
    if soundName and soundName ~= "" then
        local durationMs = self:_getSoundDurationMs(zone, data, soundName, 0)
        local volume = chooseRandomVolume(data.ambianceMinVolume, data.ambianceMaxVolume, 1, 1)
        perPlayerState.nextAtMs = nowMs + durationMs + delayMs
        local handle = playSoundLocally(soundName, volume)
        if handle then
            trackClientAmbianceHandle(zoneState, handle, volume, durationMs, nowMs)
            logSounds(string.format("onPlayerInsideTick zone=%s per-player ambiance played sound=%s volume=%.3f durationMs=%d delayMs=%d nextAtMs=%d handle=%s", toZoneIdLabel(zone), tostring(soundName), volume, durationMs, delayMs, perPlayerState.nextAtMs, tostring(handle)))
        else
            logSounds(string.format("onPlayerInsideTick zone=%s per-player ambiance failed sound=%s volume=%.3f", toZoneIdLabel(zone), tostring(soundName), volume))
        end
    else
        perPlayerState.nextAtMs = nowMs + delayMs
        logSounds(string.format("onPlayerInsideTick zone=%s per-player ambiance selected empty sound; nextAtMs=%d", toZoneIdLabel(zone), perPlayerState.nextAtMs))
    end
end

---@param zone WastelandZones.Classes.Zone
---@param data table
---@param runtimeLane table|nil
function Sounds:onServerTick(zone, data, runtimeLane)
    if isClient() then return end
    local nowMs = getTimestampMs()

    local lastEval = runtime.server.lastEvalByZone[zone.id] or 0
    if nowMs - lastEval < 1000 then
        return
    end
    runtime.server.lastEvalByZone[zone.id] = nowMs

    self:_runServerPlaylist(zone, data, nowMs)
    self:_runServerAmbianceZoneWide(zone, data, nowMs)
    self:_broadcastUnifiedStateIfChanged(zone, data, nowMs)
end

---@param zone WastelandZones.Classes.Zone
---@param data table
function Sounds:onDestroyed(zone, data)
    local zoneId = zone and zone.id or nil
    if not zoneId then return end

    logSounds(string.format("onDestroyed zone=%s", toZoneIdLabel(zoneId)))

    if runtime.server.byZone[zoneId] then
        local zoneState = runtime.server.byZone[zoneId]
        if zoneState and zoneState.subscribers and #zoneState.subscribers > 0 then
            self:_sendToZoneSubscribers(zone, "receiveSoundData", {
                state = {
                    playlist = {
                        soundName = nil,
                        startedAtMs = 0,
                        expiresAtMs = 0,
                        volume = toVolume(data.playlistVolume, 1)
                    },
                    ambiance = {
                        enabled = false,
                        zoneWide = false,
                        soundName = nil,
                        startedAtMs = 0,
                        expiresAtMs = 0,
                        volume = 1
                    }
                }
            })
        end
        runtime.server.byZone[zoneId] = nil
        runtime.server.lastEvalByZone[zoneId] = nil
    end

    local clientState = runtime.client.byZone[zoneId]
    if clientState then
        local fades = getClientFadeHandles(clientState)
        for i = 1, #fades do
            stopLocalSound(fades[i].handle)
        end
        if clientState.playlist and clientState.playlist.handle then
            stopLocalSound(clientState.playlist.handle)
        end
        local activeAmbiance = getClientAmbianceHandles(clientState)
        for i = 1, #activeAmbiance do
            stopLocalSound(activeAmbiance[i].handle)
        end
        runtime.client.byZone[zoneId] = nil
    end

    if data.noSounds and data.originals then
        getCore():setOptionSoundVolume(data.originals.sound or 50)
        getCore():setOptionMusicVolume(data.originals.music or 50)
        getCore():setOptionAmbientVolume(data.originals.ambient or 50)
        getCore():setOptionJumpScareVolume(data.originals.jumpScare or 50)
        getCore():setOptionVehicleEngineVolume(data.originals.vehicleEngine or 50)
        data.originals = nil
        data.current = nil
        data.soundFadeStartMs = nil
    end
end

function Sounds:onRecreated(oldZone, newZone, oldData, newData)
    if oldData and oldData.originals then
        newData.originals = oldData.originals
        newData.current = oldData.current
        newData.soundFadeStartMs = oldData.soundFadeStartMs
    end
end

if Events and Events.OnTick then
    Events.OnTick.Add(onClientFadeTick)
end

WastelandZones.Plugins:register(Sounds:new())
