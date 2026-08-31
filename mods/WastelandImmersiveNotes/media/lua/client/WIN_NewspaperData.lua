---
--- WIN_NewspaperData.lua
--- 2026-06-30
---

require "WIN_NewspaperPageConfigs"
require "WIN_Utils"

WIN_NewspaperData = {}

WIN_NewspaperData.CHARTER_FULL_TYPE = "Base.WIN_NewspaperCharter"
WIN_NewspaperData.DRAFT_FULL_TYPE = "Base.WIN_NewspaperDraft"
WIN_NewspaperData.PLAYER_NEWSPAPER_FULL_TYPE = "Base.WIN_PlayerNewspaper"
WIN_NewspaperData.VERSION = 3
WIN_NewspaperData.CHARTER_VERSION = 1
WIN_NewspaperData.MIN_PAGE_COUNT = 1
WIN_NewspaperData.MAX_PAGE_COUNT = 8
WIN_NewspaperData.COLUMN_COUNT = WIN_NewspaperPageConfigs.COLUMN_COUNT
WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE = WIN_NewspaperPageConfigs.NEW_ARTICLE_COLUMN_TYPE
WIN_NewspaperData.CONTINUED_ARTICLE_COLUMN_TYPE = WIN_NewspaperPageConfigs.CONTINUED_ARTICLE_COLUMN_TYPE
WIN_NewspaperData.DEFAULT_PAGE_CONFIG_KEY = WIN_NewspaperPageConfigs.DEFAULT_PAGE_CONFIG_KEY
WIN_NewspaperData.PAGE_LAYOUT = WIN_NewspaperPageConfigs.PAGE_LAYOUT
WIN_NewspaperData.PAGE_CONFIGS = WIN_NewspaperPageConfigs.PAGE_CONFIGS
WIN_NewspaperData.PAGE_CONFIG_ORDER = WIN_NewspaperPageConfigs.PAGE_CONFIG_ORDER

local DATA_KEY = "WIN_Newspaper_Data"
local CHARTER_DATA_KEY = "WIN_Newspaper_CharterData"
local DEFAULT_HEADLINE_TEXT = "ARTICLE HEADLINE GOES HERE"
local DEFAULT_AUTHOR_TEXT = "By Author Name"
local DEFAULT_BODY_TEXT = "Article content here"
local MONTH_NAMES = {
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
}

local function getTextValue(value, fallback)
    if value == nil then
        return fallback or ""
    end
    return tostring(value)
end

local function trimText(value)
    local text = getTextValue(value)
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function clampPageCount(pageCount)
    local numericPageCount = math.floor(tonumber(pageCount) or WIN_NewspaperData.MIN_PAGE_COUNT)
    if numericPageCount < WIN_NewspaperData.MIN_PAGE_COUNT then
        return WIN_NewspaperData.MIN_PAGE_COUNT
    end
    if numericPageCount > WIN_NewspaperData.MAX_PAGE_COUNT then
        return WIN_NewspaperData.MAX_PAGE_COUNT
    end
    return numericPageCount
end

local function clampIssueNumber(issueNumber)
    local numericIssueNumber = math.floor(tonumber(issueNumber) or 1)
    if numericIssueNumber < 1 then
        return 1
    end
    return numericIssueNumber
end

local function getItemPageCount(newspaperItem, storedPageCount)
    if storedPageCount ~= nil then
        return clampPageCount(storedPageCount)
    end
    if newspaperItem then
        return clampPageCount(newspaperItem:getPageToWrite())
    end
    return WIN_NewspaperData.MIN_PAGE_COUNT
end

local function getDefaultTitle(columnType)
    if columnType == WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE then
        return DEFAULT_HEADLINE_TEXT
    end
    return ""
end

local function getDefaultAuthor(columnType)
    if columnType == WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE then
        return DEFAULT_AUTHOR_TEXT
    end
    return ""
end

local function isFirstPage(pageIndex)
    return tonumber(pageIndex) == 1
end

local function getFullType(itemOrFullType)
    if type(itemOrFullType) == "string" then
        return itemOrFullType
    end
    if itemOrFullType then
        return itemOrFullType:getFullType()
    end
    return nil
end

local function getDisplayPaperName(paperName)
    local displayName = trimText(paperName)
    if displayName == "" then
        return "Newspaper"
    end
    return displayName
end

function WIN_NewspaperData.getPageConfig(pageConfigKey)
    return WIN_NewspaperData.PAGE_CONFIGS[pageConfigKey]
        or WIN_NewspaperData.PAGE_CONFIGS[WIN_NewspaperData.DEFAULT_PAGE_CONFIG_KEY]
end

function WIN_NewspaperData.getPageConfigName(pageConfigKey)
    return WIN_NewspaperData.getPageConfig(pageConfigKey).name
end

function WIN_NewspaperData.isPageConfigValidForPage(pageIndex, pageConfigKey)
    local pageConfig = WIN_NewspaperData.PAGE_CONFIGS[pageConfigKey]
    if not pageConfig then
        return false
    end

    if isFirstPage(pageIndex) then
        return pageConfig.validForFirstPage == true
    end
    return true
end

function WIN_NewspaperData.getPageConfigOrder(pageIndex)
    local pageConfigOrder = {}
    for _, pageConfigKey in ipairs(WIN_NewspaperData.PAGE_CONFIG_ORDER) do
        if WIN_NewspaperData.isPageConfigValidForPage(pageIndex, pageConfigKey) then
            table.insert(pageConfigOrder, pageConfigKey)
        end
    end
    return pageConfigOrder
end

function WIN_NewspaperData.getDefaultPageConfigKey(pageIndex)
    if WIN_NewspaperData.isPageConfigValidForPage(pageIndex, WIN_NewspaperData.DEFAULT_PAGE_CONFIG_KEY) then
        return WIN_NewspaperData.DEFAULT_PAGE_CONFIG_KEY
    end

    local pageConfigOrder = WIN_NewspaperData.getPageConfigOrder(pageIndex)
    return pageConfigOrder[1] or WIN_NewspaperData.DEFAULT_PAGE_CONFIG_KEY
end

function WIN_NewspaperData.getValidPageConfigKey(pageIndex, pageConfigKey)
    if WIN_NewspaperData.isPageConfigValidForPage(pageIndex, pageConfigKey) then
        return pageConfigKey
    end
    return WIN_NewspaperData.getDefaultPageConfigKey(pageIndex)
end

function WIN_NewspaperData.getPageConfigLayout(pageData)
    local pageConfigKey = pageData
    if type(pageData) == "table" then
        pageConfigKey = pageData.pageConfigKey
    end
    return WIN_NewspaperData.getPageConfig(pageConfigKey).layout
end

function WIN_NewspaperData.getPageConfigImageOptions(pageData)
    local pageConfigKey = pageData
    if type(pageData) == "table" then
        pageConfigKey = pageData.pageConfigKey
    end
    return WIN_NewspaperData.getPageConfig(pageConfigKey).imageOptions
end

function WIN_NewspaperData.hasPageConfigImageOptions(pageData)
    return #WIN_NewspaperData.getPageConfigImageOptions(pageData) > 0
end

function WIN_NewspaperData.getImageOption(imageKey)
    return WIN_NewspaperPageConfigs.getImageOption(imageKey)
end

function WIN_NewspaperData.getDefaultImageKey(pageData)
    local imageOptions = WIN_NewspaperData.getPageConfigImageOptions(pageData)
    if #imageOptions > 0 then
        return imageOptions[1].key
    end
    return ""
end

function WIN_NewspaperData.getValidImageKey(pageData, imageKey)
    local imageOptions = WIN_NewspaperData.getPageConfigImageOptions(pageData)
    if imageKey then
        for _, imageOption in ipairs(imageOptions) do
            if imageOption.key == imageKey then
                return imageKey
            end
        end
    end
    return WIN_NewspaperData.getDefaultImageKey(pageData)
end

local function getColumnTypeFromConfig(pageConfigKey, columnIndex)
    local pageConfig = WIN_NewspaperData.getPageConfig(pageConfigKey)
    return pageConfig.columnTypes[columnIndex] or WIN_NewspaperData.CONTINUED_ARTICLE_COLUMN_TYPE
end

local function normalizePage(sourcePage, pageIndex)
    local pageConfigKey = WIN_NewspaperData.getDefaultPageConfigKey(pageIndex)
    if sourcePage then
        pageConfigKey = WIN_NewspaperData.getValidPageConfigKey(pageIndex, sourcePage.pageConfigKey)
    end

    local normalizedPage = {
        pageConfigKey = pageConfigKey,
        imageKey = "",
        columns = {},
    }
    normalizedPage.imageKey = WIN_NewspaperData.getValidImageKey(normalizedPage, sourcePage and sourcePage.imageKey)

    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        local sourceColumn = nil
        if sourcePage and sourcePage.columns then
            sourceColumn = sourcePage.columns[i]
        end

        local columnType = getColumnTypeFromConfig(pageConfigKey, i)
        local title = getDefaultTitle(columnType)
        local author = getDefaultAuthor(columnType)
        local body = DEFAULT_BODY_TEXT
        if sourceColumn then
            title = getTextValue(sourceColumn.title, title)
            author = getTextValue(sourceColumn.author, author)
            body = getTextValue(sourceColumn.body, body)
        end

        normalizedPage.columns[i] = {
            type = columnType,
            title = title,
            author = author,
            body = body,
        }
    end

    return normalizedPage
end

function WIN_NewspaperData.normalize(newspaperData)
    local normalizedData = {
        version = WIN_NewspaperData.VERSION,
        paperName = "",
        issueNumber = 1,
        issueDate = "",
        pageCount = WIN_NewspaperData.MIN_PAGE_COUNT,
        pages = {},
    }

    if newspaperData then
        normalizedData.version = tonumber(newspaperData.version) or WIN_NewspaperData.VERSION
        normalizedData.paperName = trimText(newspaperData.paperName)
        normalizedData.issueNumber = clampIssueNumber(newspaperData.issueNumber)
        normalizedData.issueDate = getTextValue(newspaperData.issueDate)
        normalizedData.pageCount = clampPageCount(newspaperData.pageCount)
    end

    for i = 1, WIN_NewspaperData.MAX_PAGE_COUNT do
        local sourcePage = nil
        if newspaperData and newspaperData.pages then
            sourcePage = newspaperData.pages[i]
        end
        normalizedData.pages[i] = normalizePage(sourcePage, i)
    end

    return normalizedData
end

function WIN_NewspaperData.normalizeCharter(charterData)
    local normalizedData = {
        version = WIN_NewspaperData.CHARTER_VERSION,
        paperName = "",
        nextIssueNumber = 1,
    }

    if charterData then
        normalizedData.version = tonumber(charterData.version) or WIN_NewspaperData.CHARTER_VERSION
        normalizedData.paperName = trimText(charterData.paperName)
        normalizedData.nextIssueNumber = clampIssueNumber(charterData.nextIssueNumber)
    end

    return normalizedData
end

function WIN_NewspaperData.applyPageConfigKey(newspaperData, pageIndex, pageConfigKey)
    local oldData = WIN_NewspaperData.normalize(newspaperData)
    local updatedData = WIN_NewspaperData.normalize(newspaperData)
    local normalizedPageIndex = clampPageCount(pageIndex)
    local updatedPage = updatedData.pages[normalizedPageIndex]
    updatedPage.pageConfigKey = WIN_NewspaperData.getValidPageConfigKey(normalizedPageIndex, pageConfigKey)
    updatedData.pages[normalizedPageIndex] = normalizePage(updatedPage, normalizedPageIndex)

    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        local oldColumnType = oldData.pages[normalizedPageIndex].columns[i].type
        local newColumn = updatedData.pages[normalizedPageIndex].columns[i]
        if oldColumnType ~= WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE
            and newColumn.type == WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE then
            if newColumn.title == "" then
                newColumn.title = DEFAULT_HEADLINE_TEXT
            end
            if newColumn.author == "" then
                newColumn.author = DEFAULT_AUTHOR_TEXT
            end
        end
    end

    return WIN_NewspaperData.normalize(updatedData)
end

function WIN_NewspaperData.isNewspaperCharter(itemOrFullType)
    return getFullType(itemOrFullType) == WIN_NewspaperData.CHARTER_FULL_TYPE
end

function WIN_NewspaperData.isNewspaperDraft(itemOrFullType)
    return getFullType(itemOrFullType) == WIN_NewspaperData.DRAFT_FULL_TYPE
end

function WIN_NewspaperData.isPlayerNewspaper(itemOrFullType)
    return getFullType(itemOrFullType) == WIN_NewspaperData.PLAYER_NEWSPAPER_FULL_TYPE
end

function WIN_NewspaperData.isNewspaperIssue(itemOrFullType)
    return WIN_NewspaperData.isNewspaperDraft(itemOrFullType)
        or WIN_NewspaperData.isPlayerNewspaper(itemOrFullType)
end

function WIN_NewspaperData.isNewspaperItem(itemOrFullType)
    return WIN_NewspaperData.isNewspaperCharter(itemOrFullType)
        or WIN_NewspaperData.isNewspaperIssue(itemOrFullType)
end

function WIN_NewspaperData.getCurrentDateText()
    local gameTime = getGameTime()
    local day = gameTime:getDay() + 1
    local monthIndex = gameTime:getMonth() + 1
    local year = gameTime:getYear()
    local monthName = MONTH_NAMES[monthIndex] or tostring(monthIndex)
    return monthName .. " " .. tostring(day) .. ", " .. tostring(year)
end

function WIN_NewspaperData.getIssueDateText(newspaperData)
    if newspaperData and newspaperData.issueDate and newspaperData.issueDate ~= "" then
        return newspaperData.issueDate
    end
    return WIN_NewspaperData.getCurrentDateText()
end

function WIN_NewspaperData.getIssueLabel(newspaperData)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    return "Issue " .. tostring(normalizedData.issueNumber)
end

function WIN_NewspaperData.getCharterDisplayName(charterData)
    local normalizedData = WIN_NewspaperData.normalizeCharter(charterData)
    if normalizedData.paperName == "" then
        return "Newspaper Charter"
    end
    return "Newspaper Charter: " .. normalizedData.paperName
end

function WIN_NewspaperData.getDraftDisplayName(newspaperData)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    return "Draft: " .. getDisplayPaperName(normalizedData.paperName) .. " " .. WIN_NewspaperData.getIssueLabel(normalizedData)
end

function WIN_NewspaperData.getPrintedDisplayName(newspaperData)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    return getDisplayPaperName(normalizedData.paperName) .. ": " .. WIN_NewspaperData.getIssueLabel(normalizedData)
end

function WIN_NewspaperData.applyIssueDisplayName(newspaperItem, newspaperData)
    if WIN_NewspaperData.isNewspaperDraft(newspaperItem) then
        newspaperItem:setName(WIN_NewspaperData.getDraftDisplayName(newspaperData))
    else
        newspaperItem:setName(WIN_NewspaperData.getPrintedDisplayName(newspaperData))
    end
    newspaperItem:setCustomName(true)
end

function WIN_NewspaperData.loadCharterFromItem(charterItem)
    local storedData = nil
    if charterItem then
        storedData = charterItem:getModData()[CHARTER_DATA_KEY]
    end
    return WIN_NewspaperData.normalizeCharter(storedData)
end

function WIN_NewspaperData.saveCharterToItem(charterItem, charterData)
    local normalizedData = WIN_NewspaperData.normalizeCharter(charterData)
    charterItem:getModData()[CHARTER_DATA_KEY] = normalizedData
    charterItem:setName(WIN_NewspaperData.getCharterDisplayName(normalizedData))
    charterItem:setCustomName(true)
    return normalizedData
end

function WIN_NewspaperData.setCharterName(charterItem, paperName)
    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    charterData.paperName = trimText(paperName)
    return WIN_NewspaperData.saveCharterToItem(charterItem, charterData)
end

function WIN_NewspaperData.loadFromItem(newspaperItem)
    local storedData = nil
    if newspaperItem then
        storedData = newspaperItem:getModData()[DATA_KEY]
    end
    local newspaperData = {
        version = storedData and storedData.version,
        paperName = storedData and storedData.paperName,
        issueNumber = storedData and storedData.issueNumber,
        issueDate = storedData and storedData.issueDate,
        pageCount = getItemPageCount(newspaperItem, storedData and storedData.pageCount),
        pages = storedData and storedData.pages,
    }
    return WIN_NewspaperData.normalize(newspaperData)
end

function WIN_NewspaperData.getFirstArticle(newspaperData)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    local firstPage = normalizedData.pages[1]
    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        local columnData = firstPage.columns[i]
        if columnData.type == WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE then
            return trimText(columnData.title), trimText(columnData.body)
        end
    end
    return "", ""
end

function WIN_NewspaperData.getFirstHeadline(newspaperData)
    local headline = WIN_NewspaperData.getFirstArticle(newspaperData)
    return headline
end

function WIN_NewspaperData.isDefaultArticleBody(body)
    return trimText(body) == DEFAULT_BODY_TEXT
end

function WIN_NewspaperData.stampIssueDate(newspaperData)
    newspaperData.issueDate = WIN_NewspaperData.getCurrentDateText()
end

function WIN_NewspaperData.toPageText(newspaperData, pageIndex)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    local normalizedPageIndex = clampPageCount(pageIndex)
    local pageData = normalizedData.pages[normalizedPageIndex]
    local lines = {}
    table.insert(lines, normalizedData.paperName)
    table.insert(lines, WIN_NewspaperData.getIssueLabel(normalizedData))
    table.insert(lines, WIN_NewspaperData.getIssueDateText(normalizedData))

    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        local columnData = pageData.columns[i]
        table.insert(lines, "")
        if columnData.type == WIN_NewspaperData.NEW_ARTICLE_COLUMN_TYPE then
            table.insert(lines, columnData.title)
            table.insert(lines, columnData.author)
        end
        table.insert(lines, columnData.body)
    end

    return table.concat(lines, "\n")
end

function WIN_NewspaperData.toPageTexts(newspaperData)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    local pageTexts = {}
    for i = 1, normalizedData.pageCount do
        pageTexts[i] = WIN_NewspaperData.toPageText(normalizedData, i)
    end
    return pageTexts
end

function WIN_NewspaperData.hasChanges(oldNewspaperData, newNewspaperData)
    local oldData = WIN_NewspaperData.normalize(oldNewspaperData)
    local newData = WIN_NewspaperData.normalize(newNewspaperData)

    if oldData.paperName ~= newData.paperName
        or oldData.issueNumber ~= newData.issueNumber
        or oldData.pageCount ~= newData.pageCount then
        return true
    end

    for pageIndex = 1, oldData.pageCount do
        local oldPageData = oldData.pages[pageIndex]
        local newPageData = newData.pages[pageIndex]
        if oldPageData.pageConfigKey ~= newPageData.pageConfigKey
            or oldPageData.imageKey ~= newPageData.imageKey then
            return true
        end

        for columnIndex = 1, WIN_NewspaperData.COLUMN_COUNT do
            local oldColumn = oldPageData.columns[columnIndex]
            local newColumn = newPageData.columns[columnIndex]
            if oldColumn.type ~= newColumn.type
                or oldColumn.title ~= newColumn.title
                or oldColumn.author ~= newColumn.author
                or oldColumn.body ~= newColumn.body then
                return true
            end
        end
    end

    return false
end

function WIN_NewspaperData.saveToItem(newspaperItem, newspaperData, updateIssueDate)
    local normalizedData = WIN_NewspaperData.normalize(newspaperData)
    if updateIssueDate then
        WIN_NewspaperData.stampIssueDate(normalizedData)
    end

    WIN_Utils.ensureNoteUID(newspaperItem)
    newspaperItem:setPageToWrite(normalizedData.pageCount)
    newspaperItem:getModData()[DATA_KEY] = normalizedData
    WIN_NewspaperData.applyIssueDisplayName(newspaperItem, normalizedData)

    local pageTexts = WIN_NewspaperData.toPageTexts(normalizedData)
    for i = 1, #pageTexts do
        newspaperItem:addPage(i, pageTexts[i])
    end

    return normalizedData
end

function WIN_NewspaperData.createIssueData(paperName, issueNumber)
    return WIN_NewspaperData.normalize({
        paperName = paperName,
        issueNumber = issueNumber,
        pageCount = WIN_NewspaperData.MIN_PAGE_COUNT,
        pages = {},
    })
end

function WIN_NewspaperData.createDraftFromCharter(charterItem, player)
    local charterData = WIN_NewspaperData.loadCharterFromItem(charterItem)
    if charterData.paperName == "" then
        return nil
    end

    local issueNumber = charterData.nextIssueNumber
    local draftItem = player:getInventory():AddItem(WIN_NewspaperData.DRAFT_FULL_TYPE)
    if not draftItem then
        return nil
    end

    local draftData = WIN_NewspaperData.createIssueData(charterData.paperName, issueNumber)
    local savedDraftData = WIN_NewspaperData.saveToItem(draftItem, draftData, true)

    charterData.nextIssueNumber = issueNumber + 1
    WIN_NewspaperData.saveCharterToItem(charterItem, charterData)

    return draftItem, savedDraftData
end

function WIN_NewspaperData.createPrintedCopyFromDraft(draftItem, player)
    local draftData = WIN_NewspaperData.loadFromItem(draftItem)
    local copyItem = player:getInventory():AddItem(WIN_NewspaperData.PLAYER_NEWSPAPER_FULL_TYPE)
    if not copyItem then
        return nil
    end

    WIN_NewspaperData.saveToItem(copyItem, draftData, false)
    return copyItem, draftData
end

function WIN_NewspaperData.setPageCount(newspaperItem, pageCount)
    local newspaperData = WIN_NewspaperData.loadFromItem(newspaperItem)
    local oldPageCount = newspaperData.pageCount
    newspaperData.pageCount = clampPageCount(pageCount)
    return WIN_NewspaperData.saveToItem(newspaperItem, newspaperData, newspaperData.pageCount ~= oldPageCount)
end
