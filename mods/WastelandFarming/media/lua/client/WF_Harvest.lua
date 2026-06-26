local function isHarvestableSquare(sq)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq)
    return plant and plant:canHarvest()
end

local HarvestField = ISBaseTimedAction:derive("HarvestField")

function HarvestField:new(character, field)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.field = field
    o.maxTime = 1
    o.stopOnWalk = true
    return o
end

function HarvestField:isValid()
    return #self.field > 0
end

function HarvestField:perform()
    local next = table.remove(self.field, 1)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(next)
    if not plant then
	    ISBaseTimedAction.perform(self)
        return
    end
    ISFarmingMenu.onHarvest(nil, plant, next, self.character)
    if #self.field > 0 then
        ISTimedActionQueue.add(HarvestField:new(self.character, self.field))
    end
	ISBaseTimedAction.perform(self)
end

-- Temporary - check for and refund broken plants
local function CheckForAndRefundBrokenPlants(sq)
    if sq then
        local plant = CFarmingSystem.instance:getLuaObjectOnSquare(sq)
        if not plant then
            local k = CFarmingSystem.instance:getIsoObjectOnSquare(sq)
            if k then
                sq:transmitRemoveItemFromSquare(k)
                sq:RemoveTileObject(k)
                
                if k:getModData().state == "seeded" then
                    local props = farming_vegetableconf.props[k:getModData().typeOfSeed]
                    for i=1,math.max(1, props.seedPerVeg * 2) do
                        getPlayer():getInventory():AddItem(props.seedName)
                    end
                    getPlayer():addLineChatElement("Bad Plant, removing and giving seeds", 1.0, 0.4, 0.4)
                else
                    getPlayer():addLineChatElement("Bad Plant/Plot, removing", 1.0, 0.4, 0.4)
                end
            end
        elseif plant then
            local k = CFarmingSystem.instance:getIsoObjectOnSquare(sq)
            if not k then
                CFarmingSystem.instance:removeLuaObject(plant)
                CFarmingSystem.instance:sendCommand(getPlayer(), "removeLuaObject", {x=sq:getX(), y=sq:getY(), z=sq:getZ()})
                if plant.state == "seeded" then
                    local props = farming_vegetableconf.props[plant.typeOfSeed]
                    for i=1,math.max(1, props.seedPerVeg * 2) do
                        getPlayer():getInventory():AddItem(props.seedName)
                    end
                    getPlayer():addLineChatElement("Bad Plant, removing and giving seeds", 1.0, 0.4, 0.4)
                else
                    getPlayer():addLineChatElement("Bad Plant/Plot, removing", 1.0, 0.4, 0.4)
                end
            elseif plant.state == "seeded" and plant.lastWaterHour > CFarmingSystem.instance.hoursElapsed then
                sq:transmitRemoveItemFromSquare(k)
                sq:RemoveTileObject(k)
                CFarmingSystem.instance:removeLuaObject(plant)
                CFarmingSystem.instance:sendCommand(getPlayer(), "removeLuaObject", {x=sq:getX(), y=sq:getY(), z=sq:getZ()})
                local props = farming_vegetableconf.props[plant.typeOfSeed]
                for i=1,math.max(1, props.seedPerVeg * 2) do
                    getPlayer():getInventory():AddItem(props.seedName)
                end
                getPlayer():addLineChatElement("Bad Plant, removing and giving seeds", 1.0, 0.4, 0.4)
            end
        end
    end
end

function OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end
    local square = worldobjects[1]:getSquare()
    if not square then return end
    
    -- Temporary - check for and refund broken plants
    CheckForAndRefundBrokenPlants(square)
    
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(square)
    if not plant then return end
    if not plant:isAlive() then return end
    if not plant:canHarvest() then return end

    local playerObj = getSpecificPlayer(playerIdx)

    local field = WF_Lib.ScanArea(square, 20, isHarvestableSquare)
    if #field > 1 then
        context:addOption("Harvest Field", nil, function()
            ISTimedActionQueue.add(HarvestField:new(playerObj, field))
        end)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(OnPreFillWorldObjectContextMenu)