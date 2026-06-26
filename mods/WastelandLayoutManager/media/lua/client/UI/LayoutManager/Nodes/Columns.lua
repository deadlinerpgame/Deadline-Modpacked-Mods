local ColumnsNode = {}

local function isPercentValue(value)
    return type(value) == "string" and string.match(value, "^%-?%d+%.?%d*%%$") ~= nil
end

function ColumnsNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    local children = layoutManager:_collectChildren(def)
    local pad = layoutManager:_resolveMargin(def.pad, frame.width, frame.height).left
    local requestedWidths = {}
    local requestedHeights = {}
    local flexWeights = {}
    local margins = {}
    local fixedWidth = 0
    local totalHorizontalMargin = 0
    local totalPad = pad * math.max(0, #children - 1)
    local flexWeightTotal = 0

    for i = 1, #children do
        local child = children[i]
        local margin = layoutManager:_resolveMargin(child.margin, frame.width, frame.height)
        margins[i] = margin

        if child.width == nil then child.width = "*" end
        if child.height == nil then child.height = "inherit" end

        totalHorizontalMargin = totalHorizontalMargin + margin.left + margin.right
    end

    local availableMainAxisWidth = math.max(0, frame.width - totalHorizontalMargin - totalPad)

    for i = 1, #children do
        local child = children[i]
        local margin = margins[i]

        local childParentWidth = math.max(0, frame.width - margin.left - margin.right)
        local childParentHeight = math.max(0, frame.height - margin.top - margin.bottom)

        if isPercentValue(child.width) then
            childParentWidth = availableMainAxisWidth
        end

        local width, weight = layoutManager:_resolveDimension(child, "width", childParentWidth, childParentHeight, true, false, 0)
        local height = layoutManager:_resolveDimension(child, "height", childParentWidth, childParentHeight, false, false, 0)

        requestedWidths[i] = width
        requestedHeights[i] = height
        flexWeights[i] = weight or 1

        if width == nil then
            flexWeightTotal = flexWeightTotal + flexWeights[i]
        else
            fixedWidth = fixedWidth + width
        end
    end

    local remaining = frame.width - fixedWidth - totalHorizontalMargin - totalPad
    if remaining < 0 then
        remaining = 0
    end

    local offset = 0
    for i = 1, #children do
        local child = children[i]
        local margin = margins[i]
        local mainSize = requestedWidths[i]

        if mainSize == nil then
            if flexWeightTotal > 0 then
                mainSize = remaining * (flexWeights[i] / flexWeightTotal)
            else
                mainSize = 0
            end
        end

        offset = offset + margin.left
        local childFrame = {
            x = frame.x + offset,
            y = frame.y + margin.top,
            width = mainSize,
            height = requestedHeights[i]
        }

        layoutManager:_applyNode(panel, state, child, childFrame, elementsOut, seenIds)
        offset = offset + mainSize + margin.right
        if i < #children then
            offset = offset + pad
        end
    end
end

return function(layoutManager)
    layoutManager.registerNode("columns", ColumnsNode)
end
