require "WL_Utils"

WAT_ItemDuplicator = WAT_ItemDuplicator or {}

function WAT_ItemDuplicator.OnDuplicateItem(_, item, playerObj)
    local modal = ISTextBox:new(0, 0, 230, 130, "Number of Duplicates (max 100):", "", nil, function(_, button)
        WAT_ItemDuplicator.OnDuplicateItemConfirm(button, playerObj, item)
    end, nil)
    modal:initialise()
    modal.entry:setOnlyNumbers(true)
    modal:addToUIManager()
    local originalDestroy = modal.destroy
    modal.destroy = function(self)
        originalDestroy(self)
        self:removeFromUIManager()
    end
end

function WAT_ItemDuplicator.OnDuplicateItemConfirm(button, playerObj, item)
    if button.internal == "OK" then
        local count = tonumber(button.parent.entry:getText())
        if not count or count < 1 or count > 100 then
            playerObj:Say("Invalid number. Please enter a number between 1 and 100.")
            return
        end
        for i = 1, count do
            local newItem = WL_Utils.cloneItem(item)
            if newItem then
                item:getContainer():AddItem(newItem)
            end
        end
        print("Duplicated item " .. count .. " times!")
    end
end
function WAT_ItemDuplicator.OnFillInventoryObjectContextMenu(playerIdx, context, items)
    local playerObj = getSpecificPlayer(playerIdx)
    if #items ~= 1 then return end
    if isClient() and not WL_Utils.canModerate() then return end
    local item = items[1]
    if item.items then item = item.items[1] end
    if not item then return end
    context:addOption("Duplicate Item", nil, WAT_ItemDuplicator.OnDuplicateItem, item, playerObj)
end

if not WAT_ItemDuplicator.didBindEvents then
    Events.OnFillInventoryObjectContextMenu.Add(function (p, c, i) WAT_ItemDuplicator.OnFillInventoryObjectContextMenu(p, c, i) end)
    WAT_ItemDuplicator.didBindEvents = true
end