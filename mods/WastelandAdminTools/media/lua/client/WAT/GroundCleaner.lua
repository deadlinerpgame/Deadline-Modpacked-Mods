require "GroundHighlighter"
require "GravyUI"

WAT_GroundCleaner = ISPanel:derive("WAT_GroundCleaner")
WAT_GroundCleaner.instance = nil

function WAT_GroundCleaner:display()
    if WAT_GroundCleaner.instance then
        WAT_GroundCleaner.instance:close()
        return
    end
    WAT_GroundCleaner.instance = WAT_GroundCleaner:new(200, 200, 300, 300)
    WAT_GroundCleaner.instance:initialise()
    WAT_GroundCleaner.instance:addToUIManager()
    WAT_GroundCleaner.instance:setVisible(true)
end

function WAT_GroundCleaner:initialise()
    ISPanel.initialise(self)
    self:addToUIManager()
    self.moveWithMouse = true
    self.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self.backgroundColor = {r=0, g=0, b=0, a=1}
    self.groundHighlighter = GroundHighlighter:new()
    self.groundHighlighter:setColor(1.0, 0, 0, 1.0)
    self.groundHighlighter:enableXray(true, true)
    self.rangeX = 20
    self.rangeY = 20
    self.rangeMin = 5
    self.rangeMax = 50
    self.countItems = 0
    self.centerX = 0
    self.centerY = 0
    self.centerZ = 0
    self.seenItems = {}

    local window = GravyUI.Node(self.width, self.height):pad(2)
    local header, body, buttons = window:rows({20, 1, 30}, 5)
    local rangeXSlot, rangeYSlot, result, instructions, items = body:rows({15, 15, 15, 30, 1.0}, 5)
    local rangeXLabel, rangeXInput = rangeXSlot:cols({0.3, 0.7}, 2)
    local rangeYLabel, rangeYInput = rangeYSlot:cols({0.3, 0.7}, 2)
    local scanButton, cleanButton, pickupButton, toBagButton, cancelButton = buttons:cols(5, 5)

    self.headerLabel = header
    self.rangeXLabel = rangeXLabel
    self.rangeYLabel = rangeYLabel
    self.result = result
    self.instructions = instructions

    self.rangeXInput = rangeXInput:makeSlider(self, self.rangeXInputChange)
    self.rangeYInput = rangeYInput:makeSlider(self, self.rangeYInputChange)
    self.itemsBox = items:makeTextBox("")

    self.scanButton = scanButton:makeButton("Scan", self, self.scanButtonClick)
    self.cleanButton = cleanButton:makeButton("Clean", self, self.cleanButtonClick)
    self.pickupButton = pickupButton:makeButton("Pickup", self, self.pickupButtonClick)
    self.toBagButton = toBagButton:makeButton("To Bag", self, self.toBagButtonClick)
    self.cancelButton = cancelButton:makeButton("Cancel", self, self.close)

    self:addChild(self.rangeXInput)
    self:addChild(self.rangeYInput)
    self:addChild(self.itemsBox)
    self:addChild(self.scanButton)
    self:addChild(self.cleanButton)
    self:addChild(self.pickupButton)
    self:addChild(self.toBagButton)
    self:addChild(self.cancelButton)

    self.rangeXInput:setCurrentValue(self.rangeX)
    self.rangeYInput:setCurrentValue(self.rangeY)
    self.rangeXInput:setValues(self.rangeMin, self.rangeMax, 1, 5, false)
    self.rangeYInput:setValues(self.rangeMin, self.rangeMax, 1, 5, false)

    self.itemsBox:setMultipleLine(true)
    self.itemsBox:setEditable(true)
    self.itemsBox:setSelectable(true)
	self.itemsBox:addScrollBars()

    self:scanButtonClick()
end

function WAT_GroundCleaner:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    self:drawText("Ground Cleaner", self.headerLabel.left, self.headerLabel.top, 1, 1, 1, 1, UIFont.Medium)
    self:drawText("Range West/East", self.rangeXLabel.left, self.rangeXLabel.top, 1, 1, 1, 1, UIFont.Small)
    self:drawText("Range North/South", self.rangeYLabel.left, self.rangeYLabel.top, 1, 1, 1, 1, UIFont.Small)

    self:drawText("Items Found on Ground: " .. self.countItems, self.result.left, self.result.top, 1, 1, 1, 1, UIFont.Small)
    self:drawText("You can edit the list below.\nOnly items listed below will be removed or picked up.", self.instructions.left, self.instructions.top, 1, 1, 1, 1, UIFont.Small)
end

function WAT_GroundCleaner:getRange()
    return self.centerX - self.rangeX, self.centerY - self.rangeY,
           self.centerX + self.rangeX, self.centerY + self.rangeY
end

function WAT_GroundCleaner:postScan()
    local sx, sy, ex, ey = self:getRange()
    self.groundHighlighter:highlightSquare(sx, sy, ex, ey, self.centerZ)
    if self.countItems > 0 then
        local str = table.concat(self.seenItems, "\n")
        self.itemsBox:setText(str)
    else
        self.itemsBox:setText("")
    end
end

function WAT_GroundCleaner:close()
    self:setVisible(false)
    self:removeFromUIManager()
    WAT_GroundCleaner.instance = nil
end

function WAT_GroundCleaner:removeFromUIManager()
    self.groundHighlighter:remove()
    ISPanelJoypad.removeFromUIManager(self)
end

function WAT_GroundCleaner:rangeXInputChange()
    self.rangeX = self.rangeXInput:getCurrentValue()
end

function WAT_GroundCleaner:rangeYInputChange()
    self.rangeY = self.rangeYInput:getCurrentValue()
end

function WAT_GroundCleaner:scanButtonClick()
    self.countItems = 0
    self.centerX = math.floor(getPlayer():getX())
    self.centerY = math.floor(getPlayer():getY())
    self.centerZ = getPlayer():getZ()
    self.seenItems = {}
    local itemTypes = {}
    local sx, sy, ex, ey = self:getRange()
    for x = sx, ex do
        for y = sy, ey do
            local square = getCell():getGridSquare(x, y, self.centerZ)
            if square then
                local groundObjects = square:getWorldObjects()
                if groundObjects then
                    for i = 0, groundObjects:size() - 1 do
                        local object = groundObjects:get(i)
                        if object then
                            self.countItems = self.countItems + 1
                            local type = object:getItem():getFullType()
                            if not itemTypes[type] then itemTypes[type] = true end
                        end
                    end
                end
            end
        end
    end
    for type, _ in pairs(itemTypes) do
        table.insert(self.seenItems, type)
    end
    table.sort(self.seenItems)
    self.cleanButton:setEnable(self.countItems > 0)
    self.pickupButton:setEnable(self.countItems > 0)
    self:postScan()
end

function WAT_GroundCleaner:getItemsInBox()
    local items = self.itemsBox:getText():split("\n")
    local check = {}
    for _, item in ipairs(items) do
        check[item] = true
    end
    return check
end

function WAT_GroundCleaner:cleanButtonClick()
    local check = self:getItemsInBox()
    local sx, sy, ex, ey = self:getRange()
    for x = sx, ex do
        for y = sy, ey do
            local square = getCell():getGridSquare(x, y, self.centerZ)
            if square then
                local groundObjects = square:getWorldObjects()
                if groundObjects then
                    for i = groundObjects:size() - 1, 0, -1 do
                        local object = groundObjects:get(i)
                        if object and check[object:getItem():getFullType()] then
                            square:transmitRemoveItemFromSquare(object)
                        end
                    end
                end
            end
        end
    end
    self.countItems = 0
    self.centerX = 0
    self.centerY = 0
    self.centerZ = 0
    self:scanButtonClick()
end

-- pickup items in range and put in own inventory
function WAT_GroundCleaner:pickupButtonClick()
    local check = self:getItemsInBox()
    local playerInventory = getPlayer():getInventory()
    local sx, sy, ex, ey = self:getRange()
    for x = sx, ex do
        for y = sy, ey do
            local square = getCell():getGridSquare(x, y, self.centerZ)
            if square then
                local groundObjects = square:getWorldObjects()
                if groundObjects then
                    for i = groundObjects:size() - 1, 0, -1 do
                        local object = groundObjects:get(i)
                        if object and check[object:getItem():getFullType()] then
                            local item = object:getItem()
                            if item then
                                playerInventory:AddItem(item)
                                square:transmitRemoveItemFromSquare(object)
                            end
                        end
                    end
                end
            end
        end
    end
    self.countItems = 0
    self.centerX = 0
    self.centerY = 0
    self.centerZ = 0
    self:scanButtonClick()
end

-- pickup items in range and put into bag
function WAT_GroundCleaner:toBagButtonClick()
    local check = self:getItemsInBox()
    local playerInventory = getPlayer():getInventory()
    local bag = playerInventory:getFirstEval(function (x) return x:getName() == "Ground Cleaned Items" end)
    if not bag then
        bag = playerInventory:AddItem("Base.Bag_Schoolbag")
        bag:setName("Ground Cleaned Items")
        bag:setCustomName(true)
    end
    if not bag then
        self.result:setText("Unable to find or make a bag.")
        return
    end
    local sx, sy, ex, ey = self:getRange()
    for x = sx, ex do
        for y = sy, ey do
            local square = getCell():getGridSquare(x, y, self.centerZ)
            if square then
                local groundObjects = square:getWorldObjects()
                if groundObjects then
                    for i = groundObjects:size() - 1, 0, -1 do
                        local object = groundObjects:get(i)
                        if object and check[object:getItem():getFullType()] then
                            local item = object:getItem()
                            if item then
                                bag:getInventory():AddItem(item)
                                square:transmitRemoveItemFromSquare(object)
                            end
                        end
                    end
                end
            end
        end
    end
    self.countItems = 0
    self.centerX = 0
    self.centerY = 0
    self.centerZ = 0
    self:scanButtonClick()
end