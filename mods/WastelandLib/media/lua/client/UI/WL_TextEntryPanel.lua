---
--- WL_TextEntryPanel.lua
---
--- Shows a field for a user to enter text.
---
---05/05/2024
---

require "GravyUI"
require "ISUI/ISPanel"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

WL_TextEntryPanel = ISPanel:derive("WL_TextEntryPanel")
WL_TextEntryPanel.instance = nil

---@param promptText string to explain what to ask for e.g. Enter your name
---@param target table|nil to call the callback function on e.g. myTable
---@param callback function|nil to call when the enter button is used e.g. myTable.onTextSubmitted
---@param initialText string|nil optional argument for the initial text. This can be a string or number (it's converted)
---@param numbersOnly boolean|nil optional argument to lock to numbers only
---@param wholeNumbersOnly boolean|nil optional argument to lock to integers not decimals
function WL_TextEntryPanel:show(promptText, target, callback, initialText, numbersOnly, wholeNumbersOnly)
	if WL_TextEntryPanel.instance then
		WL_TextEntryPanel.instance:onClose()
	end

	WL_TextEntryPanel.instance = WL_TextEntryPanel:new(promptText, target, callback, initialText, numbersOnly, wholeNumbersOnly)
	WL_TextEntryPanel.instance:addToUIManager()
end

function WL_TextEntryPanel:new(promptText, target, callback, initialText, numbersOnly, wholeNumbersOnly)
	local scale = FONT_HGT_SMALL / 12
	local w = 350 * scale
	local h = 70 * scale
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
	o.promptText = promptText
	o.target = target
	o.callback = callback
	if initialText then o.initialText = tostring(initialText) else o.initialText = "" end
	o.numbersOnly = numbersOnly or false
	o.wholeNumbersOnly = wholeNumbersOnly or false
	o.backgroundColor = {r=0, g=0, b=0, a=0.9};
	o:initialise()
	return o
end

function WL_TextEntryPanel:initialise()
	ISPanel.initialise(self)
	self.moveWithMouse = true
	local win = GravyUI.Node(self.width, self.height, self):pad(10, 5, 10, 10)
	local rowPadding = 10
	local header, body = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - rowPadding}, rowPadding)
	header:makeLabel(self.promptText, UIFont.Medium, COLOR_WHITE, "center")
	local inputNode, buttonsNode = body:rows(2, 10)
	self.inputField = inputNode:makeTextBox(self.initialText, self.numbersOnly)
	local okButtonNode, _, cancelButtonNode = buttonsNode:cols({0.2, 0.6, 0.2}, 10)
	self.cancelButton = cancelButtonNode:makeButton("Cancel", self, self.onClose)
	self.okButton = okButtonNode:makeButton("Confirm", self, self.doSubmit)
end

function WL_TextEntryPanel:doSubmit()
	if self.callback then
		local inputText = self.inputField:getText()
		if self.numbersOnly and self.wholeNumbersOnly then
			local number = tonumber(inputText)
			if not number or number % 1 ~= 0 then
				self:onClose() -- Input is not a valid whole number, skip the callback
				return
			end
		end
		self.callback(self.target, inputText)
	end
	self:onClose()
end

function WL_TextEntryPanel:onClose()
	self:removeFromUIManager()
	WL_TextEntryPanel.instance = nil
end