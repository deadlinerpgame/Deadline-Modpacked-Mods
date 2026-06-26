if not isClient() then return end

require "WL_Utils"
require "WL_WeatherOverride"
require "WM_Utils"

if WEZ_MonitorPlayer then
    Events.OnTick.Remove(WEZ_MonitorPlayer.Check)
    Events.OnClimateTick.Remove(WEZ_MonitorPlayer.OnClimateTick)
else
    WEZ_MonitorPlayer = {}
    WEZ_MonitorPlayer.checkTimeout = 0
    WEZ_MonitorPlayer.checkInterval = 20
    WEZ_MonitorPlayer.zonesIn = {}
    WEZ_MonitorPlayer.zonesWarned = {}
    WEZ_MonitorPlayer.inCarWarned = {}
    WEZ_MonitorPlayer.jailZoneId = false
    WEZ_MonitorPlayer.stillInJail = false
    WEZ_MonitorPlayer.cancelRun = false
    WEZ_MonitorPlayer.healthInfoOnEnter = {}
    WEZ_MonitorPlayer.LastInventoryLog = {}
    WEZ_MonitorPlayer.weatherApplied = {}
end

WEZ_MonitorPlayer.SkipClimateUpdate = false

function WEZ_MonitorPlayer.Check()
    local currentlyInZones = {}
    local currentlyWarnedZones = {}
    local currentlyCarWarnedZones = {}
    local player = getPlayer()
    if player then
        WEZ_MonitorPlayer.stillInJail = false
        WEZ_MonitorPlayer.cancelRun = false
        local x, y, z = player:getX(), player:getY(), player:getZ()
        local zones = WEZ_EventZone.getZonesAt(x, y, z)
        for _, zone in pairs(zones) do
            currentlyInZones[zone.id] = true
            if not WEZ_MonitorPlayer.cancelRun then
                WEZ_MonitorPlayer.CheckZone(player, zone)
            end
        end
        WEZ_MonitorPlayer.CheckTPBackToJail(player)
        local warnedZones = WEZ_EventZone.getWarningZonesAt(x, y)
        for _, zone in pairs(warnedZones) do
            if not WEZ_MonitorPlayer.zonesWarned[zone.id] then
                WEZ_MonitorPlayer.zonesWarned[zone.id] = true
                WEZ_MonitorPlayer.showWarning(player, zone)
            end
            currentlyWarnedZones[zone.id] = true
        end

        if WEZ_MonitorPlayer.isInCar(player) then
            local inCarWarnedZones = WEZ_EventZone.getInCarZonesAt(x, y)
            for _, zone in pairs(inCarWarnedZones) do
                if not WEZ_MonitorPlayer.inCarWarned[zone.id] then
                    WEZ_MonitorPlayer.inCarWarned[zone.id] = true
                    WEZ_MonitorPlayer.showInCarWarning(player, zone)
                end
                currentlyCarWarnedZones[zone.id] = true
            end
        end
    end

    for zoneId, _ in pairs(WEZ_MonitorPlayer.zonesIn) do
        if not currentlyInZones[zoneId] then
            local zone = WEZ_EventZone.getZone(zoneId)
            WEZ_MonitorPlayer.weatherApplied[zoneId] = nil
            WEZ_MonitorPlayer.showExitZone(player, zone)
            WEZ_MonitorPlayer.zonesIn[zoneId] = nil
            -- Unset all weather overrides for this zone when player leaves it
            WL_WeatherOverride.UnsetAllOverrides("zone_" .. zoneId, zone.weatherTransitionTicks)
        end
    end
    for zoneId, _ in pairs(WEZ_MonitorPlayer.zonesWarned) do
        if not currentlyWarnedZones[zoneId] then
            WEZ_MonitorPlayer.zonesWarned[zoneId] = nil
        end
    end
    for zoneId, _ in pairs(WEZ_MonitorPlayer.inCarWarned) do
        if not currentlyCarWarnedZones[zoneId] then
            WEZ_MonitorPlayer.inCarWarned[zoneId] = nil
        end
    end
end

function WEZ_MonitorPlayer.CheckZone(player, zone)
    if WEZ_MonitorPlayer.CheckBoot(player, zone) then
        return {}
    end

    if not WEZ_MonitorPlayer.zonesIn[zone.id] then
        WEZ_MonitorPlayer.zonesIn[zone.id] = true
        if zone.noDamage then
            WEZ_MonitorPlayer.CheckAndTagHealth(player)
        end
        WEZ_MonitorPlayer.showEnterZone(player, zone)
    end

    if zone.noThump then
        zone:isNoThump(true)
    else
        zone:isNoThump(false)
    end

    if zone.noFishing and ISFishingUI.instance and ISFishingUI.instance[player:getPlayerNum()+1] and ISFishingUI.instance[player:getPlayerNum()+1]:getIsVisible() then
        ISFishingUI.instance[player:getPlayerNum()+1]:setVisible(false)
        ISFishingUI.instance[player:getPlayerNum()+1]:removeFromUIManager()
    end

    if zone.noDamage and WEZ_MonitorPlayer.healthInfoOnEnter then
        WEZ_MonitorPlayer.EnsureGoodHealth(player)
    end
    WEZ_MonitorPlayer.CheckJail(player, zone)
    WEZ_MonitorPlayer.CheckTeleport(player, zone)
    WEZ_MonitorPlayer.CheckDamage(player, zone)
    WEZ_MonitorPlayer.CheckRP(player, zone)
    WEZ_MonitorPlayer.CheckMoodle(player, zone)
    WEZ_MonitorPlayer.CheckWeather(zone)
    return {}
end

function WEZ_MonitorPlayer.increaseMoodle(player, moodle, amount)
    if amount >= 100 then amount = 100 end
    if amount < 0 then amount = 0 end
    if moodle == 1 then return end
    if moodle == 2 then
        local boredom = player:getBodyDamage():getBoredomLevel()
        if boredom < 76 then
            player:getBodyDamage():setBoredomLevel(boredom + 0.001)
        end
    elseif moodle == 3 then
        local hunger = player:getStats():getHunger()
        if hunger < 0.55 then
            player:getStats():setHunger(hunger + (0.00000005*amount))
        end
    elseif moodle == 4 then
        local pain = player:getStats():getPain()
        if amount >= 1 and amount <= 15 then
            player:getStats():setPain(pain + amount)
        elseif amount >= 16 and amount <= 25 then
            player:getStats():setPain(pain + amount)
        elseif amount >= 26 and amount <= 30 then
            player:getStats():setPain(pain + amount)
        elseif amount >= 31 then
            player:getStats():setPain(pain + amount)
        end
    elseif moodle == 5 then
        local panic = player:getStats():getPanic()
        if panic < 70 then
            player:getStats():setPanic(panic + (0.000085*amount))
        end
    elseif moodle == 6 then
        local stress = WL_Stress.getTotal(player)
        if stress < 0.80 then
            WL_Stress.adjust(0.0000001 * amount, player)
        end
    elseif moodle == 7 then
        local thirst = player:getStats():getThirst()
        if thirst < 0.71 then
            player:getStats():setThirst(thirst + (0.00000005*amount))
        end
    elseif moodle == 8 then
        local unhappyness = player:getBodyDamage():getUnhappynessLevel()
        if unhappyness < 70 then
            player:getBodyDamage():setUnhappynessLevel(unhappyness + (0.0000025*amount))
        end
    end
end

function WEZ_MonitorPlayer.CheckMoodle(player, zone)
    WEZ_MonitorPlayer.increaseMoodle(player, zone.moodleIncrease, zone.moodleIncreaseRate)
end

function WEZ_MonitorPlayer.CheckAndTagHealth(player)
    local bodyDamage = player:getBodyDamage()
    local bodyParts = bodyDamage:getBodyParts()
    local hasInjury = false

    for i=0, bodyParts:size()-1 do
        local bodyPart = bodyParts:get(i)
        if bodyPart:HasInjury() then
            hasInjury = true
            break
        end
    end
    if hasInjury then
        player:setHaloNote("Injured, Event zone will not protect!!!", 255, 0, 0, 60.0)
        WEZ_MonitorPlayer.wasHealthyOnEnter = false
    else
        player:setHaloNote("No Damage Zone", 0, 255, 0, 60.0)
        WEZ_MonitorPlayer.wasHealthyOnEnter = true
    end
end

function WEZ_MonitorPlayer.EnsureGoodHealth(player)
    local bodyDamage = player:getBodyDamage()
    bodyDamage:setOverallBodyHealth(100)
    local bodyParts = bodyDamage:getBodyParts()
    for i=0, bodyParts:size()-1 do
        local bodyPart = bodyParts:get(i)
        bodyPart:SetHealth(100)
        bodyPart:setBurnTime(0)
        bodyPart:SetBitten(false)
        bodyPart:setBleedingTime(0)
        bodyPart:setScratched(false, true)
        bodyPart:setScratchTime(0)
        bodyPart:setCut(false, true)
        bodyPart:setCutTime(0)
        bodyPart:setDeepWounded(false)
        bodyPart:setDeepWoundTime(0)
        bodyPart:setInfectedWound(false)
        bodyPart:SetInfected(false)
        bodyPart:setHaveBullet(false, 0)
        bodyPart:setHaveGlass(false)
        bodyPart:setFractureTime(0)
    end
end

function WEZ_MonitorPlayer.CheckTPBackToJail(player)
    if WEZ_MonitorPlayer.jailZoneId and not WEZ_MonitorPlayer.stillInJail then
        if WL_Utils.isStaff(player) then
            WEZ_MonitorPlayer.jailZoneId = false
            return
        end
        local targetZone = WEZ_EventZone.getZone(WEZ_MonitorPlayer.jailZoneId)
        local x, y, z = player:getX(), player:getY(), player:getZ()
        local targetX, targetY, targetZ = targetZone:getClosestPointInsideZone(x, y, z)
        local dist = math.sqrt((x - targetX)^2 + (y - targetY)^2 + (z - targetZ)^2)
        -- If TPd out of jail
        if dist > 50 then
            WEZ_MonitorPlayer.jailZoneId = false
            return
        end
        if targetZone and targetZone.isJail then
            local nx, ny = targetZone:getClosestPointInsideZone(x, y, z)
            WL_Utils.teleportPlayerToCoords(player, nx, ny, 0)
        else
            WEZ_MonitorPlayer.jailZoneId = false
        end
    end
end

function WEZ_MonitorPlayer.CheckJail(player, zone)
    if zone.isJail then
        WEZ_MonitorPlayer.jailZoneId = zone.id
        WEZ_MonitorPlayer.stillInJail = true
    end
end

function WEZ_MonitorPlayer.CheckBoot(player, zone)
    local isPlayerAllowed, reason = zone:isPlayerAllowed(player,zone)
    if not isPlayerAllowed then
        local x, y, z = player:getX(), player:getY(), player:getZ()
        local newX, newY, newZ = zone:getClosestPointOutsideZone(x, y, z)
        WEZ_MonitorPlayer.jailZoneId = false
        WEZ_MonitorPlayer.cancelRun = true
        WL_Utils.teleportPlayerToCoords(player, newX, newY, newZ)
        player:setHaloNote(reason, 255, 0, 0, 60.0)
        return true
    end
    return false
end

function WEZ_MonitorPlayer.CheckTeleport(player, zone)
    if zone.teleportX ~= 0 and zone.teleportY ~= 0 then
        if math.floor(zone.teleportX) == math.floor(player:getX()) and math.floor(zone.teleportY) == math.floor(player:getY()) then
            return
        end
        WEZ_MonitorPlayer.jailZoneId = false
        WEZ_MonitorPlayer.cancelRun = true
        WL_Utils.teleportPlayerToCoords(player, zone.teleportX, zone.teleportY, zone.teleportZ)
    end
end

function WEZ_MonitorPlayer.CheckDamage(player, zone)
    if zone.damageRate > 0 then
        if zone.damagePreventToggle then
            local maskEfficiency = WM_Utils.getEfficiency(player)
            if maskEfficiency >= 1 then
                return
            end
        end
        local items = {}
        for item in string.gmatch(zone.damagePreventItems, "([^;]+)") do
            table.insert(items, item)
        end
        local wornItems = WEZ_MonitorPlayer.getWornItems(player)
        for _, item in ipairs(items) do
            for _, wornItem in ipairs(wornItems) do
                if item == wornItem then
                    return
                end
            end
        end
        player:getBodyDamage():ReduceGeneralHealth(zone.damageRate/100)
    end
end

function WEZ_MonitorPlayer.getWornItems(player)
    local wornItems = {}
    local playerItems = player:getInventory():getItems()
    for i=0, playerItems:size()-1 do
        local item = playerItems:get(i)
        if player:isEquippedClothing(item) then
            table.insert(wornItems, item:getFullType())
        end
    end
    return wornItems
end

function WEZ_MonitorPlayer.isInCar(player)
    local vehicle = player:getVehicle()
    if vehicle and vehicle:getDriver() == player then
        return true
    end
    return false
end

--- @param player IsoPlayer
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.CheckRP(player, zone)
    if zone.isRpZone then
        player:getStats():setHunger(0.0)
        player:getStats():setThirst(0.0)
        player:getStats():setFatigue(0.0)
        player:getStats():setThirst(0.0)
        player:getBodyDamage():setBoredomLevel(0)
        player:getBodyDamage():setUnhappynessLevel(0)
        player:getBodyDamage():getThermoregulator():reset()
    end
end

--- @param player IsoPlayer
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.showWarning(player, zone)
    if zone.warningMessage == "" then
        return
    end
    player:addLineChatElement(zone.warningMessage, 255, 0, 0)
end

--- @param player IsoPlayer
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.showInCarWarning(player, zone)
    local vehicle = player:getVehicle()
    vehicle:getModData().WEZ_ZoneEnterTime = getTimestamp()
    player:addLineChatElement(zone.inCarsMessage, 255, 0, 0)
end

--- @param player IsoPlayer
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.showEnterZone(player, zone)
    if not zone or zone.enterMessage == "" then
        return
    end
    player:addLineChatElement(zone.enterMessage, 255, 0, 0)
end

--- @param player IsoPlayer
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.showExitZone(player, zone)
    if not zone or zone.exitMessage == "" then
        return
    end
    player:addLineChatElement(zone.exitMessage, 255, 0, 0)
end

-- Weather constants are now defined in WL_WeatherOverride

--- Converts EventZone weather settings to WL_WeatherOverride format
--- @param zone WEZ_EventZone
--- @return table A table of weather overrides in WL_WeatherOverride format
function WEZ_MonitorPlayer.ConvertZoneToOverrides(zone)
    local overrides = {}
    
    if zone.weatherWindEnabled then
        overrides.Wind = { intensity = (zone.weatherWind or 0) / getClimateManager():getMaxWindspeedKph() }
    end
    
    if zone.weatherCloudsEnabled then
        overrides.Clouds = { intensity = zone.weatherClouds or 0 }
    end
    
    if zone.weatherFogEnabled then
        overrides.Fog = { intensity = zone.weatherFog or 0 }
    end
    
    if zone.weatherPrecipitationEnabled then
        overrides.Precipitation = {
            intensity = zone.weatherPrecipitation or 0,
            isSnow = zone.weatherPrecipitationIsSnow or false
        }
    end
    
    if zone.weatherTemperatureEnabled then
        overrides.Temperature = { value = zone.weatherTemperature or 0 }
    end
    
    if zone.weatherDarknessEnabled then
        overrides.Darkness = { value = zone.weatherDarkness or 0 }
    end
    
    if zone.weatherDesaturationEnabled then
        overrides.Desaturation = { value = zone.weatherDesaturation or 0 }
    end
    
    if zone.weatherLightEnabled then
        overrides.Light = {
            intR = zone.weatherLightIntR or 0,
            intG = zone.weatherLightIntG or 0,
            intB = zone.weatherLightIntB or 0,
            intA = zone.weatherLightIntA or 0,
            extR = zone.weatherLightExtR or 0,
            extG = zone.weatherLightExtG or 0,
            extB = zone.weatherLightExtB or 0,
            extA = zone.weatherLightExtA or 0
        }
    end
    
    return overrides
end

--- Sets weather overrides from an EventZone
--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.SetZoneWeatherOverrides(zone)
    local overrides = WEZ_MonitorPlayer.ConvertZoneToOverrides(zone)
    
    -- Use the bulk set method instead of individual calls
    WL_WeatherOverride.SetBulkOverrides("zone_" .. zone.id, overrides, zone.weatherTransitionTicks)
end

--- Unsets all weather overrides for a zone
--- @param zoneId string The ID of the zone
function WEZ_MonitorPlayer.UnsetZoneWeatherOverrides(zoneId)
    WL_WeatherOverride.UnsetAllOverrides("zone_" .. zoneId)
end

--- @param zone WEZ_EventZone
function WEZ_MonitorPlayer.CheckWeather(zone)
    if not WEZ_MonitorPlayer.weatherApplied[zone.id] then
        -- Use our helper function to set weather overrides
        WEZ_MonitorPlayer.SetZoneWeatherOverrides(zone)
        WEZ_MonitorPlayer.weatherApplied[zone.id] = true
    end
end

Events.OnTick.Add(WEZ_MonitorPlayer.Check)


-- RP Hints

local RPHintsSystem = {}
RPHintsSystem.name = "EventZones"
function RPHintsSystem.GetHints()
    local hints = {}
    for zoneId, _ in pairs(WEZ_MonitorPlayer.zonesIn) do
        local zone = WEZ_EventZone.getZone(zoneId)
        if zone and zone.rpText and zone.rpText ~= "" then
            table.insert(hints, zone.rpText)
        end
    end
    return hints
end

if getActivatedMods():contains("WastelandRpHints") then
    WRH.RegisterSystem(RPHintsSystem)
end
