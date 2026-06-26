---
--- WIN_PageWindow.lua
--- 2025-11-29
---

require "GravyUI_WL"
require "WL_Utils"
require "WIN_Utils"

WIN_NotePaperWindow = ISCollapsableWindow:derive("WIN_NotePaperWindow")

local function doAnimation(player, notebook, isNotebookInInventory, isReadOnly)
     if not isNotebookInInventory then
        return nil
     end

    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if #queue.queue > 0 then
        return nil -- Don't open if they are busy
    end

    local writingImplement = nil
    if not isReadOnly then
        local playerInv = player:getInventory()
        if playerInv:containsTagRecurse("Pencil") then
            writingImplement =  "Base.Pencil"
        else
            writingImplement = "Base.Pen"
        end
    end
    local action = WIN_ReadWriteTimedAction:new(player, notebook:getFullType(), writingImplement)
    ISTimedActionQueue.add(action)
    return action
end

--- Displays a note/paper window from a context menu interaction.
--- Handles animations, read-only state, and inventory checks.
--- @param notebook zombie.inventory.types.Literature The notebook/paper item to display
--- @param forceReadOnly boolean|nil If true, forces the window to be read-only regardless of other conditions
function WIN_NotePaperWindow.displayFromContextMenu(notebook, forceReadOnly)
    local isNotebookInInventory = getPlayer():getInventory():getFirstTypeEvalRecurse(
        notebook:getFullType(), function(item) return item == notebook end)

    local isReadOnly = forceReadOnly
    if not isNotebookInInventory then
        isReadOnly = true -- Avoid ppl trying to edit papers on the floor
    end

    if notebook:getLockedBy() and (notebook:getLockedBy() ~= getPlayer():getUsername()) and not WL_Utils.isStaff(getPlayer()) then
        isReadOnly = true -- Can't edit if locked by someone else
    end

    local action = doAnimation(getPlayer(), notebook, isNotebookInInventory, isReadOnly)

    local pageContents = {}
     for i=0, notebook:getCustomPages():size() - 1 do
        pageContents[i + 1] = notebook:seePage(i + 1)
    end

    local fontKey = WIN_Utils.getFontKey(notebook)
    local skinKey = WIN_Utils.getSkinKey(notebook)

    local notePaperWindow = WIN_NotePaperWindow:new(notebook, isReadOnly, action, pageContents,
        notebook:getPageToWrite(), fontKey, skinKey)
    notePaperWindow:addToUIManager()
end

--- Displays a note/paper window from a server message (always read-only).
--- Used when the server sends a page to display to the client.
--- @param pageContent string The text content of the page to display
--- @param fontKey string The font key to use for rendering (from WIN_Font.FONTS)
--- @param skinKey string The skin key to use for the background texture
function WIN_NotePaperWindow.displayFromServerMessage(pageContent, fontKey, skinKey)
    local pageContents = {}
    pageContents[1] = pageContent
    local notePaperWindow = WIN_NotePaperWindow:new(nil, true, nil, pageContents, 1, fontKey, skinKey)
    notePaperWindow:addToUIManager()
end

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_DARK_GREY = {r=0.25,g=0.25,b=0.25,a=1}
local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
	return px * SCALE
end

---@param notebook zombie.inventory.types.Literature|nil Optional param, needed if isReadOnly is false
---@param isReadOnly boolean true if the user should not be able to edit the text and can only view it
---@param action WIN_ReadWriteTimedAction|nil The timed action used to open this window, can be nil if there is none
---@param pageContents table<number, string> A table of page number to page content
---@param maxPages number The maximum number of pages the literature can have
---@param fontKey string The font key to use for the text box - this is a string key from WIN_Font.FONTS
---@param skinKey string|nil The skin key to use for the literature background
---@return WIN_NotePaperWindow The newly created window instance
function WIN_NotePaperWindow:new(notebook, isReadOnly, action, pageContents, maxPages, fontKey, skinKey)
    local skin = WIN_LiteratureSkin.findFromKey(skinKey)
    if skin == nil then error("Skin not found: " .. tostring(skinKey)) end
	local w = scale(440 + (skin.paddingLeft or 0) + (skin.paddingRight or 0))
	local h = scale(620 + (skin.paddingTop or 0) + (skin.paddingBottom or 0))
	local o = ISCollapsableWindow:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
	self.__index = self
    o.resizable = false
    o.currentPage = 1
    o.pageContents = pageContents
    o.originalPageContents = {}
    for i, pageContent in ipairs(pageContents) do
        o.originalPageContents[i] = pageContent
    end
    o.maxNumberOfPages = maxPages
    o.readOnly = isReadOnly
    o.notebook = notebook
    o.action = action
    o.font = WIN_Font.FONTS[fontKey] or UIFont.DefaultFont
    o.notebookTexture = getTexture(skin.texture)
    o:initialise(skin)
	return o
end

local function makeIconButton(button, texturePath)
    button.borderColor = {r=0, g=0, b=0, a=0}
    button.backgroundColor = {r=0, g=0, b=0, a=0}
    button.backgroundColorMouseOver = {r=0.6, g=0.6, b=0.6, a=0.8}
    button:setImage(getTexture(texturePath))
end

function WIN_NotePaperWindow:initialise(skin)
	ISCollapsableWindow.initialise(self)
    self:noBackground()
    self.borderColor = {r=0, g=0, b=0, a=0}
	self.backgroundColor = {r=0, g=0, b=0, a=0.9}
	self.moveWithMouse = true
	local win = GravyUI.Node(self.width, self.height, self):pad(0, self:titleBarHeight(), 0, 0)
    win = win:pad(scale(skin.paddingLeft or 0), scale(skin.paddingTop or 0),
        scale(skin.paddingRight or 0), scale(skin.paddingBottom or 0))
    local buttonHeight = scale(30)
    local textNode, buttonsNode = win:rows({win.height - buttonHeight - scale(15), buttonHeight}, scale(10))
    self.textBox = textNode:makeTextBox(self.pageContents[self.currentPage], false, self.font)
	self.textBox.backgroundColor = {r=0, g=0, b=0, a=0}
	self.textBox:setMultipleLine(true)
    local lines = 15
	self.textBox.javaObject:setMaxLines(lines)
    self.textBox.javaObject:setMaxTextLength(lines * 80)
    self.textBox.javaObject:setTextColor(ColorInfo.new(0.05, 0.05, 0.05, 1))
    if self.readOnly then self.textBox:setEditable(false) end
    self.textBox.borderColor = {r=0, g=0, b=0, a=0} -- Do last as setEditable resets border

    local buttonsLeft, buttonsRight = buttonsNode:cols( {0.6, 0.4}, scale(10))
    local buttonsLeftStack = buttonsLeft:makeHorizontalStack(10)

    if not self.readOnly then
        local saveNode = buttonsLeftStack:makeNode(buttonHeight)
        self.saveButton = saveNode:makeButton("", self, self.onSave)
        makeIconButton(self.saveButton, "media/textures/ui/SaveDiskIcon.png")
    end

    local cancelNode = buttonsLeftStack:makeNode(buttonHeight)
    self.cancelButton = cancelNode:makeButton("", self, self.close)
    makeIconButton(self.cancelButton, "media/textures/ui/CancelIcon.png")

    if not self.readOnly then
        local clearNode = buttonsLeftStack:makeNode(buttonHeight)
        self.clearButton = clearNode:makeButton("", self, self.onClear)
        makeIconButton(self.clearButton, "media/textures/ui/TrashIcon.png")
        local lockNode = buttonsLeftStack:makeNode(buttonHeight)
        self.lockButton =lockNode:makeButton("", self, self.onToggleLock)
        makeIconButton(self.lockButton, "media/textures/ui/LockedIcon.png")
    end

    if self.maxNumberOfPages > 1 then
        local buttonsRightStack = buttonsRight:makeHorizontalStack(10)
        local prevPageNode = buttonsRightStack:makeNode(buttonHeight)
        self.prevPageButton = prevPageNode:makeButton("", self, self.onPrevPage)
        self.prevPageButton.sounds.activate = "NotebookTurnPage1"
        makeIconButton(self.prevPageButton, "media/textures/ui/PreviousPageIcon.png")
        local pageLabelNode = buttonsRightStack:makeNode(scale(50))
        self.pageLabel = pageLabelNode:makeLabel("", UIFont.Large, COLOR_DARK_GREY, "center")
        local nextPageNode = buttonsRightStack:makeNode(buttonHeight)
        self.nextPageButton = nextPageNode:makeButton("", self, self.onNextPage)
        self.nextPageButton.sounds.activate = "NotebookTurnPage2"
        makeIconButton(self.nextPageButton, "media/textures/ui/NextPageIcon.png")
    end

    self:updateState()

    if not self.readOnly then
        self:setLocked(self.notebook:getLockedBy() ~= nil)
    else
        self.textBox:setEditable(false)
        self.textBox.borderColor = {r=0, g=0, b=0, a=0} -- Do last as setEditable resets border
    end
end

function WIN_NotePaperWindow:onSave()
    if not WIN_Utils.hasLanguageKey(self.notebook) then
        WIN_Utils.setLanguageKey(self.notebook, WIN_Utils.getDefaultNoteLanguageKey())
    end
    self.pageContents[self.currentPage] = self.textBox:getText()
    WIN_Utils.writeContentChangeLog(getPlayer(), self.notebook, self.originalPageContents, self.pageContents)
    for i,v in ipairs(self.pageContents) do
        self.notebook:addPage(i,v)
    end
    self:close()
end

function WIN_NotePaperWindow:onClear()
    self.pageContents[self.currentPage] = ""
    self.textBox:setText("")
    self.textBox.javaObject:setCursorLine(0)
end

function WIN_NotePaperWindow:onToggleLock(_)
    self:setLocked(self.notebook:getLockedBy() == nil)
end

--- Sets the locked state of the notebook.
--- When locked, the notebook is set to read-only and shows a locked icon.
--- @param isLocked boolean true to lock the notebook, false to unlock
function WIN_NotePaperWindow:setLocked(isLocked)
    if isLocked then
        self.notebook:setLockedBy(getPlayer():getUsername())
        self.lockButton:setImage(getTexture("media/textures/ui/LockedIcon.png"))
        self.textBox:setEditable(false)
    else
        self.notebook:setLockedBy(nil)
        self.lockButton:setImage(getTexture("media/textures/ui/UnlockedIcon.png"))
        self.textBox:setEditable(true)
    end
    self.textBox.borderColor = {r=0, g=0, b=0, a=0} -- Do last as setEditable resets border
end

function WIN_NotePaperWindow:updateState()
    if self.maxNumberOfPages > 1 then
        self.pageLabel:setText(tostring(self.currentPage) .. "/" .. tostring(self.maxNumberOfPages))
    end
end

--- Navigates to the previous page in the notebook.
--- Saves current page content before switching.
function WIN_NotePaperWindow:onPrevPage()
    if self.currentPage > 1 then
        self.pageContents[self.currentPage] = self.textBox:getText()
        self.currentPage = self.currentPage - 1
        self.textBox:setText(self.pageContents[self.currentPage] or "")
        self.textBox.javaObject:setCursorLine(0)
        self:updateState()
    end
end

--- Navigates to the next page in the notebook.
--- Saves current page content before switching.
function WIN_NotePaperWindow:onNextPage()
    if self.currentPage < self.maxNumberOfPages then
        self.pageContents[self.currentPage] = self.textBox:getText()
        self.currentPage = self.currentPage + 1
        self.textBox:setText(self.pageContents[self.currentPage] or "")
        self.textBox.javaObject:setCursorLine(0)
        self:updateState()
    end
end

function WIN_NotePaperWindow:getLightLevelToDraw()
    local player = getPlayer()
    local lightLevel = player:getSquare():getLightLevel(player:getPlayerNum())
    if lightLevel < 0.75 then lightLevel = lightLevel - 0.27 end
    if lightLevel < 0.05 then lightLevel = 0.05 end

    if not self.currLightLevel then
        self.currLightLevel = lightLevel
    elseif self.currLightLevel < lightLevel then
        self.currLightLevel = math.min(self.currLightLevel + 0.04, lightLevel)
    elseif self.currLightLevel > lightLevel then
        self.currLightLevel = math.max(self.currLightLevel - 0.04, lightLevel)
    end
    return self.currLightLevel
end

function WIN_NotePaperWindow:prerender()
    local lightLevel = self:getLightLevelToDraw()
    self.pinButton:setVisible(false)
    self.collapseButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:drawTextureScaled(self.notebookTexture, 0, 0, self.width, self.height, 1.0, lightLevel, lightLevel, lightLevel)
end

--- Closes the window and clears any associated timed actions.
--- If the window was opened via a timed action, it will be removed from the queue.
function WIN_NotePaperWindow:close()
    if self.action then
        local queue = ISTimedActionQueue.getTimedActionQueue(getPlayer())
        if #queue.queue > 0 and queue.queue[1] == self.action then
         ISTimedActionQueue.clear(getPlayer())
        end
    end
    ISPanelJoypad.removeFromUIManager(self)
end
