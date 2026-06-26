---
--- WWP_WorkplaceInfoPanel.lua
--- 30/07/2024
---

require "GravyUI_WL"

WWP_WorkplaceInfoPanel = ISPanel:derive("WWP_WorkplaceInfoPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

function WWP_WorkplaceInfoPanel:new(x, y, width, height, workplace, workplacePanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.workplace = workplace
	o.workplacePanel = workplacePanel
	o:initialise()
	return o
end

function WWP_WorkplaceInfoPanel:initialise()
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(10, 15, 10, 10)

	local ownerInfoArea, employmentArea, statusArea, workingTogglesArea
		= win:rows({FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE}, 10)
	local ownerAreaText, claimButtonArea = ownerInfoArea:cols({0.8, 0.2}, 10)
	self.ownerTextLabel = ownerAreaText:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")
	self.claimButton = claimButtonArea:makeButton("Claim", self, self.onClaim)

	local employmentAreaText, joinQuitButtonArea = employmentArea:cols({0.8, 0.2}, 10)
	self.employmentTextLabel = employmentAreaText:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")
	self.joinQuitButton = joinQuitButtonArea:makeButton("", self, self.onJoinQuit)

	local statusAreaText, openCloseButtonArea = statusArea:cols({0.8, 0.2}, 10)
	self.statusTextLabel = statusAreaText:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")
	self.openCloseButton = openCloseButtonArea:makeButton("", self, self.onOpenClose)
end

function WWP_WorkplaceInfoPanel:updateState()
	if self.workplace:isEmployee(getPlayer()) then
		self.employmentTextLabel:setText("Employment: You work here")
		self.joinQuitButton.title = "Quit Job"
		self.joinQuitButton.enable = true
		self.joinQuitButton:setVisible(true)
	else
		if not self.workplace:hasAnyEmployees() then
			self.employmentTextLabel:setText("Employment: No owner yet")
			self.joinQuitButton:setVisible(false)
		else
			if not self.workplace.isHiring then
				self.employmentTextLabel:setText("Employment: Not hiring")
				self.joinQuitButton:setVisible(false)
			else
				if self.workplace.isNPC then
					self.employmentTextLabel:setText("Employment: Hiring")
					self.joinQuitButton.title = "Take Job"
					local canWorkHere, denyReason = self.workplace.type:isCapableOfJob(getPlayer())
					self.joinQuitButton.enable = canWorkHere
					self.joinQuitButton:setTooltip(denyReason)
					self.joinQuitButton:setVisible(true)
				else
					self.employmentTextLabel:setText("Employment: Hiring. Contact the owner.")
					self.joinQuitButton:setVisible(false)
				end
			end
		end
	end

	if self.workplace.isNPC then
		self.ownerTextLabel:setText("Ownership: Municipal  (NPC)")
		self.claimButton:setVisible(false)
	else
		if not self.workplace:hasAnyEmployees() then
			self.ownerTextLabel:setText("Ownership: None")
			self.claimButton:setVisible(true)
			local canOwnThis, denyReason = self.workplace.type:isCapableOfJob(getPlayer())
			self.claimButton.enable = canOwnThis
			self.claimButton:setTooltip(denyReason)
			self.claimButton:setVisible(true)
		else
			self.ownerTextLabel:setText("Ownership: Private (Player)")
			self.claimButton:setVisible(false)
		end
	end

	if self.workplace.open then
		self.statusTextLabel:setText("Availability: Open")
		self.openCloseButton.title = "Close"
	else
		self.statusTextLabel:setText("Availability: Closed")
		self.openCloseButton.title = "Open"
	end

	local isEmployee = self.workplace:isEmployee(getPlayer())
	self.openCloseButton:setVisible(isEmployee and not self.workplace.isNPC)
end


function WWP_WorkplaceInfoPanel:onClaim()
	self.workplace:promoteEmployee(getPlayer():getUsername())
	self.workplacePanel:onClose()

	local msg = "You are now the owner of this " .. self.workplace.type.name .. ".\n" ..
			"You can ticket to have the workplace changed to another type, provided you meet the new requirements."

	local town = self.workplace:getTown()
	if town and town.type.isHub then
		msg = msg .. "\nYour " .. self.workplace.type.name .. " is in a Hub. If you do not actively use this workplace then it will be removed from you."
	end

	WL_Dialogs.showMessageDialog(msg)
end

function WWP_WorkplaceInfoPanel:onJoinQuit()
	if self.workplace:isEmployee(getPlayer()) then
		WL_Dialogs.showConfirmationDialog("Are you sure you want to quit your job here?", function()
			self.workplace:fireEmployee(getPlayer():getUsername())
			self.workplacePanel:updateState()
		end)
	else
		self.workplace:addEmployee(getPlayer():getUsername())
		self.workplacePanel:onClose()
		WL_Dialogs.showMessageDialog("You are now an employee at " .. self.workplace.name .. ".\nBe aware that you cannot steal items from your workplace without a ticket.")
	end
end

function WWP_WorkplaceInfoPanel:onOpenClose()
	self.workplace.open = not self.workplace.open
	self.workplace:save()
	self:updateState()
end