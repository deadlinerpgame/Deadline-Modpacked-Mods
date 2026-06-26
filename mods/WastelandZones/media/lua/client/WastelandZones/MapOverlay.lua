if isServer() then return end

require "WL_Utils"

local MIN_ZONE_LABEL_WIDTH_PIXELS = 100

local function intersectsViewport(x1, y1, x2, y2, minx, miny, maxx, maxy)
    return not (x2 < minx or x1 > maxx or y2 < miny or y1 > maxy)
end

local function normalizeUIRect(x1, y1, x2, y2)
    local left = math.min(x1, x2)
    local right = math.max(x1, x2)
    local top = math.min(y1, y2)
    local bottom = math.max(y1, y2)
    return left, top, math.max(1, right - left), math.max(1, bottom - top)
end

local function toUIRect(mapAPI, x1, y1, x2, y2)
    local tlX = mapAPI:worldToUIX(x1, y1)
    local tlY = mapAPI:worldToUIY(x1, y1)
    local brX = mapAPI:worldToUIX(x2 + 1, y2 + 1)
    local brY = mapAPI:worldToUIY(x2 + 1, y2 + 1)
    return normalizeUIRect(tlX, tlY, brX, brY)
end

local function getZoneCategories(zone)
    local categories = {}
    local plugins = zone and zone.plugins

    if plugins then
        for pluginType, _ in pairs(plugins) do
            table.insert(categories, pluginType)
        end
    end
    
    table.sort(categories)
    
    if #categories == 0 then
        categories[1] = "Useless"
    end

    return categories
end

local function getZoneColor(zone)
    if zone.isClientTemporary then
        return {
            r = 1.0,
            g = 0.58,
            b = 0.16,
        }
    end

    if zone.enabled == false then
        return {
            r = 0.50,
            g = 0.50,
            b = 0.50,
        }
    end

    return {
        r = 0.20,
        g = 0.75,
        b = 1.0,
    }
end

local function drawZoneBounds(worldMap, x, y, w, h, color)
    if w < 3 or h < 3 then
        worldMap:drawRect(x + (w / 2) - 1, y + (h / 2) - 1, 3, 3, 0.8, color.r, color.g, color.b)
        return
    end

    worldMap:drawRect(x, y, w, h, 0.2, color.r, color.g, color.b)
end

function ISWorldMap:WastelandZonesMapEnsureState()
    if self.wzOverlayState then return end

    self.wzOverlayState = {
        showOverlay = false,
        includeClientTemporary = false,
        showDisabledZones = false,
        categories = {}
    }
end

---@return string[]
function ISWorldMap:WastelandZonesMapCollectCategories()
    local categories = {}
    local seen = {}
    local zones = WastelandZones.Zones:getAll()
    if not zones then return categories end

    for _, zone in pairs(zones) do
        local zoneCategories = getZoneCategories(zone)
        for i = 1, #zoneCategories do
            local category = zoneCategories[i]
            if not seen[category] then
                seen[category] = true
                categories[#categories + 1] = category
            end
        end
    end

    table.sort(categories)
    return categories
end

---@param zone WastelandZones.Classes.Zone
---@return boolean
function ISWorldMap:WastelandZonesMapIsZoneVisible(zone)
    if not zone then return false end

    local state = self.wzOverlayState
    if not state or not state.showOverlay then
        return false
    end

    if zone.isClientTemporary and not state.includeClientTemporary then
        return false
    end

    if zone.enabled == false and not state.showDisabledZones then
        return false
    end

    local zoneCategories = getZoneCategories(zone)
    for i = 1, #zoneCategories do
        if state.categories[zoneCategories[i]] == true then
            return true
        end
    end

    return false
end

---@param zone WastelandZones.Classes.Zone
function ISWorldMap:WastelandZonesMapEnsureCategoryDefaults(zone)
    local state = self.wzOverlayState
    if not state then return end

    local zoneCategories = getZoneCategories(zone)
    for i = 1, #zoneCategories do
        local key = zoneCategories[i]
        if state.categories[key] == nil then
            state.categories[key] = true
        end
    end
end

---@param zone WastelandZones.Classes.Zone
---@param minx number
---@param miny number
---@param maxx number
---@param maxy number
function ISWorldMap:WastelandZonesMapRenderZone(zone, minx, miny, maxx, maxy)
    local bounds = zone and zone.bounds
    if not bounds then return end
    if not intersectsViewport(bounds.x1, bounds.y1, bounds.x2, bounds.y2, minx, miny, maxx, maxy) then return end

    local mapAPI = self.mapAPI
    local color = getZoneColor(zone)
    local boundsX, boundsY, boundsW, boundsH = toUIRect(mapAPI, bounds.x1, bounds.y1, bounds.x2, bounds.y2)

    drawZoneBounds(self, boundsX, boundsY, boundsW, boundsH, color)

    if boundsW < MIN_ZONE_LABEL_WIDTH_PIXELS then
        return
    end

    local center = zone.center
    local centerX = center and center.x or ((bounds.x1 + bounds.x2) * 0.5)
    local centerY = center and center.y or ((bounds.y1 + bounds.y2) * 0.5)
    local label = tostring(zone.name or zone.id or "Zone")

    self:drawTextCentre(
        label,
        mapAPI:worldToUIX(centerX, centerY),
        mapAPI:worldToUIY(centerX, centerY),
        0,
        0,
        0,
        0.95,
        UIFont.Small
    )
end

-- create the map button and settings state
ISWorldMap.WastelandZonesMap_original_createChildren = ISWorldMap.WastelandZonesMap_original_createChildren or ISWorldMap.createChildren
function ISWorldMap:createChildren()
    ISWorldMap.WastelandZonesMap_original_createChildren(self)

    self:WastelandZonesMapEnsureState()

    if self.wzShowZonesButton then
        return
    end

    local buttonPanel = self.buttonPanel
    local buttons = buttonPanel and buttonPanel.joypadButtons
    if not buttons or #buttons == 0 then
        return
    end

    local btnSize = self.texViewIsometric and self.texViewIsometric:getWidth() or 48

    for _, btn in ipairs(buttons) do
        btn:setX(btn.x + btnSize + 20)
    end

    local firstBtn = buttons[1]
    local x = firstBtn and (firstBtn.x - 20 - btnSize) or 0
    self.wzShowZonesButton = ISButton:new(x, 0, btnSize, btnSize, "Zones", self, ISWorldMap.WastelandZonesMapOpenOptions)
    self.wzShowZonesButton:setVisible(false)

    table.insert(buttons, 1, self.wzShowZonesButton)
    buttonPanel:addChild(self.wzShowZonesButton)
    buttonPanel:insertNewListOfButtons(buttons)

    local btnCount = #buttons
    buttonPanel:setX(self.width - 20 - (btnSize * btnCount + 20 * (btnCount - 1)))
    buttonPanel:setWidth(btnSize * btnCount + 20 * (btnCount - 1))
end

ISWorldMap.WastelandZonesMap_original_render = ISWorldMap.WastelandZonesMap_original_render or ISWorldMap.render
function ISWorldMap:render()
    ISWorldMap.WastelandZonesMap_original_render(self)

    if not self.wzShowZonesButton then
        return
    end

    self:WastelandZonesMapEnsureState()

    local player = getPlayer()
    local isAllowed = WL_Utils.canModerate(player)
    local shouldShowButton = isAllowed and not self.isometric

    if self.wzShowZonesButton:isVisible() ~= shouldShowButton then
        self.wzShowZonesButton:setVisible(shouldShowButton)
    end

    if self.isometric or not isAllowed then return end

    local zones = WastelandZones.Zones:getAll()
    if not zones then return end
    if not self.wzOverlayState.showOverlay then return end

    local minx = math.max(self.mapAPI:uiToWorldX(0, 0), self.mapAPI:getMinXInSquares())
    local miny = math.max(self.mapAPI:uiToWorldY(0, 0), self.mapAPI:getMinYInSquares())
    local maxx = math.min(self.mapAPI:uiToWorldX(self.width, self.height), self.mapAPI:getMaxXInSquares())
    local maxy = math.min(self.mapAPI:uiToWorldY(self.width, self.height), self.mapAPI:getMaxYInSquares())

    for _, zone in pairs(zones) do
        self:WastelandZonesMapEnsureCategoryDefaults(zone)
        if self:WastelandZonesMapIsZoneVisible(zone) then
            self:WastelandZonesMapRenderZone(zone, minx, miny, maxx, maxy)
        end
    end
end

---@param button ISButton
function ISWorldMap:WastelandZonesMapOpenOptions(button)
    if self.wzOptionsUI == nil then
        local ui = WastelandZonesMapOptionsUI:new(self.width - 300, button.y - 300, self)
        self:addChild(ui)
        ui:setVisible(false)
        self.wzOptionsUI = ui
    end

    if self.wzOptionsUI:isVisible() then
        self.wzOptionsUI:setVisible(false)
        return
    end

    self.wzOptionsUI:synchUI()
    self.wzOptionsUI:setX(math.min(self.width - 20 - self.wzOptionsUI.width, button.parent.x + button.x))
    self.wzOptionsUI:setY(button.parent.y + button.y - self.wzOptionsUI.height)
    self.wzOptionsUI:setVisible(true)

    if JoypadState.players[self.playerNum + 1] then
        setJoypadFocus(self.playerNum, self.wzOptionsUI)
    end
end

---@class WastelandZonesMapOptionsUI: ISPanelJoypad
---@field map ISWorldMap
---@field currentTop number
---@field rowSpacing number
---@field rowByKey table<string, ISTickBox>
WastelandZonesMapOptionsUI = ISPanelJoypad:derive("WastelandZonesMapOptionsUI")

---@param x number
---@param y number
---@param map ISWorldMap
---@return WastelandZonesMapOptionsUI
function WastelandZonesMapOptionsUI:new(x, y, map)
    local o = ISPanelJoypad.new(self, x, y, 280, 10)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 1.0 }
    o.resizable = false
    o.map = map
    o.currentTop = 6
    o.rowSpacing = 4
    o.rowByKey = {}
    return o
end

---@param key string
---@param label string
---@param selected boolean
---@param spec table
---@return ISTickBox
function WastelandZonesMapOptionsUI:addTickRow(key, label, selected, spec)
    local tickBox = ISTickBox:new(10, self.currentTop, self.width - 20, 20, "", self, WastelandZonesMapOptionsUI.onTickBox, spec)
    tickBox:initialise()
    tickBox:addOption(label, nil)
    tickBox:setSelected(1, selected == true)
    self:addChild(tickBox)

    self.rowByKey[key] = tickBox
    self.currentTop = self.currentTop + tickBox.height + self.rowSpacing
    return tickBox
end

function WastelandZonesMapOptionsUI:synchUI()
    if not self.map then return end
    self.map:WastelandZonesMapEnsureState()

    if not self.rowByKey.overlay then
        self:addTickRow("overlay", "Show Wasteland Zones", self.map.wzOverlayState.showOverlay, { kind = "overlay" })
    else
        self.rowByKey.overlay:setSelected(1, self.map.wzOverlayState.showOverlay == true)
    end

    if not self.rowByKey.clientTemporary then
        self:addTickRow("clientTemporary", "Include client-only zones", self.map.wzOverlayState.includeClientTemporary, { kind = "clientTemporary" })
    else
        self.rowByKey.clientTemporary:setSelected(1, self.map.wzOverlayState.includeClientTemporary == true)
    end

    if not self.rowByKey.showDisabledZones then
        self:addTickRow("showDisabledZones", "Show disabled zones", self.map.wzOverlayState.showDisabledZones, { kind = "showDisabledZones" })
    else
        self.rowByKey.showDisabledZones:setSelected(1, self.map.wzOverlayState.showDisabledZones == true)
    end

    local categories = self.map:WastelandZonesMapCollectCategories()
    for i = 1, #categories do
        local category = categories[i]
        local state = self.map.wzOverlayState.categories
        if state[category] == nil then
            state[category] = true
        end

        local rowKey = "category:" .. category
        local row = self.rowByKey[rowKey]
        if not row then
            row = self:addTickRow(rowKey, category, state[category], { kind = "category", key = category })
        else
            row:setSelected(1, state[category] == true)
        end
    end

    self:setHeight(self.currentTop + 6)
end

---@param index integer
---@param selected boolean
---@param spec table
function WastelandZonesMapOptionsUI:onTickBox(index, selected, spec)
    if not self.map or not spec then return end
    self.map:WastelandZonesMapEnsureState()

    if spec.kind == "overlay" then
        self.map.wzOverlayState.showOverlay = selected
        return
    end

    if spec.kind == "clientTemporary" then
        self.map.wzOverlayState.includeClientTemporary = selected
        return
    end

    if spec.kind == "showDisabledZones" then
        self.map.wzOverlayState.showDisabledZones = selected
        return
    end

    if spec.kind == "category" and spec.key then
        self.map.wzOverlayState.categories[spec.key] = selected
    end
end
