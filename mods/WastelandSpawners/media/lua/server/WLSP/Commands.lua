if isClient() then return end -- Server or Single player only

local function isStaff(player)
    if not isServer() then return true end -- Single player
    if not player then return false end -- Guard
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

local Commands = {}

function Commands.RequestFullSync(player, args)
    if not isStaff(player) then
        print("[WLSP_Server] RequestFullSync: Access denied")
        return
    end
    
    local spawners = WLSP_SpawnerSystem.spawners or {}
    local enabledStates = WLSP_SpawnerSystem.enabledStates or {}
    sendServerCommand(player, "WLSP", "FullSync", {
        spawners = spawners,
        enabledStates = enabledStates
    })
end

function Commands.AddSpawner(player, args)
    if not isStaff(player) then
        print("[WLSP_Server] AddSpawner: Access denied")
        return
    end
    
    local spawner = args.spawner
    if spawner and spawner.id then
        WLSP_SpawnerSystem:addSpawner(spawner)
    end
end

function Commands.RemoveSpawner(player, args)
    if not isStaff(player) then
        print("[WLSP_Server] RemoveSpawner: Access denied")
        return
    end
    
    local spawnerId = args.spawnerId
    if spawnerId then
        WLSP_SpawnerSystem:removeSpawner(spawnerId)
    end
end

function Commands.ToggleSpawner(player, args)
    if not isStaff(player) then
        return
    end
    
    local spawnerId = args.spawnerId
    if spawnerId then
        WLSP_SpawnerSystem:toggleSpawner(spawnerId)
    end
end

function Commands.ToggleSpawnerGroup(player, args)
    if not isStaff(player) then
        return
    end
    
    local groupName = args.groupName
    if groupName then
        WLSP_SpawnerSystem:toggleSpawnerGroup(groupName)
    end
end

function Commands.SetLogLevel(player, args)
    if not isStaff(player) then
        print("[WLSP_Server] SetLogLevel: Access denied")
        return
    end
    
    local logLevel = args.logLevel
    if logLevel and (logLevel == 0 or logLevel == 1 or logLevel == 2) then
        WLSP_SpawnerSystem.logLevel = logLevel
        print("[WLSP_Server] Log level set to " .. logLevel .. " by " .. player:getUsername())
    end
end

function Commands.DeleteAllSpawners(player, args)
    -- Check if player is admin (not just staff)
    if not player:getAccessLevel() or player:getAccessLevel() ~= "Admin" then
        print("[WLSP_Server] DeleteAllSpawners: Access denied - Admin required")
        return
    end
    
    local count = WLSP_SpawnerSystem:deleteAllSpawners()
    print("[WLSP_Server] " .. player:getUsername() .. " deleted all spawners (count: " .. count .. ")")
end

local function OnClientCommand(module, command, player, args)
    if module == "WLSP" then
        print("[WLSP_Server] Received command: " .. command)
        if Commands[command] then
            Commands[command](player, args)
        end
    end
end

Events.OnClientCommand.Add(OnClientCommand)