---
--- InitiativeTracker.lua
--- 25/06/2025
---

require "GravyUI_WL"
require "ISUI/ISCollapsableWindow"

WAT_InitiativeTracker = ISCollapsableWindow:derive("WAT_InitiativeTracker")
WAT_InitiativeTracker.instance = nil

function WAT_InitiativeTracker.display()
    if WAT_InitiativeTracker.instance then return end
    WAT_InitiativeTracker.instance = WAT_InitiativeTracker:new()
    WAT_InitiativeTracker.instance:addToUIManager()
end

function WAT_InitiativeTracker:new()
    local scale = getTextManager():getFontHeight(UIFont.Small) / 12
    local w = 300 * scale
    local h = 430 * scale
    local o = ISCollapsableWindow:new(getCore():getScreenWidth()/2 - w/2, getCore():getScreenHeight()/2 - h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    o.character = getPlayer()
    o.scale = scale
    o.round = 1
    o.turn = 1
    o.inCombat = false
    o.alertVolume = "shout"
    o.md = getPlayer():getModData()
    o:initialise()
    return o
end

function WAT_InitiativeTracker:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self.resizable = false

    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

    local win = GravyUI.Node(self.width, self.height, self):pad(5, 15, 5, 5)
    local header, body = win:rows({30 * self.scale, 1.0}, 2 * self.scale)
    local rowsContainer, volumeRow, buttons = body:rows({1.0, 20 * self.scale, 15 * self.scale}, 2 * self.scale)

    local headerLabel, subTitleLabel = header:rows({0.5, 0.5}, 2 * self.scale)
    headerLabel = headerLabel:makeLabel("Initiative Tracker", UIFont.Medium, nil, "center")
    self.subTitleLabel = subTitleLabel:makeLabel("Round: " .. self.round .. " | Turn: " .. self.turn, UIFont.Small, nil, "center")

    local numRows = 15
    self.initRows = {}

    local rowStack = rowsContainer:makeVerticalStack(2 * self.scale)
    local rowHeight = getTextManager():getFontHeight(UIFont.Small) + 10

    for i = 1, numRows do
        local row = rowStack:makeNode(rowHeight)
        local overrideNode, inputNode, moveUpNode, moveDownNode = row:cols({0.1, 0.6, 0.15, 0.15}, 2 * self.scale)

        local overrideBtn = overrideNode:makeButton(">", self, function() self:toggleOverride(i) end)
        overrideBtn.tooltip = "Current Turn Indiciator\nClick to override and set current turn."
        local inputBox = inputNode:makeTextBox("", false)

        local moveUpBtn = nil
        local moveDownBtn = nil

        if i > 1 then
            moveUpBtn = moveUpNode:makeButton("Up", self, function() self:moveUp(i) end)
            moveUpBtn.tooltip = "Move Up\nClick to move this entry up in the initiative order."
        end
        if i < numRows then
            moveDownBtn = moveDownNode:makeButton("Down", self, function() self:moveDown(i) end)
            moveDownBtn.tooltip = "Move Down\nClick to move this entry down in the initiative order."
        end

        self.initRows[i] = {
            overrideBtn = overrideBtn,
            inputBox = inputBox,
            moveUpBtn = moveUpBtn,
            moveDownBtn = moveDownBtn
        }
    end

    local volumeLabelNode, volumeComboNode = volumeRow:cols({0.45, 0.55}, 2 * self.scale)
    local volumeLabel = volumeLabelNode:makeLabel("Alert Volume", UIFont.Small, nil, "left")
    volumeLabel:setY(volumeLabel:getY() + math.floor((volumeLabelNode.height - FONT_HGT_SMALL) / 2))
    self.alertVolumeComboBox = volumeComboNode:makeComboBox(self, self.onAlertVolumeChanged)
    self.alertVolumeComboBox:addOptionWithData("Whisper", "whisper")
    self.alertVolumeComboBox:addOptionWithData("Quiet", "quiet")
    self.alertVolumeComboBox:addOptionWithData("Normal", "say")
    self.alertVolumeComboBox:addOptionWithData("Loud", "yell")
    self.alertVolumeComboBox:addOptionWithData("Shout", "shout")
    self.alertVolumeComboBox:selectData(self.alertVolume)

    local previousButton, nextButton, endButton, resetButton = buttons:cols({0.25, 0.25, 0.3, 0.2}, 2 * self.scale)
    self.previousButton = previousButton:makeButton("Previous", self, self.previousTurn)
    self.previousButton.tooltip = "Previous Turn\nClick to go to the previous turn in the initiative order."
    self.nextButton = nextButton:makeButton("Next", self, self.nextTurn)
    self.nextButton.tooltip = "Next Turn\nClick to go to the next turn in the initiative order."
    self.endButton = endButton:makeButton("Start Combat", self, self.toggleCombat)
    self.endButton.tooltip = "Start / Stop Combat\nClick to toggle combat mode.\nWhen in combat, the tracker will manage turns."
    self.resetButton = resetButton:makeButton("Reset", self, self.resetTracker)
    self.resetButton.tooltip = "Reset Tracker\nClears all names and resets Round/Turn to 1."


    self:loadTrackerState()
end

function WAT_InitiativeTracker:onAlertVolumeChanged()
    self.alertVolume = self:getCurrentAlertVolume()
    self:saveTrackerState()
end

function WAT_InitiativeTracker:getCurrentAlertVolume()
    return self.alertVolumeComboBox:getOptionData(self.alertVolumeComboBox.selected)
end

function WAT_InitiativeTracker:getAlertCommandPrefix()
    local volume = self:getCurrentAlertVolume() or "shout"
    return "/alert" .. volume
end

function WAT_InitiativeTracker:getAlertSpeakerName()
    return "Initiative Tracker"
end

function WAT_InitiativeTracker:buildSpoofedAlertMessage(alertMessage)
    local player = getPlayer()
    local x = tostring(math.floor(player:getX()))
    local y = tostring(math.floor(player:getY()))
    local z = tostring(math.floor(player:getZ()))
    return "[UN:" .. self:getAlertSpeakerName() .. "][POS:" .. x .. "," .. y .. "," .. z .. "]" .. self:getAlertCommandPrefix() .. " " .. alertMessage
end

function WAT_InitiativeTracker:sendSpoofedAlert(alertMessage)
    local message = self:buildSpoofedAlertMessage(alertMessage)
    local volume = self:getCurrentAlertVolume() or "shout"
    if volume == "shout" then
        processShoutMessage(message)
    else
        processSayMessage(message)
    end
end

function WAT_InitiativeTracker:resetTracker()
    self.round = 1
    self.turn = 1
    self.inCombat = false
    self.endButton:setTitle("Start Combat")

    for _, row in ipairs(self.initRows) do
        row.inputBox:setText("")
    end

    self:updateTurn(self.turn)
    self:saveTrackerState()
end


function WAT_InitiativeTracker:toggleOverride(row)
    if self.turn == row then return end
    self.turn = row
    self:updateTurn(self.turn)
end

function WAT_InitiativeTracker:nextTurn()
    local numRows = #self.initRows
    local nextTurn = self.turn + 1

    while nextTurn <= numRows do
        local input = self.initRows[nextTurn].inputBox:getText()
        if input and input ~= "" then
            self.turn = nextTurn
            self:updateTurn(self.turn)
            return
        end
        nextTurn = nextTurn + 1
    end

    self.round = self.round + 1
    self.turn = 1
    self:updateTurn(self.turn)
end

function WAT_InitiativeTracker:previousTurn()
    local prevTurn = self.turn - 1

    while prevTurn >= 1 do
        local input = self.initRows[prevTurn].inputBox:getText()
        if input and input ~= "" then
            self.turn = prevTurn
            self:updateTurn(self.turn)
            return
        end
        prevTurn = prevTurn - 1
    end

    if self.round > 1 then
        self.round = self.round - 1
        for i = #self.initRows, 1, -1 do
            local input = self.initRows[i].inputBox:getText()
            if input and input ~= "" then
                self.turn = i
                self:updateTurn(self.turn)
                return
            end
        end
    end
end

function WAT_InitiativeTracker:updateTurn(turn)
    for i, row in ipairs(self.initRows) do
        local btn = row.overrideBtn
        if i == turn then
            btn:setBackgroundRGBA(0.8, 0.2, 0.2, 0.5)
        else
            btn:setBackgroundRGBA(0.5, 0.5, 0.5, 0.3)
        end
    end
    self.subTitleLabel:setText("Round: " .. self.round .. " | Turn: " .. self.turn)
    self:sendAlertMessages()
    self:saveTrackerState()
end

function WAT_InitiativeTracker:toggleCombat()
    self.inCombat = not self.inCombat
    self.endButton:setTitle(self.inCombat and "End Combat" or "Start Combat")
    
    if self.inCombat then
        self:updateTurn(self.turn)
    else
        self:sendSpoofedAlert("Initiative has Ended")
    end

    self:saveTrackerState()
end


function WAT_InitiativeTracker:moveUp(i)
    if i <= 1 then return end
    local above = self.initRows[i - 1].inputBox
    local current = self.initRows[i].inputBox
    local temp = current:getText()
    current:setText(above:getText())
    above:setText(temp)
    self:updateTurn(self.turn)
end

function WAT_InitiativeTracker:moveDown(i)
    if i >= #self.initRows then return end
    local below = self.initRows[i + 1].inputBox
    local current = self.initRows[i].inputBox
    local temp = current:getText()
    current:setText(below:getText())
    below:setText(temp)
    self:updateTurn(self.turn)
end

function WAT_InitiativeTracker:saveTrackerState()
    local data = self.md
    data.initTracker = {
        round = self.round,
        turn = self.turn,
        inCombat = self.inCombat,
        alertVolume = self:getCurrentAlertVolume(),
        entries = {}
    }

    for i, row in ipairs(self.initRows) do
        table.insert(data.initTracker.entries, row.inputBox:getText())
    end
end

function WAT_InitiativeTracker:loadTrackerState()
    local data = self.md
    if not data.initTracker then return end

    self.round = data.initTracker.round or 1
    self.turn = data.initTracker.turn or 1
    self.inCombat = data.initTracker.inCombat or false
    self.alertVolume = data.initTracker.alertVolume or "shout"
    self.alertVolumeComboBox:selectData(self.alertVolume)
    self.endButton:setTitle(self.inCombat and "End Combat" or "Start Combat")

    for i, text in ipairs(data.initTracker.entries or {}) do
        if self.initRows[i] then
            self.initRows[i].inputBox:setText(text)
        end
    end

    self:updateTurn(self.turn)
end

function WAT_InitiativeTracker:sendAlertMessages()
    if not self.inCombat then return end
    local currentName = self.initRows[self.turn] and self.initRows[self.turn].inputBox:getText() or ""
    local nextIndex = self.turn + 1
    local nextName = self.initRows[nextIndex] and self.initRows[nextIndex].inputBox:getText() or nil

    if currentName ~= "" then
        local alertMsg = currentName .. " is Up."
        if nextName and nextName ~= "" then
            alertMsg = alertMsg .. " " .. nextName .. " is Next."
        else
            alertMsg = alertMsg .. " Round ending after this turn."
        end
        self:sendSpoofedAlert(alertMsg)
    end
end

function WAT_InitiativeTracker:close()
    ISCollapsableWindow.close(self)
    WAT_InitiativeTracker.instance = nil
    self:saveTrackerState()
end

function WAT_InitiativeTracker.onContextMenu(playerId, context)
    local player = getSpecificPlayer(playerId)
    if not player then return end
    if not WL_Utils.canModerate(player) then return end

    local wlAdminMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local eventToolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdminMenu, "Event Tools")
    eventToolsMenu:addOption("Initiative Tracker", nil, WAT_InitiativeTracker.display)
end

Events.OnFillWorldObjectContextMenu.Add(WAT_InitiativeTracker.onContextMenu)
