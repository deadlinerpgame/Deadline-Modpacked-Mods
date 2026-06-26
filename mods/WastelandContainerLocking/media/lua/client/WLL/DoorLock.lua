WLL = WLL or {}
WLL.DoorLock = WLL.DoorLock or {}

function WLL.DoorLock.getSquareDoor(square)
    for i=0,square:getObjects():size()-1 do
        local obj = square:getObjects():get(i)
        if WLL.DoorLock.IsObjectDoor(obj) then
            return obj
        end
    end
end

function WLL.DoorLock.IsObjectDoor(object)
    if object and (instanceof(object, "IsoDoor") or (instanceof(object, "IsoThumpable") and object:isDoor())) then
        return true
    end
    return false
end

function WLL.DoorLock.PlayerCanPickDoorLock(player)
    return (player:HasTrait("Burglar") or player:HasTrait("Locksmith"))
    and player:getInventory():FindAndReturn("Screwdriver")
    and player:getInventory():FindAndReturn("Paperclip")
end

function WLL.DoorLock.GetDoorKeyId(door)
    local keyID = -1
    if instanceof(door, "IsoDoor") then
        keyID = door:checkKeyId()
    elseif instanceof(door, "IsoThumpable") then
        keyID = door:getKeyId()
    end
    return keyID
end

function WLL.DoorLock.HasLock(door)
    return WLL.DoorLock.GetDoorKeyId(door) ~= -1 and door:getModData().CustomLock
end

function WLL.DoorLock.CreateKey(door)
    local keyID = WLL.DoorLock.GetDoorKeyId(door)
    if keyID ~= -1 then
        local item = InventoryItemFactory.CreateItem("Base.Key1")
        item:setKeyId(keyID)
        item:setName("Door Key (" .. keyID .. ")")
        item:setCustomName(true)
        return item
    end
end

function WLL.DoorLock.SetDoorKey(door, keyID)
    door:setKeyId(keyID)
    door:getModData().CustomLock = keyID ~= -1
    door:transmitModData()

    local doubleDoorObjects = buildUtil.getDoubleDoorObjects(door)
    for i=1,#doubleDoorObjects do
        local object = doubleDoorObjects[i]
        object:setKeyId(keyID)
        object:getModData().CustomLock = keyID ~= -1
        object:transmitModData()
    end

    local garageDoorObjects = buildUtil.getGarageDoorObjects(door)
    for i=1,#garageDoorObjects do
        local object = garageDoorObjects[i]
        object:setKeyId(keyID)
        object:getModData().CustomLock = keyID ~= -1
        object:transmitModData()
    end
end

function WLL.DoorLock.CanUnlockDoor(player, door)
    local keyID = WLL.DoorLock.GetDoorKeyId(door)
    if keyID == -1 then
        return true
    end
    return player:getInventory():haveThisKeyId(keyID)
end

---Apply a key id and matching display name to a loose door lock item.
---@param item InventoryItem
---@param keyID integer
function WLL.DoorLock.SetDoorLockKeyId(item, keyID)
    item:getModData().KeyId = keyID
    item:setName("Door Lock (Key: " .. keyID .. ")")
    item:setCustomName(true)
end

---Collect all selected loose door lock items from an inventory context menu selection.
---@param items table
---@return InventoryItem[]
function WLL.DoorLock._GetSelectedInventoryDoorLocks(items)
    local selectedItems = {}
    for _, v in ipairs(items) do
        if instanceof(v, "InventoryItem") then
            if v:getFullType() == "Base.WLLDoorLock" then
                table.insert(selectedItems, v)
            end
        elseif v.items then
            for _, item in ipairs(v.items) do
                if item and item:getFullType() == "Base.WLLDoorLock" then
                    table.insert(selectedItems, item)
                end
            end
        end
    end
    return selectedItems
end

---Gather distinct key ids from the player's other loose door locks.
---@param player IsoPlayer
---@param selectedItems InventoryItem[]
---@return integer[]
function WLL.DoorLock._GetAvailableInventoryKeyIds(player, selectedItems)
    local keyIds = {}
    local seenIds = {}
    local selectedIds = {}
    for _, item in ipairs(selectedItems) do
        selectedIds[item:getID()] = true
    end

    local inventoryLocks = player:getInventory():getAllTypeEvalRecurse("WLLDoorLock", function (item)
        local keyId = item:getModData().KeyId
        return keyId and not selectedIds[item:getID()]
    end)

    for i=0,inventoryLocks:size()-1 do
        local item = inventoryLocks:get(i)
        local keyId = item:getModData().KeyId
        if keyId and not seenIds[keyId] then
            seenIds[keyId] = true
            table.insert(keyIds, keyId)
        end
    end

    table.sort(keyIds)
    return keyIds
end

---Set the chosen key id on the selected loose door lock items and refresh inventory views.
---@param player IsoPlayer
---@param items InventoryItem[]
---@param keyID integer
function WLL.DoorLock.OnSetInventoryLockKeyId(player, items, keyID)
    for _, item in ipairs(items) do
        WLL.DoorLock.SetDoorLockKeyId(item, keyID)
    end

    local pdata = getPlayerData(player:getPlayerNum())
    if pdata then
        if pdata.playerInventory then
            pdata.playerInventory:refreshBackpacks()
        end
        if pdata.lootInventory then
            pdata.lootInventory:refreshBackpacks()
        end
    end

    if #items == 1 then
        WLL.ShowInfo(player, "Door lock set to key " .. keyID .. ".")
    else
        WLL.ShowInfo(player, "Set " .. #items .. " door locks to key " .. keyID .. ".")
    end
end

function WLL.DoorLock.OnPickLock(player, door)
    local paperclip = player:getInventory():FindAndReturn("Paperclip")
    local screwdriver = player:getInventory():FindAndReturn("Screwdriver")
    if not paperclip or not screwdriver then
        return
    end

    local action = WLLPickDooorLockAction:new(player, door)
    ISTimedActionQueue.add(action)
end

function WLL.DoorLock.OnRemoveLock(player, door)
    local keyID = WLL.DoorLock.GetDoorKeyId(door)
    if keyID ~= -1 then
        local item = player:getInventory():AddItem("WLLDoorLock")
        WLL.DoorLock.SetDoorLockKeyId(item, keyID)
        WLL.DoorLock.SetDoorKey(door, -1)
        WLL.ShowInfo(player, "Removed the lock from the door.")
    end
end

function WLL.DoorLock.OnCreateKey(player, door)
    local key = WLL.DoorLock.CreateKey(door)
    if key then
        player:getInventory():AddItem(key)
        local item = player:getInventory():FindAndReturn("ScrapMetal")
        item:getContainer():DoRemoveItem(item)
        WLL.ShowInfo(player, "Created a key for the door.")
    end
end

function WLL.DoorLock.OnRekeyDoor(player, door)
    local keyID = ZombRand(1, 2000000000)
    WLL.DoorLock.SetDoorKey(door, keyID)
    local key = WLL.DoorLock.CreateKey(door)
    if key then
        player:getInventory():AddItem(key)
    end
    WLL.ShowInfo(player, "Rekeyed the door.")
end

function WLL.DoorLock.OnAddLock(player, door)
    local item = player:getInventory():FindAndReturn("WLLDoorLock")
    if item then
        local keyID = item:getModData().KeyId
        if not keyID then
            keyID = ZombRand(1, 2000000000)
        end
        WLL.DoorLock.SetDoorKey(door, keyID)
        item:getContainer():DoRemoveItem(item)
        WLL.ShowInfo(player, "Added a lock to the door. Make sure you have a key or to make a key before locking the door.")
    end
end

function WLL.DoorLock.DoorMenu(player, door, context)
    local doorContext = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Door Lock")

    local isLocksmith = player:HasTrait("Locksmith")
    local isBurglar = player:HasTrait("Burglar")
    local hasScrewdriver = player:getInventory():FindAndReturn("Screwdriver")
    local hasScrapMetal = player:getInventory():FindAndReturn("ScrapMetal")
    local hasPaperclip = player:getInventory():FindAndReturn("Paperclip")
    local doorLock = player:getInventory():FindAndReturn("WLLDoorLock")

    local function buildTooltip(option, missingItems)
        if #missingItems > 0 then
            option.notAvailable = true
            local tooltip = ISToolTip:new()
            tooltip:initialise()
            tooltip:setVisible(false)
            tooltip.description = " <RGB:1,0,0> Missing: " .. table.concat(missingItems, " <LINE> Missing: ")
            option.toolTip = tooltip
        elseif option.toolTip then
            option.toolTip:setVisible(false)
        end
    end

    if WLL.DoorLock.HasLock(door) then
        if door:isLocked() then
            local option = doorContext:addOption("Pick Lock", player, WLL.DoorLock.OnPickLock, door)
            local missingItems = {}

            if not (isLocksmith or isBurglar) then
                table.insert(missingItems, "Locksmith or Burglar trait")
            end
            if not hasScrewdriver then
                table.insert(missingItems, "Screwdriver in main inventory")
            end
            if not hasPaperclip then
                table.insert(missingItems, "Paperclip in main inventory")
            end

            buildTooltip(option, missingItems)
        else
            local option = doorContext:addOption("Remove Lock", player, WLL.DoorLock.OnRemoveLock, door)
            local missingItems = {}

            if not isLocksmith then
                table.insert(missingItems, "Locksmith trait")
            end
            if not hasScrewdriver then
                table.insert(missingItems, "Screwdriver in main inventory")
            end

            buildTooltip(option, missingItems)
        end

        if not door:isLocked() then
            local createKeyOption = doorContext:addOption("Create a Key", player, WLL.DoorLock.OnCreateKey, door)
            local rekeyOption = doorContext:addOption("Re-key Door", player, WLL.DoorLock.OnRekeyDoor, door)
            local missingItems = {}

            if not isLocksmith then
                table.insert(missingItems, "Locksmith trait")
            end
            if not hasScrapMetal then
                table.insert(missingItems, "Scrap Metal in main inventory")
            end

            buildTooltip(createKeyOption, missingItems)
            buildTooltip(rekeyOption, missingItems)
        end
    else
        local option = doorContext:addOption("Add Door Lock", player, WLL.DoorLock.OnAddLock, door)
        local missingItems = {}

        if not isLocksmith then
            table.insert(missingItems, "Locksmith trait")
        end
        if not doorLock then
            table.insert(missingItems, "Door Lock in main inventory")
        end
        if not hasScrewdriver then
            table.insert(missingItems, "Screwdriver in main inventory")
        end

        buildTooltip(option, missingItems)
    end

    if doorContext:isEmpty() then
        context:removeOptionByName("Door Lock")
    end
end

function WLL.DoorLock.OnPreFillWorldObjectContextMenu(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not test then
        for _, object in ipairs(worldobjects) do
            if WLL.DoorLock.IsObjectDoor(object) then
                WLL.DoorLock.DoorMenu(player, object, context)
                return
            end
        end
    end
end

---Populate inventory context options for setting loose door lock key ids.
---@param playerIndex integer
---@param context ISContextMenu
---@param items table
function WLL.DoorLock.OnPreFillInventoryObjectContextMenu(playerIndex, context, items)
    local player = getSpecificPlayer(playerIndex)
    local selectedItems = WLL.DoorLock._GetSelectedInventoryDoorLocks(items)
    if #selectedItems == 0 then
        return
    end

    local keyIds = WLL.DoorLock._GetAvailableInventoryKeyIds(player, selectedItems)
    if #keyIds == 0 then
        return
    end

    local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Set Key ID")
    local addedOptionCount = 0
    for _, keyId in ipairs(keyIds) do
        local shouldShowOption = false
        for _, item in ipairs(selectedItems) do
            if item:getModData().KeyId ~= keyId then
                shouldShowOption = true
                break
            end
        end

        if shouldShowOption then
            submenu:addOption("Match Key: " .. keyId, player, WLL.DoorLock.OnSetInventoryLockKeyId, selectedItems, keyId)
            addedOptionCount = addedOptionCount + 1
        end
    end

    if addedOptionCount == 0 then
        context:removeOptionByName("Set Key ID")
    end
end

Events.OnPreFillWorldObjectContextMenu.Remove(WLL.DoorLock.OnPreFillWorldObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Remove(WLL.DoorLock.OnPreFillInventoryObjectContextMenu)

Events.OnPreFillWorldObjectContextMenu.Add(WLL.DoorLock.OnPreFillWorldObjectContextMenu)
Events.OnPreFillInventoryObjectContextMenu.Add(WLL.DoorLock.OnPreFillInventoryObjectContextMenu)
