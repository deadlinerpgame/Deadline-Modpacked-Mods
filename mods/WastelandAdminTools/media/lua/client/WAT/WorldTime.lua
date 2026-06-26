require "WL_Utils"

WAT_WorldTime = WAT_WorldTime or {}

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

local function toNumber(value, fallback)
    local num = tonumber(value)
    if not num then
        return fallback
    end
    return math.floor(num)
end

local function getDefaultTime()
    local gameTime = getGameTime()
    return {
        year = gameTime:getYear(),
        month = gameTime:getMonth() + 1,
        day = gameTime:getDay() + 1,
        hour = gameTime:getHour(),
        minute = gameTime:getMinutes(),
    }
end

local function showError(message)
    local modal = ISModalDialog:new(0, 0, 280, 120, message, false, nil, nil)
    modal:initialise()
    modal:addToUIManager()
end

local function parseInput(entry, fallback)
    return toNumber(entry and entry:getText() or nil, fallback)
end

function WAT_WorldTime.show()
    local defaults = getDefaultTime()
    local width = 320
    local height = 260
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2

    local panel = ISPanel:new(x, y, width, height)
    panel:initialise()
    panel:addToUIManager()
    panel:setVisible(true)
    panel:setAlwaysOnTop(true)

    local title = ISLabel:new(0, 10, 20, "Set World Time", 1, 1, 1, 1, UIFont.Medium)
    title:initialise()
    title:setX((panel.width - title:getWidth()) / 2)
    panel:addChild(title)

    local labelX = 20
    local entryX = 140
    local rowY = 40
    local rowHeight = 28
    local entryWidth = 140
    local entryHeight = 22

    local function addRow(labelText, value)
        local label = ISLabel:new(labelX, rowY, 20, labelText, 1, 1, 1, 1, UIFont.Small, true)
        label:initialise()
        panel:addChild(label)

        local entry = ISTextEntryBox:new(tostring(value), entryX, rowY - 2, entryWidth, entryHeight)
        entry:initialise()
        entry:instantiate()
        entry:setText(tostring(value))
        entry:setOnlyNumbers(true)
        panel:addChild(entry)

        rowY = rowY + rowHeight
        return entry
    end

    local yearEntry = addRow("Year", defaults.year)
    local monthEntry = addRow("Month (1-12)", defaults.month)
    local dayEntry = addRow("Day (1-31)", defaults.day)
    local hourEntry = addRow("Hour (0-23)", defaults.hour)
    local minuteEntry = addRow("Minute (0-59)", defaults.minute)

    local okButton = ISButton:new(width / 2 - 90, height - 35, 80, 25, "Apply", panel, function()
        local year = parseInput(yearEntry, defaults.year)
        local month = parseInput(monthEntry, defaults.month)
        local day = parseInput(dayEntry, defaults.day)
        local hour = parseInput(hourEntry, defaults.hour)
        local minute = parseInput(minuteEntry, defaults.minute)

        year = clamp(year, 0, 9999)
        month = clamp(month, 1, 12)
        day = clamp(day, 1, 31)
        hour = clamp(hour, 0, 23)
        minute = clamp(minute, 0, 59)

        sendClientCommand(getPlayer(), "WAT", "setWorldTime", {
            year = year,
            month = month,
            day = day,
            hour = hour,
            minute = minute,
        })

        panel:removeFromUIManager()
    end)
    okButton:initialise()
    okButton:instantiate()
    panel:addChild(okButton)

    local cancelButton = ISButton:new(width / 2 + 10, height - 35, 80, 25, "Cancel", panel, function()
        panel:removeFromUIManager()
    end)
    cancelButton:initialise()
    cancelButton:instantiate()
    panel:addChild(cancelButton)
end
