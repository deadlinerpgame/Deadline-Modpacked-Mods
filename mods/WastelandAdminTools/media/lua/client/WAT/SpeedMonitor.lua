WAT_SpeedMonitor = WAT_SpeedMonitor or ISUIElement:derive("WAT_SpeedMonitor")

WAT_SpeedMonitor.UPDATE_INTERVAL_MS = 500

function WAT_SpeedMonitor.toggle()
    local player = getPlayer()
    if not player or not WL_Utils.isStaff(player) then
        return
    end

    if WAT_SpeedMonitor.instance then
        WAT_SpeedMonitor.instance:removeFromUIManager()
        WAT_SpeedMonitor.instance = nil
        return
    end

    local instance = WAT_SpeedMonitor:new()
    instance:initialise()
    instance:addToUIManager()
    WAT_SpeedMonitor.instance = instance
end

function WAT_SpeedMonitor:prerender()
    local player = getPlayer()
    if not player then
        return
    end

    if not WL_Utils.isStaff(player) then
        self:removeFromUIManager()
        WAT_SpeedMonitor.instance = nil
        return
    end

    local now = getTimestampMs()
    local currentX = player:getX()
    local currentY = player:getY()

    if not self.sampleTimestamp then
        self.sampleTimestamp = now
        self.sampleX = currentX
        self.sampleY = currentY
    else
        local elapsedMs = now - self.sampleTimestamp
        if elapsedMs >= self.UPDATE_INTERVAL_MS then
            local deltaX = currentX - self.sampleX
            local deltaY = currentY - self.sampleY
            local distance = math.sqrt((deltaX * deltaX) + (deltaY * deltaY))
            self.speedTilesPerSecond = distance / (elapsedMs / 1000)
            self.sampleTimestamp = now
            self.sampleX = currentX
            self.sampleY = currentY
        end
    end

    local speedText = string.format("Speed: %.2f t/s", self.speedTilesPerSecond or 0)
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, speedText)
    local textHeight = getTextManager():getFontHeight(UIFont.Small)
    self:setWidth(textWidth + 12)
    self:setHeight(textHeight + 8)

    self:drawRect(0, 0, self:getWidth(), self:getHeight(), 0.75, 0.1, 0.1, 0.1)
    self:drawRectBorder(0, 0, self:getWidth(), self:getHeight(), 0.9, 1, 1, 1)
    self:drawText(speedText, 6, 4, 1, 1, 1, 1, UIFont.Small)
end

function WAT_SpeedMonitor:new()
    local width = 110
    local height = 24
    local x = getCore():getScreenWidth() - width - 40
    local y = 120
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.speedTilesPerSecond = 0
    o.sampleTimestamp = nil
    o.sampleX = nil
    o.sampleY = nil
    o:setAlwaysOnTop(true)
    return o
end
