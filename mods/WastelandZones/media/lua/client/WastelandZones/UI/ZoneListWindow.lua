require "ISUI/ISCollapsableWindow"
require "ISUI/ISModalDialog"
require "UI/LayoutManager/LayoutManager"

---@class WastelandZones.Classes.ZoneListWindow: ISCollapsableWindow
---@field instance WastelandZones.Classes.ZoneListWindow|nil
---@field player IsoPlayer
---@field cachedEntries table[]
---@field filteredEntries table[]
---@field selectedEntry table|nil
local ZoneListWindow = WastelandZones.Classes.ZoneListWindow or ISCollapsableWindow:derive("WastelandZones.Classes.ZoneListWindow")
if not WastelandZones.Classes.ZoneListWindow then
    WastelandZones.Classes.ZoneListWindow = ZoneListWindow
end

ZoneListWindow.instance = ZoneListWindow.instance or nil

local function distanceSqToZone(zone, px, py, pz)
    local bounds = zone and zone.bounds or nil
    if bounds then
        local dx = 0
        local dy = 0
        local dz = 0

        if px < bounds.x1 then
            dx = bounds.x1 - px
        elseif px > bounds.x2 then
            dx = px - bounds.x2
        end

        if py < bounds.y1 then
            dy = bounds.y1 - py
        elseif py > bounds.y2 then
            dy = py - bounds.y2
        end

        if pz < bounds.z1 then
            dz = bounds.z1 - pz
        elseif pz > bounds.z2 then
            dz = pz - bounds.z2
        end

        return (dx * dx) + (dy * dy) + (dz * dz)
    end

    local center = zone and zone.center or nil
    if not center and zone and zone.calcCenter then
        center = zone:calcCenter()
    end

    local zx = center and center.x or px
    local zy = center and center.y or py
    local zz = center and center.z or pz
    local dx = zx - px
    local dy = zy - py
    local dz = zz - pz
    return (dx * dx) + (dy * dy) + (dz * dz)
end

local function isTempZone(zone)
    return zone and zone.isClientTemporary == true
end

local function zoneLabelFor(entry)
    local dist = math.floor((entry.distance or 0) * 10 + 0.5) / 10
    return string.format("(%.1f) - %s", dist, tostring(entry.name))
end

local function containsInsensitive(haystack, needle)
    if needle == "" then return true end
    return string.find(string.lower(haystack), string.lower(needle), 1, true) ~= nil
end

local function fitLine(font, text, maxWidth)
    local tm = getTextManager()
    if tm:MeasureStringX(font, text) <= maxWidth then
        return text
    end

    local ellipsis = "..."
    local limit = #text
    while limit > 1 do
        local candidate = string.sub(text, 1, limit) .. ellipsis
        if tm:MeasureStringX(font, candidate) <= maxWidth then
            return candidate
        end
        limit = limit - 1
    end

    return ellipsis
end

local function collectAllZonesSortedByDistance(player)
    local out = {}
    if not player or not WastelandZones or not WastelandZones.Zones then
        return out
    end

    local zones = WastelandZones.Zones:getAll()
    local px, py, pz = player:getX(), player:getY(), player:getZ()

    for zoneId, zone in pairs(zones) do
        if not isTempZone(zone) then
            local distSq = distanceSqToZone(zone, px, py, pz)
            out[#out + 1] = {
                id = zoneId,
                zone = zone,
                name = zone.name or ("Zone " .. tostring(zoneId)),
                distSq = distSq,
                distance = math.sqrt(distSq)
            }
        end
    end

    table.sort(out, function(a, b)
        if a.distSq == b.distSq then
            return tostring(a.name) < tostring(b.name)
        end
        return a.distSq < b.distSq
    end)

    return out
end

local function buildListWindowLayout(self)
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local topPad = self:titleBarHeight() + pad
    local actionHeight = 26 * scale
    local searchHeight = 22 * scale

    local rootX = pad
    local rootY = topPad
    local rootWidth = self.width - (pad * 2)
    local rootHeight = self.height - topPad - pad

    return { type = "rows", x = rootX, y = rootY, width = tostring(rootWidth) .. "px", height = tostring(rootHeight) .. "px", pad = pad, rows = {
        { type = "textbox", id = "searchInput", width = "inherit", height = searchHeight, text = "", target = self, onTextChange = self.onSearchChanged, tooltip = "Search zones..." },
        { type = "scrollinglistbox", id = "zonesList", width = "inherit", height = "*", itemheight = 20, font = UIFont.Small, target = self, onMouseDown = self.onListMouseDown },
        { type = "columns", id = "actionsRow", width = "inherit", height = actionHeight, pad = 8, columns = {
            { type = "button", id = "editButton", width = "*", text = "Edit", target = self, onClick = self.onEditSelected },
            { type = "button", id = "gotoButton", width = "*", text = "Goto", target = self, onClick = self.onGotoSelected },
            { type = "button", id = "deleteButton", width = "*", text = "Delete", target = self, onClick = self.onDeleteSelected }
        }}
    }}
end

---@param player IsoPlayer
---@return WastelandZones.Classes.ZoneListWindow|nil
function ZoneListWindow:show(player)
    if not player then return nil end

    if self.instance then
        self.instance:close()
    end

    local scale = LayoutManager:_getScale()
    local width = math.floor(300 * scale)
    local height = math.floor(400 * scale)
    local o = ZoneListWindow:new(getCore():getScreenWidth() / 2 - width / 2, getCore():getScreenHeight() / 2 - height / 2, width, height, player)
    o:initialise()
    o:addToUIManager()
    self.instance = o
    return o
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param player IsoPlayer
---@return WastelandZones.Classes.ZoneListWindow
function ZoneListWindow:new(x, y, width, height, player)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.player = player
    o.cachedEntries = {}
    o.filteredEntries = {}
    o.selectedEntry = nil
    o.moveWithMouse = true
    o.resizable = false
    o.pin = true
    o.alwaysOnTop = true
    o.title = "Zones - List All"
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.9 }

    return o
end

function ZoneListWindow:initialise()
    ISCollapsableWindow.initialise(self)
end

function ZoneListWindow:createChildren()
    if self._childrenCreated then return end
    self._childrenCreated = true

    ISCollapsableWindow.createChildren(self)

    self.layout = buildListWindowLayout(self)
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self.searchInput = self.elements.searchInput
    self.zonesList = self.elements.zonesList
    self.editButton = self.elements.editButton
    self.gotoButton = self.elements.gotoButton
    self.deleteButton = self.elements.deleteButton

    self.zonesList.doDrawItem = self.drawZoneRow
    self.cachedEntries = collectAllZonesSortedByDistance(self.player)
    self:applyFilter("")
end

function ZoneListWindow:updateActionButtons()
    local hasSelection = self.selectedEntry ~= nil and self.selectedEntry.zone ~= nil
    self.editButton:setEnable(hasSelection)
    self.gotoButton:setEnable(hasSelection)
    self.deleteButton:setEnable(hasSelection)
end

---@param y number
---@param item table
---@param alt boolean
---@return number
function ZoneListWindow:drawZoneRow(y, item, alt)
    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.22, 0.65, 0.3, 0.2)
    elseif alt then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.07, 1, 1, 1)
    end

    local text = fitLine(self.font, tostring(item.text or ""), self:getWidth() - 12)
    self:drawText(text, 6, y + 3, 1, 1, 1, 0.95, self.font)
    return y + self.itemheight
end

---@param searchText string|nil
function ZoneListWindow:applyFilter(searchText)
    local query = tostring(searchText or "")
    self.filteredEntries = {}
    self.zonesList:clear()

    for i = 1, #self.cachedEntries do
        local entry = self.cachedEntries[i]
        local name = tostring(entry.name or "")
        local label = zoneLabelFor(entry)
        if containsInsensitive(name, query) or containsInsensitive(label, query) then
            self.filteredEntries[#self.filteredEntries + 1] = entry
            self.zonesList:addItem(label, entry)
        end
    end

    self.zonesList.selected = 0
    self.selectedEntry = nil
    self:updateActionButtons()
end

function ZoneListWindow:onSearchChanged()
    local text = self:getInternalText() or self:getText() or ""
    self.parent:applyFilter(text)
end

---@param item table|nil
function ZoneListWindow:onListMouseDown(item)
    local selected = item
    if selected and selected.item then
        selected = selected.item
    end
    self.selectedEntry = selected
    self:updateActionButtons()
end

---@return table|nil
function ZoneListWindow:getSelectedEntry()
    if not self.selectedEntry then return nil end
    local zoneId = self.selectedEntry.id
    if not zoneId then return nil end

    local liveZone = WastelandZones.Zones:get(zoneId)
    if not liveZone then
        self.selectedEntry = nil
        self:updateActionButtons()
        return nil
    end

    self.selectedEntry.zone = liveZone
    return self.selectedEntry
end

function ZoneListWindow:onEditSelected()
    local entry = self:getSelectedEntry()
    if not entry then return end
    WastelandZones.Classes.ZoneEditorWindow:show(entry.zone)
end

function ZoneListWindow:onGotoSelected()
    local entry = self:getSelectedEntry()
    if not entry then return end

    local x, y, z = entry.zone:findNearestPointInsideFromPlayer(self.player)
    WL_Utils.teleportPlayerToCoords(self.player, x, y, z)
end

---@param zoneId string
function ZoneListWindow:removeFromCache(zoneId)
    local kept = {}
    for i = 1, #self.cachedEntries do
        local entry = self.cachedEntries[i]
        if entry.id ~= zoneId then
            kept[#kept + 1] = entry
        end
    end
    self.cachedEntries = kept

    local searchText = self.searchInput:getInternalText() or self.searchInput:getText() or ""
    self:applyFilter(searchText)
end

function ZoneListWindow:onDeleteSelected()
    local entry = self:getSelectedEntry()
    if not entry then return end

    local message = "Delete zone '" .. tostring(entry.name) .. "'?"
    local modal = ISModalDialog:new(getCore():getScreenWidth() / 2 - 180, getCore():getScreenHeight() / 2 - 75, 360, 150, message, true, nil, function(_, button)
        if not button or button.internal ~= "YES" then return end
        WastelandZones.Network:removeZone(self.player, entry.id)
        self:removeFromCache(entry.id)
    end)
    modal:initialise()
    modal:addToUIManager()
end

function ZoneListWindow:close()
    ZoneListWindow.instance = nil
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end

