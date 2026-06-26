if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC.Afk = WRC.Afk or {}

WRC.Afk.ALERT_AFK_DIST_SQ = 20*20 -- 20 squares
WRC.Afk.ALERT_BACK_DIST_SQ = 50*50 -- 50 squares
WRC.Afk.FORGET_AFK_DIST_SQ = 100*100 -- 100 squares
WRC.Afk.CHECK_LOCAL_PLAYERS_EVERY_TICKS = 300
WRC.Afk.UsersAlertedAbout = {}
WRC.Afk.LocalPlayersTickCounter = 0

function WRC.Afk.IsSelfAfk()
    return WRC.Meta.IsAfk(getPlayer():getUsername())
end

function WRC.Afk.StartAfk()
    WRC.Meta.EnableAfk()
    WRC.KeepSafe.OnAfkStarted()
    Events.OnPlayerMove.Add(WRC.Afk.OnMove)
    WL_Utils.addInfoToChat("You are now AFK, walk to cancel")
end

function WRC.Afk.StopAfk()
    WRC.Meta.DisableAfk()
    WRC.KeepSafe.OnAfkStopped()
    Events.OnPlayerMove.Remove(WRC.Afk.OnMove)
    WL_Utils.addInfoToChat("You are no longer AFK")
end

function WRC.Afk.OnMove(player)
    if WRC.Afk.IsSelfAfk() and player == getPlayer() and not WRC.KeepSafe.ActiveAction then
        WRC.Afk.StopAfk()
    end
end

WRC.Afk.IndicatorWidth = getTextManager():MeasureStringX(UIFont.Small, "AFK")
WRC.Afk.IndicatorHeight = getTextManager():MeasureStringY(UIFont.Small, "AFK")
WRC.Afk.OverheadUiElements = WRC.Afk.OverheadUiElements or {}
function WRC.Afk.ShowAfkOnPlayers()
    local zoom = getCore():getZoom(0)
     for _,x in pairs(WRC.Afk.OverheadUiElements) do x.seen = false end
     local allPlayers = getOnlinePlayers()
     if not allPlayers then return end
     local me = getPlayer()
     for i=0,allPlayers:size()-1 do
         local player = allPlayers:get(i)
         local username = player:getUsername()
         -- we double check the distance because admins can see players everyone on the map
         if WRC.Meta.IsAfk(username) and WRC.CanSeePlayer(player, true, 20) and me:getDistanceSq(player) < 2500 then
             local x = isoToScreenX(0, player:getX(), player:getY(), player:getZ())
             local y = isoToScreenY(0, player:getX(), player:getY(), player:getZ())
             y = y - (130 / zoom) - (3*zoom)
             if WRC.Indicator.players[username] then y = y - WRC.Indicator.IndicatorHeight - 2 end
             local ele = WRC.Afk.OverheadUiElements[username]
             if ele then
                 ele:setX(x - (ele.width / 2))
                 ele:setY(y)
             else
                 ele = ISUIElement:new(x - (WRC.Afk.IndicatorWidth/2), y, WRC.Afk.IndicatorWidth, WRC.Afk.IndicatorHeight)
                 ele.anchorTop = false
                 ele.anchorBottom = true
                 ele:initialise()
                 ele:addToUIManager()
                 ele:backMost()
                 WRC.Afk.OverheadUiElements[username] = ele
             end
             ele.seen = true
             ele:drawTextCentre("AFK", WRC.Afk.IndicatorWidth/2, 0, 0.7, 0.7, 0.7, 1.0, UIFont.Small)
         end
     end
     for k,v in pairs(WRC.Afk.OverheadUiElements) do
         if not v.seen then
             v:removeFromUIManager()
             WRC.Afk.OverheadUiElements[k] = nil
         end
     end
end

function WRC.Afk.CheckLocalPlayersForAfk()
    local players = getOnlinePlayers()
    local me = getPlayer()
    if not me then return end
    local seen = {}
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if player ~= me and me:CanSee(player) then
            local username = player:getUsername()
            seen[username] = true
            local dist = player:getDistanceSq(getPlayer())
            if WRC.Meta.IsAfk(username) and not WRC.Afk.UsersAlertedAbout[username] and dist < WRC.Afk.ALERT_AFK_DIST_SQ then
                WRC.Afk.AlertPlayerHasGoneAfk(player)
                WRC.Afk.UsersAlertedAbout[username] = true
            elseif not WRC.Meta.IsAfk(username) and WRC.Afk.UsersAlertedAbout[username] and dist < WRC.Afk.ALERT_BACK_DIST_SQ  then
                WRC.Afk.AlertPlayerHasReturned(player)
                WRC.Afk.UsersAlertedAbout[username] = nil
            elseif WRC.Afk.UsersAlertedAbout[username] and dist > WRC.Afk.FORGET_AFK_DIST_SQ then
                WRC.Afk.UsersAlertedAbout[username] = nil
            end
        end
    end
    -- They are too far away, or offline, forget about them
    for username, _ in pairs(WRC.Afk.UsersAlertedAbout) do
        if not seen[username] then
            WRC.Afk.UsersAlertedAbout[username] = nil
        end
    end
end

function WRC.Afk.AlertPlayerHasGoneAfk(player)
    player:addLineChatElement("Is AFK", 1, 1, 1)
    local username = player:getUsername()
    local message = WRC.Meta.GetNameColor(username) .. WRC.Meta.GetName(username) .. " " .. WRC.ChatColors["info"] .. WL_Utils.MagicSpace .. "is AFK"
    WL_Utils.addInfoToChat(message)
end

function WRC.Afk.AlertPlayerHasReturned(player)
    player:addLineChatElement("Is no longer AFK", 1, 1, 1)
    local username = player:getUsername()
    local message = WRC.Meta.GetNameColor(username) .. WRC.Meta.GetName(username) .. " " .. WRC.ChatColors["info"] .. WL_Utils.MagicSpace .. "is no longer AFK"
    WL_Utils.addInfoToChat(message)
end

function WRC.Afk.OnTick()
    WRC.KeepSafe.Update()

    WRC.Afk.LocalPlayersTickCounter = WRC.Afk.LocalPlayersTickCounter + 1
    if WRC.Afk.LocalPlayersTickCounter >= WRC.Afk.CHECK_LOCAL_PLAYERS_EVERY_TICKS then
        WRC.Afk.LocalPlayersTickCounter = 0
        WRC.Afk.CheckLocalPlayersForAfk()
    end
end
