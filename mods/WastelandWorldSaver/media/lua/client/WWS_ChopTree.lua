--- 
--- WWS_ChopTree.lua
--- 29/05/2025
--- 

local function predicateChopTree(item)
	return not item:isBroken() and item:hasTag("ChopTree")
end

local function isNoDeforestZone(x, y, z)
    local rules = WastelandZones and WastelandZones.Classes and WastelandZones.Classes.InteractionRules
    if rules and rules.getIsNoDeforestZone and rules.getIsNoDeforestZone(x, y, z) then
        return true
    end

    if WEZ_EventZone and WEZ_EventZone.getIsNoDeforestZone and WEZ_EventZone.getIsNoDeforestZone(x, y, z) then
        return true
    end

    return false
end

local function checkTree(player, context, worldobjects)
    if not player or not context or not worldobjects or #worldobjects == 0 then return end
    if not instanceof(worldobjects[1], "IsoTree") then return end
    local tree = worldobjects[1]
    local playerObj = getSpecificPlayer(player)
    if WL_Utils.isStaff(playerObj) then return end
    local inventory = playerObj:getInventory()
    local axe = inventory:getFirstEvalRecurse(predicateChopTree)
    if axe then
        if isNoDeforestZone(tree:getX(), tree:getY(), tree:getZ()) then
            local option = context:getOptionFromName(getText("ContextMenu_Chop_Tree"))
            if option then
                option.notAvailable = true
                WL_ContextMenuUtils.addToolTip(option, getText("ContextMenu_Chop_Tree"), "You may not chop trees in this area.", axe:getTex():getName())
            end
        end
    end
end    

Events.OnFillWorldObjectContextMenu.Add(checkTree)
