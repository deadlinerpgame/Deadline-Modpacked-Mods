local function performOverride(self)
    if not WSZ_Client.currentPermissions[self.WSZ_Permission] then
        WSZ_Client.ShowRestricted(self.character, "You don't have permission to perform this action.")
        self:forceStop()
        return
    end
    self:WSZ_Perform_Override()
end

local function startOverride(self)
    if not WSZ_Client.currentPermissions[self.WSZ_Permission] then
        WSZ_Client.ShowRestricted(self.character, "You don't have permission to perform this action.")
        self:forceStop()
        return
    end
    if self.WSZ_Start_Override then
        self:WSZ_Start_Override()
    end
end

local function overridePerform(actionClass, permission)
    actionClass.WSZ_Perform_Override = actionClass.perform
    actionClass.WSZ_Start_Override = actionClass.start
    actionClass.WSZ_Permission = permission
    actionClass.perform = performOverride
    actionClass.start = startOverride
end


local original_ISInventoryTransferAction_new = ISInventoryTransferAction.new
function ISInventoryTransferAction:new (character, item, srcContainer, destContainer, time)
    if srcContainer:isInCharacterInventory(character) and destContainer:isInCharacterInventory(character) then
        -- Moving items within the player's own inventory, allow it
        return original_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
    end

    if not WSZ_Client.currentPermissions.canMoveItems then
        WSZ_Client.ShowRestricted(character, "You don't have permission to remove items.")
        return {ignoreAction = true}
    end

    return original_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
end

overridePerform(ISGrabItemAction, "canMoveItems")
overridePerform(ISTakeGenerator, "canInteractItems")
overridePerform(ISPlugGenerator, "canInteractItems")
overridePerform(ISActivateGenerator, "canInteractItems")
overridePerform(ISToggleLightAction, "canInteractItems")
overridePerform(ISToggleStoveAction, "canInteractItems")

if ISToggleFridgesFreezers then
    overridePerform(ISToggleFridgesFreezers, "canInteractItems")
end

overridePerform(ISPlowAction, "canInteractItems")
overridePerform(ISSeedAction, "canInteractItems")
overridePerform(ISShovelAction, "canInteractItems")
overridePerform(ISWaterPlantAction, "canInteractItems")
overridePerform(ISCureFliesAction, "canInteractItems")
overridePerform(ISCureMildewAction, "canInteractItems")
overridePerform(ISFertilizeAction, "canInteractItems")
overridePerform(ISHarvestPlantAction, "canInteractItems")
overridePerform(ISPlantInfoAction, "canInteractItems")

if WFTending and WFTending.TendAction then
    overridePerform(WFTending.TendAction, "canInteractItems")
end

if WFSprinklerAttachAction then
    overridePerform(WFSprinklerAttachAction, "canInteractItems")
end

if WFSprinklerDetachAction then
    overridePerform(WFSprinklerDetachAction, "canInteractItems")
end

if WFSprinklerWaterAction then
    overridePerform(WFSprinklerWaterAction, "canInteractItems")
end

if WFGrowLampPickupAction then
    overridePerform(WFGrowLampPickupAction, "canInteractItems")
end

if WFGrowLampPlaceAction then
    overridePerform(WFGrowLampPlaceAction, "canInteractItems")
end

overridePerform(ISMoveablesAction, "canInteractItems")
overridePerform(ISTakeFuel, "canInteractItems")
overridePerform(ISTakeTrap, "canMoveItems")
overridePerform(ISSmashWindow, "canInteractItems")
overridePerform(ISTakeCarBatteryChargerAction, "canMoveItems")
overridePerform(ISToggleClothingDryer, "canInteractItems")
overridePerform(ISToggleClothingWasher, "canInteractItems")
overridePerform(ISToggleComboWasherDryer, "canInteractItems")
overridePerform(ISUnbarricadeAction, "canInteractItems")
overridePerform(ISRemoveGrass, "canInteractItems")
overridePerform(ISRemoveBush, "canInteractItems")
overridePerform(ISPlumbItem, "canInteractItems")
overridePerform(ISPlaceTrap, "canInteractItems")

if WLLPickDooorLockAction then
    overridePerform(WLLPickDooorLockAction, "canInteractItems")
end

if WLLPickLockAction then
    overridePerform(WLLPickLockAction, "canInteractItems")
end

overridePerform(ISRemoveSheetAction, "canInteractItems")
overridePerform(ISRemoveSheetRope, "canInteractItems")
overridePerform(ISOpenCloseCurtain, "canInteractItems")
overridePerform(ISLockDoor, "canInteractItems")
overridePerform(ISGetCompost, "canInteractItems")
overridePerform(ISPickupBrokenGlass, "canMoveItems")

-- Vehicle Actions
overridePerform(ISAddGasolineToVehicle, "canInteractItems")
overridePerform(ISConfigHeadlight, "canInteractItems")
overridePerform(ISDeflateTire, "canInteractItems")
overridePerform(ISDetachTrailerFromVehicle, "canInteractItems")
overridePerform(ISHotwireVehicle, "canInteractItems")
overridePerform(ISInflateTire, "canInteractItems")
overridePerform(ISInstallVehiclePart, "canInteractItems")
overridePerform(ISLightbarUITimedAction, "canInteractItems")
overridePerform(ISLockVehicleDoor, "canInteractItems")
overridePerform(ISRepairEngine, "canInteractItems")
overridePerform(ISShutOffVehicleEngine, "canInteractItems")
overridePerform(ISSmashVehicleWindow, "canInteractItems")
overridePerform(ISStartVehicleEngine, "canInteractItems")
overridePerform(ISTakeEngineParts, "canMoveItems")
overridePerform(ISTakeGasolineFromVehicle, "canMoveItems")
overridePerform(ISUninstallVehiclePart, "canInteractItems")

if ISConfigureContainerAction then
    local original_ISConfigureContainerAction_new = ISConfigureContainerAction.new
    function ISConfigureContainerAction:new(character, containers)
        if not WSZ_Client.currentPermissions.canInteractItems then
            WSZ_Client.ShowRestricted(character, "You don't have permission to configure containers.")
            return {ignoreAction = true, perform = function () end}
        end

        return original_ISConfigureContainerAction_new(self, character, containers)
    end
end

if P4Decoholic then
    local P4Decoholic_showContainerConfigWindow = P4Decoholic.showContainerConfigWindow
    P4Decoholic.showContainerConfigWindow = function(base, cOverlays, selected)
        if not WSZ_Client.currentPermissions.canInteractItems then
            WSZ_Client.ShowRestricted(getPlayer(), "You don't have permission to configure containers.")
            return
        end

        return P4Decoholic_showContainerConfigWindow(base, cOverlays, selected)
    end

    local P4Decoholic_showTileConfigWindow = P4Decoholic.showTileConfigWindow
    P4Decoholic.showTileConfigWindow = function(base, tOverlays, selected)
        if not WSZ_Client.currentPermissions.canInteractItems then
            WSZ_Client.ShowRestricted(getPlayer(), "You don't have permission to configure tiles.")
            return
        end

        return P4Decoholic_showTileConfigWindow(base, tOverlays, selected)
    end

    local P4Decoholic_showItemAdjustWindow = P4Decoholic.showItemAdjustWindow
    P4Decoholic.showItemAdjustWindow = function(item)
        if not WSZ_Client.currentPermissions.canInteractItems then
            WSZ_Client.ShowRestricted(getPlayer(), "You don't have permission to adjust items.")
            return
        end

        return P4Decoholic.showItemAdjustWindow(item)
    end
end
