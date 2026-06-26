WLZA_Client = WLZA_Client or {}

-- Internal attractor storage (only maintained for staff players)
WLZA_Client.attractors = WLZA_Client.attractors or {}
WLZA_Client.enabledStates = WLZA_Client.enabledStates or {}
WLZA_Client.isStaff = WLZA_Client.isStaff or false
WLZA_Client.initialized = WLZA_Client.initialized or false

--- Check if local player is staff
--- @return boolean
local function checkStaffStatus()
    local player = getPlayer()
    if not player then return false end
    
    -- In singleplayer, always staff
    if not isClient() and not isServer() then return true end
    
    -- Check access level
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

--- Initialize or update staff status
function WLZA_Client:updateStaffStatus()
    local wasStaff = self.isStaff
    self.isStaff = checkStaffStatus()
    
    -- If just became staff, request full sync
    if not wasStaff and self.isStaff then
        self:requestFullSync()
    end
    
    -- If no longer staff, clear attractor list and enabled states
    if wasStaff and not self.isStaff then
        self.attractors = {}
        self.enabledStates = {}
    end
end

--- Request full sync (all attractors and enabled states) from server
function WLZA_Client:requestFullSync()
    if not self.isStaff then return end
    sendClientCommand(getPlayer(), "WLZA", "RequestFullSync", {})
end

--- Update entire attractor list and enabled states (full sync)
--- @param attractorData table
--- @param enabledStatesData table
function WLZA_Client:updateFullSync(attractorData, enabledStatesData)
    if not self.isStaff then return end
    
    self.attractors = attractorData or {}
    self.enabledStates = enabledStatesData or {}
    print("[WLZA_Client] Full sync completed. Total attractors: " .. self:getAttractorCount())
end

--- Add or update a single attractor
--- @param attractor WLZA_Attractor
function WLZA_Client:addAttractor(attractor)
    if not self.isStaff then return end
    if not attractor or not attractor.id then return end
    
    -- Replace existing attractor with same ID or add new
    local found = false
    for i, existingAttractor in ipairs(self.attractors) do
        if existingAttractor.id == attractor.id then
            self.attractors[i] = attractor
            found = true
            break
        end
    end
    
    if not found then
        table.insert(self.attractors, attractor)
        self.enabledStates[attractor.id] = false -- Default to disabled
    end
    
    print("[WLZA_Client] Added/updated attractor: " .. attractor.id)
end

--- Remove an attractor by ID
--- @param attractorId string
function WLZA_Client:removeAttractor(attractorId)
    if not self.isStaff then return end
    if not attractorId then return end
    
    for i, attractor in ipairs(self.attractors) do
        if attractor.id == attractorId then
            table.remove(self.attractors, i)
            print("[WLZA_Client] Removed attractor: " .. attractorId)
            return
        end
    end
end

--- Get all attractors
--- @return WLZA_Attractor[]
function WLZA_Client:getAllAttractors()
    if not self.isStaff then return {} end
    return self.attractors
end

--- Get attractor by ID
--- @param attractorId string
--- @return WLZA_Attractor|nil
function WLZA_Client:getAttractor(attractorId)
    if not self.isStaff then return nil end
    
    for _, attractor in ipairs(self.attractors) do
        if attractor.id == attractorId then
            return attractor
        end
    end
    
    return nil
end

--- Get attractor count
--- @return number
function WLZA_Client:getAttractorCount()
    if not self.isStaff then return 0 end
    return #self.attractors
end

--- Toggle attractor enabled state (send command to server)
--- @param player IsoPlayer
--- @param attractorId string
function WLZA_Client:toggleAttractor(player, attractorId)
    if not self.isStaff then return end
    if not attractorId then return end
    
    sendClientCommand(player, "WLZA", "ToggleAttractor", { attractorId = attractorId })
end

--- Update enabled state for an attractor (from server)
--- @param attractorId string
--- @param enabled boolean
function WLZA_Client:updateAttractorEnabled(attractorId, enabled)
    if not self.isStaff then return end
    if not attractorId then return end
    
    self.enabledStates[attractorId] = enabled
    print("[WLZA_Client] Attractor " .. attractorId .. " is now " .. (enabled and "enabled" or "disabled"))
end

--- Check if attractor is enabled
--- @param attractorId string
--- @return boolean
function WLZA_Client:isAttractorEnabled(attractorId)
    if not self.isStaff then return true end
    -- Default to disabled if not set
    if self.enabledStates[attractorId] == nil then
        return false
    end
    return self.enabledStates[attractorId]
end

--- Clear all attractors
function WLZA_Client:clearAttractors()
    self.attractors = {}
    self.enabledStates = {}
    print("[WLZA_Client] Cleared all attractors")
end

-- Initialize on game start
if not WLZA_Client.initialized then
    WLZA_Client.initialized = true
    
    -- Check staff status periodically (in case player becomes staff)
    Events.OnTick.Add(function()
        if not WLZA_Client.checkTimer then
            WLZA_Client.checkTimer = 0
        end
        
        WLZA_Client.checkTimer = WLZA_Client.checkTimer + 1
        
        -- Check every 5 seconds (assuming 60 ticks per second)
        if WLZA_Client.checkTimer >= 300 then
            WLZA_Client.checkTimer = 0
            WLZA_Client:updateStaffStatus()
        end
    end)
    
    -- Initial staff check on player creation
    Events.OnCreatePlayer.Add(function()
        WLZA_Client:updateStaffStatus()
    end)
end