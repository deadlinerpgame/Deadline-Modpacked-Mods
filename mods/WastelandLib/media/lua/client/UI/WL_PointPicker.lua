--- WL_PointPicker
--- Created by Gravy.
--- @class PointDefinition
--- @field x number
--- @field y number
--- @field z number
--- @class WL_PointPicker : ISUIElement
--- @field value PointDefinition
WL_PointPicker = ISUIElement:derive("WL_PointPicker")

--- Create a new Point Picker UI element.
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WL_PointPicker
function WL_PointPicker:new(x, y, width, height)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WL_PointPicker:initialise()
    ISUIElement.initialise(self)
    self.value = {x = 0, y = 0, z = 0}
    self.currentSelection = nil
    self.target = nil
    self.callback = nil
    self.lastMouseX = nil
    self.lastMouseY = nil
    self.lastMouseZ = nil
    self.lastMouseHighlight = nil
    self.forceZ = nil
    self.showAlways = true
    local node = GravyUI.Node(self.width, self.height)
    local core, buttons = node:rows({0.4, 0.6}, 0.1)
    local point = core:cols(1)
    local pointBtns = buttons:cols(1)
    local pointZD, pointXY, pointZU = pointBtns:cols({0.2, 0.6, 0.2}, 2)
    self.point = point:makeLabel("0,0,0", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")
    self.pointZD = pointZD:makeButton("Z-", self, self._pointZ, {-1})
    self.selectPoint = pointXY:makeButton("Set Point", self, self._selectPoint)
    self.pointZU = pointZU:makeButton("Z+", self, self._pointZ, {1})
    self:addChild(self.point)
    self:addChild(self.pointZD)
    self:addChild(self.selectPoint)
    self:addChild(self.pointZU)
    self.groundHighlighter = GroundHighlighter:new()
    self.groundHighlighter:enableXray(true, true)
    self.groundHighlighter:setColor(1, 1, 0, 1)
    self.player = getPlayer()
end

function WL_PointPicker:setPriority(priority)
    self.groundHighlighter:setPriority(priority)
end

function WL_PointPicker:setColor(r, g, b, a)
    self.groundHighlighter:setColor(r, g, b, a)
end

function WL_PointPicker:_pointZ(_btn, dir)
    if self.forceZ ~= nil then
        return
    end
    if dir < 1 and self.value.z > 0 then
        self.value.z = self.value.z + dir
    elseif dir > 0 then
        self.value.z = self.value.z + dir
    end
    self:_updateValue()
end

function WL_PointPicker:setValue(value)
    self.value = value
    self:_updateValue()
end

function WL_PointPicker:getValue()
    return self.value
end

function WL_PointPicker:setCallback(callback, target)
    self.callback = callback
    self.target = target
end

function WL_PointPicker:addToolTip(instance, tooltip)
    if instance then
        instance.selectPoint.tooltip = tooltip
    else
        self.selectPoint.tooltip = tooltip
    end
end

function WL_PointPicker:setStartPickingCallback(callback, target)
    self.startPicking = callback
    self.startPickingTarget = target
end

function WL_PointPicker:setEndPickingCallback(callback, target)
    self.endPicking = callback
    self.endPickingTarget = target
end

function WL_PointPicker:_updateValue()
    if self.forceZ then
        self.value.z = self.forceZ
    end
    self.point.text = string.format("%d,%d,%d", self.value.x, self.value.y, self.value.z)
    if self.callback then
        self.callback(self.target, self.value)
    end
end

function WL_PointPicker:_selectPoint()
    self.currentSelection = not self.currentSelection
    if self.currentSelection then
        if self.startPicking then
            self.startPicking(self.startPickingTarget)
        end
    else
        if self.endPicking then
            self.endPicking(self.endPickingTarget)
        end
    end
end

function WL_PointPicker:setSquareHighlight(x, y, z, onOff)
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

function WL_PointPicker:_updateGroundHighlight(force)
    if (self.showAlways or self.currentSelection) and self.value.x1 ~= 0 and self.value.y1 ~= 0 then
        self.groundHighlighter:highlightSquare(self.value.x, self.value.y, self.value.x, self.value.y, self.value.z)
    elseif self.groundHighlighter.type ~= "none" then
        self.groundHighlighter:remove()
    end
end

function WL_PointPicker:prerender()
    if self.forceZ then
        if self.pointZD:isVisible() then
            self.pointZU:setVisible(false)
        end
    else
        if not self.pointZD:isVisible() then
            self.pointZU:setVisible(true)
        end
        self.pointZD.enable = self.value.z > 0
        self.pointZU.enable = self.value.z < 9
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
        self.value.x = wx
        self.value.y = wy
        self.value.z = wz
        self.lastMouseHighlight = nil
        if self.lastMouseX then
            self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
        end
        self.lastMouseX = nil
        self:_updateValue()
        return
    end
    if self.didMouseDown then
        self.didMouseDown = false
        self:_selectPoint()
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

function WL_PointPicker:cleanup()
    self.groundHighlighter:remove()
    if self.lastMouseX then
        self.lastMouseHighlight = nil
        self:setSquareHighlight(self.lastMouseX, self.lastMouseY, self.lastMouseZ, false)
    end
end