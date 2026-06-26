WLL = WLL or {}
WLL.SlotLock = WLL.SlotLock or {}

function WLL.SlotLock._PlayerSlotlock(player)
    return player:getInventory():FindAndReturn("WLLSlotlock");
end

function WLL.SlotLock._GetKeyFor(player, keyId)
    return player:getInventory():haveThisKeyId(keyId)
end

function WLL.SlotLock._ContainerKeyId(container)
    local modData = WLL.BaseLock.GetContainerModData(container)
    if not modData then
        return nil
    end
    return modData.WLL_SlotLockKeyId
end

function WLL.SlotLock.CanLock(player, container)
    if WLL.IsAnyLocked(container) then
        return false
    end
    if not WLL.BaseLock.IsLockableContainer(container) then
        return false
    end
    if not WLL.IsFreeOfSafehouse(player) and not container:isInCharacterInventory(player) then
        return false
    end
    local padlock = WLL.SlotLock._PlayerSlotlock(player)
    if not padlock then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.SlotLock.CanUnlock(player, container)
    if not WLL.SlotLock.IsLocked(container) then
        return false
    end
    if WL_Utils.isAtLeastGM(player) then
        return true
    end
    if not WLL.IsFreeOfSafehouse(player) and container:isInCharacterInventory(player) then
        return false
    end
    local keyId = WLL.SlotLock._ContainerKeyId(container)
    local playerKey = WLL.SlotLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.SlotLock.Lock(player, container)
    if not WLL.SlotLock.CanLock(player, container) then
        WLL.ShowError(player, "You can't lock this container.")
        return false
    end
    local padlock = WLL.SlotLock._PlayerSlotlock(player)
    if not padlock then
        WLL.ShowError(player, "You don't have a padlock.")
        return false
    end
    local keyId = ZombRand(1, 2000000000)
    if padlock:getModData().WLL_SlotLockKeyId then
        keyId = padlock:getModData().WLL_SlotLockKeyId
    end
    WLL.BaseLock.SetContainerModData(container, {
        WLL_SlotLockKeyId = keyId
    })
    player:getInventory():Remove(padlock)
    -- make a key
    local key = player:getInventory():AddItem("Base.KeyPadlock")
    key:setKeyId(keyId)
    key:setName("Slotlock Key [" .. keyId .. "]")
    local logEntry = string.format(
        "%s locked a container at %d,%d,%d with key id %d",
        player:getUsername(),
        player:getX(), player:getY(), player:getZ(),
        keyId
    )
    WL_Utils.writeLog("ContainerLocks", logEntry)
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.SlotLock.Unlock(player, container)
    if not WLL.SlotLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't unlock this container.")
        return false
    end
    local keyId = WLL.SlotLock._ContainerKeyId(container)
    local playerKey = WLL.SlotLock._GetKeyFor(player, keyId)
    if playerKey then
        playerKey:getContainer():Remove(playerKey)
    end
    local padlock = player:getInventory():AddItem("WLLSlotlock")
    padlock:setName("Slotlock [" .. keyId .. "]")
    padlock:getModData().WLL_SlotLockKeyId = keyId
    WLL.SlotLock.ClearLock(container)
    WLL.ShowInfo(player, "Padlock removed, key left in lock.")
    local logEntry = string.format(
        "%s removed a lock from a container at %d,%d,%d with key id %d",
        player:getUsername(),
        player:getX(), player:getY(), player:getZ(),
        keyId)
    WL_Utils.writeLog("ContainerLocks", logEntry)
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.SlotLock.ClearLock(container)
    WLL.BaseLock.ClearContainerModData(container, {
        "WLL_SlotLockKeyId",
    })
end

function WLL.SlotLock.IsLocked(container)
    local modData = WLL.BaseLock.GetContainerModData(container)
    if not modData then
        return false
    end
    if not modData.WLL_SlotLockKeyId then
        return false
    end
    return true
end

function WLL.SlotLock.CanView(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not WLL.SlotLock.IsLocked(container) then
        return true
    end
    if WLL.BaseLock.IsClearTile(container) then
        return true
    end
    local keyId = WLL.SlotLock._ContainerKeyId(container)
    local playerKey = WLL.SlotLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    return true
end

function WLL.SlotLock.CanTake(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not WLL.SlotLock.IsLocked(container) then
        return true
    end
    local keyId = WLL.SlotLock._ContainerKeyId(container)
    local playerKey = WLL.SlotLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    return true
end

function WLL.SlotLock.CanPut(player, container)
    return true
end


function WLL.SlotLock.GetLockedTitle(container)
    if WLL.SlotLock.IsLocked(container) then
        return "Slot locked"
    end
    return nil
end

function WLL.SlotLock.GetLockedDescription(container)
    if WLL.SlotLock.IsLocked(container) then
        local keyId = WLL.SlotLock._ContainerKeyId(container)
        return "Slotlock: " .. keyId
    end
    return nil
end

function WLL.SlotLock.OnContainerContext(player, context, container)
    if not WLL.IsFreeOfSafehouse(player) then
        return
    end
    if WLL.SlotLock.CanLock(player, container) then
        context:addOption("Add Slotlock", player, WLL.SlotLock.Lock, container)
    elseif WLL.SlotLock.CanUnlock(player, container) then
        local keyId = WLL.SlotLock._ContainerKeyId(container)
        local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Slotlock [" .. keyId .. "]")
        submenu:addOption("Remove", player, WLL.SlotLock.Unlock, container)
        local scrapMetal = player:getInventory():FindAndReturn("Base.ScrapMetal")
        if scrapMetal then
            submenu:addOption("Make Copy of Key", player, WLL.SlotLock.MakeKey, container)
        end
        local otherKeys = player:getInventory():getAllTypeEvalRecurse("KeyPadlock", function (item)
            return item:getKeyId() ~= keyId
        end)
        if otherKeys:size() > 0 then
            local rekeySubmenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "Rekey")
            local seenIds = {}
            for i=0,otherKeys:size()-1 do
                local key = otherKeys:get(i)
                local keyId = key:getKeyId()
                if not seenIds[keyId] then
                    seenIds[keyId] = true
                    rekeySubmenu:addOption("Key to: " .. key:getName(), player, WLL.SlotLock.Rekey, container, keyId)
                end
            end
        end
    end

    if WLL.SlotLock.IsLocked(container) and WLL.BaseLock.PlayerCanPickLock(player) then
        context:addOption("Pick Lock", player, WLL.BaseLock.OnPickLock, WLL.SlotLock, container)
    end
end

function WLL.SlotLock.Rekey(player, container, keyId)
    if not WLL.SlotLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't rekey this slotlock.")
        return false
    end
    local currentKeyId = WLL.SlotLock._ContainerKeyId(container)
    local key = WLL.SlotLock._GetKeyFor(player, currentKeyId)
    if not key then
        WLL.ShowError(player, "You don't have the key for this slotlock.")
        return false
    end
    WLL.BaseLock.SetContainerModData(container, {
        WLL_SlotLockKeyId = keyId
    })
    WLL.ShowInfo(player, "Slotlock rekeyed to " .. keyId .. ".")
    ISInventoryPage.OnContainerUpdate()
end

function WLL.SlotLock.MakeKey(player, container)
    if not WLL.SlotLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't make a key for this slotlock.")
        return false
    end
    local scrapMetal = player:getInventory():FindAndReturn("Base.ScrapMetal")
    local keyId = WLL.SlotLock._ContainerKeyId(container)
    local newKey = player:getInventory():AddItem("Base.KeyPadlock")
    newKey:setKeyId(keyId)
    newKey:setName("Slotlock Key [" .. keyId .. "]")
    scrapMetal:getContainer():Remove(scrapMetal)
    WLL.ShowInfo(player, "Key copy made.")
end