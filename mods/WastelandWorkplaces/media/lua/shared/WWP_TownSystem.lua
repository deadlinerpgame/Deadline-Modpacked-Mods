---
--- WWP_TownSystem.lua
--- 27/07/2024
---

--- WWP_TownSystem
--- @class WWP_TownSystem : WL_ClientServerBase
WWP_TownSystem = WL_ClientServerBase:new("WWP_TownSystem")
WWP_TownSystem.needsPublicData = true
WWP_TownSystem.needsPrivateData = true

local function ensurePublicData(data)
	if not data.towns then
		data.towns = {}
	end
end

local function ensurePrivateData(data)
	if not data.townsLastTouched then
		data.townsLastTouched = {}
	end
end

--- Runs on Server
function WWP_TownSystem:onModDataInit()
	ensurePublicData(self.publicData)
	ensurePrivateData(self.privateData)
end

--- Runs on Client
function WWP_TownSystem:onPublicDataUpdated()
	ensurePublicData(self.publicData)

	for townId, townData in pairs(self.publicData.towns) do
		if not WWP_Towns[townId] then WWP_Towns[townId] = WWP_Town:new() end
		WWP_Towns[townId]:updateFrom(townData)
	end

	local townsToRemove = {}
	for townId, _ in pairs(WWP_Towns) do
		if not self.publicData.towns[townId] then
			table.insert(townsToRemove, townId)
		end
	end

	for _, townId in ipairs(townsToRemove) do
		WL_TriggerZones.removeZone(WWP_Towns[townId].zone)
		WWP_Towns[townId].zone:delete()
		WWP_Towns[townId]:dispose()
		WWP_Towns[townId] = nil
	end

	if WWP_TownPanel.instance then
		if not WWP_Towns[WWP_TownPanel.instance.town.id] then
			WWP_TownPanel.instance:onClose() -- Town looks to have been deleted, rip
		else
			WWP_TownPanel.instance:updateState()
		end
	end
end

function WWP_TownSystem:saveTown(player, serialisedTownData)
	if isClient() then
		self:sendToServer(player, "saveTown", serialisedTownData)
		return
	end

	self.publicData.towns[serialisedTownData.id] = serialisedTownData
	self:savePublicData()
end

function WWP_TownSystem:deleteTown(player, townId)
	if isClient() then
		self:sendToServer(player, "deleteTown", townId)
		return
	end
	WLAT_Server.deleteAllActivity(WLAT_Server.getUid("WastelandWorkplaces", townId))
	self.publicData.towns[townId] = nil
	self.privateData.townsLastTouched[townId] = nil
	self:savePublicData()
	self:savePrivateData()
end

function WWP_TownSystem:touchTown(player, townId)
	if isClient() then
		self:sendToServer(player, "touchTown", townId)
		return
	end

	self.privateData.townsLastTouched[townId] = getTimestamp()
	self:savePrivateData()
end

if not isClient() then
	-- 14 days
	local inactivityLimitSeconds = 60 * 60 * 24 * 14
	function WWP_TownSystem:checkTownsForInactivity()
		local now = getTimestamp()
		for townId, townData in pairs(self.publicData.towns) do
			if townData.lastTouched and now - townData.lastTouched > inactivityLimitSeconds then
				self:deleteTown(nil, townId)
			end
		end
	end

	Events.EveryHours.Add(function()
		WWP_TownSystem:checkTownsForInactivity()
	end)
end