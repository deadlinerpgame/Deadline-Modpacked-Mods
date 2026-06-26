---
--- TriggersPanel.lua
--- Triggers panel for spawner configuration
---

WLSP_TriggersPanel = ISPanel:derive("WLSP_TriggersPanel")

function WLSP_TriggersPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o.timeTriggers = {}
    o.areaTriggers = {}
    o:initialise()
    return o
end

function WLSP_TriggersPanel:initialise()
    ISPanel.initialise(self)
    
    -- Store conditional UI elements for show/hide
    self.triggerElements = {}
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16))

    local vstack = win:makeVerticalStack(WLSP_UI_Constants.scale(8))

    -- Title
    local titleRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_LARGE)
    titleRow:makeLabel("Triggers", UIFont.Large, WLSP_UI_Constants.COLOR_WHITE, "left")

    -- Enable Triggers Checkbox
    local enableHeaderRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    local enableCheck, _ = enableHeaderRow:cols({ WLSP_UI_Constants.scale(30), 1 }, WLSP_UI_Constants.scale(5))
    self.enableCheckbox = enableCheck:makeTickBox(self, self.onTriggersCheckChanged)
    self.enableCheckbox:addOption("")
    enableHeaderRow:offset(WLSP_UI_Constants.scale(35), 0):makeLabel("Enable Triggers", UIFont.Medium, WLSP_UI_Constants.COLOR_HEADER, "left")
    
    -- Trigger Mode (OR/AND)
    local modeRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local modeLabel, modeField = modeRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    table.insert(self.triggerElements, modeLabel:makeLabel("Trigger Mode:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left"))
    self.triggerModeCombo = modeField:makeComboBox()
    table.insert(self.triggerElements, self.triggerModeCombo)
    self.triggerModeCombo:addOption("OR (any trigger)")
    self.triggerModeCombo:addOption("AND (all triggers)")
    
    -- All Triggers Section
    local triggersHeaderRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    local triggersHeaderLabel = triggersHeaderRow:makeLabel("All Triggers", UIFont.Medium, WLSP_UI_Constants.COLOR_HEADER, "left")
    table.insert(self.triggerElements, triggersHeaderLabel)
    
    -- Reserve space for triggers list
    local listHeight = WLSP_UI_Constants.scale(200)
    local listPlaceholder = vstack:makeNode(listHeight)
    
    -- Add Trigger Buttons
    local buttonRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local timeAddBtn, areaAddBtn = buttonRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    local timeBtn = timeAddBtn:makeButton("Add Time Trigger", self, self.onAddTimeTrigger)
    local areaBtn = areaAddBtn:makeButton("Add Area Trigger", self, self.onAddAreaTrigger)
    table.insert(self.triggerElements, timeBtn)
    table.insert(self.triggerElements, areaBtn)
    
    -- Create unified scroll area with calculated position
    local listY = triggersHeaderLabel.y + triggersHeaderLabel.height + WLSP_UI_Constants.scale(8)
    self.triggersScrollArea = ISScrollingListBox:new(WLSP_UI_Constants.scale(16), listY, self.width - WLSP_UI_Constants.scale(32), listHeight)
    self.triggersScrollArea:initialise()
    self.triggersScrollArea:instantiate()
    self.triggersScrollArea.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.triggersScrollArea.drawBorder = true
    self.triggersScrollArea.itemheight = WLSP_UI_Constants.FONT_HGT_SMALL + WLSP_UI_Constants.scale(40)
    self.triggersScrollArea.font = UIFont.Small
    self.triggersScrollArea.doDrawItem = WLSP_TriggersPanel.drawTriggerItem
    self.triggersScrollArea.onMouseUp = function(scrollArea, x, y)
        return self:onTriggerListMouseUp(scrollArea, x, y)
    end
    self:addChild(self.triggersScrollArea)
    table.insert(self.triggerElements, self.triggersScrollArea)
    
    self:updateTriggersVisibility()
    self:refreshTriggerLists()
end

function WLSP_TriggersPanel:onTriggersCheckChanged()
    self:updateTriggersVisibility()
end

function WLSP_TriggersPanel:updateTriggersVisibility()
    local visible = self.enableCheckbox:isSelected(1)
    for _, element in ipairs(self.triggerElements) do
        element:setVisible(visible)
    end
end

function WLSP_TriggersPanel:refreshTriggerLists()
    -- Clear scroll area
    self.triggersScrollArea:clear()
    
    -- Populate time triggers
    for idx, trigger in ipairs(self.timeTriggers) do
        self.triggersScrollArea:addItem("time_" .. idx, {type = "time", idx = idx, trigger = trigger})
    end
    
    -- Populate area triggers
    for idx, trigger in ipairs(self.areaTriggers) do
        self.triggersScrollArea:addItem("area_" .. idx, {type = "area", idx = idx, trigger = trigger})
    end
end

function WLSP_TriggersPanel:drawTriggerItem(y, item, alt)
    local a = 0.9
    
    if not item.item then
        return y + self.itemheight
    end
    
    local triggerType = item.item.type
    local idx = item.item.idx
    local trigger = item.item.trigger
    
    -- Background
    self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.1, 0.1, 0.1)
    
    -- Enabled indicator
    local statusColor = trigger.enabled and { r = 0.3, g = 1, b = 0.3 } or { r = 0.5, g = 0.5, b = 0.5 }
    self:drawRect(WLSP_UI_Constants.scale(5), y + WLSP_UI_Constants.scale(5), WLSP_UI_Constants.scale(10), WLSP_UI_Constants.scale(10), a, statusColor.r, statusColor.g, statusColor.b)
    
    -- Draw type-specific content
    if triggerType == "time" then
        -- Type label
        self:drawText("[TIME]", WLSP_UI_Constants.scale(20), y + WLSP_UI_Constants.scale(4), WLSP_UI_Constants.COLOR_HEADER.r, WLSP_UI_Constants.COLOR_HEADER.g, WLSP_UI_Constants.COLOR_HEADER.b, a, UIFont.Small)
        
        -- Times display
        local timesStr = "Times: "
        for i, timeSpec in ipairs(trigger.times) do
            if i > 1 then timesStr = timesStr .. ", " end
            timesStr = timesStr .. string.format("%02d:%02d", timeSpec[1], timeSpec[2])
        end
        self:drawText(timesStr, WLSP_UI_Constants.scale(70), y + WLSP_UI_Constants.scale(4), WLSP_UI_Constants.COLOR_WHITE.r, WLSP_UI_Constants.COLOR_WHITE.g, WLSP_UI_Constants.COLOR_WHITE.b, a, UIFont.Small)
        
        -- Cooldown
        local cooldownMins = math.floor(trigger.cooldown / 60)
        self:drawText("Cooldown: " .. cooldownMins .. "m", WLSP_UI_Constants.scale(20), y + WLSP_UI_Constants.scale(18), 0.8, 0.8, 0.8, a, UIFont.Small)
    elseif triggerType == "area" then
        -- Type label - Use cyan to match trigger highlight
        self:drawText("[AREA]", WLSP_UI_Constants.scale(20), y + WLSP_UI_Constants.scale(4), WLSP_UI_Constants.COLOR_TRIGGER.r, WLSP_UI_Constants.COLOR_TRIGGER.g, WLSP_UI_Constants.COLOR_TRIGGER.b, a, UIFont.Small)
        
        -- Position
        self:drawText(string.format("Pos: (%.1f, %.1f, %.0f)", trigger.position.x, trigger.position.y, trigger.position.z),
            WLSP_UI_Constants.scale(70), y + WLSP_UI_Constants.scale(4), WLSP_UI_Constants.COLOR_WHITE.r, WLSP_UI_Constants.COLOR_WHITE.g, WLSP_UI_Constants.COLOR_WHITE.b, a, UIFont.Small)
        
        -- Details
        self:drawText(string.format("Radius: %.0f  Min Players: %d  Cooldown: %dm",
            trigger.radius, trigger.minPlayers, math.floor(trigger.cooldown / 60)),
            WLSP_UI_Constants.scale(20), y + WLSP_UI_Constants.scale(18), 0.8, 0.8, 0.8, a, UIFont.Small)
    end
    
    -- Draw Edit and Delete buttons on the right
    local buttonWidth = WLSP_UI_Constants.scale(50)
    local buttonHeight = WLSP_UI_Constants.scale(16)
    local buttonY = y + (self.itemheight - buttonHeight) / 2
    local deleteX = self.width - buttonWidth - WLSP_UI_Constants.scale(5)
    local editX = deleteX - buttonWidth - WLSP_UI_Constants.scale(5)
    
    -- Store button bounds in item for click detection
    item.item.editButton = { x = editX, y = buttonY, w = buttonWidth, h = buttonHeight }
    item.item.deleteButton = { x = deleteX, y = buttonY, w = buttonWidth, h = buttonHeight }
    
    -- Draw Edit button
    self:drawRect(editX, buttonY, buttonWidth, buttonHeight, a, 0.2, 0.4, 0.6)
    self:drawRectBorder(editX, buttonY, buttonWidth, buttonHeight, a, 0.4, 0.6, 0.8)
    self:drawTextCentre("Edit", editX + buttonWidth / 2, buttonY + (buttonHeight - WLSP_UI_Constants.FONT_HGT_SMALL) / 2,
        1, 1, 1, a, UIFont.Small)
    
    -- Draw Delete button
    self:drawRect(deleteX, buttonY, buttonWidth, buttonHeight, a, 0.6, 0.2, 0.2)
    self:drawRectBorder(deleteX, buttonY, buttonWidth, buttonHeight, a, 0.8, 0.4, 0.4)
    self:drawTextCentre("Delete", deleteX + buttonWidth / 2, buttonY + (buttonHeight - WLSP_UI_Constants.FONT_HGT_SMALL) / 2,
        1, 1, 1, a, UIFont.Small)
    
    return y + self.itemheight
end

function WLSP_TriggersPanel:onTriggerListMouseUp(scrollArea, x, y)
    -- Find which row was clicked using ISScrollingListBox:rowAt
    local row = scrollArea:rowAt(x, y)
    if row < 1 or row > #scrollArea.items then
        return false
    end
    
    local item = scrollArea.items[row].item
    if not item then
        return false
    end
    
    -- Calculate the Y position of the row (not using scroll offset, rowAt already handles it)
    local rowY = 0
    for i = 1, row - 1 do
        local v = scrollArea.items[i]
        if not v.height then v.height = scrollArea.itemheight end
        rowY = rowY + v.height
    end
    
    -- Button coordinates are relative to the item/row position
    local buttonWidth = WLSP_UI_Constants.scale(50)
    local buttonHeight = WLSP_UI_Constants.scale(16)
    local buttonY = (scrollArea.itemheight - buttonHeight) / 2
    local deleteX = scrollArea.width - buttonWidth - WLSP_UI_Constants.scale(5)
    local editX = deleteX - buttonWidth - WLSP_UI_Constants.scale(5)
    
    -- Check if Edit button was clicked
    if x >= editX and x <= editX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        if item.type == "time" then
            self:onEditTimeTrigger(item.idx)
        elseif item.type == "area" then
            self:onEditAreaTrigger(item.idx)
        end
        return true
    end
    
    -- Check if Delete button was clicked
    if x >= deleteX and x <= deleteX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        if item.type == "time" then
            self:onDeleteTimeTrigger(item.idx)
        elseif item.type == "area" then
            self:onDeleteAreaTrigger(item.idx)
        end
        return true
    end
    
    return false
end

function WLSP_TriggersPanel:onAddTimeTrigger()
    self:showTimeTriggerDialog(nil)
end

function WLSP_TriggersPanel:onEditTimeTrigger(idx)
    self:showTimeTriggerDialog(idx)
end

function WLSP_TriggersPanel:onDeleteTimeTrigger(idx)
    WL_Dialogs.showConfirmationDialog("Delete this time trigger?", function()
        table.remove(self.timeTriggers, idx)
        self:refreshTriggerLists()
    end)
end

function WLSP_TriggersPanel:onAddAreaTrigger()
    self:showAreaTriggerDialog(nil)
end

function WLSP_TriggersPanel:onEditAreaTrigger(idx)
    self:showAreaTriggerDialog(idx)
end

function WLSP_TriggersPanel:onDeleteAreaTrigger(idx)
    WL_Dialogs.showConfirmationDialog("Delete this area trigger?", function()
        table.remove(self.areaTriggers, idx)
        self:refreshTriggerLists()
    end)
end

function WLSP_TriggersPanel:showTimeTriggerDialog(editIdx)
    local width = WLSP_UI_Constants.scale(400)
    local height = WLSP_UI_Constants.scale(350)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16))
    local vstack = win:makeVerticalStack(WLSP_UI_Constants.scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Time Trigger" or "Add Time Trigger", UIFont.Medium, WLSP_UI_Constants.COLOR_HEADER, "left")
    
    -- Hour and Minute inputs
    local timeRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local hourL, hourF, minL, minF = timeRow:cols({ 0.2, 0.3, 0.2, 0.3 }, WLSP_UI_Constants.scale(5))
    hourL:makeLabel("Hour:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local hourInput = hourF:makeTextBox("14", true)
    minL:makeLabel("Minute:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local minuteInput = minF:makeTextBox("0", true)
    
    -- Cooldown
    local cooldownRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local cdLabel, cdField = cooldownRow:cols({ 0.4, 0.6 }, WLSP_UI_Constants.scale(10))
    cdLabel:makeLabel("Cooldown (minutes):", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local cooldownInput = cdField:makeTextBox("60", true)
    
    -- Times list label
    local timesLabelRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_SMALL)
    local timesLabel = timesLabelRow:makeLabel("Configured Times:", UIFont.Small, WLSP_UI_Constants.COLOR_HEADER, "left")
    
    -- Reserve space for times list
    local timesListHeight = WLSP_UI_Constants.scale(100)
    local timesListPlaceholder = vstack:makeNode(timesListHeight)
    
    -- Create times list using ISScrollingListBox
    local timesListY = timesLabel.y + timesLabel.height + WLSP_UI_Constants.scale(4)
    local timesScrollArea = ISScrollingListBox:new(WLSP_UI_Constants.scale(16), timesListY, width - WLSP_UI_Constants.scale(32), timesListHeight)
    timesScrollArea:initialise()
    timesScrollArea:instantiate()
    timesScrollArea.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    timesScrollArea.drawBorder = true
    timesScrollArea.itemheight = WLSP_UI_Constants.FONT_HGT_SMALL + WLSP_UI_Constants.scale(8)
    timesScrollArea.font = UIFont.Small
    dialog:addChild(timesScrollArea)
    
    -- Storage for times
    local timesList = {}
    if editIdx and self.timeTriggers[editIdx] then
        local existingTrigger = self.timeTriggers[editIdx]
        -- Validate times array exists and is valid
        if existingTrigger.times and type(existingTrigger.times) == "table" then
            for _, timeSpec in ipairs(existingTrigger.times) do
                if type(timeSpec) == "table" and #timeSpec >= 2 then
                    table.insert(timesList, {timeSpec[1], timeSpec[2]})
                end
            end
        end
        cooldownInput:setText(tostring(math.floor(existingTrigger.cooldown / 60)))
    end
    
    local function refreshTimesList()
        timesScrollArea:clear()
        for i, timeSpec in ipairs(timesList) do
            timesScrollArea:addItem(string.format("%02d:%02d", timeSpec[1], timeSpec[2]), timeSpec)
        end
    end
    refreshTimesList()
    
    -- Add Time / Clear All buttons
    local addClearRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local addBtn, clearBtn = addClearRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    addBtn:makeButton("Add Time", dialog, function()
        local hour = tonumber(hourInput:getText()) or 0
        local minute = tonumber(minuteInput:getText()) or 0
        if hour >= 0 and hour <= 23 and minute >= 0 and minute <= 59 then
            table.insert(timesList, {hour, minute})
            refreshTimesList()
        else
            WL_Dialogs.showMessageDialog("Invalid time. Hour must be 0-23, minute must be 0-59.")
        end
    end)
    clearBtn:makeButton("Clear All", dialog, function()
        timesList = {}
        refreshTimesList()
    end)
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    okBtn:makeButton("OK", dialog, function()
        if #timesList == 0 then
            WL_Dialogs.showMessageDialog("Please add at least one time.")
            return
        end
        
        local cooldown = (tonumber(cooldownInput:getText()) or 60) * 60 -- Convert to seconds
        
        local trigger = {
            type = "time",
            enabled = true,
            cooldown = cooldown,
            times = timesList
        }
        
        if editIdx then
            self.timeTriggers[editIdx] = trigger
        else
            table.insert(self.timeTriggers, trigger)
        end
        
        self:refreshTriggerLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

function WLSP_TriggersPanel:showAreaTriggerDialog(editIdx)
    local width = WLSP_UI_Constants.scale(400)
    local height = WLSP_UI_Constants.scale(320)
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = ISPanel:new(x, y, width, height)
    dialog:initialise()
    dialog.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    dialog.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    dialog.moveWithMouse = true
    dialog:addToUIManager()
    
    local win = GravyUI.Node(width, height, dialog)
    win = win:pad(WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16))
    local vstack = win:makeVerticalStack(WLSP_UI_Constants.scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM)
    titleRow:makeLabel(editIdx and "Edit Area Trigger" or "Add Area Trigger", UIFont.Medium, WLSP_UI_Constants.COLOR_TRIGGER, "left")
    
    -- Position - 2x normal row height
    local posRow = vstack:makeNode((WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8)) * 2 + WLSP_UI_Constants.scale(5))
    local posLabel, posField = posRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    posLabel:makeLabel("Position:", UIFont.Small, WLSP_UI_Constants.COLOR_TRIGGER, "left")
    self.positionPicker = posField:makePointPicker()
    
    -- Set default position based on spawner or player
    local player = getPlayer()
    if editIdx and self.areaTriggers[editIdx] then
        self.positionPicker:setValue(self.areaTriggers[editIdx].position)
    elseif self.parentPanel and self.parentPanel.spawner and self.parentPanel.spawner.position then
        self.positionPicker:setValue(self.parentPanel.spawner.position)
    elseif player then
        self.positionPicker:setValue({ x = player:getX(), y = player:getY(), z = player:getZ() })
    end
    
    -- Radius
    local radiusRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local radiusL, radiusF = radiusRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    radiusL:makeLabel("Radius (tiles):", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local radiusInput = radiusF:makeTextBox("10", true)
    
    -- Min Players
    local playersRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local playersL, playersF = playersRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    playersL:makeLabel("Min Players:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local minPlayersInput = playersF:makeTextBox("1", true)
    
    -- Cooldown
    local cooldownRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local cdLabel, cdField = cooldownRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    cdLabel:makeLabel("Cooldown (min):", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    local cooldownInput = cdField:makeTextBox("30", true)
    
    -- Load existing data if editing
    if editIdx and self.areaTriggers[editIdx] then
        local trigger = self.areaTriggers[editIdx]
        radiusInput:setText(tostring(trigger.radius))
        minPlayersInput:setText(tostring(trigger.minPlayers))
        cooldownInput:setText(tostring(math.floor(trigger.cooldown / 60)))
    end
    
    -- OK / Cancel buttons
    local buttonRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local okBtn, cancelBtn = buttonRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    okBtn:makeButton("OK", dialog, function()
        local pos = positionPicker:getValue()
        local radius = tonumber(radiusInput:getText()) or 10
        local minPlayers = tonumber(minPlayersInput:getText()) or 1
        local cooldown = (tonumber(cooldownInput:getText()) or 30) * 60 -- Convert to seconds
        
        local trigger = {
            type = "area",
            enabled = true,
            cooldown = cooldown,
            position = { x = pos.x, y = pos.y, z = pos.z },
            radius = radius,
            minPlayers = minPlayers
        }
        
        if editIdx then
            self.areaTriggers[editIdx] = trigger
        else
            table.insert(self.areaTriggers, trigger)
        end
        
        self:refreshTriggerLists()
        dialog:removeFromUIManager()
    end)
    cancelBtn:makeButton("Cancel", dialog, function()
        dialog:removeFromUIManager()
    end)
end

function WLSP_TriggersPanel:loadData(spawner)
    if spawner and spawner.triggers then
        -- Separate triggers by type
        self.timeTriggers = {}
        self.areaTriggers = {}
        
        for _, trigger in ipairs(spawner.triggers) do
            if trigger.type == "time" then
                -- Deep copy to avoid reference issues and validate times array
                local timeTrigger = {
                    type = trigger.type,
                    enabled = trigger.enabled or true,
                    cooldown = trigger.cooldown or 3600,
                    times = {}
                }
                
                -- Validate and copy times array
                if trigger.times and type(trigger.times) == "table" then
                    for _, timeSpec in ipairs(trigger.times) do
                        if type(timeSpec) == "table" and #timeSpec >= 2 then
                            table.insert(timeTrigger.times, {timeSpec[1], timeSpec[2]})
                        end
                    end
                end
                
                -- Only add if we have valid times
                if #timeTrigger.times > 0 then
                    table.insert(self.timeTriggers, timeTrigger)
                end
            elseif trigger.type == "area" then
                -- Deep copy area trigger
                local areaTrigger = {
                    type = trigger.type,
                    enabled = trigger.enabled or true,
                    cooldown = trigger.cooldown or 1800,
                    position = {
                        x = trigger.position.x,
                        y = trigger.position.y,
                        z = trigger.position.z
                    },
                    radius = trigger.radius or 10,
                    minPlayers = trigger.minPlayers or 1
                }
                table.insert(self.areaTriggers, areaTrigger)
            end
        end
        
        self.enableCheckbox:setSelected(1, true)
        
        -- Set trigger mode
        local mode = spawner.triggerMode or "OR"
        if mode == "OR" then
            self.triggerModeCombo.selected = 1
        elseif mode == "AND" then
            self.triggerModeCombo.selected = 2
        end
    else
        -- Defaults for new spawner
        self.timeTriggers = {}
        self.areaTriggers = {}
        self.enableCheckbox:setSelected(1, false)
        self.triggerModeCombo.selected = 1
    end
    
    self:updateTriggersVisibility()
    self:refreshTriggerLists()
end

function WLSP_TriggersPanel:getData()
    local data = {}
    
    if self.enableCheckbox:isSelected(1) and (#self.timeTriggers > 0 or #self.areaTriggers > 0) then
        data.triggers = {}
        
        -- Add all time triggers
        for _, trigger in ipairs(self.timeTriggers) do
            table.insert(data.triggers, trigger)
        end
        
        -- Add all area triggers
        for _, trigger in ipairs(self.areaTriggers) do
            table.insert(data.triggers, trigger)
        end
        
        -- Set trigger mode
        if self.triggerModeCombo.selected == 1 then
            data.triggerMode = "OR"
        elseif self.triggerModeCombo.selected == 2 then
            data.triggerMode = "AND"
        end
    end
    
    return data
end
