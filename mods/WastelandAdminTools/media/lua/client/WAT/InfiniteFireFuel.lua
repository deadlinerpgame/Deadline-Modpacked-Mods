local function makeInfiniteFp(player, fp)
    local args = { x = fp:getX(), y = fp:getY(), z = fp:getZ(), fuelAmt = 999999999 }
    sendClientCommand(player, 'fireplace', 'addFuel', args)
end

local function makeInfiniteCf(player, cf)
	local args = { x = cf.x, y = cf.y, z = cf.z, fuelAmt = 999999999 }
    CCampfireSystem.instance:sendCommand(player, 'addFuel', args)
end

local function OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    local player = getSpecificPlayer(playerIdx)
    if not WL_Utils.canModerate(player) then return end
	if test and ISWorldObjectContextMenu.Test then return true end

	local fireplace = nil
    local campfire = nil

	for _,object in ipairs(worldobjects) do
		local square = object:getSquare()
		if square then
            campfire = CCampfireSystem.instance:getLuaObjectOnSquare(square)
			for i=1,square:getObjects():size() do
				local object2 = square:getObjects():get(i-1)
				if instanceof(object2, "IsoFireplace") then
					fireplace = object2
                    break
				end
			end
		end
        if fireplace or campfire then
            break
        end
	end

    if fireplace then
        context:addOption("Add Infinite Fuel", player, makeInfiniteFp, fireplace)
    end
    if campfire then
        context:addOption("Add Infinite Fuel", player, makeInfiniteCf, campfire)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(OnPreFillWorldObjectContextMenu)