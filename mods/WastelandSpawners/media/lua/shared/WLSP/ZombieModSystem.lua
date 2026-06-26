WLSP_ZombieModSystem = WLSP_ZombieModSystem or {}
WLSP_ZombieModSystem.pendingZombieMods = WLSP_ZombieModSystem.pendingZombieMods or {}
WLSP_ZombieModSystem.pendingClientMods = WLSP_ZombieModSystem.pendingClientMods or {} -- Client-side pending mod queue with retry
WLSP_ZombieModSystem.activePathingZombies = WLSP_ZombieModSystem.activePathingZombies or {} -- Track zombies with active pathing targets
WLSP_ZombieModSystem.SEND_DISTANCE = 200 -- Distance in tiles for sending zombie mod updates
WLSP_ZombieModSystem.SEND_DISTANCE_SQUARED = 40000 -- 200^2 for optimized distance checks
WLSP_ZombieModSystem.MAX_RETRY_TICKS = 200 -- Max ticks to retry finding a zombie before giving up
WLSP_ZombieModSystem.MAX_PATHING_TICKS = 5000 -- Max ticks to continue pathing before giving up on zombie
WLSP_ZombieModSystem.PATHING_DISTANCE_THRESHOLD = 10 -- Distance in squares before stopping pathing
WLSP_ZombieModSystem.PATHING_REFRESH_RATE = isServer() and 60 or 600 -- Ticks between path refreshes

----------
WLSP_ZombieModSystem.PATHING_DISTANCE_THRESHOLD_SQUARED = WLSP_ZombieModSystem.PATHING_DISTANCE_THRESHOLD * WLSP_ZombieModSystem.PATHING_DISTANCE_THRESHOLD

-- Speed constants
local SPEED_SPRINTER = 1
local SPEED_FAST_SHAMBLER = 2
local SPEED_SLOW_SHAMBLER = 3
local speedField
local defaultSpeed

-- Cognition constants
local COGNITION_SMART = 1
local COGNITION_DEFAULT = 3
local COGNITION_RANDOM = 4
local cognitionField
local defaultCognition

--- Find a field on an object by name
--- @param o any
--- @param fname string
--- @return any
local function findField(o, fname)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if tostring(f) == fname then
            return f
        end
    end
end

--- Update zombie speed by temporarily changing sandbox option
--- @param zombie IsoZombie
--- @param targetSpeed number
local function updateSpeed(zombie, targetSpeed)
    getSandboxOptions():set("ZombieLore.Speed", targetSpeed)
    zombie:makeInactive(true)
    zombie:makeInactive(false)
    getSandboxOptions():set("ZombieLore.Speed", defaultSpeed)
end

--- Update zombie cognition by temporarily changing sandbox option
--- @param zombie IsoZombie
--- @param targetCognition number
local function updateCognition(zombie, targetCognition)
    local cognitionConfigOption = getSandboxOptions():getOptionByName("ZombieLore.Cognition"):asConfigOption()
    cognitionConfigOption:setValue(targetCognition)
    zombie:DoZombieStats()
    cognitionConfigOption:setValue(defaultCognition)
end

--- Get current speed of a zombie
--- @param zombie IsoZombie
--- @return number
local function getZombieSpeed(zombie)
    return getClassFieldVal(zombie, speedField)
end

--- Get current cognition of a zombie
--- @param zombie IsoZombie
--- @return number
local function getZombieCognition(zombie)
    return getClassFieldVal(zombie, cognitionField)
end

--- Apply custom properties to a zombie
--- @param zombie IsoZombie
--- @param properties WLSP_ZombieProperties
local function applyZombiePropertiesInternal(zombie, properties)
    if not properties then
        return
    end
    
    -- Initialize speed field if needed
    if speedField == nil then
        speedField = findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.speedType")
        defaultSpeed = tonumber(getSandboxOptions():getOptionByName("ZombieLore.Speed"):asConfigOption():getValueAsLuaString())
    end
    
    -- Initialize cognition field if needed
    if cognitionField == nil then
        cognitionField = findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.cognition")
        defaultCognition = tonumber(getSandboxOptions():getOptionByName("ZombieLore.Cognition"):asConfigOption():getValueAsLuaString())
    end
    
    -- Speed
    if properties.speed then
        local targetSpeed
        if properties.speed == "sprinter" then
            targetSpeed = SPEED_SPRINTER
        elseif properties.speed == "shambler" then
            targetSpeed = SPEED_FAST_SHAMBLER
        elseif properties.speed == "slowShambler" then
            targetSpeed = SPEED_SLOW_SHAMBLER
        end
        
        if targetSpeed then
            local currentSpeed = getZombieSpeed(zombie)
            if currentSpeed ~= targetSpeed then
                updateSpeed(zombie, targetSpeed)
            end
        end
    end
    
    -- Cognition
    if properties.cognition then
        local targetCognition
        if properties.cognition == "smart" then
            targetCognition = COGNITION_SMART
        elseif properties.cognition == "random" then
            targetCognition = COGNITION_RANDOM
        elseif properties.cognition == "default" then
            targetCognition = COGNITION_DEFAULT
        end
        
        if targetCognition then
            local currentCognition = getZombieCognition(zombie)
            if currentCognition ~= targetCognition then
                updateCognition(zombie, targetCognition)
            end
        end
    end
    
    -- Health Modifier
    if properties.healthModifier then
        zombie:setHealth(zombie:getHealth() * properties.healthModifier)
    end
    
    -- Force Crawling
    if properties.forceCrawling then
        if not zombie:isCrawling() then
            zombie:toggleCrawling()
            zombie:setCanWalk(false)
            zombie:setFallOnFront(true)
        end
    end
end

--- Make zombie move towards target location
--- @param zombie IsoZombie
--- @param targetX number
--- @param targetY number
--- @param targetZ number
local function moveZombieToTargetInternal(zombie, targetX, targetY, targetZ)
    -- Use pathToLocationF for floating point coordinates
    zombie:pathToLocationF(targetX, targetY, targetZ)
end

--- Apply zombie properties to a zombie (handles both local and remote)
--- @param zombie IsoZombie
--- @param properties WLSP_ZombieProperties
function WLSP_ZombieModSystem:applyZombieProperties(zombie, properties)
    if not zombie or not properties then
        return
    end
    
    -- If zombie is not remote, apply immediately
    if not zombie:isRemoteZombie() then
        applyZombiePropertiesInternal(zombie, properties)
    else
        -- Queue for remote application
        local mod = {
            zombieId = zombie:getOnlineID(),
            position = {
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ()
            },
            properties = properties
        }
        table.insert(self.pendingZombieMods, mod)
    end
end

--- Calculate squared distance between zombie and target location (optimized - no sqrt)
--- @param zombie IsoZombie
--- @param targetX number
--- @param targetY number
--- @return number
local function calculateDistanceSquared(zombie, targetX, targetY)
    local dx = zombie:getX() - targetX
    local dy = zombie:getY() - targetY
    return dx * dx + dy * dy
end

--- Check if zombie should stop pathing (reached target or attacking)
--- @param zombie IsoZombie
--- @param targetX number
--- @param targetY number
--- @return boolean
local function shouldStopPathing(zombie, targetX, targetY)
    -- Check if zombie is attacking
    if zombie:isAttacking() then
        return true
    end
    
    -- Check if zombie is within threshold distance (using squared distance for optimization)
    local distanceSquared = calculateDistanceSquared(zombie, targetX, targetY)
    if distanceSquared <= WLSP_ZombieModSystem.PATHING_DISTANCE_THRESHOLD_SQUARED then
        return true
    end
    
    return false
end

--- Move zombie to target location (handles both local and remote)
--- @param zombie IsoZombie
--- @param targetX number
--- @param targetY number
--- @param targetZ number
--- @param continuous boolean Whether to enable continuous pathing (default: false)
function WLSP_ZombieModSystem:moveZombieToTarget(zombie, targetX, targetY, targetZ, continuous)
    if not zombie then
        return
    end
    
    -- If zombie is not remote, apply immediately
    if not zombie:isRemoteZombie() then
        moveZombieToTargetInternal(zombie, targetX, targetY, targetZ)
        
        -- Add to continuous pathing tracking if requested
        if continuous then
            local zombieId = zombie:getOnlineID()
            self.activePathingZombies[zombieId] = {
                zombie = zombie,
                targetX = targetX,
                targetY = targetY,
                targetZ = targetZ,
                lastPathTick = 0,
                ticksElapsed = 0
            }
        end
    else
        -- Queue for remote application
        local mod = {
            zombieId = zombie:getOnlineID(),
            position = {
                x = zombie:getX(),
                y = zombie:getY(),
                z = zombie:getZ()
            },
            targetLocation = {
                x = targetX,
                y = targetY,
                z = targetZ
            },
            continuous = continuous
        }
        table.insert(self.pendingZombieMods, mod)
    end
end

--- Sync active pathing zombies to nearby players (SERVER ONLY)
--- This ensures clients take over pathing for zombies that transition from server to client
function WLSP_ZombieModSystem:syncActivePathingZombies()
    if not isServer() then
        return
    end
    
    -- Check if we have any active pathing zombies
    local hasActivePathing = false
    for _ in pairs(self.activePathingZombies) do
        hasActivePathing = true
        break
    end
    
    if not hasActivePathing then
        return
    end
    
    -- Get all online players
    local players = getOnlinePlayers()
    if players:size() == 0 then
        return
    end
    
    -- Build sync data for each player based on proximity
    local playerSyncMap = {}
    
    for zombieId, pathData in pairs(self.activePathingZombies) do
        local zombie = pathData.zombie
        
        -- Skip if zombie is invalid or dead
        if zombie and not zombie:isDead() then
            -- Check if zombie should still be pathing
            if not shouldStopPathing(zombie, pathData.targetX, pathData.targetY) then
                local zx = zombie:getX()
                local zy = zombie:getY()
                
                -- Find nearby players
                for i = 0, players:size() - 1 do
                    local player = players:get(i)
                    local px = player:getX()
                    local py = player:getY()
                    local dx = px - zx
                    local dy = py - zy
                    local distanceSquared = dx * dx + dy * dy
                    
                    if distanceSquared <= self.SEND_DISTANCE_SQUARED then
                        if not playerSyncMap[i] then
                            playerSyncMap[i] = {}
                        end
                        table.insert(playerSyncMap[i], {
                            zombieId = zombieId,
                            targetLocation = {
                                x = pathData.targetX,
                                y = pathData.targetY,
                                z = pathData.targetZ
                            },
                            continuous = true
                        })
                    end
                end
            else
                -- Zombie reached target or is attacking, remove from server tracking
                self.activePathingZombies[zombieId] = nil
            end
        else
            -- Zombie is invalid, remove from tracking
            self.activePathingZombies[zombieId] = nil
        end
    end
    
    -- Send sync data to players
    for playerIndex, syncData in pairs(playerSyncMap) do
        local player = players:get(playerIndex)
        sendServerCommand(player, "WLSP", "SyncActivePathing", { zombies = syncData })
    end
end

--- Send pending zombie mods to nearby players (SERVER ONLY)
function WLSP_ZombieModSystem:sendMods()
    if not isServer() then
        return
    end
    
    if #self.pendingZombieMods == 0 then
        return
    end
    
    -- Get all online players
    local players = getOnlinePlayers()
    if players:size() == 0 then
        -- No players online, clear pending mods
        self.pendingZombieMods = {}
        return
    end
    
    -- Group mods by nearby players
    -- playerModMap[playerIndex] = { mods = {...} }
    local playerModMap = {}
    
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        local px = player:getX()
        local py = player:getY()
        local modsForPlayer = {}
        
        -- Check each pending mod to see if it's within range of this player
        for _, mod in ipairs(self.pendingZombieMods) do
            local dx = px - mod.position.x
            local dy = py - mod.position.y
            local distanceSquared = dx * dx + dy * dy
            
            if distanceSquared <= self.SEND_DISTANCE_SQUARED then
                table.insert(modsForPlayer, mod)
            end
        end
        
        -- If this player has any mods to receive, store them
        if #modsForPlayer > 0 then
            playerModMap[i] = modsForPlayer
        end
    end
    
    -- Send mods to each player
    for playerIndex, mods in pairs(playerModMap) do
        local player = players:get(playerIndex)
        sendServerCommand(player, "WLSP", "ApplyZombieMods", { mods = mods })
    end
    
    -- Clear pending mods after sending
    self.pendingZombieMods = {}
end

--- Apply zombie mods received from server (CLIENT ONLY)
--- Queue mods for retry processing to allow zombies to sync
--- @param mods WLSP_PendingZombieMod[]
function WLSP_ZombieModSystem:applyReceivedMods(mods)
    if not mods or #mods == 0 then
        return
    end
    
    -- Queue mods with retry counter
    for _, mod in ipairs(mods) do
        table.insert(self.pendingClientMods, {
            mod = mod,
            retryAttempts = 0
        })
    end
end

--- Process pending client mods with retry (CLIENT ONLY)
--- Called each tick to attempt applying mods, retrying if zombies not found yet
function WLSP_ZombieModSystem:processPendingClientMods()
    if #self.pendingClientMods == 0 then
        return
    end
    
    local cell = getCell()
    if not cell then
        return
    end
    
    local zombies = cell:getZombieList()
    if not zombies then
        return
    end
    
    -- Create a map of zombie IDs for quick lookup
    local zombieMap = {}
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie then
            zombieMap[zombie:getOnlineID()] = zombie
        end
    end
    
    -- Try to process each pending mod
    local stillPending = {}
    local processedCount = 0
    local expiredCount = 0
    
    for _, pending in ipairs(self.pendingClientMods) do
        pending.retryAttempts = pending.retryAttempts + 1
        local mod = pending.mod
        local zombie = zombieMap[mod.zombieId]
        
        if zombie then
            -- Found the zombie, apply modifications
            
            -- Apply properties if present
            if mod.properties then
                applyZombiePropertiesInternal(zombie, mod.properties)
            end
            
            -- Move to target if present
            if mod.targetLocation then
                moveZombieToTargetInternal(zombie, mod.targetLocation.x, mod.targetLocation.y, mod.targetLocation.z)
                
                -- Add to continuous pathing tracking if requested
                if mod.continuous then
                    local zombieId = mod.zombieId
                    WLSP_ZombieModSystem.activePathingZombies[zombieId] = {
                        zombie = zombie,
                        targetX = mod.targetLocation.x,
                        targetY = mod.targetLocation.y,
                        targetZ = mod.targetLocation.z,
                        lastPathTick = 0,
                        ticksElapsed = 0
                    }
                end
            end
            
            processedCount = processedCount + 1
        elseif pending.retryAttempts >= self.MAX_RETRY_TICKS then
            -- Max retries reached, give up
            expiredCount = expiredCount + 1
        else
            -- Zombie not found yet, keep retrying
            table.insert(stillPending, pending)
        end
    end
    
    self.pendingClientMods = stillPending
end

--- Process active pathing zombies, continuously refreshing their paths (CLIENT ONLY)
function WLSP_ZombieModSystem:processActivePathing()
    if not self.activePathingZombies then
        return
    end
    
    local toRemove = {}
    
    for zombieId, pathData in pairs(self.activePathingZombies) do
        local zombie = pathData.zombie
        
        -- Increment tick counter
        pathData.ticksElapsed = pathData.ticksElapsed + 1
        
        -- Check if zombie still exists
        if not zombie or zombie:isDead() or zombie:getOnlineID() == -1 then
            table.insert(toRemove, zombieId)
        else
            -- Check if time limit exceeded
            if pathData.ticksElapsed >= self.MAX_PATHING_TICKS then
                table.insert(toRemove, zombieId)
            -- Check if zombie should stop pathing
            elseif shouldStopPathing(zombie, pathData.targetX, pathData.targetY) then
                table.insert(toRemove, zombieId)
            else
                -- Refresh path if enough ticks have passed
                pathData.lastPathTick = pathData.lastPathTick + 1
                if pathData.lastPathTick >= self.PATHING_REFRESH_RATE then
                    moveZombieToTargetInternal(zombie, pathData.targetX, pathData.targetY, pathData.targetZ)
                    pathData.lastPathTick = 0
                end
            end
        end
    end
    
    -- Remove zombies that should stop pathing
    for _, zombieId in ipairs(toRemove) do
        self.activePathingZombies[zombieId] = nil
    end
end

--- Receive and apply active pathing sync from server (CLIENT ONLY)
--- @param syncData table Array of zombie sync data
function WLSP_ZombieModSystem:applySyncedPathing(syncData)
    if not syncData or #syncData == 0 then
        return
    end
    
    local cell = getCell()
    if not cell then
        return
    end
    
    local zombies = cell:getZombieList()
    if not zombies then
        return
    end
    
    -- Create a map of zombie IDs for quick lookup
    local zombieMap = {}
    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie then
            zombieMap[zombie:getOnlineID()] = zombie
        end
    end
    
    -- Apply synced pathing data
    local syncedCount = 0
    for _, data in ipairs(syncData) do
        local zombie = zombieMap[data.zombieId]
        if zombie and not zombie:isDead() then
            -- Add or update in active pathing tracking
            self.activePathingZombies[data.zombieId] = {
                zombie = zombie,
                targetX = data.targetLocation.x,
                targetY = data.targetLocation.y,
                targetZ = data.targetLocation.z,
                lastPathTick = 0,
                ticksElapsed = 0
            }
            syncedCount = syncedCount + 1
        end
    end
end

-- Initialize OnTick events
if not WLSP_ZombieModSystem.tickInitialized then
    WLSP_ZombieModSystem.tickInitialized = true
    
    -- Server tick counter for periodic syncing
    local serverTickCounter = 0
    local SYNC_INTERVAL = 100 -- Sync active pathing every 100 ticks (~10 seconds)
    
    Events.OnTick.Add(function()
        if isClient() then
            WLSP_ZombieModSystem:processPendingClientMods()
        end
        
        WLSP_ZombieModSystem:processActivePathing()
        
        if isServer() then
            serverTickCounter = serverTickCounter + 1
            if serverTickCounter >= SYNC_INTERVAL then
                serverTickCounter = 0
                WLSP_ZombieModSystem:syncActivePathingZombies()
            end
        end
    end)
end

