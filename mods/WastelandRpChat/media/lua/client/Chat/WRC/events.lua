if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC.Events = WRC.Events or {}
WRC.Events.IsFirstSync = true

function WRC.Events.OnReceiveGlobalModData(key, modData)
    if key == "WRC_PlayerColors" then
        WRC.PlayerColors = modData
    elseif key == "WRC_PlayerLanguages" then
        WRC.PlayerLanguages = modData
    elseif key == "WRC_PlayerModifiers" then
        WRC.PlayerModifiers = modData
        WRC.Afk.CheckLocalPlayersForAfk()
        if WRC.Events.IsFirstSync then
            WRC.Events.IsFirstSync = false
            if WRC.Afk.IsSelfAfk() then
                WRC.Afk.StartAfk()
            end
        end
    elseif key == "WRC_PlayerNames" then
        WRC.PlayerNames = modData
        if not WRC.PlayerNames[getPlayer():getUsername()] then
            WRC.Meta.SetName(getPlayer():getDescriptor():getForename())
        end
    elseif key == "WRC_PlayerStatus" then
        WRC.PlayerStatus = modData
    elseif key == "WRC_InvertStatus" then
        WRC.InvertStatus = modData
    elseif key == "WRC_InjuredAbove" then
        WRC.InjuredAbove = modData
    elseif key == "WRC_StreamingAbove" then
        WRC.StreamingAbove = modData
    elseif key == "WRC_LimpLeft" then
        WRC.LimpLeft = modData
    elseif key == "WRC_LimpRight" then
        WRC.LimpRight = modData
    elseif key == "WRC_GlobalState" then
        WRC.GlobalState = modData
    end
end

function WRC.Events.OnConnected()
	ModData.request("WRC_PlayerColors")
	ModData.request("WRC_PlayerLanguages")
    ModData.request("WRC_PlayerModifiers")
    ModData.request("WRC_PlayerNames")
    ModData.request("WRC_PlayerStatus")
    ModData.request("WRC_InvertStatus")
    ModData.request("WRC_InjuredAbove")
    ModData.request("WRC_StreamingAbove")
    ModData.request("WRC_LimpLeft")
    ModData.request("WRC_LimpRight")
    ModData.request("WRC_GlobalState")
end

function WRC.Events.onServerCommand(module, command, args)
    if module ~= "WRC" then return end

    if command == "onTyping" then
        WRC.Indicator.players[args[1]] = getTimestampMs()
    elseif command == "onCleared" then
        WRC.Indicator.players[args[1]] = nil
    elseif command == "AddKnownLanguage" then
        local languageData = WRC.Languages[args[1]]
        if languageData then
            WRC.Meta.AddKnownLanguage(args[1])
            WL_Utils.addInfoToChat("You have learned " .. languageData.name)
        end
    elseif command == "RemoveKnownLanguage" then
        local languageData = WRC.Languages[args[1]]
        if languageData then
            WRC.Meta.RemoveKnownLanguage(args[1])
            WL_Utils.addInfoToChat("You have forgotten " .. languageData.name)
        end
    elseif command == "InvitePrivate" then
        local otherPlayer = args[1]
        if WRC.Meta.HasPrivate(true) then
            sendClientCommand(getPlayer(), "WRC", "PrivateUnavailable", {otherPlayer})
        else
            WRC.Meta.OnPrivateInvite(otherPlayer)
        end
    elseif command == "PrivateUnavailable" then
        local otherPlayer = args[1]
        WL_Utils.addErrorToChat(otherPlayer .. " is unable to private chat.")
    elseif command == "AcceptPrivateInvite" then
        local otherPlayer = args[1]
        WRC.Meta.StartPrivate(otherPlayer)
        ISChat.instance.panel:activateView("Private")
        WL_Utils.addInfoToChat("Private chat started with " .. WRC.Meta.GetName(otherPlayer) .. ".")
    elseif command == "DeclinePrivateInvite" then
        local otherPlayer = args[1]
        WL_Utils.addInfoToChat(otherPlayer .. " declined your private chat invite.")
    elseif command == "PrivateChat" then
        local otherPlayerUsername = args[1]
        local message = args[2]
        WRC.Handlers.AddPrivateMessage(otherPlayerUsername, message)
    elseif command == "StopPrivate" then
        ISChat.instance.panel:activateView("Private")
        local name = WRC.Meta.PrivatePartner and WRC.Meta.GetName(WRC.Meta.PrivatePartner) or "Unknown"
        WL_Utils.addInfoToChat("Private with " .. name .. " ended.")
        WRC.Meta.StopPrivate(true)
    elseif command == "StaffChat" then
        local sourceUsername = args[1]
        local message = args[2]
        WRC.Handlers.AddStaffMessage(sourceUsername, message)
    end

end

function WRC.Events.resetGrowth()
    local player = getPlayer()
    if WRC.Meta.IsHairGrowthEnabled(player:getUsername()) then
        return
    else
        player:resetHairGrowingTime()
        if not player:isFemale() then
            player:resetBeardGrowingTime()
        end
    end
end

function WRC.Events.OnTick()
    WRC.Indicator.update()
    WRC.Afk.OnTick()
end

Events.OnReceiveGlobalModData.Add(WRC.Events.OnReceiveGlobalModData)
Events.OnConnected.Add(WRC.Events.OnConnected)
Events.OnServerCommand.Add(WRC.Events.onServerCommand)
Events.OnTick.Add(WRC.Events.OnTick)
Events.EveryTenMinutes.Add(WRC.Buffs.DoAutoClean)
Events.EveryHours.Add(WRC.Events.resetGrowth)
