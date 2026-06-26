local LayoutScrollPanel = require "UI/LayoutManager/LayoutScrollPanel"

local ScrollPanelNode = {}

local function applyColor(target, color)
    if not target or not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function clearPanelLayout(panel)
    local layoutState = panel.__wlLayoutState
    if not layoutState then
        return
    end

    for id, child in pairs(layoutState.elementsById) do
        panel:removeChild(child)
        layoutState.elementsById[id] = nil
    end
end

local function updateScrollPanel(scrollPanel, frame, def)
    scrollPanel:setX(frame.x)
    scrollPanel:setY(frame.y)
    scrollPanel:setWidth(frame.width)
    scrollPanel:setHeight(frame.height)

    if def.background ~= nil then
        scrollPanel.background = def.background == true
    end

    if def.noBackground ~= nil then
        if def.noBackground == true then
            scrollPanel:noBackground()
        else
            scrollPanel.background = true
        end
    end

    if def.moveWithMouse ~= nil then
        scrollPanel.moveWithMouse = def.moveWithMouse == true
    end

    if def.doRepaintStencil ~= nil then
        scrollPanel.doRepaintStencil = def.doRepaintStencil == true
    end

    if def.autoScrollBottomPadding ~= nil then
        scrollPanel:setAutoScrollBottomPadding(def.autoScrollBottomPadding)
    end

    applyColor(scrollPanel.backgroundColor, def.backgroundColor or def.color)
    applyColor(scrollPanel.borderColor, def.borderColor)

    scrollPanel:initializeScrolling()
end

local function createScrollPanel(panel, frame)
    local scrollPanel = LayoutScrollPanel:new(frame.x, frame.y, frame.width, frame.height)
    scrollPanel:initialise()
    panel:addChild(scrollPanel)

    scrollPanel.__layoutType = "scrollpanel"

    return scrollPanel
end

function ScrollPanelNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: scrollpanel is missing required id")
        return
    end

    local scrollPanel = state.elementsById[def.id]
    if scrollPanel and scrollPanel.__layoutType ~= "scrollpanel" then
        panel:removeChild(scrollPanel)
        scrollPanel = nil
    end

    if not scrollPanel then
        scrollPanel = createScrollPanel(panel, frame)
        state.elementsById[def.id] = scrollPanel
    end

    updateScrollPanel(scrollPanel, frame, def)

    if def.child then
        local childElements = layoutManager:applyLayout(scrollPanel, def.child)
        for childId, childElement in pairs(childElements) do
            elementsOut[childId] = childElement
        end
    else
        clearPanelLayout(scrollPanel)
    end

    scrollPanel:refreshScrollHeightFromChildren()

    elementsOut[def.id] = scrollPanel
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("scrollpanel", ScrollPanelNode)
end
