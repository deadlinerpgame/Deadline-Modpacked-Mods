---
--- WWP_TownManagePanel.lua
--- 21/07/2024
---


require "GravyUI_WL"

WWP_TownManagePanel = ISPanel:derive("WWP_TownManagePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)


function WWP_TownManagePanel:new(x, y, width, height, town, townPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.townPanel = townPanel
	o.activityCache = {}
	o:initialise()
	return o
end

function WWP_TownManagePanel:initialise()
	ISPanel.initialise(self)
	local win = GravyUI.Node(self.width, self.height, self)
	win = win:pad(20, 20, 20, 20)
	local peopleArea, controlsArea = win:rows( { 0.75, 0.25}, 10)

	local citizensArea, exilesAra = peopleArea:cols({ 0.5, 0.5}, 30)

	local citizensTitle, citizensListArea = citizensArea:rows(
			{ FONT_HGT_LARGE, citizensArea.height - FONT_HGT_LARGE - 10 }, 10)
	citizensTitle:makeLabel("Citizens", UIFont.Large, COLOR_WHITE, "center")
	self.citizenList = citizensListArea:makeScrollingListBox()

	local exilesTitle, exilesListArea = exilesAra:rows(
			{ FONT_HGT_LARGE, exilesAra.height - FONT_HGT_LARGE - 10 }, 10)
	exilesTitle:makeLabel("Exiles", UIFont.Large, COLOR_WHITE, "center")
	self.exilesList = exilesListArea:makeScrollingListBox()

	local citizenControls, townControls = controlsArea:rows(
			{ FONT_HGT_LARGE, controlsArea.height - FONT_HGT_LARGE - 10 }, 10)

	local recruitGov, recruitEnforce, exileCitizen, _, liftExile, _ =  citizenControls:cols({ 0.175, 0.175, 0.138, 0.196, 0.15, 0.18 }, 10)
	self.recruitGovButton = recruitGov:makeButton("Hire Government", self, self.recruitGov)
	self.recruitEnforceButton = recruitEnforce:makeButton("Hire Enforcement", self, self.recruitEnforce)
	self.exileButton = exileCitizen:makeButton("Exile Citizen", self, self.exileCitizen)
	self.liftExileButton = liftExile:makeButton("Lift Exile", self, self.liftExile)

	local secondaryControls, lowestButtonRow = townControls:rows(
			{ townControls.height - FONT_HGT_LARGE - 20, FONT_HGT_LARGE }, 20)

	local renameLeaders, renameTown, _, _, _ =
		lowestButtonRow:cols({ 0.2, 0.2, 0.2, 0.2, 0.2, 0.2 }, 20)

	self.renameLeadersButton = renameLeaders:makeButton("Edit Leadership", self, self.editLeadership)
	self.renameTownButton = renameTown:makeButton("Rename Town", self, self.renameTown)

	-- local _, middleButtonRow = secondaryControls:rows(
	--		{secondaryControls.height - FONT_HGT_LARGE - 20,  FONT_HGT_LARGE }, 20)
	-- local _, _, _, _, _ = middleButtonRow:cols({ 0.2, 0.2, 0.2, 0.2, 0.2, 0.2 }, 20)

	local rank = self.town:getPlayerPermissionLevel()
	self.recruitGovButton.enable = rank >= WWP_TownRank.GOVERNMENT_MANAGER
	self.recruitEnforceButton.enable = ((WWP_TownRank.isEnforcement(rank) and rank >= WWP_TownRank.ENFORCEMENT_MANAGER) or rank >= WWP_TownRank.TOWN_LEADER)
	self.exileButton.enable = rank >= WWP_TownRank.GOVERNMENT_HIGHEST
	self.liftExileButton.enable = rank >= WWP_TownRank.GOVERNMENT_HIGHEST
	self.renameLeadersButton.enable = rank >= WWP_TownRank.GOVERNMENT_HIGHEST
	self.renameTownButton.enable = rank >= WWP_TownRank.TOWN_LEADER
end

function WWP_TownManagePanel:receiveActivityList(usernames)
	self.activityCache = {}
	for username, timeSinceActiveMillis in pairs(usernames) do
		self.activityCache[username] = WL_Utils.toHumanReadableTime(timeSinceActiveMillis, {
			hideMinutes = true,
			hideSeconds = true,
			suffix = " ago"
		})
	end
	self:updateCitizensList()
end

function WWP_TownManagePanel:updateCitizensList()
	self.citizenList:clear()

	local alphabeticalNames = {}
	for citizen in pairs(self.town.citizens) do
		table.insert(alphabeticalNames, citizen)
	end
	table.sort(alphabeticalNames)

	for _, citizen in ipairs(alphabeticalNames) do
		local rank = self.town.citizens[citizen]
		local text = citizen
		if(rank > 0) then
			text = text .. " (" .. self.town:getGovernmentRankName(rank) .. ")"
		end
		local item0 = self.citizenList:addItem(text, citizen)
		if self.activityCache and self.activityCache[citizen] then
			item0.tooltip = "Last active: " .. self.activityCache[citizen]
		else
			item0.tooltip = "Inactive"
		end
	end
end

function WWP_TownManagePanel:updateExilesList()
	self.exilesList:clear()

	local alphabeticalNames = {}
	for exile in pairs(self.town.exiles) do
		table.insert(alphabeticalNames, exile)
	end
	table.sort(alphabeticalNames)

	for _, exile in ipairs(alphabeticalNames) do
		local text = exile
		local tooltip = exile .. " was exiled from this place"
		local item0 = self.exilesList:addItem(text, exile)
		item0.tooltip = tooltip
	end
end

function WWP_TownManagePanel:updateState()
	self:updateCitizensList()
	self:updateExilesList()
end

function WWP_TownManagePanel:exileCitizen()
	local selectedCitizen = self.citizenList.items[self.citizenList.selected]
	if not selectedCitizen then return end
	local username = self.citizenList.items[self.citizenList.selected].item
	if(username) then
		local exileCost = self.town:getExileCost()
		WL_Dialogs.showConfirmationDialog("Are you sure you want to exile " .. username .. "?\nIt will cost the town a one time fee of " .. tostring(exileCost) .. "s to enforce it", function()
			WWP_TownLedger.getClient():attemptWithdrawal(self.town.id, exileCost, WWP_TownLedger.EXILE_FEE,
					function(_, success, newBalance)
						if success then
							getSoundManager():playUISound("ExiledFromTown")
							self.town:removeCitizen(username)
							self.town:addExile(username)
							self.townPanel:updateState()
						else
							WL_Dialogs.showMessageDialog("You can't afford that.")
						end
					end)
		end)
	end
end

function WWP_TownManagePanel:liftExile()
	local selectedExile = self.exilesList.items[self.exilesList.selected]
	if not selectedExile then return end
	local username = self.exilesList.items[self.exilesList.selected].item
	if(username) then
		WL_Dialogs.showConfirmationDialog("Are you sure you want to lift the exile of " .. username .. "?", function()
			self.town:removeExile(username)
			self.townPanel:updateState()
		end)
	end
end

function WWP_TownManagePanel:editLeadership()
	WL_TextEntryPanel:show("Enter the name of the town's leader or council",
			self.town, self.town.setLeadershipName, self.town.leadership)
end

function WWP_TownManagePanel:renameTown()
	WL_TextEntryPanel:show("Enter a new name for the town",
			self.town, self.town.setName, self.town.name)
end

function WWP_TownManagePanel:recruitCitizen(toRank)
	local selectedCitizen = self.citizenList.items[self.citizenList.selected]
	if not selectedCitizen then return end
	local username = selectedCitizen.item

	if self.town:getGovernmentRank(username) > 0 then
		WL_Dialogs.showMessageDialog(username .. " already has a job here")
		return
	end

	WL_Dialogs.showConfirmationDialog("Are you sure you want to recruit " .. username .. " to the position of " ..
			self.town:getGovernmentRankName(toRank) .. "?", function()
		self.town:setGovernmentRank(username, toRank)
		self.townPanel:updateState()
	end)
end

function WWP_TownManagePanel:recruitGov()
	self:recruitCitizen(WWP_TownRank.GOVERNMENT_LOWEST)
end

function WWP_TownManagePanel:recruitEnforce()
	self:recruitCitizen(WWP_TownRank.ENFORCEMENT_LOWEST)
end

