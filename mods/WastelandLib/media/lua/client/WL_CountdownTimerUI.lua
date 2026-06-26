--- @class WL_CountdownTimerUI : ISUIElement
WL_CountdownTimerUI = ISUIElement:derive("WL_CountdownTimerUI")

-- Static instance
WL_CountdownTimerUI.instance = nil

-- UI configuration
WL_CountdownTimerUI.TIMER_HEIGHT = 30
WL_CountdownTimerUI.TIMER_SPACING = 5
WL_CountdownTimerUI.MIN_WIDTH = 200

function WL_CountdownTimerUI:new()    
    -- Start with minimal size, will be updated dynamically
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    
    o.timersByPosition = {
        [WL_CountdownTimer.POSITION_TOP] = {},
        [WL_CountdownTimer.POSITION_CENTER] = {},
        [WL_CountdownTimer.POSITION_BOTTOM] = {}
    }
    o.lastUpdate = 0
    
    o:initialise()
    o:setAnchorTop(true)
    
    return o
end

function WL_CountdownTimerUI:initialise()
    ISUIElement.initialise(self)
end

function WL_CountdownTimerUI:update()
    -- Update every second
    local currentTime = getTimestampMs()
    if currentTime - self.lastUpdate < 1000 then
        return
    end
    self.lastUpdate = currentTime
    
    -- Get visible timers and organize by position
    self:updateTimers()
end

function WL_CountdownTimerUI:updateTimers()
    if not WL_CountdownTimer then
        self:clearAllTimers()
        return
    end
    
    local player = getPlayer()
    if not player then
        self:clearAllTimers()
        return
    end
    
    -- Clear existing timers
    self:clearAllTimers()
    
    -- Get all visible timers for this player
    local visibleTimers = WL_CountdownTimer:getVisibleTimers(player)
    
    -- Organize timers by position and add remaining time
    for timerId, timer in pairs(visibleTimers) do
        local remaining = WL_CountdownTimer:getRemainingTime(timerId)
        local isExpired = WL_CountdownTimer:isTimerExpired(timerId)
        
        -- Include timer if it has time remaining OR if it's expired but shouldn't auto-remove
        if (remaining and remaining > 0) or (isExpired and not timer.autoRemove) then
            timer.remaining = remaining or 0
            timer.isExpired = isExpired
            timer.timerId = timerId -- Store the ID for reference
            
            local position = timer.position or WL_CountdownTimer.POSITION_TOP
            table.insert(self.timersByPosition[position], timer)
        end
    end
    
    -- Sort timers within each position by remaining time (shortest first)
    for position, timers in pairs(self.timersByPosition) do
        table.sort(timers, function(a, b)
            return a.remaining < b.remaining
        end)
    end
end

function WL_CountdownTimerUI:clearAllTimers()
    for position, _ in pairs(self.timersByPosition) do
        self.timersByPosition[position] = {}
    end
end

function WL_CountdownTimerUI:hasActiveTimers()
    for position, timers in pairs(self.timersByPosition) do
        if #timers > 0 then
            return true
        end
    end
    return false
end

function WL_CountdownTimerUI:prerender()
    if not self:hasActiveTimers() then
        return
    end
    
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    
    -- Draw timers for each position
    self:drawTimersAtPosition(WL_CountdownTimer.POSITION_TOP, screenWidth, screenHeight)
    self:drawTimersAtPosition(WL_CountdownTimer.POSITION_CENTER, screenWidth, screenHeight)
    self:drawTimersAtPosition(WL_CountdownTimer.POSITION_BOTTOM, screenWidth, screenHeight)
end

function WL_CountdownTimerUI:drawTimersAtPosition(position, screenWidth, screenHeight)
    local timers = self.timersByPosition[position]
    if #timers == 0 then
        return
    end
    
    -- Calculate maximum width needed for this position
    local maxWidth = self.MIN_WIDTH
    for _, timer in ipairs(timers) do
        local timeText = WL_CountdownTimer:formatTime(timer.remaining)
        local fullText = timer.text .. " " .. timeText
        local textWidth = getTextManager():MeasureStringX(UIFont.Medium, fullText) + 20
        maxWidth = math.max(maxWidth, textWidth)
    end
    
    -- Calculate total height needed
    local totalHeight = #timers * self.TIMER_HEIGHT + (#timers - 1) * self.TIMER_SPACING
    
    -- Calculate starting position based on screen position
    local startX = screenWidth / 2 - maxWidth / 2
    local startY
    
    local margin = 150

    if position == WL_CountdownTimer.POSITION_TOP then
        startY = margin
    elseif position == WL_CountdownTimer.POSITION_CENTER then
        startY = screenHeight / 2 - totalHeight / 2
    else -- POSITION_BOTTOM
        startY = screenHeight - totalHeight - margin
    end
    
    -- Draw each timer in this position
    for i, timer in ipairs(timers) do
        local yOffset = (i - 1) * (self.TIMER_HEIGHT + self.TIMER_SPACING)
        self:drawTimer(timer, startX, startY + yOffset, maxWidth, self.TIMER_HEIGHT)
    end
end

function WL_CountdownTimerUI:drawTimer(timer, x, y, width, height)
    local timeText = WL_CountdownTimer:formatTime(timer.remaining, timer.isExpired)
    local fullText = timer.text .. " " .. timeText
    
    -- Get timer color (default to white if not specified)
    local r = timer.color and timer.color.r or 1
    local g = timer.color and timer.color.g or 1
    local b = timer.color and timer.color.b or 1
    
    -- Draw background with slight transparency
    self:drawRect(x, y, width, height, 0.7, 0.1, 0.1, 0.1)
    
    -- Draw border with timer color
    self:drawRectBorder(x, y, width, height, 1.0, r, g, b)
    
    -- Draw text centered
    local textY = y + (height - getTextManager():getFontHeight(UIFont.Medium)) / 2
    self:drawTextCentre(fullText, x + width / 2, textY, r, g, b, 1, UIFont.Medium)
    
    -- Draw progress bar if timer has significant time remaining
    if timer.duration and timer.duration > 0 then
        local progress = timer.isExpired and 0 or (timer.remaining / timer.duration)
        local barHeight = 3
        local barY = y + height - barHeight - 2
        local barWidth = width - 4
        
        -- Background bar
        self:drawRect(x + 2, barY, barWidth, barHeight, 0.5, 0.2, 0.2, 0.2)
        
        -- Progress bar (red if expired, normal color if active)
        local progressWidth = barWidth * progress
        if timer.isExpired then
            -- Red bar for expired timers
            self:drawRect(x + 2, barY, barWidth, barHeight, 0.8, 1, 0, 0)
        else
            self:drawRect(x + 2, barY, progressWidth, barHeight, 0.8, r, g, b)
        end
    end
end

function WL_CountdownTimerUI:render()
    -- Update timers periodically
    self:update()
    
    -- Only render if we have active timers
    if self:hasActiveTimers() then
        ISUIElement.render(self)
    end
end

-- Static methods for managing the UI instance
function WL_CountdownTimerUI.show()
    if not WL_CountdownTimerUI.instance then
        WL_CountdownTimerUI.instance = WL_CountdownTimerUI:new()
        WL_CountdownTimerUI.instance:addToUIManager()
    end
    
    WL_CountdownTimerUI.instance:setVisible(true)
end

function WL_CountdownTimerUI.hide()
    if WL_CountdownTimerUI.instance then
        WL_CountdownTimerUI.instance:setVisible(false)
    end
end

function WL_CountdownTimerUI.refresh()
    -- Force refresh of the instance
    if WL_CountdownTimerUI.instance then
        WL_CountdownTimerUI.instance:updateTimers()
    end
end

function WL_CountdownTimerUI.getInstance()
    return WL_CountdownTimerUI.instance
end

function WL_CountdownTimerUI.isVisible()
    return WL_CountdownTimerUI.instance and WL_CountdownTimerUI.instance:getIsVisible()
end

-- Initialize UI when player is ready
Events.OnGameStart.Add(function()
    -- Create and show the UI instance
    WL_CountdownTimerUI.show()
end)