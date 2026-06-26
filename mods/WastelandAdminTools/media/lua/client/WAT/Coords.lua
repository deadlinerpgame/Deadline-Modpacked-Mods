WAT_ShowCoords = false
WAT_CoordsPos = "topleft"
WAT_CoordsCell = false

local function ShowCoords()
    WAT_ShowCoords = getPlayer():getModData().WAT_ShowCoords or true
    WAT_CoordsPos = getPlayer():getModData().WAT_CoordsPos or "topleft"
    WAT_CoordsCell = getPlayer():getModData().WAT_CoordsCell or false
    local font = UIFont.AutoNormSmall
    local text = "Cell: 000,000 (000,000)"
    local textWidth = getTextManager():MeasureStringX(font, text)
    local textHeight = getTextManager():MeasureStringY(font, text)
    local WAT_Coords_instance = ISUIElement:new(0, 0, textWidth, textHeight)
    local player = getPlayer()
    local isSinglePlayer = not isClient()
    local lastWatCoordsPos = "topleft"
    function WAT_Coords_instance:updatePosition()
        lastWatCoordsPos = WAT_CoordsPos
        player:getModData().WAT_CoordsPos = WAT_CoordsPos
        if WAT_CoordsPos == "topleft" then
            self:setX(0)
            self:setY(0)
        elseif WAT_CoordsPos == "topright" then
            self:setX(getCore():getScreenWidth() - textWidth)
            self:setY(0)
        elseif WAT_CoordsPos == "bottomleft" then
            self:setX(0)
            self:setY(getCore():getScreenHeight() - textHeight*2)
        elseif WAT_CoordsPos == "bottomright" then
            self:setX(getCore():getScreenWidth() - textWidth)
            self:setY(getCore():getScreenHeight() - textHeight*2)
        end
    end
    function WAT_Coords_instance:render()
        if WAT_ShowCoords and (isSinglePlayer or player:getAccessLevel() ~= "None") then
            local player = getPlayer()
            if WAT_CoordsPos ~= lastWatCoordsPos then
                self:updatePosition()
            end
            local x = math.floor(player:getX())
            local y = math.floor(player:getY())
            local text = "Pos: " .. x .. "," .. y
            self:drawText(text, 0, -2, 1.0, 1.0, 1.0, 1.0, font)

            if WAT_CoordsCell then
                local cellX = math.floor(x / 300)
                local cellY = math.floor(y / 300)
                local cOffsetX = (x - cellX * 300)
                local cOffsetY = y - cellY * 300
                local text2 = "Cell: " .. cellX .. "," .. cellY .. " (" .. cOffsetX .. "," .. cOffsetY .. ")"
                self:drawText(text2, 0, textHeight, 1.0, 1.0, 1.0, 1.0, font)
            end
        end
    end
    WAT_Coords_instance:initialise()
    WAT_Coords_instance:addToUIManager()
    WAT_Coords_instance:updatePosition()
end

Events.OnGameStart.Add(ShowCoords)