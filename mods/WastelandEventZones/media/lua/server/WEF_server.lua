if not isServer() then return end

local Json = require "json"

--- @type WEZ_EventZone[]
WEZ_EventZones = WEZ_EventZones or {}
local wereZonesLoaded = false

local lastWrite = 0
local needsWrite = false

local function loadFromDisk()
    print("Loading WEZ from disk")
    needsWrite = false
    lastWrite = getTimestamp()
    wereZonesLoaded = true

    local fileReaderObj = getFileReader("WastelandEventZones.json", true)
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
            WEZ_EventZones = decoded
        else
            WEZ_EventZones = {}
        end
    end
    WEZ_UpdateZombieTrackZones()
end

local function writeToDisk()
    local fileWriterObj = getFileWriter("WastelandEventZones.json", true, false)
    local json = Json.Encode(WEZ_EventZones)
    fileWriterObj:write(json)
    fileWriterObj:close()
end

local function optimizeDefaults()
    for zoneId, zone in pairs(WEZ_EventZones) do
        local newZone = WEZ_EventZoneDefaults.getUniqueValues(zone)
        WEZ_EventZones[zoneId] = newZone
    end
    writeToDisk()
end

function WEZ_LoadIfNeeded()
    if not wereZonesLoaded then
        loadFromDisk()
        optimizeDefaults()
    end
end

local function sendZonesToClient(player)
    sendServerCommand(player, "WastelandEventZones", "SyncZones", WEZ_EventZones)
end

local function sendZoneToAll(zoneId)
    sendServerCommand("WastelandEventZones", "SyncZone", WEZ_EventZones[zoneId])
end

local function sendZonesToAll()
    sendServerCommand("WastelandEventZones", "SyncZones", WEZ_EventZones)
end

local Commands = {}

function Commands.SetZone(player, args)
    WEZ_LoadIfNeeded()
    local zoneId = args.id
    WEZ_EventZones[zoneId] = args
    sendZoneToAll(zoneId)
    needsWrite = true
    WEZ_UpdateZombieTrackZones()
    if WEZ_ThumpZones[zoneId] then
        for _, chunk in pairs(WEZ_ThumpZones[zoneId]) do
            chunk.state = not args.noThump
        end
    end
end

function Commands.DeleteZone(player, args)
    WEZ_LoadIfNeeded()
    local zoneId = args.id
    if not zoneId then return end
    WEZ_EventZones[zoneId] = nil
    sendZonesToAll()
    needsWrite = true
    WEZ_UpdateZombieTrackZones()
end

function Commands.GetZones(player, args)
    WEZ_LoadIfNeeded()
    sendZonesToClient(player)
end

local function processClientCommand(module, command, player, args)
    if module ~= "WastelandEventZones" then return end
    if not Commands[command] then return end
    Commands[command](player, args)
end

local function checkWriteZones()
    if not needsWrite then return end
    if getTimestamp() - lastWrite < 30 then return end
    writeToDisk()
    lastWrite = getTimestamp()
    needsWrite = false
end

Events.OnClientCommand.Add(processClientCommand)
Events.EveryOneMinute.Add(checkWriteZones)