---
--- WIT_OverrideRecipe.lua
--- 14/04/2024
---
require 'recipecode'

local cutAnimalsRecipe = Recipe.OnCreate.CutAnimal

function Recipe.OnCreate.CutAnimal(items, result, player)
	cutAnimalsRecipe(items, result, player)
	local foundBirdie
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if item:getFullType() == "Base.DeadBird" then
			foundBirdie = true
			break
		end
	end

	if not foundBirdie then return end

	local feathers = ZombRand(13, 22)
	for i = 1, feathers do
		player:getInventory():AddItem("Base.WLFeather")
	end
end

local WIT_spearAttachRecipeNameSet = {
	["Attach Bread Knife to Spear"] = true,
	["Attach Butter Knife to Spear"] = true,
	["Attach Fork to Spear"] = true,
	["Attach Letter Opener to Spear"] = true,
	["Attach Scalpel to Spear"] = true,
	["Attach Spoon to Spear"] = true,
	["Attach Scissors to Spear"] = true,
	["Attach Hand Fork to Spear"] = true,
	["Attach Screwdriver to Spear"] = true,
	["Attach Kitchen Knife to Spear"] = true,
	["Attach Hunting Knife to Spear"] = true,
	["Attach Machete to Spear"] = true,
	["Attach Ice Pick to Spear"] = true,
}

function WIT_SpearRepairLimitTest(sourceItem, result)
	if not instanceof(sourceItem, "HandWeapon") then
		return true
	end

	return sourceItem:getHaveBeenRepaired() <= 1
end

local function WIT_setSpearRecipeOnTest()
	local recipes = getScriptManager():getAllRecipes()
	for i = 0, recipes:size() - 1 do
		local recipe = recipes:get(i)
		local recipeName = recipe:getName()
		local recipeNameNoModule = recipeName

		local dotIndex = string.find(recipeName, "%.")
		if dotIndex then
			recipeNameNoModule = string.sub(recipeName, dotIndex + 1)
		end

		if WIT_spearAttachRecipeNameSet[recipeName] or WIT_spearAttachRecipeNameSet[recipeNameNoModule] then
			recipe:setLuaTest("WIT_SpearRepairLimitTest")
		end
	end
end

WIT_setSpearRecipeOnTest()
Events.OnGameBoot.Add(WIT_setSpearRecipeOnTest)

--[[ This would work but Food Preservation Plus fucks with the recipe (removes it and adds it's own one)
WIT_OverrideRecipes = {}

function WIT_OverrideRecipes.ButcherBird(items, result, player)
	Recipe.OnCreate.CutAnimal(items, result, player)

	local feathers = ZombRand(13, 22)
	for i = 1, feathers do
		player:getInventory():AddItem("Base.WLFeather")
	end
end

local function setLuaOnCreate(recipeName, luaOnCreate)
	local recipes = getScriptManager():getAllRecipes()
	for i=0, recipes:size()-1 do
		local recipe = recipes:get(i);
		if recipe ~= nil and recipe:getName() == recipeName then
			recipe:setLuaCreate(luaOnCreate)
		end
	end
end

setLuaOnCreate("Butcher Bird", "WIT_OverrideRecipes.ButcherBird")
--]]

