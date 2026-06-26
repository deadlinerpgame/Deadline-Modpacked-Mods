require "ISUI/ISLabel"
require "ISUI/ISButton"
require "ISUI/ISScrollingListBox"
require "ISUI/ISTextEntryBox"
require "UI/LayoutManager/LayoutManager"
require "WastelandZones/Utils/AreaCubePacking"
require "WastelandZones/Utils/AreaOutliner"
require "WastelandZones/Utils/IndoorAreaSearcher"

local LayoutScrollPanel = require "UI/LayoutManager/LayoutScrollPanel"


---@class WastelandZones.Classes.ZoneEditorGeneralPanel:LayoutManagerScrollPanel
---@field zone WastelandZones.Classes.Zone|nil
---@field areas table[]
---@field areaOutliner WastelandZones.Utils.AreaOutliner|nil
---@field selectedAreaIndex integer
---@field selectedAreaOutliner WastelandZones.Utils.AreaOutliner|nil
---@field selectionOutliner WastelandZones.Utils.AreaOutliner|nil
---@field pendingArea table|nil
---@field hoverArea table|nil
---@field worldSelectionActive boolean
---@field worldSelecting boolean
---@field pendingMinZ integer
---@field pendingMaxZ integer
---@field outlineEnabled boolean
---@field showAllZLevels boolean
---@field floorGridEnabled boolean
---@field cleanedUp boolean
---@field activeDirectionalAction 'move'|'expand'|'contract'
local GeneralPanel = WastelandZones.Classes.ZoneEditorGeneralPanel or LayoutScrollPanel:derive("WastelandZones.Classes.ZoneEditorGeneralPanel")
if not WastelandZones.Classes.ZoneEditorGeneralPanel then
    WastelandZones.Classes.ZoneEditorGeneralPanel = GeneralPanel
end

local AreaCubePacking = WastelandZones.Utils.AreaCubePacking
local AreaOutliner = WastelandZones.Utils.AreaOutliner
local IndoorAreaSearcher = WastelandZones.Utils.IndoorAreaSearcher
local Utils = WastelandZones.Utils
local LayoutManager = LayoutManager

local MIN_Z = Utils.MIN_Z
local MAX_Z = Utils.MAX_Z
local normalizeInteger = Utils.normalizeInteger
local createArea = Utils.createArea

local ACTIVE_SELECTOR_PANEL = nil

local NORMAL_AREA_COLOR = { r = 0, g = 1, b = 0, a = 1 }
local SELECTION_COLOR = { r = 1, g = 0, b = 0, a = 1 }
local SELECTED_AREA_COLOR = { r = 0.2, g = 0.45, b = 1, a = 1 }

local ACTIVE_BUTTON_COLOR = { r = 0.16, g = 0.45, b = 0.82, a = 1 }
local DEFAULT_BUTTON_COLOR = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 }

local MODE_SELECTION = "selection"
local MODE_EXISTING = "existing"
local MODE_GLOBAL = "global"

local ACTION_MOVE = "move"
local ACTION_EXPAND = "expand"
local ACTION_CONTRACT = "contract"

local DIRECTION_NORTH = "north"
local DIRECTION_SOUTH = "south"
local DIRECTION_WEST = "west"
local DIRECTION_EAST = "east"
local DIRECTION_UP = "up"
local DIRECTION_DOWN = "down"
local DIRECTION_ALL = "all"

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 60 * SECONDS_PER_MINUTE
local SECONDS_PER_DAY = 24 * SECONDS_PER_HOUR

local function createTemporaryZone(areas, name)
    local zoneClass = WastelandZones.Classes.Zone
    if not zoneClass or not zoneClass.temporary then
        return nil
    end
    return zoneClass:temporary(name or "Editor Zone", areas or {}, {})
end

local function normalizeArea(area)
    return createArea(area.x1, area.y1, area.z1, area.x2, area.y2, area.z2)
end

local function setButtonEnabled(button, enabled)
    if not button then return end
    if button.setEnable then
        button:setEnable(enabled)
    else
        button.enable = enabled
    end
end

local function setElementVisible(element, visible)
    if not element then
        return
    end
    element:setVisible(visible and true or false)
end

local function setButtonActive(button, active)
    if not button then
        return
    end
    if active then
        button.backgroundColor = { r = ACTIVE_BUTTON_COLOR.r, g = ACTIVE_BUTTON_COLOR.g, b = ACTIVE_BUTTON_COLOR.b, a = ACTIVE_BUTTON_COLOR.a }
    else
        button.backgroundColor = { r = DEFAULT_BUTTON_COLOR.r, g = DEFAULT_BUTTON_COLOR.g, b = DEFAULT_BUTTON_COLOR.b, a = DEFAULT_BUTTON_COLOR.a }
    end
end

local function getDirectionalHelper(action, direction)
    if action == ACTION_MOVE then
        if direction == DIRECTION_NORTH then return "getMovedNorthAreas" end
        if direction == DIRECTION_SOUTH then return "getMovedSouthAreas" end
        if direction == DIRECTION_WEST then return "getMovedWestAreas" end
        if direction == DIRECTION_EAST then return "getMovedEastAreas" end
        if direction == DIRECTION_UP then return "getMovedUpAreas" end
        if direction == DIRECTION_DOWN then return "getMovedDownAreas" end
        return nil
    end

    if action == ACTION_EXPAND then
        if direction == DIRECTION_ALL then return "getExpandedAreas" end
        if direction == DIRECTION_NORTH then return "getExpandedNorthAreas" end
        if direction == DIRECTION_SOUTH then return "getExpandedSouthAreas" end
        if direction == DIRECTION_WEST then return "getExpandedWestAreas" end
        if direction == DIRECTION_EAST then return "getExpandedEastAreas" end
        if direction == DIRECTION_UP then return "getRaisedTopAreas" end
        if direction == DIRECTION_DOWN then return "getLoweredBottomAreas" end
        return nil
    end

    if action == ACTION_CONTRACT then
        if direction == DIRECTION_ALL then return "getContractedAreas" end
        if direction == DIRECTION_NORTH then return "getContractedNorthAreas" end
        if direction == DIRECTION_SOUTH then return "getContractedSouthAreas" end
        if direction == DIRECTION_WEST then return "getContractedWestAreas" end
        if direction == DIRECTION_EAST then return "getContractedEastAreas" end
        if direction == DIRECTION_UP then return "getLoweredTopAreas" end
        if direction == DIRECTION_DOWN then return "getRaisedBottomAreas" end
        return nil
    end

    return nil
end

local function isDirectionAllowedForAction(action, direction)
    return getDirectionalHelper(action, direction) ~= nil
end

local function transformAreasWithZoneHelper(areas, zoneHelper, amount, zoneName)
    if not areas or #areas == 0 then
        return {}
    end

    local tempZone = createTemporaryZone(areas, zoneName)
    if not tempZone then
        return nil
    end

    local transform = tempZone[zoneHelper]
    if not transform then
        return nil
    end

    local transformed = transform(tempZone, amount)
    if not transformed then
        return nil
    end

    return transformed
end

local function screenToWorld(mouseX, mouseY, z)
    local player = getPlayer()
    if not player then
        return nil, nil
    end

    local playerNum = player:getPlayerNum()
    local isoX = screenToIsoX(playerNum, mouseX, mouseY, z)
    local isoY = screenToIsoY(playerNum, mouseX, mouseY, z)
    if not isoX or not isoY then
        return nil, nil
    end

    return normalizeInteger(isoX, 0), normalizeInteger(isoY, 0)
end

local function getActiveSelectorPanel()
    local self = ACTIVE_SELECTOR_PANEL
    if not self then
        return nil
    end

    if self.cleanedUp or not self.worldSelectionActive then
        ACTIVE_SELECTOR_PANEL = nil
        return nil
    end

    if self.isVisible and not self:isVisible() then
        self:setWorldSelectionActive(false)
        ACTIVE_SELECTOR_PANEL = nil
        return nil
    end

    if self.parent and self.parent.isVisible and not self.parent:isVisible() then
        self:setWorldSelectionActive(false)
        ACTIVE_SELECTOR_PANEL = nil
        return nil
    end

    return self
end

local function onGlobalMouseDown(x, y)
    local self = getActiveSelectorPanel()
    if not self then return end

    if self.isMouseOver and self:isMouseOver() then
        return
    end

    local player = getPlayer()
    if not player then return end

    local z = normalizeInteger(player:getZ(), MIN_Z)
    local worldX, worldY = screenToWorld(x, y, z)
    if worldX and worldY then
        if not self.worldSelecting then
            self:startWorldSelection(worldX, worldY)
        else
            self:updateWorldSelection(worldX, worldY)
            self:finishWorldSelection()
            self:setWorldSelectionActive(false)
        end
    end
end

local function onGlobalMouseMove(x, y)
    local self = getActiveSelectorPanel()
    if not self or not self.worldSelectionActive then return end

    local player = getPlayer()
    if not player then return end

    local z = normalizeInteger(player:getZ(), MIN_Z)
    local worldX, worldY = screenToWorld(x, y, z)
    if worldX and worldY then
        if self.worldSelecting then
            self:updateWorldSelection(worldX, worldY)
        else
            self:updateWorldSelectionHover(worldX, worldY)
        end
    end
end

local function onGlobalRightMouseUp()
    local self = getActiveSelectorPanel()
    if not self then return end

    self.worldSelecting = false
    self:setWorldSelectionActive(false)
end

local function bindWorldSelectionEvents()
    if AreaCubePacking.DID_BIND_EVENTS then
        return
    end

    Events.OnMouseDown.Add(onGlobalMouseDown)
    Events.OnMouseMove.Add(onGlobalMouseMove)
    Events.OnRightMouseUp.Add(onGlobalRightMouseUp)

    AreaCubePacking.DID_BIND_EVENTS = true
end

-- Bind once globally at file load time.
bindWorldSelectionEvents()

---@param x number
---@param y number
---@param width number
---@param height number
---@param zone WastelandZones.Classes.Zone|nil
---@return WastelandZones.Classes.ZoneEditorGeneralPanel
function GeneralPanel:new(x, y, width, height, zone)
    --- @type WastelandZones.Classes.ZoneEditorGeneralPanel|LayoutManagerScrollPanel
    local o = LayoutScrollPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.zone = zone
    o.areas = {}
    o.areaOutliner = nil
    o.selectedAreaIndex = 0
    o.selectedAreaOutliner = nil
    o.selectionOutliner = nil
    o.pendingArea = nil
    o.hoverArea = nil
    o.worldSelectionActive = false
    o.worldSelecting = false
    o.pendingMinZ = 0
    o.pendingMaxZ = 0
    o.outlineEnabled = true
    o.showAllZLevels = true
    o.floorGridEnabled = true
    o.cleanedUp = false
    o.activeDirectionalAction = ACTION_MOVE
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    o.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    return o
end

---@param input string|nil
---@return integer|nil, string|nil
function GeneralPanel:parseLifespanInputToSeconds(input)
    local raw = tostring(input or "")
    raw = raw:gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then
        return 0, nil
    end

    local totalSeconds = 0
    local cursor = 1
    local len = #raw

    while cursor <= len do
        local nextCursor = raw:find("%S", cursor)
        if not nextCursor then
            break
        end

        local chunk = raw:sub(nextCursor)
        local amountText, unit = chunk:match("^(%d+)%s*([dDhHmMsS])")
        if not amountText or not unit then
            return nil, "Invalid lifespan token"
        end

        local amount = tonumber(amountText) or 0
        local lowerUnit = string.lower(unit)
        if lowerUnit == "d" then
            totalSeconds = totalSeconds + (amount * SECONDS_PER_DAY)
        elseif lowerUnit == "h" then
            totalSeconds = totalSeconds + (amount * SECONDS_PER_HOUR)
        elseif lowerUnit == "m" then
            totalSeconds = totalSeconds + (amount * SECONDS_PER_MINUTE)
        elseif lowerUnit == "s" then
            totalSeconds = totalSeconds + amount
        else
            return nil, "Invalid lifespan unit"
        end

        local _, consumed = chunk:find("^(%d+)%s*[dDhHmMsS]")
        if not consumed then
            return nil, "Invalid lifespan token"
        end
        cursor = nextCursor + consumed
    end

    return math.max(0, math.floor(totalSeconds)), nil
end

---@param seconds number|nil
---@return string
function GeneralPanel:formatLifespanSeconds(seconds)
    local total = math.max(0, math.floor(tonumber(seconds) or 0))
    if total == 0 then
        return "0s"
    end

    local days = math.floor(total / SECONDS_PER_DAY)
    total = total % SECONDS_PER_DAY
    local hours = math.floor(total / SECONDS_PER_HOUR)
    total = total % SECONDS_PER_HOUR
    local minutes = math.floor(total / SECONDS_PER_MINUTE)
    local secs = total % SECONDS_PER_MINUTE

    local parts = {}
    if days > 0 then
        parts[#parts + 1] = tostring(days) .. "d"
    end
    if hours > 0 then
        parts[#parts + 1] = tostring(hours) .. "h"
    end
    if minutes > 0 then
        parts[#parts + 1] = tostring(minutes) .. "m"
    end
    if secs > 0 then
        parts[#parts + 1] = tostring(secs) .. "s"
    end

    if #parts == 0 then
        return "0s"
    end
    return table.concat(parts, " ")
end

---@param enabledAt number|nil
---@return string
function GeneralPanel:formatEnabledAtTimestamp(enabledAt)
    local ts = tonumber(enabledAt)
    if not ts or ts <= 0 then
        return "Never"
    end

    if os and os.date then
        local ok, text = pcall(os.date, "%Y-%m-%d %H:%M:%S", ts)
        if ok and text then
            return tostring(text)
        end
    end

    return tostring(math.floor(ts))
end

function GeneralPanel:initialise()
    LayoutScrollPanel.initialise(self)

    local player = getPlayer()
    if player then
        local z = normalizeInteger(player:getZ(), MIN_Z)
        if z < MIN_Z then z = MIN_Z end
        if z > MAX_Z then z = MAX_Z end
        self.pendingMinZ = z
        self.pendingMaxZ = z
    end

    local padLeft = 8
    local padRight = 16
    local sectionGap = 10
    local rowGap = 4
    local colGap = 4
    local buttonHeight = 24
    local labelHeight = 16

    -- local editorSectionHeight = (buttonHeight * 8) + (labelHeight * 5) + 10
    -- local listHeight = math.max(120, editorSectionHeight - (16 + rowGap + buttonHeight + rowGap + buttonHeight + rowGap))

    local s = self
    self.layout = { type = "rows", width = "inherit", height = "auto", pad = sectionGap, margin = { padLeft, padRight, padLeft, padLeft }, rows = {
        { type = "label", id = "nameLabel", width = "inherit", height = labelHeight, text = "Zone Name" },
        { type = "textbox", id = "nameInput", width = "inherit", height = 24, text = "" },
        { type = "tickbox", id = "enabledTickbox", width = "inherit", height = 20, options = { "Enabled" }, selected = { true } },
        { type = "columns", width = "inherit", height = 24, pad = colGap, columns = {
            { type = "label", id = "lifespanLabel", width = 100, height = "inherit", text = "Lifespan" },
            { type = "textbox", id = "lifespanInput", width = "*", height = "inherit", text = "0s" }
        }},
        { type = "columns", width = "inherit", height = labelHeight, pad = colGap, columns = {
            { type = "label", id = "enabledAtLabel", width = 100, height = "inherit", text = "Enabled At" },
            { type = "label", id = "enabledAtValueLabel", width = "*", height = "inherit", text = function()
                local enabledAt = s.zone.enabledAt or nil
                local lifespan = s.zone.lifespan or 0
                local text = s:formatEnabledAtTimestamp(enabledAt)
                if lifespan > 0 and enabledAt and enabledAt > 0 then
                    local timeLeft = lifespan - (WL_Utils.getTimestamp() - enabledAt)
                    if timeLeft < 0 then
                        text = text .. " - expired"
                    else
                        text = text .. " - " .. s:formatLifespanSeconds(timeLeft) .. " left"
                    end
                end
                return text
            end }
        }},
        { type = "columns", width = "inherit", height = "auto", pad = 10, columns = {
            { type = "rows", width = "43%", height = "inherit", pad = rowGap, rows = {
                { type = "label", id = "areasLabel", width = "inherit", height = labelHeight, text = "Areas" },
                { type = "scrollinglistbox", id = "areasList", width = "inherit", height = "*", itemheight = 20, font = UIFont.Small, selected = 1, target = self, onMouseDown = self.onAreaListMouseDown },
                { type = "button", id = "removeSelectedExistingButton", width = "inherit", height = buttonHeight, text = "Remove Selected Existing Area", target = self, onClick = self.onRemoveSelectedExistingArea },
                { type = "button", id = "removeAllButton", width = "inherit", height = buttonHeight, text = "Clear All Areas", target = self, onClick = self.onRemoveAll },
                { type = "button", id = "selectInteriorButton", width = "inherit", height = buttonHeight, text = "Add Building Interior", target = self, onClick = self.onSelectBuildingInterior },
            }},
            { type = "rows", width = "*", height = "auto", pad = rowGap, rows = {
                { type = "label", width = "inherit", height = labelHeight, text = "View", color = { r = 0.85, g = 1.0, b = 0.85, a = 1 } },
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "zLevelViewButton", width = "*", text = "", target = self, onClick = self.onToggleAllZLevels },
                    { type = "button", id = "floorGridButton", width = "*", text = "", target = self, onClick = self.onToggleFloorGrid },
                    { type = "button", id = "outlineToggleButton", width = "*", text = "", target = self, onClick = self.onToggleOutlineEnabled }
                }},
                { type = "label", width = "inherit", height = labelHeight, text = "Selection", color = { r = 0.85, g = 1.0, b = 0.85, a = 1 } },
                { type = "columns", id = "selectAreaRow", width = "inherit", height = buttonHeight, columns = {
                    { type = "button", id = "selectAreaButton", width = "inherit", text = "Select Area", target = self, onClick = self.onToggleSelectArea }
                }},
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "minZDownButton", width = "*", text = "Min -Z", target = self, onClick = self.onMinZDown },
                    { type = "button", id = "minZUpButton", width = "*", text = "Min +Z", target = self, onClick = self.onMinZUp },
                    { type = "button", id = "maxZDownButton", width = "*", text = "Max -Z", target = self, onClick = self.onMaxZDown },
                    { type = "button", id = "maxZUpButton", width = "*", text = "Max +Z", target = self, onClick = self.onMaxZUp }
                }},
                { type = "label", id = "pendingAreaLabel", width = "inherit", height = labelHeight, text = "Selected Area: none", color = { r = 0.8, g = 1.0, b = 0.8, a = 1 } },
                { type = "columns", id = "selectionCommitRow", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "addAreaButton", width = "*", text = "Add to Zone", target = self, onClick = self.onAddArea },
                    { type = "button", id = "removeAreaButton", width = "*", text = "Cut from Zone", target = self, onClick = self.onRemoveArea }
                }},
                { type = "label", id = "selectionPreviewLabel", width = "inherit", height = labelHeight, text = "Tweak", color = { r = 0.85, g = 1.0, b = 0.85, a = 1 } },
                { type = "label", id = "modeStatusLabel", width = "inherit", height = labelHeight, center = true, text = "" },
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "actionMoveButton", width = "*", text = "Move", target = self, onClick = self.onSetActionMove },
                    { type = "button", id = "actionExpandButton", width = "*", text = "Expand", target = self, onClick = self.onSetActionExpand },
                    { type = "button", id = "actionContractButton", width = "*", text = "Contract", target = self, onClick = self.onSetActionContract }
                }},
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "directionNorthButton", width = "*", text = "North", target = self, onClick = self.onDirectionNorth },
                    { type = "button", id = "directionSouthButton", width = "*", text = "South", target = self, onClick = self.onDirectionSouth },
                    { type = "button", id = "directionWestButton", width = "*", text = "West", target = self, onClick = self.onDirectionWest },
                    { type = "button", id = "directionEastButton", width = "*", text = "East", target = self, onClick = self.onDirectionEast }
                }},
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "directionUpButton", width = "*", text = "Up", target = self, onClick = self.onDirectionUp },
                    { type = "button", id = "directionDownButton", width = "*", text = "Down", target = self, onClick = self.onDirectionDown },
                    { type = "button", id = "directionAllButton", width = "*", text = "All", target = self, onClick = self.onDirectionAll }
                }},
                { type = "columns", width = "inherit", height = buttonHeight, pad = colGap, columns = {
                    { type = "button", id = "levelTopButton", width = "*", text = "Level Top", target = self, onClick = self.onLevelTop },
                    { type = "button", id = "levelBottomButton", width = "*", text = "Level Bottom", target = self, onClick = self.onLevelBottom }
                }},
            }}
        }}
    }}

    self.elements = LayoutManager:applyLayout(self, self.layout)

    self.nameLabel = self.elements.nameLabel
    self.nameInput = self.elements.nameInput
    self.enabledTickbox = self.elements.enabledTickbox
    self.lifespanLabel = self.elements.lifespanLabel
    self.lifespanInput = self.elements.lifespanInput
    self.enabledAtLabel = self.elements.enabledAtLabel
    self.enabledAtValueLabel = self.elements.enabledAtValueLabel
    self.areasLabel = self.elements.areasLabel
    self.areasList = self.elements.areasList
    self.removeAllButton = self.elements.removeAllButton
    self.actionMoveButton = self.elements.actionMoveButton
    self.actionExpandButton = self.elements.actionExpandButton
    self.actionContractButton = self.elements.actionContractButton
    self.modeStatusLabel = self.elements.modeStatusLabel
    self.directionNorthButton = self.elements.directionNorthButton
    self.directionSouthButton = self.elements.directionSouthButton
    self.directionWestButton = self.elements.directionWestButton
    self.directionEastButton = self.elements.directionEastButton
    self.directionUpButton = self.elements.directionUpButton
    self.directionDownButton = self.elements.directionDownButton
    self.directionAllButton = self.elements.directionAllButton
    self.selectAreaButton = self.elements.selectAreaButton
    self.selectInteriorButton = self.elements.selectInteriorButton
    self.pendingAreaLabel = self.elements.pendingAreaLabel
    self.minZDownButton = self.elements.minZDownButton
    self.minZUpButton = self.elements.minZUpButton
    self.maxZDownButton = self.elements.maxZDownButton
    self.maxZUpButton = self.elements.maxZUpButton
    self.selectAreaRow = self.elements.selectAreaRow
    self.addAreaButton = self.elements.addAreaButton
    self.removeAreaButton = self.elements.removeAreaButton
    self.selectionCommitRow = self.elements.selectionCommitRow
    self.existingDangerRow = self.elements.existingDangerRow
    self.removeSelectedExistingButton = self.elements.removeSelectedExistingButton
    self.zLevelViewButton = self.elements.zLevelViewButton
    self.floorGridButton = self.elements.floorGridButton
    self.outlineToggleButton = self.elements.outlineToggleButton
    self.levelTopButton = self.elements.levelTopButton
    self.levelBottomButton = self.elements.levelBottomButton

    if self.enabledTickbox then
        self.enabledTickbox:setSelected(1, true)
    end
    if self.lifespanInput then
        self.lifespanInput:setText(self:formatLifespanSeconds(0))
    end

    if self.areasList then
        self.areasList.doDrawItem = self.drawAreaRow
        self.areasList.selected = 0
    end

    self:loadZone(self.zone)
    self:updateOutlineViewButtons()
    self:applyOutlineViewSettings()
    self:updateZControls()
    self:updateAreaActionButtons()
    self:setDirectionalAction(self.activeDirectionalAction)
    self:initializeScrolling()
    self:refreshScrollHeightFromChildren()
end

---@return 'selection'|'existing'|'global'
function GeneralPanel:getResolvedEditMode()
    if self.pendingArea then
        return MODE_SELECTION
    end

    if self.selectedAreaIndex >= 1 and self.selectedAreaIndex <= #self.areas then
        return MODE_EXISTING
    end

    return MODE_GLOBAL
end

function GeneralPanel:updateSelectAreaButtonState()
    if not self.selectAreaButton then
        return
    end

    if self.pendingArea then
        self.selectAreaButton.backgroundColor = { r = 0.55, g = 0.2, b = 0.2, a = 1.0 }
        self.selectAreaButton:setTitle("Deselect Area")
        return
    end

    if self.worldSelectionActive then
        self.selectAreaButton.backgroundColor = { r = 0.2, g = 0.75, b = 0.25, a = 1.0 }
        self.selectAreaButton:setTitle("Selecting... Click start/end")
        return
    end

    self.selectAreaButton.backgroundColor = { r = 0.0, g = 0.0, b = 0.0, a = 1.0 }
    self.selectAreaButton:setTitle("Select Area")
end

---@param outliner WastelandZones.Utils.AreaOutliner|nil
---@param forceAllZLevels boolean|nil
function GeneralPanel:applyOutlineViewToOutliner(outliner, forceAllZLevels)
    if not outliner then return end
    outliner:setEnabled(self.outlineEnabled)
    outliner:setShowAllZLevels(forceAllZLevels and true or self.showAllZLevels)
    outliner:setFloorGridEnabled(self.floorGridEnabled)
end

function GeneralPanel:applyOutlineViewSettings()
    self:applyOutlineViewToOutliner(self.areaOutliner)
    self:applyOutlineViewToOutliner(self.selectedAreaOutliner)
    self:applyOutlineViewToOutliner(self.selectionOutliner, true)
end

function GeneralPanel:updateOutlineViewButtons()
    if self.zLevelViewButton then
        if self.showAllZLevels then
            self.zLevelViewButton:setTitle("All Z")
        else
            self.zLevelViewButton:setTitle("Current Z")
        end
    end

    if self.floorGridButton then
        if self.floorGridEnabled then
            self.floorGridButton:setTitle("Floor On")
        else
            self.floorGridButton:setTitle("Floor Off")
        end
    end

    if self.outlineToggleButton then
        if self.outlineEnabled then
            self.outlineToggleButton:setTitle("Outline On")
        else
            self.outlineToggleButton:setTitle("Outline Off")
        end
    end
end

function GeneralPanel:clearAreaHighlighters()
    if self.areaOutliner then
        self.areaOutliner:cleanup()
    end
    self.areaOutliner = nil
end

function GeneralPanel:clearSelectedAreaHighlighter()
    if self.selectedAreaOutliner then
        self.selectedAreaOutliner:cleanup()
    end
    self.selectedAreaOutliner = nil
end

function GeneralPanel:refreshSelectedAreaHighlighter()
    local selectedIndex = self.selectedAreaIndex
    if selectedIndex < 1 or selectedIndex > #self.areas then
        if self.selectedAreaOutliner then
            self.selectedAreaOutliner:setAreas({})
        end
        return
    end

    if not self.selectedAreaOutliner then
        self.selectedAreaOutliner = AreaOutliner:new()
        self.selectedAreaOutliner:setColor(SELECTED_AREA_COLOR.r, SELECTED_AREA_COLOR.g, SELECTED_AREA_COLOR.b, SELECTED_AREA_COLOR.a)
        self:applyOutlineViewToOutliner(self.selectedAreaOutliner)
    end

    self.selectedAreaOutliner:setAreas({ self.areas[selectedIndex] })
end

---@param index integer
function GeneralPanel:setSelectedAreaIndex(index)
    local nextIndex = normalizeInteger(index, 0)
    if nextIndex < 1 or nextIndex > #self.areas then
        nextIndex = 0
    end

    self.selectedAreaIndex = nextIndex
    if self.areasList then
        self.areasList.selected = nextIndex
    end

    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

---@param area table|nil
---@return integer
function GeneralPanel:findAreaIndex(area)
    if not area then
        return 0
    end

    for i = 1, #self.areas do
        if self.areas[i] == area then
            return i
        end
    end

    if area.x1 == nil or area.y1 == nil or area.z1 == nil or area.x2 == nil or area.y2 == nil or area.z2 == nil then
        return 0
    end

    for i = 1, #self.areas do
        local candidate = self.areas[i]
        if candidate
        and candidate.x1 == area.x1 and candidate.y1 == area.y1 and candidate.z1 == area.z1
        and candidate.x2 == area.x2 and candidate.y2 == area.y2 and candidate.z2 == area.z2 then
            return i
        end
    end

    return 0
end

function GeneralPanel:updateAreaActionButtons()
    local hasAreas = #self.areas > 0
    local hasPending = self.pendingArea ~= nil
    local hasSelected = self.selectedAreaIndex >= 1 and self.selectedAreaIndex <= #self.areas

    local activeMode = self:getResolvedEditMode()
    local isSelectionMode = activeMode == MODE_SELECTION
    local isExistingMode = activeMode == MODE_EXISTING
    local isGlobalMode = activeMode == MODE_GLOBAL

    local hasModeTarget = (isSelectionMode and hasPending)
        or (isExistingMode and hasSelected)
        or (isGlobalMode and hasAreas)

    setButtonActive(self.actionMoveButton, self.activeDirectionalAction == ACTION_MOVE)
    setButtonActive(self.actionExpandButton, self.activeDirectionalAction == ACTION_EXPAND)
    setButtonActive(self.actionContractButton, self.activeDirectionalAction == ACTION_CONTRACT)

    setElementVisible(self.selectAreaRow, true)
    setElementVisible(self.selectionCommitRow, true)
    setElementVisible(self.existingDangerRow, true)

    setButtonEnabled(self.removeAllButton, hasAreas)
    setButtonEnabled(self.selectInteriorButton, true)
    setButtonEnabled(self.selectAreaButton, true)
    setButtonEnabled(self.addAreaButton, hasPending)
    setButtonEnabled(self.removeAreaButton, hasPending)
    setButtonEnabled(self.removeSelectedExistingButton, hasSelected)

    setButtonEnabled(self.levelTopButton, hasModeTarget)
    setButtonEnabled(self.levelBottomButton, hasModeTarget)

    setButtonEnabled(self.directionNorthButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_NORTH))
    setButtonEnabled(self.directionSouthButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_SOUTH))
    setButtonEnabled(self.directionWestButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_WEST))
    setButtonEnabled(self.directionEastButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_EAST))
    setButtonEnabled(self.directionUpButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_UP))
    setButtonEnabled(self.directionDownButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_DOWN))
    setButtonEnabled(self.directionAllButton, hasModeTarget and isDirectionAllowedForAction(self.activeDirectionalAction, DIRECTION_ALL))

    self:updateSelectAreaButtonState()
    self:updateModeStatusLabel()
end

function GeneralPanel:updateModeStatusLabel()
    if not self.modeStatusLabel then
        return
    end

    local activeMode = self:getResolvedEditMode()

    local actionName = "Move"
    if self.activeDirectionalAction == ACTION_EXPAND then
        actionName = "Expand"
    elseif self.activeDirectionalAction == ACTION_CONTRACT then
        actionName = "Contract"
    end

    if activeMode == MODE_SELECTION then
        if self.pendingArea then
            self.modeStatusLabel:setName("Target: Selection - " .. actionName)
            return
        end
        if self.worldSelectionActive then
            self.modeStatusLabel:setName("Target: Selection - Click In World")
            return
        end
        self.modeStatusLabel:setName("Target: Selection - Use Select Area to begin")
        return
    end

    if activeMode == MODE_EXISTING then
        if self.selectedAreaIndex > 0 and self.selectedAreaIndex <= #self.areas then
            self.modeStatusLabel:setName("Target: Existing Area #" .. tostring(self.selectedAreaIndex) .. " - " .. actionName)
            return
        end
        self.modeStatusLabel:setName("Target: Existing Area - Select an area from list")
        return
    end

    self.modeStatusLabel:setName("Target: Global (" .. tostring(#self.areas) .. " areas) - " .. actionName)
end

---@param action 'move'|'expand'|'contract'
function GeneralPanel:setDirectionalAction(action)
    local nextAction = action
    if nextAction ~= ACTION_MOVE and nextAction ~= ACTION_EXPAND and nextAction ~= ACTION_CONTRACT then
        nextAction = ACTION_MOVE
    end

    self.activeDirectionalAction = nextAction
    self:updateAreaActionButtons()
end

function GeneralPanel:getZoneNameForTransforms()
    return (self.nameInput and self.nameInput:getText()) or (self.zone and self.zone.name) or "Editor Zone"
end

---@param zoneHelper string
---@param amount integer|nil
function GeneralPanel:applyGlobalAreaHelper(zoneHelper, amount)
    if #self.areas == 0 then
        return
    end

    local transformedAreas = transformAreasWithZoneHelper(self.areas, zoneHelper, amount, self:getZoneNameForTransforms())
    if not transformedAreas then
        return
    end

    self.areas = transformedAreas
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

---@param zoneHelper string
---@param amount integer|nil
function GeneralPanel:applyPendingAreaHelper(zoneHelper, amount)
    if not self.pendingArea then
        return
    end

    local sourceArea = createArea(
        self.pendingArea.x1,
        self.pendingArea.y1,
        self.pendingArea.z1,
        self.pendingArea.x2,
        self.pendingArea.y2,
        self.pendingArea.z2
    )
    local transformedAreas = transformAreasWithZoneHelper({ sourceArea }, zoneHelper, amount, self:getZoneNameForTransforms())
    if not transformedAreas then
        return
    end

    if #transformedAreas == 0 then
        self:clearSelectionArea()
        return
    end

    local nextArea = transformedAreas[1]
    self.pendingArea = {
        x1 = nextArea.x1,
        y1 = nextArea.y1,
        z1 = nextArea.z1,
        x2 = nextArea.x2,
        y2 = nextArea.y2,
        z2 = nextArea.z2,
        startX = nextArea.x1,
        startY = nextArea.y1
    }
    self.pendingMinZ = nextArea.z1
    self.pendingMaxZ = nextArea.z2
    self:refreshSelectionHighlighter()
    self:updateZControls()
    self:updateAreaActionButtons()
end

---@param zoneHelper string
---@param amount integer|nil
function GeneralPanel:applySelectedAreaHelper(zoneHelper, amount)
    local selectedIndex = self.selectedAreaIndex
    if selectedIndex < 1 or selectedIndex > #self.areas then
        return
    end

    local selectedArea = self.areas[selectedIndex]
    local transformedAreas = transformAreasWithZoneHelper({ selectedArea }, zoneHelper, amount, self:getZoneNameForTransforms())
    if not transformedAreas then
        return
    end

    local mergedAreas = {}
    for i = 1, #self.areas do
        if i ~= selectedIndex then
            mergedAreas[#mergedAreas + 1] = self.areas[i]
        end
    end
    for i = 1, #transformedAreas do
        mergedAreas[#mergedAreas + 1] = transformedAreas[i]
    end

    self.areas = AreaCubePacking.packAreas(mergedAreas)
    self:refreshAreasList()
    self:refreshAreaHighlighters()

    local nextSelectedIndex = 0
    if #transformedAreas > 0 then
        nextSelectedIndex = self:findAreaIndex(transformedAreas[1])
    end
    self:setSelectedAreaIndex(nextSelectedIndex)
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

---@param zoneHelper string
---@param amount integer|nil
function GeneralPanel:applyCurrentModeHelper(zoneHelper, amount)
    local activeMode = self:getResolvedEditMode()

    if activeMode == MODE_SELECTION then
        self:applyPendingAreaHelper(zoneHelper, amount)
        return
    end
    if activeMode == MODE_EXISTING then
        self:applySelectedAreaHelper(zoneHelper, amount)
        return
    end
    self:applyGlobalAreaHelper(zoneHelper, amount)
end

---@param direction 'north'|'south'|'west'|'east'|'up'|'down'|'all'
function GeneralPanel:applyDirectionalAction(direction)
    local helper = getDirectionalHelper(self.activeDirectionalAction, direction)
    if not helper then
        return
    end
    self:applyCurrentModeHelper(helper, 1)
end

function GeneralPanel:onSetActionMove()
    self:setDirectionalAction(ACTION_MOVE)
end

function GeneralPanel:onSetActionExpand()
    self:setDirectionalAction(ACTION_EXPAND)
end

function GeneralPanel:onSetActionContract()
    self:setDirectionalAction(ACTION_CONTRACT)
end

function GeneralPanel:onDirectionNorth()
    self:applyDirectionalAction(DIRECTION_NORTH)
end

function GeneralPanel:onDirectionSouth()
    self:applyDirectionalAction(DIRECTION_SOUTH)
end

function GeneralPanel:onDirectionWest()
    self:applyDirectionalAction(DIRECTION_WEST)
end

function GeneralPanel:onDirectionEast()
    self:applyDirectionalAction(DIRECTION_EAST)
end

function GeneralPanel:onDirectionUp()
    self:applyDirectionalAction(DIRECTION_UP)
end

function GeneralPanel:onDirectionDown()
    self:applyDirectionalAction(DIRECTION_DOWN)
end

function GeneralPanel:onDirectionAll()
    self:applyDirectionalAction(DIRECTION_ALL)
end

function GeneralPanel:onLevelTop()
    self:applyCurrentModeHelper("getLeveledTopAreas")
end

function GeneralPanel:onLevelBottom()
    self:applyCurrentModeHelper("getLeveledBottomAreas")
end

function GeneralPanel:onRemoveAll()
    self.areas = {}
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

function GeneralPanel:onRemoveSelectedExistingArea()
    local selectedIndex = self.selectedAreaIndex
    if selectedIndex < 1 or selectedIndex > #self.areas then
        return
    end

    local nextAreas = {}
    for i = 1, #self.areas do
        if i ~= selectedIndex then
            nextAreas[#nextAreas + 1] = self.areas[i]
        end
    end

    self.areas = nextAreas
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

function GeneralPanel:refreshSelectionHighlighter()
    local areaToHighlight = self.pendingArea
    if not areaToHighlight
    and self.worldSelectionActive
    and not self.worldSelecting then
        areaToHighlight = self.hoverArea
    end

    if not areaToHighlight then
        if self.selectionOutliner then
            self.selectionOutliner:setAreas({})
        end
        return
    end

    if not self.selectionOutliner then
        self.selectionOutliner = AreaOutliner:new()
        self.selectionOutliner:setColor(SELECTION_COLOR.r, SELECTION_COLOR.g, SELECTION_COLOR.b, SELECTION_COLOR.a)
        self:applyOutlineViewToOutliner(self.selectionOutliner, true)
    end

    local area = areaToHighlight
    if not area then
        if self.selectionOutliner then
            self.selectionOutliner:setAreas({})
        end
        return
    end

    self.selectionOutliner:setAreas({ area })
end

---@param index integer
function GeneralPanel:updateAreaHighlighter(index)
    self:refreshAreaHighlighters()
end

function GeneralPanel:refreshAreaHighlighters()
    if not self.areaOutliner then
        self.areaOutliner = AreaOutliner:new()
        self.areaOutliner:setColor(NORMAL_AREA_COLOR.r, NORMAL_AREA_COLOR.g, NORMAL_AREA_COLOR.b, NORMAL_AREA_COLOR.a)
        self:applyOutlineViewToOutliner(self.areaOutliner)
    end

    self.areaOutliner:setAreas(self.areas)
end

function GeneralPanel:onToggleAllZLevels()
    self.showAllZLevels = not self.showAllZLevels
    self:applyOutlineViewSettings()
    self:updateOutlineViewButtons()
end

function GeneralPanel:onToggleFloorGrid()
    self.floorGridEnabled = not self.floorGridEnabled
    self:applyOutlineViewSettings()
    self:updateOutlineViewButtons()
end

function GeneralPanel:onToggleOutlineEnabled()
    self.outlineEnabled = not self.outlineEnabled
    self:applyOutlineViewSettings()
    self:updateOutlineViewButtons()
end

---@param zone WastelandZones.Classes.Zone|nil
function GeneralPanel:loadZone(zone)
    self:clearAreaHighlighters()
    self:clearSelectedAreaHighlighter()
    self.zone = zone
    self.areas = {}
    self.selectedAreaIndex = 0

    self.pendingArea = nil
    self:refreshSelectionHighlighter()
    self:updatePendingAreaLabel()

    if self.nameInput then
        self.nameInput:setText(zone and zone.name or "")
    end

    if self.enabledTickbox then
        local enabled = true
        if zone and zone.enabled ~= nil then
            enabled = zone.enabled and true or false
        end
        self.enabledTickbox:setSelected(1, enabled)
    end

    if self.lifespanInput then
        local lifespanSeconds = zone and zone.lifespan or 0
        self.lifespanInput:setText(self:formatLifespanSeconds(lifespanSeconds))
    end

    if zone and zone.areas then
        for i = 1, #zone.areas do
            local area = zone.areas[i]
            local normalized = normalizeArea(area)
            self.areas[#self.areas + 1] = normalized
        end
    end

    self:refreshAreasList()

    self:refreshAreaHighlighters()
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

---@param y number
---@param item table
---@param alt boolean
---@return number
function GeneralPanel:drawAreaRow(y, item, alt)
    if not self.parent:isVisible() then return y end

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.22, SELECTED_AREA_COLOR.r, SELECTED_AREA_COLOR.g, SELECTED_AREA_COLOR.b)
    elseif alt then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.07, 1, 1, 1)
    end

    local area = item.item
    local label = string.format("%d,%d,%d -> %d,%d,%d", area.x1, area.y1, area.z1, area.x2, area.y2, area.z2)
    self:drawText(label, 6, y + 2, 1, 1, 1, 0.95, self.font)
    return y + self.itemheight
end

---@param item table
---@return boolean
function GeneralPanel:onAreaListMouseDown(item)
    local clickedArea = item
    if clickedArea and clickedArea.item then
        clickedArea = clickedArea.item
    end

    local clickedIndex = self:findAreaIndex(clickedArea)
    if clickedIndex > 0 and clickedIndex == self.selectedAreaIndex then
        self:setSelectedAreaIndex(0)
    else
        self:setSelectedAreaIndex(clickedIndex)
    end

    return true
end

function GeneralPanel:refreshAreasList()
    if not self.areasList then return end
    self.areasList:clear()
    for i = 1, #self.areas do
        self.areasList:addItem(tostring(i), self.areas[i])
    end

    if self.selectedAreaIndex < 1 or self.selectedAreaIndex > #self.areas then
        self.selectedAreaIndex = 0
    end

    self.areasList.selected = self.selectedAreaIndex
    self:updateAreaActionButtons()
end

function GeneralPanel:updatePendingAreaLabel()
    if not self.pendingAreaLabel then return end

    if not self.pendingArea then
        self.pendingAreaLabel:setName(string.format("Selected Area: none (z %d..%d)", self.pendingMinZ, self.pendingMaxZ))
        return
    end

    local area = self.pendingArea
    self.pendingAreaLabel:setName(string.format(
        "Selected Area: %d,%d,%d -> %d,%d,%d",
        area.x1, area.y1, area.z1,
        area.x2, area.y2, area.z2
    ))
end

function GeneralPanel:updateZControls()
    if self.pendingMinZ < MIN_Z then self.pendingMinZ = MIN_Z end
    if self.pendingMaxZ > MAX_Z then self.pendingMaxZ = MAX_Z end
    if self.pendingMinZ > self.pendingMaxZ then
        self.pendingMinZ = self.pendingMaxZ
    end

    setButtonEnabled(self.minZDownButton, self.pendingMinZ > MIN_Z)
    setButtonEnabled(self.minZUpButton, self.pendingMinZ < self.pendingMaxZ)
    setButtonEnabled(self.maxZDownButton, self.pendingMaxZ > self.pendingMinZ)
    setButtonEnabled(self.maxZUpButton, self.pendingMaxZ < MAX_Z)

    if self.pendingArea then
        self.pendingArea.z1 = self.pendingMinZ
        self.pendingArea.z2 = self.pendingMaxZ
        self:refreshSelectionHighlighter()
    elseif self.hoverArea then
        self.hoverArea.z1 = self.pendingMinZ
        self.hoverArea.z2 = self.pendingMaxZ
        self:refreshSelectionHighlighter()
    end

    self:updatePendingAreaLabel()
end

function GeneralPanel:onMinZDown()
    if self.pendingMinZ <= MIN_Z then return end
    self.pendingMinZ = self.pendingMinZ - 1
    if self.pendingMaxZ < self.pendingMinZ then
        self.pendingMaxZ = self.pendingMinZ
    end
    self:updateZControls()
end

function GeneralPanel:onMinZUp()
    if self.pendingMinZ >= self.pendingMaxZ then return end
    self.pendingMinZ = self.pendingMinZ + 1
    self:updateZControls()
end

function GeneralPanel:onMaxZDown()
    if self.pendingMaxZ <= self.pendingMinZ then return end
    self.pendingMaxZ = self.pendingMaxZ - 1
    self:updateZControls()
end

function GeneralPanel:onMaxZUp()
    if self.pendingMaxZ >= MAX_Z then return end
    self.pendingMaxZ = self.pendingMaxZ + 1
    if self.pendingMinZ > self.pendingMaxZ then
        self.pendingMinZ = self.pendingMaxZ
    end
    self:updateZControls()
end

---@param active boolean
function GeneralPanel:setWorldSelectionActive(active)
    self.worldSelectionActive = active and true or false
    self.hoverArea = nil

    if self.worldSelectionActive then
        ACTIVE_SELECTOR_PANEL = self
    else
        if ACTIVE_SELECTOR_PANEL == self then
            ACTIVE_SELECTOR_PANEL = nil
        end
        self.worldSelecting = false
    end

    self:updateSelectAreaButtonState()
    self:refreshSelectionHighlighter()
    self:updateAreaActionButtons()
end

function GeneralPanel:onToggleSelectArea()
    if self.pendingArea then
        self:setWorldSelectionActive(false)
        self:clearSelectionArea()
        return
    end

    self:setWorldSelectionActive(not self.worldSelectionActive)
end

function GeneralPanel:onSelectBuildingInterior()
    local foundAreas = IndoorAreaSearcher.searchFromPlayer(getPlayer())
    if #foundAreas == 0 then
        return
    end

    local mergedAreas = {}

    for i = 1, #self.areas do
        mergedAreas[#mergedAreas + 1] = self.areas[i]
    end

    for i = 1, #foundAreas do
        local area = foundAreas[i]
        mergedAreas[#mergedAreas + 1] = createArea(area.x1, area.y1, area.z1, area.x2, area.y2, area.z2)
    end

    self.areas = AreaCubePacking.packAreas(mergedAreas)

    self:clearSelectionArea()
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
    self:refreshSelectedAreaHighlighter()
    self:updateAreaActionButtons()
end

---@param worldX integer
---@param worldY integer
function GeneralPanel:startWorldSelection(worldX, worldY)
    self.worldSelecting = true
    self.hoverArea = nil
    self.pendingArea = {
        startX = worldX,
        startY = worldY,
        x1 = worldX,
        y1 = worldY,
        z1 = self.pendingMinZ,
        x2 = worldX,
        y2 = worldY,
        z2 = self.pendingMaxZ
    }
    self:refreshSelectionHighlighter()
    self:updatePendingAreaLabel()
    self:updateAreaActionButtons()
end

---@param worldX integer|nil
---@param worldY integer|nil
function GeneralPanel:updateWorldSelectionHover(worldX, worldY)
    if self.worldSelecting
    or not self.worldSelectionActive
    or not worldX or not worldY then
        return
    end

    self.hoverArea = {
        x1 = worldX,
        y1 = worldY,
        z1 = self.pendingMinZ,
        x2 = worldX,
        y2 = worldY,
        z2 = self.pendingMaxZ
    }
    self:refreshSelectionHighlighter()
    self:updateAreaActionButtons()
end

---@param worldX integer|nil
---@param worldY integer|nil
function GeneralPanel:updateWorldSelection(worldX, worldY)
    if not self.worldSelecting
    or not self.pendingArea
    or not worldX or not worldY then
        return
    end
    
    self.pendingArea.x1 = math.min(self.pendingArea.startX, worldX)
    self.pendingArea.y1 = math.min(self.pendingArea.startY, worldY)
    self.pendingArea.x2 = math.max(self.pendingArea.startX, worldX)
    self.pendingArea.y2 = math.max(self.pendingArea.startY, worldY)
    self.pendingArea.z1 = self.pendingMinZ
    self.pendingArea.z2 = self.pendingMaxZ
    self:refreshSelectionHighlighter()
    self:updatePendingAreaLabel()
    self:updateAreaActionButtons()
end

function GeneralPanel:finishWorldSelection()
    self.worldSelecting = false
    if self.pendingArea then
        self:refreshSelectionHighlighter()
    end
    self:updatePendingAreaLabel()
    self:updateAreaActionButtons()
end

function GeneralPanel:onAddArea()
    if not self.pendingArea then return end

    local area = createArea(
        self.pendingArea.x1,
        self.pendingArea.y1,
        self.pendingArea.z1,
        self.pendingArea.x2,
        self.pendingArea.y2,
        self.pendingArea.z2
    )
    self.areas = AreaCubePacking.apply(self.areas, "add", area)

    self:clearSelectionArea()
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
end

function GeneralPanel:onRemoveArea()
    if not self.pendingArea then return end

    local area = createArea(
        self.pendingArea.x1,
        self.pendingArea.y1,
        self.pendingArea.z1,
        self.pendingArea.x2,
        self.pendingArea.y2,
        self.pendingArea.z2
    )
    self.areas = AreaCubePacking.apply(self.areas, "remove", area)

    self:clearSelectionArea()
    self:refreshAreasList()
    self:setSelectedAreaIndex(0)
    self:refreshAreaHighlighters()
end

function GeneralPanel:clearSelectionArea()
    self.pendingArea = nil
    self:refreshSelectionHighlighter()
    self:updatePendingAreaLabel()
    self:updateAreaActionButtons()
end

---@return {name:string,areas:WastelandZones.Classes.Area[],enabled:boolean,lifespan:integer,enabledAt:integer}, string[]
function GeneralPanel:collectGeneralData()
    local errors = {}
    local name = self.nameInput and self.nameInput:getText() or ""
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local enabled = self.enabledTickbox and self.enabledTickbox:isSelected(1)

    local lifespanInput = self.lifespanInput and self.lifespanInput:getText() or ""
    local lifespan, lifespanError = self:parseLifespanInputToSeconds(lifespanInput)
    if lifespanError or lifespan == nil then
        errors[#errors + 1] = "Lifespan is invalid"
        lifespan = 0
    end

    local enabledAt = 0
    if self.zone and self.zone.enabledAt ~= nil then
        enabledAt = math.max(0, math.floor(tonumber(self.zone.enabledAt) or 0))
    end

    if name == "" then
        errors[#errors + 1] = "Zone name cannot be empty"
    end

    if #self.areas == 0 then
        errors[#errors + 1] = "At least one area is required"
    end

    local normalizedAreas = {}
    for i = 1, #self.areas do
        local area = self.areas[i]
        local z1 = Utils.clampZ(area.z1)
        local z2 = Utils.clampZ(area.z2)
        if z1 > z2 then
            z1, z2 = z2, z1
        end
        normalizedAreas[#normalizedAreas + 1] = createArea(area.x1, area.y1, z1, area.x2, area.y2, z2)
    end

    return {
        name = name,
        areas = normalizedAreas,
        enabled = enabled and true or false,
        lifespan = lifespan,
        enabledAt = enabledAt
    }, errors
end

function GeneralPanel:cleanup()
    self.cleanedUp = true
    ACTIVE_SELECTOR_PANEL = nil
    self:setWorldSelectionActive(false)

    if self.selectionOutliner then
        self.selectionOutliner:cleanup()
    end
    self.selectionOutliner = nil

    self:clearSelectedAreaHighlighter()

    self:clearAreaHighlighters()
end
