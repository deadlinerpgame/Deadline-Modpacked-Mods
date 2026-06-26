require "ISUI/ISLabel"

local LabelNode = {}

local function normalizeLabelText(value)
    if value == nil then
        return ""
    end

    if type(value) == "string" then
        return value
    end

    return tostring(value)
end

local function getLabelTextMode(def)
    if type(def.text) == "function" then
        return "dynamic"
    end

    return "static"
end

local function configureDynamicPrerender(label)
    label.prerender = function(self)
        local dynamicText = normalizeLabelText(self.__wlTextProvider())
        if dynamicText ~= self.__wlLastLayoutText then
            self.text = dynamicText
            self.__wlLastLayoutText = dynamicText
            self:setName(dynamicText)
        end

        ISLabel.prerender(self)
    end
end

local function createLabel(panel, frame, def, textMode)
    local color = def.color or {}
    local r = color.r or 1
    local g = color.g or 1
    local b = color.b or 1
    local a = color.a or 1
    local text = ""
    if textMode == "dynamic" then
        text = normalizeLabelText(def.text())
    else
        text = normalizeLabelText(def.text)
    end
    local font = def.font or UIFont.Small
    local center = def.center == true

    local x = center and (frame.x + (frame.width / 2)) or frame.x

    local label = ISLabel:new(x, frame.y, frame.height, text, r, g, b, a, font, true)
    label.center = center
    label:initialise()
    panel:addChild(label)

    label:setWidth(frame.width)
    label:setHeight(frame.height)
    label.__layoutType = "label"
    label.text = text
    label.__wlLastLayoutText = text
    label.__wlTextMode = textMode

    if textMode == "dynamic" then
        label.__wlTextProvider = def.text
        configureDynamicPrerender(label)
    end

    return label
end

local function updateLabel(label, frame, def, textMode)
    local center = def.center == true
    local x = center and (frame.x + (frame.width / 2)) or frame.x

    label:setX(x)
    label:setY(frame.y)
    label:setWidth(frame.width)
    label:setHeight(frame.height)
    label.center = center
    label.originalX = x

    local color = def.color
    if color then
        label.r = color.r or 1
        label.g = color.g or 1
        label.b = color.b or 1
        label.a = color.a or 1
    end

    if textMode == "dynamic" then
        label.__wlTextProvider = def.text
        local dynamicText = normalizeLabelText(label.__wlTextProvider())
        if dynamicText ~= label.__wlLastLayoutText then
            label.text = dynamicText
            label.__wlLastLayoutText = dynamicText
            label:setName(dynamicText)
        end
    else
        local staticText = normalizeLabelText(def.text)
        if staticText ~= label.__wlLastLayoutText then
            label.text = staticText
            label.__wlLastLayoutText = staticText
            label:setName(staticText)
        end
    end
end

function LabelNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: label is missing required id")
        return
    end

    local textMode = getLabelTextMode(def)
    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "label" then
        panel:removeChild(element)
        element = nil
    end

    if element and element.__wlTextMode ~= textMode then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createLabel(panel, frame, def, textMode)
        state.elementsById[def.id] = element
    else
        updateLabel(element, frame, def, textMode)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("label", LabelNode)
end
