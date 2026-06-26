local context;

local function AddBoolItem(menu, name, option, state)
    if state then
        menu:addOption(name .. " (Enabled)", nil, function ()
            sendClientCommand(getPlayer(), "WLR_Auto", "set", { [option] = false })
        end)
    else
        menu:addOption(name .. " (Disabled)", nil, function ()
            sendClientCommand(getPlayer(), "WLR_Auto", "set", { [option] = true })
        end)
    end
end

local function AddAutoRespawnMenu(options)
    if not isAdmin() then return end
    local adminMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local utilitiesMenu = WL_ContextMenuUtils.getOrCreateSubMenu(adminMenu, "Utilities")
    local autoMenu = WL_ContextMenuUtils.getOrCreateSubMenu(utilitiesMenu, "Auto Loot Respawn")
    if options.Enabled then
        autoMenu:addOption("Disable System", nil, function ()
            sendClientCommand(getPlayer(), "WLR_Auto", "disable", {})
        end)
    else
        autoMenu:addOption("Enable System", nil, function ()
            sendClientCommand(getPlayer(), "WLR_Auto", "enable", {})
        end)
    end

    autoMenu:addOption("Reset Cell Cache", nil, function ()
        sendClientCommand(getPlayer(), "WLR_Auto", "reset", {})
    end)

    autoMenu:addOption("Force All", nil, function ()
        sendClientCommand(getPlayer(), "WLR_Auto", "forceAll", {})
    end)

    autoMenu:addOption("Run Chunk at Feet", nil, function ()
        local player = getPlayer()
        sendClientCommand(player, "WLR_Auto", "runChunk", { x = player:getX(), y = player:getY() })
    end)

    AddBoolItem(autoMenu, "Debug Logs", "Logs", options.Logs)
    AddBoolItem(autoMenu, "Trace Logs", "Trace", options.Trace)
    AddBoolItem(autoMenu, "Always Respawn", "AlwaysRespawn", options.AlwaysRespawn)
    AddBoolItem(autoMenu, "Skip Cooldown", "SkipCooldown", options.SkipCooldown)
end

Events.OnFillWorldObjectContextMenu.Add(function (player, c)
    if not isAdmin() then return end
    context = c
    sendClientCommand(getPlayer(), "WLR_Auto", "getDebug", {})
end)

Events.OnServerCommand.Add(function (module, command, args)
    if module ~= "WLR_Auto" then return end
    if command == "debug" and context then
        AddAutoRespawnMenu(args or {})
        context = nil
    end
end)