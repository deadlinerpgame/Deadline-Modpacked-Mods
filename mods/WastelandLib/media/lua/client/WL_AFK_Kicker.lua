if not isClient() then return end

WL_AFK_Kicker = {}

WL_AFK_Kicker.enabled = true
-- Prod
local timeInMin = 20
WL_AFK_Kicker.kickTime = timeInMin * 60
WL_AFK_Kicker.warnTimes = {}
table.insert(WL_AFK_Kicker.warnTimes, (timeInMin - 5) * 60)
table.insert(WL_AFK_Kicker.warnTimes, (timeInMin - 2.5) * 60)
table.insert(WL_AFK_Kicker.warnTimes, (timeInMin - 1) * 60)
table.insert(WL_AFK_Kicker.warnTimes, timeInMin * 60 - 30)
table.insert(WL_AFK_Kicker.warnTimes, timeInMin * 60 - 10)
table.insert(WL_AFK_Kicker.warnTimes, timeInMin * 60 - 5)

--- Privates
WL_AFK_Kicker.timeLastMove = getTimestamp()
WL_AFK_Kicker.lastPosition = {x = 0, y = 0, z = 0}
WL_AFK_Kicker.warns = {}

--- Checks if the player has been afk for the specified time using last position and last spoken time
--- @param timeInSeconds number|nil optional time in seconds to check against, defaults to 300 (5 minutes)
--- @return boolean hasBeenAfk true if the player has been afk for the specified time
function WL_AFK_Kicker.hasBeenAfk(timeInSeconds)
    if WL_Utils.isStaff(getPlayer()) then return false end
    if not timeInSeconds then timeInSeconds = 300 end
    if not WL_AFK_Kicker.enabled then return false end
    local timeSinceLastMove = getTimestamp() - WL_AFK_Kicker.timeLastMove
    return timeSinceLastMove >= timeInSeconds
end

--- @return number timeInSeconds The number of seconds since the player last moved or spoke
function WL_AFK_Kicker.getAfkTimeInSeconds()
    if WL_Utils.isStaff(getPlayer()) then return 0 end
    return getTimestamp() - WL_AFK_Kicker.timeLastMove
end

function WL_AFK_Kicker.checkAfk()
    local player = getPlayer()
    if player == nil then return end
    if WL_Utils.isStaff(player) then return end
    if not WL_AFK_Kicker.enabled then return end

    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local z = math.floor(player:getZ())
    local ts = getTimestamp()
    if WL_AFK_Kicker.lastPosition.x ~= x or
       WL_AFK_Kicker.lastPosition.y ~= y or
       WL_AFK_Kicker.lastPosition.z ~= z then
        WL_AFK_Kicker.timeLastMove = ts
        WL_AFK_Kicker.lastPosition.x = x
        WL_AFK_Kicker.lastPosition.y = y
        WL_AFK_Kicker.lastPosition.z = z
        local didClearWarns = false
        for _, warnTime in ipairs(WL_AFK_Kicker.warnTimes) do
            if WL_AFK_Kicker.warns[warnTime] then
                didClearWarns = true
                WL_AFK_Kicker.warns[warnTime] = false
            end
        end
        if didClearWarns then
            local message = "You are no longer AFK."
            WL_Utils.addInfoToChat(message)
            player:addLineChatElement(message, 0.3, 1.0, 0.3)
        end
        return
    end

    local timeSinceLastMove = ts - WL_AFK_Kicker.timeLastMove

    for _, warnTime in ipairs(WL_AFK_Kicker.warnTimes) do
        if not WL_AFK_Kicker.warns[warnTime] and timeSinceLastMove >= warnTime then
            local message = "You will be kicked for being AFK in " .. WL_Utils.toHumanReadableTime((WL_AFK_Kicker.kickTime - warnTime) * 1000) .. "."
            WL_Utils.addErrorToChat(message)
            player:addLineChatElement(message, 1.0, 0.3, 0.3)
            WL_AFK_Kicker.warns[warnTime] = true
        end
    end

    if timeSinceLastMove - 1 == WL_AFK_Kicker.kickTime then
        local message = "You are being kicked for being AFK."
        WL_Utils.addErrorToChat(message)
        player:addLineChatElement(message, 1.0, 0.3, 0.3)
    end

    if timeSinceLastMove > WL_AFK_Kicker.kickTime then
        local message = "You have been kicked for being AFK."
        WL_Utils.addErrorToChat(message)
        player:addLineChatElement(message, 1.0, 0.3, 0.3)
        WL_AFK_Kicker.timeLastMove = ts
        getCore():exitToMenu()
    end
end

Events.OnTick.Add(WL_AFK_Kicker.checkAfk)

Events.OnLoad.Add(function ()
    if WRC == nil then return end
    table.insert(WRC.CustomChatCallbacks, function()
        WL_AFK_Kicker.lastPosition = {x = 0, y = 0, z = 0}
    end)
end)

Events.OnCreatePlayer.Add(function()
    WL_AFK_Kicker.timeLastMove = getTimestamp()
    WL_AFK_Kicker.lastPosition = {x = 0, y = 0, z = 0}
    WL_AFK_Kicker.warns = {}
end)