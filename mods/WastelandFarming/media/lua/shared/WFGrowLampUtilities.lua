WFGrowLampUtilities = {}

WFDenyAllItems = function(item)
    return false
end

function WFGrowLampUtilities.isValidSquareForLamp(square)
    if square:getMovingObjects():size() > 0 then return false end
    if square:Has(IsoObjectType.tree) then return false end
    if isClient() then
        if CFarmingSystem.instance:getLuaObjectOnSquare(square) then return false end
    else
        if SFarmingSystem.instance:getLuaObjectOnSquare(square) then return false end
    end
    return not square:Is(IsoFlagType.solid) and not square:Is(IsoFlagType.solidtrans) and square:Is(IsoFlagType.solidfloor)
end

function WFGrowLampUtilities.isGrowLamp(object)
    if not instanceof(object, "IsoObject") then return false end
    if not object or not object:getSprite() then return false end
    local sname = object:getSprite():getName()
    if sname == "wltiles_uvlights_0" then
        return true
    end
    return false
end

function WFGrowLampUtilities.isGrowLampLight(object)
    if not instanceof(object, "IsoLightSwitch") then return false end
    if not object or not object:getSprite() then return false end
    local sname = object:getSprite():getName()
    if sname == "wltiles_uvlights_5" then
        return true
    end
    return false
end

function WFGrowLampUtilities.getGrowLamp(worldobjects)
    for _, v in pairs(worldobjects) do
        if WFGrowLampUtilities.isGrowLamp(v) then
            return v
        end
    end
    return nil
end

function WFGrowLampUtilities.doRemoveGrowLamp(playerObj, growLamp)
    if isClient() then
        sendClientCommand(playerObj, 'farming', 'removeGrowLamp', {x = growLamp:getSquare():getX(), y = growLamp:getSquare():getY(), z = growLamp:getSquare():getZ()})
        return
    end
    local square = growLamp:getSquare()

    local squareObjects = square:getObjects()
    for i = 0, squareObjects:size() - 1 do
        local obj = squareObjects:get(i)
        if WFGrowLampUtilities.isGrowLampLight(obj) then
            square:transmitRemoveItemFromSquare(obj)
            square:RemoveTileObject(obj)
        end
    end

    square:transmitRemoveItemFromSquare(growLamp)
    square:RemoveTileObject(growLamp)

    square:RecalcProperties()
    square:RecalcAllWithNeighbours(true)
    IsoGenerator.updateGenerator(square)
end

function WFGrowLampUtilities.doPlaceGrowLamp(square)
    if isClient() then
        sendClientCommand(getPlayer(), 'farming', 'addGrowLamp', {x = square:getX(), y = square:getY(), z = square:getZ()})
        return
    end
    local obj = IsoObject.new(square:getCell(), square, getSprite("wltiles_uvlights_0"))
    obj:setName("Grow Lamp")
    obj:setMovedThumpable(true)
    obj:createContainersFromSpriteProperties()
    obj:getContainerByType("fridge"):setExplored(true)
    obj:getContainerByType("fridge"):setHasBeenLooted(true)
    obj:getContainerByType("fridge"):setCapacity(0)
    obj:getProperties():Set("CustomName", "GrowLamp")

    local lightEmitter = IsoLightSwitch.new(square:getCell(), square, getSprite("wltiles_uvlights_5"), -1)
    lightEmitter:setName("Grow Lamp Emitter")

    square:AddSpecialObject(obj)
    square:AddSpecialObject(lightEmitter)

    obj:transmitCompleteItemToClients()
    lightEmitter:transmitCompleteItemToClients()

    square:RecalcProperties()
    square:RecalcAllWithNeighbours(true)
    IsoGenerator.updateGenerator(square)
end

function WFGrowLampUtilities.toggleGrowLamp(square, s)
    local objects = square:getObjects()
    for i=0,objects:size()-1 do
        local object = objects:get(i)
        if WFGrowLampUtilities.isGrowLamp(object) then
            if s then
                if object:getContainerByType("fridge_off") then
                    object:getContainerByType("fridge_off"):setType("fridge")
                end
                sendServerCommand("farming", "syncGrowLamp", {x = square:getX(), y = square:getY(), z = square:getZ(), s = true})
            else
                if object:getContainerByType("fridge") then
                    object:getContainerByType("fridge"):setType("fridge_off")
                end
                sendServerCommand("farming", "syncGrowLamp", {x = square:getX(), y = square:getY(), z = square:getZ(), s = false})
            end
        end
        if WFGrowLampUtilities.isGrowLampLight(object) then
            if s then
                object:setActive(true)
            else
                object:setActive(false)
            end
        end
    end
    IsoGenerator.updateGenerator(square)
end