---
--- WWP_PlayerStats.lua
--- Manages the player's stats and how much they have worked.
--- 07/07/2023
---

if isServer() then return end

require "UserData"
require "PlayerReady"

WWP_PlayerStats = {}
WWP_PlayerStats.MAX_WORK_POINTS = 150
WWP_PlayerStats.MAX_WORK_POINTS_LAZY = 135
WWP_PlayerStats.MAX_WORK_POINTS_INDUSTRIOUS = 165

WWP_PlayerStats.MILLIS_TO_FULL_RESTORE = 259200000   -- 72 hours
WWP_PlayerStats.MIN_CHECK_TIME_MS = 30000
WWP_PlayerStats.cachedWorkData = {}

local function getMaxWorkPoints(player)
	if player:HasTrait("Lazy") then
		return WWP_PlayerStats.MAX_WORK_POINTS_LAZY
	elseif player:HasTrait("Industrious") then
		return WWP_PlayerStats.MAX_WORK_POINTS_INDUSTRIOUS
	else
		return WWP_PlayerStats.MAX_WORK_POINTS
	end
end

--- Checks if player has enough work points for a task
function WWP_PlayerStats.hasPointsAvailable(player, pointsNeeded)
	local workData = WWP_PlayerStats.getPlayerWorkData(player)
	if not workData then return false end
	return (workData.pointsRemaining - pointsNeeded) >= 0
end

--- Removes work points from a player (Caller should check they have enough first)
function WWP_PlayerStats.deductWorkPoints(player, amount)
	if amount <= 0 then return end
	local workData = WWP_PlayerStats.getPlayerWorkData(player)
	workData.pointsRemaining = math.max(0, workData.pointsRemaining - amount)
	WL_UserData.Set("WWP_WorkData", workData)
end

--- Get a human readable string showing how many work points remain
function WWP_PlayerStats.getWorkPointsRemainingString(player)
	local workData = WWP_PlayerStats.getPlayerWorkData(player)
	if not workData then return "Still Loading" end
	return "Work Remaining: " .. string.format("%d", workData.pointsRemaining)
			.. " / " .. tostring(getMaxWorkPoints(player))
end

---@param player IsoPlayer to check work data for
---@return table|nil with pointsRemaining and lastCheckedAt keys
function WWP_PlayerStats.getPlayerWorkData(player)
	if not player then return end
	local username = player:getUsername()
	if not WWP_PlayerStats.cachedWorkData[username] then return end
	WWP_PlayerStats.updatePlayerWorkPoints(player, WWP_PlayerStats.cachedWorkData[username])
	return WWP_PlayerStats.cachedWorkData[username]
end

function WWP_PlayerStats.updatePlayerWorkPoints(player, workData)
	local currentTimeMillis = getTimestampMs()
	local maxWorkPoints = getMaxWorkPoints(player)
	if workData.pointsRemaining == maxWorkPoints then
		workData.lastCheckedAt = currentTimeMillis
		return
	end
	if currentTimeMillis - workData.lastCheckedAt < WWP_PlayerStats.MIN_CHECK_TIME_MS then return end
	local timeSinceLastCheck = currentTimeMillis - workData.lastCheckedAt
	local workPointsRestored = (timeSinceLastCheck / WWP_PlayerStats.MILLIS_TO_FULL_RESTORE) * maxWorkPoints
	local newPoints = math.floor(math.min(workData.pointsRemaining + workPointsRestored, maxWorkPoints))
	if newPoints == workData.pointsRemaining then return end
	workData.pointsRemaining = newPoints
	workData.lastCheckedAt = currentTimeMillis
	WL_UserData.Set("WWP_WorkData", workData)
end

local function receiveWorkData(data, username)
	if data.pointsRemaining == nil then
		data.pointsRemaining = (WWP_PlayerStats.MAX_WORK_POINTS)
	end
	if data.lastCheckedAt == nil then
		data.lastCheckedAt = getTimestampMs()
	end
	if data.isTownWorkDisabled == nil then
		data.isTownWorkDisabled = false
	end
	WWP_PlayerStats.cachedWorkData[username] = data
end

WL_PlayerReady.Add(function(pIdx, player)
	local username = player:getUsername()
	WL_UserData.Listen("WWP_WorkData", username, receiveWorkData)
	WL_UserData.Fetch("WWP_WorkData")
end)

Events.OnPlayerDeath.Add(function(player)
	local username = player:getUsername()
	WL_UserData.StopListening("WWP_WorkData", username, receiveWorkData)
end)