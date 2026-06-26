if isClient() then return end -- Server only

local Commands = {}

--- Check if a player is staff
--- @param player IsoPlayer
--- @return boolean
local function isStaff(player)
    if not isServer() then return true end -- SP
    if not player then return false end
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

--- Handle add/update attractor request from client
--- @param player IsoPlayer
--- @param args table
function Commands.AddAttractor(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to add attractor")
        return
    end
    
    if args and args.attractor then
        WLZA_AttractorSystem:addAttractor(args.attractor)
    end
end

--- Handle remove attractor request from client
--- @param player IsoPlayer
--- @param args table
function Commands.RemoveAttractor(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to remove attractor")
        return
    end
    
    if args and args.attractorId then
        WLZA_AttractorSystem:removeAttractor(args.attractorId)
    end
end

--- Handle toggle attractor request from client
--- @param player IsoPlayer
--- @param args table
function Commands.ToggleAttractor(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to toggle attractor")
        return
    end
    
    if args and args.attractorId then
        WLZA_AttractorSystem:toggleAttractor(args.attractorId)
    end
end

--- Handle request for full sync from client
--- @param player IsoPlayer
--- @param args table
function Commands.RequestFullSync(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to request full sync")
        return
    end
    
    -- Send full attractor list and enabled states to requesting player
    sendServerCommand(player, "WLZA", "FullSync", {
        attractors = WLZA_AttractorSystem.attractors,
        enabledStates = WLZA_AttractorSystem.enabledStates
    })
end

--- Handle delete all attractors request from client
--- @param player IsoPlayer
--- @param args table
function Commands.DeleteAllAttractors(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to delete all attractors")
        return
    end
    
    WLZA_AttractorSystem:deleteAllAttractors()
end

--- Handle set log level request from client
--- @param player IsoPlayer
--- @param args table
function Commands.SetLogLevel(player, args)
    if not isStaff(player) then
        print("[WLZA] Non-staff player " .. player:getUsername() .. " attempted to set log level")
        return
    end
    
    if args and args.logLevel ~= nil then
        WLZA_AttractorSystem.logLevel = args.logLevel
        print("[WLZA] Log level set to " .. args.logLevel)
    end
end

local function OnClientCommand(module, command, player, args)
    if module == "WLZA" then
        if Commands[command] then
            Commands[command](player, args)
        end
    end
end

Events.OnClientCommand.Add(OnClientCommand)