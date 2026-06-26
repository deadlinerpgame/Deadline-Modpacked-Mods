---
--- WWP_TownUpgradesPanel.lua
--- 31/08/2024
---

require 'ISUI/ISPanel'
require 'UI/WWP_NewUpgradeWindow'

WWP_TownUpgradesPanel = ISPanel:derive("WWP_TownUpgradesPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}
local COLOR_RED = {r=1,g=0,b=0,a=1}
local COLOR_GREEN = {r=0,g=1,b=0,a=1}

function WWP_TownUpgradesPanel:new(x, y, width, height, town)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o:initialise()
	return o
end

function WWP_TownUpgradesPanel:initialise()
	ISPanel.initialise(self)
	self.yellowCoinsTexture = getTexture("media/ui/coins-bonus.png")
	local win = GravyUI.Node(self.width, self.height, self)
	self.win = win:pad(15, 15, 15, 15)
	self:updateState()
end

function WWP_TownUpgradesPanel:updateState()
	if self.elementsToClear then
		for _, element in ipairs(self.elementsToClear) do
			self:removeChild(element)
		end
	end
	self.elementsToClear = {}
	self.bannersToPaint = {}
	self.coinIconNodes = {}
	self.elementsToClear = {}

	local maxCols = 2
	local maxRows = 4
	local bodyGrid = {self.win:grid(maxRows, maxCols, 20, 20)}
	local rowNumber = 1
	local colNumber = 1
	local upgradesList = {}

	for _, upgrade in pairs(self.town.upgrades) do
		table.insert(upgradesList, upgrade)
	end

	local rank = self.town:getPlayerPermissionLevel()
	if rank >= WWP_TownRank.GOVERNMENT_ADVISOR then
		if #upgradesList < 8 then
			local buildingSlot = { name = "Empty", button = "Begin a new project", banner = "upgrade-empty.png" }
			table.insert(upgradesList, buildingSlot)
		end

	end

	for _, upgrade in ipairs(upgradesList) do
		if(colNumber > maxCols) then return end
		local upgradeNode = bodyGrid[rowNumber][colNumber]

		local title, body = upgradeNode:rows({upgradeNode.height - (FONT_HGT_MEDIUM * 2) - 20, (FONT_HGT_MEDIUM * 2) -10 }, 10)
		local titleLabel = title:makeLabel(upgrade.name, UIFont.Large, COLOR_WHITE, "center")
		table.insert(self.elementsToClear, titleLabel)

		if upgrade.description then
			local descriptionLabel = body:makeLabel(upgrade.description, UIFont.Medium, COLOR_WHITE, "center")
			table.insert(self.elementsToClear, descriptionLabel)
		else
			local _, buttonNode, _ = body:cols( {0.2, 0.6, 0.2})
			local button = buttonNode:makeButton(upgrade.button, self, self.addUpgrade)
			table.insert(self.elementsToClear, button)
			button.font = UIFont.Medium
			button.backgroundColor = {r=0, g=0, b=0, a=0.5};
		end

		if rank >= WWP_TownRank.GOVERNMENT_LOWEST then
			title = title:pad(5, 5, 5, 5)
			local iconNode, costNode = title:cols( {1/16, 15/16}, 10)
			if upgrade.revenue and upgrade.revenue > 0 then
				table.insert(self.coinIconNodes, iconNode)
				local costLabel = costNode:makeLabel(tostring(upgrade.revenue), UIFont.Medium, COLOR_YELLOW, "left")
				table.insert(self.elementsToClear, costLabel)
			end

			if WL_Utils.canModerate(getPlayer()) and (upgrade.name ~= "Empty") then
				local removeButtonNode = upgradeNode:corner("topRight", FONT_HGT_MEDIUM * 3, FONT_HGT_MEDIUM)
				local removeButton = removeButtonNode:makeButton("Remove", self, self.removeUpgrade, {upgrade})
				table.insert(self.elementsToClear, removeButton)
			end
		end

		local bannerTexture = getTexture("media/ui/" .. upgrade.banner)
		self.bannersToPaint[upgradeNode] = bannerTexture

		colNumber = colNumber + 1
		if(colNumber > maxCols) then
			colNumber = 1
			rowNumber = rowNumber + 1
		end
	end
end

function WWP_TownUpgradesPanel:prerender()
	ISPanel.prerender(self)
	for node, bannerTexture in pairs(self.bannersToPaint) do
		self:drawTextureScaled(bannerTexture, node.left, node.top, node.width,node.height, 0.35, 1.0, 1.0, 1.0)
	end

	for _, coinNode in ipairs(self.coinIconNodes) do
		self:drawTextureScaled(self.yellowCoinsTexture, coinNode.left, coinNode.top, coinNode.width, coinNode.width, 1.0, 1.0, 1.0, 1.0)
	end
end

function WWP_TownUpgradesPanel:removeUpgrade(_, upgrade)
	WL_Dialogs.showConfirmationDialog( "Are you sure you want to remove " .. upgrade.name ..
			" from the town?", function()
		self.town:removeUpgrade(upgrade)
	end)
end

function WWP_TownUpgradesPanel:addUpgrade()
	WWP_NewUpgradeWindow.display(self.town, self)
end