---
--- WL_AdminContextMenuOverride.lua
--- 31/01/2025
---
require "DebugUIs/AdminContextMenu"

local originalAdminContextMenu = AdminContextMenu.doMenu

AdminContextMenu.doMenu = function(player, context, worldobjects, test)

	-- Add car menus for roles that don't usually get it
	if isClient() and (getAccessLevel() == "observer" or getAccessLevel() == "gm" or getAccessLevel() == "overseer") then
		local playerObj = getSpecificPlayer(player)

		local square = nil;
		for i,v in ipairs(worldobjects) do
			square = v:getSquare();
			break;
		end

		local debugOption = context:addDebugOption("Tools", worldobjects, nil);
		local subMenu = ISContextMenu:getNew(context);
		context:addSubMenu(debugOption, subMenu);

		subMenu:addOption("Spawn Vehicle", playerObj, AdminContextMenu.onSpawnVehicle);

		local vehicle = square:getVehicleContainer()
		if vehicle ~= nil then
			local debugVehOption = subMenu:addOption("Vehicle:", worldobjects, nil);
			local vehSubMenu = ISContextMenu:getNew(subMenu);
			context:addSubMenu(debugVehOption, vehSubMenu);

			vehSubMenu:addOption("HSV & Skin UI", playerObj, AdminContextMenu.onDebugColor, vehicle);
			vehSubMenu:addOption("Blood UI", playerObj, AdminContextMenu.onDebugBlood, vehicle);
			vehSubMenu:addOption("Remove", playerObj, ISVehicleMechanics.onCheatRemove, vehicle);
		end
	end

	return originalAdminContextMenu(player, context, worldobjects, test)
end

Events.OnFillWorldObjectContextMenu.Remove(originalAdminContextMenu)
Events.OnFillWorldObjectContextMenu.Add(AdminContextMenu.doMenu)