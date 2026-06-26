require "WL_Utils"

WAT_ItemRefunder = WAT_ItemRefunder or {}

function WAT_ItemRefunder.OnRefundItem()
    local playerObj = getPlayer()
    local function onConfirmCallback(_, button)
        WAT_ItemRefunder.OnRefundItemConfirm(button, playerObj)
    end

    local modal = ISTextBox:new(0, 0, 230, 130, "Paste Inventory Log Below:", "", nil, onConfirmCallback, nil)
    modal:initialise()
    modal.entry:setOnlyNumbers(false)
    modal:setX((getCore():getScreenWidth() - modal.width) / 2)
    modal:setY((getCore():getScreenHeight() - modal.height) / 2)
    modal:addToUIManager()

    local originalDestroy = modal.destroy
    modal.destroy = function(self)
        originalDestroy(self)
        self:removeFromUIManager()
    end
end

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
local function parseItems(itemString)
    local items = {}

    for item in string.gmatch(itemString, "([^,]+)") do
        local trimmed = trim(item)
        if trimmed ~= "" then
            local base, count = trimmed:match("^(.-)%s*[xX]%s*(%d+)$")
            local fullType = base and trim(base) or trimmed
            local amount = tonumber(count) or 1

            local found = false
            for _, existing in ipairs(items) do
                if existing.fullType == fullType then
                    existing.amount = existing.amount + amount
                    found = true
                    break
                end
            end
            if not found then
                table.insert(items, {
                    fullType = fullType,
                    amount = amount,
                    checked = true,
                })
            end
        end
    end

    return items
end


function WAT_ItemRefunder.InventoryParser(log)
    local inventories = {}

    local username = log:match("Username:%s*(.-)%s*|")
    if not username then
        return inventories, nil
    end

    local inventoryData = log:match("Inventory: (.+)")
    if not inventoryData then 
        return inventories, username 
    end

    local sections = {}
    for part in string.gmatch(inventoryData, "([^|]+)") do
        table.insert(sections, trim(part))
    end

    for i, section in ipairs(sections) do
        if i == 1 then
            local mainInventory = section:match("Main Inventory:%s*(.+)")
            if mainInventory then
                inventories["Everything"] = parseItems(mainInventory)
            end
        else
            local containerName, items = section:match("^([^:]+):%s*(.+)")
            if containerName and items then
                inventories[trim(containerName)] = parseItems(items)
            end
        end
    end

    return inventories, username
end

function WAT_ItemRefunder.OnRefundItemConfirm(button, playerObj)
    if button.internal == "OK" then
        local log = button.parent.entry:getText()
        log = log:gsub("%.$", "") 
        local inventories, username = WAT_ItemRefunder.InventoryParser(log)

        if not inventories["Everything"] then
            playerObj:Say("Invalid inventory log. Please make sure the log is correct.")
            return
        end

        WAT_ItemRefunder.ShowInventorySelection(playerObj, inventories, username)
    end
end

local function getItemIcon(fullType)
    local item = InventoryItemFactory.CreateItem(fullType)
    return item and item:getTex() or nil
end

function WAT_ItemRefunder.ShowInventorySelection(playerObj, inventories, username)
    local width, height = 600, 600
    local modal = ISPanel:new((getCore():getScreenWidth() - width) / 2, (getCore():getScreenHeight() - height) / 2, width, height)
    modal:initialise()
    modal:addToUIManager()
    modal:setVisible(true)

    local label = ISLabel:new(0, 10, 30, "Player Refund", 1, 1, 1, 1, UIFont.Large)
    label:setX((modal.width - label:getWidth()) / 2)
    modal:addChild(label)

    local dropdownLabelText = "Inventory Selection:"
    local labelWidth = getTextManager():MeasureStringX(UIFont.Small, dropdownLabelText)
    local labelY = 35

    local dropdownLabel = ISLabel:new(20, labelY, 30, dropdownLabelText, 1, 1, 1, 1, UIFont.Small, true)
    modal:addChild(dropdownLabel)

    local dropdown = ISComboBox:new(25 + labelWidth, 40, width - 40 - labelWidth, 22, modal)
    for name, _ in pairs(inventories) do
        dropdown:addOption(name)
    end
    dropdown:select(0)
    modal:addChild(dropdown)

    local headerY = 70
    local headerHeight = 20
    modal:addChild(ISPanel:new(10, headerY, width - 20, headerHeight))

    function modal:prerender()
        ISPanel.prerender(self)

        local y = headerY + 4
        local font = UIFont.Small

        self:drawText("Include", 15, y, 1, 1, 1, 1, font)
        self:drawText("Item", 70, y, 1, 1, 1, 1, font)
        self:drawTextRight("Amount", width - 100, y, 1, 1, 1, 1, font)
    end

    local listBox = ISScrollingListBox:new(10, 90, width - 20, 467)
    listBox:initialise()
    listBox:instantiate()
    listBox.itemheight = 40
    listBox.font = UIFont.Small
    listBox.drawBorder = true
    modal:addChild(listBox)

    function modal:updateItemList(selectedInventory)
        listBox:clear()
        local items = inventories[selectedInventory]
        if items then
            for _, entry in ipairs(items) do
                local itemObj = InventoryItemFactory.CreateItem(entry.fullType)
                if itemObj then
                    local displayName = itemObj and itemObj:getDisplayName() or entry.fullType or "Unknown"
                    listBox:addItem(displayName, {
                        fullType = entry.fullType,
                        displayName = displayName,
                        amount = entry.amount,
                        checked = entry.checked,
                        tex = itemObj and itemObj:getTex() or nil,
                        entryRef = entry
                    })
                end
            end
        end
    end

    function listBox:doDrawItem(y, item, alt)
        local r, g, b, a = 1, 1, 1, 1
        self:drawRectBorder(0, y, self:getWidth(), self.itemheight, 0.3, r, g, b)

        local x = 15

        local boxSize = 14
        self:drawRectBorder(x, y + 7, boxSize, boxSize, 1, 1, 1, 1)
        if item.item.checked then
            self:drawRect(x + 2, y + 9, boxSize - 4, boxSize - 4, 1, 1, 1, 1)
        end
        x = x + boxSize + 30

        if item.item.tex then
            self:drawTexture(item.item.tex, x, y + 4, 1)
        end
        x = x + 50

        self:drawText(item.item.displayName or "Unknown", x, y + 10, r, g, b, a, self.font)

        self:drawTextRight("x " .. tostring(item.item.amount), self.width - 100, y + 6, r, g, b, a, self.font)

        return y + self.itemheight
    end

    function listBox:onMouseDown(x, y)
        local row = self:rowAt(x, y)
        if row then
            local item = self.items[row]
            if x >= 15 and x <= 15 + 14 then
                item.item.entryRef.checked = not item.item.entryRef.checked
                self:clear()
                modal:updateItemList(dropdown:getSelectedText())
            end
        end
    end
    

    dropdown.onChange = function()
        modal:updateItemList(dropdown:getSelectedText())
    end

    modal:updateItemList(dropdown:getSelectedText())

    local okButton = ISButton:new(width / 2 - 90, height - 35, 80, 25, "Refund", modal, function()
        local selected = dropdown:getSelectedText()
        local allItems = inventories[selected]

        if not allItems then
            playerObj:Say("No items found.")
            return
        end

        local selectedItems = {}
        for _, entry in ipairs(allItems) do
            if entry.checked then
                for i = 1, entry.amount do
                    table.insert(selectedItems, entry.fullType)
                end
            end
        end

        if #selectedItems == 0 then
            playerObj:Say("No items selected to refund.")
            return
        end

        WAT_ItemRefunder.RefundSelectedInventory(playerObj, selected, selectedItems, username)
        modal:removeFromUIManager()
    end)
    modal:addChild(okButton)

    okButton.backgroundColorMouseOver = {r=0.1, g=0.4, b=0.1, a=1}

    local cancelButton = ISButton:new(width / 2 + 10, height - 35, 80, 25, "Cancel", modal, function()
        modal:removeFromUIManager()
    end)
    modal:addChild(cancelButton)

    cancelButton.backgroundColorMouseOver = {r=0.6, g=0.1, b=0.1, a=1}

    return modal
end

function WAT_ItemRefunder.RefundSelectedInventory(playerObj, containerName, items, username)
    local refundBag

    if containerName ~= "Everything" then
        local containerItem = InventoryItemFactory.CreateItem(containerName)
        if containerItem then
            refundBag = playerObj:getInventory():AddItem(containerItem)
        else
            playerObj:Say("Could not refund container: " .. containerName)
        end
    else
        refundBag = playerObj:getInventory():AddItem("Base.Bag_Schoolbag")
        refundBag:setName("Refunded Items (" .. username .. ")")
    end

    for _, item in ipairs(items) do
        local newItem = InventoryItemFactory.CreateItem(item)
        if newItem then
            refundBag:getInventory():AddItem(newItem)
        else
            playerObj:Say("Could not refund: " .. item)
        end
    end
end

