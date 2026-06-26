-- TileEditorBulk.lua
-- Handles the "Bulk" editing mode (current functionality)

require "ISUI/ISPanel"
require "GravyUI_WL"

TileEditorBulk = ISPanel:derive("TileEditorBulk")

function TileEditorBulk:new(x, y, width, height, mainEditor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.preferredHeight = 200 * (mainEditor.scale or 1)
    return o
end

function TileEditorBulk:createChildren()
    ISPanel.createChildren(self)
    
    -- Build UI using GravyUI
    local win = GravyUI.Node(self.width, self.height, self):pad(10, 10, 10, 10)
    
    -- Main layout: 3 columns + Status row at bottom
    local mainContent, statusRow = win:rows({0.9, 0.1}, 5)
    local col1, col2, col3 = mainContent:cols({0.33, 0.33, 0.34}, 10)
    
    self:buildColumn1(col1)
    self:buildColumn2(col2)
    self:buildColumn3(col3)
    self:buildStatusUI(statusRow)
end

function TileEditorBulk:buildColumn1(node)
    -- Col 1: Area Type, Thickness, Select Button
    local label, options, thicknessRow, selectBtn = node:rows({20, 0.7, 0.15, 0.15}, 5)
    
    label:makeLabel("Selection:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.selectionTickBox = options:makeTickBox(self, self.onSelectionChange)
    self.selectionTickBox.onlyOnePossibility = true
    self.selectionTickBox:addOption("Point")
    self.selectionTickBox:addOption("Rect")
    self.selectionTickBox:addOption("Circle")
    self.selectionTickBox:addOption("Box")
    self.selectionTickBox:addOption("Ring")
    self.selectionTickBox.tooltip = "Point: Single tile<LINE>Rect: Filled rectangle<LINE>Circle: Filled circle<LINE>Box: Rectangle border<LINE>Ring: Circle border"
    
    -- Set initial selection
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
    thicknessLabel:makeLabel("Thick:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.thicknessSlider = thicknessSlider:makeSlider(self, self.onThicknessSliderChange)
    self.thicknessSlider:setValues(1, 10, 1, 1, false)
    self.thicknessSlider:setCurrentValue(self.mainEditor.thickness or 1)
    self.thicknessSlider.tooltip = "Thickness for Ring and Box selections"
    
    -- Select Button
    self.selectModeBtn = selectBtn:makeButton("Select Area", self, self.onToggleSelectionMode)
    self.selectModeBtn.tooltip = "Toggle selection mode. When active, click in the world to create selections."
    self:updateSelectModeButton()
end

function TileEditorBulk:buildColumn2(node)
    -- Col 2: Bulk Type, Randomness Selector
    local label, options, sliderRow = node:rows({20, 0.5, 0.2}, 5)
    
    label:makeLabel("Mode:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.modeTickBox = options:makeTickBox(self, self.onModeChange)
    self.modeTickBox.onlyOnePossibility = true
    self.modeTickBox:addOption("Single")
    self.modeTickBox:addOption("Random")
    self.modeTickBox:addOption("Cycle")
    self.modeTickBox.tooltip = "Single: Use first tile in palette<LINE>Random: Use random tiles from palette<LINE>Cycle: Use tiles in order from palette"
    
    -- Set initial mode
    local modeIndex = 1
    if self.mainEditor.mode == "random" then modeIndex = 2
    elseif self.mainEditor.mode == "cycle" then modeIndex = 3
    end
    self.modeTickBox:setSelected(modeIndex, true)
    
    -- Partial Fill Slider
    local sliderLabel, slider, percentLabel = sliderRow:cols({0.25, 0.55, 0.20}, 5)
    sliderLabel:makeLabel("Partial %:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.partialSlider = slider:makeSlider(self, self.onPartialSliderChange)
    self.partialSlider:setValues(0, 100, 1, 10, false)
    self.partialSlider:setCurrentValue(self.mainEditor.partialPercent or 50)
    
    self.percentLabel = percentLabel:makeLabel((self.mainEditor.partialPercent or 50) .. "%", UIFont.Small, {r=1,g=1,b=1,a=1}, "center")
end

function TileEditorBulk:buildColumn3(node)
    -- Col 3: Action Buttons
    local label, buttons = node:rows({20, 1.0}, 5)
    label:makeLabel("Actions:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    local row1, row2, row3, row4 = buttons:rows(4, 5)
    
    self.fillBtn = row1:makeButton("Fill", self, self.onFill)
    self.fillBtn.tooltip = "Fill the entire selection with tiles from the palette."
    
    self.partialFillBtn = row2:makeButton("Partial Fill", self, self.onPartialFill)
    self.partialFillBtn.tooltip = "Fill a random percentage of tiles in the selection."
    
    self.clearFloorBtn = row3:makeButton("Clear Floor", self, self.onClearFloor)
    self.clearFloorBtn.tooltip = "Remove all floor tiles in the selection."
    
    self.clearOtherBtn = row4:makeButton("Clear Other", self, self.onClearOther)
    self.clearOtherBtn.tooltip = "Remove all non-floor tiles in the selection."
end

function TileEditorBulk:buildStatusUI(node)
    self.selectionInfoLabel = node:makeLabel("", UIFont.Small, {r=0.7,g=1,b=0.7,a=1}, "center")
end

-- ============================================================================
-- Event Handlers
-- ============================================================================

function TileEditorBulk:onSelectionChange(index, selected)
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

function TileEditorBulk:onModeChange(index, selected)
    if selected then
        if index == 1 then
            self.mainEditor.mode = "single"
        elseif index == 2 then
            self.mainEditor.mode = "random"
        elseif index == 3 then
            self.mainEditor.mode = "cycle"
            self.mainEditor.cycleIndex = 1  -- Reset cycle index when switching to cycle mode
        end
    end
end

function TileEditorBulk:onThicknessSliderChange(value, slider)
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

function TileEditorBulk:onToggleSelectionMode()
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

function TileEditorBulk:updateSelectModeButton()
    if self.mainEditor.selectionModeActive then
        self.selectModeBtn.backgroundColor = {r=0.2, g=0.8, b=0.2, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.3, g=0.9, b=0.3, a=1.0}
    else
        self.selectModeBtn.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0}
        self.selectModeBtn.backgroundColorMouseOver = {r=0.5, g=0.5, b=0.5, a=1.0}
    end
end

function TileEditorBulk:onPartialSliderChange(value, slider)
    self.mainEditor.partialPercent = math.floor(value)
    if self.percentLabel then
        self.percentLabel:setText(self.mainEditor.partialPercent .. "%")
    end
end

function TileEditorBulk:onClearFloor()
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Click and drag to select an area first."
        return
    end
    
    local count = self.mainEditor.actions:clearFloor(self.mainEditor.selection, self.mainEditor.undoManager)
    self.mainEditor:refresh()
    self.mainEditor.statusMessage = "Cleared " .. count .. " floor tiles"
end

function TileEditorBulk:onClearOther()
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Click and drag to select an area first."
        return
    end
    
    local count = self.mainEditor.actions:clearOther(self.mainEditor.selection, self.mainEditor.undoManager)
    self.mainEditor:refresh()
    self.mainEditor.statusMessage = "Cleared " .. count .. " non-floor tiles"
end

function TileEditorBulk:onFill()
    if self.mainEditor.palettePanel:isEmpty() then
        self.mainEditor.statusMessage = "Palette is empty! Add tiles first."
        return
    end
    
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Click and drag to select an area first."
        return
    end
    
    local count = self.mainEditor.actions:fill(self.mainEditor.selection, self.mainEditor.palettePanel, self.mainEditor.mode, self.mainEditor.undoManager, self.mainEditor.cycleIndex)
    self.mainEditor:refresh()
    
    -- Update cycle index if in cycle mode
    if self.mainEditor.mode == "cycle" then
        local paletteSize = self.mainEditor.palettePanel:getTileCount()
        if paletteSize > 0 then
            self.mainEditor.cycleIndex = ((self.mainEditor.cycleIndex + count - 1) % paletteSize) + 1
        end
    end
    
    self.mainEditor.statusMessage = "Placed " .. count .. " tiles"
end

function TileEditorBulk:onPartialFill()
    if self.mainEditor.palettePanel:isEmpty() then
        self.mainEditor.statusMessage = "Palette is empty! Add tiles first."
        return
    end
    
    if not self.mainEditor.selection:hasSelection() then
        self.mainEditor.statusMessage = "No selection! Click and drag to select an area first."
        return
    end
    
    local count = self.mainEditor.actions:partialFill(self.mainEditor.selection, self.mainEditor.palettePanel, self.mainEditor.mode,
                                          self.mainEditor.partialPercent, self.mainEditor.undoManager, self.mainEditor.cycleIndex)
    self.mainEditor:refresh()
    
    -- Update cycle index if in cycle mode
    if self.mainEditor.mode == "cycle" then
        local paletteSize = self.mainEditor.palettePanel:getTileCount()
        if paletteSize > 0 then
            self.mainEditor.cycleIndex = ((self.mainEditor.cycleIndex + count - 1) % paletteSize) + 1
        end
    end
    
    self.mainEditor.statusMessage = "Placed " .. count .. " tiles (" .. self.mainEditor.partialPercent .. "%)"
end

function TileEditorBulk:prerender()
    ISPanel.prerender(self)
    
    -- Update status labels
    if self.selectionInfoLabel then
        if self.mainEditor.selection:hasSelection() then
            local info = self.mainEditor.selection:getSelectionInfo()
            self.selectionInfoLabel:setText(info)
        else
            self.selectionInfoLabel:setText("")
        end
    end
    
    -- Keep select mode button in sync (in case it's changed externally)
    self:updateSelectModeButton()
end

return TileEditorBulk
