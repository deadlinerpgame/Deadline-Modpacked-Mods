---
--- WIN_Server.lua
--- 2025-12-08
---

if isClient() then return end

local Commands = {}

function Commands.showPageToPlayers(player, args)
	for _, username in ipairs(args.usernames) do
		local targetPlayer = WL_Utils.findPlayerFromUsername(username)
		if targetPlayer then
			local pageData = {
				pageContent = args.pageContent,
				fontKey = args.fontKey,
				skinKey = args.skinKey,
                languageKey = args.languageKey,
			}
			sendServerCommand(targetPlayer, "WastelandImmersiveNotes", "showPage", pageData)
		end
	end
end

local function onClientCommand(module, command, player, args)
	if module ~= "WastelandImmersiveNotes" then return end
	if not Commands[command] then return end
	Commands[command](player, args)
end

Events.OnClientCommand.Add(onClientCommand)
