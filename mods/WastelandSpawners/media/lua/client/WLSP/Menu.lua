---
--- WLSP_Menu.lua
--- Context menu integration for spawner management
---

local function isStaff()
    local player = getPlayer()
    if not player then return false end
    return WL_Utils.isStaff(player)
end

local function createSpawner(playerObj)
    if not playerObj then return end
    WLSP_ManageSpawner:show(playerObj, nil)
end

local function editSpawner(playerObj, spawner)
    if not playerObj or not spawner then return end
    WLSP_ManageSpawner:show(playerObj, spawner)
end

local function toggleSpawner(playerObj, spawner)
    if not playerObj or not spawner then return end
    WLSP_Client:toggleSpawner(playerObj, spawner.id)
end

local function teleportToSpawner(playerObj, spawner)
    if not playerObj or not spawner then return end
    playerObj:setX(spawner.position.x)
    playerObj:setY(spawner.position.y)
    playerObj:setZ(spawner.position.z)
    playerObj:setLx(spawner.position.x)
    playerObj:setLy(spawner.position.y)
    playerObj:setLz(spawner.position.z)
end

local function setLogLevel(playerObj, level)
    if not playerObj then return end
    sendClientCommand(playerObj, "WLSP", "SetLogLevel", { logLevel = level })
end

local function deleteAllSpawners(playerObj)
    if not playerObj then return end
    sendClientCommand(playerObj, "WLSP", "DeleteAllSpawners", {})
end

-- Add spawner management to admin menu
local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if not isStaff() then return end
    
    local playerObj = getPlayer()
    if not playerObj then return end

    context = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local eventToolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Event Tools")
        
    -- Add main spawner menu
    local spawnerMenu = eventToolsMenu:addOption("Spawners", nil, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(spawnerMenu, subMenu)
    
    -- Open spawner list window
    subMenu:addOption("Manage Nearby Spawners", playerObj, WLSP_SpawnerListWindow.show)
    
    -- Create new spawner at click location
    subMenu:addOption("Create New Spawner", playerObj, createSpawner)
    
    -- Add admin-only options
    if isAdmin() then
        -- Log level submenu
        local logLevelOption = subMenu:addOption("Set Log Level", nil, nil)
        local logLevelMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(logLevelOption, logLevelMenu)
        
        logLevelMenu:addOption("0 - None", playerObj, setLogLevel, 0)
        logLevelMenu:addOption("1 - Normal", playerObj, setLogLevel, 1)
        logLevelMenu:addOption("2 - Verbose", playerObj, setLogLevel, 2)
        
        -- Delete all spawners option
        subMenu:addOption("Delete All Spawners", playerObj, deleteAllSpawners)
    end
    
    -- List/Edit existing spawners (if any)
    local spawners = WLSP_Client:getAllSpawners()
    if spawners and #spawners > 0 then
        -- Add submenu for all spawners
        local allSpawnersOption = subMenu:addOption("All Spawners", nil, nil)
        local allSpawnersMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(allSpawnersOption, allSpawnersMenu)
        
        -- Add option to edit each spawner
        for _, spawner in ipairs(spawners) do
            local isEnabled = WLSP_Client:isSpawnerEnabled(spawner.id)
            
            local spawnerName = spawner.id or "Unknown"
            local spawnerType = spawner.type or "?"
            local statusIcon = isEnabled and "O" or "X"
            
            local displayName = string.format("[%s] %s (%s)", statusIcon, spawnerName, spawnerType)
            
            -- Create submenu for each spawner
            local spawnerOption = allSpawnersMenu:addOption(displayName, nil, nil)
            local spawnerSubMenu = ISContextMenu:getNew(allSpawnersMenu)
            allSpawnersMenu:addSubMenu(spawnerOption, spawnerSubMenu)
            
            -- Toggle enabled/disabled option
            local toggleText = isEnabled and "Disable" or "Enable"
            spawnerSubMenu:addOption(toggleText, playerObj, toggleSpawner, spawner)
            
            -- Edit option
            spawnerSubMenu:addOption("Edit Spawner", playerObj, editSpawner, spawner)
            
            -- TP option - teleport to spawner location
            if spawner.position.x and spawner.position.y and spawner.position.z then
                spawnerSubMenu:addOption("TP", playerObj, teleportToSpawner, spawner)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)