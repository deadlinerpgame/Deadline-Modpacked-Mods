if not isServer() then return end

WIT_Pager = WIT_Pager or {}

local function getPlayerByUserNameSafer(username)
	local player = getPlayerFromUsername(username)
	if player then
		return player
	end
	local players = getOnlinePlayers()
	for i=0, players:size()-1 do
		local player = players:get(i)
		if player:getUsername() == username then
			return player
		end
	end
	return nil
end

function WIT_Pager.sendMessage(player, args)
    local send = player
    local recipients = args.recipients or {}
    local message = args.message

    if not player or not send or not message then return end
    if not recipients or #recipients == 0 then return end

    local sendUsername = player:getUsername()
    local successRecipients = {}
    local failedRecipients = {}

    for _, recipientUsername in ipairs(recipients) do
        local receive = getPlayerByUserNameSafer(recipientUsername)
        
        if receive then
            local receiveUsername = receive:getUsername()
            sendServerCommand(receive, "WIT_Pager", "receiveMessage", {receive = receiveUsername, message = message})
            table.insert(successRecipients, receiveUsername)
            writeLog("pager", "[PAGER] Sent message from " .. sendUsername .. " to " .. receiveUsername .. ": " .. message)
        else
            table.insert(failedRecipients, recipientUsername)
        end
    end

    if #successRecipients > 0 then
        sendServerCommand(send, "WIT_Pager", "sentMessage", {send = sendUsername, recipients = successRecipients, message = message})
    end

    if #failedRecipients > 0 then
        sendServerCommand(send, "WIT_Pager", "failedMessage", {send = sendUsername, recipients = failedRecipients, message = message})
    end
end

local function processClientCommand(module, command, player, args)
    if module ~= "WIT_Pager" then return end
    if not WIT_Pager[command] then return end
    WIT_Pager[command](player, args)
end

Events.OnClientCommand.Add(processClientCommand)