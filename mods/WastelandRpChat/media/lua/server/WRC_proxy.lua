-- Only MP
if not isServer() or isClient() then return end

local PlayerDB = {}
local GlobalState = {}

local function canSee(player, otherPlayer, xyRange, zRange)
    if not player or not otherPlayer then return false end
    xyRange = xyRange + .99
    if player:getDistanceSq(otherPlayer) > xyRange*xyRange then return false end
    if math.abs(player:getZ() - otherPlayer:getZ()) > zRange then return false end
    -- if player:isGhostMode() and not otherPlayer:isGodMod() then return false end -- should be handled client-side now
    return true
end

local function doLog(sendingPlayer, args)
    local username = sendingPlayer:getUsername()
    local forname = sendingPlayer:getDescriptor():getForename()
    local x, y, z, text, lang = args[1], args[2], args[3], args[4], args[5]
    local logMessage = string.format("%s (%s) @ %s,%s,%s: [%s] %s", username, forname, x, y, z, lang, text)
    writeLog("CleanChat", logMessage)
end

local function doPrivateLog(sendingPlayer, args)
    local username = sendingPlayer:getUsername()
    local forname = sendingPlayer:getDescriptor():getForename()
    local x, y, z, text, lang = args[1], args[2], args[3], args[4], args[5]
    local logMessage = string.format("%s (%s) @ %s,%s,%s: [%s] %s", username, forname, x, y, z, lang, text)
    writeLog("PrivateChat", logMessage)
end

local function SetPlayerColor(player, r, g, b)
    if not player then return end
    if not r or not g or not b then return end
    PlayerDB.PlayerColors[player:getUsername()] = {r = r, g = g, b = b}
    ModData.add("WRC_PlayerColors", PlayerDB.PlayerColors)
    ModData.transmit("WRC_PlayerColors")
end

local function SetPlayerLanguage(player, language)
    if not player or not language then return end
    PlayerDB.PlayerLanguages[player:getUsername()] = language
    ModData.add("WRC_PlayerLanguages", PlayerDB.PlayerLanguages)
    ModData.transmit("WRC_PlayerLanguages")
end

local function NotifyTyping(sendingPlayer, command, args)
    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers:size() == 0 then return end
    local xyRange, zRange
    if command == "onCleared" then
        xyRange = 50
        zRange = 7
    else
        xyRange = args and args[1] or 0
        zRange = args and args[2] or 0
    end
    local username = sendingPlayer:getUsername()
    for i=0, onlinePlayers:size()-1 do
        local player = onlinePlayers:get(i)
        if canSee(player, sendingPlayer, xyRange, zRange) then
            sendServerCommand(player, "WRC", command, {username})
        end
    end
end

local function SetModifier(player, direction, modifier)
    local username = player:getUsername()
    PlayerDB.PlayerModifiers[username] = PlayerDB.PlayerModifiers[username] or {}
    if direction == "enable" then
        PlayerDB.PlayerModifiers[username][modifier] = true
    elseif direction == "disable" then
        PlayerDB.PlayerModifiers[username][modifier] = nil
    end
    ModData.add("WRC_PlayerModifiers", PlayerDB.PlayerModifiers)
    ModData.transmit("WRC_PlayerModifiers")
end

local function SetPlayerName(player, name)
    if not player or not name then return end
    PlayerDB.PlayerNames[player:getUsername()] = name
    ModData.add("WRC_PlayerNames", PlayerDB.PlayerNames)
    ModData.transmit("WRC_PlayerNames")
end

local function SetPlayerStatus(player, status)
    if not player then return end
    PlayerDB.PlayerStatus[player:getUsername()] = status
    ModData.add("WRC_PlayerStatus", PlayerDB.PlayerStatus)
    ModData.transmit("WRC_PlayerStatus")
end

local function SetPlayerStatusInverted(player, inverted)
    if not player then return end
    PlayerDB.InvertStatus[player:getUsername()] = inverted
    ModData.add("WRC_InvertStatus", PlayerDB.InvertStatus)
    ModData.transmit("WRC_InvertStatus")
end

local function SetInjuredAbove(player, InjuredAbove)
    if not player then return end
    PlayerDB.InjuredAbove[player:getUsername()] = InjuredAbove
    ModData.add("WRC_InjuredAbove", PlayerDB.InjuredAbove)
    ModData.transmit("WRC_InjuredAbove")
end

local function SetStreamingAbove(player, StreamingAbove)
    if not player then return end
    PlayerDB.StreamingAbove[player:getUsername()] = StreamingAbove
    ModData.add("WRC_StreamingAbove", PlayerDB.StreamingAbove)
    ModData.transmit("WRC_StreamingAbove")
end

local function setLimpLeft(player, LimpLeft)
    if not player then return end
    PlayerDB.LimpLeft[player:getUsername()] = LimpLeft
    ModData.add("WRC_LimpLeft", PlayerDB.LimpLeft)
    ModData.transmit("WRC_LimpLeft")
end

local function setLimpRight(player, LimpRight)
    if not player then return end
    PlayerDB.LimpRight[player:getUsername()] = LimpRight
    ModData.add("WRC_LimpRight", PlayerDB.LimpRight)
    ModData.transmit("WRC_LimpRight")
end

local staffColors = {
    ["Admin"] = "<RGB:0.2,0.8,0.2>",
    ["Moderator"] = "<RGB:0.2,0.2,0.8>",
    ["Overseer"] = "<RGB:0.8,0.2,0.2>",
    ["GM"] = "<RGB:0.8,0.8,0.2>",
    ["Observer"] = "<RGB:0.8,0.2,0.8>"
}

local function onWRCCommand(module, command, sendingPlayer, args)
    if module ~= "WRC" then return end

    if command == "doLog" then
        doLog(sendingPlayer, args)
    elseif command == "SetPlayerColor" then
        SetPlayerColor(sendingPlayer, args[1], args[2], args[3])
    elseif command == "SetPlayerLanguage" then
        SetPlayerLanguage(sendingPlayer, args[1])
    elseif command == "SetPlayerName" then
        SetPlayerName(sendingPlayer, args[1])
    elseif command == "SetPlayerStatus" then
        SetPlayerStatus(sendingPlayer, args and args[1] or nil)
    elseif command == "InvertStatus" then
        SetPlayerStatusInverted(sendingPlayer, args and args[1] or nil)
    elseif command == "SetInjuredAbove" then
        SetInjuredAbove(sendingPlayer, args and args[1] or nil)
    elseif command == "SetStreamingAbove" then
        SetStreamingAbove(sendingPlayer, args and args[1] or nil)
    elseif command == "LimpLeft" then
        setLimpLeft(sendingPlayer, args and args[1] or nil)
    elseif command == "LimpRight" then
        setLimpRight(sendingPlayer, args and args[1] or nil)
    elseif command == "RemoveKnownLanguage" or command == "AddKnownLanguage" then
        local username, language = args[1], args[2]
        local allPlayers = getOnlinePlayers()
        if allPlayers:size() == 0 then return end
        for i=0, allPlayers:size()-1 do
            local player = allPlayers:get(i)
            if player:getUsername() == username then
                sendServerCommand(player, "WRC", command, {language})
                break
            end
        end
    elseif command == "SetModifier" then
        local direction, modifier = args[1], args[2]
        SetModifier(sendingPlayer, direction, modifier)
    elseif command == "InvitePrivate"
    or     command == "PrivateUnavailable"
    or     command == "AcceptPrivateInvite"
    or     command == "DeclinePrivateInvite"
    or     command == "StopPrivate" then
        local otherPlayer = args[1]
        local allPlayers = getOnlinePlayers()
        if allPlayers:size() == 0 then return end
        for i=0, allPlayers:size()-1 do
            local player = allPlayers:get(i)
            if player:getUsername() == otherPlayer then
                sendServerCommand(player, "WRC", command, {sendingPlayer:getUsername()})
                break
            end
        end
    elseif command == "PrivateChat" then
        local otherPlayer = args[1]
        local message = args[2]
        local lang = args[3]
        local allPlayers = getOnlinePlayers()
        if allPlayers:size() == 0 then return end
        for i=0, allPlayers:size()-1 do
            local player = allPlayers:get(i)
            if player:getUsername() == otherPlayer then
                sendServerCommand(player, "WRC", command, {sendingPlayer:getUsername(), message})
                doPrivateLog(sendingPlayer, {player:getX(), player:getY(), player:getZ(), message, lang})
                break
            end
        end
    elseif command == "StaffChat" then
        local color = staffColors[sendingPlayer:getAccessLevel()]
        if not color then color = "<RGB:0.8,0.8,0.8>" end
        local message = color .. "[" .. sendingPlayer:getUsername() .. "]" .. WL_Utils.MagicSpace .. "<RGB:1,1,1>" .. args[1]

        local allPlayers = getOnlinePlayers()
        if allPlayers:size() == 0 then return end
        for i=0, allPlayers:size()-1 do
            local player = allPlayers:get(i)
            if WL_Utils.isStaff(player) then
                sendServerCommand(player, "WRC", command, {sendingPlayer:getUsername(), message})
            end
        end
    elseif command == "SetGlobalState" then
        local key, value = args[1], args[2]
        GlobalState[key] = value
        ModData.add("WRC_GlobalState", GlobalState)
        ModData.transmit("WRC_GlobalState")
    else
        NotifyTyping(sendingPlayer, command, args)
    end
end

local function ProcessLastSeenTimes()
    local allPlayers = getOnlinePlayers()
    if allPlayers:size() == 0 then return end
    for i=0, allPlayers:size()-1 do
        local player = allPlayers:get(i)
        local username = player:getUsername()
        PlayerDB.LastSeenTimes[username] = getTimestamp()
    end
    for username, lastSeenTime in pairs(PlayerDB.LastSeenTimes) do
        -- 60 days
        if lastSeenTime < getTimestamp() - 60*24*60*60 then
            PlayerDB.LastSeenTimes[username] = nil
            PlayerDB.PlayerColors[username] = nil
            PlayerDB.PlayerLanguages[username] = nil
            PlayerDB.PlayerModifiers[username] = nil
            PlayerDB.PlayerNames[username] = nil
            PlayerDB.PlayerAfk[username] = nil
            PlayerDB.PlayerStatus[username] = nil
        end
    end
    ModData.add("WRC_LastSeenTimes", PlayerDB.LastSeenTimes)
    ModData.add("WRC_PlayerColors", PlayerDB.PlayerColors)
    ModData.add("WRC_PlayerLanguages", PlayerDB.PlayerLanguages)
    ModData.add("WRC_PlayerModifiers", PlayerDB.PlayerModifiers)
    ModData.add("WRC_PlayerNames", PlayerDB.PlayerNames)
    ModData.add("WRC_PlayerAfk", PlayerDB.PlayerAfk)
    ModData.add("WRC_PlayerStatus", PlayerDB.PlayerStatus)
    ModData.add("WRC_InvertStatus", PlayerDB.InvertStatus)
    ModData.add("WRC_InjuredAbove", PlayerDB.InjuredAbove)
    ModData.add("WRC_StreamingAbove", PlayerDB.StreamingAbove)
    ModData.add("WRC_LimpLeft", PlayerDB.LimpLeft)
    ModData.add("WRC_LimpRight", PlayerDB.LimpRight)
end

local function ProcessAddLanguages() -- Get list of online players first
    if SandboxVars and SandboxVars.WastelandRpChat and SandboxVars.WastelandRpChat.EnablePlayerLanguageFileProcessing == false then
        return
    end

    local onlinePlayers = getOnlinePlayers()
    if onlinePlayers:size() == 0 then
        return
    end

    -- Build a lookup table of online players by username
    local onlinePlayerMap = {}
    for i=0, onlinePlayers:size()-1 do
        local player = onlinePlayers:get(i)
        if player:getOnlineID() ~= -1 then
            onlinePlayerMap[player:getUsername()] = player
        end
    end

    local readFile = getFileReader("addlanguages.txt", false)
    if not readFile then return end

    -- Read and process lines
    local anySent = false
    local unprocessedLines = {}
    local line = readFile:readLine()
    while line and line ~= "" do
        -- Parse line: "player name,langcode"
        local commaPos = string.find(line, ",")
        if commaPos then
            local playerName = string.sub(line, 1, commaPos - 1)
            local langCode = string.sub(line, commaPos + 1)

            -- Trim whitespace
            playerName = playerName:match("^%s*(.-)%s*$")
            langCode = langCode:match("^%s*(.-)%s*$")

            -- Check if player is online
            local player = onlinePlayerMap[playerName]
            if player then
                if player:getOnlineID() ~= -1 then
                    print("Adding known language for player:" .. playerName .. " code:" .. langCode)
                    sendServerCommand(player, "WRC", "AddKnownLanguage", {langCode})
                    anySent = true
                else
                    table.insert(unprocessedLines, line)
                end
            else
                table.insert(unprocessedLines, line)
            end
        else
            -- Invalid format, keep the line
            table.insert(unprocessedLines, line)
        end
        
        line = readFile:readLine()
    end
    readFile:close()

    if not anySent then
        return
    end
    
    -- Write back unprocessed lines
    local writeFile = getFileWriter("addlanguages.txt", true, false)
    if writeFile then
        for _, unprocessedLine in ipairs(unprocessedLines) do
            writeFile:write(unprocessedLine .. "\n")
        end
        writeFile:close()
    end
end

local function OnInitGlobalModData(isNewGame)
    PlayerDB.LastSeenTimes = ModData.getOrCreate("WRC_LastSeenTimes")
    PlayerDB.PlayerColors = ModData.getOrCreate("WRC_PlayerColors")
    PlayerDB.PlayerLanguages = ModData.getOrCreate("WRC_PlayerLanguages")
    PlayerDB.PlayerModifiers = ModData.getOrCreate("WRC_PlayerModifiers")
    PlayerDB.PlayerNames = ModData.getOrCreate("WRC_PlayerNames")
    PlayerDB.PlayerAfk = ModData.getOrCreate("WRC_PlayerAfk")
    PlayerDB.PlayerStatus = ModData.getOrCreate("WRC_PlayerStatus")
    PlayerDB.InvertStatus = ModData.getOrCreate("WRC_InvertStatus")
    PlayerDB.InjuredAbove = ModData.getOrCreate("WRC_InjuredAbove")
    PlayerDB.StreamingAbove = ModData.getOrCreate("WRC_StreamingAbove")
    PlayerDB.LimpLeft = ModData.getOrCreate("WRC_LimpLeft")
    PlayerDB.LimpRight = ModData.getOrCreate("WRC_LimpRight")
    GlobalState = ModData.getOrCreate("WRC_GlobalState")

    if GlobalState.radioJammer == nil then
        GlobalState.radioJammer = false
        ModData.add("WRC_GlobalState", GlobalState)
    end
end

Events.EveryHours.Add(ProcessLastSeenTimes)
Events.EveryOneMinute.Add(ProcessAddLanguages)
Events.OnClientCommand.Add(onWRCCommand)
Events.OnInitGlobalModData.Add(OnInitGlobalModData)
