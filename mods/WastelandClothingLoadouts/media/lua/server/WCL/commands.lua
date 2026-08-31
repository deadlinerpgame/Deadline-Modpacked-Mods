if isClient() then return end

local Json = require "wcl_json"

-- Constants
local DIR = "WCL_loadouts"
-- Build 42.20 restricts getFileReader/getFileWriter to ini/cfg/txt/log.
-- The files still contain JSON; only their extension has changed.
local PUBLIC_FILE = DIR .. "/_public.txt"
local OLD_FILE = "WCL_loadouts.txt"

local function getUserFile(username)
    return DIR .. "/" .. tostring(username) .. ".txt"
end

-- State
local loadouts = nil
local loadoutsByPlayer = {}

-- IO Helpers
local function readWholeFile(path)
    local reader = getFileReader(path, false)
    if not reader then
        return nil
    end
    local content = ""
    local line = reader:readLine()
    while line ~= nil do
        content = content .. line
        line = reader:readLine()
    end
    reader:close()
    if content == "" then
        return nil
    end
    return content
end

local function readJsonFile(path)
    local s = readWholeFile(path)
    if not s or s == "" then
        return {}
    end
    local decoded = Json.Decode(s)
    if decoded then
        return decoded
    else
        return {}
    end
end

local function writeJsonFile(path, tbl)
    local w = getFileWriter(path, true, false)
    w:write(Json.Encode(tbl or {}))
    w:close()
end

-- Migration
local function migrateOldFileIfPresent()
    local s = readWholeFile(OLD_FILE)
    if not s or s == "" then
        return
    end
    local decoded = Json.Decode(s)
    if not decoded then
        return
    end
    local globalTbl = decoded.global or {}
    local playersTbl = decoded.players or {}
    
    writeJsonFile(PUBLIC_FILE, globalTbl)
    for username, userTbl in pairs(playersTbl) do
        writeJsonFile(getUserFile(username), userTbl or {})
    end
    
    loadouts = globalTbl
    loadoutsByPlayer = {}

    local f = getFileWriter(OLD_FILE, true, false)
    f:write("")
    f:close()
    print("[WCL] Migrated old loadouts file to new format")
end

-- Loading
local function loadPublicFromDisk()
    loadouts = readJsonFile(PUBLIC_FILE) or {}
    loadoutsByPlayer = {}
end

local function loadUserFromDisk(username)
    if loadoutsByPlayer[username] then
        return
    end
    loadoutsByPlayer[username] = readJsonFile(getUserFile(username)) or {}
end

-- Writing
local function writePublicToDisk()
    writeJsonFile(PUBLIC_FILE, loadouts)
end

local function writeUserToDisk(username)
    writeJsonFile(getUserFile(username), loadoutsByPlayer[username] or {})
end

-- Sending
local function sendPlayerLoadoutsToClient(player)
    local name = player:getUsername()
    loadUserFromDisk(name)
    local playerLoadouts = loadoutsByPlayer[name] or {}
    sendServerCommand(player, "WastelandClothingLoadouts", "SyncPlayerLoadouts", playerLoadouts)
end

local function sendLoadoutsToClient(player)
    loadPublicFromDisk()
    sendServerCommand(player, "WastelandClothingLoadouts", "SyncLoadouts", loadouts)
end

local function sendLoadoutToAll(loadoutName)
    sendServerCommand("WastelandClothingLoadouts", "SyncLoadout", {name = loadoutName, loadout = loadouts[loadoutName]})
end

local function sendLoadoutsToAll()
    sendServerCommand("WastelandClothingLoadouts", "SyncLoadouts", loadouts)
end

local function sendGendersToAll()
    local genders = {}
    local onlinePlayers = getOnlinePlayers()
    for i = 0, onlinePlayers:size() - 1 do
        local onlinePlayer = onlinePlayers:get(i)
        genders[onlinePlayer:getUsername()] = {
            onlineID = onlinePlayer:getOnlineID(),
            isFemale = onlinePlayer:isFemale()
        }
    end
    sendServerCommand("WastelandClothingLoadouts", "SyncGenders", genders)
end

-- Command Handlers
local Commands = {}

function Commands.SaveLoadout(player, args)
    loadPublicFromDisk()
    local loadoutName = args.name
    if not loadoutName then return end
    loadouts[loadoutName] = args.loadout
    print("[WCL] " .. player:getUsername() .. " saved public loadout: " .. loadoutName)
    sendLoadoutToAll(loadoutName)
    writePublicToDisk()
end

function Commands.SavePlayerLoadout(player, args)
    local loadoutName = args.name
    if not loadoutName then return end
    local playerName = player:getUsername()
    loadUserFromDisk(playerName)
    loadoutsByPlayer[playerName] = loadoutsByPlayer[playerName] or {}
    loadoutsByPlayer[playerName][loadoutName] = args.loadout
    print("[WCL] " .. playerName .. " saved player loadout: " .. loadoutName)
    sendPlayerLoadoutsToClient(player)
    writeUserToDisk(playerName)
end

function Commands.DeleteLoadout(player, args)
    loadPublicFromDisk()
    local loadoutName = args.name
    if not loadoutName then return end
    loadouts[loadoutName] = nil
    print("[WCL] " .. player:getUsername() .. " deleted public loadout: " .. loadoutName)
    sendLoadoutsToAll()
    writePublicToDisk()
end

function Commands.DeletePlayerLoadout(player, args)
    local loadoutName = args.name
    if not loadoutName then return end
    local playerName = player:getUsername()
    loadUserFromDisk(playerName)
    loadoutsByPlayer[playerName] = loadoutsByPlayer[playerName] or {}
    loadoutsByPlayer[playerName][loadoutName] = nil
    print("[WCL] " .. playerName .. " deleted player loadout: " .. loadoutName)
    sendPlayerLoadoutsToClient(player)
    writeUserToDisk(playerName)
end

function Commands.GetLoadouts(player, args)
    sendLoadoutsToClient(player)
    sendPlayerLoadoutsToClient(player)
    sendGendersToAll()
end

function Commands.ChangeGender(player, args)
    if not args or type(args.isFemale) ~= "boolean" then
        return
    end

    player:setFemale(args.isFemale)
    player:getDescriptor():setFemale(args.isFemale)
    player:resetModel()
    syncVisuals(player)
    sendServerCommand("WastelandClothingLoadouts", "SyncGender", {
        onlineID = player:getOnlineID(),
        username = player:getUsername(),
        isFemale = args.isFemale
    })
    print("[WCL] " .. player:getUsername() .. " changed gender to " .. (args.isFemale and "Female" or "Male"))
end

local function processClientCommand(module, command, player, args)
    if module ~= "WastelandClothingLoadouts" then return end
    if not Commands[command] then return end
    Commands[command](player, args)
end

Events.OnClientCommand.Add(processClientCommand)
Events.OnGameBoot.Add(function()
    migrateOldFileIfPresent()
end)
