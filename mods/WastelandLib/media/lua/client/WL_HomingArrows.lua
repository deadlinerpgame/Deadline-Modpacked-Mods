---
--- WL_HomingArrows.lua
--- Allows adding of arrows that point at locations for a player when they are within range.
--- 22/10/2023
---

--TODO make this client or SP only

require "WL_HomingArrow"

WL_HomingArrows = {}

WL_HomingArrowList = {} -- Used to hold the actual arrows

--- Add a new homing arrow which will activate when a player is within it's range.
--- @param x number x coordinate of what the arrow is pointing at. Required.
--- @param y number y coordinate of what the arrow is pointing at. Required.
--- @param z number|nil z coordinate of what the arrow is pointing at. Optional, defaults to 0.
--- @param range number|nil how close the player needs to be (in tiles) before the arrow appears. Optional, defaults to 8.
--- @param zRange number|nil how close the Z level needs to be. Optional, defaults to 0 (Same z-level)
--- @param color table|nil in the format of { r = 0-255, g = 0-255, b = 0-255, a = 0-1}, whereby the values are
--- representing Red, Green, Blue and Alpha level of the arrow itself. Optional, defaults to white.
--- @param description string|nil that appears as a halo note when the arrow is first made. Optional, defaults to nil.
--- @return table WL_HomingArrow that was created for you
function WL_HomingArrows.addArrow(x, y, z, range, zRange, color, description)
	return WL_HomingArrows.addCustomArrow(WL_HomingArrow:new(x, y, z, range, zRange, color, description))
end

--- Adds a custom arrow. These are made by extending WL_HomingArrow
--- @return table the custom arrow passed back
--- @see WL_HomingArrow
function WL_HomingArrows.addCustomArrow(arrow)
	table.insert(WL_HomingArrowList, arrow)
	return arrow
end

--- Removes an arrow that has been added earlier
--- @param arrowToRemove table arrow that should be removed
--- @return boolean true if we found something to remove
function WL_HomingArrows.removeArrow(arrowToRemove)
	for i, arrow in ipairs(WL_HomingArrowList) do
		if arrow == arrowToRemove then
			table.remove(WL_HomingArrowList, i)
			return true
		end
	end
	return false
end

--- How many ticks remaining until we perform a check
WL_HomingArrows.checkTimeout = 0

--- How often we check if player is nearby arrows, in TICKS
WL_HomingArrows.checkInterval = 100

--- Dictionary of Arrow -> Homing Point containing only the Points the player is close to
WL_HomingArrows.activeHomingPoints = {}

--- Return the array of arrows which point at locations near the given coordinates
function WL_HomingArrows.getArrowsNearPlayer(player)
	local arrowsNear = {}
	local x, y, z = player:getX(), player:getY(), player:getZ()
	for _, arrow in pairs(WL_HomingArrowList) do
		if arrow:isVisible(player) and arrow:isNear(x, y, z) then
			table.insert(arrowsNear, arrow)
		end
	end
	return arrowsNear
end

function WL_HomingArrows.OnTick()
	if WL_HomingArrows.checkTimeout > 0 then
		WL_HomingArrows.checkTimeout = WL_HomingArrows.checkTimeout - 1
		return
	end
	WL_HomingArrows.checkTimeout = WL_HomingArrows.checkInterval

	local player = getPlayer()
	if not player then return end
	local nearbyArrows = WL_HomingArrows.getArrowsNearPlayer(player)

	for _, arrow in pairs(nearbyArrows) do
		local homingPoint = WL_HomingArrows.activeHomingPoints[arrow]
		if not homingPoint then -- No Homing Point, but the arrow's target is close, so make one
			if arrow.description then
				player:setHaloNote(arrow.description, arrow.color.r, arrow.color.g, arrow.color.b, 200.0)
			end
			homingPoint = getWorldMarkers():addPlayerHomingPoint(player, arrow.x, arrow.y,
					"arrow_triangle", arrow.color.r/255, arrow.color.g/255, arrow.color.b/255,
					arrow.color.a, true, 1);
			WL_HomingArrows.activeHomingPoints[arrow] = homingPoint
		end
	end

	-- Check if any arrows have moved out of range
	local homingPointsToRemove = {}
	for arrow, homingPoint in pairs(WL_HomingArrows.activeHomingPoints) do
		local isNearby = false
		for _, nearbyArrow in pairs(nearbyArrows) do
			if arrow == nearbyArrow then
				isNearby = true
				break;
			end
		end

		if not isNearby then
			homingPointsToRemove[arrow] = homingPoint
		end
	end

	-- Remove out of range arrows we found
	for arrow, homingPoint in pairs(homingPointsToRemove) do
		homingPoint:remove();
		WL_HomingArrows.activeHomingPoints[arrow] = nil
	end
end

Events.OnTick.Add(WL_HomingArrows.OnTick)