---
--- ConditionsPanel.lua
--- Spawn conditions panel for spawner configuration
---

WLSP_ConditionsPanel = ISPanel:derive("WLSP_ConditionsPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_YELLOW = { r = 1, g = 1, b = 0, a = 1 }

local SCALE = FONT_HGT_SMALL / 19
local function scale(px) return px * SCALE end

function WLSP_ConditionsPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o.timeOfDayConditions = {}
    o.weatherConditions = {}
    o.playerCountConditions = {}
    o.zombieCountConditions = {}
    o:initialise()
    return o
end

function WLSP_ConditionsPanel:initialise()
    ISPanel.initialise(self)
    
    -- Store conditional UI elements for show/hide
    self.conditionElements = {}
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))

    local vstack = win:makeVerticalStack(scale(8))

    -- Title
    local titleRow = vstack:makeNode(FONT_HGT_LARGE)
    titleRow:makeLabel("Spawn Conditions", UIFont.Large, COLOR_WHITE, "left")

    -- Enable Conditions Checkbox
    local enableHeaderRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(6))
    local enableCheck, _ = enableHeaderRow:cols({ scale(30), 1 }, scale(5))
    self.enableCheckbox = enableCheck:makeTickBox(self, self.onConditionsCheckChanged)
    self.enableCheckbox:addOption("")
    enableHeaderRow:offset(scale(35), 0):makeLabel("Enable Conditions", UIFont.Medium, COLOR_YELLOW, "left")
    
    -- Condition Mode (OR/AND)
    local modeRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local modeLabel, modeField = modeRow:cols({ 0.3, 0.7 }, scale(10))
    table.insert(self.conditionElements, modeLabel:makeLabel("Condition Mode:", UIFont.Small, COLOR_WHITE, "left"))
    self.conditionModeCombo = modeField:makeComboBox()
    table.insert(self.conditionElements, self.conditionModeCombo)
    self.conditionModeCombo:addOption("AND (all conditions)")
    self.conditionModeCombo:addOption("OR (any condition)")
    
    -- All Conditions Section
    local conditionsHeaderRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(6))
    local conditionsHeaderLabel = conditionsHeaderRow:makeLabel("All Conditions", UIFont.Medium, COLOR_YELLOW, "left")
    table.insert(self.conditionElements, conditionsHeaderLabel)
    
    -- Reserve space for conditions list
    local listHeight = scale(200)
    local listPlaceholder = vstack:makeNode(listHeight)
    
    -- Add Condition Buttons (2x2 grid)
    local buttonRow1 = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local todBtn, weatherBtn = buttonRow1:cols({ 0.5, 0.5 }, scale(5))
    local todButton = todBtn:makeButton("Add Time of Day", self, self.onAddTimeOfDayCondition)
    local weatherButton = weatherBtn:makeButton("Add Weather", self, self.onAddWeatherCondition)
    table.insert(self.conditionElements, todButton)
    table.insert(self.conditionElements, weatherButton)
    
    local buttonRow2 = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local playerBtn, zombieBtn = buttonRow2:cols({ 0.5, 0.5 }, scale(5))
    local playerButton = playerBtn:makeButton("Add Player Count", self, self.onAddPlayerCountCondition)
    local zombieButton = zombieBtn:makeButton("Add Zombie Count", self, self.onAddZombieCountCondition)
    table.insert(self.conditionElements, playerButton)
    table.insert(self.conditionElements, zombieButton)
    
    -- Create unified scroll area with calculated position
    local listY = conditionsHeaderLabel.y + conditionsHeaderLabel.height + scale(8)
    self.conditionsScrollArea = ISScrollingListBox:new(scale(16), listY, self.width - scale(32), listHeight)
    self.conditionsScrollArea:initialise()
    self.conditionsScrollArea:instantiate()
    self.conditionsScrollArea.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.conditionsScrollArea.drawBorder = true
    self.conditionsScrollArea.itemheight = FONT_HGT_SMALL + scale(40)
    self.conditionsScrollArea.font = UIFont.Small
    self.conditionsScrollArea.doDrawItem = WLSP_ConditionsPanel.drawConditionItem
    self.conditionsScrollArea.onMouseUp = function(scrollArea, x, y)
        return self:onConditionListMouseUp(scrollArea, x, y)
    end
    self:addChild(self.conditionsScrollArea)
    table.insert(self.conditionElements, self.conditionsScrollArea)
    
    self:updateConditionsVisibility()
    self:refreshConditionLists()
end

function WLSP_ConditionsPanel:onConditionsCheckChanged()
    self:updateConditionsVisibility()
end

function WLSP_ConditionsPanel:updateConditionsVisibility()
    local visible = self.enableCheckbox:isSelected(1)
    for _, element in ipairs(self.conditionElements) do
        element:setVisible(visible)
    end
end

function WLSP_ConditionsPanel:refreshConditionLists()
    -- Clear scroll area
    self.conditionsScrollArea:clear()
    
    -- Populate time of day conditions
    for idx, condition in ipairs(self.timeOfDayConditions) do
        self.conditionsScrollArea:addItem("tod_" .. idx, {type = "timeOfDay", idx = idx, condition = condition})
    end
    
    -- Populate weather conditions
    for idx, condition in ipairs(self.weatherConditions) do
        self.conditionsScrollArea:addItem("weather_" .. idx, {type = "weather", idx = idx, condition = condition})
    end
    
    -- Populate player count conditions
    for idx, condition in ipairs(self.playerCountConditions) do
        self.conditionsScrollArea:addItem("player_" .. idx, {type = "playerCount", idx = idx, condition = condition})
    end
    
    -- Populate zombie count conditions
    for idx, condition in ipairs(self.zombieCountConditions) do
        self.conditionsScrollArea:addItem("zombie_" .. idx, {type = "zombieCount", idx = idx, condition = condition})
    end
end

function WLSP_ConditionsPanel:drawConditionItem(y, item, alt)
    local a = 0.9
    
    if not item.item then
        return y + self.itemheight
    end
    
    local conditionType = item.item.type
    local idx = item.item.idx
    local condition = item.item.condition
    
    -- Background
    self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.1, 0.1, 0.1)
    
    -- Enabled indicator
    local statusColor = condition.enabled and { r = 0.3, g = 1, b = 0.3 } or { r = 0.5, g = 0.5, b = 0.5 }
    self:drawRect(scale(5), y + scale(5), scale(10), scale(10), a, statusColor.r, statusColor.g, statusColor.b)
    
    -- Draw type-specific content
    if conditionType == "timeOfDay" then
        -- Type label
        self:drawText("[TIME OF DAY]", scale(20), y + scale(4), COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, a, UIFont.Small)
        
        -- Time range
        self:drawText(string.format("Hours: %02d:00 - %02d:00", condition.startHour, condition.endHour),
            scale(20), y + scale(18), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
            
    elseif conditionType == "weather" then
        -- Type label
        self:drawText("[WEATHER]", scale(20), y + scale(4), COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, a, UIFont.Small)
        
        -- Weather details
        local details = {}
        if condition.rainMin or condition.rainMax then
            table.insert(details, string.format("Rain: %.1f-%.1f", condition.rainMin or 0, condition.rainMax or 1))
        end
        if condition.fogMin or condition.fogMax then
            table.insert(details, string.format("Fog: %.1f-%.1f", condition.fogMin or 0, condition.fogMax or 1))
        end
        if condition.requireSnow then
            table.insert(details, "Req Snow")
        end
        if condition.prohibitSnow then
            table.insert(details, "No Snow")
        end
        self:drawText(table.concat(details, ", "), scale(20), y + scale(18), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
        
    elseif conditionType == "playerCount" then
        -- Type label
        self:drawText("[PLAYER COUNT]", scale(20), y + scale(4), COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, a, UIFont.Small)
        
        -- Player details
        local typeStr = condition.checkType or "online"
        local radiusStr = condition.radius and string.format(" (R:%.0f)", condition.radius) or ""
        self:drawText(string.format("Type: %s%s  Min: %d", typeStr, radiusStr, condition.minCount),
            scale(20), y + scale(18), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
            
    elseif conditionType == "zombieCount" then
        -- Type label
        self:drawText("[ZOMBIE COUNT]", scale(20), y + scale(4), COLOR_YELLOW.r, COLOR_YELLOW.g, COLOR_YELLOW.b, a, UIFont.Small)
        
        -- Zombie details
        self:drawText(string.format("Type: %s  Radius: %.0f  Max: %d",
            condition.checkType, condition.radius, condition.maxCount),
            scale(20), y + scale(18), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
    end
    
    -- Draw Edit and Delete buttons on the right
    local buttonWidth = scale(50)
    local buttonHeight = scale(16)
    local buttonY = y + (self.itemheight - buttonHeight) / 2
    local deleteX = self.width - buttonWidth - scale(5)
    local editX = deleteX - buttonWidth - scale(5)
    
    -- Store button bounds in item for click detection
    item.item.editButton = { x = editX, y = buttonY, w = buttonWidth, h = buttonHeight }
    item.item.deleteButton = { x = deleteX, y = buttonY, w = buttonWidth, h = buttonHeight }
    
    -- Draw Edit button
    self:drawRect(editX, buttonY, buttonWidth, buttonHeight, a, 0.2, 0.4, 0.6)
    self:drawRectBorder(editX, buttonY, buttonWidth, buttonHeight, a, 0.4, 0.6, 0.8)
    self:drawTextCentre("Edit", editX + buttonWidth / 2, buttonY + (buttonHeight - FONT_HGT_SMALL) / 2,
        1, 1, 1, a, UIFont.Small)
    
    -- Draw Delete button
    self:drawRect(deleteX, buttonY, buttonWidth, buttonHeight, a, 0.6, 0.2, 0.2)
    self:drawRectBorder(deleteX, buttonY, buttonWidth, buttonHeight, a, 0.8, 0.4, 0.4)
    self:drawTextCentre("Delete", deleteX + buttonWidth / 2, buttonY + (buttonHeight - FONT_HGT_SMALL) / 2,
        1, 1, 1, a, UIFont.Small)
    
    return y + self.itemheight
end

function WLSP_ConditionsPanel:onConditionListMouseUp(scrollArea, x, y)
    -- Find which row was clicked
    local row = scrollArea:rowAt(x, y)
    if row < 1 or row > #scrollArea.items then
        return false
    end
    
    local item = scrollArea.items[row].item
    if not item then
        return false
    end
    
    -- Calculate the Y position of the row
    local rowY = 0
    for i = 1, row - 1 do
        local v = scrollArea.items[i]
        if not v.height then v.height = scrollArea.itemheight end
        rowY = rowY + v.height
    end
    
    -- Button coordinates
    local buttonWidth = scale(50)
    local buttonHeight = scale(16)
    local buttonY = (scrollArea.itemheight - buttonHeight) / 2
    local deleteX = scrollArea.width - buttonWidth - scale(5)
    local editX = deleteX - buttonWidth - scale(5)
    
    -- Check if Edit button was clicked
    if x >= editX and x <= editX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        if item.type == "timeOfDay" then
            self:onEditTimeOfDayCondition(item.idx)
        elseif item.type == "weather" then
            self:onEditWeatherCondition(item.idx)
        elseif item.type == "playerCount" then
            self:onEditPlayerCountCondition(item.idx)
        elseif item.type == "zombieCount" then
            self:onEditZombieCountCondition(item.idx)
        end
        return true
    end
    
    -- Check if Delete button was clicked
    if x >= deleteX and x <= deleteX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        if item.type == "timeOfDay" then
            self:onDeleteTimeOfDayCondition(item.idx)
        elseif item.type == "weather" then
            self:onDeleteWeatherCondition(item.idx)
        elseif item.type == "playerCount" then
            self:onDeletePlayerCountCondition(item.idx)
        elseif item.type == "zombieCount" then
            self:onDeleteZombieCountCondition(item.idx)
        end
        return true
    end
    
    return false
end

-- Time of Day Condition
function WLSP_ConditionsPanel:onAddTimeOfDayCondition()
    self:showTimeOfDayConditionDialog(nil)
end

function WLSP_ConditionsPanel:onEditTimeOfDayCondition(idx)
    self:showTimeOfDayConditionDialog(idx)
end

function WLSP_ConditionsPanel:onDeleteTimeOfDayCondition(idx)
    WL_Dialogs.showConfirmationDialog("Delete this time of day condition?", function()
        table.remove(self.timeOfDayConditions, idx)
        self:refreshConditionLists()
    end)
end

function WLSP_ConditionsPanel:showTimeOfDayConditionDialog(editIdx)
    local width = scale(350)
    local height = scale(200)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))
    local vstack = win:makeVerticalStack(scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Time of Day Condition" or "Add Time of Day Condition", UIFont.Medium, COLOR_YELLOW, "left")
    
    -- Start/End hours
    local timeRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local startL, startF, endL, endF = timeRow:cols({ 0.2, 0.3, 0.2, 0.3 }, scale(5))
    startL:makeLabel("Start:", UIFont.Small, COLOR_WHITE, "left")
    local startInput = startF:makeTextBox("0", true)
    endL:makeLabel("End:", UIFont.Small, COLOR_WHITE, "left")
    local endInput = endF:makeTextBox("23", true)
    
    -- Load existing data if editing
    if editIdx and self.timeOfDayConditions[editIdx] then
        local condition = self.timeOfDayConditions[editIdx]
        startInput:setText(tostring(condition.startHour))
        endInput:setText(tostring(condition.endHour))
    end
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, scale(5))
    okBtn:makeButton("OK", dialog, function()
        local startHour = tonumber(startInput:getText()) or 0
        local endHour = tonumber(endInput:getText()) or 23
        
        if startHour < 0 or startHour > 23 or endHour < 0 or endHour > 23 then
            WL_Dialogs.showMessageDialog("Hours must be between 0 and 23")
            return
        end
        
        local condition = {
            type = "timeOfDay",
            enabled = true,
            startHour = startHour,
            endHour = endHour
        }
        
        if editIdx then
            self.timeOfDayConditions[editIdx] = condition
        else
            table.insert(self.timeOfDayConditions, condition)
        end
        
        self:refreshConditionLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

-- Weather Condition
function WLSP_ConditionsPanel:onAddWeatherCondition()
    self:showWeatherConditionDialog(nil)
end

function WLSP_ConditionsPanel:onEditWeatherCondition(idx)
    self:showWeatherConditionDialog(idx)
end

function WLSP_ConditionsPanel:onDeleteWeatherCondition(idx)
    WL_Dialogs.showConfirmationDialog("Delete this weather condition?", function()
        table.remove(self.weatherConditions, idx)
        self:refreshConditionLists()
    end)
end

function WLSP_ConditionsPanel:showWeatherConditionDialog(editIdx)
    local width = scale(400)
    local height = scale(300)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))
    local vstack = win:makeVerticalStack(scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Weather Condition" or "Add Weather Condition", UIFont.Medium, COLOR_YELLOW, "left")
    
    -- Rain Min/Max
    local rainRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local rainMinL, rainMinF, rainMaxL, rainMaxF = rainRow:cols({ 0.2, 0.3, 0.2, 0.3 }, scale(5))
    rainMinL:makeLabel("Rain Min:", UIFont.Small, COLOR_WHITE, "left")
    local rainMinInput = rainMinF:makeTextBox("", true)
    rainMaxL:makeLabel("Max:", UIFont.Small, COLOR_WHITE, "left")
    local rainMaxInput = rainMaxF:makeTextBox("", true)
    
    -- Fog Min/Max
    local fogRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local fogMinL, fogMinF, fogMaxL, fogMaxF = fogRow:cols({ 0.2, 0.3, 0.2, 0.3 }, scale(5))
    fogMinL:makeLabel("Fog Min:", UIFont.Small, COLOR_WHITE, "left")
    local fogMinInput = fogMinF:makeTextBox("", true)
    fogMaxL:makeLabel("Max:", UIFont.Small, COLOR_WHITE, "left")
    local fogMaxInput = fogMaxF:makeTextBox("", true)
    
    -- Snow
    local snowRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local snowL, snowReq, snowPro = snowRow:cols({ 0.3, 0.35, 0.35 }, scale(5))
    snowL:makeLabel("Snow:", UIFont.Small, COLOR_WHITE, "left")
    local snowRequireCheck = snowReq:makeTickBox(dialog, function()
        if snowRequireCheck:isSelected(1) then
            snowProhibitCheck:setSelected(1, false)
        end
    end)
    snowRequireCheck:addOption("")
    snowReq:offset(scale(25), 0):makeLabel("Require", UIFont.Small, COLOR_WHITE, "left")
    local snowProhibitCheck = snowPro:makeTickBox(dialog, function()
        if snowProhibitCheck:isSelected(1) then
            snowRequireCheck:setSelected(1, false)
        end
    end)
    snowProhibitCheck:addOption("")
    snowPro:offset(scale(25), 0):makeLabel("Prohibit", UIFont.Small, COLOR_WHITE, "left")
    
    -- Load existing data if editing
    if editIdx and self.weatherConditions[editIdx] then
        local condition = self.weatherConditions[editIdx]
        rainMinInput:setText(condition.rainMin and tostring(condition.rainMin) or "")
        rainMaxInput:setText(condition.rainMax and tostring(condition.rainMax) or "")
        fogMinInput:setText(condition.fogMin and tostring(condition.fogMin) or "")
        fogMaxInput:setText(condition.fogMax and tostring(condition.fogMax) or "")
        snowRequireCheck:setSelected(1, condition.requireSnow or false)
        snowProhibitCheck:setSelected(1, condition.prohibitSnow or false)
    end
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, scale(5))
    okBtn:makeButton("OK", dialog, function()
        local condition = {
            type = "weather",
            enabled = true
        }
        
        local rainMinText = rainMinInput:getText()
        local rainMaxText = rainMaxInput:getText()
        local fogMinText = fogMinInput:getText()
        local fogMaxText = fogMaxInput:getText()
        
        if rainMinText and rainMinText ~= "" then
            condition.rainMin = tonumber(rainMinText)
        end
        if rainMaxText and rainMaxText ~= "" then
            condition.rainMax = tonumber(rainMaxText)
        end
        if fogMinText and fogMinText ~= "" then
            condition.fogMin = tonumber(fogMinText)
        end
        if fogMaxText and fogMaxText ~= "" then
            condition.fogMax = tonumber(fogMaxText)
        end
        if snowRequireCheck:isSelected(1) then
            condition.requireSnow = true
        end
        if snowProhibitCheck:isSelected(1) then
            condition.prohibitSnow = true
        end
        
        if editIdx then
            self.weatherConditions[editIdx] = condition
        else
            table.insert(self.weatherConditions, condition)
        end
        
        self:refreshConditionLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

-- Player Count Condition
function WLSP_ConditionsPanel:onAddPlayerCountCondition()
    self:showPlayerCountConditionDialog(nil)
end

function WLSP_ConditionsPanel:onEditPlayerCountCondition(idx)
    self:showPlayerCountConditionDialog(idx)
end

function WLSP_ConditionsPanel:onDeletePlayerCountCondition(idx)
    WL_Dialogs.showConfirmationDialog("Delete this player count condition?", function()
        table.remove(self.playerCountConditions, idx)
        self:refreshConditionLists()
    end)
end

function WLSP_ConditionsPanel:showPlayerCountConditionDialog(editIdx)
    local width = scale(400)
    local height = scale(250)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))
    local vstack = win:makeVerticalStack(scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Player Count Condition" or "Add Player Count Condition", UIFont.Medium, COLOR_YELLOW, "left")
    
    -- Check Type
    local typeRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local typeL, typeF = typeRow:cols({ 0.3, 0.7 }, scale(10))
    typeL:makeLabel("Check Type:", UIFont.Small, COLOR_WHITE, "left")
    local typeCombo = typeF:makeComboBox()
    typeCombo:addOption("online")
    typeCombo:addOption("rangeSpawner")
    typeCombo:addOption("rangeTarget")
    
    -- Min Count
    local countRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local countL, countF = countRow:cols({ 0.3, 0.7 }, scale(10))
    countL:makeLabel("Min Count:", UIFont.Small, COLOR_WHITE, "left")
    local minCountInput = countF:makeTextBox("1", true)
    
    -- Radius
    local radiusRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local radiusL, radiusF = radiusRow:cols({ 0.3, 0.7 }, scale(10))
    radiusL:makeLabel("Radius:", UIFont.Small, COLOR_WHITE, "left")
    local radiusInput = radiusF:makeTextBox("10", true)
    
    -- Load existing data if editing
    if editIdx and self.playerCountConditions[editIdx] then
        local condition = self.playerCountConditions[editIdx]
        for i = 1, #typeCombo.options do
            if typeCombo:getOptionText(i) == condition.checkType then
                typeCombo.selected = i
                break
            end
        end
        minCountInput:setText(tostring(condition.minCount))
        radiusInput:setText(tostring(condition.radius or 10))
    end
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, scale(5))
    okBtn:makeButton("OK", dialog, function()
        local condition = {
            type = "playerCount",
            enabled = true,
            checkType = typeCombo:getOptionText(typeCombo.selected),
            minCount = tonumber(minCountInput:getText()) or 1
        }
        
        local radiusText = radiusInput:getText()
        if radiusText and radiusText ~= "" then
            condition.radius = tonumber(radiusText)
        end
        
        if editIdx then
            self.playerCountConditions[editIdx] = condition
        else
            table.insert(self.playerCountConditions, condition)
        end
        
        self:refreshConditionLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

-- Zombie Count Condition
function WLSP_ConditionsPanel:onAddZombieCountCondition()
    self:showZombieCountConditionDialog(nil)
end

function WLSP_ConditionsPanel:onEditZombieCountCondition(idx)
    self:showZombieCountConditionDialog(idx)
end

function WLSP_ConditionsPanel:onDeleteZombieCountCondition(idx)
    WL_Dialogs.showConfirmationDialog("Delete this zombie count condition?", function()
        table.remove(self.zombieCountConditions, idx)
        self:refreshConditionLists()
    end)
end

function WLSP_ConditionsPanel:showZombieCountConditionDialog(editIdx)
    local width = scale(400)
    local height = scale(250)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))
    local vstack = win:makeVerticalStack(scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Zombie Count Condition" or "Add Zombie Count Condition", UIFont.Medium, COLOR_YELLOW, "left")
    
    -- Check Type
    local typeRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local typeL, typeF = typeRow:cols({ 0.3, 0.7 }, scale(10))
    typeL:makeLabel("Check Type:", UIFont.Small, COLOR_WHITE, "left")
    local typeCombo = typeF:makeComboBox()
    typeCombo:addOption("spawn")
    typeCombo:addOption("target")
    
    -- Radius
    local radiusRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local radiusL, radiusF = radiusRow:cols({ 0.3, 0.7 }, scale(10))
    radiusL:makeLabel("Radius:", UIFont.Small, COLOR_WHITE, "left")
    local radiusInput = radiusF:makeTextBox("10", true)
    
    -- Max Count
    local countRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local countL, countF = countRow:cols({ 0.3, 0.7 }, scale(10))
    countL:makeLabel("Max Count:", UIFont.Small, COLOR_WHITE, "left")
    local maxCountInput = countF:makeTextBox("50", true)
    
    -- Load existing data if editing
    if editIdx and self.zombieCountConditions[editIdx] then
        local condition = self.zombieCountConditions[editIdx]
        for i = 1, #typeCombo.options do
            if typeCombo:getOptionText(i) == condition.checkType then
                typeCombo.selected = i
                break
            end
        end
        radiusInput:setText(tostring(condition.radius))
        maxCountInput:setText(tostring(condition.maxCount))
    end
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(FONT_HGT_MEDIUM + scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, scale(5))
    okBtn:makeButton("OK", dialog, function()
        local condition = {
            type = "zombieCount",
            enabled = true,
            checkType = typeCombo:getOptionText(typeCombo.selected),
            radius = tonumber(radiusInput:getText()) or 10,
            maxCount = tonumber(maxCountInput:getText()) or 50
        }
        
        if editIdx then
            self.zombieCountConditions[editIdx] = condition
        else
            table.insert(self.zombieCountConditions, condition)
        end
        
        self:refreshConditionLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

function WLSP_ConditionsPanel:loadData(spawner)
    if spawner and spawner.conditions then
        -- Separate conditions by type
        self.timeOfDayConditions = {}
        self.weatherConditions = {}
        self.playerCountConditions = {}
        self.zombieCountConditions = {}
        
        for _, condition in ipairs(spawner.conditions) do
            if condition.type == "timeOfDay" then
                table.insert(self.timeOfDayConditions, {
                    type = condition.type,
                    enabled = condition.enabled or true,
                    startHour = condition.startHour or 0,
                    endHour = condition.endHour or 23
                })
            elseif condition.type == "weather" then
                table.insert(self.weatherConditions, {
                    type = condition.type,
                    enabled = condition.enabled or true,
                    rainMin = condition.rainMin,
                    rainMax = condition.rainMax,
                    requireSnow = condition.requireSnow,
                    prohibitSnow = condition.prohibitSnow,
                    fogMin = condition.fogMin,
                    fogMax = condition.fogMax
                })
            elseif condition.type == "playerCount" then
                table.insert(self.playerCountConditions, {
                    type = condition.type,
                    enabled = condition.enabled or true,
                    checkType = condition.checkType or "online",
                    minCount = condition.minCount or 1,
                    radius = condition.radius
                })
            elseif condition.type == "zombieCount" then
                table.insert(self.zombieCountConditions, {
                    type = condition.type,
                    enabled = condition.enabled or true,
                    checkType = condition.checkType or "spawn",
                    radius = condition.radius or 10,
                    maxCount = condition.maxCount or 50
                })
            end
        end
        
        self.enableCheckbox:setSelected(1, true)
        
        -- Set condition mode
        local mode = spawner.conditionMode or "AND"
        if mode == "AND" then
            self.conditionModeCombo.selected = 1
        elseif mode == "OR" then
            self.conditionModeCombo.selected = 2
        end
    else
        -- Defaults for new spawner
        self.timeOfDayConditions = {}
        self.weatherConditions = {}
        self.playerCountConditions = {}
        self.zombieCountConditions = {}
        self.enableCheckbox:setSelected(1, false)
        self.conditionModeCombo.selected = 1
    end
    
    self:updateConditionsVisibility()
    self:refreshConditionLists()
end

function WLSP_ConditionsPanel:getData()
    local data = {}
    
    if self.enableCheckbox:isSelected(1) and 
       (#self.timeOfDayConditions > 0 or #self.weatherConditions > 0 or 
        #self.playerCountConditions > 0 or #self.zombieCountConditions > 0) then
        data.conditions = {}
        
        -- Add all conditions
        for _, condition in ipairs(self.timeOfDayConditions) do
            table.insert(data.conditions, condition)
        end
        for _, condition in ipairs(self.weatherConditions) do
            table.insert(data.conditions, condition)
        end
        for _, condition in ipairs(self.playerCountConditions) do
            table.insert(data.conditions, condition)
        end
        for _, condition in ipairs(self.zombieCountConditions) do
            table.insert(data.conditions, condition)
        end
        
        -- Set condition mode
        if self.conditionModeCombo.selected == 1 then
            data.conditionMode = "AND"
        elseif self.conditionModeCombo.selected == 2 then
            data.conditionMode = "OR"
        end
    end
    
    return data
end