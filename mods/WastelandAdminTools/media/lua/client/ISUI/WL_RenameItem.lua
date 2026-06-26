---
--- WL_RenameItem.lua
--- 18/02/2025
---
require "ISInventoryPaneContextMenu"

WL_RenameItem = {};

WL_RenameItem.createMenu = function(playerID, context, items)
	if getAccessLevel() == "observer" then
		local item = nil;
		for i, v in ipairs(items) do
			item = v;

			if not instanceof(v, "InventoryItem") then
				item = v.items[1];
			end
		end

		if item then
			context:addOption("Rename Item", item, WL_RenameItem.onRenameItem, playerID);
		end
	end
end

WL_RenameItem.onRenameItem = function(item, player)
	local modal = ISTextBox:new(0, 0, 280, 180, getText("Enter the new name"), "", nil, WL_RenameItem.onConfirmNewName, player, getSpecificPlayer(player), item);
	modal:initialise();
	modal:addToUIManager();
end

function WL_RenameItem:onConfirmNewName(button, player, item)
	if button.internal == "OK" then
		if button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
			item:setName(button.parent.entry:getText());
			item:setCustomName(true);
			local pdata = getPlayerData(player:getPlayerNum());
			pdata.playerInventory:refreshBackpacks();
			pdata.lootInventory:refreshBackpacks();
		end
	end
end

Events.OnPreFillInventoryObjectContextMenu.Add(WL_RenameItem.createMenu);