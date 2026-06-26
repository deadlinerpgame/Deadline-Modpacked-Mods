WIT_Gold = WIT_Gold or {}
WIT_Gold.CurrencyName = "dollars" -- Needs to be changed each season
WIT_Gold.CurrencySound = "PaperMoney" -- Used to be CoinsClinkHeavy

WIT_Gold.ItemAmounts = {
    ["Base.GoldCurrency"] = 1,
    ["Base.GoldCurrencyFive"] = 5,
    ["Base.GoldCurrencyTen"] = 10,
    ["Base.GoldCurrencyFifty"] = 50,
    ["Base.GoldCurrencyHundred"] = 100,
    ["Base.GoldCurrencyFiveHundred"] = 500,
    ["Base.GoldCurrencyThousand"] = 1000,
}

local function isGold(item)
    return WIT_Gold.ItemAmounts[item:getFullType()] ~= nil
end

local function sortByAmount(itemA, itemB)
    return WIT_Gold.ItemAmounts[itemA:getFullType()] < WIT_Gold.ItemAmounts[itemB:getFullType()]
end

local function sortByAmountReverse(itemA, itemB)
    return WIT_Gold.ItemAmounts[itemA:getFullType()] > WIT_Gold.ItemAmounts[itemB:getFullType()]
end

local function getGoldInInventory(inventory)
    local gold = {}
    local items = inventory:getAllEval(isGold)
    for i=0, items:size()-1 do
        local item = items:get(i)
        table.insert(gold, item)
    end
    return gold
end

local function getGoldInInventoryRecurse(inventory)
    local gold = {}
    local items = inventory:getAllEvalRecurse(isGold)
    for i=0, items:size()-1 do
        local item = items:get(i)
        table.insert(gold, item)
    end
    return gold
end

---Get the total value on a player.
---@param player IsoPlayer
---@return number
function WIT_Gold.amountOnPlayer(player)
    local inventory = player:getInventory()
    local amount = 0
    for item, count in pairs(WIT_Gold.ItemAmounts) do
        amount = amount + inventory:getItemCountRecurse(item) * count
    end
    return amount
end

---Get the total value in a container.
---@param container ItemContainer
---@return number
function WIT_Gold.amountInContainer(container)
    local amount = 0
    for item, count in pairs(WIT_Gold.ItemAmounts) do
        amount = amount + container:getItemCountRecurse(item) * count
    end
    return amount
end

---Breaks down a gold item into smaller denominations.
---Works with both local and network inventories.
---@param item InventoryItem
function WIT_Gold.breakdownItem(item)
    local amount = WIT_Gold.ItemAmounts[item:getFullType()]
    if amount and amount > 1 then
        local container = item:getContainer()
        local isNetworkContainer = isClient() and not container:isInCharacterInventory(getPlayer()) and container:getType()~="floor"

        if isNetworkContainer then
            container:removeItemOnServer(item)
        end
        container:DoRemoveItem(item)

        while amount > 0 do
            local targetType = WIT_Gold.AmountsItems[1]
            local targetAmount = 1
            for i, a in pairs(WIT_Gold.ItemAmounts) do
                if a > targetAmount and a < amount then
                    targetType = i
                    targetAmount = a
                end
            end
            local numToCreate = math.floor(amount / targetAmount)
            for j=1, numToCreate do
                local newItem = container:AddItem(targetType)
                if isNetworkContainer then
                    container:addItemOnServer(newItem)
                end
            end
            amount = amount - (targetAmount * numToCreate)
        end
        return true
    end
    return false
end

---Will combine all gold in a player's inventory into optimal stacks
---in the target inventory.
---@param player IsoPlayer
---@param targetInventory ItemContainer
function WIT_Gold.combineAllOnPlayer(player, targetInventory)
    local items = getGoldInInventoryRecurse(player:getInventory())
    local total = 0
    for i=1, #items do
        local item = items[i]
        total = total + WIT_Gold.ItemAmounts[item:getFullType()]
        item:getContainer():Remove(item)
    end
    while total > 0 do
        for _, i in ipairs(WIT_Gold.ItemsListReverse) do
            local amount = WIT_Gold.ItemAmounts[i]
            while total >= amount do
                targetInventory:AddItem(i)
                total = total - amount
            end
        end
    end
end

---Gets the items which make up a specific amount of gold from a container.
---Uses largest coins first, with breakdown capability.
---May return partial amount if not enough.
---@param container ItemContainer
---@param amountToGet number
---@return InventoryItem[] a table list of items that make up the amount
function WIT_Gold.getAmountFromContainer(container, amountToGet)
    local foundItems = {}
    local foundItemsLookup = {}
    local items = nil

    while amountToGet > 0 do
        if items == nil then
            local tempTable = getGoldInInventory(container)
            items = {}
            for _, item in ipairs(tempTable) do
                if not foundItemsLookup[item] then
                    table.insert(items, item)
                end
            end
            table.sort(items, sortByAmountReverse)
        end
        local item = table.remove(items)
        if item then
            local itemAmount = WIT_Gold.ItemAmounts[item:getFullType()]
            if itemAmount > amountToGet then
                if WIT_Gold.breakdownItem(item) then
                    items = nil
                else
                    return foundItems
                end
            else
                amountToGet = amountToGet - itemAmount
                table.insert(foundItems, item)
                foundItemsLookup[item] = true
            end
        else
            return foundItems
        end
    end
    return foundItems
end

---Gets the items which make up a specific amount of gold.
---Tries to pull from main inventory first, then bags.
---Uses smallest coins first.
---May return partial amount if not enough.
---@param player number
---@param amountToGet number
---@return InventoryItem[] a table list of items that make up the amount
function WIT_Gold.getAmountFromPlayer(player, amountToGet)
    local foundItems = {}
    local foundItemsLookup = {}
    local inventory = player:getInventory()
    local items = nil
    local onlyMainInventory = true
    while amountToGet > 0 do
        if items == nil then
            local tempTable
            if onlyMainInventory then
                tempTable = getGoldInInventory(inventory)
            else
                tempTable = getGoldInInventoryRecurse(inventory)
            end
            items = {}
            for _, item in ipairs(tempTable) do
                if not foundItemsLookup[item] then
                    table.insert(items, item)
                end
            end
            table.sort(items, sortByAmountReverse)
        end
        local item = table.remove(items)
        if item then
            local itemAmount = WIT_Gold.ItemAmounts[item:getFullType()]
            if itemAmount > amountToGet then
                if WIT_Gold.breakdownItem(item) then
                    items = nil
                else
                    return foundItems
                end
            else
                amountToGet = amountToGet - itemAmount
                table.insert(foundItems, item)
                foundItemsLookup[item] = true
            end
        else
            if onlyMainInventory then
                onlyMainInventory = false
                items = nil
            else
                return foundItems
            end
        end
    end
    return foundItems
end

---Will remove a specific amount of gold from a player's inventory.
---Tries to pull from the main inventory first, then bags.
---Uses smallest coins first.
---Checks if the player has enough gold before removing any.
---@param player IsoPlayer
---@param amountToRemove number
---@return boolean true if the amount was removed, false if not
function WIT_Gold.removeAmountFromPlayer(player, amountToRemove)
    if WIT_Gold.amountOnPlayer(player) < amountToRemove then
        return false
    end
    local inventory = player:getInventory()
    local items = nil
    local onlyMainInventory = true
    while amountToRemove > 0 do
        if items == nil then
            if onlyMainInventory then
                items = getGoldInInventory(inventory)
            else
                items = getGoldInInventoryRecurse(inventory)
            end
            table.sort(items, sortByAmountReverse)
        end
        local item = table.remove(items)
        if item then
            local itemAmount = WIT_Gold.ItemAmounts[item:getFullType()]
            if itemAmount > amountToRemove then
                if WIT_Gold.breakdownItem(item) then
                    items = nil
                else
                    return false
                end
            else
                amountToRemove = amountToRemove - itemAmount
                item:getContainer():Remove(item)
            end
        else
            if onlyMainInventory then
                onlyMainInventory = false
                items = nil
            else
                return false
            end
        end
    end
    return true
end

local function getBestContainer(player)
    local inventory = player:getInventory()
    local wallet = inventory:FindAndReturn("Wallet")
    if not wallet then
        wallet = inventory:FindAndReturn("Wallet2")
    end
    if not wallet then
        wallet = inventory:FindAndReturn("Wallet3")
    end
    if not wallet then
        wallet = inventory:FindAndReturn("Wallet4")
    end

    if wallet and wallet:IsInventoryContainer() then
        return wallet:getInventory(), wallet:getDisplayName()
    end
    return inventory, nil
end

---Will add a specific amount of gold to a player's inventory.
---Largest coins first.
---@param player IsoPlayer
---@param amountToAdd number
function WIT_Gold.addAmountToPlayer(player, amountToAdd)
    local inventory, containerName = getBestContainer(player)
    local containerSuffix = containerName and (" (" .. containerName .. ")") or ""
	WL_Utils.addToChat("Gained " .. tostring(amountToAdd) .. " " .. WIT_Gold.CurrencyName .. containerSuffix, { color = "1.0,0.8,0.2", })
    while amountToAdd > 0 do
        for _, i in ipairs(WIT_Gold.ItemsListReverse) do
            local amount = WIT_Gold.ItemAmounts[i]
            while amountToAdd >= amount do
                inventory:AddItem(i)
                amountToAdd = amountToAdd - amount
            end
        end
    end
end

Events.OnGameBoot.Add(function ()
    WIT_Gold.AmountsItems = {}
    WIT_Gold.ItemsList = {}
    WIT_Gold.ItemsListReverse = {}
    for item, count in pairs(WIT_Gold.ItemAmounts) do
        WIT_Gold.AmountsItems[count] = item
        table.insert(WIT_Gold.ItemsList, item)
        table.insert(WIT_Gold.ItemsListReverse, item)
    end
    table.sort(WIT_Gold.ItemsList, function(a, b) return WIT_Gold.ItemAmounts[a] < WIT_Gold.ItemAmounts[b] end)
    table.sort(WIT_Gold.ItemsListReverse, function(a, b) return WIT_Gold.ItemAmounts[a] > WIT_Gold.ItemAmounts[b] end)
end)

