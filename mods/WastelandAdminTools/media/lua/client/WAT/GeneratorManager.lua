require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"
require "WL_Utils"

WAT_GeneratorManager = ISCollapsableWindow:derive("WAT_GeneratorManager")
WAT_GeneratorManager.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}

local GEN_SPACING_X = 34
local GEN_SPACING_Y = 30
local GEN_OFFSET_X = 17
local GEN_SEARCH_RADIUS = 200

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
    return px * SCALE
end

function WAT_GeneratorManager.show()
    if WAT_GeneratorManager.instance then
        WAT_GeneratorManager.instance:setVisible(true)
        return WAT_GeneratorManager.instance
    end

    local w = scale(300)
    local h = scale(350)
    local o = WAT_GeneratorManager:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_GeneratorManager.instance = o
    return o
end

function WAT_GeneratorManager:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Generator Manager"
    
    o.startPoint = nil
    o.width = width
    o.height = height
    
    o.executionState = {
        isRunning = false,
        queue = {},
        currentIdx = 1,
        action = nil, -- "PLACE", "TOGGLE_ON", "TOGGLE_OFF"
        step = nil, -- "TELEPORT", "WAIT_LOAD", "PLACE_FLOOR", "WAIT_FLOOR", "PLACE_GEN", "TOGGLE"
        delay = 0
    }

    return o
end

function WAT_GeneratorManager:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local win = GravyUI.Node(self.width, self.height, self):pad(scale(10), scale(30), scale(10), scale(10))
    local stack = win:makeVerticalStack(scale(8))

    -- Start Point Picker
    local startLabel = stack:makeNode(scale(18))
    startLabel:makeLabel("Start Point (Top Left):", UIFont.Small, COLOR_WHITE, "left")

    local startPickerRow = stack:makeNode(scale(60))
    self.startPointPicker = startPickerRow:makePointPicker()
    self.startPointPicker:setColor(0, 1, 1, 1)
    self.startPointPicker.showAlways = true
    self.startPointPicker:setEndPickingCallback(self.updateButtonsState, self)

    local startButtonRow = stack:makeNode(scale(25))
    local setBtnNode, autoBtnNode = startButtonRow:cols(2, scale(5))
    self.setStartButton = setBtnNode:makeButton("Set to Current Position", self, self.setStartToCurrent)
    self.autoStartButton = autoBtnNode:makeButton("Auto-Detect Top-Left", self, self.setStartToTopLeft)

    -- Dimensions
    local dimRow = stack:makeNode(scale(25))
    local wLabel, wInput, hLabel, hInput = dimRow:cols({0.2, 0.3, 0.2, 0.3}, scale(5))
    
    wLabel:makeLabel("Width:", UIFont.Small, COLOR_WHITE, "right")
    self.widthBox = wInput:makeTextBox("100", true)
    self.widthBox.onTextChange = function() self:updateButtonsState() end
    
    hLabel:makeLabel("Height:", UIFont.Small, COLOR_WHITE, "right")
    self.heightBox = hInput:makeTextBox("100", true)
    self.heightBox.onTextChange = function() self:updateButtonsState() end

    -- Status label
    local statusRow = stack:makeNode(scale(25))
    self.statusLabel = statusRow:makeLabel("Status: Ready", UIFont.Small, COLOR_WHITE, "center")

    -- Action buttons
    local actionRow = stack:makeNode(scale(35))
    local placeBtn, toggleOnBtn, toggleOffBtn = actionRow:cols(3, scale(5))
    
    self.placeButton = placeBtn:makeButton("Place", self, function() self:onAction("PLACE") end)
    self.toggleOnButton = toggleOnBtn:makeButton("Toggle On", self, function() self:onAction("TOGGLE_ON") end)
    self.toggleOffButton = toggleOffBtn:makeButton("Toggle Off", self, function() self:onAction("TOGGLE_OFF") end)

    local closeRow = stack:makeNode(scale(35))
    self.closeButton = closeRow:makeButton("Close", self, self.close)

    self:updateButtonsState()
end

function WAT_GeneratorManager:setStartToCurrent()
    local player = getPlayer()
    self.startPointPicker:setValue({
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    })
    self:updateButtonsState()
end

function WAT_GeneratorManager:getSearchOrigin()
    local startPoint = self.startPointPicker:getValue()
    local hasStart = not (startPoint.x == 0 and startPoint.y == 0 and startPoint.z == 0)
    if hasStart then
        return startPoint
    end

    local player = getPlayer()
    return {
        x = math.floor(player:getX()),
        y = math.floor(player:getY()),
        z = math.floor(player:getZ())
    }
end

function WAT_GeneratorManager:hasGeneratorAt(x, y, z)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then
        return false
    end

    for i=0, sq:getObjects():size()-1 do
        local obj = sq:getObjects():get(i)
        if instanceof(obj, "IsoGenerator") then
            return true
        end
    end

    return false
end

function WAT_GeneratorManager:findNearestGenerator(origin, maxRadius)
    local z = origin.z
    local ox = origin.x
    local oy = origin.y

    if self:hasGeneratorAt(ox, oy, z) then
        return {x = ox, y = oy, z = z}
    end

    for r=1, maxRadius do
        local minX = ox - r
        local maxX = ox + r
        local minY = oy - r
        local maxY = oy + r

        for x=minX, maxX do
            if self:hasGeneratorAt(x, minY, z) then
                return {x = x, y = minY, z = z}
            end
            if self:hasGeneratorAt(x, maxY, z) then
                return {x = x, y = maxY, z = z}
            end
        end

        for y=minY + 1, maxY - 1 do
            if self:hasGeneratorAt(minX, y, z) then
                return {x = minX, y = y, z = z}
            end
            if self:hasGeneratorAt(maxX, y, z) then
                return {x = maxX, y = y, z = z}
            end
        end
    end

    return nil
end

function WAT_GeneratorManager:collectGeneratorCluster(seed)
    local queue = {seed}
    local results = {seed}
    local seen = {}
    local seedKey = seed.x .. ":" .. seed.y .. ":" .. seed.z
    seen[seedKey] = true

    local idx = 1
    while idx <= #queue do
        local pos = queue[idx]
        idx = idx + 1

        local neighbors = {
            {x = pos.x + GEN_SPACING_X, y = pos.y},
            {x = pos.x - GEN_SPACING_X, y = pos.y},
            {x = pos.x + GEN_OFFSET_X, y = pos.y + GEN_SPACING_Y},
            {x = pos.x - GEN_OFFSET_X, y = pos.y + GEN_SPACING_Y},
            {x = pos.x + GEN_OFFSET_X, y = pos.y - GEN_SPACING_Y},
            {x = pos.x - GEN_OFFSET_X, y = pos.y - GEN_SPACING_Y}
        }

        for _, n in ipairs(neighbors) do
            local key = n.x .. ":" .. n.y .. ":" .. pos.z
            if not seen[key] and self:hasGeneratorAt(n.x, n.y, pos.z) then
                seen[key] = true
                local genPos = {x = n.x, y = n.y, z = pos.z}
                table.insert(queue, genPos)
                table.insert(results, genPos)
            end
        end
    end

    return results
end

function WAT_GeneratorManager:findTopLeftGenerator(origin)
    local seed = self:findNearestGenerator(origin, GEN_SEARCH_RADIUS)
    if not seed then
        return nil, nil
    end

    local cluster = self:collectGeneratorCluster(seed)
    local topLeft = cluster[1]

    for i=2, #cluster do
        local pos = cluster[i]
        if pos.y < topLeft.y or (pos.y == topLeft.y and pos.x < topLeft.x) then
            topLeft = pos
        end
    end

    return topLeft, cluster
end

function WAT_GeneratorManager:sortGeneratorPositions(positions)
    table.sort(positions, function(a, b)
        if a.y == b.y then
            return a.x < b.x
        end
        return a.y < b.y
    end)
    return positions
end

function WAT_GeneratorManager:setStartToTopLeft()
    local origin = self:getSearchOrigin()
    local topLeft = self:findTopLeftGenerator(origin)
    if not topLeft then
        self:setStatus("No generator found", COLOR_RED)
        return
    end

    self.startPointPicker:setValue(topLeft)
    self:setStatus("Top-left generator aligned", COLOR_GREEN)
    self:updateButtonsState()
end

function WAT_GeneratorManager:updateButtonsState()
    local startPoint = self.startPointPicker:getValue()
    local hasStart = not (startPoint.x == 0 and startPoint.y == 0 and startPoint.z == 0)
    local notRunning = not self.executionState.isRunning
    
    local w = tonumber(self.widthBox:getText())
    local h = tonumber(self.heightBox:getText())
    local validDims = w and h and w > 0 and h > 0

    local placeEnabled = hasStart and notRunning and validDims
    local toggleEnabled = notRunning

    self.placeButton:setEnable(placeEnabled)
    self.toggleOnButton:setEnable(toggleEnabled)
    self.toggleOffButton:setEnable(toggleEnabled)
end

function WAT_GeneratorManager:setStatus(text, color)
    self.statusLabel:setText("Status: " .. text)
    if color then
        self.statusLabel.textColor = color
    end
end

function WAT_GeneratorManager:onAction(action)
    if action == "PLACE" then
        local startPoint = self.startPointPicker:getValue()
        local w = tonumber(self.widthBox:getText())
        local h = tonumber(self.heightBox:getText())

        self.executionState.isRunning = true
        self.executionState.action = action
        self.executionState.queue = self:calculatePositions(startPoint, w, h)
        self.executionState.currentIdx = 1
        self.executionState.step = "TELEPORT"
        self.executionState.delay = 0

        self:setStatus("Starting " .. action .. "...", COLOR_YELLOW)
        self:updateButtonsState()
        return
    end

    local origin = self:getSearchOrigin()
    local topLeft, cluster = self:findTopLeftGenerator(origin)
    if not topLeft then
        self.executionState.isRunning = false
        self:setStatus("No generator found", COLOR_RED)
        self:updateButtonsState()
        return
    end

    self.startPointPicker:setValue(topLeft)
    self.executionState.isRunning = true
    self.executionState.action = action
    self.executionState.queue = self:sortGeneratorPositions(cluster)
    self.executionState.currentIdx = 1
    self.executionState.step = "TELEPORT"
    self.executionState.delay = 0

    self:setStatus("Starting " .. action .. "...", COLOR_YELLOW)
    self:updateButtonsState()
end

function WAT_GeneratorManager:calculatePositions(startPoint, w, h)
    local positions = {}
    local startX = startPoint.x
    local startY = startPoint.y
    local z = startPoint.z
    
    -- Rows every 30 tiles
    -- Even rows start at 0 every 34
    -- Odd rows offset by 17 every 34
    
    local y = 0
    local rowIndex = 0
    while y <= h do
        local xOffset = (rowIndex % 2 == 0) and 0 or GEN_OFFSET_X
        local x = xOffset
        while x <= w do
            table.insert(positions, {x = startX + x, y = startY + y, z = z})
            x = x + GEN_SPACING_X
        end
        y = y + GEN_SPACING_Y
        rowIndex = rowIndex + 1
    end
    
    return positions
end

function WAT_GeneratorManager:prerender()
    ISCollapsableWindow.prerender(self)
    
    if self.executionState.isRunning then
        if self.executionState.delay > 0 then
            self.executionState.delay = self.executionState.delay - 1
            return
        end
        
        self:processQueue()
    end
end

function WAT_GeneratorManager:processQueue()
    local idx = self.executionState.currentIdx
    local queue = self.executionState.queue
    
    if idx > #queue then
        self.executionState.isRunning = false
        self:setStatus("Complete!", COLOR_GREEN)
        self:updateButtonsState()
        return
    end
    
    local pos = queue[idx]
    local action = self.executionState.action
    local step = self.executionState.step
    
    if action == "PLACE" then
        if step == "TELEPORT" then
            WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x, pos.y, pos.z)
            self.executionState.step = "WAIT_LOAD"
            self.executionState.delay = 20 -- Wait for chunk load
        elseif step == "WAIT_LOAD" then
            local sq = getCell():getGridSquare(pos.x, pos.y, 0)
            if sq then
                self.executionState.step = "PLACE_FLOOR"
                self.executionState.delay = 5
            else
                self.executionState.delay = 10
            end
        elseif step == "PLACE_FLOOR" then
            local sq = getCell():getOrCreateGridSquare(pos.x, pos.y, pos.z)
            if sq then
                sq:addFloor("floors_exterior_street_01_0")
            end
            self.executionState.step = "WAIT_FLOOR"
            self.executionState.delay = 10
        elseif step == "WAIT_FLOOR" then
             self.executionState.step = "PLACE_GEN"
             self.executionState.delay = 5
        elseif step == "PLACE_GEN" then
            self:doPlaceGenerator(pos)
            self.executionState.step = "TELEPORT"
            self.executionState.currentIdx = idx + 1
            self.executionState.delay = 10
        end
    elseif action == "TOGGLE_ON" or action == "TOGGLE_OFF" then
        if step == "TELEPORT" then
            WL_Utils.teleportPlayerToCoords(getPlayer(), pos.x, pos.y, pos.z)
            self.executionState.step = "WAIT_LOAD"
            self.executionState.delay = 20
        elseif step == "WAIT_LOAD" then
            local sq = getCell():getGridSquare(pos.x, pos.y, pos.z)
            if sq then
                self.executionState.step = "TOGGLE"
                self.executionState.delay = 5
            else
                self.executionState.delay = 10
            end
        elseif step == "TOGGLE" then
            self:doToggle(pos, action == "TOGGLE_ON")
            self.executionState.step = "TELEPORT"
            self.executionState.currentIdx = idx + 1
            self.executionState.delay = 5
        end
    end
    
    self:setStatus(action .. ": " .. idx .. "/" .. #queue .. " (" .. (step or "") .. ")", COLOR_YELLOW)
end

function WAT_GeneratorManager:doPlaceGenerator(pos)
    local sq = getCell():getGridSquare(pos.x, pos.y, pos.z)
    
    -- 3. Place Infinite Generator
    -- Check if generator already exists?
    local hasGen = false
    if sq then
        for i=0, sq:getObjects():size()-1 do
            local obj = sq:getObjects():get(i)
            if instanceof(obj, "IsoGenerator") then
                hasGen = true
                break
            end
        end
    end
    
    if not hasGen and sq then
        local item = InventoryItemFactory.CreateItem("Base.Generator")
        if item then
            item:setCondition(999999999)
            item:getModData().fuel = 999999999
            item:getModData()._isFuelInfinite = true
            local javaObject = IsoGenerator.new(item, getCell(), sq)
            javaObject:setConnected(true) -- 4. Wire it up
            javaObject:transmitCompleteItemToClients()
            IsoGenerator.updateGenerator(sq)
        end
    end
end

function WAT_GeneratorManager:doToggle(pos, state)
    local sq = getCell():getGridSquare(pos.x, pos.y, pos.z)
    if sq then
        for i=0, sq:getObjects():size()-1 do
            local obj = sq:getObjects():get(i)
            if instanceof(obj, "IsoGenerator") then
                obj:setActivated(state)
                if state then
                    obj:setConnected(true)
                end
                obj:transmitCompleteItemToClients()
            end
        end
    end
end

function WAT_GeneratorManager:close()
    if self.startPointPicker then
        self.startPointPicker:cleanup()
    end
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_GeneratorManager.instance = nil
end
