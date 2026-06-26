-- blends_natural_01_16 to blends_natural_01_23
-- maps into
-- e_newgrass_1_0 to e_newgrass_1_35
--
-- blends_natural_01_32 to blends_natural_01_39
-- maps into
-- e_newgrass_1_36 to e_newgrass_1_53
--
-- blends_natural_01_48 to blends_natural_01_55
-- maps into
-- e_newgrass_1_54 to e_newgrass_1_71
--
-- blends_natural_01_64 to blends_natural_01_71
-- maps into
-- e_newgrass_1_72 to e_newgrass_1_89

require "TimedActions/ISBaseTimedAction"

local grassMapping = {}
for i = 16, 23 do
    local options = {}
    for j = 0, 35 do
        table.insert(options, "e_newgrass_1_" .. j)
    end
    grassMapping["blends_natural_01_" .. i] = options
end
for i = 32, 39 do
    local options = {}
    for j = 36, 53 do
        table.insert(options, "e_newgrass_1_" .. j)
    end
    grassMapping["blends_natural_01_" .. i] = options
end
for i = 48, 55 do
    local options = {}
    for j = 54, 71 do
        table.insert(options, "e_newgrass_1_" .. j)
    end
    grassMapping["blends_natural_01_" .. i] = options
end
for i = 64, 71 do
    local options = {}
    for j = 72, 89 do
        table.insert(options, "e_newgrass_1_" .. j)
    end
    grassMapping["blends_natural_01_" .. i] = options
end

local SEED_TYPE = "GrassSeed"
local SEED_FULL_TYPE = "Base.GrassSeed"
local EMPTY_BAG_TYPE = "EmptySandbag"
local EMPTY_BAG_FULL_TYPE = "Base.EmptySandbag"
local ACTION_TIME = 110
local COLLECT_ACTION_TIME = 50

local function getGrassSeedItem(playerObj)
    if not playerObj then return nil end
    return playerObj:getInventory():getFirstTypeEvalRecurse(SEED_TYPE, function(item)
        return item and item:getFullType() == SEED_FULL_TYPE and item:getDrainableUsesInt() > 0
    end)
end

local function getGrassSeedBag(playerObj)
    if not playerObj then return nil end
    return playerObj:getInventory():getFirstTypeEvalRecurse(SEED_TYPE, function(item)
        return item
            and item:getFullType() == SEED_FULL_TYPE
            and item:getUsedDelta() < 1
    end)
end

local function getEmptySandbag(playerObj)
    if not playerObj then return nil end
    return playerObj:getInventory():getFirstTypeEvalRecurse(EMPTY_BAG_TYPE, function(item)
        return item and item:getFullType() == EMPTY_BAG_FULL_TYPE
    end)
end

local function getGrassSeedFillTarget(playerObj)
    local seedBag = getGrassSeedBag(playerObj)
    if seedBag then
        return seedBag
    end
    return getEmptySandbag(playerObj)
end

local function getFloorObject(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getSprite() then
            local spriteName = obj:getSprite():getName()
            if grassMapping[spriteName] then
                return obj, i, spriteName
            end
        end
    end
    return nil
end

local function getGrassObject(square)
    if not square then return nil end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj:getSprite() then
            local spriteName = obj:getSprite():getName()
            if spriteName and string.sub(spriteName, 1, 11) == "e_newgrass_" then
                return obj
            end
        end
    end
    return nil
end

local function chooseGrassSprite(options)
    if not options or #options == 0 then return nil end
    return options[ZombRand(#options) + 1]
end

local function consumeGrassSeed(playerObj, seedItem)
    if not playerObj or not seedItem then return end
    local uses = seedItem:getDrainableUsesInt()
    if uses and uses > 1 then
        seedItem:Use()
    else
        playerObj:getInventory():DoRemoveItem(seedItem)
        playerObj:getInventory():AddItem("Base.EmptySandbag")
    end
end

local function addGrassSeedToBag(playerObj, bagItem)
    if not playerObj or not bagItem then return end
    if bagItem:getFullType() == SEED_FULL_TYPE then
        local usedDelta = bagItem:getUsedDelta()
        local useDelta = bagItem:getUseDelta()
        if usedDelta < 1 and useDelta then
            bagItem:setUsedDelta(math.min(1, usedDelta + useDelta))
            bagItem:updateWeight()
        end
        return
    end

    if bagItem:getFullType() == EMPTY_BAG_FULL_TYPE then
        playerObj:getInventory():DoRemoveItem(bagItem)
        local newBag = playerObj:getInventory():AddItem(SEED_FULL_TYPE)
        if newBag then
            local useDelta = newBag:getUseDelta()
            newBag:setUsedDelta(math.min(1, useDelta or 0))
            newBag:updateWeight()
        end
    end
end

local PlantGrassSeedAction = ISBaseTimedAction:derive("PlantGrassSeedAction")

function PlantGrassSeedAction:isValid()
    if not self.character or not self.square or not self.seedItem then
        return false
    end
    if not self.character:getInventory():contains(self.seedItem) then
        return false
    end
    if self.seedItem:getDrainableUsesInt() <= 0 then
        return false
    end
    local floorObj = getFloorObject(self.square)
    if not floorObj then
        return false
    end
    if getGrassObject(self.square) then
        return false
    end
    return true
end

function PlantGrassSeedAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function PlantGrassSeedAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self.character:setMetabolicTarget(Metabolics.LightWork)
end

function PlantGrassSeedAction:start()
    self:setActionAnim(CharacterActionAnims.Dig)
end

function PlantGrassSeedAction:perform()
    local floorObj, floorIndex, floorSprite = getFloorObject(self.square)
    if floorObj and floorIndex and floorSprite and not getGrassObject(self.square) then
        local options = grassMapping[floorSprite]
        local grassSprite = chooseGrassSprite(options)
        if grassSprite then
            local grassObj = IsoObject.new(self.square, grassSprite, false)
            if grassObj then
                self.square:AddTileObject(grassObj)
                grassObj:transmitCompleteItemToServer()
                consumeGrassSeed(self.character, self.seedItem)
            end
        end
    end
    ISBaseTimedAction.perform(self)
end

function PlantGrassSeedAction:new(character, seedItem, square, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.seedItem = seedItem
    o.square = square
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or ACTION_TIME
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end

local CollectGrassSeedAction = ISBaseTimedAction:derive("CollectGrassSeedAction")

function CollectGrassSeedAction:isValid()
    if not self.character or not self.square or not self.bagItem then
        return false
    end
    if not self.character:getInventory():contains(self.bagItem) then
        return false
    end
    if self.bagItem:getFullType() == SEED_FULL_TYPE and self.bagItem:getUsedDelta() >= 1 then
        return false
    end
    local floorObj = getFloorObject(self.square)
    if not floorObj then
        return false
    end
    if not getGrassObject(self.square) then
        return false
    end
    return true
end

function CollectGrassSeedAction:waitToStart()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    return self.character:shouldBeTurning()
end

function CollectGrassSeedAction:update()
    self.character:faceLocation(self.square:getX(), self.square:getY())
    self.character:setMetabolicTarget(Metabolics.DiggingSpade)
end

function CollectGrassSeedAction:start()
    self:setActionAnim("RemoveGrass")
end

function CollectGrassSeedAction:perform()
    local floorObj, floorIndex = getFloorObject(self.square)
    if floorObj and floorIndex then
        local grassObj = getGrassObject(self.square)
        if grassObj then
            self.square:transmitRemoveItemFromSquare(grassObj)
            addGrassSeedToBag(self.character, self.bagItem)
        end
    end
    ISBaseTimedAction.perform(self)
end

function CollectGrassSeedAction:new(character, bagItem, square, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.bagItem = bagItem
    o.square = square
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = time or COLLECT_ACTION_TIME
    if character:isTimedActionInstant() then
        o.maxTime = 1
    end
    return o
end

local function initiatePlantGrassseed(player, seedItem, square)
    if not player or not seedItem or not square then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, seedItem)
    ISWorldObjectContextMenu.equip(player, player:getPrimaryHandItem(), seedItem, true)
    if not luautils.walkAdj(player, square) then return end
    ISTimedActionQueue.add(PlantGrassSeedAction:new(player, seedItem, square))
end

local function initiateCollectGrassSeed(player, bagItem, square)
    if not player or not bagItem or not square then return end
    ISInventoryPaneContextMenu.transferIfNeeded(player, bagItem)
    if not luautils.walkAdj(player, square) then return end
    ISTimedActionQueue.add(CollectGrassSeedAction:new(player, bagItem, square))
end

local function OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end
    local playerObj = getSpecificPlayer(playerIdx)
    if not playerObj then return end

    local square = nil
    for _, object in ipairs(worldobjects) do
        square = object:getSquare()
        if square then
            break
        end
    end
    if not square then return end

    local floorObj = getFloorObject(square)
    if not floorObj then return end

    if getGrassObject(square) then
        local bagItem = getGrassSeedFillTarget(playerObj)
        if not bagItem then return end
        context:addOption("Collect Grass Seed", playerObj, initiateCollectGrassSeed, bagItem, square)
        return
    end

    local seedItem = getGrassSeedItem(playerObj)
    if not seedItem then return end
    context:addOption("Plant Grass Seed", playerObj, initiatePlantGrassseed, seedItem, square)
end

Events.OnPreFillWorldObjectContextMenu.Add(OnPreFillWorldObjectContextMenu)
