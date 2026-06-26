require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"

---@class WAT_BasementCreator : ISCollapsableWindow
---@field instance WAT_BasementCreator|nil
WAT_BasementCreator = ISCollapsableWindow:derive("WAT_BasementCreator")
WAT_BasementCreator.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
    return px * SCALE
end

--- Shows the Basement Creator window
--- @return WAT_BasementCreator
function WAT_BasementCreator.show()
    if WAT_BasementCreator.instance then
        WAT_BasementCreator.instance:setVisible(true)
        WAT_BasementCreator.instance:requestTemplateList()
        return WAT_BasementCreator.instance
    end

    local w = scale(450)
    local h = scale(450)
    local o = WAT_BasementCreator:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_BasementCreator.instance = o
    o:requestTemplateList()
    return o
end

--- Constructor
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WAT_BasementCreator
function WAT_BasementCreator:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Create New Basement"

    -- Template list from server
    o.templateList = {}
    o.selectedTemplateId = nil
    o.selectedTemplate = nil
    o.selectedTemplateMeta = nil

    -- Global grid configuration (loaded from server)
    o.gridConfig = {
        startX = 10000,
        startY = 10000,
        spacingX = 50,
        spacingY = 50,
        maxX = 20,
        maxY = 20
    }

    -- Basement configuration
    o.basementName = ""
    o.entrancePoint = nil  -- Where player steps to enter basement (house side)
    o.returnPoint = nil    -- Where player appears when leaving basement (house side)

    -- Execution state
    o.executionState = {
        isRunning = false,
        stage = nil,
        stageDelay = 0,
        basementKey = nil,
        basementXY = nil,
        originalPosition = nil
    }

    -- Async state
    o.isWaitingForTemplateData = false

    return o
end

--- Initialize the UI
function WAT_BasementCreator:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local win = GravyUI.Node(self.width, self.height, self):pad(scale(10), scale(30), scale(10), scale(10))
    local stack = win:makeVerticalStack(scale(8))

    -- Name input
    local nameRow = stack:makeNode(scale(25))
    local nameLabel, nameInput = nameRow:cols({0.3, 0.7}, scale(5))
    nameLabel:makeLabel("Name:", UIFont.Small, COLOR_WHITE, "right")
    self.nameTextBox = nameInput:makeTextBox("", false)

    -- Template selector
    local templateRow = stack:makeNode(scale(25))
    local templateLabel, templateSelector = templateRow:cols({0.3, 0.7}, scale(5))
    templateLabel:makeLabel("Template:", UIFont.Small, COLOR_WHITE, "right")
    self.templateSelector = templateSelector:makeComboBox(self, self.onTemplateSelected)
    self.templateSelector:addOption("Select Template...")

    -- House Side Configuration Section
    local houseSideLabel = stack:makeNode(scale(20))
    houseSideLabel:makeLabel("House Side Configuration", UIFont.Medium, COLOR_WHITE, "left")

    -- Entrance Point Picker
    local entranceLabel = stack:makeNode(scale(18))
    entranceLabel:makeLabel("Entrance Point (step here to enter basement):", UIFont.Small, COLOR_WHITE, "left")

    local entrancePickerRow = stack:makeNode(scale(60))
    self.entrancePointPicker = entrancePickerRow:makePointPicker()
    self.entrancePointPicker:setColor(0, 1, 0, 1)
    self.entrancePointPicker:setPriority(3)
    self.entrancePointPicker.showAlways = true
    self.entrancePointPicker:setEndPickingCallback(self.updateCreateButtonState, self)

    local entranceButtonRow = stack:makeNode(scale(25))
    self.setEntranceButton = entranceButtonRow:makeButton("Set to Current Position", self, self.setEntranceToCurrent)

    -- Return Point Picker
    local returnLabel = stack:makeNode(scale(18))
    returnLabel:makeLabel("Return Point (appear here when leaving basement):", UIFont.Small, COLOR_WHITE, "left")

    local returnPickerRow = stack:makeNode(scale(60))
    self.returnPointPicker = returnPickerRow:makePointPicker()
    self.returnPointPicker:setColor(1, 0.5, 0, 1)
    self.returnPointPicker:setPriority(2)
    self.returnPointPicker.showAlways = true
    self.returnPointPicker:setEndPickingCallback(self.updateCreateButtonState, self)

    local returnButtonRow = stack:makeNode(scale(25))
    self.setReturnButton = returnButtonRow:makeButton("Set to Current Position", self, self.setReturnToCurrent)

    -- Status label
    local statusRow = stack:makeNode(scale(25))
    self.statusLabel = statusRow:makeLabel("Status: Ready", UIFont.Small, COLOR_WHITE, "center")

    -- Action buttons
    local actionRow = stack:makeNode(scale(35))
    local createBtn, cancelBtn, closeBtn = actionRow:cols(3, scale(10))
    self.createButton = createBtn:makeButton("Create Basement", self, self.onCreateBasement)
    self.cancelButton = cancelBtn:makeButton("Cancel", self, self.onCancel)
    self.closeButton = closeBtn:makeButton("Close", self, self.close)

    -- Initial state
    self.createButton:setEnable(false)
    self.cancelButton:setEnable(false)
end

--- Requests the template list from the server
function WAT_BasementCreator:requestTemplateList()
    self:setStatus("Requesting templates...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "requestTemplateList", {})
end

--- Called when template list is received from server
--- @param data table Contains templates array and gridConfig
function WAT_BasementCreator:onTemplateListReceived(data)
    self.templateList = data.templates or {}
    self.templateSelector:clear()
    self.templateSelector:addOption("Select Template...")

    for _, template in ipairs(self.templateList) do
        self.templateSelector:addOptionWithData(template.name or "Unnamed", template)
    end

    -- Update grid config if provided
    if data.gridConfig then
        self.gridConfig = data.gridConfig
    end

    self:setStatus("Loaded " .. #self.templateList .. " templates", COLOR_GREEN)
end

--- Called when a template is selected in the dropdown
--- Note: We don't request full template data here - only when execution starts
function WAT_BasementCreator:onTemplateSelected()
    local data = self.templateSelector:getOptionData(self.templateSelector.selected)
    if data and type(data) == "table" then
        self.selectedTemplateId = data.id
        self.selectedTemplateMeta = data  -- Store metadata (name, gridConfig)
        self:setStatus("Template selected: " .. (data.name or "Unnamed"), COLOR_GREEN)
    else
        self.selectedTemplateId = nil
        self.selectedTemplateMeta = nil
    end
    self.selectedTemplate = nil  -- Full template data not loaded yet
    self:updateCreateButtonState()
end

--- Called when full template data is received from server
--- @param data table Contains template, gridConfig or error
function WAT_BasementCreator:onTemplateDataReceived(data)
    self.isWaitingForTemplateData = false

    if data.error then
        self:setStatus("Error: " .. data.error, COLOR_RED)
        self.selectedTemplate = nil
        self.executionState.isRunning = false
        self:resetUIState()
        return
    end

    -- Update grid config if provided
    if data.gridConfig then
        self.gridConfig = data.gridConfig
    end

    self.selectedTemplate = data.template
    self:setStatus("Template loaded, finding grid position...", COLOR_YELLOW)
    
    -- Continue execution now that we have the template
    self.executionState.stage = "FIND_GRID_POSITION"
    self.executionState.stageDelay = 5
end

--- Sets entrance point to player's current position
function WAT_BasementCreator:setEntranceToCurrent()
    local player = getPlayer()
    self.entrancePointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:updateCreateButtonState()
end

--- Sets return point to player's current position
function WAT_BasementCreator:setReturnToCurrent()
    local player = getPlayer()
    self.returnPointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:updateCreateButtonState()
end

--- Updates the Create button enabled state
function WAT_BasementCreator:updateCreateButtonState()
    local entrancePoint = self.entrancePointPicker:getValue()
    local returnPoint = self.returnPointPicker:getValue()

    local hasEntrance = not (entrancePoint.x == 0 and entrancePoint.y == 0 and entrancePoint.z == 0)
    local hasReturn = not (returnPoint.x == 0 and returnPoint.y == 0 and returnPoint.z == 0)
    -- Only need template ID selected, not full data loaded
    local hasTemplate = self.selectedTemplateId ~= nil
    local notRunning = not self.executionState.isRunning

    self.createButton:setEnable(hasEntrance and hasReturn and hasTemplate and notRunning)
end

--- Called when Create Basement button is clicked
function WAT_BasementCreator:onCreateBasement()
    if not self.selectedTemplateId then
        self:setStatus("Error: Select a template first", COLOR_RED)
        return
    end

    local entrancePoint = self.entrancePointPicker:getValue()
    local returnPoint = self.returnPointPicker:getValue()

    if entrancePoint.x == 0 and entrancePoint.y == 0 and entrancePoint.z == 0 then
        self:setStatus("Error: Set entrance point first", COLOR_RED)
        return
    end

    if returnPoint.x == 0 and returnPoint.y == 0 and returnPoint.z == 0 then
        self:setStatus("Error: Set return point first", COLOR_RED)
        return
    end

    -- Store configuration
    self.basementName = self.nameTextBox:getText() or ""
    self.entrancePoint = entrancePoint
    self.returnPoint = returnPoint

    -- Store original position
    local player = getPlayer()
    self.executionState.originalPosition = {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    }

    -- Start execution - first request the full template data
    self.executionState.isRunning = true
    self.executionState.stage = "REQUEST_TEMPLATE"
    self.executionState.stageDelay = 0

    self.createButton:setEnable(false)
    self.cancelButton:setEnable(true)
    self.closeButton:setEnable(false)

    self:setStatus("Starting basement creation...", COLOR_YELLOW)
end

--- Called when Cancel button is clicked
function WAT_BasementCreator:onCancel()
    if self.executionState.isRunning then
        self.executionState.isRunning = false
        self.executionState.stage = nil

        -- Close copy-paste tool if open
        if WAT_CopyPaste and WAT_CopyPaste.instance then
            WAT_CopyPaste.instance:close()
        end

        self:setStatus("Cancelled", COLOR_RED)
    end

    self:resetUIState()
end

--- Resets UI state after execution completes or is cancelled
function WAT_BasementCreator:resetUIState()
    self:updateCreateButtonState()
    self.cancelButton:setEnable(false)
    self.closeButton:setEnable(true)
end

--- Sets the status label text and color
--- @param text string
--- @param color table|nil
function WAT_BasementCreator:setStatus(text, color)
    self.statusLabel:setText("Status: " .. text)
    if color then
        self.statusLabel.textColor = color
    end
end

--- Prerender - handles execution state machine
function WAT_BasementCreator:prerender()
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
function WAT_BasementCreator:processStage()
    local stage = self.executionState.stage

    if stage == "REQUEST_TEMPLATE" then
        self:stageRequestTemplate()
    elseif stage == "FIND_GRID_POSITION" then
        self:stageFindGridPosition()
    elseif stage == "TELEPORT_TO_POSITION" then
        self:stageTeleportToPosition()
    elseif stage == "WAIT_TELEPORT" then
        self:stageWaitTeleport()
    elseif stage == "OPEN_COPYPASTE" then
        self:stageOpenCopyPaste()
    elseif stage == "WAIT_COPYPASTE" then
        self:stageWaitCopyPaste()
    elseif stage == "CLEAR_AREA" then
        self:stageClearArea()
    elseif stage == "WAIT_CLEAR" then
        self:stageWaitClear()
    elseif stage == "PASTE_BASEMENT" then
        self:stagePasteBasement()
    elseif stage == "WAIT_PASTE" then
        self:stageWaitPaste()
    elseif stage == "CREATE_SAFEZONE" then
        self:stageCreateSafezone()
    elseif stage == "SAVE_BASEMENT" then
        self:stageSaveBasement()
    elseif stage == "TELEPORT_BACK" then
        self:stageTeleportBack()
    elseif stage == "COMPLETE" then
        self:stageComplete()
    end
end

--- Stage: Request full template data from server
function WAT_BasementCreator:stageRequestTemplate()
    self.isWaitingForTemplateData = true
    self:setStatus("Requesting template data...", COLOR_YELLOW)
    sendClientCommand(getPlayer(), "WAT", "requestTemplate", {
        templateId = self.selectedTemplateId
    })
    -- Stage will be advanced by onTemplateDataReceived callback
    self.executionState.stage = nil  -- Wait for async response
end

--- Stage: Find next available grid position
function WAT_BasementCreator:stageFindGridPosition()
    -- Use global grid config
    local gridConfig = self.gridConfig
    if not gridConfig then
        self:setStatus("Error: No grid config available", COLOR_RED)
        self.executionState.isRunning = false
        self:resetUIState()
        return
    end

    -- Find next open position in grid using the zone manager
    local key, position = WAT_BasementZoneManager.findNextGridPosition(gridConfig)
    if key and position then
        self.executionState.basementKey = key
        self.executionState.basementXY = position
        self:setStatus("Found position: " .. key, COLOR_YELLOW)
        self.executionState.stage = "TELEPORT_TO_POSITION"
        self.executionState.stageDelay = 5
        return
    end

    self:setStatus("Error: No available grid positions", COLOR_RED)
    self.executionState.isRunning = false
    self:resetUIState()
end

--- Stage: Teleport to grid position
function WAT_BasementCreator:stageTeleportToPosition()
    local pos = self.executionState.basementXY
    WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x - 1, pos.y, 0)
    self:setStatus("Teleporting to basement location...", COLOR_YELLOW)
    self.executionState.stage = "WAIT_TELEPORT"
    self.executionState.stageDelay = 20
end

--- Stage: Wait for teleport to complete
function WAT_BasementCreator:stageWaitTeleport()
    local pos = self.executionState.basementXY
    local square = getCell():getGridSquare(pos.x, pos.y, 0)
    if not square then
        self.executionState.stageDelay = 10
        return
    end

    self.executionState.stage = "OPEN_COPYPASTE"
    self.executionState.stageDelay = 5
end

--- Stage: Open CopyPaste tool
function WAT_BasementCreator:stageOpenCopyPaste()
    if not WAT_CopyPaste then
        self:setStatus("Error: CopyPaste tool not available", COLOR_RED)
        self.executionState.isRunning = false
        self:resetUIState()
        return
    end

    WAT_CopyPaste:display()
    self:setStatus("Loading CopyPaste tool...", COLOR_YELLOW)
    self.executionState.stage = "WAIT_COPYPASTE"
    self.executionState.stageDelay = 50
end

--- Stage: Wait for CopyPaste to load and set up
function WAT_BasementCreator:stageWaitCopyPaste()
    if not WAT_CopyPaste.instance then
        self:setStatus("Error: Failed to load CopyPaste", COLOR_RED)
        self.executionState.isRunning = false
        self:resetUIState()
        return
    end

    -- Load template data into CopyPaste
    local template = self.selectedTemplate
    if template.copyPasteData then
        WAT_CopyPaste.instance.contents = template.copyPasteData
        WAT_CopyPaste.instance.pointSelector:setValue({
            x = self.executionState.basementXY.x,
            y = self.executionState.basementXY.y,
            z = 0
        })
        self.executionState.stage = "CLEAR_AREA"
        self.executionState.stageDelay = 10
    else
        self:setStatus("Error: Template has no tile data", COLOR_RED)
        self.executionState.isRunning = false
        self:resetUIState()
    end
end

--- Stage: Clear the area
function WAT_BasementCreator:stageClearArea()
    self:setStatus("Clearing area...", COLOR_YELLOW)
    WAT_CopyPaste.instance:onClear()
    self.executionState.stage = "WAIT_CLEAR"
    self.executionState.stageDelay = 20
end

--- Stage: Wait for clear to complete
function WAT_BasementCreator:stageWaitClear()
    self.executionState.stage = "PASTE_BASEMENT"
    self.executionState.stageDelay = 5
end

--- Stage: Paste the basement
function WAT_BasementCreator:stagePasteBasement()
    self:setStatus("Pasting basement...", COLOR_YELLOW)
    WAT_CopyPaste.instance:onPaste()
    self.executionState.stage = "WAIT_PASTE"
    self.executionState.stageDelay = 20
end

--- Stage: Wait for paste to complete
function WAT_BasementCreator:stageWaitPaste()
    if WAT_CopyPaste.instance.isActive then
        self:setStatus("Pasting...", COLOR_YELLOW)
        self.executionState.stageDelay = 10
        return
    end

    self.executionState.stage = "CREATE_SAFEZONE"
    self.executionState.stageDelay = 5
end

--- Stage: Create safezone for the basement
function WAT_BasementCreator:stageCreateSafezone()
    local template = self.selectedTemplate
    local pos = self.executionState.basementXY
    local footprint = template.footprintArea or {x1=0, y1=0, z1=0, x2=19, y2=19, z2=0}

    local startX = pos.x
    local startY = pos.y
    local endX = pos.x + footprint.x2
    local endY = pos.y + footprint.y2

    -- Try to use WastelandSafezone if available
    if WSZ_Client and SandboxVars.WastelandSafezone and SandboxVars.WastelandSafezone.OverrideSafehouseClaim then
        local window = WSZ_CreateSafezonePanel:show(getPlayer(), {})
        window.areaPicker:setValue({x1 = startX, y1 = startY, x2 = endX, y2 = endY, z1 = 0, z2 = 7})
        window.nameInput:setText("Basement")
        window:validateSelection()
    else
        -- Use vanilla safezone UI
        if ISAddSafeZoneUI.instance then
            ISAddSafeZoneUI.instance:close()
        end
        local addSafeZoneUI = ISAddSafeZoneUI:new(
            getCore():getScreenWidth() / 2 - 210,
            getCore():getScreenHeight() / 2 - 200,
            420, 400, getPlayer()
        )
        addSafeZoneUI:initialise()
        addSafeZoneUI:addToUIManager()
        addSafeZoneUI.startingX = startX
        addSafeZoneUI.startingY = startY
        addSafeZoneUI.X1 = startX
        addSafeZoneUI.Y1 = startY
        addSafeZoneUI.X2 = endX
        addSafeZoneUI.Y2 = endY
    end

    self:setStatus("Creating safezone...", COLOR_YELLOW)
    self.executionState.stage = "SAVE_BASEMENT"
    self.executionState.stageDelay = 10
end

--- Stage: Save basement data to server
function WAT_BasementCreator:stageSaveBasement()
    local template = self.selectedTemplate
    local pos = self.executionState.basementXY
    local entryOffset = template.basementEntryOffset or {x=10, y=10, z=0}
    local exitOffset = template.basementExitOffset or {x=18, y=18, z=0}

    -- Calculate basement-side teleport points
    local basementEntryX = pos.x + entryOffset.x
    local basementEntryY = pos.y + entryOffset.y
    local basementEntryZ = entryOffset.z

    local basementExitX = pos.x + exitOffset.x
    local basementExitY = pos.y + exitOffset.y
    local basementExitZ = exitOffset.z

    -- Send basement data to server
    sendClientCommand(getPlayer(), "WAT", "finishBasement", {
        key = self.executionState.basementKey,
        name = self.basementName,
        templateId = self.selectedTemplateId,
        -- House entrance (where player steps to go IN)
        outX1 = self.entrancePoint.x,
        outY1 = self.entrancePoint.y,
        outZ1 = self.entrancePoint.z,
        -- Basement arrival (where player appears IN basement)
        inX1 = basementEntryX,
        inY1 = basementEntryY,
        inZ1 = basementEntryZ,
        -- Basement exit (where player steps to go OUT)
        outX2 = basementExitX,
        outY2 = basementExitY,
        outZ2 = basementExitZ,
        -- House arrival (where player appears back in house)
        inX2 = self.returnPoint.x,
        inY2 = self.returnPoint.y,
        inZ2 = self.returnPoint.z
    })

    -- Close CopyPaste
    if WAT_CopyPaste.instance then
        WAT_CopyPaste.instance:close()
    end

    self:setStatus("Saving basement...", COLOR_YELLOW)
    self.executionState.stage = "TELEPORT_BACK"
    self.executionState.stageDelay = 10
end

--- Stage: Teleport back to original position
function WAT_BasementCreator:stageTeleportBack()
    local pos = self.executionState.originalPosition
    if pos then
        WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x, pos.y, pos.z)
    end

    self.executionState.stage = "COMPLETE"
    self.executionState.stageDelay = 10
end

--- Stage: Complete
function WAT_BasementCreator:stageComplete()
    self:setStatus("Basement created successfully!", COLOR_GREEN)
    self.executionState.isRunning = false
    self.executionState.stage = nil
    self:resetUIState()
end

--- Cleans up area pickers
function WAT_BasementCreator:cleanup()
    if self.entrancePointPicker then
        self.entrancePointPicker:cleanup()
    end
    if self.returnPointPicker then
        self.returnPointPicker:cleanup()
    end
end

--- Close the window
function WAT_BasementCreator:close()
    self:cleanup()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_BasementCreator.instance = nil
end

-- Event handlers for server responses
if not WAT_BasementCreator.didBindEvents then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "WAT" then return end

        local instance = WAT_BasementCreator.instance
        if not instance then return end

        if command == "basementTemplateList" then
            instance:onTemplateListReceived(args)
        elseif command == "basementTemplateData" then
            instance:onTemplateDataReceived(args)
        end
    end)
    WAT_BasementCreator.didBindEvents = true
end