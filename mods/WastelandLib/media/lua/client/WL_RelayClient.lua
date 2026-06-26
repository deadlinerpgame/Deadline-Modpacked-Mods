if not isClient() then return end

-- This file isn't used anymore so we can probably delete it + WP_RelayServer in future?

WL_RelayClient = {}

function WL_RelayClient.sendEffect(usernames, effectData)
	if not usernames then error("usernames is missing") end
	if not effectData then error("effectData is missing") end
	local data = {
		usernames = usernames,
		effectData = effectData,
	}
	sendClientCommand(getPlayer(), "WastelandLib", "sendEffect", data)
end

local serverCommands = {}

function serverCommands.receiveEffect(data)
	if not data then return end
    if not data.effectData then return end
	WL_RelayEffects.applyEffects(getPlayer(), data.effectData)
end

local function processServerCommand(module, command, args)
	if module ~= "WastelandLib" then return end
	if not serverCommands[command] then return end
	serverCommands[command](args)
end

Events.OnServerCommand.Add(processServerCommand)
