require "ISUI/ISButton"

local ButtonNode = {}

local function applyColor(target, color)
    if not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function updateButton(button, frame, def)
    button:setX(frame.x)
    button:setY(frame.y)
    button:setWidth(frame.width)
    button:setHeight(frame.height)

    local layoutText = def.text
    if layoutText == nil then
        layoutText = def.title
    end
    if layoutText ~= nil then
        button:setTitle(tostring(layoutText))
        button.__wlLastLayoutText = button.title
    end

    button.target = def.target
    button.onclick = def.onClick
    button.onmousedown = def.onMouseDown

    if def.args then
        button.onClickArgs = def.args
    else
        button.onClickArgs = {}
    end

    if def.allowMouseUpProcessing ~= nil then
        button.allowMouseUpProcessing = def.allowMouseUpProcessing == true
    end

    if def.font then
        button:setFont(def.font)
    end

    if def.tooltip ~= nil then
        button:setTooltip(def.tooltip)
    end

    if def.displayBackground ~= nil then
        button:setDisplayBackground(def.displayBackground == true)
    end

    local enabled = def.enable
    if enabled == nil then
        enabled = def.enabled
    end
    if enabled ~= nil then
        button:setEnable(enabled == true)
    end

    if def.yoffset ~= nil then
        button.yoffset = def.yoffset
    end

    applyColor(button.borderColor, def.borderColor)
    applyColor(button.backgroundColor, def.backgroundColor)
    applyColor(button.backgroundColorMouseOver, def.backgroundColorMouseOver)
    applyColor(button.textureColor, def.textureColor)
    applyColor(button.textColor, def.textColor)

    if def.soundActivate then
        button:setSound("activate", def.soundActivate)
    end
end

local function createButton(panel, frame, def)
    local title = def.text
    if title == nil then
        title = def.title
    end
    if title == nil then
        title = ""
    end

    local button = ISButton:new(
        frame.x,
        frame.y,
        frame.width,
        frame.height,
        tostring(title),
        def.target,
        def.onClick,
        def.onMouseDown,
        def.allowMouseUpProcessing
    )

    button:initialise()
    panel:addChild(button)

    button.__layoutType = "button"
    button.__wlLastLayoutText = button.title

    updateButton(button, frame, def)
    return button
end

function ButtonNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: button is missing required id")
        return
    end

    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "button" then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createButton(panel, frame, def)
        state.elementsById[def.id] = element
    else
        updateButton(element, frame, def)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("button", ButtonNode)
end
