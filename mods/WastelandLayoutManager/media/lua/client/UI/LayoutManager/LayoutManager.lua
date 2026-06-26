if not isClient() then return end

LayoutManager = LayoutManager or {}
LayoutManager.Version = 0.3
LayoutManager.NodeHandlers = LayoutManager.NodeHandlers or {}

local function clampToZero(value)
    if value == nil or value < 0 then
        return 0
    end

    return value
end

local function parseFlexWeight(value)
    if value == "*" then
        return 1
    end

    if type(value) == "string" then
        local divisorText = string.match(value, "^%*/(%-?%d+%.?%d*)$")
        if divisorText then
            local divisor = tonumber(divisorText)
            if divisor and divisor > 0 then
                return 1 / divisor
            end
        end
    end

    return nil
end

local function resolveNumber(value, parentSize, scale)
    local appliedScale = scale or 1

    if type(value) == "number" then
        return value * appliedScale
    end

    if type(value) == "string" then
        local px = string.match(value, "^%s*(%-?%d+%.?%d*)px%s*$")
        if px ~= nil then
            return tonumber(px)
        end

        local numeric = tonumber(value)
        if numeric ~= nil then
            return numeric * appliedScale
        end

        local percent = string.match(value, "^(%-?%d+%.?%d*)%%$")
        if percent and parentSize ~= nil then
            return parentSize * (tonumber(percent) / 100)
        end
    end

    return nil
end

local function resolveMainSize(value, parentSize, scale)
    if value == "inherit" then
        return parentSize
    end

    if parseFlexWeight(value) ~= nil then
        return nil
    end

    if value == "auto" then
        return nil
    end

    return resolveNumber(value, parentSize, scale)
end

local function resolveCrossSize(value, parentSize, scale)
    if value == "auto" then
        return nil
    end

    if value == "inherit" then
        return parentSize
    end

    if parseFlexWeight(value) ~= nil then
        return parentSize
    end

    local resolved = resolveNumber(value, parentSize, scale)
    if resolved == nil then
        return parentSize
    end

    return resolved
end

local function resolvePosition(value, parentSize, scale)
    local resolved = resolveNumber(value, parentSize, scale)
    if resolved == nil then
        return 0
    end

    return resolved
end

function LayoutManager.registerNode(nodeType, handler)
    if type(nodeType) ~= "string" or nodeType == "" then
        print("LayoutManager: node type must be a non-empty string")
        return
    end

    if type(handler) ~= "table" or type(handler.apply) ~= "function" then
        print("LayoutManager: node handler for '" .. tostring(nodeType) .. "' must define apply")
        return
    end

    LayoutManager.NodeHandlers[nodeType] = handler
end

function LayoutManager:_resolveMainSize(value, parentSize)
    return resolveMainSize(value, parentSize, self:_getScale())
end

function LayoutManager:_resolveCrossSize(value, parentSize)
    return resolveCrossSize(value, parentSize, self:_getScale())
end

function LayoutManager:_resolveSizeSpec(value, parentSize, isMainAxis)
    local numeric = resolveNumber(value, parentSize, self:_getScale())
    if numeric ~= nil then
        return "fixed", numeric, nil
    end

    if value == "inherit" then
        return "fixed", parentSize, nil
    end

    if value == "auto" then
        return "auto", nil, nil
    end

    local flexWeight = parseFlexWeight(value)
    if flexWeight ~= nil then
        if isMainAxis then
            return "flex", nil, flexWeight
        end

        return "fixed", parentSize, nil
    end

    if value == nil then
        if isMainAxis then
            return "flex", nil, 1
        end

        return "fixed", parentSize, nil
    end

    if isMainAxis then
        return "flex", nil, 1
    end

    return "fixed", parentSize, nil
end

function LayoutManager:_getScale()
    return getTextManager():MeasureStringY(UIFont.Small, "X") / 14
end

function LayoutManager:_resolveMargin(marginDef, parentWidth, parentHeight)
    local scale = self:_getScale()
    local top
    local right
    local bottom
    local left

    if type(marginDef) == "number" or type(marginDef) == "string" then
        top = marginDef
        right = marginDef
        bottom = marginDef
        left = marginDef
    elseif type(marginDef) == "table" then
        if marginDef.top ~= nil or marginDef.right ~= nil or marginDef.bottom ~= nil or marginDef.left ~= nil then
            top = marginDef.top or 0
            right = marginDef.right or 0
            bottom = marginDef.bottom or 0
            left = marginDef.left or 0
        else
            local count = #marginDef
            if count == 1 then
                top = marginDef[1]
                right = marginDef[1]
                bottom = marginDef[1]
                left = marginDef[1]
            elseif count == 2 then
                top = marginDef[1]
                right = marginDef[2]
                bottom = marginDef[1]
                left = marginDef[2]
            elseif count == 3 then
                top = marginDef[1]
                right = marginDef[2]
                bottom = marginDef[3]
                left = marginDef[2]
            elseif count >= 4 then
                top = marginDef[1]
                right = marginDef[2]
                bottom = marginDef[3]
                left = marginDef[4]
            end
        end
    end

    local margin = {
        top = clampToZero(resolveNumber(top, parentHeight, scale) or 0),
        right = clampToZero(resolveNumber(right, parentWidth, scale) or 0),
        bottom = clampToZero(resolveNumber(bottom, parentHeight, scale) or 0),
        left = clampToZero(resolveNumber(left, parentWidth, scale) or 0)
    }

    return margin
end

function LayoutManager:_measureAutoDimension(def, axis, parentWidth, parentHeight, depth)
    if not def or not def.type then
        return 0
    end

    if depth > 24 then
        return 0
    end

    local isRows = def.type == "rows"
    local isColumns = def.type == "columns"
    local isPanelLike = def.type == "panel" or def.type == "scrollpanel"

    if isPanelLike then
        if def.child then
            local childMargin = self:_resolveMargin(def.child.margin, parentWidth, parentHeight)
            local childParentWidth = clampToZero(parentWidth - childMargin.left - childMargin.right)
            local childParentHeight = clampToZero(parentHeight - childMargin.top - childMargin.bottom)
            local childSize = clampToZero(self:_resolveDimension(def.child, axis, childParentWidth, childParentHeight, false, true, depth + 1, axis))

            if axis == "height" then
                return childSize + childMargin.top + childMargin.bottom
            end

            return childSize + childMargin.left + childMargin.right
        end

        return 0
    end

    if not isRows and not isColumns then
        return 0
    end

    local children = self:_collectChildren(def)

    if #children == 0 then
        return 0
    end

    local mainAxis = isRows and "height" or "width"
    local crossAxis = isRows and "width" or "height"
    local padMargin = self:_resolveMargin(def.pad, parentWidth, parentHeight)
    local pad = isRows and padMargin.top or padMargin.left
    local totalPad = pad * math.max(0, #children - 1)
    local totalMainOuter = 0
    local maxCrossOuter = 0

    for i = 1, #children do
        local child = children[i]
        local margin = self:_resolveMargin(child.margin, parentWidth, parentHeight)

        local childParentWidth = clampToZero(parentWidth - margin.left - margin.right)
        local childParentHeight = clampToZero(parentHeight - margin.top - margin.bottom)

        local childMain = self:_resolveDimension(child, mainAxis, childParentWidth, childParentHeight, true, true, depth + 1, axis)
        local childCross = self:_resolveDimension(child, crossAxis, childParentWidth, childParentHeight, false, true, depth + 1, axis)

        local outerMain
        local outerCross
        if isRows then
            outerMain = childMain + margin.top + margin.bottom
            outerCross = childCross + margin.left + margin.right
        else
            outerMain = childMain + margin.left + margin.right
            outerCross = childCross + margin.top + margin.bottom
        end

        totalMainOuter = totalMainOuter + outerMain
        if outerCross > maxCrossOuter then
            maxCrossOuter = outerCross
        end
    end

    if isRows then
        if axis == "height" then
            return totalMainOuter + totalPad
        end

        return maxCrossOuter
    end

    if axis == "width" then
        return totalMainOuter + totalPad
    end

    return maxCrossOuter
end

function LayoutManager:_resolveDimension(def, axis, parentWidth, parentHeight, isMainAxis, forMeasurement, depth, measurementAxis)
    local parentSize = axis == "width" and parentWidth or parentHeight
    local sizeSpec = def[axis]
    local mode, resolved, weight = self:_resolveSizeSpec(sizeSpec, parentSize, isMainAxis)

    if mode == "fixed" then
        local isContainer = def.type == "rows" or def.type == "columns"
        if forMeasurement and measurementAxis == axis and sizeSpec == "inherit" and isContainer then
            return clampToZero(self:_measureAutoDimension(def, axis, parentWidth, parentHeight, depth + 1))
        end

        return clampToZero(resolved)
    end

    if mode == "flex" then
        if forMeasurement then
            if isMainAxis then
                return 0
            end

            return clampToZero(parentSize)
        end

        if isMainAxis then
            return nil, weight
        end

        return clampToZero(parentSize)
    end

    return clampToZero(self:_measureAutoDimension(def, axis, parentWidth, parentHeight, depth + 1))
end

function LayoutManager:_collectChildren(def)
    local children = {}
    local source = nil

    if def.type == "rows" then
        source = def.rows
    elseif def.type == "columns" then
        source = def.columns
    end

    if source then
        for i = 1, #source do
            children[#children + 1] = source[i]
        end
    end

    if def.data and def.generator then
        for i, row in ipairs(def.data) do
            local generated = def.generator(row, i, def)
            if generated then
                children[#children + 1] = generated
            end
        end
    end

    return children
end

function LayoutManager:_generateAutoId(def, autoIdState)
    local nodeType = tostring(def.type or "node")
    local counters = autoIdState.counters
    local used = autoIdState.used

    local index = counters[nodeType] or 0
    local id

    repeat
        index = index + 1
        id = nodeType .. tostring(index)
    until not used[id]

    counters[nodeType] = index
    used[id] = true

    return id
end

local nodeModules = {
    "UI/LayoutManager/Nodes/Gap",
    "UI/LayoutManager/Nodes/Rows",
    "UI/LayoutManager/Nodes/Columns",
    "UI/LayoutManager/Nodes/Element",
    "UI/LayoutManager/Nodes/Panel",
    "UI/LayoutManager/Nodes/ScrollPanel",
    "UI/LayoutManager/Nodes/SliderPanel",
    "UI/LayoutManager/Nodes/ScrollingListBox",
    "UI/LayoutManager/Nodes/TabPanel",
    "UI/LayoutManager/Nodes/Button",
    "UI/LayoutManager/Nodes/ComboBox",
    "UI/LayoutManager/Nodes/Label",
    "UI/LayoutManager/Nodes/TextBox",
    "UI/LayoutManager/Nodes/TickBox"
}

for i = 1, #nodeModules do
    local modulePath = nodeModules[i]
    local registerNode = require(modulePath)

    if type(registerNode) == "function" then
        registerNode(LayoutManager)
    else
        print("LayoutManager: node module '" .. modulePath .. "' did not return a registration function")
    end
end

if getDebug() then
    local registerDemo = require("UI/LayoutManager/LayoutManagerDemo")
    if type(registerDemo) == "function" then
        registerDemo(LayoutManager)
    else
        print("LayoutManager: demo module did not return a registration function")
    end

    local registerLayoutMaker = require("UI/LayoutManager/LayoutMaker")
    if type(registerLayoutMaker) == "function" then
        registerLayoutMaker(LayoutManager)
    else
        print("LayoutManager: layout maker module did not return a registration function")
    end
end

function LayoutManager:_applyNode(panel, state, def, frame, elementsOut, seenIds)
    if not def or not def.type then
        return
    end

    local autoIdState = state.__wlAutoIdState
    if autoIdState then
        if def.id == nil or def.id == "" then
            def.id = self:_generateAutoId(def, autoIdState)
        elseif not autoIdState.used[def.id] then
            autoIdState.used[def.id] = true
        end
    end

    local handler = self.NodeHandlers[def.type]
    if not handler then
        print("LayoutManager: unsupported element type '" .. tostring(def.type) .. "'")
        return
    end

    handler.apply(self, panel, state, def, frame, elementsOut, seenIds)
end

function LayoutManager:applyLayout(panel, layout)
    if not panel or not layout then
        return {}
    end

    if not panel.__wlLayoutState then
        panel.__wlLayoutState = {
            elementsById = {}
        }
    end

    local state = panel.__wlLayoutState
    state.__wlAutoIdState = {
        counters = {},
        used = {}
    }

    local scale = self:_getScale()

    local panelWidth = panel.width
    local panelHeight = panel.height

    local rootX = resolvePosition(layout.x, panelWidth, scale)
    local rootY = resolvePosition(layout.y, panelHeight, scale)
    local rootWidth = self:_resolveDimension(layout, "width", panelWidth, panelHeight, false, false, 0)
    local rootHeight = self:_resolveDimension(layout, "height", panelWidth, panelHeight, false, false, 0)
    local rootMargin = self:_resolveMargin(layout.margin, panelWidth, panelHeight)

    local rootFrame = {
        x = rootX + rootMargin.left,
        y = rootY + rootMargin.top,
        width = clampToZero(rootWidth - rootMargin.left - rootMargin.right),
        height = clampToZero(rootHeight - rootMargin.top - rootMargin.bottom)
    }

    local elements = {}
    local seenIds = {}

    self:_applyNode(panel, state, layout, rootFrame, elements, seenIds)

    for id, child in pairs(state.elementsById) do
        if not seenIds[id] then
            panel:removeChild(child)
            state.elementsById[id] = nil
        end
    end

    state.__wlAutoIdState = nil

    return elements
end
