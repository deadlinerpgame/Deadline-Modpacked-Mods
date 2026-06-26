require "WL_Utils"

-- create the textures and add the button to the map
ISWorldMap.WLZone_original_createChildren = ISWorldMap.WLZone_original_createChildren or ISWorldMap.createChildren;
function ISWorldMap:createChildren()
    ISWorldMap.WLZone_original_createChildren(self)

	local btnSize = self.texViewIsometric and self.texViewIsometric:getWidth() or 48
    local buttons = self.buttonPanel.joypadButtons

    for _, btn in ipairs(buttons) do
        btn:setX(btn.x + btnSize + 20)
    end

    self.showWlZonesButton = ISButton:new(buttons[1].x - 20 - btnSize, 0, btnSize, btnSize, "Zones", self, ISWorldMap.WLZonesOpenOptions)
    self.showWlZonesButton:setVisible(true)

    table.insert(buttons, 1, self.showWlZonesButton)
    self.buttonPanel:addChild(self.showWlZonesButton)
	self.buttonPanel:insertNewListOfButtons(buttons)

    local btnCount = #buttons
    self.buttonPanel:setX(self.width - 20 - (btnSize * btnCount + 20 * (btnCount - 1)))
    self.buttonPanel:setWidth(btnSize * btnCount + 20 * (btnCount - 1))

    self.wlCategories = {}
end

ISWorldMap.WLZone_original_render = ISWorldMap.WLZone_original_render or ISWorldMap.render;
function ISWorldMap:render()
    ISWorldMap.WLZone_original_render(self)

    -- show the button only if we're not in isometric mode
    if self.showWlZonesButton:isVisible() then
        if not WL_Utils.canModerate(getPlayer()) or self.isometric then
            self.showWlZonesButton:setVisible(false)
        end
    else
        if WL_Utils.canModerate(getPlayer()) and not self.isometric then
            self.showWlZonesButton:setVisible(true)
        end
    end

    if self.isometric then return end

    local minx = math.max(self.mapAPI:uiToWorldX(0, 0), self.mapAPI:getMinXInSquares())
    local miny = math.max(self.mapAPI:uiToWorldY(0, 0), self.mapAPI:getMinYInSquares())
    local maxx = math.min(self.mapAPI:uiToWorldX(self.width, self.height), self.mapAPI:getMaxXInSquares())
    local maxy = math.min(self.mapAPI:uiToWorldY(self.width, self.height), self.mapAPI:getMaxYInSquares())

    local rects = {}
    local texts = {}

    local textHeight = getTextManager():getFontHeight(UIFont.Medium)

    for _, zone in ipairs(WL_Zone.allZones) do
        local x = zone.minX
        local y = zone.minY
        local x2 = zone.maxX
        local y2 = zone.maxY

        local type = zone:getMapType()

        if not zone.mapDisabled and self.wlCategories[type] and x2 >= minx and x <= maxx and y2 >= miny and y <= maxy then
            local title = zone:getMapName()

            local tlX = self.mapAPI:worldToUIX(x, y)
            local tlY = self.mapAPI:worldToUIY(x, y)
            local brX = self.mapAPI:worldToUIX(x2, y2)
            local brY = self.mapAPI:worldToUIY(x2, y2)

            local centerX = tlX + ((brX - tlX) / 2)
            local centerY = tlY + ((brY - tlY) / 2)

            local color = zone:getMapColor()
            if brX - tlX < 20 and brY - tlY < 20 then
                table.insert(rects, {centerX - 2, centerY - 2, 5, 5, 1, color[1], color[2], color[3]})
            else
                table.insert(rects, {tlX, tlY, math.max(1, brX - tlX), math.max(1, brY - tlY), 0.5, color[1], color[2], color[3]})
                for _, text in ipairs(texts) do
                    if text[2] == centerX and text[3] == centerY then
                        centerY = centerY + textHeight + 5
                    end
                end
                table.insert(texts, {title, centerX, centerY, 0, 0, 0, 1, UIFont.Medium})
            end
        end
    end

    for _,v in ipairs(rects) do
        self:drawRect(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end
    for _,v in ipairs(texts) do
        self:drawTextCentre(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end
end

function ISWorldMap:WLZonesOpenOptions(button)
	if self.WlZonesOptionsUI == nil then
		local ui = WLZoneOptionsUI:new(self.width - 300, button.y - 300, self)
		self:addChild(ui)
		ui:setVisible(false)
		self.WlZonesOptionsUI = ui
	end
	if self.WlZonesOptionsUI:isVisible() then
		self.WlZonesOptionsUI:setVisible(false)
		return
	end
	self.WlZonesOptionsUI:synchUI()
	self.WlZonesOptionsUI:setX(math.min(self.width - 20 - self.WlZonesOptionsUI.width, button.parent.x + button.x))
	self.WlZonesOptionsUI:setY(button.parent.y + button.y - self.WlZonesOptionsUI.height)
	self.WlZonesOptionsUI:setVisible(true)
	if JoypadState.players[self.playerNum+1] then
		setJoypadFocus(self.playerNum, self.WlZonesOptionsUI)
	end
end

WLZoneOptionsUI = ISPanelJoypad:derive("WLZoneOptionsIUI")

function WLZoneOptionsUI:new(x, y, map)
	local o = ISPanelJoypad.new(self, x, y, 210, 10)
	o.backgroundColor = {r=0, g=0, b=0, a=1.0}
	o.resizable = false
	o.map = map
    o.currentTop = 5
	return o
end

function WLZoneOptionsUI:synchUI()
    for _, zone in ipairs(WL_Zone.allZones) do
        if self.map.wlCategories[zone.mapType] == nil then
            self.map.wlCategories[zone.mapType] = false
            local tickBox = ISTickBox:new(10, self.currentTop, 200, 20, "", self, WLZoneOptionsUI.onTickBox, zone.mapType)
            tickBox:initialise()
            tickBox:addOption(zone.mapType, nil)
            tickBox:setSelected(1, false)
            self:addChild(tickBox)
            self[zone.mapType] = tickBox
            self.currentTop = self.currentTop + tickBox.height + 5
        end
    end

    self:setHeight(self.currentTop + 5)
end

function WLZoneOptionsUI:onTickBox(index, selected, type)
    self.map.wlCategories[type] = selected
end