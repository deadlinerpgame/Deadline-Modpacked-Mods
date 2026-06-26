---
--- WWP_TownTradePanel.lua
--- Trade panel for town management
---

require "GravyUI_WL"
require "ISUI/ISPanel"

WWP_TownTradePanel = ISPanel:derive("WWP_TownTradePanel")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local COLOR_WHITE = {r=1,g=1,b=1,a=1}
local COLOR_YELLOW = {r=1,g=1,b=0,a=1}
local COLOR_GREEN = {r=0,g=1,b=0,a=1}
local COLOR_RED = {r=1,g=0,b=0,a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
	return px * SCALE
end

function WWP_TownTradePanel:new(x, y, width, height, town, parentPanel)
	local o = ISPanel:new(x, y, width, height)
	setmetatable(o, self)
	self.__index = self
    o.town = town
	o.parentPanel = parentPanel
	o:initialise()
	return o
end

WWP_TownTradePanel.columnSizes = {0.05, 0.35, 0.2, 0.2, 0.1, 0.1 }

function WWP_TownTradePanel:canBuyBeyondStorageLimit()
    return self.town.type == WWP_TownType.NPC_HUB
end

function WWP_TownTradePanel:addCommodityRow(winStack, commodity)
    local uiData = {}
    self.commodities[commodity] = uiData
    local row = winStack:makeNode(scale(32))
    local icon, tradeItem, sellPrice, buyPrice, buyButtonNode, sellButtonNode = row:cols(WWP_TownTradePanel.columnSizes, scale(10))
    local itemTexture = WL_Utils.getIconTexture(commodity.itemType)
    if itemTexture then icon:makeImage(itemTexture, scale(32), scale(32)) end
    tradeItem:makeLabel(commodity.name, UIFont.Large, COLOR_WHITE, "left")
    uiData.buyPriceLabel = buyPrice:makeLabel("", UIFont.Large, COLOR_WHITE, "left")
    uiData.sellPriceLabel = sellPrice:makeLabel("", UIFont.Large, COLOR_WHITE, "left")
    uiData.buyButton = buyButtonNode:makeButton("Buy", self, self.onBuyCommodity, {commodity} )
    uiData.sellButton = sellButtonNode:makeButton("Sell", self, self.onSellCommodity, {commodity} )
end

function WWP_TownTradePanel:initialise()
	ISPanel.initialise(self)
	local win =  GravyUI.Node(self.width, self.height, self)
	win = win:pad(scale(10), scale(10), scale(10), scale(10))
    local winStack = win:makeVerticalStack(scale(15))
    local columnHeaders = winStack:makeNode(scale(32))
    local _, tradeItemHeader, sellPriceHeader, buyPriceHeader, _, _ = columnHeaders:cols(WWP_TownTradePanel.columnSizes, scale(10))
    tradeItemHeader:makeLabel("Commodity", UIFont.Large, COLOR_WHITE, "left")
    buyPriceHeader:makeLabel("Price to Sell", UIFont.Large, COLOR_WHITE, "left")
    sellPriceHeader:makeLabel("Price to Buy", UIFont.Large, COLOR_WHITE, "left")

    self.commodities = {}
    for _, commodity in pairs(WWP_Commodity) do
        if not commodity.disabled then
            self:addCommodityRow(winStack, commodity)
        end
    end
    self:updateState()
end

function WWP_TownTradePanel:updateStock(commodity, quantity)
    local uiData = self.commodities[commodity]
    if not uiData then return end
    local buyPrice = self.town:getBuyPrice(commodity, quantity)
    local sellPrice = self.town:getSellPrice(commodity, quantity)
    uiData.quantity = quantity
    uiData.buyPrice = buyPrice -- Cache for later use
    uiData.sellPrice = sellPrice -- Cache for later use
    uiData.buyPriceLabel:setText(tostring(buyPrice))
    uiData.sellPriceLabel:setText(tostring(sellPrice))
    if commodity.minPrice == commodity.maxPrice then
        uiData.buyPriceLabel.color = COLOR_YELLOW
        uiData.sellPriceLabel.color = COLOR_YELLOW
    elseif buyPrice <= commodity.minPrice then
        uiData.buyPriceLabel.color = COLOR_RED
        uiData.sellPriceLabel.color = COLOR_GREEN
    elseif buyPrice >= commodity.maxPrice then
        uiData.buyPriceLabel.color = COLOR_GREEN
        uiData.sellPriceLabel.color = COLOR_RED
    else
        uiData.buyPriceLabel.color = COLOR_YELLOW
        uiData.sellPriceLabel.color = COLOR_YELLOW
    end

    if quantity <= 0 then
        uiData.hasStock = false
    else
        uiData.hasStock = true
    end

    if quantity >= WWP_Town.MAX_STORAGE then
        uiData.fullStock = true
    else
        uiData.fullStock = false
    end
    self:updateState()
end

---@return InventoryItem|nil item
---@return ItemContainer|nil container never nil when item is returned
local function findCommodityInInventory(player, commodity)
    local item = player:getInventory():getFirstTypeEvalRecurse(commodity.itemType,
            function(item) return item and (not item:IsFood() or not item:isRotten()) end)
    local container = item and item:getContainer()
    if container then
        return item, container
    else
        return nil
    end
end

function WWP_TownTradePanel:updateState()
    for commodity, uiData in pairs(self.commodities) do
        local quantity = uiData.quantity or 0
        local palletItem = findCommodityInInventory(getPlayer(), commodity)
        local townIsBuying = self.town:isBuying(commodity, quantity)
        local canBuyBeyondStorageLimit = self:canBuyBeyondStorageLimit()
        uiData.sellButton.enable = palletItem and (townIsBuying or canBuyBeyondStorageLimit) and (not uiData.fullStock or canBuyBeyondStorageLimit) and not uiData.pendingSale

        if uiData.pendingSale then
            uiData.sellButton:setTooltip("Sale is being processed.")
        elseif not townIsBuying and not canBuyBeyondStorageLimit then
            uiData.sellButton:setTooltip("Town is not looking to buy more " .. commodity.name .. " right now")
        elseif uiData.fullStock and not canBuyBeyondStorageLimit then
            uiData.sellButton:setTooltip("Fully stocked with " .. commodity.name)
        elseif uiData.fullStock then
            uiData.sellButton:setTooltip(nil)
        else
            uiData.sellButton:setTooltip(nil)
        end

        local townIsSelling = self.town:isSelling(commodity, quantity)
        uiData.buyButton.enable = townIsSelling and uiData.hasStock
        if not uiData.hasStock then
            uiData.buyButton:setTooltip("No stock remaining of " .. commodity.name)
        elseif not townIsSelling then
            uiData.buyButton:setTooltip("Town is keeping its remaining " .. commodity.name .. " in reserve")
        elseif commodity.buyWorkPoints > 0 then
            uiData.buyButton:setTooltip("Uses " .. commodity.buyWorkPoints .. " work points to buy")
        else
            uiData.buyButton:setTooltip("No work points needed to buy")
        end
    end

end

function WWP_TownTradePanel:prerender()
	ISPanel.prerender(self)
	GravyUI.prerender(self)
end

local function giveItem(player, itemType)
    local inventory = player:getInventory()
    local item = inventory:AddItem(itemType)

    if inventory:getCapacityWeight() > inventory:getEffectiveCapacity(player) then
		if inventory:contains(item) then
			inventory:Remove(item)
		end
		player:getCurrentSquare():AddWorldInventoryItem(item,
			player:getX() - math.floor(player:getX()),
			player:getY() - math.floor(player:getY()),
			player:getZ() - math.floor(player:getZ()))
	end
end

function WWP_TownTradePanel:onBuyCommodity(_, commodity)
    local uiData = self.commodities[commodity]
    uiData.buyButton.enable = false -- Prevent double click

    local player = getPlayer()
    local quantity = uiData.quantity or 0
    if not self.town:isSelling(commodity, quantity) then
        WL_Dialogs.showMessageDialog("The town is keeping its remaining " .. commodity.name .. " in reserve.")
        self:updateState()
        return
    end

    local workPointCost = commodity.buyWorkPoints
    if WL_Utils.canModerate(player) then workPointCost = 0 end

    if not WWP_PlayerStats.hasPointsAvailable(player, workPointCost) then
        WL_Dialogs.showMessageDialog("You do not have enough work points to buy commodities, you need at least " .. workPointCost)
        self:updateState()
        return
    end

    local cost = self.commodities[commodity].sellPrice
    if not cost then
        self:updateState()
        return
    end
    if WIT_Gold.amountOnPlayer(player) < cost then
        WL_Dialogs.showMessageDialog("You do not have enough to buy that.")
        self:updateState()
        return
    end

    WWP_TownLedger.attemptCommodityWithdrawal(self.town, commodity, 1, WWP_TownLedger.GOODS_SOLD,
			function(_, success, newBalance)
				if success then
                    local logMessage = string.format("%s bought %s for %d from %s", player:getUsername(), commodity.name, cost, self.town.name)
                    WWP_Client.logWithLocation(player, logMessage)
                    if workPointCost > 0 then
					    WWP_PlayerStats.deductWorkPoints(player, workPointCost)
					    local workPointsMsg = "Used " .. workPointCost ..
                            " work points to buy " .. commodity.name ..
                            "\n" .. WWP_PlayerStats.getWorkPointsRemainingString(player)
					    player:setHaloNote(workPointsMsg, 253, 216, 12, 400.0)
                    end
                    WIT_Gold.removeAmountFromPlayer(player, cost)
                    if self.town.type ~= WWP_TownType.NPC_HUB then
                        WWP_TownLedger.getClient():makeDeposit(self.town.id, cost, WWP_TownLedger.getSaleCategory(commodity))
                    end
                    giveItem(player, commodity.itemType)
                    local chatMessage = "Bought " .. commodity.name .. " for " .. tostring(cost)
                    WL_Utils.addToChat(chatMessage, { color = "1.0,0.8,0.2", })
                    self.parentPanel:updateStock(commodity, newBalance)
                    getSoundManager():playUISound("TownBuy")
				else
                    WL_Dialogs.showMessageDialog("The town has run out of " .. commodity.name .. ".")
				end
                self:updateState()
			end)
end

function WWP_TownTradePanel:onSellCommodity(_, commodity)
    local uiData = self.commodities[commodity]
    if uiData.pendingSale then return end

    local player = getPlayer()
    local quantity = uiData.quantity or 0
    if not self.town:isBuying(commodity, quantity) and not self:canBuyBeyondStorageLimit() then
        WL_Dialogs.showMessageDialog("The town is not looking to buy more " .. commodity.name .. " right now.")
        self:updateState()
        return
    end

    local palletItem = findCommodityInInventory(player, commodity)
    if not palletItem then
        WL_Dialogs.showMessageDialog("You do not have a pallet of " .. commodity.name .. " to sell.")
        self:updateState()
        return
    end

    -- Figure out what we will pay
    local buyPrice = self.commodities[commodity].buyPrice
    if not buyPrice then
        self:updateState()
        return
    end -- Shouldn't happen ever, but just in case
    local playerProfit = buyPrice
    local exportingTown = nil
    local exportDuty = 0

    if palletItem:getModData().unpaidExportDuty then
        if palletItem:getModData().originTown ~= self.town.id then
            exportingTown = WWP_Town.findTownById(palletItem:getModData().originTown)
            if exportingTown then
                exportDuty = math.floor((buyPrice * (exportingTown:getExportDuty() / 100)) + 0.5)
                playerProfit = buyPrice - exportDuty
            end
        end
    end

    uiData.pendingSale = true
    self:updateState()

    local function removeSoldCommodity()
        local itemToRemove, container = findCommodityInInventory(player, commodity)
        if not itemToRemove then
            WWP_Client.logWithLocation(player, string.format("Sale failed to remove %s for %s at %s: item missing after ledger success",
                    commodity.name, player:getUsername(), self.town.name))
            uiData.pendingSale = false
            self:updateState()
            return false
        end
        ---@cast container -nil
        container:Remove(itemToRemove)
        return true
    end

    if self.town.type == WWP_TownType.NPC_HUB then -- NPC Hub town has infinite cash
        if not removeSoldCommodity() then return end
        self:completeSaleTransaction(commodity, playerProfit, exportingTown, exportDuty)
    else
        WWP_TownLedger.getClient():attemptWithdrawal(self.town.id, buyPrice, WWP_TownLedger.getPurchaseCategory(commodity),
            function(_, success, newBalance)
                if success then
                    if not removeSoldCommodity() then return end
                    self:completeSaleTransaction(commodity, playerProfit, exportingTown, exportDuty)
                else
                    uiData.pendingSale = false
                    WL_Dialogs.showMessageDialog("The town can't afford to buy this commodity right now.")
                    self:updateState()
                end
            end)
    end
end

function WWP_TownTradePanel:completeSaleTransaction(commodity, playerProfit, exportingTown, exportDuty)
    -- The money is now out so we have to just pray from here that nothing fails as we don't do rollbacks
    local uiData = self.commodities[commodity]
    local player = getPlayer()
    local function payPlayer()
        local logMessage = string.format("%s sold %s for %d to %s", player:getUsername(), commodity.name, playerProfit, self.town.name)
        if exportDuty > 0 and exportingTown then
            logMessage = logMessage .. string.format(" (export duty: %d to %s)", exportDuty, exportingTown.name)
        end
        WWP_Client.logWithLocation(player, logMessage)

        if exportingTown and exportingTown.type ~= WWP_TownType.NPC_HUB then
            WWP_TownLedger.getClient():makeDeposit(exportingTown.id, exportDuty, WWP_TownLedger.EXPORT_DUTY)
        end

        local chatMessage = "Sold " .. commodity.name
        if exportDuty > 0 then
            chatMessage = chatMessage .. " (export duty: " .. tostring(exportDuty) .. " " .. WIT_Gold.CurrencyName .. ")"
        end
        WL_Utils.addToChat(chatMessage, { color = "1.0,0.8,0.2", })
        WIT_Gold.addAmountToPlayer(player, playerProfit)
        getSoundManager():playUISound("TownSell")
    end

    if self:canBuyBeyondStorageLimit() and uiData.fullStock then
        uiData.pendingSale = false
        self.parentPanel:updateStock(commodity, uiData.quantity)
        self:updateState()
        payPlayer()
    else
        WWP_TownLedger.makeCommodityDeposit(self.town, commodity, 1, WWP_TownLedger.GOODS_BOUGHT,
            function(_, success, newBalance)
                if success then
                    self.parentPanel:updateStock(commodity, newBalance)
                    payPlayer()
                end
                uiData.pendingSale = false
                self:updateState()
            end)
    end
end
