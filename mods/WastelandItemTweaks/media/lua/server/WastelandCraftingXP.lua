---
--- WastelandCraftingXP.lua
---
--- For XP Reference: A wooden spear takes 1 plank, 100 time and gives 5 Carpentry XP
---
--- 16/06/2023
---
function Recipe.OnGiveXP.Woodwork10(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 10);
end

function Recipe.OnGiveXP.Woodwork1(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 1);
end

function Recipe.OnGiveXP.Woodwork5(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 5);
end

function Recipe.OnGiveXP.Woodwork15(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 15);
end

function Recipe.OnGiveXP.Woodwork20(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 20);
end

function Recipe.OnGiveXP.Woodwork30(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Woodwork, 30);
end

function Recipe.OnGiveXP.MetalWelding1(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 1);
end

function Recipe.OnGiveXP.MetalWelding5(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 5);
end

function Recipe.OnGiveXP.MetalWelding10(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 10);
end

function Recipe.OnGiveXP.MetalWelding15(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 15);
end

function Recipe.OnGiveXP.MetalWelding20(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 20);
end

function Recipe.OnGiveXP.MetalWelding30(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.MetalWelding, 30);
end

function Recipe.OnGiveXP.Electricity5(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 5);
end

function Recipe.OnGiveXP.Electricity10(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 10);
end

function Recipe.OnGiveXP.Electricity15(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 15);
end

function Recipe.OnGiveXP.Electricity20(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 20);
end

function Recipe.OnGiveXP.Electricity30(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Electricity, 30);
end

function Recipe.OnGiveXP.Tailoring5(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 5);
end

Give1WoodWorkXP = Recipe.OnGiveXP.Woodwork1
Give5WoodworkXP = Recipe.OnGiveXP.Woodwork5
Give10WoodworkXP = Recipe.OnGiveXP.Woodwork10
Give15WoodworkXP = Recipe.OnGiveXP.Woodwork15
Give20WoodworkXP = Recipe.OnGiveXP.Woodwork20
Give30WoodworkXP = Recipe.OnGiveXP.Woodwork30

Give1MetalWeldingXP = Recipe.OnGiveXP.MetalWelding1
Give5MetalWeldingXP = Recipe.OnGiveXP.MetalWelding5
Give10MetalWeldingXP = Recipe.OnGiveXP.MetalWelding10
Give15MetalWeldingXP = Recipe.OnGiveXP.MetalWelding15
Give20MetalWeldingXP = Recipe.OnGiveXP.MetalWelding20
Give30MetalWeldingXP = Recipe.OnGiveXP.MetalWelding30

Give5ElectricityXP = Recipe.OnGiveXP.Electricity5
Give10ElectricityXP = Recipe.OnGiveXP.Electricity10
Give15ElectricityXP = Recipe.OnGiveXP.Electricity15
Give20ElectricityXP = Recipe.OnGiveXP.Electricity20
Give30ElectricityXP = Recipe.OnGiveXP.Electricity30


--Tailoring functions

function Recipe.OnGiveXP.Tailoring1(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 1);
end

function Recipe.OnGiveXP.Tailoring2(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 2);
end

function Recipe.OnGiveXP.Tailoring4(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 4);
end

function Recipe.OnGiveXP.Tailoring5(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 5);
end

function Recipe.OnGiveXP.Tailoring7(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 7);
end

function Recipe.OnGiveXP.Tailoring10(recipe, ingredients, result, player)
	player:getXp():AddXP(Perks.Tailoring, 10);
end

-- Tailoring Call on threads.
Get1TailoringXP = Recipe.OnGiveXP.Tailoring1
Get2TailoringXP = Recipe.OnGiveXP.Tailoring2
Get4TailoringXP = Recipe.OnGiveXP.Tailoring4
Get5TailoringXP = Recipe.OnGiveXP.Tailoring5
Get7TailoringXP = Recipe.OnGiveXP.Tailoring7
Get10TailoringXP = Recipe.OnGiveXP.Tailoring10
