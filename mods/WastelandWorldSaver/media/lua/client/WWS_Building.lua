--- 
--- WWS_Building.lua
--- 29/05/2025
--- 

local function buildingCheck(player, context, worldobjects)
    if not player or not context or not worldobjects or #worldobjects == 0 then return end
    local x, y, z = worldobjects[1]:getX(), worldobjects[1]:getY(), worldobjects[1]:getZ()

    local isNoBuild = false
    local rules = WastelandZones and WastelandZones.Classes and WastelandZones.Classes.InteractionRules
    if rules and rules.getIsNoBuildZone and rules.getIsNoBuildZone(x, y, z) then
        isNoBuild = true
    elseif WEZ_EventZone and WEZ_EventZone.getIsNoBuildZone and WEZ_EventZone.getIsNoBuildZone(x, y, z) then
        isNoBuild = true
    end

    if not isNoBuild then return end

    local playerObj = getSpecificPlayer(player)
    if WL_Utils.isStaff(playerObj) then return end
    local carpOption = context:getOptionFromName(getText("ContextMenu_Build"))
    local metalOption = context:getOptionFromName(getText("ContextMenu_MetalWelding"))
    local WLBuilds = context:getOptionFromName("WL Builds")
    local MoreBuilding = context:getOptionFromName("More Buildings")
    if carpOption then
        carpOption.notAvailable = true
        carpOption.subOption = nil
        WL_ContextMenuUtils.addToolTip(carpOption, getText("ContextMenu_Build"), "You may not build in this area.", "Item_Hammer")
    end
    if metalOption then
        metalOption.notAvailable = true
        metalOption.subOption = nil
        WL_ContextMenuUtils.addToolTip(metalOption, getText("ContextMenu_MetalWelding"), "You may not build in this area.", "Item_WeldingMask")
    end
    if WLBuilds then
        WLBuilds.notAvailable = true
        WLBuilds.subOption = nil
        WL_ContextMenuUtils.addToolTip(WLBuilds, "WL Builds", "You may not build in this area.", "Item_Hammer")
    end
    if MoreBuilding then
        MoreBuilding.notAvailable = true
        MoreBuilding.subOption = nil
        WL_ContextMenuUtils.addToolTip(MoreBuilding, "More Building", "You may not build in this area.", "Item_Hammer")
    end
end

Events.OnFillWorldObjectContextMenu.Add(buildingCheck)
