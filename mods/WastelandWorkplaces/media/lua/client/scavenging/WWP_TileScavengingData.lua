if isServer() then return end

require "UserData"
require "PlayerReady"

WWP_TileScavengingData = WWP_TileScavengingData or {}
WWP_TileScavengingData.DATA_KEY = "WWP_TileScavenging"
WWP_TileScavengingData.COOLDOWN_MS = 56 * 60 * 60 * 1000
WWP_TileScavengingData.cachedData = WWP_TileScavengingData.cachedData or {}

local function ensureData(data)
    if type(data) ~= "table" then
        data = {}
    end
    if type(data.searchedTiles) ~= "table" then data.searchedTiles = {} end
    return data
end

local function getPlayerData(player)
    local username = player:getUsername()
    local data = WWP_TileScavengingData.cachedData[username]
    if not data then
        data = ensureData(nil)
        WWP_TileScavengingData.cachedData[username] = data
    end
    return data
end

local function trimExpired(data, now)
    local cutoff = now - WWP_TileScavengingData.COOLDOWN_MS
    for tileKey, searchedAt in pairs(data.searchedTiles) do
        if type(searchedAt) ~= "number" or searchedAt <= cutoff then
            data.searchedTiles[tileKey] = nil
        end
    end
end

local function receiveData(data, username)
    WWP_TileScavengingData.cachedData[username] = ensureData(data)
end

function WWP_TileScavengingData.getTileKey(square)
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ())
end

function WWP_TileScavengingData.isRecentlySearched(player, square)
    local data = getPlayerData(player)
    local searchedAt = data.searchedTiles[WWP_TileScavengingData.getTileKey(square)]
    if type(searchedAt) ~= "number" then
        return false
    end
    return getTimestampMs() - searchedAt < WWP_TileScavengingData.COOLDOWN_MS
end

function WWP_TileScavengingData.markSearched(player, square)
    local username = player:getUsername()
    local data = getPlayerData(player)
    local now = getTimestampMs()
    trimExpired(data, now)
    data.searchedTiles[WWP_TileScavengingData.getTileKey(square)] = now
    WWP_TileScavengingData.cachedData[username] = data
    WL_UserData.Set(WWP_TileScavengingData.DATA_KEY, data, username, true)
end

WL_PlayerReady.Add(function(_, player)
    local username = player:getUsername()
    WL_UserData.Listen(WWP_TileScavengingData.DATA_KEY, username, receiveData)
    WL_UserData.Fetch(WWP_TileScavengingData.DATA_KEY)
end)

Events.OnPlayerDeath.Add(function(player)
    local username = player:getUsername()
    WL_UserData.StopListening(WWP_TileScavengingData.DATA_KEY, username, receiveData)
end)
