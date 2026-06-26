WSZ_Menu = WSZ_Menu or {}
require "WSZ/ui/WSZ_ManageSafezone"

-- Tooltip helper mirroring SafehouseLimiter behavior
local function addNegativeTooltip(option, reason)
    local toolTip = ISWorldObjectContextMenu.addToolTip()
    toolTip:setVisible(false)
    toolTip.description = reason
    option.notAvailable = true
    option.toolTip = toolTip
end

function WSZ_Menu.onFillWorldObjectContextMenu(playerNum, context)
    local player = getSpecificPlayer(playerNum)
    local safehouseOption = context:getOptionFromName(getText("ContextMenu_SafehouseClaim"))

    if safehouseOption then
        -- Check sandbox option for claiming existing buildings
        if SandboxVars.WastelandSafezone.CanPlayersClaim then
            if SandboxVars.WastelandSafezone.OverrideSafehouseClaim then
                -- Hijack vanilla safehouse claim to open our safezone creator with game-calculated bounds
                local clickedSquare = safehouseOption.param1
                local building = clickedSquare and clickedSquare:getBuilding() or nil
                local def = building and building:getDef() or nil

                -- If anything is invalid, remove the vanilla option
                if not clickedSquare or not building or not def then
                    context:removeOptionByName(getText("ContextMenu_SafehouseClaim"))
                else
                    -- If CanClaimCommercial is false, enforce SafehouseLimiter-style rules via WSZ_Client
                    local canOverride = true
                    local denyReason = nil
                    if SandboxVars.WastelandSafezone.CanClaimCommercial == false then
                        local ok, reason = WSZ_Client.checkBuildingDef(building)
                        if not ok then
                            canOverride = false
                            denyReason = reason
                        end
                    end

                    if canOverride then
                        -- Hide override option entirely if at root limit (non-staff)
                        if not WL_Utils.isStaff(player) then
                            local username = player and player:getUsername() or nil
                            local maxRoots = (SandboxVars and SandboxVars.WastelandSafezone and SandboxVars.WastelandSafezone.MaxPlayerSafezones) or 1
                            local rootCount = (username and WSZ_Client and WSZ_Client.countOwnedRootZones and WSZ_Client.countOwnedRootZones(username)) or 0
                            if rootCount >= maxRoots then
                                context:removeOptionByName(getText("ContextMenu_SafehouseClaim"))
                                canOverride = false
                            end
                        end
                    end
                    if canOverride then
                        -- Override the option to call our handler with the building def
                        safehouseOption.target = WSZ_Menu
                        safehouseOption.onSelect = WSZ_Menu.onClaimSafehouseFromDef
                        safehouseOption.param1 = player
                        safehouseOption.param2 = def
                    else
                        -- Leave the option present but disabled with a tooltip
                        addNegativeTooltip(safehouseOption, denyReason or "Cannot claim this building.")
                        safehouseOption.target = nil
                        safehouseOption.onSelect = nil
                    end
                end
            end
        else
            context:removeOptionByName(getText("ContextMenu_SafehouseClaim"))
        end
    end
    
    -- If player is already in a safezone, remove the claim option
    if #WSZ_Client.in_safezones > 0 and safehouseOption then
        context:removeOptionByName(getText("ContextMenu_SafehouseClaim"))
    end

    -- Staff Stuff
    if WL_Utils.isStaff(player) then
        local wlAdmin = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
        local worldMgmtMenu = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdmin, "World Management")
        local safehouseAdmin = WL_ContextMenuUtils.getOrCreateSubMenu(worldMgmtMenu, "Safezones")
        local safehouse = SafeHouse.getSafeHouse(player:getSquare())
        if safehouse then
            safehouseAdmin:addOption("Convert Current Safehouse to Safezone", player, WSZ_Menu.convertSafehouseToSafezone, safehouse)
        end

        if isAdmin() then
            -- If there are any safehouses on the map, show bulk convert
            local list = SafeHouse.getSafehouseList()
            local totalSafehouses = (list and list:size()) or 0
            if totalSafehouses > 0 then
                safehouseAdmin:addOption("Convert ALL Safehouses to Safezones (" .. tostring(totalSafehouses) .. ")", player, WSZ_Menu.convertAllSafehousesToSafezones, totalSafehouses)
            end
        end
    end
end

function WSZ_Menu.onPreFillWorldObjectContextMenu(playerNum, context)
    -- Show per-zone submenu for zones the player is standing in
    local player = getSpecificPlayer(playerNum)
    local zones = WSZ_Client.getCurrentZonesIn(player)
    if #zones > 0 then
        for _, zone in ipairs(zones) do
            local option = context:addOption("Safezone: " .. zone.name)
            local subMenu = context:getNew(context)
            context:addSubMenu(option, subMenu)
            
            local member = zone.members[player:getUsername()]
            if member or WL_Utils.isStaff(player) then
                subMenu:addOption("Show Info", player, WSZ_Menu.onShowInfo, zone)
            else
                subMenu:addOption("Request Membership", player, WSZ_Menu.onRequestMembership, zone)
            end
        end
    end

    -- Allow creating a safezone either:
    -- - when not inside any zone, limited by MaxPlayerSafezones (top-level limit)
    -- - when inside a zone the player owns (nested; unlimited, validation enforces enclosure)
    local username = player and player:getUsername() or nil
    local ownsAnyHere = false
    if #zones > 0 and username then
        for _, zone in ipairs(zones) do
            local m = zone.members and zone.members[username] or nil
            local role = m and (m.type or m.role)
            if role == "owner" then
                ownsAnyHere = true
                break
            end
        end
    end

    local maxRoots = SandboxVars.WastelandSafezone.MaxPlayerSafezones or 1
    local rootCount = WSZ_Client.countOwnedRootZones(username) or 0

    local canCreateHere = false
    if SandboxVars.WastelandSafezone.CanCustomClaim then
        if #zones == 0 then
            -- Not inside any zone: allow only if below top-level limit
            canCreateHere = (rootCount < maxRoots)
        else
            -- Inside some zone(s): only show if they own at least one zone here (nested creation)
            canCreateHere = ownsAnyHere
        end
    end

    if canCreateHere or WL_Utils.isStaff(player) then
        context:addOption("Create Safezone", player, WSZ_Menu.onCreateSafezone)
    end

    -- Add "My Safezones" menu item
    local memberZones = WSZ_Client.getZonesMemberOf(player)
    if #memberZones > 0 then
        local mySafezonesOption = context:addOption("My Safezones")
        local mySafezonesSubMenu = context:getNew(context)
        context:addSubMenu(mySafezonesOption, mySafezonesSubMenu)
        
        for _, zone in ipairs(memberZones) do
            mySafezonesSubMenu:addOption(zone.name, player, WSZ_Menu.onShowInfo, zone)
        end
    end

    WSZ_Client.in_safezones = zones
end

-- Opens the Create Safezone UI (delegated to WSZ_CreateSafezonePanel)
function WSZ_Menu.onCreateSafezone(player)
    WSZ_CreateSafezonePanel:show(player, {})
end

-- Handle hijacked safehouse claim: open creator with building bounds
function WSZ_Menu.onClaimSafehouseFromDef(_, player, def)
    if not player or not def then return end

    local x1 = def.getX and def:getX() or nil
    local y1 = def.getY and def:getY() or nil
    local x2 = def.getX2 and def:getX2() or nil
    local y2 = def.getY2 and def:getY2() or nil

    if not x1 or not y1 or not x2 or not y2 then
        return
    end

    WSZ_CreateSafezonePanel:show(player, {
        startX = x1,
        startY = y1,
        endX = x2,
        endY = y2
    })
end

-- Show Info: fetch fresh data then open the panel and default to Info tab
function WSZ_Menu.onShowInfo(player, zone)
    if not player or not zone or not zone.id then
        return
    end
    
    -- Use async method to get fresh, up-to-date data about the safehouse
    WSZ_System:getSafezoneAsync(player, zone.id, function(freshZoneData, errorMessage)
        if errorMessage then
            -- If there was an error fetching fresh data, show a message and fall back to cached data
            WL_Dialogs.showMessageDialog("Warning: Could not fetch latest safezone data (" .. errorMessage .. "). Showing cached data.")
            -- Fall back to showing the manage window with the original zone data
            WSZ_ManageSafezone:show(player, zone)
        elseif freshZoneData then
            -- Successfully got fresh data, show the manage window with updated data
            WSZ_ManageSafezone:show(player, freshZoneData)
        else
            -- No error message but no data either - this shouldn't happen but handle gracefully
            WL_Dialogs.showMessageDialog("Error: Could not fetch safezone data.")
        end
    end)
end

-- Request Membership: send to server workflow
function WSZ_Menu.onRequestMembership(player, zone)
    if not zone then return end
    -- Delegate to system; server will notify player if sent or if no managers online
    WSZ_System:requestMembership(player, zone.id)
end

-- Convert Safehouse to Safezone (staff only)
function WSZ_Menu.convertSafehouseToSafezone(player, safehouse)
    if not player or not safehouse then return end
    -- show confirmation dialog
    WL_Dialogs.showConfirmationDialog("Are you sure you want to convert this safehouse to a safezone?", function()
        WSZ_System:migrateOldSafehouse(player, safehouse:getX(), safehouse:getY(), safehouse:getW(), safehouse:getH())
    end)
end

-- Convert ALL Safehouses to Safezones (staff only, single server request)
function WSZ_Menu.convertAllSafehousesToSafezones(player, _)
    local list = SafeHouse.getSafehouseList()
    local total = (list and list:size()) or 0
    if total <= 0 then return end
    WL_Dialogs.showConfirmationDialog("Convert all " .. tostring(total) .. " safehouses to safezones? This cannot be undone.", function()
        WSZ_System:migrateAllSafehouses(player)
    end)
end

Events.OnPreFillWorldObjectContextMenu.Add(WSZ_Menu.onPreFillWorldObjectContextMenu)
Events.OnFillWorldObjectContextMenu.Add(WSZ_Menu.onFillWorldObjectContextMenu)