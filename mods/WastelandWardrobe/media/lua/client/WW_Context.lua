---
--- WW_Context.lua
--- 21/10/2024
---

require "WL_Utils"
require "WW_Wardrobes"
require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"

require "WL_Utils"
require "WW_Wardrobes"
require "ISUI/ISPanel"
require "ISUI/ISUIElement"
require "ISUI/ISTextEntryBox"
require "ISUI/ISLabel"

if WW_Context then
    Events.OnFillWorldObjectContextMenu.Remove(WW_Context.contextMenuAdd)
end
WW_Context = {}

local function getAvailableStorageOptions()
    return {
        {CN = "Wardrobe", GN = "none"},
        {CN = "Drawers", GN = "none"},
        {CN = "Rack", GN = "none"},
        {CN = "Clothes Stand", GN = "none"},
        {CN = "Locker", GN = "Yellow Wall"},
        {CN = "Locker", GN = "Blue Wall"},
        {CN = "Locker", GN = "Green Wall"},
        {CN = "Locker", GN = "Red Wall"},
        {CN = "Locker", GN = "none"},
        {CN = "Locker", GN = "Green Military"},
        {CN = "Shelves", GN = "Big Wall"},
    }
end

local function isValidFurniture(obj)
    if obj and obj:getSprite() then
        local properties = obj:getSprite():getProperties()
        if properties then
            for _, option in ipairs(getAvailableStorageOptions()) do
                -- Debugging (optional): 
                --print(properties:Val("CustomName"), properties:Val("GroupName"))
                if ((properties:Val("CustomName") == option.CN) or (option.CN == "none")) and 
                   ((properties:Val("GroupName") == option.GN) or (option.GN == "none")) then
                    return true
                end
            end
        end
    end
    return false
end

local function getFurniture(sq)
    if sq then
        for i = 0, sq:getObjects():size() - 1 do
            local obj = sq:getObjects():get(i)
            if isValidFurniture(obj) then
                return obj
            end
        end
    end
    return nil
end

local function tableHasEntries(t)
    if type(t) == "table" then
        for _ in pairs(t) do
            return true
        end
    end
    return false
end

local function changeName(playerObj, wardrobeKey, wardrobes, oldDisplayName, currentClothing, callback)
    local scale = getTextManager():getFontHeight(UIFont.Small) / 14
    local width = 250 * scale
    local height = 130 * scale
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)
    local modal
    local success

    modal = ISTextBox:new(x, y, width, height, getText("UI_WW_NameWardrobe"), oldDisplayName or "", nil, function(_, button)
        if button.internal == "OK" then
            local newName = button.target.entry:getText()
            if newName and newName:trim() ~= "" then
                local newKey = "WW_Wardrobe" .. newName
                if not wardrobes[newKey] then
                    if wardrobeKey then
                        wardrobes[newKey] = wardrobes[wardrobeKey]
                        wardrobes[wardrobeKey] = nil
                    else
                        wardrobes[newKey] = currentClothing
                    end
                    WW_Wardrobes.setWardrobe(playerObj, newKey, wardrobes[newKey]) 
                    playerObj:Say(wardrobeKey and (getText("UI_WW_RenameWardrobe") .. newName) or (getText("UI_WW_SaveWardrobe") .. newName))
                    success = true
                else
                    playerObj:Say(getText("UI_WW_WardrobeExists"))
                    success = false
                end
            else
                playerObj:Say(getText("UI_WW_EmptyName"))
                success = false
            end
        else
            success = false
        end

        modal:removeFromUIManager()
        if callback then
            callback(success)
        end
    end)

    modal:initialise()
    modal:addToUIManager()
end

local function checkIfWearingWardrobe(playerObj, wardrobe)
    local wornItems = WW_Wardrobes.getWornItems(playerObj)
    local matchedItemsCount = 0

    local function itemsMatch(wornItem, wardrobeItem)
        return wornItem.itemType == wardrobeItem.itemType and
               wornItem.tintRed == wardrobeItem.tintRed and
               wornItem.tintGreen == wardrobeItem.tintGreen and
               wornItem.tintBlue == wardrobeItem.tintBlue and
               wornItem.tintAlpha == wardrobeItem.tintAlpha and
               wornItem.baseTexture == wardrobeItem.baseTexture and
               wornItem.textureChoice == wardrobeItem.textureChoice and
               (wornItem.decal or "") == (wardrobeItem.decal or "")
    end

    for _, wardrobeItemData in ipairs(wardrobe) do
        for _, wornItemData in ipairs(wornItems) do
            if itemsMatch(wornItemData, wardrobeItemData) then
                matchedItemsCount = matchedItemsCount + 1
                break
            end
        end
    end
    return matchedItemsCount == #wardrobe and #wornItems == #wardrobe
end

local function addSaveWardrobeOption(submenu, playerObj, wardrobes)
    submenu:addOption(getText("UI_WW_SaveCurrent"), playerObj, function()
        local currentClothing = WW_Wardrobes.getWornItems(playerObj)
        local wardrobeCount = 0
        for _ in pairs(wardrobes) do
            wardrobeCount = wardrobeCount + 1
        end

        if wardrobeCount >= 10 then
            playerObj:Say(getText("UI_WW_WardrobeLimit"))
        else
            changeName(playerObj, nil, wardrobes, nil, currentClothing)
        end
    end)
end

local function updateWardrobe(playerObj, wardrobeKey)
    local wardrobes = WW_Wardrobes.getWardrobes(playerObj)
    local currentClothing = WW_Wardrobes.getWornItems(playerObj)
    wardrobes[wardrobeKey] = currentClothing
    WW_Wardrobes.setWardrobe(playerObj, wardrobeKey, currentClothing)
    playerObj:Say(getText("UI_WW_WardrobeUpdated"))
end

local function addWardrobeOptions(playerObj, submenu, wardrobe, wardrobes, displayName, name)
    local wardrobeSubMenu = WL_ContextMenuUtils.getOrCreateSubMenu(submenu, displayName)
    local isWearingExactWardrobe = checkIfWearingWardrobe(playerObj, wardrobe)

    local option = wardrobeSubMenu:addOption(getText("UI_WW_Wear"), playerObj, function()
        WW_Wardrobes.wearWardrobe(playerObj, wardrobe)
    end)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip:setVisible(false)
    tooltip:setName(getText("UI_WW_WearOutfit"))
    option.toolTip = tooltip
    tooltip.description = ""
    for _, item in ipairs(wardrobe) do
        tooltip.description = tooltip.description .. getItemNameFromFullType(item.itemType) .. "\n"
    end

    if isWearingExactWardrobe then
        option.notAvailable = true
        tooltip.description = getText("UI_WW_AlreadyWearing")
    end

    wardrobeSubMenu:addOption(getText("UI_WW_ChangeName"), playerObj, function()
        changeName(playerObj, name, wardrobes, displayName)
    end)

    wardrobeSubMenu:addOption(getText("UI_WW_Update"), playerObj, function()
        local scale = getTextManager():getFontHeight(UIFont.Small) / 14
        local width = 300 * scale
        local height = 100 * scale
        local x = (getCore():getScreenWidth() / 2) - (width / 2)
        local y = (getCore():getScreenHeight() / 2) - (height / 2)
        local modal = ISModalDialog:new(x, y, width, height, getText("UI_WW_ConfirmUpdate") .. displayName .. getText("UI_WW_QuestionMark"), true, nil, function(_, button)
            if button.internal == "YES" then
                updateWardrobe(playerObj, name)
            end
        end)
        modal:initialise()
        modal:addToUIManager()
    end)

    wardrobeSubMenu:addOption(getText("UI_WW_Remove"), playerObj, function()
        local scale = getTextManager():getFontHeight(UIFont.Small) / 14
        local width = 300 * scale
        local height = 100 * scale
        local x = (getCore():getScreenWidth() / 2) - (width / 2)
        local y = (getCore():getScreenHeight() / 2) - (height / 2)
        local modal = ISModalDialog:new(x, y, width, height, getText("UI_WW_ConfirmRemove") .. displayName .. getText("UI_WW_QuestionMark"), true, nil, function(_, button)
            if button.internal == "YES" then
                WW_Wardrobes.deletePlayerWardrobe(playerObj, name)
                playerObj:Say(getText("UI_WW_Wardrobe") .. displayName .. getText("UI_WW_Removed"))
            end
        end)
        modal:initialise()
        modal:addToUIManager()
    end)
end

function WW_Context.contextMenuAdd(player, context, worldobjects)
    if not worldobjects or not worldobjects[1] then return end
    local clickedSquare = worldobjects[1]:getSquare()
    local furniture = getFurniture(clickedSquare)
    if not furniture then return end

    local playerObj = getSpecificPlayer(player)
    local submenu = WL_ContextMenuUtils.getOrCreateSubMenuOnTop(context, getText("UI_WW_PlayerWardrobes"))
    local wardrobes = WW_Wardrobes.getWardrobes(playerObj)

    if tableHasEntries(wardrobes) then
        for name, wardrobe in pairs(wardrobes) do
            local displayName = name:gsub("WW_Wardrobe", "")
            addWardrobeOptions(playerObj, submenu, wardrobe, wardrobes, displayName, name)
        end
    else
        WL_ContextMenuUtils.missingRequirement(submenu, getText("UI_WW_NoWardrobes"), getText("UI_WW_NoneSaved"))
    end

    addSaveWardrobeOption(submenu, playerObj, wardrobes)

    if playerObj:isGodMod() then
        submenu:addOption(getText("UI_WW_ClearAll"), playerObj, function()
            WW_Wardrobes.deleteAllWardrobes(playerObj)
            playerObj:Say(getText("UI_WW_ConfirmAll"))
        end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(WW_Context.contextMenuAdd)
