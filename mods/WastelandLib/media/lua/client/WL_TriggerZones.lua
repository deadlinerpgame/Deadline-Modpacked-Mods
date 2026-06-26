---
--- WL_TriggerZones.lua
--- 31/10/2023
---
require "WL_Zone"

local playerIsLoaded = false

WL_TriggerZones = {}

WL_TriggerZones.monitoredZones = {}  -- Used to hold the actual zones

--- Add a zone to track. When a player enters the zone, the function onPlayerEnteredZone(player) will be called
--- When the player exits the zone, the function onPlayerExitedZone(player) will be called.
--- Each minute, onPlayerStayedForMinute(player, minutes) is called if the player is still in the zone.
--- @param zone table that derives from WL_Zone
--- @param allowGods boolean|nil if true, staff in god mode will still trigger events, otherwise they will not
--- @see WL_Zone
function WL_TriggerZones.addZone(zone, allowGods)
	table.insert(WL_TriggerZones.monitoredZones, zone)
	zone.allowGods = allowGods
end

--- Remove a zone from being tracked from all events
--- @param zone table that derives from WL_Zone
function WL_TriggerZones.removeZone(zoneToRemove)
	for i, zone in ipairs(WL_TriggerZones.monitoredZones) do
		if zone == zoneToRemove then
			table.remove(WL_TriggerZones.monitoredZones, i)
			return true
		end
	end
	return false
end

--- Checks if a zone is being tracked
--- @param zoneToCheck table that derives from WL_Zone
--- @return boolean true if tracked, false otherwise
function WL_TriggerZones.isZoneMonitored(zoneToCheck)
	for _, zone in ipairs(WL_TriggerZones.monitoredZones) do
		if zone == zoneToCheck then
			return true
		end
	end
	return false
end


--- How many ticks remaining until we perform a check
WL_TriggerZones.checkTimeout = 0

--- How often we check if player is inside zones in ticks
WL_TriggerZones.checkInterval = 30

--- How many ms in one minute (Constant)
WL_TriggerZones.oneMinute = 60000

--- Stores which zones the player is known to have been in last time we checked, and for how long
WL_TriggerZones.zonesIn = {}

function WL_TriggerZones.OnTick()
	if not playerIsLoaded then return end
	if WL_TriggerZones.checkTimeout > 0 then
		WL_TriggerZones.checkTimeout = WL_TriggerZones.checkTimeout - 1
		return
	end
	WL_TriggerZones.checkTimeout = WL_TriggerZones.checkInterval

	local player = getPlayer()
	if not player then return end

	local currentlyInZones = {}
	local x, y, z = player:getX(), player:getY(), player:getZ()
	local zonesPlayerIsInside = WL_TriggerZones.getZonesAt(x, y, z)

	for _, zone in pairs(zonesPlayerIsInside) do
		if zone.allowGods or not player:isGodMod() then
			currentlyInZones[zone] = true
			local zoneInfo = WL_TriggerZones.zonesIn[zone]

			if(zoneInfo) then -- We were in here already
				local timeSinceLastTick = getTimestampMs() - zoneInfo.minuteStartedTimeMs
				if(timeSinceLastTick > WL_TriggerZones.oneMinute) then -- If one minute passed
					zoneInfo.minutesPassed = zoneInfo.minutesPassed + 1 -- Count minutes
					zoneInfo.minuteStartedTimeMs = getTimestampMs() -- Reset the timer
					zone:onPlayerStayedForMinute(player, zoneInfo.minutesPassed)
				end
			else -- Just entered this zone now
				WL_TriggerZones.zonesIn[zone] = {
					minuteStartedTimeMs = getTimestampMs(),
					minutesPassed = 0
				}
				zone:onPlayerEnteredZone(player)
			end
		end
	end

	-- Find zones the player has left
	for zone, _ in pairs(WL_TriggerZones.zonesIn) do
		if not currentlyInZones[zone] then
			WL_TriggerZones.zonesIn[zone] = nil
			zone:onPlayerExitedZone(player)
		end
	end
end

function WL_TriggerZones.getZonesAt(x, y, z)
	local zones = {}
	for _, zone in pairs(WL_TriggerZones.monitoredZones) do
		if zone:isInZone(x, y, z) then
			table.insert(zones, zone)
		end
	end
	return zones
end

Events.OnTick.Add(WL_TriggerZones.OnTick)
WL_PlayerReady.Add(function()
	playerIsLoaded = true
end)
Events.OnPlayerDeath.Add(function(player)
	playerIsLoaded = false
end)