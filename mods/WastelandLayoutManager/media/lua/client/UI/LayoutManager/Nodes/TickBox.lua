require "ISUI/ISTickBox"

local TickBoxNode = {}

local function applyColor(target, color)
    if not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function rebuildOptions(tickBox, def)
    local options = def.options or {}

    tickBox:clearOptions()

    for i = 1, #options do
        local option = options[i]
        if type(option) == "table" then
            tickBox:addOption(option.text or option.name or "", option.data, option.texture)
        else
            tickBox:addOption(tostring(option), nil, nil)
        end
    end

    local selected = def.selected
    if type(selected) == "table" then
        for index = 1, #options do
            tickBox.selected[index] = selected[index] == true
        end
    end

    local disabledOptions = def.disabledOptions
    if type(disabledOptions) == "table" then
        for key, value in pairs(disabledOptions) do
            tickBox:disableOption(key, value == true)
        end
    end

    if def.autoWidth ~= nil then
        tickBox.autoWidth = def.autoWidth == true
    end

    if def.onlyOnePossibility ~= nil then
        tickBox.onlyOnePossibility = def.onlyOnePossibility == true
    end

    if def.font then
        tickBox:setFont(def.font)
    end

    if def.fitWidth then
        tickBox:setWidthToFit()
    end
end

local function updateTickBox(tickBox, frame, def)
    tickBox:setX(frame.x)
    tickBox:setY(frame.y)
    tickBox:setWidth(frame.width)

    tickBox.changeOptionTarget = def.target
    tickBox.changeOptionMethod = def.onChange

    if def.args then
        tickBox.changeOptionArgs = def.args
    else
        tickBox.changeOptionArgs = { nil, nil }
    end

    if def.tooltip ~= nil then
        tickBox.tooltip = def.tooltip
    end

    if def.enable ~= nil then
        tickBox.enable = def.enable == true
    elseif def.enabled ~= nil then
        tickBox.enable = def.enabled == true
    end

    if def.leftMargin ~= nil then
        tickBox.leftMargin = def.leftMargin
    end
    if def.boxSize ~= nil then
        tickBox.boxSize = def.boxSize
    end
    if def.textGap ~= nil then
        tickBox.textGap = def.textGap
    end
    if def.itemGap ~= nil then
        tickBox.itemGap = def.itemGap
    end

    tickBox.itemHgt = math.max(tickBox.boxSize, tickBox.fontHgt) + tickBox.itemGap

    applyColor(tickBox.borderColor, def.borderColor)
    applyColor(tickBox.backgroundColor, def.backgroundColor)
    applyColor(tickBox.choicesColor, def.choicesColor)

    rebuildOptions(tickBox, def)

    if def.height ~= nil then
        tickBox:setHeight(frame.height)
    end
end

local function createTickBox(panel, frame, def)
    local tickBox = ISTickBox:new(
        frame.x,
        frame.y,
        frame.width,
        frame.height,
        def.name or "",
        def.target,
        def.onChange,
        nil,
        nil
    )

    tickBox:initialise()
    panel:addChild(tickBox)

    tickBox.__layoutType = "tickbox"

    updateTickBox(tickBox, frame, def)
    return tickBox
end

function TickBoxNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: tickbox is missing required id")
        return
    end

    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "tickbox" then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createTickBox(panel, frame, def)
        state.elementsById[def.id] = element
    else
        updateTickBox(element, frame, def)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("tickbox", TickBoxNode)
end
