require "RadioCom/ISUIRadio/ISSliderPanel"

local SliderPanelNode = {}

local function applyColor(target, color)
    if not target or not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function updateSliderValues(sliderPanel, def)
    local hasValuePatch = def.minValue ~= nil or def.maxValue ~= nil or def.stepValue ~= nil or def.shiftValue ~= nil
    if hasValuePatch then
        sliderPanel:setValues(
            def.minValue ~= nil and def.minValue or sliderPanel.minValue,
            def.maxValue ~= nil and def.maxValue or sliderPanel.maxValue,
            def.stepValue ~= nil and def.stepValue or sliderPanel.stepValue,
            def.shiftValue ~= nil and def.shiftValue or sliderPanel.shiftValue,
            true
        )
    end

    local currentValue = def.currentValue
    if currentValue == nil then
        currentValue = def.value
    end

    if currentValue ~= nil then
        sliderPanel:setCurrentValue(currentValue, true)
    elseif hasValuePatch then
        sliderPanel:setCurrentValue(sliderPanel.currentValue, true)
    end
end

local function updateSliderPanel(sliderPanel, frame, def)
    sliderPanel:setX(frame.x)
    sliderPanel:setY(frame.y)
    sliderPanel:setWidth(frame.width)
    sliderPanel:setHeight(frame.height)

    sliderPanel.target = def.target
    sliderPanel.onValueChange = def.onValueChange
    sliderPanel.customPaginate = def.customPaginate

    if def.doButtons ~= nil then
        sliderPanel:setDoButtons(def.doButtons == true)
    end

    if def.doToolTip ~= nil then
        sliderPanel.doToolTip = def.doToolTip == true
    end

    if def.toolTipText ~= nil then
        sliderPanel.toolTipText = tostring(def.toolTipText)
    end

    applyColor(sliderPanel.buttonColor, def.buttonColor)
    applyColor(sliderPanel.buttonMouseOverColor, def.buttonMouseOverColor)
    applyColor(sliderPanel.sliderColor, def.sliderColor)
    applyColor(sliderPanel.sliderMouseOverColor, def.sliderMouseOverColor)
    applyColor(sliderPanel.sliderBorderColor, def.sliderBorderColor)
    applyColor(sliderPanel.sliderBarColor, def.sliderBarColor)
    applyColor(sliderPanel.sliderBarBorderColor, def.sliderBarBorderColor)

    updateSliderValues(sliderPanel, def)
    sliderPanel:paginate()
end

local function createSliderPanel(panel, frame, def)
    local sliderPanel = ISSliderPanel:new(frame.x, frame.y, frame.width, frame.height, def.target, def.onValueChange, def.customPaginate)
    sliderPanel:initialise()
    panel:addChild(sliderPanel)

    sliderPanel.__layoutType = "sliderpanel"

    updateSliderPanel(sliderPanel, frame, def)
    return sliderPanel
end

function SliderPanelNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: sliderpanel is missing required id")
        return
    end

    local sliderPanel = state.elementsById[def.id]
    if sliderPanel and sliderPanel.__layoutType ~= "sliderpanel" then
        panel:removeChild(sliderPanel)
        sliderPanel = nil
    end

    if not sliderPanel then
        sliderPanel = createSliderPanel(panel, frame, def)
        state.elementsById[def.id] = sliderPanel
    else
        updateSliderPanel(sliderPanel, frame, def)
    end

    elementsOut[def.id] = sliderPanel
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("sliderpanel", SliderPanelNode)
end
