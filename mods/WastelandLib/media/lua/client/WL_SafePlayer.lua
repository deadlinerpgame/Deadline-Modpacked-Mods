WL_SafePlayer = {}
WL_SafePlayer.instance = nil

function WL_SafePlayer:start(player, length, waitMoveTimeout)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init(player, length, waitMoveTimeout)
    if WL_SafePlayer.instance then
        WL_SafePlayer.instance:expire()
    end
    WL_SafePlayer.instance = o
end

function WL_SafePlayer:init(player, length, waitMoveTimeout)
    self.player = player
    self.length = length
    self.waitMove = waitMoveTimeout and waitMoveTimeout > 0
    if self.waitMove then
        self.waitMoveTimeout = getTimestamp() + waitMoveTimeout
        self.lastPosition = {player:getX(), player:getY(), player:getZ()}
        self.expirationTime = -1
    else
        self.expirationTime = getTimestamp() + self.length
    end
end

function WL_SafePlayer:update()
    if self.waitMove and self:shouldBreakWaitMove() then
        self.expirationTime = getTimestamp() + self.length
        self.waitMove = false
    end

    if self.expirationTime > 0 and getTimestamp() > self.expirationTime then
        self:expire()
    else
        self:setSafe()
    end
end

function WL_SafePlayer:shouldBreakWaitMove()
    if self.waitMoveTimeout < getTimestamp() then return true end
    if self.player:getX() ~= self.lastPosition[1] then return true end
    if self.player:getY() ~= self.lastPosition[2] then return true end
    if self.player:getZ() ~= self.lastPosition[3] then return true end
    return false
end

function WL_SafePlayer:setSafe()
    self.player:setGhostMode(true)
    if self.waitMove then
        self.player:setHaloNote("Safe until you move", 100, 250, 100, 50)
    else
        self.player:setHaloNote("Safe for " .. (self.expirationTime - getTimestamp()) .. " more seconds", 250, 250, 100, 50)
    end
end

function WL_SafePlayer:expire()
    self.player:setHaloNote("No longer safe", 250, 100, 100, 200)
    self.player:setGhostMode(false)
    WL_SafePlayer.instance = nil
end

function WL_SafePlayer:isSafe(player)
    return WL_SafePlayer.instance and WL_SafePlayer.instance.player == player
end

local function onSafePlayerTick()
    if WL_SafePlayer.instance then
        WL_SafePlayer.instance:update()
    end
end

Events.OnTick.Add(onSafePlayerTick)