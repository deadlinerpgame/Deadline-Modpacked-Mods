---
--- WWP_WorkplaceActionsPanel.lua
--- 03/08/2024
---

require "GravyUI_WL"

WWP_WorkplaceActionsPanel = ISPanel:derive("WWP_WorkplaceActionsPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}
local COLOR_BLUE = {r = 0.3, g = 0.5, b = 1, a = 1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
	return px * SCALE
end

function WWP_WorkplaceActionsPanel:new(x, y, width, height, workplace, workplacePanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.workplace = workplace
	o.workplacePanel = workplacePanel
	o.images = {}
	o:initialise()
	return o
end

local function makeItemList(itemList, maxIcons)
	local result = {}
	local totalCount = 0
	for itemName, count in pairs(itemList) do
		table.insert(result, itemName)
		totalCount = totalCount + 1
		if totalCount >= maxIcons then
			return result
		end
	end

	-- Alternate strategy for simplistic pallets with just one item
	if totalCount < 3 then
		result = {}
		totalCount = 0
		for itemName, count in pairs(itemList) do
			for i = 1, count do
				table.insert(result, itemName)
				totalCount = totalCount + 1
				if totalCount >= maxIcons then
					return result
				end
			end
		end
	end

	return result
end

local function findRecipe(name)
	local recipes = getScriptManager():getAllRecipes()
	for i=0,recipes:size()-1 do
		local recipe = recipes:get(i)
		if recipe:getOriginalname() == name then
			return recipe
		end
	end
	return nil
end

local function getDiscountString(multiplier)
	if not multiplier then return "" end
	local discount = (1 - multiplier) * 100
	return string.format(" (-%.0f%% town focus)", discount)
end

function WWP_WorkplaceActionsPanel:initialise()
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(scale(15), scale(15), scale(15), scale(20))

	local windowStack = win:makeVerticalStack(scale(15))
	local earningMoney = windowStack:makeNode((FONT_HGT_LARGE * 2) + scale(10))
	local earningStack = earningMoney:makeVerticalStack(scale(10))

	local moneyTitle, moneyValue = earningStack:makeNode(FONT_HGT_LARGE):cols( {0.85, 0.15})
	moneyTitle:makeLabel("Earning Currency", UIFont.Large, COLOR_WHITE, "left")

	if not self.workplace.type:disableTickRewards() then
		local moneyStack = moneyValue:makeHorizontalStack(scale(10))
		self.moneyIconNode = moneyStack:makeNode(scale(28))
		local moneyLabelNode= moneyStack:makeNode(scale(100))
		self.moneyIconNode:makeImage("media/ui/coins-bonus.png", scale(28), scale(28))
		local salary = self.workplace.type:getSalaryWithBonuses(self.workplace:getTown())
		moneyLabelNode:makeLabel(string.format("%.2f", salary), UIFont.Medium, COLOR_YELLOW, "left")
	end
	local moneyExplanation = earningStack:makeNode(FONT_HGT_LARGE)

	local commodity = self.workplace.type:getProducedCommodity()

	if commodity then
		moneyExplanation:makeLabel("You can earn currency by producing goods and then selling them at a town (See below).", UIFont.Small, COLOR_WHITE, "left")
	elseif self.workplace.type:requireCustomersForRewards() then
		moneyExplanation:makeLabel("You can earn currency by roleplaying inside this area with a customer.", UIFont.Small, COLOR_WHITE, "left")
	elseif not self.workplace.type:disableTickRewards() then
		moneyExplanation:makeLabel("You can earn currency by spending time inside this area.", UIFont.Small, COLOR_WHITE, "left")
	else
		moneyExplanation:makeLabel("You can't earn currency directly here, but might be able to sell items you get.", UIFont.Small, COLOR_WHITE, "left")
	end

	local headers = windowStack:makeNode(scale(32))
	local iconsTitle, nameTitle, skillTitle, costTitle = headers:cols({0.18, 0.38, 0.1, 0.32}, scale(20))
	iconsTitle:makeLabel("Items", UIFont.Large, COLOR_WHITE, "left")
	nameTitle:makeLabel("Name", UIFont.Large, COLOR_WHITE, "left")
	skillTitle:makeLabel("Skill", UIFont.Large, COLOR_WHITE, "left")
	costTitle:makeLabel("Work Points", UIFont.Large, COLOR_WHITE, "center")

	local actionsArea = windowStack:makeNode(scale(32) * 6 + (scale(15) * 6))
	local actionsStack = actionsArea:makeVerticalStack(scale(15))

	for _, action in ipairs(self.workplace.type.actions) do
		local icons, name, skill, cost, button = actionsStack:makeNode(scale(32)):cols({ 0.18, 0.40, 0.23, 0.04, 0.15}, scale(10))

		local maxIcons = 3
		if icons.width < 90 then
			maxIcons = 2
		end

		self:loadIconsFromTable(icons, action.items, maxIcons)

		local skillName = "None"
		if action.skill then
			skillName = action.skill:getName()
		end

		name:makeLabel(action.name, UIFont.Medium, COLOR_WHITE, "left", true)
		skill:makeLabel(skillName, UIFont.Medium, COLOR_WHITE, "left", true)
		cost:makeLabel(tostring(action.work), UIFont.Medium, COLOR_WHITE, "left")
		local startButton = button:makeButton("Start", self, self.onAction, {action})

		if action.mod and not getActivatedMods():contains(action.mod) then
			startButton:setTooltip("Mod " .. action.mod .. " is not active")
			startButton.enable = false
		end

		if action.skill and action.minSkill then
			local playerSkill = getPlayer():getPerkLevel(action.skill)
			if playerSkill < action.minSkill then
				startButton:setTooltip("Requires " .. action.skill:getName() .. " " .. tostring(action.minSkill))
				startButton.enable = false
			end
		end
	end

	if commodity then
		local title, wpCost = windowStack:makeNode(FONT_HGT_LARGE):rows({0.6, 0.4}, scale(15))
		title:makeLabel("Prepare " .. commodity.name .. " to sell", UIFont.Large, COLOR_WHITE, "left")
		wpCost = wpCost:offset(0, scale(-20))
		local cost, multiplier = self.workplace:getCommodityWorkPointCost()
		wpCost:makeLabel("Uses " .. tostring(cost) .. " Work Points" .. getDiscountString(multiplier), UIFont.Medium, COLOR_BLUE, "right")
		local commodityArea = windowStack:makeNode(300)
		local itemOptionsStack = commodityArea:makeVerticalStack(scale(15))

		for _, recipeId in pairs(commodity.recipes) do
			local isDiscountedRecipe = recipeId:sub(-#"Discounted") == "Discounted"
			if (multiplier and isDiscountedRecipe) or (not multiplier and not isDiscountedRecipe) then

				local itemsToDraw = {}
				local recipe = findRecipe(recipeId)
				if recipe then
					for j=1, recipe:getSource():size() do
						local source = recipe:getSource():get(j-1)
						local itemTypes = source:getItems()

						local maxLoops = itemTypes:size()
						if source:isKeep() then
							maxLoops = 1
						end

						for k=1,maxLoops do
							local sourceFullType = itemTypes:get(k-1)
							itemsToDraw[sourceFullType] = source:getCount()
						end
					end
				end

				local iconsNode, labelNode = itemOptionsStack:makeNode(FONT_HGT_LARGE):cols({ 0.57, 0.43}, scale(10))
				labelNode:makeLabel("Recipe: " .. recipe:getName(), UIFont.Medium, COLOR_WHITE, "left")

				local iconStack = iconsNode:makeHorizontalStack(scale(1))
				local itemsToShow = makeItemList(itemsToDraw, 11)
				for _, itemId in ipairs(itemsToShow) do
					local iconNode = iconStack:makeNode(scale(32))
					local texture = WL_Utils.getIconTexture(itemId)
					if texture then
						iconNode:makeImage(texture, scale(32), scale(32))
					end
				end
			end
		end
	end
end

function WWP_WorkplaceActionsPanel:loadIconsFromTable(parentNode, lootTable, maxIcons)
	local totalIcons = 0
	for itemID, _ in pairs(lootTable) do
		if totalIcons == maxIcons then
			break
		end

		local offset = totalIcons * 32
		totalIcons = totalIcons + 1
		local itemTexture = WL_Utils.getIconTexture(itemID)
		if itemTexture then
			table.insert(self.images, { node = parentNode, xOffset=offset, texture = itemTexture })
		end
	end
end

function WWP_WorkplaceActionsPanel:prerender()
	ISPanel.prerender(self)
	GravyUI.prerender(self)
	for _, image in ipairs(self.images) do
		if image.texture:getWidth() > 32 or image.texture:getHeight() > 32 then
			self:drawTextureScaled(image.texture, image.node.left + image.xOffset, image.node.top, 32, 32, 1, 1.0, 1.0, 1.0)
		else
			self:drawTexture(image.texture, image.node.left + image.xOffset, image.node.top, 1, 1.0, 1.0, 1.0)
		end
	end
end

function WWP_WorkplaceActionsPanel:updateState()

end

function WWP_WorkplaceActionsPanel:onAction(_, action)
	ISTimedActionQueue.add(WWP_WorkplaceTimedAction:new(getPlayer(), action, self.workplace))
end