if not getDebug() then return nil end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local DEFAULT_LAYOUT_SOURCE = [[local sampleText = "Sample"
return { type = "label", text = sampleText }]]

local function setTextEntryValue(textEntry, value)
    local resolved = tostring(value or "")
    textEntry:setText(resolved)
    textEntry.__wlLastLayoutText = textEntry:getText()
end

local function joinLines(lines)
    return table.concat(lines, "\n")
end

local function collectLayoutNodes(node, lines, depth)
    if type(node) ~= "table" then
        return 0
    end

    local nodeType = tostring(node.type or "<missing type>")
    local nodeId = node.id and tostring(node.id) or "<auto>"
    local indent = string.rep("  ", depth)
    lines[#lines + 1] = indent .. "- " .. nodeType .. " (id=" .. nodeId .. ")"

    local count = 1

    if nodeType == "rows" and type(node.rows) == "table" then
        for i = 1, #node.rows do
            count = count + collectLayoutNodes(node.rows[i], lines, depth + 1)
        end
    elseif nodeType == "columns" and type(node.columns) == "table" then
        for i = 1, #node.columns do
            count = count + collectLayoutNodes(node.columns[i], lines, depth + 1)
        end
    elseif nodeType == "tabpanel" and type(node.tabs) == "table" then
        for i = 1, #node.tabs do
            local tab = node.tabs[i]
            local tabId = "<missing id>"
            if type(tab) == "table" and tab.id ~= nil then
                tabId = tostring(tab.id)
            end

            lines[#lines + 1] = indent .. "  [tab " .. tabId .. "]"

            if type(tab) == "table" then
                count = count + collectLayoutNodes(tab.content, lines, depth + 1)
            end
        end
    elseif nodeType == "panel" and type(node.child) == "table" then
        count = count + collectLayoutNodes(node.child, lines, depth + 1)
    end

    return count
end

local function collectElementIds(elements)
    local ids = {}

    for id in pairs(elements or {}) do
        ids[#ids + 1] = tostring(id)
    end

    table.sort(ids)
    return ids
end

local LayoutMakerPreviewWindow = ISCollapsableWindow:derive("LayoutMakerPreviewWindow")

function LayoutMakerPreviewWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function LayoutMakerPreviewWindow:createChildren()
    if self._childrenCreated then
        return
    end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)

    local pad = 8
    local contentY = self:titleBarHeight() + pad
    self.contentPanel = ISPanel:new(
        pad,
        contentY,
        math.max(0, self.width - (pad * 2)),
        math.max(0, self.height - contentY - pad)
    )
    self.contentPanel:initialise()
    self.contentPanel:noBackground()
    self:addChild(self.contentPanel)
end

function LayoutMakerPreviewWindow:onResize()
    ISUIElement.onResize(self)

    if not self.contentPanel then
        return
    end

    local pad = 8
    local contentY = self:titleBarHeight() + pad
    self.contentPanel:setX(pad)
    self.contentPanel:setY(contentY)
    self.contentPanel:setWidth(math.max(0, self.width - (pad * 2)))
    self.contentPanel:setHeight(math.max(0, self.height - contentY - pad))

    if self.currentLayout then
        self.elements = self.layoutManager:applyLayout(self.contentPanel, self.currentLayout)
    end
end

function LayoutMakerPreviewWindow:setLayoutSize(width, height)
    self:setWidth(width)
    self:setHeight(height)
    self:onResize()
end

function LayoutMakerPreviewWindow:applyPreviewLayout(layout)
    self.currentLayout = layout
    self.elements = self.layoutManager:applyLayout(self.contentPanel, layout)
    return self.elements
end

function LayoutMakerPreviewWindow:close()
    ISCollapsableWindow.close(self)

    if self.layoutManager and self.layoutManager._layoutMakerPreviewWindow == self then
        self.layoutManager._layoutMakerPreviewWindow = nil
    end
end

function LayoutMakerPreviewWindow:new(x, y, width, height, layoutManager)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true
    o.resizable = true
    o.pin = true
    o.alwaysOnTop = true
    o.title = "LayoutMaker Preview"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }
    o.layoutManager = layoutManager
    o.currentLayout = nil
    o.elements = {}

    return o
end

local LayoutMakerEditorWindow = ISCollapsableWindow:derive("LayoutMakerEditorWindow")

function LayoutMakerEditorWindow:setDebugText(text)
    self.debugText = tostring(text or "")

    if self.elements and self.elements.debug_output then
        setTextEntryValue(self.elements.debug_output, self.debugText)
    end
end

function LayoutMakerEditorWindow:buildEditorLayout()
    return  { type = "rows", width = "inherit", height = "inherit", margin = 6, pad = 6, rows = {
                { type = "label", height = 20, text = "Paste Lua source that returns a layout table. The source can define functions and data before returning." },
                { type = "columns", height = 24, width = "inherit", pad = 6, columns = {
                    { type = "label", width = 68, text = "Window W" },
                    { type = "textbox", id = "window_width", width = 90, text = tostring(self.previewWidth), onlyNumbers = true },
                    { type = "label", width = 68, text = "Window H" },
                    { type = "textbox", id = "window_height", width = 90, text = tostring(self.previewHeight), onlyNumbers = true },
                    { type = "gap", width = "*" },
                    { type = "button", id = "run_layout", width = 110, text = "Go", target = self, onClick = self.onRunLayout },
                }},
                { type = "label", height = 18, text = "Layout Source" },
                { type = "textbox", id = "layout_source", height = "*", text = self.sourceText, multipleLine = true, maxLines = 4096, clearButton = false },
                { type = "label", height = 18, text = "Debug Output" },
                { type = "textbox", id = "debug_output", height = 170, text = self.debugText, multipleLine = true, maxLines = 4096, editable = false, selectable = true, clearButton = false }
            }}
end

function LayoutMakerEditorWindow:applyEditorLayout()
    self.layout = self:buildEditorLayout()
    self.elements = self.layoutManager:applyLayout(self.contentPanel, self.layout)

    setTextEntryValue(self.elements.layout_source, self.sourceText)
    setTextEntryValue(self.elements.debug_output, self.debugText)
    setTextEntryValue(self.elements.window_width, tostring(self.previewWidth))
    setTextEntryValue(self.elements.window_height, tostring(self.previewHeight))
end

function LayoutMakerEditorWindow:readPreviewSize()
    local widthText = self.elements.window_width:getText()
    local heightText = self.elements.window_height:getText()

    local width = math.floor(tonumber(widthText) or self.previewWidth)
    local height = math.floor(tonumber(heightText) or self.previewHeight)

    if width < 180 then
        width = 180
    end

    if height < 120 then
        height = 120
    end

    self.previewWidth = width
    self.previewHeight = height

    setTextEntryValue(self.elements.window_width, tostring(self.previewWidth))
    setTextEntryValue(self.elements.window_height, tostring(self.previewHeight))

    return width, height
end

function LayoutMakerEditorWindow:compileLayout(source)
    local chunk, loadErr = loadstring(source or "", "LayoutMakerInput")
    if not chunk then
        return nil, "Compile error: " .. tostring(loadErr)
    end

    if setfenv then
        local env = setmetatable({}, { __index = _G })
        setfenv(chunk, env)
    end

    local ok, result = pcall(chunk)
    if not ok then
        return nil, "Runtime error: " .. tostring(result)
    end

    if type(result) ~= "table" then
        return nil, "Returned value must be a layout table, got " .. tostring(type(result))
    end

    return result, nil
end

function LayoutMakerEditorWindow:showOrRebuildPreview(layout, width, height)
    local preview = self.layoutManager._layoutMakerPreviewWindow

    if preview and preview:isVisible() then
        preview:setLayoutSize(width, height)
        local elements = preview:applyPreviewLayout(layout)
        return elements, "Reapplied layout to visible preview window."
    end

    if preview then
        preview:close()
        self.layoutManager._layoutMakerPreviewWindow = nil
    end

    local x = getCore():getScreenWidth() / 2 - width / 2
    local y = getCore():getScreenHeight() / 2 - height / 2

    preview = LayoutMakerPreviewWindow:new(x, y, width, height, self.layoutManager)
    preview:initialise()
    preview:addToUIManager()
    preview:setVisible(true)
    preview:setLayoutSize(width, height)

    local elements = preview:applyPreviewLayout(layout)
    self.layoutManager._layoutMakerPreviewWindow = preview

    return elements, "Created preview window and applied layout."
end

function LayoutMakerEditorWindow:onRunLayout()
    self.sourceText = self.elements.layout_source:getText()
    local width, height = self:readPreviewSize()

    local layout, err = self:compileLayout(self.sourceText)
    if not layout then
        self:setDebugText(err)
        return
    end

    local treeLines = {}
    local nodeCount = collectLayoutNodes(layout, treeLines, 0)
    local elements, actionText = self:showOrRebuildPreview(layout, width, height)
    local ids = collectElementIds(elements)

    local lines = {
        "Layout compile/run: OK",
        actionText,
        "Preview size: " .. tostring(width) .. " x " .. tostring(height),
        "",
        "Nodes discovered in returned layout tree: " .. tostring(nodeCount)
    }

    for i = 1, #treeLines do
        lines[#lines + 1] = treeLines[i]
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Exposed element ids from LayoutManager: " .. tostring(#ids)

    if #ids == 0 then
        lines[#lines + 1] = "<none>"
    else
        for i = 1, #ids do
            lines[#lines + 1] = "- " .. ids[i]
        end
    end

    self:setDebugText(joinLines(lines))
end

function LayoutMakerEditorWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function LayoutMakerEditorWindow:createChildren()
    if self._childrenCreated then
        return
    end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)

    local pad = 8
    local contentY = self:titleBarHeight() + pad
    self.contentPanel = ISPanel:new(
        pad,
        contentY,
        math.max(0, self.width - (pad * 2)),
        math.max(0, self.height - contentY - pad)
    )
    self.contentPanel:initialise()
    self.contentPanel:noBackground()
    self:addChild(self.contentPanel)

    self:applyEditorLayout()
end

function LayoutMakerEditorWindow:onResize()
    ISUIElement.onResize(self)

    local pad = 8
    local contentY = self:titleBarHeight() + pad
    self.contentPanel:setX(pad)
    self.contentPanel:setY(contentY)
    self.contentPanel:setWidth(math.max(0, self.width - (pad * 2)))
    self.contentPanel:setHeight(math.max(0, self.height - contentY - pad))

    self:applyEditorLayout()
end

function LayoutMakerEditorWindow:close()
    ISCollapsableWindow.close(self)

    if self.layoutManager and self.layoutManager._layoutMakerWindow == self then
        self.layoutManager._layoutMakerWindow = nil
    end
end

function LayoutMakerEditorWindow:new(x, y, width, height, layoutManager)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true
    o.resizable = true
    o.pin = true
    o.alwaysOnTop = true
    o.title = "LayoutMaker"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }
    o.layoutManager = layoutManager
    o.previewWidth = 600
    o.previewHeight = 420
    o.sourceText = DEFAULT_LAYOUT_SOURCE
    o.debugText = "Press Go to compile and apply the layout."
    o.elements = {}

    return o
end

return function(layoutManager)
    function layoutManager:showLayoutMaker()
        local existing = self._layoutMakerWindow

        if existing then
            existing:addToUIManager()
            existing:setVisible(true)
            return existing
        end

        local scale = getTextManager():getFontHeight(UIFont.Small) / 12
        local width = math.floor(400 * scale)
        local height = math.floor(600 * scale)
        local x = getCore():getScreenWidth() / 2 - width / 2
        local y = getCore():getScreenHeight() / 2 - height / 2

        local window = LayoutMakerEditorWindow:new(x, y, width, height, self)
        window:initialise()
        window:addToUIManager()

        self._layoutMakerWindow = window
        return window
    end
end
