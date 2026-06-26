require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISModalDialog"
require "UI/LayoutManager/LayoutManager"
require "WastelandZones/UI/ZoneEditorGeneralPanel"

local LayoutScrollPanel = require "UI/LayoutManager/LayoutScrollPanel"

---@class WastelandZones.Classes.ZoneEditorWindow: ISCollapsableWindow
---@field instance WastelandZones.Classes.ZoneEditorWindow|nil
---@field originalZone WastelandZones.Classes.Zone|nil
---@field draftZone WastelandZones.Classes.Zone
---@field pluginOrder string[]
---@field pluginsByType table<string, WastelandZones.Classes.Plugin>
---@field pluginPanels table<string, ISUIElement>
---@field pluginEnabled table<string, boolean>
---@field activePluginType string|nil
local EditorWindow = WastelandZones.Classes.ZoneEditorWindow or ISCollapsableWindow:derive("WastelandZones.Classes.ZoneEditorWindow")
if not WastelandZones.Classes.ZoneEditorWindow then
    WastelandZones.Classes.ZoneEditorWindow = EditorWindow
end

EditorWindow.instance = EditorWindow.instance or nil

local function copyTableDeep(value)
    if type(value) ~= "table" then
        return value
    end

    local out = {}
    for k, v in pairs(value) do
        out[k] = copyTableDeep(v)
    end
    return out
end

local function cloneZone(zone)
    local Zone = WastelandZones.Classes.Zone
    local Utils = WastelandZones.Utils

    local out = Zone:new()
    if not zone then
        return out
    end

    out.id = zone.id or out.id
    out.name = zone.name or out.name
    if zone.enabled == nil then
        out.enabled = true
    else
        out.enabled = zone.enabled == true
    end
    out.lifespan = tonumber(zone.lifespan) or 0
    out.enabledAt = tonumber(zone.enabledAt) or 0

    out.areas = {}
    for i = 1, #(zone.areas or {}) do
        local area = zone.areas[i]
        out.areas[#out.areas + 1] = Utils.createArea(area.x1, area.y1, area.z1, area.x2, area.y2, area.z2)
    end

    out.plugins = {}
    for type, data in pairs(zone.plugins or {}) do
        out.plugins[type] = copyTableDeep(data)
    end

    out:init()
    return out
end

local function collectPluginTypes(all)
    local out = {}
    local seen = {}
    if not all then
        return out
    end

    for type, plugin in pairs(all) do
        if type ~= nil and plugin.isEditable then
            local key = tostring(type)
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = key
            end
        end
    end

    table.sort(out)
    return out
end

---@return table
local function buildWindowLayout(self)
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local topPad = self:titleBarHeight() + pad
    local headerHeight = 30 * scale
    local footerHeight = 26 * scale

    local rootX = pad
    local rootY = topPad
    local rootWidth = self.width  - (pad * 2)
    local rootHeight = self.height - topPad - pad

    return  { type = "rows", x = rootX, y = rootY, width = tostring(rootWidth) .. "px", height = tostring(rootHeight) .. "px", pad = pad, rows = {
                { type = "columns", width = "inherit", height = "*", pad = pad, columns = {
                    { type = "panel", id = "sidebar", width = "28%", height = "inherit", 
                      backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 1 }, borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.7 }, child = 
                        { type = "rows", width = "inherit", height = "inherit", margin = { 8, 8, 8, 8 }, rows = {
                            { type = "label", id = "sidebarTitle", height = 20, text = "Zones Editor", font = UIFont.Medium }
                        }}
                    },
                    { type = "rows", width = "*", height = "inherit", pad = pad, rows = {
                        { type = "panel", id = "contentHeader", width = "inherit", height = headerHeight, backgroundColor = { r = 0.08, g = 0.08, b = 0.08, a = 1 }, borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.7 }, child =
                            { type = "columns", width = "inherit", height = "inherit", margin = { 3, 12, 3, 12 }, pad = 8, columns = {
                                { type = "label", id = "contentHeaderTitle", width = "*", text = "General", font = UIFont.Medium },
                                { type = "button", id = "contentHeaderToggleButton", width = 120, text = "Disable Plugin", target = self, onClick = self.onToggleSelectedPlugin }
                            }}
                        },
                        { type = "scrollpanel", id = "contentPanel", width = "inherit", height = "*", autoScrollBottomPadding = 0, backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 1 }, borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.7 } }
                    }}
                }},
                { type = "columns", width = "inherit", height = footerHeight, pad = 8, columns = {
                    { type = "gap", width = "*" },
                    { type = "button", id = "saveButton", width = 110, text = "Save", target = self, onClick = self.onSave },
                    { type = "button", id = "resetButton", width = 110, text = "Reset", target = self, onClick = self.onReset },
                    { type = "button", id = "deleteButton", width = 110, text = "Delete", target = self, onClick = self.onDelete }
                }}
            }}
end

---@param zone WastelandZones.Classes.Zone|table|nil
---@return WastelandZones.Classes.ZoneEditorWindow
function EditorWindow:show(zone)
    if self.instance then
        self.instance:close()
    end

    local scale = LayoutManager:_getScale()
    print("Scale: " .. tostring(scale))
    local width = math.floor(650 * scale)
    local height = math.floor(450 * scale)

    local o = EditorWindow:new(
        getCore():getScreenWidth() / 2 - width / 2,
        getCore():getScreenHeight() / 2 - height / 2,
        width,
        height,
        zone
    )
    o:initialise()
    o:addToUIManager()
    self.instance = o
    return o
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param zone WastelandZones.Classes.Zone|table|nil
---@return WastelandZones.Classes.ZoneEditorWindow
function EditorWindow:new(x, y, width, height, zone)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.originalZone = zone
    o.draftZone = cloneZone(zone)
    o.moveWithMouse = true
    o.resizable = false
    o.pin = true
    o.alwaysOnTop = true
    o.title = "Zones Editor"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }

    return o
end

function EditorWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function EditorWindow:createChildren()
    if self._childrenCreated then
        return
    end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)

    self.layout = buildWindowLayout(self)
    self.elements = LayoutManager:applyLayout(self, self.layout)

    self.sidebar = self.elements.sidebar
    self.sidebarTitle = self.elements.sidebarTitle
    self.contentHeader = self.elements.contentHeader
    self.contentHeaderTitle = self.elements.contentHeaderTitle
    self.contentHeaderToggleButton = self.elements.contentHeaderToggleButton
    self.contentPanel = self.elements.contentPanel
    self.saveButton = self.elements.saveButton
    self.resetButton = self.elements.resetButton
    self.deleteButton = self.elements.deleteButton

    local navY = 30
    self.navList = ISScrollingListBox:new(8, navY, self.sidebar.width - 16, self.sidebar.height - navY - 8)
    self.navList:initialise()
    self.navList.itemheight = 22
    self.navList.font = UIFont.Small
    self.navList.doDrawItem = self.drawNavItem
    self.navList:setOnMouseDownFunction(self, self.onNavItemClicked)
    self.sidebar:addChild(self.navList)
    self.contentHeaderToggleButton:setVisible(false)

    self.generalPanel = WastelandZones.Classes.ZoneEditorGeneralPanel:new(0, 0, self.contentPanel.width, self.contentPanel.height, self.draftZone)
    self.generalPanel:initialise()

    self.pluginOrder = {}
    self.pluginsByType = {}
    self.pluginPanels = {}
    self.pluginEnabled = {}
    self.activePluginType = nil
    self:initializePluginPanels()

    self:refreshNavigation()
    self:selectGeneral()
end

function EditorWindow:cleanupPluginPanels()
    for i = 1, #self.pluginOrder do
        local type = self.pluginOrder[i]
        local panel = self.pluginPanels[type]
        if panel then
            if panel.children then
                for j = 1, #panel.children do
                    local child = panel.children[j]
                    if child and child.cleanup then
                        child:cleanup()
                    end
                end
            end

            if panel.cleanup then
                panel:cleanup()
            end

            panel:setVisible(false)
            if self.contentPanel and panel.parent == self.contentPanel then
                self.contentPanel:removeChild(panel)
                panel.parent = nil
            end
        end
    end

    self.pluginsByType = {}
    self.pluginPanels = {}
    self.pluginEnabled = {}
    self.pluginOrder = {}
    self.activePluginType = nil
end

---@param zone WastelandZones.Classes.Zone|table|nil
function EditorWindow:reloadZone(zone)
    local selectedKind = self.selectedKind
    local selectedPluginType = self.selectedPluginType

    self.originalZone = zone
    self.draftZone = cloneZone(zone)

    if self.generalPanel then
        self.generalPanel:loadZone(self.draftZone)
    end

    self:cleanupPluginPanels()
    self:initializePluginPanels()

    self:refreshNavigation()

    if selectedKind == "plugin" and selectedPluginType and self.pluginsByType[selectedPluginType] then
        self:selectPlugin(selectedPluginType)
    else
        self:selectGeneral()
    end
end

function EditorWindow:initializePluginPanels()
    if not self.draftZone.plugins then
        self.draftZone.plugins = {}
    end

    local registry = WastelandZones.Plugins
    local all = registry:getAll()
    self.pluginOrder = collectPluginTypes(all)

    for i = 1, #self.pluginOrder do
        local type = self.pluginOrder[i]
        local plugin = registry:get(type)

        local panel = LayoutScrollPanel:new(0, 0, self.contentPanel.width, self.contentPanel.height)
        panel:initialise()
        panel.backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 1 }
        panel.borderColor = { r = 0.2, g = 0.2, b = 0.2, a = 1 }
        panel:setVisible(false)
        self.contentPanel:addChild(panel)

        local data = self.draftZone.plugins[type] or {}
        plugin:buildPanel(self.draftZone, panel, data)
        panel:initializeScrolling()
        panel:refreshScrollHeightFromChildren()

        self.pluginsByType[type] = plugin
        self.pluginPanels[type] = panel

        local enabled = self.draftZone.plugins[type] ~= nil
        self.pluginEnabled[type] = enabled
        if enabled then
            plugin:enablePanel(panel)
        else
            plugin:disablePanel(panel)
        end
    end
end

---@param panel ISUIElement
function EditorWindow:attachContentPanel(panel)
    if not panel or not self.contentPanel then
        return
    end
    if panel.parent ~= self.contentPanel then
        self.contentPanel:addChild(panel)
    end
end

---@param panel ISUIElement
function EditorWindow:detachContentPanel(panel)
    if not panel or not self.contentPanel then
        return
    end
    panel:setVisible(false)
    if panel.parent == self.contentPanel then
        self.contentPanel:removeChild(panel)
        panel.parent = nil
    end
end

function EditorWindow:refreshNavigation()
    local keepSelectionKind = self.selectedKind
    local keepSelectionType = self.selectedPluginType

    self.navList:clear()
    self.navList:addItem("General", { kind = "general" })

    local pluginTypes = self.pluginOrder
    for i = 1, #pluginTypes do
        local type = pluginTypes[i]
        self.navList:addItem(tostring(type), { kind = "plugin", type = type })
    end

    if keepSelectionKind == "plugin" and keepSelectionType then
        for i = 1, #self.navList.items do
            local nav = self.navList.items[i].item
            if nav and nav.kind == "plugin" and nav.type == keepSelectionType then
                self.navList.selected = i
                return
            end
        end
    elseif keepSelectionKind == "general" then
        self.navList.selected = 1
    end
end

---@param y number
---@param item table
---@param alt boolean
---@return number
function EditorWindow:drawNavItem(y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.25, 0.65, 0.3, 0.2)
    end

    local text = item.text
    local nav = item.item
    if nav and nav.kind == "plugin" then
        local enabled = self.parent.parent:isPluginEnabled(nav.type)
        local mark = enabled and "[x] " or "[ ] "
        text = mark .. tostring(nav.type)
    end

    self:drawText(text, 6, y + 3, 1, 1, 1, 0.95, self.font)
    return y + self.itemheight
end

---@param item table
function EditorWindow:onNavItemClicked(item)
    if not item then return end
    local nav = item
    if nav.kind == "general" then
        self:selectGeneral()
    elseif nav.kind == "plugin" then
        self:selectPlugin(nav.type)
    end
end

---@param type string
---@return boolean
function EditorWindow:isPluginEnabled(type)
    return self.pluginEnabled[type] == true
end

---@param type string
function EditorWindow:enablePlugin(type)
    if self.pluginEnabled[type] then
        return
    end

    self.pluginEnabled[type] = true

    if not self.draftZone.plugins then
        self.draftZone.plugins = {}
    end

    local plugin = self.pluginsByType[type]
    local panel = self.pluginPanels[type]
    if self.draftZone.plugins[type] == nil then
        self.draftZone.plugins[type] = plugin:getSaveData(panel) or {}
    end

    plugin:enablePanel(panel)
end

---@param type string
function EditorWindow:disablePlugin(type)
    local plugin = self.pluginsByType[type]
    local panel = self.pluginPanels[type]

    if not self.pluginEnabled[type] then
        plugin:disablePanel(panel)
        return
    end

    self.pluginEnabled[type] = false
    if self.draftZone.plugins then
        self.draftZone.plugins[type] = nil
    end

    plugin:disablePanel(panel)

    if self.activePluginType == type then
        self.activePluginType = nil
    end
end

function EditorWindow:hidePluginPanels()
    for i = 1, #self.pluginOrder do
        local panel = self.pluginPanels[self.pluginOrder[i]]
        if panel then
            panel:setVisible(false)
        end
    end
    self.activePluginType = nil
end

---@param type string
function EditorWindow:showPlugin(type)
    self:hidePluginPanels()

    local panel = self.pluginPanels[type]
    if not panel then
        return
    end

    panel:setVisible(true)
    panel:bringToTop()
    self.activePluginType = type
end

function EditorWindow:hideContentPanels()
    self:detachContentPanel(self.generalPanel)
    self:hidePluginPanels()
end

function EditorWindow:selectGeneral()
    self.selectedKind = "general"
    self.selectedPluginType = nil
    self:hideContentPanels()
    self:attachContentPanel(self.generalPanel)
    self.generalPanel:setVisible(true)
    self.generalPanel:bringToTop()

    self.contentHeaderTitle:setName("General")
    self.contentHeaderToggleButton:setVisible(false)
end

---@param type string
function EditorWindow:selectPlugin(type)
    self.selectedKind = "plugin"
    self.selectedPluginType = type
    self:hideContentPanels()

    self.contentHeaderTitle:setName(tostring(type))
    if self:isPluginEnabled(type) then
        self.contentHeaderToggleButton:setTitle("Disable Plugin")
    else
        self.contentHeaderToggleButton:setTitle("Enable Plugin")
    end
    self.contentHeaderToggleButton:setVisible(true)

    self:showPlugin(type)
end

function EditorWindow:onToggleSelectedPlugin()
    if self.selectedKind ~= "plugin" or not self.selectedPluginType then
        return
    end

    if self:isPluginEnabled(self.selectedPluginType) then
        self:disablePlugin(self.selectedPluginType)
    else
        self:enablePlugin(self.selectedPluginType)
    end

    self:selectPlugin(self.selectedPluginType)
end

---@param errors string[]
function EditorWindow:showValidationErrors(errors)
    if not errors or #errors == 0 then
        return
    end

    local message = "Cannot save zone:\n - " .. table.concat(errors, "\n - ")
    local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 220, getCore():getScreenHeight() / 2 - 120, 440, 240, message, false)
    modal:initialise()
    modal:addToUIManager()
end

---@return table<string, table>, string[]
function EditorWindow:collectPluginData()
    local out = {}

    for i = 1, #self.pluginOrder do
        local type = self.pluginOrder[i]
        if self.pluginEnabled[type] then
            local plugin = self.pluginsByType[type]
            local panel = self.pluginPanels[type]
            local savedData = self.draftZone.plugins[type] or {}
            out[type] = plugin:getSaveData(panel) or savedData
        end
    end

    return out, {}
end

---@return WastelandZones.Classes.Zone|nil, string[]|nil
function EditorWindow:toSaveZone()
    local errors = {}
    local generalData, generalErrors = self.generalPanel:collectGeneralData()
    for i = 1, #generalErrors do
        errors[#errors + 1] = generalErrors[i]
    end

    local pluginsData, pluginErrors = self:collectPluginData()
    for i = 1, #pluginErrors do
        errors[#errors + 1] = pluginErrors[i]
    end

    if #errors > 0 then
        return nil, errors
    end

    local Utils = WastelandZones.Utils
    local out = self.draftZone
    if not out.id or out.id == "" then
        out.id = getRandomUUID()
    end

    out.name = generalData.name
    local oldEnabled = false
    if self.originalZone and self.originalZone.enabled ~= nil then
        oldEnabled = self.originalZone.enabled == true
    elseif out.enabled ~= nil then
        oldEnabled = out.enabled == true
    end

    local newEnabled = generalData.enabled == true
    out.enabled = newEnabled
    out.lifespan = generalData.lifespan

    local collectedEnabledAt = tonumber(generalData.enabledAt) or 0
    if not oldEnabled and newEnabled then
        out.enabledAt = WL_Utils.getTimestamp()
    elseif oldEnabled and not newEnabled then
        out.enabledAt = 0
    else
        out.enabledAt = collectedEnabledAt
    end

    out.areas = {}
    for i = 1, #generalData.areas do
        local area = generalData.areas[i]
        out.areas[#out.areas + 1] = Utils.createArea(area.x1, area.y1, area.z1, area.x2, area.y2, area.z2)
    end

    out.plugins = {}
    for type, data in pairs(pluginsData) do
        out.plugins[type] = data
    end

    out:init()

    return out, nil
end

function EditorWindow:onSave()
    local zone, errors = self:toSaveZone()
    if not zone then
        self:showValidationErrors(errors)
        return
    end

    if not WastelandZones.Network then
        self:showValidationErrors({ "Network not initialized" })
        return
    end

    WastelandZones.Network:saveZone(getPlayer(), zone)
end

function EditorWindow:onReset()
    local zoneId = nil
    if self.originalZone and self.originalZone.id and self.originalZone.id ~= "" then
        zoneId = self.originalZone.id
    elseif self.draftZone and self.draftZone.id and self.draftZone.id ~= "" then
        zoneId = self.draftZone.id
    end

    local registeredZones = WastelandZones.Zones
    local zone = nil

    if registeredZones and zoneId then
        zone = registeredZones:get(zoneId)
    end

    if not zone then
        zone = self.originalZone
    end

    self:reloadZone(zone)
end

function EditorWindow:onDelete()
    if not self.draftZone or not self.draftZone.id or self.draftZone.id == "" then
        self:close()
        return
    end

    if WastelandZones.Network then
        WastelandZones.Network:removeZone(getPlayer(), self.draftZone.id)
    end

    self:close()
end

function EditorWindow:cleanup()
    if self.generalPanel then
        self.generalPanel:cleanup()
    end

    self:cleanupPluginPanels()
end

function EditorWindow:close()
    self:cleanup()
    EditorWindow.instance = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end
