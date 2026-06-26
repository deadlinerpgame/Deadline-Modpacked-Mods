---
--- WorldMapOverride.lua
--- 05/10/2023
---
--- Enables any access level (other than regular player) to teleport by right clicking on the world map.
---
---
--- Currently Handled with Wandering Pollen Storm

local onRightMouseUp = ISWorldMap.onRightMouseUp
function ISWorldMap:onRightMouseUp(x, y)
	local bool = onRightMouseUp(self, x, y)

	if not (isClient() and (getAccessLevel() == "observer" or getAccessLevel() == "gm"
			or getAccessLevel() == "overseer" or getAccessLevel() == "moderator")) then
		return bool
	end

	local playerNum = 0
	local playerObj = getSpecificPlayer(0)
	if not playerObj then return end -- Debug in main menu
	local context = ISContextMenu.get(playerNum, x + self:getAbsoluteX(), y + self:getAbsoluteY())

	local worldX = self.mapAPI:uiToWorldX(x, y)
	local worldY = self.mapAPI:uiToWorldY(x, y)
	if getWorld():getMetaGrid():isValidChunk(worldX / 10, worldY / 10) then
		option = context:addOption("Teleport Here", self, self.onTeleport, worldX, worldY)
	end

	return true
end
