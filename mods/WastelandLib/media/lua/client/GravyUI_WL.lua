if GravyUI and GravyUI.Version >= 1.3 then return end

require "ISUI/ISComboBox"
require "ISUI/ISButton"
require "RadioCom/ISUIRadio/ISSliderPanel"
require "ISUI/ISTextEntryBox"
require "ISUI/ISTickBox"

GravyUI = {}
GravyUI.Version = 1.3

--- @class Vec2
--- @field x number
--- @field y number
local Vec2 = {x = 0, y = 0}
Vec2.__index = Vec2
function Vec2:new(o, x, y)
    o = o or {}
    setmetatable(o, self)
    o.x = x
    o.y = y
    return o
end
function Vec2:__add(b) return self:new(nil, self.x + b.x, self.y + b.y) end

function Vec2:__sub(b) return Vec2:new(nil, self.x - b.x, self.y - b.y) end

local function vec2(x, y) return Vec2:new(nil, x, y) end

local function unpack(t, i)
    i = i or 1
    if t[i] ~= nil then return t[i], unpack(t, i + 1) end
end

--- @class Rect
--- @field topLeft Vec2
--- @field bottomRight Vec2
--- @field width number
--- @field height number
--- @field center Vec2
local function rect(v1, v2)
    return {
        topLeft = v1,
        bottomRight = v2,
        width = v2.x - v1.x,
        height = v2.y - v1.y,
        center = vec2(v1.x + (v2.x - v1.x) / 2, v1.y + (v2.y - v1.y) / 2)
    }
end


--- @class GravyUI.Node
--- @field rect Rect
--- @field left number
--- @field top number
--- @field right number
--- @field bottom number
--- @field width number
--- @field height number
--- @field element any|nil
--- @field parentNode GravyUI.Node|nil
--- @field childNodes GravyUI.Node[]
local Node = {}
Node.__index = Node

local function node(width, height, element) return Node:new(width, height, element) end

--- @param width number|Rect
--- @param height number|nil
--- @param element any|nil
--- @return GravyUI.Node
--- @overload fun(self: GravyUI.Node, rect: Rect): GravyUI.Node
function Node:new(width, height, element)
    if height ~= nil then width = rect(vec2(0, 0), vec2(width, height)) end
    if width.topLeft == nil then error("Invalid arguments to Node:new") end
    local o = {
        rect = width,
        left = width.topLeft.x,
        top = width.topLeft.y,
        right = width.bottomRight.x,
        bottom = width.bottomRight.y,
        width = width.width,
        height = width.height,
        element = element,
        childNodes = {}
    }
    setmetatable(o, self)
    o.__index = o
    return o
end

--- Creates a child node of this node with the given rect
--- @param rect Rect
--- @return GravyUI.Node
function Node:child(rect)
    local child = node(rect)
    child.parentNode = self
    child.element = self.element
    table.insert(self.childNodes, child)
    return child
end

--- sets a new element for this node, and all of its children
--- @param element any
function Node:setElement(element)
    self.element = element
    for _, child in ipairs(self.childNodes) do
        child:setElement(element)
    end
end

--- Creates a new node scaled by a factor of x and y, centered on the same point as this node
--- @param x number
--- @param y number
--- @return GravyUI.Node
function Node:scale(x, y)
    if y == nil then y = x end
    return self:resize(x * self.rect.width, y * self.rect.height)
end

--- Creates a new node of size width and height, centered on the same point as this node
--- @param width number
--- @param height number
--- @return GravyUI.Node
function Node:resize(width, height)
    local vec = vec2(width / 2, height / 2)
    return self:child(rect(self.rect.center - vec, self.rect.center + vec))
end

--- @param left number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param top number if <= 1, then it is a percentage of the parent's height, otherwise it is a pixel value
--- @param right number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param bottom number if <= 1, then it is a percentage of the parent's height, otherwise it is a pixel value
--- @overload fun(self: GravyUI.Node, leftRight: number, topBottom: number): GravyUI.Node
--- @overload fun(self: GravyUI.Node, allSides: number): GravyUI.Node
--- @return GravyUI.Node
function Node:pad(left, top, right, bottom)
    local topLeft, bottomRight

    if bottom ~= nil then
        if math.abs(left) <= 1 then left = left * self.rect.width end
        if math.abs(top) <= 1 then top = top * self.rect.height end
        if math.abs(right) <= 1 then right = right * self.rect.width end
        if math.abs(bottom) <= 1 then bottom = bottom * self.rect.height end
        topLeft = vec2(left, top)
        bottomRight = vec2(right, bottom)
    elseif top ~= nil then
        if math.abs(left) <= 1 then left = left * self.rect.width end
        if math.abs(top) <= 1 then top = top * self.rect.height end
        topLeft = vec2(left, top)
        bottomRight = vec2(left, top)
    elseif left ~= nil then
        if math.abs(left) <= 1 then
            topLeft = vec2(left * self.rect.width, left * self.rect.height)
        else
            topLeft = vec2(left, left)
        end
        bottomRight = topLeft
    else
        error("Invalid number of arugments to pad")
    end

    local newrect = rect(self.rect.topLeft + topLeft,
                         self.rect.bottomRight - bottomRight)
    return self:child(newrect)
end

--- @param splits number[]|number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param margin number|nil if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @return GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node
function Node:cols(splits, margin)
    margin = margin or 0
    if math.abs(margin) <= 1 then margin = (margin * self.rect.width) end
    local numSplits
    if type(splits) == "number" then
        numSplits = splits
        splits = {}
        for i = 1, numSplits do table.insert(splits, 1 / numSplits) end
    else
        numSplits = #splits
    end
    local availableSize = self.rect.width - margin * (numSplits - 1)
    for i = 1, numSplits do
        if math.abs(splits[i]) > 1 then
            availableSize = availableSize - splits[i]
        end
    end
    local nodes = {}
    local offset = 0
    for i = 1, numSplits do
        local split = splits[i]
        if math.abs(split) <= 1 then split = (split * availableSize) end
        local topLeft = self.rect.topLeft + vec2((i - 1) * margin + offset, 0)
        local bottomRight = topLeft + vec2(split, self.rect.height)
        table.insert(nodes, self:child(rect(topLeft, bottomRight)))
        offset = offset + split
    end
    return unpack(nodes)
end

--- @param splits number[]|number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param margin number|nil if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @return GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node,GravyUI.Node
function Node:rows(splits, margin)
    margin = margin or 0
    if math.abs(margin) <= 1 then margin = (margin * self.rect.height) end
    local numSplits
    if type(splits) == "number" then
        numSplits = splits
        splits = {}
        for _ = 1, numSplits do table.insert(splits, 1 / numSplits) end
    else
        numSplits = #splits
    end
    local availableSize = self.rect.height - margin * (numSplits - 1)
    for i = 1, numSplits do
        if math.abs(splits[i]) > 1 then
            availableSize = availableSize - splits[i]
        end
    end
    local nodes = {}
    local offset = 0
    for i = 1, numSplits do
        local split = splits[i]
        if math.abs(split) <= 1 then split = (split * availableSize) end
        local topLeft = self.rect.topLeft + vec2(0, (i - 1) * margin + offset)
        local bottomRight = topLeft + vec2(self.rect.width, split)
        table.insert(nodes, self:child(rect(topLeft, bottomRight)))
        offset = offset + split
    end
    return unpack(nodes)
end

--- @param rowSplits number[]|number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param colSplits number[]|number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param rowMargin number|nil if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param colMargin number|nil if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @return GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[],GravyUI.Node[]
function Node:grid(rowSplits, colSplits, rowMargin, colMargin)
    local nodes = {}
    for _, rowNode in ipairs({self:rows(rowSplits, rowMargin)}) do
        table.insert(nodes, {rowNode:cols(colSplits, colMargin)})
    end
    return unpack(nodes)
end

--- @param x number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param y number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @return GravyUI.Node
function Node:offset(x, y)
    if math.abs(x) <= 1 then x = x * self.rect.width end
    if math.abs(y) <= 1 then y = y * self.rect.height end
    local offset = vec2(x, y)
    return self:child(rect(self.rect.topLeft + offset,
                           self.rect.bottomRight + offset))
end


--- @param corner "topLeft"|"topRight"|"bottomLeft"|"bottomRight"
--- @param w number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param h number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
function Node:corner(corner, w, h)
    if w <= 1 then w = w * self.width end
    if h <= 1 then h = h * self.height end
    if corner == "topLeft" then
        return self:child(rect(self.rect.topLeft, self.rect.topLeft + vec2(w, h)))
    elseif corner == "topRight" then
        return self:child(rect(vec2(self.right - w, self.top),
                               vec2(self.right, self.top + h)))
    elseif corner == "bottomLeft" then
        return self:child(rect(vec2(self.left, self.bottom - h),
                               vec2(self.left + w, self.bottom)))
    elseif corner == "bottomRight" then
        return self:child(rect(vec2(self.right - w, self.bottom - h),
                               vec2(self.right, self.bottom)))
    else
        return print("Invalid corner for GravyUI.Node:corner")
    end
end

--- @param angle number
--- @param xDistance number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @param yDistance number if <= 1, then it is a percentage of the parent's width, otherwise it is a pixel value
--- @return GravyUI.Node
function Node:radial(angle, xDistance, yDistance)
    if yDistance == nil then yDistance = xDistance end
    if math.abs(xDistance) <= 1 then xDistance = xDistance * self.rect.width end
    if math.abs(yDistance) <= 1 then yDistance = yDistance * self.rect.width end

    local xs = xDistance * math.sin(angle)
    local ys = yDistance * math.cos(angle)
    return self:offset(xs, ys)
end

--- @param x number
--- @param y number
--- @return boolean
function Node:contains(x, y)
    return self.left <= x and x <= self.right and self.top <= y and y <= self.bottom
end

function Node:makeTabPanel()
    local tabPanel = ISTabPanel:new(self.left, self.top, self.width, self.height)
    tabPanel:setEqualTabWidth(false)
    if self.element then
        self.element:addChild(tabPanel)
    end
    return tabPanel
end

--- @param text string
--- @param target any|nil
--- @param callback function|nil
--- @param args any[]|nil
function Node:makeButton(text, target, callback, args)
    local button = ISButton:new(self.left, self.top, self.width, self.height, text, target, callback)
    button.anchorTop = true
    button.anchorLeft = true
    if args then button.onClickArgs = args end
    button:initialise()
    button:instantiate()
    if self.element then
        self.element:addChild(button)
    end
    return button
end

--- @param target any|nil
--- @param callback function|nil
function Node:makeSlider(target, callback)
    local slider = ISSliderPanel:new(self.left, self.top, self.width, self.height, target, callback)
    slider.anchorTop = true
    slider.anchorLeft = true
    slider:initialise()
    slider:instantiate()
    if self.element then
        self.element:addChild(slider)
    end
    return slider
end

--- @param target any|nil
--- @param callback function|nil
function Node:makeComboBox(target, callback)
    local comboBox = ISComboBox:new(self.left, self.top, self.width, self.height, target, callback)
    comboBox.anchorTop = true
    comboBox.anchorLeft = true
    comboBox:initialise()
    if self.element then
        self.element:addChild(comboBox)
    end
    return comboBox
end

--- @param initialText string
--- @param numbersOnly boolean|nil optional, if true the box only works for numbers
function Node:makeTextBox(initialText, numbersOnly, font)
    local textBox = ISTextEntryBox:new(initialText, self.left, self.top, self.width, self.height)
    if font then textBox.font = font end
    textBox.anchorTop = true
    textBox.anchorLeft = true
    textBox:initialise()
    textBox:instantiate()
    if numbersOnly then textBox:setOnlyNumbers(numbersOnly) end
    if self.element then
        self.element:addChild(textBox)
    end
    return textBox
end

--- @param initialText string
--- @param backgroundColor table|nil optional, if provided, sets the background color of the rich text box
--- @param borderColor table|nil optional, if provided, sets the border color of the rich text box
--- @param scrollBars boolean|nil optional, if true, adds scroll bars to the rich text body
--- @param autoSetHeight boolean|nil optional, if false, the height of the rich text box will not be automatically set based on the content
function Node:makeRichTextPanel(initialText, backgroundColor, borderColor, scrollBars, autoSetHeight)
    local richTextPanel = ISRichTextPanel:new(self.left, self.top, self.width, self.height)
    if backgroundColor then
        richTextPanel.backgroundColor = backgroundColor
    end
    if borderColor then
        richTextPanel.borderColor = borderColor
    end
    if not autoSetHeight then
        richTextPanel.autosetheight = false
    end
    richTextPanel:initialise()
    richTextPanel:instantiate()
    richTextPanel.text = initialText

    if self.element then
        self.element:addChild(richTextPanel)
    end
    if scrollBars then
        richTextPanel:addScrollBars()
    end
    richTextPanel:paginate()
    return richTextPanel
end

function Node:makeTickBox(target, callback, arg1, arg2)
    local checkbox = ISTickBox:new(self.left, self.top, self.width, self.height, "", target, callback, arg1, arg2)
    checkbox.anchorTop = true
    checkbox.anchorLeft = true
    checkbox:initialise()
    if self.element then
        self.element:addChild(checkbox)
    end
    return checkbox
end

local function drawListBoxItem(listBox, y, item, alt)
    local a = 0.9
    listBox:drawRectBorder(0, (y), listBox:getWidth(), listBox.itemheight - 1, a,
            listBox.borderColor.r, listBox.borderColor.g, listBox.borderColor.b)

    if listBox.selected == item.index then
        listBox:drawRect(0, (y), listBox:getWidth(), listBox.itemheight - 1, 0.3, 0.7, 0.35, 0.15)
    end

    listBox:drawText(item.text, 10, y + 2, 1, 1, 1, a, listBox.font)
    return y + listBox.itemheight
end

function Node:makeScrollingListBox(font)
    local listBox = ISScrollingListBox:new(self.left, self.top, self.width, self.height)
    listBox:initialise()
    listBox:instantiate()
    listBox.selected = 0
    listBox.font = font or UIFont.NewSmall
    listBox.itemheight = getTextManager():getFontHeight(listBox.font) + 2 * 2
    listBox.doDrawItem = drawListBoxItem
    listBox.drawBorder = true
    if self.element then
        listBox.joypadParent = self.element
        self.element:addChild(listBox)
    end
    return listBox
end

function Node:drawRect(uiElement, a, r, g, b)
    uiElement:drawRect(self.left, self.top, self.width, self.height, a, r, g, b)
end

function Node:drawRectBorder(uiElement, a, r, g, b)
    uiElement:drawRectBorder(self.left, self.top, self.width, self.height, a, r, g, b)
end

local LabelNode = ISUIElement:derive("LabelNode");
function LabelNode:new(x, y, width, height, text, font, color, align, truncateIfTooLong)
    local o = ISUIElement:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.font = font or UIFont.Medium
    o.color = color or {r=1,g=1,b=1,a=1}
    o.align = align or "left"
    o.truncateIfTooLong = truncateIfTooLong or false
    o:setText(text)
    return o
end

--- @param text string|function if a function is provided, it will be called to get the text each time the tooltip
--- is made visible. The function should have no arguments and return a string.
function LabelNode:setTooltip(text)
    self.mouseovertext = text
end

function LabelNode:prerender()
    local text = self.text
    local color = self.color
    if self.hoverText and self:isMouseOver() then
        text = self.hoverText
        color = self.hoverTextColor
    end
    if self.align == "left" then
        self:drawText(text, 0, 0, color.r, color.g, color.b, color.a, self.font)
    elseif self.align == "center" then
        self:drawTextCentre(text, self.width / 2, 0, color.r, color.g, color.b, color.a, self.font)
    elseif self.align == "right" then
        self:drawTextRight(text, self.width, 0, color.r, color.g, color.b, color.a, self.font)
    end
    self:updateTooltip()
end

function LabelNode:updateTooltip()
    if self:isMouseOver() and self.mouseovertext then
        if not self.tooltipUI then
            self.tooltipUI = ISToolTip:new()
            self.tooltipUI.descriptionPanel.backgroundColor = {r=0, g=0, b=0, a=0 };
            self.tooltipUI:setOwner(self)
            self.tooltipUI:setVisible(false)
            self.tooltipUI:setAlwaysOnTop(true)
        end
        if not self.tooltipUI:getIsVisible() then
            local text = type(self.mouseovertext) == "function" and self.mouseovertext() or self.mouseovertext
            if string.contains(text, "\n") then
                self.tooltipUI.maxLineWidth = 1000
            else
                self.tooltipUI.maxLineWidth = 300
            end
            self.tooltipUI:addToUIManager()
            self.tooltipUI:setVisible(true)
            self.tooltipUI.description = text
        end
        -- Changed to follow mouse position with a small offset
        self.tooltipUI:setDesiredPosition(getMouseX() + 8, getMouseY() + 8)
    else
        if self.tooltipUI and self.tooltipUI:getIsVisible() then
            self.tooltipUI:setVisible(false)
            self.tooltipUI:removeFromUIManager()
        end
    end
end

function LabelNode:setHoverText(hoverText, hoverTextColor)
    self.hoverText = hoverText
    self.hoverTextColor = hoverTextColor or {r=1,g=1,b=1,a=1}
end

function LabelNode:getText()
    return self.text
end

function LabelNode:setText(text)
    if not text then return end
    if not self.truncateIfTooLong then
        self.text = text
        return
    end

    local xLength = getTextManager():MeasureStringX(self.font, text)
    local trimmedText = text

    while xLength > self.width do
        if #trimmedText == 0 then break end
        trimmedText = string.sub(trimmedText, 1, -2) -- Remove the last character
        xLength = getTextManager():MeasureStringX(self.font, (trimmedText .. "..")) + 5
    end

    if trimmedText == text then
        self.text = trimmedText
    else
        self.text = trimmedText .. ".."
    end
end

function Node:makeLabel(text, font, color, align, truncateIfTooLong)
    local label = LabelNode:new(self.left, self.top, self.width, self.height, text, font, color, align,
            truncateIfTooLong)
    label.anchorTop = true
    label.anchorLeft = true
    label:initialise()
    if self.element then
        self.element:addChild(label)
    end
    return label
end

function Node:makeAreaPicker()
    local areaPicker = WL_AreaPicker:new(self.left, self.top, self.width, self.height)
    areaPicker.anchorTop = true
    areaPicker.anchorLeft = true
    areaPicker:initialise()
    if self.element then
        self.element:addChild(areaPicker)
    end
    return areaPicker
end

function Node:makePointPicker()
    local pointPicker = WL_PointPicker:new(self.left, self.top, self.width, self.height)
    pointPicker.anchorTop = true
    pointPicker.anchorLeft = true
    pointPicker:initialise()
    if self.element then
        self.element:addChild(pointPicker)
    end
    return pointPicker
end

local StackPanel = {}
StackPanel.__index = StackPanel

function StackPanel:new(parentNode, margin, isVertical)
    local o = {
        parentNode = parentNode,
        margin = margin or 0,
        isVertical = isVertical or false,
        currentOffset = 0,
        remainingSpace = isVertical and parentNode.height or parentNode.width
    }
    setmetatable(o, self)
    return o
end

function StackPanel:willFit(size)
    local margin = self.currentOffset > 0 and self.margin or 0
    return (size + margin) <= self.remainingSpace
end

function StackPanel:makeNode(size)
    local margin = self.currentOffset > 0 and self.margin or 0
    local offset = self.currentOffset + margin
    local newNode
    if self.isVertical then         -- Create a new row with the specified height
        local topLeft = self.parentNode.rect.topLeft + vec2(0, offset)
        local bottomRight = topLeft + vec2(self.parentNode.width, size)
        newNode = self.parentNode:child(rect(topLeft, bottomRight))
    else         -- Create a new column with the specified width
        local topLeft = self.parentNode.rect.topLeft + vec2(offset, 0)
        local bottomRight = topLeft + vec2(size, self.parentNode.height)
        newNode = self.parentNode:child(rect(topLeft, bottomRight))
    end

    self.currentOffset = offset + size
    self.remainingSpace = self.remainingSpace - (size + margin)
    return newNode
end

function Node:makeVerticalStack(margin)
    return StackPanel:new(self, margin, true)
end

function Node:makeHorizontalStack(margin)
    return StackPanel:new(self, margin, false)
end

local ImageElement = {}
ImageElement.__index = ImageElement

function ImageElement:new(parentNode, texture, width, height, alpha)
    local o = {
        parentNode = parentNode,
        texture = texture,
        width = width or parentNode.width,
        height = height or parentNode.height,
        alpha = alpha or 1.0,
    }
    setmetatable(o, self)
    return o
end

function Node:makeImage(texture, width, height, alpha)
    if type(texture) == "string" then
        texture = getTexture(texture)
    end

    local image = ImageElement:new(self, texture, width, height, alpha)
    if not self.element then
        error("Node does not have an element to add the image to. Pass it in as an argument when creating the Node.")
    end

    if self.element.imagesToRender == nil then
        self.element.imagesToRender = {}
    end

    table.insert(self.element.imagesToRender, image)
    return image
end

local function prerenderImages(element)
    if not element.imagesToRender then return end
    for _, image in ipairs(element.imagesToRender) do
        element:drawTextureScaled(image.texture, image.parentNode.left, image.parentNode.top, image.width, image.height, image.alpha, 1.0, 1.0, 1.0)
    end
end

GravyUI.Rect = rect
GravyUI.Vec2 = vec2
GravyUI.Node = node
GravyUI.unpack = unpack
GravyUI.prerender = prerenderImages