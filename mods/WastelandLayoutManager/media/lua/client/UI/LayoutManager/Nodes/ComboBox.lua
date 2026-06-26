require "ISUI/ISComboBox"

local ComboBoxNode = {}

local function applyColor(target, color)
    if not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function applySelection(comboBox, def)
    if def.selected ~= nil then
        local selectedIndex = tonumber(def.selected) or 0
        if selectedIndex < 0 then
            selectedIndex = 0
        end
        if selectedIndex > #comboBox.options then
            selectedIndex = #comboBox.options
        end
        comboBox.selected = selectedIndex
        return
    end

    if def.selectedText ~= nil then
        comboBox:select(tostring(def.selectedText))
        return
    end

    if def.selectedData ~= nil then
        comboBox:selectData(def.selectedData)
    end
end

local function rebuildOptions(comboBox, def)
    if type(def.options) ~= "table" then
        return
    end

    local previousSelectedText = comboBox:getSelectedText()
    comboBox:clear()

    local options = def.options
    for i = 1, #options do
        local option = options[i]
        if type(option) == "table" then
            local optionText = tostring(option.text or option.name or "")
            comboBox:addOptionWithData(optionText, option.data)

            if option.tooltip ~= nil then
                comboBox.tooltip[optionText] = option.tooltip
            end
        else
            comboBox:addOption(tostring(option))
        end
    end

    if def.selected == nil and def.selectedText == nil and def.selectedData == nil and previousSelectedText ~= nil then
        comboBox:select(previousSelectedText)
    end
end

local function updateComboBox(comboBox, frame, def)
    comboBox:setX(frame.x)
    comboBox:setY(frame.y)
    comboBox:setWidth(frame.width)
    comboBox:setHeight(frame.height)
    comboBox.baseHeight = frame.height

    comboBox.target = def.target
    comboBox.onChange = def.onChange

    if def.args then
        comboBox.onChangeArgs = def.args
    else
        comboBox.onChangeArgs = { nil, nil }
    end

    if def.font then
        comboBox.font = def.font
    end

    if def.noSelectionText ~= nil then
        comboBox.noSelectionText = tostring(def.noSelectionText)
    end

    if def.openUpwards ~= nil then
        comboBox.openUpwards = def.openUpwards == true
    end

    if def.editable ~= nil then
        comboBox:setEditable(def.editable == true)
    end

    if def.filterText ~= nil then
        comboBox:setFilterText(def.filterText)
    end

    if def.disabled ~= nil then
        comboBox.disabled = def.disabled == true
    else
        local enabled = def.enable
        if enabled == nil then
            enabled = def.enabled
        end
        if enabled ~= nil then
            comboBox.disabled = enabled ~= true
        end
    end

    applyColor(comboBox.backgroundColor, def.backgroundColor)
    applyColor(comboBox.backgroundColorMouseOver, def.backgroundColorMouseOver)
    applyColor(comboBox.borderColor, def.borderColor)
    applyColor(comboBox.textColor, def.textColor)

    rebuildOptions(comboBox, def)
    applySelection(comboBox, def)

    if type(def.tooltip) == "table" then
        comboBox:setToolTipMap(def.tooltip)
    end
end

local function createComboBox(panel, frame, def)
    local comboBox = ISComboBox:new(frame.x, frame.y, frame.width, frame.height, def.target, def.onChange, nil, nil)

    comboBox:initialise()
    comboBox:instantiate()
    panel:addChild(comboBox)

    comboBox.__layoutType = "combobox"

    updateComboBox(comboBox, frame, def)
    return comboBox
end

function ComboBoxNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: combobox is missing required id")
        return
    end

    local element = state.elementsById[def.id]
    if element and element.__layoutType ~= "combobox" then
        panel:removeChild(element)
        element = nil
    end

    if not element then
        element = createComboBox(panel, frame, def)
        state.elementsById[def.id] = element
    else
        updateComboBox(element, frame, def)
    end

    elementsOut[def.id] = element
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("combobox", ComboBoxNode)
end
