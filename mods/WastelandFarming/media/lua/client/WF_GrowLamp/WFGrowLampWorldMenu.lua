if WFGrowLampMenu then
    Events.OnPreFillWorldObjectContextMenu.Remove(WFGrowLampMenu.OnPreFillWorldObjectContextMenu)
end

WFGrowLampMenu = {}

function WFGrowLampMenu.startPlaceGrowlamp(player, growLamp, square)
    if not ISFarmingMenu.walkToPlant(player, square) then
        return
    end
    ISTimedActionQueue.add(WFGrowLampPlaceAction:new(player, growLamp, square))
end

function WFGrowLampMenu.startPickupGrowlamp(player, growLamp)
    local square = growLamp:getSquare()
    if not ISFarmingMenu.walkToPlant(player, square) then
        return
    end
    ISTimedActionQueue.add(WFGrowLampPickupAction:new(player, growLamp))
end

function WFGrowLampMenu.OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end
    local playerObj = getSpecificPlayer(playerIdx)
    local groundLamp = WFGrowLampUtilities.getGrowLamp(worldobjects)
    local inventoryLamp = playerObj:getInventory():FindAndReturn("wastelandfarming.GrowLamp")

    local clickedSquare = worldobjects[1]:getSquare()
    if inventoryLamp and WFGrowLampUtilities.isValidSquareForLamp(clickedSquare) then
        context:addOption("Place Grow Lamp", playerObj, WFGrowLampMenu.startPlaceGrowlamp, inventoryLamp, clickedSquare)
    end

    if groundLamp then
        context:addOption("Pick Up Grow Lamp", playerObj, WFGrowLampMenu.startPickupGrowlamp, groundLamp)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(WFGrowLampMenu.OnPreFillWorldObjectContextMenu)


local original_ISToggleLightAction_perform = ISToggleLightAction.perform
function ISToggleLightAction:perform()
    if self.object:getSprite():getName() == "wltiles_uvlights_5" then
        local args = {
            x = self.object:getSquare():getX(),
            y = self.object:getSquare():getY(),
            z = self.object:getSquare():getZ(),
            s = not self.object:isActivated()
        }
        sendClientCommand(self.character, 'farming', 'toggleGrowLamp', args)
        ISBaseTimedAction.perform(self)
        return
    end
    original_ISToggleLightAction_perform(self)
end

Events.OnServerCommand.Add(function(module, command, args)
    if module == "farming" then
        if command == "syncGrowLamp" then
            local square = getCell():getGridSquare(args.x, args.y, args.z)
            if square then
                local onOff = args.s
                local objects = square:getObjects()
                for i = 0, objects:size() - 1 do
                    local object = objects:get(i)
                    if WFGrowLampUtilities.isGrowLamp(object) then
                        if onOff and object:getContainerByType("fridge_off") then
                            object:getContainerByType("fridge_off"):setType("fridge")
                        elseif not onOff and object:getContainerByType("fridge") then
                            object:getContainerByType("fridge"):setType("fridge_off")
                        end
                    end
                    if WFGrowLampUtilities.isGrowLampLight(object) then
                        if onOff then
                            object:setActive(true)
                        else
                            object:setActive(false)
                        end
                    end
                end
                IsoGenerator.updateGenerator(square)
            end
        end
    end
end)

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldobjects, test)
    local didFind = false

    for _, object in ipairs(worldobjects) do
        if WFGrowLampUtilities.isGrowLamp(object) then
            didFind = true
            break
        end
    end

    if not didFind then return end

    context:removeOptionByName(getText("ContextMenu_RemoveLightbulb"))
    if getActivatedMods():contains("fridgesoff") then
        context:removeOptionByName(getText("ContextMenu_TurnOff"))
        context:removeOptionByName(getText("ContextMenu_TurnOn"))
    end
end)