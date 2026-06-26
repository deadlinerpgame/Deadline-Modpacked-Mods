-- TileEditorFloodFill.lua
-- Handles the "Flood Fill" editing mode

require "ISUI/ISPanel"
require "GravyUI_WL"

TileEditorFloodFill = ISPanel:derive("TileEditorFloodFill")

function TileEditorFloodFill:new(x, y, width, height, mainEditor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.preferredHeight = 200 * (mainEditor.scale or 1)
    
    o.fillTile = nil
    o.maxDistance = 10
    o.fillMode = "floor" -- "floor" or "roof"
    
    return o
end

function TileEditorFloodFill:createChildren()
    ISPanel.createChildren(self)
    
    local win = GravyUI.Node(self.width, self.height, self):pad(10, 10, 10, 10)
    
    -- Layout: 3 columns + Status row at bottom
    local mainContent, statusRow = win:rows({1, 20 * (self.mainEditor.scale or 1)}, 5)
    local col1, col2, col3 = mainContent:cols({0.2, 0.2, 0.6}, 10)
    
    self:buildTileColumn(col1)
    self:buildSettingsColumn(col2)
    self:buildControlColumn(col3)
    self:buildStatusUI(statusRow)
end

function TileEditorFloodFill:buildTileColumn(node)
    local label, btnContainer = node:rows({20, 1.0}, 5)
    self.tileLabel = label:makeLabel("Tile:", UIFont.Small, {r=1,g=1,b=1,a=1}, "center")
    
    self.tileBtn = btnContainer:makeButton("", self, self.onTileClick)
    self.tileBtn.tooltip = "Click with a tile on cursor to set Fill Tile"
    self.tileBtn.borderColor = {r=1, g=1, b=1, a=1}
end

function TileEditorFloodFill:buildSettingsColumn(node)
    local modeLabel, modeCombo, distLabel, distEntry = node:rows({20, 25, 20, 25}, 5)
    
    self.modeLabel = modeLabel:makeLabel("Mode:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.modeCombo = modeCombo:makeComboBox(self, self.onModeChange)
    self.modeCombo:addOption("Floor")
    self.modeCombo:addOption("Roof")
    self.modeCombo:select("Floor")
    
    self.distLabel = distLabel:makeLabel("Max Dist:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.distEntry = distEntry:makeTextBox(tostring(self.maxDistance), true)
    self.distEntry:setOnlyNumbers(true)
    self.distEntry.tooltip = "Maximum distance to flood fill"
end

function TileEditorFloodFill:buildControlColumn(node)
    -- Col 3: Selection info and Go button
    local leftCol, rightCol = node:cols({150 * (self.mainEditor.scale or 1), 80 * (self.mainEditor.scale or 1)}, 5)
    local label, selectBtn = leftCol:rows({20 * (self.mainEditor.scale or 1), 25 * (self.mainEditor.scale or 1)}, 5)
    local goBtn = rightCol:resize(rightCol.width, 40 * (self.mainEditor.scale or 1))

    self.selectionLabel = label:makeLabel("Selection: Point", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.selectModeBtn = selectBtn:makeButton("Select Point", self, self.onToggleSelectionMode)
    self.selectModeBtn.tooltip = "Toggle selection mode (Point only)"
    self:updateSelectModeButton()
    
    self.fillBtn = goBtn:makeButton("Go", self, self.onFill)
    self.fillBtn.tooltip = "Start Flood Fill from selected point"
end

function TileEditorFloodFill:buildStatusUI(node)
    self.statusLabel = node:makeLabel("", UIFont.Small, {r=0.7,g=1,b=0.7,a=1}, "center")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function TileEditorFloodFill:onTileClick()
    local cursor = getCell():getDrag(0)
    if cursor and cursor.choosenSprite then
        self.fillTile = cursor.choosenSprite
        self.tileBtn:setImage(getTexture(self.fillTile))
        getCell():setDrag(nil, 0)
        self.mainEditor.statusMessage = "Fill tile set: " .. self.fillTile
    else
        self.fillTile = nil
        self.tileBtn:setImage(nil)
        self.mainEditor.statusMessage = "Fill tile cleared"
    end
end

function TileEditorFloodFill:onModeChange(combo)
    self.fillMode = combo:getOptionText(combo.selected)
    self.fillMode = string.lower(self.fillMode)
end

function TileEditorFloodFill:onToggleSelectionMode()
    -- Force point selection for flood fill
    if self.mainEditor.selection then
        self.mainEditor.selection:setType("point")
    end
    
    self.mainEditor.selectionModeActive = not self.mainEditor.selectionModeActive
    self:updateSelectModeButton()
    
    if self.mainEditor.selectionModeActive then
        self.mainEditor.statusMessage = "Selection mode active. Click a point in the world."
        TileEditorUtils.debug("Selection mode activated (Point)")
    else
        self.mainEditor.statusMessage = "Selection mode deactivated."
        TileEditorUtils.debug("Selection mode deactivated")
    end
end

function TileEditorFloodFill:updateSelectModeButton()
    if self.mainEditor.selectionModeActive then
        self.selectModeBtn.backgroundColor = {r=0.2, g=0.8, b=0.2, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.3, g=0.9, b=0.3, a=1.0}
    else
        self.selectModeBtn.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.5, g=0.5, b=0.5, a=1.0}
    end
end

function TileEditorFloodFill:onFill()
    if not self.fillTile then
        self.mainEditor.statusMessage = "Set a Fill Tile first!"
        return
    end
    
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Select a starting point first."
        return
    end
    
    -- Get start point from selection
    local tiles = self.mainEditor.selection:getAffectedTiles()
    if #tiles == 0 then return end
    local startPoint = tiles[1] -- Should be only one for point selection
    
    local distText = self.distEntry:getText()
    if distText and distText ~= "" then
        self.maxDistance = tonumber(distText) or 10
    end

    local count = self.mainEditor.actions:floodFill(startPoint, self.fillTile, self.fillMode, self.maxDistance, self.mainEditor.undoManager)
    self.mainEditor:refresh()
    self.mainEditor.statusMessage = "Flood filled " .. count .. " tiles."
end

function TileEditorFloodFill:onSelectionFinished(selection)
    -- Called when selection is finished in main editor
    -- Ensure we stay in point mode if we are active
    if selection:getType() ~= "point" then
        selection:setType("point")
    end
end

function TileEditorFloodFill:prerender()
    ISPanel.prerender(self)
    
    if self.mainEditor and self.mainEditor.lightMode then
        self.tileBtn.backgroundColor = {r=1, g=1, b=1, a=1.0}
    else
        self.tileBtn.backgroundColor = {r=0, g=0, b=0, a=1.0}
    end

    -- Update status labels
    if self.statusLabel then
        if self.mainEditor.selection:hasSelection() then
            local info = self.mainEditor.selection:getSelectionInfo()
            self.statusLabel:setText(info)
        else
            self.statusLabel:setText("")
        end
    end
    
    -- Keep select mode button in sync
    self:updateSelectModeButton()
end

return TileEditorFloodFill
