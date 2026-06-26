if not getDebug() then return nil end

require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"

local LayoutManagerDemoWindow = ISCollapsableWindow:derive("LayoutManagerDemoWindow")

local function updateLabelText(label, text)
    local resolved = tostring(text or "")
    label.text = resolved
    label.__wlLastLayoutText = resolved
    label:setName(resolved)
end

function LayoutManagerDemoWindow:setStatusText(text)
    self.lastStatusText = tostring(text or "")

    local elements = self.elements
    if not elements then
        return
    end

    if elements.controls_status then
        updateLabelText(elements.controls_status, "Status: " .. self.lastStatusText)
    end

    if elements.dynamic_status then
        updateLabelText(elements.dynamic_status, "Dynamic status: " .. self.lastStatusText)
    end
end

function LayoutManagerDemoWindow:onOverviewStatus()
    self:setStatusText("Overview ping")
end

function LayoutManagerDemoWindow:onOverviewReapply()
    self:applyDemoLayout()
    self:setStatusText("Layout reapplied")
end

function LayoutManagerDemoWindow:onControlsRead()
    local textValue = self.elements.controls_input:getText()
    local selectedName = self.elements.controls_combo:getSelectedText() or "<none>"
    local flags = self.elements.controls_flags.selected

    local flagA = flags[1] and "x" or " "
    local flagB = flags[2] and "x" or " "
    local flagC = flags[3] and "x" or " "

    local summary = "input='" .. tostring(textValue) .. "' combo='" .. tostring(selectedName)
        .. "' flags=[" .. flagA .. flagB .. flagC .. "]"
    self:setStatusText(summary)
end

function LayoutManagerDemoWindow:onControlsLoadSample()
    self.elements.controls_input:setText("Wasteland Demo")
    self.elements.controls_combo:select("Gamma")

    local selected = self.elements.controls_flags.selected
    selected[1] = true
    selected[2] = false
    selected[3] = true

    self:setStatusText("Loaded sample control values")
end

function LayoutManagerDemoWindow:onControlsClear()
    self.elements.controls_input:setText("")
    self.elements.controls_combo.selected = 0

    local selected = self.elements.controls_flags.selected
    selected[1] = false
    selected[2] = false
    selected[3] = false

    self:setStatusText("Cleared controls")
end

function LayoutManagerDemoWindow:onControlsComboChanged()
    local selectedName = self.elements.controls_combo:getSelectedText() or "<none>"
    self:setStatusText("Combo changed to '" .. tostring(selectedName) .. "'")
end

function LayoutManagerDemoWindow:onDynamicPick(_, rowName, rowSpec)
    local pickedName = tostring(rowName or "")
    local pickedSpec = tostring(rowSpec or "")
    self:setStatusText("Picked '" .. pickedName .. "' with spec '" .. pickedSpec .. "'")
end

function LayoutManagerDemoWindow:buildDemoLayout()
    return  { type = "tabpanel", id = "lm_demo_tabs", width = "inherit", height = "inherit", activeTabId = "overview", tabs = {
                { id = "overview", title = "Overview", content =
                    { type = "rows",width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", height = 22, text = "LayoutManager Demo" },
                        { type = "label", height = 20, text = "Top-level tabpanel with focused examples of sizing, spacing, controls, and generators." },
                        { type = "columns", height = 24, pad = 6, columns = {
                            { type = "button", id = "overview_ping_button", width = 150, text = "Ping Status", target = self, onClick = self.onOverviewStatus },
                            { type = "button", id = "overview_rebuild_button", width = 150, text = "Re-apply Layout", target = self, onClick = self.onOverviewReapply },
                            { type = "gap", width = "*" }
                        }},
                        { type = "rows", height = "auto", margin = { 6, 0, 0, 0 }, pad = 4, rows = {
                            { type = "label", height = 20, text = "- Containers: rows, columns, and nested tabpanel" },
                            { type = "label", height = 20, text = "- Size expressions: fixed, %, auto, inherit, *, */N, px" },
                            { type = "label", height = 20, text = "- Spacing: margin and pad comparisons" },
                            { type = "label", height = 20, text = "- Interactive nodes: textbox, combobox, tickbox, button" },
                        }},
                        { type = "gap", height = "*" },
                        { type = "label", height = 20, text = "Open this window with LayoutManager:showDemo() while getDebug() is true." }
                    }}
                },
                { id = "sizes", title = "Sizing", content =
                    { type = "rows", width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", height = 22, text = "Size expressions compared side-by-side" },
                        { type = "columns", height = 26, pad = 6, columns = {
                            { type = "button", id = "sizes_fixed_scaled", width = 120, text = "120" },
                            { type = "button", id = "sizes_percent_30", width = "30%", text = "30%" },
                            { type = "button", id = "sizes_flex_1", width = "*", text = "*" }
                        }},
                        { type = "columns", height = 26, pad = 6, columns = {
                            { type = "button", id = "sizes_flex_full", width = "*", text = "*" },
                            { type = "button", id = "sizes_flex_half", width = "*/2", text = "*/2" },
                            { type = "button", id = "sizes_flex_quarter", width = "*/4", text = "*/4" }
                        }},
                        { type = "columns", height = 26, pad = 6, columns = {
                            { type = "button", id = "sizes_scaled_text", width = "120", text = "\"120\" (scaled)" },
                            { type = "button", id = "sizes_static_px", width = "120px", text = "\"120px\" (static)" },
                            { type = "button", id = "sizes_inherit", width = "*", text = "inherit/default cross-axis" }
                        }},
                        { type = "rows", height = "auto", margin = { 8, 0, 0, 0 }, pad = 4, rows = {
                            { type = "label", height = 20, text = "auto measurement" },
                            { type = "columns", height = 24, columns = {
                                { type = "label", id = "sizes_auto_left", width = "40%", text = "Container height = auto" },
                                { type = "label", id = "sizes_auto_right", width = "60%", text = "Rows sum child outer heights (+ margins/pad)" }
                            }}
                        }},
                        { type = "gap", height = "*" }
                    }}
                },
                { id = "spacing", title = "Margins & Pad", content =
                    { type = "rows", width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", height = 22, text = "Margin changes outer spacing, pad changes sibling gaps" },
                        { type = "columns", height = 48, pad = 8, columns = {
                            { type = "button", id = "spacing_margin_none", width = "*", text = "margin=0" },
                            { type = "button", id = "spacing_margin_uniform", width = "*", margin = 8, text = "margin=8" },
                            { type = "button", id = "spacing_margin_css", width = "*", margin = { 2, 12, 10, 4 }, text = "margin={2,12,10,4}" }
                        }},
                        { type = "columns", height = 142, pad = 10, margin = { 8, 0, 0, 0 }, columns = {
                            { type = "rows", width = "*", height = "inherit", pad = 0, rows = {
                                { type = "label", id = "spacing_pad0_title", height = 20, text = "pad = 0" },
                                { type = "button", id = "spacing_pad0_a", height = 24, text = "A" },
                                { type = "button", id = "spacing_pad0_b", height = 24, text = "B" },
                                { type = "button", id = "spacing_pad0_c", height = 24, text = "C" }
                            }},
                            { type = "rows", width = "*", height = "inherit", pad = 12, rows = {
                                { type = "label", id = "spacing_pad12_title", height = 20, text = "pad = 12" },
                                { type = "button", id = "spacing_pad12_a", height = 24, text = "A" },
                                { type = "button", id = "spacing_pad12_b", height = 24, text = "B" },
                                { type = "button", id = "spacing_pad12_c", height = 24, text = "C" }
                            }}
                        }},
                        { type = "gap", height = "*" }
                    }}
                },
                { id = "scroll", title = "ScrollPanel", content =
                    { type = "rows", width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", id = "scroll_intro", height = 22, text = "scrollpanel node (auto scroll height from children)" },
                        { type = "scrollpanel", id = "scroll_demo_panel", width = "inherit", height = "*", autoScrollBottomPadding = 12,
                            child = { type = "rows", width = "inherit", height = "auto", pad = 4, data = self.demoScrollRows, generator =
                                function(row, i)
                                    local idx = tostring(i)
                                    return
                                        { type = "columns", height = 24, pad = 6, columns = {
                                        { type = "label", id = "scroll_row_label_" .. idx, width = "40%", text = row.label },
                                        { type = "button", id = "scroll_row_button_" .. idx, width = "60%", text = row.buttonText }
                                    }}
                                end
                            }
                        }
                    }}
                },
                { id = "controls", title = "Controls", content =
                    { type = "rows", width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", id = "controls_title", height = 22, text = "Interactive node examples" },
                        { type = "columns", height = 22, pad = 6, columns = {
                            { type = "label", id = "controls_input_label", width = "30%", text = "TextBox" },
                            { type = "textbox", id = "controls_input", width = "70%", text = "Hello LayoutManager" }
                        }},
                        { type = "columns", height = 22, pad = 6, columns = {
                            { type = "label", id = "controls_combo_label", width = "30%", text = "ComboBox" },
                            { type = "combobox", id = "controls_combo", width = "70%", options = { "Alpha", "Beta", "Gamma" }, selected = 1, target = self, onChange = self.onControlsComboChanged }
                        }},
                        { type = "tickbox", id = "controls_flags", height = 58, options = { "Flag A", "Flag B", "Flag C" }, selected = { true, false, false } },
                        { type = "columns", height = 24, pad = 6, columns = {
                            { type = "button", id = "controls_read", width = 120, text = "Read Values", target = self, onClick = self.onControlsRead },
                            { type = "button", id = "controls_sample", width = 120, text = "Load Sample", target = self, onClick = self.onControlsLoadSample },
                            { type = "button", id = "controls_clear", width = 120, text = "Clear", target = self, onClick = self.onControlsClear },
                            { type = "gap", width = "*" }
                        }},
                        { type = "label", id = "controls_status", height = 20, text = "Status: ready" },
                        { type = "gap", height = "*" }
                    }}
                },
                { id = "dynamic", title = "Dynamic", content =
                    { type = "rows", width = "inherit", height = "inherit", margin = 5, pad = 6, rows = {
                        { type = "label", id = "dynamic_title", height = 22, text = "data + generator / tabGenerator" },
                        { type = "rows", height = "auto", pad = 4, data = self.demoRows, generator =
                        function(row, i)
                            local idx = tostring(i)
                            return
                                { type = "columns", height = 24, columns = {
                                { type = "label", id = "dynamic_name_" .. idx, width = "34%", text = row.name },
                                { type = "label", id = "dynamic_spec_" .. idx, width = "22%", text = row.spec },
                                { type = "button", id = "dynamic_pick_" .. idx, width = "44%", text = "Pick", target = self, onClick = self.onDynamicPick, args = { row.name, row.spec } }
                            }} end
                        },
                        { type = "label", id = "dynamic_status", height = 20, text = "Dynamic status: ready" },
                        { type = "tabpanel", id = "dynamic_nested_tabs", width = "inherit", height = "*", data = self.demoNestedTabs, tabGenerator =
                        function(row)
                            return
                                { id = "nested_" .. row.key, title = row.title, content =
                                    { type = "rows", width = "inherit", height = "inherit", pad = 6, rows = {
                                        { type = "label", id = "nested_title_" .. row.key, height = 20, text = row.title },
                                        { type = "label", id = "nested_desc_" .. row.key, height = 20, text = row.description }
                                    }
                                }
                            } end
                        }
                    }
                }
            }
        }}
end

function LayoutManagerDemoWindow:applyDemoLayout()
    self.layout = self:buildDemoLayout()
    self.elements = self.layoutManager:applyLayout(self.contentPanel, self.layout)

    if self.lastStatusText and self.lastStatusText ~= "" then
        self:setStatusText(self.lastStatusText)
    else
        self:setStatusText("ready")
    end
end

function LayoutManagerDemoWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function LayoutManagerDemoWindow:createChildren()
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

    self.demoRows = {
        { name = "fixed", spec = "120" },
        { name = "percent", spec = "30%" },
        { name = "flex", spec = "*" },
        { name = "static", spec = "120px" }
    }

    self.demoNestedTabs = {
        { key = "margin", title = "Margin", description = "Outer spacing around a child." },
        { key = "pad", title = "Pad", description = "Spacing inserted between siblings." },
        { key = "flex", title = "Flex", description = "Main-axis share using * and */N." }
    }

    self.demoScrollRows = {
        { label = "Scrollable Row 01", buttonText = "Action 01" },
        { label = "Scrollable Row 02", buttonText = "Action 02" },
        { label = "Scrollable Row 03", buttonText = "Action 03" },
        { label = "Scrollable Row 04", buttonText = "Action 04" },
        { label = "Scrollable Row 05", buttonText = "Action 05" },
        { label = "Scrollable Row 06", buttonText = "Action 06" },
        { label = "Scrollable Row 07", buttonText = "Action 07" },
        { label = "Scrollable Row 08", buttonText = "Action 08" },
        { label = "Scrollable Row 09", buttonText = "Action 09" },
        { label = "Scrollable Row 10", buttonText = "Action 10" },
        { label = "Scrollable Row 11", buttonText = "Action 11" },
        { label = "Scrollable Row 12", buttonText = "Action 12" }
    }

    self:applyDemoLayout()
end

function LayoutManagerDemoWindow:onResize()
    ISUIElement.onResize(self)

    local pad = 8
    local contentY = self:titleBarHeight() + pad
    self.contentPanel:setX(pad)
    self.contentPanel:setY(contentY)
    self.contentPanel:setWidth(math.max(0, self.width - (pad * 2)))
    self.contentPanel:setHeight(math.max(0, self.height - contentY - pad))

    self:applyDemoLayout()
end

function LayoutManagerDemoWindow:close()
    ISCollapsableWindow.close(self)
    if self.layoutManager and self.layoutManager._demoWindow == self then
        self.layoutManager._demoWindow = nil
    end
end

function LayoutManagerDemoWindow:new(x, y, width, height, layoutManager)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.moveWithMouse = true
    o.resizable = true
    o.pin = true
    o.alwaysOnTop = true
    o.title = "LayoutManager Demo"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }
    o.lastStatusText = ""
    o.layoutManager = layoutManager

    return o
end

return function(layoutManager)
    function layoutManager:showDemo()
        if self._demoWindow then
            self._demoWindow:addToUIManager()
            self._demoWindow:setVisible(true)
            return self._demoWindow
        end

        local scale = getTextManager():getFontHeight(UIFont.Small) / 12
        local width = math.floor(600 * scale)
        local height = math.floor(400 * scale)
        local x = getCore():getScreenWidth() / 2 - width / 2
        local y = getCore():getScreenHeight() / 2 - height / 2

        local window = LayoutManagerDemoWindow:new(x, y, width, height, self)
        window:initialise()
        window:addToUIManager()

        self._demoWindow = window
        return window
    end
end
