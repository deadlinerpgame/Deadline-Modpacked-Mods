WLL = WLL or {}
WLL.ComboLock = WLL.ComboLock or {}

function WLL.ComboLock._PlayerCombolock(player)
    return player:getInventory():FindAndReturn("WLLCombinationPadlock")
end

function WLL.ComboLock._ContainerComboData(container)
    local modData = WLL.BaseLock.GetContainerModData(container)
    if not modData then
        return nil
    end
    if not modData.WLL_ComboId then
        return nil
    end
    return {
        id = modData.WLL_ComboId,
        number = modData.WLL_ComboNumber,
    }
end

function WLL.ComboLock._SetContainerComboData(container, data)
    WLL.BaseLock.SetContainerModData(container, {
        WLL_ComboId = data.id,
        WLL_ComboNumber = data.number,
    })
end

function WLL.ComboLock._PlayerKnownComboFor(player, containerId)
    return player:getModData()["WLL_Combo" .. containerId]
end

function WLL.ComboLock._SetPlayerKnownComboFor(player, containerId, comboNumber)
    player:getModData()["WLL_Combo" .. containerId] = comboNumber
end

function WLL.ComboLock.CanLock(player, container)
    if WLL.IsAnyLocked(container) then
        return false
    end
    if not WLL.BaseLock.IsLockableContainer(container) then
        return false
    end
    if not WLL.IsFreeOfSafehouse(player) and not container:isInCharacterInventory(player) then
        return false
    end
    local comboLock = WLL.ComboLock._PlayerCombolock(player)
    if not comboLock then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.ComboLock.CanUnlock(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return false
    end
    if WL_Utils.isAtLeastGM(player) then
        return true
    end
    if not WLL.IsFreeOfSafehouse(player) and not container:isInCharacterInventory(player) then
        return false
    end
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        return false
    end
    local playerKnownCombo = WLL.ComboLock._PlayerKnownComboFor(player, comboData.id)
    if not playerKnownCombo then
        return false
    end
    if playerKnownCombo ~= comboData.number then
        return false
    end
    if not container:isInCharacterInventory(player) and not container:getParent() then
        return false
    end
    return true
end

function WLL.ComboLock.Lock(player, container)
    if not WLL.ComboLock.CanLock(player, container) then
        WLL.ShowError(player, "You can't lock this container.")
        return false
    end
    local comboLock = WLL.ComboLock._PlayerCombolock(player)
    local comboData = {
        id = ZombRand(1, 2000000000),
        number = ZombRand(0, 999),
    }
    if comboLock:getModData().WLL_ComboId then
        comboData.id = comboLock:getModData().WLL_ComboId
    end
    if comboLock:getModData().WLL_ComboNumber then
        comboData.number = comboLock:getModData().WLL_ComboNumber
    end
    WLL.ComboLock._SetPlayerKnownComboFor(player, comboData.id, comboData.number)
    WLL.BaseLock.SetContainerModData(container, {
        WLL_ComboId = comboData.id,
        WLL_ComboNumber = comboData.number,
    })
    player:getInventory():Remove(comboLock)
    WLL.ShowInfo(player, "The container is now locked with combination " .. comboData.number .. ".")
    local logEntry = string.format(
        "%s locked a container at %d,%d,%d with combo id %d and combo number %03d",
        player:getUsername(),
        player:getX(), player:getY(), player:getZ(),
        comboData.id, comboData.number
    )
    WL_Utils.writeLog("ContainerLocks", logEntry)
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.ComboLock.Unlock(player, container)
    if not WLL.ComboLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't unlock this container.")
        return false
    end
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        WLL.ShowError(player, "The lock looks broken.")
        return false
    end
    WLL.ComboLock.ClearLock(container)
    local comboLock = player:getInventory():AddItem("WLLCombinationPadlock")
    comboLock:getModData().WLL_ComboId = comboData.id
    comboLock:getModData().WLL_ComboNumber = comboData.number
    comboLock:setName("Combination Padlock [" .. comboData.number .. "]")
    WLL.ShowInfo(player, "The container is now unlocked.")
    local logEntry = string.format(
        "%s removed a lock from a container at %d,%d,%d with combo id %d and combo number %03d",
        player:getUsername(),
        player:getX(), player:getY(), player:getZ(),
        comboData.id, comboData.number
    )
    WL_Utils.writeLog("ContainerLocks", logEntry)
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.ComboLock.ClearLock(container)
    WLL.BaseLock.ClearContainerModData(container, {
        "WLL_ComboId",
        "WLL_ComboNumber",
    })
end

function WLL.ComboLock.IsLocked(container)
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData or not comboData.id then
        return false
    end
    return true
end

function WLL.ComboLock.CanView(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return true
    end
    if WLL.ComboLock.CanUnlock(player, container) then
        return true
    end
    if WLL.BaseLock.IsClearTile(container) then
        return true
    end
    return false
end

function WLL.ComboLock.CanTake(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return true
    end
    if WLL.ComboLock.CanUnlock(player, container) then
        return true
    end
    return false
end

function WLL.ComboLock.CanPut(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return true
    end
    if WLL.ComboLock.CanUnlock(player, container) then
        return true
    end
    return false
end

function WLL.ComboLock.GetLockedTitle(container)
    if WLL.ComboLock.IsLocked(container) then
        return "Combination Padlock"
    end

    return nil
end

function WLL.ComboLock.GetLockedDescription(container)
    if WLL.ComboLock.IsLocked(container) then
        local comboData = WLL.ComboLock._ContainerComboData(container)
        return "Combo Lock: " .. comboData.number .. "(id:" .. comboData.id .. ")"
    end
    return nil
end

function WLL.ComboLock.OnContainerContext(player, context, container)
    if not WLL.IsFreeOfSafehouse(player) then
        return
    end
    if WLL.ComboLock.CanLock(player, container) then
        context:addOption("Add Combo Lock", player, WLL.ComboLock.Lock, container)
    elseif WLL.ComboLock.CanUnlock(player, container) then
        local comboData = WLL.ComboLock._ContainerComboData(container)
        local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Combo Lock [" .. comboData.number .. "]")
        submenu:addOption("Change Code", player, WLL.ComboLock.ChangeCode, container)
        submenu:addOption("Remove Lock", player, WLL.ComboLock.Unlock, container)
    elseif WLL.ComboLock.IsLocked(container) then
        context:addOption("Combo Lock: Open", player, WLL.ComboLock.SetCombination, container)
    end

    if WLL.ComboLock.IsLocked(container) and WLL.BaseLock.PlayerCanPickLock(player) then
        context:addOption("Pick Lock", player, WLL.BaseLock.OnPickLock, WLL.ComboLock, container)
    end

    if getDebug() and WLL.ComboLock.IsLocked(container) then
        context:addOption("DEBUG: Forget Combination", player, WLL.ComboLock.ForgetCombination, container)
    end
end

function WLL.ComboLock.SetCombination(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return false
    end

    local modal = ISDigitalCode:new(0, 0, 230, 120, container, WLL.ComboLock.OnSetCombination, 0, nil, nil, false)
    modal:initialise()
    modal.number1:setText("0")
    modal.number2:setText("0")
    modal.number3:setText("0")
    modal:addToUIManager()
end

function WLL.ComboLock.OnSetCombination(container, btn, player)
    local modal = btn.parent
    local num1 = tonumber(modal.number1:getText())
    local num2 = tonumber(modal.number2:getText())
    local num3 = tonumber(modal.number3:getText())
    local newPin = (num1 * 100) + (num2 * 10) + num3
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        return
    end
    if comboData.number ~= newPin then
        WLL.ShowError(player, "The lock does not open.")
        return
    end
    WLL.ComboLock._SetPlayerKnownComboFor(player, comboData.id, comboData.number)
    WLL.ShowInfo(player, "The lock opens.")
    ISInventoryPage.OnContainerUpdate()
end

function WLL.ComboLock.ChangeCode(player, container)
    if not WLL.ComboLock.CanUnlock(player, container) then
        return false
    end
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        return false
    end
    -- get current digits of comboData.number, which is a 3-digit number
    local num1 = math.floor(comboData.number / 100)
    local num2 = math.floor((comboData.number - (num1 * 100)) / 10)
    local num3 = comboData.number - (num1 * 100) - (num2 * 10)

    local modal = ISDigitalCode:new(0, 0, 230, 120, container, WLL.ComboLock.OnChangeCode, 0, nil, nil, false)
    modal:initialise()
    modal.number1:setText(num1 .. "")
    modal.number2:setText(num2 .. "")
    modal.number3:setText(num3 .. "")
    modal:addToUIManager()
end


function WLL.ComboLock.OnChangeCode(container, btn, player)
    local modal = btn.parent
    local num1 = tonumber(modal.number1:getText())
    local num2 = tonumber(modal.number2:getText())
    local num3 = tonumber(modal.number3:getText())
    local newPin = (num1 * 100) + (num2 * 10) + num3
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        return false
    end
    comboData.number = newPin
    WLL.ComboLock._SetContainerComboData(container, comboData)
    WLL.ComboLock._SetPlayerKnownComboFor(player, comboData.id, comboData.number)
    WLL.ShowInfo(player, "The lock combination has been changed.")
    ISInventoryPage.OnContainerUpdate()
end

function WLL.ComboLock.ForgetCombination(player, container)
    if not WLL.ComboLock.IsLocked(container) then
        return false
    end
    local comboData = WLL.ComboLock._ContainerComboData(container)
    if not comboData then
        return false
    end
    WLL.ComboLock._SetPlayerKnownComboFor(player, comboData.id, nil)
    WLL.ShowInfo(player, "DEBUG: You have forgotten the combination.")
    ISInventoryPage.OnContainerUpdate()
end