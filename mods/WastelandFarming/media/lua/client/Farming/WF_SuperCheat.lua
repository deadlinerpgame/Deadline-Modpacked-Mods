require 'Farming/ISFarmingMenu'

local function doSuperCheat(worldobjects, plant, level)
    local args = {}
    args.x = plant.x
    args.y = plant.y
    args.z = plant.z
    args.level = level
    sendClientCommand(getPlayer(), 'farming', 'superCheat', args)
end

local original_ISFarmingMenu_doFarmingMenu2 = ISFarmingMenu.doFarmingMenu2
ISFarmingMenu.doFarmingMenu2 = function(player, context, worldobjects, test)
    original_ISFarmingMenu_doFarmingMenu2(player, context, worldobjects, test)
    if not ISFarmingMenu.cheat then return end
    for _,v in ipairs(worldobjects) do
        local plant = CFarmingSystem.instance:getLuaObjectOnSquare(v:getSquare())
        if plant then
            local superCheatOption = context:addOption("Super Cheat", nil, nil)
            local superCheatContext = context:getNew(context)
            context:addSubMenu(superCheatOption, superCheatContext)
            for i=0,6 do
                superCheatContext:addOption("Grow To " .. tostring(i + 1), worldobjects, doSuperCheat, plant, i + 1)
            end
            return
        end
    end
end