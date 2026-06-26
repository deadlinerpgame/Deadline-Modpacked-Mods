---
--- WWP_ListTowns.lua
--- 27/07/2024
---

if not isClient() then return end

require "WL_Utils"
require "GravyUI"
require "ISUI/ISPanel"

WWP_ListTowns = ISPanel:derive("WWP_ListTowns")
WWP_ListTowns.instance = nil

function WWP_ListTowns:show()
	if WWP_ListTowns.instance then
		WWP_ListTowns.instance:onClose()
	end
	local w = 150
	local h = 100
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	o.__index = self
	o:initialise()
	o:addToUIManager()
	WWP_ListTowns.instance = o
	return o
end

function WWP_ListTowns:initialise()
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

	local towns = {}
	for _, town in pairs(WWP_Towns) do
		table.insert(towns, town)
	end

	table.sort(towns, function(a, b) return a.name < b.name end)

	if #towns == 0 then
		self.selector:addOption("No Towns")
		self.goButton:setEnable(false)
	else
		for _,zone in ipairs(towns) do
			self.selector:addOptionWithData(zone.name, zone)
		end
	end
end

function WWP_ListTowns:prerender()
	ISPanel.prerender(self)
	self:drawTextCentre("Towns", self.headerLabel.left + (self.headerLabel.width/2),
			self.headerLabel.top, 1, 1, 1, 1, UIFont.Medium)
end

function WWP_ListTowns:onGo()
	local town = self.selector:getOptionData(self.selector.selected)
	WWP_TownPanel.display(town)
	self:removeFromUIManager()

	local zone = town.zone
	local player = getPlayer()
	if(player) then
		local x = zone.minX + ((zone.maxX - zone.minX) / 2)
		local y = zone.minY + ((zone.maxY - zone.minY) / 2)
		WL_Utils.teleportPlayerToCoords(player, x, y, 0)
	end
end

function WWP_ListTowns:onClose()
	WWP_ListTowns.instance = nil
	self:removeFromUIManager()
end