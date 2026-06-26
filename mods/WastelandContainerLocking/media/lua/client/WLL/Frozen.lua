WLL = WLL or {}
WLL.Frozen = WLL.Frozen or {}

function WLL.Frozen.GetLockedTitle(container)
    return WLL.Frozen.GetFrozenTitle(container)
end

function WLL.Frozen.GetLockedDescription(container)
    return WLL.Frozen.GetFrozenDescription(container)
end

function WLL.Frozen.IsLocked(container)
    return false
end

function WLL.Frozen.CanView(player, container)
    return true
end

function WLL.Frozen.CanTake(player, container)
    return true
end

function WLL.Frozen.CanPut(player, container)
    return not WLL.Frozen.IsFrozen(container)
end


function WLL.Frozen.CanFreeze(player, container)
    if WLL.Frozen.IsFrozen(container) then
        return false
    end
    if not WL_Utils.isAtLeastGM(player) then
        return false
    end
    local isoObject = container:getParent()
    if not isoObject then
        return false
    end
    return true
end

function WLL.Frozen.CanUnfreeze(player, container)
    if not WLL.Frozen.IsFrozen(container) then
        return false
    end
    if not WL_Utils.isAtLeastGM(player) then
        return false
    end
    return true
end

function WLL.Frozen.FreezeContainer(player, container)
    if WLL.Frozen.IsFrozen(container) then
        WLL.ShowError(player, "This container is already frozen.")
        return false
    end
    if not WL_Utils.isAtLeastGM(player) then
        WLL.ShowError(player, "You can't freeze containers.")
        return false
    end
    local isoObject = container:getParent()
    if not isoObject then
        WLL.ShowError(player, "This container can't be frozen.")
        return false
    end
    isoObject:getModData().WLL_FrozenBy = player:getUsername()
    isoObject:transmitModData()
    WLL.ShowInfo(player, "Container frozen.")
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.Frozen.UnfreezeContainer(player, container)
    if not WLL.Frozen.IsFrozen(container) then
        WLL.ShowError(player, "This container is not frozen.")
        return false
    end
    if not WL_Utils.isAtLeastGM(player) then
        WLL.ShowError(player, "You can't unfreeze containers.")
        return false
    end
    local isoObject = container:getParent()
    if not isoObject then
        WLL.ShowError(player, "This container can't be unfrozen.")
        return false
    end
    isoObject:getModData().WLL_FrozenBy = nil
    isoObject:transmitModData()
    WLL.ShowInfo(player, "Container unfrozen.")
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.Frozen.IsFrozen(container)
    local isoObject = container:getParent()
    if not isoObject then
        return false
    end
    if isoObject:getModData().WLL_FrozenBy then
        return true
    end
end

function WLL.Frozen.GetFrozenTitle(container)
    if not WLL.Frozen.IsFrozen(container) then
        return nil
    end
    return "Frozen"
end

function WLL.Frozen.GetFrozenDescription(container)
    if not WLL.Frozen.IsFrozen(container) then
        return nil
    end
    local isoObject = container:getParent()
    if not isoObject then
        return nil
    end
    return "Frozen by " .. isoObject:getModData().WLL_FrozenBy
end

function WLL.Frozen.OnContainerContext(player, context, container)
    if WLL.Frozen.CanFreeze(player, container) then
        context:addOption("Freeze", player, WLL.Frozen.FreezeContainer, container)
    elseif WLL.Frozen.CanUnfreeze(player, container) then
        context:addOption("Unfreeze", player, WLL.Frozen.UnfreezeContainer, container)
    end
end