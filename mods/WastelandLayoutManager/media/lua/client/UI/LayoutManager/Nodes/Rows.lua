local RowsNode = {}

function RowsNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    local children = layoutManager:_collectChildren(def)
    local pad = layoutManager:_resolveMargin(def.pad, frame.width, frame.height).top
    local requestedHeights = {}
    local requestedWidths = {}
    local flexWeights = {}
    local margins = {}
    local fixedHeight = 0
    local totalVerticalMargin = 0
    local totalPad = pad * math.max(0, #children - 1)
    local flexWeightTotal = 0

    for i = 1, #children do
        local child = children[i]
        local margin = layoutManager:_resolveMargin(child.margin, frame.width, frame.height)
        margins[i] = margin

        local childParentWidth = math.max(0, frame.width - margin.left - margin.right)
        local childParentHeight = math.max(0, frame.height - margin.top - margin.bottom)
        
        if child.width == nil then child.width = "inherit" end
        if child.height == nil then child.height = "*" end

        local height, weight = layoutManager:_resolveDimension(child, "height", childParentWidth, childParentHeight, true, false, 0)
        local width = layoutManager:_resolveDimension(child, "width", childParentWidth, childParentHeight, false, false, 0)

        requestedHeights[i] = height
        requestedWidths[i] = width
        flexWeights[i] = weight or 1

        totalVerticalMargin = totalVerticalMargin + margin.top + margin.bottom

        if height == nil then
            flexWeightTotal = flexWeightTotal + flexWeights[i]
        else
            fixedHeight = fixedHeight + height
        end
    end

    local remaining = frame.height - fixedHeight - totalVerticalMargin - totalPad
    if remaining < 0 then
        remaining = 0
    end

    local offset = 0
    for i = 1, #children do
        local child = children[i]
        local margin = margins[i]
        local mainSize = requestedHeights[i]

        if mainSize == nil then
            if flexWeightTotal > 0 then
                mainSize = remaining * (flexWeights[i] / flexWeightTotal)
            else
                mainSize = 0
            end
        end

        offset = offset + margin.top
        local childFrame = {
            x = frame.x + margin.left,
            y = frame.y + offset,
            width = requestedWidths[i],
            height = mainSize
        }

        layoutManager:_applyNode(panel, state, child, childFrame, elementsOut, seenIds)
        offset = offset + mainSize + margin.bottom
        if i < #children then
            offset = offset + pad
        end
    end
end

return function(layoutManager)
    layoutManager.registerNode("rows", RowsNode)
end
