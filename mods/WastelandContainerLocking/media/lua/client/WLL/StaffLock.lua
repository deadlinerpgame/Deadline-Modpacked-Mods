WLL = WLL or {}
WLL.StaffLock = WLL.StaffLock or {}

function WLL.StaffLock.CanLock(player, container)
    if WLL.IsAnyLocked(container) then
        return false
    end

    if WL_Utils.isAtLeastGM(player) then
        return true
    end

    return false
end

function WLL.StaffLock.CanUnlock(player, container)
    if not WLL.StaffLock.IsLocked(container) then
        return false
    end

    if WL_Utils.isAtLeastGM(player) then
        return true
    end

    return false
end

--- @param player IsoPlayer
--- @param container ItemContainer
--- @return boolean true if the container was locked
function WLL.StaffLock.Lock(player, container)
    if not WLL.StaffLock.CanLock(player, container) then
        WLL.ShowError(player, "You can't lock this container.")
        return false
    end
    local isoObject = container:getParent()
    if not isoObject then
        WLL.ShowError(player, "You can't lock this container.")
        return false
    end
    isoObject:getModData().WLL_StaffLockedBy = player:getUsername()
    isoObject:transmitModData()
    WLL.ShowInfo(player, "Container locked.")
    ISInventoryPage.OnContainerUpdate()
    return true
end

--- @param player IsoPlayer
--- @param container ItemContainer
--- @return boolean true if the container was unlocked
function WLL.StaffLock.Unlock(player, container)
    if not WLL.StaffLock.CanUnlock(player, container) then
        WLL.ShowError(player, "You can't unlock this container.")
        return false
    end
    local isoObject = container:getParent()
    if not isoObject then
        WLL.ShowError(player, "You can't unlock this container.")
        return false
    end
    isoObject:getModData().WLL_StaffLockedBy = nil
    isoObject:transmitModData()
    WLL.ShowInfo(player, "Container unlocked.")
    ISInventoryPage.OnContainerUpdate()
    return true
end

function WLL.StaffLock.IsLocked(container)
    local isoObject = container:getParent()
    if not isoObject then
        return false
    end
    if isoObject:getModData().WLL_StaffLockedBy then
        return true
    end
    return false
end

function WLL.StaffLock.CanView(player, container)
    if WL_Utils.isStaff(player) then
        return true
    end
    return not WLL.StaffLock.IsLocked(container)
end

function WLL.StaffLock.CanTake(player, container)
    return WLL.StaffLock.CanView(player, container)
end

function WLL.StaffLock.CanPut(player, container)
    return WLL.StaffLock.CanView(player, container)
end

function WLL.StaffLock.GetLockedTitle(container)
    if WLL.StaffLock.IsLocked(container) then
        return "Staff Locked"
    end
    return nil
end

function WLL.StaffLock.GetLockedDescription(container)
    if WLL.StaffLock.IsLocked(container) then
        -- We can assume container:getParent() is not nil because otherwise it would not be locked
        return "Locked by " .. container:getParent():getModData().WLL_StaffLockedBy
    end
    return nil
end

function WLL.StaffLock.OnContainerContext(player, context, container)
    if WLL.StaffLock.CanLock(player, container) then
        context:addOption("Staff Lock", player, WLL.StaffLock.Lock, container)
    elseif WLL.StaffLock.CanUnlock(player, container) then
        context:addOption("Staff Unlock", player, WLL.StaffLock.Unlock, container)
    end
end