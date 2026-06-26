---
--- HealthPanelFix.lua
--- 04/12/2023
---
--- Allows moderators to send health panel commands that affect other players.
---

Events.OnClientCommand.Add(function (module, command, player, args)
	if module ~= "player" then return end
	if command ~= "onHealthCheat" then return end
	local otherPlayer = getPlayerByOnlineID(args.id)
	if otherPlayer and player:isAccessLevel("moderator") then
		sendServerCommand(otherPlayer, "ISHealthPanel", "onHealthCheat", args)
	end
end)