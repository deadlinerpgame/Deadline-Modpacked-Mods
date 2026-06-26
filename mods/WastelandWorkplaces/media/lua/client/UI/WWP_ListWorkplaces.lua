---
--- WWP_ListWorkplaces.lua
--- 25/06/2023
---

if not isClient() then return end

require "WL_Utils"
require "GravyUI"
require "ISUI/ISPanel"
require "WWP_WorkplaceZone"

WWP_ListWorkplaces = ISPanel:derive("WWP_ListWorkplaces")
WWP_ListWorkplaces.instance = nil

function WWP_ListWorkplaces:show()
	if WWP_ListWorkplaces.instance then
		WWP_ListWorkplaces.instance:onClose()
	end
	local w = 150
	local h = 100
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	o.__index = self
	o:initialise()
	o:addToUIManager()
	WWP_ListWorkplaces.instance = o
	return o
end

function WWP_ListWorkplaces:initialise()
	self.moveWithMouse = true

	local window = GravyUI.Node(self.width, self.height):pad(5)
	local header, body, footer = window:rows({30, 1, 20}, 5)
	local leftBtn, rightBtn = footer:cols(2, 5)

	self.headerLabel = header

	self.selector = body:makeComboBox()
	self.goButton = leftBtn:makeButton("Go", self, self.onGo)
	self.cancelButton = rightBtn:makeButton("Close", self, self.onClose)

	self:addChild(self.selector)
	self:addChild(self.goButton)
	self:addChild(self.cancelButton)

	local zones = {}
	for _,zone in pairs(WWP_WorkplaceZone.getAllZones()) do
		table.insert(zones, zone)
	end

	table.sort(zones, function(a,b) return a.name < b.name end)

	if #zones == 0 then
		self.selector:addOption("No Workplaces")
		self.goButton:setEnable(false)
	else
		for _,zone in ipairs(zones) do
			self.selector:addOptionWithData(zone.name, zone)
		end
	end
end

function WWP_ListWorkplaces:prerender()
	ISPanel.prerender(self)
	self:drawTextCentre("Workplaces", self.headerLabel.left + (self.headerLabel.width/2),
			self.headerLabel.top, 1, 1, 1, 1, UIFont.Medium)
end

function WWP_ListWorkplaces:onGo()
	local zone = self.selector:getOptionData(self.selector.selected)
	WWP_WorkplacePanel.display(zone)
	self:removeFromUIManager()
	local player = getPlayer()
	if(player) then
		local x = zone.minX + ((zone.maxX - zone.minX) / 2)
		local y = zone.minY + ((zone.maxY - zone.minY) / 2)
		WL_Utils.teleportPlayerToCoords(player, x, y, 0)
	end
end

function WWP_ListWorkplaces:onClose()
	WWP_ListWorkplaces.instance = nil
	self:removeFromUIManager()
end