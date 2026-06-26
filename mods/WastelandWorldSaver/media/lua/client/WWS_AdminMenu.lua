local function GiveToken(player, amount)
    WL_UserData.Fetch("WastelandWorldSaver", player:getUsername(), function(data)
        WL_UserData.Append("WastelandWorldSaver", {
            availablePickups = data.availablePickups + amount
        }, player:getUsername())
    end)
end

Events.OnFillWorldObjectContextMenu.Add(function (playerIdx, context, worldObjects)
    local player = getPlayer(playerIdx)
    if not WL_Utils.isStaff(player) then return end
	for _, v in ipairs(worldObjects) do
        local movingObjects = v:getSquare():getMovingObjects()
        for i = 0, movingObjects:size() - 1 do
            local object = movingObjects:get(i)
            if instanceof(object, "IsoPlayer") then
                local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Tile Tokens | " .. object:getUsername())
                submenu:addOption("Give 1", object, GiveToken, 1)
                submenu:addOption("Give 5", object, GiveToken, 5)
                submenu:addOption("Give 10", object, GiveToken, 10)
                submenu:addOption("Give 20", object, GiveToken, 20)
                return
            end
        end
    end
end)