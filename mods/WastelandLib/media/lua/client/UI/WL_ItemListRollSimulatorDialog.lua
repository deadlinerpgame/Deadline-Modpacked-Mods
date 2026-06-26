require "ISUI/ISPanel"
require "ISUI/RichTextPanel"
require "UI/LayoutManager/LayoutManager"
require "UI/WL_Dialogs"

WL_ItemListRollSimulatorDialog = ISPanel:derive("WL_ItemListRollSimulatorDialog")
WL_ItemListRollSimulatorDialog.instance = nil

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function toWholeNumber(value, fallback)
    local number = tonumber(value)
    if not number then
        return fallback
    end
    number = math.floor(number)
    if number < 1 then
        return fallback
    end
    return number
end

local function formatPercent(value)
    return string.format("%.2f%%", (tonumber(value) or 0) * 100)
end

local function appendLine(lines, text)
    lines[#lines + 1] = tostring(text or "")
end

local function ensureRichTextChild(parentPanel, existingChild)
    if not parentPanel then
        return nil
    end

    local child = existingChild
    if child and child.parent ~= parentPanel then
        child = nil
    end

    if not child then
        child = ISRichTextPanel:new(0, 0, parentPanel.width, parentPanel.height)
        child:initialise()
        child:instantiate()
        child.background = false
        child.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
        child.borderColor = { r = 0, g = 0, b = 0, a = 0 }
        child.autosetheight = false
        child.clip = true
        parentPanel:addChild(child)
        if child.addScrollBars then
            child:addScrollBars()
        end
    end

    child:setX(0)
    child:setY(0)
    child:setWidth(parentPanel.width)
    child:setHeight(parentPanel.height)

    return child
end

function WL_ItemListRollSimulatorDialog:show(listData, player)
    if not listData then
        return nil
    end

    if WL_ItemListRollSimulatorDialog.instance then
        WL_ItemListRollSimulatorDialog.instance:onClose()
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(720 * scale)
    local height = math.floor(560 * scale)
    local o = WL_ItemListRollSimulatorDialog:new(
        getCore():getScreenWidth() / 2 - width / 2,
        getCore():getScreenHeight() / 2 - height / 2,
        width,
        height,
        listData,
        player
    )
    o:initialise()
    o:addToUIManager()
    WL_ItemListRollSimulatorDialog.instance = o
    return o
end

function WL_ItemListRollSimulatorDialog:new(x, y, width, height, listData, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.listData = listData
    o.player = player
    o.moveWithMouse = true
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.94 }
    o.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    o.rollDefinitions = {}
    o.rollReport = nil
    o.simulationSummaryLines = {}
    o.chanceSummaryLines = {}
    o.traceLines = {}

    return o
end

function WL_ItemListRollSimulatorDialog:initialise()
    ISPanel.initialise(self)
    self:applyLayout()
    self:refreshOutputs()
end

function WL_ItemListRollSimulatorDialog:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local margin = 10 * scale
    local titleHeight = 24 * scale
    local rowHeight = 22 * scale
    local actionHeight = 26 * scale
    local rootWidth = self.width - (margin * 2)
    local rootHeight = self.height - (margin * 2)

    return {
        type = "rows",
        x = margin,
        y = margin,
        width = tostring(rootWidth) .. "px",
        height = tostring(rootHeight) .. "px",
        pad = pad,
        rows = {
            { type = "label", id = "dialogTitle", width = "inherit", height = titleHeight, text = "Item List Roll Simulator", font = UIFont.Medium, center = true },
            { type = "label", id = "listTitleLabel", width = "inherit", height = rowHeight, text = "List: " .. tostring(self.listData and self.listData.name or "Unknown"), color = { r = 0.85, g = 0.85, b = 0.85, a = 1 } },
            { type = "columns", id = "inputsRow", width = "inherit", height = rowHeight, pad = 8, columns = {
                { type = "label", id = "rollCountLabel", width = "18%", text = "Top Rolls" },
                { type = "textbox", id = "rollCountInput", width = "16%", text = "1", onlyNumbers = true },
                { type = "label", id = "sampleCountLabel", width = "18%", text = "Samples" },
                { type = "textbox", id = "sampleCountInput", width = "16%", text = "1000", onlyNumbers = true },
                { type = "gap", width = "32%" }
            }},
            { type = "columns", id = "actionRow", width = "inherit", height = actionHeight, pad = 8, columns = {
                { type = "button", id = "runSimulationButton", width = "40%", text = "Run Simulation", target = self, onClick = self.onRunSimulation },
                { type = "button", id = "runSingleTraceButton", width = "40%", text = "Run Single Roll Trace", target = self, onClick = self.onRunSingleTrace },
                { type = "button", id = "closeButton", width = "20%", text = "Close", target = self, onClick = self.onCloseButton }
            }},
            { type = "columns", id = "outputColumns", width = "inherit", height = "*", pad = 8, columns = {
                { type = "panel", id = "summaryPanel", width = "34%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.94 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = {
                    type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "label", id = "summaryHeader", width = "inherit", height = rowHeight, text = "Simulation Summary", color = { r = 0.82, g = 1, b = 0.82, a = 1 } },
                        { type = "panel", id = "summaryOutputHost", width = "inherit", height = "*", background = false, borderColor = { r = 0, g = 0, b = 0, a = 0 } }
                    }
                }},
                { type = "panel", id = "chancePanel", width = "33%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.94 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = {
                    type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "label", id = "chanceHeader", width = "inherit", height = rowHeight, text = "Effective Chances", color = { r = 0.82, g = 0.9, b = 1, a = 1 } },
                        { type = "panel", id = "chanceOutputHost", width = "inherit", height = "*", background = false, borderColor = { r = 0, g = 0, b = 0, a = 0 } }
                    }
                }},
                { type = "panel", id = "tracePanel", width = "33%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.94 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = {
                    type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "label", id = "traceHeader", width = "inherit", height = rowHeight, text = "Last Roll Trace", color = { r = 1, g = 0.9, b = 0.82, a = 1 } },
                        { type = "panel", id = "traceOutputHost", width = "inherit", height = "*", background = false, borderColor = { r = 0, g = 0, b = 0, a = 0 } }
                    }
                }}
            }}
        }
    }
end

function WL_ItemListRollSimulatorDialog:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self.rollCountInput = self.elements.rollCountInput
    self.sampleCountInput = self.elements.sampleCountInput
    self.summaryOutput = ensureRichTextChild(self.elements.summaryOutputHost, self.summaryOutput)
    self.chanceOutput = ensureRichTextChild(self.elements.chanceOutputHost, self.chanceOutput)
    self.traceOutput = ensureRichTextChild(self.elements.traceOutputHost, self.traceOutput)
end

function WL_ItemListRollSimulatorDialog:onResize()
    ISUIElement.onResize(self)
    self:applyLayout()
    self:refreshOutputs()
end

function WL_ItemListRollSimulatorDialog:getRollCount()
    return toWholeNumber(self.rollCountInput:getInternalText() or self.rollCountInput:getText() or "1", 1)
end

function WL_ItemListRollSimulatorDialog:getSampleCount()
    return toWholeNumber(self.sampleCountInput:getInternalText() or self.sampleCountInput:getText() or "1000", 1000)
end

function WL_ItemListRollSimulatorDialog:joinLines(lines)
    return table.concat(lines or {}, " <LINE> ")
end

function WL_ItemListRollSimulatorDialog:refreshOutputs()
    self.summaryOutput.text = self:joinLines(self.simulationSummaryLines)
    self.chanceOutput.text = self:joinLines(self.chanceSummaryLines)
    self.traceOutput.text = self:joinLines(self.traceLines)

    if self.summaryOutput.paginate then
        self.summaryOutput:paginate()
    end
    if self.chanceOutput.paginate then
        self.chanceOutput:paginate()
    end
    if self.traceOutput.paginate then
        self.traceOutput:paginate()
    end
end

function WL_ItemListRollSimulatorDialog:buildChanceLines()
    local lines = {}
    local report = WL_ItemLists:getEffectiveChances(self.listData.id)
    local entries = report and report.entries or {}

    appendLine(lines, "Theoretical per-parent-roll chance")
    if report and report.errors and #report.errors > 0 then
        appendLine(lines, "Errors:")
        for i = 1, #report.errors do
            appendLine(lines, "- " .. tostring(report.errors[i]))
        end
    end

    if #entries == 0 then
        appendLine(lines, "No reachable item entries.")
        return lines
    end

    for i = 1, #entries do
        local entry = entries[i]
        appendLine(lines, tostring(entry.displayName or entry.fullType or "Unknown") .. " | " .. formatPercent(entry.effectiveChance))
    end

    return lines
end

function WL_ItemListRollSimulatorDialog:buildTraceLines(trace, depth, lines)
    lines = lines or {}
    depth = depth or 0
    local indent = string.rep("  ", depth)

    if not trace then
        appendLine(lines, indent .. "No trace available.")
        return lines
    end

    local header = indent .. tostring(trace.listName or trace.listId or "Unknown List")
    if trace.displayName then
        header = header .. " -> " .. tostring(trace.displayName)
    end
    if trace.entryType then
        header = header .. " [" .. tostring(trace.entryType) .. "]"
    end
    if trace.qtyRolled then
        header = header .. " x" .. tostring(trace.qtyRolled)
    end
    if trace.normalizedChance then
        header = header .. " @ " .. formatPercent(trace.normalizedChance)
    end
    appendLine(lines, header)

    if trace.error then
        appendLine(lines, indent .. "  Error: " .. tostring(trace.error))
    end

    local descendants = trace.descendants or {}
    for i = 1, #descendants do
        self:buildTraceLines(descendants[i], depth + 1, lines)
    end

    return lines
end

function WL_ItemListRollSimulatorDialog:buildObservedSummary(rollCount, sampleCount)
    local observedByKey = {}
    local totalTopRolls = rollCount * sampleCount

    for sampleIndex = 1, sampleCount do
        local rolledDefinitions = WL_ItemLists:rollItemDefinitions(self.listData.id, rollCount)
        local seenThisSample = {}

        for i = 1, #(rolledDefinitions or {}) do
            local definition = rolledDefinitions[i]
            local key = tostring(definition.fullType or "") .. "::" .. tostring(definition.customName or "")
            local entry = observedByKey[key]
            if not entry then
                entry = {
                    displayName = definition.displayName or definition.fullType or "Unknown",
                    hits = 0,
                    totalQuantity = 0
                }
                observedByKey[key] = entry
            end

            entry.totalQuantity = entry.totalQuantity + (tonumber(definition.quantity) or 0)
            if not seenThisSample[key] then
                entry.hits = entry.hits + 1
                seenThisSample[key] = true
            end
        end
    end

    local lines = {}
    appendLine(lines, "Samples: " .. tostring(sampleCount))
    appendLine(lines, "Top-level rolls per sample: " .. tostring(rollCount))
    appendLine(lines, "Total parent rolls: " .. tostring(totalTopRolls))
    appendLine(lines, "")
    appendLine(lines, "Observed outcomes")

    local ordered = {}
    for _, entry in pairs(observedByKey) do
        ordered[#ordered + 1] = entry
    end

    table.sort(ordered, function(a, b)
        if a.hits == b.hits then
            return string.lower(tostring(a.displayName or "")) < string.lower(tostring(b.displayName or ""))
        end
        return a.hits > b.hits
    end)

    if #ordered == 0 then
        appendLine(lines, "No items observed.")
        return lines
    end

    for i = 1, #ordered do
        local entry = ordered[i]
        local observedPercent = 0
        if sampleCount > 0 then
            observedPercent = entry.hits / sampleCount
        end
        appendLine(lines, tostring(entry.displayName) .. " | Seen " .. tostring(entry.hits) .. " | " .. formatPercent(observedPercent) .. " | Qty " .. tostring(entry.totalQuantity))
    end

    return lines
end

function WL_ItemListRollSimulatorDialog:onRunSimulation()
    local rollCount = self:getRollCount()
    local sampleCount = self:getSampleCount()
    self.simulationSummaryLines = self:buildObservedSummary(rollCount, sampleCount)
    self.chanceSummaryLines = self:buildChanceLines()
    self:refreshOutputs()
end

function WL_ItemListRollSimulatorDialog:onRunSingleTrace()
    local rollCount = self:getRollCount()
    local rolledDefinitions, rollReport = WL_ItemLists:rollItemDefinitions(self.listData.id, rollCount)
    self.rollDefinitions = rolledDefinitions or {}
    self.rollReport = rollReport

    local lines = {}
    appendLine(lines, "Flattened items: " .. tostring(#self.rollDefinitions))
    for i = 1, #self.rollDefinitions do
        local definition = self.rollDefinitions[i]
        appendLine(lines, "- " .. tostring(definition.displayName or definition.fullType or "Unknown") .. " x" .. tostring(definition.quantity or 0))
    end
    if rollReport and rollReport.errors and #rollReport.errors > 0 then
        appendLine(lines, "")
        appendLine(lines, "Errors:")
        for i = 1, #rollReport.errors do
            appendLine(lines, "- " .. tostring(rollReport.errors[i]))
        end
    end
    self.simulationSummaryLines = lines

    self.chanceSummaryLines = self:buildChanceLines()

    self.traceLines = {}
    local traces = rollReport and rollReport.traces or {}
    if #traces == 0 then
        appendLine(self.traceLines, "No trace available.")
    else
        for i = 1, #traces do
            self:buildTraceLines(traces[i], 0, self.traceLines)
        end
    end

    self:refreshOutputs()
end

function WL_ItemListRollSimulatorDialog:onCloseButton()
    self:onClose()
end

function WL_ItemListRollSimulatorDialog:onClose()
    WL_ItemListRollSimulatorDialog.instance = nil
    self:removeFromUIManager()
end
