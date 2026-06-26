--- @class WSZ_ClientZone : WSZ_Zone
--- @field wlZone WSZ_WL_Zone

--- @class WSZ_WL_Zone : WL_Zone
--- @field parent WSZ_ClientZone

--- @class WSZ_Permissions
--- @field isOfficer boolean
--- @field canViewItems boolean
--- @field canMoveItems boolean
--- @field canForage boolean
--- @field canInteractItems boolean

--- @class WSZ_Client
WSZ_Client = {}

--- Stores all active zones
--- @type table<string, WSZ_ClientZone>
WSZ_Client.zones = {}

--- Current Permissions for active user
--- @type WSZ_Permissions
WSZ_Client.currentPermissions = {
    isOwner = false,
    isOfficer = false,
    canViewItems = true,
    canMoveItems = true,
    canForage = true,
    canInteractItems = true,
}

--- UI element for showing protected safezone notice
--- @type ISUIElement
WSZ_Client.protectedZoneUI = nil

-- Refresh the Safezone panel if it's open and showing this zone
function WSZ_Client._refreshOpenPanelForZone(zoneId)
    if not WSZ_ManageSafezone or not WSZ_ManageSafezone.instance then return end
    local ui = WSZ_ManageSafezone.instance
    if not ui.zone or ui.zone.id ~= zoneId then return end
    -- Ensure UI points at the latest zone object (table may be replaced)
    local latest = WSZ_Client.zones[zoneId]
    if latest then ui.zone = latest end
    ui:updateState()
end

--- @param wlZone WSZ_WL_Zone
--- @param player IsoPlayer
function onEnteredZone(wlZone, player)
    -- Always notify server when player enters zone - let server handle membership check
    -- This ensures we don't miss updates due to stale client-side membership data
    WSZ_System:playerVisited(player, wlZone.parent.id)

    if wlZone.parent.members[player:getUsername()] then
        WSZ_Client.ShowValid(player, "Entered safezone: " .. wlZone.parent.name)
        return
    end
end

function onExitedZone(wlZone, player)
    WSZ_Client.ShowInfo(player, "Left safezone: " .. wlZone.parent.name)
end

local function getMapName(wlZone)
    return wlZone.parent.name or "Safezone"
end

--- Updates the specified zone
--- @param zoneObj WSZ_Zone
function WSZ_Client.updateZone(zoneObj)
    if WSZ_Client.zones[zoneObj.id] then
        WSZ_Client.removeZone(zoneObj.id)
    end

    local wlZone = WL_Zone:new(zoneObj.x1, zoneObj.y1, zoneObj.z1, zoneObj.x2, zoneObj.y2, zoneObj.z2)
    wlZone.onPlayerEnteredZone = onEnteredZone
    wlZone.onPlayerExitedZone = onExitedZone
    wlZone.parent = zoneObj
    wlZone.mapType = "Safezone"
    wlZone.mapColor = {0.3, 1.0, 0.3}
    wlZone.getMapName = getMapName
    WL_TriggerZones.addZone(wlZone, true)
    zoneObj.wlZone = wlZone
    WSZ_Client.zones[zoneObj.id] = zoneObj

    -- If panel is open for this zone, refresh it
    WSZ_Client._refreshOpenPanelForZone(zoneObj.id)
end

function WSZ_Client.removeZone(zoneId)
    if WSZ_Client.zones[zoneId] then
        local zoneObj = WSZ_Client.zones[zoneId]
        if zoneObj.wlZone then
            WL_TriggerZones.removeZone(zoneObj.wlZone)
            zoneObj.wlZone:delete()
        end
        WSZ_Client.zones[zoneId] = nil
    end
end

--- Called when a member is updated or added to a zone
--- @param zoneId string The ID of the zone containing the member
--- @param memberObject WSZ_Member The updated member data
function WSZ_Client.onMemberUpdated(zoneId, memberObject)
    local zone = WSZ_Client.zones[zoneId]
    if not zone then
        return
    end

    -- Show notice if is current player and not already in zone
    local player = getPlayer()
    if player and memberObject.username == player:getUsername() and not zone.members[player:getUsername()] then
        WSZ_Client.ShowInfo(player, "You have been added to the safezone: " .. zone.name)
    end

    -- Update the member in the local zone data
    zone.members[memberObject.username] = memberObject

    -- Refresh UI if open on this zone
    WSZ_Client._refreshOpenPanelForZone(zoneId)
end

--- Called when a member is removed from a zone
--- @param zoneId string The ID of the zone the member was removed from
--- @param username string The username of the removed member
function WSZ_Client.onMemberRemoved(zoneId, username)
    local zone = WSZ_Client.zones[zoneId]
    if not zone then
        return
    end

    -- Show notice if current player
    local player = getPlayer()
    if player and username == player:getUsername() then
        WSZ_Client.ShowInfo(player, "You have been removed from the safezone: " .. zone.name)
    end

    -- Remove the member from the local zone data
    zone.members[username] = nil

    -- Refresh UI if open on this zone
    WSZ_Client._refreshOpenPanelForZone(zoneId)
end

--- get the zones the player is standing in
--- @param player IsoPlayer
--- @return WSZ_ClientZone[]
function WSZ_Client.getCurrentZonesIn(player)
    local zonesIn = {}
    for _, zoneObj in pairs(WSZ_Client.zones) do
        if zoneObj.wlZone:isPlayerInZone(player) then
            table.insert(zonesIn, zoneObj)
        end
    end
    return zonesIn
end

--- get the zones the player is currently a member of
--- @param player IsoPlayer
--- @return WSZ_ClientZone[]
function WSZ_Client.getZonesMemberOf(player)
    local zones = {}
    for _, zoneObj in pairs(WSZ_Client.zones) do
        if zoneObj.members[player:getUsername()] then
            table.insert(zones, zoneObj)
        end
    end
    return zones
end

--- get the zones that contain the specified coordinates
--- @param x number
--- @param y number
--- @param z number
--- @return WSZ_ClientZone[]
function WSZ_Client.getZonesAt(x, y, z)
    x = math.floor(x)
    y = math.floor(y)
    z = math.floor(z)
    local zonesAt = {}
    for _, zoneObj in pairs(WSZ_Client.zones) do
        -- Check if coordinates are within zone bounds
        if x >= zoneObj.x1 and x <= zoneObj.x2 and
           y >= zoneObj.y1 and y <= zoneObj.y2 and
           z >= zoneObj.z1 and z <= zoneObj.z2 then
            table.insert(zonesAt, zoneObj)
        end
    end
    return zonesAt
end

--- get the permissions at the specified coordinates
--- @param x number
--- @param y number
--- @param z number
--- @return WSZ_Permissions
function WSZ_Client.getPermissionsAt(x, y, z)
    local zones = WSZ_Client.getZonesAt(x, y, z)
    local player = getPlayer()
    
    local permissions = {
        isOwner = false,
        isOfficer = false,
        canViewItems = true,
        canMoveItems = true,
        canForage = true,
        canInteractItems = true
    }

    if player and WL_Utils.isStaff(player) then
        return permissions
    end

    -- If no player or no zones at this location, return default permissions
    if not player or #zones == 0 then
        return permissions
    end

    -- Check permissions in overlapping zones (most restrictive wins)
    for _, zone in ipairs(zones) do
        local member = zone.members[player:getUsername()]
        if not member then
            -- Player is not a member of this zone, restrict all permissions
            permissions.canViewItems = false
            permissions.canMoveItems = false
            permissions.canForage = false
            permissions.canInteractItems = false
            break
        end
        
        -- Set role-based permissions
        if member.role == "officer" then
            permissions.isOfficer = true
        end
        if member.role == "owner" then
            permissions.isOwner = true
            permissions.isOfficer = true
        end
    end

    return permissions
end

--- handles a player moving
--- Sets current permissions
--- Shows notifications for entering and leaving safezones
--- @param player IsoPlayer
function WSZ_Client.onPlayerMoved(player)
    local zones = WSZ_Client.getCurrentZonesIn(player)

    local permissions = {
        isOwner = false,
        isOfficer = false,
        canViewItems = true,
        canMoveItems = true,
        canForage = true,
        canInteractItems = true
    }

    local inProtectedZone = false

    if WL_Utils.isStaff(player) then
        WSZ_Client.currentPermissions = permissions
        WSZ_Client.hideProtectedZoneUI()
        return
    end

    -- right now, permissions in overlapping zones determine the most restrictive set
    -- this is so a "room" inside a larger zone is protected
    for _, zone in ipairs(zones) do
        local member = zone.members[player:getUsername()]
        if not member then
            permissions.canViewItems = false
            permissions.canMoveItems = false
            permissions.canForage = false
            permissions.canInteractItems = false
            inProtectedZone = true
            break
        -- potentially later have fine grained safezone permissions
        end
        if member.role == "officer" then
            permissions.isOfficer = true
        end
        if member.role == "owner" then
            permissions.isOwner = true
            permissions.isOfficer = true
        end
    end

    WSZ_Client.currentPermissions = permissions
    
    -- Show or hide the protected zone UI based on whether player is in a protected zone
    if inProtectedZone then
        WSZ_Client.showProtectedZoneUI()
    else
        WSZ_Client.hideProtectedZoneUI()
    end
end

local function protectedZonePrerender(self)
    local w = getPlayerScreenWidth(self.playerNum)
    local h = getPlayerScreenHeight(self.playerNum)
    self:drawRectBorder(0, 0, w, h, 1, 1, 0, 0) -- red border around screen
    local elapsedTime = (getTimestampMs() - self.startTime) / 1000.0 -- Convert to seconds
    local textAlpha = 1.0
    if elapsedTime > 5.0 then
        -- Start fading after 5 seconds
        local fadeTime = elapsedTime - 5.0
        if fadeTime < 3.0 then
            -- Fade over 3 seconds
            textAlpha = 1.0 - (fadeTime / 3.0)
        else
            -- Fully faded after 8 seconds total
            textAlpha = 0.0
        end
    end
    if textAlpha > 0 then
        -- Draw text with calculated alpha
        self:drawTextCentre(self.message, w/2, h/3, 1, 0, 0, textAlpha, UIFont.Large) -- red text with fadeTimeOption
    end
end

--- Shows the protected safezone UI notice
function WSZ_Client.showProtectedZoneUI()
    if WSZ_Client.protectedZoneUI then
        return -- Already showing
    end
    
    local player = getPlayer()
    if not player then return end
    
    local playerNum = player:getPlayerNum()
    local x = getPlayerScreenLeft(playerNum)
    local y = getPlayerScreenTop(playerNum)
    
    local message = "Safezone: No Permission"
    local startTime = getTimestampMs()
    
    local ele = ISUIElement:new(x, y, 0, 0)
    ele.startTime = startTime
    ele.message = message
    ele.playerNum = playerNum
    ele.prerender = protectedZonePrerender
    ele:initialise()
    ele:addToUIManager()
    ele:setCapture(false)
    ele:setAlwaysOnTop(true)
    WSZ_Client.protectedZoneUI = ele
end

--- Hides the protected safezone UI notice
function WSZ_Client.hideProtectedZoneUI()
    if WSZ_Client.protectedZoneUI then
        WSZ_Client.protectedZoneUI:removeFromUIManager()
        WSZ_Client.protectedZoneUI = nil
    end
end

function WSZ_Client.ShowRestricted(character, message)
    character:setHaloNote(message, 250, 20, 60, 500.0)
end

function WSZ_Client.ShowInfo(character, message)
    character:setHaloNote(message, 76, 154, 237, 500.0)
end

function WSZ_Client.ShowValid(character, message)
    character:setHaloNote(message, 20, 250, 60, 500.0)
end

-- SafehouseLimiter-style building checks centralized for reuse
-- Returns (true, nil) if building is allowed, otherwise (false, reason)
function WSZ_Client.checkBuildingDef(building)
    if not building then
        return false, "Internal error. Make ticket to claim."
    end
    
    if not building:isResidential() then
        return false, "Not residential. Make ticket to claim."
    end

    local def = building:getDef()
    if not def then
        return false, "No building definition. Make ticket to claim."
    end

    local numBedrooms = 0
    local rooms = def:getRooms()
    for i = 0, rooms:size() - 1 do
        local room = rooms:get(i)
        if room:getName() == "bedroom" then
            numBedrooms = numBedrooms + 1
        end
    end
    if numBedrooms > 4 then
        return false, "Too many bedrooms. Make ticket to claim."
    end

    local size = def:getW() * def:getH()
    if size > 400 then
        return false, "Too big. Make ticket to claim."
    end

    return true, nil
end

-- Utility: find any building intersecting the given 2D area (z=0 slice)
function WSZ_Client.findAnyBuildingInArea(x1, y1, x2, y2)
    local cell = getCell()
    if not cell then return nil end
    local bx1 = math.min(x1, x2)
    local by1 = math.min(y1, y2)
    local bx2 = math.max(x1, x2)
    local by2 = math.max(y1, y2)
    for x = bx1, bx2 do
        for y = by1, by2 do
            local sq = cell:getGridSquare(x, y, 0)
            if sq then
                local b = sq:getBuilding()
                if b then return b end
            end
        end
    end
    return nil
end

-- Library: ownership helpers

-- Returns a normalized list of zones owned by username (with x1<=x2, y1<=y2, z1<=z2)
function WSZ_Client.getOwnedZones(username)
    local owned = {}
    if not username or not WSZ_Client or not WSZ_Client.zones then return owned end
    for _, z in pairs(WSZ_Client.zones) do
        local m = z.members and z.members[username] or nil
        local role = m and (m.type or m.role)
        if role == "owner" then
            local x1, y1, z1 = z.x1, z.y1, z.z1
            local x2, y2, z2 = z.x2, z.y2, z.z2
            if x1 > x2 then x1, x2 = x2, x1 end
            if y1 > y2 then y1, y2 = y2, y1 end
            if z1 > z2 then z1, z2 = z2, z1 end
            table.insert(owned, { x1=x1, y1=y1, z1=z1, x2=x2, y2=y2, z2=z2, id=z.id, name=z.name })
        end
    end
    return owned
end

-- Returns total zones owned by username
function WSZ_Client.countOwnedZones(username)
    if not username or not WSZ_Client or not WSZ_Client.zones then return 0 end
    local count = 0
    for _, z in pairs(WSZ_Client.zones) do
        local m = z.members and z.members[username] or nil
        local role = m and (m.type or m.role)
        if role == "owner" then
            count = count + 1
        end
    end
    return count
end

-- Returns number of "root" (top-level) zones owned by username
-- A root zone is not entirely contained within any other zone the user owns
function WSZ_Client.countOwnedRootZones(username)
    local owned = WSZ_Client.getOwnedZones(username)
    local n = #owned
    if n == 0 then return 0 end

    local function contains(a, b)
        return (a.x1 <= b.x1 and a.y1 <= b.y1 and a.z1 <= b.z1) and
               (a.x2 >= b.x2 and a.y2 >= b.y2 and a.z2 >= b.z2)
    end

    local roots = 0
    for i = 1, n do
        local zi = owned[i]
        local contained = false
        for j = 1, n do
            if i ~= j then
                if contains(owned[j], zi) then
                    contained = true
                    break
                end
            end
        end
        if not contained then
            roots = roots + 1
        end
    end
    return roots
end

Events.OnPlayerMove.Add(WSZ_Client.onPlayerMoved)