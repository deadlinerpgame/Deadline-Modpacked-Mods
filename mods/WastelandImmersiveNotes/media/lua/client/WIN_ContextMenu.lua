---
--- WIN_ContextMenu.lua
--- 2025-11-27
---
require "ISInventoryPaneContextMenu"
require "ISUI/ISModalDialog"
require "ISUI/ISTextBox"
require "UI/WIN_NewspaperWindow"
require "WIN_NewspaperData"
require "WIN_WDCIntegration"

local originalOnWriteSomething = ISInventoryPaneContextMenu.onWriteSomething
local SHEET_PAPER_FULL_TYPE = "Base.SheetPaper2"
local PRINT_COPY_COUNTS = { 1, 2, 5, 10, 20 }
local HANDWRITING_MATCH_COLOR = "0.5,0.75,0.5"
local HANDWRITING_MISMATCH_COLOR = "0.75,0.5,0.5"

local function getWdcAbilityIconTexture(ability)
    if not WIN_WDCIntegration.isActive() then
        return nil
    end
    return getTexture("media/ui/" .. ability.iconName .. ".png")
end

local function configureHandwritingComparisonOption(option, player)
    if not WIN_WDCIntegration.isActive() then
        return true
    end

    option.iconTexture = getWdcAbilityIconTexture(WDC_Ability.Investigation)
    if WIN_Utils.canIdentifyHandwriting(player) then
        return true
    end

    option.notAvailable = true
    option.toolTip = ISInventoryPaneContextMenu.addToolTip()
    option.toolTip:setName("Compare Handwriting")
    option.toolTip.description = "Requires Investigation " .. tostring(WIN_WDCIntegration.INVESTIGATION_REQUIRED) .. "."
    return false
end

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
    if not notebook then
        originalOnWriteSomething(notebook, editable, player)
        return
    end

    if WIN_NewspaperData.isPlayerNewspaper(notebook) then
        WIN_NewspaperWindow.displayFromContextMenu(notebook, true)
        return
    end

    if WIN_NewspaperData.isNewspaperDraft(notebook) then
        if editable then
            WIN_NewspaperWindow.displayFromContextMenu(notebook, false)
        end
        return
    end

    if WIN_NewspaperData.isNewspaperCharter(notebook) then
        return
    end

    if WIN_Utils.isSpecialItem(notebook) then
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

local function getSelectedInventoryItem(itemData)
    local item = itemData
    if not instanceof(itemData, "InventoryItem") then
        item = itemData.items[1]
    end
    return item
end

local function findSelectedNewspaperItem(items)
    for _, v in ipairs(items) do
        local item = getSelectedInventoryItem(v)
        if WIN_NewspaperData.isNewspaperItem(item) then
            return item
        end
    end
    return nil
end

local function findWriteableItem(items)
	local writeableItem = nil;
	for i, v in ipairs(items) do
		local item = getSelectedInventoryItem(v)

        if item:getCategory() == "Literature"
            and item:canBeWrite()
            and not WIN_NewspaperData.isNewspaperItem(item) then
            writeableItem = item;
        end
	end
    return writeableItem
end

local function isInPlayerInventory(item, player)
    local container = item:getContainer()
    return container and (container == player:getInventory() or container:isInCharacterInventory(player))
end

local function isInSimpleShopInventory(item)
    local container = item:getContainer()
    local containingItem = container and container:getContainingItem()
    return WSS and containingItem and WSS:isSimpleShop(containingItem)
end

local function refreshInventory(player)
    local pdata = getPlayerData(player:getPlayerNum())
    if pdata then
        pdata.playerInventory:refreshBackpacks()
        pdata.lootInventory:refreshBackpacks()
    end
end

local function canEditNewspaper(newspaperItem, playerObj)
    if not isInPlayerInventory(newspaperItem, playerObj) then
        return false
    end
    if newspaperItem:getLockedBy() and newspaperItem:getLockedBy() ~= playerObj:getUsername() then
        return false
    end
    local playerInv = playerObj:getInventory()
    return playerInv:containsTagRecurse("Write")
        or playerInv:containsTagRecurse("BluePen")
        or playerInv:containsTagRecurse("Pen")
        or playerInv:containsTagRecurse("Pencil")
        or playerInv:containsTagRecurse("RedPen")
end

local function canSetCharterName(charterItem, playerObj)
    if not isInPlayerInventory(charterItem, playerObj) then
        return false
    end

    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    return charterData.paperName == "" or WL_Utils.isStaff(playerObj)
end

local function addShowToMenu(context, writeableItem)
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

local function addHandwritingComparisonMenu(context, sourceItem, playerObj)
    local comparableItems = playerObj:getInventory():getAllEvalRecurse(function(item)
        return item ~= sourceItem and WIN_Utils.isComparableNote(item)
    end)
    if comparableItems:size() == 0 then
        return
    end

    local subMenu, option = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Compare Handwriting")
    if not configureHandwritingComparisonOption(option, playerObj) then
        return
    end
    for i = 0, comparableItems:size() - 1 do
        local candidateItem = comparableItems:get(i)
        subMenu:addOption(candidateItem:getName(), sourceItem, WIN_ContextMenu.onCompareHandwriting, candidateItem)
    end
end

local function addCharterOptions(context, charterItem, playerObj, playerID)
    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    if canSetCharterName(charterItem, playerObj) then
        context:addOption("Set Newspaper Name", charterItem, WIN_ContextMenu.onSetNewspaperName, playerID)
    end

    if charterData.paperName ~= "" then
        context:addOption("Create Draft", charterItem, WIN_ContextMenu.onCreateNewspaperDraft, playerID)
    end
end

local function addNewspaperPageCountOptions(context, draftItem, playerObj, playerID)
    if not canEditNewspaper(draftItem, playerObj) then
        return
    end

    local newspaperData = WIN_NewspaperData.loadFromItem(draftItem)
    local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Total Pages")
    for pageCount = WIN_NewspaperData.MIN_PAGE_COUNT, WIN_NewspaperData.MAX_PAGE_COUNT do
        local label = tostring(pageCount) .. " Pages"
        if pageCount == 1 then
            label = "1 Page"
        end
        local option = subMenu:addOption(label, draftItem, WIN_ContextMenu.onSetNewspaperPageCount, pageCount, playerID)
        if pageCount == newspaperData.pageCount then
            option.notAvailable = true
        end
    end
end

local function addPrintCopyOptions(context, draftItem, playerObj, playerID)
    if not isInPlayerInventory(draftItem, playerObj) then
        return
    end
    if draftItem:getLockedBy() and draftItem:getLockedBy() ~= playerObj:getUsername() then
        return
    end

    local sheetCount = playerObj:getInventory():getCountTypeRecurse(SHEET_PAPER_FULL_TYPE)
    local subMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Print Copies")
    for _, copyCount in ipairs(PRINT_COPY_COUNTS) do
        local label = tostring(copyCount) .. " Copies"
        if copyCount == 1 then
            label = "1 Copy"
        end
        local option = subMenu:addOption(label, draftItem, WIN_ContextMenu.onPrintNewspaperCopies, copyCount, playerID)
        option.toolTip = ISInventoryPaneContextMenu.addToolTip()
        option.toolTip:setName(label)
        option.toolTip.description = "Costs " .. tostring(copyCount) .. " sheets of paper."
        if sheetCount < copyCount then
            option.notAvailable = true
            option.toolTip.description = "<RGB:1,0,0>Requires " .. tostring(copyCount)
                .. " sheets of paper. You have " .. tostring(sheetCount) .. "."
        end
    end
end

WIN_ContextMenu.createMenu = function(playerID, context, items)
	local playerObj = getSpecificPlayer(playerID)
    if not playerObj then return end

    local newspaperItem = findSelectedNewspaperItem(items)
    if newspaperItem then
        if WIN_NewspaperData.isNewspaperCharter(newspaperItem) then
            if isInPlayerInventory(newspaperItem, playerObj) then
                addCharterOptions(context, newspaperItem, playerObj, playerID)
            end
            return
        end

        if WIN_NewspaperData.isNewspaperDraft(newspaperItem) then
            if isInPlayerInventory(newspaperItem, playerObj) then
                addNewspaperPageCountOptions(context, newspaperItem, playerObj, playerID)
                addPrintCopyOptions(context, newspaperItem, playerObj, playerID)
            end
            return
        end

        if WIN_NewspaperData.isPlayerNewspaper(newspaperItem) then
            if isInPlayerInventory(newspaperItem, playerObj) then
                addShowToMenu(context, newspaperItem)
            end
            return
        end
    end

    local writeableItem = findWriteableItem(items)

    if not writeableItem then return end
    if not isInPlayerInventory(writeableItem, playerObj) then
        return -- Not in their inventory
    end
    if writeableItem:getLockedBy() and writeableItem:getLockedBy() ~= playerObj:getUsername() then
        if WIN_Utils.isComparableNote(writeableItem) then
            addHandwritingComparisonMenu(context, writeableItem, playerObj)
        end
        return -- No permissions
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

    if WIN_Utils.isPaperSheet(writeableItem:getFullType()) and writeableItem:getFullType() ~= "Base.Parchment" then
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

    if WIN_Utils.isComparableNote(writeableItem) then
        addHandwritingComparisonMenu(context, writeableItem, playerObj)
    end

    local authorUsername = WIN_Utils.getLastAuthorUsername(writeableItem)
    if WIN_Utils.canDisguiseHandwriting(playerObj, authorUsername) then
        local optionName = "Disguise Handwriting"
        local callback = WIN_ContextMenu.onDisguiseHandwriting
        if WIN_Utils.isHandwritingDisguised(writeableItem) then
            optionName = "Restore Normal Handwriting"
            callback = WIN_ContextMenu.onRestoreHandwriting
        end
        local option = context:addOption(optionName, writeableItem, callback)
        option.iconTexture = getWdcAbilityIconTexture(WDC_Ability.Deception)
    end

    addShowToMenu(context, writeableItem)
end

function WIN_ContextMenu.onRenameLiterature(item, playerID)
	local modal = ISTextBox:new(0, 0, 330, 180, getText("Enter the new name"), item:getName(), nil, WIN_ContextMenu.onConfirmNewName, playerID, getSpecificPlayer(playerID), item)
    modal:initialise()
	modal:addToUIManager()
end

function WIN_ContextMenu.onOpenNewspaper(writeableItem, forceReadOnly, playerID)
    WIN_NewspaperWindow.displayFromContextMenu(writeableItem, forceReadOnly)
end

function WIN_ContextMenu.onSetNewspaperName(charterItem, playerID)
    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    local modal = ISTextBox:new(
        0,
        0,
        360,
        180,
        "Newspaper name",
        charterData.paperName,
        nil,
        WIN_ContextMenu.onConfirmNewspaperName,
        playerID,
        getSpecificPlayer(playerID),
        charterItem
    )
    modal.maxChars = 60
    modal.noEmpty = true
    modal:initialise()
    modal.entry:setMaxTextLength(60)
    modal:addToUIManager()
end

function WIN_ContextMenu.onCreateNewspaperDraft(charterItem, playerID)
    local player = getSpecificPlayer(playerID)
    if not player or not charterItem or not isInPlayerInventory(charterItem, player) then
        return
    end

    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    if charterData.paperName == "" then
        return
    end

    WIN_NewspaperData.createDraftFromCharter(charterItem, player)
    refreshInventory(player)
end

function WIN_ContextMenu.onSetNewspaperPageCount(draftItem, pageCount, playerID)
    local player = getSpecificPlayer(playerID)
    if not player
        or not draftItem
        or not WIN_NewspaperData.isNewspaperDraft(draftItem)
        or not canEditNewspaper(draftItem, player) then
        return
    end

    WIN_NewspaperData.setPageCount(draftItem, pageCount)
    refreshInventory(player)
end

local function removeSheetPaper(player, sheetCount)
    local sheetItems = player:getInventory():getAllTypeRecurse(SHEET_PAPER_FULL_TYPE)
    if sheetItems:size() < sheetCount then
        return false
    end

    for i = 1, sheetCount do
        local sheetItem = sheetItems:get(i - 1)
        sheetItem:getContainer():Remove(sheetItem)
    end

    return true
end

function WIN_ContextMenu.onPrintNewspaperCopies(draftItem, copyCount, playerID)
    local player = getSpecificPlayer(playerID)
    if not player
        or not draftItem
        or not WIN_NewspaperData.isNewspaperDraft(draftItem)
        or not isInPlayerInventory(draftItem, player) then
        return
    end
    if draftItem:getLockedBy() and draftItem:getLockedBy() ~= player:getUsername() then
        return
    end

    local normalizedCopyCount = math.floor(tonumber(copyCount) or 0)
    if normalizedCopyCount < 1 then
        return
    end

    if not removeSheetPaper(player, normalizedCopyCount) then
        player:Say("I need more sheets of paper.")
        return
    end

    local draftData = WIN_NewspaperData.loadFromItem(draftItem)
    for i = 1, normalizedCopyCount do
        WIN_NewspaperData.createPrintedCopyFromDraft(draftItem, player)
    end
    WIN_Utils.writeNewspaperPrintLog(player, draftItem, normalizedCopyCount, draftData)
    refreshInventory(player)
end

function WIN_ContextMenu.onShowTo(writeableItem, playerUsernames, rpName)
    if WRC and isClient() then
        if WIN_NewspaperData.isPlayerNewspaper(writeableItem) then
            WRC.SendEmote("shows a newspaper to " .. (rpName or "those nearby"))
        elseif  WIN_Utils.isBook(writeableItem:getFullType()) then
            WRC.SendEmote("shows a notebook to " .. (rpName or "those nearby"))
        else
            WRC.SendEmote("shows a note to " .. (rpName or "those nearby"))
        end
	end

    if WIN_NewspaperData.isPlayerNewspaper(writeableItem) then
        WIN_Client.showNewspaperToPlayers(playerUsernames, WIN_NewspaperData.loadFromItem(writeableItem))
        return
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

function WIN_ContextMenu.onCompareHandwriting(sourceItem, candidateItem)
    if not WIN_Utils.canIdentifyHandwriting(getPlayer()) then
        WL_Utils.addInfoToChat("You need Investigation "
            .. tostring(WIN_WDCIntegration.INVESTIGATION_REQUIRED) .. " to compare handwriting.")
        return
    end

    local sourceAuthor = WIN_Utils.getLastAuthorUsername(sourceItem)
    local candidateAuthor = WIN_Utils.getLastAuthorUsername(candidateItem)
    if not sourceAuthor or not candidateAuthor then
        WIN_Utils.writeHandwritingComparisonDebug(sourceItem, candidateItem, "insufficient author information")
        WL_Utils.addInfoToChat("There is not enough handwriting information to compare these notes.")
    elseif WIN_Utils.isHandwritingDisguised(sourceItem)
        or WIN_Utils.isHandwritingDisguised(candidateItem) then
        WIN_Utils.writeHandwritingComparisonDebug(sourceItem, candidateItem, "does not match: disguised handwriting")
        WL_Utils.addToChat("The handwriting does not match.", {color = HANDWRITING_MISMATCH_COLOR})
    elseif sourceAuthor == candidateAuthor then
        WIN_Utils.writeHandwritingComparisonDebug(sourceItem, candidateItem, "matches")
        WL_Utils.addToChat("The handwriting matches.", {color = HANDWRITING_MATCH_COLOR})
    else
        WIN_Utils.writeHandwritingComparisonDebug(sourceItem, candidateItem, "does not match: different authors")
        WL_Utils.addToChat("The handwriting does not match.", {color = HANDWRITING_MISMATCH_COLOR})
    end
end

function WIN_ContextMenu.onDisguiseHandwriting(writeableItem)
    local player = getPlayer()
    local authorUsername = WIN_Utils.getLastAuthorUsername(writeableItem)
    if WIN_Utils.canDisguiseHandwriting(player, authorUsername) then
        WIN_Utils.disguiseHandwriting(writeableItem)
        WIN_Utils.writeHandwritingDisguiseLog(player, writeableItem)
    end
end

function WIN_ContextMenu.onRestoreHandwriting(writeableItem)
    local player = getPlayer()
    local authorUsername = WIN_Utils.getLastAuthorUsername(writeableItem)
    if WIN_Utils.canDisguiseHandwriting(player, authorUsername) then
        WIN_Utils.clearHandwritingDisguise(writeableItem)
    end
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
    WIN_Utils.clearLastAuthorUsername(writeableItem)
    WIN_Utils.clearHandwritingDisguise(writeableItem)

    refreshInventory(player)
end

function WIN_ContextMenu:onConfirmNewName(button, player, item)
	if button.internal == "OK" then
		if button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
            local oldName = item:getName()
            local newName = button.parent.entry:getText()
			item:setName(newName)
            item:setCustomName(true)
            if oldName ~= newName and WIN_Utils.isComparableNote(item) then
                local authorIdentity = WIN_Utils.getAuthorIdentity(player)
                if authorIdentity then
                    WIN_Utils.setLastAuthorUsername(item, authorIdentity)
                end
            end
            WIN_Utils.writeRenameLog(player, item, oldName, newName)
			refreshInventory(player)
		end
	end
end

function WIN_ContextMenu.onConfirmNewspaperName(_, button, player, charterItem)
    if button.internal ~= "OK" then
        return
    end
    if not player
        or not charterItem
        or not WIN_NewspaperData.isNewspaperCharter(charterItem)
        or not canSetCharterName(charterItem, player) then
        return
    end

    local newName = string.trim(button.parent.entry:getText() or "")
    if newName == "" then
        return
    end

    local oldData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    if oldData.paperName == newName then
        return
    end

    local oldName = charterItem:getName()
    WIN_NewspaperData.setCharterName(charterItem, newName)
    WIN_Utils.writeRenameLog(player, charterItem, oldName, charterItem:getName())

    refreshInventory(player)
end

function WIN_ContextMenu.updateNewspaperReadWriteOptions(playerID, context, items)
	local playerObj = getSpecificPlayer(playerID)
    if not playerObj then return end

    local newspaperItem = findSelectedNewspaperItem(items)
    if not newspaperItem or WIN_NewspaperData.isNewspaperCharter(newspaperItem) then
        if newspaperItem then
            context:removeOptionByName(getText("ContextMenu_Read"))
        end
        return
    end

    context:removeOptionByName(getText("ContextMenu_Read"))
    context:removeOptionByName(getText("ContextMenu_Read_Note", newspaperItem:getName()))
    context:removeOptionByName(getText("ContextMenu_Write_Note", newspaperItem:getName()))

    if WIN_NewspaperData.isPlayerNewspaper(newspaperItem) then
        if isInSimpleShopInventory(newspaperItem) then
            WL_ContextMenuUtils.missingRequirement(
                context,
                "Read Newspaper",
                "You need to buy this newspaper first.")
            return
        end
        context:addOption("Read Newspaper", newspaperItem, WIN_ContextMenu.onOpenNewspaper, true, playerID)
        return
    end

    if WIN_NewspaperData.isNewspaperDraft(newspaperItem) and canEditNewspaper(newspaperItem, playerObj) then
        context:addOption("Write Draft", newspaperItem, WIN_ContextMenu.onOpenNewspaper, false, playerID)
    end
end


Events.OnPreFillInventoryObjectContextMenu.Add(WIN_ContextMenu.createMenu)
Events.OnFillInventoryObjectContextMenu.Add(WIN_ContextMenu.updateNewspaperReadWriteOptions)
