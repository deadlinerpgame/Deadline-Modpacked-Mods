---
--- WWP_TownWarehousePanel.lua
--- Warehouse panel for town management
---

require "GravyUI_WL"
require "ISUI/ISPanel"
require "UI/WL_TextEntryPanel"

WWP_TownWarehousePanel = ISPanel:derive("WWP_TownWarehousePanel")

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

function WWP_TownWarehousePanel:new(x, y, width, height, town, parentPanel)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.town = town
    o.parentPanel = parentPanel
    o:initialise()
    return o
end

WWP_TownWarehousePanel.columnSizes = { 0.05, 0.34, 0.13, 0.12, 0.13, 0.13, 0.1 }

function WWP_TownWarehousePanel:addCommodityRow(winStack, commodity)
    local uiData = {}
    self.commodities[commodity] = uiData
    local row = winStack:makeNode(scale(32))
    local icon, warehouseItem, quantity, usageNode, buyUpToNode, sellDownToNode, donateNode = row
        :cols(WWP_TownWarehousePanel.columnSizes, scale(10))

    local itemTexture = WL_Utils.getIconTexture(commodity.itemType)
    if itemTexture then icon:makeImage(itemTexture, scale(32), scale(32)) end
    warehouseItem:makeLabel(commodity.name, UIFont.Medium, COLOR_WHITE, "left")
    uiData.quantityLabel = quantity:makeLabel("0/200", UIFont.Medium, COLOR_WHITE, "left")
    uiData.usageLabel = usageNode:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")
    uiData.usageLabel:setTooltip("The town uses this much of the commodity each month.\nIf the town cannot pay the commodity upkeep, it\nwill be forced to buy it at an extremely high price.")
    uiData.buyUpToButton = buyUpToNode:makeButton("", self, self.onChangeBuyUpTo, {commodity})
    uiData.buyUpToButton:setTooltip("Town buys this commodity from players while stock is below this amount.")
    uiData.sellDownToButton = sellDownToNode:makeButton("", self, self.onChangeSellDownTo, {commodity})
    uiData.sellDownToButton:setTooltip("Town sells this commodity to players while stock is above this amount.")
    uiData.donateButton = donateNode:makeButton("Donate", self, self.onDonate, {commodity} )
end

function WWP_TownWarehousePanel:initialise()
    ISPanel.initialise(self)
    local win = GravyUI.Node(self.width, self.height, self)
    self.win = win
    win = win:pad(scale(10), scale(10), scale(10), scale(10))

    local winStack = win:makeVerticalStack(scale(15))
    local columnHeaders = winStack:makeNode(scale(32))
    local _, warehouseItemHeader, quantityHeader, usageHeader, buyHeader, sellHeader, _ = columnHeaders
        :cols(WWP_TownWarehousePanel.columnSizes, scale(10))

    warehouseItemHeader:makeLabel("Commodity", UIFont.Large, COLOR_WHITE, "left")
    quantityHeader:makeLabel("Stored", UIFont.Large, COLOR_WHITE, "left")
    usageHeader:makeLabel("Monthly", UIFont.Large, COLOR_WHITE, "left")
    local buyHeaderLabel = buyHeader:makeLabel("Buy", UIFont.Large, COLOR_WHITE, "left")
    buyHeaderLabel:setTooltip("Town buys this commodity from players while stock is below this amount.")
    local sellHeaderLabel = sellHeader:makeLabel("Sell", UIFont.Large, COLOR_WHITE, "left")
    sellHeaderLabel:setTooltip("Town sells this commodity to players while stock is above this amount.")

    self.commodities = {}
    for _, commodity in pairs(WWP_Commodity) do
        if not commodity.disabled then
            self:addCommodityRow(winStack, commodity)
        end
    end
    self:updateState()
end

function WWP_TownWarehousePanel:updateStock(commodity, quantity)
    local uiData = self.commodities[commodity]
    if not uiData then return end
    uiData.quantityLabel:setText(tostring(quantity) .. "/" .. WWP_Town.MAX_STORAGE)

    local buyUpTo = self.town:getBuyUpTo(commodity)
    local sellDownTo = self.town:getSellDownTo(commodity)
    if quantity < sellDownTo then
        uiData.quantityLabel.color = COLOR_RED
        uiData.quantityLabel:setTooltip("Below reserve stock.")
    elseif quantity > buyUpTo then
        uiData.quantityLabel.color = COLOR_YELLOW
        uiData.quantityLabel:setTooltip("Above target stock.")
    else
        uiData.quantityLabel.color = COLOR_GREEN
        uiData.quantityLabel:setTooltip("Within desired stock range.")
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

function WWP_TownWarehousePanel:updateState()
    for commodity, uiData in pairs(self.commodities) do
        local upkeep = self.town:getUpkeep(commodity)
        if upkeep == 0 then
            uiData.usageLabel:setText("")
        else
            uiData.usageLabel:setText("-" .. tostring(upkeep))
         end
        uiData.buyUpToButton:setTitle("< " .. tostring(self.town:getBuyUpTo(commodity)))
        uiData.sellDownToButton:setTitle("> " .. tostring(self.town:getSellDownTo(commodity)))
        local itemFound = findCommodityInInventory(getPlayer(), commodity)
        uiData.donateButton.enable = itemFound and not uiData.fullStock and not uiData.pendingDonation
        if uiData.pendingDonation then
            uiData.donateButton:setTooltip("Donation is being processed.")
        elseif itemFound and not uiData.fullStock then
            uiData.donateButton:setTooltip("Donate this commodity to the town from your inventory")
        elseif uiData.fullStock then
            uiData.donateButton:setTooltip("The town is fully stocked with " .. commodity.name)
        else
            uiData.donateButton:setTooltip(nil)
        end
    end
end

local function submitBuyUpTo(target, inputText)
    target.panel.town:setBuyUpTo(target.commodity, inputText)
    target.panel.parentPanel:updateState()
end

local function submitSellDownTo(target, inputText)
    target.panel.town:setSellDownTo(target.commodity, inputText)
    target.panel.parentPanel:updateState()
end

function WWP_TownWarehousePanel:onChangeBuyUpTo(_, commodity)
    WL_TextEntryPanel:show("Buy " .. commodity.name .. " up to stock", {panel = self, commodity = commodity},
        submitBuyUpTo, self.town:getBuyUpTo(commodity), true, true)
    self.parentPanel:updateState()
end

function WWP_TownWarehousePanel:onChangeSellDownTo(_, commodity)
    WL_TextEntryPanel:show("Sell " .. commodity.name .. " down to stock", {panel = self, commodity = commodity},
        submitSellDownTo, self.town:getSellDownTo(commodity), true, true)
    self.parentPanel:updateState()
end

function WWP_TownWarehousePanel:onDonate(_, commodity)
    local uiData = self.commodities[commodity]
    if uiData.pendingDonation then return end

    local player = getPlayer()
    local palletItem = findCommodityInInventory(player, commodity)
    if not palletItem then
        WL_Dialogs.showMessageDialog("You do not have " .. commodity.name .. " to donate.")
        return
    end

    if palletItem:getModData().unpaidExportDuty then
        if palletItem:getModData().originTown ~= self.town.id then
            WL_Dialogs.showMessageDialog("You cannot donate this commodity as it has unpaid export duty from another town.")
            return
        end
    end

    WWP_Client.logWithLocation(player, string.format("%s donated %s to %s", player:getUsername(), commodity.name, self.town.name))

    uiData.pendingDonation = true
    self:updateState()

    WWP_TownLedger.makeCommodityDeposit(self.town, commodity, 1, WWP_TownLedger.DONATION,
        function(_, success, newBalance)
            if success then
                local itemToRemove, container = findCommodityInInventory(player, commodity)
                if not itemToRemove then
                    WWP_Client.logWithLocation(player, string.format("Donation failed to remove %s for %s at %s: item missing after ledger success",
                            commodity.name, player:getUsername(), self.town.name))
                    uiData.pendingDonation = false
                    self:updateState()
                    return
                end
                ---@cast container -nil
                container:Remove(itemToRemove)
                self.parentPanel:updateStock(commodity, newBalance)
            end
            uiData.pendingDonation = false
            self:updateState()
        end)
end

function WWP_TownWarehousePanel:prerender()
    ISPanel.prerender(self)
    GravyUI.prerender(self)
end
