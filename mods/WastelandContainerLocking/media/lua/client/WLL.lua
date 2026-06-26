WLL = WLL or {}

require "WLL/BaseLock"
require "WLL/ComboLock"
require "WLL/DoorLock"
require "WLL/PadLock"
require "WLL/StaffLock"
require "WLL/SlotLock"
require "WLL/Frozen"

WLL.Systems = {
    WLL.ComboLock,
    WLL.PadLock,
    WLL.StaffLock,
    WLL.SlotLock,
    WLL.Frozen,
}

local function isLockedMannequinsZone(x, y, z)
    local rules = WastelandZones and WastelandZones.Classes and WastelandZones.Classes.InteractionRules
    if rules and rules.getIsLockedMannequinsZone and rules.getIsLockedMannequinsZone(x, y, z) then
        return true
    end

    if WEZ_EventZone and WEZ_EventZone.getIsLockedMannequinsZone and WEZ_EventZone.getIsLockedMannequinsZone(x, y, z) then
        return true
    end

    return false
end

local lastError = nil
local lastErrorTime = 0
function WLL.ShowError(player, message)
    if lastError == message and lastErrorTime + 2 > getTimestamp() then
        return
    end
    WL_Utils.addErrorToChat(message, {chatId = WRC and WRC.OocStreamId or nil})
    player:addLineChatElement(message,1.0, 0.2, 0.2)
    lastError = message
    lastErrorTime = getTimestamp()
end

function WLL.ShowInfo(player, message)
    WL_Utils.addInfoToChat(message, {chatId = WRC and WRC.OocStreamId or nil})
    player:addLineChatElement(message,0.8, 0.8, 1.0)
end

function WLL.IsAnyLocked(container)
    for _, system in ipairs(WLL.Systems) do
        if system.IsLocked(container) then
            return true
        end
    end
    return false
end

function WLL.CanViewContainer(player, container)
    for _, system in ipairs(WLL.Systems) do
        if not system.CanView(player, container) then
            return false
        end
    end

    if WWP_WorkplaceZone then
        if WWP_WorkplaceZone.isContainerLockedFor(player, container) and not WLL.BaseLock.IsClearTile(container) then
            return false
        end
    end

    if instanceof(container:getParent(), "IsoMannequin") then
        local x, y, z = container:getSourceGrid():getX(), container:getSourceGrid():getY(), container:getSourceGrid():getZ()
        if isLockedMannequinsZone(x, y, z) and not WL_Utils.isStaff(player) then
            return false
        end
    end

    if AVCS then
        local vehiclePart = container:getVehiclePart()
        if vehiclePart then
            local checkResult = AVCS.getPublicPermission(vehiclePart:getVehicle(), "AllowContainersAccess")
            if not checkResult then
                checkResult = AVCS.checkPermission(player, vehiclePart:getVehicle())
                checkResult = AVCS.getSimpleBooleanPermission(checkResult)
            end

            if not checkResult then
                return false
            end
        end
    end

    return true
end

function WLL.CanTakeFromContainer(player, container)
    for _, system in ipairs(WLL.Systems) do
        if not system.CanTake(player, container) then
            return false
        end
    end

    if WWP_WorkplaceZone then
        if WWP_WorkplaceZone.isContainerLockedFor(player, container) then
            return false
        end
    end

    if instanceof(container:getParent(), "IsoMannequin") then
        local x, y, z = container:getSourceGrid():getX(), container:getSourceGrid():getY(), container:getSourceGrid():getZ()
        if isLockedMannequinsZone(x, y, z) and not WL_Utils.isStaff(player) then
            return false
        end
    end

    return true
end

function WLL.CanPutIntoContainer(player, container)
    for _, system in ipairs(WLL.Systems) do
        if not system.CanPut(player, container) then
            return false
        end
    end

    if WWP_WorkplaceZone then
        if WWP_WorkplaceZone.isContainerLockedFor(player, container) then
            return false
        end
    end

    if instanceof(container:getParent(), "IsoMannequin") then
        local x, y, z = container:getSourceGrid():getX(), container:getSourceGrid():getY(), container:getSourceGrid():getZ()
        if isLockedMannequinsZone(x, y, z) and not WL_Utils.isStaff(player) then
            return false
        end
    end

    return true
end

function WLL.GetContainerTitle(container)
    local titles = {}
    for _, system in ipairs(WLL.Systems) do
        local title = system.GetLockedTitle(container)
        if title then
            table.insert(titles, title)
        end
    end
    if #titles == 0 then
        return nil
    end
    return table.concat(titles, ", ")
end

function WLL.GetContainerDescriptions(container)
    local descriptions = {}
    for _, system in ipairs(WLL.Systems) do
        local desc = system.GetLockedDescription(container)
        if desc then
            table.insert(descriptions, desc)
        end
    end
    return descriptions
end

function WLL.IsFreeOfSafehouse(player)
    -- check for safezone permissions
    if WSZ_Client then
        if not WSZ_Client.currentPermissions.canInteractItems then
            return false
        end
    end

    -- get all safehouse at players location
    local sh = SafeHouse.getSafeHouse(player:getCurrentSquare())
    if not sh then return true end

    -- check if player is a member
    return sh:getPlayers():contains(player:getUsername())
end
