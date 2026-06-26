---
--- WIN_ContextMenu.lua
--- 2025-11-27
---
require "ISInventoryPaneContextMenu"
require "ISUI/ISModalDialog"

local originalOnWriteSomething = ISInventoryPaneContextMenu.onWriteSomething

local function showUnreadableLanguageError(writeableItem)
    local languageLabel = WIN_Utils.getLanguageDisplayName((WIN_Utils.getLanguageKey(writeableItem)))
    local message = "You can't read this. It is written in " .. languageLabel .. "."
    if WL_Utils and WL_Utils.addErrorToChat then
        WL_Utils.addErrorToChat(message)
        return
    end

    local player = getPlayer()
    if player then
        player:setHaloNote(message, 255, 0, 0, 250.0)
    end
end

---@param notebook zombie.inventory.types.Literature
ISInventoryPaneContextMenu.onWriteSomething = function(notebook, editable, player)
    if not notebook or WIN_Utils.isSpecialItem(notebook) then
        originalOnWriteSomething(notebook, editable, player)
        return
    end

    if not WIN_Utils.canUnderstandItem(notebook) then
        showUnreadableLanguageError(notebook)
        return
    end

    local forceReadOnly = not editable
    if editable and not WIN_Utils.canWriteItem(notebook) then
        forceReadOnly = true
    end

    WIN_NotePaperWindow.displayFromContextMenu(notebook, forceReadOnly)
end

WIN_ContextMenu = {}

local function shouldShowEraseOption(writeableItem)
    return not WIN_Utils.canUnderstandItem(writeableItem) or not WIN_Utils.canWriteItem(writeableItem)
end

WIN_ContextMenu.createMenu = function(playerID, context, items)
	local playerObj = getSpecificPlayer(playerID)
    if not playerObj then return end

	local writeableItem = nil;
	for i, v in ipairs(items) do
		local item = v;

		if not instanceof(v, "InventoryItem") then
			item = v.items[1];
		end

        if item:getCategory() == "Literature" and item:canBeWrite() then
            writeableItem = item;
        end
	end

    if not writeableItem then return end
    if writeableItem:getLockedBy() and writeableItem:getLockedBy() ~= playerObj:getUsername() then
        return -- No permissions
	end
    if not playerObj:getInventory():getFirstTypeEvalRecurse(
        writeableItem:getFullType(), function(item) return item == writeableItem end) then
        return -- Not in their inventory
    end

	context:addOption("Rename " .. writeableItem:getName(), writeableItem, WIN_ContextMenu.onRenameLiterature, playerID)

    if WIN_Utils.isSpecialItem(writeableItem) then
        return -- No additional options for special items
    end

    local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Change Writing Style")
    local currentOption = WIN_Utils.getFontKey(writeableItem)
    for fontName, _ in pairs(WIN_Font.FONTS) do
        local option = subMenu:addOption(fontName, writeableItem, WIN_Utils.setFontKey, fontName)
        if fontName == currentOption then
            option.notAvailable = true
        end
    end

    if WIN_Utils.isPaperSheet(writeableItem:getFullType()) then
        local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Note Style")
        local currentOption = WIN_Utils.getSkinKey(writeableItem)
        for skinKey, skinData in pairs(WIN_LiteratureSkin.SHEET_PAPER_TYPES) do
            local option = subMenu:addOption(skinData.name, writeableItem, WIN_Utils.setSkinKey, skinKey)
            if skinKey == currentOption then
                option.notAvailable = true
            end
        end
    end

    if WIN_Utils.canUnderstandItem(writeableItem) then
        local currentLanguageKey = WIN_Utils.getStoredLanguageKey(writeableItem)
        local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Choose Note Language")
        for _, languageKey in ipairs(WIN_Utils.getSelectableLanguages()) do
            local option = subMenu:addOption(WIN_Utils.getLanguageLabel(languageKey), writeableItem, WIN_ContextMenu.onSetNoteLanguage, languageKey)
            if languageKey == currentLanguageKey then
                option.notAvailable = true
            end
        end
    end

    if shouldShowEraseOption(writeableItem) then
        context:addOption("Erase Contents", writeableItem, WIN_ContextMenu.confirmEraseContents, playerID)
    end

    local nearbyUsernames = {}
    local playersNearby = WL_Utils.findPlayers(
        {maxDistance = 3, zRange = 0, onlyInLOS = true, excludeSelf = true })
    local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Show To")
    for _, playerData in ipairs(playersNearby) do
        subMenu:addOption(playerData.rpName, writeableItem, WIN_ContextMenu.onShowTo, {playerData.player:getUsername()}, playerData.rpName)
        table.insert(nearbyUsernames, playerData.player:getUsername())
    end
    subMenu:addOption("Everyone Nearby", writeableItem, WIN_ContextMenu.onShowTo, nearbyUsernames)
end

function WIN_ContextMenu.onRenameLiterature(item, playerID)
	local modal = ISTextBox:new(0, 0, 330, 180, getText("Enter the new name"), item:getName(), nil, WIN_ContextMenu.onConfirmNewName, playerID, getSpecificPlayer(playerID), item)
    modal:initialise()
	modal:addToUIManager()
end

function WIN_ContextMenu.onShowTo(writeableItem, playerUsernames, rpName)
    if WRC and isClient() then
        if  WIN_Utils.isBook(writeableItem:getFullType()) then
            WRC.SendEmote("shows a notebook to " .. (rpName or "those nearby"))
        else
            WRC.SendEmote("shows a note to " .. (rpName or "those nearby"))
        end
	end

    local pageContent = writeableItem:seePage(1)
    local fontKey = WIN_Utils.getFontKey(writeableItem)
    local skinKey = WIN_Utils.getSkinKey(writeableItem)
    local languageKey = WIN_Utils.getStoredLanguageKey(writeableItem)
    WIN_Client.showPageToPlayers(playerUsernames, pageContent, fontKey, skinKey, languageKey)
end

function WIN_ContextMenu.onSetNoteLanguage(writeableItem, languageKey)
    WIN_Utils.setLanguageKey(writeableItem, languageKey)
end

function WIN_ContextMenu.confirmEraseContents(writeableItem, playerID)
    local message = "Erase all contents from " .. writeableItem:getName() .. "?\n\nThis will clear every page and remove the note language until someone writes in it again."
    local modal = ISModalDialog:new(0, 0, 420, 160, message, true, nil, WIN_ContextMenu.onConfirmEraseContents, playerID, getSpecificPlayer(playerID), writeableItem)
    modal:initialise()
    modal:addToUIManager()
end

function WIN_ContextMenu.onConfirmEraseContents(_, button, player, writeableItem)
    if button.internal ~= "YES" then
        return
    end
    if not player or not writeableItem then
        return
    end

    local customPages = writeableItem:getCustomPages()
    local pageCount = writeableItem:getPageToWrite()
    if customPages and customPages:size() > pageCount then
        pageCount = customPages:size()
    end
    if pageCount < 1 then
        pageCount = 1
    end

    for i = 1, pageCount do
        writeableItem:addPage(i, "")
    end
    WIN_Utils.clearLanguageKey(writeableItem)

    local pdata = getPlayerData(player:getPlayerNum())
    if pdata then
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end
end

function WIN_ContextMenu:onConfirmNewName(button, player, item)
	if button.internal == "OK" then
		if button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
            local oldName = item:getName()
            local newName = button.parent.entry:getText()
			item:setName(newName)
            item:setCustomName(true)
            WIN_Utils.writeRenameLog(player, item, oldName, newName)
			local pdata = getPlayerData(player:getPlayerNum())
			pdata.playerInventory:refreshBackpacks()
			pdata.lootInventory:refreshBackpacks()
		end
	end
end


Events.OnPreFillInventoryObjectContextMenu.Add(WIN_ContextMenu.createMenu)
