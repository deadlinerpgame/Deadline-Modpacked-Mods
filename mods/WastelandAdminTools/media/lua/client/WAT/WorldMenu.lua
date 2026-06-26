require "WAT/ItemAudit"
require "WAT/GroundCleaner"
require "WAT/Coords"
require "WAT/TimerManager"
require "WAT/BasementZoneManager"
require "WAT/BasementTemplateManager"
require "WAT/BasementCreator"
require "WAT/BasementList"
require "WAT/BasementEditor"
require "WAT/LightbulbChanger"
require "WAT/WorldTime"
require "WAT/WorldTimeSync"
require "WAT/SpeedMonitor"
require "WL_Utils"
require "UI/WL_ItemListManagerWindow"
require "WAT/DFiller"

local WAT_WorldMenu = {}

function WAT_WorldMenu.doMenu(playerIdx, context)
    if isClient() and not WL_Utils.isStaff(getPlayer()) then return end

    local submenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
    
    -- Utilities submenu
    local utilitiesMenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "Utilities")

    if WAT_OverFiller then
        if WAT_OverFiller.enabled then
            utilitiesMenu:addOption("Disable Over Filler", nil, WAT_OverFiller.disable)
        else
            utilitiesMenu:addOption("Enable Over Filler", nil, WAT_OverFiller.enable)
        end
    end
    
    if getPlayer():getAccessLevel() == "Admin" then
        utilitiesMenu:addOption("Lua Reloader", nil, WLR_LuaReloader.display)
    end
    
    utilitiesMenu:addOption("Tile Editor", TileEditorMain, TileEditorMain.display)
    utilitiesMenu:addOption("Copy/Paste", WAT_CopyPaste, WAT_CopyPaste.display)
    utilitiesMenu:addOption("D-Filler", WAT_DFiller, WAT_DFiller.display)
    utilitiesMenu:addOption("Item Lists", nil, WAT_WorldMenu.showItemListsWindow)
    utilitiesMenu:addOption("Speed Monitor", nil, WAT_SpeedMonitor.toggle)
    
    if WAT_ShowCoords then
        local coordsSubmenu = WL_ContextMenuUtils.getOrCreateSubMenu(utilitiesMenu, "Coords")
        coordsSubmenu:addOption("Hide Coords" , nil, WAT_WorldMenu.toggleCoords)
        coordsSubmenu:addOption("Move To Top Left", "topleft", WAT_WorldMenu.moveCoords)
        coordsSubmenu:addOption("Move To Top Right", "topright", WAT_WorldMenu.moveCoords)
        coordsSubmenu:addOption("Move To Bottom Left", "bottomleft", WAT_WorldMenu.moveCoords)
        coordsSubmenu:addOption("Move To Bottom Right", "bottomright", WAT_WorldMenu.moveCoords)
        if WAT_CoordsCell then
            coordsSubmenu:addOption("Hide Cell", nil, WAT_WorldMenu.toggleCell)
        else
            coordsSubmenu:addOption("Show Cell", nil, WAT_WorldMenu.toggleCell)
        end
    else
        utilitiesMenu:addOption("Show Coords" , nil, WAT_WorldMenu.toggleCoords)
    end

    utilitiesMenu:addOption("Zombie Population Debug", nil, newZombiePopulationWindow)
    utilitiesMenu:addOption("Region Debug", nil, IsoRegionsWindow.OnOpenPanel)
    
    utilitiesMenu:addOption("Player Refund", nil, WAT_ItemRefunder.OnRefundItem)
    utilitiesMenu:addOption("Toggle Mouse Coords", nil, WL_MouseCoords.toggle)

    if ZZL_URL then
        local status = WAT_WorldMenu.getRareLootStatus()
        utilitiesMenu:addOption("Reset Rare Loot (Next: " .. status .. ")", nil, WAT_WorldMenu.resetRareLoot)
    end
    
    if isAdmin() then
        utilitiesMenu:addOption("Reboot Server", nil, function()
            sendClientCommand(getPlayer(), "WAT", "reboot", {})
        end)
    end
    
    -- Event Tools submenu
    local eventToolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "Event Tools")
    eventToolsMenu:addOption("Events Helper", WAT_EventsHelper, WAT_EventsHelper.display)
    eventToolsMenu:addOption("Timer Manager", WAT_TimerManager, WAT_TimerManager.display)
    
    -- World Management submenu
    local worldMgmtMenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "World Management")
    worldMgmtMenu:addOption("Level Analyzer", nil, WAT_ShowLevelAnalyzer)
    worldMgmtMenu:addOption("Lightbulb Changer", nil, WAT_LightbulbChanger.display)
    worldMgmtMenu:addOption("Generator Manager", nil, WAT_GeneratorManager.show)

    if isAdmin() then
        worldMgmtMenu:addOption("Set World Time", nil, WAT_WorldTime.show)
    end
    
    if WL_Utils.canModerate(getPlayer()) then
        -- New Basement System (template-based)
        local basementMenu = WL_ContextMenuUtils.getOrCreateSubMenu(worldMgmtMenu, "Basements")
        basementMenu:addOption("Create Basement", nil, function() WAT_BasementCreator.show() end)
        basementMenu:addOption("Nearby Basements", nil, function() WAT_BasementList.show() end)
        
        if isAdmin() then
            basementMenu:addOption("Template Manager", nil, function() WAT_BasementTemplateManager.show() end)
        end
    end
    
    -- Audits submenu
    if WL_Utils.canModerate(getPlayer()) then
        local auditsSubmenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "Audits")
        auditsSubmenu:addOption("Item Audit" , nil, WAT_WorldMenu.showItemAuditWindow)
        auditsSubmenu:addOption("Ground Cleaner" , nil, WAT_WorldMenu.showGroundCleanerWindow)
        auditsSubmenu:addOption("Safehouse Audit", WAT_SafehouseAudit, WAT_SafehouseAudit.display)
        auditsSubmenu:addOption("Workplace Audit", WAT_WorkplaceAudit, WAT_WorkplaceAudit.display)
    end
    
    -- Spawn submenu
    local spawnerSubmenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, "Spawn")
    spawnerSubmenu:addOption("Metal Barrel [Silver]", "crafted_01_24", WAT_WorldMenu.spawnMetalBarrel)
    spawnerSubmenu:addOption("Metal Barrel [Copper]", "crafted_01_28", WAT_WorldMenu.spawnMetalBarrel)
    spawnerSubmenu:addOption("Corpse (Male)", "Base.CorpseMale", WAT_WorldMenu.spawnCorpse)
    spawnerSubmenu:addOption("Corpse (Female)", "Base.CorpseFemale", WAT_WorldMenu.spawnCorpse)
    spawnerSubmenu:addOption("Trees", WAT_TreeSpawner, WAT_TreeSpawner.display)
    spawnerSubmenu:addOption("Grass", WAT_GrassSpawner, WAT_GrassSpawner.display)

    local vehicle = IsoObjectPicker.Instance:PickVehicle(getMouseXScaled(), getMouseYScaled())
    if vehicle then
        local toolsMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Tools")
        local vehicleMenu = WL_ContextMenuUtils.getOrCreateSubMenu(toolsMenu, "Vehicle:")
        if not getCore():getDebug() then
		    vehicleMenu:addOption("Vehicle Angles UI", vehicle, debugVehicleAngles)
        end
        vehicleMenu:addOption("Simple Repair", vehicle, WAT_WorldMenu.simpleRepair)
    end

end

function WAT_WorldMenu.showItemAuditWindow()
    WAT_ItemAudit:display()
end

function WAT_WorldMenu.showItemListsWindow()
    WL_ItemListManagerWindow:show(getPlayer())
end

function WAT_WorldMenu.showGroundCleanerWindow()
    WAT_GroundCleaner:display()
end

function WAT_WorldMenu.toggleCoords()
    WAT_ShowCoords = not WAT_ShowCoords
    getPlayer():getModData().WAT_ShowCoords = WAT_ShowCoords
end

function WAT_WorldMenu.moveCoords(pos)
    WAT_CoordsPos = pos
end

function WAT_WorldMenu.toggleCell()
    WAT_CoordsCell = not WAT_CoordsCell
    getPlayer():getModData().WAT_CoordsCell = WAT_CoordsCell
end

function WAT_WorldMenu.simpleRepair(vehicle)
	sendClientCommand(getPlayer(), "WAT", "simpleRepair", { vehicle = vehicle:getId() })
end

function WAT_WorldMenu.spawnMetalBarrel(sprite)
    ISBlacksmithMenu.onMetalDrum({}, 0, sprite)
end

function WAT_WorldMenu.spawnCorpse(corpseType)
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return end
    local corpse = InventoryItemFactory.CreateItem(corpseType)
    sq:AddWorldInventoryItem(corpse, 0, 0, 0)
end

function WAT_WorldMenu.getRareLootStatus()
    if not ZZL_URL or not ZZL_URL.nextSpawn then return "Unknown" end
    local now = getTimestamp()
    local diff = ZZL_URL.nextSpawn - now
    if diff <= 0 then return "Ready" end

    local hours = math.floor(diff / 3600)
    local minutes = math.floor((diff % 3600) / 60)
    local seconds = math.floor(diff % 60)

    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

function WAT_WorldMenu.resetRareLoot()
    sendClientCommand(getPlayer(), "ZoomiesZombieLoot", "resetSpawnTime", {})
end

Events.OnFillWorldObjectContextMenu.Add(WAT_WorldMenu.doMenu)
