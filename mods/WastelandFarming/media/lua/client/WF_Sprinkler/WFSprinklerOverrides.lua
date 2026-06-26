require("WF_Sprinkler/WFSprinklerUtilities")
require("Moveables/ISMoveablesAction")
require("Moveables/ISMoveableSpriteProps")

-- prevent picking up the barrel if it has a sprinkler attached
local originalISMoveablesAction_isValidObject = ISMoveablesAction.isValidObject
function ISMoveablesAction:isValidObject()
    if (not self.square) then return false end
    if (not self.moveProps) then return false end

    if self.mode == "pickup" or self.mode == "scrap" then
        if self.moveProps.object and
           WFSprinklerUtilities.isBarrelObject(self.moveProps.object) and
           WFSprinklerUtilities.getBarrelSprinkler(self.moveProps.object) then
            return false
        end
    end
    return originalISMoveablesAction_isValidObject(self)
end

local originalISMoveableSpriteProps_canPickUpMoveableInternal = ISMoveableSpriteProps.canPickUpMoveableInternal
function ISMoveableSpriteProps:canPickUpMoveableInternal( _character, _square, _object, _isMulti )
    if WFSprinklerUtilities.isBarrelObject(_object) and
       WFSprinklerUtilities.getBarrelSprinkler(_object) then
        return false
    end
    return originalISMoveableSpriteProps_canPickUpMoveableInternal(self, _character, _square, _object, _isMulti)
end

local originalISMoveableSpriteProps_getInfoPanelFlagsPerTile = ISMoveableSpriteProps.getInfoPanelFlagsPerTile
function ISMoveableSpriteProps:getInfoPanelFlagsPerTile( _square, _object, _player, _mode )
    originalISMoveableSpriteProps_getInfoPanelFlagsPerTile(self, _square, _object, _player, _mode)
    if WFSprinklerUtilities.isBarrelObject(_object) and WFSprinklerUtilities.getBarrelSprinkler(_object) then
        InfoPanelFlags.hasSprinkler = true
    else
        InfoPanelFlags.hasSprinkler = false
    end
end

local originalISMoveableSpriteProps_getInfoPanelDescription = ISMoveableSpriteProps.getInfoPanelDescription
function ISMoveableSpriteProps:getInfoPanelDescription( _square, _object, _player, _mode )
    local infoTable = originalISMoveableSpriteProps_getInfoPanelDescription(self, _square, _object, _player, _mode)

    local bR,bG,bB = ISMoveableSpriteProps.bhc:getR()*255, ISMoveableSpriteProps.bhc:getG()*255, ISMoveableSpriteProps.bhc:getB()*255
    if InfoPanelFlags.hasSprinkler then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_WFHasSprinkler"), bR,bG,bB ); end

    return infoTable
end