local FONT_HGT_NORMAL = getTextManager():getFontHeight(UIFont.Normal)

local function getSinceLastTended(plant)
    if not plant.lastTendHour then return "Never" end
    return round2((CFarmingSystem.instance.hoursElapsed - plant.lastTendHour)) .. " hours ago"
end

local function getGrowLampStatus(plant)
    if not plant.lightEnabled then return "Not Covered" end
    return "Covered"
end

local original_ISFarmingInfo_render = ISFarmingInfo.render
function ISFarmingInfo:render()
    original_ISFarmingInfo_render(self)
	if not self:isPlantValid() then return end
    local y = self:getHeight()
    local top = y
	local pady = 1
	local lineHgt = FONT_HGT_NORMAL + pady * 2

    self:drawRect(13, y, self.width - 25, lineHgt, 0.05, 1.0, 1.0, 1.0)
	self:drawText("Last Tended : ", 20, y + pady, 1, 1, 1, 1, UIFont.Normal)
	self:drawTextRight(getSinceLastTended(self.plant), self.width - 17, y + pady, 1, 1, 1, 1, UIFont.Normal)
    y = y + lineHgt

    self:drawRect(13, y, self.width - 25, lineHgt, 0.05, 1.0, 1.0, 1.0)
	self:drawText("Grow Lamp : ", 20, y + pady, 1, 1, 1, 1, UIFont.Normal)
	self:drawTextRight(getGrowLampStatus(self.plant), self.width - 17, y + pady, 1, 1, 1, 1, UIFont.Normal)
    y = y + lineHgt

    self:drawRectBorder(13, top - 1, self.width - 25, y - top + 2, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

	self:setHeightAndParentHeight(y + 8)
end