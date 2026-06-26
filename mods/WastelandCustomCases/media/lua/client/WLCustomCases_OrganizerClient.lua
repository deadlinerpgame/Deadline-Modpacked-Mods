require "WLCustomCases_OrganizerShared"

WLCustomCases = WLCustomCases or {}
WLCustomCases.Organizer = WLCustomCases.Organizer or {}

local Organizer = WLCustomCases.Organizer

Organizer.VIRTUAL_MODE_UNORGANIZED = "unorganized"
Organizer.VIRTUAL_MODE_ORGANIZER = "organizer"

local storageOrganizers = {
    ["WLCustomCases.StorageOrganizer_Black"] = true,
    ["WLCustomCases.StorageOrganizer_Blue"] = true,
    ["WLCustomCases.StorageOrganizer_Green"] = true,
    ["WLCustomCases.StorageOrganizer_Red"] = true,
}

local virtualContainerCache = {}
local virtualContainerData = setmetatable({}, { __mode = "k" })

function Organizer.IsStorageOrganizer(item)
    if not item then
        return false
    end
    return storageOrganizers[item:getFullType()] == true
end

function Organizer.GetVirtualContainerData(container)
    return virtualContainerData[container]
end

function Organizer.ResolveVirtualParent(container)
    local virtualData = Organizer.GetVirtualContainerData(container)
    if virtualData and virtualData.parent then
        return virtualData.parent, virtualData
    end
    return container, nil
end

function Organizer.ResolveContainer(container)
    return Organizer.ResolveVirtualParent(container)
end

function Organizer.GetOrCreateVirtualContainer(playerNum, parentContainer, mode, organizerId)
    if not virtualContainerCache[playerNum] then
        virtualContainerCache[playerNum] = setmetatable({}, { __mode = "k" })
    end

    local playerCache = virtualContainerCache[playerNum]
    local parentCache = playerCache[parentContainer]
    if not parentCache then
        parentCache = { unorganized = nil, organizers = {} }
        playerCache[parentContainer] = parentCache
    end

    local container = nil
    if mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
        container = parentCache.unorganized
        if not container then
            container = ItemContainer.new("WLCC_VirtualContainer", nil, nil)
            container:setExplored(true)
            parentCache.unorganized = container
        end
    else
        container = parentCache.organizers[organizerId]
        if not container then
            container = ItemContainer.new("WLCC_VirtualContainer", nil, nil)
            container:setExplored(true)
            parentCache.organizers[organizerId] = container
        end
    end

    virtualContainerData[container] = {
        parent = parentContainer,
        mode = mode,
        organizerId = organizerId,
    }

    return container
end

function Organizer.GetOrganizersInContainer(container)
    local organizers = {}
    if not container then
        return organizers
    end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if Organizer.IsStorageOrganizer(item) then
            local id = Organizer.EnsureOrganizerId(item)
            if id then
                table.insert(organizers, { item = item, id = id })
            end
        end
    end

    return organizers
end

function Organizer.BuildOrganizerIdMap(container)
    local map = {}
    local organizers = Organizer.GetOrganizersInContainer(container)
    for _, organizer in ipairs(organizers) do
        map[organizer.id] = true
    end
    return map
end

local function GetContainerCommandArgs(container, item, organizerId, clear)
    if not container or not item then
        return nil
    end

    local parent = container:getParent()
    if parent and instanceof(parent, "BaseVehicle") then
        return {
            containerType = "vehicle",
            vehicleId = parent:getId(),
            containerId = container:getType(),
            itemId = item:getID(),
            organizerId = organizerId,
            clear = clear,
        }
    end

    if parent and parent.getSquare then
        local square = parent:getSquare()
        if not square then
            return nil
        end

        local containerIndex = -1
        if parent.getContainerCount then
            for i = 0, parent:getContainerCount() - 1 do
                if parent:getContainerByIndex(i) == container then
                    containerIndex = i
                    break
                end
            end
        end

        return {
            containerType = "object",
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            objectIndex = parent:getObjectIndex(),
            containerIndex = containerIndex,
            itemId = item:getID(),
            organizerId = organizerId,
            clear = clear,
        }
    end

    return nil
end

function Organizer.SendOrganizerUpdateToServer(playerObj, item, container, organizerId, clear)
    if not isClient() then
        return
    end
    local args = GetContainerCommandArgs(container, item, organizerId, clear)
    if not args then
        return
    end
    sendClientCommand(playerObj, "WLCustomCases", "UpdateOrganizerTag", args)
end

function Organizer.ResolveContainerFromServerArgs(args)
    if not args then
        return nil
    end

    if args.containerType == "vehicle" then
        if not args.vehicleId or not args.containerId then
            return nil
        end
        local vehicle = getVehicleById(args.vehicleId)
        if not vehicle then
            return nil
        end
        local part = vehicle:getPartById(args.containerId)
        if not part then
            return nil
        end
        return part:getItemContainer()
    end

    if args.containerType == "object" then
        if args.x == nil or args.y == nil or args.z == nil then
            return nil
        end
        local square = getCell():getGridSquare(args.x, args.y, args.z)
        if not square then
            return nil
        end
        local object = square:getObjects():get(args.objectIndex)
        if not object then
            return nil
        end
        if args.containerIndex == nil or args.containerIndex < 0 then
            if object.getContainer then
                return object:getContainer()
            end
            return nil
        end
        if object.getContainerByIndex then
            return object:getContainerByIndex(args.containerIndex)
        end
    end

    return nil
end

function Organizer.GetOrganizerChange(srcVirtual, destVirtual)
    local organizerId = nil
    local clear = false
    if destVirtual then
        if destVirtual.mode == Organizer.VIRTUAL_MODE_ORGANIZER then
            organizerId = destVirtual.organizerId
        elseif destVirtual.mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
            clear = true
        end
    elseif srcVirtual and srcVirtual.mode == Organizer.VIRTUAL_MODE_ORGANIZER then
        clear = true
    end
    return organizerId, clear
end

function Organizer.ShouldApplyOrganizerChange(item, organizerId, clear)
    if not item then
        return false
    end
    local currentId = Organizer.GetOrganizerId(item)
    if organizerId then
        return currentId ~= organizerId
    end
    if clear then
        return currentId ~= nil
    end
    return false
end

function Organizer.ApplyOrganizerChange(character, item, container, organizerId, clear, shouldSync)
    if not item then
        return
    end

    if organizerId then
        Organizer.ApplyOrganizerId(item, organizerId, false)
    elseif clear then
        Organizer.ApplyOrganizerId(item, nil, true)
    else
        return
    end

    if shouldSync then
        Organizer.SendOrganizerUpdateToServer(character, item, container, organizerId, clear)
    end
end
