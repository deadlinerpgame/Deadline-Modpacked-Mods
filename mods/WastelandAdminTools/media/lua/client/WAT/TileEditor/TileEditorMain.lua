-- TileEditorMain.lua
-- Main UI panel and entry point for the Tile Editor system

require "ISUI/ISCollapsableWindow"
require "ISUI/ISTextBox"
require "ISUI/ISContextMenu"
require "GravyUI_WL"

-- Load all TileEditor modules
require "WAT/TileEditor/TileEditorUtils"
require "WAT/TileEditor/TileEditorPalette"
require "WAT/TileEditor/TileEditorSelection"
require "WAT/TileEditor/TileEditorActions"
require "WAT/TileEditor/TileEditorUndo"
require "WAT/TileEditor/TileEditorBulk"
require "WAT/TileEditor/TileEditorPicker"
require "WAT/TileEditor/TileEditorReplacement"
require "WAT/TileEditor/TileEditorFloodFill"
require "WAT/TileEditor/TileEditorLayers"
require "WAT/TileEditor/Overrides"
require "ISUI/ISTabPanel"

TileEditorMain = ISCollapsableWindow:derive("TileEditorMain")
TileEditorMain.instance = nil

-- ============================================================================
-- Display / Constructor
-- ============================================================================

function TileEditorMain:display()
    if TileEditorMain.instance then
        TileEditorMain.instance:close()
    end
    
    local scale = getTextManager():MeasureStringY(UIFont.Small, "X") / 12
    local width = 700 * scale
    local height = 600 * scale
    local x = getCore():getScreenWidth() / 2 - width / 2
    local y = getCore():getScreenHeight() / 2 - height / 2
    
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.scale = scale
    o:initialise()
    o:addToUIManager()
    TileEditorMain.instance = o
    return o
end

-- ============================================================================
-- Initialization
-- ============================================================================

function TileEditorMain:initialise()
    ISCollapsableWindow.initialise(self)
    
    self.title = "Tile Editor"
    self:setResizable(false)
    self.moveWithMouse = true
    self.paletteHeight = 180
    
    -- Initialize subsystems
    self.palette = TileEditorPalette:new(0, 0, 100, 100)
    self.selection = TileEditorSelection:new()
    self.actions = TileEditorActions:new()
    self.undoManager = TileEditorUndo:new()
    
    -- Current state
    self.mode = "single"  -- "single", "random", or "cycle"
    self.partialPercent = 50
    self.thickness = 1  -- Thickness for ring/box selections
    self.selectionModeActive = false  -- Track if we're in selection mode
    self.cycleIndex = 1  -- Track current position in cycle mode
    
    -- World Select Mode
    self.worldSelectModeActive = false
    self.worldDeleteModeActive = false
    
    self.lightMode = false
end

function TileEditorMain:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    -- Calculate heights
    local th = self:titleBarHeight()
    local paletteHeight = self.paletteHeight * self.scale
    local bodyHeight = self.height - paletteHeight - th
    
    -- Build Palette UI (Top)
    local paletteNode = GravyUI.Node(self.width, paletteHeight, self):pad(2, th, 2, 0)
    self:buildPaletteUI(paletteNode)
    
    -- Build Tab Panel (Bottom)
    self.tabPanel = ISTabPanel:new(0, paletteHeight, self.width, bodyHeight)
    self.tabPanel:initialise()
    self.tabPanel.borderColor = {r=0, g=0, b=0, a=0}
    self.tabPanel.target = self
    self:addChild(self.tabPanel)

    self.noneView = ISPanel:new(0, 0, 0, 0)
    self.noneView:initialise()
    self.tabPanel:addView("None", self.noneView)  -- Empty view for no editor
    
    self.pickerEditor = TileEditorPicker:new(0, 0, self.tabPanel.width, self.tabPanel.height - self.tabPanel.tabHeight, self)
    self.pickerEditor:setHeight(self.pickerEditor.preferredHeight)
    self.pickerEditor:initialise()
    self.tabPanel:addView("Picker", self.pickerEditor)

    self.bulkEditor = TileEditorBulk:new(0, 0, self.tabPanel.width, self.tabPanel.height - self.tabPanel.tabHeight, self)
    self.bulkEditor:setHeight(self.bulkEditor.preferredHeight)
    self.bulkEditor:initialise()
    self.tabPanel:addView("Bulk", self.bulkEditor)
    
    self.replacementEditor = TileEditorReplacement:new(0, 0, self.tabPanel.width, self.tabPanel.height - self.tabPanel.tabHeight, self)
    self.replacementEditor:setHeight(self.replacementEditor.preferredHeight)
    self.replacementEditor:initialise()
    self.tabPanel:addView("Replace", self.replacementEditor)
    
    self.floodFillEditor = TileEditorFloodFill:new(0, 0, self.tabPanel.width, self.tabPanel.height - self.tabPanel.tabHeight, self)
    self.floodFillEditor:setHeight(self.floodFillEditor.preferredHeight)
    self.floodFillEditor:initialise()
    self.tabPanel:addView("Flood Fill", self.floodFillEditor)

    self.layersEditor = TileEditorLayers:new(0, 0, self.tabPanel.width, self.tabPanel.height - self.tabPanel.tabHeight, self)
    self.layersEditor:setHeight(self.layersEditor.preferredHeight)
    self.layersEditor:initialise()
    self.tabPanel:addView("Layers", self.layersEditor)

    -- Hook into tab switching
    local originalActivateView = self.tabPanel.activateView
    self.tabPanel.activateView = function(panel, viewName)
        if originalActivateView then originalActivateView(panel, viewName) end
        if self.onTabActivated then self:onTabActivated(viewName) end
    end
    
    -- Trigger initial resize for the default tab
    if self.tabPanel.activeView then
        self:onTabActivated(self.tabPanel.activeView.name)
    end
end

function TileEditorMain:onTabActivated(viewName)
    local view = nil
    if viewName == "Picker" then view = self.pickerEditor
    elseif viewName == "Bulk" then view = self.bulkEditor
    elseif viewName == "Replace" then view = self.replacementEditor
    elseif viewName == "Flood Fill" then view = self.floodFillEditor
    elseif viewName == "Layers" then view = self.layersEditor
    elseif viewName == "None" then view = self.noneView
    end
    
    if view then
        local paletteHeight = self.paletteHeight * self.scale
        local tabHeight = self.tabPanel.tabHeight or 20
        
        local newBodyHeight = view.height + tabHeight
        local newTotalHeight = paletteHeight + newBodyHeight
        
        self:setHeight(newTotalHeight)
        self.tabPanel:setHeight(newBodyHeight)
    end
end

-- ============================================================================
-- UI Building Methods
-- ============================================================================

function TileEditorMain:buildPaletteUI(node)
    local label, buttons, info, content = node:rows({20, 25, 20, 1.0}, 2)
    self.statusLabel = label:makeLabel("", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    -- Save/Load buttons
    local saveBtn, loadBtn, clearBtn, worldSelectBtn, worldDeleteBtn, undoBtn, lightModeBox = buttons:cols(7, 5)
    
    self.infoLabel  = info:makeLabel("R-Click: Remove    |    Ctrl+R-Click: Go To Sheet    |    Brackets: Cycle Single    |    Ctrl+Brackets: Cycle Next", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")

    self.lightModeTick = lightModeBox:makeTickBox(self, self.onLightModeToggled)
    self.lightModeTick:addOption("Light", false)
    self.lightModeTick.tooltip = "Toggle light background mode"

    self.savePaletteBtn = saveBtn:makeButton("Save", self, self.onSavePalette)
    self.savePaletteBtn.tooltip = "Save current palette to disk"
    
    self.loadPaletteBtn = loadBtn:makeButton("Load", self, self.onLoadPalette)
    self.loadPaletteBtn.tooltip = "Load a saved palette from disk"
    
    self.clearPaletteBtn = clearBtn:makeButton("Clear", self, self.onClearPalette)
    self.clearPaletteBtn.tooltip = "Clear all tiles from current palette"

    self.worldSelectBtn = worldSelectBtn:makeButton("World Select", self, self.onWorldSelect)
    self.worldSelectBtn.tooltip = "Select a tile from the world to add to palette"

    self.worldDeleteBtn = worldDeleteBtn:makeButton("World Delete", self, self.onWorldDelete)
    self.worldDeleteBtn.tooltip = "Delete a tile from the world"

    self.undoBtn = undoBtn:makeButton("Undo (0)", self, self.onUndo)
    self.undoBtn.tooltip = "Undo the last action"
    self.undoBtn:setEnable(false)
    
    -- Palette display panel takes full width
    self.palettePanel = TileEditorPalette:new(
        content.left, content.top,
        content.width, content.height
    )
    self.palettePanel:initialise()
    self:addChild(self.palettePanel)
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

-- Handlers moved to TileEditorBulk.lua

function TileEditorMain:onSavePalette()
    if self.palettePanel:isEmpty() then
        self.statusMessage = "Cannot save: palette is empty!"
        return
    end
    
    -- Prompt user for palette name
    local modal = ISTextBox:new(0, 0, 280, 180, "Enter palette name:", "", self, self.onSavePaletteConfirm)
    modal:initialise()
    modal:addToUIManager()
end

function TileEditorMain:onSavePaletteConfirm(button)
    if button.internal == "OK" then
        local text = button.parent.entry:getText()
        if text and text ~= "" then
            if self.palettePanel:savePalette(text) then
                self.statusMessage = "Palette saved: " .. text
            else
                self.statusMessage = "Failed to save palette"
            end
        end
    end
end

function TileEditorMain:onLoadPalette()
    -- Get list of saved palettes
    local paletteNames = TileEditorPalette.getSavedPaletteNames()
    
    if #paletteNames == 0 then
        self.statusMessage = "No saved palettes found"
        return
    end
    
    -- Create context menu with palette names
    local context = ISContextMenu.get(0, getMouseX() + 10, getMouseY() + 10)
    
    for _, name in ipairs(paletteNames) do
        local option = context:addOption(name, self, self.onLoadPaletteConfirm, name)
        
        -- Add delete submenu
        local subMenu = ISContextMenu:getNew(context)
        context:addSubMenu(option, subMenu)
        subMenu:addOption("Delete", self, self.onDeletePalette, name)
    end
end

function TileEditorMain:onLoadPaletteConfirm(paletteName)
    if self.palettePanel:loadPalette(paletteName) then
        self.statusMessage = "Loaded palette: " .. paletteName
    else
        self.statusMessage = "Failed to load palette: " .. paletteName
    end
end

function TileEditorMain:onDeletePalette(paletteName)
    if TileEditorPalette.deleteSavedPalette(paletteName) then
        self.statusMessage = "Deleted palette: " .. paletteName
    else
        self.statusMessage = "Failed to delete palette: " .. paletteName
    end
end

function TileEditorMain:switchToPickerAndSelect(sheetName)
    if not sheetName then return end
    
    -- Switch to Picker tab
    if self.tabPanel then
        self.tabPanel:activateView("Picker")
    end
    
    -- Select category in Picker
    if self.pickerEditor then
        self.pickerEditor:selectCategory(sheetName)
    end
end

function TileEditorMain:onClearPalette()
    if self.palettePanel:isEmpty() then
        self.statusMessage = "Palette is already empty"
        return
    end
    
    self.palettePanel:clearPalette()
    self.statusMessage = "Palette cleared"
end

function TileEditorMain:onUndo()
    if self.undoManager:undo() then
        self.statusMessage = "Undo successful"
        if self.selection then
            self.selection:updateHighlight()
        end
    else
        self.statusMessage = "Nothing to undo"
    end
end

function TileEditorMain:onWorldSelect()
    self.worldSelectModeActive = not self.worldSelectModeActive
    self.worldDeleteModeActive = false
    self.worldDeleteBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
    
    if self.worldSelectModeActive then
        self.worldSelectBtn.backgroundColor = {r=0.2, g=0.8, b=0.2, a=1.0}
        self.statusMessage = "World Select Mode: Hover over tiles, use [ and ] to cycle, Click to add."
        -- Disable other selection modes if necessary
        if self.selectionModeActive then
             self.selectionModeActive = false
             if self.bulkEditor then self.bulkEditor:updateSelectModeButton() end
        end
        
        local cursor = WATTileCursor:new(getSpecificPlayer(0), "select", self)
        getCell():setDrag(cursor, 0)
    else
        self.worldSelectBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
        self.statusMessage = "World Select Mode deactivated."
        getCell():setDrag(nil, 0)
    end
end

function TileEditorMain:onWorldDelete()
    self.worldDeleteModeActive = not self.worldDeleteModeActive
    self.worldSelectModeActive = false
    self.worldSelectBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
    
    if self.worldDeleteModeActive then
        self.worldDeleteBtn.backgroundColor = {r=0.8, g=0.2, b=0.2, a=1.0}
        self.statusMessage = "World Delete Mode: Hover over tiles, use [ and ] to cycle, Click to DELETE."
        -- Disable other selection modes if necessary
        if self.selectionModeActive then
             self.selectionModeActive = false
             if self.bulkEditor then self.bulkEditor:updateSelectModeButton() end
        end
        
        local cursor = WATTileCursor:new(getSpecificPlayer(0), "delete", self)
        getCell():setDrag(cursor, 0)
    else
        self.worldDeleteBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
        self.statusMessage = "World Delete Mode deactivated."
        getCell():setDrag(nil, 0)
    end
end

function TileEditorMain:onLightModeToggled(index, selected)
    self.lightMode = selected
end
function TileEditorMain:refresh()
    self.selection:updateHighlight()
    self.layersEditor:onRefresh()
end


-- ============================================================================
-- Mouse Handling for Selection
-- ============================================================================

function TileEditorMain:onMouseDown(x, y)
    return ISCollapsableWindow.onMouseDown(self, x, y)
end

function TileEditorMain:onMouseUp(x, y)
    return ISCollapsableWindow.onMouseUp(self, x, y)
end

function TileEditorMain:onRightMouseDown(x, y)
    return ISCollapsableWindow.onRightMouseDown(self, x, y)
end


-- ============================================================================
-- Rendering
-- ============================================================================

function TileEditorMain:prerender()
    ISCollapsableWindow.prerender(self)
    if self.statusLabel then
        self.statusLabel:setText(self.statusMessage or "")
    end

    if self.undoBtn and self.undoManager then
        local count = self.undoManager:getStackSize()
        self.undoBtn.title = "Undo (" .. count .. ")"
        self.undoBtn:setEnable(count > 0)
    end
end

function TileEditorMain:render()
    ISCollapsableWindow.render(self)
end

-- ============================================================================
-- Cleanup
-- ============================================================================

function TileEditorMain:close()
    if self.selection then
        self.selection:cleanup()
    end
    
    getCell():setDrag(nil, 0)
    
    ISCollapsableWindow.close(self)
    TileEditorMain.instance = nil
end

-- ============================================================================
-- Global Event Handlers
-- ============================================================================

-- Handle world clicks for selection
local function onMouseDown(x, y)
    if not TileEditorMain.instance then return end
    
    -- Handle World Select/Delete Mode
    if TileEditorMain.instance.worldSelectModeActive or TileEditorMain.instance.worldDeleteModeActive then
        -- Click handled by WATTileCursor
        return
    end

    -- Only allow selection if selection mode is active
    if not TileEditorMain.instance.selectionModeActive then return end
    
    local player = getPlayer()
    if not player then return end
    
    local z = player:getZ()
    local worldX, worldY = TileEditorUtils.screenToWorld(x, y, z)
    
    if worldX and worldY then
        TileEditorMain.instance.selection:startSelection(worldX, worldY, z)
    end
end

local function onRightMouseUp()
    if not TileEditorMain.instance then return end
    if TileEditorMain.instance.selection:isCurrentlySelecting() then
        TileEditorMain.instance.selection:cancelSelection()
        TileEditorMain.instance.statusMessage = "Selection cancelled."
    end
    if TileEditorMain.instance.worldSelectModeActive or TileEditorMain.instance.worldDeleteModeActive then
        TileEditorMain.instance.worldSelectModeActive = false
        TileEditorMain.instance.worldDeleteModeActive = false
        TileEditorMain.instance.worldSelectBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
        TileEditorMain.instance.worldDeleteBtn.backgroundColor = {r=0.0, g=0.0, b=0.0, a=1.0}
        TileEditorMain.instance.statusMessage = "Mode deactivated."
        getCell():setDrag(nil, 0)
    end
end

local function onMouseMove(x, y)
    if not TileEditorMain.instance then return end

    -- Handle World Select/Delete Mode
    if TileEditorMain.instance.worldSelectModeActive or TileEditorMain.instance.worldDeleteModeActive then
        -- Cursor handles update via render
        return
    end

    if not TileEditorMain.instance.selection:isCurrentlySelecting() then return end
    
    local player = getPlayer()
    if not player then return end
    
    local z = player:getZ()
    local worldX, worldY = TileEditorUtils.screenToWorld(x, y, z)
    
    if worldX and worldY then
        TileEditorMain.instance.selection:updateSelection(worldX, worldY)
    end
end

local function onKeyPressed(key)
    local self = TileEditorMain.instance
    if not self then return end
    
    -- Handle Palette Cycling (Brackets)
    -- Check if mouse is over palette
    if self.palettePanel and self.palettePanel:isMouseOver() then
        local isCtrl = isCtrlKeyDown()
        local palette = self.palettePanel
        
        if key == Keyboard.KEY_LBRACKET then -- [
            if isCtrl and self.mode == "cycle" then
                -- Cycle "Next" indicator (cycleIndex)
                if palette:getTileCount() > 0 then
                    self.cycleIndex = self.cycleIndex - 1
                    if self.cycleIndex < 1 then self.cycleIndex = palette:getTileCount() end
                end
            else
                -- Cycle "Single" indicator (singleIndex)
                if palette:getTileCount() > 0 then
                    palette.singleIndex = palette.singleIndex - 1
                    if palette.singleIndex < 1 then palette.singleIndex = palette:getTileCount() end
                end
            end
            return
        elseif key == Keyboard.KEY_RBRACKET then -- ]
            if isCtrl and self.mode == "cycle" then
                -- Cycle "Next" indicator (cycleIndex)
                if palette:getTileCount() > 0 then
                    self.cycleIndex = self.cycleIndex + 1
                    if self.cycleIndex > palette:getTileCount() then self.cycleIndex = 1 end
                end
            else
                -- Cycle "Single" indicator (singleIndex)
                if palette:getTileCount() > 0 then
                    palette.singleIndex = palette.singleIndex + 1
                    if palette.singleIndex > palette:getTileCount() then palette.singleIndex = 1 end
                end
            end
            return
        end
    end

    if not self.worldSelectModeActive and not self.worldDeleteModeActive then return end
    
    local cursor = getCell():getDrag(0)
    if cursor and cursor.Type == "WATTileCursor" then
        cursor:onKeyPressed(key)
    end
end

local function onMouseUp(x, y)
    if not TileEditorMain.instance then return end
    if not TileEditorMain.instance.selection:isCurrentlySelecting() then return end
    
    TileEditorMain.instance.selection:finishSelection()
    
    -- Notify active tab
    if TileEditorMain.instance.tabPanel and TileEditorMain.instance.tabPanel.activeView then
        local view = TileEditorMain.instance.tabPanel.activeView.view
        if view and view.onSelectionFinished then
            view:onSelectionFinished(TileEditorMain.instance.selection)
        end
    end

    -- Deactivate selection mode after completing a selection
    if TileEditorMain.instance.selectionModeActive then
        TileEditorMain.instance.selectionModeActive = false
        -- Update UI in Bulk editor if it exists
        if TileEditorMain.instance.bulkEditor then
            TileEditorMain.instance.bulkEditor:updateSelectModeButton()
        end
        if TileEditorMain.instance.floodFillEditor then
            TileEditorMain.instance.floodFillEditor:updateSelectModeButton()
        end
        TileEditorMain.instance.statusMessage = "Selection completed. Selection mode deactivated."
        TileEditorUtils.debug("Selection mode auto-deactivated after selection")
    end
end

-- Register events
Events.OnMouseDown.Add(onMouseDown)
Events.OnRightMouseUp.Add(onRightMouseUp)
Events.OnPreFillWorldObjectContextMenu.Add(onRightMouseUp)
Events.OnMouseMove.Add(onMouseMove)
Events.OnMouseUp.Add(onMouseUp)
Events.OnKeyPressed.Add(onKeyPressed)

return TileEditorMain
