require "WL_ClientServerBase"
require "WL_Utils"

--[[
WL_CountdownTimer - Generic Countdown Timer System for WastelandLib

This system provides a robust, client-server synchronized countdown timer system
that supports multiple simultaneous timers with different configurations.

Features:
- Multiple simultaneous timers with unique IDs
- Global timers (visible to all players) and local timers (visible within range)
- Configurable colors, text, and screen positions (top/center/bottom)
- Automatic cleanup of expired timers
- Client-server synchronization via publicData
- Easy-to-use API for other mods

Usage Examples:
-- Create a global timer
local timerId = WL_CountdownTimer:createGlobalTimer("Event Starting", 300, {r=1, g=0, b=0}, "top")

-- Create a local timer
local timerId = WL_CountdownTimer:createLocalTimer("Area Effect", 60, 100, 200, 50, {r=0, g=1, b=0}, "center")

-- Remove a timer
WL_CountdownTimer:removeTimer(timerId)
--]]

--- @class WL_CountdownTimer : WL_ClientServerBase
--- @field publicData table<string, any>
--- @field private _nextTimerId number
WL_CountdownTimer = WL_ClientServerBase:new("WL_CountdownTimer")
WL_CountdownTimer.needsPublicData = true

-- Timer position constants
WL_CountdownTimer.POSITION_TOP = "top"
WL_CountdownTimer.POSITION_CENTER = "center"
WL_CountdownTimer.POSITION_BOTTOM = "bottom"

-- Timer location type constants
WL_CountdownTimer.LOCATION_GLOBAL = "global"
WL_CountdownTimer.LOCATION_LOCAL = "local"

--- @class TimerConfig
--- @field id string Unique identifier for the timer
--- @field text string Display text for the timer
--- @field duration number Duration in seconds
--- @field color table RGB color table {r, g, b} with values 0-1
--- @field position string Position on screen (top/center/bottom)
--- @field locationType string Location type (global/local)
--- @field x number|nil X coordinate for local timers
--- @field y number|nil Y coordinate for local timers
--- @field range number|nil Range for local timers
--- @field autoRemove boolean|nil Whether to auto-remove when expired (default: true)
--- @field startTime number Unix timestamp when timer was created
--- @field endTime number Unix timestamp when timer expires

function WL_CountdownTimer:onModDataInit()
    if not self.publicData then 
        self.publicData = {}
    end
    if not self.publicData.timers then
        self.publicData.timers = {}
    end
    if not self.publicData.nextTimerId then
        self.publicData.nextTimerId = 1
    end
    
    -- Clean up expired timers on server startup
    if isServer() then
        self:cleanupExpiredTimers()
    end
end

--- Creates a new countdown timer
--- @param config TimerConfig Timer configuration
--- @param player IsoPlayer|nil Player creating the timer (for client-side calls)
function WL_CountdownTimer:createTimer(config, player)
    if isClient() then
        -- Client-side call - send to server for processing
        self:sendToServer(player or getPlayer(), "serverCreateTimer", config)
    else
        -- Server-side processing
        self:_createTimerOnServer(config)
    end
end

--- Internal server-side timer creation
--- @param config TimerConfig Timer configuration
--- @return string Timer ID
function WL_CountdownTimer:_createTimerOnServer(config)
    -- Generate unique timer ID
    local timerId = config.id or ("timer_" .. self.publicData.nextTimerId)
    self.publicData.nextTimerId = self.publicData.nextTimerId + 1
    
    -- Validate configuration
    if not config.text or not config.duration then
        self:logError("Invalid timer configuration: missing text or duration")
        return nil
    end
    
    -- Set defaults
    local currentTime = WL_Utils.getTimestamp()
    local timer = {
        id = timerId,
        text = config.text,
        duration = config.duration,
        color = config.color or {r = 1, g = 1, b = 1}, -- Default white
        position = config.position or self.POSITION_TOP,
        locationType = config.locationType or self.LOCATION_GLOBAL,
        x = config.x,
        y = config.y,
        range = config.range,
        autoRemove = config.autoRemove ~= false, -- Default to true unless explicitly set to false
        startTime = currentTime,
        endTime = currentTime + config.duration
    }
    
    -- Validate local timer configuration
    if timer.locationType == self.LOCATION_LOCAL then
        if not timer.x or not timer.y or not timer.range then
            self:logError("Local timer missing coordinates or range")
            return nil
        end
    end
    
    -- Store timer
    self.publicData.timers[timerId] = timer
    self:savePublicData()
    
    self:logInfo("Created timer '" .. timerId .. "' with duration " .. config.duration .. " seconds")
    return timerId
end

--- Server-side command handler for creating timers
--- @param player IsoPlayer Player who sent the command
--- @param config TimerConfig Timer configuration
function WL_CountdownTimer:serverCreateTimer(player, config)
    local timerId = self:_createTimerOnServer(config)
    if timerId then
        -- Send the timer ID back to the requesting client
        self:sendToClient(player, "clientTimerCreated", timerId)
    end
end

--- Removes a timer by ID
--- @param timerId string Timer ID to remove
--- @param player IsoPlayer|nil Player removing the timer (for client-side calls)
function WL_CountdownTimer:removeTimer(timerId, player)
    if isClient() then
        self:sendToServer(player or getPlayer(), "serverRemoveTimer", timerId)
    else
        if self.publicData.timers[timerId] then
            self.publicData.timers[timerId] = nil
            self:savePublicData()
            self:logInfo("Removed timer '" .. timerId .. "'")
        end
    end
end

--- Server-side command handler for removing timers
--- @param player IsoPlayer Player who sent the command
--- @param timerId string Timer ID to remove
function WL_CountdownTimer:serverRemoveTimer(player, timerId)
    if self.publicData.timers[timerId] then
        self.publicData.timers[timerId] = nil
        self:savePublicData()
        self:logInfo("Removed timer '" .. timerId .. "'")
    end
end

--- Gets all active timers
--- @return table<string, TimerConfig> Active timers
function WL_CountdownTimer:getActiveTimers()
    if not self.publicData or not self.publicData.timers then
        return {}
    end
    return self.publicData.timers
end

--- Gets timers visible to a specific player at their current location
--- @param player IsoPlayer Player to check visibility for
--- @return table<string, TimerConfig> Visible timers
function WL_CountdownTimer:getVisibleTimers(player)
    local visibleTimers = {}
    local playerX = player:getX()
    local playerY = player:getY()
    
    for timerId, timer in pairs(self:getActiveTimers()) do
        if self:isTimerVisibleToPlayer(timer, playerX, playerY) then
            visibleTimers[timerId] = timer
        end
    end
    
    return visibleTimers
end

--- Checks if a timer is visible to a player at specific coordinates
--- @param timer TimerConfig Timer to check
--- @param playerX number Player X coordinate
--- @param playerY number Player Y coordinate
--- @return boolean True if timer is visible
function WL_CountdownTimer:isTimerVisibleToPlayer(timer, playerX, playerY)
    if timer.locationType == self.LOCATION_GLOBAL then
        return true
    elseif timer.locationType == self.LOCATION_LOCAL then
        if not timer.x or not timer.y or not timer.range then
            return false
        end
        local distance = WL_Utils.distance2d(playerX, playerY, timer.x, timer.y)
        return distance <= timer.range
    end
    return false
end

--- Gets remaining time for a timer
--- @param timerId string Timer ID
--- @return number|nil Remaining time in seconds, nil if timer doesn't exist
function WL_CountdownTimer:getRemainingTime(timerId)
    local timer = self.publicData.timers and self.publicData.timers[timerId]
    if not timer then
        return nil
    end
    
    local currentTime = WL_Utils.getTimestamp()
    local remaining = timer.endTime - currentTime
    return math.max(0, remaining)
end

--- Checks if a timer has expired
--- @param timerId string Timer ID
--- @return boolean True if timer has expired
function WL_CountdownTimer:isTimerExpired(timerId)
    local remaining = self:getRemainingTime(timerId)
    return remaining ~= nil and remaining <= 0
end

--- Cleans up expired timers (server-side only)
--- Only removes timers that have autoRemove set to true
function WL_CountdownTimer:cleanupExpiredTimers()
    if isClient() then
        return
    end
    
    local currentTime = WL_Utils.getTimestamp()
    local expiredTimers = {}
    
    for timerId, timer in pairs(self.publicData.timers or {}) do
        if timer.endTime <= currentTime and timer.autoRemove then
            table.insert(expiredTimers, timerId)
        end
    end
    
    if #expiredTimers > 0 then
        for _, timerId in ipairs(expiredTimers) do
            self.publicData.timers[timerId] = nil
            self:logInfo("Auto-removed expired timer '" .. timerId .. "'")
        end
        self:savePublicData()
    end
end

--- Formats time as MM:SS or "NOW" for expired timers
--- @param seconds number Time in seconds
--- @param isExpired boolean|nil Whether the timer is expired
--- @return string Formatted time string
function WL_CountdownTimer:formatTime(seconds, isExpired)
    if isExpired or seconds <= 0 then
        return "NOW"
    end
    
    local minutes = math.floor(seconds / 60)
    local secs = seconds % 60
    return string.format("%d:%02d", minutes, secs)
end

--- API method for other mods to create a simple global timer
--- @param id string Unique timer ID
--- @param text string Display text
--- @param duration number Duration in seconds
--- @param color table|nil RGB color {r, g, b}, defaults to white
--- @param position string|nil Position (top/center/bottom), defaults to top
--- @param autoRemove boolean|nil Whether to auto-remove when expired, defaults to true
--- @return string|nil Timer ID
function WL_CountdownTimer:createGlobalTimer(id, text, duration, color, position, autoRemove)
    local config = {
        id = id,
        text = text,
        duration = duration,
        color = color,
        position = position,
        autoRemove = autoRemove,
        locationType = self.LOCATION_GLOBAL
    }
    return self:createTimer(config)
end

--- API method for other mods to create a local timer
--- @param id string Unique timer ID
--- @param text string Display text
--- @param duration number Duration in seconds
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param range number Visibility range
--- @param color table|nil RGB color {r, g, b}, defaults to white
--- @param position string|nil Position (top/center/bottom), defaults to top
--- @param autoRemove boolean|nil Whether to auto-remove when expired, defaults to true
--- @return string|nil Timer ID
function WL_CountdownTimer:createLocalTimer(id, text, duration, x, y, range, color, position, autoRemove)
    local config = {
        id = id,
        text = text,
        duration = duration,
        x = x,
        y = y,
        range = range,
        color = color,
        position = position,
        autoRemove = autoRemove,
        locationType = self.LOCATION_LOCAL
    }
    return self:createTimer(config)
end

-- Client-side event handlers
if isClient() then
    function WL_CountdownTimer:onPublicDataUpdated()
        self:debugPrint("Timer data updated from server")
        -- Notify UI to refresh
        if WL_CountdownTimerUI then
            WL_CountdownTimerUI.refresh()
        end
    end
    
    --- Client-side handler for timer creation confirmation
    --- @param player IsoPlayer Player who created the timer
    --- @param timerId string Timer ID that was created
    function WL_CountdownTimer:clientTimerCreated(player, timerId)
        self:debugPrint("Timer created with ID: " .. timerId)
    end
    
    WL_CountdownTimer:debugPrint("WL_CountdownTimer client initialized")
end

-- Server-side initialization and cleanup
if isServer() then
    WL_CountdownTimer:debugPrint("WL_CountdownTimer server initialized")
    
    -- Periodic cleanup of expired timers
    Events.EveryOneMinute.Add(function()
        WL_CountdownTimer:cleanupExpiredTimers()
    end)
end