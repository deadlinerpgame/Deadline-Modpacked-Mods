---
--- WIT_Keybinds.lua
--- 02/06/2025
--- 

require "WM_Utils"

local function WIT_ToggleMask(playerObj)
    if not playerObj then return end
    local mask = WM_Utils.isWearingMask(playerObj)
    if mask then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, mask, 50))
        HaloTextHelper.addText(playerObj, getText("IGUI_MaskRemoved"), HaloTextHelper.getColorWhite())
    else
        local maskItem = WM_Utils.findMask(playerObj)
        if maskItem then
            ISTimedActionQueue.add(ISWearClothing:new(playerObj, maskItem, 50))
            HaloTextHelper.addText(playerObj, getText("IGUI_MaskEquipped"), HaloTextHelper.getColorWhite())
        else
            HaloTextHelper.addText(playerObj, getText("IGUI_NoMaskFound"), HaloTextHelper.getColorRed())
        end
    end
end

local function WIT_DiceCombat(playerObj)
    if WDC_DiceWindow.instance then
        if WDC_DiceWindow.instance:getIsVisible() then
            WDC_DiceWindow.instance:setVisible(false)
        else
            WDC_DiceWindow.instance:setVisible(true)
        end
    else
        WDC_DiceWindow.display()
    end
end

local function WIT_SoundBoard(playerObj)
    if not WL_Utils.isStaff(playerObj) then
        HaloTextHelper.addText(playerObj, getText("IGUI_StaffOnly"), HaloTextHelper.getColorRed())
        return
    end
    if WSB_SoundboardWindow.instance then
        WSB_SoundboardWindow.instance:close()
    else
        WSB_SoundboardWindow.show()
    end
end

local function WIT_LevelAnalyzer(playerObj)
    if not WL_Utils.isStaff(playerObj) then
        HaloTextHelper.addText(playerObj, getText("IGUI_StaffOnly"), HaloTextHelper.getColorRed())
        return
    end
    WAT_ShowLevelAnalyzer()
end

local function WO_ToggleObjectiveTracker()
    if not getActivatedMods():contains("WastelandObjectives") then return end
    if not WO_ObjectiveTracker.instance then
        WO_ObjectiveTracker.display()
    else
        WO_ObjectiveTracker.instance:close()
    end
end

local function WO_ToggleObjectiveAdmin()
    if not getActivatedMods():contains("WastelandObjectives") then return end
    if not WL_Utils.isStaff(getSpecificPlayer(0)) then
        HaloTextHelper.addText(getSpecificPlayer(0), getText("IGUI_StaffOnly"), HaloTextHelper.getColorRed())
        return
    end
    if not WO_Panel.instance then
        WO_Panel.display()
    else
        WO_Panel.instance:onClose()
    end
end

local function WIT_ToggleLootCategoryFilter()
    WastelandManageContainers.LootCategoryFilter.ToggleEnabled(getSpecificPlayer(0))
    if WastelandManageContainers.LootCategoryFilter.State.enabled then
        HaloTextHelper.addText(getSpecificPlayer(0), getText("IGUI_WITLootCategoryFilterEnabled"), HaloTextHelper.getColorWhite())
    else
        HaloTextHelper.addText(getSpecificPlayer(0), getText("IGUI_WITLootCategoryFilterDisabled"), HaloTextHelper.getColorWhite())
    end
end


local WIT_Keybinds = {
    toggleMask = { name = 'WIT_ToggleMask', key = Keyboard.KEY_NONE, callback = WIT_ToggleMask },
    diceCombat = { name = 'WIT_DiceCombat', key = Keyboard.KEY_NONE, callback = WIT_DiceCombat },
    toggleLootCategoryFilter = { name = 'WIT_ToggleLootCategoryFilter', key = Keyboard.KEY_NONE, callback = WIT_ToggleLootCategoryFilter },
    toggleObjectiveTracker = { name = 'WO_ToggleObjectiveTracker', key = Keyboard.KEY_NONE, callback = WO_ToggleObjectiveTracker },
}

local WIT_StaffKeybinds = {
    soundBoard = { name = 'WIT_SoundBoard', key = Keyboard.KEY_NONE, callback = WIT_SoundBoard },
    levelAnalyzer = { name = 'WIT_LevelAnalyzer', key = Keyboard.KEY_NONE, callback = WIT_LevelAnalyzer },
    toggleObjectiveAdmin = { name = 'WO_ToggleObjectiveAdmin', key = Keyboard.KEY_NONE, callback = WO_ToggleObjectiveAdmin },
}

if ModOptions and ModOptions.AddKeyBinding then
    for _, keybind in pairs(WIT_Keybinds) do
        ModOptions:AddKeyBinding("[Wasteland]", keybind)
    end
    for _, keybind in pairs(WIT_StaffKeybinds) do
        ModOptions:AddKeyBinding("[WastelandStaff]", keybind)
    end
end

local function onKeyPressed(keynum)
    local playerObj = getSpecificPlayer(0)
    if not playerObj then return end

    for _, keybind in pairs(WIT_Keybinds) do
        if keynum == keybind.key and type(keybind.callback) == "function" then
            keybind.callback(playerObj)
            break
        end
    end
    if WL_Utils.isStaff(playerObj) then
        for _, keybind in pairs(WIT_StaffKeybinds) do
            if keynum == keybind.key and type(keybind.callback) == "function" then
                keybind.callback(playerObj)
                break
            end
        end
    end
end

Events.OnKeyPressed.Add(onKeyPressed)
