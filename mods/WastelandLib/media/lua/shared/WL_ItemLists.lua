require "WL_ClientServerBase"
require "WL_Utils"

--- @class WL_ItemLists : WL_ClientServerBase
WL_ItemLists = WL_ClientServerBase:new("WL_ItemLists")
WL_ItemLists.needsPublicData = true

WL_ItemLists.SCHEMA_VERSION = 2
WL_ItemLists.DEFAULT_CATEGORY_ID = "default"
WL_ItemLists.DEFAULT_CATEGORY_NAME = "Default"

WL_ItemLists.publicData = {
    schemaVersion = WL_ItemLists.SCHEMA_VERSION,
    categories = {},
    lists = {}
}

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function nowTimestamp()
    if WL_Utils and WL_Utils.getTimestamp then
        return WL_Utils.getTimestamp()
    end
    return getTimestamp()
end

local function duplicateValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nested in pairs(value) do
        copy[key] = duplicateValue(nested)
    end
    return copy
end

local function normalizeOptionalText(value)
    local text = trim(value)
    if text == "" then
        return nil
    end
    return text
end

local function normalizePositiveNumber(value)
    local number = tonumber(value)
    if not number then
        return nil
    end
    return number
end

local function normalizePositiveInteger(value)
    local number = tonumber(value)
    if not number then
        return nil
    end

    number = math.floor(number)
    return number
end

local function getScriptItem(fullType)
    local normalized = trim(fullType)
    if normalized == "" then
        return nil
    end
    return ScriptManager.instance:getItem(normalized)
end

local function getResolvedItemDisplayName(fullType, customName)
    if customName and customName ~= "" then
        return customName
    end

    local scriptItem = getScriptItem(fullType)
    if scriptItem then
        return scriptItem:getDisplayName()
    end

    return tostring(fullType or "")
end

local function getListReferenceDisplayName(listData, childListId)
    if listData and trim(listData.name) ~= "" then
        local prefix = listData.deleted == true and "[D] " or ""
        return prefix .. trim(listData.name)
    end
    return "Missing List: " .. tostring(childListId or "")
end

local function getCategoryDisplayName(categoryData)
    local name = trim(categoryData and categoryData.name)
    if name ~= "" then
        return name
    end
    return WL_ItemLists.DEFAULT_CATEGORY_NAME
end

local function formatCategoryQualifiedListName(listSummary)
    local categoryName = tostring(listSummary and (listSummary.categoryDisplayName or listSummary.categoryName) or WL_ItemLists.DEFAULT_CATEGORY_NAME)
    local listName = tostring(listSummary and (listSummary.displayName or listSummary.name) or "")
    if listName == "" then
        return categoryName
    end
    return categoryName .. " / " .. listName
end

local function sortByNameThenId(a, b)
    local aName = string.lower(tostring(a.name or a.displayName or ""))
    local bName = string.lower(tostring(b.name or b.displayName or ""))
    if aName == bName then
        return tostring(a.id or "") < tostring(b.id or "")
    end
    return aName < bName
end

local function sortCategories(a, b)
    local aIsDefault = a and a.isDefault == true
    local bIsDefault = b and b.isDefault == true
    if aIsDefault ~= bIsDefault then
        return aIsDefault == true
    end
    return sortByNameThenId(a, b)
end

local function normalizeItemQuantityRange(qtyMin, qtyMax)
    local minValue = normalizePositiveInteger(qtyMin)
    local maxValue = normalizePositiveInteger(qtyMax)

    if not minValue or minValue < 1 then
        return nil, nil, "Quantity minimum must be a whole number of at least 1."
    end
    if not maxValue or maxValue < 1 then
        return nil, nil, "Quantity maximum must be a whole number of at least 1."
    end
    if maxValue < minValue then
        local swap = minValue
        minValue = maxValue
        maxValue = swap
    end

    return minValue, maxValue, nil
end

function WL_ItemLists:onModDataInit()
    local didMutate = false

    if not self.publicData then
        self.publicData = {}
        didMutate = true
    end

    if type(self.publicData.categories) ~= "table" then
        self.publicData.categories = {}
        didMutate = true
    end

    if type(self.publicData.lists) ~= "table" then
        self.publicData.lists = {}
        didMutate = true
    end

    local _, defaultCategoryMutated = self:_ensureDefaultCategory()
    if defaultCategoryMutated then
        didMutate = true
    end

    for categoryId, categoryData in pairs(self.publicData.categories) do
        if type(categoryData) ~= "table" then
            self.publicData.categories[categoryId] = {
                id = tostring(categoryId),
                name = tostring(categoryId),
                isDefault = tostring(categoryId) == self.DEFAULT_CATEGORY_ID,
                createdAt = nowTimestamp(),
                updatedAt = nowTimestamp()
            }
            categoryData = self.publicData.categories[categoryId]
            didMutate = true
        end

        local normalizedId = tostring(categoryData.id or categoryId)
        if normalizedId ~= tostring(categoryId) then
            categoryData.id = tostring(categoryId)
            didMutate = true
        end

        local normalizedName = trim(categoryData.name)
        if normalizedName == "" then
            normalizedName = tostring(categoryId) == self.DEFAULT_CATEGORY_ID and self.DEFAULT_CATEGORY_NAME or tostring(categoryId)
        end
        if categoryData.name ~= normalizedName then
            categoryData.name = normalizedName
            didMutate = true
        end

        local isDefaultCategory = tostring(categoryId) == self.DEFAULT_CATEGORY_ID
        if categoryData.isDefault ~= isDefaultCategory then
            categoryData.isDefault = isDefaultCategory
            didMutate = true
        end
    end

    local categories = self.publicData.categories
    for _, listData in pairs(self.publicData.lists) do
        local resolvedCategoryId = normalizeOptionalText(listData.categoryId) or self.DEFAULT_CATEGORY_ID
        if not categories[resolvedCategoryId] then
            resolvedCategoryId = self.DEFAULT_CATEGORY_ID
        end
        if listData.categoryId ~= resolvedCategoryId then
            listData.categoryId = resolvedCategoryId
            didMutate = true
        end
    end

    if self.publicData.schemaVersion ~= self.SCHEMA_VERSION then
        self.publicData.schemaVersion = self.SCHEMA_VERSION
        didMutate = true
    end

    if didMutate and not isClient() and not self._isSavingMigratedData then
        self._isSavingMigratedData = true
        self:savePublicData()
        self._isSavingMigratedData = nil
    end
end

function WL_ItemLists:onPublicDataUpdated()
    self:onModDataInit()

    if not isClient() then
        return
    end

    if WL_ItemListManagerWindow and WL_ItemListManagerWindow.refreshOpenWindow then
        WL_ItemListManagerWindow.refreshOpenWindow()
    end

    if WL_ItemListPickerDialog and WL_ItemListPickerDialog.refreshOpenWindow then
        WL_ItemListPickerDialog.refreshOpenWindow()
    end
end

function WL_ItemLists:_getPublicLists()
    self:onModDataInit()
    return self.publicData.lists
end

function WL_ItemLists:_getPublicCategories()
    self:onModDataInit()
    return self.publicData.categories
end

function WL_ItemLists:_ensureDefaultCategory()
    local categories = self.publicData and self.publicData.categories or nil
    if not categories then
        return nil, false
    end

    local timestamp = nowTimestamp()
    local category = categories[self.DEFAULT_CATEGORY_ID]
    local didMutate = false
    if not category then
        category = {
            id = self.DEFAULT_CATEGORY_ID,
            name = self.DEFAULT_CATEGORY_NAME,
            isDefault = true,
            createdAt = timestamp,
            updatedAt = timestamp,
            createdBy = "system",
            updatedBy = "system"
        }
        categories[self.DEFAULT_CATEGORY_ID] = category
        didMutate = true
    end

    if category.id ~= self.DEFAULT_CATEGORY_ID then
        category.id = self.DEFAULT_CATEGORY_ID
        didMutate = true
    end
    if trim(category.name) ~= self.DEFAULT_CATEGORY_NAME then
        category.name = self.DEFAULT_CATEGORY_NAME
        didMutate = true
    end
    if category.isDefault ~= true then
        category.isDefault = true
        didMutate = true
    end
    if not category.createdAt then
        category.createdAt = timestamp
        didMutate = true
    end
    if not category.updatedAt then
        category.updatedAt = category.createdAt
        didMutate = true
    end

    return category, didMutate
end

function WL_ItemLists:_findList(listId)
    if not listId then
        return nil
    end
    return self:_getPublicLists()[tostring(listId)]
end

function WL_ItemLists:_findCategory(categoryId)
    local normalizedId = normalizeOptionalText(categoryId) or self.DEFAULT_CATEGORY_ID
    return self:_getPublicCategories()[normalizedId]
end

function WL_ItemLists:_getResolvedCategoryId(listData)
    local categoryId = normalizeOptionalText(listData and listData.categoryId) or self.DEFAULT_CATEGORY_ID
    if not self:_findCategory(categoryId) then
        return self.DEFAULT_CATEGORY_ID
    end
    return categoryId
end

function WL_ItemLists:_getListCategory(listData)
    return self:_findCategory(self:_getResolvedCategoryId(listData))
end

function WL_ItemLists:_isDefaultCategory(categoryId)
    return tostring(categoryId or "") == self.DEFAULT_CATEGORY_ID
end

function WL_ItemLists:_getCategoryListCount(categoryId, includeDeleted)
    local normalizedCategoryId = normalizeOptionalText(categoryId) or self.DEFAULT_CATEGORY_ID
    local count = 0
    for _, listData in pairs(self:_getPublicLists()) do
        if self:_canReadList(listData, includeDeleted == true) and self:_getResolvedCategoryId(listData) == normalizedCategoryId then
            count = count + 1
        end
    end
    return count
end

function WL_ItemLists:_canReadList(listData, includeDeleted)
    if not listData then
        return false
    end
    if includeDeleted then
        return true
    end
    return listData.deleted ~= true
end

function WL_ItemLists:_copyItemEntry(itemEntry)
    local copy = duplicateValue(itemEntry)

    copy.entryType = trim(copy.entryType)
    if copy.entryType == "" then
        copy.entryType = copy.childListId and "list" or "item"
    end

    copy.customName = normalizeOptionalText(copy.customName)
    copy.fullType = normalizeOptionalText(copy.fullType)
    copy.childListId = normalizeOptionalText(copy.childListId)

    if copy.entryType == "list" then
        local childList = self:_findList(copy.childListId)
        local canResolveChild = childList ~= nil
        copy.resolvedListName = getListReferenceDisplayName(childList, copy.childListId)
        copy.isMissingReference = not canResolveChild
        copy.displayName = getListReferenceDisplayName(childList, copy.childListId)
        copy.displaySubtext = canResolveChild and (childList.deleted == true and "Nested item list [D]" or "Nested item list") or "Missing child list"
        copy.customName = nil
    else
        copy.entryType = "item"
        copy.resolvedListName = nil
        copy.isMissingReference = false
        copy.displayName = getResolvedItemDisplayName(copy.fullType, copy.customName)
        copy.displaySubtext = tostring(copy.fullType or "")
        copy.childListId = nil
    end

    return copy
end

function WL_ItemLists:_copyListRecord(listData)
    local copy = duplicateValue(listData)
    copy.name = trim(copy.name)
    copy.categoryId = self:_getResolvedCategoryId(listData)

    local categoryData = self:_getListCategory(listData)
    copy.categoryName = getCategoryDisplayName(categoryData)
    copy.categoryDisplayName = copy.categoryName
    copy.items = {}

    local sourceItems = listData.items or {}
    for i = 1, #sourceItems do
        copy.items[i] = self:_copyItemEntry(sourceItems[i])
    end

    return copy
end

function WL_ItemLists:_buildListSummary(listData)
    local displayName = getListReferenceDisplayName(listData, listData and listData.id)
    local categoryData = self:_getListCategory(listData)
    return {
        id = listData.id,
        name = trim(listData.name),
        displayName = displayName,
        categoryId = self:_getResolvedCategoryId(listData),
        categoryName = getCategoryDisplayName(categoryData),
        categoryDisplayName = getCategoryDisplayName(categoryData),
        deleted = listData.deleted == true,
        createdAt = listData.createdAt,
        updatedAt = listData.updatedAt,
        deletedAt = listData.deletedAt,
        itemCount = #(listData.items or {})
    }
end

function WL_ItemLists:getListSummaries(includeDeleted)
    local summaries = {}
    for _, listData in pairs(self:_getPublicLists()) do
        if self:_canReadList(listData, includeDeleted == true) then
            summaries[#summaries + 1] = self:_buildListSummary(listData)
        end
    end

    table.sort(summaries, function(a, b)
        local aName = string.lower(tostring(a.name or ""))
        local bName = string.lower(tostring(b.name or ""))
        if aName == bName then
            return tostring(a.id or "") < tostring(b.id or "")
        end
        return aName < bName
    end)

    return summaries
end

function WL_ItemLists:_copyCategoryRecord(categoryData)
    if not categoryData then
        return nil
    end

    local copy = duplicateValue(categoryData)
    copy.id = tostring(copy.id or "")
    copy.name = getCategoryDisplayName(copy)
    copy.displayName = copy.name
    copy.isDefault = self:_isDefaultCategory(copy.id)
    return copy
end

function WL_ItemLists:getCategorySummaries(includeDeleted)
    local summaries = {}
    for _, categoryData in pairs(self:_getPublicCategories()) do
        local summary = self:_copyCategoryRecord(categoryData)
        summary.listCount = self:_getCategoryListCount(summary.id, includeDeleted)
        summary.canRename = summary.isDefault ~= true
        summary.canDelete = summary.isDefault ~= true and summary.listCount <= 0
        summaries[#summaries + 1] = summary
    end

    table.sort(summaries, sortCategories)
    return summaries
end

function WL_ItemLists:getCategoryById(categoryId)
    return self:_copyCategoryRecord(self:_findCategory(categoryId))
end

function WL_ItemLists:getCategoryNameById(categoryId)
    local categoryData = self:_findCategory(categoryId)
    if not categoryData then
        return nil
    end
    return getCategoryDisplayName(categoryData)
end

function WL_ItemLists:getListSummaryById(listId, includeDeleted)
    local listData = self:_findList(listId)
    if not self:_canReadList(listData, includeDeleted == true) then
        return nil
    end
    return self:_buildListSummary(listData)
end

function WL_ItemLists:getListPickerDisplayNameById(listId, includeDeleted)
    local summary = self:getListSummaryById(listId, includeDeleted)
    if not summary then
        return nil
    end
    return formatCategoryQualifiedListName(summary)
end

function WL_ItemLists:getAvailableLists(includeDeleted)
    return self:getListSummaries(includeDeleted)
end

function WL_ItemLists:getSelectableChildListSummaries(parentListId)
    local summaries = {}
    local parentId = normalizeOptionalText(parentListId)

    for _, summary in ipairs(self:getListSummaries(true)) do
        if summary.id ~= parentId then
            local _, cycleError = self:_validateNestedReference(parentId, summary.id)
            local disabledReason = nil
            if summary.deleted == true then
                disabledReason = "Deleted lists cannot be newly selected."
            else
                disabledReason = cycleError
            end

            summaries[#summaries + 1] = {
                id = summary.id,
                name = summary.name,
                displayName = summary.displayName,
                deleted = summary.deleted,
                itemCount = summary.itemCount,
                createdAt = summary.createdAt,
                updatedAt = summary.updatedAt,
                categoryId = summary.categoryId,
                categoryName = summary.categoryName,
                categoryDisplayName = summary.categoryDisplayName,
                pickerDisplayName = formatCategoryQualifiedListName(summary),
                isSelectable = disabledReason == nil,
                disabledReason = disabledReason
            }
        end
    end

    return summaries
end

function WL_ItemLists:getListById(listId, includeDeleted)
    local listData = self:_findList(listId)
    if not self:_canReadList(listData, includeDeleted == true) then
        return nil
    end
    return self:_copyListRecord(listData)
end

function WL_ItemLists:getListNameById(listId, includeDeleted)
    local listData = self:_findList(listId)
    if not self:_canReadList(listData, includeDeleted == true) then
        return nil
    end

    return getListReferenceDisplayName(listData, listId)
end

function WL_ItemLists:_getRollCandidates(listData)
    local candidates = {}
    local totalWeight = 0
    local items = listData and listData.items or {}

    for i = 1, #items do
        local itemEntry = items[i]
        local entryType = trim(itemEntry.entryType)
        if entryType == "" then
            entryType = itemEntry.childListId and "list" or "item"
        end
        local scriptItem = getScriptItem(itemEntry.fullType)
        local weight = tonumber(itemEntry.weight) or 0

        local isValid = false
        if entryType == "list" then
            local childList = self:_findList(itemEntry.childListId)
            isValid = childList ~= nil
        else
            isValid = scriptItem ~= nil
        end

        if isValid and weight > 0 then
            candidates[#candidates + 1] = itemEntry
            totalWeight = totalWeight + weight
        end
    end

    return candidates, totalWeight
end

function WL_ItemLists:_buildRolledDefinition(rootListData, leafListData, itemEntry, quantity, path)
    local customName = normalizeOptionalText(itemEntry.customName)
    return {
        sourceRootListId = rootListData and rootListData.id or nil,
        sourceLeafListId = leafListData and leafListData.id or nil,
        sourceEntryId = itemEntry.id,
        fullType = itemEntry.fullType,
        customName = customName,
        quantity = quantity,
        displayName = getResolvedItemDisplayName(itemEntry.fullType, customName),
        path = duplicateValue(path or {})
    }
end

function WL_ItemLists:_pickWeightedEntry(listData)
    local candidates, totalWeight = self:_getRollCandidates(listData)
    if #candidates == 0 or totalWeight <= 0 then
        return nil, totalWeight, candidates
    end

    local randomValue = ZombRand(0, totalWeight) + 1
    for i = 1, #candidates do
        local itemEntry = candidates[i]
        randomValue = randomValue - (tonumber(itemEntry.weight) or 0)
        if randomValue <= 0 then
            return itemEntry, totalWeight, candidates
        end
    end

    return nil, totalWeight, candidates
end

function WL_ItemLists:_rollQuantity(itemEntry)
    local qtyMin = tonumber(itemEntry.qtyMin) or 1
    local qtyMax = tonumber(itemEntry.qtyMax) or qtyMin
    if qtyMax < qtyMin then
        qtyMax = qtyMin
    end

    if qtyMax > qtyMin then
        return ZombRand(qtyMin, qtyMax + 1), qtyMin, qtyMax
    end

    return qtyMin, qtyMin, qtyMax
end

function WL_ItemLists:_appendRollError(outputTrace, outputReport, message)
    if outputTrace then
        outputTrace.error = message
    end
    if outputReport then
        outputReport.errors[#outputReport.errors + 1] = message
    end
end

function WL_ItemLists:_rollEntryRecursive(rootListData, listData, outputDefinitions, outputTrace, outputReport, path)
    local selected, totalWeight = self:_pickWeightedEntry(listData)
    outputTrace.totalWeight = totalWeight

    if not selected then
        self:_appendRollError(outputTrace, outputReport, "No valid roll candidates for list '" .. tostring(listData and listData.id or "") .. "'.")
        return false
    end

    local quantity, qtyMin, qtyMax = self:_rollQuantity(selected)
    local normalizedWeight = tonumber(selected.weight) or 0
    local normalizedChance = 0
    if totalWeight > 0 then
        normalizedChance = normalizedWeight / totalWeight
    end

    outputTrace.pickedEntryId = selected.id
    outputTrace.entryType = selected.entryType
    outputTrace.entryWeight = normalizedWeight
    outputTrace.normalizedChance = normalizedChance
    outputTrace.qtyRolled = quantity
    outputTrace.qtyMin = qtyMin
    outputTrace.qtyMax = qtyMax
    outputTrace.fullType = selected.fullType
    outputTrace.customName = selected.customName
    outputTrace.childListId = selected.childListId
    outputTrace.displayName = selected.displayName or selected.fullType or selected.childListId
    outputTrace.descendants = {}

    local nextPath = duplicateValue(path or {})
    nextPath[#nextPath + 1] = {
        listId = listData.id,
        listName = getListReferenceDisplayName(listData, listData and listData.id),
        entryId = selected.id,
        entryType = selected.entryType,
        displayName = selected.displayName or selected.fullType or selected.childListId,
        childListId = selected.childListId,
        fullType = selected.fullType,
        quantity = quantity
    }

    if selected.entryType == "list" then
        local childList = self:_findList(selected.childListId)
        if not childList then
            self:_appendRollError(outputTrace, outputReport, "Missing child list reference: " .. tostring(selected.childListId or ""))
            return false
        end

        for i = 1, quantity do
            local childTrace = {
                rollIndex = i,
                listId = childList.id,
                listName = getListReferenceDisplayName(childList, childList.id)
            }
            outputTrace.descendants[#outputTrace.descendants + 1] = childTrace
            self:_rollEntryRecursive(rootListData, childList, outputDefinitions, childTrace, outputReport, nextPath)
        end

        return true
    end

    outputDefinitions[#outputDefinitions + 1] = self:_buildRolledDefinition(rootListData, listData, selected, quantity, nextPath)
    return true
end

function WL_ItemLists:rollItemDefinitions(listId, rollCount, options)
    local listData = self:_findList(listId)
    if not listData then
        return nil, {
            rootListId = listId,
            requestedRollCount = tonumber(rollCount) or 1,
            executedRollCount = 0,
            flattenedItemCount = 0,
            traces = {},
            errors = { "List not found." }
        }
    end

    local requestedRollCount = normalizePositiveInteger(rollCount) or 1
    if requestedRollCount < 1 then
        requestedRollCount = 1
    end

    local rolledDefinitions = {}
    local rollReport = {
        rootListId = listData.id,
        requestedRollCount = requestedRollCount,
        executedRollCount = 0,
        flattenedItemCount = 0,
        traces = {},
        errors = {}
    }

    options = options or {}

    for i = 1, requestedRollCount do
        local trace = {
            rollIndex = i,
            listId = listData.id,
            listName = getListReferenceDisplayName(listData, listData.id)
        }
        rollReport.traces[#rollReport.traces + 1] = trace
        local didExecute = self:_rollEntryRecursive(listData, listData, rolledDefinitions, trace, rollReport, {})
        if didExecute then
            rollReport.executedRollCount = rollReport.executedRollCount + 1
        end
    end

    rollReport.flattenedItemCount = #rolledDefinitions
    return rolledDefinitions, rollReport
end

function WL_ItemLists:rollItemDefinition(listId)
    local rolledDefinitions, rollReport = self:rollItemDefinitions(listId, 1)
    if not rolledDefinitions or #rolledDefinitions == 0 then
        return nil, rollReport
    end
    return rolledDefinitions[1], rollReport
end

function WL_ItemLists:_applyCustomName(item, customName)
    local normalized = normalizeOptionalText(customName)
    if not item or not normalized then
        return item
    end
    item:setName(normalized)
    item:setCustomName(true)
    return item
end

function WL_ItemLists:createItemsFromRolledDefinitions(rolledDefinitions)
    local items = {}

    if type(rolledDefinitions) ~= "table" then
        return nil
    end

    for i = 1, #rolledDefinitions do
        local rolledDefinition = rolledDefinitions[i]
        local fullType = trim(rolledDefinition and rolledDefinition.fullType)
        local quantity = normalizePositiveInteger(rolledDefinition and rolledDefinition.quantity) or 0

        if fullType ~= "" and quantity >= 1 then
            for itemIndex = 1, quantity do
                local item = InventoryItemFactory.CreateItem(fullType)
                if item then
                    self:_applyCustomName(item, rolledDefinition.customName)
                    items[#items + 1] = item
                end
            end
        end
    end

    if #items == 0 then
        return nil
    end

    return items
end

function WL_ItemLists:createItemsFromRolledDefinition(rolledDefinition)
    if not rolledDefinition then
        return nil
    end
    return self:createItemsFromRolledDefinitions({ rolledDefinition })
end

function WL_ItemLists:createRolledItems(listId, rollCount, options)
    local rolledDefinitions, rollReport = self:rollItemDefinitions(listId, rollCount, options)
    if not rolledDefinitions or #rolledDefinitions == 0 then
        return nil, rolledDefinitions, rollReport
    end
    return self:createItemsFromRolledDefinitions(rolledDefinitions), rolledDefinitions, rollReport
end

function WL_ItemLists:_getNestedReferenceStatus(childListId)
    local childId = normalizeOptionalText(childListId)
    if not childId then
        return nil, "Child list is required."
    end

    local childList = self:_findList(childId)
    if not childList then
        return nil, "Referenced child list does not exist."
    end

    return childList, nil
end

function WL_ItemLists:_wouldCreateCycle(rootListId, candidateChildListId, visited)
    local rootId = tostring(rootListId or "")
    local childId = tostring(candidateChildListId or "")
    if childId == "" then
        return false
    end
    if childId == rootId then
        return true
    end

    visited = visited or {}
    if visited[childId] then
        return false
    end
    visited[childId] = true

    local childList = self:_findList(childId)
    if not childList then
        return false
    end

    local items = childList.items or {}
    for i = 1, #items do
        local itemEntry = items[i]
        if itemEntry.entryType == "list" and self:_wouldCreateCycle(rootId, itemEntry.childListId, visited) then
            return true
        end
    end

    return false
end

function WL_ItemLists:_validateNestedReference(parentListId, childListId, itemEntryId)
    local childList, childError = self:_getNestedReferenceStatus(childListId)
    if childError then
        return nil, childError
    end

    if tostring(parentListId or "") == tostring(childList.id or "") then
        return nil, "A list cannot reference itself."
    end

    if self:_wouldCreateCycle(parentListId, childList.id, {}) then
        return nil, "This child list selection would create a nested cycle."
    end

    return childList, nil
end

function WL_ItemLists:_validateStaffPlayer(player)
    if not WL_Utils.isStaff(player) then
        return false, "Only staff can modify item lists."
    end
    return true, nil
end

function WL_ItemLists:_validateListName(name)
    local normalized = trim(name)
    if normalized == "" then
        return nil, "List name is required."
    end
    return normalized, nil
end

function WL_ItemLists:_validateCategoryName(name)
    local normalized = trim(name)
    if normalized == "" then
        return nil, "Category name is required."
    end
    return normalized, nil
end

function WL_ItemLists:_validateCategorySelection(categoryId)
    local normalizedCategoryId = normalizeOptionalText(categoryId) or self.DEFAULT_CATEGORY_ID
    local categoryData = self:_findCategory(normalizedCategoryId)
    if not categoryData then
        return nil, "Category not found."
    end
    return categoryData, nil
end

function WL_ItemLists:_validateItemPayload(payload)
    if type(payload) ~= "table" then
        return nil, "Invalid item payload."
    end

    local entryType = trim(payload.entryType)
    if entryType == "" then
        entryType = payload.childListId and "list" or "item"
    end
    if entryType ~= "item" and entryType ~= "list" then
        return nil, "Entry type must be 'item' or 'list'."
    end

    local weight = normalizePositiveNumber(payload.weight)
    if not weight or weight <= 0 then
        return nil, "Spawn weight must be greater than 0."
    end

    local qtyMin, qtyMax, qtyError = normalizeItemQuantityRange(payload.qtyMin, payload.qtyMax)
    if qtyError then
        return nil, qtyError
    end

    local fullType = nil
    local childListId = nil
    local customName = nil

    if entryType == "item" then
        fullType = trim(payload.fullType)
        if fullType == "" then
            return nil, "Full item type is required."
        end

        if not getScriptItem(fullType) then
            return nil, "Item type does not exist: " .. fullType
        end

        customName = normalizeOptionalText(payload.customName)
    else
        childListId = normalizeOptionalText(payload.childListId)
        if not childListId then
            return nil, "Child list is required."
        end
    end

    return {
        id = payload.id and tostring(payload.id) or nil,
        entryType = entryType,
        fullType = fullType,
        childListId = childListId,
        customName = customName,
        weight = weight,
        qtyMin = qtyMin,
        qtyMax = qtyMax
    }, nil
end

function WL_ItemLists:_buildChancePathNode(listData, itemEntry)
    return {
        listId = listData and listData.id or nil,
        listName = listData and getListReferenceDisplayName(listData, listData.id) or nil,
        entryId = itemEntry and itemEntry.id or nil,
        entryType = itemEntry and itemEntry.entryType or nil,
        displayName = itemEntry and (itemEntry.displayName or itemEntry.fullType or itemEntry.childListId) or nil,
        fullType = itemEntry and itemEntry.fullType or nil,
        childListId = itemEntry and itemEntry.childListId or nil
    }
end

function WL_ItemLists:_addEffectiveChanceResult(resultsByKey, rootListData, leafListData, itemEntry, chance, path)
    if chance <= 0 then
        return
    end

    local key = tostring(itemEntry.id or "") .. "::" .. tostring(itemEntry.fullType or "") .. "::" .. tostring(itemEntry.customName or "")
    local existing = resultsByKey[key]
    if existing then
        existing.effectiveChance = 1 - ((1 - existing.effectiveChance) * (1 - chance))
        return
    end

    resultsByKey[key] = {
        sourceRootListId = rootListData and rootListData.id or nil,
        sourceLeafListId = leafListData and leafListData.id or nil,
        sourceEntryId = itemEntry.id,
        fullType = itemEntry.fullType,
        customName = normalizeOptionalText(itemEntry.customName),
        displayName = getResolvedItemDisplayName(itemEntry.fullType, itemEntry.customName),
        effectiveChance = chance,
        path = duplicateValue(path or {})
    }
end

function WL_ItemLists:_getEntryChanceForQuantityDistribution(baseChance, nestedResults, qtyMin, qtyMax)
    if baseChance <= 0 then
        return 0
    end

    local quantities = (qtyMax - qtyMin) + 1
    if quantities < 1 then
        quantities = 1
    end

    local aggregated = {}
    for key, nested in pairs(nestedResults) do
        local averageChance = 0
        for quantity = qtyMin, qtyMax do
            local childChance = nested.effectiveChance or 0
            local perQuantityChance = 1 - ((1 - childChance) ^ quantity)
            averageChance = averageChance + perQuantityChance
        end
        averageChance = averageChance / quantities
        aggregated[key] = {
            definition = nested,
            effectiveChance = baseChance * averageChance
        }
    end

    return aggregated
end

function WL_ItemLists:_collectEffectiveChancesRecursive(rootListData, listData, parentChance, resultsByKey, path, visited)
    if parentChance <= 0 then
        return
    end

    local listId = tostring(listData and listData.id or "")
    visited = visited or {}
    if visited[listId] then
        return
    end
    visited[listId] = true

    local candidates, totalWeight = self:_getRollCandidates(listData)
    if #candidates == 0 or totalWeight <= 0 then
        visited[listId] = nil
        return
    end

    for i = 1, #candidates do
        local itemEntry = candidates[i]
        local entryType = itemEntry.entryType
        if not entryType or entryType == "" then
            entryType = itemEntry.childListId and "list" or "item"
        end
        local weight = tonumber(itemEntry.weight) or 0
        local entryChance = parentChance * (weight / totalWeight)
        local nextPath = duplicateValue(path or {})
        nextPath[#nextPath + 1] = self:_buildChancePathNode(listData, itemEntry)

        if entryType == "item" then
            self:_addEffectiveChanceResult(resultsByKey, rootListData, listData, itemEntry, entryChance, nextPath)
        else
            local childList = self:_findList(itemEntry.childListId)
            if childList then
                local childResults = {}
                self:_collectEffectiveChancesRecursive(rootListData, childList, 1, childResults, nextPath, visited)
                local qtyMin = tonumber(itemEntry.qtyMin) or 1
                local qtyMax = tonumber(itemEntry.qtyMax) or qtyMin
                local aggregated = self:_getEntryChanceForQuantityDistribution(entryChance, childResults, qtyMin, qtyMax)
                for key, nested in pairs(aggregated) do
                    self:_addEffectiveChanceResult(resultsByKey, rootListData, childList, nested.definition, nested.effectiveChance, nested.definition.path)
                end
            end
        end
    end

    visited[listId] = nil
end

function WL_ItemLists:getEffectiveChances(listId, options)
    local listData = self:_findList(listId)
    options = options or {}
    local chanceReport = {
        rootListId = listId,
        entries = {},
        errors = {}
    }

    if not listData then
        chanceReport.errors[#chanceReport.errors + 1] = "List not found."
        return chanceReport
    end

    local resultsByKey = {}
    self:_collectEffectiveChancesRecursive(listData, listData, 1, resultsByKey, {}, {})

    for _, entry in pairs(resultsByKey) do
        chanceReport.entries[#chanceReport.entries + 1] = entry
    end

    table.sort(chanceReport.entries, function(a, b)
        if a.effectiveChance == b.effectiveChance then
            local aName = string.lower(tostring(a.displayName or a.fullType or ""))
            local bName = string.lower(tostring(b.displayName or b.fullType or ""))
            if aName == bName then
                return tostring(a.sourceEntryId or "") < tostring(b.sourceEntryId or "")
            end
            return aName < bName
        end
        return a.effectiveChance > b.effectiveChance
    end)

    return chanceReport
end

function WL_ItemLists:_validateMutableList(listData)
    if not listData then
        return false, "List not found."
    end
    return true, nil
end

function WL_ItemLists:_findItemIndex(listData, itemEntryId)
    local items = listData.items or {}
    for i = 1, #items do
        if tostring(items[i].id) == tostring(itemEntryId) then
            return i
        end
    end
    return nil
end

function WL_ItemLists:_saveAndRefresh(logMessage)
    self.publicData.schemaVersion = self.SCHEMA_VERSION
    self:savePublicData()
    if logMessage then
        self:logInfo(logMessage)
    end
end

function WL_ItemLists:createList(player, listName, categoryId)
    if isClient() then
        self:sendToServer(player or getPlayer(), "createList", listName, categoryId)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local normalizedName, nameError = self:_validateListName(listName)
    if nameError then
        self:showPlayerError(player, nameError)
        return
    end

    local selectedCategory, categoryError = self:_validateCategorySelection(categoryId)
    if categoryError then
        self:showPlayerError(player, categoryError)
        return
    end

    local timestamp = nowTimestamp()
    local listId = getRandomUUID()
    self:_getPublicLists()[listId] = {
        id = listId,
        name = normalizedName,
        categoryId = selectedCategory.id,
        deleted = false,
        createdAt = timestamp,
        updatedAt = timestamp,
        deletedAt = nil,
        createdBy = player and player:getUsername() or nil,
        updatedBy = player and player:getUsername() or nil,
        items = {}
    }

    self:_saveAndRefresh("Created item list '" .. normalizedName .. "' (" .. listId .. ") in category '" .. tostring(selectedCategory.id) .. "'")
end

function WL_ItemLists:createCategory(player, categoryName)
    if isClient() then
        self:sendToServer(player or getPlayer(), "createCategory", categoryName)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local normalizedName, nameError = self:_validateCategoryName(categoryName)
    if nameError then
        self:showPlayerError(player, nameError)
        return
    end

    local timestamp = nowTimestamp()
    local categoryId = getRandomUUID()
    self:_getPublicCategories()[categoryId] = {
        id = categoryId,
        name = normalizedName,
        isDefault = false,
        createdAt = timestamp,
        updatedAt = timestamp,
        createdBy = player and player:getUsername() or nil,
        updatedBy = player and player:getUsername() or nil
    }

    self:_saveAndRefresh("Created item list category '" .. normalizedName .. "' (" .. categoryId .. ")")
end

function WL_ItemLists:renameCategory(player, categoryId, newName)
    if isClient() then
        self:sendToServer(player or getPlayer(), "renameCategory", categoryId, newName)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local categoryData, categoryError = self:_validateCategorySelection(categoryId)
    if categoryError then
        self:showPlayerError(player, categoryError)
        return
    end
    if categoryData.isDefault == true then
        self:showPlayerError(player, "The default category cannot be renamed.")
        return
    end

    local normalizedName, nameError = self:_validateCategoryName(newName)
    if nameError then
        self:showPlayerError(player, nameError)
        return
    end

    categoryData.name = normalizedName
    categoryData.updatedAt = nowTimestamp()
    categoryData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh("Renamed item list category '" .. tostring(categoryId) .. "' to '" .. normalizedName .. "'")
end

function WL_ItemLists:deleteCategory(player, categoryId)
    if isClient() then
        self:sendToServer(player or getPlayer(), "deleteCategory", categoryId)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local categoryData, categoryError = self:_validateCategorySelection(categoryId)
    if categoryError then
        self:showPlayerError(player, categoryError)
        return
    end
    if categoryData.isDefault == true then
        self:showPlayerError(player, "The default category cannot be deleted.")
        return
    end

    local assignedListCount = self:_getCategoryListCount(categoryData.id, true)
    if assignedListCount > 0 then
        self:showPlayerError(player, "Only empty categories can be deleted.")
        return
    end

    self:_getPublicCategories()[categoryData.id] = nil
    self:_saveAndRefresh("Deleted item list category '" .. tostring(categoryData.id) .. "'")
end

function WL_ItemLists:renameList(player, listId, newName)
    if isClient() then
        self:sendToServer(player or getPlayer(), "renameList", listId, newName)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local listData = self:_findList(listId)
    local canModifyList, listError = self:_validateMutableList(listData)
    if not canModifyList then
        self:showPlayerError(player, listError)
        return
    end

    local normalizedName, nameError = self:_validateListName(newName)
    if nameError then
        self:showPlayerError(player, nameError)
        return
    end

    listData.name = normalizedName
    listData.updatedAt = nowTimestamp()
    listData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh("Renamed item list '" .. tostring(listId) .. "' to '" .. normalizedName .. "'")
end

function WL_ItemLists:setListCategory(player, listId, categoryId)
    if isClient() then
        self:sendToServer(player or getPlayer(), "setListCategory", listId, categoryId)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local listData = self:_findList(listId)
    local canModifyList, listError = self:_validateMutableList(listData)
    if not canModifyList then
        self:showPlayerError(player, listError)
        return
    end

    local categoryData, categoryError = self:_validateCategorySelection(categoryId)
    if categoryError then
        self:showPlayerError(player, categoryError)
        return
    end

    listData.categoryId = categoryData.id
    listData.updatedAt = nowTimestamp()
    listData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh("Moved item list '" .. tostring(listId) .. "' to category '" .. tostring(categoryData.id) .. "'")
end

function WL_ItemLists:setListDeleted(player, listId, deleted)
    if isClient() then
        self:sendToServer(player or getPlayer(), "setListDeleted", listId, deleted == true)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local listData = self:_findList(listId)
    local canModifyList, listError = self:_validateMutableList(listData)
    if not canModifyList then
        self:showPlayerError(player, listError)
        return
    end

    local isDeleted = deleted == true
    listData.deleted = isDeleted
    listData.deletedAt = isDeleted and nowTimestamp() or nil
    listData.updatedAt = nowTimestamp()
    listData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh((isDeleted and "Soft-deleted" or "Restored") .. " item list '" .. tostring(listId) .. "'")
end

function WL_ItemLists:upsertItemEntry(player, listId, payload)
    if isClient() then
        self:sendToServer(player or getPlayer(), "upsertItemEntry", listId, payload)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local listData = self:_findList(listId)
    if not listData then
        self:showPlayerError(player, "List not found.")
        return
    end

    local itemPayload, validationError = self:_validateItemPayload(payload)
    if validationError then
        self:showPlayerError(player, validationError)
        return
    end

    if itemPayload.entryType == "list" then
        local _, nestedError = self:_validateNestedReference(listId, itemPayload.childListId, itemPayload.id)
        if nestedError then
            self:showPlayerError(player, nestedError)
            return
        end
    end

    local items = listData.items or {}
    listData.items = items

    local existingIndex = nil
    if itemPayload.id then
        existingIndex = self:_findItemIndex(listData, itemPayload.id)
    end

    if existingIndex then
        local existing = items[existingIndex]
        existing.entryType = itemPayload.entryType
        existing.fullType = itemPayload.fullType
        existing.childListId = itemPayload.childListId
        existing.customName = itemPayload.customName
        existing.weight = itemPayload.weight
        existing.qtyMin = itemPayload.qtyMin
        existing.qtyMax = itemPayload.qtyMax
    else
        itemPayload.id = getRandomUUID()
        items[#items + 1] = itemPayload
    end

    listData.updatedAt = nowTimestamp()
    listData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh("Saved item entry in list '" .. tostring(listId) .. "'")
end

function WL_ItemLists:deleteItemEntry(player, listId, itemEntryId)
    if isClient() then
        self:sendToServer(player or getPlayer(), "deleteItemEntry", listId, itemEntryId)
        return
    end

    local canMutate, permissionError = self:_validateStaffPlayer(player)
    if not canMutate then
        self:showPlayerError(player, permissionError)
        return
    end

    local listData = self:_findList(listId)
    if not listData then
        self:showPlayerError(player, "List not found.")
        return
    end

    local itemIndex = self:_findItemIndex(listData, itemEntryId)
    if not itemIndex then
        self:showPlayerError(player, "Item entry not found.")
        return
    end

    table.remove(listData.items, itemIndex)
    listData.updatedAt = nowTimestamp()
    listData.updatedBy = player and player:getUsername() or nil
    self:_saveAndRefresh("Deleted item entry '" .. tostring(itemEntryId) .. "' from list '" .. tostring(listId) .. "'")
end
