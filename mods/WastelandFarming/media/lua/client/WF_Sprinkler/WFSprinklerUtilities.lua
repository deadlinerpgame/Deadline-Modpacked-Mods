WFSprinklerUtilities = {}

function WFSprinklerUtilities.getSprinklerItem(player)
    return player:getInventory():FindAndReturn("SprinklerCrafted")
end

function WFSprinklerUtilities.getBarrelSprinkler(barrel)
    local worldobjects = barrel:getSquare():getObjects()
    for i=0, worldobjects:size()-1 do
        local obj = worldobjects:get(i)
        if obj:getSprite() then
            local sname = obj:getSprite():getName()
            if sname == "Sprinkl_0" or sname == "Sprinkl_1" or sname == "Sprinkl_2" then
                return obj
            end
        end
    end
    return nil
end

function WFSprinklerUtilities.isBarrelObject(object)
    if not instanceof(object, "IsoObject") then return false end
    if not object or not object:getSprite() then return false end
    local sname = object:getSprite():getName()
    if sname == "crafted_01_24" or sname == "crafted_01_25" or
       sname == "crafted_01_28" or sname == "crafted_01_29" or
       sname == "carpentry_02_52" or sname == "carpentry_02_55" or
       sname == "carpentry_02_53" or sname == "carpentry_02_54" then
        return true
    end
    return false
end

function WFSprinklerUtilities.getBarrelObject(worldobjects)
    for _, v in pairs(worldobjects) do
        if WFSprinklerUtilities.isBarrelObject(v) and v:getWaterMax() then
            return v
        end
    end
    return nil
end

function WFSprinklerUtilities.getUsableWaterInBarrel(barrel)
    if not barrel or not barrel:getWaterMax() then return 0 end
    local water = barrel:getWaterAmount()
    return water * 8
end

function WFSprinklerUtilities.getWaterAmountFromUsed(used)
    return math.ceil(used / 8)
end

function WFSprinklerUtilities.getWaterUsedForPlant(barrel, plant)
	return math.min(100 - plant.waterLvl, WFSprinklerUtilities.getUsableWaterInBarrel(barrel))
end

function WFSprinklerUtilities.getWaterablePlants(sourceSquare, range, skipAphids)
    local plants = {}
    local x = sourceSquare:getX()
    local y = sourceSquare:getY()
    local z = sourceSquare:getZ()
    for ny = y - range, y + range do
        for nx = x - range, x + range do
            if WFSprinklerUtilities.isSquareInRange(x, y, nx, ny, range) then
                local plant = CFarmingSystem.instance:getLuaObjectAt(nx, ny, z)
                if plant and plant.state == "seeded" and plant.waterLvl < 100 and (not skipAphids or plant.aphidLvl == 0) then
                    table.insert(plants, plant)
                end
            end
        end
    end
    return plants
end

function WFSprinklerUtilities.isWaterablePlant(x, y, z)
    local plant = CFarmingSystem.instance:getLuaObjectAt(x, y, z)
    if plant and plant.state == "seeded" and plant.waterLvl < 100 then
        return true
    end
    return false
end

function WFSprinklerUtilities.isSquareInRange(sx, sy, dx, dy, range)
    return math.abs(sx - dx) <= range and math.abs(sy - dy) <= range
end

function WFSprinklerUtilities.getStandInSquare(centerSquare, targetPlant)
    local tsq = targetPlant:getSquare()
    local dx = tsq:getX() - centerSquare:getX()
    local dy = tsq:getY() - centerSquare:getY()
    local tx = centerSquare:getX()
    local ty = centerSquare:getY()
    if math.abs(dx) > math.abs(dy) then
        if dx > 0 then
            tx = tx - 1
        else
            tx = tx + 1
        end
    else
        if dy > 0 then
            ty = ty - 1
        else
            ty = ty + 1
        end
    end
    return getCell():getGridSquare(tx, ty, centerSquare:getZ())
end

function WFSprinklerUtilities.sortPlants(a, b)
    local ax1 = a[1]:getX()
    local ay1 = a[1]:getY()
    local bx1 = b[1]:getX()
    local by1 = b[1]:getY()

    if ax1 == bx1 then
        return ay1 < by1
    end
    return ax1 < bx1
end