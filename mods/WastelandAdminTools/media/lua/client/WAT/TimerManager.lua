require "WL_CountdownTimer"
require "WL_Utils"

WAT_TimerManager = ISPanel:derive("WAT_TimerManager")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local COLOR_WHITE = {r=1,g=1,b=1,a=1}

function WAT_TimerManager.display()
    if WAT_TimerManager.instance then
        return
    end
    WAT_TimerManager.instance = WAT_TimerManager:new()
    WAT_TimerManager.instance:initialise()
    WAT_TimerManager.instance:addToUIManager()
end

function WAT_TimerManager:new()
    local scale = FONT_HGT_SMALL / 12
    local w = 300 * scale
    local h = 300 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WAT_TimerManager:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local player = getPlayer()

    local win = GravyUI.Node(self.width, self.height, self):pad(5)

    -- Main layout: header, form, timer list, buttons
    local header, body = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - 5}, 5)
    local form, timerList, buttons = body:rows({0.5, 0.4, 0.1}, 5)

    header:makeLabel("Timer Manager", UIFont.Medium, COLOR_WHITE, "center")

    -- Form section for creating new timers
    local textRow, durationRow, autoRemoveRow, positionRow, colorRow, typeRow, localRow = form:rows(7, 5)

    -- Timer text input
    local textLabel, textInput = textRow:cols({0.3, 0.7}, 5)
    textLabel:makeLabel("Text:", UIFont.Small, COLOR_WHITE, "right")
    self.textEntry = textInput:makeTextBox("Event Timer")

    -- Duration input
    local durationLabel, durationInput = durationRow:cols({0.3, 0.7}, 5)
    durationLabel:makeLabel("Duration (sec):", UIFont.Small, COLOR_WHITE, "right")
    self.durationEntry = durationInput:makeTextBox("300", true)

    -- Auto-remove checkbox
    local autoRemoveLabel, autoRemoveCheck = autoRemoveRow:cols({0.3, 0.7}, 5)
    autoRemoveLabel:makeLabel("Auto-remove:", UIFont.Small, COLOR_WHITE, "right")
    self.autoRemoveCheckbox = autoRemoveCheck:makeTickBox()
    self.autoRemoveCheckbox:addOption("")
    self.autoRemoveCheckbox:setSelected(1, true) -- Default to checked

    -- Timer type dropdown
    local typeLabel, typeDropdown = typeRow:cols({0.3, 0.7}, 5)
    typeLabel:makeLabel("Type:", UIFont.Small, COLOR_WHITE, "right")
    self.typeDropdown = typeDropdown:makeComboBox()
    self.typeDropdown:addOption("Global")
    self.typeDropdown:addOption("Local")
    self.typeDropdown.onChange = function() self:onTypeChanged() end

    -- Position dropdown
    local positionLabel, positionDropdown = positionRow:cols({0.3, 0.7}, 5)
    positionLabel:makeLabel("Position:", UIFont.Small, COLOR_WHITE, "right")
    self.positionDropdown = positionDropdown:makeComboBox()
    self.positionDropdown:addOption("Top")
    self.positionDropdown:addOption("Center")
    self.positionDropdown:addOption("Bottom")

    -- Color dropdown
    local colorLabel, colorDropdown = colorRow:cols({0.3, 0.7}, 5)
    colorLabel:makeLabel("Color:", UIFont.Small, COLOR_WHITE, "right")
    self.colorDropdown = colorDropdown:makeComboBox()
    self.colorDropdown:addOption("White")
    self.colorDropdown:addOption("Red")
    self.colorDropdown:addOption("Green")
    self.colorDropdown:addOption("Blue")
    self.colorDropdown:addOption("Yellow")
    self.colorDropdown:addOption("Orange")
    self.colorDropdown:addOption("Purple")

    -- Local timer settings
    local xLabel, xInput, yLabel, yInput, rangeLabel, rangeInput = localRow:cols({0.1, 0.2, 0.1, 0.2, 0.15, 0.25}, 5)
    self.xLabel = xLabel:makeLabel("X:", UIFont.Small, COLOR_WHITE, "right")
    self.xEntry = xInput:makeTextBox(tostring(math.floor(player:getX())), true)
    self.yLabel = yLabel:makeLabel("Y:", UIFont.Small, COLOR_WHITE, "right")
    self.yEntry = yInput:makeTextBox(tostring(math.floor(player:getY())), true)
    self.rangeLabel = rangeLabel:makeLabel("Range:", UIFont.Small, COLOR_WHITE, "right")
    self.rangeEntry = rangeInput:makeTextBox("50", true)

    -- Timer list
    self.timerListBox = timerList:makeScrollingListBox()
    self.timerListBox.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.8}

    -- Buttons
    local createButton, deleteButton, refreshButton = buttons:cols(3, 5)
    self.createButton = createButton:makeButton("Create Timer", self, self.createTimer)
    self.createButton.backgroundColor = {r=0,g=0.5,b=0,a=1}

    self.deleteButton = deleteButton:makeButton("Delete Timer", self, self.deleteTimer)
    self.deleteButton.backgroundColor = {r=0.5,g=0,b=0,a=1}

    self.refreshButton = refreshButton:makeButton("Refresh List", self, self.refreshTimerList)
    self.refreshButton.backgroundColor = {r=0,g=0,b=0.5,a=1}

    -- Close button
    win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3):offset(4, -4):makeButton("X", self, self.onClose)

    -- Initialize UI state
    self:onTypeChanged()
    self:refreshTimerList()
end

function WAT_TimerManager:onTypeChanged()
    local isLocal = self.typeDropdown:getOptionText(self.typeDropdown.selected) == "Local"
    
    -- Enable/disable local timer controls
    self.xEntry:setEditable(isLocal)
    self.yEntry:setEditable(isLocal)
    self.rangeEntry:setEditable(isLocal)
    if isLocal then
        self.xEntry:setText(tostring(math.floor(getPlayer():getX())))
        self.yEntry:setText(tostring(math.floor(getPlayer():getY())))
        self.rangeEntry:setText("50")
    else
        self.xEntry:setText("")
        self.yEntry:setText("")
        self.rangeEntry:setText("")
    end
    
    -- Update label colors to indicate enabled/disabled state
    local labelColor = isLocal and COLOR_WHITE or {r=0.5, g=0.5, b=0.5, a=1}
    self.xLabel.color = labelColor
    self.yLabel.color = labelColor
    self.rangeLabel.color = labelColor
end

function WAT_TimerManager:getColorFromSelection()
    local colorName = self.colorDropdown:getOptionText(self.colorDropdown.selected)
    local colors = {
        ["White"] = {r=1, g=1, b=1},
        ["Red"] = {r=1, g=0, b=0},
        ["Green"] = {r=0, g=1, b=0},
        ["Blue"] = {r=0.2, g=0.2, b=1},
        ["Yellow"] = {r=1, g=1, b=0},
        ["Orange"] = {r=1, g=0.5, b=0},
        ["Purple"] = {r=1, g=0, b=1}
    }
    return colors[colorName] or colors["White"]
end

function WAT_TimerManager:getPositionFromSelection()
    local positionName = self.positionDropdown:getOptionText(self.positionDropdown.selected)
    local positions = {
        ["Top"] = WL_CountdownTimer.POSITION_TOP,
        ["Center"] = WL_CountdownTimer.POSITION_CENTER,
        ["Bottom"] = WL_CountdownTimer.POSITION_BOTTOM
    }
    return positions[positionName] or WL_CountdownTimer.POSITION_TOP
end

function WAT_TimerManager:generateTimerId()
    local random = ZombRand(100000000, 999999999)
    return "manual_" .. random
end

function WAT_TimerManager:createTimer()
    local text = self.textEntry:getText()
    local duration = tonumber(self.durationEntry:getText())
    
    if not text or text == "" then
        getPlayer():Say("Timer text cannot be empty!")
        return
    end
    
    if not duration or duration <= 0 then
        getPlayer():Say("Duration must be a positive number!")
        return
    end

    local config = {
        id = self:generateTimerId(),
        text = text,
        duration = duration,
        color = self:getColorFromSelection(),
        position = self:getPositionFromSelection(),
        autoRemove = self.autoRemoveCheckbox:isSelected(1)
    }

    local isLocal = self.typeDropdown:getOptionText(self.typeDropdown.selected) == "Local"
    if isLocal then
        local x = tonumber(self.xEntry:getText())
        local y = tonumber(self.yEntry:getText())
        local range = tonumber(self.rangeEntry:getText())
        
        if not x or not y or not range or range <= 0 then
            getPlayer():Say("Local timer requires valid coordinates and range!")
            return
        end
        
        config.locationType = WL_CountdownTimer.LOCATION_LOCAL
        config.x = x
        config.y = y
        config.range = range
    else
        config.locationType = WL_CountdownTimer.LOCATION_GLOBAL
    end

    WL_CountdownTimer:createTimer(config, getPlayer())
    getPlayer():Say("Timer created: " .. config.id)
    
    -- Refresh the list after a short delay to allow server sync
    self:scheduleRefresh()
end

function WAT_TimerManager:deleteTimer()
    local selected = self.timerListBox.selected
    if selected <= 0 then
        getPlayer():Say("Please select a timer to delete!")
        return
    end
    
    local timerData = self.timerListBox.items[selected].item
    if timerData and timerData.timerId then
        WL_CountdownTimer:removeTimer(timerData.timerId, getPlayer())
        getPlayer():Say("Timer deleted: " .. timerData.timerId)
        
        -- Refresh the list after a short delay to allow server sync
        self:scheduleRefresh()
    end
end

function WAT_TimerManager.scheduledRefreshCheck()
    if WAT_TimerManager.refreshDelay > 0 then
        WAT_TimerManager.refreshDelay = WAT_TimerManager.refreshDelay - 1
        return
    end
    if WAT_TimerManager.instance then
        WAT_TimerManager.instance:refreshTimerList()
    end
    Events.OnTick.Remove(WAT_TimerManager.scheduledRefreshCheck)
end

function WAT_TimerManager:scheduleRefresh()
    -- Schedule a refresh in 1 second to allow server sync
    WAT_TimerManager.refreshDelay = 60 -- 1 second in game ticks (60 ticks per second)
    Events.OnTick.Remove(WAT_TimerManager.scheduledRefreshCheck)
    Events.OnTick.Add(WAT_TimerManager.scheduledRefreshCheck)
end

function WAT_TimerManager:refreshTimerList()
    print("Refreshing timer list...")
    self.timerListBox:clear()
    
    local allTimers = WL_CountdownTimer:getActiveTimers()
    local manualTimers = {}
    
    -- Filter for manual timers only
    for timerId, timer in pairs(allTimers) do
        if string.sub(timerId, 1, 7) == "manual_" then
            table.insert(manualTimers, {timerId = timerId, timer = timer})
        end
    end
    
    -- Sort by creation time (newest first)
    table.sort(manualTimers, function(a, b)
        return (a.timer.startTime or 0) > (b.timer.startTime or 0)
    end)
    
    -- Add to list
    for _, data in ipairs(manualTimers) do
        local timer = data.timer
        local remaining = WL_CountdownTimer:getRemainingTime(data.timerId) or 0
        local timeStr = WL_CountdownTimer:formatTime(remaining)
        local typeStr = timer.locationType == WL_CountdownTimer.LOCATION_GLOBAL and "Global" or "Local"
        
        local displayText = string.format("%s [%s] (%s)", timer.text, timeStr, typeStr)
        
        self.timerListBox:addItem(displayText, data)
    end
end

function WAT_TimerManager:onClose()
    self:removeFromUIManager()
    WAT_TimerManager.instance = nil
end
