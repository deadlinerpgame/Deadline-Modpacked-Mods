--- @class WSZ_System : WL_ClientServerBase
WSZ_System = WL_ClientServerBase:new("WSZ_System")
WSZ_System.needsPublicData = true
WSZ_System.needsPrivateData = false

WSZ_System.publicData = {
    --- @type table<string, WSZ_Zone>
    zones = {}
}

-- Client-side request tracking for async callbacks
WSZ_System.pendingRequests = {}
WSZ_System.requestIdCounter = 0

-- Spatial partitioning grid for performance optimization
WSZ_System.zoneGrid = {}
WSZ_System.gridSize = 100 -- Grid cell size in world units (tunable parameter)

--- Initializes mod data when the system starts up
--- Ensures publicData and zones table exist
function WSZ_System:onModDataInit()
    if not self.publicData then
        self.publicData = {}
    end
    if not self.publicData.zones then
        self.publicData.zones = {}
    end

    -- Ensure all zones are aligned to 0 grid
    for _, zone in pairs(self.publicData.zones) do
        zone.x1 = math.floor(zone.x1 or 0)
        zone.y1 = math.floor(zone.y1 or 0)
        zone.z1 = math.floor(zone.z1 or 0)
        zone.x2 = math.floor(zone.x2 or 0)
        zone.y2 = math.floor(zone.y2 or 0)
        zone.z2 = math.floor(zone.z2 or 0)
    end

    -- Initialize spatial grid
    self:rebuildZoneGrid()
end

--- Called when public data is updated from the server
--- Ensures data integrity and notifies client systems
function WSZ_System:onPublicDataUpdated()
    if not self.publicData then
        self.publicData = {}
    end
    if not self.publicData.zones then
        self.publicData.zones = {}
    end

    -- Rebuild spatial grid when data is updated
    self:rebuildZoneGrid()

    for _, zone in pairs(self.publicData.zones) do
        WSZ_Client.updateZone(zone)
    end
end

--- Client-side callback when a zone is updated
--- @param _ IsoPlayer The player receiving the update
--- @param zone WSZ_Zone The updated zone data
function WSZ_System:zoneUpdated(_, zone)
    if isServer() then
        self:logError("zoneUpdated should not be called on server")
        return
    end
    
    -- Rebuild spatial grid when zone is updated
    self:rebuildZoneGrid()
    
    WSZ_Client.updateZone(zone)
end

--- Client-side callback when a zone is deleted
--- @param _ IsoPlayer The player receiving the update
--- @param zoneId string The ID of the deleted zone
function WSZ_System:zoneDeleted(_, zoneId)
    if isServer() then
        self:logError("zoneDeleted should not be called on server")
        return
    end
    
    -- Rebuild spatial grid when zone is deleted
    self:rebuildZoneGrid()
    
    WSZ_Client.removeZone(zoneId)
end

--- Rebuilds the spatial partitioning grid for fast zone lookups
--- This should be called whenever zones are added, removed, or modified
function WSZ_System:rebuildZoneGrid()
    if not self.publicData or not self.publicData.zones then
        self.zoneGrid = {}
        return
    end
    
    self.zoneGrid = {}
    
    for _, zone in pairs(self.publicData.zones) do
        if zone.x1 and zone.y1 and zone.x2 and zone.y2 then
            -- Calculate which grid cells this zone overlaps (2D only since z is limited to 8 levels)
            local startX = math.floor(zone.x1 / self.gridSize)
            local endX = math.floor(zone.x2 / self.gridSize)
            local startY = math.floor(zone.y1 / self.gridSize)
            local endY = math.floor(zone.y2 / self.gridSize)
            
            -- Add zone to all overlapping grid cells
            for gx = startX, endX do
                for gy = startY, endY do
                    local key = gx .. "_" .. gy
                    if not self.zoneGrid[key] then
                        self.zoneGrid[key] = {}
                    end
                    table.insert(self.zoneGrid[key], zone)
                end
            end
        end
    end
end

function WSZ_System:isSafezoneAt(x, y, z)
    if not self.publicData or not self.publicData.zones then
        return false
    end
    
    x = math.floor(x or 0)
    y = math.floor(y or 0)
    z = math.floor(z or 0)

    -- Use spatial grid for fast lookup if available
    if self.zoneGrid then
        local gx = math.floor(x / self.gridSize)
        local gy = math.floor(y / self.gridSize)
        local key = gx .. "_" .. gy
        
        local potentialZones = self.zoneGrid[key]
        if not potentialZones then
            return false
        end
        
        -- Check only zones in this grid cell
        for _, zone in ipairs(potentialZones) do
            if zone.x1 and zone.y1 and zone.z1 and zone.x2 and zone.y2 and zone.z2 then
                if x >= zone.x1 and x <= zone.x2 and
                   y >= zone.y1 and y <= zone.y2 and
                   z >= zone.z1 and z <= zone.z2 then
                    return true
                end
            end
        end
        
        return false
    end

    -- Fallback to linear search if grid is not available
    for _, zone in pairs(self.publicData.zones) do
        if zone.x1 and zone.y1 and zone.z1 and zone.x2 and zone.y2 and zone.z2 then
            if x >= zone.x1 and x <= zone.x2 and
               y >= zone.y1 and y <= zone.y2 and
               z >= zone.z1 and z <= zone.z2 then
                return true
            end
        end
    end

    return false
end

--- Creates a new safezone with the specified parameters
--- @param player IsoPlayer The player creating the zone
--- @param name string The name of the zone
--- @param bounds table Flattened bounds with keys x1,y1,z1,x2,y2,z2
function WSZ_System:createZone(player, name, bounds)
    if isClient() then
        self:sendToServer(player, "createZone", name, bounds)
        return
    end

    -- Normalize bounds on server for safety
    local x1 = math.floor(math.min(bounds.x1, bounds.x2))
    local y1 = math.floor(math.min(bounds.y1, bounds.y2))
    local z1 = math.floor(math.min(bounds.z1, bounds.z2))
    local x2 = math.floor(math.max(bounds.x1, bounds.x2))
    local y2 = math.floor(math.max(bounds.y1, bounds.y2))
    local z2 = math.floor(math.max(bounds.z1, bounds.z2))

    local zone = {
        id = getRandomUUID(),
        name = name,
        -- Store flattened bounds directly on the zone object to match WSZ_Client.updateZone expectations
        x1 = x1, y1 = y1, z1 = z1,
        x2 = x2, y2 = y2, z2 = z2,
        members = {
            [player:getUsername()] = {
                username = player:getUsername(),
                type = "owner",
                addedBy = player:getUsername(),
                addedAt = getTimestamp(),
                lastVisitedAt = getTimestamp(),
                expiration = nil -- no expiration for owner
            }
        },
        createdBy = player:getUsername(),
        createdAt = getTimestamp(),
        lastVisitedAt = getTimestamp()
    }

    self.publicData.zones[zone.id] = zone

    -- Rebuild spatial grid after adding new zone
    self:rebuildZoneGrid()

    -- Log zone creation
    self:logInfo("Zone created: '" .. name .. "' (ID: " .. zone.id .. ") by " .. player:getUsername() .. " at bounds (" .. x1 .. "," .. y1 .. "," .. z1 .. ") to (" .. x2 .. "," .. y2 .. "," .. z2 .. ")")

    -- save but do not send full public data to clients
    self:savePublicData(false)

    -- send just the new zone to clients
    self:sendZoneToClients(zone.id)
    self:openZoneForManage(player, zone)
end

function WSZ_System:openZoneForManage(player, zone)
    if isServer() then
        self:sendToClient(player, "openZoneForManage", zone)
        return
    end
    WSZ_ManageSafezone:show(player, zone)
end

--- Deletes an existing safezone
--- @param player IsoPlayer The player deleting the zone
--- @param zoneId string The ID of the zone to delete
function WSZ_System:deleteZone(player, zoneId)
    if isClient() then
        self:sendToServer(player, "deleteZone", zoneId)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("deleteZone: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    -- Log zone deletion
    self:logInfo("Zone deleted: '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") by " .. player:getUsername())

    -- Remove the zone from public data
    self.publicData.zones[zoneId] = nil

    -- Rebuild spatial grid after removing zone
    self:rebuildZoneGrid()

    -- save but do not send full public data to clients
    self:savePublicData(false)

    -- notify clients about the deletion
    self:sendToAllClients("zoneDeleted", zoneId)
end

--- Sends zone data to all connected clients
--- @param zoneId string The ID of the zone to send
function WSZ_System:sendZoneToClients(zoneId)
    if isClient() then
        self:logError("sendZoneToClients should not be called on client")
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("sendZoneToClients: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    self:sendToAllClients("zoneUpdated", zone)
end

local function _normalizeZoneBounds(zone)
    local x1 = math.floor(zone.x1 or 0)
    local y1 = math.floor(zone.y1 or 0)
    local z1 = math.floor(zone.z1 or 0)
    local x2 = math.floor(zone.x2 or 0)
    local y2 = math.floor(zone.y2 or 0)
    local z2 = math.floor(zone.z2 or 0)

    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    if z1 > z2 then z1, z2 = z2, z1 end

    return {
        x1 = x1, y1 = y1, z1 = z1,
        x2 = x2, y2 = y2, z2 = z2,
    }
end

local function _zoneContains(a, b)
    return (a.x1 <= b.x1 and a.y1 <= b.y1 and a.z1 <= b.z1) and
           (a.x2 >= b.x2 and a.y2 >= b.y2 and a.z2 >= b.z2)
end

function WSZ_System:getMaxPlayerRootSafezones()
    return (SandboxVars and SandboxVars.WastelandSafezone and SandboxVars.WastelandSafezone.MaxPlayerSafezones) or 1
end

function WSZ_System:isRootZoneForUser(zone, username, assumedOwnerZoneId)
    if not zone or not username then
        return false
    end

    local member = zone.members and zone.members[username] or nil
    local isAssumedOwner = assumedOwnerZoneId ~= nil and zone.id == assumedOwnerZoneId
    if not isAssumedOwner and (not member or member.type ~= "owner") then
        return false
    end

    local targetBounds = _normalizeZoneBounds(zone)
    for _, otherZone in pairs(self.publicData.zones or {}) do
        if otherZone.id ~= zone.id then
            local otherMember = otherZone.members and otherZone.members[username] or nil
            local otherIsOwner = (otherMember and otherMember.type == "owner") or (assumedOwnerZoneId ~= nil and otherZone.id == assumedOwnerZoneId)
            if otherIsOwner then
                local otherBounds = _normalizeZoneBounds(otherZone)
                if _zoneContains(otherBounds, targetBounds) then
                    return false
                end
            end
        end
    end

    return true
end

function WSZ_System:countOwnedRootZones(username, assumedOwnerZoneId)
    if not username then
        return 0
    end

    local count = 0
    for _, zone in pairs(self.publicData.zones or {}) do
        if self:isRootZoneForUser(zone, username, assumedOwnerZoneId) then
            count = count + 1
        end
    end

    return count
end

function WSZ_System:canUserOwnZone(username, zoneId)
    if not username then
        return false
    end

    local zone = self.publicData.zones and self.publicData.zones[zoneId] or nil
    if not zone then
        return false
    end

    if not self:isRootZoneForUser(zone, username, zoneId) then
        return true
    end

    local rootCount = self:countOwnedRootZones(username, zoneId)
    local maxRoots = self:getMaxPlayerRootSafezones()
    return rootCount <= maxRoots
end

function WSZ_System:getEligibleOwnerSuccessor(zone, departingUsername)
    if not zone or not zone.members then
        return nil
    end

    local bestMember = nil
    for username, member in pairs(zone.members) do
        if username ~= departingUsername and member and member.type == "officer" and self:canUserOwnZone(username, zone.id) then
            if not bestMember then
                bestMember = member
            else
                local bestAddedAt = bestMember.addedAt or 0
                local memberAddedAt = member.addedAt or 0
                if memberAddedAt < bestAddedAt or (memberAddedAt == bestAddedAt and string.lower(username) < string.lower(bestMember.username or "")) then
                    bestMember = member
                end
            end
        end
    end

    return bestMember
end

-- Member management functions
--- Adds a new member to a safezone
--- @param player IsoPlayer The player adding the member
--- @param zoneId string The ID of the zone to add the member to
--- @param memberObject WSZ_Member The member data to add
function WSZ_System:addMember(player, zoneId, memberObject)
    if isClient() then
        self:sendToServer(player, "addMember", zoneId, memberObject)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("addMember: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    -- Check if member already exists
    if zone.members[memberObject.username] then
        self:logError("addMember: Member " .. memberObject.username .. " already exists in zone " .. zoneId)
        return
    end

    -- Add timestamp if not provided
    if not memberObject.addedAt then
        memberObject.addedAt = getTimestamp()
    end
    if not memberObject.lastVisitedAt then
        memberObject.lastVisitedAt = getTimestamp()
    end

    zone.members[memberObject.username] = memberObject

    -- Log member addition
    self:logInfo("Member added: " .. memberObject.username .. " (" .. (memberObject.type or "member") .. ") to zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") by " .. (memberObject.addedBy or "Unknown"))

    -- Save data
    self:savePublicData(false)

    -- Notify clients
    self:sendToAllClients("onMemberUpdated", zoneId, memberObject)
end

--- Modifies an existing member in a safezone
--- @param player IsoPlayer The player modifying the member
--- @param zoneId string The ID of the zone containing the member
--- @param memberObject WSZ_Member The updated member data
function WSZ_System:modifyMember(player, zoneId, memberObject)
    if isClient() then
        self:sendToServer(player, "modifyMember", zoneId, memberObject)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("modifyMember: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    -- Check if member exists and update
    if not zone.members[memberObject.username] then
        self:logError("modifyMember: Member " .. memberObject.username .. " not found in zone " .. zoneId)
        return
    end

    local oldMember = zone.members[memberObject.username]
    zone.members[memberObject.username] = memberObject

    -- Log member modification (promotion/demotion)
    if oldMember and oldMember.type ~= memberObject.type then
        self:logInfo("Member " .. (oldMember.type == "member" and "promoted" or "demoted") .. ": " .. memberObject.username .. " from " .. (oldMember.type or "member") .. " to " .. (memberObject.type or "member") .. " in zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") by " .. player:getUsername())
    else
        self:logInfo("Member modified: " .. memberObject.username .. " in zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") by " .. player:getUsername())
    end

    -- Save data
    self:savePublicData(false)

    -- Notify clients
    self:sendToAllClients("onMemberUpdated", zoneId, memberObject)
end

--- Removes a member from a safezone
--- @param player IsoPlayer The player removing the member
--- @param zoneId string The ID of the zone to remove the member from
--- @param username string The username of the member to remove
function WSZ_System:removeMember(player, zoneId, username)
    if isClient() then
        self:sendToServer(player, "removeMember", zoneId, username)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("removeMember: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    -- Check if member exists and remove
    if not zone.members[username] then
        self:logError("removeMember: Member " .. username .. " not found in zone " .. zoneId)
        return
    end

    local removedMember = zone.members[username]

    if removedMember and removedMember.type == "owner" then
        local successor = self:getEligibleOwnerSuccessor(zone, username)
        zone.members[username] = nil

        if not successor then
            self:logInfo("Owner left with no eligible successor; deleting zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") after " .. username .. " left")
            self.publicData.zones[zoneId] = nil
            self:rebuildZoneGrid()
            self:savePublicData(false)
            self:sendToAllClients("zoneDeleted", zoneId)
            return
        end

        successor.type = "owner"
        successor.expiration = nil

        self:logInfo("Owner transferred by leave: " .. username .. " left zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. "), ownership reassigned to " .. successor.username)
        self:savePublicData(false)
        self:sendZoneToClients(zoneId)
        return
    end

    zone.members[username] = nil

    -- Log member removal
    self:logInfo("Member removed: " .. username .. " (" .. (removedMember and removedMember.type or "member") .. ") from zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ") by " .. player:getUsername())

    -- Save data
    self:savePublicData(false)

    -- Notify clients
    self:sendToAllClients("onMemberRemoved", zoneId, username)
end

--- Records when a player visits a safezone
--- @param player IsoPlayer The player visiting the zone
--- @param zoneId string The ID of the zone being visited
function WSZ_System:playerVisited(player, zoneId)
    if isClient() then
        self:sendToServer(player, "playerVisited", zoneId)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("playerVisited: Zone with ID " .. zoneId .. " does not exist")
        return
    end

    local username = player:getUsername()
    local currentTime = getTimestamp()

    -- Update zone's last visited time if they are a member
    -- Update member's last visited time if they are a member
    if zone.members[username] then
        zone.members[username].lastVisitedAt = currentTime
        zone.lastVisitedAt = currentTime
    end
        
    -- Log zone visit
    self:logInfo("Zone visited: " .. username .. " visited zone '" .. (zone.name or "Unknown") .. "' (ID: " .. zoneId .. ")")

    -- Save data (lightweight update, no client notification needed)
    self:savePublicData(false)
end

-- Client-only callback functions
--- Client-side callback when a member is updated or added
--- @param player IsoPlayer The player receiving the update
--- @param zoneId string The ID of the zone containing the member
--- @param memberObject WSZ_Member The updated member data
function WSZ_System:onMemberUpdated(player, zoneId, memberObject)
    if isServer() then
        self:logError("onMemberUpdated should not be called on server")
        return
    end
    
    -- Update local zone data
    local zone = self.publicData.zones[zoneId]
    if zone then
        -- Update or add the member in local data
        zone.members[memberObject.username] = memberObject
    end
    
    -- Notify client-side systems
    WSZ_Client.onMemberUpdated(zoneId, memberObject)
end

--- Client-side callback when a member is removed from a zone
--- @param player IsoPlayer The player receiving the update
--- @param zoneId string The ID of the zone the member was removed from
--- @param username string The username of the removed member
function WSZ_System:onMemberRemoved(player, zoneId, username)
    if isServer() then
        self:logError("onMemberRemoved should not be called on server")
        return
    end
    
    -- Update local zone data
    local zone = self.publicData.zones[zoneId]
    if zone then
        zone.members[username] = nil
    end
    
    -- Notify client-side systems
    WSZ_Client.onMemberRemoved(zoneId, username)
end

--- Asynchronously requests an updated version of a safezone from the server
--- @param player IsoPlayer The player making the request
--- @param zoneId string The ID of the zone to request
--- @param callback fun(zoneData: WSZ_Zone|nil, errorMessage: string|nil) The callback function to execute when data is received
function WSZ_System:getSafezoneAsync(player, zoneId, callback)
    if isServer() then
        self:logError("getSafezoneAsync should not be called on server")
        return
    end
    
    if not player or not zoneId or not callback then
        self:logError("getSafezoneAsync: player, zoneId and callback are required")
        return
    end
    
    -- Generate unique request ID
    self.requestIdCounter = self.requestIdCounter + 1
    local requestId = "safezone_request_" .. self.requestIdCounter
    
    -- Store the callback for when response arrives
    self.pendingRequests[requestId] = {
        callback = callback,
        zoneId = zoneId,
        timestamp = getTimestamp()
    }
    
    -- Send request to server
    self:sendToServer(player, "requestSafezone", zoneId, requestId)
end

--- Server-side handler for safezone requests
--- @param player IsoPlayer The player requesting the zone
--- @param zoneId string The ID of the zone being requested
--- @param requestId string The unique request identifier
function WSZ_System:requestSafezone(player, zoneId, requestId)
    if isClient() then
        self:logError("requestSafezone should not be called on client")
        return
    end
    
    local zone = self.publicData.zones[zoneId]
    if not zone then
        -- Send error response
        self:sendToClient(player, "safezoneRequestResponse", requestId, nil, "Zone not found")
        return
    end
    
    -- Send the zone data back to the requesting client
    self:sendToClient(player, "safezoneRequestResponse", requestId, zone, nil)
end

--- Client-side callback when safezone response is received
--- @param player IsoPlayer The player receiving the response
--- @param requestId string The unique request identifier
--- @param zoneData WSZ_Zone|nil The zone data (nil if error)
--- @param errorMessage string|nil Error message if request failed
function WSZ_System:safezoneRequestResponse(player, requestId, zoneData, errorMessage)
    if isServer() then
        self:logError("safezoneRequestResponse should not be called on server")
        return
    end
    
    local request = self.pendingRequests[requestId]
    if not request then
        self:logError("safezoneRequestResponse: No pending request found for ID " .. requestId)
        return
    end
    
    -- Remove the request from pending list
    self.pendingRequests[requestId] = nil
    
    -- Execute the callback
    if errorMessage then
        -- Call callback with nil to indicate error
        request.callback(nil, errorMessage)
    else
        -- Update local zone data if we have it
        if zoneData and self.publicData.zones[zoneData.id] then
            self.publicData.zones[zoneData.id] = zoneData
        end
        
        -- Call callback with the zone data
        request.callback(zoneData)
    end
end

--- Cleanup old pending requests (should be called periodically)
function WSZ_System:cleanupPendingRequests()
    if isServer() then
        return
    end
    
    local currentTime = getTimestamp()
    local timeout = 30000 -- 30 seconds timeout
    
    for requestId, request in pairs(self.pendingRequests) do
        if currentTime - request.timestamp > timeout then
            -- Timeout the request
            request.callback(nil, "Request timeout")
            self.pendingRequests[requestId] = nil
        end
    end
end

-- Membership request workflow
-- Server-side tracking for pending membership requests
WSZ_System.pendingMembershipRequests = WSZ_System.pendingMembershipRequests or {}

--- Client+Server: player requests membership in a zone
--- On client: forwards to server
--- On server: finds closest online manager and prompts them
--- @param player IsoPlayer
--- @param zoneId string
function WSZ_System:requestMembership(player, zoneId)
    if isClient() then
        self:sendToServer(player, "requestMembership", zoneId)
        return
    end

    -- Server handler starts here
    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:sendToClient(player, "membershipRequestNotice", "error", "Zone not found.")
        return
    end

    -- Build set of candidate usernames (owner + officers)
    local candidates = {}
    for uname, m in pairs(zone.members or {}) do
        if m and (m.type == "owner" or m.type == "officer") then
            candidates[uname] = true
        end
    end

    -- Gather online managers and pick closest to requester
    local online = getOnlinePlayers() or {}
    local requesterX, requesterY = player:getX(), player:getY()
    local closestManager = nil
    local closestDist2 = math.huge

    for i = 0, online:size() - 1 do
        local p = online:get(i)
        if p and candidates[p:getUsername()] then
            local dx = (p:getX() - requesterX)
            local dy = (p:getY() - requesterY)
            local d2 = dx * dx + dy * dy
            if d2 < closestDist2 then
                closestDist2 = d2
                closestManager = p
            end
        end
    end

    if not closestManager then
        self:sendToClient(player, "membershipRequestNotice", "no_managers_online", "No zone managers are currently online.")
        return
    end

    -- Create pending request
    local requestId = getRandomUUID()
    self.pendingMembershipRequests[requestId] = {
        id = requestId,
        zoneId = zoneId,
        zoneName = zone.name or "Safezone",
        requester = player:getUsername(),
        manager = closestManager:getUsername(),
        timestamp = getTimestamp()
    }

    -- Log membership request
    self:logInfo("Membership request: " .. player:getUsername() .. " requested membership in zone '" .. (zone.name or "Safezone") .. "' (ID: " .. zoneId .. "), assigned to manager " .. closestManager:getUsername())

    -- Notify requester that request was sent
    self:sendToClient(player, "membershipRequestNotice", "sent", "Membership request sent to " .. tostring(closestManager:getUsername()) .. ".")

    -- Prompt manager
    self:sendToClient(closestManager, "membershipRequestPrompt", requestId, zoneId, zone.name or "Safezone", player:getUsername())
end


--- Client: manager receives prompt to accept/reject/accept timed
--- @param _ IsoPlayer
--- @param requestId string
--- @param zoneId string
--- @param zoneName string
--- @param requesterUsername string
function WSZ_System:membershipRequestPrompt(_, requestId, zoneId, zoneName, requesterUsername)
    WSZ_Modals.membershipRequestPrompt(_, requestId, zoneId, zoneName, requesterUsername)
end

--- Server: manager decision received
--- @param player IsoPlayer -- manager
--- @param requestId string
--- @param decision "reject"|"accept"|"accept_timed"
--- @param minutes number
function WSZ_System:membershipRequestDecision(player, requestId, decision, minutes)
    if isClient() then
        self:logError("membershipRequestDecision should not be called on client")
        return
    end

    local req = self.pendingMembershipRequests[requestId]
    if not req then
        self:sendToClient(player, "membershipRequestNotice", "error", "Request not found or timed out.")
        return
    end

    -- Ensure this manager is the assigned one
    if req.manager ~= player:getUsername() then
        self:sendToClient(player, "membershipRequestNotice", "error", "You are not assigned to this request.")
        return
    end

    local zone = self.publicData.zones[req.zoneId]
    if not zone then
        self:sendToClient(player, "membershipRequestNotice", "error", "Zone not found.")
        self.pendingMembershipRequests[requestId] = nil
        return
    end

    -- Find requester online (for feedback); requester might be offline by now
    local requesterPlayer = nil
    local online = getOnlinePlayers() or {}
    for i = 0, online:size() - 1 do
        local p = online:get(i)
        if p and p:getUsername() == req.requester then
            requesterPlayer = p
            break
        end
    end

    local nowTs = getTimestamp()
    if decision == "reject" then
        -- Log membership request rejection
        self:logInfo("Membership request rejected: " .. player:getUsername() .. " rejected " .. req.requester .. "'s request for zone '" .. req.zoneName .. "' (ID: " .. req.zoneId .. ")")
        
        if requesterPlayer then
            self:sendToClient(requesterPlayer, "membershipRequestResult", "rejected", req.zoneId, req.zoneName, player:getUsername(), 0)
        end
        self:sendToClient(player, "membershipRequestNotice", "handled", "Rejected membership request from " .. req.requester .. ".")
        self.pendingMembershipRequests[requestId] = nil
        return
    end

    if decision == "accept" or decision == "accept_timed" then
        -- Add member if not present
        zone.members = zone.members or {}
        local member = zone.members[req.requester]
        local expiration = nil
        if decision == "accept_timed" and type(minutes) == "number" and minutes > 0 then
            -- getTimestamp() returns seconds, so convert minutes to seconds
            expiration = nowTs + (minutes * 60)
        end

        if member then
            -- Update expiration only if accept_timed provided, else leave as-is
            if expiration ~= nil then
                member.expiration = expiration
            else
                member.expiration = nil
            end
        else
            member = {
                username = req.requester,
                type = "member",
                addedBy = player:getUsername(),
                addedAt = nowTs,
                lastVisitedAt = 0,
                expiration = expiration
            }
            zone.members[req.requester] = member
        end

        -- Log membership request approval
        if expiration then
            local minutesGranted = math.floor((expiration - nowTs) / 60)
            self:logInfo("Membership request approved (timed): " .. player:getUsername() .. " approved " .. req.requester .. "'s request for zone '" .. req.zoneName .. "' (ID: " .. req.zoneId .. ") for " .. minutesGranted .. " minutes")
        else
            self:logInfo("Membership request approved: " .. player:getUsername() .. " approved " .. req.requester .. "'s request for zone '" .. req.zoneName .. "' (ID: " .. req.zoneId .. ")")
        end

        -- Persist and notify clients
        self:savePublicData(false)
        self:sendToAllClients("onMemberUpdated", req.zoneId, member)

        -- Notify players
        if requesterPlayer then
            local result = (expiration and "accepted_timed") or "accepted"
            local minutesLeft = expiration and math.floor((expiration - nowTs) / 60000) or 0
            self:sendToClient(requesterPlayer, "membershipRequestResult", result, req.zoneId, req.zoneName, player:getUsername(), minutesLeft)
        end
        self:sendToClient(player, "membershipRequestNotice", "handled", "Accepted membership request for " .. req.requester .. ".")

        self.pendingMembershipRequests[requestId] = nil
        return
    end

    -- Unknown decision
    self:sendToClient(player, "membershipRequestNotice", "error", "Unknown decision.")
    self.pendingMembershipRequests[requestId] = nil
end

--- Client: general notices regarding membership requests (requester or manager)
--- @param _ IsoPlayer
--- @param status string
--- @param message string
function WSZ_System:membershipRequestNotice(_, status, message)
    WSZ_Modals.membershipRequestNotice(_, status, message)
end

--- Client: requester receives final result
--- @param _ IsoPlayer
--- @param result "accepted"|"accepted_timed"|"rejected"
--- @param zoneId string
--- @param zoneName string
--- @param managerUsername string
--- @param minutes number
function WSZ_System:membershipRequestResult(_, result, zoneId, zoneName, managerUsername, minutes)
    WSZ_Modals.membershipRequestResult(_, result, zoneId, zoneName, managerUsername, minutes)
end

--- Renames an existing safezone (owner+ on client; server enforces)
--- @param player IsoPlayer
--- @param zoneId string
--- @param newName string
function WSZ_System:renameZone(player, zoneId, newName)
    if isClient() then
        self:sendToServer(player, "renameZone", zoneId, newName)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("renameZone: Zone with ID " .. tostring(zoneId) .. " does not exist")
        return
    end

    if type(newName) ~= "string" or newName == "" then
        self:logError("renameZone: Invalid name")
        return
    end

    zone.name = newName

    -- Persist and notify clients
    self:savePublicData(false)
    self:sendZoneToClients(zoneId)
end

--- Modifies zone bounds (staff only)
--- @param player IsoPlayer
--- @param zoneId string
--- @param bounds table {x1,y1,z1,x2,y2,z2}
function WSZ_System:modifyZoneBounds(player, zoneId, bounds)
    if isClient() then
        self:sendToServer(player, "modifyZoneBounds", zoneId, bounds)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("modifyZoneBounds: Zone with ID " .. tostring(zoneId) .. " does not exist")
        return
    end

    if not bounds then
        self:logError("modifyZoneBounds: Missing bounds")
        return
    end

    local x1 = math.min(bounds.x1, bounds.x2)
    local y1 = math.min(bounds.y1, bounds.y2)
    local z1 = math.min(bounds.z1, bounds.z2)
    local x2 = math.max(bounds.x1, bounds.x2)
    local y2 = math.max(bounds.y1, bounds.y2)
    local z2 = math.max(bounds.z1, bounds.z2)

    zone.x1, zone.y1, zone.z1 = x1, y1, z1
    zone.x2, zone.y2, zone.z2 = x2, y2, z2

    -- Rebuild spatial grid after modifying zone bounds
    self:rebuildZoneGrid()

    -- Persist and notify clients
    self:savePublicData(false)
    self:sendZoneToClients(zoneId)
end

--- Reassigns the owner of a safezone (owner or staff on client; server enforces)
--- @param player IsoPlayer
--- @param zoneId string
--- @param newOwnerUsername string
function WSZ_System:reassignOwner(player, zoneId, newOwnerUsername)
    if isClient() then
        self:sendToServer(player, "reassignOwner", zoneId, newOwnerUsername)
        return
    end

    local zone = self.publicData.zones[zoneId]
    if not zone then
        self:logError("reassignOwner: Zone with ID " .. tostring(zoneId) .. " does not exist")
        return
    end

    if type(newOwnerUsername) ~= "string" or newOwnerUsername == "" then
        self:logError("reassignOwner: Invalid new owner username")
        return
    end

    local actorIsStaff = WL_Utils.isStaff(player)
    if not actorIsStaff and not self:canUserOwnZone(newOwnerUsername, zoneId) then
        self:logInfo("reassignOwner denied: " .. tostring(newOwnerUsername) .. " is already at the ownership limit for root safezones")
        return
    end

    zone.members = zone.members or {}

    -- Ensure target exists as a member (allow non-member to become owner)
    local target = zone.members[newOwnerUsername]
    local nowTs = getTimestamp()
    if not target then
        target = {
            username = newOwnerUsername,
            type = "member", -- will be promoted to owner below
            addedBy = player and player.getUsername and player:getUsername() or "system",
            addedAt = nowTs,
            lastVisitedAt = 0,
            expiration = nil
        }
        zone.members[newOwnerUsername] = target
    end

    -- No-op if already owner
    if target.type == "owner" then
        -- Still send zone to clients to ensure UI is synced
        self:sendZoneToClients(zoneId)
        return
    end

    -- Demote all current owners to officer, excluding the incoming user if present
    for uname, m in pairs(zone.members) do
        if m.type == "owner" and uname ~= newOwnerUsername then
            zone.members[uname] = {
                username = m.username,
                type = "officer",
                addedBy = m.addedBy,
                addedAt = m.addedAt,
                lastVisitedAt = m.lastVisitedAt,
                expiration = m.expiration
            }
        end
    end

    -- Promote target to owner, preserving their metadata where possible
    zone.members[newOwnerUsername] = {
        username = target.username,
        type = "owner",
        addedBy = target.addedBy,
        addedAt = target.addedAt,
        lastVisitedAt = target.lastVisitedAt,
        expiration = target.expiration
    }

    -- Persist and notify clients with full zone update to keep UI in sync
    self:savePublicData(false)
    self:sendZoneToClients(zoneId)
end

--- Cleanup expired members from all safezones
--- Removes members whose expiration timestamp has passed
function WSZ_System:cleanupExpiredMembers()
    if isClient() then
        return
    end
    
    local currentTime = getTimestamp()
    local membersRemoved = 0
    local zonesModified = {}
    
    for zoneId, zone in pairs(self.publicData.zones) do
        if zone.members then
            local membersToRemove = {}
            
            -- Find expired members (excluding owners who should never expire)
            for username, member in pairs(zone.members) do
                if member.expiration and member.type ~= "owner" and currentTime >= member.expiration then
                    table.insert(membersToRemove, username)
                end
            end
            
            -- Remove expired members
            for _, username in ipairs(membersToRemove) do
                zone.members[username] = nil
                membersRemoved = membersRemoved + 1
                zonesModified[zoneId] = true
                
                -- Notify clients about member removal
                self:sendToAllClients("onMemberRemoved", zoneId, username)
            end
        end
    end
    
    -- Save data if any changes were made
    if membersRemoved > 0 then
        self:savePublicData(false)
        self:logInfo("Cleaned up " .. membersRemoved .. " expired members from " .. #zonesModified .. " zones")
    end
end

--- Cleanup expired safezones based on ClaimExpirationHours setting
--- Removes zones where no one has visited within the configured time limit
function WSZ_System:cleanupExpiredSafezones()
    if isClient() then
        return
    end
    
    -- Get expiration hours from sandbox options (default 336 hours = 14 days)
    local expirationHours = SandboxVars.WastelandSafezone.ClaimExpirationHours or 336
    
    -- If expiration is set to 0, disable safehouse expiration
    if expirationHours <= 0 then
        return
    end
    
    local currentTime = getTimestamp()
    local expirationSeconds = expirationHours * 3600 -- Convert hours to seconds
    local zonesToRemove = {}
    
    for zoneId, zone in pairs(self.publicData.zones) do
        -- Check if zone has expired (no visits within expiration time)
        if zone.lastVisitedAt and (currentTime - zone.lastVisitedAt) >= expirationSeconds then
            table.insert(zonesToRemove, zoneId)
        end
    end
    
    -- Remove expired zones
    for _, zoneId in ipairs(zonesToRemove) do
        local zone = self.publicData.zones[zoneId]
        if zone then
            self.publicData.zones[zoneId] = nil
            
            -- Notify clients about zone deletion
            self:sendToAllClients("zoneDeleted", zoneId)
        end
    end
    
    -- Rebuild spatial grid if zones were removed
    if #zonesToRemove > 0 then
        self:rebuildZoneGrid()
        self:savePublicData(false)
        self:logInfo("Cleaned up " .. #zonesToRemove .. " expired safezones (no visits for " .. expirationHours .. " hours)")
    end
end

local function getShId(safehouse)
    return safehouse:getX() .. "," .. safehouse:getY() .. "," .. safehouse:getW() .. "," .. safehouse:getH()
end

--- Builds a WSZ_Zone table from a vanilla SafeHouse
--- @param safehouse SafeHouse
--- @param createdBy string
--- @return WSZ_Zone -- zone
function WSZ_System:buildZoneFromSafeHouse(safehouse, createdBy)
    local owner = safehouse:getOwner()
    local nowTs = getTimestamp()

    local x1 = safehouse:getX()
    local y1 = safehouse:getY()
    local x2 = safehouse:getX() + safehouse:getW()
    local y2 = safehouse:getY() + safehouse:getH()

    local zone = {
        id = getRandomUUID(),
        name = safehouse:getTitle() or (owner .. "'s Safehouse"),
        x1 = x1, y1 = y1, z1 = 0,
        x2 = x2, y2 = y2, z2 = 7, -- full height
        members = {
            [owner] = {
                username = owner,
                type = "owner",
                addedBy = owner,
                addedAt = nowTs,
                lastVisitedAt = nowTs,
                expiration = nil
            }
        },
        createdBy = createdBy,
        createdAt = nowTs,
        lastVisitedAt = nowTs
    }

    if zone.name == "Safehouse" then
        zone.name = owner .. "'s Safehouse"
    end

    local members = safehouse:getPlayers()
    if members then
        for i=0, members:size()-1 do
            local m = members:get(i)
            if m ~= owner then
                local level = "member"
                local shId = getShId(safehouse)
                if SafeHouseOfficerDb then
                    if SafeHouseOfficerDb[shId] and SafeHouseOfficerDb[shId][m] then
                        level = "officer"
                    end
                end
                zone.members[m] = {
                    username = m,
                    type = level,
                    addedBy = owner,
                    addedAt = nowTs,
                    lastVisitedAt = nowTs,
                    expiration = nil
                }
            end
        end
    end

    return zone
end
function WSZ_System:migrateOldSafehouse(player, x, y, w, h)
    if isClient() then
        self:sendToServer(player, "migrateOldSafehouse", x, y, w, h)
        return
    end

    local safehouse = SafeHouse.getSafeHouse(x, y, w, h)
    if not safehouse then
        self:logError("migrateOldSafehouse: No safehouse found at specified bounds")
        return
    end

    local zone = self:buildZoneFromSafeHouse(safehouse, player:getUsername())
    if not zone then
        return
    end

    self.publicData.zones[zone.id] = zone
    
    -- Rebuild spatial grid after adding migrated zone
    self:rebuildZoneGrid()
    
    self:logInfo("Migrated old safehouse '" .. (zone.name or "Unknown") .. "' to new safezone system with ID " .. zone.id)
    self:savePublicData(false)
    self:sendZoneToClients(zone.id)

    safehouse:removeSafeHouse(player, true)
end

-- Bulk migrate all existing SafeHouses into WSZ zones in one server pass
-- Creates all zones without per-zone syncing, then sends a single full public data update.
function WSZ_System:migrateAllSafehouses(player)
    if isClient() then
        self:sendToServer(player, "migrateAllSafehouses")
        return
    end

    local list = SafeHouse.getSafehouseList()
    local count = (list and list:size()) or 0
    if count == 0 then
        self:logInfo("migrateAllSafehouses: No safehouses to migrate")
        return
    end

    -- Ensure structures exist
    if not self.publicData then self.publicData = {} end
    if not self.publicData.zones then self.publicData.zones = {} end

    local migrated = 0
    local toRemove = {}

    for i = 0, count - 1 do
        local sh = list:get(i)
        if sh then
            local zone, _ = self:buildZoneFromSafeHouse(sh)
            if not zone then
                self:logError("migrateAllSafehouses: Failed to build zone from safehouse at index " .. i)
            else
                self:logInfo("migrateAllSafehouses: Migrating safehouse '" .. (zone.name or "Unknown") .. "' to new safezone system with ID " .. zone.id)
                self.publicData.zones[zone.id] = zone
                migrated = migrated + 1
                table.insert(toRemove, sh)
            end
        end
    end

    -- Rebuild spatial grid after bulk migration
    self:rebuildZoneGrid()

    -- Persist and broadcast full dataset once
    self:savePublicData(true)

    -- Remove the old safehouses after migration
    for _, sh in ipairs(toRemove) do
        sh:removeSafeHouse(player, true)
    end

    self:logInfo("migrateAllSafehouses: Migrated " .. tostring(migrated) .. " safehouses to safezones")
end

function WSZ_System.getSafehouseList()
    local function makeArrayList(items)
        local list = { _items = items or {} }
        function list:size() return #self._items end
        function list:get(i) return self._items[i + 1] end
        return list
    end

    local function makeSafeHouseLike(zone)
        local sh = { _zone = zone }

        function sh:getX() return math.floor(self._zone.x1 or 0) end
        function sh:getY() return math.floor(self._zone.y1 or 0) end
        function sh:getW() return math.floor((self._zone.x2 or 0) - (self._zone.x1 or 0)) end
        function sh:getH() return math.floor((self._zone.y2 or 0) - (self._zone.y1 or 0)) end
        function sh:getTitle() return tostring(self._zone.name or "Safehouse") end
        function sh:getId() return tostring(self._zone.id or "") end

        function sh:getOwner()
            local owner = nil
            local members = self._zone.members or {}
            for uname, m in pairs(members) do
                if m and m.type == "owner" then
                    owner = uname
                    break
                end
            end
            return tostring(owner or self._zone.createdBy or "unknown")
        end

        function sh:getPlayers()
            local names = {}
            local members = self._zone.members or {}
            for uname, _ in pairs(members) do
                names[#names + 1] = uname
            end
            return makeArrayList(names)
        end

        return sh
    end

    local zones = (WSZ_System.publicData and WSZ_System.publicData.zones) or {}
    local items = {}

    for _, zone in pairs(zones) do
        items[#items + 1] = makeSafeHouseLike(zone)
    end

    return makeArrayList(items)
end

if not isClient() then
    Events.EveryOneMinute.Add(function()
        WSZ_System:cleanupPendingRequests()
        WSZ_System:cleanupExpiredMembers()
        WSZ_System:cleanupExpiredSafezones()
    end)
end
