WEZ_EventZones = WEZ_EventZones or {}

local SpawnZones = {}

-- Cache structures for optimized zombie processing
local PreventZombieZones = {}
local AdjustZombieZones = {}
local ZoneCacheValid = false

local SPEED_SPRINTER = 1
local SPEED_FAST_SHAMBLER = 2
local SPEED_SLOW_SHAMBLER = 3
local speedField
local defaultSpeed

local function findField(o, fname)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if tostring(f) == fname then
        return f
        end
    end
end

local function updateSpeed(zombie, targetSpeed)
    getSandboxOptions():set("ZombieLore.Speed", targetSpeed)
    zombie:makeInactive(true)
    zombie:makeInactive(false)
    getSandboxOptions():set("ZombieLore.Speed", defaultSpeed)
end

local function makeSlowShambler(isoZombie)
    updateSpeed(isoZombie, SPEED_SLOW_SHAMBLER)
end

local function makeFastShambler(isoZombie)
    updateSpeed(isoZombie, SPEED_FAST_SHAMBLER)
end

local function makeSprinter(isoZombie)
    updateSpeed(isoZombie, SPEED_SPRINTER)
end

local function getZombieSpeed(isoZombie)
    return getClassFieldVal(isoZombie, speedField)
end

local function removeZombie(isoZombie)
    isoZombie:removeFromWorld()
    isoZombie:removeFromSquare()
end

local function wasConsidered(isoZombie, modData)
    local square = isoZombie:getSquare()
    if not square then return false end
    if not modData.WEZ_WasConsidered then return false end
    local x = square:getX()
    local y = square:getY()
    local modX = modData.WEZ_LastX or 0
    local modY = modData.WEZ_LastY or 0
    local dX = math.abs(x - modX)
    local dY = math.abs(y - modY)
    return dX < 40 and dY < 40
end

local function doConsideration(isoZombie, modData, zone, skipTransmit)
    if (zone.percentageSprinters or 0) > 0 and ZombRand(1, 100) <= zone.percentageSprinters then
        modData.WEZ_type = SPEED_SPRINTER
    elseif (zone.percentageFastShamblers or 0) > 0 and ZombRand(1, 100) <= zone.percentageFastShamblers then
        modData.WEZ_type = SPEED_FAST_SHAMBLER
    elseif (zone.percentageSlowShamblers or 0) > 0 and ZombRand(1, 100) <= zone.percentageSlowShamblers then
        modData.WEZ_type = SPEED_SLOW_SHAMBLER
    else
        modData.WEZ_type = defaultSpeed
    end

    local square = isoZombie:getSquare()

    if not square then return end
    modData.WEZ_LastX = math.floor(square:getX())
    modData.WEZ_LastY = math.floor(square:getY())
    modData.WEZ_WasConsidered = true

    if isServer() and not skipTransmit then
        isoZombie:transmitModData()
    end
end

local function doApplication(isoZombie, modData)
    local type = modData.WEZ_type
    local currentSpeed = getZombieSpeed(isoZombie)

    if type == SPEED_SPRINTER and currentSpeed ~= SPEED_SPRINTER then
        makeSprinter(isoZombie)
    elseif type == SPEED_FAST_SHAMBLER and currentSpeed ~= SPEED_FAST_SHAMBLER then
        makeFastShambler(isoZombie)
    elseif type == SPEED_SLOW_SHAMBLER and currentSpeed ~= SPEED_SLOW_SHAMBLER then
        makeSlowShambler(isoZombie)
    end
end

local function processZombieInZone(isoZombie, zone, skipTransmit)
    local modData = isoZombie:getModData()
    if not wasConsidered(isoZombie, modData) then
        doConsideration(isoZombie, modData, zone, skipTransmit)
    end
    doApplication(isoZombie, modData)
end

-- Build caches for preventZombie and adjustZombie zones
local function buildZoneCaches()
    PreventZombieZones = {}
    AdjustZombieZones = {}
    
    for _, zone in pairs(WEZ_EventZones) do
        if zone.preventZombies then
            table.insert(PreventZombieZones, zone)
        elseif zone.killZombies and not isServer() then
            table.insert(PreventZombieZones, zone)
        elseif (zone.percentageSlowShamblers or 0) > 0 or (zone.percentageSprinters or 0) > 0 or (zone.percentageFastShamblers or 0) > 0 then
            table.insert(AdjustZombieZones, zone)
        end
    end

    table.sort(PreventZombieZones, function(a, b)
        return a.preventZombies and not b.preventZombies
    end)
    
    ZoneCacheValid = true
    print("WEZ: Built zone caches - PreventZombie: " .. #PreventZombieZones .. ", AdjustZombie: " .. #AdjustZombieZones)
end

-- Invalidate zone caches when zones change
local function invalidateZoneCaches()
    ZoneCacheValid = false
    print("WEZ: Zone caches invalidated")
end

local function countZombie(zombie)
    for _, zone in pairs(SpawnZones) do
        if zombie:getX() >= zone.checkMinX and zombie:getX() <= zone.checkMaxX and
           zombie:getY() >= zone.checkMinY and zombie:getY() <= zone.checkMaxY and
           zombie:getZ() >= zone.minZ and zombie:getZ() <= zone.maxZ then
            zone.count = zone.count + 1
        end
    end
end

local function processZombies()
    -- Rebuild caches if invalid
    if not ZoneCacheValid then
        buildZoneCaches()
    end
    
    local zombies = getCell():getZombieList()
    local zombieCount = zombies:size()
    local toRemoveList = {}
    
    for i = 0, zombieCount - 1 do
        local isoZombie = zombies:get(i)
        countZombie(isoZombie)
        
        local zombieX = isoZombie:getX()
        local zombieY = isoZombie:getY()
        local zombieRemoved = false
        
        -- Check preventZombie zones first (smaller list, early exit if zombie removed)
        for _, zone in ipairs(PreventZombieZones) do
            if zombieX >= zone.minX and zombieX <= (zone.maxX + 1) and zombieY >= zone.minY and zombieY <= (zone.maxY + 1) then
                if not isoZombie:getModData().ParanoidDelusions then
                    if zone.killZombies then
                        if not isServer() and not isoZombie:isDead() and isoZombie:isLocal() then
                            isoZombie:Kill(getCell():getFakeZombieForHit())
                        end
                        zombieRemoved = true
                    else
                        if not isClient() then
                            table.insert(toRemoveList, isoZombie)
                        end
                        zombieRemoved = true
                    end
                end
                break -- Exit early since zombie will be removed
            end
        end
        
        -- Only check adjustZombie zones if zombie wasn't removed
        if not zombieRemoved then
            for _, zone in ipairs(AdjustZombieZones) do
                if zombieX >= zone.minX and zombieX <= (zone.maxX + 1) and zombieY >= zone.minY and zombieY <= (zone.maxY + 1) then
                    processZombieInZone(isoZombie, zone, isClient())
                end
            end
        end
    end
    
    for _, isoZombie in pairs(toRemoveList) do
        removeZombie(isoZombie)
    end
end

local function trySpawnZone(zone, currentTime)
    if zone.lastSpawn == 0 then
        zone.lastSpawn = currentTime - zone.spawnInterval
    end
    -- check cell spawn time
    local timeSinceLastSpawn = currentTime - zone.lastSpawn
    if timeSinceLastSpawn < zone.spawnInterval then
        return false
    end

    -- check cell is loaded
    if getCell():getGridSquare(zone.minX, zone.minY, zone.minZ) == nil then
        return false
    end

    local zoneName = "Zone (" .. zone.minX .. "," .. zone.minY .. "," .. zone.minZ.. ") to (" .. zone.maxX .. "," .. zone.maxY .. "," .. zone.maxZ .. ")"
    local intervalsPassed = zone.spawnCatchup and math.floor(timeSinceLastSpawn / zone.spawnInterval) or 1

    local log = {"WEZ Spawner", zoneName}
    table.insert(log, "Zombie Count: " .. zone.count .. " / " .. zone.spawnMax)
    table.insert(log, "Times: " .. timeSinceLastSpawn ..  " / " .. zone.spawnInterval)
    table.insert(log, "Eligible Spawns: " .. intervalsPassed .. " @ " .. zone.spawnCount .. "each")

    -- check zombies present in area
    local toSpawn = math.max(math.min(zone.spawnCount * intervalsPassed, zone.spawnMax - zone.count), 0)
    if toSpawn == 0 then
        table.insert(log, "No Zombies To Spawn")
    elseif zone.spawnCheckPlayers and zone.players then
        table.insert(log, "Players Present, No Zombies will Spawn")
    else
        local numZLevels = zone.maxZ - zone.minZ + 1
        local countPerZ = math.max(1, toSpawn / numZLevels)
        table.insert(log, "Zombies To Spawn: " .. toSpawn)

        -- spawn zombies
        for z = zone.minZ,zone.maxZ do
            addZombiesInOutfitArea(zone.minX, zone.minY, zone.maxX, zone.maxY, z, countPerZ, nil, nil)
        end
    end

    if not zone.spawnCatchup or zone.lastSpawn == 0 then
        zone.lastSpawn = currentTime
    else
        zone.lastSpawn = zone.lastSpawn + (intervalsPassed * zone.spawnInterval)
    end

    print(table.concat(log, " | "))

    return true
end

local function processSpawns()
    local didSpawn = false
    local time = getTimestamp()
    local players = getOnlinePlayers()
    for _, zone in pairs(SpawnZones) do
        zone.players = false
        for i=0,players:size()-1 do
            local player = players:get(i)
            local x = player:getX()
            local y = player:getY()
            if not WL_Utils.isStaff(player) and
               x >= zone.checkPlayerMinX and x <= zone.checkPlayerMaxX and
               y >= zone.checkPlayerMinY and y <= zone.checkPlayerMaxY then
                zone.players = true
                break
            end
        end
    end

    for _, zone in pairs(SpawnZones) do
        if trySpawnZone(zone, time) then
            didSpawn = true
        end
    end

    if didSpawn then
        local data = {}
        for k, v in pairs(SpawnZones) do
            data[k] = v.lastSpawn
        end
        ModData.add("WEZ_EventZoneSpawnTimes", data)
    end
end

WEZ_ThumpZones = nil

local function setThumpStatus(zone, noThump)
    local cell = getWorld():getCell()
    local s1 = cell:getGridSquare(zone.minX, zone.minY, zone.minZ)
    if not s1 then return false end
    for x = zone.minX, zone.maxX do
        for y = zone.minY, zone.maxY do
            for z = zone.minZ, zone.maxZ do
                local square = cell:getGridSquare(x, y, z)
                if square then
                    for i = 0, square:getObjects():size() - 1 do
                        local obj = square:getObjects():get(i)
                        if obj and instanceof(obj, "IsoThumpable") then
                            if noThump and obj:isThumpable() then
                                obj:setIsThumpable(false)
                            elseif not noThump and not obj:isThumpable() then
                                obj:setIsThumpable(true)
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

local function makeThumpChunks(zone)
    local minChunkX = math.floor(zone.minX / 50)
    local maxChunkX = math.floor(zone.maxX / 50)
    local minChunkY = math.floor(zone.minY / 50)
    local maxChunkY = math.floor(zone.maxY / 50)
    local chunkAreas = {}
    for cx = minChunkX, maxChunkX do
    for cy = minChunkY, maxChunkY do
        -- Calculate the overlapping area between the input area and the current chunk
        local overlapMinX = math.max(zone.minX, cx * 50)
        local overlapMaxX = math.min(zone.maxX, (cx + 1) * 50 - 1)
        local overlapMinY = math.max(zone.minY, cy * 50)
        local overlapMaxY = math.min(zone.maxY, (cy + 1) * 50 - 1)
        -- Check if there is an overlap
        if overlapMinX <= overlapMaxX and overlapMinY <= overlapMaxY then
            -- Add the overlapping area to the list
            table.insert(chunkAreas, {
                state = false,
                minX = overlapMinX,
                minY = overlapMinY,
                maxX = overlapMaxX,
                maxY = overlapMaxY,
                minZ = zone.minZ,
                maxZ = zone.maxZ
            })
        end
    end end
    return chunkAreas
end

local function processNoThumpZones()
    if not WEZ_ThumpZones then return end

    local didChange = false

    for _, zone in pairs(WEZ_EventZones) do
        local thumpChange = WEZ_ThumpZones[zone.id]
        if not thumpChange and zone.noThump then
            --print("Creating thump chunks for zone " .. zone.name .. " (" .. zone.id .. ")")
            thumpChange = makeThumpChunks(zone)
            WEZ_ThumpZones[zone.id] = thumpChange
        end
        if thumpChange then
            local isAllReset = true
            for _, chunk in ipairs(thumpChange) do
                if chunk.state ~= zone.noThump then
                    --print("Thump status for zone " .. zone.name .. " (" .. zone.id .. "), chunk (" .. chunk.minX .. "," .. chunk.minY .. ") to (" .. chunk.maxX .. "," .. chunk.maxY .. ") set to " .. tostring(zone.noThump))
                    if setThumpStatus(chunk, zone.noThump) then
                        --print("-- Success")
                        chunk.state = zone.noThump
                        didChange = true
                    end
                end
                if chunk.state then
                    isAllReset = false
                end
            end
            if not zone.noThump and isAllReset then
                --print("Removing thump chunks for zone " .. zone.name .. " (" .. zone.id .. ")")
                WEZ_ThumpZones[zone.id] = nil
            end
        end
    end

    if didChange then
        ModData.add("WEZ_WEZ_ThumpZones", WEZ_ThumpZones)
    end
end

local ticksToWait = 60
local function doZoneUpdates()
    if ticksToWait > 0 then
        ticksToWait = ticksToWait - 1
        return
    end

    if speedField == nil then
        speedField = findField(IsoZombie.new(nil), "public int zombie.characters.IsoZombie.speedType")
        defaultSpeed = tonumber(getSandboxOptions():getOptionByName("ZombieLore.Speed"):asConfigOption():getValueAsLuaString())
    end

    if isServer() then
        ticksToWait = 100
    else
        ticksToWait = 60
    end

    for k, _ in pairs(SpawnZones) do
        SpawnZones[k].count = 0
        SpawnZones[k].players = false
    end
    processZombies()
    if not isClient() then
        processSpawns()
    end
    processNoThumpZones()
    -- TODO: process cars in no-car zones
end
Events.OnTick.Add(doZoneUpdates)

if not isClient() then
    local function setupModData()
        WEZ_LoadIfNeeded()
        local modData_EZPT = ModData.getOrCreate("WEZ_EventZoneSpawnTimes")
        for k, v in pairs(SpawnZones) do
            if modData_EZPT[k] then
                v.lastSpawn = modData_EZPT[k]
            end
        end
        WEZ_ThumpZones = ModData.getOrCreate("WEZ_WEZ_ThumpZones")
    end
    Events.OnInitGlobalModData.Add(setupModData)
end

Events.EveryHours.Add(function()
    if not WEZ_ThumpZones then return end
    for _, zone in pairs(WEZ_ThumpZones) do
        for _, chunk in ipairs(zone) do
            chunk.state = false
        end
    end
end)

function WEZ_UpdateZombieTrackZones()
    local oldSpawnZones = SpawnZones
    SpawnZones = {}
    for id, zone in pairs(WEZ_EventZones) do
        zone = WEZ_EventZoneDefaults.getAllValues(zone)
        if zone.spawnCount and zone.spawnCount > 0 then
            SpawnZones[zone.id] = {
                minX = zone.minX,
                minY = zone.minY,
                maxX = zone.maxX,
                maxY = zone.maxY,
                minZ = zone.minZ,
                maxZ = zone.maxZ,
                checkMinX = zone.minX - zone.spawnRange,
                checkMinY = zone.minY - zone.spawnRange + 1,
                checkMaxX = zone.maxX + zone.spawnRange,
                checkMaxY = zone.maxY + zone.spawnRange + 1,
                checkPlayerMinX = zone.minX - (zone.spawnPlayerRange or 0),
                checkPlayerMinY = zone.minY - (zone.spawnPlayerRange or 0) + 1,
                checkPlayerMaxX = zone.maxX + (zone.spawnPlayerRange or 0),
                checkPlayerMaxY = zone.maxY + (zone.spawnPlayerRange or 0) + 1,
                spawnCount = zone.spawnCount,
                spawnInterval = zone.spawnInterval,
                spawnMax = zone.spawnMax,
                spawnCatchup = zone.spawnCatchup,
                spawnCheckPlayers = zone.spawnCheckPlayers,
                lastSpawn = oldSpawnZones[zone.id] and oldSpawnZones[zone.id].lastSpawn or 0,
                count = 0,
                players = false,
                noThump = zone.noThump,
            }
        end
    end
    
    -- Invalidate zone caches when zones are updated
    invalidateZoneCaches()
end