---
--- WWP_TownAdminPanel.lua
--- 22/07/2024
---


require "GravyUI_WL"

WWP_TownAdminPanel = ISPanel:derive("WWP_TownAdminPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)


function WWP_TownAdminPanel:new(x, y, width, height, town, townPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.townPanel = townPanel
	o:initialise()
	return o
end

function WWP_TownAdminPanel:initialise()
	ISPanel.initialise(self)
	local win = GravyUI.Node(self.width, self.height, self)
	win = win:pad(20, 20, 20, 20)
	local zoneEditArea, extraControlsArea = win:rows( { 0.5, 0.5}, 10)

	local apTitle, apPicker, apButtons = zoneEditArea:corner("topLeft", 0.4, 0.5):rows({0.25, 0.5, 0.25}, 15)
	local apToggle, apReset, apSave = apButtons:cols(3, 20)
	self.apTitle = apTitle:makeLabel("Town Area", UIFont.Large, {r=1, g=1, b=1, a=1})
	self.apPicker = apPicker:makeAreaPicker()
	self.apPicker:setValue({
		x1 = self.town.zone.minX,
		y1 = self.town.zone.minY,
		z1 = self.town.zone.minZ,
		x2 = self.town.zone.maxX,
		y2 = self.town.zone.maxY,
		z2 = self.town.zone.maxZ
	})
	self.apPicker.showAlways = false
	self.apPicker.fullZ = true
	self.apToggle = apToggle:makeButton("Toggle On", self, self.onApToggle)
	self.apReset = apReset:makeButton("Reset", self, self.onApReset)
	self.apSave = apSave:makeButton("Save", self, self.onApSave)

	local _, lowestButtonRow = extraControlsArea:rows(
			{extraControlsArea.height - FONT_HGT_LARGE - 20,  FONT_HGT_LARGE }, 20)
	local changeTownType, changeGovernment, deleteTown, _, _ = lowestButtonRow:cols({ 0.2, 0.2, 0.2, 0.2, 0.2, 0.2 }, 20)
	self.changeGovernmentButton = changeGovernment:makeButton("Change Government", self, self.changeGovernment)
	self.changeTownTypeButton = changeTownType:makeButton("Edit Town Type", self, self.changeTownType)
	self.deleteTownButton = deleteTown:makeButton("Delete Town", self, self.deleteTown)
end

function WWP_TownAdminPanel:onApToggle()
	self.apPicker.showAlways = not self.apPicker.showAlways
	self.apPicker:_updateGroundHighlight()
	if self.apPicker.showAlways then
		self.apToggle.title = "Toggle Off"
	else
		self.apToggle.title = "Toggle On"
	end
end

function WWP_TownAdminPanel:onApReset()
	self.apPicker:setValue({
		x1 = self.town.zone.minX,
		y1 = self.town.zone.minY,
		z1 = self.town.zone.minZ,
		x2 = self.town.zone.maxX,
		y2 = self.town.zone.maxY,
		z2 = self.town.zone.maxZ
	})
end

function WWP_TownAdminPanel:onApSave()
	local value = self.apPicker:getValue()
	self.town.zone.minX = value.x1
	self.town.zone.minY = value.y1
	self.town.zone.minZ = value.z1
	self.town.zone.maxX = value.x2
	self.town.zone.maxY = value.y2
	self.town.zone.maxZ = value.z2
	self.town:save()
end

function WWP_TownAdminPanel:changeTownType()
	local comboPanel = WL_ComboEntryPanel:new("Select new town type")
	for _, townType in pairs(WWP_TownType) do
		comboPanel:addOption(townType.displayName, townType)
	end
	comboPanel:setInitialSelection(self.town.type)
	comboPanel:getUserSelection(self.town, self.town.setTownType)
end

function WWP_TownAdminPanel:changeGovernment()
	local comboPanel = WL_ComboEntryPanel:new("Select new government type")
	for _, govType in pairs(WWP_GovernmentType) do
		comboPanel:addOption(govType.displayName, govType)
	end
	comboPanel:setInitialSelection(self.town.governmentType)
	comboPanel:getUserSelection(self.town, self.town.setGovernmentType)
end

function WWP_TownAdminPanel:deleteTown()
	WL_Dialogs.showConfirmationDialog("Are you sure you want to delete " .. self.town.name .. "?", function()
		self.town:delete()
		self.townPanel:onClose()
	end)
end