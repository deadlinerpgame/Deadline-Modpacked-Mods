
---
--- WLSP_ManageSpawner.lua
--- Manage Spawner UI implemented using tabbed panels
---

WLSP_ManageSpawner = ISPanel:derive("WLSP_ManageSpawner")

-- Container/show
function WLSP_ManageSpawner:show(player, spawner)
    if WLSP_ManageSpawner.instance then
        WLSP_ManageSpawner.instance:onClose()
    end
    local w = math.floor(WLSP_UI_Constants.scale(700))
    -- Static height that fits all content
    local h = math.floor(WLSP_UI_Constants.scale(600))
    local x = math.floor((getCore():getScreenWidth() - w) / 2)
    local y = math.floor((getCore():getScreenHeight() - h) / 2)
    local ui = WLSP_ManageSpawner:new(x, y, w, h, player, spawner)
    ui:initialise()
    ui:addToUIManager()
    WLSP_ManageSpawner.instance = ui
    return ui
end

function WLSP_ManageSpawner:new(x, y, width, height, player, spawner)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.spawner = spawner
    o.isNewSpawner = (spawner == nil)
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
function WLSP_ManageSpawner:getHighlighterRelevantData()
    local data = self:collectData()
    if not data then return "" end
    
    local relevant = {}
    
    -- Spawner type and position
    relevant.type = data.type or ""
    if data.position then
        relevant.posX = data.position.x or 0
        relevant.posY = data.position.y or 0
        relevant.posZ = data.position.z or 0
    end
    
    -- Area offsets (for area type)
    if data.area then
        relevant.areaX = data.area.x or 0
        relevant.areaY = data.area.y or 0
    end
    
    -- Spawn radius (for radius/ring types)
    if data.spawnRadius then
        relevant.spawnRadius = data.spawnRadius
    end
    
    -- Target location
    if data.targetLocation then
        relevant.targetX = data.targetLocation.x or 0
        relevant.targetY = data.targetLocation.y or 0
        relevant.targetZ = data.targetLocation.z or 0
    end
    
    -- Player and zombie conditions (only radius and type affect highlighters)
    if data.conditions then
        for i, condition in ipairs(data.conditions) do
            if condition.type == "playerCount" then
                relevant["playerType" .. i] = condition.checkType or ""
                relevant["playerRadius" .. i] = condition.radius or 0
            elseif condition.type == "zombieCount" then
                relevant["zombieType" .. i] = condition.checkType or ""
                relevant["zombieRadius" .. i] = condition.radius or 0
            end
        end
    end
    
    -- Per Player In Area point and radius
    if data.perPlayerInAreaPoint then
        relevant.perPlayerPointX = data.perPlayerInAreaPoint.x or 0
        relevant.perPlayerPointY = data.perPlayerInAreaPoint.y or 0
        relevant.perPlayerPointZ = data.perPlayerInAreaPoint.z or 0
    end
    if data.perPlayerInAreaRadius then
        relevant.perPlayerRadius = data.perPlayerInAreaRadius
    end
    
    -- Triggers (area triggers with positions and radii)
    if data.triggers then
        for i, trigger in ipairs(data.triggers) do
            if trigger.type == "area" and trigger.position then
                relevant["triggerPosX" .. i] = trigger.position.x or 0
                relevant["triggerPosY" .. i] = trigger.position.y or 0
                relevant["triggerPosZ" .. i] = trigger.position.z or 0
                relevant["triggerRadius" .. i] = trigger.radius or 0
            end
        end
    end
    
    -- Serialize to string for comparison
    local parts = {}
    for k, v in pairs(relevant) do
        table.insert(parts, k .. "=" .. tostring(v))
    end
    table.sort(parts)  -- Ensure consistent ordering
    return table.concat(parts, "|")
end

--- Create and configure all highlighters based on current spawner data
function WLSP_ManageSpawner:createHighlighters()
    -- Clear any existing highlighters first
    self:clearHighlighters()
    
    -- Get current spawner data from UI
    local data = self:collectData()
    if not data or not data.position then
        return
    end
    
    local pos = data.position
    
    -- Priority scheme (lower = higher priority):
    -- 0 = Spawn position (green) - highest priority
    -- 1 = Target location (red)
    -- 2 = Target line (red, semi-transparent)
    -- 3 = Spawn area/radius/ring (yellow)
    -- 4 = Conditional areas (blue) - lowest priority
    
    -- 1. Spawn Position (Green) - Priority 0
    local spawnPosHL = GroundHighlighter:new()
    local c = WLSP_UI_Constants.COLOR_SPAWN_POINT
    spawnPosHL:setColor(c.r, c.g, c.b, c.a)
    spawnPosHL:setPriority(0)
    spawnPosHL:enableXray(true)
    spawnPosHL:highlightSquare(pos.x, pos.y, pos.x, pos.y, pos.z)
    table.insert(self.highlighters, spawnPosHL)
    
    -- 2. Spawn Area/Radius/Ring (Yellow) - Priority 3
    if data.type == "area" and data.area then
        local areaHL = GroundHighlighter:new()
        c = WLSP_UI_Constants.COLOR_SPAWN_AREA
        areaHL:setColor(c.r, c.g, c.b, c.a)
        areaHL:setPriority(3)
        areaHL:enableXray(true)
        -- Position is now at center, so calculate corners
        local halfX = data.area.x / 2
        local halfY = data.area.y / 2
        areaHL:highlightSquare(
            pos.x - halfX, pos.y - halfY,
            pos.x + halfX, pos.y + halfY,
            pos.z
        )
        table.insert(self.highlighters, areaHL)
        
    elseif data.type == "radius" and data.spawnRadius then
        local radiusHL = GroundHighlighter:new()
        c = WLSP_UI_Constants.COLOR_SPAWN_AREA
        radiusHL:setColor(c.r, c.g, c.b, c.a)
        radiusHL:setPriority(3)
        radiusHL:enableXray(true)
        radiusHL:highlightCircle(pos.x, pos.y, data.spawnRadius, pos.z)
        table.insert(self.highlighters, radiusHL)
        
    elseif data.type == "ring" and data.spawnRadius then
        local ringHL = GroundHighlighter:new()
        c = WLSP_UI_Constants.COLOR_SPAWN_AREA
        ringHL:setColor(c.r, c.g, c.b, c.a)
        ringHL:setPriority(3)
        ringHL:enableXray(true)
        ringHL:highlightRing(pos.x, pos.y, data.spawnRadius, 2, pos.z)
        table.insert(self.highlighters, ringHL)
    end
    -- type "point" shows only spawn position (already handled above)
    
    -- 3. Target Location (Red) - Priority 1 for position, 2 for line
    if data.targetLocation then
        local target = data.targetLocation
        
        -- Check if target has valid coordinates (not 0,0,0)
        local hasValidTarget = target.x ~= 0 or target.y ~= 0 or target.z ~= 0
        
        if hasValidTarget then
            -- Target position marker - Priority 1
            local targetHL = GroundHighlighter:new()
            c = WLSP_UI_Constants.COLOR_TARGET
            targetHL:setColor(c.r, c.g, c.b, c.a)
            targetHL:setPriority(1)
            targetHL:enableXray(true)
            targetHL:highlightSquare(target.x, target.y, target.x, target.y, target.z)
            table.insert(self.highlighters, targetHL)
            
            -- Line from spawn to target - Priority 2
            local lineHL = GroundHighlighter:new()
            c = WLSP_UI_Constants.COLOR_TARGET
            lineHL:setColor(c.r, c.g, c.b, c.a)
            lineHL:setPriority(2)
            lineHL:enableXray(true)
            lineHL:highlightLine(pos.x, pos.y, pos.z, target.x, target.y, target.z, 1)
            table.insert(self.highlighters, lineHL)
        end
    end
    
    -- 4. Conditional Areas (Blue) - Priority 4
    if data.conditions then
        for _, condition in ipairs(data.conditions) do
            if condition.type == "playerCount" then
                local centerX, centerY = pos.x, pos.y
                
                -- Determine center based on player condition type
                if condition.checkType == "rangeTarget" and data.targetLocation then
                    centerX = data.targetLocation.x
                    centerY = data.targetLocation.y
                end
                
                if condition.radius and (condition.checkType == "rangeSpawner" or condition.checkType == "rangeTarget") then
                    local playerHL = GroundHighlighter:new()
                    c = WLSP_UI_Constants.COLOR_PLAYER_CONDITION
                    playerHL:setColor(c.r, c.g, c.b, c.a)
                    playerHL:setPriority(4)
                    playerHL:enableXray(true)
                    if condition.checkType == "rangeTarget" then
                        playerHL:highlightCircle(centerX, centerY, condition.radius, data.targetLocation.z)
                    else
                        playerHL:highlightCircle(centerX, centerY, condition.radius, pos.z)
                    end
                    table.insert(self.highlighters, playerHL)
                end
            elseif condition.type == "zombieCount" then
                local centerX, centerY, centerZ = pos.x, pos.y, pos.z
                
                -- Determine center based on zombie condition type
                if condition.checkType == "target" and data.targetLocation then
                    centerX = data.targetLocation.x
                    centerY = data.targetLocation.y
                    centerZ = data.targetLocation.z
                end
                
                if condition.radius then
                    local zombieHL = GroundHighlighter:new()
                    c = WLSP_UI_Constants.COLOR_ZOMBIE_CONDITION
                    zombieHL:setColor(c.r, c.g, c.b, c.a)
                    zombieHL:setPriority(4)
                    zombieHL:enableXray(true)
                    zombieHL:highlightCircle(centerX, centerY, condition.radius, centerZ)
                    table.insert(self.highlighters, zombieHL)
                end
            end
        end
    end
    
    -- Per Player In Area check area (Purple) - Priority 4
    if data.countType == "perPlayerInArea" and data.perPlayerInAreaPoint and data.perPlayerInAreaRadius then
        local perPlayerHL = GroundHighlighter:new()
        c = WLSP_UI_Constants.COLOR_PER_PLAYER_AREA
        perPlayerHL:setColor(c.r, c.g, c.b, c.a)
        perPlayerHL:setPriority(4)
        perPlayerHL:enableXray(true)
        perPlayerHL:highlightCircle(
            data.perPlayerInAreaPoint.x,
            data.perPlayerInAreaPoint.y,
            data.perPlayerInAreaRadius,
            data.perPlayerInAreaPoint.z
        )
        table.insert(self.highlighters, perPlayerHL)
        
        -- Also add a marker at the center point
        local centerMarker = GroundHighlighter:new()
        c = WLSP_UI_Constants.COLOR_PER_PLAYER_AREA
        centerMarker:setColor(c.r, c.g, c.b, c.a)
        centerMarker:setPriority(1)
        centerMarker:enableXray(true)
        centerMarker:highlightSquare(
            data.perPlayerInAreaPoint.x,
            data.perPlayerInAreaPoint.y,
            data.perPlayerInAreaPoint.x,
            data.perPlayerInAreaPoint.y,
            data.perPlayerInAreaPoint.z
        )
        table.insert(self.highlighters, centerMarker)
    end
    
    -- 5. Trigger Areas (Cyan) - Priority 4
    if data.triggers then
        for _, trigger in ipairs(data.triggers) do
            if trigger.type == "area" and trigger.position and trigger.radius then
                local triggerHL = GroundHighlighter:new()
                c = WLSP_UI_Constants.COLOR_TRIGGER
                triggerHL:setColor(c.r, c.g, c.b, c.a)
                triggerHL:setPriority(4)
                triggerHL:enableXray(true)
                triggerHL:highlightCircle(
                    trigger.position.x,
                    trigger.position.y,
                    trigger.radius,
                    trigger.position.z
                )
                table.insert(self.highlighters, triggerHL)
                
                -- Add a marker at the center point
                local triggerMarker = GroundHighlighter:new()
                c = WLSP_UI_Constants.COLOR_TRIGGER
                triggerMarker:setColor(c.r, c.g, c.b, c.a)
                triggerMarker:setPriority(1)
                triggerMarker:enableXray(true)
                triggerMarker:highlightSquare(
                    trigger.position.x,
                    trigger.position.y,
                    trigger.position.x,
                    trigger.position.y,
                    trigger.position.z
                )
                table.insert(self.highlighters, triggerMarker)
            end
        end
    end
    
end

--- Clear all highlighters (called before creating new ones or on window close)
function WLSP_ManageSpawner:clearHighlighters()
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
function WLSP_ManageSpawner:initialise()
    ISPanel.initialise(self)

    -- Styling
    self.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
    self.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    self.moveWithMouse = true

    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(0, WLSP_UI_Constants.scale(5), 0, WLSP_UI_Constants.scale(5))

    local rowPadding = WLSP_UI_Constants.scale(5)
    
    -- Header with title and buttons
    local headerHeight = WLSP_UI_Constants.FONT_HGT_LARGE + WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(10)
    self.headerHeight = headerHeight
    local headerArea, bodyArea = win:rows({ headerHeight, self.height - headerHeight - WLSP_UI_Constants.scale(10) }, rowPadding)
    
    -- Header layout: buttons on right, title/subtitle on left
    local headerButtonWidth = WLSP_UI_Constants.scale(180)
    local titleArea, buttonArea = headerArea:cols({ self.width - headerButtonWidth - WLSP_UI_Constants.scale(10), headerButtonWidth }, WLSP_UI_Constants.scale(10))
    
    -- Title and subtitle
    local titleRow, subTitleRow = titleArea:rows({ WLSP_UI_Constants.FONT_HGT_LARGE, WLSP_UI_Constants.FONT_HGT_MEDIUM }, WLSP_UI_Constants.scale(3))
    self.titleLabel = titleRow:makeLabel("", UIFont.Large, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.subtitleLabel = subTitleRow:makeLabel("", UIFont.Medium, WLSP_UI_Constants.COLOR_WHITE, "left")
    
    -- Header buttons (Save/Delete/Close/Duplicate stacked vertically)
    local buttonStack = buttonArea:makeVerticalStack(WLSP_UI_Constants.scale(3))
    local duplicateCloseRow = buttonStack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    local saveDeleteRow = buttonStack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    
    -- Duplicate and Close buttons (side by side)
    local duplicateCol, closeCol = duplicateCloseRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    self.duplicateButton = duplicateCol:makeButton("Duplicate", self, self.onDuplicate)
    self.duplicateButton:setVisible(not self.isNewSpawner)
    self.closeButton = closeCol:makeButton("Close", self, self.onClose)
    
    -- Save and Delete buttons (side by side)
    local saveCol, deleteCol = saveDeleteRow:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    self.saveButton = saveCol:makeButton("Save", self, self.onSave)
    self.deleteButton = deleteCol:makeButton("Delete", self, self.onDelete)
    self.deleteButton:setVisible(not self.isNewSpawner)

    -- TabPanel (takes remaining space)
    self.tabs = bodyArea:makeTabPanel()
    self.tabs.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    local tabX, tabY, tabW, tabH = self.tabs.x, self.tabs.y, self.tabs.width, self.tabs.height - self.tabs.tabHeight

    -- Create tabs
    self.basicPanel = WLSP_BasicSettingsPanel:new(tabX, tabY, tabW, tabH, self)
    self.tabs:addView("Basic", self.basicPanel)

    self.zombiePropsPanel = WLSP_ZombiePropertiesPanel:new(tabX, tabY, tabW, tabH, self)
    self.tabs:addView("Zombie Props", self.zombiePropsPanel)

    self.conditionsPanel = WLSP_ConditionsPanel:new(tabX, tabY, tabW, tabH, self)
    self.tabs:addView("Conditions", self.conditionsPanel)
    
    self.triggersPanel = WLSP_TriggersPanel:new(tabX, tabY, tabW, tabH, self)
    self.tabs:addView("Triggers", self.triggersPanel)
    
    self:updateState()
    
    -- Create highlighters after UI is set up
    self:createHighlighters()
end

function WLSP_ManageSpawner:updateState()
    if self.isNewSpawner then
        self.titleLabel:setText("Create New Spawner")
        self.subtitleLabel:setText("Configure spawner settings")
    else
        self.titleLabel:setText("Edit Spawner")
        self.subtitleLabel:setText(self.spawner and self.spawner.id or "Unknown")
    end

    -- Load data into panels
    if self.basicPanel and self.basicPanel.loadData then
        self.basicPanel:loadData(self.spawner)
    end
    if self.conditionsPanel and self.conditionsPanel.loadData then
        self.conditionsPanel:loadData(self.spawner)
    end
    if self.zombiePropsPanel and self.zombiePropsPanel.loadData then
        self.zombiePropsPanel:loadData(self.spawner)
    end
    if self.triggersPanel and self.triggersPanel.loadData then
        self.triggersPanel:loadData(self.spawner)
    end
end

function WLSP_ManageSpawner:validateData(data)
    -- Extract spawner name from ID
    local spawnerName = ""
    if data.id then
        local colonPos = string.find(data.id, ": ")
        if colonPos then
            spawnerName = string.sub(data.id, colonPos + 2)
        end
    end
    
    -- Check required fields
    if not spawnerName or spawnerName == "" then
        WL_Dialogs.showMessageDialog("Spawner Name is required")
        return false
    end
    
    -- Check for uniqueness (only for new spawners or if ID changed)
    if self.isNewSpawner or (self.spawner and self.spawner.id ~= data.id) then
        local allSpawners = WLSP_Client:getAllSpawners()
        for _, existingSpawner in ipairs(allSpawners) do
            if existingSpawner.id == data.id then
                WL_Dialogs.showMessageDialog("A spawner with this name already exists. Please choose a different name.")
                return false
            end
        end
    end
    
    if not data.position or not data.position.x or not data.position.y or not data.position.z then
        WL_Dialogs.showMessageDialog("Position is required")
        return false
    end
    
    if not data.count or data.count <= 0 then
        WL_Dialogs.showMessageDialog("Count must be greater than 0")
        return false
    end
    
    if not data.spawnInterval or data.spawnInterval <= 0 then
        WL_Dialogs.showMessageDialog("Spawn interval must be greater than 0")
        return false
    end
    
    -- Validate type-specific requirements
    if data.type == "area" and (not data.area or not data.area.x or not data.area.y) then
        WL_Dialogs.showMessageDialog("Area type requires area offsets")
        return false
    end
    
    if (data.type == "radius" or data.type == "ring") and (not data.spawnRadius or data.spawnRadius <= 0) then
        WL_Dialogs.showMessageDialog("Radius/Ring type requires spawn radius > 0")
        return false
    end
    
    -- Validate time of day
    if data.requiredTimeOfDay then
        local start = data.requiredTimeOfDay.start
        local endHour = data.requiredTimeOfDay["end"]
        if start < 0 or start > 23 or endHour < 0 or endHour > 23 then
            WL_Dialogs.showMessageDialog("Time of day hours must be between 0 and 23")
            return false
        end
    end
    
    return true
end

function WLSP_ManageSpawner:collectData()
    local data = {}
    
    -- Collect from basic panel
    if self.basicPanel and self.basicPanel.getData then
        local basicData = self.basicPanel:getData()
        for k, v in pairs(basicData) do
            data[k] = v
        end
    end
    
    -- Collect from conditions panel
    if self.conditionsPanel and self.conditionsPanel.getData then
        local condData = self.conditionsPanel:getData()
        for k, v in pairs(condData) do
            data[k] = v
        end
    end
    
    -- Collect from zombie properties panel (includes target location)
    if self.zombiePropsPanel and self.zombiePropsPanel.getData then
        local zombiePropsData = self.zombiePropsPanel:getData()
        for k, v in pairs(zombiePropsData) do
            data[k] = v
        end
    end
    
    -- Collect from triggers panel
    if self.triggersPanel and self.triggersPanel.getData then
        local triggersData = self.triggersPanel:getData()
        for k, v in pairs(triggersData) do
            data[k] = v
        end
    end
    
    return data
end

function WLSP_ManageSpawner:onSave()
    local data = self:collectData()
    
    if not self:validateData(data) then
        return
    end
    
    -- Send to server
    sendClientCommand(self.player, "WLSP", "AddSpawner", { spawner = data })
    
    print("[WLSP] Saved spawner: " .. data.id)

    if not self.isNewSpawner then
        -- Editing existing spawner, do not reopen
        return
    end
    
    -- Close current window and re-open in edit mode
    local savedSpawnerId = data.id
    local player = self.player
    self:onClose()
    
    -- Re-open window after a short delay to allow server sync
    -- We'll use a timer to wait for the spawner to be added to client storage
    local waitTicks = 0
    local maxWaitTicks = 60  -- Wait up to 1 second
    
    local function checkAndReopen()
        waitTicks = waitTicks + 1
        
        -- Try to get the spawner from client storage
        local spawner = WLSP_Client:getSpawner(savedSpawnerId)
        
        if spawner then
            -- Spawner is now in client storage, open it
            WLSP_ManageSpawner:show(player, spawner)
            Events.OnTick.Remove(checkAndReopen)
        elseif waitTicks >= maxWaitTicks then
            -- Timeout - just use the data we have
            WLSP_ManageSpawner:show(player, data)
            Events.OnTick.Remove(checkAndReopen)
        end
    end
    
    Events.OnTick.Add(checkAndReopen)
end

function WLSP_ManageSpawner:onDelete()
    if self.isNewSpawner then
        self:onClose()
        return
    end
    
    local spawnerId = self.spawner and self.spawner.id
    if not spawnerId then
        self:onClose()
        return
    end
    
    WL_Dialogs.showConfirmationDialog("Delete this spawner? This cannot be undone!", function()
        sendClientCommand(self.player, "WLSP", "RemoveSpawner", { spawnerId = spawnerId })
        print("[WLSP] Deleted spawner: " .. spawnerId)
        self:onClose()
    end)
end

function WLSP_ManageSpawner:onDuplicate()
    if self.isNewSpawner then
        return
    end
    
    -- Collect current spawner data
    local data = self:collectData()
    if not data then
        return
    end
    
    -- Clear the name from the ID (keep the prefix)
    if data.id then
        local colonPos = string.find(data.id, ": ")
        if colonPos then
            -- Keep only the prefix, clear the name part
            data.id = string.sub(data.id, 1, colonPos + 1)
        end
    end
    
    local player = self.player
    
    -- Close current window
    self:onClose()
    
    -- Open new spawner window with duplicated data
    -- Pass nil as spawner to indicate this is a new spawner
    WLSP_ManageSpawner:show(player, nil)
    
    -- Load the duplicated data into the new window after a short delay
    -- to ensure the window is fully initialized
    local instance = WLSP_ManageSpawner.instance
    if instance then
        -- Manually set the spawner data (without the name)
        instance.spawner = data
        instance.isNewSpawner = true  -- Ensure it's treated as new
        
        -- Reload data into panels
        if instance.basicPanel and instance.basicPanel.loadData then
            instance.basicPanel:loadData(data)
            -- Make name field editable for duplicate (it's set to read-only in loadData for existing spawners)
            if instance.basicPanel.nameInput then
                instance.basicPanel.nameInput:setEditable(true)
            end
        end
        if instance.conditionsPanel and instance.conditionsPanel.loadData then
            instance.conditionsPanel:loadData(data)
        end
        if instance.zombiePropsPanel and instance.zombiePropsPanel.loadData then
            instance.zombiePropsPanel:loadData(data)
        end
        if instance.triggersPanel and instance.triggersPanel.loadData then
            instance.triggersPanel:loadData(data)
        end
        
        -- Update highlighters with the duplicated data
        instance:createHighlighters()
    end
end

function WLSP_ManageSpawner:prerender()
    -- Check if highlighter-relevant data has changed
    local currentData = self:getHighlighterRelevantData()
    if currentData ~= self.previousHighlighterData then
        self:createHighlighters()
        self.previousHighlighterData = currentData
    end
    
    ISPanel.prerender(self)
    GravyUI.prerender(self)
end

function WLSP_ManageSpawner:onClose()
    -- Clear all highlighters before closing
    self:clearHighlighters()
    
    if self.basicPanel and self.basicPanel.positionPicker then
        self.basicPanel.positionPicker:cleanup()
    end
    if self.triggersPanel and self.triggersPanel.positionPicker then
        self.triggersPanel.positionPicker:cleanup()
    end
    self:removeFromUIManager()
    WLSP_ManageSpawner.instance = nil
end