local original_ISPlowAction_isValid = ISPlowAction.isValid
function ISPlowAction:isValid()
    if not SandboxVars.WastelandFarming.EnableFarmingTokens then
        return original_ISPlowAction_isValid(self)
    end
    local player = self.character
    if not WF_TokensSystem:canUsePlot(player) then
        player:Say(getText("IGUI_WFTokens_TooManyPlots"))
        return false
    end
    return original_ISPlowAction_isValid(self)
end

local function overridePlowActionCount(playerId, context)
    if not SandboxVars.WastelandFarming.EnableFarmingTokens then
        return
    end

    local player = getSpecificPlayer(playerId)

    for i = 1, #context.options do
        local option = context.options[i]
        if option.onSelect == ISFarmingMenu.onPlow then
            option.name = option.name .. " (" .. WF_TokensSystem.myUsedTokens .. "/" .. WF_TokensSystem:getAllowedTokens(player) .. ")"
            if WF_TokensSystem:canUsePlot(player) then
                option.notAvailable = false
            end
            if WF_TokensSystem.myUsedTokens > 0 then
                context:addOption(getText("ContextMenu_WFListMyPlots"), WF_TokensSystem, WF_TokensSystem.listMyPlots, player)
            end
        end
    end
end

local function finishChat(command)
    ISChat.instance:unfocus()
    ISChat.instance:logChatCommand(command)
    doKeyPress(false)
    ISChat.instance.timerTextEntry = 20
end

if WF_WorldMenu then
    Events.OnFillWorldObjectContextMenu.Remove(WF_WorldMenu)
end

function WF_WorldMenu(playerNum, context)
    if not SandboxVars.WastelandFarming.EnableFarmingTokens then
        return
    end


    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj then return end

    if not WL_Utils.canModerate(playerObj) then
        return
    end

    local wlAdminMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local worldMgmtMenu = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdminMenu, "World Management")
    worldMgmtMenu:addOption("Manage Farming Plots", nil, WF_ManagePlotsUI.open)
end

Events.OnFillWorldObjectContextMenu.Add(WF_WorldMenu)

WF_Chat_OnCommandEntered = WF_Chat_OnCommandEntered or ISChat.onCommandEntered
function ISChat:onCommandEntered()
    local text = ISChat.instance.textEntry:getText()
    local command = text
    if text:sub(1, 4) == "/wf " then
        text = text:sub(5)
        local player = getPlayer()
        if not player or not WL_Utils.canModerate(player) then
            WL_Utils.addErrorToChat("You do not have permission to use this command.")
            finishChat(command)
            return
        end
        if text:sub(1, 6) == "clear " then
            local x,y,z = text:sub(7):trim():match("^(%d+),(%d+),(%d+)$")
            if x and y and z then
                x, y, z = tonumber(x), tonumber(y), tonumber(z)
                WF_TokensSystem:adminReleasePlot(getPlayer(), x, y, z)
                WL_Utils.addInfoToChat("Releasing plot at coordinates: " .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z))
            else
                WL_Utils.addErrorToChat("Invalid coordinates. Use: /wf clear x,y,z")
            end
            finishChat(command)
            return
        end
        WL_Utils.addErrorToChat("Unknown wf command: " .. text)
        finishChat(command)
        return
    end
    WF_Chat_OnCommandEntered(self)
end

Events.OnFillWorldObjectContextMenu.Add(overridePlowActionCount)

WL_PlayerReady.Add(function(playerIdx, player)
    WF_TokensSystem:getMyData(player)
end)
