-- Compute min/max bounds
local function _bounds(x1, y1, z1, x2, y2, z2)
    local bx1 = math.min(x1, x2)
    local by1 = math.min(y1, y2)
    local bz1 = math.min(z1, z2)
    local bx2 = math.max(x1, x2)
    local by2 = math.max(y1, y2)
    local bz2 = math.max(z1, z2)
    return bx1, by1, bz1, bx2, by2, bz2
end

-- Area value helpers for cheap change detection
local function _copyArea(v)
    v = v or {}
    return {
        x1 = v.x1 or 0, y1 = v.y1 or 0, z1 = v.z1 or 0,
        x2 = v.x2 or 0, y2 = v.y2 or 0, z2 = v.z2 or 0
    }
end

local function _areaEquals(a, b)
    return a and b
        and a.x1 == b.x1 and a.y1 == b.y1 and a.z1 == b.z1
        and a.x2 == b.x2 and a.y2 == b.y2 and a.z2 == b.z2
end

-- Geometry/ownership helpers (module scope so they aren't redefined per call)
-- Containment is inclusive on all axes (edges and corners count as contained).
local function _rectContains(ax1, ay1, az1, ax2, ay2, az2, bx1, by1, bz1, bx2, by2, bz2)
    return ax1 <= bx1 and ay1 <= by1 and az1 <= bz1
       and ax2 >= bx2 and ay2 >= by2 and az2 >= bz2
end

-- Overlap including shared edges/corners on all axes (no touching allowed).
-- This blocks any intersection or boundary contact in X/Y/Z, including single-level Z slices (e.g., 0..0 vs 0..2).
local function _rectOverlaps(ax1, ay1, az1, ax2, ay2, az2, bx1, by1, bz1, bx2, by2, bz2)
    local ox = (ax1 <= bx2) and (ax2 >= bx1)
    local oy = (ay1 <= by2) and (ay2 >= by1)
    local oz = (az1 <= bz2) and (az2 >= bz1)
    return ox and oy and oz
end

local function _isOwnerOf(zone, username)
    if not zone or not zone.members or not username then return false end
    local m = zone.members[username]
    if not m then return false end
    local role = m.type or m.role
    return role == "owner"
end

-- Custom Safezone creation panel with validation-aware highlighting
WSZ_CreateSafezonePanel = ISPanel:derive("WSZ_CreateSafezonePanel")
WSZ_CreateSafezonePanel.instance = nil

function WSZ_CreateSafezonePanel:show(player, startingCoordinates)
    if WSZ_CreateSafezonePanel.instance then
        WSZ_CreateSafezonePanel.instance:onClose()
    end

    local s = getTextManager():getFontHeight(UIFont.Small) / 12
    local w = 300 * s
    local h = 130 * s
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2, getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    o.__index = self

    -- Accept either {startX,startY,endX,endY} or {x,y,z}
    local sx = startingCoordinates.startX or startingCoordinates.x or 0
    local sy = startingCoordinates.startY or startingCoordinates.y or 0
    local ex = startingCoordinates.endX   or (startingCoordinates.x and startingCoordinates.x) or 0
    local ey = startingCoordinates.endY   or (startingCoordinates.y and startingCoordinates.y) or 0

    o.player = player

    o.startX = sx
    o.startY = sy
    o.endX = ex
    o.endY = ey
    o.startZ = 0
    o.endZ = 7
    o._valid = false
    o._invalidReason = nil

    o:initialise()
    o:addToUIManager()
    WSZ_CreateSafezonePanel.instance = o
    return o
end

function WSZ_CreateSafezonePanel:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local win = GravyUI.Node(self.width, self.height):pad(5)
    local header, body, footer = win:rows({30, 1, 25}, 5)
    local header, headerRight = header:cols({1, 100}, 5)
    local nameInput, reasonRow, areaPicker = body:rows({0.33, 20, 0.67}, 5)

    local b1, b2 = footer:cols(2, 5)

    self.headerBox = header:makeLabel("Safezone Creator", UIFont.Medium)

    self.showHighlightCheckbox = headerRight:makeTickBox()

    local nameInput1, nameInput2 = nameInput:cols({0.25, 0.75}, 5)
    self.nameLabel = nameInput1:makeLabel("Name:")
    self.nameInput = nameInput2:makeTextBox("")

    self.areaPicker = areaPicker:makeAreaPicker()
    self.areaPicker.showAlways = true
    self.areaPicker:setValue({
        x1 = self.startX,
        y1 = self.startY,
        x2 = self.endX,
        y2 = self.endY,
        z1 = self.startZ,
        z2 = self.endZ
    })
    -- initialize dirty-tracking so we only validate when inputs change
    self._lastName = self.nameInput and self.nameInput:getText() or ""
    self._lastArea = _copyArea(self.areaPicker.value or {})
    self._dirty = true

    -- Validation reason label (shows when invalid)
    self.reasonLabel = reasonRow:makeLabel("", UIFont.Small, {r=1, g=0.3, b=0.3, a=1}, "left", true)

    -- Default good color = green
    if self.areaPicker.groundHighlighter then
        self.areaPicker.groundHighlighter:setColor(0, 1, 0, 1)
    end

    self.createZoneButton = b1:makeButton("Create Safezone", self, self.onCreateZone)
    self.closeButton = b2:makeButton("Close", self, self.onClose)

    self:addChild(self.headerBox)
    self:addChild(self.nameLabel)
    self:addChild(self.showHighlightCheckbox)
    self:addChild(self.nameInput)
    self:addChild(self.areaPicker)
    -- add reason label to panel
    if self.reasonLabel then
        self:addChild(self.reasonLabel)
    end
    self:addChild(self.createZoneButton)
    self:addChild(self.closeButton)

    self.showHighlightCheckbox:addOption("Highlight?")
    self.showHighlightCheckbox:setSelected(1, true)
end

-- Perform validation and provide reason when invalid
function WSZ_CreateSafezonePanel:validateSelection()
    local name = self.nameInput and self.nameInput:getText() or ""
    local x1, y1, z1 = self.areaPicker.value.x1 or 0, self.areaPicker.value.y1 or 0, self.areaPicker.value.z1 or 0
    local x2, y2, z2 = self.areaPicker.value.x2 or 0, self.areaPicker.value.y2 or 0, self.areaPicker.value.z2 or 0

    if x1 == 0 or y1 == 0 or x2 == 0 or y2 == 0 then
        return false, "Select an area first."
    end
    if not name or name == "" then
        return false, "Safezone name is required."
    end

    if WL_Utils.isStaff(self.player) then
        -- Staff can create any safezone they want
        return true, nil
    end

    local bx1, by1, bz1, bx2, by2, bz2 = _bounds(x1, y1, z1, x2, y2, z2)
    local width  = math.abs(bx2 - bx1) + 1
    local height = math.abs(by2 - by1) + 1
    local zSpan  = math.abs(bz2 - bz1) + 1

    local maxXY = SandboxVars.WastelandSafezone.MaxClaimSizeXY
    local maxZ  = SandboxVars.WastelandSafezone.MaxClaimSizeZ

    if width > maxXY or height > maxXY then
        return false, "Safezone too large. Max dimensions are " .. tostring(maxXY) .. "x" .. tostring(maxXY) .. "."
    end
    if zSpan > maxZ then
        return false, "Safezone vertical span too large. Max z-levels is " .. tostring(maxZ) .. "."
    end

    -- Overlap rules against existing safezones:
    -- 1) No partial overlaps with any existing safezone
    -- 2) New zone may be fully inside an existing one only if creator owns the outer zone
    -- 3) New zone may not fully envelope an existing safezone

    local player = self.player or getPlayer()
    local username = player and player:getUsername() or nil

    local ownsAny = false
    local insideOwned = false

    if WSZ_Client and WSZ_Client.zones then
        for _, existing in pairs(WSZ_Client.zones) do
            local ex1, ey1, ez1 = existing.x1, existing.y1, existing.z1
            local ex2, ey2, ez2 = existing.x2, existing.y2, existing.z2

            if ex1 > ex2 then ex1, ex2 = ex2, ex1 end
            if ey1 > ey2 then ey1, ey2 = ey2, ey1 end
            if ez1 > ez2 then ez1, ez2 = ez2, ez1 end

            local newInsideExisting = _rectContains(ex1, ey1, ez1, ex2, ey2, ez2, bx1, by1, bz1, bx2, by2, bz2)
            local existingInsideNew = _rectContains(bx1, by1, bz1, bx2, by2, bz2, ex1, ey1, ez1, ex2, ey2, ez2)
            local overlaps = _rectOverlaps(bx1, by1, bz1, bx2, by2, bz2, ex1, ey1, ez1, ex2, ey2, ez2)

            local isOwner = username and _isOwnerOf(existing, username)
            if isOwner then
                ownsAny = true
            end

            -- Rule 3: cannot fully envelope another zone
            if existingInsideNew then
                return false, "Cannot fully envelope existing safezone '" .. (existing.name or "Safezone") .. "'."
            end

            -- Rule 2 + Rule 1 handling (original behavior)
            if newInsideExisting then
                if not isOwner then
                    return false, "Must be owner of outer safezone '" .. (existing.name or "Safezone") .. "' to create a nested safezone."
                end
                -- Track that the new zone is inside at least one zone they own
                insideOwned = true
                -- keep checking other zones for conflicts
            else
                -- Rule 1: disallow partial overlap (any overlap that isn't full containment one way)
                if overlaps then
                    return false, "Cannot partially overlap existing safezone '" .. (existing.name or "Safezone") .. "'."
                end
            end
        end
    end

    -- If player already owns any safezone, any new safezone must be fully enclosed within one they already own.
    if ownsAny and not insideOwned then
        -- Additionally enforce top-level ownership limit for creating a new top-level zone (not enclosed).
        -- Players may own unlimited nested zones inside their existing ones.
        local rootCount = (username and WSZ_Client and WSZ_Client.countOwnedRootZones and WSZ_Client.countOwnedRootZones(username)) or 0
        local maxRoots = (SandboxVars and SandboxVars.WastelandSafezone and SandboxVars.WastelandSafezone.MaxPlayerSafezones) or 1
        if rootCount >= maxRoots then
            return false, "You reached the limit of " .. tostring(maxRoots) .. " top-level safezones. Create nested safezones inside your owned safezones instead."
        end

        -- Enforce the stricter rule: must be enclosed within one they already own.
        return false, "You already own a safezone; new safezones must be fully inside one you own."
    end

    -- When creating a top-level zone (no existing ownership), enforce the top-level limit as well.
    local ownedCount = (username and WSZ_Client and WSZ_Client.countOwnedZones and WSZ_Client.countOwnedZones(username)) or 0
    local maxRoots = (SandboxVars and SandboxVars.WastelandSafezone and SandboxVars.WastelandSafezone.MaxPlayerSafezones) or 1
    if ownedCount >= maxRoots and not insideOwned then
        return false, "You reached the limit of " .. tostring(maxRoots) .. " top-level safezones."
    end

    -- If top-level zones and if commercial claims are disallowed, and the area includes a building, enforce SafehouseLimiter rules via WSZ_Client
    if not insideOwned and SandboxVars.WastelandSafezone.CanClaimCommercial == false and not WL_Utils.isStaff(self.player) then
        local building = WSZ_Client.findAnyBuildingInArea(bx1, by1, bx2, by2)
        if building then
            local ok, reason = WSZ_Client.checkBuildingDef(building)
            if not ok then
                return false, reason or "Cannot claim area containing this building."
            end
        end
    end

    return true, nil
end

function WSZ_CreateSafezonePanel:prerender()
    ISPanel.prerender(self)

    -- Only show highlighter if requested
    self.areaPicker.showAlways = self.showHighlightCheckbox:isSelected(1)

    -- Cheap change detection: compare name and area values
    local currentName = self.nameInput and self.nameInput:getText() or ""
    local currentArea = _copyArea(self.areaPicker.value or {})

    local changed = false
    if currentName ~= (self._lastName or "") then
        self._lastName = currentName
        changed = true
    end
    if not _areaEquals(currentArea, self._lastArea) then
        self._lastArea = currentArea
        changed = true
    end

    if self._dirty or changed then
        self._dirty = false

        -- Mirror live values out of picker only when changed
        self.startX = currentArea.x1
        self.startY = currentArea.y1
        self.endX   = currentArea.x2
        self.endY   = currentArea.y2
        self.startZ = currentArea.z1
        self.endZ   = currentArea.z2

        -- Validate only when something changed
        local ok, reason = self:validateSelection()
        self._valid = ok
        self._invalidReason = reason

        -- Update on-panel reason text
        if self.reasonLabel then
            if ok then
                self.reasonLabel:setText("")
            else
                self.reasonLabel:setText(reason or "")
            end
        end

        -- Update highlighter color on changes
        if self.areaPicker.groundHighlighter then
            if ok then
                self.areaPicker.groundHighlighter:setColor(0, 1, 0, 1) -- green
            else
                self.areaPicker.groundHighlighter:setColor(1, 0, 0, 1) -- red
            end
        end
    end
end

function WSZ_CreateSafezonePanel:onCreateZone()
    -- Validate first; do NOT close on failed validation.
    local ok, reason = self:validateSelection()
    if not ok then
        if reason and WSZ_Client and WSZ_Client.ShowRestricted then
            WSZ_Client.ShowRestricted(self.player, reason)
        end
        -- Keep panel open; color already red from prerender
        return
    end

    -- Compute bounds and create
    local x1, y1, z1 = self.startX, self.startY, self.startZ
    local x2, y2, z2 = self.endX, self.endY, self.endZ
    local bx1, by1, bz1, bx2, by2, bz2 = _bounds(x1, y1, z1, x2, y2, z2)

    -- Create via system
    local name = self.nameInput:getText()
    WSZ_System:createZone(self.player, name, {
        x1 = bx1, y1 = by1, z1 = bz1,
        x2 = bx2, y2 = by2, z2 = bz2
    })

    WSZ_Client.ShowInfo(self.player, "Safezone created: " .. name)

    -- Clear selection and close
    self.startX, self.startY, self.startZ = 0, 0, 0
    self.endX,   self.endY,   self.endZ   = 0, 0, 0
    self:onClose()
end

function WSZ_CreateSafezonePanel:onClose()
    WSZ_CreateSafezonePanel.instance = nil
    self:removeFromUIManager()
end

function WSZ_CreateSafezonePanel:removeFromUIManager()
    if self.areaPicker then
        self.areaPicker:cleanup()
    end
    ISPanel.removeFromUIManager(self)
end