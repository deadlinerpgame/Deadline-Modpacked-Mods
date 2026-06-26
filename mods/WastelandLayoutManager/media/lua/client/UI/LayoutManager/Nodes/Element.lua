require "ISUI/ISUIElement"

local ElementNode = {}

local function updateElement(element, frame)
    element:setX(frame.x)
    element:setY(frame.y)
    element:setWidth(frame.width)
    element:setHeight(frame.height)
end

local function createElement(panel, frame)
    local element = ISUIElement:new(frame.x, frame.y, frame.width, frame.height)
    element:initialise()
    panel:addChild(element)

    element.__layoutType = "element"

    return element
end

function ElementNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: element is missing required id")
        return
    end

    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "element" then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createElement(panel, frame)
        state.elementsById[def.id] = element
    else
        updateElement(element, frame)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("element", ElementNode)
end
