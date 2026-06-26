WLSP_Client = WLSP_Client or {}

-- Internal spawner storage (only maintained for staff players)
WLSP_Client.spawners = WLSP_Client.spawners or {}
WLSP_Client.enabledStates = WLSP_Client.enabledStates or {}
WLSP_Client.isStaff = WLSP_Client.isStaff or false
WLSP_Client.initialized = WLSP_Client.initialized or false

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
function WLSP_Client:updateStaffStatus()
    local wasStaff = self.isStaff
    self.isStaff = checkStaffStatus()
    
    -- If just became staff, request full sync
    if not wasStaff and self.isStaff then
        self:requestFullSync()
    end
    
    -- If no longer staff, clear spawner list and enabled states
    if wasStaff and not self.isStaff then
        self.spawners = {}
        self.enabledStates = {}
    end
end

--- Request full sync (all spawners and enabled states) from server
function WLSP_Client:requestFullSync()
    if not self.isStaff then return end
    sendClientCommand(getPlayer(), "WLSP", "RequestFullSync", {})
end

--- Update entire spawner list and enabled states (full sync)
--- @param spawnerData table
--- @param enabledStatesData table
function WLSP_Client:updateFullSync(spawnerData, enabledStatesData)
    if not self.isStaff then return end
    
    self.spawners = spawnerData or {}
    self.enabledStates = enabledStatesData or {}
    print("[WLSP_Client] Full sync completed. Total spawners: " .. self:getSpawnerCount())
end

--- Add or update a single spawner
--- @param spawner WLSP_Spawner
function WLSP_Client:addSpawner(spawner)
    if not self.isStaff then return end
    if not spawner or not spawner.id then return end
    
    -- Replace existing spawner with same ID or add new
    local found = false
    for i, existingSpawner in ipairs(self.spawners) do
        if existingSpawner.id == spawner.id then
            self.spawners[i] = spawner
            found = true
            break
        end
    end
    
    if not found then
        table.insert(self.spawners, spawner)
        self.enabledStates[spawner.id] = false -- Default to disabled
    end
    
    print("[WLSP_Client] Added/updated spawner: " .. spawner.id)
end

--- Remove a spawner by ID
--- @param spawnerId string
function WLSP_Client:removeSpawner(spawnerId)
    if not self.isStaff then return end
    if not spawnerId then return end
    
    for i, spawner in ipairs(self.spawners) do
        if spawner.id == spawnerId then
            table.remove(self.spawners, i)
            print("[WLSP_Client] Removed spawner: " .. spawnerId)
            return
        end
    end
end

--- Get all spawners
--- @return WLSP_Spawner[]
function WLSP_Client:getAllSpawners()
    if not self.isStaff then return {} end
    return self.spawners
end

--- Get spawner by ID
--- @param spawnerId string
--- @return WLSP_Spawner|nil
function WLSP_Client:getSpawner(spawnerId)
    if not self.isStaff then return nil end
    
    for _, spawner in ipairs(self.spawners) do
        if spawner.id == spawnerId then
            return spawner
        end
    end
    
    return nil
end

--- Get spawner count
--- @return number
function WLSP_Client:getSpawnerCount()
    if not self.isStaff then return 0 end
    return #self.spawners
end

--- Toggle spawner enabled state (send command to server)
--- @param player IsoPlayer
--- @param spawnerId string
function WLSP_Client:toggleSpawner(player, spawnerId)
    if not self.isStaff then return end
    if not spawnerId then return end

    sendClientCommand(player, "WLSP", "ToggleSpawner", { spawnerId = spawnerId })
end

--- Toggle all spawners in a group (send command to server)
--- @param player IsoPlayer
--- @param groupName string
function WLSP_Client:toggleSpawnerGroup(player, groupName)
    if not self.isStaff then return end
    if not groupName then return end

    sendClientCommand(player, "WLSP", "ToggleSpawnerGroup", { groupName = groupName })
end

--- Update enabled state for a spawner (from server)
--- @param spawnerId string
--- @param enabled boolean
function WLSP_Client:updateSpawnerEnabled(spawnerId, enabled)
    if not self.isStaff then return end
    if not spawnerId then return end
    
    self.enabledStates[spawnerId] = enabled
    print("[WLSP_Client] Spawner " .. spawnerId .. " is now " .. (enabled and "enabled" or "disabled"))
end

--- Check if spawner is enabled
--- @param spawnerId string
--- @return boolean
function WLSP_Client:isSpawnerEnabled(spawnerId)
    if not self.isStaff then return true end
    -- Default to disabled if not set
    if self.enabledStates[spawnerId] == nil then
        return false
    end
    return self.enabledStates[spawnerId]
end

--- Clear all spawners
function WLSP_Client:clearSpawners()
    self.spawners = {}
    self.enabledStates = {}
    print("[WLSP_Client] Cleared all spawners")
end

-- Initialize on game start
if not WLSP_Client.initialized then
    WLSP_Client.initialized = true
    
    -- Check staff status periodically (in case player becomes staff)
    Events.OnTick.Add(function()
        if not WLSP_Client.checkTimer then
            WLSP_Client.checkTimer = 0
        end
        
        WLSP_Client.checkTimer = WLSP_Client.checkTimer + 1
        
        -- Check every 5 seconds (assuming 60 ticks per second)
        if WLSP_Client.checkTimer >= 300 then
            WLSP_Client.checkTimer = 0
            WLSP_Client:updateStaffStatus()
        end
    end)
    
    -- Initial staff check on player creation
    Events.OnCreatePlayer.Add(function()
        WLSP_Client:updateStaffStatus()
    end)
end