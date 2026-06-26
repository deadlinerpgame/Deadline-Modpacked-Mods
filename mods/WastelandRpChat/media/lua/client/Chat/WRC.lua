if not isClient() then return end -- only in MP
WRC = WRC or {}

require "Chat/WRC/afk"
require "Chat/WRC/buffs"
require "Chat/WRC/commands"
require "Chat/WRC/config"
require "Chat/WRC/handlers"
require "Chat/WRC/indicator"
require "Chat/WRC/keepsafe"
require "Chat/WRC/languages"
require "Chat/WRC/meta"
require "Chat/WRC/modifiers"
require "Chat/WRC/voiceportal"

-- Must be last in require chain
require "Chat/WRC/events"

WRC.CustomChatCallbacks = {}

-- dynamically create all possible chat type command, modified, and language combinations
-- modifier and language are optional
WRC.ChatCommands = {}
for type, typeData in pairs(WRC.ChatTypes) do
    for _, typeCommand in pairs(typeData.command) do
        if typeCommand ~= "" then
            WRC.ChatCommands["/" .. typeCommand] = {}
            WRC.ChatCommands["/" .. typeCommand].type = type
            WRC.ChatCommands["/" .. typeCommand].modifier = nil
            WRC.ChatCommands["/" .. typeCommand].language = nil
        end
    end
    for modifier, modifierData in pairs(WRC.ChatModifiers) do
        for _, modifierCommand in pairs(modifierData.command) do
            for _, typeCommand in pairs(typeData.command) do
                WRC.ChatCommands["/" .. modifierCommand .. typeCommand] = {}
                WRC.ChatCommands["/" .. modifierCommand .. typeCommand].type = type
                WRC.ChatCommands["/" .. modifierCommand .. typeCommand].modifier = modifier
                WRC.ChatCommands["/" .. modifierCommand .. typeCommand].language = nil
            end
        end
    end
    for language, _ in pairs(WRC.Languages) do
        for _, typeCommand in pairs(typeData.command) do
            if typeCommand ~= "" then
                WRC.ChatCommands["/" .. typeCommand .. ":" .. language] = {}
                WRC.ChatCommands["/" .. typeCommand .. ":" .. language].type = type
                WRC.ChatCommands["/" .. typeCommand .. ":" .. language].modifier = nil
                WRC.ChatCommands["/" .. typeCommand .. ":" .. language].language = language
            end
        end
        for modifier, modifierData in pairs(WRC.ChatModifiers) do
            for _, modifierCommand in pairs(modifierData.command) do
                for _, typeCommand in pairs(typeData.command) do
                    WRC.ChatCommands["/" .. modifierCommand .. typeCommand .. ":" .. language] = {}
                    WRC.ChatCommands["/" .. modifierCommand .. typeCommand .. ":" .. language].type = type
                    WRC.ChatCommands["/" .. modifierCommand .. typeCommand .. ":" .. language].modifier = modifier
                    WRC.ChatCommands["/" .. modifierCommand .. typeCommand .. ":" .. language].language = language
                end
            end
        end
    end
end

function WRC.Override(skipDisable)
    if WRC.Meta.DisableOverride and not skipDisable then return false end
    return isAdmin() or getAccessLevel() ~= ""
end

function WRC.CanSeePlayer(player, allowSelf, distance)
    if not distance then distance = 10 end
    if WRC.Override() then return true end
    if not player then return false end
    local me = getPlayer()
    if not allowSelf and player == me then return false end
    if not me:CanSee(player) then return false end
    if player:isGhostMode() then return false end
    if me:getDistanceSq(player) > distance * distance then return false end
    return true
end

function WRC.GetBodyParts()
    local bodyParts = {}
    for i=0,16 do
        table.insert(bodyParts, BodyPartType.ToString(BodyPartType.FromIndex(i)))
    end
    return bodyParts
end

function WRC.GetInjuries()
    return {
        "Bleeding",
        "Bullet",
        "Burned",
        "Deep Wound",
        "Fracture",
        "Glass Shards",
        "Infected",
        "Scratched",
        "Laceration",
        "Bite",
    }
end

--- @param message string
--- @return number,number the xyRange and zRange
function WRC.GetRangeFromMessage(message)
    if message:len() < 2 then
        return 0,0
    end
    if message:sub(1,1) ~= "/" then
        return WRC.ChatTypes["say"].xyRange, WRC.ChatTypes["say"].zRange
    end
    local firstSpace = message:find(" ")
    if not firstSpace then
        return 0,0
    end
    local command = message:sub(1, firstSpace - 1)
    if WRC.ChatCommands[command] then
        return WRC.ChatTypes[WRC.ChatCommands[command].type].xyRange, WRC.ChatTypes[WRC.ChatCommands[command].type].zRange
    end
    return 0,0
end

function WRC.GetAllPlayersInRange(range, zRange)
    local players = {}
    local me = getPlayer()
    local online = getOnlinePlayers()
    local range2 = range * range
    zRange = zRange or 0
    for i=0,online:size()-1 do
        local player = online:get(i)
        local zDist = math.abs(player:getZ() - me:getZ())
        if player ~= me and me:getDistanceSq(player) <= range2 and zDist <= zRange and not player:isGhostMode() then
            table.insert(players, player)
        end
    end
    return players

end

--- @param str string
--- @param sep string|nil
--- @return table
function WRC.SplitString(str, sep)
    if not sep then sep = " " end
    local parts = {}
    local part = ""
    local quote = false
    for i=1,str:len() do
        local c = str:sub(i,i)
        if c == '"' then
            quote = not quote
        elseif c == ' ' and not quote then
            if part:len() > 0 then
                table.insert(parts, part)
                part = ""
            end
        else
            part = part .. c
        end
    end
    if part:len() > 0 then
        table.insert(parts, part)
    end
    return parts
end

function WRC.GetColor(args)
    local color = args:gsub("^%s*(.-)%s*$", "%1") -- trim
    local rStr, gStr, bStr = color:match("(%d+),(%d+),(%d+)")
    if not rStr or not gStr or not bStr then
        WL_Utils.addErrorToChat("Invalid color format. EX: /color 0,128,255")
        return nil
    end
    local r, g, b = tonumber(rStr), tonumber(gStr), tonumber(bStr)
    if r < 0 or r > 255 or g < 0 or g > 255 or b < 0 or b > 255 then
        WL_Utils.addErrorToChat("Color numbers out of range of 0 to 255. EX: /color 0,128,255")
        return nil
    end
    r = math.floor(r/255 * 100)/100
    g = math.floor(g/255 * 100)/100
    b = math.floor(b/255 * 100)/100
    return {r = r, g = g, b = b}
end

local radiosShutOff = {}
local radiosShutOffPlayer = nil

local function restoreRadios()
    for i=1,#radiosShutOff do
        WRU_Utils.setRadioPowerInstant(radiosShutOffPlayer, radiosShutOff[i], true)
    end
    radiosShutOff = {}
end

local function muteRadios(player)
    radiosShutOffPlayer = player
    radiosShutOff = WRU_Utils.getPlayerRadios(player, true, true)
    for i=1,#radiosShutOff do
        WRU_Utils.setRadioPowerInstant(player, radiosShutOff[i], false)
    end
end

--- Send an in chat only local
--- @param chat string The chat to send
function WRC.SendLocalChat(chat)
    local player = getPlayer()
    chat= WRC.Parsing.PrependPlayerData(player, chat)
    muteRadios(player)
    processSayMessage(chat)
    restoreRadios()
end

local function determinePrefixForRange(range)
    if range == "whisper" then
        return "/mew"
    elseif range == "quiet" then
        return "/meq"
    elseif range == "yell" then
        return "/mey"
    elseif range == "shout" then
        return "/mes"
    end
    return "/me"
end

--- Send an above head emote only for the current player
--- @param emote string The emote to send, without the /me
--- @param range nil|"whisper"|"quiet"|"yell"|"shout" The range of the emote
function WRC.SendLocalEmote(emote, range)
    local player = getPlayer()
    if player:isGhostMode() then return end
    local me = determinePrefixForRange(range)
    emote = WRC.Parsing.PrependPlayerData(player, "[emote]" .. me .. " " .. emote)
    muteRadios(player)
    processSayMessage(emote)
    restoreRadios()
end

--- Send an above emote that everyone can see and goes to chat windows
--- @param emote string The emote to send, without the /me
--- @param range nil|"whisper"|"quiet"|"yell"|"shout" The range of the emote
function WRC.SendEmote(emote, range)
    local player = getPlayer()
    local me = determinePrefixForRange(range)
    emote = WRC.Parsing.PrependPlayerData(player, me .. " " .. emote)
    muteRadios(player)
    processSayMessage(emote)
    restoreRadios()
end

--- Sends an OOC message from the current player
--- @param message string The message to send, without the /ooc
--- @param range nil|"whisper"|"quiet"|"yell"|"shout" The range of the message
function WRC.SendLocalOOC(message, range)
    local player = getPlayer()
    if player:isGhostMode() then return end

    local ooc = "/ooc"
    if range == "whisper" then
        ooc = "/oocw"
    elseif range == "quiet" then
        ooc = "/oocq"
    elseif range == "yell" then
        ooc = "/oocy"
    elseif range == "shout" then
        ooc = "/oocs"
    end

    message = WRC.Parsing.PrependPlayerData(player, ooc .. " " .. message)
    muteRadios(player)
    processSayMessage(message)
    restoreRadios()
end
