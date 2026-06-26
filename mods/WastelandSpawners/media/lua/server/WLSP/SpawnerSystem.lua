if isClient() then return end -- Server and Singleplayer only

WLSP_SpawnerSystem = WLSP_SpawnerSystem or {}

WLSP_SpawnerSystem.spawners = WLSP_SpawnerSystem.spawners or {}
WLSP_SpawnerSystem.lastTickTime = WLSP_SpawnerSystem.lastTickTime or 0
WLSP_SpawnerSystem.spawnTimers = WLSP_SpawnerSystem.spawnTimers or {}
WLSP_SpawnerSystem.lifespanTimers = WLSP_SpawnerSystem.lifespanTimers or {}
WLSP_SpawnerSystem.enabledStates = WLSP_SpawnerSystem.enabledStates or {}
WLSP_SpawnerSystem.triggerStates = WLSP_SpawnerSystem.triggerStates or {}
WLSP_SpawnerSystem.logLevel = WLSP_SpawnerSystem.logLevel or 0 -- 0=none, 1=normal, 2=verbose

-- Climate manager constants for accessing weather properties
local FLOAT_PRECIPITATION_INTENSITY = 3
local FLOAT_FOG_INTENSITY = 5
local BOOL_IS_SNOW = 0

--- Check if a player is staff
--- @param player IsoPlayer
--- @return boolean
local function isStaff(player)
    if not isServer() then return true end -- SP
    if not player then return false end -- Guard
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

--- Broadcast spawner update to all staff clients
--- @param command string
--- @param args table
local function broadcastToStaff(command, args)
    if not isServer() then return end -- Only broadcast in multiplayer
    
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if isStaff(player) then
            sendServerCommand(player, "WLSP", command, args)
        end
    end
end

--- Check if a time of day condition is met
--- @param condition WLSP_TimeOfDayCondition
--- @return boolean
local function checkTimeOfDayCondition(condition)
    if not condition.enabled then
        return true
    end

    local currentHour = getGameTime():getHour()
    local startHour = condition.startHour
    local endHour = condition.endHour
    
    -- Handle time ranges that wrap around midnight
    if startHour <= endHour then
        return currentHour >= startHour and currentHour < endHour
    else
        return currentHour >= startHour or currentHour < endHour
    end
end

--- Check if the spawner locations are loaded
--- @param spawner WLSP_Spawner
--- @return boolean
local function checkSpawnerLocations(spawner)
    local square = getCell():getGridSquare(
        math.floor(spawner.position.x),
        math.floor(spawner.position.y),
        math.floor(spawner.position.z)
    )
    if not square then
        return false
    end
    if spawner.targetLocation then
        local targetSquare = getCell():getGridSquare(
            math.floor(spawner.targetLocation.x),
            math.floor(spawner.targetLocation.y),
            math.floor(spawner.targetLocation.z)
        )
        if not targetSquare then
            return false
        end
    end
    return true
end

--- Check if a weather condition is met
--- @param condition WLSP_WeatherCondition
--- @return boolean
local function checkWeatherCondition(condition)
    if not condition.enabled then
        return true
    end
    
    local climate = getClimateManager()
    
    -- Check rain conditions
    if condition.rainMin or condition.rainMax then
        local rainIntensity = climate:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):getFinalValue()
        if condition.rainMin and rainIntensity < condition.rainMin then
            return false
        end
        if condition.rainMax and rainIntensity > condition.rainMax then
            return false
        end
    end
    
    -- Check snow conditions
    if condition.requireSnow or condition.prohibitSnow then
        local isSnowing = climate:getClimateBool(BOOL_IS_SNOW):getInternalValue()
        if condition.requireSnow and not isSnowing then
            return false
        end
        if condition.prohibitSnow and isSnowing then
            return false
        end
    end
    
    -- Check fog conditions
    if condition.fogMin or condition.fogMax then
        local fogIntensity = climate:getClimateFloat(FLOAT_FOG_INTENSITY):getFinalValue()
        if condition.fogMin and fogIntensity < condition.fogMin then
            return false
        end
        if condition.fogMax and fogIntensity > condition.fogMax then
            return false
        end
    end
    
    return true
end

--- Spawn zombies at the given position using Java's addZombiesInOutfit
--- @param x number
--- @param y number
--- @param z number
--- @param totalZombies number
--- @param outfit string|nil Optional outfit name
--- @return ArrayList<IsoZombie>
local function spawnZombies(x, y, z, totalZombies, outfit)
    -- Call Java method addZombiesInOutfit
    -- public static ArrayList<IsoZombie> addZombiesInOutfit(int x, int y, int z, int totalZombies, String outfit, Integer femaleChance)
    local zombies = addZombiesInOutfit(x, y, z, totalZombies, outfit, 50)
    if WLSP_SpawnerSystem.logLevel >= 1 then
        local outfitStr = outfit and (" with outfit '" .. outfit .. "'") or ""
        print("[WLSP] Spawned " .. totalZombies .. " zombie(s) at (" .. x .. ", " .. y .. ", " .. z .. ")" .. outfitStr)
    end
    return zombies
end

--- Check if a player count condition is met using pre-calculated count
--- @param condition WLSP_PlayerCountCondition
--- @param playerCount number|nil Pre-calculated player count (nil if not calculated)
--- @return boolean
local function checkPlayerCountCondition(condition, playerCount)
    if not condition.enabled then
        return true
    end
    
    if condition.checkType == "online" then
        local players = getOnlinePlayers()
        local nonStaffCount = 0
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if not isStaff(player) then
                nonStaffCount = nonStaffCount + 1
            end
        end
        return nonStaffCount >= condition.minCount
    elseif condition.checkType == "rangeSpawner" or condition.checkType == "rangeTarget" then
        if not condition.radius then
            return true
        end
        
        -- Use pre-calculated count
        local nearbyPlayers = playerCount or 0
        return nearbyPlayers >= condition.minCount
    end
    
    return true
end

--- Check if a zombie count condition is met using pre-calculated count
--- @param condition WLSP_ZombieCountCondition
--- @param zombieCount number|nil Pre-calculated zombie count (nil if not calculated)
--- @return boolean
local function checkZombieCountCondition(condition, zombieCount)
    if not condition.enabled then
        return true
    end
    
    -- Use pre-calculated count
    local currentZombieCount = zombieCount or 0
    
    return currentZombieCount < condition.maxCount
end

--- Calculate number of zombies to spawn based on count type using pre-calculated count
--- @param spawner WLSP_Spawner
--- @param playerCount number|nil Pre-calculated player count (nil if not calculated)
--- @return number
local function calculateSpawnCount(spawner, playerCount)
    if spawner.countType == "fixed" then
        return spawner.count
    elseif spawner.countType == "perPlayerInArea" then
        -- Use pre-calculated player count if available
        local nearbyPlayers = playerCount or 0
        
        -- If we don't have a pre-calculated count, return base count
        if playerCount == nil then
            return spawner.count
        end
        
        return spawner.count * nearbyPlayers
    elseif spawner.countType == "totalOnlinePlayers" then
        local players = getOnlinePlayers()
        local nonStaffCount = 0
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            if not isStaff(player) then
                nonStaffCount = nonStaffCount + 1
            end
        end
        return spawner.count * nonStaffCount
    end
    
    return spawner.count
end

--- Spawn zombies at a point
--- @param spawner WLSP_Spawner
--- @param count number
--- @return ArrayList<IsoZombie>
local function spawnAtPoint(spawner, count)
    if WLSP_SpawnerSystem.logLevel >= 2 then
        print("[WLSP] Spawning " .. count .. " zombie(s) at point (" .. spawner.position.x .. ", " .. spawner.position.y .. ", " .. spawner.position.z .. ")")
    end
    -- Spawn all zombies at once
    local zombies = spawnZombies(spawner.position.x, spawner.position.y, spawner.position.z, count, spawner.outfit)
    return zombies
end

--- Check if time trigger conditions are met
--- @param spawner WLSP_Spawner
--- @param trigger WLSP_TimeTrigger
--- @param triggerState table
--- @return boolean
local function checkTimeTrigger(spawner, trigger, triggerState)
    -- Validate trigger has times configured
    if not trigger.times or type(trigger.times) ~= "table" or #trigger.times == 0 then
        if WLSP_SpawnerSystem.logLevel >= 1 then
            print("[WLSP] WARNING: Time trigger for spawner " .. spawner.id .. " has invalid or empty times array")
        end
        return false
    end
    
    -- Get current game time
    local gameTime = getGameTime()
    local currentDay = gameTime:getNightsSurvived() + 1
    local currentHour = gameTime:getHour()
    local currentMinute = gameTime:getMinutes()
    
    -- Check each configured time (daily recurring)
    for _, timeSpec in ipairs(trigger.times) do
        -- Validate timeSpec structure
        if timeSpec and type(timeSpec) == "table" and #timeSpec >= 2 then
            local targetHour, targetMinute = timeSpec[1], timeSpec[2]
            
            if currentHour == targetHour and currentMinute == targetMinute then
                -- Check if we already triggered today
                local lastActivationDay = triggerState.lastActivationDay or 0
                if lastActivationDay < currentDay then
                    return true
                end
            end
        elseif WLSP_SpawnerSystem.logLevel >= 2 then
            print("[WLSP] WARNING: Skipping invalid timeSpec in trigger")
        end
    end
    
    return false
end

--- Check if area trigger conditions are met
--- @param spawner WLSP_Spawner
--- @param trigger WLSP_AreaTrigger
--- @param triggerState table
--- @return boolean
local function checkAreaTrigger(spawner, trigger, triggerState)
    -- Count non-staff players in radius
    local playerCount = 0
    local players = getOnlinePlayers()
    
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        -- Skip staff members
        if not isStaff(player) then
            local px, py = player:getX(), player:getY()
            local dx = px - trigger.position.x
            local dy = py - trigger.position.y
            local distSq = dx * dx + dy * dy
            local radiusSq = trigger.radius * trigger.radius
            
            if distSq <= radiusSq then
                playerCount = playerCount + 1
            end
        end
    end
    
    -- Activate if minimum players reached
    return playerCount >= trigger.minPlayers
end

--- Update trigger cooldown states
--- @param spawner WLSP_Spawner
--- @param deltaTime number
local function updateTriggerCooldowns(spawner, deltaTime)
    if not spawner.triggers then return end
    
    local states = WLSP_SpawnerSystem.triggerStates[spawner.id]
    if not states then
        states = {}
        WLSP_SpawnerSystem.triggerStates[spawner.id] = states
    end
    
    local currentTime = getGameTime():getWorldAgeHours() * 3600 -- in seconds
    
    for idx, trigger in ipairs(spawner.triggers) do
        local state = states[idx]
        if not state then
            state = {
                lastActivationTime = 0,
                onCooldown = false,
                cooldownEndsAt = 0,
                activationCount = 0,
                lastActivationDay = 0
            }
            states[idx] = state
        end
        
        -- Check if cooldown has expired
        if state.onCooldown and currentTime >= state.cooldownEndsAt then
            state.onCooldown = false
            if WLSP_SpawnerSystem.logLevel >= 1 then
                print("[WLSP] Trigger " .. idx .. " for spawner " .. spawner.id .. " cooldown expired")
            end
        end
    end
end

--- Update trigger state (cooldown, activation count, etc.)
--- @param spawner WLSP_Spawner
--- @param triggerIdx number
local function updateTriggerState(spawner, triggerIdx)
    local trigger = spawner.triggers[triggerIdx]
    local currentTime = getGameTime():getWorldAgeHours() * 3600
    local currentDay = getGameTime():getNightsSurvived() + 1
    
    -- Get or create trigger state
    local states = WLSP_SpawnerSystem.triggerStates[spawner.id]
    if not states then
        states = {}
        WLSP_SpawnerSystem.triggerStates[spawner.id] = states
    end
    
    local state = states[triggerIdx]
    if not state then
        state = {
            lastActivationTime = 0,
            onCooldown = false,
            cooldownEndsAt = 0,
            activationCount = 0,
            lastActivationDay = 0
        }
        states[triggerIdx] = state
    end
    
    -- Update state
    state.lastActivationTime = currentTime
    state.lastActivationDay = currentDay
    state.activationCount = state.activationCount + 1
    state.onCooldown = true
    state.cooldownEndsAt = currentTime + trigger.cooldown
end

--- Enable the spawner
--- @param spawner WLSP_Spawner
--- @param triggerInfo string|number Info about what triggered it (trigger index or "AND")
local function enableSpawner(spawner, triggerInfo)
    WLSP_SpawnerSystem.enabledStates[spawner.id] = true
    WLSP_SpawnerSystem.lifespanTimers[spawner.id] = 0
    -- Set to a very large value to trigger immediate spawn on next tick
    WLSP_SpawnerSystem.spawnTimers[spawner.id] = 999999
    
    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Trigger " .. tostring(triggerInfo) .. " activated spawner " .. spawner.id)
    end
    
    -- Broadcast state change
    broadcastToStaff("ToggleSpawner", {
        spawnerId = spawner.id,
        enabled = true,
        triggeredBy = triggerInfo
    })
end

--- Process triggers for all spawners
--- @param spawners table
--- @param deltaTime number
--- @return table List of triggered spawner IDs
local function processTriggers(spawners, deltaTime)
    local triggered = {}
    local currentTime = getGameTime():getWorldAgeHours() * 3600
    
    for _, spawner in ipairs(spawners) do
        -- Skip if spawner is already enabled
        if not WLSP_SpawnerSystem:isSpawnerEnabled(spawner.id) then
            -- Skip if no triggers configured
            if spawner.triggers and #spawner.triggers > 0 then
                -- Update cooldowns
                updateTriggerCooldowns(spawner, deltaTime)
                
                -- Check triggers based on mode
                local triggerMode = spawner.triggerMode or "OR"
                local states = WLSP_SpawnerSystem.triggerStates[spawner.id] or {}
                
                if triggerMode == "OR" then
                    -- Any trigger can activate
                    for idx, trigger in ipairs(spawner.triggers) do
                        if trigger.enabled then
                            local state = states[idx]
                            if not (state and state.onCooldown) then
                                local shouldActivate = false
                                if trigger.type == "time" then
                                    shouldActivate = checkTimeTrigger(spawner, trigger, state or {})
                                elseif trigger.type == "area" then
                                    shouldActivate = checkAreaTrigger(spawner, trigger, state or {})
                                end
                                
                                if shouldActivate then
                                    updateTriggerState(spawner, idx)
                                    enableSpawner(spawner, idx)
                                    table.insert(triggered, spawner.id)
                                    break -- Stop checking other triggers
                                end
                            end
                        end
                    end
                elseif triggerMode == "AND" then
                    -- All triggers must be satisfied
                    local allSatisfied = true
                    for idx, trigger in ipairs(spawner.triggers) do
                        if not trigger.enabled then
                            allSatisfied = false
                            break
                        end
                        
                        local state = states[idx]
                        if state and state.onCooldown then
                            allSatisfied = false
                            break
                        end
                        
                        local shouldActivate = false
                        if trigger.type == "time" then
                            shouldActivate = checkTimeTrigger(spawner, trigger, state or {})
                        elseif trigger.type == "area" then
                            shouldActivate = checkAreaTrigger(spawner, trigger, state or {})
                        end
                        
                        if not shouldActivate then
                            allSatisfied = false
                            break
                        end
                    end
                    
                    if allSatisfied then
                        -- Update all trigger states
                        for idx, _ in ipairs(spawner.triggers) do
                            updateTriggerState(spawner, idx)
                        end
                        -- Enable spawner once
                        enableSpawner(spawner, "AND")
                        table.insert(triggered, spawner.id)
                    end
                end
            end
        end
    end
    
    return triggered
end

--- Spawn zombies in a rectangular area (spread across the area)
--- @param spawner WLSP_Spawner
--- @param count number
--- @return ArrayList<IsoZombie>
local function spawnInArea(spawner, count)
    if not spawner.area then
        -- Fall back to point spawn if no area defined
        return spawnAtPoint(spawner, count)
    end
    
    -- Use addZombiesInOutfitArea to spread zombies across the rectangular area
    -- Position is now at center, so calculate corners
    local halfX = spawner.area.x / 2
    local halfY = spawner.area.y / 2
    local x1 = math.floor(spawner.position.x - halfX)
    local y1 = math.floor(spawner.position.y - halfY)
    local x2 = math.floor(spawner.position.x + halfX)
    local y2 = math.floor(spawner.position.y + halfY)
    local z = math.floor(spawner.position.z)
    
    local zombies = addZombiesInOutfitArea(x1, y1, x2, y2, z, count, spawner.outfit, 50)
    
    if WLSP_SpawnerSystem.logLevel >= 2 then
        local outfitStr = spawner.outfit and (" with outfit '" .. spawner.outfit .. "'") or ""
        print("[WLSP] Spawned " .. count .. " zombie(s) in area (" .. x1 .. ", " .. y1 .. ") to (" .. x2 .. ", " .. y2 .. ") at z=" .. z .. outfitStr)
    end
    
    return zombies
end

--- Spawn zombies randomly within a circular radius (spread out)
--- @param spawner WLSP_Spawner
--- @param count number
--- @return ArrayList<IsoZombie>
local function spawnInRadius(spawner, count)
    local radius = spawner.spawnRadius or 10 -- Default radius if not specified
    local allZombies = ArrayList.new(count)
    
    -- Spawn zombies one at a time at random points WITHIN the circle
    -- Use square root for uniform distribution
    for i = 1, count do
        local angle = ZombRandFloat(0, 1) * 2 * 3.141592
        local distance = math.sqrt(ZombRandFloat(0, 1)) * radius
        local spawnX = spawner.position.x + distance * math.cos(angle)
        local spawnY = spawner.position.y + distance * math.sin(angle)
        
        local zombies = spawnZombies(spawnX, spawnY, spawner.position.z, 1, spawner.outfit)
        if zombies and zombies:size() > 0 then
            local zombie = zombies:get(0)
            if zombie then
                allZombies:add(zombie)
            end
        end
    end

    if WLSP_SpawnerSystem.logLevel >= 2 then
        local outfitStr = spawner.outfit and (" with outfit '" .. spawner.outfit .. "'") or ""
        print("[WLSP] Spawned " .. count .. " zombie(s) in radius " .. radius .. " around (" .. spawner.position.x .. ", " .. spawner.position.y .. ", " .. spawner.position.z .. ")" .. outfitStr)
    end
    
    return allZombies
end

--- Spawn zombies on the perimeter of a circle (ring, spread out)
--- @param spawner WLSP_Spawner
--- @param count number
--- @return ArrayList<IsoZombie>
local function spawnInRing(spawner, count)
    local radius = spawner.spawnRadius or 10 -- Default radius if not specified
    local allZombies = ArrayList.new(count)
    
    -- Spawn zombies one at a time at random points on circle perimeter
    for i = 1, count do
        local angle = ZombRandFloat(0, 1) * 2 * 3.141592
        local spawnX = spawner.position.x + radius * math.cos(angle)
        local spawnY = spawner.position.y + radius * math.sin(angle)
        
        local zombies = spawnZombies(spawnX, spawnY, spawner.position.z, 1, spawner.outfit)
        if zombies and zombies:size() > 0 then
            local zombie = zombies:get(0)
            if zombie then
                allZombies:add(zombie)
            end
        end
    end

    if WLSP_SpawnerSystem.logLevel >= 2 then
        local outfitStr = spawner.outfit and (" with outfit '" .. spawner.outfit .. "'") or ""
        print("[WLSP] Spawned " .. count .. " zombie(s) in ring at radius " .. radius .. " around (" .. spawner.position.x .. ", " .. spawner.position.y .. ", " .. spawner.position.z .. ")" .. outfitStr)
    end
    
    return allZombies
end

--- @param spawner WLSP_Spawner
function WLSP_SpawnerSystem:addSpawner(spawner)
    local didFind = false
    for index, existing in ipairs(self.spawners) do
        if existing.id == spawner.id then
            self.spawners[index] = spawner
            didFind = true
            break
        end
    end
    if not didFind then
        table.insert(self.spawners, spawner)
        self.enabledStates[spawner.id] = false
        self.spawnTimers[spawner.id] = 0
        self.lifespanTimers[spawner.id] = 0
    end
    -- New spawners are enabled by default
    ModData.add("WLSP_Spawners", self.spawners)
    ModData.add("WLSP_EnabledStates", self.enabledStates)
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)

    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Added spawner with ID: " .. spawner.id)
    end

    -- Broadcast to all staff clients
    broadcastToStaff("AddSpawner", { spawner = spawner })
end

--- @param spawnerId string
function WLSP_SpawnerSystem:removeSpawner(spawnerId)
    for i, spawner in ipairs(self.spawners) do
        if spawner.id == spawnerId then
            table.remove(self.spawners, i)
            break
        end
    end
    self.lifespanTimers[spawnerId] = nil
    self.spawnTimers[spawnerId] = nil
    self.enabledStates[spawnerId] = nil
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
    ModData.add("WLSP_EnabledStates", self.enabledStates)
    ModData.add("WLSP_Spawners", self.spawners)

    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Removed spawner with ID: " .. spawnerId)
    end

    -- Broadcast to all staff clients
    broadcastToStaff("RemoveSpawner", { spawnerId = spawnerId })
end

--- Toggle spawner enabled state
--- @param spawnerId string
function WLSP_SpawnerSystem:toggleSpawner(spawnerId)
    -- Default to enabled if not set
    if self.enabledStates[spawnerId] == nil then
        self.enabledStates[spawnerId] = true
    end
    
    local wasEnabled = self.enabledStates[spawnerId]
    self.enabledStates[spawnerId] = not self.enabledStates[spawnerId]
    
    -- Reset lifespan timer when enabling or disabling
    self.lifespanTimers[spawnerId] = 0
    
    -- If enabling, set spawn timer to a large value so it spawns next tick
    -- If disabling, reset to 0
    if self.enabledStates[spawnerId] then
        -- Set to a very large value to trigger immediate spawn
        self.spawnTimers[spawnerId] = 999999
    else
        self.spawnTimers[spawnerId] = 0
    end
    
    ModData.add("WLSP_EnabledStates", self.enabledStates)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)

    local state = self.enabledStates[spawnerId] and "enabled" or "disabled"

    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Toggled spawner " .. spawnerId .. " to " .. state)
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("ToggleSpawner", { spawnerId = spawnerId, enabled = self.enabledStates[spawnerId] })
end

--- Toggle all spawners in a group
--- @param groupName string
function WLSP_SpawnerSystem:toggleSpawnerGroup(groupName)
    if not groupName or groupName == "" then return end
    
    -- Find all spawners in this group
    local groupSpawners = {}
    for _, spawner in ipairs(self.spawners) do
        if spawner.group == groupName then
            table.insert(groupSpawners, spawner)
        end
    end
    
    if #groupSpawners == 0 then
        if WLSP_SpawnerSystem.logLevel >= 1 then
            print("[WLSP] No spawners found in group: " .. groupName)
        end
        return
    end
    
    -- Check if all spawners in the group are currently enabled
    local allEnabled = true
    for _, spawner in ipairs(groupSpawners) do
        if not self:isSpawnerEnabled(spawner.id) then
            allEnabled = false
            break
        end
    end
    
    -- Toggle all spawners to the opposite state
    local newState = not allEnabled
    for _, spawner in ipairs(groupSpawners) do
        -- Set the new state
        self.enabledStates[spawner.id] = newState
        
        -- Reset lifespan timer
        self.lifespanTimers[spawner.id] = 0
        
        -- Set spawn timer
        if newState then
            self.spawnTimers[spawner.id] = 999999
        else
            self.spawnTimers[spawner.id] = 0
        end
        
        -- Broadcast individual spawner toggle to clients
        broadcastToStaff("ToggleSpawner", { spawnerId = spawner.id, enabled = newState })
    end
    
    -- Save state
    ModData.add("WLSP_EnabledStates", self.enabledStates)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)
    
    local state = newState and "enabled" or "disabled"
    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Toggled group '" .. groupName .. "' (" .. #groupSpawners .. " spawners) to " .. state)
    end
end

--- Check if spawner is enabled
--- @param spawnerId string
--- @return boolean
function WLSP_SpawnerSystem:isSpawnerEnabled(spawnerId)
    -- Default to enabled if not set
    if self.enabledStates[spawnerId] == nil then
        return true
    end
    return self.enabledStates[spawnerId]
end

--- Delete all spawners
function WLSP_SpawnerSystem:deleteAllSpawners()
    local count = #self.spawners
    self.spawners = {}
    self.spawnTimers = {}
    self.lifespanTimers = {}
    self.enabledStates = {}
    
    ModData.add("WLSP_Spawners", self.spawners)
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
    ModData.add("WLSP_EnabledStates", self.enabledStates)
    
    if WLSP_SpawnerSystem.logLevel >= 1 then
        print("[WLSP] Deleted all spawners (count: " .. count .. ")")
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("DeleteAllSpawners", {})
    
    return count
end


--- Main tick function to process all spawners using optimized multi-stage approach
function WLSP_SpawnerSystem:tickSpawners()
    local currentTime = getTimestampMs()
    local deltaTime = 0
    
    if self.lastTickTime > 0 then
        deltaTime = (currentTime - self.lastTickTime) / 1000 -- Convert to seconds
    else
        self.lastTickTime = currentTime
        return
    end

    if deltaTime < 1 then
        return
    end
    
    self.lastTickTime = currentTime
    
    -- STAGE 0: Process triggers for disabled spawners (NEW)
    local triggeredSpawners = processTriggers(self.spawners, deltaTime)
    
    -- STAGE 1: Filter to enabled spawners only
    local enabledSpawners = {}
    for _, spawner in ipairs(self.spawners) do
        if self:isSpawnerEnabled(spawner.id) then
            table.insert(enabledSpawners, spawner)
        end
    end
    
    -- STAGE 2: Update timers and check time/weather conditions (cheap checks)
    local readyToSpawn = {}
    for _, spawner in ipairs(enabledSpawners) do
        local shouldRemove = false
        
        -- Update lifespan timer
        if spawner.lifespan > 0 then
            if not self.lifespanTimers[spawner.id] then
                self.lifespanTimers[spawner.id] = 0
            end
            
            self.lifespanTimers[spawner.id] = self.lifespanTimers[spawner.id] + deltaTime
            if self.lifespanTimers[spawner.id] >= spawner.lifespan * 60 then
                -- Spawner has expired - disable it and reset lifespan
                self.enabledStates[spawner.id] = false
                self.lifespanTimers[spawner.id] = 0
                ModData.add("WLSP_EnabledStates", self.enabledStates)
                ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
                
                if WLSP_SpawnerSystem.logLevel >= 1 then
                    print("[WLSP] Spawner " .. spawner.id .. " expired and has been disabled")
                end
                
                -- Broadcast to all staff clients
                broadcastToStaff("ToggleSpawner", { spawnerId = spawner.id, enabled = false })
                shouldRemove = true
            end
        end
        
        if not shouldRemove then
            -- Update spawn timer
            if not self.spawnTimers[spawner.id] then
                self.spawnTimers[spawner.id] = 0
            end
            self.spawnTimers[spawner.id] = self.spawnTimers[spawner.id] + deltaTime
            
            -- Check if it's time to spawn
            if self.spawnTimers[spawner.id] >= spawner.spawnInterval then
                -- Reset spawn timer
                self.spawnTimers[spawner.id] = 0
                
                -- Only proceed if locations are loaded
                if checkSpawnerLocations(spawner) then
                    table.insert(readyToSpawn, spawner)
                end
            end
        end
    end
    
    -- STAGE 3: Build optimized range check lists with pre-calculated positions and radii
    local spawnerPlayerCounts = {}
    local spawnerZombieCounts = {}
    local playerRangeChecks = {} -- {id, conditionIdx, x, y, radiusSquared}
    local zombieRangeChecks = {} -- {id, conditionIdx, x, y, radiusSquared}
    
    for _, spawner in ipairs(readyToSpawn) do
        -- Build player range checks from conditions
        if spawner.conditions then
            for conditionIdx, condition in ipairs(spawner.conditions) do
                if condition.type == "playerCount" and condition.enabled and
                   (condition.checkType == "rangeSpawner" or condition.checkType == "rangeTarget") and
                   condition.radius then
                    
                    local checkPosition = spawner.position
                    if condition.checkType == "rangeTarget" and spawner.targetLocation then
                        checkPosition = spawner.targetLocation
                    end
                    
                    local checkId = spawner.id .. "_pc_" .. conditionIdx
                    table.insert(playerRangeChecks, {
                        id = checkId,
                        spawnerId = spawner.id,
                        conditionIdx = conditionIdx,
                        x = checkPosition.x,
                        y = checkPosition.y,
                        radiusSquared = condition.radius * condition.radius
                    })
                    spawnerPlayerCounts[checkId] = 0
                end
                
                -- Build zombie range checks from conditions
                if condition.type == "zombieCount" and condition.enabled and condition.radius then
                    local checkPosition = spawner.position
                    if condition.checkType == "target" and spawner.targetLocation then
                        checkPosition = spawner.targetLocation
                    end
                    
                    local checkId = spawner.id .. "_zc_" .. conditionIdx
                    table.insert(zombieRangeChecks, {
                        id = checkId,
                        spawnerId = spawner.id,
                        conditionIdx = conditionIdx,
                        x = checkPosition.x,
                        y = checkPosition.y,
                        radiusSquared = condition.radius * condition.radius
                    })
                    spawnerZombieCounts[checkId] = 0
                end
            end
        end
        
        -- Build player range checks for perPlayerInArea count type
        if spawner.countType == "perPlayerInArea" and spawner.perPlayerInAreaPoint and spawner.perPlayerInAreaRadius then
            table.insert(playerRangeChecks, {
                id = spawner.id,
                spawnerId = spawner.id,
                x = spawner.perPlayerInAreaPoint.x,
                y = spawner.perPlayerInAreaPoint.y,
                radiusSquared = spawner.perPlayerInAreaRadius * spawner.perPlayerInAreaRadius
            })
            spawnerPlayerCounts[spawner.id] = 0
        end
    end
    
    -- STAGE 4: Count players using optimized range check list (expensive operation)
    if #playerRangeChecks > 0 then
        local players = getOnlinePlayers()
        for i = 0, players:size() - 1 do
            local player = players:get(i)
            -- Skip staff members
            if not isStaff(player) then
                local px = player:getX()
                local py = player:getY()
                
                for _, check in ipairs(playerRangeChecks) do
                    local dx = px - check.x
                    local dy = py - check.y
                    local distanceSquared = dx * dx + dy * dy
                    
                    if distanceSquared <= check.radiusSquared then
                        spawnerPlayerCounts[check.id] = spawnerPlayerCounts[check.id] + 1
                    end
                end
            end
        end
    end
    
    -- STAGE 5: Count zombies using optimized range check list (expensive operation)
    if #zombieRangeChecks > 0 then
        local cell = getCell()
        local zombies = cell:getZombieList()
        
        for i = 0, zombies:size() - 1 do
            local zombie = zombies:get(i)
            local zx = zombie:getX()
            local zy = zombie:getY()
            
            for _, check in ipairs(zombieRangeChecks) do
                local dx = zx - check.x
                local dy = zy - check.y
                local distanceSquared = dx * dx + dy * dy
                
                if distanceSquared <= check.radiusSquared then
                    spawnerZombieCounts[check.id] = spawnerZombieCounts[check.id] + 1
                end
            end
        end
    end
    
    -- STAGE 6: Filter by conditions and perform spawns
    local zombiesSpawned = false
    for _, spawner in ipairs(readyToSpawn) do
        -- Check all conditions
        local conditionsMet = true
        
        if spawner.conditions and #spawner.conditions > 0 then
            local conditionMode = spawner.conditionMode or "AND"
            local anyConditionMet = false
            local allConditionsMet = true
            
            for conditionIdx, condition in ipairs(spawner.conditions) do
                local conditionResult = false
                
                if condition.type == "timeOfDay" then
                    conditionResult = checkTimeOfDayCondition(condition)
                elseif condition.type == "weather" then
                    conditionResult = checkWeatherCondition(condition)
                elseif condition.type == "playerCount" then
                    local checkId = spawner.id .. "_pc_" .. conditionIdx
                    conditionResult = checkPlayerCountCondition(condition, spawnerPlayerCounts[checkId])
                elseif condition.type == "zombieCount" then
                    local checkId = spawner.id .. "_zc_" .. conditionIdx
                    conditionResult = checkZombieCountCondition(condition, spawnerZombieCounts[checkId])
                end
                
                if conditionResult then
                    anyConditionMet = true
                else
                    allConditionsMet = false
                end
            end
            
            -- Determine if conditions are met based on mode
            if conditionMode == "AND" then
                conditionsMet = allConditionsMet
            elseif conditionMode == "OR" then
                conditionsMet = anyConditionMet
            end
        end
        
        if conditionsMet then
            -- Calculate spawn count using pre-calculated player count
            local spawnCount = calculateSpawnCount(spawner, spawnerPlayerCounts[spawner.id])
            
            if spawnCount > 0 then
                -- Spawn zombies based on spawner type
                local zombies = nil
                if spawner.type == "point" then
                    zombies = spawnAtPoint(spawner, spawnCount)
                elseif spawner.type == "area" then
                    zombies = spawnInArea(spawner, spawnCount)
                elseif spawner.type == "radius" then
                    zombies = spawnInRadius(spawner, spawnCount)
                elseif spawner.type == "ring" then
                    zombies = spawnInRing(spawner, spawnCount)
                end
                
                -- Move zombies to target location if specified, and apply custom properties
                if zombies and zombies:size() > 0 then
                    zombiesSpawned = true
                    for i = 0, zombies:size() - 1 do
                        local zombie = zombies:get(i)
                        if zombie then
                            -- Apply custom zombie properties
                            if spawner.zombieProperties then
                                WLSP_ZombieModSystem:applyZombieProperties(zombie, spawner.zombieProperties)
                            end
                            
                            -- Move to target if specified
                            if spawner.targetLocation then
                                WLSP_ZombieModSystem:moveZombieToTarget(zombie, spawner.targetLocation.x, spawner.targetLocation.y, spawner.targetLocation.z, true)
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Send any pending zombie mods to clients if we spawned any zombies
    if zombiesSpawned then
        WLSP_ZombieModSystem:sendMods()
    end
    
    -- Save ModData
    ModData.add("WLSP_SpawnTimers", self.spawnTimers)
    ModData.add("WLSP_LifespanTimers", self.lifespanTimers)
    ModData.add("WLSP_TriggerStates", self.triggerStates)
end

if not WLSP_SpawnerSystem.initialized then
    WLSP_SpawnerSystem.initialized = true
    
    Events.OnInitGlobalModData.Add(function()
        WLSP_SpawnerSystem.spawners = ModData.getOrCreate("WLSP_Spawners")
        WLSP_SpawnerSystem.spawnTimers = ModData.getOrCreate("WLSP_SpawnTimers")
        WLSP_SpawnerSystem.lifespanTimers = ModData.getOrCreate("WLSP_LifespanTimers")
        WLSP_SpawnerSystem.enabledStates = ModData.getOrCreate("WLSP_EnabledStates")
        WLSP_SpawnerSystem.triggerStates = ModData.getOrCreate("WLSP_TriggerStates")
    end)

    Events.OnTick.Add(function()
        WLSP_SpawnerSystem:tickSpawners()
    end)
end

