require "WL_Utils"

WAT_BagEditor = WAT_BagEditor or {}

function WAT_BagEditor.OnChangeSize(_, item, playerObj)
    local currentCapacity = item:getCapacity()
    local modal = ISTextBox:new(0, 0, 280, 180, "New Capacity (1-999999999):", tostring(currentCapacity), nil, function(_, button)
        WAT_BagEditor.OnChangeSizeConfirm(button, playerObj, item)
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

function WAT_BagEditor.OnChangeSizeConfirm(button, playerObj, item)
    if button.internal == "OK" then
        local capacity = tonumber(button.parent.entry:getText())
        if not capacity or capacity < 1 or capacity > 999999999 then
            playerObj:Say("Invalid capacity. Please enter a number between 1 and 999999999.")
            return
        end
        item:setCapacity(capacity)
        playerObj:Say("Bag capacity set to " .. capacity)
    end
end

function WAT_BagEditor.OnChangeReduction(_, item, playerObj)
    local currentReduction = item:getWeightReduction()
    local modal = ISTextBox:new(0, 0, 280, 180, "New Weight Reduction (0-100):", tostring(currentReduction), nil, function(_, button)
        WAT_BagEditor.OnChangeReductionConfirm(button, playerObj, item)
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

function WAT_BagEditor.OnChangeReductionConfirm(button, playerObj, item)
    if button.internal == "OK" then
        local reduction = tonumber(button.parent.entry:getText())
        if not reduction or reduction < 0 or reduction > 100 then
            playerObj:Say("Invalid reduction. Please enter a number between 0 and 100.")
            return
        end
        item:setWeightReduction(reduction)
        playerObj:Say("Bag weight reduction set to " .. reduction)
    end
end

function WAT_BagEditor.OnFillInventoryObjectContextMenu(playerIdx, context, items)
    local playerObj = getSpecificPlayer(playerIdx)
    if #items ~= 1 then return end
    if isClient() and not WL_Utils.canModerate() then return end
    
    local item = items[1]
    if item.items then item = item.items[1] end
    if not item then return end
    
    if not instanceof(item, "InventoryContainer") then return end

    local modifyOption = context:addOption("Modify Bag")
    local subMenu = context:getNew(context)
    context:addSubMenu(modifyOption, subMenu)

    subMenu:addOption("Change Size", nil, WAT_BagEditor.OnChangeSize, item, playerObj)
    subMenu:addOption("Change Reduction", nil, WAT_BagEditor.OnChangeReduction, item, playerObj)
end

if not WAT_BagEditor.didBindEvents then
    Events.OnFillInventoryObjectContextMenu.Add(function (p, c, i) WAT_BagEditor.OnFillInventoryObjectContextMenu(p, c, i) end)
    WAT_BagEditor.didBindEvents = true
end