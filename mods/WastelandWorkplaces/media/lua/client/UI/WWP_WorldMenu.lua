---
--- WWP_WorldMenu.lua
--- Right click context menu for Admins, used for managing workplaces
--- 18/06/2023
---
---
if not isClient() then return end

require "UI/WL_CreateZonePanel"
require "WL_ContextMenuUtils"
require "WL_Utils"

local WWP_WorldMenu = {}

WWP_WorldMenu.doMenu = function(playerIdx, context)
	local player = getPlayer(playerIdx)
	local x, y = ISCoordConversion.ToWorld(getMouseXScaled(), getMouseYScaled(), player:getZ())

	if WL_Utils.canModerate(player) then
		local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Zones")
		submenu:addOption("List Workplaces" , nil, WWP_WorldMenu.listZones)
		submenu:addOption("List Towns" , nil, WWP_WorldMenu.listTowns)
		local startingCoordinates = {
            startX = math.floor(player:getX() - 5),
            startY = math.floor(player:getY() - 5),
            endX = math.floor(player:getX() + 5),
            endY = math.floor(player:getY() + 5),
		}
		submenu:addOption("New Workplace", startingCoordinates, WWP_WorldMenu.createZone)
		submenu:addOption("New Town", startingCoordinates, WWP_WorldMenu.createTown)
	end

	local workplaces = WWP_WorkplaceZone.getZonesAt(x, y, player:getZ())
	for i=1,#workplaces do 	-- Very unlikely to be more than one here
		local zone = workplaces[i]
		context:addOption(zone.type.name .. " Details", zone, WWP_WorldMenu.openWorkplacePanel)
		if WL_Utils.canModerate(player) or (zone:isEmployee(player) and not zone.isNPC) then
			local openClosed = zone.open and "Close " or "Open "
			context:addOption(openClosed.. zone.name, zone, WWP_WorldMenu.flipOpenClosed)
		end

		-- if WL_Utils.canModerate(player) then
		-- 	local square = getCell():getGridSquare(x, y, player:getZ())
		-- 	local objects = square:getObjects()
		-- 	for j=0,objects:size()-1 do
		-- 		local obj = objects:get(j)
		-- 		if obj:getContainer() then
		-- 			if obj:getModData().WWP_AutoATSContainer then
		-- 				context:addOption("Remove Auto-ATS Container", obj, WWP_WorldMenu.removeAutoATSContainer)
		-- 			else
		-- 				context:addOption("Set as Auto-ATS Container", obj, WWP_WorldMenu.setAutoATSContainer)
		-- 			end
		-- 		end
		-- 	end
		-- end
	end

	local town = WWP_Town.findTownAt(x, y, player:getZ())
	if town then
		context:addOption("Settlement Details", town, WWP_WorldMenu.openTownPanel)
	end
end

function WWP_WorldMenu.setAutoATSContainer(object)
	object:getModData().WWP_AutoATSContainer = true
	object:transmitModData()
end

function WWP_WorldMenu.removeAutoATSContainer(object)
	object:getModData().WWP_AutoATSContainer = nil
	object:transmitModData()
end

function WWP_WorldMenu.listZones()
	WWP_ListWorkplaces:show()
end

function WWP_WorldMenu.listTowns()
	WWP_ListTowns:show()
end

local function createWorkplaceZone(name, startX, startY, endX, endY, startZ, endZ)
	local newZone = WWP_WorkplaceZone:new(name, startX, startY, endX, endY, startZ, endZ)
	WWP_WorkplaceZones[newZone.id] = newZone
	WWP_WorkplacePanel.display(newZone)
end

function WWP_WorldMenu.createZone(startingCoordinates)
	if WWP_ListWorkplaces.instance then
		WWP_ListWorkplaces.instance:onClose()
	end

	WL_CreateZonePanel:show("Workplace", startingCoordinates, createWorkplaceZone, false)
end

local function createTownZone(name, coords)
	local newTown = WWP_Town.createTown(name, coords)
	newTown:save()
	WWP_TownPanel.display(newTown)
end

function WWP_WorldMenu.createTown(startingCoordinates)
	WL_CreateZonePanel:display("Settlement", startingCoordinates, createTownZone, true)
end

function WWP_WorldMenu.openTownPanel(town)
	WWP_TownPanel.display(town)
end

function WWP_WorldMenu.openWorkplacePanel(workplace)
	WWP_WorkplacePanel.display(workplace)
end

--- @param zone WWP_WorkplaceZone
function WWP_WorldMenu.flipOpenClosed(zone)
	zone.open = not zone.open
	zone:save()

	if zone.open then
		zone:showWorkplaceInfo(getPlayer())
	end
end

Events.OnFillWorldObjectContextMenu.Add(WWP_WorldMenu.doMenu)