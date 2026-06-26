---
--- WL_AdminPanelOverride.lua
--- 26/10/2023
---
require "ISUI/AdminPanel/ISAdminPanelUI"
require "WL_Utils"

local adminPanelButtonRefresh = ISAdminPanelUI.updateButtons

function ISAdminPanelUI:updateButtons()
	adminPanelButtonRefresh(self)

	local isModerator = WL_Utils.canModerate(getPlayer())
	self.safezoneBtn.enable = isModerator
	self.seeFactionBtn.enable = isModerator
	self.seeSafehousesBtn.enable = isModerator
	self.seeTicketsBtn.enable = isModerator
	self.miniScoreboardBtn.enable = isModerator
	self.packetCountsBtn.enable = isAdmin()
	self.sandboxOptionsBtn.enable = isAdmin()
	self.itemListBtn.enable = WL_Utils.isAtLeastGM(getPlayer())
	self.climateOptionsBtn.enable = isModerator
	self.showStatisticsBtn.enable = isModerator
	self.dbBtn.enable = isAdmin() and getDebug()
end

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local adminPanelInitialise = ISAdminPanelUI.initialise
function ISAdminPanelUI:initialise()
	adminPanelInitialise(self)

	if not WL_Utils.isAtLeastGM(getPlayer()) then
		return
	end

	local btnWid = 150
    local btnHgt = math.max(25, FONT_HGT_SMALL + 3 * 2)
    local btnGapY = 5

    local last_btn = self.children[self.IDMax - 1]
    if last_btn.internal == "CANCEL" then
        last_btn = self.children[self.IDMax - 2]
    end
    local x = last_btn.x
    local y = last_btn.y + btnHgt + btnGapY

	-- Add our new button
	self.isoRegionDebug = ISButton:new(x, y, btnWid, btnHgt, "ISO Debug", self, IsoRegionsWindow.OnOpenPanel)
	self.isoRegionDebug.internal = "SOUNDBOARD"
	self.isoRegionDebug:initialise()
	self.isoRegionDebug:instantiate()
	self.isoRegionDebug.borderColor = self.buttonBorderColor
	self:addChild(self.isoRegionDebug)
	self.isoRegionDebug.tooltip = "Open ISO Region Debugger"
	self.isoRegionDebug.enable = WL_Utils.isAtLeastGM(getPlayer())
	-- Adjust positions like the admin panel does (Copy paste)
	local width = 0
	local bottom = 0
	for _,child in pairs(self:getChildren()) do
		width = math.max(width, child:getWidth())
		bottom = math.max(bottom, child:getBottom())
	end
	for _,child in pairs(self:getChildren()) do
		if child:getX() > 10 then
			child:setX(10 + width + 20)
		end
		child:setWidth(width)
	end

end
