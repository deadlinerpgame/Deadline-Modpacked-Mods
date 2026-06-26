require "WRU_Utils"

-- create the textures and add the button to the map
local original_map_createChildren = ISWorldMap.createChildren;
function ISWorldMap:createChildren()
    original_map_createChildren(self)

    self.textureCircle256 = getTexture("media/ui/WRU_Circle256.png")
    self.textureCircle512 = getTexture("media/ui/WRU_Circle512.png")
    self.textureCircle1024 = getTexture("media/ui/WRU_Circle1024.png")
    self.textureCircle1536 = getTexture("media/ui/WRU_Circle1536.png")
    self.textureCircle2048 = getTexture("media/ui/WRU_Circle2048.png")
    self.textureCircle4096 = getTexture("media/ui/WRU_Circle4096.png")


    local btnSize = self.texViewIsometric and self.texViewIsometric:getWidth() or 48
    local buttons = self.buttonPanel.joypadButtons

    for _, btn in ipairs(buttons) do
        btn:setX(btn.x + btnSize + 20)
    end

    self.showRadioRangeButton = ISButton:new(buttons[1].x - 20 - btnSize, 0, btnSize, btnSize, "Radios", self, ISWorldMap.onShowRadioRangeClick)
    self.showRadioRangeButton:setVisible(true)

    table.insert(buttons, 1, self.showRadioRangeButton)
    self.buttonPanel:addChild(self.showRadioRangeButton)
	self.buttonPanel:insertNewListOfButtons(buttons)

    local btnCount = #buttons
    self.buttonPanel:setX(self.width - 20 - (btnSize * btnCount + 20 * (btnCount - 1)))
    self.buttonPanel:setWidth(btnSize * btnCount + 20 * (btnCount - 1))

    self.showRadioRange = false
end

function ISWorldMap:onShowRadioRangeClick()
    self.showRadioRange = not self.showRadioRange
end

local function renderRadioRanges(self)
    if not self.radioRanges then return end

    for _,range in pairs(self.radioRanges) do
        local tlX = self.mapAPI:worldToUIX(range.x1, range.y1)
        local tlY = self.mapAPI:worldToUIY(range.x1, range.y1)
        local brX = self.mapAPI:worldToUIX(range.x2, range.y2)
        local brY = self.mapAPI:worldToUIY(range.x2, range.y2)

        if brX - tlX < 256 then
            self:drawTextureScaled(self.textureCircle256, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        elseif brX - tlX < 512 then
            self:drawTextureScaled(self.textureCircle512, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        elseif brX - tlX < 1024 then
            self:drawTextureScaled(self.textureCircle1024, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        elseif brX - tlX < 1536 then
            self:drawTextureScaled(self.textureCircle1536, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        elseif brX - tlX < 2048 then
            self:drawTextureScaled(self.textureCircle2048, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        else
            self:drawTextureScaled(self.textureCircle4096, tlX, tlY, brX - tlX, brY - tlY, 1, 1, 1, 1)
        end

        local centerX = tlX + ((brX - tlX) / 2)
        local topY = brY + 2
        local textWidth = getTextManager():MeasureStringX(UIFont.Medium, range.freq)
        local textHeight = getTextManager():MeasureStringY(UIFont.Medium, range.freq)
        local btnX1 = math.floor(centerX - (textWidth / 2) - 2)
        local btnY1 = math.floor(topY - 2)
        local btnWidth2 = textWidth + 4
        local btnHeight2 = textHeight + 4

        self:drawRect(btnX1, btnY1, btnWidth2, btnHeight2, 0.5, 0, 0, 0)
        self:drawTextCentre(range.freq, centerX, topY, 0.337, 1, 0.349, 1, UIFont.Medium)
    end
end

local original_map_render = ISWorldMap.render;
function ISWorldMap:render()
    original_map_render(self)

    -- show the button only if we're not in isometric mode
    if self.isometric == self.showRadioRangeButton:isVisible() then
        self.showRadioRangeButton:setVisible(not self.showRadioRangeButton:isVisible())
    end

    -- don't render the radio ranges if we're not supposed to or if we're in isometric mode
    if not self.showRadioRange or self.isometric then return end

    -- TODO - cache the radio ranges so we don't have to calculate them every frame
    self.radioRanges = WRU_Utils.getRadioRanges(WRU_Utils.getPlayerRadios(getPlayer()))

    renderRadioRanges(self)
end
