if isServer() then return end

require "WLR_ClientSync"
require "WLR_NetworkConstants"

-- Zone Editor - Zone creation/editing dialog
WLR_ZoneEditor = ISCollapsableWindow:derive("WLR_ZoneEditor")
WLR_ZoneEditor.instance = nil

function WLR_ZoneEditor:show(zoneId)
    -- Admin check
    if not isAdmin() then
        getPlayer():Say("Access denied - admin privileges required")
        return
    end
    
    if self.instance then
        self.instance:close()
    end
    
    local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12
    local w = 300 * scale
    local h = 500 * scale
    local o = WLR_ZoneEditor:new(getCore():getScreenWidth()/2-w/2, getCore():getScreenHeight()/2-h/2, w, h)
    o.scale = scale
    o.editingZoneId = zoneId
    o.alwaysOnTop = true
    setmetatable(o, self)
    self.__index = self
    o:initialise()
    o:addToUIManager()
    self.instance = o
    return o
end

function WLR_ZoneEditor:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)
    
    if self.editingZoneId then
        self.title = "Edit Zone: " .. self.editingZoneId
    else
        self.title = "Create New Zone"
    end
    
    -- Default values
    self.zoneData = {
        id = self.editingZoneId or "",
        enabled = true,
        x1 = 0,
        y1 = 0,
        x2 = 100,
        y2 = 100,
        containerChance = 1.0,
        itemChance = 1.0,
        frequencyHours = 168,
        itemCountToIgnore = 10,
        gasFillChance = 0.0,
        gasFillRange = {0, 0},
        ignoredCategories = {},
        ignoredItems = {}
    }
    
    -- Load existing zone data if editing
    if self.editingZoneId then
        local existingZone = WLR_ClientSync.GetZoneDefinition(self.editingZoneId)
        if existingZone then
            for key, value in pairs(existingZone) do
                self.zoneData[key] = value
            end
        end
    end
    
    local win = GravyUI.Node(self.width, self.height, self):pad(5, 21, 5, 16)
    
    -- Main sections
    local basicSection, coordinatesSection, chancesSection, advancedSection, buttonsSection = 
        win:rows({0.11, 0.22, 0.22, 0.37, .08}, 10)
    
    -- Basic info section
    local basicGrid = {basicSection:grid(2, {100, 1.0}, 5, 2)}
    
    basicGrid[1][1]:makeLabel("Zone ID:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.zoneIdInput = basicGrid[1][2]:makeTextBox(self.zoneData.id)
    if self.editingZoneId then
        self.zoneIdInput:setEditable(false) -- Can't change ID when editing
    end
    
    basicGrid[2][1]:makeLabel("Enabled:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.enabledCheckbox = basicGrid[2][2]:makeTickBox()
    self.enabledCheckbox:addOption("", self.zoneData.enabled or false)
    
    -- Coordinates section
    local coordHeader, coordGrid = coordinatesSection:rows({25, 1.0}, 5)
    coordHeader:makeLabel("Zone Coordinates", UIFont.Medium, {r=1, g=1, b=1, a=1}, "center")
    
    local coordGridLayout = {coordGrid:grid(4, {80, 1.0}, 5, 2)}
    
    coordGridLayout[1][1]:makeLabel("X1:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.x1Input = coordGridLayout[1][2]:makeTextBox(tostring(self.zoneData.x1))
    self.x1Input:setOnlyNumbers(true)
    
    coordGridLayout[2][1]:makeLabel("Y1:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.y1Input = coordGridLayout[2][2]:makeTextBox(tostring(self.zoneData.y1))
    self.y1Input:setOnlyNumbers(true)
    
    coordGridLayout[3][1]:makeLabel("X2:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.x2Input = coordGridLayout[3][2]:makeTextBox(tostring(self.zoneData.x2))
    self.x2Input:setOnlyNumbers(true)
    
    coordGridLayout[4][1]:makeLabel("Y2:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.y2Input = coordGridLayout[4][2]:makeTextBox(tostring(self.zoneData.y2))
    self.y2Input:setOnlyNumbers(true)
    
    -- Chances section
    local chancesHeader, chancesGrid = chancesSection:rows({25, 1.0}, 5)
    chancesHeader:makeLabel("Respawn Chances", UIFont.Medium, {r=1, g=1, b=1, a=1}, "center")
    
    local chancesGridLayout = {chancesGrid:grid(4, {120, 1.0}, 5, 2)}
    
    chancesGridLayout[1][1]:makeLabel("Container Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.containerChanceInput = chancesGridLayout[1][2]:makeTextBox(tostring(self.zoneData.containerChance))
    
    chancesGridLayout[2][1]:makeLabel("Item Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.itemChanceInput = chancesGridLayout[2][2]:makeTextBox(tostring(self.zoneData.itemChance))
    
    chancesGridLayout[3][1]:makeLabel("Frequency (hours):", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.frequencyInput = chancesGridLayout[3][2]:makeTextBox(tostring(self.zoneData.frequencyHours))
    self.frequencyInput:setOnlyNumbers(true)
    
    chancesGridLayout[4][1]:makeLabel("Item Count Ignore:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.itemCountIgnoreInput = chancesGridLayout[4][2]:makeTextBox(tostring(self.zoneData.itemCountToIgnore))
    self.itemCountIgnoreInput:setOnlyNumbers(true)
    
    -- Advanced section
    local advancedHeader, advancedContent = advancedSection:rows({25, 1.0}, 5)
    advancedHeader:makeLabel("Advanced Settings", UIFont.Medium, {r=1, g=1, b=1, a=1}, "center")
    
    local gasSection, ignoredSection = advancedContent:rows({60, 1.0}, 10)
    
    -- Gas fill section
    local gasGrid = {gasSection:grid(2, {120, 1.0}, 5, 2)}
    
    gasGrid[1][1]:makeLabel("Gas Fill Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.gasFillChanceInput = gasGrid[1][2]:makeTextBox(tostring(self.zoneData.gasFillChance))
    
    gasGrid[2][1]:makeLabel("Gas Fill Range:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local gasRangeText = string.format("%d-%d", self.zoneData.gasFillRange[1] or 0, self.zoneData.gasFillRange[2] or 0)
    self.gasFillRangeInput = gasGrid[2][2]:makeTextBox(gasRangeText)
    
    -- Ignored items section
    local ignoredHeader, ignoredContent = ignoredSection:rows({25, 1.0}, 5)
    ignoredHeader:makeLabel("Ignored Categories/Items (comma-separated)", UIFont.Small, {r=1, g=1, b=1, a=1}, "left")
    
    local categoriesRow, itemsRow = ignoredContent:rows(2, 5)
    
    local categoriesLabel, categoriesInput = categoriesRow:cols({100, 1.0}, 5)
    categoriesLabel:makeLabel("Categories:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local categoriesText = ""
    if self.zoneData.ignoredCategories then
        local cats = {}
        for cat, _ in pairs(self.zoneData.ignoredCategories) do
            table.insert(cats, cat)
        end
        categoriesText = table.concat(cats, ", ")
    end
    self.ignoredCategoriesInput = categoriesInput:makeTextBox(categoriesText)
    
    local itemsLabel, itemsInput = itemsRow:cols({100, 1.0}, 5)
    itemsLabel:makeLabel("Items:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local itemsText = ""
    if self.zoneData.ignoredItems then
        local items = {}
        for item, _ in pairs(self.zoneData.ignoredItems) do
            table.insert(items, item)
        end
        itemsText = table.concat(items, ", ")
    end
    self.ignoredItemsInput = itemsInput:makeTextBox(itemsText)
    
    -- Buttons section
    local saveButton, cancelButton, validateButton = buttonsSection:cols(3, 10)
    self.saveButton = saveButton:makeButton("Save Zone", self, self.onSave)
    self.cancelButton = cancelButton:makeButton("Cancel", self, self.close)
    self.validateButton = validateButton:makeButton("Validate", self, self.onValidate)
end

function WLR_ZoneEditor:onValidate()
    local errors = self:validateInputs()
    if #errors == 0 then
        getPlayer():Say("All inputs are valid!")
    else
        local errorMsg = "Validation errors:\n" .. table.concat(errors, "\n")
        local modal = ISModalDialog:new(getCore():getScreenWidth()/2-200, getCore():getScreenHeight()/2-100, 400, 200, errorMsg, false)
        modal:initialise()
        modal:addToUIManager()
    end
end

function WLR_ZoneEditor:validateInputs()
    local errors = {}
    
    -- Zone ID validation
    local zoneId = self.zoneIdInput:getText():trim()
    if zoneId == "" then
        table.insert(errors, "Zone ID cannot be empty")
    elseif not self.editingZoneId and WLR_ClientSync.GetZoneDefinition(zoneId) then
        table.insert(errors, "Zone ID already exists")
    end
    
    -- Coordinate validation
    local x1 = tonumber(self.x1Input:getText())
    local y1 = tonumber(self.y1Input:getText())
    local x2 = tonumber(self.x2Input:getText())
    local y2 = tonumber(self.y2Input:getText())
    
    if not x1 or not y1 or not x2 or not y2 then
        table.insert(errors, "All coordinates must be valid numbers")
    elseif x1 >= x2 or y1 >= y2 then
        table.insert(errors, "X2 must be greater than X1, Y2 must be greater than Y1")
    end
    
    -- Chance validation (0.0 to 1.0)
    local containerChance = tonumber(self.containerChanceInput:getText())
    local itemChance = tonumber(self.itemChanceInput:getText())
    
    if not containerChance or containerChance < 0 or containerChance > 1 then
        table.insert(errors, "Container chance must be between 0.0 and 1.0")
    end
    
    if not itemChance or itemChance < 0 or itemChance > 1 then
        table.insert(errors, "Item chance must be between 0.0 and 1.0")
    end
    
    -- Frequency validation (positive number)
    local frequency = tonumber(self.frequencyInput:getText())
    if not frequency or frequency <= 0 then
        table.insert(errors, "Frequency must be a positive number")
    end
    
    -- Item count ignore validation (non-negative)
    local itemCountIgnore = tonumber(self.itemCountIgnoreInput:getText())
    if not itemCountIgnore or itemCountIgnore < 0 then
        table.insert(errors, "Item count ignore must be a non-negative number")
    end
    
    -- Gas fill chance validation
    local gasFillChance = tonumber(self.gasFillChanceInput:getText())
    if not gasFillChance or gasFillChance < 0 then
        table.insert(errors, "Gas fill chance must be a non-negative number")
    end
    
    -- Gas fill range validation
    local gasFillRangeText = self.gasFillRangeInput:getText():trim()
    if gasFillRangeText ~= "" then
        local min, max = gasFillRangeText:match("(%d+)-(%d+)")
        if not min or not max then
            table.insert(errors, "Gas fill range must be in format 'min-max' (e.g., '0-5')")
        elseif tonumber(min) > tonumber(max) then
            table.insert(errors, "Gas fill range minimum must be less than or equal to maximum")
        end
    end
    
    return errors
end

function WLR_ZoneEditor:onSave()
    local errors = self:validateInputs()
    if #errors > 0 then
        local errorMsg = "Cannot save zone:\n" .. table.concat(errors, "\n")
        local modal = ISModalDialog:new(getCore():getScreenWidth()/2-200, getCore():getScreenHeight()/2-100, 400, 200, errorMsg, false)
        modal:initialise()
        modal:addToUIManager()
        return
    end
    
    -- Build zone data
    local zoneData = {
        id = self.zoneIdInput:getText():trim(),
        enabled = self.enabledCheckbox:isSelected(1),
        x1 = tonumber(self.x1Input:getText()),
        y1 = tonumber(self.y1Input:getText()),
        x2 = tonumber(self.x2Input:getText()),
        y2 = tonumber(self.y2Input:getText()),
        containerChance = tonumber(self.containerChanceInput:getText()),
        itemChance = tonumber(self.itemChanceInput:getText()),
        frequencyHours = tonumber(self.frequencyInput:getText()),
        itemCountToIgnore = tonumber(self.itemCountIgnoreInput:getText()),
        gasFillChance = tonumber(self.gasFillChanceInput:getText()),
        gasFillRange = {0, 0},
        ignoredCategories = {},
        ignoredItems = {}
    }
    
    -- Parse gas fill range
    local gasFillRangeText = self.gasFillRangeInput:getText():trim()
    if gasFillRangeText ~= "" then
        local min, max = gasFillRangeText:match("(%d+)-(%d+)")
        if min and max then
            zoneData.gasFillRange = {tonumber(min), tonumber(max)}
        end
    end
    
    -- Parse ignored categories
    local categoriesText = self.ignoredCategoriesInput:getText():trim()
    if categoriesText ~= "" then
        for category in categoriesText:gmatch("[^,]+") do
            zoneData.ignoredCategories[category:trim()] = true
        end
    end
    
    -- Parse ignored items
    local itemsText = self.ignoredItemsInput:getText():trim()
    if itemsText ~= "" then
        for item in itemsText:gmatch("[^,]+") do
            zoneData.ignoredItems[item:trim()] = true
        end
    end
    
    -- Send to server
    if self.editingZoneId then
        sendClientCommand(getPlayer(), "WLR_Auto", "updateZone", zoneData)
        getPlayer():Say("Zone update sent to server")
    else
        sendClientCommand(getPlayer(), "WLR_Auto", "createZone", zoneData)
        getPlayer():Say("Zone creation sent to server")
    end
    
    self:close()
end

function WLR_ZoneEditor:close()
    self:setVisible(false)
    self:removeFromUIManager()
    WLR_ZoneEditor.instance = nil
end

-- Helper function for string trimming
if not string.trim then
    function string:trim()
        return self:match("^%s*(.-)%s*$")
    end
end