if not isClient() then return end

require "WL_Zone"

--- @class WEZ_EventZone : WL_Zone
WEZ_EventZone = WEZ_EventZone or WL_Zone:derive("WEZ_EventZone")
--- @type WEZ_EventZone[]
WEZ_EventZones = {}

function WEZ_EventZone.getZonesAt(x, y, z)
    local zones = {}
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) then
            table.insert(zones, zone)
        end
    end
    return zones
end

function WEZ_EventZone.getWarningZonesAt(x, y)
    local zones = {}
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInWarningZone(x, y) then
            table.insert(zones, zone)
        end
    end
    return zones
end

function WEZ_EventZone.getInCarZonesAt(x, y)
    local zones = {}
    for _, zone in pairs(WEZ_EventZones) do
        if zone.inCars and zone:isInZone(x, y, 0) then
            table.insert(zones, zone)
        end
    end
    return zones
end

function WEZ_EventZone.getIsScrapZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.isScrapZone then
            return true
        end
    end
    return false
end

function WEZ_EventZone.getIsNoDeforestZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.noDeforest then
            return true
        end
    end
    return false
end

function WEZ_EventZone.getIsNoBuildZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.noBuild then
            return true
        end
    end
    return false
end

function WEZ_EventZone.getIsNoPickupZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.noPickup then
            return true
        end
    end
    return false
end

function WEZ_EventZone.getIsLockedMannequinsZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.lockedMannequins then
            return true
        end
    end
    return false
end

function WEZ_EventZone.getRiftSpawnZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and (zone.riftSpawnChance > 0 or zone.noRiftZone)  then
            return zone
        end
    end
    return nil
end

function WEZ_EventZone.getZone(zoneId)
    return WEZ_EventZones[zoneId]
end

function WEZ_EventZone.dump()
    print(WEZ_tabledump(WEZ_EventZones))
end

function WEZ_EventZone:new(name, x1, y1, z1, x2, y2, z2)
    --- @type WEZ_EventZone
    local o = WEZ_EventZone.parentClass.new(self, x1, y1, z1, x2, y2, z2)  -- call inherited constructor
    o:init()
    o.name = name
    WEZ_EventZones[o.id] = o
    o:save()
    return o
end

function WEZ_EventZone:loadFrom(data)
    local o = WEZ_EventZone.parentClass.new(self, data.minX, data.minY, data.minZ, data.maxX, data.maxY, data.maxZ)
    
    local allValues = WEZ_EventZoneDefaults.getAllValues(data)

    for key, value in pairs(allValues) do
        o[key] = value
    end
    
    WEZ_EventZones[o.id] = o
    if o.weatherTransitionTicks == nil then
        o.weatherTransitionTicks = 600
    end
    return o
end

function WEZ_EventZone:init()    
    local allValues = WEZ_EventZoneDefaults.getAllValues({
        id = getRandomUUID(),
        name = "",
    })
    for key, value in pairs(allValues) do
        if self[key] == nil then
            self[key] = value
        end
    end
end

function WEZ_EventZone:save()
    if self.external then return end
    sendClientCommand(getPlayer(), "WastelandEventZones", "SetZone", WEZ_EventZoneDefaults.getUniqueValues({
        id = self.id,
        minX = self.minX,
        minY = self.minY,
        maxX = self.maxX,
        maxY = self.maxY,
        minZ = self.minZ,
        maxZ = self.maxZ,

        -- general
        name = self.name,
        teleportX = self.teleportX,
        teleportY = self.teleportY,
        teleportZ = self.teleportZ,

        -- zombies
        preventZombies = self.preventZombies,
        killZombies = self.killZombies,
        percentageSprinters = self.percentageSprinters,
        percentageFastShamblers = self.percentageFastShamblers,
        percentageSlowShamblers = self.percentageSlowShamblers,
        spawnInterval = self.spawnInterval,
        spawnCount = self.spawnCount,
        spawnMax = self.spawnMax,
        spawnRange = self.spawnRange,
        spawnCatchup = self.spawnCatchup,
        spawnCheckPlayers = self.spawnCheckPlayers,
        spawnPlayerRange = self.spawnPlayerRange,
        noThump = self.noThump,

        -- players
        isAdminOnly = self.isAdminOnly,
        isPlayerGatedToggle = self.isPlayerGatedToggle,
        isPlayerGated = self.isPlayerGated,
        playersGated = self.playersGated,
        isPlayerGatedItem = self.isPlayerGatedItem,
        playerItemGated = self.playerItemGated,
        playerItemNameGated = self.playerItemNameGated,
        isJail = self.isJail,
        isRpZone = self.isRpZone,
        noDamage = self.noDamage,
        noFishing = self.noFishing,
        isQuiet = self.isQuiet,
        isScrapZone = self.isScrapZone,
        noDeforest = self.noDeforest,
        noBuild = self.noBuild,
        noPickup = self.noPickup,
        lockedMannequins = self.lockedMannequins,
        freeDeathZone = self.freeDeathZone,
        unlimitedWater = self.unlimitedWater,
        damageRate = self.damageRate,
        damagePreventToggle = self.damagePreventToggle,
        damagePreventItems = self.damagePreventItems,
        moodleIncrease = self.moodleIncrease,
        moodleIncreaseRate = self.moodleIncreaseRate,

        -- messages
        warningBuffer = self.warningBuffer,
        warningMessage = self.warningMessage,
        enterMessage = self.enterMessage,
        exitMessage = self.exitMessage,
        inCars = self.inCars,
        inCarsMessage = self.inCarsMessage,
        rpText = self.rpText,

        -- rifts
        noRiftZone = self.noRiftZone,
        riftSpawnChance = self.riftSpawnChance,
        riftMinCount = self.riftMinCount,
        riftMaxCount = self.riftMaxCount,
        riftMinRate = self.riftMinRate,
        riftMaxRate = self.riftMaxRate,

        -- weather
        weatherTransitionTicks = self.weatherTransitionTicks,
        weatherWind = self.weatherWind,
        weatherWindEnabled = self.weatherWindEnabled,
        weatherClouds = self.weatherClouds,
        weatherCloudsEnabled = self.weatherCloudsEnabled,
        weatherFog = self.weatherFog,
        weatherFogEnabled = self.weatherFogEnabled,
        weatherPrecipitation = self.weatherPrecipitation,
        weatherPrecipitationEnabled = self.weatherPrecipitationEnabled,
        weatherPrecipitationIsSnow = self.weatherPrecipitationIsSnow,
        weatherTemperature = self.weatherTemperature,
        weatherTemperatureEnabled = self.weatherTemperatureEnabled,
        weatherDarkness = self.weatherDarkness,
        weatherDarknessEnabled = self.weatherDarknessEnabled,
        weatherDesaturation = self.weatherDesaturation,
        weatherDesaturationEnabled = self.weatherDesaturationEnabled,
        weatherLightExtR = self.weatherLightExtR,
        weatherLightExtG = self.weatherLightExtG,
        weatherLightExtB = self.weatherLightExtB,
        weatherLightExtA = self.weatherLightExtA,
        weatherLightIntR = self.weatherLightIntR,
        weatherLightIntG = self.weatherLightIntG,
        weatherLightIntB = self.weatherLightIntB,
        weatherLightIntA = self.weatherLightIntA,
        weatherLightEnabled = self.weatherLightEnabled,        
    }));
end



function WEZ_EventZone:getMapName()
    return self.name or "Unamed Event Zone"
end

function WEZ_EventZone:delete()
    sendClientCommand(getPlayer(), "WastelandEventZones", "DeleteZone", {id = self.id})
end

function WEZ_EventZone:isInWarningZone(x, y)
    if self.warningBuffer == 0 then
        return false
    end
    if x >= (self.minX-self.warningBuffer) and x <= (self.maxX+1+self.warningBuffer) and y >= (self.minY-self.warningBuffer) and y <= (self.maxY+1+self.warningBuffer) then
        return true
    end
    return false
end

function WEZ_EventZone:isNoThump(toggle)
    self.noThump = toggle
end

function WEZ_EventZone.isQuietZone(x, y, z)
    for _, zone in pairs(WEZ_EventZones) do
        if zone:isInZone(x, y, z) and zone.isQuiet then
            return true
        end
    end
    return false
end

function WEZ_EventZone:isPlayerInWarningZone(player)
    return self:isInWarningZone(player:getX(), player:getY(), player:getZ())
end

function WEZ_EventZone:isPlayerInList(player, zone)
    if not zone.isPlayerGated or zone.playersGated == "" then
        return true
    end

    local playerNames = {}
    if string.find(zone.playersGated, ",") then
        for name in string.gmatch(zone.playersGated, "[^,]+") do
            name = name:gsub("^%s+", "")
            name = name:gsub("%s+$", "")
            table.insert(playerNames, name)
        end
    elseif zone.playersGated ~= "" then
        local name = zone.playersGated:gsub("^%s+", ""):gsub("%s+$", "")
        table.insert(playerNames, name)
    end

    local isListed = false
    for _, name in ipairs(playerNames) do
        if player:getUsername() == name then
            isListed = true
            break
        end
    end

    if zone.isPlayerGatedToggle then
        return not isListed
    else
        return isListed
    end
end

function WEZ_EventZone:hasItemInInventory(player, itemId, itemName, zone)
    if not player or not itemId or itemId == "" then return false end

    local itemIds = {}
    if string.find(itemId, ",") then
        for id in string.gmatch(itemId, "[^,]+") do
            id = id:gsub("^%s+", "")
            id = id:gsub("%s+$", "")
            table.insert(itemIds, id)
        end
    else
        itemIds = { itemId }
    end

    local ignoreItemName = #itemIds > 1

    local function isMatchingItem(item)
        for _, id in ipairs(itemIds) do
            if item:getFullType() == id then
                if ignoreItemName or not itemName or itemName == "" or item:getName() == itemName then
                    return true
                end
            end
        end
        return false
    end

    local function hasMatchingItemInContainer(container)
        if not container then return false end

        local items = container:getItems()
        for i = 0, items:size() - 1 do
            local item = items:get(i)

            if isMatchingItem(item) then
                return true
            end

            if instanceof(item, "InventoryContainer") then
                local subContainer = item:getItemContainer()
                if subContainer and hasMatchingItemInContainer(subContainer) then
                    return true
                end
            end
        end

        return false
    end

    return hasMatchingItemInContainer(player:getInventory())
end

function WEZ_EventZone:isPlayerAllowed(player,zone)
    if self.isPlayerGated and not WEZ_EventZone:isPlayerInList(player,zone) and not WL_Utils.isStaff(player) then
        return false, "You are not allowed to enter this zone."
    end
    if self.isPlayerGatedItem and not WL_Utils.isStaff(player) then
        local hasItem = WEZ_EventZone:hasItemInInventory(player, zone.playerItemGated, zone.playerItemNameGated, zone)
        if zone.isPlayerGatedToggle then
            if hasItem then
                local firstFoundItem
                if string.find(zone.playerItemGated, ",") then
                    for id in string.gmatch(zone.playerItemGated, "[^,]+") do
                        id = id:gsub("^%s+", ""):gsub("%s+$", "")
                        firstFoundItem = player:getInventory():getFirstTypeRecurse(id)
                        if firstFoundItem then break end
                    end
                else
                    firstFoundItem = player:getInventory():getFirstTypeRecurse(zone.playerItemGated)
                end
                local item = InventoryItemFactory.CreateItem(zone.playerItemGated)
                local itemName = item and item:getName() or (zone.playerItemGated or "required item")
                if zone.playerItemGated and not string.find(zone.playerItemGated, ",") and zone.playerItemNameGated and zone.playerItemNameGated ~= "" then
                    return false, "You are not allowed to enter this zone with " .. itemName .. " named " .. zone.playerItemNameGated .. "."
                else
                    return false, "You are not allowed to enter this zone with " .. firstFoundItem:getType() .. "."
                end
            end
        else
            if not hasItem then
                return false, "You do not have the required item to enter this zone."
            end
        end
    end
    if self.isAdminOnly and not WL_Utils.isStaff(player) then
        return false, "You must be an staff to enter this zone."
    end

    return true
end
