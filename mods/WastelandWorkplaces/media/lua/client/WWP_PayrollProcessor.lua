---
--- WWP_PayrollProcessor.lua
--- 27/07/2024
---

WWP_PayrollProcessor = {}
WWP_PayrollProcessor.DEFAULT_CURRENCY = "GoldCurrency"
WWP_PayrollProcessor.DEFAULT_WORK_POINTS_PER_TICK = 5

--- Pays a salary after deducting tax. Decimals are resolved via RNG. This function assumes town bonuses have already
--- been applied (e.g. +10% to bars or whatever)
---@param baseSalaryDecimal number can be decimal, must 0 or higher
---@param town table|nil the local town, can be nil if the player is not in one
---@param salarySource string describing the source of income e.g. Waitress, Bar, Mayor. Should be capitalised.
---@param townSalaryCategory string optional parameter, if set then the town will pay from treasury instead of taxing
function WWP_PayrollProcessor.paySalary(player, currency, baseSalaryDecimal, town, salarySource, townSalaryCategory)
	if baseSalaryDecimal == 0 then return end
	local salaryInteger = WWP_PayrollProcessor.randomRound(baseSalaryDecimal)
	local username = player:getUsername()

	if town and town:isExile(username) then
		WL_Utils.addToChat("You are an exile here and cannot earn wages", { color = "1.0,0.2,0", })
		return
	end

	if townSalaryCategory then
		WWP_PayrollProcessor.payTownSalary(player, town, salaryInteger, salarySource, townSalaryCategory, currency)
	else
		WWP_PayrollProcessor.payRegularSalary(player, salaryInteger, salarySource, town, currency)
	end
end

function WWP_PayrollProcessor.payTownSalary(player, town, salaryInteger, salarySource, townSalaryCategory, currency)
	WWP_TownLedger.getClient():attemptWithdrawal(town.id, salaryInteger, townSalaryCategory,
			function(_, success, newBalance)
				if success then
					WWP_PlayerStats.deductWorkPoints(player, WWP_TownZone.PAY_WORK_POINTS_DEDUCTED)
					WWP_PayrollProcessor.giveCurrency(player, currency, salaryInteger)
					WWP_PayrollProcessor.reportSalary(player, salarySource, salaryInteger, "",
							76, 154, 237)
				else
					player:setHaloNote("Your town is bankrupt and can't pay you", 250, 20, 60, 800.0)
				end
			end)
end

--- Deducts work points, calculates tax (if applicable), gives currency, and reports the salary to a player.
---@param player IsoPlayer the player to pay
---@param salary number whole number expected, of the salary to be paid
---@param salarySource string describing the source of income e.g. Waitress, Bar, Mayor. Should be capitalised.
---@param town table|nil the local town, can be nil if the player is not in one. Nil here means no tax is applied.
---@param currency string|nil the currency item to give, or nil for our default (WWP_PayrollProcessor.DEFAULT_CURRENCY)
function WWP_PayrollProcessor.payRegularSalary(player, salary, salarySource, town, currency)
	local taxRate = WWP_PayrollProcessor.calculateTaxRate(town, player:getUsername())
	local finalSalary = salary
	local taxInteger = 0
	local taxRateString = ""

	if taxRate > 0 then
		taxInteger = WWP_PayrollProcessor.calculateTax(salary, taxRate)
		if taxInteger > 0 and town.type ~= WWP_TownType.NPC_HUB then
			WWP_TownLedger.getClient():makeDeposit(town.id, taxInteger, WWP_TownLedger.INCOME_TAX)
		end
		taxRateString = " (" .. tostring(taxInteger) .. " lost to " .. tostring(taxRate) ..  "% tax)"
		finalSalary = salary - taxInteger
	end

	WWP_PlayerStats.deductWorkPoints(player, WWP_PayrollProcessor.DEFAULT_WORK_POINTS_PER_TICK)
	WWP_PayrollProcessor.giveCurrency(player, currency, finalSalary)
	WWP_PayrollProcessor.reportSalary(player, salarySource, finalSalary, taxRateString, 253, 216, 12)
end

function WWP_PayrollProcessor.calculateTaxRate(town, username)
	if not town then return 0 end

	local taxRate = town.incomeTaxRate
	if not town:isCitizen(username) then
		taxRate = taxRate + 20
		WL_Utils.addToChat("Non-citizen status incurs an extra 20% tax on your earnings in this town.",
				{ color = "1.0,0.5,0", })
	end
	return taxRate
end

---@param income number expected to be a whole number, of the income to be taxed
---@param taxRate number between 0 and 100
---@return number a whole number representing the money lost to tax. This needs to be deducted from the income.
function WWP_PayrollProcessor.calculateTax(salary, taxRate)
	local taxRateDecimal = taxRate / 100 -- Convert tax rate to decimal (e.g., 40% becomes 0.4)
	local taxDecimal = salary * taxRateDecimal  -- Calculate the exact tax amount (can be a decimal) e.g. 4 * 0.4 = 1.6
	local taxInteger = math.floor(taxDecimal)  -- Get the integer part of the tax e.g. 1 or 2
	local taxFraction = taxDecimal - taxInteger  -- -- Calculate the fractional part of the tax e.g. 1.6 - 1 = 0.6

	-- Determine if the fractional part goes to tax or salary
	local randomChance = ZombRand(0, 100)  -- Returns a number from 0 to 99
	if randomChance < (taxFraction * 100) then
		taxInteger = taxInteger + 1 -- If the random number is less than the fractional part * 100, round up
	end
	return taxInteger
end

function WWP_PayrollProcessor.giveCurrency(player, currency, currencyAmount)
	if currency == nil then
		currency = WWP_PayrollProcessor.DEFAULT_CURRENCY
	end

	if currency == WWP_PayrollProcessor.DEFAULT_CURRENCY then
		WIT_Gold.addAmountToPlayer(player, currencyAmount)
	else
		local inventory = player:getInventory()
		for _ = 1, currencyAmount do
			inventory:AddItem(currency)
		end
	end

	getSoundManager():playUISound(WIT_Gold.CurrencySound)
end

function WWP_PayrollProcessor.reportSalary(player, salarySource, salary, taxRateString, r, g, b)
	if not taxRateString then taxRateString = "" end
	local salaryStr = salarySource .. " salary: " .. tostring(salary) .. taxRateString
	salaryStr = salaryStr .. "\n"  .. WWP_PlayerStats.getWorkPointsRemainingString(player)
	player:setHaloNote(salaryStr, r, g, b, 800.0)
end

--- Takes a decimal and rounds it up or down randomly according to how close it is to either whole number
function WWP_PayrollProcessor.randomRound(number)
	local integerPart = math.floor(number)
	if integerPart == number then return number
	end
	local decimalPart = number - integerPart
	local randomChance = ZombRand(0, 100) -- ZombRand(0, 100) will return a number from 0 to 99
	if randomChance < (decimalPart * 100) then -- If the random number is less than the decimal part * 100, round up
		return integerPart + 1
	else
		return integerPart
	end
end