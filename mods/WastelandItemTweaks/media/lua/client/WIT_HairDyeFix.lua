-- Hair dye is valid at a usedDelta of either 0.5 or 1.
-- Any other value provides a Fix Hair Dye inventory option that raises it to the next valid value.

WIT_ItemFix = {}

local function isInPlayerInventory(item, player)
    local container = item:getContainer()
    return container and (container == player:getInventory() or container:isInCharacterInventory(player))
end

local function itemNeedsFix(item, player)
    if not item:isHairDye() then
        return false
    end

    local usedDelta = item:getUsedDelta()
    if usedDelta == 1 or usedDelta == 0.5 then
        return false
    end

    return isInPlayerInventory(item, player)
end

local function fixItem(player, item)
    if not item:isHairDye() then
        return
    end

    if not isInPlayerInventory(item, player) then
        return
    end

    local usedDelta = item:getUsedDelta()
    if usedDelta == 1 or usedDelta == 0.5 then
        return
    end

    if usedDelta < 0.5 then
        item:setUsedDelta(0.5)
    else
        item:setUsedDelta(1)
    end
end

function WIT_ItemFix.InventoryContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)

    items = ISInventoryPane.getActualItems(items)
    for _, item in ipairs(items) do
        if itemNeedsFix(item, playerObj) then
            local fixOption = context:addOptionOnTop("Fix Hair Dye", playerObj, fixItem, item)

            WL_ContextMenuUtils.addToolTip(
                fixOption,
                "Fix Hair Dye",
                "Raise this hair dye to the next valid amount.",
                item:getTex():getName()
            )
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(WIT_ItemFix.InventoryContextMenu)
