if not isClient() then return end -- only in MP

require "WL_Utils"
require "WLADC_System"

WRC = WRC or {}
WRC.Meta = WRC.Meta or {}

WRC.GlobalState = WRC.GlobalState or {}
WRC.Meta.DisableOverride = false
WRC.Meta.ChatForced = {}
WRC.Meta.LastChat = nil
WRC.Meta.LastEvent = nil
WRC.Meta.ChatPreferences = WRC.Meta.ChatPreferences  or {}

-- Defaults
WRC.Meta.ChatPreferences["SayColor"] = WRC.Meta.ChatPreferences["SayColor"] or WRC.ChatColors["text"]
WRC.Meta.ChatPreferences["EmoteColor"] = WRC.Meta.ChatPreferences["EmoteColor"] or WRC.ChatColors["emote"]
WRC.Meta.ChatPreferences["DoColor"] = WRC.Meta.ChatPreferences["DoColor"] or WRC.ChatColors["environment"]
WRC.Meta.ChatPreferences["OocColor"] = WRC.Meta.ChatPreferences["OocColor"] or WRC.ChatColors["ooc"]
WRC.Meta.ChatPreferences["WhisperVolumeColor"] = WRC.Meta.ChatPreferences["WhisperVolumeColor"] or WRC.ChatColors["volumeprefixes"]["whisper"]
WRC.Meta.ChatPreferences["LowVolumeColor"] = WRC.Meta.ChatPreferences["LowVolumeColor"] or WRC.ChatColors["volumeprefixes"]["low"]
WRC.Meta.ChatPreferences["SayVolumeColor"] = WRC.Meta.ChatPreferences["SayVolumeColor"] or WRC.ChatColors["volumeprefixes"]["say"]
WRC.Meta.ChatPreferences["LoudVolumeColor"] = WRC.Meta.ChatPreferences["LoudVolumeColor"] or WRC.ChatColors["volumeprefixes"]["loud"]
WRC.Meta.ChatPreferences["ShoutVolumeColor"] = WRC.Meta.ChatPreferences["ShoutVolumeColor"] or WRC.ChatColors["volumeprefixes"]["shout"]
WRC.Meta.ChatPreferences["UnreadTabTextColor"] = WRC.Meta.ChatPreferences["UnreadTabTextColor"] or {r = 0, g = 0, b = 0}
WRC.Meta.ChatPreferences["UnreadTabBackgroundColor"] = WRC.Meta.ChatPreferences["UnreadTabBackgroundColor"] or {r = 1, g = 0, b = 0}
WRC.Meta.ChatPreferences["UnreadTabBlinking"] = WRC.Meta.ChatPreferences["UnreadTabBlinking"] or true
WRC.Meta.ChatPreferences["OverheadTypingIndicator"] = WRC.Meta.ChatPreferences["OverheadTypingIndicator"] or true
WRC.Meta.ChatPreferences["InvertStatus"] = WRC.Meta.ChatPreferences["InvertStatus"] or false
WRC.Meta.ChatPreferences["SaveLastChat"] = WRC.Meta.ChatPreferences["SaveLastChat"] or false
WRC.Meta.ChatPreferences["KeepSafe"] = WRC.Meta.ChatPreferences["KeepSafe"] or true


local function changeModifer(modifer, enable)
    local args = {}
    if enable then
        args[1] = "enable"
    else
        args[1] = "disable"
    end
    args[2] = modifer
    sendClientCommand(getPlayer(), "WRC", "SetModifier", args)
end

local function getModifier(username, modifier)
    if not WRC.PlayerModifiers[username] then return false end
    if not WRC.PlayerModifiers[username][modifier] then return false end
    return true
end

-- Writes the WRC.Meta.ChatPreferences to a WRC_ChatPreferences.txt file
-- key1=value1
-- key2=value2
-- ...
local function writeChatPrefs()
    local file = getFileWriter("WRC_ChatPreferences.txt", true, false)
    if not file then return end
    for k, v in pairs(WRC.Meta.ChatPreferences) do
        if type(v) == "boolean" then
            v = tostring(v)
        elseif type(v) == "table" and v.r ~= nil and v.g ~= nil and v.b ~= nil then
            v = v.r .. "," .. v.g .. "," .. v.b
        elseif type(v) == "number" then
            v = tostring(v)
        elseif type(v) == "string" then
            -- do nothing
        else
            print("WRC: Unknown type for chat preference " .. k .. ": " .. type(v))
            v = ""
        end
        file:write(k .. "=" .. v .. "\n")
    end
    file:close()
end

-- Updates WRC.Meta.ChatPreferences then writes it
local function writeChatPref(preference, value)
    WRC.Meta.ChatPreferences[preference] = value
    writeChatPrefs()
end

local function getChatPref(preference)
    return WRC.Meta.ChatPreferences[preference]
end

local function getGlobalState(key)
    return WRC.GlobalState[key]
end

local function setGlobalState(key, value)
    WRC.GlobalState[key] = value
    sendClientCommand(getPlayer(), "WRC", "SetGlobalState", {key, value})
end

-- Reads the WRC.Meta.ChatPreferences from a WRC_ChatPreferences.txt file
local function readChatPrefs()
    local file = getFileReader("WRC_ChatPreferences.txt", false)
    if not file then return end
    local line = file:readLine()
    while line do
        local split = string.split(line, "=")
        if #split == 2 then
            local val = split[2]
            -- true/false
            if val == "true" then
                val = true
            elseif val == "false" then
                val = false
            else
                local r, g, b = val:match("^(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)$")
                if r and g and b then
                    local rgb = string.split(val, ",")
                    val = {r = tonumber(rgb[1]), g = tonumber(rgb[2]), b = tonumber(rgb[3])}
                -- number
                elseif val:match("^%d+$") then
                    val = tonumber(val)
                end
            end
            WRC.Meta.ChatPreferences[split[1]] = val
        end
        line = file:readLine()
    end
    file:close()
end

function WRC.Meta.GetKnownLanguages()
    local md = getPlayer():getModData()
    local languages = {}
    local numKnown = md["WRC_NumKnownLanguages"] or 0
    if numKnown == 0 then
        md["WRC_NumKnownLanguages"] = 1
        if getPlayer():HasTrait("Deaf") then
            md["WRC_KnownLanguage1"] = "asl"
            languages = {"asl"}
        else
            md["WRC_KnownLanguage1"] = "en"
            languages = {"en"}
        end
    else
        for i=1, numKnown do
            table.insert(languages, md["WRC_KnownLanguage" .. i])
        end
    end
    if WRC.Meta.ChatForced and WRC.Meta.ChatForced[getPlayer():getUsername()] then
        table.insert(languages, WRC.Meta.ChatForced[getPlayer():getUsername()])
    end
    return languages
end

function WRC.Meta.AddLanguageTo(username, language)
    local args = {}
    args[1] = username
    args[2] = language
    -- TODO move this
    sendClientCommand(getPlayer(), "WRC", "AddKnownLanguage", args)
end

function WRC.Meta.RemoveLanguageFrom(username, language)
    local args = {}
    args[1] = username
    args[2] = language
    sendClientCommand(getPlayer(), "WRC", "RemoveKnownLanguage", args)
end

function WRC.Meta.ForceLanguage(player, language)
    if language then
        WRC.Meta.ChatForced[player:getUsername()] = language
    else
        WRC.Meta.ChatForced[player:getUsername()] = nil
    end
end

local function writeLanguages(languages)
    local md = getPlayer():getModData()
    local numKnown = #languages
    if numKnown == 0 then
        numKnown = 1
        if getPlayer():HasTrait("Deaf") then
            md["WRC_KnownLanguage1"] = "asl"
            return
        else
            md["WRC_KnownLanguage1"] = "en"
            return
        end
    end
    md["WRC_NumKnownLanguages"] = numKnown
    for i=1, numKnown do
        md["WRC_KnownLanguage" .. i] = languages[i]
    end
end

function WRC.Meta.AddKnownLanguage(language)
    local languages = WRC.Meta.GetKnownLanguages()
    for i=1, #languages do
        if languages[i] == language then
            return
        end
    end
    table.insert(languages, language)
    writeLanguages(languages)
end

function WRC.Meta.RemoveKnownLanguage(language)
    local md = getPlayer():getModData()
    local known = WRC.Meta.GetKnownLanguages()
    local toKeep = {}
    for i=1, #known do
        if known[i] ~= language then
            table.insert(toKeep, known[i])
        end
    end
    writeLanguages(toKeep)
end

function WRC.Meta.CanSpeak(language)
    if WRC.Override() then return true end
    local known = WRC.Meta.GetKnownLanguages()
    for i=1, #known do
        if known[i] == language then
            return true
        end
    end
    return false
end

function WRC.Meta.CanUnderstand(language)
    if WRC.Override() then return true end

    local known = WRC.Meta.GetKnownLanguages()
    for _, l in ipairs(known) do
        if l == language then
            local wrcLang = WRC.Languages[l]
            if not (wrcLang and wrcLang.noFullSelfUnderstand) then
                return true
            end
        end
        local wrcLang = WRC.Languages[l]
        if wrcLang.canFullyUnderstand then
            for _, ll in ipairs(wrcLang.canFullyUnderstand) do
                if ll == language then
                    return true
                end
            end
        end
    end
    return false
end

function WRC.Meta.CanPartiallyUnderstand(language)
    return WRC.Meta.GetPartialUnderstandingChance(language) > 0
end

function WRC.Meta.GetPartialUnderstandingChance(language)
    if WRC.Override() then return 100 end
    local known = WRC.Meta.GetKnownLanguages()
    for _, l in ipairs(known) do
        local wrcLang = WRC.Languages[l]
        if wrcLang.partialUnderstanding and wrcLang.partialUnderstanding[language] then
            return wrcLang.partialUnderstanding[language]
        end
    end
    return 0
end

--- @param username string
function WRC.Meta.GetCurrentLanguage(username)
    if WRC.PlayerLanguages and WRC.PlayerLanguages[username] then
        return WRC.PlayerLanguages[username]
    end
    if getPlayer():getUsername() == username then
        local known = WRC.Meta.GetKnownLanguages()
        if #known > 0 then
            WRC.Meta.SetCurrentLanguage(known[1])
            return known[1]
        end
    end
    return "en"
end

function WRC.Meta.SetCurrentLanguage(language)
    local args = {}
    args[1] = language
    sendClientCommand(getPlayer(), "WRC", "SetPlayerLanguage", args)
end

function WRC.Meta.IsInRange(myPlayer, chattingPlayer, xyRange, zRange)
    if WRC.Override() then return true end

    xyRange = xyRange + 0.99
    if myPlayer:getDistanceSq(chattingPlayer) > xyRange * xyRange or math.abs(myPlayer:getZ() - chattingPlayer:getZ()) > zRange then
        return false
    end

    return true
end

function WRC.Meta.IsInPosRange(myPlayer, pos, xyRange, zRange)
    if WRC.Override() then return true end

    xyRange = xyRange + 0.99

    local xDist = myPlayer:getX() - pos.x
    local yDist = myPlayer:getY() - pos.y
    local zDist = math.abs(myPlayer:getZ() - pos.z)
    local xyDistSq = xDist * xDist + yDist * yDist

    if xyDistSq > xyRange * xyRange or zDist > zRange then
        return false
    end

    return true
end

function WRC.Meta.GetStatus(username)
    local status = nil
    if WRC.PlayerStatus and WRC.PlayerStatus[username] then
        status = WRC.PlayerStatus[username]
    end
    return status
end

function WRC.Meta.SetStatus(status)
    local args = {}
    args[1] = status
    sendClientCommand(getPlayer(), "WRC", "SetPlayerStatus", args)
end

function WRC.Meta.GetInvertedStatus(username)
    local inverted = false
    if WRC.InvertStatus and WRC.InvertStatus[username] then
        inverted = WRC.InvertStatus[username]
    end
    return inverted
end
function WRC.Meta.InvertStatus(inverted)
    local args = {}
    args[1] = inverted
    sendClientCommand(getPlayer(), "WRC", "InvertStatus", args)
end

function WRC.Meta.GetInjured(username)
    local injured = nil
    if WRC.InjuredAbove and WRC.InjuredAbove[username] then
        injured = WRC.InjuredAbove[username]
    end
    return injured
end

function WRC.Meta.SetInjured(injured)
    local args = {}
    args[1] = injured
    sendClientCommand(getPlayer(), "WRC", "SetInjuredAbove", args)
end

function WRC.Meta.GetStreaming(username)
    local streaming = nil
    if WRC.StreamingAbove and WRC.StreamingAbove[username] then
        streaming = WRC.StreamingAbove[username]
    end
    return streaming
end

function WRC.Meta.SetStreaming(streaming)
    local args = {}
    args[1] = streaming
    sendClientCommand(getPlayer(), "WRC", "SetStreamingAbove", args)
end

function WRC.Meta.getLimpLeft(username)
    local leftLimp = nil
    if WRC.LimpLeft and WRC.LimpLeft[username] then
        leftLimp = WRC.LimpLeft[username]
    end
    return leftLimp
end

function WRC.Meta.setLimpLeft(leftLimp)
    local args = {}
    args[1] = leftLimp
    sendClientCommand(getPlayer(), "WRC", "LimpLeft", args)
end

function WRC.Meta.getLimpRight(username)
    local rightLimp = nil
    if WRC.LimpRight and WRC.LimpRight[username] then
        rightLimp = WRC.LimpRight[username]
    end
    return rightLimp
end

function WRC.Meta.setLimpRight(rightLimp)
    local args = {}
    args[1] = rightLimp
    sendClientCommand(getPlayer(), "WRC", "LimpRight", args)
end

function WRC.Meta.GetName(username)
    local name = username
    if WRC.PlayerNames and WRC.PlayerNames[username] then
        name = WRC.PlayerNames[username]
    end
	return name
end

function WRC.Meta.SetName(newName)
    local player = getPlayer()
    player:getDescriptor():setForename(newName)
    player:getDescriptor():setSurname("")
    sendPlayerStatsChange(player)
    local args = {}
    args[1] = newName
    sendClientCommand(player, "WRC", "SetPlayerName", args)
end

function WRC.Meta.GetNameColor(username)
    local c = WRC.ChatColors["playerDefault"]
    if WRC.PlayerColors and WRC.PlayerColors[username] then
        c = WRC.PlayerColors[username]
    end
    return "<RGB:" .. c.r .. "," .. c.g .. "," .. c.b .. ">"
end

function WRC.Meta.GetNameColorRGB(username)
    local c = WRC.ChatColors["playerDefault"]
    if WRC.PlayerColors and WRC.PlayerColors[username] then
        c = WRC.PlayerColors[username]
    end
    return c
end

function WRC.Meta.SetNameColor(r, g, b)
    local args = {}
    args[1] = r
    args[2] = g
    args[3] = b
    sendClientCommand(getPlayer(), "WRC", "SetPlayerColor", args)
end

function WRC.Meta.GetSayColor()
    return getChatPref("SayColor")
end

function WRC.Meta.SetSayColor(color)
    writeChatPref("SayColor", color)
end

function WRC.Meta.GetEmoteColor()
    return getChatPref("EmoteColor")
end

function WRC.Meta.SetEmoteColor(color)
    writeChatPref("EmoteColor", color)
end

function WRC.Meta.GetDoColor()
    return getChatPref("DoColor")
end

function WRC.Meta.SetDoColor(doColor)
    writeChatPref("DoColor", doColor)
end

function WRC.Meta.GetOocColor()
    return getChatPref("OocColor")
end

function WRC.Meta.SetOocColor(color)
    writeChatPref("OocColor", color)
end

function WRC.Meta.GetWhisperVolumeColor()
    return getChatPref("WhisperVolumeColor")
end

function WRC.Meta.SetWhisperVolumeColor(color)
    writeChatPref("WhisperVolumeColor", color)
end

function WRC.Meta.GetLowVolumeColor()
    return getChatPref("LowVolumeColor")
end

function WRC.Meta.SetLowVolumeColor(color)
    writeChatPref("LowVolumeColor", color)
end

function WRC.Meta.GetSayVolumeColor()
    return getChatPref("SayVolumeColor")
end

function WRC.Meta.SetSayVolumeColor(color)
    writeChatPref("SayVolumeColor", color)
end

function WRC.Meta.GetLoudVolumeColor()
    return getChatPref("LoudVolumeColor")
end

function WRC.Meta.SetLoudVolumeColor(color)
    writeChatPref("LoudVolumeColor", color)
end

function WRC.Meta.GetShoutVolumeColor()
    return getChatPref("ShoutVolumeColor")
end

function WRC.Meta.SetShoutVolumeColor(color)
    writeChatPref("ShoutVolumeColor", color)
end

function WRC.Meta.EnableSaveLastChat()
    writeChatPref("SaveLastChat", true)
end

function WRC.Meta.DisableSaveLastChat()
    writeChatPref("SaveLastChat", false)
end

function WRC.Meta.IsSaveLastChatEnabled()
    return getChatPref("SaveLastChat")
end

function WRC.Meta.IsKeepSafeEnabled()
    return getChatPref("KeepSafe")
end

function WRC.Meta.SetKeepSafeEnabled(enabled)
    writeChatPref("KeepSafe", enabled)
end

WRC.Meta.FocusedPersons = WRC.Meta.FocusedPersons or {}

function WRC.Meta.FocusOn(username)
    if not WRC.Meta.FocusedPersons then
        WRC.Meta.FocusedPersons = {}
    end

    if WRC.Meta.IsFocusedOn(username) then return end

    table.insert(WRC.Meta.FocusedPersons, username)
end

function WRC.Meta.UnfocusOn(username)
    if not WRC.Meta.FocusedPersons then
        WRC.Meta.FocusedPersons = {}
    end
    local newFocused = {}
    for i=1, #WRC.Meta.FocusedPersons do
        if WRC.Meta.FocusedPersons[i] ~= username then
            table.insert(newFocused, WRC.Meta.FocusedPersons[i])
        end
    end
    WRC.Meta.FocusedPersons = newFocused
end

function WRC.Meta.HasFocus()
    if not WRC.Meta.FocusedPersons then
        WRC.Meta.FocusedPersons = {}
    end
    return #WRC.Meta.FocusedPersons > 0
end

function WRC.Meta.IsFocusedOn(username)
    if not WRC.Meta.FocusedPersons then
        WRC.Meta.FocusedPersons = {}
    end
    for i=1, #WRC.Meta.FocusedPersons do
        if WRC.Meta.FocusedPersons[i] == username then
            return true
        end
    end
    return false
end

function WRC.Meta.InvitePrivate(username)
    if not username then return false end
    local target = getPlayerFromUsername(username)
    if not target or target == getPlayer() then return false end
    if getPlayer():getDistanceSq(target) > 100 then return false end -- 10 tiles
    if WRC.Meta.PrivateWith then return false end
    sendClientCommand(getPlayer(), "WRC", "InvitePrivate", {username})
    WL_Utils.addInfoToChat("You have invited " .. WRC.Meta.GetName(username) .. " to a private chat.")
    return true
end

function WRC.Meta.OnPrivateInvite(otherUser)
    local w = 300
    local h = 200
    local x = getCore():getScreenWidth() / 2 - w / 2
    local y = getCore():getScreenHeight() / 2 - h / 2
    local othersName = WRC.Meta.GetName(otherUser)
    local dialog = ISModalDialog:new(x, y, w, h, "Start private chat with " .. othersName .. "?", true, otherUser, WRC.Meta.OnPrivateInviteResponse)
    dialog:initialise()
    dialog:addToUIManager()
end

function WRC.Meta.OnPrivateInviteResponse(otherUser, button)
    if button.internal == "YES" then
        WRC.Meta.StartPrivate(otherUser)
        ISChat.instance.panel:activateView("Private")
        WL_Utils.addInfoToChat("Private chat started with " .. WRC.Meta.GetName(otherUser) .. ".")
        sendClientCommand(getPlayer(), "WRC", "AcceptPrivateInvite", {otherUser})
    else
        sendClientCommand(getPlayer(), "WRC", "DeclinePrivateInvite", {otherUser})
    end
end

function WRC.Meta.StartPrivate(username)
    WRC.Meta.PrivatePartner = username
    WRC.Meta.ShowPrivateChat = true
end

function WRC.Meta.StopPrivate(skipSend)
    if not skipSend and WRC.Meta.PrivatePartner then
        sendClientCommand(getPlayer(), "WRC", "StopPrivate", {WRC.Meta.PrivatePartner})
    end
    WRC.Meta.PrivatePartner = nil
end

function WRC.Meta.ClosePrivate()
    ISChat.instance.panel:activateView("Private")
    ISChat.instance:onContextClear()
    WRC.Meta.ShowPrivateChat = false
    ISChat.instance.panel:activateView("General")
end

function WRC.Meta.HasPrivate(simple)
    if simple and WRC.Meta.ShowPrivateChat then return true end
    if not WRC.Meta.PrivatePartner then return false end
    local others = WRC.GetAllPlayersInRange(10, 0)
    if #others ~= 1 or others[1]:getUsername() ~= WRC.Meta.PrivatePartner then return false end
    return true
end

function WRC.Meta.EnableAdminHammer()
    if not WL_Utils.canModerate(getPlayer()) then return end
    changeModifer("adminHammer", true)
end

function WRC.Meta.DisableAdminHammer()
    changeModifer("adminHammer", false)
end

function WRC.Meta.HasAdminHammer(username)
    return getModifier(username, "adminHammer")
end

function WRC.Meta.EnableNpcTag()
    if not WL_Utils.canModerate(getPlayer()) then return end
    changeModifer("npcTag", true)
end

function WRC.Meta.DisableNpcTag()
    changeModifer("npcTag", false)
end

function WRC.Meta.HasNpcTag(username)
    return getModifier(username, "npcTag")
end

function WRC.Meta.EnableAfk()
    changeModifer("afk", true)
end

function WRC.Meta.DisableAfk()
    changeModifer("afk", false)
end

function WRC.Meta.IsAfk(username)
    return getModifier(username, "afk")
end

function WRC.Meta.EnableHairGrowth()
    changeModifer("hairGrowth", true)
end

function WRC.Meta.DisableHairGrowth()
    changeModifer("hairGrowth", false)
end

function WRC.Meta.IsHairGrowthEnabled(username)
    return getModifier(username, "hairGrowth")
end

function WRC.Meta.GetUnreadTabOptions()
    local textColor = getChatPref("UnreadTabTextColor")
    local backgroundColor = getChatPref("UnreadTabBackgroundColor")
    local blinking = getChatPref("UnreadTabBlinking")
    return textColor, backgroundColor, blinking
end

function WRC.Meta.SetUnreadTabTextColor(color)
    if not color or color == "" then
        writeChatPref("UnreadTabTextColor", nil)
        WL_Utils.addInfoToChat("Unread tab text color reset to default.")
        return
    end
    local colorVals = WRC.GetColor(color)
    if not colorVals then return end
    writeChatPref("UnreadTabTextColor", colorVals)
    WL_Utils.addInfoToChat("<RGB:" .. colorVals.r .. "," .. colorVals.g .. "," .. colorVals.b .. ">Unread tab text color updated.")
end

function WRC.Meta.SetUnreadTabBackgroundColor(color)
    if not color or color == "" then
        writeChatPref("UnreadTabBackgroundColor", nil)
        WL_Utils.addInfoToChat("Unread tab background color reset to default.")
        return
    end
    local colorVals = WRC.GetColor(color)
    if not colorVals then return end
    writeChatPref("UnreadTabBackgroundColor", colorVals)
    WL_Utils.addInfoToChat("<RGB:" .. colorVals.r .. "," .. colorVals.g .. "," .. colorVals.b .. ">Unread tab background color updated.")
end

function WRC.Meta.SetUnreadTabBlinking(blinking)
    writeChatPref("UnreadTabBlinking", blinking)
end

function WRC.Meta.GetOverheadTypingIndicator()
    return getChatPref("OverheadTypingIndicator")
end

function WRC.Meta.SetOverheadTypingIndicator(enabled)
    writeChatPref("OverheadTypingIndicator", enabled)
end

local radioSyncOption = nil
function WRC.Meta.GetRadioSync()
    return radioSyncOption
end

function WRC.Meta.SetRadioSync(channel)
    radioSyncOption = channel
end

function WRC.Meta.GetRadioJammer()
    return getGlobalState("radioJammer")
end

function WRC.Meta.SetRadioJammer(enabled)
    setGlobalState("radioJammer", enabled)
end

function WRC.Meta.ReceivedEvent()
    WRC.Meta.LastEvent = getTimestamp()
end

function WRC.Meta.HasEvent()
    if WRC.Override(true) then return true end
    if not WRC.Meta.LastEvent then return false end
    local diff = getTimestamp() - WRC.Meta.LastEvent
    if diff < 3600 then -- 1 hour
        return true
    end
    return false
end

WRC.Meta.RegisteredActions = {}

function WRC.Meta.RegisterAction(actionName, actionFunc)
    table.insert(WRC.Meta.RegisteredActions, {
        name = actionName,
        func = actionFunc
    })
end

function WRC.Meta.CreateActionsContext(context, myPlayer, players)
    local actionsOption = context:addOptionOnTop("Actions", nil, nil)
    local actionsContext = context:getNew(context)
    context:addSubMenu(actionsOption, actionsContext)

    actionsContext:addOption("Go AFK", nil, WRC.Commands.GoAFK)
    local keepSafeEnabled = WRC.Meta.IsKeepSafeEnabled()
    actionsContext:addOption((keepSafeEnabled and "Disable" or "Enable") .. " Keep Safe", keepSafeEnabled and "off" or "on", WRC.Commands.KeepSafe)

    local languageOption = actionsContext:addOption("Choose Language", nil, nil)
    local languageContext = actionsContext:getNew(actionsContext)
    actionsContext:addSubMenu(languageOption, languageContext)

    for _, language in ipairs(WRC.Meta.GetKnownLanguages()) do
        languageContext:addOption(WRC.Languages[language].name .. " (" .. language .. ")", language, WRC.Commands.SetLang)
    end

    local donoOption = actionsContext:addOption("Dono Options", nil, nil)
    local donoContext = actionsContext:getNew(actionsContext)
    actionsContext:addSubMenu(donoOption, donoContext)

    local availableRewards = WLADC_System and WLADC_System:getAvailableRewards(myPlayer) or nil
    local donoStatus = SandboxVars.WastelandAutoDC and SandboxVars.WastelandAutoDC.Enabled or false
    if not donoStatus then
        WL_ContextMenuUtils.missingRequirement(donoContext, "Dono System", "The dono system is currently offline.", nil, "Item_Pillow")
    end
    if donoStatus and availableRewards then
        local loreItems = availableRewards.loreItems
        local animals = availableRewards.animals
        local carKit = availableRewards.carKit

        if WLADC_System:getCanVisit(myPlayer) then
            if SandboxVars.WastelandAutoDC and SandboxVars.WastelandAutoDC.Trips then
                local option = donoContext:addOption("Visit DC", nil, WLAutoDC.showGoToPopup)
                WL_ContextMenuUtils.addToolTip(option, "Visit DC", "You are able to visit the DC. Clicking this will open a new window to facilitate the trip.")
            else
                WL_ContextMenuUtils.missingRequirement(donoContext, "Visit DC", "The dono system is currently not allowing trips to the DC.")
            end
        elseif WLADC_System:getIsAtDc(myPlayer) == true then
            local option = donoContext:addOption("Leave DC", nil, WLAutoDC.showReturnPopup)
            WL_ContextMenuUtils.addToolTip(option, "Leave DC", "You are at the DC. Clicking this will open a new window to facilitate the return.")
        else
            WL_ContextMenuUtils.missingRequirement(donoContext, "Visit DC", "You cannot visit the DC.")
        end

        local dono = WLADC_System:getUserStatus(myPlayer).donoLevel
        local donoStatus = dono and dono ~= "Player"

        if loreItems and loreItems > 0 and donoStatus then
            local loreOption = donoContext:addOption("Claim Lore Item", nil, nil)
            WL_ContextMenuUtils.addToolTip(loreOption, "Claim Lore Item", "Please submit a Dono Ticket to claim your Lore Item(s).")
        else
            WL_ContextMenuUtils.missingRequirement(donoContext, "Claim Lore Item", "You have no remaining lore items to claim.")
        end

        if WLADC_System:getIsAtDc(myPlayer) == true then
            WL_ContextMenuUtils.missingRequirement(donoContext, "Claim Animal", "You cannot claim your animals while you're at the DC.")
            WL_ContextMenuUtils.missingRequirement(donoContext, "Claim Car Kit", "You cannot claim your car kit while you're at the DC.")
        else
            if animals and animals > 0 and donoStatus then
                local animalOption = donoContext:addOption("Claim Animal", nil, WLAutoDC.claimAnimal)
                WL_ContextMenuUtils.addToolTip(animalOption, "Claim Animal", "Claim your Animal. You have " .. animals .. " remaining.")
            else
                WL_ContextMenuUtils.missingRequirement(donoContext, "Claim Animal", "You have no remaining animals to claim.")
            end

            if carKit and carKit > 0 and donoStatus then
                local carOption = donoContext:addOption("Claim Car Kit", nil, function()
                    local modal = ISModalDialog:new(0, 0, 200, 100, "Are you sure you want to claim your Car Kit?", true, nil,
                        function(_, button)
                            if button.internal == "YES" then
                                local player = getPlayer()
                                local inventory = player:getInventory()
                                inventory:AddItem("Base.RecolorKit")
                                WL_Utils.addInfoToChat("You have claimed your Car Kit.")
                                WL_Utils.addInfoToChat("You have " .. (carKit - 1) .. " Car Kit(s) remaining.")
                                WLADC_System:redeemReward(player, "carKit")
                            end
                        end
                    )
                    modal:initialise()
                    modal:addToUIManager()
                end)
                WL_ContextMenuUtils.addToolTip(carOption, "Claim Car Kit", "Claim your Car Kit. You have " .. carKit .. " remaining.")

            else
                WL_ContextMenuUtils.missingRequirement(donoContext, "Claim Car Kit", "You have no remaining car kits to claim.")
            end
        end
    end

    local focusablePlayers = {}
    local unfocusablePlayers = {}
    local tradablePlayers = {}
    for i=0,players:size()-1 do
        local player = players:get(i)
        local username = player:getUsername()
        if WRC.Meta.IsFocusedOn(username) then
            table.insert(unfocusablePlayers, username)
        else
            if not player:isGhostMode() and WRC.CanSeePlayer(player) then
                table.insert(focusablePlayers, username)
            end
        end
        if not player:isGhostMode() and WRC.CanSeePlayer(player) then
            table.insert(tradablePlayers, player)
        end
    end
    table.sort(focusablePlayers)
    table.sort(unfocusablePlayers)
    table.sort(tradablePlayers, function (a,b) return myPlayer:getDistanceSq(a) < myPlayer:getDistanceSq(b) end)
    local focusOption = actionsContext:addOption("Focus On", nil, nil)
    if #focusablePlayers > 0 then
        table.sort(focusablePlayers)
        local focusContext = actionsContext:getNew(actionsContext)
        actionsContext:addSubMenu(focusOption, focusContext)
        for _, username in ipairs(focusablePlayers) do
            focusContext:addOption(WRC.Meta.GetName(username), '"' .. username .. '"', WRC.Commands.Focus)
        end
        focusOption.notAvailable = false
    else
        focusOption.notAvailable = true
    end

    local unfocusOption = actionsContext:addOption("Unfocus From", nil, nil)
    if #unfocusablePlayers > 0 then
        table.sort(unfocusablePlayers)
        local unfocusContext = actionsContext:getNew(actionsContext)
        actionsContext:addSubMenu(unfocusOption, unfocusContext)
        for _, username in ipairs(unfocusablePlayers) do
            unfocusContext:addOption(WRC.Meta.GetName(username), '"' .. username .. '"', WRC.Commands.Unfocus)
        end
        unfocusOption.notAvailable = false
    else
        unfocusOption.notAvailable = true
    end

    local tradingOption = actionsContext:addOption("Trade With", nil, nil)
    if #tradablePlayers > 0 then
        local tradingContext = context:getNew(context)
        context:addSubMenu(tradingOption, tradingContext)
        for _, player in ipairs(tradablePlayers) do
            local username = player:getUsername()
            tradingContext:addOption(WRC.Meta.GetName(username), '"' .. username .. '"', WRC.Commands.Trade)
        end
        tradingOption.notAvailable = false
    else
        tradingOption.notAvailable = true
    end

    if WRC.Meta.HasPrivate(true) then
        actionsContext:addOption("Close Private Chat", nil, WRC.Commands.StopPrivateChat)
    else
        local privateablePlayers = WRC.GetAllPlayersInRange(5, 0)
        if #privateablePlayers == 1 then
            local name = WRC.Meta.GetName(privateablePlayers[1]:getUsername())
            actionsContext:addOption("Invite Private: " .. name, privateablePlayers[1]:getUsername(), WRC.Meta.InvitePrivate)
        end
    end

    for _, action in ipairs(WRC.Meta.RegisteredActions) do
        actionsContext:addOption(action.name, nil, action.func)
    end

    if getActivatedMods():contains("WastelandObjectives") then
        local objectiveTrackerOption = actionsContext:addOption("Toggle Objective Tracker", nil, function() 
            if not WO_ObjectiveTracker.instance then
                WO_ObjectiveTracker.display() 
            else
                WO_ObjectiveTracker.instance:close()
            end
        end)
    end

    actionsContext:addOption("Show Help", nil, WRC.Commands.Help)
    actionsContext:addOption("List RP Chat Commands", nil, WRC.Commands.ListAllCommands)
end

function WRC.Meta.CreateCharacterContext(context, myPlayer)
    local characterOption = context:insertOptionAfter("Actions", "Character", nil, nil)
    local characterContext = context:getNew(context)
    context:addSubMenu(characterOption, characterContext)

    characterContext:addOption("Set Name", nil, WRC.MakeShowDialogPrompt("Input your new name", WRC.Commands.SetName))
    characterContext:addOption("Set Name Color", nil, WRC.MakeColorDialogPrompt("New Name Color (blank for default)", WRC.Commands.SetColor))

    characterContext:addOption("Edit Status", nil, function()
        local currentStatus = WRC.Meta.GetStatus(getPlayer():getUsername()) or ""
        WRC.MakeShowDialogPrompt("Input your new status", WRC.Commands.SetStatus, currentStatus)()
    end)

    characterContext:addOption("Grow Hair", nil, WRC.Commands.GrowHair)
    characterContext:addOption("Set Hair Color", nil, WRC.MakeColorDialogPrompt("Set Hair Color", WRC.Commands.SetHairColor))
    if not myPlayer:isFemale() then
        characterContext:addOption("Grow Beard", nil, WRC.Commands.GrowBeard)
        characterContext:addOption("Set Beard Color", nil, WRC.MakeColorDialogPrompt("Set Beard Color", WRC.Commands.SetBeardColor))
    end

    if WRC.Meta.IsHairGrowthEnabled(getPlayer():getUsername()) then
        characterContext:addOption("Disable Hair Growth", "off", WRC.Commands.HairGrowth)
    else
        characterContext:addOption("Enable Hair Growth", "on", WRC.Commands.HairGrowth)
    end

    if WRC.Buffs.IsAutoCleanEnabled() then
        characterContext:addOption("Disable Autoclean", false, WRC.Buffs.SetAutoCleanEnabled)
    else
        characterContext:addOption("Enable Autoclean", true, WRC.Buffs.SetAutoCleanEnabled)
    end
    characterContext:addOption("Clean Now", nil, WRC.Buffs.DoClean)

    local addDirtOption = characterContext:addOption("Add Dirt", nil, nil)
    local addDirtContext = characterContext:getNew(characterContext)
    characterContext:addSubMenu(addDirtOption, addDirtContext)
    addDirtContext:addOption("To All", nil, WRC.Buffs.DoAddDirt)
    for _, bodyPartStr in ipairs(WRC.GetBodyParts()) do
        local bodyPart = BodyPartType.FromString(bodyPartStr)
        addDirtContext:addOption(BodyPartType.getDisplayName(bodyPart), bodyPartStr, WRC.Buffs.DoAddDirt)
    end

    local addBloodOption = characterContext:addOption("Add Blood", nil, nil)
    local addBloodContext = characterContext:getNew(characterContext)
    characterContext:addSubMenu(addBloodOption, addBloodContext)
    addBloodContext:addOption("To All", nil, WRC.Buffs.DoAddBlood)
    for _, bodyPartStr in ipairs(WRC.GetBodyParts()) do
        local bodyPart = BodyPartType.FromString(bodyPartStr)
        addBloodContext:addOption(BodyPartType.getDisplayName(bodyPart), bodyPartStr, WRC.Buffs.DoAddBlood)
    end

    local injureSelfOption = characterContext:addOption("Add Injury", nil, nil)
    local injureSelfContext = characterContext:getNew(characterContext)
    characterContext:addSubMenu(injureSelfOption, injureSelfContext)

    for _, bodyPartStr in ipairs(WRC.GetBodyParts()) do
        local bodyPart = BodyPartType.FromString(bodyPartStr)
        local bodyPartOption = injureSelfContext:addOption(BodyPartType.getDisplayName(bodyPart), nil, nil)
        local bodyPartContext = injureSelfContext:getNew(injureSelfContext)
        injureSelfContext:addSubMenu(bodyPartOption, bodyPartContext)

        for _, injury in ipairs(WRC.GetInjuries()) do
            bodyPartContext:addOption(injury, '"' .. bodyPartStr .. '" "' .. injury .. '"', WRC.Commands.Injure)
        end
    end

    if WRC.Meta.GetInjured(getPlayer():getUsername()) then
        characterContext:addOption("Disable Injured Tag", "off", WRC.Commands.InjuredAbove)
    else
        characterContext:addOption("Enable Injured Tag", "on", WRC.Commands.InjuredAbove)
    end

    local limpOption = characterContext:addOption("Toggle Limp", nil, nil)
    local limpMenu = characterContext:getNew(characterContext)
    characterContext:addSubMenu(limpOption, limpMenu)
    if WRC.Meta.getLimpLeft(getPlayer():getUsername()) then
        limpMenu:addOption("Disable Limp Left", "off", WRC.Commands.LimpLeft)
    else
        if getPlayer():isGodMod() then
            WL_ContextMenuUtils.missingRequirement(limpMenu, "Enable Limp Left", "You must disable God Mode first.")
        else
            if WRC.Meta.getLimpRight(getPlayer():getUsername()) then
                WL_ContextMenuUtils.missingRequirement(limpMenu, "Enable Limp Left", "You must disable Limp Right first.")
            else
                limpMenu:addOption("Enable Limp Left", "on", WRC.Commands.LimpLeft)
            end
        end
    end
    if WRC.Meta.getLimpRight(getPlayer():getUsername()) then
        limpMenu:addOption("Disable Limp Right", "off", WRC.Commands.LimpRight)
    else
        if getPlayer():isGodMod() then
            WL_ContextMenuUtils.missingRequirement(limpMenu, "Enable Limp Right", "You must disable God Mode first.")
        else
            if WRC.Meta.getLimpLeft(getPlayer():getUsername()) then
                WL_ContextMenuUtils.missingRequirement(limpMenu, "Enable Limp Right", "You must disable Limp Left first.")
            else
                limpMenu:addOption("Enable Limp Right", "on", WRC.Commands.LimpRight)
            end
        end
    end

    local respawnOption = characterContext:addOption("Respawn", nil, WRC.Commands.Respawn)
    if myPlayer:isDead() then
        respawnOption.notAvailable = true
    end
    local tt = ISToolTip:new()
    tt:initialise()
    tt:setName("Respawn")
    tt.description = "Will kill your character, deleting your body and all items."
    respawnOption.toolTip = tt
end

function WRC.Meta.CreateChatSettingsContext(context)
    local chatSettingsOption = context:insertOptionAfter("Character", "RP Chat Settings", nil, nil)
    local chatSettingsContext = context:getNew(context)
    context:addSubMenu(chatSettingsOption, chatSettingsContext)

    local saveLast = WRC.Meta.IsSaveLastChatEnabled()
    chatSettingsContext:addOption((saveLast and "Disable" or "Enable") .. " Keep Last", not saveLast and "on" or "off", WRC.Commands.KeepLast)

    local chatColorsOption = chatSettingsContext:addOption("Chat Colors", nil, nil)
    local chatColorsContext = chatSettingsContext:getNew(chatSettingsContext)
    chatSettingsContext:addSubMenu(chatColorsOption, chatColorsContext)

    chatColorsContext:addOption("Set Speech Color", nil, WRC.MakeColorDialogPrompt("New Speech Color (blank for default)", WRC.Commands.SetSayColor))
    chatColorsContext:addOption("Set Emote Color", nil, WRC.MakeColorDialogPrompt("New Emote Color (blank for default)", WRC.Commands.SetEmoteColor))
    chatColorsContext:addOption("Set Do Color", nil, WRC.MakeColorDialogPrompt("New Do Color (blank for default)", WRC.Commands.SetDoColor))
    chatColorsContext:addOption("Set OOC Color", nil, WRC.MakeColorDialogPrompt("New OOC Color (blank for default)", WRC.Commands.SetOocColor))

    local volumeColorsOption = chatColorsContext:addOption("Volume Prefix Colors", nil, nil)
    local volumeColorsContext = chatColorsContext:getNew(chatColorsContext)
    chatSettingsContext:addSubMenu(volumeColorsOption, volumeColorsContext)

    volumeColorsContext:addOption("Set Whisper Color", nil, WRC.MakeColorDialogPrompt("New Whisper Volume Color (blank for default)", WRC.Commands.SetWhisperVolumeColor))
    volumeColorsContext:addOption("Set Low Color", nil, WRC.MakeColorDialogPrompt("New Low Volume Color (blank for default)", WRC.Commands.SetLowVolumeColor))
    volumeColorsContext:addOption("Set Say Color", nil, WRC.MakeColorDialogPrompt("New Say Volume Color (blank for default)", WRC.Commands.SetSayVolumeColor))
    volumeColorsContext:addOption("Set Loud Color", nil, WRC.MakeColorDialogPrompt("New Loud Volume Color (blank for default)", WRC.Commands.SetLoudVolumeColor))
    volumeColorsContext:addOption("Set Shout Color", nil, WRC.MakeColorDialogPrompt("New Shout Volume Color (blank for default)", WRC.Commands.SetShoutVolumeColor))

    local unreadTabOption = chatSettingsContext:addOption("Unread Tab Options", nil, nil)
    local unreadTabContext = chatSettingsContext:getNew(chatSettingsContext)
    chatSettingsContext:addSubMenu(unreadTabOption, unreadTabContext)

    local _, _, blinking = WRC.Meta.GetUnreadTabOptions()
    unreadTabContext:addOption("Set Title Color", nil, WRC.MakeColorDialogPrompt("New Title Color (blank for default)", WRC.Meta.SetUnreadTabTextColor))
    unreadTabContext:addOption("Set Background Color", nil, WRC.MakeColorDialogPrompt("New Background Color (blank for default)", WRC.Meta.SetUnreadTabBackgroundColor))
    unreadTabContext:addOption((blinking and "Disable" or "Enable") .. " Blinking", not blinking, WRC.Meta.SetUnreadTabBlinking)

    local overheadTypingIndicator = WRC.Meta.GetOverheadTypingIndicator()
    chatSettingsContext:addOption((overheadTypingIndicator and "Disable" or "Enable") .. " Overhead Typing Indicator", not overheadTypingIndicator, WRC.Meta.SetOverheadTypingIndicator)

    if WRC.Meta.GetInvertedStatus(getPlayer():getUsername()) then
        chatSettingsContext:addOption("Disable Inverted Status", "off", WRC.Commands.InvertStatus)
    else
        chatSettingsContext:addOption("Enable Inverted Status", "on", WRC.Commands.InvertStatus)
    end
end

function WRC.Meta.CreateAdminContext(context, myPlayer, players)
    local adminOption = context:insertOptionAfter("RP Chat Settings", "RP Chat Admin", nil, nil)
    local adminContext = context:getNew(context)
    context:addSubMenu(adminOption, adminContext)

    if WRC.Meta.HasAdminHammer(myPlayer:getUsername()) then
        adminContext:addOption("Disable Admin Hammer", "off", WRC.Commands.Hammer)
    else
        adminContext:addOption("Enable Admin Hammer", "on", WRC.Commands.Hammer)
    end

    if WRC.Meta.HasNpcTag(myPlayer:getUsername()) then
        adminContext:addOption("Disable NPC Tag", "off", WRC.Commands.NpcTag)
    else
        adminContext:addOption("Enable NPC Tag", "on", WRC.Commands.NpcTag)
    end

    if WRC.Meta.DisableOverride then
        adminContext:addOption("Enable Admin Chat Override", "on", WRC.Commands.Override)
    else
        adminContext:addOption("Disable Admin Chat Override", "off", WRC.Commands.Override)
    end

    if WRC.Meta.GetRadioJammer() then
        adminContext:addOption("Disable Radio Jammer", "off", WRC.Commands.RadioJammer)
    else
        adminContext:addOption("Enable Radio Jammer", "on", WRC.Commands.RadioJammer)
    end

    local usernames = {}
    for i=0,players:size()-1 do
        local username = players:get(i):getUsername()
        table.insert(usernames, {WRC.Meta.GetName(username) .. " (" .. username .. ")", username})
    end
    local languages = {}
    for code, language in pairs(WRC.Languages) do
        table.insert(languages, {language.name .. " (" .. code .. ")", code})
    end
    table.sort(usernames, function (a,b) return a[1] < b[1] end)
    table.sort(languages, function (a,b) return a[1] < b[1] end)

    -- add lang to player
    local addLangOption = adminContext:addOption("Add Language", nil, nil)
    local addLangContext = adminContext:getNew(adminContext)
    adminContext:addSubMenu(addLangOption, addLangContext)
    for _,p in ipairs(usernames) do
        local userDisplayName = p[1]
        local username = p[2]
        local playerOption = addLangContext:addOption(userDisplayName, nil, nil)
        local playerContext = addLangContext:getNew(addLangContext)
        addLangContext:addSubMenu(playerOption, playerContext)
        for _, l in ipairs(languages) do
            local languageDisplayName = l[1]
            local code = l[2]
            playerContext:addOption(languageDisplayName, '"' .. username .. '" ' .. code, WRC.Commands.AddLang)
        end
    end
    local removeLangOption = adminContext:addOption("Remove Language", nil, nil)
    local removeLangContext = adminContext:getNew(adminContext)
    adminContext:addSubMenu(removeLangOption, removeLangContext)
    for _,p in ipairs(usernames) do
        local userDisplayName = p[1]
        local username = p[2]
        local playerOption = removeLangContext:addOption(userDisplayName, nil, nil)
        local playerContext = removeLangContext:getNew(removeLangContext)
        removeLangContext:addSubMenu(playerOption, playerContext)
        for _, l in ipairs(languages) do
            local languageDisplayName = l[1]
            local code = l[2]
            playerContext:addOption(languageDisplayName, '"' .. username .. '" ' .. code, WRC.Commands.RemoveLang)
        end
    end
end

Events.OnLoad.Add(function()
    readChatPrefs()
end)
