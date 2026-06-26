require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"

WAT_LightbulbChanger = ISCollapsableWindow:derive("WAT_LightbulbChanger")
WAT_LightbulbChanger.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}

local BULB_TYPES = {
    "Base.LightBulb",
    "Base.LightBulbRed",
    "Base.LightBulbGreen",
    "Base.LightBulbBlue",
    "Base.LightBulbYellow",
    "Base.LightBulbCyan",
    "Base.LightBulbMagenta",
    "Base.LightBulbOrange",
    "Base.LightBulbPurple",
    "RemoteLightsController.LightBulbRGBRemoteControlled"
}

local BULB_NAMES = {
    ["Base.LightBulb"] = "White (Standard)",
    ["Base.LightBulbRed"] = "Red",
    ["Base.LightBulbGreen"] = "Green",
    ["Base.LightBulbBlue"] = "Blue",
    ["Base.LightBulbYellow"] = "Yellow",
    ["Base.LightBulbCyan"] = "Cyan",
    ["Base.LightBulbMagenta"] = "Magenta",
    ["Base.LightBulbOrange"] = "Orange",
    ["Base.LightBulbPurple"] = "Purple",
    ["RemoteLightsController.LightBulbRGBRemoteControlled"] = "RGB Remote Controlled"
}

--- @return WAT_LightbulbChanger
function WAT_LightbulbChanger.display()
    if WAT_LightbulbChanger.instance then
        WAT_LightbulbChanger.instance:setVisible(true)
        WAT_LightbulbChanger.instance:bringToTop()
        return WAT_LightbulbChanger.instance
    end

    local scale = FONT_HGT_SMALL / 12
    local w = 350 * scale
    local h = 280 * scale
    local o = WAT_LightbulbChanger:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_LightbulbChanger.instance = o
    return o
end

--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WAT_LightbulbChanger
function WAT_LightbulbChanger:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Lightbulb Changer"
    o.scale = FONT_HGT_SMALL / 12

    return o
end

function WAT_LightbulbChanger:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local player = getPlayer()

    local win = GravyUI.Node(self.width, self.height, self):pad(self.scale * 10, self.scale * 30, self.scale * 10, self.scale * 10)
    local stack = win:makeVerticalStack(self.scale * 8)

    local headerRow = stack:makeNode(FONT_HGT_MEDIUM)
    headerRow:makeLabel("Lightbulb Changer", UIFont.Medium, COLOR_WHITE, "center")

    local instructionRow = stack:makeNode(self.scale * 30)
    instructionRow:makeLabel("Select an area and choose a bulb type to replace all bulbs in light fixtures.", UIFont.Small, COLOR_WHITE, "left")

    local bulbTypeRow = stack:makeNode(self.scale * 25)
    local bulbTypeLabel, bulbTypeCombo = bulbTypeRow:cols({0.35, 0.65}, self.scale * 5)
    bulbTypeLabel:makeLabel("Bulb Type:", UIFont.Small, COLOR_WHITE, "right")
    self.bulbTypeCombo = bulbTypeCombo:makeComboBox()
    
    for _, bulbType in ipairs(BULB_TYPES) do
        local displayName = BULB_NAMES[bulbType] or bulbType
        self.bulbTypeCombo:addOption(displayName)
    end

    local areaLabel = stack:makeNode(self.scale * 18)
    areaLabel:makeLabel("Select Area:", UIFont.Small, COLOR_WHITE, "left")

    local areaPickerRow = stack:makeNode(self.scale * 60)
    self.areaPicker = areaPickerRow:makeAreaPicker()
    self.areaPicker:setColor(1, 1, 0, 1)
    self.areaPicker:setValue({
        x1 = math.floor(player:getX() - 5),
        y1 = math.floor(player:getY() - 5),
        z1 = math.floor(player:getZ()),
        x2 = math.floor(player:getX() + 5),
        y2 = math.floor(player:getY() + 5),
        z2 = math.floor(player:getZ())
    })

    local statusRow = stack:makeNode(self.scale * 25)
    self.statusLabel = statusRow:makeLabel("Ready", UIFont.Small, COLOR_WHITE, "center")

    local buttonRow = stack:makeNode(self.scale * 35)
    local changeBtn, closeBtn = buttonRow:cols(2, self.scale * 10)
    self.changeButton = changeBtn:makeButton("Change Bulbs", self, self.onChangeBulbs)
    self.changeButton.backgroundColor = {r=0, g=0.5, b=0, a=1}
    self.closeButton = closeBtn:makeButton("Close", self, self.close)

    local buffer = stack:makeNode(self.scale * 25)
end

--- @return string
function WAT_LightbulbChanger:getSelectedBulbType()
    local selectedIndex = self.bulbTypeCombo.selected
    return BULB_TYPES[selectedIndex]
end

--- @return table
function WAT_LightbulbChanger:findLightSources()
    local area = self.areaPicker:getValue()
    local lights = {}
    
    for x = area.x1, area.x2 do
        for y = area.y1, area.y2 do
            for z = area.z1, area.z2 do
                local square = getCell():getGridSquare(x, y, z)
                if square then
                    local objects = square:getObjects()
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        
                        -- Check for light switches
                        if instanceof(obj, "IsoLightSwitch") then
                            table.insert(lights, {
                                type = "switch",
                                object = obj,
                                square = square,
                                x = x,
                                y = y,
                                z = z
                            })
                        -- Check for lamps and other light fixtures (IsoThumpable with light properties)
                        elseif instanceof(obj, "IsoThumpable") then
                            local sprite = obj:getSprite()
                            if sprite then
                                local props = sprite:getProperties()
                                -- Check if it's a light fixture
                                if props and (props:Is("IsLamp") or props:Is("LightSource")) then
                                    table.insert(lights, {
                                        type = "lamp",
                                        object = obj,
                                        square = square,
                                        x = x,
                                        y = y,
                                        z = z
                                    })
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return lights
end

--- @param lightData table The light object data
--- @param newBulbType string The new bulb type
function WAT_LightbulbChanger:changeBulb(lightData, newBulbType)
    local obj = lightData.object
    local player = getPlayer()
    
    if not obj:getCanBeModified() then
        return false
    end
    
    local newBulb = InventoryItemFactory.CreateItem(newBulbType)
    if not newBulb then
        return false
    end
    
    if obj:hasLightBulb() then
        obj:removeLightBulb(player)
    end
    
    obj:addLightBulb(player, newBulb)
    
    return true
end

function WAT_LightbulbChanger:onChangeBulbs()
    local bulbType = self:getSelectedBulbType()
    if not bulbType then
        self:setStatus("Error: No bulb type selected", COLOR_RED)
        return
    end

    self:setStatus("Scanning for lights...", COLOR_YELLOW)
    
    local lights = self:findLightSources()
    
    if #lights == 0 then
        self:setStatus("No light sources found in area", COLOR_YELLOW)
        return
    end

    local changedCount = 0
    for _, lightData in ipairs(lights) do
        if self:changeBulb(lightData, bulbType) then
            changedCount = changedCount + 1
        end
    end

    local bulbName = BULB_NAMES[bulbType] or bulbType
    self:setStatus(string.format("Changed %d bulbs to %s", changedCount, bulbName), COLOR_GREEN)
end

--- @param text string
--- @param color table|nil
function WAT_LightbulbChanger:setStatus(text, color)
    self.statusLabel:setText(text)
    if color then
        self.statusLabel.color = color
    end
end

function WAT_LightbulbChanger:cleanup()
    if self.areaPicker then
        self.areaPicker:cleanup()
    end
end

function WAT_LightbulbChanger:close()
    self:cleanup()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_LightbulbChanger.instance = nil
end
