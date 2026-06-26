---
--- WWP_TownCitizenPanel.lua
--- 18/07/2024
---

require "GravyUI_WL"

WWP_TownCitizenPanel = ISPanel:derive("WWP_TownEmployeesPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

function WWP_TownCitizenPanel:new(x, y, width, height, town, townPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.townPanel = townPanel
	o:initialise(town)
	return o
end

function WWP_TownCitizenPanel:initialise(town)
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(10, 10, 10, 10)
	local rowPadding = 10
	local applyOrLeave, remainder = win:rows({ FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - rowPadding}, rowPadding)
	local applyButtonArea, applyInformationArea = applyOrLeave:cols( {0.18, 0.82 }, 10)
	self.applyOrLeaveButton = applyButtonArea:makeButton("", self, self.changeCitizenship)
	self.applyInformationLabel = applyInformationArea:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")

end

function WWP_TownCitizenPanel:updateState()
	if self.town.citizenshipCost > 0 then
		self.applyOrLeaveButton.title = "Buy Citizenship (" .. tostring(self.town.citizenshipCost) .. "s)"
	else
		self.applyOrLeaveButton.title = "Register Citizenship"
	end
	if self.town:isExile(getPlayer():getUsername()) then
		self.applyOrLeaveButton.enable = false
		self.applyInformationLabel:setText("You are exiled from " .. self.town.name .. ".")
	elseif self.town:isCitizen(getPlayer():getUsername()) then
		local rank = self.town:getGovernmentRank(getPlayer():getUsername())
		if rank > 0 then
			self.applyOrLeaveButton.title = "Quit Job"
			self.applyInformationLabel:setText("You hold the position of " .. self.town:getGovernmentRankName(rank) .. " in " .. self.town.name .. ".")
		else
			self.applyOrLeaveButton.title = "Renounce Citizenship"
			self.applyInformationLabel:setText("You are a citizen of " .. self.town.name .. ".")
		end
		self.applyOrLeaveButton.enable = true
	else
		self.applyInformationLabel:setText("You are not a citizen. You can only be a citizen in one trade hub and one town.")
		self.applyOrLeaveButton.enable = true
	end
end

function WWP_TownCitizenPanel:changeCitizenship()
	if self.town:isCitizen(getPlayer():getUsername()) then
		local rank = self.town:getGovernmentRank(getPlayer():getUsername())
		if rank > WWP_TownRank.CITIZEN then
			WL_Dialogs.showConfirmationDialog("Are you sure you want to quit your job here?", function()
				self.town:addCitizen(getPlayer():getUsername())
				self.townPanel:updateState()
			end)
		else
			WL_Dialogs.showConfirmationDialog("Are you sure you want to renounce your citizenship?", function()
				self.town:removeCitizen(getPlayer():getUsername())
				self.townPanel:updateState()
			end)
		end
	else
		local messageString = "Are you sure you want to become a citizen?"
		if self.town.citizenshipCost > 0 then
			messageString = messageString .. " You will pay " .. tostring(self.town.citizenshipCost) .. "s."
		end
		local existingTown = WWP_Town.getPlayerTownMembership(getPlayer():getUsername(), self.town:isHub())
		if existingTown then
			messageString = "This will remove your citizenship in " .. existingTown.name .. ", are you sure?"
		end

		WL_Dialogs.showConfirmationDialog(messageString, function()
			local hadTheMoney = WIT_Gold.removeAmountFromPlayer(getPlayer(), self.town.citizenshipCost)
			if hadTheMoney then
				if existingTown then
					existingTown:removeCitizen(getPlayer():getUsername())
				end

				if self.town.citizenshipCost > 0 then
					getSoundManager():playUISound("CitizenshipPaid")
					if self.town.type ~= WWP_TownType.NPC_HUB then
						WWP_TownLedger.getClient():makeDeposit(self.town.id, self.town.citizenshipCost,
								WWP_TownLedger.CITIZENSHIP_FEE)
					end
				else
					getSoundManager():playUISound("CitizenshipFree")
				end

				self.town:addCitizen(getPlayer():getUsername())
				self.townPanel:updateState()
			else
				WL_Dialogs.showMessageDialog("You can't afford that.")
			end
		end)
	end
end
