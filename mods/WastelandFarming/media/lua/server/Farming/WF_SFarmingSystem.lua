local original_ISObjectClickHandler_doClickLightSwitch = ISObjectClickHandler.doClickLightSwitch
function ISObjectClickHandler.doClickLightSwitch(object, playerNum, playerObj)
    if WFGrowLampUtilities.isGrowLampLight(object) then
        if isClient() then
            local args = {
                x = object:getSquare():getX(),
                y = object:getSquare():getY(),
                z = object:getSquare():getZ(),
                s = not object:isActivated()
            }
            sendClientCommand(playerObj, 'farming', 'toggleGrowLamp', args)
        else
            WFGrowLampUtilities.toggleGrowLamp(object:getSquare(), not object:isActivated())
        end
        return true
    end
    return original_ISObjectClickHandler_doClickLightSwitch(object, playerNum, playerObj)
end

if isClient() then return end

require "Farming/SFarmingSystem"
require "Farming/SGFarmingSystem"

if farming_vegetableconf.props["Tea"] then farming_vegetableconf.props["Tea"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Coffee"] then farming_vegetableconf.props["Coffee"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Latex"] then farming_vegetableconf.props["Latex"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Rose"] then farming_vegetableconf.props["Rose"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Carnation"] then farming_vegetableconf.props["Carnation"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Larkspur"] then farming_vegetableconf.props["Larkspur"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Dahlia"] then farming_vegetableconf.props["Dahlia"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Delphi"] then farming_vegetableconf.props["Delphi"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Daisy"] then farming_vegetableconf.props["Daisy"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Penta"] then farming_vegetableconf.props["Penta"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Geranium"] then farming_vegetableconf.props["Geranium"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Bird"] then farming_vegetableconf.props["Bird"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Mutton"] then farming_vegetableconf.props["Mutton"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Pork"] then farming_vegetableconf.props["Pork"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Beef"] then farming_vegetableconf.props["Beef"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Wool"] then farming_vegetableconf.props["Wool"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Milk"] then farming_vegetableconf.props["Milk"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Egg"] then farming_vegetableconf.props["Egg"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Honey"] then farming_vegetableconf.props["Honey"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Leek"] then farming_vegetableconf.props["Leek"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Lettuce"] then farming_vegetableconf.props["Lettuce"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Onion"] then farming_vegetableconf.props["Onion"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["SoyBean"] then farming_vegetableconf.props["SoyBean"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Pumpkin"] then farming_vegetableconf.props["Pumpkin"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Watermelon"] then farming_vegetableconf.props["Watermelon"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Zucchini"] then farming_vegetableconf.props["Zucchini"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Corn"] then farming_vegetableconf.props["Corn"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Ginger"] then farming_vegetableconf.props["Ginger"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Pineapple"] then farming_vegetableconf.props["Pineapple"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Wheat"] then farming_vegetableconf.props["Wheat"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["SugarCane"] then farming_vegetableconf.props["SugarCane"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Ginseng"] then farming_vegetableconf.props["Ginseng"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Mushroom"] then farming_vegetableconf.props["Mushroom"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["BellPepper"] then farming_vegetableconf.props["BellPepper"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["BerryBlack"] then farming_vegetableconf.props["BerryBlack"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["BerryBlue"] then farming_vegetableconf.props["BerryBlue"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Lemongrass"] then farming_vegetableconf.props["Lemongrass"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Eggplant"] then farming_vegetableconf.props["Eggplant"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Grape"] then farming_vegetableconf.props["Grape"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Rice"] then farming_vegetableconf.props["Rice"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["PepperPlant"] then farming_vegetableconf.props["PepperPlant"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Hops"] then farming_vegetableconf.props["Hops"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Cotton"] then farming_vegetableconf.props["Cotton"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["Pear"] then farming_vegetableconf.props["Pear"].seedPerVegVar = {1,5} end
if farming_vegetableconf.props["CommonMallow"] then farming_vegetableconf.props["CommonMallow"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Plantain"] then farming_vegetableconf.props["Plantain"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Comfrey"] then farming_vegetableconf.props["Comfrey"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Garlic"] then farming_vegetableconf.props["Garlic"].seedPerVegVar = {1,3} end
if farming_vegetableconf.props["Sage"] then farming_vegetableconf.props["Sage"].seedPerVegVar = {1,3} end


-- Override to attach luaObject temporarily so
-- that we can use the amount of fertilizer on the plant to
-- reduce the grow time.
local original_SFarmingSystem_growPlant = SFarmingSystem.growPlant
function SFarmingSystem:growPlant(luaObject, nextGrowing, updateNbOfGrow)
    SFarmingSystem.WF_currentLuaObject = luaObject
    original_SFarmingSystem_growPlant(self, luaObject, nextGrowing, updateNbOfGrow)
    SFarmingSystem.WF_currentLuaObject = nil
end

-- Override to reduce the grow time of the plant based on the
-- amount of fertilizer on the plant.
function calcNextGrowing(nextGrowing, nextTime)
	if nextGrowing then
		return nextGrowing;
	end
    if SandboxVars.Farming == 1 then -- very fast
        nextTime = nextTime / 3;
    end
    if SandboxVars.Farming == 2 then -- fast
        nextTime = nextTime / 1.5;
    end
    if SandboxVars.Farming == 4 then -- slow
        nextTime = nextTime * 1.5;
    end
    if SandboxVars.Farming == 5 then -- very slow
        nextTime = nextTime * 3;
    end
    if SFarmingSystem.WF_currentLuaObject then
        local reduction = 0
        if SFarmingSystem.WF_currentLuaObject.fertilizer then
            reduction = SFarmingSystem.WF_currentLuaObject.fertilizer * 0.1 -- fertilizer reduces grow time by 10% per point
        end
        if SFarmingSystem.WF_currentLuaObject.lightEnabled then
            reduction = reduction + 0.1 -- grow lamp reduces grow time by 10%
        end
        if reduction > 0 then
            nextTime = nextTime - (nextTime * reduction)
        end
    end
	return SFarmingSystem.instance.hoursElapsed + nextTime;
end

-- Override to attach player to the luaObject temporarily so
-- that we can use the player's farming skill to determine
-- the yield of the plant.
-- Also will adjust the seedsPerVeg if a range is specified.
local original_SFarmingSystem_harvest = SFarmingSystem.harvest
function SFarmingSystem:harvest(luaObject, player)
    luaObject.harvestPlayer = player
    local props = farming_vegetableconf.props[luaObject.typeOfSeed]
    if props.seedPerVegVar ~= nil then
        props.seedPerVeg = ZombRand(props.seedPerVegVar[1], props.seedPerVegVar[2] + 1)
    end
    original_SFarmingSystem_harvest(self, luaObject, player)
    luaObject.harvestPlayer = nil
end

local lastCheckPlantIdx = 1
local plantsToCheckPerTick = 999
local checkPlantsTicker = false

local function checkPlantsTickerCallback()
    SFarmingSystem.instance:checkPlant()
end

-- Override checking plants to reset the grow time for level 7 plants
-- to prevent in-ground rotting and optimize the loops
function SFarmingSystem:checkPlant()
    local trueCount = self:getLuaObjectCount()
    local max = math.min(trueCount, lastCheckPlantIdx + plantsToCheckPerTick)
    for i=lastCheckPlantIdx,max do
		local luaObject = self:getLuaObjectByIndex(i)
        if luaObject.state ~= "plow" and luaObject.state ~= "destroy" then
            local square = luaObject:getSquare()
            if square then
                luaObject.exterior = square:isOutside()
            end
            -- we may destroy our plant if someone walk onto it
            self:destroyOnWalk(luaObject)
            -- Something can grow up !
            if luaObject.nextGrowing ~= nil then
                if self.hoursElapsed >= luaObject.nextGrowing then
                    self:growPlant(luaObject, nil, true)
                end
            end
            -- if the plant still alive
            if luaObject.state ~= "plow" and luaObject:isAlive() then
                if luaObject.nbOfGrow == 7 then
                    luaObject.nextGrowing = self.hoursElapsed + 9999
                end
                if square then
                    self:CheckSquare(square, luaObject)
                end
                -- check the last water hour of all our plant, if it's more than 76 hours the plant start to lose health
                -- if it's raining we up a little the water lvl of the plant
                if RainManager.isRaining() then
                    if luaObject.exterior then
                        luaObject.waterLvl = luaObject.waterLvl + 3
                        if luaObject.waterLvl > 100 then
                            luaObject.waterLvl = 100
                        end
                        luaObject.lastWaterHour = self.hoursElapsed
                    end
                -- if it's sunny, we lower a bit our water lvl
                elseif season.weather == "sunny" then
                    luaObject.waterLvl = luaObject.waterLvl - 0.1
                    if luaObject.waterLvl < 0 then
                        luaObject.waterLvl = 0
                    end
                end
            end
            -- add the icon if we have the required farming xp and if we're close enough of the plant
            luaObject:addIcon()
            luaObject:checkStat()
            luaObject:saveData()
        end
	end
    lastCheckPlantIdx = max+1
    if max < trueCount then
        if not checkPlantsTicker then
            checkPlantsTicker = true
            Events.OnTick.Add(checkPlantsTickerCallback)
        end
    else
        if checkPlantsTicker then
            checkPlantsTicker = false
            Events.OnTick.Remove(checkPlantsTickerCallback)
        end
        lastCheckPlantIdx = 1
    end
end

-- Kill plants in winter

local winterPlants = ArrayList.new()
winterPlants:add("Olive")
winterPlants:add("GrapeFruit")
winterPlants:add("Lemon")
winterPlants:add("Lime")
winterPlants:add("Orange")
winterPlants:add("Apple")
winterPlants:add("Banana")
winterPlants:add("Cherry")
winterPlants:add("Mango")
winterPlants:add("Pear")
winterPlants:add("Peach")
winterPlants:add("Milk")
winterPlants:add("Egg")
winterPlants:add("Wool")
winterPlants:add("Beef")
winterPlants:add("Pork")
winterPlants:add("Mutton")
winterPlants:add("Bird")
winterPlants:add("Honey")
winterPlants:add("Latex")

local function survivesWinter(luaObject)
    return winterPlants:contains(luaObject.typeOfSeed) and luaObject.nbOfGrow >= 4
end

local function hasPoweredLamp(sq)
    if not sq or not sq:haveElectricity() then return false end

    local objects = sq:getObjects()
    for i=0,objects:size()-1 do
        if WFGrowLampUtilities.isGrowLamp(objects:get(i)) then
            return true
        end
    end
    return false
end

function SFarmingSystem:CheckSquare(square, luaObject)
    for x=square:getX()-3,square:getX()+3 do
        for y=square:getY()-3,square:getY()+3 do
            local checkSquare = getCell():getGridSquare(x, y, square:getZ())
            if checkSquare then
                if hasPoweredLamp(checkSquare) then
                    luaObject.lightEnabled = true
                    return
                end
            end
        end
    end
    luaObject.lightEnabled = false
end

function SFarmingSystem:CheckTemperture(luaObject)
    if luaObject.state == "seeded" and luaObject.exterior and not survivesWinter(luaObject) then
        luaObject.health = luaObject.health - 0.5
        return true
    end
    return false
end

-- will lower health of any plant that is inside and not under a grow lamp
function SFarmingSystem:CheckGrowLamp(luaObject)
    if luaObject.state == "seeded" and not luaObject.exterior and not luaObject.lightEnabled then
        luaObject.health = luaObject.health - 0.5
        return true
    end
    return false
end

function SFarmingSystem:checkHealthPlant(luaObject, temp)
    if temp < 0 then
        if self:CheckTemperture(luaObject) then
            -- health was lowered, no need to check other conditions
            return
        end
    end

    if SandboxVars.WastelandFarming.EnableIndoorPenaltyWithoutLamp then
        if self:CheckGrowLamp(luaObject) then
            -- health was lowered, no need to check other conditions
            return
        end
    end

    -- change with weather
    local weather = getWorld():getWeather()
    if "sunny" == weather then -- if it's sunny
        if luaObject.exterior then
            luaObject.health = luaObject.health + 1
        else
            luaObject.health = luaObject.health + 0.25
        end
    end

    -- change with water
    local water = farming_vegetableconf.calcWater(luaObject.waterNeeded, luaObject.waterLvl)
    local waterMax = farming_vegetableconf.calcWater(luaObject.waterLvl, luaObject.waterNeededMax)

    if water >= 0 and waterMax >= 0 then
        luaObject.health = luaObject.health + 0.4
    elseif water == -1 then -- we low health by 0.2
        luaObject.health = luaObject.health - 0.2
    elseif water == -2 then -- low health by 0.5
        luaObject.health = luaObject.health - 0.5
    elseif waterMax == -1 and luaObject.health > 20  then
        luaObject.health = luaObject.health - 0.2
    elseif waterMax == -2 and luaObject.health > 20  then
        luaObject.health = luaObject.health - 0.5
    end
end

function SFarmingSystem:changeHealth()
    local temp = getClimateManager():getTemperature()
	for i=1,self:getLuaObjectCount() do
		local luaObject = self:getLuaObjectByIndex(i)
        self:checkHealthPlant(luaObject, temp)
	end
end

Events.OnClientCommand.Add(function (module, command, player, args)
    if module == "farming" then
        if command == "tend" then
            local x = tonumber(args.x)
            local y = tonumber(args.y)
            local z = tonumber(args.z)
            local farmingLevel = player:getPerkLevel(Perks.Farming)
            local square = getCell():getGridSquare(x, y, z)
            if square then
                local luaObject = SFarmingSystem.instance:getLuaObjectOnSquare(square)
                if luaObject and luaObject.state == "seeded" and luaObject.nbOfGrow < 7 then
                    luaObject.lastTendHour = SFarmingSystem.instance.hoursElapsed
                    local timeRemaining = luaObject.nextGrowing - SFarmingSystem.instance.hoursElapsed
                    if timeRemaining > 0 then
                        local reduction = player:getPerkLevel(Perks.Farming) * 0.01 -- farming skill reduces grow time by 1% per level
                        luaObject.nextGrowing = SFarmingSystem.instance.hoursElapsed + (timeRemaining * (1 - reduction))
                    end
                    if luaObject.aphidLvl > 0 then
                        local amtToRemove = math.min(farmingLevel, luaObject.aphidLvl)
                        luaObject.aphidLvl = math.max(0, luaObject.aphidLvl - amtToRemove)
                        luaObject.health = math.max(0, luaObject.health - amtToRemove)
                    end
                    if luaObject.mildewLvl > 0 then
                        local amtToRemove = math.min(farmingLevel, luaObject.mildewLvl)
                        luaObject.mildewLvl = math.max(0, luaObject.mildewLvl - amtToRemove)
                        luaObject.health = math.max(0, luaObject.health - amtToRemove)
                    end
                    if luaObject.fliesLvl > 0 then
                        local amtToRemove = math.min(farmingLevel, luaObject.fliesLvl)
                        luaObject.fliesLvl = math.max(0, luaObject.fliesLvl - amtToRemove)
                        luaObject.health = math.max(0, luaObject.health - amtToRemove)
                    end
                    luaObject:saveData()
                end
            end
        end

        if command == "addGrowLamp" then
            local x = tonumber(args.x)
            local y = tonumber(args.y)
            local z = tonumber(args.z)
            local square = getCell():getGridSquare(x, y, z)
            if square then
                WFGrowLampUtilities.doPlaceGrowLamp(square)
            end
        end

        if command == "removeGrowLamp" then
            local x = tonumber(args.x)
            local y = tonumber(args.y)
            local z = tonumber(args.z)
            local square = getCell():getGridSquare(x, y, z)
            if square then
                local objects = square:getObjects()
                for i=0,objects:size()-1 do
                    if WFGrowLampUtilities.isGrowLamp(objects:get(i)) then
                        WFGrowLampUtilities.doRemoveGrowLamp(player, objects:get(i))
                        return
                    end
                end
            end
        end

        if command == "toggleGrowLamp" then
            local x = tonumber(args.x)
            local y = tonumber(args.y)
            local z = tonumber(args.z)
            local s = args.s
            local square = getCell():getGridSquare(x, y, z)
            if square then
               WFGrowLampUtilities.toggleGrowLamp(square, s)
            end
        end

        if command == "superCheat" then
            local x = tonumber(args.x)
            local y = tonumber(args.y)
            local z = tonumber(args.z)
            local level = tonumber(args.level)
            local square = getCell():getGridSquare(x, y, z)
            if square then
                local luaObject = SFarmingSystem.instance:getLuaObjectOnSquare(square)
                if luaObject then
                    luaObject.state = "seeded"
                    luaObject.nbOfGrow = level - 1
                    luaObject.nextGrowing = SFarmingSystem.instance.hoursElapsed
                    luaObject.lastWaterHour = SFarmingSystem.instance.hoursElapsed
                    luaObject.health = 100
                    luaObject.fliesLvl = 0
                    luaObject.mildewLvl = 0
                    luaObject.aphidLvl = 0
                    luaObject.waterLvl = 100
                    luaObject:addIcon()
                    luaObject:checkStat()
                    luaObject:saveData()
                end
            end
        end
    end
end)

local original_SPlantGlobalObject_fromModData = SPlantGlobalObject.fromModData
function SPlantGlobalObject:fromModData(modData)
    original_SPlantGlobalObject_fromModData(self, modData)
	self.lastTendHour = modData.lastTendHour
	self.lightEnabled = modData.lightEnabled
    self.deadTime = modData.deadTime
end

local original_SPlantGlobalObject_toModData = SPlantGlobalObject.toModData
function SPlantGlobalObject:toModData(modData)
    original_SPlantGlobalObject_toModData(self, modData)
	modData.lastTendHour = self.lastTendHour
	modData.lightEnabled = self.lightEnabled
    modData.deadTime = self.deadTime
end

local original_SFarmingSystem_initSystem = SFarmingSystem.initSystem
function SFarmingSystem:initSystem()
    original_SFarmingSystem_initSystem(self)
    self.system:setObjectModDataKeys({
		'state', 'nbOfGrow', 'typeOfSeed', 'fertilizer', 'mildewLvl',
		'aphidLvl', 'fliesLvl', 'waterLvl', 'waterNeeded', 'waterNeededMax',
		'lastWaterHour', 'nextGrowing', 'hasSeed', 'hasVegetable',
		'health', 'badCare', 'exterior', 'spriteName', 'objectName',
        'lastTendHour', 'lightEnabled', 'deadTime'})
end

local original_SPlantGlobalObject_aphid = SPlantGlobalObject.aphid
function SPlantGlobalObject:aphid()
    original_SPlantGlobalObject_aphid(self)
    if self.lastTendHour and self.aphidLvl == 1 and SFarmingSystem.instance.hoursElapsed - self.lastTendHour < 24 then
        self.aphidLvl = 0
    end
end

local original_SPlantGlobalObject_flies = SPlantGlobalObject.flies
function SPlantGlobalObject:flies()
    original_SPlantGlobalObject_flies(self)
    if self.lastTendHour and self.fliesLvl == 1 and SFarmingSystem.instance.hoursElapsed - self.lastTendHour < 24 then
        self.fliesLvl = 0
    end
end

local original_SPlantGlobalObject_mildew = SPlantGlobalObject.mildew
function SPlantGlobalObject:mildew()
    original_SPlantGlobalObject_mildew(self)
    if self.lastTendHour and self.mildewLvl == 1 and SFarmingSystem.instance.hoursElapsed - self.lastTendHour < 24 then
        self.mildewLvl = 0
    end
end

local original_SPlantGlobalObject_deadPlant = SPlantGlobalObject.deadPlant
function SPlantGlobalObject:deadPlant()
    if not self.deadTime then
        self.deadTime = getTimestamp()
    end
    original_SPlantGlobalObject_deadPlant(self)
end