---
--- WWP_NewUpgradeWindow.lua
--- 01/09/2024
---
require "GravyUI_WL"

WWP_NewUpgradeWindow = ISPanel:derive("WWP_NewUpgradeWindow")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_MASSIVE = getTextManager():getFontHeight(UIFont.Massive)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}
local COLOR_RED = {r=1,g=0,b=0,a=1}
local COLOR_GREEN = {r=0,g=1,b=0,a=1}
local COLOR_ORANGE = {r=1,g=0.5,b=0,a=1}

function WWP_NewUpgradeWindow.display(town, upgradeParentPanel)
	if WWP_NewUpgradeWindow.instance then
		WWP_NewUpgradeWindow.instance:onClose()
	end
	WWP_NewUpgradeWindow.instance = WWP_NewUpgradeWindow:new(town, upgradeParentPanel)
	WWP_NewUpgradeWindow.instance:addToUIManager()
end

function WWP_NewUpgradeWindow:new(town, upgradeParentPanel)
	local scale = FONT_HGT_SMALL / 12
	local w = 350 * scale
	local h = 330 * scale
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.upgradeParentPanel = upgradeParentPanel
	o:initialise()
	return o
end

function WWP_NewUpgradeWindow:initialise()
	ISPanel.initialise(self)
	self.backgroundColor = {r=0, g=0, b=0, a=1};
	self.moveWithMouse = true
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(15, 15, 15, 15)

	local dropDownNode, bodyNode = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - 10 }, 10)
	local whichLabel, whichComboBox = dropDownNode:cols({0.3, 0.7}, 10)
	whichLabel:makeLabel("Infrastructure:", UIFont.Medium, COLOR_WHITE, "right")
	self.whichComboBox = whichComboBox:makeComboBox(self, self.onSelectionChanged)
	for _, upgrade in pairs(WWP_TownUpgrade) do
	if (upgrade.townType == nil) or (upgrade.townType == self.town.type) then
			self.whichComboBox:addOptionWithData(upgrade.name, upgrade)
		end
	end

	local bannerNode, textNode = bodyNode:rows({0.4, 0.6}, 10)
	self.bannerNode = bannerNode
	local title, status, body = bannerNode:rows({bannerNode.height - (FONT_HGT_MEDIUM * 2) - 30 - FONT_HGT_LARGE, FONT_HGT_LARGE, (FONT_HGT_MEDIUM * 2) -10 }, 10)
	self.titleLabel = title:makeLabel("", UIFont.Large, COLOR_WHITE, "center")
	self.descriptionLabel = body:makeLabel("", UIFont.Medium, COLOR_WHITE, "center")
	self.statusLabel = status:makeLabel("", UIFont.Large, COLOR_GREEN, "center")

	local costNode, requirementsNode, instructionsNode, revenueNode, revenueReasonNode, buttonsNode = textNode:rows({FONT_HGT_MEDIUM, FONT_HGT_SMALL *4, FONT_HGT_SMALL*2, FONT_HGT_SMALL, FONT_HGT_MEDIUM, FONT_HGT_LARGE}, 10)
	self.upkeepLabel = costNode:makeLabel("", UIFont.Medium, COLOR_ORANGE, "left")
	self.requirementsLabel = requirementsNode:makeLabel("", UIFont.Small, COLOR_WHITE, "left")
	self.instructionsNode = instructionsNode:makeLabel("", UIFont.Small, COLOR_WHITE, "left")
	self.revenueLabel = revenueNode:makeLabel("", UIFont.Small, COLOR_GREEN, "left")
	self.revenueReasonLabel = revenueReasonNode:makeLabel("", UIFont.Small, COLOR_GREEN, "left")

	local activateButtonNode, _, closeButtonNode = buttonsNode:cols({0.3, 0.4, 0.3})
	self.activateButton = activateButtonNode:makeButton("Activate", self, self.onActivateUpgrade)
	self.closeButton = closeButtonNode:makeButton("Close", self, self.onClose)
	self:onSelectionChanged()
end

function WWP_NewUpgradeWindow:prerender()
	ISPanel.prerender(self)
	if self.currentBanner then
		self:drawTextureScaled(self.currentBanner, self.bannerNode.left, self.bannerNode.top, self.bannerNode.width,
				self.bannerNode.height, 0.5, 1.0, 1.0, 1.0)
	end
end

local function upkeepToString(upkeep)
	local parts = {}
	for commodity, amount in pairs(upkeep) do
		table.insert(parts, amount .. " " .. commodity.name)
	end
	return table.concat(parts, ", ")
end

function WWP_NewUpgradeWindow:onSelectionChanged()
	local upgrade = self.whichComboBox:getOptionData(self.whichComboBox.selected)
	local isAllowedToUpgrade = (not upgrade.needsTicket) or WL_Utils.canModerate(getPlayer())

	local isCurrentUpgradeActive = self.town.upgrades[upgrade.key] ~= nil
	local isCurrentUpgradeAllowed = true
	for _, prerequisite in ipairs(upgrade.prerequisites) do
		if self.town.upgrades[prerequisite] == nil then
			isCurrentUpgradeAllowed = false
			break
		end
	end

	self.currentBanner = getTexture("media/ui/" .. upgrade.banner)
	self.titleLabel:setText(upgrade.name)
	self.descriptionLabel:setText(upgrade.description)
	self.upkeepLabel:setText("Upkeep: " .. upkeepToString(upgrade.upkeep))
	self.requirementsLabel:setText("Requirements: " .. upgrade.requirements)
	self.instructionsNode:setText("Instructions: " .. upgrade.instructions)

	if upgrade.revenue then
		self.revenueLabel:setText("Town Income: " .. tostring(upgrade.revenue))
		self.revenueLabel:setVisible(true)
		self.revenueReasonLabel:setText(upgrade.revenueReason or "")
		self.revenueReasonLabel:setVisible(upgrade.revenueReason ~= nil)
	else
		self.revenueLabel:setVisible(false)
		self.revenueReasonLabel:setVisible(false)
	end

	if isCurrentUpgradeActive then
		self.statusLabel:setText("ACTIVE")
		self.statusLabel.color = COLOR_GREEN
		self.activateButton:setVisible(false)
	else
		self.activateButton:setVisible(true)

		if isCurrentUpgradeAllowed then
			self.statusLabel:setText("AVAILABLE")
			self.statusLabel.color = COLOR_ORANGE
			self.activateButton.enable = isAllowedToUpgrade
			if not isAllowedToUpgrade then
				self.activateButton:setTooltip("Requires a ticket to activate: Read the instructions.")
			else
				self.activateButton:setTooltip(nil)
			end
		else
			self.statusLabel:setText("LOCKED")
			self.statusLabel.color = COLOR_RED
			self.activateButton.enable = false
			self.activateButton:setTooltip("Missing prerequisite infrastructure")
		end
	end
end

function WWP_NewUpgradeWindow:onActivateUpgrade()
	local upgrade = self.whichComboBox:getOptionData(self.whichComboBox.selected)
	self.town:addUpgrade(upgrade)
	self:onClose()
end

function WWP_NewUpgradeWindow:onClose()
	self:removeFromUIManager()
end

function WWP_NewUpgradeWindow:removeFromUIManager()
	ISPanelJoypad.removeFromUIManager(self)
	WWP_NewUpgradeWindow.instance = nil
end
