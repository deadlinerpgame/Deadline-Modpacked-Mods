---
--- WWP_WorkplacePanel.lua
--- 30/07/2024
---
require "GravyUI_WL"

WWP_WorkplacePanel = ISPanel:derive("WWP_WorkplacePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local FONT_HGT_MASSIVE = getTextManager():getFontHeight(UIFont.Massive)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}

function WWP_WorkplacePanel.display(workplace)
	if WWP_WorkplacePanel.instance then
		WWP_WorkplacePanel.instance:onClose()
	end
	WWP_WorkplacePanel.instance = WWP_WorkplacePanel:new(workplace)
	WWP_WorkplacePanel.instance:addToUIManager()
end

function WWP_WorkplacePanel:new(workplace)
	local scale = FONT_HGT_SMALL / 12
	local w = 450 * scale
	local h = 530 * scale
	local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
	o.workplace = workplace
	o:initialise(workplace)
	return o
end

function WWP_WorkplacePanel:initialise(workplace)
	ISPanel.initialise(self)
	self.moveWithMouse = true
	self.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.6};
	self.borderColor = {r=0.1, g=0.1, b=0.1, a=1};
	local win =  GravyUI.Node(self.width, self.height, self)
	local closeButtonNode = win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3)
	win = win:pad(0, 5, 0, 0)

	local rowPadding = 5
	local bannerArea, bodyArea = win:rows({ 0.15, 0.85 }, rowPadding)
	self.bannerArea = bannerArea
	local titleArea, subTitleArea, _ = bannerArea:rows({ FONT_HGT_LARGE, FONT_HGT_MEDIUM, bannerArea.height - FONT_HGT_LARGE - FONT_HGT_MEDIUM - rowPadding*2 }, rowPadding)
	self.titleLabel = titleArea:makeLabel("", UIFont.Large, COLOR_WHITE, "center")
	self.subtitleLabel = subTitleArea:makeLabel("", UIFont.Medium, COLOR_WHITE, "center")

	self.tabs = bodyArea:makeTabPanel()
	self.tabs.borderColor = {r=0.1, g=0.1, b=0.1, a=1};
	local tabX, tabY, tabW, tabH = self.tabs.x, self.tabs.y, self.tabs.width, self.tabs.height - self.tabs.tabHeight

	if self.workplace:isEmployee(getPlayer()) or WL_Utils.canModerate(getPlayer()) then
		self.actionsPanel = WWP_WorkplaceActionsPanel:new(tabX, tabY, tabW, tabH, self.workplace, self)
		self.tabs:addView("Actions", self.actionsPanel)
	end

	self.infoPanel = WWP_WorkplaceInfoPanel:new(tabX, tabY, tabW, tabH, self.workplace, self)
	self.tabs:addView("Overview", self.infoPanel)

	if self.workplace:isPartner(getPlayer():getUsername()) or WL_Utils.canModerate(getPlayer()) then
		self.managePanel = WWP_WorkplaceManagePanel:new(tabX, tabY, tabW, tabH, self.workplace, self)
		self.tabs:addView("Manage", self.managePanel)
	end

	if WL_Utils.canModerate(getPlayer()) then
		self.adminPanel = WWP_WorkplaceAdminPanel:new(tabX, tabY, tabW, tabH, self.workplace, self)
		self.tabs:addView("Admin", self.adminPanel)
	end

	self.closeButton = closeButtonNode:makeButton("X", self, self.onClose)
	self:updateState()
end

function WWP_WorkplacePanel:prerender()
	ISPanel.prerender(self)
	if self.bannerTexture then
		self:drawTextureScaled(self.bannerTexture, 2, 2, self.width-4, self.bannerArea.height + self.tabs.tabHeight + 7, 0.6, 1.0, 1.0, 1.0)
	end
end


function WWP_WorkplacePanel:updateState()
	if self.workplace.type.banner then
		self.bannerTexture = getTexture("media/ui/" .. self.workplace.type.banner .. ".png")
	end

	self.titleLabel:setText(self.workplace.name)
	self.subtitleLabel:setText(self.workplace.type.name)
	self.infoPanel:updateState()
	if self.managePanel then
		self.managePanel:updateState()
	end
	if self.adminPanel then
		self.adminPanel:updateState()
	end
end

function WWP_WorkplacePanel:onClose()
	if self.adminPanel then
		self.adminPanel.apPicker:cleanup()
	end
	self:removeFromUIManager()
end

function WWP_WorkplacePanel:removeFromUIManager()
	ISPanelJoypad.removeFromUIManager(self)
	WWP_WorkplacePanel.instance = nil
end