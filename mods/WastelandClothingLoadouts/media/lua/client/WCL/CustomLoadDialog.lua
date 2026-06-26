require "ISUI/ISPanel"

-- ============================================================================
-- WCL_CustomLoadDialog
-- A dialog for customizing loadout restore options
-- ============================================================================

WCL_CustomLoadDialog = ISPanel:derive("WCL_CustomLoadDialog")

--- Create a new custom load dialog
--- @param x number X position
--- @param y number Y position
--- @param width number Dialog width
--- @param height number Dialog height
--- @param loadoutName string Name of the loadout to load
--- @param onConfirm function Callback function(options) when GO is clicked
function WCL_CustomLoadDialog:new(x, y, width, height, loadoutName, onConfirm)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.loadoutName = loadoutName
    o.onConfirm = onConfirm
    o.backgroundColor = {r=0, g=0, b=0, a=0.8}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.moveWithMouse = true
    
    -- Option names in order (matches index in tickbox)
    o.optionNames = {
        "removeItems",
        "restoreOutfit",
        "restoreItems",
        "restoreIdentity",
        "restoreHair"
    }
    
    -- Default all options to true
    o.options = {
        removeItems = true,
        restoreOutfit = true,
        restoreItems = true,
        restoreIdentity = true,
        restoreHair = true
    }
    
    return o
end

function WCL_CustomLoadDialog:initialise()
    ISPanel.initialise(self)
end

function WCL_CustomLoadDialog:createChildren()
    ISPanel.createChildren(self)
    
    local padding = 10
    local yOffset = 40
    local checkboxHeight = 130
    
    -- Title label
    self.titleLabel = ISLabel:new(padding, padding, 30, 'Load "' .. self.loadoutName .. '"', 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    
    -- Create single tickbox with all options
    self.optionsTickBox = ISTickBox:new(padding, yOffset, 200, checkboxHeight, "", self, WCL_CustomLoadDialog.onTickBoxChange)
    self.optionsTickBox:initialise()
    self.optionsTickBox:addOption("Remove Items")
    self.optionsTickBox:addOption("Restore Outfit")
    self.optionsTickBox:addOption("Restore Items")
    self.optionsTickBox:addOption("Restore Identity")
    self.optionsTickBox:addOption("Restore Hair")
    
    -- Set all options to selected by default
    for i = 1, #self.optionNames do
        self.optionsTickBox:setSelected(i, self.options[self.optionNames[i]])
    end
    
    self:addChild(self.optionsTickBox)
    yOffset = yOffset + checkboxHeight + 10
    
    -- Buttons
    local buttonWidth = 80
    local buttonHeight = 25
    local buttonY = yOffset
    local totalButtonWidth = buttonWidth * 2 + 10
    local buttonStartX = (self.width - totalButtonWidth) / 2
    
    self.goButton = ISButton:new(buttonStartX, buttonY, buttonWidth, buttonHeight, "GO", self, WCL_CustomLoadDialog.onGo)
    self.goButton:initialise()
    self.goButton.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.goButton)
    
    self.cancelButton = ISButton:new(buttonStartX + buttonWidth + 10, buttonY, buttonWidth, buttonHeight, "Cancel", self, WCL_CustomLoadDialog.onCancel)
    self.cancelButton:initialise()
    self.cancelButton.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.cancelButton)
end

function WCL_CustomLoadDialog:onTickBoxChange(index, selected)
    -- Update the corresponding option based on index
    if index >= 1 and index <= #self.optionNames then
        local optionName = self.optionNames[index]
        self.options[optionName] = selected
    end
end

function WCL_CustomLoadDialog:onGo()
    if self.onConfirm then
        self.onConfirm(self.options)
    end
    self:close()
end

function WCL_CustomLoadDialog:onCancel()
    self:close()
end

function WCL_CustomLoadDialog:close()
    self:setVisible(false)
    self:removeFromUIManager()
end

--- Static method to show the dialog
--- @param loadoutName string Name of the loadout
--- @param onConfirm function Callback when GO is clicked
function WCL_CustomLoadDialog.show(loadoutName, onConfirm)
    local width = 300
    local height = 230
    local x = (getCore():getScreenWidth() - width) / 2
    local y = (getCore():getScreenHeight() - height) / 2
    
    local dialog = WCL_CustomLoadDialog:new(x, y, width, height, loadoutName, onConfirm)
    dialog:initialise()
    dialog:addToUIManager()
    dialog:setAlwaysOnTop(true)
    
    return dialog
end