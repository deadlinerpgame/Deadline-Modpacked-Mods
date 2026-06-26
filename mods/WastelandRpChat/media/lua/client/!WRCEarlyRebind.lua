local STATE = {}
STATE[1] = {}
STATE[2] = {}
STATE[3] = {}
STATE[4] = {}

local radiosShutOff = {}
local radiosShutOffPlayer = nil

local function restoreRadios()
    for i=1,#radiosShutOff do
        WRU_Utils.setRadioPowerInstant(radiosShutOffPlayer, radiosShutOff[i], true)
    end
    radiosShutOff = {}
    Events.OnTick.Remove(restoreRadios)
end

local function muteRadios(player)
    radiosShutOffPlayer = player
    radiosShutOff = WRU_Utils.getPlayerRadios(player, true, true)
    for i=1,#radiosShutOff do
        WRU_Utils.setRadioPowerInstant(player, radiosShutOff[i], false)
    end
    Events.OnTick.Add(restoreRadios)
end

function ISEmoteRadialMenu.onKeyPressed(key)
    if not ISEmoteRadialMenu.checkKey(key) then
        return
    end
    if getCore():getGameMode() == "Tutorial" and key ~= getCore():getKey("Shout") then
        return
    end
    local radialMenu = getPlayerRadialMenu(0)
    if getCore():getOptionRadialMenuKeyToggle() and radialMenu:isReallyVisible() then
        STATE[1].radialWasVisible = true
        radialMenu:removeFromUIManager()
        return
    end
    STATE[1].keyPressedMS = getTimestampMs()
    STATE[1].radialWasVisible = false
end

function ISEmoteRadialMenu.onKeyRepeat(key)
    if not ISEmoteRadialMenu.checkKey(key) then
        return
    end
    if getCore():getGameMode() == "Tutorial" and key ~= getCore():getKey("Shout") then
        return
    end
    if STATE[1].radialWasVisible then
        return
    end
    if not STATE[1].keyPressedMS then
        return
    end
    local playerObj = getSpecificPlayer(0)
    local radialMenu = getPlayerRadialMenu(0)
    local delay = 450
    if (getTimestampMs() - STATE[1].keyPressedMS >= delay) and key == getCore():getKey("Emote") and not playerObj:getVehicle() then
        if not radialMenu:isReallyVisible() then
            local frm = ISEmoteRadialMenu:new(playerObj)
            frm:fillMenu()
        end
    end
end

-- Do not broadcast on radios when playing doing a callout
function ISEmoteRadialMenu.onKeyReleased(key)
    if not ISEmoteRadialMenu.checkKey(key) then
        return
    end
    if getCore():getGameMode() == "Tutorial" and key ~= getCore():getKey("Shout") then
        return
    end
    if not STATE[1].keyPressedMS then
        return
    end
    local playerObj = getSpecificPlayer(0)
    local radialMenu = getPlayerRadialMenu(0)
    if radialMenu:isReallyVisible() or STATE[1].radialWasVisible then
        if not getCore():getOptionRadialMenuKeyToggle() then
            radialMenu:removeFromUIManager()
        end
        return
    end

    local delay = 450
    if (getTimestampMs() - STATE[1].keyPressedMS < delay) and key == getCore():getKey("Shout") and not playerObj:getVehicle() then
        muteRadios(playerObj)
        playerObj:Callout(true)
    end
end



-- Do not broadcast on radios when playing doing a callout
function ISEmoteRadialMenu:emote(emote)
    -- check for variant of the same anim (like wave hi could be wavehi or wavehi02)
    if ISEmoteRadialMenu.variants[emote] then
        emote = ISEmoteRadialMenu.variants[emote][ZombRand(#ISEmoteRadialMenu.variants[emote])+1]
    end
    self.character:playEmote(emote)
    if emote == "shout" then
        muteRadios(self.character)
        self.character:Callout(false)
    end
end