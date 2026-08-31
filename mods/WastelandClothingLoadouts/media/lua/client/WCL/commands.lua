if not isClient() then return end

require "WCL/Loadouts"
WCL_Loadouts = WCL_Loadouts or {}
WCL_Loadouts.PlayerLoadouts = WCL_Loadouts.PlayerLoadouts or {}
WCL_Loadouts.Loadouts = WCL_Loadouts.Loadouts or {}

local Commands = {}
local lastTry = 0
local didGetInitialLoadouts = false
local gendersByUsername = {}

local function applyGender(player, isFemale)
    if not player or player:isFemale() == isFemale then return end
    player:setFemale(isFemale)
    player:getDescriptor():setFemale(isFemale)
    player:resetModelNextFrame()
end

local function applyKnownGender(player)
    if player == getPlayer() then return end
    local isFemale = gendersByUsername[player:getUsername()]
    if type(isFemale) == "boolean" then
        applyGender(player, isFemale)
    end
end

local function checkForInitialLoadout()
    if didGetInitialLoadouts then
        Events.OnTick.Remove(checkForInitialLoadout)
        return
    end
    if getTimestampMs() - lastTry < 2000 then return end
    lastTry = getTimestampMs()
    sendClientCommand(getPlayer(), "WastelandClothingLoadouts", "GetLoadouts", {})
end

local function processServerCommand(module, command, args)
    if module ~= "WastelandClothingLoadouts" then return end
    if not Commands[command] then return end
    Commands[command](args)
end

function Commands.SyncLoadout(args)
    WCL_Loadouts.Loadouts[args.name] = args.loadout
end

function Commands.SyncLoadouts(args)
    didGetInitialLoadouts = true

    if args == nil then
        WCL_Loadouts.Loadouts = {}
        return
    end
    WCL_Loadouts.Loadouts = args
end

function Commands.SyncPlayerLoadouts(args)
    if args == nil then
        WCL_Loadouts.PlayerLoadouts = {}
        return
    end
    WCL_Loadouts.PlayerLoadouts = args
end

function Commands.SyncGender(args)
    if not args or type(args.username) ~= "string" or type(args.isFemale) ~= "boolean" then
        return
    end

    gendersByUsername[args.username] = args.isFemale
    if type(args.onlineID) == "number" then
        applyGender(getPlayerByOnlineID(args.onlineID), args.isFemale)
    end
end

function Commands.SyncGenders(args)
    gendersByUsername = {}
    if not args then return end

    for username, genderData in pairs(args) do
        if type(username) == "string" and type(genderData) == "table"
            and type(genderData.isFemale) == "boolean" then
            gendersByUsername[username] = genderData.isFemale
            if type(genderData.onlineID) == "number" then
                applyGender(getPlayerByOnlineID(genderData.onlineID), genderData.isFemale)
            end
        end
    end
end

Events.OnServerCommand.Add(processServerCommand)
Events.OnPlayerUpdate.Add(applyKnownGender)
Events.OnInitWorld.Add(function()
    Events.OnTick.Add(checkForInitialLoadout)
end)
