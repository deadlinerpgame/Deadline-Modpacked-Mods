if not isServer() then return end

local Json = require "json"

--- @type WWP_WorkplaceZone[]
WWP_WorkplaceZones = WWP_WorkplaceZones or {}
local wereZonesLoaded = false


local function loadFromDisk()
    print("Loading WWP from disk")
    wereZonesLoaded = true
    local fileReaderObj = getFileReader("WastelandWorkplaces.json", true)
    local json = ""
    local line = fileReaderObj:readLine()
    while line ~= nil do
        json = json .. line
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()
    if json and json ~= "" then
        local decoded = Json.Decode(json)
        if decoded then
            WWP_WorkplaceZones = decoded
        end
    end
end

local function writeToDisk()
    local fileWriterObj = getFileWriter("WastelandWorkplaces.json", true, false)
    local json = Json.Encode(WWP_WorkplaceZones)
    fileWriterObj:write(json)
    fileWriterObj:close()
end

local function loadIfNeeded()
    if not wereZonesLoaded then
        loadFromDisk()
    end
end

local function sendZonesToClient(player)
    sendServerCommand(player, "WastelandWorkplaces", "SyncZones", WWP_WorkplaceZones)
end

local function sendZoneToAll(zoneId)
    sendServerCommand("WastelandWorkplaces", "SyncZone", WWP_WorkplaceZones[zoneId])
end

local function sendZonesToAll()
    sendServerCommand("WastelandWorkplaces", "SyncZones", WWP_WorkplaceZones)
end

WWP_Server = {}
function WWP_Server.IsWorkplace(x, y, z)
    loadIfNeeded()
    for _, zone in pairs(WWP_WorkplaceZones) do
        if x >= zone.minX and x <= zone.maxX+1 and y >= zone.minY and y <= zone.maxY+1 and z >= zone.minZ and z <= zone.maxZ+1 then
            return true
        end
    end
    return false
end

local Commands = {}

function Commands.SetZone(player, args)
    loadIfNeeded()
    local zoneId = args.id
    WWP_WorkplaceZones[zoneId] = args
    sendZoneToAll(zoneId)
    writeToDisk()
end

function Commands.DeleteZone(player, args)
    loadIfNeeded()
    local zoneId = args.id
    if not zoneId then return end
    WWP_WorkplaceZones[zoneId] = nil
    sendZonesToAll()
    writeToDisk()
end

function Commands.GetZones(player, args)
    loadIfNeeded()
    sendZonesToClient(player)
end

local function isNearZone(zone, x, y, z, range)
    if x >= zone.minX - range and x <= (zone.maxX+1) + range and y >= zone.minY - range and y <= (zone.maxY+1) + range and z >= (zone.minZ) - range and z <= (zone.maxZ) + range then
        return true
    end
    return false
end

local function sendNotification(args, type)
    loadIfNeeded()
    local online = getOnlinePlayers()
    for zoneId, playerItems in pairs(args) do
        local zoneObj = WWP_WorkplaceZones[zoneId]
        if zoneObj then
            for playerUsername, items in pairs(playerItems) do
                local playerUsername = playerUsername
                if getActivatedMods():contains("WastelandDisguises") then
                    local disguisedUsername = WL_Utils.getRolePlayChatName(playerUsername)
                    if disguisedUsername then
                        playerUsername = disguisedUsername
                    end
                end
                local sendStr = playerUsername .. " " .. type .. " items:"
                for itemId, count in pairs(items) do
                    local itemName = getItemNameFromFullType(itemId)
                    sendStr = sendStr .. " " .. count .. " " .. itemName .. ","
                end
                sendStr = sendStr:sub(1, -2)
                for empUsername, _ in pairs(zoneObj.employees) do
                    for i = 0, online:size() - 1 do
                        local playerObj = online:get(i)
                        if playerObj:getUsername() == empUsername then
                            sendServerCommand(playerObj, "WastelandWorkplaces", "Notify", {zoneId, sendStr})
                            break
                        end
                    end
                end
            end
        end
    end
end

function Commands.PutItems(player, args)
    sendNotification(args, "put")
end

function Commands.TakeItems(player, args)
    sendNotification(args, "took")
end

function Commands.log(player, args)
	writeLog("WastelandWorkplaces", args.logStatement)
end

local function processClientCommand(module, command, player, args)
    if module ~= "WastelandWorkplaces" then return end
    if not Commands[command] then return end
    Commands[command](player, args)
end
Events.OnClientCommand.Add(processClientCommand)

local function checkForZonesWithoutEmployees()
    loadIfNeeded()
    local online = getOnlinePlayers()
    for _, zone in pairs(WWP_WorkplaceZones) do
        if zone.open and zone.autoClose then
            local wasAnyOnline = false
            for i = 0, online:size() - 1 do
                local player = online:get(i)
                if zone.employees[player:getUsername()] ~= nil then
                    if isNearZone(zone, player:getX(), player:getY(), player:getZ(), 10) then
                        wasAnyOnline = true
                        break
                    end
                end
            end
            if not wasAnyOnline then
                zone.open = false
                sendZoneToAll(zone.id)
                writeToDisk()
            end
        end
    end
end

WL_RealTimeEvents.EveryXSeconds(120, checkForZonesWithoutEmployees)