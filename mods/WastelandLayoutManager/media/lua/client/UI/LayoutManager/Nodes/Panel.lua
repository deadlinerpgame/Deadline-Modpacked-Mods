require "ISUI/ISPanel"

local PanelNode = {}

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

local function updatePanel(panelElement, frame, def)
    panelElement:setX(frame.x)
    panelElement:setY(frame.y)
    panelElement:setWidth(frame.width)
    panelElement:setHeight(frame.height)

    if def.background ~= nil then
        panelElement.background = def.background == true
    end

    if def.noBackground ~= nil then
        if def.noBackground == true then
            panelElement:noBackground()
        else
            panelElement.background = true
        end
    end

    if def.moveWithMouse ~= nil then
        panelElement.moveWithMouse = def.moveWithMouse == true
    end

    applyColor(panelElement.backgroundColor, def.backgroundColor or def.color)
    applyColor(panelElement.borderColor, def.borderColor)
end

local function createPanel(panel, frame)
    local panelElement = ISPanel:new(frame.x, frame.y, frame.width, frame.height)
    panelElement:initialise()
    panel:addChild(panelElement)

    panelElement.__layoutType = "panel"

    return panelElement
end

function PanelNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: panel is missing required id")
        return
    end

    local panelElement = state.elementsById[def.id]
    if panelElement and panelElement.__layoutType ~= "panel" then
        panel:removeChild(panelElement)
        panelElement = nil
    end

    if not panelElement then
        panelElement = createPanel(panel, frame)
        state.elementsById[def.id] = panelElement
    end

    updatePanel(panelElement, frame, def)

    if def.child then
        local childElements = layoutManager:applyLayout(panelElement, def.child)
        for childId, childElement in pairs(childElements) do
            elementsOut[childId] = childElement
        end
    else
        clearPanelLayout(panelElement)
    end

    elementsOut[def.id] = panelElement
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("panel", PanelNode)
end
