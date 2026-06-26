if not isClient() then return end

require "UI/WL_CreateZonePanel"
require "WEZ_EventZone"
require "UI/WEZ_ManageZone"
require "UI/WEZ_ListZones"
require "WL_ContextMenuUtils"
require "WL_Utils"

local WEZ_WorldMenu = {}

WEZ_WorldMenu.doMenu = function(playerIdx, context)
    local player = getPlayer(playerIdx)
    local zones = WEZ_EventZone.getZonesAt(x, y, player:getZ())
    local isNoFishingZone = false
    for i=1,#zones do
        local zone = zones[i]
        if zone.noFishing then
            isNoFishingZone = true
            break
        end
    end
    if isNoFishingZone then
        context:removeOptionByName(getText("ContextMenu_Fishing"))
    end

    if not isClient() or WL_Utils.canModerate(player) then
        local x, y = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), player:getZ())
        
        for i=1,#zones do
            local zone = zones[i]
            if not zone.external then
                context:addOption("Manage: " .. zone.name, zone, WEZ_WorldMenu.manageZone)
            end
        end

        local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Zones")
        submenu:addOption("List Event Zones" , nil, WEZ_WorldMenu.listZones)
        submenu:addOption("List No-Thump Zones" , nil, WEZ_WorldMenu.listNoThumpZones)
        submenu:addOption("List No-Zombie Zones" , nil, WEZ_WorldMenu.listNoZombieZones)

        local startingCoordinates = {
            startX = math.floor(player:getX() - 5),
            startY = math.floor(player:getY() - 5),
            endX = math.floor(player:getX() + 5),
            endY = math.floor(player:getY() + 5),
        }
        submenu:addOption("New Event Zone", startingCoordinates, WEZ_WorldMenu.createZone)
    end
end

function WEZ_WorldMenu.listZones()
    WEZ_ListZones:show(function(zone) return true end)
end

function WEZ_WorldMenu.listNoThumpZones()
    WEZ_ListZones:show(function(zone) return zone.noThump end)
end

function  WEZ_WorldMenu.listNoZombieZones()
    WEZ_ListZones:show(function(zone) return zone.preventZombies end)
end

local function createEventZone(name, startX, startY, endX, endY, startZ, endZ)
    local newZone = WEZ_EventZone:new(name, startX, startY, startZ, endX, endY, endZ)
    WEZ_ManageZone:show(newZone)
end

function WEZ_WorldMenu.createZone(startingCoordinates)
    if WEZ_ManageZone.instance then
        WEZ_ManageZone.instance:onClose()
    end
    if WEZ_ListZones.instance then
        WEZ_ListZones.instance:onClose()
    end

    WL_CreateZonePanel:show("Event Zone", startingCoordinates, createEventZone, true)
end

--- @param zone WEZ_EventZone
function WEZ_WorldMenu.manageZone(zone)
    WEZ_ManageZone:show(zone)
end

function WEZ_WorldMenu.preDoMenu(playerIdx, context, worldObjects)
    if worldObjects == nil or #worldObjects == 0 then
        return
    end
    x, y, z = worldObjects[1]:getSquare():getX(), worldObjects[1]:getSquare():getY(), worldObjects[1]:getSquare():getZ()
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return end
    local objects = sq:getObjects()
    for i=0, objects:size()-1 do
        local obj = objects:get(i)
        local props = obj:getSprite() and obj:getSprite():getProperties() or nil
        local canBeFilled = (obj:hasModData() and obj:getModData().canBeWaterPiped) or (props and props:Is(IsoFlagType.waterPiped))

        if canBeFilled then
            local x,y,z = obj:getSquare():getX(), obj:getSquare():getY(), obj:getSquare():getZ()
            local zones = WEZ_EventZone.getZonesAt(x, y, z)
            for _, zone in ipairs(zones) do
                if zone.unlimitedWater then
                    obj:setWaterAmount(obj:getWaterMax())
                    if not storeWater then
                        storeWater = obj
                    end
                end
            end
        end
    end

        
end

Events.OnPreFillWorldObjectContextMenu.Add(WEZ_WorldMenu.preDoMenu)

Events.OnFillWorldObjectContextMenu.Add(WEZ_WorldMenu.doMenu)
