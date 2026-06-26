if isClient() then return end -- Server and Singleplayer only

WLZA_AttractorSystem = WLZA_AttractorSystem or {}

WLZA_AttractorSystem.attractors = WLZA_AttractorSystem.attractors or {}
WLZA_AttractorSystem.lastTickTime = WLZA_AttractorSystem.lastTickTime or 0
WLZA_AttractorSystem.pulseTimers = WLZA_AttractorSystem.pulseTimers or {}
WLZA_AttractorSystem.enabledStates = WLZA_AttractorSystem.enabledStates or {}
WLZA_AttractorSystem.logLevel = WLZA_AttractorSystem.logLevel or 0 -- 0=none, 1=normal, 2=verbose

--- Check if a player is staff
--- @param player IsoPlayer
--- @return boolean
local function isStaff(player)
    if not isServer() then return true end -- SP
    if not player then return false end -- Guard
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

--- Broadcast attractor update to all staff clients
--- @param command string
--- @param args table
local function broadcastToStaff(command, args)
    if not isServer() then return end -- Only broadcast in multiplayer
    
    local players = getOnlinePlayers()
    for i = 0, players:size() - 1 do
        local player = players:get(i)
        if isStaff(player) then
            sendServerCommand(player, "WLZA", command, args)
        end
    end
end

--- Emit silent sound at attractor position
--- @param attractor WLZA_Attractor
local function emitAttractorSound(attractor)
    if not attractor or not attractor.position then return end
    
    -- Check if location is loaded
    local square = getCell():getGridSquare(
        math.floor(attractor.position.x),
        math.floor(attractor.position.y),
        math.floor(attractor.position.z)
    )
    
    if not square then
        if WLZA_AttractorSystem.logLevel >= 2 then
            print("[WLZA] Attractor " .. attractor.id .. " location not loaded, skipping sound")
        end
        return
    end
    
    -- Emit silent sound that attracts zombies
    getWorldSoundManager():addSound(
        nil,                    -- source (nil for environmental)
        attractor.position.x,   -- x
        attractor.position.y,   -- y
        attractor.position.z,   -- z
        attractor.maxRange,     -- maximum range
        100,                    -- volume (100 = loud for zombies)
        false,                  -- is zombie sound
        attractor.minRange,     -- minimum range (full volume)
        0                       -- unknown parameter
    )
    
    if WLZA_AttractorSystem.logLevel >= 2 then
        print("[WLZA] Attractor " .. attractor.id .. " emitted sound at (" .. 
              attractor.position.x .. ", " .. attractor.position.y .. ", " .. attractor.position.z .. 
              ") range: " .. attractor.minRange .. "-" .. attractor.maxRange)
    end
end

--- Add or update an attractor
--- @param attractor WLZA_Attractor
function WLZA_AttractorSystem:addAttractor(attractor)
    local didFind = false
    for index, existing in ipairs(self.attractors) do
        if existing.id == attractor.id then
            self.attractors[index] = attractor
            didFind = true
            break
        end
    end
    
    if not didFind then
        table.insert(self.attractors, attractor)
        self.enabledStates[attractor.id] = false
        self.pulseTimers[attractor.id] = 0
    end
    
    -- Save to ModData
    ModData.add("WLZA_Attractors", self.attractors)
    ModData.add("WLZA_EnabledStates", self.enabledStates)
    ModData.add("WLZA_PulseTimers", self.pulseTimers)
    
    if WLZA_AttractorSystem.logLevel >= 1 then
        print("[WLZA] Added/updated attractor: " .. attractor.id)
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("AddAttractor", { attractor = attractor })
end

--- Remove an attractor by ID
--- @param attractorId string
function WLZA_AttractorSystem:removeAttractor(attractorId)
    for i, attractor in ipairs(self.attractors) do
        if attractor.id == attractorId then
            table.remove(self.attractors, i)
            break
        end
    end
    
    self.pulseTimers[attractorId] = nil
    self.enabledStates[attractorId] = nil
    
    ModData.add("WLZA_PulseTimers", self.pulseTimers)
    ModData.add("WLZA_EnabledStates", self.enabledStates)
    ModData.add("WLZA_Attractors", self.attractors)
    
    if WLZA_AttractorSystem.logLevel >= 1 then
        print("[WLZA] Removed attractor: " .. attractorId)
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("RemoveAttractor", { attractorId = attractorId })
end

--- Toggle attractor enabled state
--- @param attractorId string
function WLZA_AttractorSystem:toggleAttractor(attractorId)
    -- Default to disabled if not set
    if self.enabledStates[attractorId] == nil then
        self.enabledStates[attractorId] = false
    end
    
    self.enabledStates[attractorId] = not self.enabledStates[attractorId]
    
    -- Reset pulse timer when toggling
    self.pulseTimers[attractorId] = 9999999
    
    ModData.add("WLZA_EnabledStates", self.enabledStates)
    ModData.add("WLZA_PulseTimers", self.pulseTimers)
    
    if WLZA_AttractorSystem.logLevel >= 1 then
        local state = self.enabledStates[attractorId] and "enabled" or "disabled"
        print("[WLZA] Toggled attractor " .. attractorId .. " to " .. state)
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("ToggleAttractor", { attractorId = attractorId, enabled = self.enabledStates[attractorId] })
end

--- Check if attractor is enabled
--- @param attractorId string
--- @return boolean
function WLZA_AttractorSystem:isAttractorEnabled(attractorId)
    -- Default to disabled if not set
    if self.enabledStates[attractorId] == nil then
        return false
    end
    return self.enabledStates[attractorId]
end

--- Delete all attractors
function WLZA_AttractorSystem:deleteAllAttractors()
    local count = #self.attractors
    self.attractors = {}
    self.pulseTimers = {}
    self.enabledStates = {}
    
    ModData.add("WLZA_Attractors", self.attractors)
    ModData.add("WLZA_PulseTimers", self.pulseTimers)
    ModData.add("WLZA_EnabledStates", self.enabledStates)
    
    if WLZA_AttractorSystem.logLevel >= 1 then
        print("[WLZA] Deleted all attractors (count: " .. count .. ")")
    end
    
    -- Broadcast to all staff clients
    broadcastToStaff("DeleteAllAttractors", {})
    
    return count
end

--- Main tick function to process all attractors
function WLZA_AttractorSystem:tickAttractors()
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
    
    -- Process each enabled attractor
    for _, attractor in ipairs(self.attractors) do
        if self:isAttractorEnabled(attractor.id) then
            -- Initialize timer if needed
            if not self.pulseTimers[attractor.id] then
                self.pulseTimers[attractor.id] = 0
            end
            
            -- Update pulse timer
            self.pulseTimers[attractor.id] = self.pulseTimers[attractor.id] + deltaTime
            
            -- Check if it's time to emit sound
            if self.pulseTimers[attractor.id] >= attractor.interval then
                -- Reset timer
                self.pulseTimers[attractor.id] = 0
                
                -- Emit sound
                emitAttractorSound(attractor)
            end
        end
    end
    
    -- Save pulse timers periodically
    ModData.add("WLZA_PulseTimers", self.pulseTimers)
end

if not WLZA_AttractorSystem.initialized then
    WLZA_AttractorSystem.initialized = true
    
    Events.OnInitGlobalModData.Add(function()
        WLZA_AttractorSystem.attractors = ModData.getOrCreate("WLZA_Attractors")
        WLZA_AttractorSystem.pulseTimers = ModData.getOrCreate("WLZA_PulseTimers")
        WLZA_AttractorSystem.enabledStates = ModData.getOrCreate("WLZA_EnabledStates")
    end)
    
    Events.OnTick.Add(function()
        WLZA_AttractorSystem:tickAttractors()
    end)
end