if isClient() then return end

local Commands = {}

function Commands.sendEffect(player, args)
    if not player then return end
    if not args then return end
    if not args.usernames then return end
    local payload = {
        sourcePlayer = player:getUsername(),
        effectData = args.effectData
    }
	for _, username in ipairs(args.usernames) do
        local targetPlayer = WL_Utils.findPlayerFromUsername(username)
        if targetPlayer then
			sendServerCommand(targetPlayer, "WastelandLib", "receiveEffect", payload)
        end
	end
end

local function onClientCommand(module, command, player, args)
	if module ~= "WastelandLib" then return end
	if not Commands[command] then return end
	Commands[command](player, args)
end

Events.OnClientCommand.Add(onClientCommand)