---
--- WWP_WorkplaceZone.lua
--- 18/06/2023
---

if not isClient() then return end

require "WWP_WorkplaceType"
require "WWP_PlayerStats"
require "WL_Zone"

--- @class WWP_WorkplaceZone
--- @inherits WL_Zone
--- @field id string
--- @field name string
--- @field location string
--- @field description string
--- @field typeKey string
--- @field mapType string
--- @field open boolean
--- @field autoClose boolean
--- @field employees table<string, boolean>
WWP_WorkplaceZone = WWP_WorkplaceZone or WL_Zone:derive("WWP_WorkplaceZone")

--- @type table zoneID -> WWP_WorkplaceZone
WWP_WorkplaceZones = WWP_WorkplaceZones or {}

function WWP_WorkplaceZone.getAllZones()
	return WWP_WorkplaceZones
end


--- Get all zones at a given location
--- @param x number
--- @param y number
--- @param z number
---@return WWP_WorkplaceZone[]
function WWP_WorkplaceZone.getZonesAt(x, y, z)
	local zones = {}
	for _, zone in pairs(WWP_WorkplaceZones) do
		if zone:isInZone(x, y, z) then
			table.insert(zones, zone)
		end
	end
	return zones
end

function WWP_WorkplaceZone.hasWorkplaceAt(x, y, z)
	for _, zone in pairs(WWP_WorkplaceZones) do
		if zone:isInZone(x, y, z) then
			return true
		end
	end
	return false
end

function WWP_WorkplaceZone.getZone(zoneId)
	return WWP_WorkplaceZones[zoneId]
end

--- @param player IsoPlayer
--- @param container ItemContainer
--- @return boolean true if the container is locked for the player
function WWP_WorkplaceZone.isContainerLockedFor(player, container)
	if WL_Utils.isAtLeastGM(player) then
		return false
	end
	if container:isInCharacterInventory(player) then
		return false
	end
	local isoObject = container:getParent()
	local item = container:getContainingItem()
	local x, y, z
	if isoObject then
		x = isoObject:getX()
		y = isoObject:getY()
		z = isoObject:getZ()
	elseif item and item:getWorldItem() and not item:hasTag("WSS_Shop") and item:getCategory() == "Container" then
		local worldItem = item:getWorldItem()
		x = worldItem:getX()
		y = worldItem:getY()
		z = worldItem:getZ()
	elseif container:getType() == "floor" then
		x = player:getX()
		y = player:getY()
		z = player:getZ()
	else
		return false
	end
	for _, workplace in pairs(WWP_WorkplaceZone.getAllZones()) do
		if not workplace:isAllowedToTakeItems(player, x, y, z) then
			return true
		end
	end
	return false
end

--- This function is always called for both new workplaces and deserialised ones.
local function setupWorkplace(o)
	o.mapType = "Workplace"
	o.mapColor = {1.0, 0.87, 0}
	o.mapDisabled = false
	o.activityTracker = WLAT_Client:new("WastelandWorkplaces", o.id)
end

---@param name string Human visible name
function WWP_WorkplaceZone:new(name, x1, y1, x2, y2, z1, z2)
	--- @type WWP_WorkplaceZone
	local o = WWP_WorkplaceZone.parentClass.new(self, x1, y1, z1, x2, y2, z2)  -- call inherited constructor
	setmetatable(o, self)
	self.__index = self
	o.id = getRandomUUID()
	o.name = name
	o.type = WWP_WorkplaceTypes["general_store"]
	o.open = false
	o.autoClose = true
	o.isHiring = false
	o.isNPC = false
	o.employees = {}
	setupWorkplace(o)
	o:save()
	return o
end

function WWP_WorkplaceZone:loadFrom(o)
	setmetatable(o, self)
	self.__index = self
	if o.minZ == nil then o.minZ = 0 end
	if o.maxZ == nil then o.maxZ = 0 end
	o.type = WWP_WorkplaceTypes[o.typeKey]
	o.minX = math.floor(o.minX)
	o.minY = math.floor(o.minY)
	o.maxX = math.floor(o.maxX)
	o.maxY = math.floor(o.maxY)
	setupWorkplace(o)
	table.insert(WL_Zone.allZones, o)
	return o
end

function WWP_WorkplaceZone:save()
	sendClientCommand(getPlayer(), "WastelandWorkplaces", "SetZone", {
		id = self.id,
		name = self.name,
		location = self.location or "",
		description = self.description or "",
		typeKey = self.type.key,
		autoClose = self.autoClose,
		isHiring = self.isHiring,
		isNPC = self.isNPC,
		open = self.open,
		employees = self.employees,
		minX = self.minX,
		minY = self.minY,
		maxX = self.maxX,
		maxY = self.maxY,
		minZ = self.minZ,
		maxZ = self.maxZ,
		currency = self.currency,
		townOverrideId = self.townOverrideId
	})
end

function WWP_WorkplaceZone:delete()
	self.activityTracker:deleteAllActivity()
	self.parentClass.delete(self)
	sendClientCommand(getPlayer(), "WastelandWorkplaces", "DeleteZone", {id = self.id})
end

function WWP_WorkplaceZone:getMapName()
	return self.name
end

function WWP_WorkplaceZone:setIsNPC(isNPC)
	if self.isNPC ~= isNPC then
		self.isNPC = isNPC
		self:save()
	end
end

function WWP_WorkplaceZone:setIsHiring(isHiring)
	if self.isHiring ~= isHiring then
		self.isHiring = isHiring
		self:save()
	end
end

function WWP_WorkplaceZone:setLocation(location)
	if self.location ~= location then
		self.location = location
		self:save()
	end
end

function WWP_WorkplaceZone:setDescription(description)
	if self.description ~= description then
		self.description = description
		self:save()
	end
end

function WWP_WorkplaceZone:setName(name)
	if self.name ~= name then
		self.name = name
		self:save()
	end
end

function WWP_WorkplaceZone:setWorkplaceType(type)
	if self.type ~= type then
		self.type = type
		self:save()
	end
end

--- Checks if a tile is locked by this workplace. If so, it does not want players taking items unless they
--- are employees at this workplace.
---@param player IsoPlayer that is trying to take an item
---@param x number coordinate on X-axis of the tile where the item or container can be found
---@param y number coordinate on Y-axis of the tile where the item or container can be found
---@param z number coordinate on Z-axis of the tile where the item or container can be found
---@return boolean true if this workplace wants the tile locked so no items can be taken from it, like a safe-house.
function WWP_WorkplaceZone:isAllowedToTakeItems(player, x, y, z)
	if self.open then -- Let players configure this later? Add "always locked" and "always unlocked" options dropdown
		return true
	else
		if self:isInZone(x, y, z) then
			return self:isEmployee(player)
		else
			return true
		end
	end
end

function WWP_WorkplaceZone:hasAnyEmployees()
	for _, _ in pairs(self.employees) do
		return true
	end
	return false
end

function WWP_WorkplaceZone:isEmployee(player)
	return self.employees[player:getUsername()] ~= nil
end

function WWP_WorkplaceZone:isPartner(username)
	return self.employees[username]
end

function WWP_WorkplaceZone:fireEmployee(username)
	self.activityTracker:clearActivity(username)
	self.employees[username] = nil
	self:save()
end

function WWP_WorkplaceZone:addEmployee(username)
	if not self.employees[username] then
		self.activityTracker:recordActivity(username)
		self.employees[username] = false
		self:save()
	end
end

function WWP_WorkplaceZone:promoteEmployee(username)
	self.employees[username] = true
	self:save()
end

function WWP_WorkplaceZone:demoteEmployee(username)
	self.employees[username] = false
	self:save()
end

function WWP_WorkplaceZone:isPlayerInZone(player)
	return self:isInZone(player:getX(), player:getY(), player:getZ())
end

function WWP_WorkplaceZone:setAutoClose(autoClose)
	if self.autoClose ~= autoClose then
		self.autoClose = autoClose
		self:save()
	end
end

function WWP_WorkplaceZone:onEnter(player)
	if self:isEmployee(player) then
		local isCapable, msg = self.type:isCapableOfJob(player)
		if not isCapable then
			self:fireEmployee(player:getUsername())
			player:setHaloNote("You've been fired from your job\n" .. msg, 250, 20, 60, 300.0)
			return
		else
			self.activityTracker:recordActivity(player:getUsername())
		end
	end

	self:showWorkplaceInfo(player, "Entering")

	if not self:isEmployee(player) and self.open then
		if self.type:getVisitorEnterSound() then
			getSoundManager():PlayWorldSound(self.type:getVisitorEnterSound(), player:getSquare(), 1, 100, 1, false);
		end
	end
end

function WWP_WorkplaceZone:showWorkplaceInfo(player, prefix)
	local entryMessage
	if prefix then
		entryMessage = prefix .. " " .. self.name
	else
		entryMessage = self.name
	end

	if not self:hasAnyEmployees() then
		entryMessage = entryMessage .. "\nVacant: Available to be claimed"
		player:setHaloNote(entryMessage, 124, 252, 0, 300.0)
		return
	end

	if(self:isEmployee(player)) then
		if not self.type:disableTickRewards() then
			if not self.open then
				entryMessage = entryMessage .. "\nClosed: Open to earn money"
				player:setHaloNote(entryMessage, 200, 200, 200, 300.0)
				return
			end

			if not WWP_Options.workInWorkplaces then
				entryMessage = entryMessage .. "\nWork Disabled: Clock in to start earning money"
				player:setHaloNote(entryMessage, 200, 200, 200, 300.0)
				return
			end

			if self.type:requireSomeonePresentForRewards() then
				local employees, visitors = self:countPlayersInZone()
				if self.type:requireCustomersForRewards() then
					if visitors == 0 then
						entryMessage = entryMessage .. "\nNo customers present\n"  .. WWP_PlayerStats.getWorkPointsRemainingString(player)
						player:setHaloNote(entryMessage, 200, 200, 200, 500.0)
						return
					end
				else -- Then anyone will do
					if visitors == 0 and employees < 2 then
						entryMessage = entryMessage .. "\nNobody around\n"  .. WWP_PlayerStats.getWorkPointsRemainingString(player)
						player:setHaloNote(entryMessage, 200, 200, 200, 500.0)
						return
					end
				end
			end
		end

		entryMessage = entryMessage .. "\n" .. WWP_PlayerStats.getWorkPointsRemainingString(player)
		player:setHaloNote(entryMessage, 253, 216, 12, 500.0)
	else
		if not self.open then
			entryMessage = entryMessage .. "\n***  CLOSED  ***"
			player:setHaloNote(entryMessage, 250, 20, 60, 200.0)
			return
		end

		if self.isHiring then
			entryMessage = entryMessage .. "\nHiring new employees!"
		end

		if self.type:requireEmployeesForBenefits() and (#self.type:getBenefits()) > 0 then
			local employees, _ = self:countPlayersInZone()
			if employees == 0 then
				entryMessage = entryMessage .. "\nNo Employees present"
				player:setHaloNote(entryMessage, 200, 200, 200, 350.0)
				return
			end
		end

		for _, benefit in pairs(self.type:getBenefits()) do
			entryMessage = entryMessage .. "\n" .. benefit
		end

		player:setHaloNote(entryMessage, 124, 252, 0, 500.0)
	end
end

function WWP_WorkplaceZone:countPlayersInZone()
	local employeeCount = 0
	local visitorCount = 0
	local players = getOnlinePlayers()
	players = players or ArrayList.new()
	for playerIndex = 0, players:size() -1 do
		local p = players:get(playerIndex)
		local isInZone = self:isInZone(p:getX(), p:getY(), p:getZ())

		if isInZone then
			if self:isEmployee(p) then
				employeeCount = employeeCount + 1
			else
				visitorCount = visitorCount + 1
			end
		end
	end

	return employeeCount, visitorCount
end

function WWP_WorkplaceZone:onExit(player)
	local msg = "Leaving " .. self.name
	if self:isEmployee(player) then
		msg = msg .. "\n" .. WWP_PlayerStats.getWorkPointsRemainingString(player)
		self.activityTracker:recordActivity(player:getUsername())
	else
		if self.type:getVisitorExitSound() then
			getSoundManager():PlayWorldSound(self.type:getVisitorExitSound(), player:getSquare(), 1, 100, 1, false);
		end
	end
	player:setHaloNote(msg, 200, 200, 200, 250.0)
end

function WWP_WorkplaceZone:perMinute(player)
	if not self.open then return end

	if self:isEmployee(player) then
		self.type:decreaseBoredom(player, 10)
	end

	if self.type:requireEmployeesForBenefits() and (#self.type:getBenefits()) > 0 then
		local employees, _ = self:countPlayersInZone()
		if employees == 0 then return end
	end

	if not self:isEmployee(player) then
		self.type:applyBenefits(player)
	end

	self.type:onMinuteTick(player, self)
end

function WWP_WorkplaceZone:perTwoMinutes(player)
	if self.type:doSpeedyTicks() then
		self:doWorkTick(player)
	end
	self.type:onTwoMinuteTick(player, self)
end

function WWP_WorkplaceZone:perFiveMinutes(player)
	if not self.type:doSpeedyTicks() then
		self:doWorkTick(player)
	end
	self.type:onFiveMinuteTick(player, self)
end

function WWP_WorkplaceZone:perTenMinutes(player)
	self:doWorkTick(player, true)
end

function WWP_WorkplaceZone:doWorkTick(player, doPityReward)
	if self.type:disableTickRewards() then return end
	if not self.open then return end
	if not self:isEmployee(player) then return end
	if not WWP_Options.workInWorkplaces then return end
	if WWP_Factions.getFactionRank(player) then return end -- Faction members can't work in towns

	if(WWP_PlayerStats.hasPointsAvailable(player, WWP_PayrollProcessor.DEFAULT_WORK_POINTS_PER_TICK)) then
		if self.type:requireSomeonePresentForRewards() then
			local employees, visitors = self:countPlayersInZone()
			if visitors > 0 and doPityReward then
				return
			end
			if self.type:requireCustomersForRewards() then
				if visitors == 0 and not doPityReward then
					local rewardString = "No customers present\n"  .. WWP_PlayerStats.getWorkPointsRemainingString(player)
					player:setHaloNote(rewardString, 200, 200, 200, 350.0)
					return
				end
			else -- Then anyone will do
				if visitors == 0 and employees < 2 then
					local rewardString = "Nobody around\n"  .. WWP_PlayerStats.getWorkPointsRemainingString(player)
					player:setHaloNote(rewardString, 200, 200, 200, 350.0)
					return
				end
			end
		end

		local town = self:getTown()
		local currency = self.currency or WWP_PayrollProcessor.DEFAULT_CURRENCY
		self.type:generateReward(player, town, currency)
	end
end

---@return table|nil the town this workplace is in, if any
function WWP_WorkplaceZone:getTown()
	if self.townOverrideId == "IGNORE_TOWN" then
		return nil -- Ignore all towns
	end
	local town = WWP_Town.findTownById(self.townOverrideId)
	if town then return town end
	return WWP_Town.findTownAt(self.minX, self.minY, self.minZ)
end

--- Sets a town override onto this workplace that it will try to return instead of town zone it is in.
--- This is useful when the workplace is not inside a town zone but IC would be part of it (e.g. off map mine area)
--- @param town table WWP_Town to override with, nil to clear it (Auto mode), or IGNORE_TOWN to ignore all towns
function WWP_WorkplaceZone:setTown(town)
	if not town then
		self.townOverrideId = nil
	else
		if town == "IGNORE_TOWN" then
			self.townOverrideId = town
		else
			self.townOverrideId = town.id
		end
	end
	self:save()
end

---@return number the amount of work points needed to produce a commodity at this workplace
---@return number|nil the work point multiplier for the town, if any was present (decimal from 0-1)
function WWP_WorkplaceZone:getCommodityWorkPointCost()
	local commodity = self.type:getProducedCommodity()
	if not commodity then return 9999 end -- Stop anyone making it
	local baseWp = commodity.workPoints
	if not baseWp then return 9999 end -- Stop anyone making it
	local town = self:getTown()
	if not town then return baseWp end -- No town, no bonuses
	if not town.type.workPointMultipliers then return 9999 end -- Stop anyone making it
	local multiplier = town.type.workPointMultipliers[commodity]
	return math.floor(baseWp * (multiplier or 1)), multiplier
end

local bufferTimeout = 80
local takeItemBuffer = nil
local putItemBuffer = nil

local function insertToBuffer(buffer, zoneId, username, itemType)
	if not buffer[zoneId] then
		buffer[zoneId] = {}
	end
	if not buffer[zoneId][username] then
		buffer[zoneId][username] = {}
	end
	if not buffer[zoneId][username][itemType] then
		buffer[zoneId][username][itemType] = 0
	end
	buffer[zoneId][username][itemType] = buffer[zoneId][username][itemType] + 1
	bufferTimeout = 80
end

function WWP_WorkplaceZone:onPlayerPutItem(player, item)
	if self:isEmployee(player) and not WWP_WorkplaceZone.debug then return end
	if WL_Utils.isStaff(player) then return end
	if not putItemBuffer then putItemBuffer = {} end
	insertToBuffer(putItemBuffer, self.id, player:getUsername(), item:getFullType())
end

function WWP_WorkplaceZone:onPlayerTakeItem(player, item)
	if self:isEmployee(player) and not WWP_WorkplaceZone.debug then return end
	if WL_Utils.isStaff(player) then return end
	if not takeItemBuffer then takeItemBuffer = {} end
	insertToBuffer(takeItemBuffer, self.id, player:getUsername(), item:getFullType())
end

local function processBuffers()
	if bufferTimeout > 0 then
		bufferTimeout = bufferTimeout - 1
		return
	end
	if putItemBuffer then
		sendClientCommand(getPlayer(), "WastelandWorkplaces", "PutItems", putItemBuffer)
		putItemBuffer = nil
	end
	if takeItemBuffer then
		sendClientCommand(getPlayer(), "WastelandWorkplaces", "TakeItems", takeItemBuffer)
		takeItemBuffer = nil
	end
end

Events.OnTick.Add(processBuffers)