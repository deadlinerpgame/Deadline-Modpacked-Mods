if not isClient() then return end -- only in MP

require "TimedActions/ISWalkToTimedAction"
require "Util/AdjacentFreeTileFinder"

WRC = WRC or {}
WRC.KeepSafe = WRC.KeepSafe or {}

WRC.KeepSafe.Config = {
    CheckEveryTicks = 30,
    CritialDistanceTiles = 10,
    DangerDistanceTiles = 25,
    MaxScanDistanceTiles = 40,
    MinEscapeDistanceTiles = 4,
    MaxEscapeDistanceTiles = 16,
    EscapeDistanceStep = 2,
    BlacklistMs = 10000,
    RetryDelayTicks = 2,
    MinDistanceImprovementSq = 4,
    AllowedClosestDistanceLossSq = 1,
    DirectionWeightInfluence = 2.5,
    ClosestDistanceScoreWeight = 1.0,
    AverageDistanceScoreWeight = 0.45,
    ImprovementScoreWeight = 0.75,
    DirectionOffsetsRadians = {
        0,
        math.rad(25),
        -math.rad(25),
        math.rad(50),
        -math.rad(50),
        math.rad(75),
        -math.rad(75),
    },
}

WRC.KeepSafe.BlacklistedSquares = WRC.KeepSafe.BlacklistedSquares or {}
WRC.KeepSafe.ActiveAction = nil
WRC.KeepSafe.PendingRetryTicks = nil
WRC.KeepSafe.TickCounter = 0

local function toSquareKey(square)
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

local function cleanupBlacklist()
    local now = getTimestampMs()
    for key, expiresAt in pairs(WRC.KeepSafe.BlacklistedSquares) do
        if expiresAt <= now then
            WRC.KeepSafe.BlacklistedSquares[key] = nil
        end
    end
end

local function blacklistSquare(square)
    if not square then return end
    local cfg = WRC.KeepSafe.Config
    WRC.KeepSafe.BlacklistedSquares[toSquareKey(square)] = getTimestampMs() + cfg.BlacklistMs
end

local function isSquareBlacklisted(square)
    if not square then return true end
    local expiresAt = WRC.KeepSafe.BlacklistedSquares[toSquareKey(square)]
    return expiresAt ~= nil and expiresAt > getTimestampMs()
end

local function isValidSquare(square)
    if not square then return false end

    if square:Is(IsoFlagType.solid) then
        return false
    end

    if square:getTree() then
        return false
    end

    -- Player can stand on solidtrans squares adjacent to windows.
    if square:Is(IsoFlagType.solidtrans) then
        local hasWindow = false
        if square:Is(IsoFlagType.windowW) or square:Is(IsoFlagType.windowN) then
            hasWindow = true
        end
        if not hasWindow then
            local s = square:getAdjacentSquare(IsoDirections.S)
            if s and s:Is(IsoFlagType.windowN) then
                hasWindow = true
            end
        end
        if not hasWindow then
            local e = square:getAdjacentSquare(IsoDirections.E)
            if e and e:Is(IsoFlagType.windowW) then
                hasWindow = true
            end
        end
        if not hasWindow then
            return false
        end
    end

    if not square:TreatAsSolidFloor() then
        return false
    end

    return true
end

local function canRunForPlayer(player)
    if not player then return false end
    if not WRC.Afk.IsSelfAfk() then return false end
    if player:getZ() > 0 then return false end
    if player:getVehicle() then return false end
    if not WRC.Meta.IsKeepSafeEnabled() then return false end
    if player:isDead() then return false end
    return true
end

local function getNearbyZombies(player)
    local anyDangerDistance = false
    local anyCriticalDistance = false
    local nearby = {}
    local cfg = WRC.KeepSafe.Config
    local dangerDistSq = cfg.DangerDistanceTiles * cfg.DangerDistanceTiles
    local scanDistSq = cfg.MaxScanDistanceTiles * cfg.MaxScanDistanceTiles
    local criticalDistSq = cfg.CritialDistanceTiles * cfg.CritialDistanceTiles
    local zombies = getCell():getZombieList()
    if not zombies then
        return nearby
    end

    for i = 0, zombies:size() - 1 do
        local zombie = zombies:get(i)
        if zombie and zombie:getZ() == player:getZ() and not zombie:isDead() then
            local distSq = zombie:getDistanceSq(player)
            if distSq <= scanDistSq then
                table.insert(nearby, {
                    x = zombie:getX(),
                    y = zombie:getY(),
                    distSq = distSq,
                })
                if distSq <= criticalDistSq then
                    anyCriticalDistance = true
                end
                if distSq <= dangerDistSq then
                    anyDangerDistance = true
                end
            end
        end
    end

    return anyDangerDistance, anyCriticalDistance, nearby
end

local function getClosestZombieDistSq(x, y, zombies)
    local best = nil
    for _, zombieData in ipairs(zombies) do
        local dx = x - zombieData.x
        local dy = y - zombieData.y
        local distSq = dx * dx + dy * dy
        if not best or distSq < best then
            best = distSq
        end
    end
    return best or math.huge
end

local function getAverageZombieDistSq(x, y, zombies)
    if #zombies == 0 then return math.huge end

    local total = 0
    for _, zombieData in ipairs(zombies) do
        local dx = x - zombieData.x
        local dy = y - zombieData.y
        total = total + (dx * dx + dy * dy)
    end

    return total / #zombies
end

local function getDirectionWeight(playerX, playerY, dirX, dirY, zombies, cfg)
    local towardThreat = 0
    local awayFromThreat = 0

    for _, zombieData in ipairs(zombies) do
        local zx = zombieData.x - playerX
        local zy = zombieData.y - playerY
        local dist = math.sqrt(zx * zx + zy * zy)
        if dist > 0.0001 then
            local nzx = zx / dist
            local nzy = zy / dist
            local dot = dirX * nzx + dirY * nzy -- +1 means moving toward this zombie
            local proximityWeight = 1 / dist

            if dot > 0 then
                towardThreat = towardThreat + (dot * proximityWeight)
            else
                awayFromThreat = awayFromThreat + ((-dot) * proximityWeight)
            end
        end
    end

    local raw = 1 + ((awayFromThreat - towardThreat) * cfg.DirectionWeightInfluence)
    if raw < 0.1 then return 0.1 end
    return raw
end

local function getEscapeDirection(playerX, playerY, zombies)
    local awayX = 0
    local awayY = 0

    for _, zombieData in ipairs(zombies) do
        local dx = playerX - zombieData.x
        local dy = playerY - zombieData.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist > 0 then
            local weight = 1 / dist
            awayX = awayX + (dx / dist) * weight
            awayY = awayY + (dy / dist) * weight
        end
    end

    local len = math.sqrt(awayX * awayX + awayY * awayY)
    if len <= 0.0001 then
        return 0, -1
    end
    return awayX / len, awayY / len
end

local function rotate2D(x, y, radians)
    local cosA = math.cos(radians)
    local sinA = math.sin(radians)
    return x * cosA - y * sinA, x * sinA + y * cosA
end

local function findBestEscapeSquare(player, zombies)
    local cfg = WRC.KeepSafe.Config
    local playerSquare = player:getSquare()
    if not playerSquare then return nil end

    local playerX = player:getX()
    local playerY = player:getY()
    local playerZ = player:getZ()
    local currentClosestDistSq = getClosestZombieDistSq(playerX, playerY, zombies)
    local currentAverageDistSq = getAverageZombieDistSq(playerX, playerY, zombies)

    local awayX, awayY = getEscapeDirection(playerX, playerY, zombies)

    local bestSquare = nil
    local bestScore = -1

    for _, offset in ipairs(cfg.DirectionOffsetsRadians) do
        local dirX, dirY = rotate2D(awayX, awayY, offset)
        local directionWeight = getDirectionWeight(playerX, playerY, dirX, dirY, zombies, cfg)

        for dist = cfg.MinEscapeDistanceTiles, cfg.MaxEscapeDistanceTiles, cfg.EscapeDistanceStep do
            local targetX = math.floor(playerX + dirX * dist)
            local targetY = math.floor(playerY + dirY * dist)
            local square = getCell():getGridSquare(targetX, targetY, playerZ)

            if square and not isSquareBlacklisted(square) and isValidSquare(square) then
                if AdjacentFreeTileFinder.privTrySquareForWalls(playerSquare, square) then
                    local closestDistSq = getClosestZombieDistSq(targetX, targetY, zombies)
                    local closestDelta = closestDistSq - currentClosestDistSq

                    -- Avoid clearly dangerous moves while still allowing detours when surrounded.
                    if closestDelta >= -cfg.AllowedClosestDistanceLossSq then
                        local averageDistSq = getAverageZombieDistSq(targetX, targetY, zombies)
                        local averageDelta = averageDistSq - currentAverageDistSq

                        local improvementBonus = 0
                        if closestDelta >= cfg.MinDistanceImprovementSq then
                            improvementBonus = closestDelta
                        end

                        local baseScore =
                            (closestDistSq * cfg.ClosestDistanceScoreWeight) +
                            (averageDistSq * cfg.AverageDistanceScoreWeight) +
                            (averageDelta * cfg.ImprovementScoreWeight) +
                            (improvementBonus * cfg.ImprovementScoreWeight)

                        local score = baseScore * directionWeight
                        if score > bestScore then
                            bestScore = score
                            bestSquare = square
                        end
                    end
                end
            end
        end
    end

    return bestSquare
end

local function startWalkToSquare(player, square, anyCriticalDistance)
    ISTimedActionQueue.clear(player)
    local action = ISWalkToTimedAction:new(player, square)
    action.WRC_KeepSafeData = {
        targetSquare = square,
        anyCriticalDistance = anyCriticalDistance,
    }
    WRC.KeepSafe.ActiveAction = action
    ISTimedActionQueue.add(action)
end

function WRC.KeepSafe.TryEscape(player)
    cleanupBlacklist()
    if not canRunForPlayer(player) then
        WRC.KeepSafe.ActiveAction = nil
        WRC.KeepSafe.PendingRetryTicks = nil
        return
    end

    local anyDangerDistance, anyCriticalDistance, zombies = getNearbyZombies(player)
    if not anyDangerDistance then
        WRC.KeepSafe.ActiveAction = nil
        WRC.KeepSafe.PendingRetryTicks = nil
        return
    end

    local square = findBestEscapeSquare(player, zombies)
    if not square then
        return
    end

    startWalkToSquare(player, square, anyCriticalDistance)
end

function WRC.KeepSafe.OnWalkActionFailed(action)
    if not action or not action.WRC_KeepSafeData then return end

    blacklistSquare(action.WRC_KeepSafeData.targetSquare)
    WRC.KeepSafe.ActiveAction = nil
    WRC.KeepSafe.PendingRetryTicks = WRC.KeepSafe.Config.RetryDelayTicks
end

function WRC.KeepSafe.OnAfkStopped()
    WRC.KeepSafe.ActiveAction = nil
    WRC.KeepSafe.PendingRetryTicks = nil
    WRC.KeepSafe.TickCounter = 0
end

function WRC.KeepSafe.OnAfkStarted()
    WRC.KeepSafe.ActiveAction = nil
    WRC.KeepSafe.PendingRetryTicks = nil
    WRC.KeepSafe.TickCounter = 0
end

function WRC.KeepSafe.Update()
    local player = getPlayer()
    if not player then return end

    if not canRunForPlayer(player) then
        WRC.KeepSafe.ActiveAction = nil
        WRC.KeepSafe.PendingRetryTicks = nil
        return
    end

    if WRC.KeepSafe.PendingRetryTicks then
        WRC.KeepSafe.PendingRetryTicks = WRC.KeepSafe.PendingRetryTicks - 1
        if WRC.KeepSafe.PendingRetryTicks <= 0 then
            WRC.KeepSafe.PendingRetryTicks = nil
            WRC.KeepSafe.TryEscape(player)
        end
        return
    end

    if WRC.KeepSafe.ActiveAction then
        if not ISTimedActionQueue.hasAction(WRC.KeepSafe.ActiveAction) then
            WRC.KeepSafe.ActiveAction = nil
        else
            return
        end
    end

    WRC.KeepSafe.TickCounter = WRC.KeepSafe.TickCounter + 1
    if WRC.KeepSafe.TickCounter < WRC.KeepSafe.Config.CheckEveryTicks then
        return
    end
    WRC.KeepSafe.TickCounter = 0

    WRC.KeepSafe.TryEscape(player)
end

if not WRC.KeepSafe.OriginalWalkToUpdate then
    WRC.KeepSafe.OriginalWalkToUpdate = ISWalkToTimedAction.update
    function ISWalkToTimedAction:update()
        WRC.KeepSafe.OriginalWalkToUpdate(self)

        if self.WRC_KeepSafeData then
            local player = self.character
            if self.result == BehaviorResult.Failed then
                WRC.KeepSafe.OnWalkActionFailed(self)
                if self.WRC_KeepSafeData.anyCriticalDistance then
                    player:setRunning(false)
                end
                print("Walk action failed, blacklisting square and trying again...")
            elseif self.result == BehaviorResult.Succeeded then
                if self.WRC_KeepSafeData.anyCriticalDistance then
                    player:setRunning(false)
                end
                WRC.KeepSafe.TryEscape(player)
                print("Walk action succeeded, checking if we need to keep escaping...")
            end
            
            if self.WRC_KeepSafeData.anyCriticalDistance and not player:isRunning() then
                print("Toggling run on player due to critical distance")
                player:toggleForceRun()
            end

            if WL_AFK_Kicker.lastPosition then
                WL_AFK_Kicker.lastPosition.x = math.floor(player:getX())
                WL_AFK_Kicker.lastPosition.y = math.floor(player:getY())
                WL_AFK_Kicker.lastPosition.z = math.floor(player:getZ())
            end
        end
    end
end
