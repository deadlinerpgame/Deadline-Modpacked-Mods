require "WL_Utils"

-- create the textures and add the button to the map
ISWorldMap.SafehouseMap_original_createChildren = ISWorldMap.SafehouseMap_original_createChildren or ISWorldMap.createChildren;
function ISWorldMap:createChildren()
    ISWorldMap.SafehouseMap_original_createChildren(self)

	local btnSize = self.texViewIsometric and self.texViewIsometric:getWidth() or 48
    local buttons = self.buttonPanel.joypadButtons

    for _, btn in ipairs(buttons) do
        btn:setX(btn.x + btnSize + 20)
    end

    self.onShowSafehousesButton = ISButton:new(buttons[1].x - 20 - btnSize, 0, btnSize, btnSize, "SH", self, ISWorldMap.onShowSafehousesClick)
    self.onShowSafehousesButton:setVisible(true)

    table.insert(buttons, 1, self.onShowSafehousesButton)
    self.buttonPanel:addChild(self.onShowSafehousesButton)
	self.buttonPanel:insertNewListOfButtons(buttons)

    local btnCount = #buttons
    self.buttonPanel:setX(self.width - 20 - (btnSize * btnCount + 20 * (btnCount - 1)))
    self.buttonPanel:setWidth(btnSize * btnCount + 20 * (btnCount - 1))

    self.onShowSafehouses = false
end

function ISWorldMap:onShowSafehousesClick()
    self.showSafehouses = not self.showSafehouses
end

ISWorldMap.SafehouseMap_original_render = ISWorldMap.SafehouseMap_original_render or ISWorldMap.render;
function ISWorldMap:render()
    ISWorldMap.SafehouseMap_original_render(self)

    -- show the button only if we're not in isometric mode
    if self.onShowSafehousesButton:isVisible() then
        if not WL_Utils.canModerate(getPlayer()) or self.isometric then
            self.showSafehouses = false
            self.onShowSafehousesButton:setVisible(false)
        end
    else
        if WL_Utils.canModerate(getPlayer()) and not self.isometric then
            self.onShowSafehousesButton:setVisible(true)
        end
    end

    if not self.showSafehouses or self.isometric then return end

    local safehouses = SafeHouse.getSafehouseList()

    local minx = math.max(self.mapAPI:uiToWorldX(0, 0), self.mapAPI:getMinXInSquares())
    local miny = math.max(self.mapAPI:uiToWorldY(0, 0), self.mapAPI:getMinYInSquares())
    local maxx = math.min(self.mapAPI:uiToWorldX(self.width, self.height), self.mapAPI:getMaxXInSquares())
    local maxy = math.min(self.mapAPI:uiToWorldY(self.width, self.height), self.mapAPI:getMaxYInSquares())

    local r = 0.3
    local g = 1.0
    local b = 0.3

    local rects = {}
    local texts = {}

    for i=0,safehouses:size()-1 do
        local sh = safehouses:get(i)
        if sh then
            local x = sh:getX()
            local y = sh:getY()
            local x2 = sh:getX2()
            local y2 = sh:getY2()

            if x2 >= minx and x <= maxx and y2 >= miny and y <= maxy then
                local title = sh:getTitle() .. " (".. sh:getOwner() ..")"

                local tlX = self.mapAPI:worldToUIX(x, y)
                local tlY = self.mapAPI:worldToUIY(x, y)
                local brX = self.mapAPI:worldToUIX(x2, y2)
                local brY = self.mapAPI:worldToUIY(x2, y2)

                local centerX = tlX + ((brX - tlX) / 2)
                local centerY = tlY + ((brY - tlY) / 2)


                if brX - tlX < 20 or brY - tlY < 20 then
                    table.insert(rects, {centerX - 2, centerY - 2, 5, 5, 1, r, g, b})
                else
                    table.insert(rects, {tlX, tlY, brX - tlX, brY - tlY, 0.5, r, g, b})
                    table.insert(texts, {title, centerX, centerY, 0, 0, 0, 1, UIFont.Medium})
                end
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
