---
--- WL_HomingArrow.lua
--- 22/10/2023
---

require "WLBaseObject"

WL_HomingArrow = WLBaseObject:derive("WL_HomingArrow")

--- Make a new homing arrow that will point at the given coordinates when the player is within range.
--- @param x number
--- @param y number
--- @param z number|nil
--- @param range number|nil
--- @param zRange number|nil
--- @param color table|nil
--- @param description string|nil
--- @return WL_HomingArrow
function WL_HomingArrow:new(x, y, z, range, zRange, color, description)
	local o = WL_HomingArrow.parentClass.new(self)
	o.z = z or 0
	o.x = x - (o.z * 3)
	o.y = y - (o.z * 3)
	o.range = range or 8
	o.zRange = zRange or 0
	o.color = color or { r = 255, g = 255, b = 255, a = 0.8}  -- Red/Green/Blue/Alpha
	o.description = description -- Can be nil
	return o
end

function WL_HomingArrow:setRange(range, zRange)
	self.range = range
	self.zRange = zRange or 0
end

--- Cheap function to check if the given coordinates are near this arrow's target.
--- Doesn't do diagonals well, but avoids expensive math operations, as it is designed to be run frequently.
function WL_HomingArrow:isNear(x, y, z)
	if math.abs(self.z - z) > self.zRange then
		return false
	end

	local dx = self.x - x
	local dy = self.y - y
	if dx * dx + dy * dy > self.range * self.range then
		return false
	end

	return true
end

function WL_HomingArrow:isVisible(player)
	return true
end

