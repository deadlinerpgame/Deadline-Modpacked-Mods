---
--- WL_CreateZonePanel.lua
--- 29/03/2024
---

require "GravyUI"
require "GroundHighlighter"
require "ISUI/ISPanel"

WL_CreateZonePanel = ISPanel:derive("WL_CreateZonePanel")
WL_CreateZonePanel.instance = nil

--- Show the create zone panel
---@param typeName string describing the type of the zone, e.g. "Workplace" or "Event Zone"
---@param startingCoordinates table defining the initial shape, with startX, startY, endX and endY as keys
---@param createZoneCallback function used on creation with args (name, tableOfCoordinates)
---@param isFullHeight boolean determines if full height is initially enabled
function WL_CreateZonePanel:display(typeName, startingCoordinates, createZoneCallback, isFullHeight)
	WL_CreateZonePanel:show(typeName, startingCoordinates, createZoneCallback, isFullHeight, true)
end

--- Show the create zone panel
---@param typeName string describing the type of the zone, e.g. "Workplace" or "Event Zone"
---@param startingCoordinates table defining the initial shape, with startX, startY, endX and endY as keys
---@param createZoneCallback function used on creation with args (name, startX, startY, endX, endY, startZ, endZ)
---@param isFullHeight boolean determines if full height is initially enabled
---@param useCoordinatesTable boolean false by default. If true, the callback is (name, table) instead of sending
--- the coordinates as 6 individual numbers
---@deprecated use WL_CreateZonePanel:display instead
function WL_CreateZonePanel:show(typeName, startingCoordinates, createZoneCallback, isFullHeight, useCoordinatesTable)
	if WL_CreateZonePanel.instance then
		WL_CreateZonePanel.instance:onClose()
	end

	local s = getTextManager():getFontHeight(UIFont.Small) / 12
	local w = 250 * s
	local h = 130 * s
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	o.__index = self
	o.startX = startingCoordinates.startX
	o.startY = startingCoordinates.startY
	o.endX = startingCoordinates.endX
	o.endY = startingCoordinates.endY
	o.isFullHeight = isFullHeight
	o.startZ = 0
	o.endZ = isFullHeight and 7 or 0
	o.typeName = typeName
	o.createZoneCallback = createZoneCallback
	o.useCoordinatesTable = useCoordinatesTable or false
	o:initialise()
	o:addToUIManager()
	WL_CreateZonePanel.instance = o
	return o
end

function WL_CreateZonePanel:initialise()
	ISPanel.initialise(self)
	self.moveWithMouse = true

	local win = GravyUI.Node(self.width, self.height):pad(5)
	local header, body, footer = win:rows({30, 1, 25}, 5)
	local header, headerRight = header:cols({1, 100}, 5)
	local nameInput, areaPicker = body:rows({0.33, 0.67}, 5);

	local b1, b2 = footer:cols(2, 5)

	self.headerBox = header:makeLabel(self.typeName .. " Creator", UIFont.Medium)

	self.showHighlightCheckbox = headerRight:makeTickBox()

	local nameInput1, nameInput2 = nameInput:cols({0.25, 0.75}, 5)
	self.nameLabel = nameInput1:makeLabel("Name:")
	self.nameInput = nameInput2:makeTextBox("Unnamed " .. self.typeName)

	self.areaPicker = areaPicker:makeAreaPicker()
	self.areaPicker.showAlways = true
	self.areaPicker:setValue({
		x1 = self.startX,
		y1 = self.startY,
		x2 = self.endX,
		y2 = self.endY,
		z1 = self.startZ,
		z2 = self.endZ
	})

	self.createZoneButton = b1:makeButton("Create " .. self.typeName, self, self.onCreateZone)
	self.closeButton = b2:makeButton("Close", self, self.onClose)

	self:addChild(self.headerBox)
	self:addChild(self.nameLabel)
	self:addChild(self.showHighlightCheckbox)
	self:addChild(self.nameInput)
	self:addChild(self.areaPicker)
	self:addChild(self.createZoneButton)
	self:addChild(self.closeButton)

	self.showHighlightCheckbox:addOption("Highlight?")
	self.showHighlightCheckbox:setSelected(1, true)

end

function WL_CreateZonePanel:prerender()
	ISPanel.prerender(self)

	self.areaPicker.showAlways = self.showHighlightCheckbox:isSelected(1)
	self.startX = self.areaPicker.value.x1
	self.startY = self.areaPicker.value.y1
	self.endX = self.areaPicker.value.x2
	self.endY = self.areaPicker.value.y2
	self.startZ = self.areaPicker.value.z1
	self.endZ = self.areaPicker.value.z2
end

function WL_CreateZonePanel:onCreateZone()
	if self.startX == 0 or self.startY == 0 then return end
	if self.endX == 0 or self.endY == 0 then return end
	if self.nameInput:getText() == "" then return end

	if self.useCoordinatesTable then
		self.createZoneCallback(self.nameInput:getText(), {startX = self.startX, endX = self.endX, startY = self.startY,
		                                                   endY = self.endY, startZ = self.startZ, endZ = self.endZ})
	else
		self.createZoneCallback(self.nameInput:getText(), self.startX, self.startY, self.endX, self.endY, self.startZ, self.endZ)
	end

	self.startX = 0
	self.startY = 0
	self.startZ = 0
	self.endX = 0
	self.endY = 0
	self.endZ = 0
	self:onClose()
end

function WL_CreateZonePanel:onClose()
	WL_CreateZonePanel.instance = nil
	self:removeFromUIManager()
end

function WL_CreateZonePanel:removeFromUIManager()
	self.areaPicker:cleanup()
	ISPanel.removeFromUIManager(self)
end
