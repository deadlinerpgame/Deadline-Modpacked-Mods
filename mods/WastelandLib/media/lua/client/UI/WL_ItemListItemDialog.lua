require "ISUI/ISPanel"
require "UI/LayoutManager/LayoutManager"
require "UI/WL_Dialogs"

WL_ItemListItemDialog = ISPanel:derive("WL_ItemListItemDialog")
WL_ItemListItemDialog.instance = nil

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

function WL_ItemListItemDialog:show(listData, itemEntry, target, callback)
    if WL_ItemListItemDialog.instance then
        WL_ItemListItemDialog.instance:onClose()
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(460 * scale)
    local height = math.floor(380 * scale)
    local o = WL_ItemListItemDialog:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, listData, itemEntry, target, callback)
    o:initialise()
    o:addToUIManager()
    WL_ItemListItemDialog.instance = o
    return o
end

function WL_ItemListItemDialog:new(x, y, width, height, listData, itemEntry, target, callback)
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

function WL_ItemListItemDialog:initialise()
    ISPanel.initialise(self)
    self:applyLayout()
end

function WL_ItemListItemDialog:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local titleHeight = 24 * scale
    local rowHeight = 22 * scale
    local actionHeight = 26 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2)

    local itemEntry = self.itemEntry or {}
    local dialogTitle = itemEntry.id and "Edit Item Entry" or "Add Item Entry"
    local listName = self.listData and self.listData.name or "Unknown List"

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
            { type = "panel", id = "fullTypeRow", width = "inherit", height = rowHeight, noBackground = true, child = {
                type = "columns",
                width = "inherit",
                height = "inherit",
                pad = 8,
                columns = {
                    { type = "label", id = "fullTypeLabel", width = "28%", text = "Full Type" },
                    { type = "textbox", id = "fullTypeInput", width = "46%", text = tostring(itemEntry.fullType or "") },
                    { type = "button", id = "chooseItemButton", width = "26%", text = "Choose Item", target = self, onClick = self.onChooseItem }
                }
            }},
            { type = "panel", id = "customNameRow", width = "inherit", height = rowHeight, noBackground = true, child = {
                type = "columns",
                width = "inherit",
                height = "inherit",
                columns = {
                    { type = "label", id = "customNameLabel", width = "28%", text = "Custom Name" },
                    { type = "textbox", id = "customNameInput", width = "72%", text = tostring(itemEntry.customName or "") }
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
            { type = "label", id = "entryHelpLabel", width = "inherit", height = rowHeight, text = "Direct items create concrete inventory items.", font = UIFont.NewSmall, color = { r = 0.78, g = 0.78, b = 0.78, a = 1 } },
            { type = "gap", width = "inherit", height = "*" },
            { type = "columns", id = "actionsRow", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "saveButton", width = "*", text = "Save", target = self, onClick = self.onSave },
                { type = "button", id = "cancelButton", width = "*", text = "Cancel", target = self, onClick = self.onCancel }
            }}
        }
    }
end

function WL_ItemListItemDialog:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)

    self.fullTypeInput = self.elements.fullTypeInput
    self.chooseItemButton = self.elements.chooseItemButton
    self.customNameInput = self.elements.customNameInput
    self.weightInput = self.elements.weightInput
    self.qtyMinInput = self.elements.qtyMinInput
    self.qtyMaxInput = self.elements.qtyMaxInput
    self.entryHelpLabel = self.elements.entryHelpLabel
end

function WL_ItemListItemDialog:onResize()
    ISUIElement.onResize(self)
    self:applyLayout()
end

function WL_ItemListItemDialog:onChooseItem()
    WL_Dialogs:promptItem(getFieldText(self.fullTypeInput), function(selectedFullType)
        self:onItemPicked(selectedFullType)
    end)
end

function WL_ItemListItemDialog:onItemPicked(selectedFullType)
    if not selectedFullType then
        return
    end

    self.fullTypeInput:setText(tostring(selectedFullType))
end

function WL_ItemListItemDialog:validatePayload(payload)
    payload.entryType = "item"

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

    payload.fullType = trim(payload.fullType)
    if payload.fullType == "" then
        return nil, "Full item type is required."
    end

    if not ScriptManager.instance:getItem(payload.fullType) then
        return nil, "Item type does not exist: " .. payload.fullType
    end

    payload.customName = trim(payload.customName)
    if payload.customName == "" then
        payload.customName = nil
    end
    payload.childListId = nil

    return payload, nil
end

function WL_ItemListItemDialog:collectPayload()
    return {
        id = self.itemEntry and self.itemEntry.id or nil,
        entryType = "item",
        fullType = getFieldText(self.fullTypeInput),
        customName = getFieldText(self.customNameInput),
        childListId = nil,
        weight = getFieldText(self.weightInput),
        qtyMin = getFieldText(self.qtyMinInput),
        qtyMax = getFieldText(self.qtyMaxInput)
    }
end

function WL_ItemListItemDialog:onSave()
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

function WL_ItemListItemDialog:onCancel()
    self:onClose()
end

function WL_ItemListItemDialog:onClose()
    WL_ItemListItemDialog.instance = nil
    self:removeFromUIManager()
end
