require "ISUI/ISPanel"
require "UI/LayoutManager/LayoutManager"

WL_ItemListPickerDialog = ISPanel:derive("WL_ItemListPickerDialog")
WL_ItemListPickerDialog.instance = nil

local function containsInsensitive(haystack, needle)
    local source = tostring(haystack or "")
    local query = tostring(needle or "")
    if query == "" then
        return true
    end
    return string.find(string.lower(source), string.lower(query), 1, true) ~= nil
end

local function getPickerDisplayName(summary)
    local categoryName = tostring(summary and (summary.categoryDisplayName or summary.categoryName) or "Default")
    local listName = tostring(summary and (summary.displayName or summary.name) or "")
    if listName == "" then
        return categoryName
    end
    return categoryName .. " / " .. listName
end

local function getFilterOwner(self)
    if self and self.applyFilter then
        return self
    end
    if self and self.target and self.target.applyFilter then
        return self.target
    end
    if self and self.parent and self.parent.applyFilter then
        return self.parent
    end
    if self and self.parent and self.parent.target and self.parent.target.applyFilter then
        return self.parent.target
    end
    return self
end

function WL_ItemListPickerDialog:show(target, callback, options)
    if WL_ItemListPickerDialog.instance then
        WL_ItemListPickerDialog.instance:onClose()
    end

    options = options or {}

    local scale = LayoutManager:_getScale()
    local width = math.floor(520 * scale)
    local height = math.floor(420 * scale)
    local o = WL_ItemListPickerDialog:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, target, callback, options)
    o:initialise()
    o:addToUIManager()
    WL_ItemListPickerDialog.instance = o
    return o
end

function WL_ItemListPickerDialog.refreshOpenWindow()
    if WL_ItemListPickerDialog.instance then
        WL_ItemListPickerDialog.instance:refreshData(true)
    end
end

function WL_ItemListPickerDialog:new(x, y, width, height, target, callback, options)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.target = target
    o.callback = callback
    o.options = options or {}
    o.moveWithMouse = true
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.94 }
    o.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }

    o.allCategories = {}
    o.allSummaries = {}
    o.filteredSummaries = {}
    o.filteredRows = {}
    o.selectedListId = nil

    return o
end

function WL_ItemListPickerDialog:initialise()
    ISPanel.initialise(self)
    self:applyLayout()
    self:refreshData(false)
end

function WL_ItemListPickerDialog:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local titleHeight = 24 * scale
    local headerHeight = 20 * scale
    local searchHeight = 22 * scale
    local rowHeight = 24 * scale
    local actionHeight = 26 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2)

    local title = tostring(self.options.title or "Select Item List")

    return {
        type = "rows",
        x = margin,
        y = margin,
        width = tostring(rootWidth) .. "px",
        height = tostring(rootHeight) .. "px",
        pad = pad,
        rows = {
            { type = "label", id = "dialogTitle", width = "inherit", height = titleHeight, text = title, font = UIFont.Medium, center = true },
            { type = "label", id = "infoLabel", width = "inherit", height = headerHeight, text = "Choose an active item list grouped by category.", color = { r = 0.82, g = 0.82, b = 0.82, a = 1 } },
            { type = "textbox", id = "searchInput", width = "inherit", height = searchHeight, text = "", target = self, onTextChange = self.onSearchChanged, clearButton = true, tooltip = "Search lists or categories" },
            { type = "scrollinglistbox", id = "listsList", width = "inherit", height = "*", itemheight = rowHeight, font = UIFont.Small },
            { type = "columns", id = "actionsRow", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "selectButton", width = "*", text = "Select", target = self, onClick = self.onSelect, enabled = false },
                { type = "button", id = "cancelButton", width = "*", text = "Cancel", target = self, onClick = self.onCancel }
            }}
        }
    }
end

function WL_ItemListPickerDialog:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self.searchInput = self.elements.searchInput
    self.listsList = self.elements.listsList
    self.selectButton = self.elements.selectButton

    local owner = self
    self.listsList.doDrawItem = function(list, y, item, alt)
        return owner:drawListRow(list, y, item, alt)
    end
    self.listsList.onMouseDown = function(list, x, y)
        return owner:onListMouseDown(list, x, y)
    end
    self.listsList.onMouseDoubleClick = function(list, x, y)
        return owner:onListDoubleClick(list, x, y)
    end
end

function WL_ItemListPickerDialog:onResize()
    ISUIElement.onResize(self)
    self:applyLayout()
    self:refreshData(true)
end

function WL_ItemListPickerDialog:getSearchText()
    return self.searchInput:getInternalText() or self.searchInput:getText() or ""
end

function WL_ItemListPickerDialog:refreshData(keepSelection)
    local preferredListId = keepSelection and self.selectedListId or nil
    self.allCategories = WL_ItemLists:getCategorySummaries(true)

    if self.options and self.options.parentListId then
        self.allSummaries = WL_ItemLists:getSelectableChildListSummaries(self.options.parentListId)
    else
        self.allSummaries = WL_ItemLists:getListSummaries(false)
        for i = 1, #self.allSummaries do
            local summary = self.allSummaries[i]
            summary.isSelectable = true
            summary.disabledReason = nil
            summary.pickerDisplayName = getPickerDisplayName(summary)
        end
    end

    self:applyFilter(self:getSearchText(), preferredListId)
end

function WL_ItemListPickerDialog:applyFilter(searchText, preferredListId)
    local query = tostring(searchText or "")
    self.filteredSummaries = {}
    self.filteredRows = {}
    self.listsList:clear()

    for i = 1, #self.allSummaries do
        self.filteredSummaries[#self.filteredSummaries + 1] = self.allSummaries[i]
    end

    for categoryIndex = 1, #self.allCategories do
        local category = self.allCategories[categoryIndex]
        local categoryMatches = containsInsensitive(category.name, query)
        local matchingLists = {}

        for i = 1, #self.filteredSummaries do
            local summary = self.filteredSummaries[i]
            if summary.deleted ~= true and summary.categoryId == category.id then
                local listMatches = containsInsensitive(summary.name, query) or containsInsensitive(summary.displayName, query)
                if query == "" or categoryMatches or listMatches then
                    matchingLists[#matchingLists + 1] = {
                        rowType = "list",
                        id = summary.id,
                        categoryId = category.id,
                        summary = summary,
                        displayName = summary.displayName or summary.name,
                        itemCount = summary.itemCount,
                        isSelectable = summary.isSelectable ~= false,
                        disabledReason = summary.disabledReason
                    }
                end
            end
        end

        if query == "" or categoryMatches or #matchingLists > 0 then
            self.filteredRows[#self.filteredRows + 1] = {
                rowType = "category",
                categoryId = category.id,
                category = category,
                displayName = category.displayName or category.name,
                itemCount = category.listCount or 0,
                isSelectable = false
            }
            for i = 1, #matchingLists do
                self.filteredRows[#self.filteredRows + 1] = matchingLists[i]
            end
        end
    end

    local selectedIndex = 0
    self.selectedListId = nil

    for i = 1, #self.filteredRows do
        local row = self.filteredRows[i]
        self.listsList:addItem(tostring(row.displayName or row.id or "Unknown"), row)
        local renderedHeight = self.listsList.itemheight
        if row.rowType == "list" and row.disabledReason then
            renderedHeight = renderedHeight + 12
        end
        self.listsList.items[#self.listsList.items].height = renderedHeight

        if selectedIndex == 0 and row.rowType == "list" and row.id == preferredListId then
            self.selectedListId = preferredListId
            selectedIndex = i
        end
    end

    if not self.selectedListId and #self.filteredRows > 0 and self.options.autoSelectFirst ~= false then
        for i = 1, #self.filteredRows do
            local row = self.filteredRows[i]
            if row.rowType == "list" and row.isSelectable ~= false then
                self.selectedListId = row.id
                selectedIndex = i
                break
            end
        end
    end

    self.listsList.selected = selectedIndex
    self.selectButton:setEnable(self:getSelectedSummary() ~= nil)
end

function WL_ItemListPickerDialog:getSelectedSummary()
    if not self.selectedListId then
        return nil
    end

    for i = 1, #self.filteredRows do
        local row = self.filteredRows[i]
        if row.rowType == "list" and row.id == self.selectedListId and row.isSelectable ~= false then
            return row.summary
        end
    end

    return nil
end

function WL_ItemListPickerDialog:drawListRow(list, y, item, alt)
    if not item then
        return y
    end

    local row = item.item or {}
    local itemHeight = item.height or list.itemheight

    if row.rowType == "category" then
        list:drawRect(0, y, list:getWidth(), itemHeight, list.selected == item.index and 0.2 or 0.12, 0.2, 0.24, 0.3)
        list:drawText(tostring(row.displayName or item.text or "Unnamed Category"), 6, y + 3, 0.82, 0.9, 1, 0.95, list.font)
        list:drawTextRight(tostring(row.itemCount or 0), list:getWidth() - 8, y + 3, 0.78, 0.78, 0.78, 0.9, list.font)
        return y + itemHeight
    end

    if list.selected == item.index then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.22, 0.65, 0.3, 0.2)
    elseif alt then
        list:drawRect(0, y, list:getWidth(), itemHeight, 0.07, 1, 1, 1)
    end

    local summary = row.summary or {}
    local textR, textG, textB = 1, 1, 1
    if summary.isSelectable == false then
        textR, textG, textB = 0.95, 0.72, 0.3
    end

    list:drawText(tostring(summary.displayName or summary.name or item.text or "Unnamed"), 18, y + 3, textR, textG, textB, 0.95, list.font)
    list:drawTextRight(tostring(summary.itemCount or 0), list:getWidth() - 8, y + 3, 0.8, 0.8, 0.8, 0.9, list.font)

    if summary.isSelectable == false and summary.disabledReason then
        list:drawText(tostring(summary.disabledReason), 18, y + 14, 0.85, 0.62, 0.28, 0.9, UIFont.NewSmall)
    end

    return y + itemHeight
end

function WL_ItemListPickerDialog:onSearchChanged()
    local text = self:getInternalText() or self:getText() or ""
    local owner = getFilterOwner(self)
    owner:applyFilter(text, owner.selectedListId)
end

function WL_ItemListPickerDialog:onListMouseDown(list, x, y)
    local rowIndex = list:rowAt(x, y)
    if rowIndex == -1 then
        return false
    end

    list.selected = rowIndex
    local clicked = list.items[rowIndex]
    local selected = clicked and clicked.item or nil
    if selected and selected.rowType == "list" and selected.isSelectable ~= false then
        self.selectedListId = selected.id
    else
        self.selectedListId = nil
    end
    self.selectButton:setEnable(self:getSelectedSummary() ~= nil)
    return true
end

function WL_ItemListPickerDialog:onListDoubleClick(list, x, y)
    local rowIndex = list:rowAt(x, y)
    if rowIndex == -1 then
        return false
    end

    local clicked = list.items[rowIndex]
    local selected = clicked and clicked.item or nil
    if not selected or selected.rowType ~= "list" or selected.isSelectable == false then
        return false
    end

    self.selectedListId = selected.id
    self.listsList.selected = rowIndex
    self:onSelect()
    return true
end

function WL_ItemListPickerDialog:onSelect()
    local selectedSummary = self:getSelectedSummary()
    if not selectedSummary then
        return
    end

    if self.callback then
        self.callback(self.target, selectedSummary.id)
    end
    self:onClose()
end

function WL_ItemListPickerDialog:onCancel()
    self:onClose()
end

function WL_ItemListPickerDialog:onClose()
    WL_ItemListPickerDialog.instance = nil
    self:removeFromUIManager()
end
