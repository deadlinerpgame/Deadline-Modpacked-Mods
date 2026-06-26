require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"

---@class WAT_BasementEditor : ISCollapsableWindow
---@field instance WAT_BasementEditor|nil
WAT_BasementEditor = ISCollapsableWindow:derive("WAT_BasementEditor")
WAT_BasementEditor.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
    return px * SCALE
end

--- Shows the Basement Editor window
--- @param basement table|nil The basement to edit (optional)
--- @return WAT_BasementEditor
function WAT_BasementEditor.show(basement)
    if WAT_BasementEditor.instance then
        WAT_BasementEditor.instance:setVisible(true)
        if basement then
            WAT_BasementEditor.instance:loadBasement(basement)
        end
        return WAT_BasementEditor.instance
    end

    local w = scale(500)
    local h = scale(600)
    local o = WAT_BasementEditor:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_BasementEditor.instance = o

    if basement then
        o:loadBasement(basement)
    end

    return o
end

--- Constructor
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WAT_BasementEditor
function WAT_BasementEditor:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Edit Basement"

    -- Current basement being edited
    o.basement = nil
    o.originalBasement = nil  -- For detecting changes

    return o
end

--- Initialize the UI
function WAT_BasementEditor:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local win = GravyUI.Node(self.width, self.height, self):pad(scale(10), scale(30), scale(10), scale(10))
    local stack = win:makeVerticalStack(scale(5))

    -- Name input
    local nameRow = stack:makeNode(scale(22))
    local nameLabel, nameInput = nameRow:cols({0.25, 0.75}, scale(5))
    nameLabel:makeLabel("Name:", UIFont.Small, COLOR_WHITE, "right")
    self.nameTextBox = nameInput:makeTextBox("", false)

    stack:makeNode(scale(10))  -- Spacer

    -- House Side Section
    local houseSideLabel = stack:makeNode(scale(18))
    houseSideLabel:makeLabel("House Side", UIFont.Medium, COLOR_YELLOW, "left")

    -- Entrance Point (outX1, outY1, outZ1) - where player steps to go IN
    local entranceLabel = stack:makeNode(scale(16))
    entranceLabel:makeLabel("Entrance (step here to enter basement):", UIFont.Small, COLOR_WHITE, "left")

    local entrancePickerRow = stack:makeNode(scale(45))
    self.entrancePointPicker = entrancePickerRow:makePointPicker()
    self.entrancePointPicker:setColor(0, 1, 0, 1)
    self.entrancePointPicker:setPriority(4)
    self.entrancePointPicker.showAlways = true

    local entranceButtonRow = stack:makeNode(scale(22))
    local setEntranceBtn, tpEntranceBtn = entranceButtonRow:cols(2, scale(5))
    self.setEntranceButton = setEntranceBtn:makeButton("Set to Current", self, self.setEntranceToCurrent)
    self.tpEntranceButton = tpEntranceBtn:makeButton("Teleport", self, self.teleportToEntrance)

    -- Return Point (inX2, inY2, inZ2) - where player appears when leaving basement
    local returnLabel = stack:makeNode(scale(16))
    returnLabel:makeLabel("Return Point (appear here when leaving):", UIFont.Small, COLOR_WHITE, "left")

    local returnPickerRow = stack:makeNode(scale(45))
    self.returnPointPicker = returnPickerRow:makePointPicker()
    self.returnPointPicker:setColor(1, 0.5, 0, 1)
    self.returnPointPicker:setPriority(3)
    self.returnPointPicker.showAlways = true

    local returnButtonRow = stack:makeNode(scale(22))
    local setReturnBtn, tpReturnBtn = returnButtonRow:cols(2, scale(5))
    self.setReturnButton = setReturnBtn:makeButton("Set to Current", self, self.setReturnToCurrent)
    self.tpReturnButton = tpReturnBtn:makeButton("Teleport", self, self.teleportToReturn)

    stack:makeNode(scale(10))  -- Spacer

    -- Basement Side Section
    local basementSideLabel = stack:makeNode(scale(18))
    basementSideLabel:makeLabel("Basement Side", UIFont.Medium, COLOR_YELLOW, "left")

    -- Arrival Point (inX1, inY1, inZ1) - where player appears IN basement
    local arrivalLabel = stack:makeNode(scale(16))
    arrivalLabel:makeLabel("Arrival Point (appear here in basement):", UIFont.Small, COLOR_WHITE, "left")

    local arrivalPickerRow = stack:makeNode(scale(45))
    self.arrivalPointPicker = arrivalPickerRow:makePointPicker()
    self.arrivalPointPicker:setColor(0, 0.5, 1, 1)
    self.arrivalPointPicker:setPriority(2)
    self.arrivalPointPicker.showAlways = true

    local arrivalButtonRow = stack:makeNode(scale(22))
    local setArrivalBtn, tpArrivalBtn = arrivalButtonRow:cols(2, scale(5))
    self.setArrivalButton = setArrivalBtn:makeButton("Set to Current", self, self.setArrivalToCurrent)
    self.tpArrivalButton = tpArrivalBtn:makeButton("Teleport", self, self.teleportToArrival)

    -- Exit Point (outX2, outY2, outZ2) - where player steps to EXIT basement
    local exitLabel = stack:makeNode(scale(16))
    exitLabel:makeLabel("Exit Point (step here to leave basement):", UIFont.Small, COLOR_WHITE, "left")

    local exitPickerRow = stack:makeNode(scale(45))
    self.exitPointPicker = exitPickerRow:makePointPicker()
    self.exitPointPicker:setColor(1, 0, 0, 1)
    self.exitPointPicker:setPriority(1)
    self.exitPointPicker.showAlways = true

    local exitButtonRow = stack:makeNode(scale(22))
    local setExitBtn, tpExitBtn = exitButtonRow:cols(2, scale(5))
    self.setExitButton = setExitBtn:makeButton("Set to Current", self, self.setExitToCurrent)
    self.tpExitButton = tpExitBtn:makeButton("Teleport", self, self.teleportToExit)

    stack:makeNode(scale(10))  -- Spacer

    -- Status label
    local statusRow = stack:makeNode(scale(18))
    self.statusLabel = statusRow:makeLabel("Status: No basement loaded", UIFont.Small, COLOR_WHITE, "center")

    -- Action buttons
    local actionRow = stack:makeNode(scale(30))
    local saveBtn, cancelBtn = actionRow:cols(2, scale(10))
    self.saveButton = saveBtn:makeButton("Save Changes", self, self.onSaveChanges)
    self.cancelButton = cancelBtn:makeButton("Close", self, self.close)

    -- Initial state
    self:updateButtonStates(false)
end

--- Loads a basement into the editor
--- @param basement table
function WAT_BasementEditor:loadBasement(basement)
    self.basement = {
        key = basement.key,
        name = basement.name,
        templateId = basement.templateId,
        outX1 = basement.outX1,
        outY1 = basement.outY1,
        outZ1 = basement.outZ1,
        inX1 = basement.inX1,
        inY1 = basement.inY1,
        inZ1 = basement.inZ1,
        outX2 = basement.outX2,
        outY2 = basement.outY2,
        outZ2 = basement.outZ2,
        inX2 = basement.inX2,
        inY2 = basement.inY2,
        inZ2 = basement.inZ2
    }

    -- Store original for comparison
    self.originalBasement = {
        key = basement.key,
        name = basement.name,
        templateId = basement.templateId,
        outX1 = basement.outX1,
        outY1 = basement.outY1,
        outZ1 = basement.outZ1,
        inX1 = basement.inX1,
        inY1 = basement.inY1,
        inZ1 = basement.inZ1,
        outX2 = basement.outX2,
        outY2 = basement.outY2,
        outZ2 = basement.outZ2,
        inX2 = basement.inX2,
        inY2 = basement.inY2,
        inZ2 = basement.inZ2
    }

    -- Populate UI
    self.nameTextBox:setText(basement.name or "")

    -- House side points
    self.entrancePointPicker:setValue({
        x = basement.outX1 or 0,
        y = basement.outY1 or 0,
        z = basement.outZ1 or 0
    })

    self.returnPointPicker:setValue({
        x = basement.inX2 or 0,
        y = basement.inY2 or 0,
        z = basement.inZ2 or 0
    })

    -- Basement side points
    self.arrivalPointPicker:setValue({
        x = basement.inX1 or 0,
        y = basement.inY1 or 0,
        z = basement.inZ1 or 0
    })

    self.exitPointPicker:setValue({
        x = basement.outX2 or 0,
        y = basement.outY2 or 0,
        z = basement.outZ2 or 0
    })

    self.title = "Edit Basement: " .. (basement.name or basement.key)
    self:setStatus("Loaded: " .. (basement.name or basement.key), COLOR_GREEN)
    self:updateButtonStates(true)
end

--- Updates button enabled states
--- @param hasBasement boolean
function WAT_BasementEditor:updateButtonStates(hasBasement)
    self.saveButton:setEnable(hasBasement)
    self.setEntranceButton:setEnable(hasBasement)
    self.tpEntranceButton:setEnable(hasBasement)
    self.setReturnButton:setEnable(hasBasement)
    self.tpReturnButton:setEnable(hasBasement)
    self.setArrivalButton:setEnable(hasBasement)
    self.tpArrivalButton:setEnable(hasBasement)
    self.setExitButton:setEnable(hasBasement)
    self.tpExitButton:setEnable(hasBasement)
    self.nameTextBox:setEditable(hasBasement)
end

--- Sets the status label text and color
--- @param text string
--- @param color table|nil
function WAT_BasementEditor:setStatus(text, color)
    self.statusLabel:setText("Status: " .. text)
    if color then
        self.statusLabel.textColor = color
    end
end

-- House Side Point Methods

--- Sets entrance point to player's current position
function WAT_BasementEditor:setEntranceToCurrent()
    local player = getPlayer()
    self.entrancePointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:setStatus("Entrance point updated", COLOR_YELLOW)
end

--- Teleports to entrance point
function WAT_BasementEditor:teleportToEntrance()
    local point = self.entrancePointPicker:getValue()
    if point.x ~= 0 or point.y ~= 0 or point.z ~= 0 then
        WL_Utils.teleportPlayerToCoords(getPlayer(), point.x, point.y, point.z)
    end
end

--- Sets return point to player's current position
function WAT_BasementEditor:setReturnToCurrent()
    local player = getPlayer()
    self.returnPointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:setStatus("Return point updated", COLOR_YELLOW)
end

--- Teleports to return point
function WAT_BasementEditor:teleportToReturn()
    local point = self.returnPointPicker:getValue()
    if point.x ~= 0 or point.y ~= 0 or point.z ~= 0 then
        WL_Utils.teleportPlayerToCoords(getPlayer(), point.x, point.y, point.z)
    end
end

-- Basement Side Point Methods

--- Sets arrival point to player's current position
function WAT_BasementEditor:setArrivalToCurrent()
    local player = getPlayer()
    self.arrivalPointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:setStatus("Arrival point updated", COLOR_YELLOW)
end

--- Teleports to arrival point
function WAT_BasementEditor:teleportToArrival()
    local point = self.arrivalPointPicker:getValue()
    if point.x ~= 0 or point.y ~= 0 or point.z ~= 0 then
        WL_Utils.teleportPlayerToCoords(getPlayer(), point.x, point.y, point.z)
    end
end

--- Sets exit point to player's current position
function WAT_BasementEditor:setExitToCurrent()
    local player = getPlayer()
    self.exitPointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:setStatus("Exit point updated", COLOR_YELLOW)
end

--- Teleports to exit point
function WAT_BasementEditor:teleportToExit()
    local point = self.exitPointPicker:getValue()
    if point.x ~= 0 or point.y ~= 0 or point.z ~= 0 then
        WL_Utils.teleportPlayerToCoords(getPlayer(), point.x, point.y, point.z)
    end
end

--- Called when Save Changes button is clicked
function WAT_BasementEditor:onSaveChanges()
    if not self.basement then
        self:setStatus("No basement loaded", COLOR_RED)
        return
    end

    -- Get values from UI
    local entrancePoint = self.entrancePointPicker:getValue()
    local returnPoint = self.returnPointPicker:getValue()
    local arrivalPoint = self.arrivalPointPicker:getValue()
    local exitPoint = self.exitPointPicker:getValue()

    -- Build update data
    local updateData = {
        key = self.basement.key,
        name = self.nameTextBox:getText() or nil,
        -- House entrance (where player steps to go IN)
        outX1 = entrancePoint.x,
        outY1 = entrancePoint.y,
        outZ1 = entrancePoint.z,
        -- Basement arrival (where player appears IN basement)
        inX1 = arrivalPoint.x,
        inY1 = arrivalPoint.y,
        inZ1 = arrivalPoint.z,
        -- Basement exit (where player steps to go OUT)
        outX2 = exitPoint.x,
        outY2 = exitPoint.y,
        outZ2 = exitPoint.z,
        -- House arrival (where player appears back in house)
        inX2 = returnPoint.x,
        inY2 = returnPoint.y,
        inZ2 = returnPoint.z
    }

    -- Send update to server
    sendClientCommand(getPlayer(), "WAT", "updateBasement", updateData)

    self:setStatus("Saving changes...", COLOR_YELLOW)

    -- Update local data
    self.basement.name = updateData.name
    self.basement.outX1 = updateData.outX1
    self.basement.outY1 = updateData.outY1
    self.basement.outZ1 = updateData.outZ1
    self.basement.inX1 = updateData.inX1
    self.basement.inY1 = updateData.inY1
    self.basement.inZ1 = updateData.inZ1
    self.basement.outX2 = updateData.outX2
    self.basement.outY2 = updateData.outY2
    self.basement.outZ2 = updateData.outZ2
    self.basement.inX2 = updateData.inX2
    self.basement.inY2 = updateData.inY2
    self.basement.inZ2 = updateData.inZ2

    -- Update title
    self.title = "Edit Basement: " .. (updateData.name or self.basement.key)

    -- Show success after a short delay
    self.saveSuccessDelay = 10
end

--- Cleans up area pickers
function WAT_BasementEditor:cleanup()
    if self.entrancePointPicker then
        self.entrancePointPicker:cleanup()
    end
    if self.returnPointPicker then
        self.returnPointPicker:cleanup()
    end
    if self.arrivalPointPicker then
        self.arrivalPointPicker:cleanup()
    end
    if self.exitPointPicker then
        self.exitPointPicker:cleanup()
    end
end

--- Prerender
function WAT_BasementEditor:prerender()
    ISCollapsableWindow.prerender(self)

    -- Handle save success delay
    if self.saveSuccessDelay then
        self.saveSuccessDelay = self.saveSuccessDelay - 1
        if self.saveSuccessDelay <= 0 then
            self.saveSuccessDelay = nil
            self:setStatus("Changes saved!", COLOR_GREEN)
        end
    end
end

--- Close the window
function WAT_BasementEditor:close()
    self:cleanup()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_BasementEditor.instance = nil
end