---
--- WIN_Utils.lua
--- 2025-12-03
---

WIN_Utils = {}
WIN_Utils.DEFAULT_LANGUAGE_KEY = "en"
WIN_Utils.NOTE_UID_KEY = "WIN_UID"
WIN_Utils.LAST_AUTHOR_USERNAME_KEY = "WIN_LastAuthorUsername"
WIN_Utils.DISGUISED_HANDWRITING_KEY = "WIN_IsHandwritingDisguised"
WIN_Utils.DEBUG_HANDWRITING_COMPARISONS = false
WIN_Utils.ASL_LANGUAGE_KEY = "asl"
WIN_Utils.BROKEN_ENGLISH_LANGUAGE_KEY = "pen"

local function normalizeNoteLanguageKey(languageKey)
    if languageKey == WIN_Utils.ASL_LANGUAGE_KEY or languageKey == WIN_Utils.BROKEN_ENGLISH_LANGUAGE_KEY then
        return WIN_Utils.DEFAULT_LANGUAGE_KEY
    end
    return languageKey or WIN_Utils.DEFAULT_LANGUAGE_KEY
end

local function playerHasLanguage(languageKey)
    if WRC and WRC.Meta and WRC.Meta.GetKnownLanguages then
        for _, knownLanguageKey in ipairs(WRC.Meta.GetKnownLanguages()) do
            if knownLanguageKey == languageKey then
                return true
            end
        end
    end
    return false
end

function WIN_Utils.isPaperSheet(fullType)
    if fullType == "Base.Newspaper"
        or fullType == "Base.WIN_PlayerNewspaper"
        or fullType == "Base.WIN_NewspaperDraft"
        or fullType == "Base.SheetPaper2"
        or fullType == "Base.Parchment"
        or string.sub(fullType, 1, 20) == "RPDescriptors.Pinned" then
        return true
    end
    return false
end

function WIN_Utils.isTTRPDescriptorExemptFromDarkness(fullType)
    local prefixes = {
        "TTRPDescriptors.Question",
        "TTRPDescriptors.Exclamation",
        "TTRPDescriptors.X",
        "TTRPDescriptors.O",
    }

    for _, prefix in ipairs(prefixes) do
        if string.sub(fullType, 1, #prefix) == prefix then
            return true
        end
    end

    return false
end

function WIN_Utils.isBook(fullType)
     if fullType == "Base.Notebook"
        or fullType == "Base.Book"
        or fullType == "Base.Magazine"
        or fullType == "Base.Journal"
        or fullType == "Base.NotebookLeather"
        or fullType == "Base.NotebookGrey"
        or fullType == "Base.NotebookPink" then
       return true
    end
    return false
end

function WIN_Utils.getFontKey(writeableItem)
    return writeableItem:getModData()["WIN_Font"] or WIN_Font.DefaultFont
end

function WIN_Utils.getSkinKey(writeableItem)
    if writeableItem:getFullType() == "Base.Parchment" then
        return "Base.Parchment"
    elseif WIN_Utils.isPaperSheet(writeableItem:getFullType()) then
        return writeableItem:getModData()["WIN_Skin"] or WIN_LiteratureSkin.DEFAULT_SHEET_PAPER_TYPE
    elseif WIN_Utils.isBook(writeableItem:getFullType()) then
        if WIN_LiteratureSkin.findFromKey(writeableItem:getFullType()) then
            return writeableItem:getFullType() -- The item's full type is a valid skin key itself
        end
    end
    return WIN_LiteratureSkin.DEFAULT_NOTEBOOK_TYPE
end

function WIN_Utils.setFontKey(writeableItem, fontKey)
    writeableItem:getModData()["WIN_Font"] = fontKey
end

function WIN_Utils.setSkinKey(writeableItem, skinKey)
    writeableItem:getModData()["WIN_Skin"] = skinKey
end

function WIN_Utils.hasLanguageKey(writeableItem)
    local languageKey = writeableItem:getModData()["WIN_Language"]
    return languageKey ~= nil and languageKey ~= ""
end

function WIN_Utils.getLanguageKey(writeableItem)
    if WIN_Utils.hasLanguageKey(writeableItem) then
        local storedLanguageKey = writeableItem:getModData()["WIN_Language"]
        local normalizedLanguageKey = normalizeNoteLanguageKey(storedLanguageKey)
        if normalizedLanguageKey ~= storedLanguageKey then
            writeableItem:getModData()["WIN_Language"] = normalizedLanguageKey
        end
        return normalizedLanguageKey
    end
    return WIN_Utils.DEFAULT_LANGUAGE_KEY
end

function WIN_Utils.getStoredLanguageKey(writeableItem)
    if WIN_Utils.hasLanguageKey(writeableItem) then
        local storedLanguageKey = writeableItem:getModData()["WIN_Language"]
        return normalizeNoteLanguageKey(storedLanguageKey)
    end
    return nil
end

function WIN_Utils.setLanguageKey(writeableItem, languageKey)
    writeableItem:getModData()["WIN_Language"] = normalizeNoteLanguageKey(languageKey)
end

function WIN_Utils.clearLanguageKey(writeableItem)
    writeableItem:getModData()["WIN_Language"] = nil
end

function WIN_Utils.getLastAuthorUsername(writeableItem)
    local username = writeableItem:getModData()[WIN_Utils.LAST_AUTHOR_USERNAME_KEY]
    if username ~= nil and username ~= "" then
        return username
    end
    return nil
end

function WIN_Utils.setLastAuthorUsername(writeableItem, username)
    writeableItem:getModData()[WIN_Utils.LAST_AUTHOR_USERNAME_KEY] = username
end

function WIN_Utils.clearLastAuthorUsername(writeableItem)
    writeableItem:getModData()[WIN_Utils.LAST_AUTHOR_USERNAME_KEY] = nil
end

function WIN_Utils.isHandwritingDisguised(writeableItem)
    return writeableItem:getModData()[WIN_Utils.DISGUISED_HANDWRITING_KEY] == true
end

function WIN_Utils.disguiseHandwriting(writeableItem)
    writeableItem:getModData()[WIN_Utils.DISGUISED_HANDWRITING_KEY] = true
end

function WIN_Utils.clearHandwritingDisguise(writeableItem)
    writeableItem:getModData()[WIN_Utils.DISGUISED_HANDWRITING_KEY] = nil
end

function WIN_Utils.writeHandwritingComparisonDebug(sourceItem, candidateItem, result)
    if not WIN_Utils.DEBUG_HANDWRITING_COMPARISONS then
        return
    end

    local sourceAuthor = WIN_Utils.getLastAuthorUsername(sourceItem) or "none"
    local candidateAuthor = WIN_Utils.getLastAuthorUsername(candidateItem) or "none"
    local sourceDisguised = tostring(WIN_Utils.isHandwritingDisguised(sourceItem))
    local candidateDisguised = tostring(WIN_Utils.isHandwritingDisguised(candidateItem))
    print(string.format(
        "[WastelandImmersiveNotes] Handwriting comparison: %s | source=%s | candidate=%s | sourceAuthor=%s | candidateAuthor=%s | sourceDisguised=%s | candidateDisguised=%s",
        result,
        WIN_Utils.getLogIdentity(sourceItem),
        WIN_Utils.getLogIdentity(candidateItem),
        sourceAuthor,
        candidateAuthor,
        sourceDisguised,
        candidateDisguised))
end

function WIN_Utils.canIdentifyHandwriting(player)
    if WL_Utils.isStaff(player) or not WIN_WDCIntegration.isActive() then
        return true
    end
    return WIN_WDCIntegration.hasSufficientInvestigation(player)
end

function WIN_Utils.canDisguiseHandwriting(player, authorUsername)
    if WL_Utils.isStaff(player) then
        return true
    end
    if not authorUsername or WIN_Utils.getAuthorIdentity(player) ~= authorUsername then
        return false
    end
    return WIN_WDCIntegration.isActive()
        and WIN_WDCIntegration.hasSufficientDeception(player)
end

function WIN_Utils.getAuthorIdentity(player)
    if not player then
        return nil
    end

    local username = player:getUsername()
    if not WL_Utils.isStaff(player) then
        return username
    end

    local roleplayName = WL_Utils.getRolePlayChatName(username)
    if not roleplayName or roleplayName == username then
        return nil
    end
    return roleplayName
end

function WIN_Utils.hasWrittenContent(pageContents)
    for _, pageContent in pairs(pageContents or {}) do
        if string.find(tostring(pageContent or ""), "%S") then
            return true
        end
    end
    return false
end

function WIN_Utils.hasPageContentChanges(oldPages, newPages)
    local oldPageCount = oldPages and #oldPages or 0
    local newPageCount = newPages and #newPages or 0
    local maxPageCount = math.max(oldPageCount, newPageCount)

    for i = 1, maxPageCount do
        local oldText = (oldPages and oldPages[i]) or ""
        local newText = (newPages and newPages[i]) or ""
        if oldText ~= newText then
            return true
        end
    end
    return false
end

function WIN_Utils.getNoteUID(writeableItem)
    local uid = writeableItem:getModData()[WIN_Utils.NOTE_UID_KEY]
    if uid ~= nil and uid ~= "" then
        return uid
    end
    return nil
end

function WIN_Utils.hasNoteUID(writeableItem)
    return WIN_Utils.getNoteUID(writeableItem) ~= nil
end

local function generateShortNoteUID()
    local raw = nil
    if getRandomUUID then
        raw = tostring(getRandomUUID())
        raw = string.gsub(raw, "-", "")
    else
        raw = string.format("%08x%08x", ZombRand(2147483647), ZombRand(2147483647))
    end
    return string.sub(raw, 1, 12)
end

function WIN_Utils.ensureNoteUID(writeableItem)
    local uid = WIN_Utils.getNoteUID(writeableItem)
    if uid ~= nil then
        return uid
    end
    uid = generateShortNoteUID()
    writeableItem:getModData()[WIN_Utils.NOTE_UID_KEY] = uid
    return uid
end

local function sanitizeForLog(text)
    local value = tostring(text or "")
    value = string.gsub(value, "\r\n", "\\n")
    value = string.gsub(value, "\n", "\\n")
    value = string.gsub(value, "\r", "\\n")
    value = string.gsub(value, "\"", "\\\"")
    return value
end

local function addChangedValue(changedValues, label, oldValue, newValue)
    local oldText = tostring(oldValue or "")
    local newText = tostring(newValue or "")
    if oldText ~= newText then
        table.insert(changedValues, string.format("%s: \"%s\" -> \"%s\"",
            label, sanitizeForLog(oldText), sanitizeForLog(newText)))
    end
end

local function getLogLocation(player)
    local x = 0
    local y = 0
    local z = 0
    if player then
        x = math.floor(player:getX())
        y = math.floor(player:getY())
        z = math.floor(player:getZ())
    end
    return x, y, z
end

local function writeChangedValuesLog(player, writeableItem, changedValues)
    if #changedValues == 0 then
        return false
    end

    WIN_Utils.ensureNoteUID(writeableItem)

    local username = player and player:getUsername() or "unknown"
    local x, y, z = getLogLocation(player)
    WL_Utils.writeLog("WrittenNotes", string.format(
        "%s modified %s | %s at %d,%d,%d",
        username,
        WIN_Utils.getLogIdentity(writeableItem),
        table.concat(changedValues, " | "),
        x,
        y,
        z
    ))
    return true
end

function WIN_Utils.getLogIdentity(writeableItem)
    local languageKey = WIN_Utils.getStoredLanguageKey(writeableItem) or "none"
    local uid = WIN_Utils.getNoteUID(writeableItem) or "none"
    return string.format("%s [%s | %s]", writeableItem:getName(), uid, languageKey)
end

function WIN_Utils.writeRenameLog(player, writeableItem, oldName, newName)
    if not oldName or not newName or oldName == newName then
        return
    end

    local username = player and player:getUsername() or "unknown"
    WL_Utils.writeLog("WrittenNotes", string.format("%s renamed %s from \"%s\" to \"%s\"",
        username, WIN_Utils.getLogIdentity(writeableItem), oldName, newName))
end

function WIN_Utils.writeHandwritingDisguiseLog(player, writeableItem)
    local username = player and player:getUsername() or "unknown"
    local x, y, z = getLogLocation(player)
    WL_Utils.writeLog("WrittenNotes", string.format(
        "%s disguised the handwriting on %s at %d,%d,%d",
        username,
        WIN_Utils.getLogIdentity(writeableItem),
        x,
        y,
        z))
end

function WIN_Utils.writeContentChangeLog(player, writeableItem, oldPages, newPages)
    local changedPageContents = {}
    local oldPageCount = oldPages and #oldPages or 0
    local newPageCount = newPages and #newPages or 0
    local maxPageCount = math.max(oldPageCount, newPageCount)

    for i = 1, maxPageCount do
        local oldText = (oldPages and oldPages[i]) or ""
        local newText = (newPages and newPages[i]) or ""
        if oldText ~= newText then
            table.insert(changedPageContents, string.format("Page: %d \"%s\"", i, sanitizeForLog(newText)))
        end
    end

    return writeChangedValuesLog(player, writeableItem, changedPageContents)
end

local function getNewspaperPageConfigName(pageData)
    return WIN_NewspaperData.getPageConfigName(pageData.pageConfigKey)
end

local function getNewspaperImageName(pageData)
    local imageKey = pageData.imageKey or ""
    if imageKey == "" then
        return "none"
    end

    local imageOption = WIN_NewspaperData.getImageOption(imageKey)
    if imageOption and imageOption.name then
        return imageOption.name .. " (" .. imageKey .. ")"
    end
    return imageKey
end

local function addNewspaperColumnChanges(changedValues, pageIndex, columnIndex, oldColumn, newColumn)
    local labelPrefix = string.format("Page %d Column %d ", pageIndex, columnIndex)
    addChangedValue(changedValues, labelPrefix .. "Headline", oldColumn.title, newColumn.title)
    addChangedValue(changedValues, labelPrefix .. "Author", oldColumn.author, newColumn.author)
    addChangedValue(changedValues, labelPrefix .. "Body", oldColumn.body, newColumn.body)
end

function WIN_Utils.writeNewspaperChangeLog(player, newspaperItem, oldNewspaperData, newNewspaperData)
    local oldData = WIN_NewspaperData.normalize(oldNewspaperData)
    local newData = WIN_NewspaperData.normalize(newNewspaperData)
    local changedValues = {}

    addChangedValue(changedValues, "Paper Name", oldData.paperName, newData.paperName)
    addChangedValue(changedValues, "Issue Number", oldData.issueNumber, newData.issueNumber)
    addChangedValue(changedValues, "Issue Date", oldData.issueDate, newData.issueDate)
    if oldData.pageCount ~= newData.pageCount then
        table.insert(changedValues, string.format("Page Count: %d -> %d", oldData.pageCount, newData.pageCount))
    end

    local maxPageCount = math.max(oldData.pageCount, newData.pageCount)
    for pageIndex = 1, maxPageCount do
        local oldPageData = oldData.pages[pageIndex]
        local newPageData = newData.pages[pageIndex]
        if oldPageData and newPageData and pageIndex <= oldData.pageCount and pageIndex <= newData.pageCount then
            addChangedValue(changedValues, string.format("Page %d Layout", pageIndex),
                getNewspaperPageConfigName(oldPageData), getNewspaperPageConfigName(newPageData))
            addChangedValue(changedValues, string.format("Page %d Image", pageIndex),
                getNewspaperImageName(oldPageData), getNewspaperImageName(newPageData))

            for columnIndex = 1, WIN_NewspaperData.COLUMN_COUNT do
                addNewspaperColumnChanges(
                    changedValues,
                    pageIndex,
                    columnIndex,
                    oldPageData.columns[columnIndex],
                    newPageData.columns[columnIndex]
                )
            end
        end
    end

    return writeChangedValuesLog(player, newspaperItem, changedValues)
end

function WIN_Utils.writeNewspaperPrintLog(player, draftItem, copyCount, newspaperData)
    local issueData = WIN_NewspaperData.normalize(newspaperData)
    local username = player and player:getUsername() or "unknown"
    local x, y, z = getLogLocation(player)
    WL_Utils.writeLog("WrittenNotes", string.format(
        "%s printed %d copies of %s %s from %s at %d,%d,%d",
        username,
        copyCount,
        issueData.paperName,
        WIN_NewspaperData.getIssueLabel(issueData),
        WIN_Utils.getLogIdentity(draftItem),
        x,
        y,
        z
    ))
end

function WIN_Utils.getLanguageDisplayName(languageKey)
    languageKey = languageKey or WIN_Utils.DEFAULT_LANGUAGE_KEY
    local languageData = WRC and WRC.Languages and WRC.Languages[languageKey]
    if languageData and languageData.name then
        return languageData.name
    end
    if languageKey == WIN_Utils.DEFAULT_LANGUAGE_KEY then
        return "English"
    end
    return tostring(languageKey)
end

function WIN_Utils.getLanguageLabel(languageKey)
    languageKey = languageKey or WIN_Utils.DEFAULT_LANGUAGE_KEY
    return WIN_Utils.getLanguageDisplayName(languageKey) .. " (" .. languageKey .. ")"
end

function WIN_Utils.getCurrentLanguageKey()
    local player = getPlayer()
    if WRC and WRC.Meta and WRC.Meta.GetCurrentLanguage and player then
        local languageKey = WRC.Meta.GetCurrentLanguage(player:getUsername())
        if languageKey and languageKey ~= "" then
            return normalizeNoteLanguageKey(languageKey)
        end
    end
    return WIN_Utils.DEFAULT_LANGUAGE_KEY
end

function WIN_Utils.getDefaultNoteLanguageKey()
    if WIN_Utils.canWriteLanguage(WIN_Utils.DEFAULT_LANGUAGE_KEY) then
        return WIN_Utils.DEFAULT_LANGUAGE_KEY
    end
    return WIN_Utils.getCurrentLanguageKey()
end

function WIN_Utils.getSelectableLanguages()
    local languages = {}
    local seen = {}
    if WRC and WRC.Meta and WRC.Meta.GetKnownLanguages then
        for _, languageKey in ipairs(WRC.Meta.GetKnownLanguages()) do
            languageKey = normalizeNoteLanguageKey(languageKey)
            if languageKey and not seen[languageKey] then
                seen[languageKey] = true
                table.insert(languages, languageKey)
            end
        end
    end
    if #languages == 0 then
        local currentLanguage = normalizeNoteLanguageKey(WIN_Utils.getCurrentLanguageKey())
        table.insert(languages, currentLanguage)
    end
    return languages
end

function WIN_Utils.canUnderstandLanguage(languageKey)
    languageKey = normalizeNoteLanguageKey(languageKey)
    if WRC and WRC.Meta and WRC.Meta.CanUnderstand then
        if WRC.Meta.CanUnderstand(languageKey) then
            return true
        end
        if languageKey == WIN_Utils.DEFAULT_LANGUAGE_KEY then
            if playerHasLanguage(WIN_Utils.BROKEN_ENGLISH_LANGUAGE_KEY) then
                return true
            end
            if playerHasLanguage(WIN_Utils.ASL_LANGUAGE_KEY) then
                return true
            end
            if WRC.Meta.CanUnderstand(WIN_Utils.ASL_LANGUAGE_KEY) then
                return true
            end
        end
        return false
    end
    return true
end

function WIN_Utils.canWriteLanguage(languageKey)
    languageKey = normalizeNoteLanguageKey(languageKey)
    if WRC and WRC.Meta and WRC.Meta.CanSpeak then
        if WRC.Meta.CanSpeak(languageKey) then
            return true
        end
        if languageKey == WIN_Utils.DEFAULT_LANGUAGE_KEY then
            if playerHasLanguage(WIN_Utils.BROKEN_ENGLISH_LANGUAGE_KEY) then
                return true
            end
            if playerHasLanguage(WIN_Utils.ASL_LANGUAGE_KEY) then
                return true
            end
            if WRC.Meta.CanSpeak(WIN_Utils.ASL_LANGUAGE_KEY) then
                return true
            end
        end
        return false
    end
    return true
end

function WIN_Utils.canUnderstandItem(writeableItem)
    if not WIN_Utils.hasLanguageKey(writeableItem) then
        return true
    end
    return WIN_Utils.canUnderstandLanguage(WIN_Utils.getLanguageKey(writeableItem))
end

function WIN_Utils.canWriteItem(writeableItem)
    if not WIN_Utils.hasLanguageKey(writeableItem) then
        return true
    end
    return WIN_Utils.canWriteLanguage(WIN_Utils.getLanguageKey(writeableItem))
end

function WIN_Utils.isSpecialItem(writeableItem)
    local fullType = writeableItem:getFullType()

    -- Roleplay Descriptors
    if string.sub(fullType, 1, 14) == "RPDescriptors." then
        if not (string.sub(fullType, 1, 20) == "RPDescriptors.Pinned") then
            return true
        end
    end

    -- Sketchbooks
    if fullType == "Base.WLM_Sketchbook" or fullType == "Base.WLM_Sketchpage" then
        return true
    end

    return false
end

function WIN_Utils.isComparableNote(writeableItem)
    return writeableItem:getCategory() == "Literature"
        and writeableItem:canBeWrite()
        and not WIN_NewspaperData.isNewspaperItem(writeableItem)
        and not WIN_Utils.isSpecialItem(writeableItem)
end
