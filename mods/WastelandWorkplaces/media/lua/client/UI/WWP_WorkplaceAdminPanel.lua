---
--- WWP_WorkplaceAdminPanel.lua
--- 01/08/2024
---

require "GravyUI_WL"

WWP_WorkplaceAdminPanel = ISPanel:derive("WWP_WorkplaceAdminPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_INTRO = getTextManager():getFontHeight(UIFont.Intro)

local SCALE = FONT_HGT_SMALL / 12
local MARGIN_SMALL = 6.3 * SCALE -- 10px for 19 height small font
local MARGIN_LARGE = 12.6 * SCALE -- 20px for 19 height small font

function WWP_WorkplaceAdminPanel:new(x, y, width, height, workplace, workplacePanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.workplace = workplace
	o.workplacePanel = workplacePanel
	o:initialise()
	return o
end

function WWP_WorkplaceAdminPanel:initialise()
	ISPanel.initialise(self)
	local win = GravyUI.Node(self.width, self.height, self)
	win = win:pad(20, 20, 20, 20)

	local windowStack = win:makeVerticalStack(MARGIN_SMALL)
	local lowestButtonRow = windowStack:makeNode(FONT_HGT_LARGE)
	local changeWorkplaceType, setNpcOwned, deleteWorkplace, _, _ = lowestButtonRow:cols({ 0.3, 0.3, 0.3, 0.1 }, 20)
	self.changeWorkplaceTypeButton = changeWorkplaceType:makeButton("Set Workplace Type", self, self.changeWorkplaceType)
	self.npcOwnedButton = setNpcOwned:makeButton("", self, self.toggleNpcOwned)
	self.deleteWorkplaceButton = deleteWorkplace:makeButton("Delete Workplace", self, self.deleteWorkplace)
	local overrideButtons = windowStack:makeNode(FONT_HGT_LARGE)
	local currencyOverride, currencyField, _, _ = overrideButtons:cols({ 0.3, 0.3, 0.3, 0.1}, 20)

	self.overrideCurrencyButton = currencyOverride:makeButton("Set Currency", self, self.changeCurrency)
	self.overrideCurrencyButton:setTooltip("Set a custom currency to give out at this workplace. e.g. Base.Money")
	self.currencyLabel = currencyField:makeLabel("", UIFont.Medium, nil, "left")

	local townSettingsRow = windowStack:makeNode(FONT_HGT_LARGE)
	local overrideTownSetting, townText, _, _ = townSettingsRow:cols({ 0.3, 0.3, 0.3, 0.1 }, 20)
	overrideTownSetting:makeButton("Set Town", self, self.onOverrideTownSetting)
	self.townLabel = townText:makeLabel("", UIFont.Medium, nil, "left")

	local zoneEditArea = windowStack:makeNode(SCALE*200):pad(0, MARGIN_LARGE, 0, 0)
	local apTitle, apPicker, apButtons = zoneEditArea:corner("topLeft", 0.4, 0.5):rows({0.25, 0.5, 0.25}, 15)
	local apToggle, apReset, apSave = apButtons:cols(3, 20)
	self.apTitle = apTitle:makeLabel("Workplace Area", UIFont.Large, {r=1, g=1, b=1, a=1})
	self.apPicker = apPicker:makeAreaPicker()
	self.apPicker:setValue({
		x1 = self.workplace.minX,
		y1 = self.workplace.minY,
		z1 = self.workplace.minZ,
		x2 = self.workplace.maxX,
		y2 = self.workplace.maxY,
		z2 = self.workplace.maxZ
	})
	self.apPicker.showAlways = false
	self.apPicker.fullZ = false
	self.apToggle = apToggle:makeButton("Toggle On", self, self.onApToggle)
	self.apReset = apReset:makeButton("Reset", self, self.onApReset)
	self.apSave = apSave:makeButton("Save", self, self.onApSave)
end

function WWP_WorkplaceAdminPanel:updateState()
	if self.workplace.isNPC then
		self.npcOwnedButton.title = "Set Player Owned"
	else
		self.npcOwnedButton.title = "Set NPC Owned"
	end

	self.currencyLabel:setText(self.workplace.currency or WWP_PayrollProcessor.DEFAULT_CURRENCY)

	local townId = self.workplace.townOverrideId
	if not townId then
		local name = "None"
		local town = self.workplace:getTown()
		if town then name = town.name end
		self.townLabel:setText("Automatic (" .. name .. ")")
	else
		if townId == "IGNORE_TOWN" then
			self.townLabel:setText("Override (None)")
		else
			local town = WWP_Town.findTownById(townId)
			local name = "NOT FOUND"
			if town then
				name = town.name
			end
			self.townLabel:setText("Override (" .. name .. ")")
		end
	end
end

function WWP_WorkplaceAdminPanel:onApToggle()
	self.apPicker.showAlways = not self.apPicker.showAlways
	self.apPicker:_updateGroundHighlight()
	if self.apPicker.showAlways then
		self.apToggle.title = "Toggle Off"
	else
		self.apToggle.title = "Toggle On"
	end
end

function WWP_WorkplaceAdminPanel:onApReset()
	self.apPicker:setValue({
		x1 = self.workplace.minX,
		y1 = self.workplace.minY,
		z1 = self.workplace.minZ,
		x2 = self.workplace.maxX,
		y2 = self.workplace.maxY,
		z2 = self.workplace.maxZ
	})
end

function WWP_WorkplaceAdminPanel:onApSave()
	local value = self.apPicker:getValue()
	self.workplace.minX = value.x1
	self.workplace.minY = value.y1
	self.workplace.minZ = value.z1
	self.workplace.maxX = value.x2
	self.workplace.maxY = value.y2
	self.workplace.maxZ = value.z2
	self.workplace:save()
end

function WWP_WorkplaceAdminPanel:changeWorkplaceType()
	local comboPanel = WL_ComboEntryPanel:new("Select new workplace type")
	local types = {}
	for _, type in pairs(WWP_WorkplaceTypes) do
		table.insert(types, type)
	end
	table.sort(types, function(a, b) return a.name < b.name end)
	for _, type in pairs(types) do
		comboPanel:addOption(type.name, type)
	end
	comboPanel:setInitialSelection(self.workplace.type)
	comboPanel:getUserSelection(nil, function(_, type)
		self.workplace:setWorkplaceType(type)
		self.workplacePanel:updateState()
	end)
end

function WWP_WorkplaceAdminPanel:toggleNpcOwned()
	if self.workplace.isNPC then
		self.workplace.isNPC = false
		self.workplace:save()
	else
		if not self.workplace:hasAnyEmployees() then
			WL_Dialogs.showMessageDialog("You need to add an NPC employee first")
			return
		end
		self.workplace.isNPC = true
		self.workplace.autoClose = false
		self.workplace.open = true
		self.workplace.isHiring = true
		self.workplace:save()
	end
	self.workplacePanel:updateState()
end

function WWP_WorkplaceAdminPanel:changeCurrency()
	WL_TextEntryPanel:show("Enter the new currency type", nil, function(_, newName)
		if newName == "" then
			self.workplace.currency = nil
		else
			self.workplace.currency = newName
		end
		self.workplace:save()
		self.workplacePanel:updateState()
	end, self.workplace.currency)
end

function WWP_WorkplaceAdminPanel:deleteWorkplace()
	self.workplace:delete()
	self.workplacePanel:onClose()
end

function WWP_WorkplaceAdminPanel:onOverrideTownSetting()
	local comboPanel = WL_ComboEntryPanel:new("Select Town")
	comboPanel:addOption("None", "IGNORE_TOWN")
	comboPanel:addOption("Automatic", nil)
	for _, town in pairs(WWP_Towns) do
		comboPanel:addOption(town.name, town)
	end
	comboPanel:setInitialSelection(nil)
	comboPanel:getUserSelection(nil, function(_, town)
		self.workplace:setTown(town)
		self.workplacePanel:updateState()
	end)
end


