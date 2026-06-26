require "ISUI/ISTextEntryBox"

local TextBoxNode = {}

local function applyColor(target, color)
    if not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function updateText(textBox, def)
    local layoutText = def.text
    if layoutText == nil then
        layoutText = def.value
    end
    if layoutText == nil then
        layoutText = ""
    end

    local currentText = textBox:getText()
    if currentText == textBox.__wlLastLayoutText then
        textBox:setText(tostring(layoutText))
        textBox.__wlLastLayoutText = textBox:getText()
    end
end

local function updateTextBox(textBox, frame, def)
    textBox:setX(frame.x)
    textBox:setY(frame.y)
    textBox:setWidth(frame.width)
    textBox:setHeight(frame.height)

    updateText(textBox, def)

    textBox.target = def.target
    if def.onCommandEntered ~= nil then
        textBox.onCommandEntered = def.onCommandEntered
    end
    if def.onTextChange ~= nil then
        textBox.onTextChange = def.onTextChange
    end
    if def.onPressDown ~= nil then
        textBox.onPressDown = def.onPressDown
    end
    if def.onPressUp ~= nil then
        textBox.onPressUp = def.onPressUp
    end

    if def.onlyNumbers ~= nil then
        textBox:setOnlyNumbers(def.onlyNumbers == true)
    end

    if def.editable ~= nil then
        textBox:setEditable(def.editable == true)
    end

    if def.selectable ~= nil then
        textBox:setSelectable(def.selectable == true)
    end

    if def.multipleLine ~= nil then
        textBox:setMultipleLine(def.multipleLine == true)
    end

    if def.maxLines ~= nil then
        textBox:setMaxLines(def.maxLines)
    end

    if def.maxTextLength ~= nil then
        textBox:setMaxTextLength(def.maxTextLength)
    end

    if def.forceUpperCase ~= nil then
        textBox:setForceUpperCase(def.forceUpperCase == true)
    end

    if def.masked ~= nil then
        textBox:setMasked(def.masked == true)
    end

    if def.clearButton ~= nil then
        textBox:setClearButton(def.clearButton == true)
    end

    if def.hasFrame ~= nil then
        textBox:setHasFrame(def.hasFrame == true)
    end

    if def.frameAlpha ~= nil then
        textBox:setFrameAlpha(def.frameAlpha)
    end

    if def.valid ~= nil then
        textBox:setValid(def.valid == true)
    end

    if def.tooltip ~= nil then
        textBox:setTooltip(def.tooltip)
    end

    applyColor(textBox.backgroundColor, def.backgroundColor)
    applyColor(textBox.borderColor, def.borderColor)
end

local function createTextBox(panel, frame, def)
    local initialText = def.text
    if initialText == nil then
        initialText = def.value
    end
    if initialText == nil then
        initialText = ""
    end

    local textBox = ISTextEntryBox:new(tostring(initialText), frame.x, frame.y, frame.width, frame.height)
    if def.font then
        textBox.font = def.font
    end

    textBox:initialise()
    textBox:instantiate()
    panel:addChild(textBox)

    textBox.__layoutType = "textbox"
    textBox.__wlLastLayoutText = textBox:getText()

    updateTextBox(textBox, frame, def)
    return textBox
end

function TextBoxNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: textbox is missing required id")
        return
    end

    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "textbox" then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createTextBox(panel, frame, def)
        state.elementsById[def.id] = element
    else
        updateTextBox(element, frame, def)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("textbox", TextBoxNode)
end
