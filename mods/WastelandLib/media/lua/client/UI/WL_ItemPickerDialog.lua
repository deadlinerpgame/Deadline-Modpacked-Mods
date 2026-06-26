require "ISUI/ISPanel"
require "UI/LayoutManager/LayoutManager"

WL_ItemPickerDialog = ISPanel:derive("WL_ItemPickerDialog")
WL_ItemPickerDialog.instance = nil

local MAX_VISIBLE_RESULTS = 1000

local function containsInsensitive(haystack, needle)
    local source = tostring(haystack or "")
    local query = tostring(needle or "")
    if query == "" then
        return true
    end
    return string.find(string.lower(source), string.lower(query), 1, true) ~= nil
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function parseSearchTerms(value)
    local terms = {}
    for part in string.gmatch(tostring(value or ""), "([^,]+)") do
        local term = trim(part)
        if term ~= "" then
            terms[#terms + 1] = string.lower(term)
        end
    end
    return terms
end

local function matchesAllTerms(itemData, terms)
    if #terms == 0 then
        return true
    end

    for i = 1, #terms do
        local term = terms[i]
        if not containsInsensitive(itemData.displayNameKey, term) and not containsInsensitive(itemData.fullTypeKey, term) then
            return false
        end
    end

    return true
end

local function setLabelText(label, text)
    if not label then
        return
    end
    if label.setName then
        label:setName(text)
    end
end

local function compareItems(a, b)
    if a.displayNameKey == b.displayNameKey then
        return a.fullTypeKey < b.fullTypeKey
    end
    return a.displayNameKey < b.displayNameKey
end

function WL_ItemPickerDialog:show(callbackOrPreselectedItem, callback, options)
    if WL_ItemPickerDialog.instance then
        WL_ItemPickerDialog.instance:onClose()
    end

    local preselectedItem = nil
    local resolvedCallback = callback
    local resolvedOptions = options or {}
    if type(callbackOrPreselectedItem) == "function" then
        resolvedCallback = callbackOrPreselectedItem
    else
        preselectedItem = callbackOrPreselectedItem
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(620 * scale)
    local height = math.floor(480 * scale)
    local o = WL_ItemPickerDialog:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, preselectedItem, resolvedCallback, resolvedOptions)
    o:initialise()
    o:addToUIManager()
    WL_ItemPickerDialog.instance = o
    return o
end

function WL_ItemPickerDialog:new(x, y, width, height, preselectedItem, callback, options)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.preselectedItem = trim(preselectedItem)
    if o.preselectedItem == "" then
        o.preselectedItem = nil
    end
    o.callback = callback
    o.options = options or {}
    o.closeOnConfirm = o.options.closeOnConfirm ~= false
    o.cancelReturnsNil = o.options.cancelReturnsNil ~= false
    o.moveWithMouse = true
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.94 }
    o.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }

    o.allItems = {}
    o.filteredItems = {}
    o.selectedFullType = nil

    return o
end

function WL_ItemPickerDialog:initialise()
    ISPanel.initialise(self)
    self:loadItems()
    self:applyLayout()
    self:applyFilter("", self.preselectedItem)
end

function WL_ItemPickerDialog:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local titleHeight = 24 * scale
    local infoHeight = 36 * scale
    local searchHeight = 22 * scale
    local rowHeight = 34 * scale
    local actionHeight = 26 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2)

    return {
        type = "rows",
        x = margin,
        y = margin,
        width = tostring(rootWidth) .. "px",
        height = tostring(rootHeight) .. "px",
        pad = pad,
        rows = {
            { type = "label", id = "dialogTitle", width = "inherit", height = titleHeight, text = "Select Item", font = UIFont.Medium, center = true },
            { type = "label", id = "infoLabel", width = "inherit", height = infoHeight, text = "Search by display name or full item id, then select an item.", font = UIFont.NewSmall, color = { r = 0.82, g = 0.82, b = 0.82, a = 1 } },
            { type = "textbox", id = "searchInput", width = "inherit", height = searchHeight, text = "", target = self, onTextChange = self.onSearchChanged, clearButton = true, tooltip = "Search items by display name or full item id" },
            { type = "scrollinglistbox", id = "itemsList", width = "inherit", height = "*", itemheight = rowHeight, font = UIFont.Small, target = self, onMouseDown = self.onListMouseDown, onMouseDoubleClick = self.onListDoubleClick },
            { type = "columns", id = "actionsRow", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "confirmButton", width = "*", text = "Confirm", target = self, onClick = self.onConfirm, enabled = false },
                { type = "button", id = "cancelButton", width = "*", text = "Cancel", target = self, onClick = self.onCancel }
            }}
        }
    }
end

function WL_ItemPickerDialog:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self.infoLabel = self.elements.infoLabel
    self.searchInput = self.elements.searchInput
    self.itemsList = self.elements.itemsList
    self.confirmButton = self.elements.confirmButton
    self.itemsList.doDrawItem = self.drawListRow
end

function WL_ItemPickerDialog:onResize()
    local searchText = self:getSearchText()
    ISUIElement.onResize(self)
    self:applyLayout()
    if searchText ~= "" then
        self.searchInput:setText(searchText)
    end
    self:applyFilter(searchText, self.selectedFullType)
end

function WL_ItemPickerDialog:getSearchText()
    return self.searchInput:getInternalText() or self.searchInput:getText() or ""
end

function WL_ItemPickerDialog:loadItems()
    self.allItems = {}

    local allItems = getScriptManager():getAllItems()
    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)
        local fullType = trim(scriptItem and scriptItem:getFullName() or nil)
        if fullType ~= "" then
            local displayName = trim(scriptItem:getDisplayName())
            if displayName == "" then
                displayName = fullType
            end

            self.allItems[#self.allItems + 1] = {
                fullType = fullType,
                displayName = displayName,
                displayNameKey = string.lower(displayName),
                fullTypeKey = string.lower(fullType)
            }
        end
    end

    table.sort(self.allItems, compareItems)
end

function WL_ItemPickerDialog:applyFilter(searchText, preferredFullType)
    local query = tostring(searchText or "")
    local retainedSelection = preferredFullType or self.selectedFullType
    local totalMatches = 0
    local searchTerms = parseSearchTerms(query)

    self.filteredItems = {}
    self.itemsList:clear()

    for i = 1, #self.allItems do
        local itemData = self.allItems[i]
        if matchesAllTerms(itemData, searchTerms) then
            totalMatches = totalMatches + 1
            if #self.filteredItems < MAX_VISIBLE_RESULTS then
                self.filteredItems[#self.filteredItems + 1] = itemData
                self.itemsList:addItem(itemData.displayName, itemData)
            end
        end
    end

    local selectedIndex = 0
    self.selectedFullType = nil
    for i = 1, #self.filteredItems do
        if self.filteredItems[i].fullType == retainedSelection then
            self.selectedFullType = retainedSelection
            selectedIndex = i
            break
        end
    end

    self.itemsList.selected = selectedIndex
    self:refreshSelectionState(totalMatches)
end

function WL_ItemPickerDialog:getSelectedItem()
    if not self.selectedFullType then
        return nil
    end

    for i = 1, #self.filteredItems do
        local itemData = self.filteredItems[i]
        if itemData.fullType == self.selectedFullType then
            return itemData
        end
    end

    return nil
end

function WL_ItemPickerDialog:refreshSelectionState(totalMatches)
    local selectedItem = self:getSelectedItem()
    local matchCount = totalMatches or #self.filteredItems
    self.confirmButton:setEnable(selectedItem ~= nil)

    if selectedItem then
        setLabelText(self.infoLabel, "Selected: " .. tostring(selectedItem.displayName) .. " (" .. tostring(selectedItem.fullType) .. ")")
    elseif matchCount == 0 then
        setLabelText(self.infoLabel, "No items match the current search.")
    elseif matchCount > #self.filteredItems then
        setLabelText(self.infoLabel, "Showing first " .. tostring(#self.filteredItems) .. " of " .. tostring(matchCount) .. " matching items. Refine the search to narrow results.")
    else
        setLabelText(self.infoLabel, "Search by display name or full item id, then select an item.")
    end
end

function WL_ItemPickerDialog:drawListRow(y, item, alt)
    local rightPad = 22

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.22, 0.2, 0.55, 0.75)
    elseif alt then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.07, 1, 1, 1)
    end

    local itemData = item.item or {}
    self:drawText(tostring(itemData.displayName or item.text or "Unnamed Item"), 6, y + 3, 1, 1, 1, 0.95, self.font)
    self:drawTextRight(tostring(itemData.fullType or ""), self:getWidth() - rightPad, y + 3, 0.76, 0.76, 0.76, 0.9, UIFont.NewSmall)

    return y + self.itemheight
end

function WL_ItemPickerDialog:onSearchChanged()
    local text = self:getInternalText() or self:getText() or ""
    self.parent:applyFilter(text, self.parent.selectedFullType)
end

function WL_ItemPickerDialog:onListMouseDown(item)
    local selected = item
    if selected and selected.item then
        selected = selected.item
    end

    self.selectedFullType = selected and selected.fullType or nil
    self:refreshSelectionState()
end

function WL_ItemPickerDialog:onListDoubleClick(item)
    local selected = item
    if selected and selected.item then
        selected = selected.item
    end

    self.selectedFullType = selected and selected.fullType or nil
    self:refreshSelectionState()
    self:onConfirm()
end

function WL_ItemPickerDialog:_invokeCallback(selectedFullItemId)
    if self.callback then
        self.callback(selectedFullItemId)
    end
end

function WL_ItemPickerDialog:onConfirm()
    local selectedItem = self:getSelectedItem()
    if not selectedItem then
        return
    end

    self:_invokeCallback(selectedItem.fullType)
    if self.closeOnConfirm then
        self:onClose()
    end
end

function WL_ItemPickerDialog:onCancel()
    if self.cancelReturnsNil then
        self:_invokeCallback(nil)
    end
    self:onClose()
end

function WL_ItemPickerDialog:onClose()
    WL_ItemPickerDialog.instance = nil
    self:removeFromUIManager()
end
