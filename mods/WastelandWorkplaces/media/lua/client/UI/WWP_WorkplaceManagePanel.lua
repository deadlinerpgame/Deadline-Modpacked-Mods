---
--- WWP_WorkplaceManagePanel.lua
--- 31/07/2024
---

require "GravyUI_WL"

WWP_WorkplaceManagePanel = ISPanel:derive("WWP_WorkplaceManagePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

function WWP_WorkplaceManagePanel:new(x, y, width, height, workplace, workplacePanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.workplace = workplace
	o.workplacePanel = workplacePanel
	o:initialise()
	return o
end

function WWP_WorkplaceManagePanel:initialise()
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(15, 15, 15, 20)
	local employeesTitle, employeesArea, extraButtonsArea =	win:rows({0.06, 0.6, 0.34}, 10)
	employeesTitle:makeLabel(" Employees", UIFont.Large, COLOR_WHITE, "left")

	local employeeListArea, employeeButtonsArea = employeesArea:cols({ 0.75, 0.25}, 20)
	self.employeeList = employeeListArea:makeScrollingListBox()

	local hire, promote, demote, fire, addNpc = employeeButtonsArea:rows({FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE}, 10)
	self.hireButton = hire:makeButton("Hire", self, self.onHire)
	self.promoteButton = promote:makeButton("Promote", self, self.onPromote)
	self.demoteButton = demote:makeButton("Demote", self, self.onDemote)
	self.fireButton = fire:makeButton("Fire", self, self.onFire)
	self.addNpcButton = addNpc:makeButton("Add NPC", self, self.onAddNpc)

	local _, autoClose, hiring, buttonRowArea = extraButtonsArea:rows({FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE }, 20)

	self.autoCloseCheckbox = autoClose:makeTickBox(self, self.onAutoCloseChanged)
	self.autoCloseCheckbox:addOption("Auto Close (Recommended) - Closes when no employees are present")

	self.hiringCheckbox = hiring:makeTickBox(self, self.onIsHiringChanged)
	self.hiringCheckbox:addOption("Advertise Hiring - Tells visitors you are hiring when they enter")

	local _, buttonRow = buttonRowArea:rows({ buttonRowArea.height - FONT_HGT_LARGE, FONT_HGT_LARGE}, 0)
	local changeLocation, changeDescription, rename = buttonRow:cols({ 0.3, 0.3, 0.25, 0.15}, 20)
	self.changeLocationButton = changeLocation:makeButton("Adjust Location", self, self.onChangeLocation)
	self.changeDescriptionButton = changeDescription:makeButton("Adjust Description", self, self.onChangeDescription)
	self.renameButton = rename:makeButton("Change Name", self, self.onRename)
	self.workplace.activityTracker:fetchAllUsernames(self.receiveActivityList, self)
end

function WWP_WorkplaceManagePanel:updateState()
	self.addNpcButton:setVisible(WL_Utils.canModerate(getPlayer()))
	self.demoteButton.enable = (WL_Utils.canModerate(getPlayer()))
	self.autoCloseCheckbox:setSelected(1, self.workplace.autoClose)
	self.hiringCheckbox:setSelected(1, self.workplace.isHiring)
	self:updateEmployeesList()
end

function WWP_WorkplaceManagePanel:receiveActivityList(usernames)
	self.activityCache = {}
	for username, timeSinceActiveMillis in pairs(usernames) do
		self.activityCache[username] = WL_Utils.toHumanReadableTime(timeSinceActiveMillis, {
			hideMinutes = true,
			hideSeconds = true,
			suffix = " ago"
		})
	end
	self:updateEmployeesList()
end

function WWP_WorkplaceManagePanel:updateEmployeesList()
	self.employeeList:clear()
	for employee, isPartner in pairs(self.workplace.employees) do
		local text = employee
		if(isPartner) then
			text = text .. " (Partner)"
		end
		local item0 = self.employeeList:addItem(text, employee)
		if self.activityCache and self.activityCache[employee] then
			item0.tooltip  = "Last active: " .. self.activityCache[employee]
		end
	end
end

function WWP_WorkplaceManagePanel:onHire()
	WL_SelectPlayersPanel:show(nil, function(_, username)
		local player = getPlayerFromUsername(username)
		if player then
			local canWorkHere, denyReason = self.workplace.type:isCapableOfJob(player)
			if canWorkHere then
				self.workplace:addEmployee(username)
				self:updateEmployeesList()
			else
				WL_Dialogs.showMessageDialog("You cannot hire " .. username .. ": " .. denyReason)
			end
		end
	end, {
		includeSelf = false,
		onlyInLOS = false,
	})
end

function WWP_WorkplaceManagePanel:onPromote()
	local selected = self.employeeList.items[self.employeeList.selected]
	if not selected then return end
	local username = selected.item
	if not username then return end
	if self.workplace:isPartner(username) then return end
	WL_Dialogs.showConfirmationDialog( "Are you sure you want to promote " .. username ..
			"?\n\nYou cannot remove a partner once they have been promoted!", function()
			self.workplace:promoteEmployee(username)
			self:updateEmployeesList()
	end)
end

function WWP_WorkplaceManagePanel:onDemote()
	local selected = self.employeeList.items[self.employeeList.selected]
	if not selected then return end
	local username = selected.item
	if not username then return end
	if not self.workplace:isPartner(username) then return end
	self.workplace:demoteEmployee(username)
	self:updateEmployeesList()
end

function WWP_WorkplaceManagePanel:onFire()
	local selected = self.employeeList.items[self.employeeList.selected]
	if not selected then return end
	local username = selected.item
	if not username then return end
	if self.workplace:isPartner(username) and not WL_Utils.canModerate(getPlayer()) then return end

	WL_Dialogs.showConfirmationDialog( "Are you sure you want to fire " .. username .. "?", function()
		self.workplace:fireEmployee(username)
		self:updateEmployeesList()
	end)
end

function WWP_WorkplaceManagePanel:onAddNpc()
	WL_TextEntryPanel:show("Enter the name of your new NPC", nil, function(_, npcName)
		self.workplace:addEmployee("[NPC] " .. npcName)
		self:updateEmployeesList()
	end)
end

function WWP_WorkplaceManagePanel:onChangeLocation()
	WL_TextEntryPanel:show("Describe the location of your business for others to find it",
			self.workplace, self.workplace.setLocation, self.workplace.location)
end

function WWP_WorkplaceManagePanel:onChangeDescription()
	WL_TextEntryPanel:show("Describe what your business offers",
			self.workplace, self.workplace.setDescription, self.workplace.description)
end

function WWP_WorkplaceManagePanel:onRename()
	WL_TextEntryPanel:show("Enter the name for your business", nil, function(_, newName)
		self.workplace:setName(newName)
		self.workplacePanel:updateState()
	end, self.workplace.name)
end

function WWP_WorkplaceManagePanel:onAutoCloseChanged()
	self.workplace:setAutoClose(self.autoCloseCheckbox:isSelected(1))
	self.workplacePanel:updateState()
end

function WWP_WorkplaceManagePanel:onIsHiringChanged()
	self.workplace:setIsHiring(self.hiringCheckbox:isSelected(1))
	self.workplacePanel:updateState()
end