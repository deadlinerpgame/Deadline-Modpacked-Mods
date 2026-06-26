---
--- Menu.lua
--- Context menu integration for attractor management
---

local function isStaff()
    local player = getPlayer()
    if not player then return false end
    return WL_Utils.isStaff(player)
end

local function createAttractor(playerObj)
    if not playerObj then return end
    WLZA_ManageAttractor:show(playerObj, nil)
end

local function editAttractor(playerObj, attractor)
    if not playerObj or not attractor then return end
    WLZA_ManageAttractor:show(playerObj, attractor)
end

local function toggleAttractor(playerObj, attractor)
    if not playerObj or not attractor then return end
    WLZA_Client:toggleAttractor(playerObj, attractor.id)
end

local function teleportToAttractor(playerObj, attractor)
    if not playerObj or not attractor then return end
    playerObj:setX(attractor.position.x)
    playerObj:setY(attractor.position.y)
    playerObj:setZ(attractor.position.z)
    playerObj:setLx(attractor.position.x)
    playerObj:setLy(attractor.position.y)
    playerObj:setLz(attractor.position.z)
end

local function setLogLevel(playerObj, level)
    if not playerObj then return end
    sendClientCommand(playerObj, "WLZA", "SetLogLevel", { logLevel = level })
end

local function deleteAllAttractors(playerObj)
    if not playerObj then return end
    sendClientCommand(playerObj, "WLZA", "DeleteAllAttractors", {})
end

-- Add attractor management to admin menu
local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if not isStaff() then return end
    
    local playerObj = getPlayer()
    if not playerObj then return end
    
    context = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    local eventToolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Event Tools")
    
    -- Add main attractor menu
    local attractorMenu = eventToolsMenu:addOption("Attractors", nil, nil)
    local subMenu = ISContextMenu:getNew(context)
    context:addSubMenu(attractorMenu, subMenu)
    
    -- Open attractor list window
    subMenu:addOption("Manage Nearby Attractors", WLZA_AttractorListWindow, WLZA_AttractorListWindow.show, playerObj)
    
    -- Create new attractor at click location
    subMenu:addOption("Create New Attractor", playerObj, createAttractor)
    
    -- Add admin-only options
    if isAdmin() then
        -- Log level submenu
        local logLevelOption = subMenu:addOption("Set Log Level", nil, nil)
        local logLevelMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(logLevelOption, logLevelMenu)
        
        logLevelMenu:addOption("0 - None", playerObj, setLogLevel, 0)
        logLevelMenu:addOption("1 - Normal", playerObj, setLogLevel, 1)
        logLevelMenu:addOption("2 - Verbose", playerObj, setLogLevel, 2)
        
        -- Delete all attractors option
        subMenu:addOption("Delete All Attractors", playerObj, deleteAllAttractors)
    end
    
    -- List/Edit existing attractors (if any)
    local attractors = WLZA_Client:getAllAttractors()
    if attractors and #attractors > 0 then
        -- Add submenu for all attractors
        local allAttractorsOption = subMenu:addOption("All Attractors", nil, nil)
        local allAttractorsMenu = ISContextMenu:getNew(subMenu)
        subMenu:addSubMenu(allAttractorsOption, allAttractorsMenu)
        
        -- Add option to edit each attractor
        for _, attractor in ipairs(attractors) do
            local isEnabled = WLZA_Client:isAttractorEnabled(attractor.id)
            
            local attractorName = attractor.name or "Unknown"
            local statusIcon = isEnabled and "O" or "X"
            
            local displayName = string.format("[%s] %s", statusIcon, attractorName)
            
            -- Create submenu for each attractor
            local attractorOption = allAttractorsMenu:addOption(displayName, nil, nil)
            local attractorSubMenu = ISContextMenu:getNew(allAttractorsMenu)
            allAttractorsMenu:addSubMenu(attractorOption, attractorSubMenu)
            
            -- Toggle enabled/disabled option
            local toggleText = isEnabled and "Disable" or "Enable"
            attractorSubMenu:addOption(toggleText, playerObj, toggleAttractor, attractor)
            
            -- Edit option
            attractorSubMenu:addOption("Edit Attractor", playerObj, editAttractor, attractor)
            
            -- TP option - teleport to attractor location
            if attractor.position and attractor.position.x and attractor.position.y and attractor.position.z then
                attractorSubMenu:addOption("TP", playerObj, teleportToAttractor, attractor)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)