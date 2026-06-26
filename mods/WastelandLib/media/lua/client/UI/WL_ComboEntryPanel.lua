---
--- WL_ComboEntryPanel.lua
--- 22/07/2024
---

require "GravyUI"
require "ISUI/ISPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

WL_ComboEntryPanel = ISPanel:derive("WL_ComboEntryPanel")
WL_ComboEntryPanel.instance = nil

---@param promptText string to explain what to ask for e.g. select an animal, this is optional
function WL_ComboEntryPanel:new(promptText)
	local scale = FONT_HGT_SMALL / 12
	local w = 250 * scale
	local h = 70 * scale
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
	o.promptText = promptText or "Select an option"
	o.backgroundColor = {r=0, g=0, b=0, a=0.9};
	o:initialise()
	return o
end

function WL_ComboEntryPanel:initialise()
	ISPanel.initialise(self)
	self.moveWithMouse = true
	local win = GravyUI.Node(self.width, self.height, self):pad(10, 5, 10, 10)
	local rowPadding = 10
	local header, body = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - rowPadding}, rowPadding)
	header:makeLabel(self.promptText, UIFont.Medium, COLOR_WHITE, "center")
	local inputNode, buttonsNode = body:rows(2, 10)
	self.typeComboBox = inputNode:makeComboBox()
	local okButtonNode, _, cancelButtonNode = buttonsNode:cols({0.4, 0.2, 0.4}, 10)
	self.cancelButton = cancelButtonNode:makeButton("Cancel", self, self.onClose)
	self.okButton = okButtonNode:makeButton("Confirm", self, self.doSubmit)
end

function WL_ComboEntryPanel:addOption(displayName, option)
	self.typeComboBox:addOptionWithData(displayName, option)
end

function WL_ComboEntryPanel:setInitialSelection(option)
	self.typeComboBox:selectData(option)
end

function WL_ComboEntryPanel:getUserSelection(target, callback)
	self.target = target
	self.callback = callback
	if WL_ComboEntryPanel.instance then
		WL_ComboEntryPanel.instance:onClose()
	end
	WL_ComboEntryPanel.instance = self
	self:addToUIManager()
end

function WL_ComboEntryPanel:doSubmit()
	self.callback(self.target, self.typeComboBox:getOptionData(self.typeComboBox.selected))
	self:onClose()
end

function WL_ComboEntryPanel:onClose()
	self:removeFromUIManager()
	WL_ComboEntryPanel.instance = nil
end