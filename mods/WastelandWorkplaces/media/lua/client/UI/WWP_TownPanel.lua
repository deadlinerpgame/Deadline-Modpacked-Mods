---
--- WWP_TownPanel.lua
--- 17/07/2024
---

require "GravyUI_WL"

WWP_TownPanel = ISPanel:derive("WWP_TownPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_MASSIVE = getTextManager():getFontHeight(UIFont.Massive)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
	return px * SCALE
end
function WWP_TownPanel.display(town)
	if WWP_TownPanel.instance then
		WWP_TownPanel.instance:onClose()
	end
	WWP_TownPanel.instance = WWP_TownPanel:new(town)
	WWP_TownPanel.instance:addToUIManager()
end

function WWP_TownPanel:new(town)
	local scale = FONT_HGT_SMALL / 12
	local w = 600 * scale
	local h = 600 * scale
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o:initialise(town)
	return o
end

function WWP_TownPanel:initialise(town)
	ISPanel.initialise(self)
	self.moveWithMouse = true
	self.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.6};
	self.borderColor = {r=0.1, g=0.1, b=0.1, a=1};
	local win =  GravyUI.Node(self.width, self.height, self)
	local closeButtonNode = win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3)
	win = win:pad(0, 5, 0, 0)

	local bannerArea, infoArea = win:rows({ 1/4, 3/4 }, 0)
	self.bannerArea = bannerArea

	local rowPadding = scale(10)
	local title, headerBody = bannerArea:rows({ FONT_HGT_MASSIVE, bannerArea.height - FONT_HGT_MASSIVE - rowPadding}, rowPadding)
	self.titleLabel = title:makeLabel("", UIFont.Massive, COLOR_WHITE, "center")
	headerBody = headerBody:pad(scale(10), 0, scale(10), scale(10))

	local subHeaders, headerBody2 = headerBody:rows({ FONT_HGT_LARGE*2 + rowPadding, headerBody.height - FONT_HGT_LARGE*2 - rowPadding*2}, rowPadding)
	local leftSubHeader, _, rightSubHeader = subHeaders:cols( {0.4, 0.2, 0.4})

	local governmentType, governmentBonus = leftSubHeader:rows({ 0.5, 0.5})
	self.governmentTypeLabel = governmentType:makeLabel("", UIFont.Large, COLOR_WHITE, "right")

	local _, _, governmentBonusText = governmentBonus:cols( {governmentBonus.width - scale(75), scale(25), scale(50) })
	self.governmentBonusTextLabel = governmentBonusText:makeLabel("", UIFont.Medium, COLOR_YELLOW, "right")
	self.governmentBonusTextLabel:setTooltip("Bonus to the income of all workplaces inside the town that pay a salary")

	local settlementType, settlementBonus = rightSubHeader:rows({ 0.5, 0.5})
	self.settlementTypeLabel = settlementType:makeLabel("", UIFont.Large, COLOR_WHITE, "left")
	local settlementBonusIcon, settlementBonusText = settlementBonus:cols( {scale(30), settlementBonus.width - scale(90) })
	self.settlementBonusIcon = settlementBonusIcon
	self.settlementBonusTextLabel = settlementBonusText:makeLabel("", UIFont.Medium, COLOR_YELLOW, "left")

	local settlementInfoLeft, settlementInfoRight = bannerArea:cols({bannerArea.width - scale(100), scale(100)})
	local infoPadding = scale(12)
	local _, settlementInfoLeftLowest = settlementInfoLeft:rows({ settlementInfoLeft.height - FONT_HGT_MEDIUM - infoPadding, FONT_HGT_MEDIUM}, infoPadding)
	settlementInfoLeftLowest = settlementInfoLeftLowest:pad(scale(10), 0, 0, scale(10))
	self.leadershipLabel = settlementInfoLeftLowest:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")

	--local _, settlementInfoRightOne, settlementInfoRightTwo, settlementInfoRightThree, settlementInfoRightFour, settlementInfoRightFive = settlementInfoRight:rows({ settlementInfoRight.height - 150 - infoPadding*3, 30, 30, 30, 30, 30}, infoPadding)

	local infoStack = settlementInfoRight:makeVerticalStack(scale(infoPadding))
	infoStack:makeNode(scale(20)) -- Padding
	self:createInfoRow(infoStack, "population",  "media/ui/population.png",
		"Population: The number of players who are citizens in this settlement and have been active during the past "
		.. tostring(SandboxVars.WastelandWorkplaces.TownCitizenActivity) .. " days")
	self:createInfoRow(infoStack, "workplace",  "media/ui/workplace.png",
		"Businesses: The total number of workplaces within the settlement limits.")
	self:createInfoRow(infoStack, "salesTax",  "media/ui/salesTax.png",
		"Sales Tax: This percentage is taken from all player shops whenever they make a sale within the settlement.")
	self:createInfoRow(infoStack, "taxRate", "media/ui/incomeTax.png",
		"Income Tax: This percentage is taken from all player salaries from workplaces in the settlement.")
	self:createInfoRow(infoStack, "exportDuty",  "media/ui/export-duty.png",
			"Export Duty: The percentage tax for all sales of trade goods made here and sold outside the settlement.")

	self.tabs = ISTabPanel:new(infoArea.left, infoArea.top, infoArea.width, infoArea.height)
	self.tabs.borderColor = {r=0.1, g=0.1, b=0.1, a=1};
	self.tabs:setEqualTabWidth(false)
	self:addChild(self.tabs)

	self.lawsPanel = WWP_TownLawsPanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town)
	self.tabs:addView("Laws", self.lawsPanel)
	self.citizenPanel = WWP_TownCitizenPanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
	self.tabs:addView("Citizenship", self.citizenPanel)

	self.upgradesPanel = WWP_TownUpgradesPanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town)
	self.tabs:addView("Infrastructure", self.upgradesPanel)

	self.tradePanel = WWP_TownTradePanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
	self.tabs:addView("Trade", self.tradePanel)

	local rank = self.town:getPlayerPermissionLevel()
	if rank > WWP_TownRank.CITIZEN then
		self.governmentPanel = WWP_TownGovernmentPanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
		self.tabs:addView("Governance", self.governmentPanel)
	end

	if rank >= WWP_TownRank.GOVERNMENT_LOWEST then
		self.financePanel = WWP_TownFinancePanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
		self.tabs:addView("Finances", self.financePanel)
		self.warehousePanel = WWP_TownWarehousePanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
		self.tabs:addView("Warehouse", self.warehousePanel)
	end

	if rank >= WWP_TownRank.ENFORCEMENT_MANAGER then
		self.managePanel = WWP_TownManagePanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
		self.tabs:addView("Manage", self.managePanel)
	end

	if rank >= WWP_TownRank.STAFF then
		self.adminPanel = WWP_TownAdminPanel:new(infoArea.left, infoArea.top, self.tabs.width, self.tabs.height - self.tabs.tabHeight, town, self)
		self.tabs:addView("Admin", self.adminPanel)
	end

	self.closeButton = closeButtonNode:makeButton("X", self, self.onClose)
	self:updateState()
	self:updateAllCommodities()

	local timeMillis = SandboxVars.WastelandWorkplaces.TownCitizenActivity * 1000 * 60 * 60 * 24
	self.town.activityTracker:fetchActiveUsernames(timeMillis, self.receiveActivityList, self)
	getSoundManager():playUISound(self.town.type.openSound)
end

function WWP_TownPanel:createInfoRow(stack, iconName, texturePath, tooltip)
	local parentNode = stack:makeNode(scale(34))
	local iconNode, textNode = parentNode:cols({ 0.5, 0.5 })
	self[iconName .. "IconNode"] = iconNode
	self[iconName .. "IconTexture"] = getTexture(texturePath)
	self[iconName .. "Label"] = textNode:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")
	self[iconName .. "Label"]:setTooltip(tooltip)
	return iconNode, textNode
end

function WWP_TownPanel:updateAllCommodities()
    for _, commodity in pairs(WWP_Commodity) do
        if not commodity.disabled then
			WWP_TownLedger.fetchCommodityBalance(self.town, commodity, function(_, success, newBalance)
				-- If success is false (Account doesn't exist yet), balance will be 0 which is fine.
				self:updateStock(commodity, newBalance)
			end)
    	end
	end
end

function WWP_TownPanel:receiveActivityList(usernames)
	local count = 0
	for username, timeSinceActiveMillis in pairs(usernames) do
		count = count + 1
	end
	self.populationLabel:setText(tostring(count))
	if self.managePanel then
		self.managePanel:receiveActivityList(usernames)
	end
end

function WWP_TownPanel:updateStock(commodity, newBalance)
	self.tradePanel:updateStock(commodity, newBalance)
	if self.warehousePanel then self.warehousePanel:updateStock(commodity, newBalance) end
end

function WWP_TownPanel:updateState()
	self.settlementBonusIconTexture = getTexture("media/ui/" .. self.town.type.bonusIcon)
	self.bannerTexture = getTexture("media/ui/" .. self.town.type.banner)
	self.governmentBonusIconTexture = getTexture("media/ui/" .. self.town.governmentType.bonusIcon)
	self.leadershipLabel:setText("Leadership: " .. self.town.leadership)
	self.workplaceLabel:setText(tostring(#self.town:getWorkplaces()))
	self.taxRateLabel:setText(tostring(self.town.incomeTaxRate) .. "%")
	self.salesTaxLabel:setText(tostring(self.town.salesTaxRate) .. "%")
	self.exportDutyLabel:setText(tostring(self.town:getExportDuty()) .. "%")
	self.governmentBonusTextLabel.color = self.town.governmentType.bonusTextColor
	self.governmentBonusTextLabel:setText(self.town.governmentType.bonusText)
	self.settlementBonusTextLabel:setText(self.town.type.bonusText)
	self.settlementBonusTextLabel:setTooltip(self.town.type.bonusTooltip)
	self.titleLabel:setText(self.town.name)
	self.governmentTypeLabel:setText(self.town.governmentType.displayName)
	self.governmentTypeLabel:setTooltip(self.town.governmentType.tooltip)
	self.settlementTypeLabel:setText(self.town.type.displayName)
	self.lawsPanel:updateState()
	self.citizenPanel:updateState()
	self.upgradesPanel:updateState()
	self.tradePanel:updateState()
	if self.warehousePanel then self.warehousePanel:updateState() end
	if self.governmentPanel then self.governmentPanel:updateState() end
	if self.financePanel then self.financePanel:updateState() end
	if self.managePanel then self.managePanel:updateState() end
end

function WWP_TownPanel:prerender()
	ISPanel.prerender(self)
	self:drawTextureScaled(self.bannerTexture, scale(2), scale(2), self.width-scale(4), self.bannerArea.height + self.tabs.tabHeight + scale(3), 0.5, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.salesTaxIconTexture, self.salesTaxIconNode.left, self.salesTaxIconNode.top, scale(30), scale(30), 1, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.populationIconTexture, self.populationIconNode.left, self.populationIconNode.top, scale(30), scale(30), 1, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.workplaceIconTexture, self.workplaceIconNode.left, self.workplaceIconNode.top, scale(30), scale(30), 1, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.taxRateIconTexture, self.taxRateIconNode.left, self.taxRateIconNode.top, scale(30), scale(30), 1, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.exportDutyIconTexture, self.exportDutyIconNode.left, self.exportDutyIconNode.top, scale(30), scale(30), 1, 1.0, 1.0, 1.0)
	self:drawTextureScaled(self.settlementBonusIconTexture, self.settlementBonusIcon.left, self.settlementBonusIcon.top, scale(28), scale(28), 1, 1.0, 1.0, 1.0)
	local xLength = getTextManager():MeasureStringX(self.governmentBonusTextLabel.font, self.governmentBonusTextLabel.text)
	self:drawTextureScaled(self.governmentBonusIconTexture, self.governmentBonusTextLabel.x + self.governmentBonusTextLabel.width - xLength - scale(35), self.governmentBonusTextLabel.y, scale(28), scale(28), 1, 1.0, 1.0, 1.0)
end

function WWP_TownPanel:onClose()
	if self.adminPanel then
		self.adminPanel.apPicker:cleanup()
	end
	self:removeFromUIManager()
end

function WWP_TownPanel:removeFromUIManager()
	ISPanelJoypad.removeFromUIManager(self)
	WWP_TownPanel.instance = nil
end