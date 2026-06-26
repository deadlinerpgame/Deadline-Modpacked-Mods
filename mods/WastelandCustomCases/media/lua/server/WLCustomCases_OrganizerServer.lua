require "WLCustomCases_OrganizerShared"

WLCustomCases = WLCustomCases or {}
local Organizer = WLCustomCases.Organizer
local ORGANIZER_SYNC_DEBOUNCE_TICKS = 20
local organizerSyncQueue = {}

local function getContainerFromVehicle(args)
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
    return part:getItemContainer(), vehicle
end

local function getContainerFromObject(args)
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
            return object:getContainer(), object
        end
        return nil
    end
    if object.getContainerByIndex then
        return object:getContainerByIndex(args.containerIndex), object
    end
    return nil
end

local function resolveContainer(args)
    if not args then
        return nil
    end
    if args.containerType == "vehicle" then
        return getContainerFromVehicle(args)
    end
    if args.containerType == "object" then
        return getContainerFromObject(args)
    end
    return nil
end

local function scheduleOrganizerContainerSync(target)
    if not target or not target.container then
        return
    end
    if target.container:isEmpty() then
        return
    end
    target.ticks = ORGANIZER_SYNC_DEBOUNCE_TICKS
    organizerSyncQueue[target.key] = target
end

local function onOrganizerSyncTick()
    local completed = {}
    for key, entry in pairs(organizerSyncQueue) do
        entry.ticks = (entry.ticks or 0) - 1
        if entry.ticks <= 0 then
            if entry.container then
                sendServerCommand("WLCustomCases", "refreshOrganizerContainer", {
                    containerType = entry.containerType,
                    vehicleId = entry.vehicleId,
                    containerId = entry.containerId,
                    x = entry.x,
                    y = entry.y,
                    z = entry.z,
                    objectIndex = entry.objectIndex,
                    containerIndex = entry.containerIndex,
                })
            end
            completed[#completed + 1] = key
        end
    end
    for i = 1, #completed do
        organizerSyncQueue[completed[i]] = nil
    end
end

local function findItemById(container, itemId)
    if not container or not itemId then
        return nil
    end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:getID() == itemId then
            return item
        end
    end
    return nil
end

local function applyOrganizerTag(item, organizerId, clear)
    Organizer.ApplyOrganizerId(item, organizerId, clear)
end

function WLCustomCases.onClientCommand(module, command, player, args)
    if module ~= "WLCustomCases" or command ~= "UpdateOrganizerTag" then
        return
    end

    local container, isoObjectOrVehicle = resolveContainer(args)
    if not container then
        return
    end
    local item = findItemById(container, args.itemId)
    if not item then
        return
    end

    applyOrganizerTag(item, args.organizerId, args.clear)

    local syncKey = args.containerType .. ":" .. tostring(args.vehicleId or "") .. ":" .. tostring(args.x or "") .. ":" .. tostring(args.y or "") .. ":" .. tostring(args.z or "") .. ":" .. tostring(args.objectIndex or "") .. ":" .. tostring(args.containerIndex or "") .. ":" .. tostring(args.containerId or "")
    scheduleOrganizerContainerSync({
        key = syncKey,
        containerType = args.containerType,
        container = container,
        vehicle = args.containerType == "vehicle" and isoObjectOrVehicle or nil,
        object = args.containerType == "object" and isoObjectOrVehicle or nil,
        vehicleId = args.vehicleId,
        containerId = args.containerId,
        x = args.x,
        y = args.y,
        z = args.z,
        objectIndex = args.objectIndex,
        containerIndex = args.containerIndex,
    })
end

Events.OnClientCommand.Add(WLCustomCases.onClientCommand)
Events.OnTick.Add(onOrganizerSyncTick)
