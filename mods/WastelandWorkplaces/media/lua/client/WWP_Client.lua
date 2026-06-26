if not isClient() then return end

require "WWP_WorkplaceZone"

WWP_Client = WWP_Client or {}

function WWP_Client.logWithLocation(player, stringToLog)
	if not stringToLog then error("stringToLog is missing") end
	local x = math.floor(player:getX())
	local y = math.floor(player:getY())
	local z = math.floor(player:getZ())
	local fullMessage = string.format("%s at %s,%s,%s", stringToLog, x, y, z)
	sendClientCommand(getPlayer(), "WastelandWorkplaces", "log", { logStatement = fullMessage })
end

local Commands = {}
local lastTry = 0
local didGetIntialZones = false

local function checkForInitialZones()
    if didGetIntialZones then
        Events.OnTick.Remove(checkForInitialZones);
        return
    end
    if getTimestampMs() - lastTry < 2000 then return end
    lastTry = getTimestampMs()
    sendClientCommand(getPlayer(), "WastelandWorkplaces", "GetZones", {})
end

local function processServerCommand(module, command, args)
    if module ~= "WastelandWorkplaces" then return end
    if not Commands[command] then return end
    Commands[command](args)
end

function Commands.SyncZone(args)
    local player = getPlayer()
    if WWP_WorkplaceZones[args.id] then
        local playerTown = WWP_Town.findTownAt(player:getX(), player:getY(), player:getZ())
        if playerTown and
           playerTown.zone:isInZone(WWP_WorkplaceZones[args.id].minX, WWP_WorkplaceZones[args.id].minY, WWP_WorkplaceZones[args.id].minZ) and
           WWP_WorkplaceZones[args.id].autoClose and
           WWP_WorkplaceZones[args.id].open ~= args.open
           then
            if args.open then
                getPlayer():setHaloNote("Now Open: " .. args.name, 124, 252, 0, 200.0)
            else
                getPlayer():setHaloNote("Now Closed: " .. args.name, 250, 20, 60, 200.0)
            end
        end
        for k,v in pairs(args) do
            if k == "typeKey" then
                WWP_WorkplaceZones[args.id].type = WWP_WorkplaceTypes[v]
            end
            WWP_WorkplaceZones[args.id][k] = v
        end
    else
        WWP_WorkplaceZones[args.id] = WWP_WorkplaceZone:loadFrom(args)
    end
end

function Commands.SyncZones(args)
    didGetIntialZones = true

    if args == nil then
        WWP_WorkplaceZones = {}
        return
    end

    local seenZoneIds = {}
    for _, zone in pairs(args) do
        seenZoneIds[zone.id] = true
        Commands.SyncZone(zone)
    end
    for id, _ in pairs(WWP_WorkplaceZones) do
        if not seenZoneIds[id] then
            WWP_WorkplaceZones[id].parentClass.delete(WWP_WorkplaceZones[id]) -- TODO: Improve this API
            WWP_WorkplaceZones[id] = nil
        end
    end
end

function Commands.Notify(args)
    if getPlayer():getModData()["WWP_DisableAlertFor_" .. args[1]] then return end
    local zone = WWP_WorkplaceZone.getZone(args[1])
    if not zone then return end
    if not zone:isPlayerInZone(getPlayer()) then return end

    WL_Utils.addToChat(args[2], {
        color = "0.8,0.8,0.8",
        chatId = WRC and WRC.OocTabId or 0,
    })
end

Events.OnServerCommand.Add(processServerCommand)
Events.OnInitWorld.Add(function()
    Events.OnTick.Add(checkForInitialZones)
end)