---
--- WWP_TownZone.lua
--- 26/07/2024
---

WWP_TownZone = WL_Zone:derive("WWP_TownZone")

--- How frequently town employees are paid
WWP_TownZone.PAY_FREQUENCY_MINUTES = 10

--- How many work points are used each salary pay tick
WWP_TownZone.PAY_WORK_POINTS_DEDUCTED = 5

--- How much town workers are paid
WWP_TownZone.WORKER_SALARY = 1.8

function WWP_TownZone:new(town, zoneCoordinates)
	local o = WL_Zone.createFromTable(zoneCoordinates)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	return o
end

function WWP_TownZone:getMapName()
	return self.town.name
end

function WWP_TownZone:getWorkPointsText()
	local playerRank = self.town:getGovernmentRank(getPlayer():getUsername())
	if playerRank > WWP_TownRank.CITIZEN then
		return "\n" .. WWP_PlayerStats.getWorkPointsRemainingString(getPlayer())
	end
	return ""
end

function WWP_TownZone:showTownInfo(player, prefix)
	local message
	if prefix then
		message = prefix .. " " .. self.town.name
	else
		message = self.town.name
	end

	if self.town:isExile(player:getUsername()) then
		message = message .. "\nYou are an exile here"
		player:setHaloNote(message, 250, 20, 60, 500.0)
		return
	end

	message = message .. self:getWorkPointsText()

	local workplaces = self.town:getWorkplaces()
	local openWorkplaces = {}
	for _, workplace in ipairs(workplaces) do
		if workplace.open and workplace.autoClose then
			table.insert(openWorkplaces, workplace)
		end
	end

	if #openWorkplaces > 0 then
		message = message .. "\nOpen now: "
		local limit = math.min(8, #openWorkplaces)
		for i = 1, limit do
			local workplace = openWorkplaces[i]
			if i == 5 then
				message = message .. "\n"
			end
			message = message .. workplace.name
			if i < limit and i ~= 4 then
				message = message .. ", "
			end
		end
	end

	player:setHaloNote(message, 76, 154, 237, 500.0)
end

--- To be called when a player enters the zone bounds
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @see WL_TriggerZones
function WWP_TownZone:onPlayerEnteredZone(player)
	local username = player:getUsername()
	if self.town:isCitizen(username) then
		self.town.activityTracker:recordActivity(username)
	end
	self:showTownInfo(player, "Entering")
	WWP_TownSystem:touchTown(player, self.town.id)
end

--- To be called when a player exits the zone bounds
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @see WL_TriggerZones
function WWP_TownZone:onPlayerExitedZone(player)
	local username = player:getUsername()
	if self.town:isCitizen(username) then
		self.town.activityTracker:recordActivity(username)
	end
	local message = "Leaving " .. self.town.name
	message = message .. self:getWorkPointsText()
	player:setHaloNote(message, 200, 200, 200, 350.0)
end

--- To be called when a player has remained inside the zone bounds for a minute, and each minute after
--- This function is a placeholder designed for override and only called if the zone if the zone is registered
--- @param player IsoPlayer remaining
--- @param minutesPassed number of minutes that the player has been inside the zone
--- @see WL_TriggerZones
function WWP_TownZone:onPlayerStayedForMinute(player, minutesPassed)
	if self.town:hasUpgrade(WWP_TownUpgrade.FESTIVALS) then
		local boredomAdjust =  player:getBodyDamage():getBoredomLevel()
		if(boredomAdjust > 0) then
			boredomAdjust = math.max(0, boredomAdjust - 10)
			player:getBodyDamage():setBoredomLevel(boredomAdjust)
		end
		local sadnessAdjust = player:getBodyDamage():getUnhappynessLevel()
		if(sadnessAdjust > 0) then
			sadnessAdjust = math.max(0, sadnessAdjust - 10)
			player:getBodyDamage():setUnhappynessLevel(sadnessAdjust)
		end
	end

	if(minutesPassed % WWP_TownZone.PAY_FREQUENCY_MINUTES) == 0 then
		if not WWP_Options.workInTowns then return end

		local salary = self.town:getSalary(player:getUsername())
		if salary == 0 then return end

		if WWP_Factions.getFactionRank(player) then
			return -- Faction members can't work in towns
		end

		local workplaces = WWP_WorkplaceZone.getZonesAt(player:getX(), player:getY(), player:getZ())
		for _, workplace in ipairs(workplaces) do
			if workplace:isEmployee(player) then return end -- Workplaces override town employment
		end

		local playerRank = self.town:getGovernmentRank(player:getUsername())
		local townSalaryCategory
		if WWP_TownRank.isEnforcement(playerRank) then
			townSalaryCategory = WWP_TownLedger.SALARY_ENFORCEMENT
		else
			townSalaryCategory = WWP_TownLedger.SALARY_CIVIL
		end

		if(WWP_PlayerStats.hasPointsAvailable(player, WWP_TownZone.PAY_WORK_POINTS_DEDUCTED)) then
			WWP_PayrollProcessor.paySalary(player, WWP_PayrollProcessor.DEFAULT_CURRENCY, WWP_TownZone.WORKER_SALARY,
					self.town, self.town:getGovernmentRankName(playerRank), townSalaryCategory)
		end
	end
end