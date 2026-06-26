if not isClient() then return end

require "WCL/Loadouts"
WCL_Loadouts = WCL_Loadouts or {}
WCL_Loadouts.PlayerLoadouts = WCL_Loadouts.PlayerLoadouts or {}
WCL_Loadouts.Loadouts = WCL_Loadouts.Loadouts or {}

local Commands = {}
local lastTry = 0
local didGetInitialLoadouts = false

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

Events.OnServerCommand.Add(processServerCommand)
Events.OnInitWorld.Add(function()
    Events.OnTick.Add(checkForInitialLoadout)
end)