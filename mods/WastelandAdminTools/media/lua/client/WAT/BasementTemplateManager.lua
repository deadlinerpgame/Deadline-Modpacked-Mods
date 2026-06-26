require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"

---@class WAT_BasementTemplateManager : ISCollapsableWindow
---@field instance WAT_BasementTemplateManager|nil
WAT_BasementTemplateManager = ISCollapsableWindow:derive("WAT_BasementTemplateManager")
WAT_BasementTemplateManager.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
    return px * SCALE
end

--- Shows the Template Manager window
--- @return WAT_BasementTemplateManager
function WAT_BasementTemplateManager.show()
    if WAT_BasementTemplateManager.instance then
        WAT_BasementTemplateManager.instance:setVisible(true)
        WAT_BasementTemplateManager.instance:requestTemplateList()
        return WAT_BasementTemplateManager.instance
    end

    local w = scale(800)
    local h = scale(500)
    local o = WAT_BasementTemplateManager:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_BasementTemplateManager.instance = o
    o:requestTemplateList()
    return o
end

--- Constructor
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WAT_BasementTemplateManager
function WAT_BasementTemplateManager:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Basement Template Manager"

    -- Template list from server
    o.templateList = {}
    o.selectedTemplateId = nil

    -- Current template being edited
    o.currentTemplate = {
        id = nil,
        name = "",
        copyPasteData = nil,
        footprintArea = nil,
        basementEntryOffset = nil,
        basementExitOffset = nil
    }

    -- Global grid configuration (loaded from server)
    o.gridConfig = {
        startX = 10000,
        startY = 10000,
        spacingX = 50,
        spacingY = 50,
        maxX = 20,
        maxY = 20
    }

    -- Execution state for automated save process
    o.executionState = {
        isRunning = false,
        stage = nil,
        stageDelay = 0,
        originalPosition = nil,
        templateData = nil
    }

    -- Async state
    o.isWaitingForTemplateData = false
    o.pendingTemplateId = nil

    return o
end

--- Initialize the UI
function WAT_BasementTemplateManager:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local win = GravyUI.Node(self.width, self.height, self):pad(scale(10), scale(30), scale(10), scale(10))

    -- Main layout: three columns - left (template list), middle (template editor), right (grid config)
    local leftPanel, middlePanel, rightPanel = win:cols({0.25, 0.45, 0.30}, scale(10))

    -- LEFT PANEL - Template List
    local leftStack = leftPanel:makeVerticalStack(scale(8))

    local listLabel = leftStack:makeNode(scale(20))
    listLabel:makeLabel("Templates", UIFont.Medium, COLOR_WHITE, "left")

    -- Template list box
    local listBoxContainer = leftStack:makeNode(scale(350))
    self.templateListBox = ISScrollingListBox:new(
        listBoxContainer.left, listBoxContainer.top,
        listBoxContainer.width, listBoxContainer.height
    )
    self.templateListBox:initialise()
    self.templateListBox:instantiate()
    self.templateListBox.itemheight = scale(25)
    self.templateListBox.selected = 0
    self.templateListBox.joypadParent = self
    self.templateListBox.font = UIFont.Small
    self.templateListBox.doDrawItem = self.drawTemplateListItem
    self.templateListBox:setOnMouseDownFunction(self, self.onTemplateSelected)
    self:addChild(self.templateListBox)

    -- List buttons
    local listButtonRow = leftStack:makeNode(scale(30))
    local newBtn, refreshBtn = listButtonRow:cols(2, scale(5))
    self.newButton = newBtn:makeButton("New", self, self.onNewTemplate)
    self.refreshButton = refreshBtn:makeButton("Refresh", self, self.requestTemplateList)

    local deleteRow = leftStack:makeNode(scale(30))
    self.deleteButton = deleteRow:makeButton("Delete Selected", self, self.onDeleteTemplate)
    self.deleteButton:setEnable(false)

    -- MIDDLE PANEL - Template Editor
    local middleStack = middlePanel:makeVerticalStack(scale(8))

    local editorLabel = middleStack:makeNode(scale(20))
    editorLabel:makeLabel("Template Configuration", UIFont.Medium, COLOR_WHITE, "left")

    -- Name input
    local nameRow = middleStack:makeNode(scale(25))
    local nameLabel, nameInput = nameRow:cols({0.3, 0.7}, scale(5))
    nameLabel:makeLabel("Name:", UIFont.Small, COLOR_WHITE, "right")
    self.nameTextBox = nameInput:makeTextBox("", false)

    -- Footprint Area Picker
    local footprintLabel = middleStack:makeNode(scale(18))
    footprintLabel:makeLabel("Footprint Area (copy area):", UIFont.Small, COLOR_WHITE, "left")

    local footprintPickerRow = middleStack:makeNode(scale(60))
    self.footprintAreaPicker = footprintPickerRow:makeAreaPicker()
    self.footprintAreaPicker:setColor(1, 1, 0, 1)
    self.footprintAreaPicker:setPriority(5)
    self.footprintAreaPicker.showAlways = true

    -- Entry Point Picker (relative offset)
    local entryLabel = middleStack:makeNode(scale(18))
    entryLabel:makeLabel("Entry Point (where arrives in basement):", UIFont.Small, COLOR_WHITE, "left")

    local entryPickerRow = middleStack:makeNode(scale(60))
    self.entryPointPicker = entryPickerRow:makePointPicker()
    self.entryPointPicker:setColor(0, 1, 0, 1)
    self.entryPointPicker:setPriority(3)
    self.entryPointPicker.showAlways = true

    -- Exit Point Picker (relative offset)
    local exitLabel = middleStack:makeNode(scale(18))
    exitLabel:makeLabel("Exit Point (where to leave basement):", UIFont.Small, COLOR_WHITE, "left")

    local exitPickerRow = middleStack:makeNode(scale(60))
    self.exitPointPicker = exitPickerRow:makePointPicker()
    self.exitPointPicker:setColor(1, 0, 0, 1)
    self.exitPointPicker:setPriority(2)
    self.exitPointPicker.showAlways = true

    -- Status label
    local statusRow = middleStack:makeNode(scale(25))
    self.statusLabel = statusRow:makeLabel("Status: Ready", UIFont.Small, COLOR_WHITE, "center")

    -- Action buttons
    local actionRow = middleStack:makeNode(scale(35))
    local saveBtn, cancelBtn, closeBtn = actionRow:cols(3, scale(10))
    self.saveButton = saveBtn:makeButton("Save Template", self, self.onSaveTemplate)
    self.cancelButton = cancelBtn:makeButton("Cancel", self, self.onCancel)
    self.closeButton = closeBtn:makeButton("Close", self, self.close)

    -- RIGHT PANEL - Grid Configuration Section
    local rightStack = rightPanel:makeVerticalStack(scale(8))

    local gridLabel = rightStack:makeNode(scale(20))
    gridLabel:makeLabel("Grid Configuration", UIFont.Medium, COLOR_WHITE, "left")

    -- Start X/Y
    local startRow = rightStack:makeNode(scale(25))
    local startXLabel, startXInput = startRow:cols({0.35, 0.65}, scale(5))
    startXLabel:makeLabel("Start X:", UIFont.Small, COLOR_WHITE, "right")
    self.startXTextBox = startXInput:makeTextBox("10000", true)

    local startYRow = rightStack:makeNode(scale(25))
    local startYLabel, startYInput = startYRow:cols({0.35, 0.65}, scale(5))
    startYLabel:makeLabel("Start Y:", UIFont.Small, COLOR_WHITE, "right")
    self.startYTextBox = startYInput:makeTextBox("10000", true)

    -- Spacing X/Y
    local spacingXRow = rightStack:makeNode(scale(25))
    local spacingXLabel, spacingXInput = spacingXRow:cols({0.35, 0.65}, scale(5))
    spacingXLabel:makeLabel("Spacing X:", UIFont.Small, COLOR_WHITE, "right")
    self.spacingXTextBox = spacingXInput:makeTextBox("50", true)

    local spacingYRow = rightStack:makeNode(scale(25))
    local spacingYLabel, spacingYInput = spacingYRow:cols({0.35, 0.65}, scale(5))
    spacingYLabel:makeLabel("Spacing Y:", UIFont.Small, COLOR_WHITE, "right")
    self.spacingYTextBox = spacingYInput:makeTextBox("50", true)

    -- Max X/Y
    local maxXRow = rightStack:makeNode(scale(25))
    local maxXLabel, maxXInput = maxXRow:cols({0.35, 0.65}, scale(5))
    maxXLabel:makeLabel("Max X:", UIFont.Small, COLOR_WHITE, "right")
    self.maxXTextBox = maxXInput:makeTextBox("20", true)

    local maxYRow = rightStack:makeNode(scale(25))
    local maxYLabel, maxYInput = maxYRow:cols({0.35, 0.65}, scale(5))
    maxYLabel:makeLabel("Max Y:", UIFont.Small, COLOR_WHITE, "right")
    self.maxYTextBox = maxYInput:makeTextBox("20", true)

    -- Grid Config Save Button
    local gridSaveRow = rightStack:makeNode(scale(35))
    self.saveGridButton = gridSaveRow:makeButton("Save Grid Config", self, self.onSaveGridConfig)

    -- Initial state
    self:updateEditorState(false)
    self.cancelButton:setEnable(false)
end

--- Draws a template list item
--- @param y number
--- @param item table
--- @param alt boolean
function WAT_BasementTemplateManager:drawTemplateListItem(y, item, alt)
    local itemPadY = scale(2)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
    end
    self:drawText(item.text, 10, y + itemPadY, 1, 1, 1, 0.9, self.font)
    return y + self.itemheight
end

--- Updates the editor UI state
--- @param enabled boolean
function WAT_BasementTemplateManager:updateEditorState(enabled)
    local notRunning = not self.executionState.isRunning
    self.nameTextBox:setEditable(enabled and notRunning)
    self.saveButton:setEnable(enabled and notRunning)
    self.deleteButton:setEnable(enabled and notRunning and self.selectedTemplateId ~= nil)
    self.cancelButton:setEnable(self.executionState.isRunning)
    
    -- Grid config fields are always editable (independent of template editing)
    self.startXTextBox:setEditable(notRunning)
    self.startYTextBox:setEditable(notRunning)
    self.spacingXTextBox:setEditable(notRunning)
    self.spacingYTextBox:setEditable(notRunning)
    self.maxXTextBox:setEditable(notRunning)
    self.maxYTextBox:setEditable(notRunning)
    self.saveGridButton:setEnable(notRunning)
end

--- Requests the template list from the server
function WAT_BasementTemplateManager:requestTemplateList()
    self:setStatus("Requesting template list...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "requestTemplateList", {})
end

--- Called when template list is received from server
--- @param data table Contains templates array and gridConfig
function WAT_BasementTemplateManager:onTemplateListReceived(data)
    self.templateList = data.templates or {}
    self.templateListBox:clear()

    for _, template in ipairs(self.templateList) do
        self.templateListBox:addItem(template.name or "Unnamed", template)
    end

    -- Update grid config if provided
    if data.gridConfig then
        self.gridConfig = data.gridConfig
        self:updateGridConfigUI()
    end

    self:setStatus("Loaded " .. #self.templateList .. " templates", COLOR_GREEN)
end

--- Called when a template is selected in the list
function WAT_BasementTemplateManager:onTemplateSelected()
    local selected = self.templateListBox.items[self.templateListBox.selected]
    if not selected then
        self.selectedTemplateId = nil
        self:updateEditorState(false)
        return
    end

    local templateMeta = selected.item
    self.selectedTemplateId = templateMeta.id
    self.pendingTemplateId = templateMeta.id
    self.isWaitingForTemplateData = true

    self:setStatus("Loading template data...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "requestTemplate", {
        templateId = templateMeta.id
    })
end

--- Called when full template data is received from server
--- @param data table Contains template, gridConfig or error
function WAT_BasementTemplateManager:onTemplateDataReceived(data)
    self.isWaitingForTemplateData = false

    if data.error then
        self:setStatus("Error: " .. data.error, COLOR_RED)
        return
    end

    local template = data.template
    if not template then
        self:setStatus("Error: No template data received", COLOR_RED)
        return
    end

    -- Update grid config if provided
    if data.gridConfig then
        self.gridConfig = data.gridConfig
        self:updateGridConfigUI()
    end

    -- Populate editor with template data
    self.currentTemplate = template
    self.nameTextBox:setText(template.name or "")

    -- Set footprint area
    if template.footprintArea then
        self.footprintAreaPicker:setValue(template.footprintArea)
    end

    -- Set entry point
    if template.basementEntryOffset then
        self.entryPointPicker:setValue(template.basementEntryOffset)
    end

    -- Set exit point
    if template.basementExitOffset then
        self.exitPointPicker:setValue(template.basementExitOffset)
    end

    self:updateEditorState(true)
    self:setStatus("Template loaded: " .. (template.name or "Unnamed"), COLOR_GREEN)
end

--- Called when New Template button is clicked
function WAT_BasementTemplateManager:onNewTemplate()
    self.selectedTemplateId = nil
    self.templateListBox.selected = 0

    -- Reset editor to defaults
    self.currentTemplate = {
        id = nil,
        name = "",
        copyPasteData = nil,
        footprintArea = nil,
        basementEntryOffset = nil,
        basementExitOffset = nil
    }

    self.nameTextBox:setText("")
    self.footprintAreaPicker:setValue({x1 = 0, y1 = 0, z1 = 0, x2 = 0, y2 = 0, z2 = 0})
    self.entryPointPicker:setValue({x = 0, y = 0, z = 0})
    self.exitPointPicker:setValue({x = 0, y = 0, z = 0})

    self:updateEditorState(true)
    self.deleteButton:setEnable(false)
    self:setStatus("Creating new template", COLOR_YELLOW)
end

--- Called when Delete Template button is clicked
function WAT_BasementTemplateManager:onDeleteTemplate()
    if not self.selectedTemplateId then
        return
    end

    local modal = ISModalDialog:new(0, 0, 300, 150,
        "Are you sure you want to delete this template?",
        true, self, self.onDeleteConfirm)
    modal:initialise()
    modal:addToUIManager()
end

--- Called when delete confirmation is received
--- @param button table
function WAT_BasementTemplateManager:onDeleteConfirm(button)
    if button.internal == "YES" then
        self:setStatus("Deleting template...", COLOR_YELLOW)
        sendClientCommand(getPlayer(), "WAT", "deleteBasementTemplate", {
            id = self.selectedTemplateId
        })
    end
end

--- Called when template is deleted on server
--- @param data table Contains id or error
function WAT_BasementTemplateManager:onTemplateDeleted(data)
    if data.error then
        self:setStatus("Error: " .. data.error, COLOR_RED)
        return
    end

    self:setStatus("Template deleted", COLOR_GREEN)
    self.selectedTemplateId = nil
    self:onNewTemplate()
    self:requestTemplateList()
end

--- Called when Cancel button is clicked
function WAT_BasementTemplateManager:onCancel()
    if self.executionState.isRunning then
        self.executionState.isRunning = false
        self.executionState.stage = nil

        -- Close copy-paste tool if open
        if WAT_CopyPaste and WAT_CopyPaste.instance then
            WAT_CopyPaste.instance:close()
        end

        -- Teleport back if we moved
        if self.executionState.originalPosition then
            local pos = self.executionState.originalPosition
            WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x, pos.y, pos.z)
            self.executionState.originalPosition = nil
        end

        self:setStatus("Cancelled", COLOR_RED)
    end

    self:updateEditorState(true)
end

--- Called when Save Template button is clicked
function WAT_BasementTemplateManager:onSaveTemplate()
    local name = self.nameTextBox:getText()
    if not name or name == "" then
        self:setStatus("Error: Template name is required", COLOR_RED)
        return
    end

    local footprint = self.footprintAreaPicker:getValue()
    if footprint.x1 == 0 and footprint.y1 == 0 and footprint.x2 == 0 and footprint.y2 == 0 then
        self:setStatus("Error: Set footprint area first", COLOR_RED)
        return
    end

    local entryPoint = self.entryPointPicker:getValue()
    local exitPoint = self.exitPointPicker:getValue()

    -- Calculate relative offsets from footprint origin
    local basementEntryOffset = {
        x = entryPoint.x - footprint.x1,
        y = entryPoint.y - footprint.y1,
        z = entryPoint.z - footprint.z1
    }

    local basementExitOffset = {
        x = exitPoint.x - footprint.x1,
        y = exitPoint.y - footprint.y1,
        z = exitPoint.z - footprint.z1
    }

    -- Build template data (without copyPasteData yet - will be captured during automation)
    local templateData = {
        id = self.selectedTemplateId or getRandomUUID(),
        name = name,
        copyPasteData = nil,  -- Will be filled during automation
        footprintArea = {
            x1 = 0, y1 = 0, z1 = 0,
            x2 = footprint.x2 - footprint.x1,
            y2 = footprint.y2 - footprint.y1,
            z2 = footprint.z2 - footprint.z1
        },
        basementEntryOffset = basementEntryOffset,
        basementExitOffset = basementExitOffset
    }

    -- Store template data and footprint for automation
    self.executionState.templateData = templateData
    self.executionState.footprint = footprint

    -- Store original position
    local player = getPlayer()
    self.executionState.originalPosition = {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    }

    -- Start automated save process
    self.executionState.isRunning = true
    self.executionState.stage = "TELEPORT_TO_TEMPLATE"
    self.executionState.stageDelay = 0

    self:updateEditorState(true)
    self:setStatus("Starting automated save process...", COLOR_YELLOW)
end

--- Called when template is added/updated on server
--- @param data table Contains id, name or error
function WAT_BasementTemplateManager:onTemplateAdded(data)
    if data.error then
        self:setStatus("Error: " .. data.error, COLOR_RED)
        return
    end

    self:setStatus("Template saved: " .. (data.name or ""), COLOR_GREEN)
    self.selectedTemplateId = data.id
    self:requestTemplateList()
end

--- Sets the status label text and color
--- @param text string
--- @param color table|nil
function WAT_BasementTemplateManager:setStatus(text, color)
    self.statusLabel:setText("Status: " .. text)
    if color then
        self.statusLabel.textColor = color
    end
end

--- Updates the grid config UI fields from current gridConfig
function WAT_BasementTemplateManager:updateGridConfigUI()
    self.startXTextBox:setText(tostring(self.gridConfig.startX or 10000))
    self.startYTextBox:setText(tostring(self.gridConfig.startY or 10000))
    self.spacingXTextBox:setText(tostring(self.gridConfig.spacingX or 50))
    self.spacingYTextBox:setText(tostring(self.gridConfig.spacingY or 50))
    self.maxXTextBox:setText(tostring(self.gridConfig.maxX or 20))
    self.maxYTextBox:setText(tostring(self.gridConfig.maxY or 20))
end

--- Called when grid config is updated on server
--- @param data table Contains gridConfig
function WAT_BasementTemplateManager:onGridConfigUpdated(data)
    if data.gridConfig then
        self.gridConfig = data.gridConfig
        self:updateGridConfigUI()
        self:setStatus("Grid config saved", COLOR_GREEN)
    end
end

--- Called when Save Grid Config button is clicked
function WAT_BasementTemplateManager:onSaveGridConfig()
    local gridConfigData = {
        startX = tonumber(self.startXTextBox:getText()) or 10000,
        startY = tonumber(self.startYTextBox:getText()) or 10000,
        spacingX = tonumber(self.spacingXTextBox:getText()) or 50,
        spacingY = tonumber(self.spacingYTextBox:getText()) or 50,
        maxX = tonumber(self.maxXTextBox:getText()) or 20,
        maxY = tonumber(self.maxYTextBox:getText()) or 20
    }

    self:setStatus("Saving grid config...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "updateGridConfig", gridConfigData)
end

--- Prerender - handles execution state machine
function WAT_BasementTemplateManager:prerender()
    ISCollapsableWindow.prerender(self)

    -- Handle stage delay
    if self.executionState.stageDelay > 0 then
        self.executionState.stageDelay = self.executionState.stageDelay - 1
        return
    end

    -- Process current stage
    if self.executionState.isRunning and self.executionState.stage then
        self:processStage()
    end
end

--- Processes the current execution stage
function WAT_BasementTemplateManager:processStage()
    local stage = self.executionState.stage

    if stage == "TELEPORT_TO_TEMPLATE" then
        self:stageTeleportToTemplate()
    elseif stage == "WAIT_TELEPORT" then
        self:stageWaitTeleport()
    elseif stage == "OPEN_COPYPASTE" then
        self:stageOpenCopyPaste()
    elseif stage == "WAIT_COPYPASTE" then
        self:stageWaitCopyPaste()
    elseif stage == "COPY_TILES" then
        self:stageCopyTiles()
    elseif stage == "WAIT_COPY" then
        self:stageWaitCopy()
    elseif stage == "GRAB_DATA" then
        self:stageGrabData()
    elseif stage == "CLOSE_COPYPASTE" then
        self:stageCloseCopyPaste()
    elseif stage == "SAVE_TO_SERVER" then
        self:stageSaveToServer()
    elseif stage == "TELEPORT_BACK" then
        self:stageTeleportBack()
    elseif stage == "COMPLETE" then
        self:stageComplete()
    end
end

--- Stage: Teleport to template area
function WAT_BasementTemplateManager:stageTeleportToTemplate()
    local footprint = self.executionState.footprint
    WL_Utils.teleportPlayerToCoords(getPlayer(), footprint.x1, footprint.y1, footprint.z1)
    self:setStatus("Teleporting to template area...", COLOR_YELLOW)
    self.executionState.stage = "WAIT_TELEPORT"
    self.executionState.stageDelay = 20
end

--- Stage: Wait for teleport to complete
function WAT_BasementTemplateManager:stageWaitTeleport()
    local footprint = self.executionState.footprint
    local square = getCell():getGridSquare(footprint.x1, footprint.y1, footprint.z1)
    if not square then
        self.executionState.stageDelay = 10
        return
    end

    self.executionState.stage = "OPEN_COPYPASTE"
    self.executionState.stageDelay = 5
end

--- Stage: Open CopyPaste tool
function WAT_BasementTemplateManager:stageOpenCopyPaste()
    if not WAT_CopyPaste then
        self:setStatus("Error: CopyPaste tool not available", COLOR_RED)
        self.executionState.isRunning = false
        self:updateEditorState(true)
        return
    end

    WAT_CopyPaste:display()
    self:setStatus("Opening CopyPaste tool...", COLOR_YELLOW)
    self.executionState.stage = "WAIT_COPYPASTE"
    self.executionState.stageDelay = 50
end

--- Stage: Wait for CopyPaste to load
function WAT_BasementTemplateManager:stageWaitCopyPaste()
    if not WAT_CopyPaste.instance then
        self:setStatus("Error: Failed to load CopyPaste", COLOR_RED)
        self.executionState.isRunning = false
        self:updateEditorState(true)
        return
    end

    self.executionState.stage = "COPY_TILES"
    self.executionState.stageDelay = 10
end

--- Stage: Copy tiles
function WAT_BasementTemplateManager:stageCopyTiles()
    local footprint = self.executionState.footprint
    WAT_CopyPaste.instance.areaSelector:setValue(footprint)
    WAT_CopyPaste.instance:onCopy()
    self:setStatus("Copying tiles...", COLOR_YELLOW)
    self.executionState.stage = "WAIT_COPY"
    self.executionState.stageDelay = 20
end

--- Stage: Wait for copy to complete
function WAT_BasementTemplateManager:stageWaitCopy()
    if WAT_CopyPaste.instance.isActive then
        self:setStatus("Copying...", COLOR_YELLOW)
        self.executionState.stageDelay = 10
        return
    end

    self.executionState.stage = "GRAB_DATA"
    self.executionState.stageDelay = 5
end

--- Stage: Grab data from CopyPaste
function WAT_BasementTemplateManager:stageGrabData()
    if WAT_CopyPaste.instance and WAT_CopyPaste.instance.contents then
        self.executionState.templateData.copyPasteData = WAT_CopyPaste.instance.contents
        self:setStatus("Tile data captured", COLOR_GREEN)
        self.executionState.stage = "CLOSE_COPYPASTE"
        self.executionState.stageDelay = 5
    else
        self:setStatus("Error: No tile data available", COLOR_RED)
        self.executionState.isRunning = false
        self:updateEditorState(true)
    end
end

--- Stage: Close CopyPaste window
function WAT_BasementTemplateManager:stageCloseCopyPaste()
    if WAT_CopyPaste.instance then
        WAT_CopyPaste.instance:close()
    end
    self.executionState.stage = "SAVE_TO_SERVER"
    self.executionState.stageDelay = 10
end

--- Stage: Save to server
function WAT_BasementTemplateManager:stageSaveToServer()
    self:setStatus("Saving template...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "addBasementTemplate", self.executionState.templateData)
    
    self.executionState.stage = "TELEPORT_BACK"
    self.executionState.stageDelay = 10
end

--- Stage: Teleport back to original position
function WAT_BasementTemplateManager:stageTeleportBack()
    local pos = self.executionState.originalPosition
    if pos then
        WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x, pos.y, pos.z)
    end

    self.executionState.stage = "COMPLETE"
    self.executionState.stageDelay = 10
end

--- Stage: Complete
function WAT_BasementTemplateManager:stageComplete()
    self:setStatus("Template saved successfully!", COLOR_GREEN)
    self.executionState.isRunning = false
    self.executionState.stage = nil
    self.executionState.originalPosition = nil
    self.executionState.templateData = nil
    self.executionState.footprint = nil
    self:updateEditorState(true)
end

--- Cleans up area pickers
function WAT_BasementTemplateManager:cleanup()
    if self.footprintAreaPicker then
        self.footprintAreaPicker:cleanup()
    end
    if self.entryPointPicker then
        self.entryPointPicker:cleanup()
    end
    if self.exitPointPicker then
        self.exitPointPicker:cleanup()
    end
end

--- Close the window
function WAT_BasementTemplateManager:close()
    self:cleanup()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_BasementTemplateManager.instance = nil
end

-- Event handlers for server responses
if not WAT_BasementTemplateManager.didBindEvents then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "WAT" then return end

        local instance = WAT_BasementTemplateManager.instance
        if not instance then return end

        if command == "basementTemplateList" then
            instance:onTemplateListReceived(args)
        elseif command == "basementTemplateData" then
            instance:onTemplateDataReceived(args)
        elseif command == "basementTemplateAdded" then
            instance:onTemplateAdded(args)
        elseif command == "basementTemplateDeleted" then
            instance:onTemplateDeleted(args)
        elseif command == "gridConfigUpdated" then
            instance:onGridConfigUpdated(args)
        end
    end)
    WAT_BasementTemplateManager.didBindEvents = true
end