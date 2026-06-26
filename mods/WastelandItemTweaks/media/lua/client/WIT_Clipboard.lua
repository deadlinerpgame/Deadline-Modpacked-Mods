---
--- WIT_Clipboard
--- 07/11/2024
---

require "GravyUI_WL"
require "WL_Utils"

WIT_Clipboard = ISPanel:derive("WIT_Clipboard")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r = 1, g = 1, b = 1, a = 1}
local COLOR_RED_LOW = {r = 1, g = 0, b = 0, a = 0.5}
local BACKGROUND_COLOR = {r = 0, g = 0, b = 0, a = 0.8}
local BORDER_COLOR = {r = 0.4, g = 0.4, b = 0.4, a = 1}

function WIT_Clipboard:display(player, clipboard, readOnly)
    if WIT_Clipboard.instance then
        WIT_Clipboard.instance:removeFromUIManager()
    end
    WIT_Clipboard.instance = WIT_Clipboard:new(player, clipboard, readOnly)
    WIT_Clipboard.instance:addToUIManager()

    local clipboardAction = WIT_ClipboardAction:new(player, clipboard, readOnly)
    ISTimedActionQueue.add(clipboardAction)
    player:playSound("MapOpen")
end

function WIT_Clipboard:findClipboard(player)
    local clipboard = nil
    local square = player:getCurrentSquare()
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        if object:getContainer() and object:getContainer():getItems() then
            for j = 0, object:getContainer():getItems():size() - 1 do
                local item = object:getContainer():getItems():get(j)
                if item:getFullType() == "Base.ClipboardEmpty" or item:getFullType() == "Base.ClipboardPaper" then
                    clipboard = item
                    break
                end
            end
        end
    end
    return clipboard
end

function WIT_Clipboard:new(player, clipboard, readOnly)
    local scale = FONT_HGT_SMALL / 12
    local w = 400 * scale
    local h = 400 * scale
    local o = ISPanel:new(getCore():getScreenWidth() / 2 - w / 2, getCore():getScreenHeight() / 2 - h / 2, w, h)
    setmetatable(o, self)
    self.__index = self
    o.panel = o
    o.clipboard = clipboard
    o.character = player
    if readOnly and readOnly == true then
        o.readOnly = true
    else
        o.readOnly = false
    end
    o.backgroundColor = BACKGROUND_COLOR
    o.borderColor = BORDER_COLOR
    o.modDataKey = "WIT_ClipboardData"
    o.titleText = clipboard:getModData()[o.modDataKey].titleText
    o.totalPages = clipboard:getModData()[o.modDataKey].paperAmount or 0
    o.clipboard:getModData()[o.modDataKey] = o.clipboard:getModData()[o.modDataKey] or {}
    o:initialise()
    return o
end

function WIT_Clipboard:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(20, 20, 20, 20)

    local titleNode, subtitleNode, mainContentNode = win:rows({0.05, 0.03, 0.92}, 10)
    local titleDivider, closeButtonNode = titleNode:cols({0.95, 0.05}, 5)
    local titleText = self.titleText
    self.titleLabel = titleDivider:makeLabel(titleText, UIFont.Large, COLOR_WHITE, "center")
    self.titleLabel:setX(self.titleLabel:getX() + closeButtonNode.width / 2)
    closeButtonNode:makeButton("X", self, self.onClose)

    local contentNode, buttonNode = mainContentNode:rows({0.95, 0.05}, 5)

    self.listItems = {}
    self.currentPage = 1
    self.itemsPerPage = 15
    self.totalPages = self.totalPages
    local readOnlyWarning = "[Read Only Mode]"
    
    local subtitleText = "Page " .. self.currentPage .. " of " .. self.totalPages
    if self.readOnly then
        subtitleText = readOnlyWarning .. " " .. subtitleText
    end
    self.subtitleLabel = subtitleNode:makeLabel(subtitleText, UIFont.Small, COLOR_WHITE, "center")

    self:createListItems(contentNode)
    self:createPaginationButtons(buttonNode)

    self:updateState()
end

function WIT_Clipboard:createListItems(parentNode)
    local modData = self.clipboard:getModData()[self.modDataKey]
    modData.listItems = modData.listItems or {}

    local listRows = {parentNode:rows(self.itemsPerPage, 5)}
    for i = 1, self.itemsPerPage do
        local rowNode = listRows[i]
        if rowNode then
            local checkBoxNode, textBoxNode = rowNode:cols({0.05, 0.95}, 5)
            local checkBox = checkBoxNode:makeButton("", self, function()
                if self.readOnly then
                    self.character:Say("I can't check items off unless I pick up the clipboard.")
                    return
                else
                    self:toggleCheckBoxState(i)
                end
            end)

            local textBox = textBoxNode:makeTextBox("")
            textBox:setEditable(true)
            textBox:setSelectable(true)
            textBox.javaObject:setMaxTextLength(75)

            self.listItems[i] = {checkBox = checkBox, textBox = textBox}

            local itemIndex = (self.currentPage - 1) * self.itemsPerPage + i
            local data = modData.listItems[itemIndex] or {text = "", checked = false, drawLine = false}
            textBox:setText(data.text)
            checkBox:setTitle(data.checked and "X" or "")
        end
    end
end


function WIT_Clipboard:createPaginationButtons(parentNode)
    local prevButtonNode, paperButtonNode, nextButtonNode = parentNode:cols({0.3333, 0.3333, 0.3333}, 10)

    self.prevButton = prevButtonNode:makeButton("Previous Page", self, function()
        self:onPreviousPage()
    end)
    self.paperButton = paperButtonNode:makeButton("Add Paper: " .. self.totalPages .. " / 5", self, function()
        if self.readOnly then
            self.character:Say("I can't add paper to the clipboard unless I pick it up.")
            return
        else
            WIT_Clipboard.addPaper(self.character, self.clipboard)
            self.totalPages = self.clipboard:getModData()[self.modDataKey].paperAmount or 0
            self.paperButton:setTitle("Add Paper: " .. self.totalPages .. " / 5")
            if self.readOnly then
                self.subtitleLabel:setText("[Read Only Mode] Page " .. self.currentPage .. " of " .. self.totalPages)
            else
                self.subtitleLabel:setText("Page " .. self.currentPage .. " of " .. self.totalPages)
            end
            self.character:playSound("PageFlipMagazine")
            self:saveCurrentState()
            self:updateState()
        end
    end)
    
    self.prevButton:setVisible(false)
    self.nextButton = nextButtonNode:makeButton("Next Page", self, function()
        self:onNextPage()
    end)
end

function WIT_Clipboard:toggleCheckBoxState(index)
    local text = self.listItems[index].textBox:getText()
    if text ~= "" then
        local itemIndex = (self.currentPage - 1) * self.itemsPerPage + index
        local modData = self.clipboard:getModData()[self.modDataKey]
        modData.listItems[itemIndex] = modData.listItems[itemIndex] or {text = "", checked = false}
        modData.listItems[itemIndex].checked = not modData.listItems[itemIndex].checked
        self.listItems[index].checkBox:setTitle(modData.listItems[itemIndex].checked and "X" or "")
        self.listItems[index].textBox:setEditable(not modData.listItems[itemIndex].checked)
        self.listItems[index].textBox:setSelectable(not modData.listItems[itemIndex].checked)
        self.listItems[index].drawLine = modData.listItems[itemIndex].checked
        if modData.listItems[itemIndex].checked then
            self.character:playSound("MapAddSymbol")
        else
            self.character:playSound("MapRemoveMarking")
        end
    end
end

function WIT_Clipboard:onPreviousPage()
    self:saveCurrentState()
    if self.currentPage > 1 then
        self.currentPage = self.currentPage - 1
        if self.readOnly then
            self.subtitleLabel:setText("[Read Only Mode] Page " .. self.currentPage .. " of " .. self.totalPages)
        else
            self.subtitleLabel:setText("Page " .. self.currentPage .. " of " .. self.totalPages)
        end
        self.character:playSound("PageFlipBook")
        self:updateState()
    end
end

function WIT_Clipboard:onNextPage()
    self:saveCurrentState()
    if self.currentPage == self.totalPages then
        return
    else
        self.currentPage = self.currentPage + 1
        if self.readOnly then
            self.subtitleLabel:setText("[Read Only Mode] Page " .. self.currentPage .. " of " .. self.totalPages)
        else
            self.subtitleLabel:setText("Page " .. self.currentPage .. " of " .. self.totalPages)
        end
        self.character:playSound("PageFlipBook")
    end
    self:updateState()
end

function WIT_Clipboard:saveCurrentState()
    local modData = self.clipboard:getModData()[self.modDataKey]
    modData.listItems = modData.listItems or {}

    for i, item in ipairs(self.listItems) do
        local itemIndex = (self.currentPage - 1) * self.itemsPerPage + i
        local data = modData.listItems[itemIndex] or {text = "", checked = false, drawLine = false}
        data.text = item.textBox:getText()
        data.checked = (item.checkBox:getTitle() == "X")
        data.drawLine = item.drawLine
        modData.listItems[itemIndex] = data
    end
end


function WIT_Clipboard:updateState()
    local modData = self.clipboard:getModData()[self.modDataKey]
    local totalItems = #modData.listItems

    for i, item in ipairs(self.listItems) do
        local itemIndex = (self.currentPage - 1) * self.itemsPerPage + i
        local data = modData.listItems[itemIndex] or {text = "", checked = false, drawLine = false}
        item.textBox:setText(data.text)
        item.textBox:setEditable(not data.checked)
        item.textBox:setSelectable(not data.checked)
        item.checkBox:setTitle(data.checked and "X" or "")
        item.drawLine = data.drawLine
    end

    self.prevButton:setVisible(self.currentPage > 1)
    if self.currentPage < self.totalPages then
        self.nextButton.backgroundColor = {r=0,g=0,b=0,a=1}
        if self.nextButton.backgroundColorMouseOver then
            self.nextButton.backgroundColorMouseOver = {r=0.5,g=0.5,b=0.5,a=1}
        end
        local originalRender = self.nextButton.render
        self.nextButton.render = function(button)
            originalRender(button)
            button:drawRectBorder(0, 0, button.width, button.height, 1, 0.7, 0.7, 0.7)
        end
    elseif self.currentPage == self.totalPages then
        self.nextButton.backgroundColor = {r=0.5,g=0.5,b=0.5,a=0.5}
        if self.nextButton.backgroundColorMouseOver then
            self.nextButton.backgroundColorMouseOver = {r=0.5,g=0.5,b=0.5,a=0.7}
        end
        self.nextButton.onClickArgs = {}
        self.nextButton:initialise()
        local originalRender = self.nextButton.render
        self.nextButton.render = function(button)
            originalRender(button)
            button:drawRectBorder(0, 0, button.width, button.height, 1, 0.7, 0.7, 0.7)
        end
    end

    if self.readOnly then
        for i, item in ipairs(self.listItems) do
            item.textBox:setEditable(false)
            item.textBox:setSelectable(false)
        end
    end
end

function WIT_Clipboard:prerender()
    ISPanel.prerender(self)
    if self.readOnly then
        local px = self.character:getX()
        local py = self.character:getY()
        local cx = self.clipboard:getWorldItem():getX()
        local cy = self.clipboard:getWorldItem():getY()
        local dx = px - cx
        local dy = py - cy
        if dx * dx + dy * dy > 4 then
            self:onClose()
        end
    end
end

function WIT_Clipboard:render()
    ISPanel.render(self)

    for i, item in ipairs(self.listItems) do
        if item.drawLine then
            local lineThickness = 2
            local lineColor = COLOR_RED_LOW
            local textBox = item.textBox

            self:drawRect(
                textBox:getX(),
                textBox:getY(),
                textBox:getWidth(),
                textBox:getHeight(),
                0.5, 0, 0, 0
            )

            self:drawRect(
                textBox:getX()+2,
                textBox:getY() + textBox:getHeight() / 2,
                getTextManager():MeasureStringX(UIFont.Small, item.textBox:getText())+5,
                lineThickness,
                lineColor.a, lineColor.r, lineColor.g, lineColor.b
            )
        end
    end
end


function WIT_Clipboard:onClose()
    ISTimedActionQueue.clear(self.character)
    self.character:playSound("MapClose")

    self:saveCurrentState()
    self:removeFromUIManager()
end

function WIT_Clipboard:removeFromUIManager()
    self:setVisible(false)
    WIT_Clipboard.instance = nil
end

function WIT_Clipboard.addPaper(player, clipboard)
    local paper = player:getInventory():getAllTypeRecurse("Base.SheetPaper2")
    if paper:size() > 0 then
        local paperAmount = clipboard:getModData()["WIT_ClipboardData"].paperAmount or 0
        if paperAmount < 5 then
            clipboard:getModData()["WIT_ClipboardData"].paperAmount = paperAmount + 1
            player:getInventory():RemoveOneOf("Base.SheetPaper2")
            WIT_Clipboard.changeModel(player, clipboard, "paper")
        end
    end
end

function WIT_Clipboard.removePaper(player, clipboard)
    local modData = clipboard:getModData()["WIT_ClipboardData"]
    local paperAmount = modData.paperAmount or 0

    if paperAmount > 0 then
        modData.paperAmount = paperAmount - 1
        player:getInventory():AddItem("Base.SheetPaper2")
        WIT_Clipboard.changeModel(player, clipboard, "empty")
    end

    if modData.paperAmount == 0 then
        modData.listItems = {}
    end
end

function WIT_Clipboard.changeName(player, clipboard)
    local scale = getTextManager():getFontHeight(UIFont.Small) / 14
    local width = 250 * scale
    local height = 150 * scale
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)
    local titleText = clipboard:getModData()["WIT_ClipboardData"].titleText

    local maxTitleWidth = 300

    local inputModal = ISTextBox:new(x, y, width, height, "Change Clipboard Name", titleText, nil, function(_, button)
        if button.internal == "OK" then
            local newName = button.target.entry:getText()
            local nameWidth = getTextManager():MeasureStringX(UIFont.Large, newName)
            if newName and nameWidth > maxTitleWidth then
                player:Say("Name is too long, please reduce it.")
            elseif newName and newName ~= "" then
                clipboard:getModData()["WIT_ClipboardData"].titleText = newName
                local name = "CB: " .. newName
                clipboard:setName(name)
            end
        end
    end, nil)

    inputModal:initialise()
    inputModal:addToUIManager()
end

function WIT_Clipboard.changeModel(player, clipboard, switch)
    local inventory = player:getInventory()
    local modData = clipboard:getModData()
    local modDataKey = "WIT_ClipboardData"
    local paperAmount = modData[modDataKey] and modData[modDataKey].paperAmount

    if clipboard:getFullType() == "Base.ClipboardPaper" and paperAmount <= 0 and switch == "empty" then
        local newClipboard = inventory:AddItem("Base.ClipboardEmpty")

        if newClipboard then
            for key, value in pairs(modData) do
                newClipboard:getModData()[key] = value
            end
            newClipboard:setName(clipboard:getName())
            inventory:Remove(clipboard)
        else
            print("Error: Could not create new ClipboardEmpty item.")
        end

    elseif clipboard:getFullType() == "Base.ClipboardEmpty" and paperAmount > 0 and switch == "paper" then
        local newClipboard = inventory:AddItem("Base.ClipboardPaper")

        if newClipboard then
            for key, value in pairs(modData) do
                newClipboard:getModData()[key] = value
            end
            newClipboard:setName(clipboard:getName())
            inventory:Remove(clipboard)
        else
            print("Error: Could not create new ClipboardPaper item.")
        end
    elseif clipboard:getFullType() == "Base.ClipboardPaper" and paperAmount > 0 and switch == "wall" then
        local newClipboard = inventory:AddItem("Base.ClipboardWall")

        if newClipboard then
            for key, value in pairs(modData) do
                newClipboard:getModData()[key] = value
            end
            newClipboard:setName(clipboard:getName())
            inventory:Remove(clipboard)
            player:Say("Clipboard is now able to be placed on the wall.")
        else
            print("Error: Could not create new ClipboardWall item.")
        end
    elseif clipboard:getFullType() == "Base.ClipboardWall" and switch == "paper" then
        local newClipboard = inventory:AddItem("Base.ClipboardPaper")

        if newClipboard then
            for key, value in pairs(modData) do
                newClipboard:getModData()[key] = value
            end
            newClipboard:setName(clipboard:getName())
            inventory:Remove(clipboard)
            player:Say("Clipboard has been removed from the wall.")
        else
            print("Error: Could not create new ClipboardPaper item.")
        end
    end
end

function WIT_Clipboard.InventoryContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)
    
    items = ISInventoryPane.getActualItems(items)
    for _, item in ipairs(items) do
        if item:getFullType() == "Base.ClipboardEmpty" or item:getFullType() == "Base.ClipboardPaper" or item:getFullType() == "Base.ClipboardWall" then
            context:removeOptionByName(getText("ContextMenu_Read"))
            if not item:getModData()["WIT_ClipboardData"] then
                WIT_CreateClipboard(item)
            end
            if item:getContainer() == playerObj:getInventory() then
                if #items == 1 then
                    local clipboardMenu = WL_ContextMenuUtils.getOrCreateSubMenuOnTop(context, "Clipboard")
                    local paperAmount = item:getModData()["WIT_ClipboardData"].paperAmount or 0
                    if paperAmount >= 0 and paperAmount <= 5 then
                        local paper = playerObj:getInventory():getAllTypeRecurse("Base.SheetPaper2")
                        if paper and not paper:isEmpty() then
                            if paper:size() > 0 and paperAmount < 5 then
                                local addPaper = clipboardMenu:addOption("Add Paper", playerObj, function() WIT_Clipboard.addPaper(playerObj, item) end, item)
                                WL_ContextMenuUtils.addToolTip(addPaper, "Add Paper", "Add a sheet of paper to the clipboard", "Item_Paper")
                            elseif paper:size() > 0 and paperAmount >= 5 then
                                WL_ContextMenuUtils.missingRequirement(clipboardMenu, "Add Paper", "Clipboard is full", nil, "Item_Paper")
                            end
                        else
                            if paperAmount >= 5 then
                                WL_ContextMenuUtils.missingRequirement(clipboardMenu, "Add Paper", "Clipboard is full", nil, "Item_Paper")
                            elseif paper:isEmpty() then
                                WL_ContextMenuUtils.missingRequirement(clipboardMenu, "Add Paper", "No paper in inventory", nil, "Item_Paper")
                            end
                        end
                    end
                    if paperAmount > 0 then
                        local removePaper = clipboardMenu:addOption("Remove Paper", playerObj, function() WIT_Clipboard.removePaper(playerObj, item) end, item)
                        WL_ContextMenuUtils.addToolTip(removePaper, "Remove Paper", "Remove a sheet of paper from the clipboard", "Item_Paper")
                        local openClipboard = clipboardMenu:addOption("Open Clipboard", playerObj, WIT_Clipboard.display, playerObj, item)
                        WL_ContextMenuUtils.addToolTip(openClipboard, "Open Clipboard", "Open the clipboard to view and edit the contents", "Item_Clipboard")
                    else
                        WL_ContextMenuUtils.missingRequirement(clipboardMenu, "Open Clipboard", "No paper in clipboard", nil, "Item_Clipboard")
                    end
                    if item:getFullType() == "Base.ClipboardWall" then
                        local wallClipboard = clipboardMenu:addOption("Take off Wall", playerObj, function() WIT_Clipboard.changeModel(playerObj, item, "paper") end, item)
                        WL_ContextMenuUtils.addToolTip(wallClipboard, "Take off Wall", "Swap the model of the clipboard to lay flat..", "Item_Clipboard")
                    elseif item:getFullType() == "Base.ClipboardPaper" then
                        local wallClipboard = clipboardMenu:addOption("Put on Wall", playerObj, function() WIT_Clipboard.changeModel(playerObj, item, "wall") end, item)
                        WL_ContextMenuUtils.addToolTip(wallClipboard, "Put on Wall", "Swap the model of the clipboard to be placeable on the wall.", "Item_Clipboard")
                    end
                    local changeName = clipboardMenu:addOption("Change Name", playerObj, function() WIT_Clipboard.changeName(playerObj, item) end, item)
                    WL_ContextMenuUtils.addToolTip(changeName, "Change Name", "Change the name of the clipboard", "Item_Clipboard")
                end
            else
                if #items == 1 then
                    local clipboardMenu = WL_ContextMenuUtils.getOrCreateSubMenuOnTop(context, "Clipboard")
                    local readClipboard = clipboardMenu:addOption("Read Clipboard", playerObj, function()
                        WIT_Clipboard:display(playerObj, item, true)
                    end, item)
                    WL_ContextMenuUtils.addToolTip(readClipboard, "Read Clipboard", "Read the clipboard, but you won't be able to make changes unless you pick it up.", "Item_Clipboard")
                    local takeClipboard = clipboardMenu:addOption("Take Clipboard", playerObj, function() 
                        ISTimedActionQueue.add(ISInventoryTransferAction:new(playerObj, item, item:getContainer(), playerObj:getInventory()))
                     end, item)
                    WL_ContextMenuUtils.addToolTip(takeClipboard, "Take Clipboard", "Pick up the clipboard", "Item_Clipboard")
                    WL_ContextMenuUtils.missingRequirement(clipboardMenu, "Take off Wall", "Clipboard must be in inventory to change position.", nil, "Item_Clipboard")
                end
            end
        end
    end
end

function WIT_CreateClipboard(clipboard)
    local modData = clipboard:getModData()
    local modDataKey = "WIT_ClipboardData"

    if not modData[modDataKey] then
        modData[modDataKey] = {}
    end

    modData[modDataKey].titleText = "Clipboard"
    modData[modDataKey].listItems = modData[modDataKey].listItems or {}
    modData[modDataKey].paperAmount = modData[modDataKey].paperAmount or 0
end

Events.OnFillInventoryObjectContextMenu.Add(WIT_Clipboard.InventoryContextMenu)