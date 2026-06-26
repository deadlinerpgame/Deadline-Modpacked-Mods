--- WL_AreaPicker
--- Created by Gravy.

--- @class AreaDefinition
--- @field x1 number
--- @field y1 number
--- @field z1 number
--- @field x2 number
--- @field y2 number
--- @field z2 number

--- @class WL_AreaPicker : ISUIElement
--- @field value AreaDefinition
WL_AreaPicker = ISUIElement:derive("WL_AreaPicker")

--- Create a new Area Picker UI element.
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WL_AreaPicker
function WL_AreaPicker:new(x, y, width, height)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WL_AreaPicker:initialise()
    ISUIElement.initialise(self)

    self.value = {
        x1 = 0,
        y1 = 0,
        z1 = 0,
        x2 = 0,
        y2 = 0,
        z2 = 0
    }
    self.currentSelection = nil
    self.target = nil
    self.callback = nil
    self.lastMouseX = nil
    self.lastMouseY = nil
    self.lastMouseZ = nil
    self.lastMouseHighlight = nil
    self.forceZ = nil
    self.singleZ = false
    self.fullZ = false
    self.showAlways = true
    self.maxSize = 20000

    local node = GravyUI.Node(self.width, self.height)

    local core, buttons = node:rows({0.4, 0.6}, 0.1)
    local startPoint, endPoint = core:cols(2, 5)
    local startPointBtns, endPointBtns = buttons:cols(2, 5)

    local startPointZD, startPointXY, startPointZU = startPointBtns:cols({0.2, 0.6, 0.2}, 2)
    local endPointZD, endPointXY, endPointZU = endPointBtns:cols({0.2, 0.6, 0.2}, 2)

    self.startPoint = startPoint:makeLabel("0,0,0", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")
    self.endPoint = endPoint:makeLabel("0,0,0", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")

    self.startPointZD = startPointZD:makeButton("Z-", self, self._startZ, {-1})
    self.selectStart = startPointXY:makeButton("Set NW", self, self._startSelect, {"NW"})
    self.startPointZU = startPointZU:makeButton("Z+", self, self._startZ, {1})

    self.endPointZD = endPointZD:makeButton("Z-", self, self._endZ, {-1})
    self.selectEnd = endPointXY:makeButton("Set SE", self, self._startSelect, {"SE"})
    self.endPointZU = endPointZU:makeButton("Z+", self, self._endZ, {1})

    self:addChild(self.startPoint)
    self:addChild(self.endPoint)

    self:addChild(self.startPointZD)
    self:addChild(self.selectStart)
    self:addChild(self.startPointZU)

    self:addChild(self.endPointZD)
    self:addChild(self.selectEnd)
    self:addChild(self.endPointZU)

    self.groundHighlighter = GroundHighlighter:new()
    self.groundHighlighter:enableXray(true, true)
    self.groundHighlighter:setColor(1, 1, 0, 1)
    self.player = getPlayer()
end

function WL_AreaPicker:setPriority(priority)
    self.groundHighlighter:setPriority(priority)
end

function WL_AreaPicker:setColor(r, g, b, a)
    self.groundHighlighter:setColor(r, g, b, a)
end

function WL_AreaPicker:_startZ(_btn, dir)
    if self.forceZ ~= nil or self.fullZ then
        return
    end
    if dir < 1 and self.value.z1 > 0 then
        self.value.z1 = self.value.z1 + dir
    elseif dir > 0 and self.value.z1 < 7 then
        self.value.z1 = self.value.z1 + dir
    end
    self.value.z2 = math.max(self.value.z1, self.value.z2)
    self:_updateValue()
end

function WL_AreaPicker:_endZ(_btn, dir)
    if self.forceZ ~= nil or self.fullZ then
        return
    end
    if dir < 1 and self.value.z2 > 0 then
        self.value.z2 = self.value.z2 + dir
    elseif dir > 0 then
        self.value.z2 = self.value.z2 + dir
    end
    self.value.z1 = math.min(self.value.z1, self.value.z2)
    self:_updateValue()
end

--- Sets the value
--- @param value AreaDefinition
function WL_AreaPicker:setValue(value)
    self.value = value
    self:_updateValue()
end

--- Gets the value
--- @return AreaDefinition
function WL_AreaPicker:getValue()
    return self.value
end

--- Sets the callback function when the value changes
--- @param callback Function
--- @param target any|nil The target object to call the callback on, if nil the callback will be called without a target
function WL_AreaPicker:setCallback(callback, target)
    self.callback = callback
    self.target = target
end

function WL_AreaPicker:setStartPickingCallback(callback, target)
    self.startPicking = callback
    self.startPickingTarget = target
end

function WL_AreaPicker:setEndPickingCallback(callback, target)
    self.endPicking = callback
    self.endPickingTarget = target
end

function WL_AreaPicker:_updateValue()
    if self.value.x1 > self.value.x2 then
        local tmp = self.value.x1
        self.value.x1 = self.value.x2
        self.value.x2 = tmp
    end
    if self.value.y1 > self.value.y2 then
        local tmp = self.value.y1
        self.value.y1 = self.value.y2
        self.value.y2 = tmp
    end
    if self.value.z1 > self.value.z2 then
        local tmp = self.value.z1
        self.value.z1 = self.value.z2
        self.value.z2 = tmp
    end

    if self.forceZ then
        self.value.z1 = self.forceZ
        self.value.z2 = self.forceZ
    elseif self.singleZ then
        self.value.z2 = self.value.z1
    elseif self.fullZ then
        self.value.z1 = 0
        self.value.z2 = 8
    end

    if self.value.x2 - self.value.x1 > self.maxSize then
        self.value.x2 = self.value.x1 + self.maxSize
    end
    if self.value.y2 - self.value.y1 > self.maxSize then
        self.value.y2 = self.value.y1 + self.maxSize
    end

    self.startPoint.text = string.format("%d,%d,%d", self.value.x1, self.value.y1, self.value.z1)
    self.endPoint.text = string.format("%d,%d,%d", self.value.x2, self.value.y2, self.value.z2)

    if self.callback then
        if self.target then
            self.callback(self.target, self.value)
        else
            self.callback(self.value)
        end
    end
end

function WL_AreaPicker:_startSelect(_, side)
    if self.currentSelection == nil then
        if side == "NW" then
            self.selectStart.backgroundColor = {r=0.5, g=0, b=0, a=1}
            self.selectStart.title = "Stop"
            self.selectEnd.enable = false
        else
            self.selectEnd.backgroundColor = {r=0.5, g=0, b=0, a=1}
            self.selectEnd.title = "Stop"
            self.selectStart.enable = false
        end
        self.currentSelection = side
        if self.startPicking then
            self.startPicking(self.startPickingTarget)
        end
    else
        self.selectStart.backgroundColor = {r = 0, g = 0, b = 0, a = 1}
        self.selectEnd.backgroundColor = {r = 0, g = 0, b = 0, a = 1}
        self.selectStart.title = "Set NW"
        self.selectEnd.title = "Set SE"
        self.selectStart.enable = true
        self.selectEnd.enable = true
        self.currentSelection = nil
        self:_updateValue()
        if self.endPicking then
            self.endPicking(self.endPickingTarget)
        end
    end
end

function WL_AreaPicker:setSquareHighlight(x, y, z, onOff)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return end

    local objects = sq:getObjects()
    if onOff and objects:size() > 0 then
        if objects:get(0):isHighlighted() then
            local color = objects:get(0):getHighlightColor()
            self.lastMouseHighlight = {r = color:getR(), g = color:getG(), b = color:getB(), a = color:getA()}
        else
            self.lastMouseHighlight = nil
        end

        self.lastMouseX = x
        self.lastMouseY = y
        self.lastMouseZ = z
    end

    for i=1, objects:size() do
        local obj = objects:get(i-1)
        if not onOff and self.lastMouseHighlight then
            obj:setBlink(false)
            obj:setHighlightColor(self.lastMouseHighlight.r, self.lastMouseHighlight.g, self.lastMouseHighlight.b, self.lastMouseHighlight.a)
            obj:setHighlighted(true, false)
        else
            obj:setHighlightColor(1, 0, 0, 1)
            obj:setHighlighted(onOff, false)
            obj:setBlink(onOff)
        end
    end
    local specialObjects = sq:getSpecialObjects()
    for i=1, specialObjects:size() do
        local obj = specialObjects:get(i-1)
        if not onOff and self.lastMouseHighlight then
            obj:setBlink(false)
            obj:setHighlightColor(self.lastMouseHighlight.r, self.lastMouseHighlight.g, self.lastMouseHighlight.b, self.lastMouseHighlight.a)
            obj:setHighlighted(true, false)
        else
            obj:setHighlightColor(1, 0, 0, 1)
            obj:setHighlighted(onOff, false)
            obj:setBlink(onOff)
        end
    end

    if not onOff then
        self.lastMouseX = nil
        self.lastMouseY = nil
        self.lastMouseZ = nil
        self.lastMouseHighlight = nil
    end
end

function WL_AreaPicker:_updateGroundHighlight(force)
    if self.cleanedUp then return end

    if (self.showAlways or self.currentSelection) and self.value.x1 ~= 0 and self.value.y1 ~= 0 then
        local player = getPlayer()
        local x, y = math.floor(player:getX()), math.floor(player:getY())
        local x1 = math.max(self.value.x1, x - 50)
        local y1 = math.max(self.value.y1, y - 50)
        local x2 = math.min(self.value.x2, x + 50)
        local y2 = math.min(self.value.y2, y + 50)
        if  force
            or x1 ~= self.groundHighlighter.bounds.x1
            or y1 ~= self.groundHighlighter.bounds.y1
            or x2 ~= self.groundHighlighter.bounds.x2
            or y2 ~= self.groundHighlighter.bounds.y2
            or self.value.z1 ~= self.groundHighlighter.bounds.z1
            or self.value.z2 ~= self.groundHighlighter.bounds.z2
        then
            self.groundHighlighter:highlightCube(x1, y1, x2, y2, self.value.z1, self.value.z2)
        end
    elseif self.groundHighlighter.type ~= "none" then
        self.groundHighlighter:remove()
    end
end

function WL_AreaPicker:prerender()
    if self.singleZ then
        if not self.startPointZD:isVisible() then
            self.startPointZD:setVisible(true)
        end
        if not self.startPointZU:isVisible() then
            self.startPointZU:setVisible(false)
        end
        if self.endPointZD:isVisible() then
            self.endPointZD:setVisible(false)
        end
        if self.endPointZU:isVisible() then
            self.endPointZU:setVisible(false)
        end
    elseif self.forceZ or self.fullZ then
        if self.startPointZD:isVisible() then
            self.startPointZD:setVisible(false)
            self.startPointZU:setVisible(false)
            self.endPointZD:setVisible(false)
            self.endPointZU:setVisible(false)
        end
    else
        if not self.startPointZD:isVisible() then
            self.startPointZD:setVisible(true)
            self.startPointZU:setVisible(true)
            self.endPointZD:setVisible(true)
            self.endPointZU:setVisible(true)
        end
        self.startPointZD.enable = self.value.z1 > 0
        self.startPointZU.enable = self.value.z1 < self.value.z2
        self.endPointZD.enable = self.value.z2 > self.value.z1
        self.endPointZU.enable = self.value.z2 < 9
    end

    if not self.currentSelection then
        if self.lastMouseX then
            self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
        end
        self:_updateGroundHighlight()
        return
    end

    self:_updateGroundHighlight()

    local wz = math.floor(self.player:getZ())

    if self.forceZ ~= nil and self.forceZ ~= wz then
        return
    end

    local x, y = getMouseX(), getMouseY()
    local wx = math.floor(screenToIsoX(self.player:getPlayerNum(), x, y, self.player:getZ()))
    local wy = math.floor(screenToIsoY(self.player:getPlayerNum(), x, y, self.player:getZ()))

    if isMouseButtonDown(0) and not self:isMouseOver() then
        self.didMouseDown = true
        if self.currentSelection == "NW" then
            if self.value.x1 == 0 and self.value.y1 == 0 then
                self.value.z1 = wz
                if self.value.x2 == 0 and self.value.y2 == 0 then
                    self.value.z2 = wz
                end
            end
            self.value.x1 = wx
            self.value.y1 = wy
        elseif self.currentSelection == "SE" then
            if self.value.x2 == 0 and self.value.y2 == 0 then
                self.value.z2 = wz
                if self.value.x1 == 0 and self.value.y1 == 0 then
                    self.value.z1 = wz
                end
            end
            self.value.x2 = wx
            self.value.y2 = wy
        end
        self.lastMouseHighlight = nil
        if self.lastMouseX then
            self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
        end
        self.lastMouseX = nil
        if self.singleZ then
            self.value.z1 = wz
            self.value.z2 = wz
        end
        self:_updateValue()
        return
    end

    if self.didMouseDown then
        self.didMouseDown = false
        self:_startSelect(_, self.currentSelection)
        return
    end

    if not self.lastMouseX or self.lastMouseX ~= wx or self.lastMouseY ~= wy or self.lastMouseZ ~= wz then
        if self.lastMouseX then
            self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
        end
        self:setSquareHighlight(wx, wy, wz, true)
        self.lastMouseX = wx
        self.lastMouseY = wy
        self.lastMouseZ = wz
    end
end



function WL_AreaPicker:cleanup()
    self.cleanedUp = true
    self.groundHighlighter:remove()
    if self.lastMouseX then
        self.lastMouseHighlight = nil
        self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
    end
end
