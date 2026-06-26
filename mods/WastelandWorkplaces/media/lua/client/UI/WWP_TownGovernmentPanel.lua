---
--- WWP_TownGovernmentPanel.lua
--- 24/07/2024
---

---
--- WWP_TownManagePanel.lua
--- 21/07/2024
---


require "GravyUI_WL"
require "UI/WL_Dialogs"

WWP_TownGovernmentPanel = ISPanel:derive("WWP_TownGovernmentPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)


function WWP_TownGovernmentPanel:new(x, y, width, height, town, townPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.townPanel = townPanel
	o:initialise()
	return o
end

function WWP_TownGovernmentPanel:initialise()
	ISPanel.initialise(self)
	local win = GravyUI.Node(self.width, self.height, self)
	win = win:pad(20, 20, 20, 20)
	local peopleArea, controlsArea = win:rows( { 0.85, 0.25}, 10)

	local governmentArea, enforcementArea = peopleArea:cols({ 0.5, 0.5}, 30)

	local govTitle, govArea = governmentArea:rows(
			{ FONT_HGT_LARGE, governmentArea.height - FONT_HGT_LARGE - 10 }, 10)
	govTitle:makeLabel("Government", UIFont.Large, COLOR_WHITE, "center")
	local govListArea, govListControls = govArea:rows({ govArea.height - FONT_HGT_LARGE - 10, FONT_HGT_LARGE }, 10)
	self.govList = govListArea:makeScrollingListBox()
	local govPromote, govDemote, govFire = govListControls:cols( { 0.35, 0.35, 0.3 }, 20)
	self.govPromoteButton = govPromote:makeButton("Promote", self, self.govPromote)
	self.govDemoteButton = govDemote:makeButton("Demote", self, self.govDemote)
	self.govFireButton = govFire:makeButton("Fire", self, self.govFire)

	local enforceTitle, enforceArea = enforcementArea:rows(
			{ FONT_HGT_LARGE, enforcementArea.height - FONT_HGT_LARGE - 10 }, 10)
	enforceTitle:makeLabel("Enforcement", UIFont.Large, COLOR_WHITE, "center")

	local enforceListArea, enforceListControls = enforceArea:rows(
			{ enforceArea.height - FONT_HGT_LARGE - 10, FONT_HGT_LARGE }, 10)
	self.enforceList = enforceListArea:makeScrollingListBox()
	local enforcePromote, enforceDemote, enforceFire = enforceListControls:cols( { 0.35, 0.35, 0.3 }, 20)
	self.enforcePromoteButton = enforcePromote:makeButton("Promote", self, self.enforcePromote)
	self.enforceDemoteButton = enforceDemote:makeButton("Demote", self, self.enforceDemote)
	self.enforceFireButton = enforceFire:makeButton("Fire", self, self.enforceFire)

	local _, buttonRow = controlsArea:rows( { FONT_HGT_LARGE, FONT_HGT_LARGE }, 10)

	-- Handle permissions
	local rank = self.town:getPlayerPermissionLevel()
	local canManageEnforcers = WWP_TownRank.isEnforcement(rank) or rank >= WWP_TownRank.TOWN_LEADER
	self.enforcePromoteButton.enable = canManageEnforcers
	self.enforceDemoteButton.enable = canManageEnforcers
	self.enforceFireButton.enable = canManageEnforcers
	local canManageGovernment =  WWP_TownRank.isGovernment(rank) or rank >= WWP_TownRank.TOWN_LEADER
	self.govPromoteButton.enable = canManageGovernment
	self.govDemoteButton.enable = canManageGovernment
	self.govFireButton.enable = canManageGovernment
end

function WWP_TownGovernmentPanel:getOrderedOfficialsList(minRank, maxRank)
	local officials = {}
	for username, rank in pairs(self.town.citizens) do
		if rank >= minRank and rank <= maxRank then
			table.insert(officials, {username = username, rank = rank})
		end
	end
	table.sort(officials, function(a, b)
		return a.rank > b.rank
	end)
	return officials
end

function WWP_TownGovernmentPanel:updateGovernmentList()
	self.govList:clear()
	local governmentOfficials = self:getOrderedOfficialsList(11, 20)
	for _, official in ipairs(governmentOfficials) do
		local text = official.username .. " (" .. self.town:getGovernmentRankName(official.rank) .. ")"
		local item = self.govList:addItem(text, official.username)
		item.tooltip = "Salary: " .. tostring(self.town:getSalary(official.username))
	end
end

function WWP_TownGovernmentPanel:updateEnforcementList()
	self.enforceList:clear()
	local enforcementOfficials = self:getOrderedOfficialsList(1, 10)
	for _, official in ipairs(enforcementOfficials) do
		local text = official.username .. " (" .. self.town:getGovernmentRankName(official.rank) .. ")"
		local item = self.enforceList:addItem(text, official.username)
		item.tooltip = "Salary: " .. tostring(self.town:getSalary(official.username))
	end
end

function WWP_TownGovernmentPanel:updateState()
	self:updateGovernmentList()
	self:updateEnforcementList()
end

function WWP_TownGovernmentPanel:attemptPromotion(username)
	local rank = self.town:getGovernmentRank(username)
	if rank >= self.town:getPlayerPermissionLevel() then
		WL_Dialogs.showMessageDialog("You can't promote those at or above your level")
		return
	end

	local promotionRank = WWP_TownRank.getNextPromotion(rank)
	if promotionRank then
		WL_Dialogs.showConfirmationDialog("Are you sure you want to promote " .. username ..  "?", function()
			self.town:setGovernmentRank(username, promotionRank)
		end)
	end
end

function WWP_TownGovernmentPanel:attemptDemotion(username)
	local rank = self.town:getGovernmentRank(username)
	local player = getPlayer():getUsername()

	if rank >= self.town:getPlayerPermissionLevel() and username ~= player then
		WL_Dialogs.showMessageDialog("You can't demote those at or above your level")
		return
	end

	local demotionRank = WWP_TownRank.getNextDemotion(rank)
	if demotionRank then
		WL_Dialogs.showConfirmationDialog("Are you sure you want to demote " .. username ..  "?", function()
			self.town:setGovernmentRank(username, demotionRank)
		end)
	end
end

function WWP_TownGovernmentPanel:attemptFire(username)
	local rank = self.town:getGovernmentRank(username)
	local player = getPlayer():getUsername()

	if rank >= self.town:getPlayerPermissionLevel() and username ~= player then
		WL_Dialogs.showMessageDialog("You can't fire those at or above your level")
		return
	end

	WL_Dialogs.showConfirmationDialog("Are you sure you want to fire " .. username ..  "?", function()
		self.town:addCitizen(username)
	end)
end

function WWP_TownGovernmentPanel:govPromote()
	local selectedOfficial = self.govList.items[self.govList.selected]
	if not selectedOfficial then return end
	local username = selectedOfficial.item
	self:attemptPromotion(username)
end

function WWP_TownGovernmentPanel:govDemote()
	local selectedOfficial = self.govList.items[self.govList.selected]
	if not selectedOfficial then return end
	local username = selectedOfficial.item
	self:attemptDemotion(username)
end

function WWP_TownGovernmentPanel:govFire()
	local selectedOfficial = self.govList.items[self.govList.selected]
	if not selectedOfficial then return end
	local username = selectedOfficial.item
	self:attemptFire(username)
end

function WWP_TownGovernmentPanel:enforcePromote()
	local selectedEnforcers = self.enforceList.items[self.enforceList.selected]
	if not selectedEnforcers then return end
	local username = selectedEnforcers.item
	self:attemptPromotion(username)
end

function WWP_TownGovernmentPanel:enforceDemote()
	local selectedEnforcers = self.enforceList.items[self.enforceList.selected]
	if not selectedEnforcers then return end
	local username = selectedEnforcers.item
	self:attemptDemotion(username)
end

function WWP_TownGovernmentPanel:enforceFire()
	local selectedEnforcers = self.enforceList.items[self.enforceList.selected]
	if not selectedEnforcers then return end
	local username = selectedEnforcers.item
	self:attemptFire(username)
end
