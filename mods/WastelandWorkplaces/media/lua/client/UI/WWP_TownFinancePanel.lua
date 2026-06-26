---
--- WWP_TownFinancePanel.lua
--- 11/08/2024
---


require "GravyUI_WL"

WWP_TownFinancePanel = ISPanel:derive("WWP_TownEmployeesPanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)
local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}
local COLOR_RED = {r=1,g=0,b=0,a=1}
local COLOR_GREEN = {r=0,g=1,b=0,a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
	return px * SCALE
end

function WWP_TownFinancePanel:new(x, y, width, height, town, townPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
	o.town = town
	o.townPanel = townPanel
	o.labelsToUpdate = {} -- Format: { ledgeKey = label }
	o:initialise()
	return o
end


function WWP_TownFinancePanel:initialise()
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(15, 15, 15, 20)
	local rowPadding = 15
	local currentBalance, remainder = win:rows({ FONT_HGT_LARGE, win.height - FONT_HGT_LARGE - rowPadding}, rowPadding)

	local balanceDescLabel, balanceLabel = currentBalance:cols( { 0.2, 0.8 }, 10)
	balanceDescLabel:makeLabel("Treasury Balance: ", UIFont.Large, COLOR_WHITE, "left")
	self.balanceLabel = balanceLabel:makeLabel("", UIFont.Large, COLOR_YELLOW, "left")

	local balanceSheet, buttonRow = remainder:rows(
			{ remainder.height - FONT_HGT_LARGE - 20, FONT_HGT_LARGE }, 20)
	local incomeArea, expensesArea = balanceSheet:cols({0.5, 0.5} , 10)
	local incomeHeader, incomeBreakdown = incomeArea:rows({ FONT_HGT_LARGE, incomeArea.height - FONT_HGT_LARGE - rowPadding}, rowPadding)

	local revenueDescription, revenueValue = incomeHeader:cols({ 0.6, 0.4 }, 10)
	revenueDescription:makeLabel("Revenue", UIFont.Large, COLOR_WHITE, "left")
	self.labelsToUpdate["totalRevenue"] = revenueValue:makeLabel("0", UIFont.Large, COLOR_GREEN, "left")
	local incomeStack = incomeBreakdown:makeVerticalStack(scale(10))
	self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "Income Tax:", WWP_TownLedger.INCOME_TAX, scale(10), COLOR_GREEN)
	self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "Sales Tax:", WWP_TownLedger.SALES_TAX, scale(10), COLOR_GREEN)
	self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "Export Duty:", WWP_TownLedger.EXPORT_DUTY, scale(10), COLOR_GREEN)
	self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "New Citizens:", WWP_TownLedger.CITIZENSHIP_FEE, scale(10), COLOR_GREEN)
	self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "Cash Injection:", WWP_TownLedger.MANUALLY_ADDED, scale(10), COLOR_GREEN)

	for _, commodity in pairs(WWP_Commodity) do
        if not commodity.disabled then
			self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), "Sale of " .. commodity.name .. ":", WWP_TownLedger.getSaleCategory(commodity), scale(10), COLOR_GREEN)
		end
	end

	for _, upgrade in pairs(WWP_TownUpgrade) do
		if upgrade.revenue and self.town:hasUpgrade(upgrade) then
			self:createLabeledField(incomeStack:makeNode(FONT_HGT_MEDIUM), upgrade.name .. ":", upgrade.key, scale(10), COLOR_GREEN)
		end
	end

	local expensesHeader, expensesBreakdown = expensesArea:rows({ FONT_HGT_LARGE, expensesArea.height - FONT_HGT_LARGE - rowPadding}, rowPadding)

	local expensesDescription, expensesValue = expensesHeader:cols({ 0.6, 0.4 }, 10)
	expensesDescription:makeLabel("Expenses", UIFont.Large, COLOR_WHITE, "left")
	self.labelsToUpdate["totalExpenses"] = expensesValue:makeLabel("0", UIFont.Large, COLOR_RED, "left")

	local expenses = {
		{ label = "Civil Salaries:", key = WWP_TownLedger.SALARY_CIVIL },
		{ label = "Enforcement Salaries:", key = WWP_TownLedger.SALARY_ENFORCEMENT },
		{ label = "Exile Fees:", key = WWP_TownLedger.EXILE_FEE },
		{ label = "Special Projects:", key = WWP_TownLedger.STAFF_REMOVAL }
	}
	for _, commodity in pairs(WWP_Commodity) do
        if not commodity.disabled then
			table.insert(expenses, { label = "Purchase of " .. commodity.name .. ":", key = WWP_TownLedger.getPurchaseCategory(commodity) })
		end
	end

	local rowHeights = {}
	for i = 1, #expenses do
		rowHeights[i] = FONT_HGT_MEDIUM
	end

	local rows = {expensesBreakdown:rows(rowHeights, scale(10))}
	for i, expense in ipairs(expenses) do
		self:createLabeledField(rows[i], expense.label, expense.key, scale(10), COLOR_RED)
	end

	local changeSalesTaxRate, changeIncomeTaxRate, changeCitizenshipFee, injectCash, removeCash = buttonRow:cols({ 0.2, 0.2, 0.2, 0.2, 0.2, 0.2 }, 20)
	self.changeSalesTaxRateButton = changeSalesTaxRate:makeButton("Adjust Sales Tax", self, self.changeSalesTaxRate)
	self.changeTaxRateButton = changeIncomeTaxRate:makeButton("Adjust Income Tax", self, self.changeIncomeTaxRate)
	self.changeCitizenshipFeeButton = changeCitizenshipFee:makeButton("Adjust Citizen Fee", self, self.changeCitizenshipFee)
	self.injectCashButton = injectCash:makeButton("Inject Funds", self, self.injectCash)
	self.removeCashButton = removeCash:makeButton("Remove Funds", self, self.removeCash)

	local rank = self.town:getPlayerPermissionLevel()
	self.changeTaxRateButton.enable = rank >= WWP_TownRank.GOVERNMENT_MANAGER
	self.changeSalesTaxRateButton.enable = rank >= WWP_TownRank.GOVERNMENT_MANAGER
	self.changeCitizenshipFeeButton.enable = rank >= WWP_TownRank.GOVERNMENT_MANAGER
	self.removeCashButton:setVisible(rank >= WWP_TownRank.STAFF)
	self:fetchLatestLedger()
end

function WWP_TownFinancePanel:createLabeledField(parent, labelText, ledgerKey, padding, color)
	local descriptionLabel, valueLabel = parent:cols({ 0.6, 0.4 }, padding)
	descriptionLabel:makeLabel(labelText, UIFont.Medium, COLOR_WHITE, "left")
	self.labelsToUpdate[ledgerKey] = valueLabel:makeLabel("0", UIFont.Medium, color, "left")
	return descriptionLabel, valueLabel
end

function WWP_TownFinancePanel:updateState()

end

function WWP_TownFinancePanel:fetchLatestLedger()
	WWP_TownLedger.getClient():fetchBalance(self.town.id, function(_, success, newBalance)
		self.balanceLabel:setText(tostring(newBalance))
	end, nil)

	WWP_TownLedger.getClient():fetchLedger(self.town.id, 5, function(_, success, result)
		if result.deposit then
			local totalIncome = 0
			for category, amount in pairs(result.deposit) do
				local label = self.labelsToUpdate[category]
				if label then
					label:setText(tostring(amount))
				end
				totalIncome = totalIncome + amount
			end
			self.labelsToUpdate["totalRevenue"]:setText(tostring(totalIncome))
		end

		if result.withdrawal then
			local totalExpenses = 0
			for category, amount in pairs(result.withdrawal) do
				local label = self.labelsToUpdate[category]
				if label then
					label:setText(tostring(amount))
				end
				totalExpenses = totalExpenses + amount
			end
			self.labelsToUpdate["totalExpenses"]:setText(tostring(totalExpenses))
		end
	end)
end

function WWP_TownFinancePanel:changeIncomeTaxRate()
	WL_TextEntryPanel:show("Enter the new income tax rate, minimum: " .. self.town:getMinIncomeTaxRate()
			.. " maximum: " .. self.town:getMaxIncomeTaxRate(),
			self.town, self.town.setIncomeTaxRate, self.town.incomeTaxRate, true, true)
end

function WWP_TownFinancePanel:changeSalesTaxRate()
	WL_TextEntryPanel:show("Enter the new sales tax rate, minimum: " .. self.town:getMinSalesTaxRate()
			.. " maximum: " .. self.town:getMaxSalesTaxRate(),
			self.town, self.town.setSalesTaxRate, self.town.salesTaxRate, true, true)
end

function WWP_TownFinancePanel:changeCitizenshipFee()
	WL_TextEntryPanel:show("Enter the new cost of becoming a citizen in this town",
			self.town, self.town.setCitizenshipCost, self.town.citizenshipCost, true, true)
end

function WWP_TownFinancePanel:injectCash()
	WL_TextEntryPanel:show("Enter the amount you want to add to the treasury", nil,
	function(_, amountString)
		local amount = tonumber(amountString)
		if not amount or amount < 1 then return end
		local isAllowed = WL_Utils.canModerate(getPlayer())
		if not isAllowed then
			isAllowed = WIT_Gold.removeAmountFromPlayer(getPlayer(), amount)
		end

		if isAllowed then
			WWP_TownLedger.getClient():makeDeposit(self.town.id, amount, WWP_TownLedger.MANUALLY_ADDED)
			self:fetchLatestLedger()
		else
			WL_Dialogs.showMessageDialog("You can't afford that.")
		end
	end, nil, true, true)
end

function WWP_TownFinancePanel:removeCash()
	WL_TextEntryPanel:show("Enter the amount you want to remove", nil,
		function(_, amountString)
			local amount = tonumber(amountString)
			if not amount or amount < 1 then return end

			local staffClient = WLE_Client.getClient("WastelandTowns", 99999)
			staffClient:attemptWithdrawal(self.town.id, amount, WWP_TownLedger.STAFF_REMOVAL,
					function(_, success, newBalance)
						if success then
							self:fetchLatestLedger()
						else
							WL_Dialogs.showMessageDialog("Error: Failed to withdraw.")
						end
					end)
		end, nil, true, true)
end