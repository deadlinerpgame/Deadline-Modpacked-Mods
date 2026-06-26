---
--- WWP_MonitorPlayer.lua
--- 20/06/2023
---

require "WWP_WorkplaceZone"

if not isClient() then return end

WWP_MonitorPlayer = {}

--- How many ticks remaining until we perform a check
WWP_MonitorPlayer.checkTimeout = 0

--- How often we check if player is inside zones another other things, in TICKS
WWP_MonitorPlayer.checkInterval = 30

--- How many ms in one minute (Constant)
WWP_MonitorPlayer.oneMinute = 60000

WWP_MonitorPlayer.zonesIn = {}

local function isLockedItem(item)
	return item:getModData().WWP_ATS_Applied
end

function WWP_MonitorPlayer.OnTick()
	if WWP_MonitorPlayer.checkTimeout > 0 then
		WWP_MonitorPlayer.checkTimeout = WWP_MonitorPlayer.checkTimeout - 1
		return
	end
	WWP_MonitorPlayer.checkTimeout = WWP_MonitorPlayer.checkInterval

	local player = getPlayer()
	if not player then return end
	if player:isGodMod() then return end

	local currentlyInZones = {}
	local x, y, z = player:getX(), player:getY(), player:getZ()
	local zones = WWP_WorkplaceZone.getZonesAt(x, y, z)
	for _, zone in pairs(zones) do
		currentlyInZones[zone.id] = true
		local zoneInfo = WWP_MonitorPlayer.zonesIn[zone.id]
		if(zoneInfo) then -- We were in here already
			local timeSinceLastTick = getTimestampMs() - zoneInfo.minuteStartedTimeMs
			if(timeSinceLastTick > WWP_MonitorPlayer.oneMinute) then -- If one minute passed
				zoneInfo.minutesPassed = zoneInfo.minutesPassed + 1 -- Count minutes
				zoneInfo.minuteStartedTimeMs = getTimestampMs() -- Reset the timer
				zone:perMinute(player)

				if((zoneInfo.minutesPassed % 2) == 0) then -- If 2 minutes have passed
					zone:perTwoMinutes(player)
				end
				if((zoneInfo.minutesPassed % 5) == 0) then -- If 5 minutes have passed
					zone:perFiveMinutes(player)
				end
				if (zoneInfo.minutesPassed % 10 == 0) then
					zone:perTenMinutes(player)
				end

				if(zoneInfo.minutesPassed == 60) then -- Reset timer
					zoneInfo.minutesPassed = 0
				end
			end
		else -- Just entered this zone now
			WWP_MonitorPlayer.zonesIn[zone.id] = {
				["zone"] = zone,
				minuteStartedTimeMs = getTimestampMs(),
				minutesPassed = 0
			}
			zone:onEnter(player)
		end
	end

	-- Find zones the player has left
	for zoneId, zoneInfo in pairs(WWP_MonitorPlayer.zonesIn) do
		if not currentlyInZones[zoneId] then
			WWP_MonitorPlayer.zonesIn[zoneId] = nil
			zoneInfo.zone:onExit(player)
		end
	end

	local lockedItems = player:getInventory():getAllEvalRecurse(isLockedItem)
	for i=0, lockedItems:size()-1 do
		local item = lockedItems:get(i)
		local workplaceId = item:getModData().WWP_ATS_AppliedTo
		if not currentlyInZones[workplaceId] then
			local wp = WWP_WorkplaceZone.getZone(workplaceId)
			if wp then
				player:addLineChatElement("You have items on you which are not allowed to leave " .. wp.name .. "!")
				local tx, ty, tz = wp:getClosestPointInsideZone(x, y, z)
				WL_Utils.teleportPlayerToCoords(player, tx, ty, tz)
			end
		end
	end

end

Events.OnTick.Add(WWP_MonitorPlayer.OnTick)