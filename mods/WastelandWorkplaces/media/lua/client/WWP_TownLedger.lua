---
--- WWP_TownLedger.lua
--- 11/08/2024
---
require 'WLE_Client'

WWP_TownLedger = {}
WWP_TownLedger.MAX_OVERDRAFT = 30000

-- Deposits
WWP_TownLedger.INCOME_TAX = "incomeTax"
WWP_TownLedger.SALES_TAX = "salesTax"
WWP_TownLedger.CITIZENSHIP_FEE = "citizenshipFee"
WWP_TownLedger.MANUALLY_ADDED = "manuallyAdded"
WWP_TownLedger.EXPORT_DUTY = "exportDuty"

-- Withdrawals
WWP_TownLedger.SALARY_CIVIL = "salaryGovernment"
WWP_TownLedger.SALARY_ENFORCEMENT = "salaryEnforcement"
WWP_TownLedger.STAFF_REMOVAL = "staffRemoval"
WWP_TownLedger.EXILE_FEE = "exileFee"

-- Commodities
WWP_TownLedger.DONATION = "donation"
WWP_TownLedger.GOODS_BOUGHT = "bought"
WWP_TownLedger.GOODS_SOLD = "sold"

function WWP_TownLedger.getClient()
	return WLE_Client.getClient("WastelandTowns", WWP_TownLedger.MAX_OVERDRAFT)
end

function WWP_TownLedger.fetchCommodityBalance(town, commodity, callback, target)
	local client = WLE_Client.getClient("WastelandTowns") -- No overdraft for commodities
	client:fetchBalance(town.id .. "_" .. commodity.key, callback, target)
end

function WWP_TownLedger.makeCommodityDeposit(town, commodity, amount, category, callback, target)
	local client = WLE_Client.getClient("WastelandTowns") -- No overdraft for commodities
	client:makeDeposit(town.id .. "_" .. commodity.key, amount, category, callback, target)
end

function WWP_TownLedger.attemptCommodityWithdrawal(town, commodity, amount, category, callback, target)
	local client = WLE_Client.getClient("WastelandTowns") -- No overdraft for commodities
	client:attemptWithdrawal(town.id .. "_" .. commodity.key, amount, category, callback, target)
end

function WWP_TownLedger.updateMonthlyCommodityUsage(town, commodity, transactions)
	local client = WLE_Client.getClient("WastelandTowns") -- No overdraft for commodities
	client:setMonthlyTransactions(town.id .. "_" .. commodity.key, transactions)
end

function WWP_TownLedger.getPurchaseCategory(commodity)
	return "bought_" .. commodity.key
end

function WWP_TownLedger.getSaleCategory(commodity)
	return "sold_" .. commodity.key
end