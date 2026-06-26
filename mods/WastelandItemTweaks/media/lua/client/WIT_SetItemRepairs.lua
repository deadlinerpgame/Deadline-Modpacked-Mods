---
--- WIT_SetItemRepairs.lua
--- 09/11/2024
---

if WIT_SetItemRepairs then
    Events.OnFillInventoryObjectContextMenu.Remove(WIT_SetItemRepairs.InventoryContextMenu)
end
WIT_SetItemRepairs = {}

function WIT_SetItemRepairs.display(player, item)
    local scale = getTextManager():getFontHeight(UIFont.Small) / 14
    local width = 220 * scale
    local height = 130 * scale
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)
    local modal = ISTextBox:new(x, y, width, height, "Enter repairs amount:", tostring(item:getHaveBeenRepaired()-1), nil, function (_, button)
        if button.internal == "OK" then
            local newRepairs = tonumber(button.target.entry:getText()) + 1
            if newRepairs then
                item:setHaveBeenRepaired(newRepairs)
            end
        end
    end, nil)
    modal:initialise()
    modal.entry:setOnlyNumbers(true)
    modal:addToUIManager()
    local originalDestroy = modal.destroy
    modal.destroy = function(self)
        originalDestroy(self)
    end
end

function WIT_SetItemRepairs.InventoryContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)
    local playerInv = playerObj:getInventory()

    items = ISInventoryPane.getActualItems(items)
    if #items == 1 then
        local item = items[1]
        if item:IsWeapon() and playerObj:isGodMod() and playerInv:contains(item) then
            local repairsText = "Set Repairs Amount"
            local repairsOption = context:addOption(repairsText, playerObj, WIT_SetItemRepairs.display, item)
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(WIT_SetItemRepairs.InventoryContextMenu)