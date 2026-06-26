---
--- WWP_TownLawsPanel.lua
--- 18/07/2024
---

require "GravyUI_WL"

WWP_TownLawsPanel = ISPanel:derive("WWP_TownOverviewPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)

function WWP_TownLawsPanel:new(x, y, width, height, town)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.editing = false
	o:initialise(town)
	return o
end

function WWP_TownLawsPanel:initialise(town)
	ISPanel.initialise(self)
	local win = GravyUI.Node(self.width, self.height, self)
	win = win:pad(10, 10, 10, 10)
	local rowPadding = 10
	local lawsTitle, lawsArea = win:rows({ FONT_HGT_INTRO, win.height - FONT_HGT_INTRO - rowPadding}, rowPadding)
	local lawsTitleTextArea, editLaws = lawsTitle:cols({0.95, 0.05})
	self.lawsTitleLabel = lawsTitleTextArea:makeLabel("", UIFont.Intro, nil, "left")
	self.editLawsButton = editLaws:makeButton("", self, self.toggleEdit)
	self.lawsTextBox = ISTextEntryBox:new(self.town.lawsText, lawsArea.left, lawsArea.top, lawsArea.width, lawsArea.height)
	self.lawsTextBox.anchorTop = true
	self.lawsTextBox.anchorLeft = true
	self.lawsTextBox.font = UIFont.Medium
	self.lawsTextBox.backgroundColor = {r=0, g=0, b=0, a=0}
	self.lawsTextBox:initialise()
	self:addChild(self.lawsTextBox)
	self.lawsTextBox:setMultipleLine(true)
	self.lawsTextBox.javaObject:setMaxLines(24)
	local rank = self.town:getPlayerPermissionLevel()
	self.editLawsButton:setVisible(rank >= WWP_TownRank.GOVERNMENT_MANAGER)
end

function WWP_TownLawsPanel:updateState()
	self.lawsTextBox:setEditable(self.editing)
	self.lawsTextBox:setSelectable(self.editing)

	if self.editing then
		self.editLawsButton.title = "Save"
	else
		self.lawsTextBox.borderColor = {r=0, g=0, b=0, a=0}
		self.editLawsButton.title = "Edit"
	end
	self.lawsTitleLabel:setText(self.town.name .. " LAWS")
end

function WWP_TownLawsPanel:toggleEdit()
	if self.editing then
		local textLength = string.len(self.lawsTextBox:getText())
		if textLength > 2000 then
			WL_Dialogs.showMessageDialog("Your laws text has " .. tostring(textLength) ..
					" characters, the maximum you are allowed is 2000 characters")
			return
		end

		self.town:setLaws(self.lawsTextBox:getText())
		self.editing = false
	else
		self.editing = true
		self:updateState()
	end
end