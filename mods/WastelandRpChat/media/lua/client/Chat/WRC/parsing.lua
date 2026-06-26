if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC.Parsing = WRC.Parsing or {}

WRC.Parsing.AlwaysUnderstoodEnglishWords = {
    -- Greetings / politeness
    ["hello"] = true,
    ["hi"] = true,
    ["hey"] = true,
    ["bye"] = true,
    ["goodbye"] = true,
    ["please"] = true,
    ["thanks"] = true,
    ["thank"] = true,
    ["sorry"] = true,
    ["yes"] = true,
    ["no"] = true,
    -- Numbers
    ["0"] = true,
    ["1"] = true,
    ["2"] = true,
    ["3"] = true,
    ["4"] = true,
    ["5"] = true,
    ["6"] = true,
    ["7"] = true,
    ["8"] = true,
    ["9"] = true,
    ["10"] = true,
    ["zero"] = true,
    ["one"] = true,
    ["two"] = true,
    ["three"] = true,
    ["four"] = true,
    ["five"] = true,
    ["six"] = true,
    ["seven"] = true,
    ["eight"] = true,
    ["nine"] = true,
    ["ten"] = true,
    -- Curse words
    ["damn"] = true,
    ["hell"] = true,
    ["shit"] = true,
    ["fuck"] = true,
    ["crap"] = true,
    ["bastard"] = true,
    ["bitch"] = true,
    ["ass"] = true,
    ["asshole"] = true,
    -- Colors
    ["red"] = true,
    ["blue"] = true,
    ["green"] = true,
    ["yellow"] = true,
    ["orange"] = true,
    ["purple"] = true,
    ["pink"] = true,
    ["black"] = true,
    ["white"] = true,
    ["gray"] = true,
    ["grey"] = true,
    ["brown"] = true,
}

--- @param message string
--- @return table|nil
function WRC.Parsing.ParseMessage(message)
    local parsedMessage = {}
    local type = "say"
    local chatModifier = nil
    local language = nil
    local parts = {}
    local playerUsername = nil
    local pos = nil
    local fromRecorder = false
    local emote = false
    local onRadio = false
    local isNpc = false

    while true do
        local unMatch = message:match("^%[UN:([^%]]+)%]")
        local x,y,z = message:match("^%[POS:(%d+),(%d+),(%d+)%]")

        -- [UN:username]
        if unMatch then
            playerUsername = unMatch
            message = message:sub(unMatch:len() + 6, message:len())
        -- [POS:x,y,z]
        elseif x and y and z then
            pos = {x = tonumber(x), y = tonumber(y), z = tonumber(z)}
            message = message:sub(x:len() + y:len() + z:len() + 9, message:len())
        -- [Radio]
        elseif message:sub(1, 7) == "[radio]" then
            onRadio = true
            message = message:sub(8, message:len())
        -- [emote]
        elseif message:sub(1, 7) == "[emote]" then
            emote = true
            message = message:sub(8, message:len())
        -- [Recorder]
        elseif message:sub(1, 10) == "[Recorder]" then
            fromRecorder = true
            message = message:sub(11, message:len())
        -- [npc]
        elseif message:sub(1, 5) == "[npc]" then
            isNpc = true
            message = message:sub(6, message:len())
        else
            break
        end
    end

    if message:sub(1, 5) == "/roll" then
        local args = message:sub(7)

        local parts = WRC.SplitString(args)
        if #parts ~= 6 then
            return nil
        end

        local volume = parts[1]
        local numDice = tonumber(parts[2])
        local numSides = tonumber(parts[3])
        local bonus = tonumber(parts[4])
        local total = tonumber(parts[5])
        local rolls = parts[6]

        local message = "threw " .. numDice .. "d" .. numSides
        if bonus ~= "0" then
            message = message .. "+" .. bonus
        end
        message = message .. " and got " .. rolls .. " for a total of " .. total

        return {
            playerUsername = playerUsername,
            showName = true,
            chatType = volume,
            chatModifier = "roll",
            parts = {
                {
                    type = "roll",
                    text = message
                }
            }
        }
    end

    if message:contains("<") then
        message = message:gsub("<", "&lt;")
    end
    if message:contains("<") then
        message = message:gsub(">", "&gt;")
    end

    if message:sub(1,1) == "/" then
        -- parse chat type, modifier, and language from message using WRC.ChatCommands
        local space = message:find(" ")
        if not space then
            return nil
        end
        local command = message:sub(1, space - 1)
        if WRC.ChatCommands[command] then
            type = WRC.ChatCommands[command].type
            chatModifier = WRC.ChatCommands[command].modifier
            language = WRC.ChatCommands[command].language
        else
            return nil
        end
        -- remove chat type, modifier, and language from message
        message = message:sub(command:len() + 2, message:len())
    end

    -- remove leading and trailing spaces
    message = message:gsub("^%s*(.-)%s*$", "%1")

    if message == "" then
        return nil
    end

    if chatModifier then
        if WRC.ChatModifiers[chatModifier].singleLine then
            table.insert(parts, {type = WRC.ChatModifiers[chatModifier].type , text = message})
        else
            -- parse message into parts
            local currentPart = {type = WRC.ChatModifiers[chatModifier].type, text = ""}
            local inQuotes = false
            for i = 1, message:len() do
                local char = message:sub(i, i)
                if char == "'" then
                    -- check if next char is also a single quote. If so, treat it like a double quote
                    if i < message:len() and message:sub(i + 1, i + 1) == "'" then
                        char = "\""
                        i = i + 1
                    end
                end
                if char == "\"" then
                    inQuotes = not inQuotes
                    table.insert(parts, currentPart)
                    currentPart = {type = inQuotes and "text" or WRC.ChatModifiers[chatModifier].type, text = ""}
                else
                    currentPart.text = currentPart.text .. char
                end
            end
            if currentPart.text ~= "" then
                table.insert(parts, currentPart)
            end
        end
    else
        -- check if message is wrapped in quotes, and remove them if so
        if message:sub(1,1) == "\"" and message:sub(message:len(), message:len()) == "\"" then
            message = message:sub(2, message:len() - 1)
        end

        table.insert(parts, {type = "emote", text = WRC.Parsing.DeterminePrefix(type, message) .. " "})
        table.insert(parts, {type = "text", text = message})
    end

    if #parts == 0 then
        return nil
    end

    parsedMessage.showName = not chatModifier or not WRC.ChatModifiers[chatModifier].hideName
    parsedMessage.chatType = type
    parsedMessage.parts = parts
    parsedMessage.language = language
    parsedMessage.playerUsername = playerUsername
    parsedMessage.chatModifier = chatModifier
    parsedMessage.pos = pos
    parsedMessage.fromRecorder = fromRecorder
    parsedMessage.isEmote = emote
    parsedMessage.onRadio = onRadio
    parsedMessage.isNpc = isNpc
    return parsedMessage
end

function WRC.Parsing.GetOriginalMessage(parsedMessage)
    local messageParts = {}
    -- output tags
    if parsedMessage.playerUsername then
        table.insert(messageParts, "[UN:" .. parsedMessage.playerUsername .. "]")
    end
    if parsedMessage.pos then
        table.insert(messageParts, "[POS:" .. parsedMessage.pos.x .. "," .. parsedMessage.pos.y .. "," .. parsedMessage.pos.z .. "]")
    end
    if parsedMessage.onRadio then
        table.insert(messageParts, "[radio]")
    end
    if parsedMessage.isEmote then
        table.insert(messageParts, "[emote]")
    end
    if parsedMessage.fromRecorder then
        table.insert(messageParts, "[Recorder]")
    end
    if parsedMessage.isNpc then
        table.insert(messageParts, "[npc]")
    end
    -- output type, modifier, and language
    for key, command in pairs(WRC.ChatCommands) do
        if command.type == parsedMessage.chatType and command.modifier == parsedMessage.chatModifier and command.language == parsedMessage.language then
            table.insert(messageParts, key)
            break
        end
    end
    table.insert(messageParts, " ")
    -- output parts
    if not parsedMessage.chatModifier then
        table.insert(messageParts, parsedMessage.parts[2].text)
    else
        for _, part in ipairs(parsedMessage.parts) do
            if part.type == "text" then
                table.insert(messageParts, "\"" .. part.text .. "\"" .. " ")
            else
                table.insert(messageParts, part.text .. " ")
            end
        end
    end
    return table.concat(messageParts)
end

function WRC.Parsing.GetTextConvertedToOoc(parsedMessage)
    return "/ooc" .. WRC.ChatTypes[parsedMessage.chatType].command[1] .. " " .. parsedMessage.parts[2].text
end

function WRC.Parsing.GetTextConvertedToEvent(parsedMessage)
    return "/event" .. WRC.ChatTypes[parsedMessage.chatType].command[1] .. " " .. parsedMessage.parts[2].text
end

function WRC.Parsing.PrependPlayerData(player, message)
    local x = tostring(math.floor(player:getX()))
    local y = tostring(math.floor(player:getY()))
    local z = tostring(math.floor(player:getZ()))
    return "[UN:" .. player:getUsername() .. "][POS:" .. x .. "," .. y .. "," .. z .. "]" .. message
end

function WRC.Parsing.GetRandomWordsFromMessage(message, percentChancePerWord)
    local words = {}
    local word = ""
    message = message .. " "
    for i=1, message:len() do
        local char = message:sub(i, i)
        if char == " " then
            if ZombRand(100) < percentChancePerWord then
                table.insert(words, word)
            end
            word = ""
        else
            word = word .. char
        end
    end
    return words
end

local function normalizeUnderstoodWord(word)
    word = word:lower()
    word = word:gsub("^[^%a%d']+", "")
    word = word:gsub("[^%a%d']+$", "")
    return word
end

function WRC.Parsing.GetAlwaysUnderstoodWordsFromMessage(message)
    local words = {}
    local seen = {}
    for rawWord in message:gmatch("[%a%d']+") do
        local word = rawWord:lower()
        if WRC.Parsing.AlwaysUnderstoodEnglishWords[word] and not seen[word] then
            seen[word] = true
            table.insert(words, rawWord)
        end
    end
    return words
end

function WRC.Parsing.MergeUnderstoodWords(alwaysUnderstoodWords, randomWords)
    local mergedWords = {}
    local seen = {}

    for i=1, #alwaysUnderstoodWords do
        local word = alwaysUnderstoodWords[i]
        local normalizedWord = normalizeUnderstoodWord(word)
        if normalizedWord ~= "" and not seen[normalizedWord] then
            seen[normalizedWord] = true
            table.insert(mergedWords, word)
        end
    end

    for i=1, #randomWords do
        local word = randomWords[i]
        local normalizedWord = normalizeUnderstoodWord(word)
        if normalizedWord ~= "" and not seen[normalizedWord] then
            seen[normalizedWord] = true
            table.insert(mergedWords, word)
        end
    end

    return mergedWords
end

function WRC.Parsing.AdjustForDeaf(parsedMessage)
    if WRC.Meta.CanSpeak("asl") and parsedMessage.language == "asl" then
        return
    end
    for _, part in ipairs(parsedMessage.parts) do
        if part.type == "text" then
            local newText = ""
            for c in part.text:gmatch(".") do
                if c == " " or c == "." or c == "," or c == "!" or c == "?" or c == ";" or c == ":" then
                    newText = newText .. c
                else
                    newText = newText .. "-"
                end
            end
            part.text = newText
        end
    end
end

WRC.Parsing.HoH_BottomRange = 0.35
WRC.Parsing.HoH_MaxFail = 0.8
function WRC.Parsing.AdjustForHardOfHearing(parsedMessage, rangeRatio)
    if rangeRatio < WRC.Parsing.HoH_BottomRange then
        return
    end
    if WRC.Meta.CanSpeak("asl") and parsedMessage.language == "asl" then
        return
    end
    local failChance = (rangeRatio - WRC.Parsing.HoH_BottomRange) / (1 - WRC.Parsing.HoH_BottomRange) * WRC.Parsing.HoH_MaxFail * 100
    for _, part in ipairs(parsedMessage.parts) do
        if part.type == "text" then
            local newText = ""
            for c in part.text:gmatch(".") do
                if ZombRand(100) > failChance or c == " " or c == "." or c == "," or c == "!" or c == "?" or c == ";" or c == ":" then
                    newText = newText .. c
                else
                    newText = newText .. "-"
                end
            end
            part.text = newText
        end
    end
end

function WRC.Parsing.AdjustForUnknownLanguage(parsedMessage)
    local partialUnderstandingChance = WRC.Meta.GetPartialUnderstandingChance(parsedMessage.language)
    for i=1, #parsedMessage.parts do
        if parsedMessage.parts[i].type == "text" then
            local len = parsedMessage.parts[i].text:len()
            if parsedMessage.language == "asl" then
                if len > 100 then
                    parsedMessage.parts[i] = {
                        type = "emotemuted",
                        text = "a lot of ASL"
                    }
                elseif len > 50 then
                    parsedMessage.parts[i] = {
                        type = "emotemuted",
                        text = "some ASL"
                    }
                else
                    parsedMessage.parts[i] = {
                        type = "emotemuted",
                        text = "a little ASL"
                    }
                end
            else
                local understoodText
                if partialUnderstandingChance > 0 then
                    local alwaysUnderstoodWords = WRC.Parsing.GetAlwaysUnderstoodWordsFromMessage(parsedMessage.parts[i].text)
                    local randomWords = WRC.Parsing.GetRandomWordsFromMessage(parsedMessage.parts[i].text, partialUnderstandingChance)
                    local understoodWords = WRC.Parsing.MergeUnderstoodWords(alwaysUnderstoodWords, randomWords)
                    if #understoodWords > 0 then
                        understoodText = " but you picked up: " .. table.concat(understoodWords, ", ")
                    end
                end
                if len > 100 then
                    parsedMessage.parts[i] = {
                        type = "textmuted",
                        text = "a lot of " .. WRC.Languages[parsedMessage.language].name
                    }
                elseif len > 50 then
                    parsedMessage.parts[i] = {
                        type = "textmuted",
                        text = "some " .. WRC.Languages[parsedMessage.language].name
                    }
                else
                    parsedMessage.parts[i] = {
                        type = "textmuted",
                        text = "a little " .. WRC.Languages[parsedMessage.language].name
                    }
                end
                if understoodText then
                    parsedMessage.parts[i].text = parsedMessage.parts[i].text .. understoodText
                end
            end
        end
    end
end

function WRC.Parsing.DeterminePrefix(chatType, line)
    local hasQuestion = line.find(line, "?") ~= nil
    local hasExclamation = line.find(line, "!") ~= nil
    if hasQuestion then
        return WRC.ChatTypes[chatType].questionPrefix
    elseif hasExclamation then
        return WRC.ChatTypes[chatType].exclamationPrefix
    else
        return WRC.ChatTypes[chatType].defaultPrefix
    end
end

function WRC.Parsing.GetSpecialStart(text)
    if text:sub(1, 3) == "'s " then return "'s " end
    if text:sub(1, 2) == ", " then return ", " end
    if text:sub(1, 2) == ": " then return ": " end
    return nil
end

function WRC.Parsing.FormatPart(part, omitStart)
    local text = part.text
    if text and omitStart then
        text = text:sub(omitStart + 1, text:len())
    end
    if part.type == "text" then
        local sayColor = WRC.Meta.GetSayColor()
        return WRC.ChatColors[part.type] .. sayColor .. "\"" .. text .. "\"" .. WL_Utils.MagicSpace
    elseif part.type == "textmuted" then
        return WRC.ChatColors[part.type] .. "\"" .. text .. "\"" .. WL_Utils.MagicSpace
    elseif part.type == "ooc" then
        local oocColor = WRC.Meta.GetOocColor()
        return oocColor .. "OOC " .. text .. WL_Utils.MagicSpace
    elseif part.type == "environment" then
        local doColor = WRC.Meta.GetDoColor()
        return doColor .. "[[ " .. text .. " ]]" .. WL_Utils.MagicSpace
    elseif part.type == "emote" then
        local emoteColor = WRC.Meta.GetEmoteColor()
        return emoteColor .. text .. WL_Utils.MagicSpace
    elseif part.type == "alert" then
        local alertColor = WRC.ChatColors["alert"]
        return alertColor .. text .. WL_Utils.MagicSpace
    elseif part.type == "roll" then
        local fontHeight = getTextManager():MeasureStringY(UIFont.NewSmall, "XXX")
        local imageTag = " <IMAGE:Item_Dice,".. fontHeight .. "," .. fontHeight .. ">"
        return WRC.ChatColors[part.type] .. imageTag .. text .. imageTag .. WL_Utils.MagicSpace
    else
        return WRC.ChatColors[part.type] .. text .. WL_Utils.MagicSpace
    end
end

local fontHeight = getTextManager():MeasureStringY(UIFont.NewSmall, "XXX")
-- format a parsed message into a string
function WRC.Parsing.FormatMessage(parsedMessage)
    local message = ""
    local hadText = false

    local specialStart
    if parsedMessage.playerUsername and parsedMessage.showName then
        specialStart = WRC.Parsing.GetSpecialStart(parsedMessage.parts[1].text)
        if parsedMessage.parts[1].type == "emote" and specialStart then
            message = WRC.Meta.GetNameColor(parsedMessage.playerUsername) .. WRC.Meta.GetName(parsedMessage.playerUsername) .. specialStart .. WL_Utils.MagicSpace
        else
            message = WRC.Meta.GetNameColor(parsedMessage.playerUsername) .. WRC.Meta.GetName(parsedMessage.playerUsername) .. WL_Utils.MagicSpace
        end
    end

    -- capitalize first letter of the first text part in parts
    for i=1, #parsedMessage.parts do
        if parsedMessage.parts[i].type == "text" then
            parsedMessage.parts[i].text = parsedMessage.parts[i].text:sub(1, 1):upper() .. parsedMessage.parts[i].text:sub(2, parsedMessage.parts[i].text:len())
            break
        end
    end

    -- append punctuation to the last text part in parts if it doesn't already have punctuation
    for i=#parsedMessage.parts, 1, -1 do
        if parsedMessage.parts[i].type == "text" then
            local lastChar = parsedMessage.parts[i].text:sub(parsedMessage.parts[i].text:len(), parsedMessage.parts[i].text:len())
            if lastChar ~= "." and lastChar ~= "!" and lastChar ~= "?" and lastChar ~= "," then
                parsedMessage.parts[i].text = parsedMessage.parts[i].text .. "."
            end
            break
        end
    end

    for n, part in ipairs(parsedMessage.parts) do
        if part.type == "text" or part.type == "textmuted" then
            hadText = true
        end
        if n == 1 and specialStart then
            message = message .. WRC.Parsing.FormatPart(part, specialStart:len())
        else
            message = message .. WRC.Parsing.FormatPart(part)
        end
    end

    if hadText then
        local language = parsedMessage.language or WRC.Meta.GetCurrentLanguage(parsedMessage.playerUsername)
        if language ~= "en" or not WRC.Meta.CanUnderstand(language) then
            message = WRC.ChatColors["langprefix"] .. "[" .. WRC.Languages[language].name .. "]" .. WL_Utils.MagicSpace .. message
        end
    end

    if parsedMessage.chatType == "whisper" then
        message = WRC.Meta.GetWhisperVolumeColor() .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "]" .. WL_Utils.MagicSpace .. message
    elseif parsedMessage.chatType == "low" then
        message = WRC.Meta.GetLowVolumeColor() .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "]" .. WL_Utils.MagicSpace .. message
    elseif parsedMessage.chatType == "say" then
        message = WRC.Meta.GetSayVolumeColor() .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "]" .. WL_Utils.MagicSpace .. message
    elseif parsedMessage.chatType == "loud" then
        message = WRC.Meta.GetLoudVolumeColor() .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "]" .. WL_Utils.MagicSpace .. message
    elseif parsedMessage.chatType == "shout" then
        message = WRC.Meta.GetShoutVolumeColor() .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "]" .. WL_Utils.MagicSpace .. message
    end

    if parsedMessage.fromRecorder then
        message = WRC.ChatColors["info"] .. "[Recorder]" .. WL_Utils.MagicSpace .. message
    end

    if WRC.Meta.HasNpcTag(parsedMessage.playerUsername) or parsedMessage.isNpc then
        message = WRC.ChatColors["npctag"] .. "[NPC]" .. WL_Utils.MagicSpace .. message
    end

    if WRC.Meta.HasAdminHammer(parsedMessage.playerUsername) or parsedMessage.parts[1].type == "alert" then
        message = WRC.ChatColors["admintag"] .. "[Admin] <IMAGE:Item_Hammer,".. fontHeight .. "," .. fontHeight .. ">" .. WL_Utils.MagicSpace .. message
    end

    if parsedMessage.parts[1].type == "event" then
        message = WRC.ChatColors["event"] .. "[Event]" .. WL_Utils.MagicSpace .. message
    end

    if parsedMessage.radioFrequency and parsedMessage.radioFrequency > 0 then
        if parsedMessage.isOwnRadio then
            local freq = tostring(parsedMessage.radioFrequency/1000) .. " MHz"
            message = WRC.ChatColors["radiochannel"] .. "[" .. freq .. "]" .. WL_Utils.MagicSpace .. message
        else
            message = WRC.ChatColors["radiochannel"] .. "[Radio]" .. WL_Utils.MagicSpace .. message
        end
    end

    return message
end

function WRC.Parsing.GetTextOnly(parsedMessage)
    local message = WRC.Meta.GetName(parsedMessage.playerUsername)
    for n, part in ipairs(parsedMessage.parts) do
        if n == 1 and part.type == "emote" and WRC.Parsing.GetSpecialStart(part.text) then
            message = message .. part.text
        elseif part.type == "textmuted" then
            message = message .. ' "Something you dont understand."'
        elseif part.type == "text" then
            message = message .. ' "' .. part.text .. '"'
        elseif part.type == "ooc" then
            message = message .. " (( " .. part.text .. " ))"
        elseif part.type == "environment" then
            message = message .. " [[ " .. part.text .. " ]]"
        else
            message = message .. " " .. part.text
        end
    end
    if message:contains("&lt;") then
        message = message:gsub("&lt;", "<")
    end
    if message:contains("&gt;") then
        message = message:gsub("&gt;", ">")
    end
    return message
end

function WRC.Parsing.GetLogText(parsedMessage)
    local message = ""
    if parsedMessage.radioFrequency and parsedMessage.radioFrequency > 0 then
        local freq = tostring(parsedMessage.radioFrequency/1000) .. " MHz"
        message = message .. "[" .. freq .. "] "
    end
    message = message .. "[" .. WRC.ChatTypes[parsedMessage.chatType].volumePrefix .. "] "
    message = message .. WRC.Parsing.GetTextOnly(parsedMessage)
    return message
end

local vowelReplacements = {
    e = {"a"},
    a = {"e", "o"},
    i = {"e"},
    o = {"a"},
    u = {"o"}
}

function getSlurredLetter(char, isWordStart, isWordEnd, strength)
    local vowels = "aeiou"
    local slurChance = ZombRand(1, 100)  -- Random number between 1 and 100
    local chance = strength * 10         -- Chance scales with strength (10% per level)

    if chance > 10 then
        -- Replace 's' with 'sh' for slurring
        if char:lower() == "s" and slurChance <= chance + 20 then
            return (char == "S") and "Sh" or "sh"
        end

        -- Replace 'r' with 'w' or drag it
        if char:lower() == "r" and slurChance <= chance then
            if slurChance % 2 == 0 then
                return "w"
            else
                return char:rep(ZombRand(2, 4))
            end
        end
    end

    if chance > 20 then
        -- Replace 'l' with 'w' or 'r'
        if char:lower() == "l" and slurChance <= chance then
            return (slurChance % 2 == 0) and "w" or "r"
        end

        -- Replace 'p' with 'b'
        if char:lower() == "p" and slurChance <= chance then
            return (char == "P") and "B" or "b"
        end

        -- Replace 'k' with 'g'
        if char:lower() == "k" and slurChance <= chance then
            return (char == "K") and "G" or "g"
        end

        -- Replace 'v' with 'b'
        if char:lower() == "v" and slurChance <= chance then
            return (char == "V") and "B" or "b"
        end

        -- Replace 'f' with 'v'
        if char:lower() == "f" and slurChance <= chance then
            return (char == "F") and "V" or "v"
        end
    end

    -- Vowel elongation
    if vowels:find(char:lower()) and slurChance <= chance then
        return char:rep(ZombRand(2, 4))
    end

    -- Replace vowels with alternatives if utterly drunk
    if chance > 30 and vowels:find(char:lower()) and slurChance <= chance + 30 then
        local replacements = vowelReplacements[char:lower()]
        if replacements then
            local replacement = replacements[ZombRand(1, #replacements + 1)]
            return (char == char:upper()) and replacement:upper() or replacement
        end
    end

    -- Leave character unchanged
    return char
end

function WRC.Parsing.MakeQuiet(text)
    if text:sub(1, 1) ~= "/" then
        return "/low " .. text
    end

    if text:sub(1, 3) == "/m " then
        return "/ml " .. text:sub(4)
    end

    if text:sub(1, 4) == "/me " then
        return "/mel " .. text:sub(5)
    end

    return text
end

function WRC.Parsing.SlurText(text, strength)
    local message = WRC.Parsing.ParseMessage(text)

    for _, part in ipairs(message.parts) do
        if part.type == "text" then
            local slurredText = {}
            local partText = part.text

            -- Character-level slurring
            for i = 1, #partText do
                local char = partText:sub(i, i)
                local wordStart = (i == 1 or partText:sub(i - 1, i - 1) == " ")
                local wordEnd = (i == #partText or partText:sub(i + 1, i + 1) == " ")
                table.insert(slurredText, getSlurredLetter(char, wordStart, wordEnd, strength))
            end

            part.text = table.concat(slurredText)
        end
    end

    return WRC.Parsing.GetOriginalMessage(message)
end

function WRC.Parsing.AppendFromRadio(message)
    return WRC.ChatColors["fromRadio"] .. "[Into Radio] " .. message
end
