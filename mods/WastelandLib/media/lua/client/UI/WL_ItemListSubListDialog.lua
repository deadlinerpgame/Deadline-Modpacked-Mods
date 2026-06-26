require "ISUI/ISPanel"
require "UI/LayoutManager/LayoutManager"
require "UI/WL_Dialogs"
require "UI/WL_ItemListPickerDialog"

WL_ItemListSubListDialog = ISPanel:derive("WL_ItemListSubListDialog")
WL_ItemListSubListDialog.instance = nil

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function toWholeNumber(value)
    local number = tonumber(value)
    if not number then
        return nil
    end
    return math.floor(number)
end

local function getFieldText(element)
    return element:getInternalText() or element:getText() or ""
end

function WL_ItemListSubListDialog:show(listData, itemEntry, target, callback)
    if WL_ItemListSubListDialog.instance then
        WL_ItemListSubListDialog.instance:onClose()
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(460 * scale)
    local height = math.floor(300 * scale)
    local o = WL_ItemListSubListDialog:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, listData, itemEntry, target, callback)
    o:initialise()
    o:addToUIManager()
    WL_ItemListSubListDialog.instance = o
    return o
end

function WL_ItemListSubListDialog:new(x, y, width, height, listData, itemEntry, target, callback)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.listData = listData
    o.itemEntry = itemEntry
    o.target = target
    o.callback = callback
    o.moveWithMouse = true
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.94 }
    o.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }

    return o
end

function WL_ItemListSubListDialog:initialise()
    ISPanel.initialise(self)
    self:applyLayout()
end

function WL_ItemListSubListDialog:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local titleHeight = 24 * scale
    local rowHeight = 22 * scale
    local actionHeight = 26 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2)

    local itemEntry = self.itemEntry or {}
    local dialogTitle = itemEntry.id and "Edit List Entry" or "Add List Entry"
    local listName = self.listData and self.listData.name or "Unknown List"
    local childListLabel = tostring(itemEntry.resolvedListName or itemEntry.childListId or "No child list selected")

    return {
        type = "rows",
        x = margin,
        y = margin,
        width = tostring(rootWidth) .. "px",
        height = tostring(rootHeight) .. "px",
        pad = pad,
        rows = {
            { type = "label", id = "dialogTitle", width = "inherit", height = titleHeight, text = dialogTitle, font = UIFont.Medium, center = true },
            { type = "label", id = "listLabel", width = "inherit", height = rowHeight, text = "List: " .. tostring(listName), color = { r = 0.8, g = 0.8, b = 0.8, a = 1 } },
            { type = "panel", id = "childListRow", width = "inherit", height = actionHeight, noBackground = true, child = {
                type = "columns",
                width = "inherit",
                height = "inherit",
                pad = 8,
                columns = {
                    { type = "label", id = "childListLabel", width = "28%", text = "Child List" },
                    { type = "label", id = "childListValue", width = "46%", text = childListLabel, font = UIFont.NewSmall, color = { r = 0.82, g = 0.82, b = 0.82, a = 1 } },
                    { type = "button", id = "chooseChildListButton", width = "26%", text = "Choose List", target = self, onClick = self.onChooseChildList }
                }
            }},
            { type = "columns", id = "weightRow", width = "inherit", height = rowHeight, columns = {
                { type = "label", id = "weightLabel", width = "28%", text = "Spawn Weight" },
                { type = "textbox", id = "weightInput", width = "72%", text = tostring(itemEntry.weight or 1), onlyNumbers = true }
            }},
            { type = "columns", id = "qtyMinRow", width = "inherit", height = rowHeight, columns = {
                { type = "label", id = "qtyMinLabel", width = "28%", text = "Qty Min" },
                { type = "textbox", id = "qtyMinInput", width = "72%", text = tostring(itemEntry.qtyMin or 1), onlyNumbers = true }
            }},
            { type = "columns", id = "qtyMaxRow", width = "inherit", height = rowHeight, columns = {
                { type = "label", id = "qtyMaxLabel", width = "28%", text = "Qty Max" },
                { type = "textbox", id = "qtyMaxInput", width = "72%", text = tostring(itemEntry.qtyMax or 1), onlyNumbers = true }
            }},
            { type = "label", id = "entryHelpLabel", width = "inherit", height = rowHeight, text = "Child lists perform nested rolls and flatten descendant items.", font = UIFont.NewSmall, color = { r = 0.78, g = 0.78, b = 0.78, a = 1 } },
            { type = "gap", width = "inherit", height = "*" },
            { type = "columns", id = "actionsRow", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "saveButton", width = "*", text = "Save", target = self, onClick = self.onSave },
                { type = "button", id = "cancelButton", width = "*", text = "Cancel", target = self, onClick = self.onCancel }
            }}
        }
    }
end

function WL_ItemListSubListDialog:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)

    self.childListValue = self.elements.childListValue
    self.weightInput = self.elements.weightInput
    self.qtyMinInput = self.elements.qtyMinInput
    self.qtyMaxInput = self.elements.qtyMaxInput

    self.selectedChildListId = self.itemEntry and self.itemEntry.childListId or nil
    self.selectedChildListName = self.itemEntry and self.itemEntry.resolvedListName or nil
    self:refreshSelectionLabel()
end

function WL_ItemListSubListDialog:onResize()
    ISUIElement.onResize(self)
    self:applyLayout()
end

function WL_ItemListSubListDialog:refreshSelectionLabel()
    local childText = self.selectedChildListName or self.selectedChildListId or "No child list selected"
    self.childListValue:setName(childText)
end

function WL_ItemListSubListDialog:onChooseChildList()
    WL_ItemListPickerDialog:show(self, self.onChildListPicked, {
        title = "Choose Child Item List",
        parentListId = self.listData and self.listData.id or nil,
        autoSelectFirst = true
    })
end

function WL_ItemListSubListDialog:onChildListPicked(childListId)
    self.selectedChildListId = childListId
    self.selectedChildListName = WL_ItemLists:getListPickerDisplayNameById(childListId, true)

    self:refreshSelectionLabel()
end

function WL_ItemListSubListDialog:validatePayload(payload)
    payload.entryType = "list"

    payload.weight = tonumber(payload.weight)
    if not payload.weight or payload.weight <= 0 then
        return nil, "Spawn weight must be numeric and greater than 0."
    end

    payload.qtyMin = toWholeNumber(payload.qtyMin)
    payload.qtyMax = toWholeNumber(payload.qtyMax)
    if not payload.qtyMin or payload.qtyMin < 1 then
        return nil, "Quantity minimum must be a whole number of at least 1."
    end
    if not payload.qtyMax or payload.qtyMax < 1 then
        return nil, "Quantity maximum must be a whole number of at least 1."
    end
    if payload.qtyMax < payload.qtyMin then
        local swap = payload.qtyMin
        payload.qtyMin = payload.qtyMax
        payload.qtyMax = swap
    end

    payload.fullType = nil
    payload.customName = nil
    payload.childListId = trim(self.selectedChildListId)
    if payload.childListId == "" then
        return nil, "Child list is required."
    end

    return payload, nil
end

function WL_ItemListSubListDialog:collectPayload()
    return {
        id = self.itemEntry and self.itemEntry.id or nil,
        entryType = "list",
        fullType = nil,
        customName = nil,
        childListId = self.selectedChildListId,
        weight = getFieldText(self.weightInput),
        qtyMin = getFieldText(self.qtyMinInput),
        qtyMax = getFieldText(self.qtyMaxInput)
    }
end

function WL_ItemListSubListDialog:onSave()
    local payload, errorMessage = self:validatePayload(self:collectPayload())
    if errorMessage then
        WL_Dialogs.showMessageDialog(errorMessage)
        return
    end

    if self.callback then
        self.callback(self.target, payload)
    end
    self:onClose()
end

function WL_ItemListSubListDialog:onCancel()
    self:onClose()
end

function WL_ItemListSubListDialog:onClose()
    WL_ItemListSubListDialog.instance = nil
    self:removeFromUIManager()
end
