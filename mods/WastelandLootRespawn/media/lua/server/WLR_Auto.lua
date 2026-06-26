if isClient() then return end

require "WLR_NetworkConstants"

WLR_Auto = WLR_Auto or {}
WLR_Auto._modDataChunkCacheKey = "WLR_Auto:chunkCache"
WLR_Auto._modDataDebugKey = "WLR_Auto:debugOptions"

WLR_Auto.Config = {
    Enabled = true,
    Logs = false,
    Trace = false,
    AlwaysRespawn = false,
    SkipCooldown = false,
}

function WLR_Auto.Reset()
    ModData.remove(WLR_Auto._modDataChunkCacheKey)
    WLR_Auto.Init()
end

function WLR_Auto.DebugSet(options)
    for key, value in pairs(options) do
        WLR_Auto.Config[key] = value
    end
    ModData.add(WLR_Auto._modDataDebugKey, WLR_Auto.Config)
end

function WLR_Auto.InfoLog(message)
    writeLog("AutoLoot", "[INFO] " .. message)
end

function WLR_Auto.DebugLog(message)
    if WLR_Auto.Config.Logs then
        writeLog("AutoLoot", "[DEBUG] " .. message)
    end
end

function WLR_Auto.TraceLog(message)
    if WLR_Auto.Config.Trace then
        writeLog("AutoLoot", "[TRACE] " .. message)
    end
end

require "WLR_Auto/Range"
require "WLR_Auto/Definition"
require "WLR_Auto/Instance"
require "WLR_Auto/Runner"
require "WLR_Auto/Data"

local data = WLR_Auto.Data:new()
local runner = WLR_Auto.Runner:new()
local isTicking = false

function WLR_Auto.Init()
    data:loadDefinitions()
    data:loadChunkCache(ModData.getOrCreate(WLR_Auto._modDataChunkCacheKey));
end

function WLR_Auto.ForceAll()
    data:forceAll()
end

function WLR_Auto.OnTick()
    if runner:run() then
        Events.OnTick.Remove(WLR_Auto.OnTick)
        isTicking = false
    end
end

function WLR_Auto.OnChunkLoaded(x, y)
    local range = WLR_Auto.Range:new(x, y, x + 50, y + 50)
    local definition = data:getDefinitionsReadyInChunk(range)
    if not definition then return end
    local toRunRange = definition:getOverlap(range)
    runner:queue(definition, toRunRange)
    if not isTicking then
        Events.OnTick.Add(WLR_Auto.OnTick)
        isTicking = true
    end
    ModData.add(WLR_Auto._modDataChunkCacheKey, data.chunkCache)
    
    -- Chunk status broadcasting removed - must be requested manually
end

local recentlyLoaded = {}
local function LoadGridSquareHandler(square)
    local x1 = math.floor(square:getX() / 50) * 50
    local y1 = math.floor(square:getY() / 50) * 50
    local key = x1 .. "," .. y1
    if not recentlyLoaded[key] or WLR_Auto.Config.SkipCooldown then
        WLR_Auto.OnChunkLoaded(x1, y1)
        recentlyLoaded[key] = getTimestamp()
    end
end

local function EveryOneMinuteHandler()
    local ts = getTimestamp() - 120
    for key, timestamp in pairs(recentlyLoaded) do
        if timestamp < ts then
            recentlyLoaded[key] = nil
        end
    end
end

local function EveryHoursHandler()
    data:checkForNeededRespawn()
    -- Chunk status broadcasting removed - must be requested manually
end

local function EnableSystem()
    WLR_Auto.DebugLog("EnableSystem - Loot respawn system enabled")
    WLR_Auto.DebugSet({ Enabled = true })
    WLR_Auto.Init()
    Events.LoadGridsquare.Add(LoadGridSquareHandler)
    Events.EveryHours.Add(EveryHoursHandler)
    Events.EveryOneMinute.Add(EveryOneMinuteHandler)
end

local function DisableSystem()
    WLR_Auto.DebugLog("DisableSystem - Loot respawn system disabled")
    WLR_Auto.DebugSet({ Enabled = false })
    Events.LoadGridsquare.Remove(LoadGridSquareHandler)
    Events.EveryHours.Remove(EveryHoursHandler)
    Events.EveryOneMinute.Remove(EveryOneMinuteHandler)
end

local function OnInitGlobalModDataHandler()
    if ModData.exists(WLR_Auto._modDataDebugKey) then
        WLR_Auto.Config = ModData.get(WLR_Auto._modDataDebugKey)
    else
        WLR_Auto.InfoLog("Configuration not found, creating default settings")
        WLR_Auto.Debug = ModData.create(WLR_Auto._modDataDebugKey)
        WLR_Auto.DebugSet({
            Enabled = false,
            Logs = false,
            Trace = false,
            AlwaysRespawn = false,
            SkipCooldown = false,
        });
    end
    if WLR_Auto.Config.Enabled then
        EnableSystem()
    end
end

Events.OnInitGlobalModData.Add(OnInitGlobalModDataHandler)

Events.OnClientCommand.Add(function (module, command, player, args)
    if module ~= "WLR_Auto" then return end
    
    -- Existing commands
    if command == "reset" then
        WLR_Auto.Reset()
    end
    if command == "forceAll" then
        WLR_Auto.ForceAll()
    end
    if command == "set" then
        WLR_Auto.DebugSet(args)
    end
    if command == "getDebug" then
        sendServerCommand(player, "WLR_Auto", "debug", WLR_Auto.Config)
    end
    if command == "runChunk" then
        local x = math.floor(args.x / 50) * 50
        local y = math.floor(args.y / 50) * 50
        WLR_Auto.DebugLog("Admin command: Force run chunk at " .. x .. ", " .. y)
        recentlyLoaded[x .. "," .. y] = nil
        local square = getCell():getGridSquare(x, y, 0)
        LoadGridSquareHandler(square)
    end
    if command == "enable" then
        EnableSystem()
    end
    if command == "disable" then
        DisableSystem()
    end
    
    -- New client-server sync commands
    if command == "requestZoneDefinitions" then
        data:sendZoneDefinitionsToAdmin(player)
    end
    if command == "requestChunkStatus" then
        data:sendChunkStatusToAdmin(player)
    end
    if command == "reloadConfig" then
        data:reloadAndBroadcastConfig(player)
    end
    if command == "forceChunkRespawn" then
        if args and args.chunkKey then
            data:forceChunkRespawn(args.chunkKey, player)
        else
            sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.FORCE_RESPAWN, {
                success = false,
                error = "Missing chunkKey parameter"
            })
        end
    end
    
    -- Zone management commands
    if command == "createZone" then
        data:createZone(args, player)
    end
    if command == "updateZone" then
        data:updateZone(args, player)
    end
    if command == "deleteZone" then
        data:deleteZone(args, player)
    end
    if command == "respawnAllReady" then
        data:respawnAllReady(player)
    end
    if command == "respawnAllReadyInZone" then
        if args and args.zoneId then
            data:respawnAllReadyInZone(args.zoneId, player)
        else
            sendServerCommand(player, "WLR_Auto", WLR_NetworkConstants.Messages.ZONE_OPERATION, {
                success = false,
                operation = "respawnAllReadyInZone",
                error = "Missing zoneId parameter"
            })
        end
    end
end)
