require "Farming/farming_vegetableconf"

-- This is a copy of the original function from farming_vegetableconf.lua
-- with the addition of the skillModifierMin and skillModifierMax variables
-- which are used to increase the minimum and maximum number of vegetables
-- you get from a plant based on your farming skill.
--
-- return the number of vegtable you gain with your xp
-- every 10 points over 50 health you plant have = 1 more vegetable
function getVegetablesNumber(min, max, minAutorized, maxAutorized, plant)
	local healthModifier = math.floor((plant.health - 50) /10);
	if healthModifier < 0 then
		healthModifier = 0;
    end

    local vegModifier = 0;
    if SandboxVars.PlantAbundance == 1 then -- very poor
        vegModifier = -4;
    elseif SandboxVars.PlantAbundance == 2 then -- poor
        vegModifier = -2;
    elseif SandboxVars.PlantAbundance == 4 then -- abundant
        vegModifier = 3;
    elseif SandboxVars.PlantAbundance == 5 then -- very abundant
        vegModifier = 5;
    end

    local skillModifierMin = 0;
    local skillModifierMax = 0;
    if plant.harvestPlayer then
        skillModifierMin = math.floor(plant.harvestPlayer:getPerkLevel(Perks.Farming) / 3);
        skillModifierMax = math.floor(plant.harvestPlayer:getPerkLevel(Perks.Farming) / 1.5);
    end

	local minV = min + healthModifier + vegModifier + skillModifierMin;
	local maxV = max + healthModifier + vegModifier + skillModifierMax;
	if minV > (minAutorized + vegModifier + skillModifierMin) then
		minV = minAutorized + vegModifier + skillModifierMin;
	end
	if maxV > (maxAutorized  + vegModifier + skillModifierMax) then
		maxV = maxAutorized + vegModifier + skillModifierMax;
	end
    if minV <= 0 then
        minV = 1; -- you always get at least 1 vegetable
    end
	-- I have to add 1 to the maxV, don't know why but the zombRand never take the last digit (ex, between 5 and 10, you'll never have 10...)
	local nbOfVegetable = ZombRand(minV, maxV + 1);
	-- every 10 pts of aphid lower by 1 the vegetable you'll get
	local aphidModifier = math.floor(plant.aphidLvl/10);
	nbOfVegetable = nbOfVegetable - aphidModifier;
	return nbOfVegetable;
end

local original_badPlant = badPlant;
function badPlant(water, waterMax, diseaseLvl, plant, nextGrowing, updateNbOfGrow)
    if not plant then return end
    original_badPlant(water, waterMax, diseaseLvl, plant, nextGrowing, updateNbOfGrow)
end