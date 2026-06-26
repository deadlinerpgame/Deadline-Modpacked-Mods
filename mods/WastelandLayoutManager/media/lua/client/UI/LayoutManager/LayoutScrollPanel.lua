require "ISUI/ISPanel"

local LayoutScrollPanel = ISPanel:derive("LayoutManagerScrollPanel")

local function applyParentClipStencil(ui)
    local stencilX = 0
    local stencilY = 0
    local stencilX2 = ui.width
    local stencilY2 = ui.height

    if ui.parent and ui.parent:getScrollChildren() then
        stencilX = ui.javaObject:clampToParentX(ui:getAbsoluteX() + stencilX) - ui:getAbsoluteX()
        stencilX2 = ui.javaObject:clampToParentX(ui:getAbsoluteX() + stencilX2) - ui:getAbsoluteX()
        stencilY = ui.javaObject:clampToParentY(ui:getAbsoluteY() + stencilY) - ui:getAbsoluteY()
        stencilY2 = ui.javaObject:clampToParentY(ui:getAbsoluteY() + stencilY2) - ui:getAbsoluteY()
    end

    ui._clipStencil = {
        x = stencilX + 1,
        y = stencilY + 1,
        w = stencilX2 - stencilX - 1,
        h = stencilY2 - stencilY - 1
    }
    ui:setStencilRect(ui._clipStencil.x, ui._clipStencil.y, ui._clipStencil.w, ui._clipStencil.h)
end

local function clearParentClipStencil(ui)
    if ui._clipStencil then
        ui:clearStencilRect()
        if ui.doRepaintStencil then
            ui:repaintStencilRect(ui._clipStencil.x, ui._clipStencil.y, ui._clipStencil.w, ui._clipStencil.h)
        end
    end
end

---@param x number
---@param y number
---@param width number
---@param height number
---@return LayoutManagerScrollPanel
function LayoutScrollPanel:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.autoScrollBottomPadding = 12

    return o
end

function LayoutScrollPanel:initialise()
    ISPanel.initialise(self)
end

function LayoutScrollPanel:initializeScrolling()
    if self._scrollInitialized then
        return
    end

    self._scrollInitialized = true

    self:setScrollChildren(true)
    if not self.vscroll then
        self:addScrollBars()
    end
    if self.vscroll then
        self.vscroll.doSetStencil = true
    end

    self:refreshScrollHeightFromChildren()
end

---@param del number
---@return boolean
function LayoutScrollPanel:onMouseWheel(del)
    if self:getScrollHeight() > self:getScrollAreaHeight() then
        self:setYScroll(self:getYScroll() - (del * 30))
        return true
    end

    return false
end

---@param padding number
function LayoutScrollPanel:setAutoScrollBottomPadding(padding)
    self.autoScrollBottomPadding = math.max(0, tonumber(padding) or 0)
    self:refreshScrollHeightFromChildren()
end

function LayoutScrollPanel:refreshScrollHeightFromChildren()
    local children = self.children or {}
    local maxBottom = 0

    for _, child in pairs(children) do
        if child and child ~= self.vscroll and child ~= self.hscroll then
            local childBottom = (child.y or 0) + (child.height or 0)
            if childBottom > maxBottom then
                maxBottom = childBottom
            end
        end
    end

    local targetHeight = math.max(self.height, maxBottom + (self.autoScrollBottomPadding or 0))
    self:setScrollHeight(targetHeight)
end

function LayoutScrollPanel:prerender()
    applyParentClipStencil(self)
    self:refreshScrollHeightFromChildren()
    ISPanel.prerender(self)
end

function LayoutScrollPanel:render()
    ISPanel.render(self)
    clearParentClipStencil(self)
end

return LayoutScrollPanel
