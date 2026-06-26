require("WF_Sprinkler/WFSprinklerUtilities")

local WFSprinklerWorldMenu = {}

function WFSprinklerWorldMenu.startWaterPlantsCursor(playerObj, barrel)
    if WFWaterCursor.IsVisible() then
        getCell():setDrag(nil, playerObj:getPlayerNum())
    end

    WFSprinklerData.waterCursor = WFWaterCursor:new(playerObj, barrel)
    getCell():setDrag(WFSprinklerData.waterCursor, playerObj:getPlayerNum())
end

function WFSprinklerWorldMenu.waterAllPlants(playerObj, barrel)
    local plants = WFSprinklerUtilities.getWaterablePlants(barrel:getSquare(), 3, true)
    if #plants == 0 then return end
    ISFarmingMenu.walkToPlant(playerObj, barrel:getSquare())
    for _, plant in ipairs(plants) do
        local water = WFSprinklerUtilities.getWaterUsedForPlant(barrel, plant)
        ISTimedActionQueue.add(WFSprinklerWaterAction:new(playerObj, barrel, plant, water, math.max(10, water * 2)))
    end
end

function WFSprinklerWorldMenu.doDetachSprinkler(player, sprinkler)
	local adjacent = AdjacentFreeTileFinder.Find(sprinkler:getSquare(), player)
    if adjacent == nil then
        player:Say("I can't reach that.")
        return
    end
	ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent))
    ISTimedActionQueue.add(WFSprinklerDetachAction:new(player, sprinkler, 200))
end

function WFSprinklerWorldMenu.doAttachSprinkler(player, sprinkler, barrel)
	local adjacent = AdjacentFreeTileFinder.Find(barrel:getSquare(), player)
    if adjacent == nil then
        player:Say("I can't reach that.")
        return
    end
	ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent))
    ISTimedActionQueue.add(WFSprinklerAttachAction:new(player, sprinkler, barrel, 200))
end

function WFSprinklerWorldMenu.fillContext(playerIdx, context, worldobjects, test)
    -- check if and get the barrel
    local barrel = WFSprinklerUtilities.getBarrelObject(worldobjects)
    if not barrel then return end

    -- check if and get the sprinkler in the player's inventory
    local playerObj = getSpecificPlayer(playerIdx)
    local inventorySprinkler = WFSprinklerUtilities.getSprinklerItem(playerObj)

    -- check if and get the sprinkler attached to the barrel
    local worldSprinkler = WFSprinklerUtilities.getBarrelSprinkler(barrel)


    if worldSprinkler then
        -- detach sprinkler
        context:addOption(getText("ContextMenu_WFDetachSprinkler"), playerObj, WFSprinklerWorldMenu.doDetachSprinkler, worldSprinkler)

        -- use sprinkler
        local maxWater = math.floor(math.min(100, WFSprinklerUtilities.getUsableWaterInBarrel(barrel))/10)*10
        if maxWater >= 10 then
            context:addOption(getText("ContextMenu_WFUseSprinkler"), playerObj, WFSprinklerWorldMenu.startWaterPlantsCursor, barrel)
            context:addOption(getText("ContextMenu_WFUseSprinklerAll"), playerObj, WFSprinklerWorldMenu.waterAllPlants, barrel)
        end
    elseif inventorySprinkler then
        -- attach sprinkler
        context:addOption(getText("ContextMenu_WFAttachSprinkler"), playerObj, WFSprinklerWorldMenu.doAttachSprinkler, inventorySprinkler, barrel)
    end
end

Events.OnFillWorldObjectContextMenu.Add(WFSprinklerWorldMenu.fillContext)
