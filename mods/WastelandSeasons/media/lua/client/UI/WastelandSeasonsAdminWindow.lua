require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "UI/LayoutManager/LayoutManager"
require "UI/WL_Dialogs"

WastelandSeasonsAdminWindow = ISCollapsableWindow:derive("WastelandSeasonsAdminWindow")
WastelandSeasonsAdminWindow.instance = nil

local SEASON_NAMES = WastelandSeasons.SEASON_NAMES or { "Spring", "Early Summer", "Late Summer", "Autumn", "Winter" }

local EVENT_TEMP_MODE_OPTIONS = {
    { text = "None", data = "none" },
    { text = "Adjust", data = "adjust" },
    { text = "Target", data = "target" },
}

local EVENT_PRECIPITATION_OPTIONS = {
    { text = "Unchanged", data = "" },
    { text = "Clear", data = "none" },
    { text = "Light Rain", data = "lightrain" },
    { text = "Medium Rain", data = "mediumrain" },
    { text = "Heavy Rain", data = "heavyrain" },
    { text = "Light Snow", data = "lightsnow" },
    { text = "Medium Snow", data = "mediumsnow" },
    { text = "Heavy Snow", data = "heavysnow" },
}

local MANUAL_PRECIPITATION_OPTIONS = {
    { text = "Clear", data = "none" },
    { text = "Light Rain", data = "lightrain" },
    { text = "Medium Rain", data = "mediumrain" },
    { text = "Heavy Rain", data = "heavyrain" },
    { text = "Light Snow", data = "lightsnow" },
    { text = "Medium Snow", data = "mediumsnow" },
    { text = "Heavy Snow", data = "heavysnow" },
}

local EVENT_TRIGGER_OPTIONS = {
    { text = "None", data = "" },
    { text = "Blizzard", data = "blizzard" },
    { text = "Tropical Storm", data = "tropicalstorm" },
}

local MANUAL_STORM_OPTIONS = {
    { text = "Blizzard", data = "blizzard" },
    { text = "Tropical Storm", data = "tropicalstorm" },
}

local HARM_TYPE_OPTIONS = {
    { text = "None", data = "none" },
    { text = "Radiation", data = "radiation" },
    { text = "Acid", data = "acid" },
}

local SCHEDULE_START_OPTIONS = {
    { text = "Now", data = 0 },
    { text = "In 1 Hour", data = 1 },
    { text = "In 2 Hours", data = 2 },
    { text = "In 3 Hours", data = 3 },
    { text = "In 6 Hours", data = 6 },
    { text = "In 12 Hours", data = 12 },
    { text = "In 1 Day", data = 24 },
    { text = "In 2 Days", data = 48 },
    { text = "In 3 Days", data = 72 },
    { text = "In 1 Week", data = 168 },
    { text = "In 2 Weeks", data = 336 },
}

local DURATION_OPTIONS = {
    { text = "1 Hour", data = 1 },
    { text = "2 Hours", data = 2 },
    { text = "4 Hours", data = 4 },
    { text = "6 Hours", data = 6 },
    { text = "8 Hours", data = 8 },
    { text = "12 Hours", data = 12 },
    { text = "18 Hours", data = 18 },
    { text = "1 Day", data = 24 },
    { text = "2 Days", data = 48 },
    { text = "3 Days", data = 72 },
    { text = "1 Week", data = 168 },
}

local PANEL_BG = { r = 0.06, g = 0.06, b = 0.06, a = 0.96 }
local PANEL_BORDER = { r = 0.24, g = 0.24, b = 0.24, a = 1 }
local MUTED_TEXT = { r = 0.72, g = 0.72, b = 0.72, a = 1 }

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function copyTableDeep(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for key, nestedValue in pairs(value) do
        out[key] = copyTableDeep(nestedValue)
    end
    return out
end

local function getTextBoxText(element)
    if not element then
        return ""
    end
    return element:getInternalText() or element:getText() or ""
end

local function setTextBoxText(element, value)
    if element then
        element:setText(tostring(value or ""))
    end
end

local function getComboSelectedData(comboBox)
    local selectedIndex = comboBox and tonumber(comboBox.selected) or 0
    if selectedIndex < 1 then
        return nil
    end
    return comboBox:getOptionData(selectedIndex)
end

local function setComboSelectedData(comboBox, selectedData)
    if not comboBox then
        return
    end
    for i = 1, #comboBox.options do
        if comboBox:getOptionData(i) == selectedData then
            comboBox.selected = i
            return
        end
    end
    if #comboBox.options > 0 then
        comboBox.selected = 1
    else
        comboBox.selected = 0
    end
end

local function setTickBoxSelection(tickBox, states)
    if not tickBox or type(states) ~= "table" then
        return
    end
    for i = 1, #states do
        tickBox.selected[i] = states[i] == true
    end
end

local function splitLines(text)
    local out = {}
    local normalized = tostring(text or ""):gsub("\r\n", "\n")
    for line in string.gmatch(normalized, "([^\n]+)") do
        local trimmed = trim(line)
        if trimmed ~= "" then
            out[#out + 1] = trimmed
        end
    end
    return out
end

local function messageValueToText(value)
    if value == nil then
        return ""
    end
    if type(value) == "table" then
        local lines = {}
        for i = 1, #value do
            local line = trim(value[i])
            if line ~= "" then
                lines[#lines + 1] = line
            end
        end
        return table.concat(lines, "\n")
    end
    return tostring(value)
end

local function textToMessageValue(text)
    local lines = splitLines(text)
    if #lines == 0 then
        return nil
    end
    if #lines == 1 then
        return lines[1]
    end
    return lines
end

local function warningMessagesToText(messages)
    if type(messages) ~= "table" then
        return ""
    end
    local rows = {}
    local hours = {}
    for key, _ in pairs(messages) do
        if type(key) == "number" then
            hours[#hours + 1] = key
        end
    end
    table.sort(hours, function(left, right)
        return left > right
    end)
    for i = 1, #hours do
        local hour = hours[i]
        local value = messages[hour]
        if type(value) == "table" then
            for j = 1, #value do
                if trim(value[j]) ~= "" then
                    rows[#rows + 1] = tostring(hour) .. "=" .. trim(value[j])
                end
            end
        elseif trim(value) ~= "" then
            rows[#rows + 1] = tostring(hour) .. "=" .. trim(value)
        end
    end
    return table.concat(rows, "\n")
end

local function addWarningMessage(target, hour, text)
    if target[hour] == nil then
        target[hour] = text
        return
    end
    if type(target[hour]) == "table" then
        target[hour][#target[hour] + 1] = text
        return
    end
    target[hour] = { target[hour], text }
end

local function textToWarningMessages(text)
    local lines = splitLines(text)
    local out = {}
    local errors = {}
    for i = 1, #lines do
        local line = lines[i]
        local hourText, messageText = string.match(line, "^(%-?%d+)%s*[:=]%s*(.-)$")
        local hour = tonumber(hourText)
        local message = trim(messageText)
        if hour == nil or hour < 1 or message == "" then
            errors[#errors + 1] = "Line " .. tostring(i) .. " must be in the format hour=message"
        else
            addWarningMessage(out, math.floor(hour), message)
        end
    end
    if #errors > 0 then
        return nil, table.concat(errors, "\n")
    end
    return out, nil
end

local function buildStatusText(runtime)
    runtime = runtime or {}
    local snapshot = runtime.activeEventSnapshot
    local eventName = snapshot and snapshot.name or runtime.scheduledEvent or "None"
    if runtime.scheduledEvent and runtime.scheduledEventStart and runtime.scheduledEventStart > 0 then
        return eventName .. " starts in " .. tostring(runtime.scheduledEventStart) .. "h"
    end
    if runtime.scheduledEvent and runtime.scheduledEventEnd and runtime.scheduledEventEnd > 0 then
        return eventName .. " active for " .. tostring(runtime.scheduledEventEnd) .. "h"
    end
    return "No active or scheduled event"
end

local function buildPrecipitationText(runtime)
    if runtime and runtime.setPrecipitation then
        return tostring(runtime.setPrecipitation)
    end
    return "None"
end

local function buildStormText(runtime)
    if runtime and runtime.stormType then
        local duration = runtime.stormDuration and (" (" .. tostring(runtime.stormDuration) .. "h)") or ""
        return tostring(runtime.stormType) .. duration
    end
    return "None"
end

local function buildHarmText(runtime)
    if runtime and runtime.harmType and runtime.harmType ~= "none" then
        return tostring(runtime.harmType) .. " @ " .. tostring(runtime.harmRate or 0)
    end
    return "None"
end

local function buildDefaultEventDraft()
    return {
        id = "new_event",
        name = "New Event",
        enabled = true,
        chance = 1,
        seasons = copyTableDeep(SEASON_NAMES),
        leadupHours = { 1, 3 },
        durationHours = { 6, 24 },
        tempMode = "none",
        tempAdjust = { 0, 0 },
        tempTarget = "",
        precipitation = "",
        wind = "",
        fog = "",
        dayColor = { r = "", g = "", b = "", a = "" },
        trigger = "",
        harmType = "none",
        harmRate = "",
        messages = {}
    }
end

local function collectDraftDayColor(self)
    local dayColor = {
        r = getTextBoxText(self.dayColorRInput),
        g = getTextBoxText(self.dayColorGInput),
        b = getTextBoxText(self.dayColorBInput),
        a = getTextBoxText(self.dayColorAInput),
    }

    if trim(dayColor.r) == "" and trim(dayColor.g) == "" and trim(dayColor.b) == "" and trim(dayColor.a) == "" then
        return nil
    end

    return dayColor
end

local function getFontMetrics()
    local tm = getTextManager()
    local small = tm:MeasureStringY(UIFont.Small, "Ag")
    local medium = tm:MeasureStringY(UIFont.Medium, "Ag")
    return small, medium
end

function WastelandSeasonsAdminWindow:show(playerObj)
    if self.instance then
        self.instance:close()
    end

    local scale = LayoutManager:_getScale()
    local width = math.min(math.floor(960 * scale), getCore():getScreenWidth() - 40)
    local height = math.min(math.floor(500 * scale), getCore():getScreenHeight() - 60)
    local window = WastelandSeasonsAdminWindow:new(
        getCore():getScreenWidth() / 2 - width / 2,
        getCore():getScreenHeight() / 2 - height / 2,
        width,
        height,
        playerObj or getPlayer()
    )
    window:initialise()
    window:addToUIManager()
    self.instance = window
    if WastelandSeasons.AdminData then
        window:applyServerData(WastelandSeasons.AdminData)
    end
    WastelandSeasons.RequestAdminData()
    return window
end

function WastelandSeasonsAdminWindow:updateServerData(data)
    if self.instance then
        self.instance:applyServerData(data)
    end
end

function WastelandSeasonsAdminWindow:showError(message)
    WL_Dialogs.showMessageDialog(tostring(message or "Unknown seasons admin error"))
end

function WastelandSeasonsAdminWindow:new(x, y, width, height, playerObj)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.playerObj = playerObj
    o.moveWithMouse = true
    o.resizable = false
    o.pin = true
    o.alwaysOnTop = true
    o.title = "Wasteland Seasons"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.92 }

    o.serverData = { definitions = {}, runtime = {} }
    o.eventDefinitions = {}
    o.selectedEventId = nil
    o.draftEvent = buildDefaultEventDraft()
    o._childrenCreated = false
    return o
end

function WastelandSeasonsAdminWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function WastelandSeasonsAdminWindow:createChildren()
    if self._childrenCreated then
        return
    end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)
    self:applyLayout()
end

function WastelandSeasonsAdminWindow:close()
    WastelandSeasonsAdminWindow.instance = nil
    ISCollapsableWindow.close(self)
end

function WastelandSeasonsAdminWindow:findDefinitionById(eventId)
    for i = 1, #self.eventDefinitions do
        local definition = self.eventDefinitions[i]
        if definition.id == eventId then
            return definition, i
        end
    end
    return nil, nil
end

function WastelandSeasonsAdminWindow:getSelectedEventIndex()
    if not self.selectedEventId then
        return 0
    end
    for i = 1, #self.eventDefinitions do
        if self.eventDefinitions[i].id == self.selectedEventId then
            return i
        end
    end
    return 0
end

function WastelandSeasonsAdminWindow:buildEventListItems()
    local items = {}
    for i = 1, #self.eventDefinitions do
        local definition = self.eventDefinitions[i]
        local prefix = definition.enabled and "" or "[Off] "
        items[#items + 1] = {
            text = prefix .. tostring(definition.name or definition.id),
            item = { id = definition.id },
            tooltip = tostring(definition.id)
        }
    end
    return items
end

function WastelandSeasonsAdminWindow:getDraftTitle()
    if self.selectedEventId then
        local definition = self:findDefinitionById(self.selectedEventId)
        if definition then
            return "Editing: " .. tostring(definition.name or definition.id)
        end
    end
    return "New Event"
end

function WastelandSeasonsAdminWindow:getDraftSubtitle()
    if self.selectedEventId then
        return "Modify fields and press Save to update."
    end
    return "Fill in details and press Save to create."
end

function WastelandSeasonsAdminWindow:buildLayout()
    local scale = LayoutManager:_getScale()
    local smallH, mediumH = getFontMetrics()
    local pad = math.floor(8 * scale)
    local rowH = math.max(math.floor(22 * scale), smallH + 4)
    local btnH = math.max(math.floor(24 * scale), smallH + 8)
    local tickRowH = math.max(18, smallH + 2) * (#SEASON_NAMES + 1)
    local rootX = pad
    local rootY = self:titleBarHeight() + pad
    local rootWidth = self.width - (pad * 2)
    local rootHeight = self.height - rootY - pad
    local listItems = self:buildEventListItems()

    local runtime = self.serverData and self.serverData.runtime or {}

    return { type = "rows", x = rootX, y = rootY, width = tostring(rootWidth) .. "px", height = tostring(rootHeight) .. "px", pad = pad, rows = {
        { type = "columns", width = "inherit", height = "*", pad = pad, columns = {
            -- Left sidebar: event list
            { type = "panel", id = "eventListPanel", width = "26%", height = "inherit", backgroundColor = PANEL_BG, borderColor = PANEL_BORDER, child = { type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 5, rows = {
                { type = "label", id = "eventListTitle", height = mediumH + 2, text = "Event Definitions", font = UIFont.Medium },
                { type = "label", id = "eventListSubtitle", height = smallH, text = "Select to edit, or create new.", color = MUTED_TEXT },
                { type = "scrollinglistbox", id = "eventList", width = "inherit", height = "*", itemheight = rowH, font = UIFont.Small, items = listItems, selected = self:getSelectedEventIndex(), drawBorder = true, backgroundColor = { r = 0.04, g = 0.04, b = 0.04, a = 1 }, borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.9 } },
                { type = "columns", width = "inherit", height = btnH, pad = 4, columns = {
                    { type = "button", id = "newEventButton", width = "*", text = "New", target = self, onClick = self.onNewEvent },
                    { type = "button", id = "saveEventButton", width = "*", text = "Save", target = self, onClick = self.onSaveEvent },
                    { type = "button", id = "deleteEventButton", width = "*", text = "Delete", target = self, onClick = self.onDeleteEvent }
                }},
                { type = "button", id = "refreshButton", width = "inherit", height = btnH, text = "Refresh", target = self, onClick = self.onRefresh }
            }}},
            -- Right main area: header + tabpanel
            { type = "rows", width = "*", height = "inherit", pad = pad, rows = {
                -- Header
                { type = "panel", id = "headerPanel", width = "inherit", height = mediumH + smallH + 16, backgroundColor = PANEL_BG, borderColor = PANEL_BORDER, child = { type = "rows", width = "inherit", height = "inherit", margin = { 5, 8, 5, 8 }, pad = 2, rows = {
                    { type = "label", id = "editorTitle", height = mediumH + 2, text = self:getDraftTitle(), font = UIFont.Medium },
                    { type = "label", id = "editorSubtitle", height = smallH, text = self:getDraftSubtitle(), color = MUTED_TEXT }
                }}},
                -- Tab panel
                { type = "tabpanel", id = "editorTabs", width = "inherit", height = "*", activeTabId = "general", equalTabWidth = true, tabs = {
                    -- General tab
                    { id = "general", title = "General", content = { type = "scrollpanel", id = "generalScroll", width = "inherit", height = "inherit", autoScrollBottomPadding = 8, child = { type = "rows", width = "inherit", height = "auto", margin = { 6, 6, 6, 6 }, pad = 5, rows = {
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Id" },
                            { type = "textbox", id = "idInput", width = "32%", text = "" },
                            { type = "label", width = "18%", text = "Name" },
                            { type = "textbox", id = "nameInput", width = "32%", text = "" }
                        }},
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "tickbox", id = "enabledTickbox", width = "50%", height = rowH, options = { "Enabled" }, selected = { true } },
                            { type = "label", width = "18%", text = "Chance" },
                            { type = "textbox", id = "chanceInput", width = "32%", text = "" }
                        }},
                        { type = "label", height = smallH, text = "Seasons", color = MUTED_TEXT },
                        { type = "tickbox", id = "seasonsTickbox", width = "inherit", height = tickRowH, options = SEASON_NAMES, selected = { true, true, true, true, true } },
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Lead-up Min" },
                            { type = "textbox", id = "leadupMinInput", width = "32%", text = "" },
                            { type = "label", width = "18%", text = "Lead-up Max" },
                            { type = "textbox", id = "leadupMaxInput", width = "32%", text = "" }
                        }},
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Duration Min" },
                            { type = "textbox", id = "durationMinInput", width = "32%", text = "" },
                            { type = "label", width = "18%", text = "Duration Max" },
                            { type = "textbox", id = "durationMaxInput", width = "32%", text = "" }
                        }}
                    }}}},
                    -- Weather tab
                    { id = "weather", title = "Weather", content = { type = "scrollpanel", id = "weatherScroll", width = "inherit", height = "inherit", autoScrollBottomPadding = 8, child = { type = "rows", width = "inherit", height = "auto", margin = { 6, 6, 6, 6 }, pad = 5, rows = {
                        { type = "label", height = smallH, text = "Temperature", color = MUTED_TEXT },
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Temp Mode" },
                            { type = "combobox", id = "tempModeCombo", width = "32%", options = EVENT_TEMP_MODE_OPTIONS, selectedData = "none" },
                            { type = "label", width = "18%", text = "Temp Target" },
                            { type = "textbox", id = "tempTargetInput", width = "32%", text = "" }
                        }},
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Adjust Min" },
                            { type = "textbox", id = "tempAdjustMinInput", width = "32%", text = "" },
                            { type = "label", width = "18%", text = "Adjust Max" },
                            { type = "textbox", id = "tempAdjustMaxInput", width = "32%", text = "" }
                        }},
                        { type = "label", height = smallH, text = "Precipitation & Wind", color = MUTED_TEXT },
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Precipitation" },
                            { type = "combobox", id = "precipitationCombo", width = "32%", options = EVENT_PRECIPITATION_OPTIONS, selectedData = "" },
                            { type = "label", width = "18%", text = "Storm Trigger" },
                            { type = "combobox", id = "triggerCombo", width = "32%", options = EVENT_TRIGGER_OPTIONS, selectedData = "" }
                        }},
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Wind" },
                            { type = "textbox", id = "windInput", width = "32%", text = "" },
                            { type = "label", width = "18%", text = "Fog" },
                            { type = "textbox", id = "fogInput", width = "32%", text = "" }
                        }},
                        { type = "label", height = smallH, text = "Day Color Override (RGBA 0-1)", color = MUTED_TEXT },
                        { type = "columns", height = rowH, pad = 4, columns = {
                            { type = "label", width = "6%", text = "R" },
                            { type = "textbox", id = "dayColorRInput", width = "19%", text = "" },
                            { type = "label", width = "6%", text = "G" },
                            { type = "textbox", id = "dayColorGInput", width = "19%", text = "" },
                            { type = "label", width = "6%", text = "B" },
                            { type = "textbox", id = "dayColorBInput", width = "19%", text = "" },
                            { type = "label", width = "6%", text = "A" },
                            { type = "textbox", id = "dayColorAInput", width = "19%", text = "" }
                        }}
                    }}}},
                    -- Hazards & Messages tab
                    { id = "hazards", title = "Hazards & Msgs", content = { type = "scrollpanel", id = "hazardsScroll", width = "inherit", height = "inherit", autoScrollBottomPadding = 8, child = { type = "rows", width = "inherit", height = "auto", margin = { 6, 6, 6, 6 }, pad = 5, rows = {
                        { type = "label", height = smallH, text = "Environmental Hazards", color = MUTED_TEXT },
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Harm Type" },
                            { type = "combobox", id = "harmTypeCombo", width = "32%", options = HARM_TYPE_OPTIONS, selectedData = "none" },
                            { type = "label", width = "18%", text = "Harm Rate" },
                            { type = "textbox", id = "harmRateInput", width = "32%", text = "" }
                        }},
                        { type = "label", height = smallH, text = "Start Messages (one per line, random selection)", color = MUTED_TEXT },
                        { type = "textbox", id = "startMessagesInput", width = "inherit", height = math.floor(64 * scale), text = "", multipleLine = true, maxLines = 8 },
                        { type = "label", height = smallH, text = "End Messages (one per line, random selection)", color = MUTED_TEXT },
                        { type = "textbox", id = "endMessagesInput", width = "inherit", height = math.floor(64 * scale), text = "", multipleLine = true, maxLines = 8 },
                        { type = "label", height = smallH, text = "Warning Messages (hour=message, repeat hour for random)", color = MUTED_TEXT },
                        { type = "textbox", id = "warningMessagesInput", width = "inherit", height = math.floor(100 * scale), text = "", multipleLine = true, maxLines = 16 }
                    }}}},
                    -- Live Operations tab
                    { id = "operations", title = "Live Ops", content = { type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                        { type = "label", height = smallH, text = "Current Status", color = MUTED_TEXT },
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Event" },
                            { type = "label", id = "currentStatusValue", width = "32%", text = buildStatusText(runtime) },
                            { type = "label", width = "18%", text = "Hazard" },
                            { type = "label", id = "currentHarmValue", width = "32%", text = buildHarmText(runtime) }
                        }},
                        { type = "columns", height = rowH, pad = 6, columns = {
                            { type = "label", width = "18%", text = "Precipitation" },
                            { type = "label", id = "currentPrecipitationValue", width = "32%", text = buildPrecipitationText(runtime) },
                            { type = "label", width = "18%", text = "Storm" },
                            { type = "label", id = "currentStormValue", width = "32%", text = buildStormText(runtime) }
                        }},
                        { type = "label", height = smallH + 4, text = "Schedule Event", color = MUTED_TEXT },
                        { type = "columns", height = btnH, pad = 6, columns = {
                            { type = "label", width = "18%", height = btnH, text = "Start In" },
                            { type = "combobox", id = "scheduleStartCombo", width = "32%", options = SCHEDULE_START_OPTIONS, selectedData = 0 },
                            { type = "label", width = "18%", height = btnH, text = "Duration" },
                            { type = "combobox", id = "scheduleDurationCombo", width = "32%", options = DURATION_OPTIONS, selectedData = 24 }
                        }},
                        { type = "columns", height = btnH, pad = 6, columns = {
                            { type = "button", id = "scheduleButton", width = "*", height = btnH, text = "Schedule", target = self, onClick = self.onScheduleEvent },
                            { type = "button", id = "forceButton", width = "*", height = btnH, text = "Force Start Now", target = self, onClick = self.onForceEvent },
                            { type = "button", id = "cancelButton", width = "*", height = btnH, text = "Cancel Event", target = self, onClick = self.onCancelEvent },
                            { type = "button", id = "writeTempsButton", width = "*", height = btnH, text = "Write Temps", target = self, onClick = self.onWriteTemps }
                        }},
                        { type = "label", height = smallH + 4, text = "Manual Precipitation", color = MUTED_TEXT },
                        { type = "columns", height = btnH, pad = 6, columns = {
                            { type = "combobox", id = "manualPrecipitationCombo", width = "34%", options = MANUAL_PRECIPITATION_OPTIONS, selectedData = "none" },
                            { type = "button", id = "startPrecipitationButton", width = "*", height = btnH, text = "Force Precipitation", target = self, onClick = self.onStartPrecipitation },
                            { type = "button", id = "clearPrecipitationButton", width = "*", height = btnH, text = "Clear Precipitation", target = self, onClick = self.onClearPrecipitation }
                        }},
                        { type = "label", height = smallH + 4, text = "Manual Storm", color = MUTED_TEXT },
                        { type = "columns", height = btnH, pad = 6, columns = {
                            { type = "combobox", id = "manualStormCombo", width = "22%", options = MANUAL_STORM_OPTIONS, selectedData = "blizzard" },
                            { type = "combobox", id = "manualStormDurationCombo", width = "18%", options = DURATION_OPTIONS, selectedData = 6 },
                            { type = "button", id = "startStormButton", width = "*", height = btnH, text = "Force Storm", target = self, onClick = self.onStartStorm },
                            { type = "button", id = "clearStormButton", width = "*", height = btnH, text = "Clear Storm", target = self, onClick = self.onClearStorm }
                        }},
                        { type = "gap", height = "*" }
                    }}}
                }}
            }}
        }}
    }}
end

function WastelandSeasonsAdminWindow:bindElements()
    self.eventList = self.elements.eventList
    self.editorTitle = self.elements.editorTitle
    self.editorSubtitle = self.elements.editorSubtitle

    self.idInput = self.elements.idInput
    self.nameInput = self.elements.nameInput
    self.enabledTickbox = self.elements.enabledTickbox
    self.chanceInput = self.elements.chanceInput
    self.seasonsTickbox = self.elements.seasonsTickbox
    self.leadupMinInput = self.elements.leadupMinInput
    self.leadupMaxInput = self.elements.leadupMaxInput
    self.durationMinInput = self.elements.durationMinInput
    self.durationMaxInput = self.elements.durationMaxInput
    self.tempModeCombo = self.elements.tempModeCombo
    self.tempTargetInput = self.elements.tempTargetInput
    self.tempAdjustMinInput = self.elements.tempAdjustMinInput
    self.tempAdjustMaxInput = self.elements.tempAdjustMaxInput
    self.precipitationCombo = self.elements.precipitationCombo
    self.windInput = self.elements.windInput
    self.fogInput = self.elements.fogInput
    self.triggerCombo = self.elements.triggerCombo
    self.harmTypeCombo = self.elements.harmTypeCombo
    self.harmRateInput = self.elements.harmRateInput
    self.dayColorRInput = self.elements.dayColorRInput
    self.dayColorGInput = self.elements.dayColorGInput
    self.dayColorBInput = self.elements.dayColorBInput
    self.dayColorAInput = self.elements.dayColorAInput
    self.startMessagesInput = self.elements.startMessagesInput
    self.endMessagesInput = self.elements.endMessagesInput
    self.warningMessagesInput = self.elements.warningMessagesInput

    self.newEventButton = self.elements.newEventButton
    self.saveEventButton = self.elements.saveEventButton
    self.deleteEventButton = self.elements.deleteEventButton
    self.refreshButton = self.elements.refreshButton
    self.scheduleStartCombo = self.elements.scheduleStartCombo
    self.scheduleDurationCombo = self.elements.scheduleDurationCombo
    self.scheduleButton = self.elements.scheduleButton
    self.forceButton = self.elements.forceButton
    self.cancelButton = self.elements.cancelButton
    self.writeTempsButton = self.elements.writeTempsButton
    self.manualPrecipitationCombo = self.elements.manualPrecipitationCombo
    self.startPrecipitationButton = self.elements.startPrecipitationButton
    self.clearPrecipitationButton = self.elements.clearPrecipitationButton
    self.manualStormCombo = self.elements.manualStormCombo
    self.manualStormDurationCombo = self.elements.manualStormDurationCombo
    self.startStormButton = self.elements.startStormButton
    self.clearStormButton = self.elements.clearStormButton
    self.currentStatusValue = self.elements.currentStatusValue
    self.currentPrecipitationValue = self.elements.currentPrecipitationValue
    self.currentStormValue = self.elements.currentStormValue
    self.currentHarmValue = self.elements.currentHarmValue

    local owner = self
    self.eventList.onMouseDown = function(list, x, y)
        local result = ISScrollingListBox.onMouseDown(list, x, y)
        local selectedItem = list.items[list.selected]
        if selectedItem and selectedItem.item and selectedItem.item.id then
            owner:selectEvent(selectedItem.item.id)
        end
        return result
    end
end

function WastelandSeasonsAdminWindow:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self:bindElements()
    self:loadDraftIntoFields()
    self:updateUiState()
end

function WastelandSeasonsAdminWindow:loadDraftIntoFields()
    local draft = self.draftEvent or buildDefaultEventDraft()

    if self.editorTitle and self.editorTitle.setName then
        self.editorTitle:setName(self:getDraftTitle())
    end
    if self.editorSubtitle and self.editorSubtitle.setName then
        self.editorSubtitle:setName(self:getDraftSubtitle())
    end

    setTextBoxText(self.idInput, draft.id)
    setTextBoxText(self.nameInput, draft.name)
    setTickBoxSelection(self.enabledTickbox, { draft.enabled ~= false })

    local seasonState = {}
    local selectedSeasons = {}
    if type(draft.seasons) == "table" then
        for i = 1, #draft.seasons do
            selectedSeasons[draft.seasons[i]] = true
        end
    end
    for i = 1, #SEASON_NAMES do
        seasonState[i] = selectedSeasons[SEASON_NAMES[i]] == true
    end
    setTickBoxSelection(self.seasonsTickbox, seasonState)

    setTextBoxText(self.chanceInput, draft.chance)
    setTextBoxText(self.leadupMinInput, draft.leadupHours and draft.leadupHours[1] or "")
    setTextBoxText(self.leadupMaxInput, draft.leadupHours and draft.leadupHours[2] or "")
    setTextBoxText(self.durationMinInput, draft.durationHours and draft.durationHours[1] or "")
    setTextBoxText(self.durationMaxInput, draft.durationHours and draft.durationHours[2] or "")
    setComboSelectedData(self.tempModeCombo, draft.tempMode or "none")
    setTextBoxText(self.tempTargetInput, draft.tempTarget)
    setTextBoxText(self.tempAdjustMinInput, draft.tempAdjust and draft.tempAdjust[1] or "")
    setTextBoxText(self.tempAdjustMaxInput, draft.tempAdjust and draft.tempAdjust[2] or "")
    setComboSelectedData(self.precipitationCombo, draft.precipitation or "")
    setTextBoxText(self.windInput, draft.wind)
    setTextBoxText(self.fogInput, draft.fog)
    setComboSelectedData(self.triggerCombo, draft.trigger or "")
    setComboSelectedData(self.harmTypeCombo, draft.harmType or "none")
    setTextBoxText(self.harmRateInput, draft.harmRate)
    setTextBoxText(self.dayColorRInput, draft.dayColor and draft.dayColor.r or "")
    setTextBoxText(self.dayColorGInput, draft.dayColor and draft.dayColor.g or "")
    setTextBoxText(self.dayColorBInput, draft.dayColor and draft.dayColor.b or "")
    setTextBoxText(self.dayColorAInput, draft.dayColor and draft.dayColor.a or "")
    setTextBoxText(self.startMessagesInput, messageValueToText(draft.messages and draft.messages.start or nil))
    setTextBoxText(self.endMessagesInput, messageValueToText(draft.messages and draft.messages["end"] or nil))
    setTextBoxText(self.warningMessagesInput, warningMessagesToText(draft.messages or {}))
end

function WastelandSeasonsAdminWindow:updateUiState()
    local runtime = self.serverData and self.serverData.runtime or {}
    local selectedDefinition = self.selectedEventId and self:findDefinitionById(self.selectedEventId) or nil

    self.currentStatusValue:setName(buildStatusText(runtime))
    self.currentPrecipitationValue:setName(buildPrecipitationText(runtime))
    self.currentStormValue:setName(buildStormText(runtime))
    self.currentHarmValue:setName(buildHarmText(runtime))

    self.saveEventButton:setEnable(true)
    self.deleteEventButton:setEnable(selectedDefinition ~= nil)
    self.scheduleButton:setEnable(selectedDefinition ~= nil)
    self.forceButton:setEnable(runtime.scheduledEvent ~= nil and runtime.scheduledEventStart ~= nil and runtime.scheduledEventStart > 0)
    self.cancelButton:setEnable(runtime.scheduledEvent ~= nil)
    self.clearPrecipitationButton:setEnable(runtime.setPrecipitation ~= nil)
    self.clearStormButton:setEnable(runtime.stormType ~= nil)
end

function WastelandSeasonsAdminWindow:selectEvent(eventId)
    local definition = self:findDefinitionById(eventId)
    if not definition then
        return
    end

    self.selectedEventId = eventId
    self.draftEvent = copyTableDeep(definition)
    self:loadDraftIntoFields()
    self:updateUiState()
end

function WastelandSeasonsAdminWindow:applyServerData(data)
    self.serverData = data or { definitions = {}, runtime = {} }
    self.eventDefinitions = copyTableDeep(self.serverData.definitions or {})

    local selectedId = self.selectedEventId
    if selectedId then
        local selectedDefinition = self:findDefinitionById(selectedId)
        if selectedDefinition then
            self.draftEvent = copyTableDeep(selectedDefinition)
        else
            self.selectedEventId = nil
            self.draftEvent = buildDefaultEventDraft()
        end
    elseif #self.eventDefinitions > 0 then
        self.selectedEventId = self.eventDefinitions[1].id
        self.draftEvent = copyTableDeep(self.eventDefinitions[1])
    else
        self.draftEvent = buildDefaultEventDraft()
    end

    if self._childrenCreated then
        self:applyLayout()
    end
end

function WastelandSeasonsAdminWindow:collectDraftFromFields()
    local warningMessages, warningError = textToWarningMessages(getTextBoxText(self.warningMessagesInput))
    if warningError then
        return nil, warningError
    end

    local seasons = {}
    for i = 1, #SEASON_NAMES do
        if self.seasonsTickbox:isSelected(i) then
            seasons[#seasons + 1] = SEASON_NAMES[i]
        end
    end

    local messages = warningMessages or {}
    messages.start = textToMessageValue(getTextBoxText(self.startMessagesInput))
    messages["end"] = textToMessageValue(getTextBoxText(self.endMessagesInput))

    return {
        id = trim(getTextBoxText(self.idInput)),
        name = trim(getTextBoxText(self.nameInput)),
        enabled = self.enabledTickbox:isSelected(1),
        chance = getTextBoxText(self.chanceInput),
        seasons = seasons,
        leadupHours = { getTextBoxText(self.leadupMinInput), getTextBoxText(self.leadupMaxInput) },
        durationHours = { getTextBoxText(self.durationMinInput), getTextBoxText(self.durationMaxInput) },
        tempMode = getComboSelectedData(self.tempModeCombo) or "none",
        tempAdjust = { getTextBoxText(self.tempAdjustMinInput), getTextBoxText(self.tempAdjustMaxInput) },
        tempTarget = getTextBoxText(self.tempTargetInput),
        precipitation = getComboSelectedData(self.precipitationCombo) or "",
        wind = getTextBoxText(self.windInput),
        fog = getTextBoxText(self.fogInput),
        dayColor = collectDraftDayColor(self),
        trigger = getComboSelectedData(self.triggerCombo) or "",
        harmType = getComboSelectedData(self.harmTypeCombo) or "none",
        harmRate = getTextBoxText(self.harmRateInput),
        messages = messages,
    }, nil
end

function WastelandSeasonsAdminWindow:onNewEvent()
    self.selectedEventId = nil
    self.draftEvent = buildDefaultEventDraft()
    self:loadDraftIntoFields()
    self:updateUiState()
end

function WastelandSeasonsAdminWindow:onSaveEvent()
    local draft, draftError = self:collectDraftFromFields()
    if not draft then
        WL_Dialogs.showMessageDialog(draftError)
        return
    end

    self.draftEvent = copyTableDeep(draft)
    if self.selectedEventId then
        WastelandSeasons.SendCommand("UpdateEvent", { existingId = self.selectedEventId, event = draft })
    else
        WastelandSeasons.SendCommand("CreateEvent", { event = draft })
    end
end

function WastelandSeasonsAdminWindow:onDeleteEvent()
    if not self.selectedEventId then
        WL_Dialogs.showMessageDialog("Select an existing event to delete.")
        return
    end

    local eventId = self.selectedEventId
    WL_Dialogs.showConfirmationDialog("Delete event '" .. tostring(eventId) .. "'?", function()
        WastelandSeasons.SendCommand("DeleteEvent", { id = eventId })
    end)
end

function WastelandSeasonsAdminWindow:onRefresh()
    WastelandSeasons.RequestAdminData()
end

function WastelandSeasonsAdminWindow:onScheduleEvent()
    if not self.selectedEventId then
        WL_Dialogs.showMessageDialog("Save and select an event before scheduling it.")
        return
    end

    WastelandSeasons.SendCommand("ScheduleEvent", {
        eventId = self.selectedEventId,
        startHours = getComboSelectedData(self.scheduleStartCombo) or 0,
        durationHours = getComboSelectedData(self.scheduleDurationCombo) or 24,
    })
end

function WastelandSeasonsAdminWindow:onForceEvent()
    WastelandSeasons.SendCommand("ForceEvent", {})
end

function WastelandSeasonsAdminWindow:onCancelEvent()
    WastelandSeasons.SendCommand("CancelEvent", {})
end

function WastelandSeasonsAdminWindow:onStartPrecipitation()
    WastelandSeasons.SendCommand("ForcePrecipitation", {
        precipitation = getComboSelectedData(self.manualPrecipitationCombo) or "none"
    })
end

function WastelandSeasonsAdminWindow:onClearPrecipitation()
    WastelandSeasons.SendCommand("ClearPrecipitation", {})
end

function WastelandSeasonsAdminWindow:onStartStorm()
    WastelandSeasons.SendCommand("ForceStorm", {
        storm = getComboSelectedData(self.manualStormCombo) or "blizzard",
        durationHours = getComboSelectedData(self.manualStormDurationCombo) or 6,
    })
end

function WastelandSeasonsAdminWindow:onClearStorm()
    WastelandSeasons.SendCommand("ClearStorm", {})
end

function WastelandSeasonsAdminWindow:onWriteTemps()
    WastelandSeasons.SendCommand("WriteTemps", {})
end
