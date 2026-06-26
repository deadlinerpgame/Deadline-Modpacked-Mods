---
--- WWP_Town.lua
--- 17/07/2024
---
require 'WL_Utils'

WWP_Town = WLBaseObject:derive("WWP_Town")

--- @type table WWP_Town[]
WWP_Towns = WWP_Towns or {}

--- Get all towns at a given location
--- @param x number
--- @param y number
--- @param z number
---@return table WWP_Town or nil
function WWP_Town.findTownAt(x, y, z)
	for _, town in pairs(WWP_Towns) do
		if town.zone:isInZone(x, y, z) then
			return town
		end
	end
	return nil
end

---@param townId string the ID of the town to find. This can be nil, in which case nil will also be returned.
---@return table WWP_Town can be nil if no town matches the ID.
function WWP_Town.findTownById(townId)
	if townId == nil then return nil end
	for _, town in pairs(WWP_Towns) do
		if town.id == townId then
			return town
		end
	end
	return nil
end

function WWP_Town.getPlayerTownMembership(username, isHubSearch)
	for _, town in pairs(WWP_Towns) do
		if town:isCitizen(username) and town:isHub() == isHubSearch then
			return town
		end
	end
	return nil
end

--- Makes a brand new town
--- @param name string human readable name
function WWP_Town.createTown(name, zoneCoordinates)
	local town = WWP_Town:new()
	town.name = name
	town.id = getRandomUUID()
	town.type = WWP_TownType.FARMING
	town.governmentType = WWP_GovernmentType.ANARCHY
	town.incomeTaxRate = 0
	town.salesTaxRate = 0
	town.citizenshipCost = 0
	town.lawsText = "This settlement is a lawless wasteland"
	town.leadership = "?"
	town.citizens = {}
	town.exiles = {}
	town.upgrades = {}
	town.commoditySettings = {}
	town.zone = WWP_TownZone:new(town, zoneCoordinates)
	WL_TriggerZones.addZone(town.zone)
	town:init()
	WWP_Towns[town.id] = town
	return town
end

--- Creates a new Town
function WWP_Town:new()
	return WWP_Town.parentClass.new(self)
end

function WWP_Town:init()
	self.zone.mapType = "Town"
	self.zone.mapColor = {0.3, 0.74, 1.0}
	self.activityTracker = WLAT_Client:new("WastelandWorkplaces", self.id)
end

function WWP_Town:setName(newName)
	self.name = newName
	self:save()
end

function WWP_Town:setLeadershipName(newName)
	self.leadership = newName
	self:save()
end

function WWP_Town:setTownType(newType)
	self.type = newType
	self:resetCommoditySettingsToDefaults()
	self:setIncomeTaxRate(self.incomeTaxRate) -- Adjusts to min/max tax rate and then calls self:save() for us
end

function WWP_Town:setGovernmentType(newType)
	self.governmentType = newType
	if newType == WWP_GovernmentType.ANARCHY then
		self.leadership = "None"
		self.citizenshipCost = 0
	end

	-- Tax rate caps may change so we need to re-cap them to be sure
	self.incomeTaxRate = math.max(self:getMinIncomeTaxRate(), math.min(self.incomeTaxRate, self:getMaxIncomeTaxRate()))
	self.salesTaxRate = math.max(self:getMinSalesTaxRate(), math.min(self.salesTaxRate, self:getMaxSalesTaxRate()))
	self:save()
end

function WWP_Town:getMinIncomeTaxRate()
	if self.governmentType == WWP_GovernmentType.ANARCHY then return 0 end
	if self.type.isHub then return 20 else return 15 end
end

function WWP_Town:getMaxIncomeTaxRate()
	if self.governmentType == WWP_GovernmentType.ANARCHY then return 0 end
	return 40
end

function WWP_Town:getMinSalesTaxRate()
	if self.governmentType == WWP_GovernmentType.ANARCHY then return 0 end
	if self.type.isHub then return 6 end
	return 4
end

function WWP_Town:getMaxSalesTaxRate()
	if self.governmentType == WWP_GovernmentType.ANARCHY then return 0 end
	return 30
end

function WWP_Town:setIncomeTaxRate(newTaxRate)
	local newRate = tonumber(newTaxRate)
	assert(newRate, "Tax rate is not a number")
	self.incomeTaxRate = math.max(self:getMinIncomeTaxRate(), math.min(newRate, self:getMaxIncomeTaxRate()))
	self:save()
end

function WWP_Town:setSalesTaxRate(newTaxRate)
	local newRate = tonumber(newTaxRate)
	assert(newRate, "Tax rate is not a number")
	self.salesTaxRate = math.max(self:getMinSalesTaxRate(), math.min(newRate, self:getMaxSalesTaxRate()))
	self:save()
end

function WWP_Town:setCitizenshipCost(newCost)
	local newCostNum = tonumber(newCost)
	assert(newCostNum, "Citizen cost is not a number")
	newCostNum = math.max(0, newCostNum)
	self.citizenshipCost = newCostNum
	self:save()
end

function WWP_Town:isHub()
	return self.type.isHub == true
end

function WWP_Town:getCitizenCount()
	local count = 0
	for _ in pairs(self.citizens) do
		count = count + 1
	end
	return count
end

function WWP_Town:getExportDuty()
	return 20 -- Hardcoded for now. Later we can allow players to set this.
end

function WWP_Town:isCitizen(username)
	return self.citizens[username] ~= nil
end

function WWP_Town:getGovernmentRankName(rankNumber)
	return WWP_TownRank.DEFAULT_RANK_NAMES[rankNumber] -- Later we can allow customisation of these
end

function WWP_Town:getPlayerPermissionLevel()
	if WL_Utils.canModerate(getPlayer()) then return WWP_TownRank.STAFF end
	return self:getGovernmentRank(getPlayer():getUsername())
end

--- Get the salary for a player in the town zone, if any. Can be safely called for anyone, including non-citizens
---@return number between 0 and 2, can be a decimal. Never nil.
function WWP_Town:getSalary(username)
	local playerRank = self:getGovernmentRank(username)
	if playerRank <= WWP_TownRank.CITIZEN then
		return 0 -- Not a town employee
	elseif playerRank == WWP_TownRank.ENFORCEMENT_LOWEST then
		return 10
	elseif playerRank == WWP_TownRank.ENFORCEMENT_OFFICER then
		return 11
	elseif playerRank == WWP_TownRank.ENFORCEMENT_MANAGER then
		return 12
	elseif playerRank == WWP_TownRank.ENFORCEMENT_LIEUTENANT then
		return 13
	elseif playerRank == WWP_TownRank.ENFORCEMENT_HIGHEST then
		return 14
	elseif playerRank == WWP_TownRank.ENFORCEMENT_LEADER then
		return 16
	elseif playerRank == WWP_TownRank.GOVERNMENT_LOWEST then
		return 10
	elseif playerRank == WWP_TownRank.GOVERNMENT_CLERK then
		return 11
	elseif playerRank == WWP_TownRank.GOVERNMENT_MANAGER then
		return 12
	elseif playerRank == WWP_TownRank.GOVERNMENT_ADVISOR then
		return 14
	elseif playerRank == WWP_TownRank.GOVERNMENT_HIGHEST then
		return 15
	elseif playerRank >= WWP_TownRank.TOWN_LEADER then
		return 20
	else
		return 0 -- Default case, shouldn't occur with given ranks
	end
end

---@return number of government rank, 0 if just a citizen, -1 if not even a citizen here. Never nil.
function WWP_Town:getGovernmentRank(username)
	return self.citizens[username] or -1
end

function WWP_Town:setGovernmentRank(username, rank)
	self.citizens[username] = rank
	self:save()
end

function WWP_Town:setLaws(lawsText)
	self.lawsText = lawsText
	self:save()
end

WWP_Town.COMMODITY_UPKEEP = {
	[WWP_Commodity.FARM_PRODUCE] = 1,
	[WWP_Commodity.LUMBER] = 0,
	[WWP_Commodity.METAL_SALVAGE] = 0,
}

WWP_Town.COMMODITY_UPKEEP_NPC_HUB = {
	[WWP_Commodity.FARM_PRODUCE] = 10,
	[WWP_Commodity.LUMBER] = 9,
	[WWP_Commodity.METAL_SALVAGE] = 5,
}

function WWP_Town:getUpkeep(commodity)
	local upkeep = 0
	if self:isHub() then
		upkeep = upkeep + (WWP_Town.COMMODITY_UPKEEP_NPC_HUB[commodity] or 0)
	else
		upkeep = upkeep + (WWP_Town.COMMODITY_UPKEEP[commodity] or 0)
	end
	for _, upgrade in pairs(self.upgrades) do
		if upgrade.upkeep then
			upkeep = upkeep + (upgrade.upkeep[commodity] or 0)
		end
	end
	return upkeep
end

--TODO base on season/number of citizens?
function WWP_Town:updateCommodityMonthlyTransactions()
	for _, commodity in pairs(WWP_Commodity) do
		if not commodity.disabled then
			local transactions = { withdrawals = {
				["upkeep"] = self:getUpkeep(commodity)
			}}
			WWP_TownLedger.updateMonthlyCommodityUsage(self, commodity, transactions)
		end
	end
end

function WWP_Town:addCitizen(username)
	self.activityTracker:recordActivity(username)
	self.citizens[username] = WWP_TownRank.CITIZEN
	self:save()
end

function WWP_Town:removeCitizen(username)
	self.activityTracker:clearActivity(username)
	self.citizens[username] = nil
	self:save()
end

function WWP_Town:isExile(username)
	return self.exiles[username] ~= nil
end

function WWP_Town:addExile(username)
	self.exiles[username] = true
	self:save()
end

function WWP_Town:removeExile(username)
	self.exiles[username] = nil
	self:save()
end

function WWP_Town:getExileCost()
	if self.type.isHub then return 50 end
	return 10
end

function WWP_Town:hasUpgrade(upgrade)
	return self.upgrades[upgrade.key] ~= nil
end

function WWP_Town:addUpgrade(upgrade)
	self.upgrades[upgrade.key] = upgrade
	self:save()
	self:updateMonthlyTransactions()
end

function WWP_Town:removeUpgrade(upgrade)
	self.upgrades[upgrade.key] = nil
	self:save()
	self:updateMonthlyTransactions()
end

function WWP_Town:updateMonthlyTransactions()
	local transactions = { deposits = {} }
	for _, upgrade in pairs(self.upgrades) do
		if upgrade.revenue then
			transactions.deposits[upgrade.key] = upgrade.revenue
		end
	end
	WWP_TownLedger.getClient():setMonthlyTransactions(self.id, transactions)
end

function WWP_Town:getWorkplaces()
	local zonesFound = {}
	for _, workplace in pairs(WWP_WorkplaceZone.getAllZones()) do
		if self.zone:isInZone(workplace.minX, workplace.minY, workplace.minZ) then
			table.insert(zonesFound, workplace)
		end
	end
	return zonesFound
end

---@return number the bonus guilders the player is paid for working here e.g. pass in 1 and get back 0.17 if 17% bonus
function WWP_Town:getSalaryBonus(baseSalary, isCustomer, workplaceTypeKey)
	local bonus = 0
	if isCustomer then
		local customerBonus = self.type.customerWorkplaceBonus
		if customerBonus then
			bonus = bonus + (baseSalary * (customerBonus/100))
		end
	end

	if self.type.improvedWorkplaces then
		for _, improvedType in ipairs(self.type.improvedWorkplaces) do
			if improvedType == workplaceTypeKey then
				bonus = bonus + (baseSalary * 0.1)
			end
		end
	end

	local incomeBonus = self.governmentType.incomeBonus
	if incomeBonus and incomeBonus > 0 then
		bonus = bonus + (baseSalary *  (incomeBonus/100))
	end

	return bonus
end

local function findTownTypeByKey(key)
	for _, townType in pairs(WWP_TownType) do
		if townType.key == key then
			return townType
		end
	end
	return nil
end

local function findGovernmentTypeByKey(key)
	for _, governmentType in pairs(WWP_GovernmentType) do
		if governmentType.key == key then
			return governmentType
		end
	end
	return nil
end

local function deserialiseUpgrades(keysTable)
	local upgrades = {}
	if not keysTable then return upgrades end
	for _, key in ipairs(keysTable) do
		for _, upgrade in pairs(WWP_TownUpgrade) do
			if upgrade.key == key then
				upgrades[key] = upgrade
				break
			end
		end
	end
	return upgrades
end

local function serialiseUpgrades(upgrades)
	local keys = {}
	if not upgrades then return keys end
	for key, _ in pairs(upgrades) do
		table.insert(keys, key)
	end
	return keys
end

WWP_Town.SALE_MARKUP = 1.3
WWP_Town.MAX_STORAGE = 200
WWP_Town.DEFAULT_BUY_UP_TO = 20
WWP_Town.DEFAULT_SELL_DOWN_TO = 15

function WWP_Town:getBuyPrice(commodity, quantity)
	local minPrice = commodity.minPrice
	local maxPrice = commodity.maxPrice
	if self.type.priceModifiers then
		local modifier = self.type.priceModifiers[commodity]
		if modifier then
			minPrice = minPrice + modifier
			maxPrice = maxPrice + modifier
		end
	end

	local invertedRatio = 1 - (quantity / WWP_Town.MAX_STORAGE)
	if invertedRatio < 0 then
		invertedRatio = 0
	elseif invertedRatio > 1 then
		invertedRatio = 1
	end

	local decimal = (minPrice + (maxPrice - minPrice) * invertedRatio)
	return math.floor(decimal + 0.5) -- Round to nearest integer
end

function WWP_Town:getSellPrice(commodity, quantity)
	local decimal = self:getBuyPrice(commodity, quantity) * WWP_Town.SALE_MARKUP
	return math.floor(decimal+0.5) -- Round to nearest integer
end

function WWP_Town:isSpecialistCommodity(commodity)
	return self.type.workPointMultipliers and self.type.workPointMultipliers[commodity] ~= nil
end

function WWP_Town:getDefaultCommoditySettingsForType(commodity, townType)
	if townType == WWP_TownType.NPC_HUB then
		return {
			buyUpTo = WWP_Town.MAX_STORAGE,
			sellDownTo = 0,
		}
	elseif townType.workPointMultipliers and townType.workPointMultipliers[commodity] ~= nil then
		return {
			buyUpTo = WWP_Town.MAX_STORAGE,
			sellDownTo = WWP_Town.DEFAULT_SELL_DOWN_TO,
		}
	end

	return {
		buyUpTo = WWP_Town.DEFAULT_BUY_UP_TO,
		sellDownTo = WWP_Town.DEFAULT_SELL_DOWN_TO,
	}
end

function WWP_Town:getDefaultCommoditySettings(commodity)
	return self:getDefaultCommoditySettingsForType(commodity, self.type)
end

function WWP_Town:resetCommoditySettingsToDefaults()
	for _, commodity in pairs(WWP_Commodity) do
		if not commodity.disabled then
			self.commoditySettings[commodity.key] = self:getDefaultCommoditySettings(commodity)
		end
	end
end

local function clampCommodityThreshold(amount)
	local number = tonumber(amount) or 0
	number = math.floor(number)
	return math.max(0, math.min(number, WWP_Town.MAX_STORAGE))
end

function WWP_Town:getCommoditySettings(commodity)
	if not self.commoditySettings[commodity.key] then
		self.commoditySettings[commodity.key] = self:getDefaultCommoditySettings(commodity)
	end

	local settings = self.commoditySettings[commodity.key]

	-- BACK COMPAT: Converts old isBuying/isSelling settings to buyUpTo/sellDownTo.
	-- Added for the warehouse threshold migration. Safe to remove after old town saves
	-- have aged out, around September 2026.
	if settings.buyUpTo == nil then
		if settings.isBuying == false then
			settings.buyUpTo = 0
		else
			settings.buyUpTo = WWP_Town.MAX_STORAGE
		end
	end
	if settings.sellDownTo == nil then
		if settings.isSelling == false then
			settings.sellDownTo = WWP_Town.MAX_STORAGE
		else
			settings.sellDownTo = 0
		end
	end

	return self.commoditySettings[commodity.key]
end

function WWP_Town:getBuyUpTo(commodity)
	return self:getCommoditySettings(commodity).buyUpTo
end

function WWP_Town:setBuyUpTo(commodity, amount)
	local settings = self:getCommoditySettings(commodity)
	settings.buyUpTo = clampCommodityThreshold(amount)
	self:save()
end

function WWP_Town:getSellDownTo(commodity)
	return self:getCommoditySettings(commodity).sellDownTo
end

function WWP_Town:setSellDownTo(commodity, amount)
	local settings = self:getCommoditySettings(commodity)
	settings.sellDownTo = clampCommodityThreshold(amount)
	self:save()
end

function WWP_Town:isBuying(commodity, quantity)
	quantity = quantity or 0
	return quantity < self:getBuyUpTo(commodity)
end

function WWP_Town:isSelling(commodity, quantity)
	quantity = quantity or 0
	return quantity > self:getSellDownTo(commodity)
end

function WWP_Town:updateFrom(serialisedData)
	self.name = serialisedData.name
	self.id = serialisedData.id
	self.type = findTownTypeByKey(serialisedData.typeKey)
	self.governmentType = findGovernmentTypeByKey(serialisedData.governmentTypeKey)
	self.incomeTaxRate = serialisedData.incomeTaxRate
	self.salesTaxRate = serialisedData.salesTaxRate
	self.citizenshipCost = serialisedData.citizenshipCost
	self.lawsText = serialisedData.lawsText
	self.leadership = serialisedData.leadership
	self.citizens = serialisedData.citizens
	self.exiles = serialisedData.exiles
	self.commoditySettings = serialisedData.commoditySettings or {}
	self.upgrades = deserialiseUpgrades(serialisedData.upgrades)
	if not self.zone then
		self.zone = WWP_TownZone:new(self, serialisedData.zone)
		WL_TriggerZones.addZone(self.zone)
	else
		self.zone:setAreaFromTable(serialisedData.zone)
	end
	self:init()
end

function WWP_Town:save()
	self:updateCommodityMonthlyTransactions()
	local serialisedData = {
		id = self.id,
		name = self.name,
		typeKey = self.type.key,
		governmentTypeKey = self.governmentType.key,
		incomeTaxRate = self.incomeTaxRate,
		salesTaxRate = self.salesTaxRate,
		citizenshipCost = self.citizenshipCost,
		lawsText = self.lawsText,
		leadership = self.leadership,
		citizens = self.citizens,
		exiles = self.exiles,
		commoditySettings = self.commoditySettings,
		upgrades = serialiseUpgrades(self.upgrades),
		zone = self.zone:toCoordinatesTable(),
	}
	WWP_TownSystem:saveTown(getPlayer(), serialisedData)
end

function WWP_Town:delete()
	WWP_TownSystem:deleteTown(getPlayer(), self.id)
end

function WWP_Town:dispose()
	WL_TriggerZones.removeZone(self.zone)
	self.zone:delete()
end
