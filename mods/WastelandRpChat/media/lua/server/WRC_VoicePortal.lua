-- Only MP
if not isServer() or isClient() then return end

--- Check if player is within range of a point
--- @param player IsoPlayer
--- @param point table {x, y, z}
--- @param xyRange number
--- @param zRange number
--- @return boolean
local function isPlayerNearPoint(player, point, xyRange, zRange)
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local dx = px - point.x
    local dy = py - point.y
    local dz = math.abs(pz - point.z)
    
    local distSq = dx * dx + dy * dy
    return distSq <= (xyRange * xyRange) and dz <= zRange
end

--- Handle client command to trigger a portal
--- @param module string
--- @param command string
--- @param sendingPlayer IsoPlayer
--- @param args table
local function onClientCommand(module, command, sendingPlayer, args)
    if module ~= "WRC_VoicePortal" then return end
    
    if command == "TriggerPortal" then
        local targetPoint = args.targetPoint
        local message = args.message
        local xyRange = args.xyRange
        local zRange = args.zRange
        
        if not targetPoint or not message then return end
        
        -- Find all players near the target point
        local onlinePlayers = getOnlinePlayers()
        for i = 0, onlinePlayers:size() - 1 do
            local player = onlinePlayers:get(i)
            
            -- Don't send to the speaking player
            if player ~= sendingPlayer then
                if isPlayerNearPoint(player, targetPoint, xyRange, zRange) then
                    sendServerCommand(player, "WRC_VoicePortal", "ReceivePortalMessage", {message})
                end
            end
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)