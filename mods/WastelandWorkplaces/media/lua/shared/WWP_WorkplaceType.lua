---
--- WWP_WorkplaceType.lua
--- 18/06/2023
---
require "XPController"
require "WL_Utils"

WWP_WorkplaceTypes = WWP_WorkplaceTypes or {}

-- WorkplaceType base class
---@public field name string
WWP_WorkplaceType = {}

---@param key string This MUST NOT EVER CHANGE once you put it in
---@param name string Human visible name. Change it as much as you want.
---@param banner string name of the banner file i.e. ui/<banner>.png
---@param xpTable table for XP, works similar to above but includes how much XP they get if it comes up as a reward
function WWP_WorkplaceType:new(key, name, banner, xpTable)
    local obj = {}
    setmetatable(obj, self)
    self.__index = self
    obj.name = name
    obj.key = key
    obj.banner = banner
    obj.xpTable = xpTable
    obj:initialise()
    obj.actions = {}
    WWP_WorkplaceTypes[key] = obj
    return obj
end

function WWP_WorkplaceType:initialise()
    self.totalXPWeight = 0
    for _, row in ipairs(self.xpTable) do
        self.totalXPWeight = self.totalXPWeight + row.weighting
    end
end

--- Get an array of string describing the benefits of the establishment
-- e.g. {"+ Energy", "+ Happiness" }
function WWP_WorkplaceType:getBenefits() return {} end

--- Applies benefits like + happiness or healing to the player inside
------@param player IsoGameCharacter
function WWP_WorkplaceType:applyBenefits(player) end

---@return boolean true if visitors don't get benefits if no employee is present (e.g. no doctor means no bonus healing from the clinic)
function WWP_WorkplaceType:requireEmployeesForBenefits() return true end

---@return boolean true if employees don't get paid/xp etc unless SOMEONE is there. Can be another employee!
function WWP_WorkplaceType:requireSomeonePresentForRewards() return true end

---@return boolean true if employees don't get paid/xp etc unless a non-employee is around for them to server
---Note that this won't do anything unless :requireSomeonePresentForRewards is also set to true.
function WWP_WorkplaceType:requireCustomersForRewards() return false end

---@return boolean true if the workplace should disable ALL onTick rewards for employees, both XP and money
function WWP_WorkplaceType:disableTickRewards() return false end

---@return boolean true if we do speedy ticks for employee work points (2 minutes) instead of slow ticks (5 minutes)
function WWP_WorkplaceType:doSpeedyTicks() return false end

---@return string|nil the id of the sound for non-employees entering the workplace. This can be nil. It is played for all players
function WWP_WorkplaceType:getVisitorEnterSound() return nil end

---@return string|nil the id of the sound for non-employees exiting the workplace. This can be nil. It is played for all players
function WWP_WorkplaceType:getVisitorExitSound() return nil end

---@return table of { perk+level and/or a trait required to work here} This is only used for workplaces set to
---employee anyone (Such as NPC workplaces) to ensure they have basic skills for the job. This table can be empty but
---is never nil.
function WWP_WorkplaceType:getWorkRequirements() return {} end

---@return table WWP_Commodity |nil the commodity produced by this workplace, or nil if it doesn't produce anything
function WWP_WorkplaceType:getProducedCommodity() return nil end

--- A callback every minute a player is in a workplace.
---@param player IsoGameCharacter
---@param workplaceZone WWP_WorkplaceZone
function WWP_WorkplaceType:onMinuteTick(player, workplaceZone) end

--- A callback every two minutes a player is in a workplace.
---@param player IsoGameCharacter
---@param workplaceZone WWP_WorkplaceZone
function WWP_WorkplaceType:onTwoMinuteTick(player, workplaceZone) end

--- A callback every five minutes a player is in a workplace.
---@param player IsoGameCharacter
---@param workplaceZone WWP_WorkplaceZone
function WWP_WorkplaceType:onFiveMinuteTick(player, workplaceZone) end

function WWP_WorkplaceType:isCapableOfJob(player)
    local requirements = self:getWorkRequirements()

    if requirements.perk then
        local playerLevel = player:getPerkLevel(requirements.perk)
        if playerLevel < requirements.level then
            return false, requirements.perk:getName() .. " level is too low, requires " .. tostring(requirements.level)
        end
    end

    if requirements.trait then
        if not player:HasTrait(requirements.trait) then
            return false, "Missing required trait: " .. getText("UI_trait_" .. requirements.trait)
        end
    end

    return true, "Able to work here"
end

---@param town table optional town can be nil
---@return number decimal number with bonuses. e.g. could be 1.1 if the town has a 10% bonus
function WWP_WorkplaceType:getSalaryWithBonuses(town)
    local salary = 10
    if town then
        salary = salary + town:getSalaryBonus(salary, self:requireCustomersForRewards(), self.key)
    end
    return salary
end

--- Generates a reward and returns a string describing it e.g. "Gained Item: Donuts" or "Gained Skill: Nimble 100XP"
--- If the workplace provides a salary too, it will append that on a new line afterwards, e.g. "Gained Currency: 1 Guilder"
---@param player IsoGameCharacter
---@param town table|nil optional as not all workplaces are in a town
---@param currency string type id of the currency item we pay out
function WWP_WorkplaceType:generateReward(player, town, currency)
    local rewardString = ""
    local rewardGenerated = self:giveRandomXpReward(player)
    if rewardGenerated then
        rewardString = "Gained " .. rewardGenerated .. "\n"
    end
    WWP_PayrollProcessor.paySalary(player, currency, self:getSalaryWithBonuses(town), town, rewardString .. self.name)
end

---@return string | nil with the xp reward description, or nil if they were level capped so didn't get one
local function grantXp(player, perk, amount)
    local cap = getLevelCap(player, perk)
    local isSkillCapped = player:getPerkLevel(perk) == 10 or ((cap ~= nil) and (player:getPerkLevel(perk) >= cap))
    if isSkillCapped then
        return nil
    end

    WL_Utils.gainXP(perk, amount)
    local xpAmountString = tostring(amount) .. "XP"

    -- Check if we just leveled up
    isSkillCapped = (cap ~= nil) and (player:getPerkLevel(perk) >= cap)
    if isSkillCapped then  -- If we have hit the cap, set XP to the cap level exactly
        player:getXp():setXPToLevel(perk, cap)
        xpAmountString = "MAX LEVEL"
    end

    return perk:getName() .. ": " .. xpAmountString
end


---@return string|nil with the xp reward description or nil if they were level capped so didn't get one
function WWP_WorkplaceType:giveRandomXpReward(player)
    if WL_Utils.isEmpty(self.xpTable) then return nil end
    local perk, amount = self:rollXP()
    local perkBoost = player:getXp():getPerkBoost(perk)
    amount = amount * (perkBoost + 1) -- Not perfect but okay to increase XP gains
    return grantXp(player, perk, amount)
end

function WWP_WorkplaceType:rollXP()
    local randomNumber = ZombRand(1, self.totalXPWeight+1)
    local cumulativeWeighting = 0
    for _, row in ipairs(self.xpTable) do
        cumulativeWeighting = cumulativeWeighting + row.weighting
        if randomNumber <= cumulativeWeighting then
            return row.perk, row.amount
        end
    end
end

--- Utility method
---@param player IsoGameCharacter
function WWP_WorkplaceType:decreaseUnhappy(player, amount)
    local sadnessAdjust = player:getBodyDamage():getUnhappynessLevel()
    if(sadnessAdjust > 0) then
        sadnessAdjust = math.max(0, sadnessAdjust - amount)
        player:getBodyDamage():setUnhappynessLevel(sadnessAdjust)
    end
end

--- Utility method
---@param player IsoGameCharacter
function WWP_WorkplaceType:decreaseBoredom(player, amount)
    local boredomAdjust =  player:getBodyDamage():getBoredomLevel()
    if(boredomAdjust > 0) then
        boredomAdjust = math.max(0, boredomAdjust - amount)
        player:getBodyDamage():setBoredomLevel(boredomAdjust)
    end
end

--- Utility method
---@param player IsoGameCharacter
function WWP_WorkplaceType:decreaseStress(player, amount)
    amount = amount / 100 -- Stress is a decimal from 0.0 to 1.0, so consistent!
    local stressAdjust = WL_Stress.getTotal(player)
    if(stressAdjust > 0) then
        WL_Stress.adjust(-amount, player)
    end
end

--------------------------- Workplace Type Definitions  -------------------------------

WorkplaceClinic = WWP_WorkplaceType:new("clinic", "Clinic", "wp-clinic",  {
    { perk = Perks.Doctor, amount = 50, weighting = 8 },
    { perk = Perks.Lightfoot, amount = 50, weighting = 2 },
    { perk = Perks.SmallBlade, amount = 50, weighting = 1 },
})
WorkplaceClinic.actions = { WWP_WorkplaceAction.BANDAGES, WWP_WorkplaceAction.THREAD  }

function WorkplaceClinic:getWorkRequirements()
    return { perk = Perks.Doctor, level=5 }
end

function WorkplaceClinic:getBenefits()
    return {"+ Healing"}
end

---@param player IsoGameCharacter
function WorkplaceClinic:applyBenefits(player)
    local sicknessAdjust = player:getBodyDamage():getFoodSicknessLevel() - 3
    sicknessAdjust = math.max(sicknessAdjust, 0)
    player:getBodyDamage():setFoodSicknessLevel(sicknessAdjust)

    for i = 0, player:getBodyDamage():getBodyParts():size() - 1 do
        local bodyPart = player:getBodyDamage():getBodyParts():get(i)

        local bleedingTime = bodyPart:getBleedingTime()
        if(bleedingTime > 0) then
            bleedingTime = math.max(0, bleedingTime - 0.1)
            bodyPart:setBleedingTime(bleedingTime)
        end

        local scratchTime = bodyPart:getScratchTime()
        if(scratchTime > 0) then
            scratchTime = math.max(0, scratchTime - 0.3)
            bodyPart:setScratchTime(scratchTime)
        end

        local cutTime = bodyPart:getCutTime()
        if(cutTime > 0) then
            cutTime = math.max(0, cutTime - 0.12)
            bodyPart:setCutTime(cutTime)
        end

        local deepWoundTime = bodyPart:getDeepWoundTime()
        if(deepWoundTime > 0) then
            deepWoundTime = math.max(0, deepWoundTime - 0.06)
            bodyPart:setDeepWoundTime(deepWoundTime)
        end

        local fractureTime = bodyPart:getFractureTime()
        if(fractureTime > 0) then
            fractureTime = math.max(0, fractureTime - 0.01)
            bodyPart:setFractureTime(fractureTime)
        end

        local biteTime = bodyPart:getBiteTime()
        if(biteTime > 0) then
            biteTime = math.max(0, biteTime - 0.2)
            bodyPart:setBiteTime(biteTime)
        end
    end
end

function WorkplaceClinic:requireCustomersForRewards()
    return true
end

WorkplaceLibrary = WWP_WorkplaceType:new("library","Library", "wp-library",  {
    { perk = Perks.Lightfoot, amount = 15, weighting = 2 },
})

WorkplaceLibrary.actions = { WWP_WorkplaceAction.BOOKS }

function WorkplaceLibrary:getBenefits()
    return {"- Boredom"}
end

function WorkplaceLibrary:getWorkRequirements()
    return { trait="FastReader" }
end

---@param player IsoGameCharacter
function WorkplaceLibrary:applyBenefits(player)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceLibrary:requireEmployeesForBenefits()
    return false
end

function WorkplaceLibrary:requireSomeonePresentForRewards()
    return false
end

WorkplaceChineseRestaurant = WWP_WorkplaceType:new("restaurant_chinese", "Chinese Restaurant",
        "wp-restaurant_chinese", {
    { perk = Perks.Cooking, amount = 70, weighting = 10 },
    { perk = Perks.Nimble, amount = 5, weighting = 2 },
    { perk = Perks.SmallBlade, amount = 40, weighting = 2 },
})

WorkplaceChineseRestaurant.actions = { WWP_WorkplaceAction.COOKINGUTENSILS, WWP_WorkplaceAction.GLASSES }

function WorkplaceChineseRestaurant:getBenefits()
    return {"+ Happiness", "- Stress"}
end

--[[
function WorkplaceChineseRestaurant:getWorkRequirements()
    return { perk = Perks.Cooking, level=5 }
end--]]

---@param player IsoGameCharacter
function WorkplaceChineseRestaurant:applyBenefits(player)
    WWP_WorkplaceType:decreaseUnhappy(player, 10)
    WWP_WorkplaceType:decreaseStress(player, 10)
end

function WorkplaceChineseRestaurant:requireCustomersForRewards() return true end

WorkplaceFrenchRestaurant = WWP_WorkplaceType:new("restaurant_french", "French Restaurant",
        "wp-restaurant_french", {
    { perk = Perks.Cooking, amount = 70, weighting = 10 },
    { perk = Perks.Nimble, amount = 5, weighting = 2 },
    { perk = Perks.SmallBlade, amount = 20, weighting = 2 },
})

WorkplaceFrenchRestaurant.actions = { WWP_WorkplaceAction.COOKINGUTENSILS, WWP_WorkplaceAction.GLASSES }

--[[
function WorkplaceFrenchRestaurant:getWorkRequirements()
    return { perk = Perks.Cooking, level=5 }
end]]--

function WorkplaceFrenchRestaurant:getBenefits()
    return {"+ Happiness", "- Stress"}
end

---@param player IsoGameCharacter
function WorkplaceFrenchRestaurant:applyBenefits(player)
    WWP_WorkplaceType:decreaseUnhappy(player, 10)
    WWP_WorkplaceType:decreaseStress(player, 10)
end

function WorkplaceFrenchRestaurant:requireCustomersForRewards()
    return true
end

WorkplaceTailor = WWP_WorkplaceType:new("tailor","Tailor", "wp-tailor",  {
    { perk = Perks.Tailoring, amount = 70, weighting = 10 },
    { perk = Perks.Maintenance, amount = 25, weighting = 2 },
})

WorkplaceTailor.actions = { WWP_WorkplaceAction.YARN, WWP_WorkplaceAction.CLOTH, WWP_WorkplaceAction.THREAD,
                            WWP_WorkplaceAction.KEVLAR, WWP_WorkplaceAction.FABRICGLUE }

function WorkplaceTailor:getWorkRequirements()
    return { perk = Perks.Tailoring, level=5 }
end

function WorkplaceTailor:doSpeedyTicks() return true end
function WorkplaceTailor:requireCustomersForRewards() return true end
function WorkplaceTailor:getVisitorEnterSound() return "ShopDoorBell" end
function WorkplaceTailor:getVisitorExitSound() return "ShopDoorBell2" end

WorkplaceGeneralStore= WWP_WorkplaceType:new("general_store", "General Store",
        "wp-general_store", {
    { perk = Perks.Electricity, amount = 25, weighting = 1 },
    { perk = Perks.Maintenance, amount = 30, weighting = 3 },
    { perk = Perks.MetalWelding, amount = 25, weighting = 1 },
    { perk = Perks.Woodwork, amount = 25, weighting = 1 },
})

WorkplaceGeneralStore.actions = { WWP_WorkplaceAction.PAINTS, WWP_WorkplaceAction.COOKINGUTENSILS }

function WorkplaceGeneralStore:doSpeedyTicks() return true end
function WorkplaceGeneralStore:requireCustomersForRewards() return true end
function WorkplaceGeneralStore:getVisitorEnterSound() return "ShopDoorBell" end
function WorkplaceGeneralStore:getVisitorExitSound() return "ShopDoorBell2" end

WorkplaceMechanicShop = WWP_WorkplaceType:new("mechanic-shop", "Mechanic Shop",
        "wp-mechanic-shop", {
    { perk = Perks.Mechanics, amount = 50, weighting = 10 },
    { perk = Perks.Maintenance, amount = 20, weighting = 1 },
})

WorkplaceMechanicShop.actions = { WWP_WorkplaceAction.MECHTOOLS }

function WorkplaceMechanicShop:getWorkRequirements()
    return { perk = Perks.Mechanics, level=5 }
end

function WorkplaceMechanicShop:doSpeedyTicks() return true end
function WorkplaceMechanicShop:requireSomeonePresentForRewards() return false end

WorkplaceFarm = WWP_WorkplaceType:new("farm", "Farm", "wp-farm", {
    { perk = Perks.Farming, amount = 50, weighting = 10 },
    { perk = Perks.Spear, amount = 10, weighting = 1 },
})

WorkplaceFarm.actions = { WWP_WorkplaceAction.SEEDS, WWP_WorkplaceAction.RARE_SEEDS }

function WorkplaceFarm:getWorkRequirements()
    return { perk = Perks.Farming, level=5 }
end

function WorkplaceFarm:disableTickRewards() return true end
function WorkplaceFarm:getProducedCommodity() return WWP_Commodity.FARM_PRODUCE end

WorkplaceMunitionsFactory = WWP_WorkplaceType:new("munitions_factory", "Munitions Factory",
        "wp-munitions", {
    { perk = Perks.MetalWelding, amount = 30, weighting = 2 },
    { perk = Perks.Reloading, amount = 30, weighting = 4 },
    { perk = Perks.Gunsmith, amount = 50, weighting = 10 },
})

WorkplaceMunitionsFactory.actions = { WWP_WorkplaceAction.GUNPOWDERSHELL, WWP_WorkplaceAction.GUNTOOLS }

function WorkplaceMunitionsFactory:doSpeedyTicks() return true end
function WorkplaceMunitionsFactory:requireSomeonePresentForRewards() return false end

function WorkplaceMunitionsFactory:getWorkRequirements()
    return { perk = Perks.Gunsmith, level=5 }
end

WorkplaceGunFactory = WWP_WorkplaceType:new("gun-crafter", "Gun Crafter",
        "wp-gun-crafter", {
    { perk = Perks.MetalWelding, amount = 30, weighting = 3 },
    { perk = Perks.Gunsmith, amount = 40, weighting = 10 },
})

WorkplaceGunFactory.actions = { WWP_WorkplaceAction.GUNPARTS, WWP_WorkplaceAction.GUNTOOLS }

function WorkplaceGunFactory:getWorkRequirements()
    return { perk = Perks.Gunsmith, level=5 }
end

function WorkplaceGunFactory:doSpeedyTicks() return true end
function WorkplaceGunFactory:requireSomeonePresentForRewards() return false end

WorkplaceDrugLab = WWP_WorkplaceType:new("drug-lab", "Drug Lab", "wp-drug-lab", {
    { perk = Perks.Cooking, amount = 20, weighting = 1 },
})

WorkplaceDrugLab.actions = { WWP_WorkplaceAction.OXYCODONE, WWP_WorkplaceAction.XANAX, WWP_WorkplaceAction.COCAINE,
                             WWP_WorkplaceAction.CRACK, WWP_WorkplaceAction.SPEED, WWP_WorkplaceAction.METH,
                             WWP_WorkplaceAction.HEROIN }

function WorkplaceDrugLab:disableTickRewards() return true end

function WorkplaceDrugLab:getWorkRequirements()
    return { trait="Chemist" }
end

WorkplacePharmacy = WWP_WorkplaceType:new("pharmacy", "Pharmacy", "wp-pharmacy", {
    { perk = Perks.Doctor, amount = 30, weighting = 1 },
    { perk = Perks.Lightfoot, amount = 50, weighting = 2 },
})

WorkplacePharmacy.actions = { WWP_WorkplaceAction.INJECTABLES1, WWP_WorkplaceAction.INJECTABLES2, WWP_WorkplaceAction.ORAL }

function WorkplacePharmacy:disableTickRewards() return true end

function WorkplacePharmacy:getWorkRequirements()
    return { perk= Perks.Doctor, level=8 }
end

WorkplaceSoupKitchen = WWP_WorkplaceType:new("soup-kitchen", "Soup Kitchen",
        "wp-soup-kitchen", {
    { perk = Perks.Cooking, amount = 50, weighting = 13 },
    { perk = Perks.Fitness, amount = 500, weighting = 1 },
})

WorkplaceSoupKitchen.actions = {WWP_WorkplaceAction.SOUP, WWP_WorkplaceAction.SOUPTOOLS }

function WorkplaceSoupKitchen:getBenefits()
    return {"+ Happiness"}
end

function WorkplaceSoupKitchen:getWorkRequirements()
    return { perk = Perks.Cooking, level=3 }
end

function WorkplaceSoupKitchen:doSpeedyTicks() return true end

---@param player IsoGameCharacter
function WorkplaceSoupKitchen:applyBenefits(player)
    WWP_WorkplaceType:decreaseUnhappy(player, 10)
end

function WorkplaceSoupKitchen:requireCustomersForRewards()
    return true
end

WorkplaceGym = WWP_WorkplaceType:new("gym", "Gym", "wp-gym", {
    { perk = Perks.Strength, amount = 500, weighting = 3 },
    { perk = Perks.Fitness, amount = 500, weighting = 7 },
})

WorkplaceGym.actions = { WWP_WorkplaceAction.PROTEIN, WWP_WorkplaceAction.JUICE,
                       WWP_WorkplaceAction.TOWEL }

function WorkplaceGym:getWorkRequirements()
    return { perk = Perks.Fitness, level=8 }
end

function WorkplaceGym:getBenefits()
    return {"+ Fitness", "+ Strength", "- Boredom"}
end

---@param player IsoGameCharacter
function WorkplaceGym:applyBenefits(player)
    WL_Utils.gainXP(Perks.Fitness, 250 )
    WL_Utils.gainXP(Perks.Strength, 160)

    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceGym:requireCustomersForRewards()
    return true
end

WorkplaceFishingPier = WWP_WorkplaceType:new("fishing-pier", "Fishing Pier",
        "wp-fishing-pier",{ 		-- see PerkFactory.Perks : zombie.characters.skills.PerkFactory.Perks
    { perk = Perks.Fishing, amount = 50, weighting = 15 },
    { perk = Perks.Spear, amount = 30, weighting = 1 },
})

function WorkplaceFishingPier:doSpeedyTicks() return true end
function WorkplaceFishingPier:requireSomeonePresentForRewards() return false end

function WorkplaceFishingPier:getWorkRequirements()
    return { perk = Perks.Fishing, level=5 }
end

WorkplaceFishingPier.actions = { WWP_WorkplaceAction.FISHING_SUPPLIES }

WorkplaceCafe = WWP_WorkplaceType:new("cafe", "Cafe", "wp-cafe", { 		-- see PerkFactory.Perks : zombie.characters.skills.PerkFactory.Perks
    { perk = Perks.Cooking, amount = 50, weighting = 8 },
    { perk = Perks.Nimble, amount = 5, weighting = 2 },
})

WorkplaceCafe.actions = { WWP_WorkplaceAction.GLASSES, WWP_WorkplaceAction.CROCKWARE}

function WorkplaceCafe:getWorkRequirements()
    return { perk = Perks.Cooking, level=2 }
end

function WorkplaceCafe:getBenefits()
    return {"+ Happiness", "- Boredom"}
end

---@param player IsoGameCharacter
function WorkplaceCafe:applyBenefits(player)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
    WWP_WorkplaceType:decreaseUnhappy(player, 10)
end

function WorkplaceCafe:requireCustomersForRewards()
    return true
end

WorkplaceOffice = WWP_WorkplaceType:new("office","Office", "wp-office", {
    { perk = Perks.Electricity, amount = 20, weighting = 5 },
    { perk = Perks.Maintenance, amount = 20, weighting = 2 },
})

function WorkplaceOffice:requireCustomersForRewards()
    return true
end

WorkplaceOffice.actions = { WWP_WorkplaceAction.STATIONARY, WWP_WorkplaceAction.BREAKROOM }

WorkplaceLoggingCamp = WWP_WorkplaceType:new("logging_camp","Logging Camp", "wp-logging", {
    { perk = Perks.Axe, amount = 25, weighting = 10 },
    { perk = Perks.Woodwork, amount = 50, weighting = 2 },
    { perk = Perks.Strength, amount = 700, weighting = 4 },
    { perk = Perks.PlantScavenging, amount = 35, weighting = 1 },
})

function WorkplaceLoggingCamp:getProducedCommodity() return WWP_Commodity.LUMBER end
function WorkplaceLoggingCamp:disableTickRewards() return true end

function WorkplaceLoggingCamp:getWorkRequirements()
    return { perk = Perks.Axe, level=1 }
end

WorkplaceLoggingCamp.actions = { WWP_WorkplaceAction.AXE, WWP_WorkplaceAction.LOGTRASH, }


local function isPlantableSquare(square)
    if not square then return false end
    if not square:isOutside() then return false end
    if CFarmingSystem.instance:getLuaObjectOnSquare(square) then
		return false
	end
	if not square:isFreeOrMidair(true, true) then return false end
	for i = 0, square:getObjects():size() - 1 do
		local item = square:getObjects():get(i)
		if item:getTextureName() and (luautils.stringStarts(item:getTextureName(), "floors_exterior_natural") or
				luautils.stringStarts(item:getTextureName(), "blends_natural_01")) then
			return true
		end
	end
    return false
end

local function scanAreaTrees(workplace)
    local growableTrees = {}
    local plantableSquares = {}
    for x = workplace.minX, workplace.maxX do
        for y = workplace.minY, workplace.maxY do
            local cSquare = getCell():getGridSquare(x, y, 0)
            if cSquare then
                local tree = cSquare:getTree()
                if tree then
                    if tree:getSize() < 6 then
                        table.insert(growableTrees, cSquare)
                    end
                else
                    if cSquare:getX() % 2 == 0 and cSquare:getY() % 2 == 0 then
                        if isPlantableSquare(cSquare) then
                            table.insert(plantableSquares, cSquare)
                        end
                    end
                end
            end
        end
    end
    return growableTrees, plantableSquares
end

local function tryGrowTree(growableSquares)
    if #growableSquares > 0 then
        local index = ZombRand(#growableSquares)+1
        local square = growableSquares[index]
        local tree = square:getTree()
        if not tree then return false end
        if tree:getSize() <= 5 then
            table.remove(growableSquares, index)
        end
        WL_Utils.GrowTree(square)
        return true
    end
    return false
end

local function tryPlantTree(plantableSquares)
    if #plantableSquares > 0 then
        local index = ZombRand(#plantableSquares)+1
        local square = plantableSquares[index]
        table.remove(plantableSquares, index)
        WL_Utils.SpawnTree(square, nil, 1)
        return true
    else
        if getDebug() then print("No squares available for planting") end
        return false
    end
end

function WorkplaceLoggingCamp:onMinuteTick(player, workplace)
    if not workplace or not workplace.open or (not workplace:isEmployee(player) and not workplace.isNPC) then return end
    local growableSquares, plantableSquares = scanAreaTrees(workplace)
    for i=1,8 do
        if ZombRand(5) < 3 and #growableSquares > 0 then
            if getDebug() then print("Growing tree...") end
            tryGrowTree(growableSquares)
        elseif #plantableSquares > 0 then
            if getDebug() then print("Planting tree...") end
            tryPlantTree(plantableSquares)
        else
            if getDebug() then print("No action...") end
        end
    end
end

if getActivatedMods():contains("WastelandBuilds") then
    WorkplaceQuarry = WWP_WorkplaceType:new("quarry", "Quarry", "wp-mine", {
        { perk = Perks.Strength, amount = 500, weighting = 5 },
        { perk = Perks.Fitness,  amount = 500, weighting = 5 },
    })

    WorkplaceQuarry.actions = { WWP_WorkplaceAction.MINE, WWP_WorkplaceAction.MINETOOLS }
    function WorkplaceQuarry:disableTickRewards() return true end

    function WorkplaceQuarry:onMinuteTick(player, workplace)
        if not workplace or not workplace.open or not workplace:isEmployee(player) then return end
        local possibleSquares = {}
        for x = workplace.minX, workplace.maxX do
            for y = workplace.minY, workplace.maxY do
                for z = workplace.minZ, workplace.maxZ do
                    local cSquare = getCell():getGridSquare(x, y, z)
                    if cSquare and WBStoning.IsSuitableSquare(cSquare) and WBStoning.IsClear(cSquare) then
                        table.insert(possibleSquares, cSquare)
                    end
                end
            end
        end
        if #possibleSquares == 0 then return "Warning: No suitable tiles" end
        local squareToReplace = possibleSquares[ZombRand(#possibleSquares) + 1]
        WBStoning.AddStone(squareToReplace, ZombRand(10, 20))
        return "Added Stone"
    end
end

if getActivatedMods():contains("WastelandBuilds") then
    WorkplaceMine = WWP_WorkplaceType:new("iron_mine","Iron Mine", "wp-mine", {
        { perk = Perks.Strength, amount = 500, weighting = 5 },
        { perk = Perks.Fitness, amount = 500, weighting = 5 },
    })

    WorkplaceMine.actions = {  WWP_WorkplaceAction.MINE_IRON, WWP_WorkplaceAction.MINETOOLS }
    function WorkplaceMine:disableTickRewards() return true end

    function WorkplaceMine:onMinuteTick(player, workplace)
        if not workplace or not workplace.open or not workplace:isEmployee(player) then return end
        local possibleSquares = {}
        for x = workplace.minX, workplace.maxX do
            for y = workplace.minY, workplace.maxY do
                for z = workplace.minZ, workplace.maxZ do
                    local cSquare = getCell():getGridSquare(x, y, z)
                    if cSquare and WBStoning.IsSuitableSquare(cSquare) and WBStoning.IsClear(cSquare) then
                        table.insert(possibleSquares, cSquare)
                    end
                end
            end
        end
        if #possibleSquares == 0 then return "Warning: No suitable tiles" end
        local squareToReplace = possibleSquares[ZombRand(#possibleSquares)+1]
        WBStoning.AddStone(squareToReplace, ZombRand(10, 20))
        return "Added Stone"
    end
end

if getActivatedMods():contains("WastelandBuilds") then
    WorkplaceZeoliteMine = WWP_WorkplaceType:new("zeolitemine","Zeolite Mine", "wp-zeolitemine", {
        { perk = Perks.Strength, amount = 500, weighting = 5 },
        { perk = Perks.Fitness, amount = 500, weighting = 5 },
    })

    WorkplaceZeoliteMine.actions = { WWP_WorkplaceAction.MINEZEOLITE, WWP_WorkplaceAction.MINETOOLS }

    function WorkplaceZeoliteMine:disableTickRewards() return true end

    function WorkplaceZeoliteMine:getWorkRequirements()
        return { trait="MiningTech" }
    end

    function WorkplaceZeoliteMine:onMinuteTick(player, workplace)
        if not workplace or not workplace.open or not workplace:isEmployee(player) then return end

        local possibleSquares = {}
        for x = workplace.minX, workplace.maxX do
            for y = workplace.minY, workplace.maxY do
                for z = workplace.minZ, workplace.maxZ do
                    local cSquare = getCell():getGridSquare(x, y, z)
                    if cSquare and WBStoning.IsSuitableSquare(cSquare) and WBStoning.IsClear(cSquare) then
                        table.insert(possibleSquares, cSquare)
                    end
                end
            end
        end
        if #possibleSquares == 0 then return "Warning: No suitable tiles" end
        local squareToReplace = possibleSquares[ZombRand(#possibleSquares)+1]
        WBStoning.AddStone(squareToReplace, ZombRand(10, 20))
        return "Added Stone"
    end
end

WorkplaceMusicStore = WWP_WorkplaceType:new("music-store", "Music Store", "wp-music-store", {
    { perk = Perks.PseudonymousEdPiano, amount = 50, weighting = 10 },
})

WorkplaceMusicStore.actions = { WWP_WorkplaceAction.ELECTRIC_GUITARS, WWP_WorkplaceAction.INSTRUMENTS,
                                 WWP_WorkplaceAction.CASSETTES, WWP_WorkplaceAction.MUSIC_SHEET }

function WorkplaceMusicStore:doSpeedyTicks() return true end
function WorkplaceMusicStore:getVisitorEnterSound() return "ShopDoorBell" end
function WorkplaceMusicStore:getVisitorExitSound() return "ShopDoorBell2" end
function WorkplaceMusicStore:requireCustomersForRewards() return true end

WorkplaceBrewery = WWP_WorkplaceType:new("brewery", "Brewery", "wp-brewery", {
            { perk = Perks.Brewing, amount = 50, weighting = 10 },
            { perk = Perks.WineMaking, amount = 50, weighting = 10 },
        })
function WorkplaceBrewery:doSpeedyTicks() return true end
function WorkplaceBrewery:requireSomeonePresentForRewards() return false end

WorkplaceBrewery.actions = { WWP_WorkplaceAction.BREWING_SUPPLIES }

function WorkplaceBrewery:getWorkRequirements()
    return { perk = Perks.Brewing, level=3 }
end

WorkplaceBar = WWP_WorkplaceType:new("bar", "Bar", "wp-bar",{
    { perk = Perks.Nimble, amount = 2, weighting = 3 },
})

WorkplaceBar.actions = { WWP_WorkplaceAction.GLASSES }

function WorkplaceBar:getBenefits()
    return {"+ Happiness", "- Boredom"}
end

---@param player IsoGameCharacter
function WorkplaceBar:applyBenefits(player)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
    WWP_WorkplaceType:decreaseUnhappy(player, 10)
end

function WorkplaceBar:requireCustomersForRewards() return true end

WorkplaceHuntingGrounds = WWP_WorkplaceType:new("hunting_grounds", "Hunting Grounds",
        "wp-trapper", { 	-- see PerkFactory.Perks : zombie.characters.skills.PerkFactory.Perks
    { perk = Perks.Trapping, amount = 40, weighting = 9 },
    { perk = Perks.Lightfoot, amount = 35, weighting = 4 },
    { perk = Perks.Sneak, amount = 35, weighting = 4 },
    { perk = Perks.PlantScavenging, amount = 30, weighting = 3 },
})

WorkplaceHuntingGrounds.actions = { WWP_WorkplaceAction.FORAGE, WWP_WorkplaceAction.HUNT }

function WorkplaceHuntingGrounds:getWorkRequirements()
    return { perk = Perks.Trapping, level=5 }
end

function WorkplaceHuntingGrounds:doSpeedyTicks() return true end
function WorkplaceHuntingGrounds:requireSomeonePresentForRewards() return false end

WorkplaceScrapyard = WWP_WorkplaceType:new("scrapyard","Scrapyard", "wp-scrapyard",  {
    { perk = Perks.MetalWelding, amount = 50, weighting = 6 },
    { perk = Perks.Mechanics, amount = 30, weighting = 1 },
})

WorkplaceScrapyard.actions = { WWP_WorkplaceAction.SCRAP_METAL, WWP_WorkplaceAction.SCRAP_ELECTRONICS,  }

function WorkplaceScrapyard:getWorkRequirements()
    return { perk = Perks.MetalWelding, level=5 }
end

function WorkplaceScrapyard:getProducedCommodity() return WWP_Commodity.METAL_SALVAGE end
function WorkplaceScrapyard:disableTickRewards() return true end


WorkplaceButcher = WWP_WorkplaceType:new("butcher","Butcher", "wp-butcher", {
    { perk = Perks.Trapping, amount = 35, weighting = 2 },
    { perk = Perks.Cooking, amount = 35, weighting = 2 },
    { perk = Perks.Fishing, amount = 35, weighting = 2 },
})

WorkplaceButcher.actions = { WWP_WorkplaceAction.MEATUTENSILS, WWP_WorkplaceAction.MEATEXTRAS }


function WorkplaceButcher:getWorkRequirements()
    return { perk = Perks.Cooking, level=3 }
end

---@param player IsoGameCharacter
function WorkplaceButcher:requireEmployeesForBenefits() return false end

function WorkplaceButcher:requireSomeonePresentForRewards() return false end

function WorkplaceButcher:doSpeedyTicks() return true end

WorkplaceGreengrocer = WWP_WorkplaceType:new("greengrocer","Greengrocer", "wp-greengrocer", {
    { perk = Perks.Farming, amount = 35, weighting = 2 },
})

WorkplaceGreengrocer.actions = { WWP_WorkplaceAction.SACKS }

--[[
function WorkplaceGreengrocer:getWorkRequirements()
    return { perk = Perks.Farming, level=2 }
end--]]

function WorkplaceGreengrocer:requireSomeonePresentForRewards() return true end

function WorkplaceGreengrocer:doSpeedyTicks() return true end

WorkplaceFishnchips = WWP_WorkplaceType:new("fishnchips","Fish 'n Chips", "wp-fishnchips", {
    { perk = Perks.Fishing, amount = 35, weighting = 2 },
    { perk = Perks.Cooking, amount = 35, weighting = 2 },
})

WorkplaceFishnchips.actions = { WWP_WorkplaceAction.PAPER_BAGS }

function WorkplaceFishnchips:getBenefits()
    return {"- Stress"}
end

function WorkplaceFishnchips:getWorkRequirements()
    return { perk = Perks.Cooking, level=3 }
end

---@param player IsoGameCharacter
function WorkplaceFishnchips:applyBenefits(player)
    WWP_WorkplaceType:decreaseStress(player, 10)
end

function WorkplaceFishnchips:requireCustomersForRewards() return true end

function WorkplaceFishnchips:doSpeedyTicks() return true end

WorkplaceRadioStation = WWP_WorkplaceType:new("radiostation","Radio Station", "wp-radiostation", {
    { perk = Perks.Electricity, amount = 35, weighting = 2 },
})

WorkplaceRadioStation.actions = { WWP_WorkplaceAction.CLEAN_TAPES, WWP_WorkplaceAction.FIX_RADIOS, }

function WorkplaceRadioStation:getBenefits()
    return {"- Stress", "- Boredom"}
end

--[[
function WorkplaceRadioStation:getWorkRequirements()
    return { perk = Perks.Electricity, level=2 }
end--]]

---@param player IsoGameCharacter
function WorkplaceRadioStation:applyBenefits(player)
    WWP_WorkplaceType:decreaseStress(player, 10)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceRadioStation:requireEmployeesForBenefits() return false end

function WorkplaceRadioStation:requireSomeonePresentForRewards() return false end

function WorkplaceRadioStation:doSpeedyTicks() return true end

WorkplaceTattooParlor = WWP_WorkplaceType:new("tattooparlor","Tattoo Parlour", "wp-tattooparlor", {
    { perk = Perks.Nimble, amount = 2, weighting = 3 },
})

WorkplaceTattooParlor.actions = { WWP_WorkplaceAction.RECHARGE_INK, WWP_WorkplaceAction.ORDER_INK,
                                    WWP_WorkplaceAction.STERALISE_SURFACE }

function WorkplaceTattooParlor:getBenefits()
    return {"- Boredom"}
end

function WorkplaceTattooParlor:getWorkRequirements()
    return { perk = Perks.Nimble, level=2 }
end

---@param player IsoGameCharacter
function WorkplaceTattooParlor:applyBenefits(player)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceTattooParlor:requireEmployeesForBenefits() return true end

function WorkplaceTattooParlor:requireSomeonePresentForRewards() return true end

function WorkplaceTattooParlor:doSpeedyTicks() return true end

WorkplaceSawMill = WWP_WorkplaceType:new("sawmill","Saw Mill", "wp-sawmill", {
    { perk = Perks.Woodwork, amount = 35, weighting = 3 },
})

WorkplaceSawMill.actions = { WWP_WorkplaceAction.PROCESS_LUMBER }

function WorkplaceSawMill:getBenefits()
    return {"- Boredom"}
end

function WorkplaceSawMill:getWorkRequirements()
    return { perk = Perks.Woodwork, level=5 }
end

---@param player IsoGameCharacter
function WorkplaceSawMill:applyBenefits(player)
    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceSawMill:requireEmployeesForBenefits() return false end

function WorkplaceSawMill:requireSomeonePresentForRewards() return false end

function WorkplaceSawMill:doSpeedyTicks() return true end

WorkplaceSwordDojo = WWP_WorkplaceType:new("sword-dojo", "Sword Dojo", "wp-gym", {
    { perk = Perks.LongBlade, amount = 20, weighting = 10 },
    { perk = Perks.Strength, amount = 100, weighting = 3 },
    { perk = Perks.Fitness, amount = 200, weighting = 7 },
})

WorkplaceSwordDojo.actions = {  }

function WorkplaceSwordDojo:getWorkRequirements()
    return { perk = Perks.LongBlade, level=5 }
end

function WorkplaceSwordDojo:getBenefits()
    return {"+ Long Blade", "+ Fitness", "+ Strength", "- Boredom"}
end

---@param player IsoGameCharacter
function WorkplaceSwordDojo:applyBenefits(player)

    -- These benefit from XP multipliers (the second bool arg) so we need to be careful with them
    -- However this requires an employee to be there for the whole time!
    WL_Utils.gainXP(Perks.Fitness, 150)
    WL_Utils.gainXP(Perks.Strength, 50)

    -- Can't learn more than the teacher knows
    if player:getPerkLevel(Perks.LongBlade) < 5 then
        -- This is 1 per minute forever...
        WL_Utils.gainXP(Perks.LongBlade, 1.5)
    end

    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceSwordDojo:requireCustomersForRewards()
    return true
end


WorkplaceShootingRange = WWP_WorkplaceType:new("shooting-range", "Shooting Range", "wp-gym", {
    { perk = Perks.Aiming, amount = 15, weighting = 9 },
    { perk = Perks.Reloading, amount = 15, weighting = 6 },
    { perk = Perks.Sneak, amount = 25, weighting = 3 },
})

WorkplaceShootingRange.actions = {  }

function WorkplaceShootingRange:getWorkRequirements()
    return { perk = Perks.Aiming, level=6 }
end

function WorkplaceShootingRange:getBenefits()
    return {"+ Aiming", "+ Reloading", "+ Sneak", "- Boredom"}
end

---@param player IsoGameCharacter
function WorkplaceShootingRange:applyBenefits(player)

    -- Can't learn more than the teacher knows
    if player:getPerkLevel(Perks.Aiming) < 6 then
        grantXp(player, Perks.Aiming, 1)
    end

    if player:getPerkLevel(Perks.Reloading) < 6 then
        grantXp(player, Perks.Reloading, 1)
    end

    WWP_WorkplaceType:decreaseBoredom(player, 10)
end

function WorkplaceShootingRange:requireCustomersForRewards()
    return true
end
