if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC.StatusIndicator = WRC.StatusIndicator or {}
WRC.PlayerStatus = WRC.PlayerStatus or {}
WRC.InjuredStatus = WRC.InjuredStatus or {}
WRC.StreamingStatus = WRC.StreamingStatus or {}

function WRC.StatusIndicator.GetDistanceSq(mouseWorldX, mouseWorldY, player)
    local playerWorldX = player:getX()
    local playerWorldY = player:getY()
    local dx = mouseWorldX - playerWorldX
    local dy = mouseWorldY - playerWorldY
    return dx*dx + dy*dy
end

local maxDistSq = 2.25 -- 1.5 tiles
local maxInjuredDistSq = 64.00 -- 8 tiles
WRC.StatusIndicator.OverheadUiElements = WRC.StatusIndicator.OverheadUiElements or {}
WRC.InjuredStatus.OverheadUiElements = WRC.InjuredStatus.OverheadUiElements or {}
WRC.StreamingStatus.OverheadUiElements = WRC.StreamingStatus.OverheadUiElements or {}

function WRC.StatusIndicator.ShowStatusIndicatorOnHovered()
    local zoom = getCore():getZoom(0)
    for _,x in pairs(WRC.StatusIndicator.OverheadUiElements) do x.seen = false end

    local allPlayers = getOnlinePlayers()
    if not allPlayers then return end

    local ownPlayer = getPlayer()
    local worldX = screenToIsoX(0, getMouseX(), getMouseY(), ownPlayer:getZ())
    local worldY = screenToIsoY(0, getMouseX(), getMouseY(), ownPlayer:getZ())
    local worldZ = ownPlayer:getZ()

    for i=0,allPlayers:size()-1 do
        local player = allPlayers:get(i)
        local username = player:getUsername()
        local distSq = WRC.StatusIndicator.GetDistanceSq(worldX, worldY, player)
        local status = WRC.Meta.GetStatus(username)
        if worldZ == player:getZ() and distSq <= maxDistSq and WRC.CanSeePlayer(player, true, 20) and status then
            local x = isoToScreenX(0, player:getX(), player:getY(), player:getZ())
            local y = isoToScreenY(0, player:getX(), player:getY(), player:getZ())
            y = y - (130 / zoom) - (3*zoom)
            if WRC.Indicator.players[username] then y = y - WRC.Indicator.IndicatorHeight - 2 end
            if WRC.Meta.IsAfk(username) then y = y - WRC.Afk.IndicatorHeight - 2 end
            local statusWidth = getTextManager():MeasureStringX(UIFont.Small, status)
            local statusHeight = getTextManager():MeasureStringY(UIFont.Small, status)
            local ele = WRC.StatusIndicator.OverheadUiElements[username]
            if ele then
                ele:setX(x - (ele.width / 2))
                ele:setY(y)
            else
                ele = ISUIElement:new(x - (statusWidth/2), y, statusWidth, statusHeight)
                ele.anchorTop = false
                ele.anchorBottom = true
                ele:initialise()
                ele:addToUIManager()
                ele:backMost()
                WRC.StatusIndicator.OverheadUiElements[username] = ele
            end
            ele.seen = true
            if WRC.Meta.GetInvertedStatus(getPlayer():getUsername()) then
                ele:drawTextCentre(status, statusWidth/2, 0, 0.0, 0.0, 0.0, 0.6, UIFont.Small)
            else
                ele:drawTextCentre(status, statusWidth/2, 0, 1.0, 1.0, 1.0, 0.6, UIFont.Small)
            end
        end
    end
    for k,v in pairs(WRC.StatusIndicator.OverheadUiElements) do
        if not v.seen then
            v:removeFromUIManager()
            WRC.StatusIndicator.OverheadUiElements[k] = nil
        end
    end
end

function WRC.InjuredStatus.ShowInjuredIndicatorOnApproach()
    local zoom = getCore():getZoom(0)
    for _,x in pairs(WRC.InjuredStatus.OverheadUiElements) do x.seen = false end

    local allPlayers = getOnlinePlayers()
    if not allPlayers then return end

    local ownPlayer = getPlayer()
    local worldX = ownPlayer:getX()
    local worldY = ownPlayer:getY()
    local worldZ = ownPlayer:getZ()
    local injuredText = getText("UI_WRC_Injured")

    for i=0, allPlayers:size()-1 do
        local player = allPlayers:get(i)
        local username = player:getUsername()
        local distSq = WRC.StatusIndicator.GetDistanceSq(worldX, worldY, player)
        local injured = WRC.Meta.GetInjured(username)
        if worldZ == player:getZ() and distSq <= maxInjuredDistSq and WRC.CanSeePlayer(player, true, 20) and injured then
            local x = isoToScreenX(0, player:getX(), player:getY(), player:getZ())
            local y = isoToScreenY(0, player:getX(), player:getY(), player:getZ())
            y = y - (130 / zoom) - (3 * zoom)
            if WRC.Indicator.players[username] then y = y - WRC.Indicator.IndicatorHeight - 2 end
            if WRC.Meta.IsAfk(username) then y = y - WRC.Afk.IndicatorHeight - 2 end
            local injuredWidth = getTextManager():MeasureStringX(UIFont.Small, injuredText)
            local injuredHeight = getTextManager():MeasureStringY(UIFont.Small, injuredText)
            y = y - injuredHeight - 5
            local ele = WRC.InjuredStatus.OverheadUiElements[username]
            if ele then
                ele:setX(x - (ele.width / 2))
                ele:setY(y)
            else
                ele = ISUIElement:new(x - (injuredWidth / 2), y, injuredWidth, injuredHeight)
                ele.anchorTop = false
                ele.anchorBottom = true
                ele:initialise()
                ele:addToUIManager()
                ele:backMost()
                WRC.InjuredStatus.OverheadUiElements[username] = ele
            end
            ele.seen = true
            ele:drawTextCentre(injuredText, injuredWidth / 2, 0, 1.0, 1.0, 0.0, 0.6, UIFont.Small)
        end
    end

    for k,v in pairs(WRC.InjuredStatus.OverheadUiElements) do
        if not v.seen then
            v:removeFromUIManager()
            WRC.InjuredStatus.OverheadUiElements[k] = nil
        end
    end
end

function WRC.StreamingStatus.ShowStreamingIndicatorOnApproach()
    local zoom = getCore():getZoom(0)
    for _,x in pairs(WRC.StreamingStatus.OverheadUiElements) do x.seen = false end

    local allPlayers = getOnlinePlayers()
    if not allPlayers then return end

    local ownPlayer = getPlayer()
    local worldX = ownPlayer:getX()
    local worldY = ownPlayer:getY()
    local worldZ = ownPlayer:getZ()
    local streamingText = getText("UI_WRC_Streaming")

    for i=0, allPlayers:size()-1 do
        local player = allPlayers:get(i)
        local username = player:getUsername()
        local distSq = WRC.StatusIndicator.GetDistanceSq(worldX, worldY, player)
        local streaming = WRC.Meta.GetStreaming(username)
        if worldZ == player:getZ() and distSq <= maxInjuredDistSq and WRC.CanSeePlayer(player, true, 20) and streaming then
            local x = isoToScreenX(0, player:getX(), player:getY(), player:getZ())
            local y = isoToScreenY(0, player:getX(), player:getY(), player:getZ())
            y = y - (130 / zoom) - (3 * zoom)
            if WRC.Indicator.players[username] then y = y - WRC.Indicator.IndicatorHeight - 2 end
            if WRC.Meta.IsAfk(username) then y = y - WRC.Afk.IndicatorHeight - 2 end
            local streamingWidth = getTextManager():MeasureStringX(UIFont.Small, streamingText)
            local streamingHeight = getTextManager():MeasureStringY(UIFont.Small, streamingText)
            y = y - streamingHeight - 5
            local ele = WRC.StreamingStatus.OverheadUiElements[username]
            if ele then
                ele:setX(x - (ele.width / 2))
                ele:setY(y)
            else
                ele = ISUIElement:new(x - (streamingWidth / 2), y, streamingWidth, streamingHeight)
                ele.anchorTop = false
                ele.anchorBottom = true
                ele:initialise()
                ele:addToUIManager()
                ele:backMost()
                WRC.StreamingStatus.OverheadUiElements[username] = ele
            end
            ele.seen = true
            ele:drawTextCentre(streamingText, streamingWidth / 2, 0, 1.0, 0.0, 0.0, 0.6, UIFont.Small)
        end
    end

    for k,v in pairs(WRC.StreamingStatus.OverheadUiElements) do
        if not v.seen then
            v:removeFromUIManager()
            WRC.StreamingStatus.OverheadUiElements[k] = nil
        end
    end
end