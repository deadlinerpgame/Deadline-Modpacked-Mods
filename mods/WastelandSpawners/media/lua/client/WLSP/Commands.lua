local Commands = {}

--- Handle full sync from server (spawners + enabled states)
--- @param args table
function Commands.FullSync(args)
    if args and args.spawners and args.enabledStates then
        WLSP_Client:updateFullSync(args.spawners, args.enabledStates)
        if WLSP_SpawnerListWindow.instance then
            WLSP_SpawnerListWindow.instance:populateList()
        end
    end
end

--- Handle single spawner add/update from server
--- @param args table
function Commands.AddSpawner(args)
    if args and args.spawner then
        WLSP_Client:addSpawner(args.spawner)
        if WLSP_SpawnerListWindow.instance then
            WLSP_SpawnerListWindow.instance:populateList()
        end
    end
end

--- Handle spawner removal from server
--- @param args table
function Commands.RemoveSpawner(args)
    if args and args.spawnerId then
        WLSP_Client:removeSpawner(args.spawnerId)
        if WLSP_SpawnerListWindow.instance then
            WLSP_SpawnerListWindow.instance:populateList()
        end
    end
end

--- Handle spawner toggle from server
--- @param args table
function Commands.ToggleSpawner(args)
    if args and args.spawnerId and args.enabled ~= nil then
        WLSP_Client:updateSpawnerEnabled(args.spawnerId, args.enabled)
        if WLSP_SpawnerListWindow.instance then
            WLSP_SpawnerListWindow.instance:populateList()
        end
    end
end

--- Handle delete all spawners from server
--- @param args table
function Commands.DeleteAllSpawners(args)
    WLSP_Client:clearSpawners()
    print("[WLSP_Client] All spawners deleted")
    if WLSP_SpawnerListWindow.instance then
        WLSP_SpawnerListWindow.instance:populateList()
    end
end

--- Handle zombie mod application from server
--- @param args table
function Commands.ApplyZombieMods(args)
    if args and args.mods then
        WLSP_ZombieModSystem:applyReceivedMods(args.mods)
    end
end

--- Handle active pathing sync from server
--- @param args table
function Commands.SyncActivePathing(args)
    if args and args.zombies then
        WLSP_ZombieModSystem:applySyncedPathing(args.zombies)
    end
end

local function OnServerCommand(module, command, args)
    if module == "WLSP" then
        if Commands[command] then
            Commands[command](args)
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand)