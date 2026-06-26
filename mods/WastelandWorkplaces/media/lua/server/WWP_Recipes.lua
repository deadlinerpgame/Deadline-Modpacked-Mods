---
--- WWP_Recipes.lua
--- 13/07/2025
---

if not isClient() then return end

local function findMatchingWorkplace(player, typeKey)
	local workplaces = WWP_WorkplaceZone.getZonesAt(player:getX(), player:getY(), player:getZ())
	if #workplaces == 0 then return false end
	for _, workplace in ipairs(workplaces) do
		if workplace.type.key == typeKey or typeKey == "any" then
			if workplace:isEmployee(player) then
				return workplace
			else
				return false
			end
		end
	end
	return false
end

local function getDiscountString(multiplier, town)
	if not multiplier or not town then return "" end
	local townType = town.type.displayName
	local discount = (1 - multiplier) * 100
	return string.format("\n-%.0f%% %s discount", discount, townType)
end

function Recipe.OnCreate.craftedTradePallet(items, result, player)
	local workplace = findMatchingWorkplace(player,"any")
	local town = workplace:getTown()
	if town then
		local townName = town.name
		if result and townName then
			result:setName(result:getName() .. " from " .. townName)
			result:getModData().originTown = town.id
			result:getModData().unpaidExportDuty = true -- The town is due some portion of the sale price still
		end
	end

	local msg = ""
	local rewardGenerated = workplace.type:giveRandomXpReward(player)
	if rewardGenerated then
		msg = "Gained " .. rewardGenerated .. "\n"
	end

	local workPointCost, multiplier = workplace:getCommodityWorkPointCost()
	WWP_PlayerStats.deductWorkPoints(player, workPointCost)
	msg = msg .. workPointCost .. " Work Points used" .. getDiscountString(multiplier, town)
	msg = msg .. "\n" ..  WWP_PlayerStats.getWorkPointsRemainingString(player)
	player:setHaloNote(msg, 253, 216, 12, 800.0)
end

local function onTestTradeGood(workplaceTypeKey, isDiscountRecipe)
	local player = getPlayer()
	local workplace = findMatchingWorkplace(player, workplaceTypeKey)
	if not workplace then return false end
	local workPointCost, multiplier = workplace:getCommodityWorkPointCost()

	if isDiscountRecipe then
		if not multiplier then return false end -- This town does not have a discount so bump them to the other recipe
	else
		if multiplier then return false end -- This town has a discount so bump them to the other recipe
	end
	return WWP_PlayerStats.hasPointsAvailable(player, workPointCost)
end

function Recipe.OnTest.lumberPallet(sourceItem, result)
	return onTestTradeGood("logging_camp", false)
end

function Recipe.OnTest.lumberPalletDiscounted(sourceItem, result)
	return onTestTradeGood("logging_camp", true)
end

function Recipe.OnTest.farmPallet(sourceItem, result)
	return onTestTradeGood("farm", false)
end

function Recipe.OnTest.farmPalletDiscounted(sourceItem, result)
	return onTestTradeGood("farm", true)
end

function Recipe.OnTest.metalPallet(sourceItem, result)
	return onTestTradeGood("scrapyard", false)
end

function Recipe.OnTest.metalPalletDiscounted(sourceItem, result)
	return onTestTradeGood("scrapyard", true)
end