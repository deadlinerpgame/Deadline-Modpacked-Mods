---
--- BasicSettingsPanel.lua
--- Basic settings panel for spawner configuration
---

WLSP_BasicSettingsPanel = ISPanel:derive("WLSP_BasicSettingsPanel")

function WLSP_BasicSettingsPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o:initialise()
    return o
end

function WLSP_BasicSettingsPanel:initialise()
    ISPanel.initialise(self)
    
    -- Store conditional UI elements for show/hide
    self.areaElements = {}
    self.radiusElements = {}
    self.perPlayerInAreaElements = {}
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16))

    local vstack = win:makeVerticalStack(WLSP_UI_Constants.scale(8))

    -- Title
    local titleRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_LARGE)
    titleRow:makeLabel("Basic Settings", UIFont.Large, WLSP_UI_Constants.COLOR_WHITE, "left")

    -- Spawner Name (user input for new spawners, read-only for existing)
    local nameRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local nameLabel, nameField = nameRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    nameLabel:makeLabel("Spawner Name:", UIFont.Medium, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.nameInput = nameField:makeTextBox("", false)
    self.nameInput:setTooltip("Unique name for this spawner")

    -- Group (optional)
    local groupRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local groupLabel, groupField = groupRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    groupLabel:makeLabel("Group:", UIFont.Medium, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.groupInput = groupField:makeTextBox("", false)
    self.groupInput:setTooltip("Optional group name for organizing spawners")

    -- Position (using PointPicker) - 2x normal row height
    local posRow = vstack:makeNode((WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8)) * 2 + WLSP_UI_Constants.scale(5))
    local posLabel, posField = posRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    posLabel:makeLabel("Position:", UIFont.Medium, WLSP_UI_Constants.COLOR_SPAWN_POINT, "left")
    self.positionPicker = posField:makePointPicker()

    -- Row 1: Spawner Type and Lifespan (2 columns)
    local row1 = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local typeCol, lifespanCol = row1:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(10))
    
    -- Spawner Type (left column)
    local typeLabel, typeField = typeCol:cols({ 0.4, 0.6 }, WLSP_UI_Constants.scale(5))
    typeLabel:makeLabel("Type:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.typeCombo = typeField:makeComboBox(self, self.onTypeChanged)
    self.typeCombo:addOption("point")
    self.typeCombo:addOption("area")
    self.typeCombo:addOption("radius")
    self.typeCombo:addOption("ring")
    
    -- Lifespan (right column)
    local lifespanLabel, lifespanField = lifespanCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    lifespanLabel:makeLabel("Lifespan:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.lifespan = lifespanField:makeTextBox("0", true)
    self.lifespan:setTooltip("Lifespan of the spawner in minutes (0 = infinite)")

    -- Row 2: Spawn Radius and Area Size (2 columns)
    local row2 = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local radiusCol, areaCol = row2:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(10))
    
    -- Spawn Radius (left column) - conditional
    local radiusLabel, radiusField = radiusCol:cols({ 0.4, 0.6 }, WLSP_UI_Constants.scale(5))
    local radiusLabelEl = radiusLabel:makeLabel("Radius:", UIFont.Small, WLSP_UI_Constants.COLOR_SPAWN_AREA, "left")
    table.insert(self.radiusElements, radiusLabelEl)
    self.spawnRadius = radiusField:makeTextBox("10", true)
    table.insert(self.radiusElements, self.spawnRadius)
    
    -- Area Size (right column) - conditional
    local areaLabel, areaFields = areaCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    local areaLabelEl = areaLabel:makeLabel("Area W/H:", UIFont.Small, WLSP_UI_Constants.COLOR_SPAWN_AREA, "left")
    table.insert(self.areaElements, areaLabelEl)
    local areaX, areaY = areaFields:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(3))
    self.areaOffsetX = areaX:makeTextBox("10", true)
    table.insert(self.areaElements, self.areaOffsetX)
    self.areaOffsetY = areaY:makeTextBox("10", true)
    table.insert(self.areaElements, self.areaOffsetY)

    -- Row 3: Count Type and Count (2 columns)
    local row3 = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local countTypeCol, countCol = row3:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(10))
    
    -- Count Type (left column)
    local countTypeLabel, countTypeField = countTypeCol:cols({ 0.4, 0.6 }, WLSP_UI_Constants.scale(5))
    countTypeLabel:makeLabel("Count Type:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.countTypeCombo = countTypeField:makeComboBox(self, self.onCountTypeChanged)
    self.countTypeCombo:addOption("fixed")
    self.countTypeCombo:addOption("perPlayerInArea")
    self.countTypeCombo:addOption("totalOnlinePlayers")
    
    -- Count (right column)
    local countLabel, countField = countCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    countLabel:makeLabel("Count:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.count = countField:makeTextBox("5", true)

    -- Spawn Interval (full width)
    local intervalRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local intervalLabel, intervalField = intervalRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    intervalLabel:makeLabel("Spawn Interval (sec):", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.spawnInterval = intervalField:makeTextBox("60", true)
    self.spawnInterval:setTooltip("Time interval between spawns in seconds")
    
    local perPlayerPointRow = vstack:makeNode((WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8)) * 2 + WLSP_UI_Constants.scale(5))
    local perPlayerPointLabel, perPlayerPointField = perPlayerPointRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    local pointLabel = perPlayerPointLabel:makeLabel("Per Player Point:", UIFont.Small, WLSP_UI_Constants.COLOR_PER_PLAYER_AREA, "left")
    table.insert(self.perPlayerInAreaElements, pointLabel)
    self.perPlayerInAreaPoint = perPlayerPointField:makePointPicker()
    table.insert(self.perPlayerInAreaElements, self.perPlayerInAreaPoint)
    
    local perPlayerRadiusRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local perPlayerRadiusLabel, perPlayerRadiusField = perPlayerRadiusRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    local radiusLabel = perPlayerRadiusLabel:makeLabel("Radius:", UIFont.Small, WLSP_UI_Constants.COLOR_PER_PLAYER_AREA, "left")
    table.insert(self.perPlayerInAreaElements, radiusLabel)
    self.perPlayerInAreaRadius = perPlayerRadiusField:makeTextBox("10", true)
    table.insert(self.perPlayerInAreaElements, self.perPlayerInAreaRadius)
end

function WLSP_BasicSettingsPanel:onCountTypeChanged()
    self:updateCountTypeVisibility()
end

function WLSP_BasicSettingsPanel:onTypeChanged()
    self:updateTypeVisibility()
end

function WLSP_BasicSettingsPanel:updateTypeVisibility()
    local selectedType = self.typeCombo:getOptionText(self.typeCombo.selected)
    
    -- Show/hide area offset fields
    for _, element in ipairs(self.areaElements) do
        element:setVisible(selectedType == "area")
    end
    
    -- Show/hide radius field
    for _, element in ipairs(self.radiusElements) do
        element:setVisible(selectedType == "radius" or selectedType == "ring")
    end
end

function WLSP_BasicSettingsPanel:updateCountTypeVisibility()
    local selectedCountType = self.countTypeCombo:getOptionText(self.countTypeCombo.selected)
    
    -- Show/hide perPlayerInArea fields
    for _, element in ipairs(self.perPlayerInAreaElements) do
        element:setVisible(selectedCountType == "perPlayerInArea")
    end
end

function WLSP_BasicSettingsPanel:loadData(spawner)
    if spawner then
        -- Extract name from ID format "Username: SpawnerName"
        local spawnerName = ""
        if spawner.id then
            local colonPos = string.find(spawner.id, ": ")
            if colonPos then
                spawnerName = string.sub(spawner.id, colonPos + 2)
            else
                spawnerName = spawner.id
            end
        end
        self.nameInput:setText(spawnerName)
        self.nameInput:setEditable(false)  -- Read-only for existing spawners
        
        -- Load group
        if spawner.group then
            self.groupInput:setText(spawner.group)
        else
            self.groupInput:setText("")
        end
        
        if spawner.position then
            self.positionPicker:setValue({
                x = spawner.position.x,
                y = spawner.position.y,
                z = spawner.position.z
            })
        end
        
        -- Set spawner type
        for i = 1, #self.typeCombo.options do
            if self.typeCombo:getOptionText(i) == spawner.type then
                self.typeCombo.selected = i
                break
            end
        end
        
        -- Type-specific fields
        if spawner.area then
            self.areaOffsetX:setText(tostring(spawner.area.x or 10))
            self.areaOffsetY:setText(tostring(spawner.area.y or 10))
        end
        if spawner.spawnRadius then
            self.spawnRadius:setText(tostring(spawner.spawnRadius))
        end
        
        self.lifespan:setText(tostring(spawner.lifespan or 0))
        
        -- Set count type
        for i = 1, #self.countTypeCombo.options do
            if self.countTypeCombo:getOptionText(i) == spawner.countType then
                self.countTypeCombo.selected = i
                break
            end
        end
        
        self.count:setText(tostring(spawner.count or 1))
        self.spawnInterval:setText(tostring(spawner.spawnInterval or 60))
        
        -- Per Player In Area fields
        if spawner.perPlayerInAreaPoint then
            self.perPlayerInAreaPoint:setValue({
                x = spawner.perPlayerInAreaPoint.x,
                y = spawner.perPlayerInAreaPoint.y,
                z = spawner.perPlayerInAreaPoint.z
            })
        end
        if spawner.perPlayerInAreaRadius then
            self.perPlayerInAreaRadius:setText(tostring(spawner.perPlayerInAreaRadius))
        end
    else
        -- New spawner defaults
        self.nameInput:setText("")
        self.nameInput:setEditable(true)  -- Editable for new spawners
        self.groupInput:setText("")
        local player = getPlayer()
        if player then
            self.positionPicker:setValue({
                x = player:getX(),
                y = player:getY(),
                z = player:getZ()
            })
        end
        self.typeCombo.selected = 1
        self.lifespan:setText("0")
        self.countTypeCombo.selected = 1
        self.count:setText("5")
        self.spawnInterval:setText("60")
        self.areaOffsetX:setText("10")
        self.areaOffsetY:setText("10")
        self.spawnRadius:setText("10")
        
        -- Set default per player in area point to player position
        local player = getPlayer()
        if player then
            self.perPlayerInAreaPoint:setValue({
                x = player:getX(),
                y = player:getY(),
                z = player:getZ()
            })
        end
        self.perPlayerInAreaRadius:setText("10")
    end
    
    self:updateTypeVisibility()
    self:updateCountTypeVisibility()
end

function WLSP_BasicSettingsPanel:getData()
    local data = {}
    
    -- Generate ID from username and name input
    local spawnerName = self.nameInput:getText()
    local username = getPlayer():getUsername()
    data.id = username .. ": " .. spawnerName
    
    -- Add group if specified
    local groupName = self.groupInput:getText()
    if groupName and groupName ~= "" then
        data.group = groupName
    end
    
    local pos = self.positionPicker:getValue()
    data.position = { x = pos.x, y = pos.y, z = pos.z }
    
    data.type = self.typeCombo:getOptionText(self.typeCombo.selected)
    
    -- Type-specific data
    if data.type == "area" then
        data.area = {
            x = tonumber(self.areaOffsetX:getText()) or 10,
            y = tonumber(self.areaOffsetY:getText()) or 10
        }
    elseif data.type == "radius" or data.type == "ring" then
        data.spawnRadius = tonumber(self.spawnRadius:getText()) or 10
    end
    
    data.lifespan = tonumber(self.lifespan:getText()) or 0
    data.countType = self.countTypeCombo:getOptionText(self.countTypeCombo.selected)
    data.count = tonumber(self.count:getText()) or 1
    data.spawnInterval = tonumber(self.spawnInterval:getText()) or 60
    
    -- Per Player In Area fields
    if data.countType == "perPlayerInArea" then
        local point = self.perPlayerInAreaPoint:getValue()
        data.perPlayerInAreaPoint = { x = point.x, y = point.y, z = point.z }
        data.perPlayerInAreaRadius = tonumber(self.perPlayerInAreaRadius:getText()) or 10
    end
    
    return data
end