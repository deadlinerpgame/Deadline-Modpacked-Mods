if WL_RealTimeEvents and WL_RealTimeEvents._update then
    Events.OnTick.Remove(WL_RealTimeEvents._update)
    WL_RealTimeEvents._update = nil
end

WL_RealTimeEvents = WL_RealTimeEvents or {}

--- @private
WL_RealTimeEvents._callbacks = WL_RealTimeEvents._callbacks or {}

-- Helper functions

--- Adds a callback that will be called every second.
--- @param callback function
function WL_RealTimeEvents.EverySecond(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(1, callback)
end

--- Adds a callback that will be called every X seconds.
--- @param seconds number
--- @param callback function
function WL_RealTimeEvents.EveryXSeconds(seconds, callback)
    if type(seconds) ~= "number" or seconds <= 0 then
        error("Invalid seconds: " .. tostring(seconds))
    end
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(seconds, callback)
end

--- Adds a callback that will be called every minute.
--- @param callback function
function WL_RealTimeEvents.EveryMinute(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(60, callback)
end

--- Adds a callback that will be called every X minutes.
--- @param minutes number
function WL_RealTimeEvents.EveryXMinutes(minutes, callback)
    if type(minutes) ~= "number" or minutes <= 0 then
        error("Invalid minutes: " .. tostring(minutes))
    end
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(minutes * 60, callback)
end

--- Adds a callback that will be called every hour.
--- @param callback function
function WL_RealTimeEvents.EveryHour(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(3600, callback)
end

--- Adds a callback that will be called every X hours.
--- @param hours number
--- @param callback function
function WL_RealTimeEvents.EveryXHours(hours, callback)
    if type(hours) ~= "number" or hours <= 0 then
        error("Invalid hours: " .. tostring(hours))
    end
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(hours * 3600, callback)
end

--- Adds a callback that will be called every day at UTC Midnight.
--- @param callback function
function WL_RealTimeEvents.EveryDay(callback)
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(86400, callback)
end

--- Adds a callback that will be called every X days at UTC Midnight.
--- @param days number
--- @param callback function
function WL_RealTimeEvents.EveryXDays(days, callback)
    if type(days) ~= "number" or days <= 0 then
        error("Invalid days: " .. tostring(days))
    end
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    WL_RealTimeEvents._add(days * 86400, callback)
end

--- Removes a callback from the list of real-time events.
--- @param callback function
function WL_RealTimeEvents.Remove(callback)
    for i = #WL_RealTimeEvents._callbacks, 1, -1 do
        if WL_RealTimeEvents._callbacks[i].callback == callback then
            table.remove(WL_RealTimeEvents._callbacks, i)
            return
        end
    end
end

-- private functions
local lastTs = 0

--- Adds a callback with a specific interval in seconds.
--- @private
--- @param intervalInSeconds number
--- @param callback function
function WL_RealTimeEvents._add(intervalInSeconds, callback)
    if type(intervalInSeconds) ~= "number" or intervalInSeconds <= 0 then
        error("Invalid interval: " .. tostring(intervalInSeconds))
    end
    if type(callback) ~= "function" then
        error("Callback must be a function")
    end
    table.insert(WL_RealTimeEvents._callbacks, {interval = intervalInSeconds, callback = callback})
end

--- Updates the real-time events every tick.
--- @private
function WL_RealTimeEvents._update()
    local currentTs = WL_Utils.getTimestamp()
    if currentTs == lastTs then
        return
    end
    local deltaTs = currentTs - lastTs -- should always be 1, but could lag
    lastTs = currentTs
    for _, event in ipairs(WL_RealTimeEvents._callbacks) do
        local isOn = (currentTs % event.interval) < deltaTs
        if isOn then
            event.callback()
        end
    end
end

Events.OnTick.Add(WL_RealTimeEvents._update)