require "ISUI/ISCollapsableWindow"
require "UI/LayoutManager/LayoutManager"
require "WL_Utils"
require "UI/WL_Dialogs"
require "UI/WL_TextEntryPanel"
require "UI/WL_ItemListItemDialog"
require "UI/WL_ItemListSubListDialog"
require "UI/WL_ItemListRollSimulatorDialog"
require "UI/WL_ItemPickerDialog"

WL_ItemListManagerWindow = ISCollapsableWindow:derive("WL_ItemListManagerWindow")
WL_ItemListManagerWindow.instance = nil

local function containsInsensitive(haystack, needle)
    local source = tostring(haystack or "")
    local query = tostring(needle or "")
    if query == "" then
        return true
    end
    return string.find(string.lower(source), string.lower(query), 1, true) ~= nil
end

local function formatTimestamp(value)
    local stamp = tonumber(value)
    if not stamp then
        return "-"
    end
    return tostring(stamp)
end

local function getItemStatusText(listData)
    if not listData then
        return "Select a list to manage items."
    end
    if listData.deleted then
        return "This list is deleted. Restore it before editing items."
    end
    return ""
end

local function formatPercent(value)
    local percent = (tonumber(value) or 0) * 100
    return string.format("%.2f%%", percent)
end

local function formatQtyRange(entry)
    return tostring(entry.qtyMin or 1) .. "-" .. tostring(entry.qtyMax or 1)
end

local function getEventOwner(self)
    if self and self.rebuildDetails then
        return self
    end
    if self and self.target and self.target.rebuildDetails then
        return self.target
    end
    if self and self.parent and self.parent.rebuildDetails then
        return self.parent
    end
    if self and self.parent and self.parent.target and self.parent.target.rebuildDetails then
        return self.parent.target
    end
    return self
end

local function getComboBoxSelectedData(comboBox)
    local selectedIndex = comboBox and tonumber(comboBox.selected) or 0
    if selectedIndex < 1 then
        return nil
    end
    return comboBox:getOptionData(selectedIndex)
end

function WL_ItemListManagerWindow:show(player)
    local localPlayer = player or getPlayer()
    if not localPlayer then
        return nil
    end

    if not WL_Utils.isStaff(localPlayer) then
        WL_Dialogs.showMessageDialog("Only staff can open the item list manager.")
        return nil
    end

    if self.instance then
        self.instance:close()
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(600 * scale)
    local height = math.floor(600 * scale)
    local o = WL_ItemListManagerWindow:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, localPlayer)
    o:initialise()
    o:addToUIManager()
    self.instance = o
    return o
end

function WL_ItemListManagerWindow.refreshOpenWindow()
    if WL_ItemListManagerWindow.instance then
        WL_ItemListManagerWindow.instance:refreshData(true)
    end
end

function WL_ItemListManagerWindow:new(x, y, width, height, player)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.player = player
    o.moveWithMouse = true
    o.resizable = true
    o.pin = true
    o.alwaysOnTop = true
    o.title = "Item Lists Manager"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }

    o.allSummaries = {}
    o.allCategories = {}
    o.filteredSummaries = {}
    o.filteredListRows = {}
    o.selectedCategoryId = WL_ItemLists and WL_ItemLists.DEFAULT_CATEGORY_ID or "default"
    o.selectedListId = nil
    o.selectedItemEntryId = nil
    o.expandedRows = {}
    o.itemRows = {}

    return o
end

function WL_ItemListManagerWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function WL_ItemListManagerWindow:createChildren()
    if self._childrenCreated then
        return
    end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)

    self:applyLayout()

    self:refreshData(false)
end

function WL_ItemListManagerWindow:bindElements()
    self.listSearchInput = self.elements.listSearchInput
    self.showDeletedTickbox = self.elements.showDeletedTickbox
    self.listsList = self.elements.listsList
    self.selectedListTitle = self.elements.selectedListTitle
    self.listStatusValue = self.elements.listStatusValue
    self.listAuditValue = self.elements.listAuditValue
    self.itemsList = self.elements.itemsList

    self.addCategoryButton = self.elements.addCategoryButton
    self.renameCategoryButton = self.elements.renameCategoryButton
    self.deleteCategoryButton = self.elements.deleteCategoryButton
    self.addListButton = self.elements.addListButton
    self.renameListButton = self.elements.renameListButton
    self.toggleDeletedButton = self.elements.toggleDeletedButton
    self.listCategoryCombo = self.elements.listCategoryCombo
    self.moveListButton = self.elements.moveListButton
    self.addItemButton = self.elements.addItemButton
    self.addSubListButton = self.elements.addSubListButton
    self.editEntryButton = self.elements.editEntryButton
    self.deleteEntryButton = self.elements.deleteEntryButton
    self.simulateButton = self.elements.simulateButton
    self.refreshButton = self.elements.refreshButton
    self.closeButton = self.elements.closeButton

    local owner = self
    self.listsList.doDrawItem = function(list, y, item, alt)
        return owner:drawListRow(list, y, item, alt)
    end
    self.itemsList.doDrawItem = function(list, y, item, alt)
        return owner:drawItemRow(list, y, item, alt)
    end
    self.listsList.onMouseDown = function(list, x, y)
        return owner:onListsListMouseDown(list, x, y)
    end
    self.itemsList.onMouseDown = function(list, x, y)
        return owner:onItemsListMouseDown(list, x, y)
    end
    self.itemsList.itemheightoverride = self.itemsList.itemheightoverride or {}

    if self.listAuditValue.setAlign then
        self.listAuditValue:setAlign("right")
    else
        self.listAuditValue.align = "right"
    end
end

function WL_ItemListManagerWindow:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self:bindElements()
end

function WL_ItemListManagerWindow:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local headerHeight = 20 * scale
    local titleHeight = 24 * scale
    local searchHeight = 22 * scale
    local actionHeight = 26 * scale
    local statusHeight = 20 * scale
    local rowHeight = 22 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2) - 16 * scale

    return {
        type = "rows",
        x = margin,
        y = margin + 6 * scale,
        width = tostring(rootWidth) .. "px",
        height = tostring(rootHeight) .. "px",
        pad = pad,
        rows = {
            { type = "label", id = "windowTitle", width = "inherit", height = titleHeight, text = "WastelandLib Item Lists", font = UIFont.Medium, center = true },
            { type = "columns", id = "mainColumns", width = "inherit", height = "*", pad = pad, columns = {
                { type = "panel", id = "listsPanel", width = "38%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.94 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = {
                    type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "label", id = "listsHeader", width = "inherit", height = headerHeight, text = "Lists", font = UIFont.Small, color = { r = 0.82, g = 0.9, b = 1, a = 1 } },
                        { type = "textbox", id = "listSearchInput", width = "inherit", height = searchHeight, text = "", target = self, onTextChange = self.onSearchChanged, clearButton = true, tooltip = "Search lists or categories" },
                        { type = "tickbox", id = "showDeletedTickbox", width = "inherit", height = headerHeight, options = { "Show deleted lists" }, selected = { false }, target = self, onChange = self.onShowDeletedChanged },
                        { type = "scrollinglistbox", id = "listsList", width = "inherit", height = "*", itemheight = rowHeight, font = UIFont.Small },
                        { type = "columns", id = "listActionsRow1", width = "inherit", height = actionHeight, pad = 6, columns = {
                            { type = "button", id = "addCategoryButton", width = "*", text = "Add Category", target = self, onClick = self.onAddCategory },
                            { type = "button", id = "renameCategoryButton", width = "*", text = "Rename Category", target = self, onClick = self.onRenameCategory, enabled = false }
                        }},
                        { type = "columns", id = "listActionsRow2", width = "inherit", height = actionHeight, pad = 6, columns = {
                            { type = "button", id = "deleteCategoryButton", width = "*", text = "Delete Category", target = self, onClick = self.onDeleteCategory, enabled = false },
                            { type = "button", id = "addListButton", width = "*", text = "Add List", target = self, onClick = self.onAddList }
                        }},
                        { type = "columns", id = "listActionsRow3", width = "inherit", height = actionHeight, pad = 6, columns = {
                            { type = "button", id = "renameListButton", width = "*", text = "Rename List", target = self, onClick = self.onRenameList, enabled = false },
                            { type = "button", id = "toggleDeletedButton", width = "*", text = "Delete / Restore", target = self, onClick = self.onToggleDeleted, enabled = false }
                        }}
                    }
                }},
                { type = "panel", id = "detailsPanel", width = "62%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.94 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = {
                    type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "columns", id = "detailsHeaderRow", width = "inherit", height = titleHeight, columns = {
                            { type = "label", id = "selectedListTitle", width = "*", height = titleHeight, text = "No list selected", font = UIFont.Medium, color = { r = 1, g = 1, b = 1, a = 1 } },
                            { type = "label", id = "listStatusValue", width = "18%", text = "", font = UIFont.NewSmall, align = "right", color = { r = 0.88, g = 0.88, b = 0.88, a = 1 } }
                        }},
                        { type = "columns", id = "listMetaRow", width = "inherit", height = headerHeight, columns = {
                            { type = "label", id = "listAuditValue", text = "", font = UIFont.NewSmall, align = "right", color = { r = 0.7, g = 0.7, b = 0.7, a = 1 } }
                        }},
                        { type = "columns", id = "listCategoryRow", width = "inherit", height = actionHeight, pad = 6, columns = {
                            { type = "label", id = "listCategoryLabel", width = "22%", text = "Category", font = UIFont.NewSmall, color = { r = 0.8, g = 0.8, b = 0.8, a = 1 } },
                            { type = "combobox", id = "listCategoryCombo", width = "50%", options = {}, noSelectionText = "Select Category", target = self, onChange = self.onListCategoryChanged, disabled = true },
                            { type = "button", id = "moveListButton", width = "28%", text = "Move", target = self, onClick = self.onMoveList, enabled = false }
                        }},
                        { type = "label", id = "itemsHeader", width = "inherit", height = headerHeight, text = "Items", font = UIFont.Small, color = { r = 0.82, g = 1, b = 0.82, a = 1 } },
                        { type = "scrollinglistbox", id = "itemsList", width = "inherit", height = "*", itemheight = 38 * scale, font = UIFont.Small },
                        { type = "columns", id = "itemActionsRow", width = "inherit", height = actionHeight, pad = 6, margin = { 0, 0, 0, 0 }, columns = {
                            { type = "button", id = "addItemButton", width = "*", text = "Add Item", target = self, onClick = self.onAddItem, enabled = false },
                            { type = "button", id = "addSubListButton", width = "*", text = "Add List", target = self, onClick = self.onAddSubList, enabled = false },
                            { type = "button", id = "editEntryButton", width = "*", text = "Edit", target = self, onClick = self.onEditEntry, enabled = false }
                        }},
                        { type = "columns", id = "itemActionsRow2", width = "inherit", height = actionHeight, pad = 6, margin = { 0, 0, 0, 0 }, columns = {
                            { type = "button", id = "deleteEntryButton", width = "*", text = "Delete", target = self, onClick = self.onDeleteItem, enabled = false },
                            { type = "button", id = "simulateButton", width = "*", text = "Simulate Rolls", target = self, onClick = self.onSimulateRolls, enabled = false }
                        }},
                    }
                }}
            }},
            { type = "columns", id = "footerActions", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "refreshButton", width = "*", text = "Refresh", target = self, onClick = self.onRefresh },
                { type = "button", id = "closeButton", width = "*", text = "Close", target = self, onClick = self.onCloseButton }
            }}
        }
    }
end

function WL_ItemListManagerWindow:onResize()
    ISUIElement.onResize(self)
    if not self._childrenCreated then
        return
    end

    self:applyLayout()
    self:refreshData(true)
end

function WL_ItemListManagerWindow:getShowDeleted()
    return self.showDeletedTickbox:isSelected(1)
end

function WL_ItemListManagerWindow:getSearchText()
    return self.listSearchInput:getInternalText() or self.listSearchInput:getText() or ""
end

function WL_ItemListManagerWindow:refreshData(keepSelection)
    local selectedCategoryId = keepSelection and self.selectedCategoryId or nil
    local selectedListId = keepSelection and self.selectedListId or nil
    local selectedItemEntryId = keepSelection and self.selectedItemEntryId or nil

    self.allCategories = WL_ItemLists:getCategorySummaries(self:getShowDeleted())
    self.allSummaries = WL_ItemLists:getListSummaries(self:getShowDeleted())
    self:applyListFilter(self:getSearchText(), selectedCategoryId, selectedListId, selectedItemEntryId)
end

function WL_ItemListManagerWindow:getSelectedCategorySummary()
    local categoryId = self.selectedCategoryId
    if not categoryId then
        local summary = self:getSelectedSummary()
        categoryId = summary and summary.categoryId or nil
    end
    if not categoryId then
        return nil
    end

    for i = 1, #self.allCategories do
        local category = self.allCategories[i]
        if category.id == categoryId then
            return category
        end
    end

    return nil
end

function WL_ItemListManagerWindow:getActiveCategoryId()
    local categorySummary = self:getSelectedCategorySummary()
    if categorySummary then
        return categorySummary.id
    end

    local listSummary = self:getSelectedSummary()
    if listSummary and listSummary.categoryId then
        return listSummary.categoryId
    end

    return WL_ItemLists.DEFAULT_CATEGORY_ID
end

function WL_ItemListManagerWindow:applyListFilter(searchText, preferredCategoryId, preferredListId, preferredItemEntryId)
    local query = tostring(searchText or "")
    self.filteredSummaries = {}
    self.filteredListRows = {}
    self.listsList:clear()

    for i = 1, #self.allSummaries do
        self.filteredSummaries[#self.filteredSummaries + 1] = self.allSummaries[i]
    end

    for categoryIndex = 1, #self.allCategories do
        local category = self.allCategories[categoryIndex]
        local categoryMatches = containsInsensitive(category.name, query)
        local categoryRows = {}

        for summaryIndex = 1, #self.filteredSummaries do
            local summary = self.filteredSummaries[summaryIndex]
            if summary.categoryId == category.id then
                local listMatches = containsInsensitive(summary.name, query) or containsInsensitive(summary.displayName, query)
                if query == "" or categoryMatches or listMatches then
                    categoryRows[#categoryRows + 1] = {
                        rowType = "list",
                        id = summary.id,
                        categoryId = category.id,
                        summary = summary,
                        displayName = summary.displayName or summary.name,
                        itemCount = summary.itemCount,
                        deleted = summary.deleted == true
                    }
                end
            end
        end

        if query == "" or categoryMatches or #categoryRows > 0 then
            self.filteredListRows[#self.filteredListRows + 1] = {
                rowType = "category",
                id = category.id,
                categoryId = category.id,
                category = category,
                displayName = category.displayName or category.name,
                itemCount = category.listCount or 0,
                isDefault = category.isDefault == true
            }

            for i = 1, #categoryRows do
                self.filteredListRows[#self.filteredListRows + 1] = categoryRows[i]
            end
        end
    end

    local selectedIndex = 0
    self.selectedCategoryId = nil
    self.selectedListId = nil

    for i = 1, #self.filteredListRows do
        local row = self.filteredListRows[i]
        self.listsList:addItem(tostring(row.displayName or row.id or "Unknown"), row)
        self.listsList.items[#self.listsList.items].height = self.listsList.itemheight

        if selectedIndex == 0 and row.rowType == "list" and row.id == preferredListId then
            self.selectedCategoryId = row.categoryId
            self.selectedListId = preferredListId
            selectedIndex = i
        end
    end

    if selectedIndex == 0 and preferredCategoryId then
        for i = 1, #self.filteredListRows do
            local row = self.filteredListRows[i]
            if row.rowType == "category" and row.categoryId == preferredCategoryId then
                self.selectedCategoryId = row.categoryId
                selectedIndex = i
                break
            end
        end
    end

    if selectedIndex == 0 then
        for i = 1, #self.filteredListRows do
            local row = self.filteredListRows[i]
            if row.rowType == "list" then
                self.selectedCategoryId = row.categoryId
                self.selectedListId = row.id
                selectedIndex = i
                break
            end
        end
    end

    if selectedIndex == 0 and #self.filteredListRows > 0 then
        local row = self.filteredListRows[1]
        self.selectedCategoryId = row.categoryId
        self.selectedListId = row.rowType == "list" and row.id or nil
        selectedIndex = 1
    end

    self.listsList.selected = selectedIndex
    self.selectedItemEntryId = preferredItemEntryId
    self:rebuildDetails()
end

function WL_ItemListManagerWindow:getSelectedSummary()
    if not self.selectedListId then
        return nil
    end

    for i = 1, #self.filteredSummaries do
        local summary = self.filteredSummaries[i]
        if summary.id == self.selectedListId then
            return summary
        end
    end

    return nil
end

function WL_ItemListManagerWindow:getSelectedList()
    if not self.selectedListId then
        return nil
    end
    return WL_ItemLists:getListById(self.selectedListId, true)
end

function WL_ItemListManagerWindow:getSelectedItemEntry(listData)
    local resolvedList = listData or self:getSelectedList()
    if not resolvedList or not self.selectedItemEntryId then
        return nil
    end

    local items = resolvedList.items or {}
    for i = 1, #items do
        if items[i].id == self.selectedItemEntryId then
            return items[i]
        end
    end
    return nil
end

function WL_ItemListManagerWindow:getSelectedRow()
    for i = 1, #self.itemRows do
        local row = self.itemRows[i]
        if row.sourceEntryId == self.selectedItemEntryId then
            return row
        end
    end
    return nil
end

function WL_ItemListManagerWindow:getEntryChanceMap(listData)
    local map = {}
    if not listData then
        return map
    end

    local chanceReport = WL_ItemLists:getEffectiveChances(listData.id)
    local entries = chanceReport and chanceReport.entries or {}
    for i = 1, #entries do
        local entry = entries[i]
        local key = tostring(entry.sourceEntryId or "")
        if key ~= "" then
            local existing = map[key]
            if existing then
                existing.effectiveChance = 1 - ((1 - existing.effectiveChance) * (1 - (entry.effectiveChance or 0)))
            else
                map[key] = {
                    effectiveChance = entry.effectiveChance or 0,
                    path = entry.path
                }
            end
        end
    end

    return map
end

function WL_ItemListManagerWindow:getExpandedRowKey(row)
    return tostring(row.expandKey or row.sourceEntryId or row.childListId or "")
end

function WL_ItemListManagerWindow:isRowExpanded(row)
    return self.expandedRows[self:getExpandedRowKey(row)] == true
end

function WL_ItemListManagerWindow:toggleRowExpanded(row)
    local key = self:getExpandedRowKey(row)
    if key == "" then
        return
    end
    self.expandedRows[key] = not self.expandedRows[key]
end

function WL_ItemListManagerWindow:buildItemRowViewModel(entry, chanceMap)
    local effectiveChance = chanceMap[tostring(entry.id or "")]
    local isListEntry = entry.entryType == "list"
    local chanceText = effectiveChance and formatPercent(effectiveChance.effectiveChance) or "-"
    local metaText = "Wt " .. tostring(entry.weight or 0) .. " | Qty " .. formatQtyRange(entry) .. " | Chance " .. chanceText

    return {
        rowType = "entry",
        depth = 0,
        isExpandable = isListEntry and not entry.isMissingReference,
        isExpanded = false,
        isSelectable = true,
        entryType = entry.entryType,
        displayName = entry.displayName or entry.fullType or entry.childListId or "Unknown",
        displaySubtext = entry.displaySubtext or entry.fullType or "",
        chanceText = chanceText,
        metaText = metaText,
        sourceEntryId = entry.id,
        childListId = entry.childListId,
        itemEntry = entry,
        expandKey = tostring(entry.id or "")
    }
end

function WL_ItemListManagerWindow:appendDescendantRows(rows, row, depth, ancestry)
    if not row.childListId then
        return
    end

    local childList = WL_ItemLists:getListById(row.childListId, true)
    if not childList then
        rows[#rows + 1] = {
            rowType = "summary",
            depth = depth,
            isExpandable = false,
            isExpanded = false,
            isSelectable = false,
            entryType = "summary",
            displayName = "Missing child list",
            displaySubtext = "This child list is unavailable.",
            chanceText = "-",
            metaText = "Reference unavailable",
            sourceEntryId = row.sourceEntryId,
            childListId = row.childListId,
            expandKey = tostring(row.expandKey or "") .. "::missing"
        }
        return
    end

    local chanceMap = self:getEntryChanceMap(childList)
    local items = childList.items or {}
    table.sort(items, function(a, b)
        local aName = string.lower(tostring(a.displayName or a.customName or a.fullType or a.childListId or ""))
        local bName = string.lower(tostring(b.displayName or b.customName or b.fullType or b.childListId or ""))
        if aName == bName then
            return tostring(a.id or "") < tostring(b.id or "")
        end
        return aName < bName
    end)

    for i = 1, #items do
        local entry = items[i]
        local effectiveChance = chanceMap[tostring(entry.id or "")]
        local isListEntry = entry.entryType == "list"
        local descendantRow = {
            rowType = "expanded-descendant",
            depth = depth,
            isExpandable = isListEntry and not entry.isMissingReference,
            isExpanded = false,
            isSelectable = false,
            entryType = entry.entryType,
            displayName = entry.displayName or entry.fullType or entry.childListId or "Unknown",
            displaySubtext = entry.displaySubtext or entry.fullType or "",
            chanceText = effectiveChance and formatPercent(effectiveChance.effectiveChance) or "-",
            metaText = "Wt " .. tostring(entry.weight or 0) .. " | Qty " .. formatQtyRange(entry) .. " | Chance " .. (effectiveChance and formatPercent(effectiveChance.effectiveChance) or "-"),
            sourceEntryId = row.sourceEntryId,
            childListId = entry.childListId,
            itemEntry = entry,
            expandKey = tostring(row.expandKey or row.sourceEntryId or "") .. "::" .. tostring(entry.id or i),
            path = ancestry
        }
        descendantRow.isExpanded = descendantRow.isExpandable and self:isRowExpanded(descendantRow)
        rows[#rows + 1] = descendantRow
        if descendantRow.isExpanded then
            self:appendDescendantRows(rows, descendantRow, depth + 1, ancestry)
        end
    end
end

function WL_ItemListManagerWindow:rebuildDetails()
    local listData = self:getSelectedList()
    local categorySummary = self:getSelectedCategorySummary()

    if not listData then
        self.selectedItemEntryId = nil
        if categorySummary then
            self.selectedListTitle:setName("Category: " .. tostring(categorySummary.displayName or categorySummary.name or "Unnamed Category"))
            self.listStatusValue:setName(categorySummary.isDefault and "Default" or "Category")
            self.listAuditValue:setName("Lists " .. tostring(categorySummary.listCount or 0) .. "  Created " .. formatTimestamp(categorySummary.createdAt) .. "  Updated " .. formatTimestamp(categorySummary.updatedAt))
        else
            self.selectedListTitle:setName("No list selected")
            self.listStatusValue:setName("")
            self.listAuditValue:setName("")
        end
        self.itemsList:clear()
        self:refreshCategoryMoveOptions(nil)
        self:updateActionButtons(nil)
        return
    end

    self.selectedListTitle:setName(WL_ItemLists:getListNameById(listData.id, true) or tostring(listData.name or "Unnamed List"))
    self.listStatusValue:setName(listData.deleted and "Deleted" or "Active")
    self.listAuditValue:setName("Category " .. tostring(listData.categoryDisplayName or listData.categoryName or "Default") .. "  Created " .. formatTimestamp(listData.createdAt) .. "  Updated " .. formatTimestamp(listData.updatedAt))

    self:refreshCategoryMoveOptions(listData.categoryId)
    self:rebuildItemsList(listData)
    self:updateActionButtons(listData)
end

function WL_ItemListManagerWindow:refreshCategoryMoveOptions(selectedCategoryId)
    self.listCategoryCombo:clear()

    local selectedIndex = 0
    for i = 1, #self.allCategories do
        local category = self.allCategories[i]
        self.listCategoryCombo:addOptionWithData(tostring(category.displayName or category.name or "Unnamed Category"), category.id)
        if category.id == selectedCategoryId then
            selectedIndex = i
        end
    end

    self.listCategoryCombo.selected = selectedIndex
    self.listCategoryCombo.disabled = selectedCategoryId == nil
end

function WL_ItemListManagerWindow:rebuildItemsList(listData)
    self.itemsList:clear()
    self.itemsList.itemheightoverride = {}
    self.itemRows = {}

    local items = listData.items or {}
    local chanceMap = self:getEntryChanceMap(listData)
    table.sort(items, function(a, b)
        local aName = string.lower(tostring(a.displayName or a.customName or a.fullType or ""))
        local bName = string.lower(tostring(b.displayName or b.customName or b.fullType or ""))
        if aName == bName then
            return tostring(a.id or "") < tostring(b.id or "")
        end
        return aName < bName
    end)

    local selectedIndex = 0
    local preferredId = self.selectedItemEntryId
    local rows = {}

    for i = 1, #items do
        local itemEntry = items[i]
        local row = self:buildItemRowViewModel(itemEntry, chanceMap)
        row.isExpanded = row.isExpandable and self:isRowExpanded(row)
        rows[#rows + 1] = row
        if row.isExpanded then
            self:appendDescendantRows(rows, row, 1, {
                {
                    listId = listData.id,
                    listName = listData.name,
                    entryId = itemEntry.id,
                    displayName = row.displayName
                }
            })
        end
    end

    self.itemRows = rows

    for i = 1, #rows do
        local row = rows[i]
        self.itemsList:addItem(tostring(row.displayName or "Unknown"), row)
        self.itemsList.items[#self.itemsList.items].height = self.itemsList.itemheight
        if row.rowType == "entry" and row.sourceEntryId == preferredId then
            selectedIndex = i
        end
    end

    if #rows == 0 then
        self.selectedItemEntryId = nil
        self.itemsList.selected = 0
        return
    end

    if selectedIndex == 0 then
        for i = 1, #rows do
            if rows[i].rowType == "entry" then
                self.selectedItemEntryId = rows[i].sourceEntryId
                selectedIndex = i
                break
            end
        end
    end

    self.itemsList.selected = selectedIndex
end

function WL_ItemListManagerWindow:updateActionButtons(listData)
    local summary = self:getSelectedSummary()
    local categorySummary = self:getSelectedCategorySummary()
    local hasList = summary ~= nil and listData ~= nil
    local hasCategory = categorySummary ~= nil
    local listDeleted = hasList and listData.deleted == true
    local selectedRow = hasList and self:getSelectedRow() or nil
    local hasItem = hasList and selectedRow ~= nil and selectedRow.rowType == "entry"
    local moveTargetCategoryId = getComboBoxSelectedData(self.listCategoryCombo)

    self.renameCategoryButton:setEnable(hasCategory and categorySummary.canRename == true)
    self.deleteCategoryButton:setEnable(hasCategory and categorySummary.canDelete == true)

    self.renameListButton:setEnable(hasList)
    self.toggleDeletedButton:setEnable(hasList)
    if self.toggleDeletedButton.setTitle then
        self.toggleDeletedButton:setTitle(listDeleted and "Restore List" or "Delete List")
    elseif self.toggleDeletedButton.setName then
        self.toggleDeletedButton:setName(listDeleted and "Restore List" or "Delete List")
    end

    self.addListButton:setEnable(self:getActiveCategoryId() ~= nil)
    self.listCategoryCombo.disabled = not hasList
    self.moveListButton:setEnable(hasList and moveTargetCategoryId ~= nil and moveTargetCategoryId ~= listData.categoryId)
    self.addItemButton:setEnable(hasList)
    self.addSubListButton:setEnable(hasList)
    self.editEntryButton:setEnable(hasItem)
    self.deleteEntryButton:setEnable(hasItem)
    self.simulateButton:setEnable(hasList)
end

function WL_ItemListManagerWindow:onSearchChanged()
    local text = self:getInternalText() or self:getText() or ""
    local owner = getEventOwner(self)
    owner:applyListFilter(text, owner.selectedCategoryId, owner.selectedListId, owner.selectedItemEntryId)
end

function WL_ItemListManagerWindow:onShowDeletedChanged()
    local owner = getEventOwner(self)
    owner:refreshData(true)
end

function WL_ItemListManagerWindow:onListsListMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then
        return false
    end

    list.selected = row
    local clicked = list.items[row]
    local selected = clicked and clicked.item or nil
    self.selectedCategoryId = selected and selected.categoryId or nil
    self.selectedListId = selected and selected.rowType == "list" and selected.id or nil
    self.selectedItemEntryId = nil
    self:rebuildDetails()
    return true
end

function WL_ItemListManagerWindow:onItemsListMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then
        return false
    end

    list.selected = row
    local clicked = list.items[row]
    local selected = clicked and clicked.item or nil
    if selected and selected.isExpandable and x <= 24 + (selected.depth * 18) then
        self:toggleRowExpanded(selected)
        self:rebuildItemsList(self:getSelectedList())
        self:updateActionButtons(self:getSelectedList())
        return true
    end

    if selected and selected.rowType == "entry" then
        self.selectedItemEntryId = selected.sourceEntryId
    end
    self:updateActionButtons(self:getSelectedList())
    return true
end

function WL_ItemListManagerWindow:drawListRow(list, y, item, alt)
    if not item then
        return y
    end
    local row = item.item or {}
    local itemHeight = item.height or list.itemheight

    if row.rowType == "category" then
        list:drawRect(0, y, list:getWidth(), itemHeight, list.selected == item.index and 0.22 or 0.12, 0.2, 0.24, 0.3)
        local category = row.category or {}
        local label = tostring(category.displayName or category.name or item.text or "Unnamed Category")
        if category.isDefault == true then
            label = label .. " [Default]"
        end
        list:drawText(label, 6, y + 3, 0.82, 0.9, 1, 0.95, list.font)
        list:drawTextRight(tostring(category.listCount or row.itemCount or 0), list:getWidth() - 8, y + 3, 0.78, 0.78, 0.78, 0.9, list.font)
        return y + itemHeight
    end

    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.22, 0.65, 0.3, 0.2)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.07, 1, 1, 1)
    end

    local summary = row.summary or {}
    local name = tostring(summary.displayName or summary.name or item.text or "Unnamed")
    local itemCount = tonumber(summary.itemCount) or 0
    local nameR, nameG, nameB = 1, 1, 1
    if summary.deleted == true then
        nameR, nameG, nameB = 0.85, 0.78, 0.78
    end

    list:drawText(name, 20, y + 3, nameR, nameG, nameB, 0.95, list.font)
    list:drawTextRight(tostring(itemCount), list:getWidth() - 8, y + 3, 0.8, 0.8, 0.8, 0.9, list.font)
    return y + itemHeight
end

function WL_ItemListManagerWindow:drawItemRow(list, y, item, alt)
    if not item then
        return y
    end

    local key = tostring((item.item and item.item.id) or item.text or item.index or y)
    local cachedHeight = list.itemheightoverride and list.itemheightoverride[key] or list.itemheight
    if y + list:getYScroll() + cachedHeight < 0 or y + list:getYScroll() >= list.height then
        return y + cachedHeight
    end

    local itemHeight = math.max(list.itemheight, 38)
    if list.itemheightoverride then
        list.itemheightoverride[key] = itemHeight
    end
    item.height = itemHeight

    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.22, 0.65, 0.3, 0.2)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.05, 1, 1, 1)
    end

    local row = item.item or {}
    local depth = tonumber(row.depth) or 0
    local indent = 6 + (depth * 18)
    local marker = ""
    if row.isExpandable then
        marker = row.isExpanded and "▼ " or "▶ "
    end

    local nameR, nameG, nameB = 1, 1, 1
    if row.entryType == "list" then
        nameR, nameG, nameB = 0.72, 0.88, 1
    end
    if row.itemEntry and row.itemEntry.isMissingReference then
        nameR, nameG, nameB = 1, 0.72, 0.32
    end
    if row.rowType == "expanded-descendant" then
        nameR = math.min(nameR, 0.92)
        nameG = math.min(nameG, 0.92)
        nameB = math.min(nameB, 0.92)
    end

    list:drawText(marker .. tostring(row.displayName or item.text or "Unknown"), indent, y + 2, nameR, nameG, nameB, 0.95, UIFont.Small)
    list:drawText(tostring(row.displaySubtext or ""), indent, y + 18, 0.78, 0.78, 0.78, 0.9, UIFont.NewSmall)
    list:drawTextRight(tostring(row.metaText or ""), list:getWidth() - 8, y + 18, 0.78, 0.78, 0.78, 0.9, UIFont.NewSmall)
    return y + itemHeight
end

function WL_ItemListManagerWindow:onListCategoryChanged()
    local owner = getEventOwner(self)
    owner:updateActionButtons(owner:getSelectedList())
end

function WL_ItemListManagerWindow:prepareCategoryReveal(searchText)
    self.selectedCategoryId = nil
    self.selectedListId = nil
    self.selectedItemEntryId = nil

    if self.listSearchInput and self.listSearchInput.setText then
        self.listSearchInput:setText(tostring(searchText or ""))
    end
end

function WL_ItemListManagerWindow:onAddCategory()
    WL_TextEntryPanel:show("Enter category name", nil, function(_, newName)
        self:prepareCategoryReveal(newName)
        WL_ItemLists:createCategory(self.player, newName)
    end, "")
end

function WL_ItemListManagerWindow:onRenameCategory()
    local categorySummary = self:getSelectedCategorySummary()
    if not categorySummary or categorySummary.canRename ~= true then
        return
    end

    WL_TextEntryPanel:show("Rename category", nil, function(_, newName)
        self:prepareCategoryReveal(newName)
        WL_ItemLists:renameCategory(self.player, categorySummary.id, newName)
    end, categorySummary.name)
end

function WL_ItemListManagerWindow:onDeleteCategory()
    local categorySummary = self:getSelectedCategorySummary()
    if not categorySummary or categorySummary.canDelete ~= true then
        return
    end

    WL_Dialogs.showConfirmationDialog("Delete empty category '" .. tostring(categorySummary.displayName or categorySummary.name) .. "'?", function()
        WL_ItemLists:deleteCategory(self.player, categorySummary.id)
    end)
end

function WL_ItemListManagerWindow:onAddList()
    local targetCategoryId = self:getActiveCategoryId()
    WL_TextEntryPanel:show("Enter item list name", nil, function(_, newName)
        WL_ItemLists:createList(self.player, newName, targetCategoryId)
    end, "")
end

function WL_ItemListManagerWindow:onRenameList()
    local summary = self:getSelectedSummary()
    if not summary then
        return
    end

    WL_TextEntryPanel:show("Rename item list", nil, function(_, newName)
        WL_ItemLists:renameList(self.player, summary.id, newName)
    end, summary.name)
end

function WL_ItemListManagerWindow:onToggleDeleted()
    local summary = self:getSelectedSummary()
    if not summary then
        return
    end

    local deleteTarget = summary.deleted ~= true
    local listLabel = tostring(summary.displayName or summary.name)
    local message = deleteTarget and ("Soft-delete list '" .. listLabel .. "'?") or ("Restore list '" .. listLabel .. "'?")
    WL_Dialogs.showConfirmationDialog(message, function()
        WL_ItemLists:setListDeleted(self.player, summary.id, deleteTarget)
    end)
end

function WL_ItemListManagerWindow:onMoveList()
    local summary = self:getSelectedSummary()
    local targetCategoryId = getComboBoxSelectedData(self.listCategoryCombo)
    if not summary or not targetCategoryId or targetCategoryId == summary.categoryId then
        return
    end

    WL_ItemLists:setListCategory(self.player, summary.id, targetCategoryId)
end

function WL_ItemListManagerWindow:onAddItem()
    local listData = self:getSelectedList()
    if not listData then
        return
    end

    WL_ItemPickerDialog:show(nil, function(selectedFullType)
        self:onAddItemPicked(selectedFullType)
    end, {
        closeOnConfirm = false,
        cancelReturnsNil = false
    })
end

function WL_ItemListManagerWindow:onAddItemPicked(selectedFullType)
    local listData = self:getSelectedList()
    if not listData or not selectedFullType then
        return
    end

    WL_ItemLists:upsertItemEntry(self.player, listData.id, {
        entryType = "item",
        fullType = selectedFullType,
        customName = nil,
        childListId = nil,
        weight = 1,
        qtyMin = 1,
        qtyMax = 1
    })
end

function WL_ItemListManagerWindow:onAddSubList()
    local listData = self:getSelectedList()
    if not listData then
        return
    end

    WL_ItemListSubListDialog:show(listData, nil, self, self.onEntryDialogSaved)
end

function WL_ItemListManagerWindow:onEditEntry()
    local listData = self:getSelectedList()
    local selectedRow = self:getSelectedRow()
    local itemEntry = selectedRow and selectedRow.itemEntry or self:getSelectedItemEntry(listData)
    if not listData or not itemEntry then
        return
    end

    if itemEntry.entryType == "list" then
        WL_ItemListSubListDialog:show(listData, itemEntry, self, self.onEntryDialogSaved)
    else
        WL_ItemListItemDialog:show(listData, itemEntry, self, self.onEntryDialogSaved)
    end
end

function WL_ItemListManagerWindow:onEntryDialogSaved(payload)
    local listData = self:getSelectedList()
    if not listData then
        return
    end

    WL_ItemLists:upsertItemEntry(self.player, listData.id, payload)
end

function WL_ItemListManagerWindow:onDeleteItem()
    local listData = self:getSelectedList()
    local selectedRow = self:getSelectedRow()
    local itemEntry = selectedRow and selectedRow.itemEntry or self:getSelectedItemEntry(listData)
    if not listData or not itemEntry then
        return
    end

    local message = "Delete entry '" .. tostring(itemEntry.displayName or itemEntry.fullType or itemEntry.childListId or itemEntry.id) .. "'?"
    WL_Dialogs.showConfirmationDialog(message, function()
        WL_ItemLists:deleteItemEntry(self.player, listData.id, itemEntry.id)
    end)
end

function WL_ItemListManagerWindow:onRefresh()
    self:refreshData(true)
end

function WL_ItemListManagerWindow:onSimulateRolls()
    local listData = self:getSelectedList()
    if not listData then
        return
    end

    WL_ItemListRollSimulatorDialog:show(listData, self.player)
end

function WL_ItemListManagerWindow:onCloseButton()
    self:close()
end

function WL_ItemListManagerWindow:close()
    WL_ItemListManagerWindow.instance = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end
