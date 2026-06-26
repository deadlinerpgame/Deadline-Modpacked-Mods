---
--- ManageAttractor.lua
--- Create/Edit UI for zombie attractors
---

WLZA_ManageAttractor = ISPanel:derive("WLZA_ManageAttractor")

-- Container/show
function WLZA_ManageAttractor:show(player, attractor)
    if WLZA_ManageAttractor.instance then
        WLZA_ManageAttractor.instance:onClose()
    end
    local w = math.floor(WLZA_UI_Constants.scale(500))
    local h = math.floor(WLZA_UI_Constants.scale(300))
    local x = math.floor((getCore():getScreenWidth() - w) / 2)
    local y = math.floor((getCore():getScreenHeight() - h) / 2)
    local ui = WLZA_ManageAttractor:new(x, y, w, h, player, attractor)
    ui:initialise()
    ui:addToUIManager()
    WLZA_ManageAttractor.instance = ui
    return ui
end

function WLZA_ManageAttractor:new(x, y, width, height, player, attractor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.attractor = attractor
    o.isNewAttractor = (attractor == nil)
    o.highlighters = {}  -- Track all highlighter instances for cleanup
    o.previousHighlighterData = nil  -- Track previous state for change detection
    o.anchorTop = true
    o.anchorBottom = true
    o.anchorLeft = true
    o.anchorRight = true
    o.resizable = false
    o.moveWithMouse = true
    return o
end

-- ==============================================
-- Highlighter Management
-- ==============================================

--- Extract only highlighter-relevant data for change detection
--- Returns a serialized string representation of the relevant data
function WLZA_ManageAttractor:getHighlighterRelevantData()
    local data = self:collectData()
    if not data then return "" end
    
    local relevant = {}
    
    -- Position
    if data.position then
        relevant.posX = data.position.x or 0
        relevant.posY = data.position.y or 0
        relevant.posZ = data.position.z or 0
    end
    
    -- Ranges
    relevant.minRange = data.minRange or 0
    relevant.maxRange = data.maxRange or 0
    
    -- Serialize to string for comparison
    local parts = {}
    for k, v in pairs(relevant) do
        table.insert(parts, k .. "=" .. tostring(v))
    end
    table.sort(parts)  -- Ensure consistent ordering
    return table.concat(parts, "|")
end

--- Create and configure all highlighters based on current attractor data
function WLZA_ManageAttractor:createHighlighters()
    -- Clear any existing highlighters first
    self:clearHighlighters()
    
    -- Get current attractor data from UI
    local data = self:collectData()
    if not data or not data.position then
        return
    end
    
    local pos = data.position
    
    -- Priority scheme (lower = higher priority):
    -- 0 = Attractor position (green) - highest priority
    -- 1 = Min range (yellow)
    -- 2 = Max range (orange)
    -- 3 = Cardinal lines (red) connecting min to max range - lowest priority
    
    -- 1. Attractor Position (Green) - Priority 0
    local attractorPosHL = GroundHighlighter:new()
    local c = WLZA_UI_Constants.COLOR_ATTRACTOR_POINT
    attractorPosHL:setColor(c.r, c.g, c.b, c.a)
    attractorPosHL:setPriority(0)
    attractorPosHL:enableXray(true)
    attractorPosHL:highlightSquare(pos.x, pos.y, pos.x, pos.y, pos.z)
    table.insert(self.highlighters, attractorPosHL)
    
    -- 2. Min Range Circle (Yellow) - Priority 1
    if data.minRange and data.minRange > 0 then
        local minRangeHL = GroundHighlighter:new()
        c = WLZA_UI_Constants.COLOR_MIN_RANGE
        minRangeHL:setColor(c.r, c.g, c.b, c.a)
        minRangeHL:setPriority(1)
        minRangeHL:enableXray(true)
        minRangeHL:highlightRing(pos.x, pos.y, data.minRange, 1, pos.z)
        table.insert(self.highlighters, minRangeHL)
    end
    
    -- 3. Max Range Circle (Orange) - Priority 2
    if data.maxRange and data.maxRange > 0 and data.maxRange < 100 then
        local maxRangeHL = GroundHighlighter:new()
        c = WLZA_UI_Constants.COLOR_MAX_RANGE
        maxRangeHL:setColor(c.r, c.g, c.b, c.a)
        maxRangeHL:setPriority(2)
        maxRangeHL:enableXray(true)
        maxRangeHL:highlightRing(pos.x, pos.y, data.maxRange, 1, pos.z)
        table.insert(self.highlighters, maxRangeHL)
    end
    
    -- 4. Cardinal Lines connecting min range to max range - Priority 3
    if data.maxRange and data.maxRange > 0 then
        -- Use a color between min and max range colors for the lines
        c = WLZA_UI_Constants.COLOR_INSIDE_RANGE  -- Using min range color for the lines
        
        -- North line (positive Y direction)
        local northLineHL = GroundHighlighter:new()
        northLineHL:setColor(c.r, c.g, c.b, c.a)
        northLineHL:setPriority(3)
        northLineHL:enableXray(true)
        northLineHL:highlightLine(pos.x, pos.y + data.minRange, pos.z, pos.x, pos.y + math.min(100, data.maxRange), pos.z, 1)
        table.insert(self.highlighters, northLineHL)
        
        -- South line (negative Y direction)
        local southLineHL = GroundHighlighter:new()
        southLineHL:setColor(c.r, c.g, c.b, c.a)
        southLineHL:setPriority(3)
        southLineHL:enableXray(true)
        southLineHL:highlightLine(pos.x, pos.y - data.minRange, pos.z, pos.x, pos.y - math.min(100, data.maxRange), pos.z, 1)
        table.insert(self.highlighters, southLineHL)
        
        -- East line (positive X direction)
        local eastLineHL = GroundHighlighter:new()
        eastLineHL:setColor(c.r, c.g, c.b, c.a)
        eastLineHL:setPriority(3)
        eastLineHL:enableXray(true)
        eastLineHL:highlightLine(pos.x + data.minRange, pos.y, pos.z, pos.x + math.min(100, data.maxRange), pos.y, pos.z, 1)
        table.insert(self.highlighters, eastLineHL)
        
        -- West line (negative X direction)
        local westLineHL = GroundHighlighter:new()
        westLineHL:setColor(c.r, c.g, c.b, c.a)
        westLineHL:setPriority(3)
        westLineHL:enableXray(true)
        westLineHL:highlightLine(pos.x - data.minRange, pos.y, pos.z, pos.x - math.min(100, data.maxRange), pos.y, pos.z, 1)
        table.insert(self.highlighters, westLineHL)
    end
end

--- Clear all highlighters (called before creating new ones or on window close)
function WLZA_ManageAttractor:clearHighlighters()
    for _, hl in ipairs(self.highlighters) do
        if hl then
            hl:remove()
        end
    end
    self.highlighters = {}
end

-- ==============================================
-- Main Panel Lifecycle
-- ==============================================
function WLZA_ManageAttractor:initialise()
    ISPanel.initialise(self)
    
    -- Styling
    self.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
    self.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    self.moveWithMouse = true
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(WLZA_UI_Constants.scale(5), WLZA_UI_Constants.scale(5), WLZA_UI_Constants.scale(5), WLZA_UI_Constants.scale(5))
    
    local rowPadding = WLZA_UI_Constants.scale(5)
    
    -- Header with title and buttons
    local headerHeight = WLZA_UI_Constants.FONT_HGT_LARGE + WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(10)
    self.headerHeight = headerHeight
    local headerArea, bodyArea = win:rows({ headerHeight, self.height - headerHeight - WLZA_UI_Constants.scale(10) }, rowPadding)
    
    -- Header layout: buttons on right, title/subtitle on left
    local headerButtonWidth = WLZA_UI_Constants.scale(180)
    local titleArea, buttonArea = headerArea:cols({ self.width - headerButtonWidth - WLZA_UI_Constants.scale(20), headerButtonWidth }, WLZA_UI_Constants.scale(10))
    
    -- Title and subtitle
    local titleRow, subTitleRow = titleArea:rows({ WLZA_UI_Constants.FONT_HGT_LARGE, WLZA_UI_Constants.FONT_HGT_MEDIUM }, WLZA_UI_Constants.scale(3))
    self.titleLabel = titleRow:makeLabel("", UIFont.Large, WLZA_UI_Constants.COLOR_WHITE, "left")
    self.subtitleLabel = subTitleRow:makeLabel("", UIFont.Medium, WLZA_UI_Constants.COLOR_WHITE, "left")
    
    -- Header buttons (Save/Delete/Close stacked vertically) - aligned to exact header height
    local deleteCloseRow, saveRow = buttonArea:rows({ WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(6), WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(6) }, WLZA_UI_Constants.scale(3))
    
    -- Save and Delete buttons (side by side)
    local deleteCol, closeCol = deleteCloseRow:cols({ 0.5, 0.5 }, WLZA_UI_Constants.scale(5))
    self.deleteButton = deleteCol:makeButton("Delete", self, self.onDelete)
    self.closeButton = closeCol:makeButton("Close", self, self.onClose)
    self.deleteButton:setVisible(not self.isNewAttractor)
    
    -- Close button
    self.saveButton = saveRow:makeButton("Save", self, self.onSave)
    
    -- Body content
    local vstack = bodyArea:makeVerticalStack(WLZA_UI_Constants.scale(8))
    
    -- Name
    local nameRow = vstack:makeNode(WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(8))
    local nameLabel, nameField = nameRow:cols({ 0.3, 0.7 }, WLZA_UI_Constants.scale(10))
    nameLabel:makeLabel("Name:", UIFont.Small, WLZA_UI_Constants.COLOR_WHITE, "left")
    self.nameInput = nameField:makeTextBox("", false)
    
    -- Store reference to disable editing for existing attractors
    self.nameInput.isNewAttractor = self.isNewAttractor
    
    -- Position - 2x normal row height for point picker
    local posRow = vstack:makeNode((WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(8)) * 2 + WLZA_UI_Constants.scale(5))
    local posLabel, posField = posRow:cols({ 0.3, 0.7 }, WLZA_UI_Constants.scale(10))
    posLabel:makeLabel("Position:", UIFont.Small, WLZA_UI_Constants.COLOR_WHITE, "left")
    self.positionPicker = posField:makePointPicker()
    
    -- Range (combined on one row)
    local rangeRow = vstack:makeNode(WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(8))
    local rangeLabel, rangeFields = rangeRow:cols({ 0.3, 0.7 }, WLZA_UI_Constants.scale(10))
    rangeLabel:makeLabel("Range:", UIFont.Small, WLZA_UI_Constants.COLOR_WHITE, "left")
    
    -- Split range fields into: minInput, "to" label, maxInput
    local minCol, toCol, maxCol = rangeFields:cols({ 0.35, 0.15, 0.35 }, WLZA_UI_Constants.scale(10))
    self.minRangeInput = minCol:makeTextBox("5", true)
    toCol:makeLabel("to", UIFont.Small, WLZA_UI_Constants.COLOR_WHITE, "center")
    self.maxRangeInput = maxCol:makeTextBox("50", true)
    
    -- Interval
    local intervalRow = vstack:makeNode(WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(8))
    local intervalLabel, intervalField = intervalRow:cols({ 0.3, 0.7 }, WLZA_UI_Constants.scale(10))
    intervalLabel:makeLabel("Interval (sec):", UIFont.Small, WLZA_UI_Constants.COLOR_WHITE, "left")
    self.intervalInput = intervalField:makeTextBox("10", true)
    
    self:updateState()
    
    -- Create highlighters after UI is set up
    self:createHighlighters()
end

function WLZA_ManageAttractor:updateState()
    if self.isNewAttractor then
        self.titleLabel:setText("Create New Attractor")
        self.subtitleLabel:setText("Configure attractor settings")
        
        -- Set default position to player location
        local player = getPlayer()
        if player then
            self.positionPicker:setValue({ x = player:getX(), y = player:getY(), z = player:getZ() })
        end
    else
        self.titleLabel:setText("Edit Attractor")
        self.subtitleLabel:setText(self.attractor and self.attractor.name or "Unknown")
        
        -- Load existing attractor data
        if self.attractor then
            -- Extract name from ID (format: "username: name")
            local colonPos = string.find(self.attractor.id, ": ")
            if colonPos then
                self.nameInput:setText(string.sub(self.attractor.id, colonPos + 2))
            else
                self.nameInput:setText(self.attractor.name or "")
            end
            
            if self.attractor.position then
                self.positionPicker:setValue(self.attractor.position)
            end
            
            self.minRangeInput:setText(tostring(self.attractor.minRange or 5))
            self.maxRangeInput:setText(tostring(self.attractor.maxRange or 50))
            self.intervalInput:setText(tostring(self.attractor.interval or 10))
            
            -- Disable name editing for existing attractors
            self.nameInput:setEditable(false)
        end
    end
end

function WLZA_ManageAttractor:validateData(data)
    -- Check required fields
    if not data.name or data.name == "" then
        WL_Dialogs.showMessageDialog("Attractor Name is required")
        return false
    end
    
    -- Check for uniqueness (only for new attractors or if name changed)
    if self.isNewAttractor or (self.attractor and self.attractor.id ~= data.id) then
        local allAttractors = WLZA_Client:getAllAttractors()
        for _, existingAttractor in ipairs(allAttractors) do
            if existingAttractor.id == data.id then
                WL_Dialogs.showMessageDialog("An attractor with this name already exists. Please choose a different name.")
                return false
            end
        end
    end
    
    if not data.position or not data.position.x or not data.position.y or not data.position.z then
        WL_Dialogs.showMessageDialog("Position is required")
        return false
    end
    
    if not data.minRange or data.minRange < 0 then
        WL_Dialogs.showMessageDialog("Min range must be >= 0")
        return false
    end
    
    if not data.maxRange or data.maxRange <= 0 then
        WL_Dialogs.showMessageDialog("Max range must be > 0")
        return false
    end
    
    if data.minRange >= data.maxRange then
        WL_Dialogs.showMessageDialog("Min range must be less than max range")
        return false
    end
    
    if not data.interval or data.interval <= 0 then
        WL_Dialogs.showMessageDialog("Interval must be > 0")
        return false
    end
    
    return true
end

function WLZA_ManageAttractor:collectData()
    local data = {}
    
    -- Get name and create ID
    data.name = self.nameInput:getText()
    local username = self.player:getUsername()
    data.id = username .. ": " .. data.name
    data.owner = username
    
    -- Get position
    data.position = self.positionPicker:getValue()
    
    -- Get ranges
    data.minRange = tonumber(self.minRangeInput:getText()) or 5
    data.maxRange = tonumber(self.maxRangeInput:getText()) or 50
    
    -- Get interval
    data.interval = tonumber(self.intervalInput:getText()) or 10
    
    -- Set enabled state (always true for new attractors, preserve for existing)
    if self.isNewAttractor then
        data.enabled = true
    else
        data.enabled = self.attractor.enabled or true
    end
    
    -- Set creation time (only for new attractors)
    if self.isNewAttractor then
        data.createdAt = getGameTime():getWorldAgeHours()
    else
        data.createdAt = self.attractor.createdAt or getGameTime():getWorldAgeHours()
    end
    
    return data
end

function WLZA_ManageAttractor:onSave()
    local data = self:collectData()
    
    if not self:validateData(data) then
        return
    end
    
    -- Send to server
    sendClientCommand(self.player, "WLZA", "AddAttractor", { attractor = data })
    
    print("[WLZA] Saved attractor: " .. data.id)
    
    self:onClose()
end

function WLZA_ManageAttractor:onDelete()
    if self.isNewAttractor then
        self:onClose()
        return
    end
    
    local attractorId = self.attractor and self.attractor.id
    if not attractorId then
        self:onClose()
        return
    end
    
    WL_Dialogs.showConfirmationDialog("Delete this attractor? This cannot be undone!", function()
        sendClientCommand(self.player, "WLZA", "RemoveAttractor", { attractorId = attractorId })
        print("[WLZA] Deleted attractor: " .. attractorId)
        self:onClose()
    end)
end

function WLZA_ManageAttractor:prerender()
    -- Check if highlighter-relevant data has changed
    local currentData = self:getHighlighterRelevantData()
    if currentData ~= self.previousHighlighterData then
        self:createHighlighters()
        self.previousHighlighterData = currentData
    end
    
    ISPanel.prerender(self)
    GravyUI.prerender(self)
end

function WLZA_ManageAttractor:onClose()
    -- Clear all highlighters before closing
    self:clearHighlighters()
    
    self:removeFromUIManager()
    WLZA_ManageAttractor.instance = nil
end