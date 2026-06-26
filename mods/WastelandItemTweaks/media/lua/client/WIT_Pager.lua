--- 
--- WIT_Pager.lua
--- 16/04/2025
--- 

require "WL_Utils"
require "GravyUI_WL"

local HamRadioItem = {"HamRadio1", "HamRadio2", "HamRadioMakeShift"}
local RadioItem = {"WalkieTalkie3", "WalkieTalkie4", "WalkieTalkie5", "WalkieTalkiePremiumBoosted", "WalkieTalkieTacticalBoosted", "WalkieTalkieMakeShift"}
local HamRadioSprite = {"appliances_com_01_0", "appliances_com_01_1", "appliances_com_01_2", "appliances_com_01_4", "appliances_com_01_5",
                        "appliances_com_01_6", "appliances_com_01_7", "appliances_com_01_8", "appliances_com_01_9", "appliances_com_01_10",
                        "appliances_com_01_11", "appliances_com_01_12", "appliances_com_01_13", "appliances_com_01_14", "appliances_com_01_15",
                        "appliances_com_01_56", "appliances_com_01_57", "appliances_com_01_58", "appliances_com_01_59", "appliances_com_01_60",
                        "appliances_com_01_61", "appliances_com_01_62", "appliances_com_01_63"}

if WIT_Pager then
    Events.OnFillWorldObjectContextMenu.Remove(WIT_Pager.contextMenu)
    Events.OnFillInventoryObjectContextMenu.Remove(WIT_Pager.InventoryContextMenu)
end
local WIT_Pager = {}

--- UI

WIT_Pager_UI = ISPanel:derive("WIT_Pager_UI")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

function WIT_Pager_UI.display(player, hamRadio)
    if WIT_Pager_UI.instance then
        WIT_Pager_UI.instance:removeFromUIManager()
    end
    WIT_Pager_UI.instance = WIT_Pager_UI:new(player, hamRadio)
    WIT_Pager_UI.instance:addToUIManager()
end

function WIT_Pager_UI:new(player, hamRadio)
    local scale = FONT_HGT_SMALL / 12
    local w = 300 * scale
    local h = 500 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    o.character = player
    o.hamRadio = hamRadio:getSquare()
    o.hamRadioObject = hamRadio
    o.scoreboard = nil
    o.selectedPlayers = {}
    o:initialise()
    return o
end

function WIT_Pager_UI:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true
    

    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(20, 20, 20, 20)

    self.backgroundColor = {r=0, g=0, b=0, a=0.9}
    self.borderColor = {r=0,g=0,b=0,a=1}

    local dividerArea = win:rows(1,10)

    local titleNode, instructionsNode, mainContentNode = win:rows({0.05, 0.05, 0.9}, 5)
    local titleDivider = titleNode:cols(1, 5)
    local titleText = "Send Pager Alert"
    local instructionText = "Click Players to Select/Deselect. You can select up to 8 Players."

    self.titleLabel = titleNode:makeLabel(titleText, UIFont.Large, {r=0.5, g=0.8, b=0.5, a=1}, "center")
    
    local contentNode, buttonNode = mainContentNode:rows({0.95, 0.05}, 5)
    local playerNode, messageNode = contentNode:rows({0.9, 0.1}, 5)
    local playerLabel, playerSelect = playerNode:rows({0.05, 0.95}, 5)
    local messageLabel, messageInput = messageNode:rows({0.3, 0.7}, 5)
    local sendButton, cancelButton = buttonNode:cols({0.5, 0.5}, 5)

    self.instructionLabel = instructionsNode:makeLabel(instructionText, UIFont.Small, {r=0.5, g=0.8, b=0.5, a=1}, "center")
    self.playerLabel = playerLabel:makeLabel("Select Players", UIFont.Small, {r=0.5, g=0.8, b=0.5, a=1}, "center")
    self.messageLabel = messageLabel:makeLabel("Message", UIFont.Small, {r=0.5, g=0.8, b=0.5, a=1}, "center")

    self.playerSelectList = playerSelect:makeScrollingListBox(UIFont.Small)
    self.playerSelectList.drawBorder = true
    
    self.playerSelectList:setOnMouseDownFunction(self, function(target, item)
        if item and item.username then
            target:togglePlayerSelection(item.username)
        end
    end)

    self:populatePlayerSelect()

    self.messageInput = messageInput:makeTextBox("", true)
    self.messageInput.javaObject:setMaxTextLength(8)

    self.messageInput.tooltip = "Include up to eight digits. Periods are allowed. \nExample: 12345.67"

    self.sendButton = sendButton:makeButton("Send", self, self.onSend)
    self.cancelButton = cancelButton:makeButton("Cancel", self, function()
        self:close()
    end)

    self:updateState()
    scoreboardUpdate()
end

function WIT_Pager_UI:togglePlayerSelection(username)
    if self.selectedPlayers[username] then
        self.selectedPlayers[username] = nil
    else
        local count = 0
        for _ in pairs(self.selectedPlayers) do
            count = count + 1
        end
        
        local isStaff = self.character:getAccessLevel() ~= "None"
        local maxPlayers = isStaff and 999 or 8
        
        if count >= maxPlayers then
            WL_Utils.addErrorToChat("Maximum " .. maxPlayers .. " players can be selected")
            return
        end
        
        self.selectedPlayers[username] = true
    end
    
    self:updatePlayerList()
end

function WIT_Pager_UI:onSend()
    local message = self.messageInput:getText()
    
    if not message or message == "" then
        WL_Utils.addErrorToChat("No message entered")
        return
    end
    
    local selectedPlayers = {}
    for username, _ in pairs(self.selectedPlayers) do
        table.insert(selectedPlayers, username)
    end
    
    if #selectedPlayers == 0 then
        WL_Utils.addErrorToChat("No player selected")
        return
    end
    
    sendClientCommand(self.character, "WIT_Pager", "sendMessage", {recipients = selectedPlayers, message = tostring(message)})
    self:close()
end

function WIT_Pager_UI:updateState()
    --
end

function WIT_Pager_UI:prerender()
    ISPanel.prerender(self)
end

function WIT_Pager_UI:render()
    ISPanel.render(self)
end

function WIT_Pager_UI:close()
    self:removeFromUIManager()
    WIT_Pager_UI.instance = nil
end

--- Context Menu

local function getHamRadio(sq)
    if sq then
        if sq:getObjects() then
            for i = 0, sq:getObjects():size() - 1 do
                local obj = sq:getObjects():get(i)
                if obj:getSprite() then
                    local spriteName = obj:getSprite():getName() or nil
                    if spriteName then
                        for j = 1, #HamRadioSprite do
                            if spriteName == HamRadioSprite[j] then
                                return obj
                            end
                        end
                    end
                end
            end
        end
    end
end

local function readMessage(player, pagerObj)
    local messageText = "Received Message: " .. pagerObj:getModData().message
    WL_Utils.addToChat(messageText, {color = "0.4,0.8,0.7"})
    pagerObj:getModData().message = nil
    WRC.SendLocalEmote("checked their pager")
end

local function isHamRadio(item)
    for _, hamRadio in ipairs(HamRadioItem) do
        if item:getType() == hamRadio then
            return true
        end
    end
    return false
end

local function isRadio(item)
    for _, radio in ipairs(RadioItem) do
        if item:getType() == radio then
            return true
        end
    end
    return false
end

local function openPanel( _p, _item )
    ISRadioWindow.activate( _p.player, _item );
end

function WIT_Pager.InventoryContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()
    local pagerObj, pagerAttached, hamAttached, hamHeld
    local attachedItems = playerObj:getAttachedItems()
    local inventory = playerInv:getItems()
    local primary = playerObj:getPrimaryHandItem()
    local secondary = playerObj:getSecondaryHandItem()
    items = ISInventoryPane.getActualItems(items)

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem:getItem()
        if item:getFullType() == "Base.WITPager" then
            pagerObj = item
            pagerAttached = true
        end
        if isHamRadio(item) then
            if item:getDeviceData():getIsTurnedOn() then
                hamAttached = true
            end
        end
        if isRadio(item) then
            if item:getDeviceData():getIsTurnedOn() then
                hamAttached = true
            end
        end
    end

    if not hamAttached then
        if (primary and isHamRadio(primary)) or (secondary and isHamRadio(secondary)) then
            if (primary and primary:getDeviceData():getIsTurnedOn()) or (secondary and secondary:getDeviceData():getIsTurnedOn()) then
                hamHeld = true
            end
        end
    end

    if not pagerObj then
        for i = 0, inventory:size() - 1 do
            local item = inventory:get(i)
            if item:getFullType() == "Base.WITPager" then
                pagerObj = item
                break
            end
        end
    end

    for _, item in ipairs(items) do
        if item:getFullType() == "Base.WITPager" then
            if pagerObj and pagerAttached then
                local messageData = pagerObj:getModData().message
                if messageData then
                    local option = context:addOption("Read Pager Message", playerObj, readMessage, pagerObj)
                    WL_ContextMenuUtils.addToolTip(option, "Read Pager Message", "Click to read the message", nil, "Item_Pager")
                else
                    WL_ContextMenuUtils.missingRequirement(context, "Read Pager Message", "No message to read", nil, "Item_Pager")
                end
            elseif pagerObj and not pagerAttached then
                WL_ContextMenuUtils.missingRequirement(context, "Read Pager Message", "Pager is not attached to you", nil, "Item_Pager")
            end
        elseif (isHamRadio(item) or isRadio(item)) and (hamAttached or hamHeld) then
            context:addOption("Send Pager Alert", playerObj, function()
                    WIT_Pager_UI.display(playerObj, item)
            end)
            if not hamHeld and isHamRadio(item) then
                context:addOption(getText("IGUI_DeviceOptions"), playerObj, function()
                    ISRadioWindow.activate( playerObj, item )
                end)
            end
        end
    end
end

function WIT_Pager.contextMenu(player, context, worldobjects, test)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()
    local hamRadio = getHamRadio(worldobjects[1]:getSquare())
    

    if not hamRadio then return end
    
    context:addOption("Send Pager Alert", playerObj, function()
        if luautils.walkAdj(playerObj, hamRadio:getSquare()) then
            WIT_Pager_UI.display(playerObj, hamRadio)
        end
    end)
end

local function getPlayerByUserNameSafer(username)
	local player = getPlayerFromUsername(username)
	if player then
		return player
	end
	local players = getOnlinePlayers()
	for i=0, players:size()-1 do
		local player = players:get(i)
		if player:getUsername() == username then
			return player
		end
	end
	return nil
end

function WIT_Pager.receiveMessage(args)
    local player = args.receive
    local playerObj = getPlayerByUserNameSafer(player)
    local message = args.message
    local pager = "Base.WITPager"
    local pagerObj
    local attachedItems = playerObj:getAttachedItems()

    for i = 0, attachedItems:size() - 1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem:getItem()
        if item:getFullType() == "Base.WITPager" then
            pagerObj = item
            break
        end
    end
    if pagerObj then
        WRC.SendLocalEmote("'s pager went off!")
        pagerObj:getModData().message = message
    end
end

function WIT_Pager.sentMessage(args)
    local player = args.send
    local recipients = args.recipients or {}
    local message = args.message
    local playerObj = getPlayerByUserNameSafer(player)

    if playerObj then
        local recipientList = table.concat(recipients, ", ")
        local messageText = "Successfully sent message: " .. message .. " to " .. (#recipients) .. " player(s): " .. recipientList
        WL_Utils.addToChat(tostring(messageText), {color = "0,1.0,0"})
    end
end

function WIT_Pager.failedMessage(args)
    local player = args.send
    local recipients = args.recipients or {}
    local message = args.message
    local playerObj = getPlayerByUsername(player)

    if playerObj then
        local recipientList = table.concat(recipients, ", ")
        local messageText = "Failed to send message: " .. message .. " to " .. (#recipients) .. " player(s): " .. recipientList
        WL_Utils.addErrorToChat(messageText)
    end
end

function WIT_Pager_UI:updatePlayerList()
    self.playerSelectList:clear()

    if not self.scoreboard then return end

    local players = {}
    for i = 0, self.scoreboard.usernames:size() - 1 do
        local username = self.scoreboard.usernames:get(i)
        local displayName = self.scoreboard.displayNames:get(i)
        if username ~= self.character:getUsername() then
            table.insert(players, {displayName = displayName, username = username})
        end
    end

    table.sort(players, function(a, b)
        return tostring(a.displayName):lower() < tostring(b.displayName):lower()
    end)

    for _, player in ipairs(players) do
        local prefix = self.selectedPlayers[player.username] and "[X] " or "[_] "
        self.playerSelectList:addItem(prefix .. player.displayName, player)
    end
end

function WIT_Pager_UI:populatePlayerSelect()
    self:updatePlayerList()
end


local function processServerCommand(module, command, args)
    if module ~= "WIT_Pager" then return end
    if not WIT_Pager[command] then return end
    WIT_Pager[command](args)
end

function WIT_Pager_UI.OnScoreboardUpdate(usernames, displayNames, steamIDs)
    if not WIT_Pager_UI.instance then return end

    WIT_Pager_UI.instance.scoreboard = {
        usernames = usernames,
        displayNames = displayNames,
    }

    WIT_Pager_UI.instance:populatePlayerSelect()
end

local dist = 10
function ISRadioWindow:update()
    ISCollapsableWindow.update(self);

    if self:getIsVisible() then

        if self.deviceData and self.deviceType == "VehiclePart" then
            local part = self.deviceData:getParent()
            if part and part:getItemType() and not part:getItemType():isEmpty() and not part:getInventoryItem() then
                self:close()
                return
            end
        end

        local function isAttached()
            local attachedItems = self.player:getAttachedItems()
            for i = 0, attachedItems:size() - 1 do
                local attachedItem = attachedItems:get(i)
                local item = attachedItem:getItem()
                if item == self.device then
                    if self.device:getType():sub(1, 8) == "HamRadio" then
                        return true
                    end
                end
            end
        end

        if self.deviceType and self.device and self.player and self.deviceData then		
            if self.deviceType=="InventoryItem" then
                if self.player:getPrimaryHandItem() == self.device or self.player:getSecondaryHandItem() == self.device or isAttached() then
                    return;
                end
            elseif self.deviceType == "IsoObject" or self.deviceType == "VehiclePart" then
                if self.device:getSquare() and self.player:getX() > self.device:getX()-dist and self.player:getX() < self.device:getX()+dist and self.player:getY() > self.device:getY()-dist and self.player:getY() < self.device:getY()+dist then
                    return;
                end
            end
        end
    end

    self:close();
end


Events.OnFillWorldObjectContextMenu.Add(WIT_Pager.contextMenu)
Events.OnFillInventoryObjectContextMenu.Add(WIT_Pager.InventoryContextMenu)
Events.OnScoreboardUpdate.Add(WIT_Pager_UI.OnScoreboardUpdate)
Events.OnServerCommand.Add(processServerCommand)