WL_MouseCoords = WL_MouseCoords or ISUIElement:derive("WL_MouseCoords")

function WL_MouseCoords.toggle()
    if WL_MouseCoords.instance then
        WL_MouseCoords.instance:removeFromUIManager()
        WL_MouseCoords.instance = nil
    else
        WL_MouseCoords.instance = WL_MouseCoords:new()
        WL_MouseCoords.instance:initialise()
        WL_MouseCoords.instance:addToUIManager()
    end
end

function WL_MouseCoords:prerender()
    local player = getPlayer()
    if not player then return end
    local mouseX, mouseY = getMouseX(), getMouseY()
    local isoX = screenToIsoX(0, mouseX, mouseY, player:getZ())
    local isoY = screenToIsoY(0, mouseX, mouseY, player:getZ())
    local coordsText = string.format("Coords: %d, %d, %d", isoX, isoY, player:getZ())
    local textWidth = getTextManager():MeasureStringX(UIFont.Small, coordsText)
    local textHeight = getTextManager():getFontHeight(UIFont.Small)
    self:setWidth(textWidth + 10) -- add some padding
    self:setHeight(textHeight + 4) -- add some padding

    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    if mouseX > screenWidth/2 then
        self:setX(mouseX - self:getWidth() - 10) -- move to the left side of the screen
    else
        self:setX(mouseX + 20)
    end
    if mouseY > screenHeight/2 then
        self:setY(mouseY - self:getHeight() - 10) -- move to the top of the screen
    else
        self:setY(mouseY + 10)
    end
    
    self:drawRect(0, 0, self:getWidth(), self:getHeight(), 0.1, 0.1, 0.1, 0.8) -- dark background
    self:drawText(coordsText, 5, 2, 1, 1, 1, 1, UIFont.Small) -- white text
end

function WL_MouseCoords:new()
    local o = ISUIElement:new(0, 0, 200, 20)
    setmetatable(o, self)
    self.__index = self
    o:setAlwaysOnTop(true)
    return o
end