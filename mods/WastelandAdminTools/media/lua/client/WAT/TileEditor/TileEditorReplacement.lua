-- TileEditorReplacement.lua
-- Handles the "Replacement" editing mode

require "ISUI/ISPanel"
require "GravyUI_WL"

TileEditorReplacement = ISPanel:derive("TileEditorReplacement")

function TileEditorReplacement:new(x, y, width, height, mainEditor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.preferredHeight = 200 * (mainEditor.scale or 1)
    
    o.sourceTile = nil
    o.targetTile = nil
    
    return o
end

function TileEditorReplacement:createChildren()
    ISPanel.createChildren(self)
    
    local win = GravyUI.Node(self.width, self.height, self):pad(10, 10, 10, 10)
    
    -- Layout: 3 columns + Status row at bottom
    local mainContent, statusRow = win:rows({1, 20 * (self.mainEditor.scale or 1)}, 5)
    local col1, col2, col3 = mainContent:cols({0.15, 0.15, 0.7}, 10)
    
    self:buildSourceColumn(col1)
    self:buildTargetColumn(col2)
    self:buildControlColumn(col3)
    self:buildStatusUI(statusRow)
end

function TileEditorReplacement:buildSourceColumn(node)
    local label, btnContainer = node:rows({20, 1.0}, 5)
    self.sourceLabel = label:makeLabel("Find:", UIFont.Small, {r=1,g=1,b=1,a=1}, "center")
    
    self.sourceBtn = btnContainer:makeButton("", self, self.onSourceClick)
    self.sourceBtn.tooltip = "Click with a tile on cursor to set Source Tile"
    self.sourceBtn.borderColor = {r=1, g=1, b=1, a=1}
end

function TileEditorReplacement:buildTargetColumn(node)
    local label, btnContainer = node:rows({20, 1.0}, 5)
    self.targetLabel = label:makeLabel("Replace With:", UIFont.Small, {r=1,g=1,b=1,a=1}, "center")
    
    self.targetBtn = btnContainer:makeButton("", self, self.onTargetClick)
    self.targetBtn.tooltip = "Click with a tile on cursor to set Target Tile"
    self.targetBtn.borderColor = {r=1, g=1, b=1, a=1}
end

function TileEditorReplacement:buildControlColumn(node)
    -- Col 3: Area Selector, thickness slider, select button, go button
    local leftCol, rightCol = node:cols({150 * (self.mainEditor.scale or 1), 80 * (self.mainEditor.scale or 1)}, 5)
    local label, options, thicknessRow, selectBtn = leftCol:rows({20 * (self.mainEditor.scale or 1), 1, 20 * (self.mainEditor.scale or 1), 20 * (self.mainEditor.scale or 1)}, 5)
    local goBtn = rightCol:resize(rightCol.width, 40 * (self.mainEditor.scale or 1))

    
    self.selectionLabel = label:makeLabel("Selection:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    -- Selection Shape
    self.selectionTickBox = options:makeTickBox(self, self.onSelectionChange)
    self.selectionTickBox.onlyOnePossibility = true
    self.selectionTickBox:addOption("Point")
    self.selectionTickBox:addOption("Rect")
    self.selectionTickBox:addOption("Circle")
    self.selectionTickBox:addOption("Box")
    self.selectionTickBox:addOption("Ring")
    self.selectionTickBox.tooltip = "Point: Single tile<LINE>Rect: Filled rectangle<LINE>Circle: Filled circle<LINE>Box: Rectangle border<LINE>Ring: Circle border"
    
    -- Sync with main editor
    if self.mainEditor.selection then
        local type = self.mainEditor.selection:getType()
        local index = 1
        if type == "rect" then index = 2
        elseif type == "circle" then index = 3
        elseif type == "box" then index = 4
        elseif type == "ring" then index = 5
        end
        self.selectionTickBox:setSelected(index, true)
    end
    
    -- Thickness
    local thicknessLabel, thicknessSlider = thicknessRow:cols({0.35, 0.65}, 5)
    self.thicknessLabel = thicknessLabel:makeLabel("Thick:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.thicknessSlider = thicknessSlider:makeSlider(self, self.onThicknessSliderChange)
    self.thicknessSlider:setValues(1, 10, 1, 1, false)
    self.thicknessSlider:setCurrentValue(self.mainEditor.thickness or 1)
    self.thicknessSlider.tooltip = "Thickness for Ring and Box selections"
    
    self.selectModeBtn = selectBtn:makeButton("Select", self, self.onToggleSelectionMode)
    self.selectModeBtn.tooltip = "Toggle selection mode"
    self:updateSelectModeButton()
    
    self.replaceBtn = goBtn:makeButton("Go", self, self.onReplace)
    self.replaceBtn.tooltip = "Replace all instances of Source with Target in selection"
end

function TileEditorReplacement:buildStatusUI(node)
    self.statusLabel = node:makeLabel("", UIFont.Small, {r=0.7,g=1,b=0.7,a=1}, "center")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function TileEditorReplacement:onSourceClick()
    local cursor = getCell():getDrag(0)
    if cursor and cursor.choosenSprite then
        self.sourceTile = cursor.choosenSprite
        self.sourceBtn:setImage(getTexture(self.sourceTile))
        -- self.sourceBtn:setTitle(self.sourceTile) 
        getCell():setDrag(nil, 0)
        self.mainEditor.statusMessage = "Source tile set: " .. self.sourceTile
    else
        self.sourceTile = nil
        self.sourceBtn:setImage(nil)
        -- self.sourceBtn:setTitle("Click to Set")
        self.mainEditor.statusMessage = "Source tile cleared"
    end
end

function TileEditorReplacement:onTargetClick()
    local cursor = getCell():getDrag(0)
    if cursor and cursor.choosenSprite then
        self.targetTile = cursor.choosenSprite
        self.targetBtn:setImage(getTexture(self.targetTile))
        getCell():setDrag(nil, 0)
        self.mainEditor.statusMessage = "Target tile set: " .. self.targetTile
    else
        self.targetTile = nil
        self.targetBtn:setImage(nil)
        -- self.targetBtn:setTitle("Click to Set")
        self.mainEditor.statusMessage = "Target tile cleared"
    end
end

function TileEditorReplacement:onSelectionChange(index, selected)
    if selected then
        local types = {"point", "rect", "circle", "box", "ring"}
        self.mainEditor.selection:setType(types[index])
        
        -- Explicitly ensure only this option is selected
        for i = 1, 5 do
            if i ~= index then
                self.selectionTickBox:setSelected(i, false)
            end
        end
    end
end

function TileEditorReplacement:onThicknessSliderChange(value, slider)
    self.mainEditor.thickness = math.floor(value)
    
    -- Update the selection's thickness if we have a ring or box selection
    if self.mainEditor.selection then
        local selectionType = self.mainEditor.selection:getType()
        if selectionType == "ring" then
            self.mainEditor.selection.ringThickness = self.mainEditor.thickness
            self.mainEditor.selection.innerRadius = math.max(0, self.mainEditor.selection.radius - self.mainEditor.thickness)
            self.mainEditor.selection:updateHighlight()
        elseif selectionType == "box" then
            self.mainEditor.selection.boxThickness = self.mainEditor.thickness
            self.mainEditor.selection:updateHighlight()
        end
    end
end

function TileEditorReplacement:onToggleSelectionMode()
    self.mainEditor.selectionModeActive = not self.mainEditor.selectionModeActive
    self:updateSelectModeButton()
    
    if self.mainEditor.selectionModeActive then
        self.mainEditor.statusMessage = "Selection mode active. Click and drag in the world to create a selection."
        TileEditorUtils.debug("Selection mode activated")
    else
        self.mainEditor.statusMessage = "Selection mode deactivated."
        TileEditorUtils.debug("Selection mode deactivated")
    end
end

function TileEditorReplacement:updateSelectModeButton()
    if self.mainEditor.selectionModeActive then
        self.selectModeBtn.backgroundColor = {r=0.2, g=0.8, b=0.2, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.3, g=0.9, b=0.3, a=1.0}
    else
        self.selectModeBtn.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.5, g=0.5, b=0.5, a=1.0}
    end
end

function TileEditorReplacement:onReplace()
    if not self.sourceTile or not self.targetTile then
        self.mainEditor.statusMessage = "Set both Source and Target tiles first!"
        return
    end
    
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Select an area first."
        return
    end
    
    local count = self.mainEditor.actions:replace(self.mainEditor.selection, self.sourceTile, self.targetTile, self.mainEditor.undoManager)
    self.mainEditor:refresh()
    self.mainEditor.statusMessage = "Replaced " .. count .. " tiles."
end

function TileEditorReplacement:prerender()
    ISPanel.prerender(self)
    
    if self.mainEditor and self.mainEditor.lightMode then
        self.sourceBtn.backgroundColor = {r=1, g=1, b=1, a=1.0}
        self.targetBtn.backgroundColor = {r=1, g=1, b=1, a=1.0}
    else
        self.sourceBtn.backgroundColor = {r=0, g=0, b=0, a=1.0}
        self.targetBtn.backgroundColor = {r=0, g=0, b=0, a=1.0}
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
    
    -- Keep select mode button in sync (in case it's changed externally)
    self:updateSelectModeButton()
end

return TileEditorReplacement
