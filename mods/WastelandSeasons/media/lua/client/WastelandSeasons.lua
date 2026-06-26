require "WM_Utils"
require "UI/WastelandSeasonsAdminWindow"

WastelandSeasons = WastelandSeasons or {}
WastelandSeasons.DEBUG_LOG = WastelandSeasons.DEBUG_LOG or false

if WastelandSeasons.INTIALIZED then
    Events.OnFillWorldObjectContextMenu.Remove(WastelandSeasons.OnFillWorldObjectContextMenu)
    Events.OnServerCommand.Remove(WastelandSeasons.OnServerCommand)
    Events.OnReceiveGlobalModData.Remove(WastelandSeasons.ReceiveModData)
    Events.OnConnected.Remove(WastelandSeasons.RequestModData)
    Events.EveryOneMinute.Remove(WastelandSeasons.CheckDoHarm)
end

function WastelandSeasons.debugLog(message)
    if WastelandSeasons.DEBUG_LOG then
        print("[WastelandSeasons] " .. tostring(message))
    end
end

function WastelandSeasons.SendCommand(command, args)
    sendClientCommand(getPlayer(), "WastelandSeasons", command, args or {})
end

function WastelandSeasons.RequestAdminData()
    WastelandSeasons.SendCommand("RequestAdminData", {})
end

function WastelandSeasons.OnFillWorldObjectContextMenu(playerIdx, context)
    if not WL_Utils.canModerate(getPlayer()) then return end
    local wlAdmin = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local eventToolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdmin, "Event Tools")
    eventToolsMenu:addOption("Wasteland Seasons", nil, function()
        WastelandSeasonsAdminWindow:show(getPlayer())
    end)
end

function WastelandSeasons.RequestModData()
    ModData.request("WastelandSeasonsPublic")
end

function WastelandSeasons.ReceiveModData(key, data)
    if key == "WastelandSeasonsPublic" then
        WastelandSeasons.PublicData = data
    end
end

function WastelandSeasons.OnServerCommand(module, command, args)
    if module ~= "WastelandSeasons" then return end
    if command == "env" then
        local message = args[1]
        local fakeMessage = WL_FakeMessage:new("[npc][UN:NPC]/env " .. tostring(message))
        ISChat.addLineInChat(fakeMessage)
    elseif command == "AdminData" or command == "data" then
        WastelandSeasons.AdminData = args
        WastelandSeasonsAdminWindow:updateServerData(args)
    elseif command == "AdminError" then
        WastelandSeasonsAdminWindow:showError(args and args.message or "Unknown seasons admin error")
    end
end

function WastelandSeasons.CheckDoHarm()
    if not WastelandSeasons.PublicData then return end
    if not WastelandSeasons.PublicData.harmType then return end
    if not WastelandSeasons.PublicData.harmRate then return end
    local player = getPlayer()
    local mask = WM_Utils.findBestWornMask(player)
    local maskType
    if mask then
        maskType = WM_Utils.getMaskType(mask)
    end
    if WastelandSeasons.PublicData.harmType == "radiation" then
        WastelandSeasons.debugLog("Checking " .. WastelandSeasons.PublicData.harmType .. " at " .. WastelandSeasons.PublicData.harmRate)
        if not player:isOutside() then
            WastelandSeasons.debugLog("Not outside")
            return
        end
        local harmRate = WastelandSeasons.PublicData.harmRate
        if mask then
            if maskType == "HazmatSuit" then
                WastelandSeasons.debugLog("Wearing hazmat")
                return
            elseif maskType == "GasMask" then
                local gasMaskFilterUse = WM_Utils.getFilterUse(mask)
                if gasMaskFilterUse > 0 then
                    WastelandSeasons.debugLog("Wearing gas mask")
                    harmRate = harmRate / 2
                end
            end
        end
        WastelandSeasons.debugLog("Harming player: " .. harmRate)
        player:getBodyDamage():ReduceGeneralHealth(harmRate)
    elseif WastelandSeasons.PublicData.harmType == "acid" then
        WastelandSeasons.debugLog("Checking " .. WastelandSeasons.PublicData.harmType .. " at " .. WastelandSeasons.PublicData.harmRate)
        if not player:isOutside() then
            WastelandSeasons.debugLog("Not outside")
            return
        end

        if mask and maskType == "HazmatSuit" then
            WastelandSeasons.debugLog("Wearing hazmat")
            return
        end
        local harmRate = WastelandSeasons.PublicData.harmRate
        local bodyPercentCovered = WastelandSeasons.getBodyPercentCovered(player)
        WastelandSeasons.debugLog("Body percent covered: " .. bodyPercentCovered)
        harmRate = harmRate * (1 - bodyPercentCovered)
        WastelandSeasons.debugLog("Harming player: " .. harmRate)
        player:getBodyDamage():ReduceGeneralHealth(harmRate)
    end
end

function WastelandSeasons.getBodyPercentCovered(player)
    local partsMax = BodyPartType.MAX:index()
    local partsCovered = {}
    for i = 0, partsMax - 1 do
        partsCovered[i] = false
    end
    local wornItems = player:getWornItems()
    for i = 1, wornItems:size() do
        local item = wornItems:getItemByIndex(i - 1)
        if item and instanceof(item, "Clothing") then
            local coveredParts = item:getCoveredParts()
            for j = 1, coveredParts:size() do
                local part = coveredParts:get(j - 1)
                partsCovered[part:index()] = true
            end
        end
    end
    local totalCovered = 0
    for i = 0, partsMax - 1 do
        if partsCovered[i] then
            WastelandSeasons.debugLog(BodyPartType.FromIndex(i):toString() .. " is covered")
            totalCovered = totalCovered + 1
        else
            WastelandSeasons.debugLog(BodyPartType.FromIndex(i):toString() .. " is not covered")
        end
    end
    return totalCovered / partsMax
end

Events.OnFillWorldObjectContextMenu.Add(WastelandSeasons.OnFillWorldObjectContextMenu)
Events.OnServerCommand.Add(WastelandSeasons.OnServerCommand)
Events.OnReceiveGlobalModData.Add(WastelandSeasons.ReceiveModData)
Events.OnConnected.Add(WastelandSeasons.RequestModData)
Events.EveryOneMinute.Add(WastelandSeasons.CheckDoHarm)

WastelandSeasons.INTIALIZED = true
