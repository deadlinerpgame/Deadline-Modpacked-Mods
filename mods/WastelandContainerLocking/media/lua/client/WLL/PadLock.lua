WLL = WLL or {}
WLL.PadLock = WLL.PadLock or {}

function WLL.PadLock._PlayerPadlock(player)
    return player:getInventory():FindAndReturn("WLLPadlock");
end

function WLL.PadLock._GetKeyFor(player, keyId)
    return player:getInventory():haveThisKeyId(keyId)
end

function WLL.PadLock._ContainerKeyId(container)
    local modData = WLL.BaseLock.GetContainerModData(container)
    if not modData then
        return nil
    end
    return modData.WLL_PadLockKeyId
end

function WLL.PadLock.CanLock(player, container)
    if WLL.IsAnyLocked(container) then
        return false
    end
    if not WLL.BaseLock.IsLockableContainer(container) then
        return false
    end
    if not WLL.IsFreeOfSafehouse(player) and not container:isInCharacterInventory(player) then
        return false
    end
    local padlock = WLL.PadLock._PlayerPadlock(player)
    if not padlock then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.PadLock.CanUnlock(player, container)
    if not WLL.PadLock.IsLocked(container) then
        return false
    end
    if WL_Utils.isAtLeastGM(player) then
        return true
    end
    if not WLL.IsFreeOfSafehouse(player) and container:isInCharacterInventory(player) then
        return false
    end
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local playerKey = WLL.PadLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.PadLock.Lock(player, container)
    if not WLL.PadLock.CanLock(player, container) then
        WLL.ShowError(player, "You can't lock this container.")
        return false
    end
    local padlock = WLL.PadLock._PlayerPadlock(player)
    if not padlock then
        WLL.ShowError(player, "You don't have a padlock.")
        return false
    end
    local keyId = ZombRand(1, 2000000000)
    if padlock:getModData().WLL_PadLockKeyId then
        keyId = padlock:getModData().WLL_PadLockKeyId
    end
    WLL.BaseLock.SetContainerModData(container, {
        WLL_PadLockKeyId = keyId
    })
    player:getInventory():Remove(padlock)
    -- make a key
    local key = player:getInventory():AddItem("Base.KeyPadlock")
    key:setKeyId(keyId)
    key:setName("Padlock Key [" .. keyId .. "]")
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

function WLL.PadLock.Unlock(player, container)
    if not WLL.PadLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't unlock this container.")
        return false
    end
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local playerKey = WLL.PadLock._GetKeyFor(player, keyId)
    if playerKey then
        playerKey:getContainer():Remove(playerKey)
    end
    local padlock = player:getInventory():AddItem("WLLPadlock")
    padlock:setName("Padlock [" .. keyId .. "]")
    padlock:getModData().WLL_PadLockKeyId = keyId
    WLL.PadLock.ClearLock(container)
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

function WLL.PadLock.ClearLock(container)
    WLL.BaseLock.ClearContainerModData(container, {
        "WLL_PadLockKeyId",
    })
end

function WLL.PadLock.IsLocked(container)
    local modData = WLL.BaseLock.GetContainerModData(container)
    if not modData then
        return false
    end
    if not modData.WLL_PadLockKeyId then
        return false
    end
    return true
end

function WLL.PadLock.CanView(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not WLL.PadLock.IsLocked(container) then
        return true
    end
    if WLL.BaseLock.IsClearTile(container) then
        return true
    end
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local playerKey = WLL.PadLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    return true
end

function WLL.PadLock.CanTake(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not WLL.PadLock.IsLocked(container) then
        return true
    end
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local playerKey = WLL.PadLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    return true
end

function WLL.PadLock.CanPut(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not WLL.PadLock.IsLocked(container) then
        return true
    end
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local playerKey = WLL.PadLock._GetKeyFor(player, keyId)
    if not playerKey then
        return false
    end
    return true
end


function WLL.PadLock.GetLockedTitle(container)
    if WLL.PadLock.IsLocked(container) then
        return "Padlocked"
    end
    return nil
end

function WLL.PadLock.GetLockedDescription(container)
    if WLL.PadLock.IsLocked(container) then
        local keyId = WLL.PadLock._ContainerKeyId(container)
        return "Padlock: " .. keyId
    end
    return nil
end

function WLL.PadLock.OnContainerContext(player, context, container)
    if not WLL.IsFreeOfSafehouse(player) then
        return
    end
    if WLL.PadLock.CanLock(player, container) then
        context:addOption("Add Padlock", player, WLL.PadLock.Lock, container)
    elseif WLL.PadLock.CanUnlock(player, container) then
        local keyId = WLL.PadLock._ContainerKeyId(container)
        local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Padlock [" .. keyId .. "]")
        submenu:addOption("Remove", player, WLL.PadLock.Unlock, container)
        local scrapMetal = player:getInventory():FindAndReturn("Base.ScrapMetal")
        if scrapMetal then
            submenu:addOption("Make Copy of Key", player, WLL.PadLock.MakeKey, container)
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
                    rekeySubmenu:addOption("Key to: " .. key:getName(), player, WLL.PadLock.Rekey, container, keyId)
                end
            end
        end
    end

    if WLL.PadLock.IsLocked(container) and WLL.BaseLock.PlayerCanPickLock(player) then
        context:addOption("Pick Lock", player, WLL.BaseLock.OnPickLock, WLL.PadLock, container)
    end
end

function WLL.PadLock.Rekey(player, container, keyId)
    if not WLL.PadLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't rekey this padlock.")
        return false
    end
    local currentKeyId = WLL.PadLock._ContainerKeyId(container)
    local key = WLL.PadLock._GetKeyFor(player, currentKeyId)
    if not key then
        WLL.ShowError(player, "You don't have the key for this padlock.")
        return false
    end
    WLL.BaseLock.SetContainerModData(container, {
        WLL_PadLockKeyId = keyId
    })
    WLL.ShowInfo(player, "Padlock rekeyed to " .. keyId .. ".")
    ISInventoryPage.OnContainerUpdate()
end

function WLL.PadLock.MakeKey(player, container)
    if not WLL.PadLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't make a key for this padlock.")
        return false
    end
    local scrapMetal = player:getInventory():FindAndReturn("Base.ScrapMetal")
    local keyId = WLL.PadLock._ContainerKeyId(container)
    local newKey = player:getInventory():AddItem("Base.KeyPadlock")
    newKey:setKeyId(keyId)
    newKey:setName("Padlock Key [" .. keyId .. "]")
    scrapMetal:getContainer():Remove(scrapMetal)
    WLL.ShowInfo(player, "Key copy made.")
end