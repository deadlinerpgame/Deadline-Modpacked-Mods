require "ISUI/ISEmoteRadialMenu"

local walletTypes = {
    "Base.Wallet",
    "Base.Wallet2",
    "Base.Wallet3",
    "Base.Wallet4",
}

local function isWallet(item)
    if not item then return false end
    local ft = item:getFullType()
    for i = 1, #walletTypes do
        if ft == walletTypes[i] then return true end
    end
    return false
end

local function collectWalletItemsFromInventory(inv, out)
    if not inv then return end
    local items = inv:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if isWallet(it) and it.getInventory and it:getInventory() then
            local wInv = it:getInventory()
            local wItems = wInv:getItems()
            for j = 0, wItems:size() - 1 do
                table.insert(out, wItems:get(j))
            end
        end
    end
end

Events.OnGameStart.Add(function()
    if not ISEmoteRadialMenu or not ISEmoteRadialMenu.fillMenu then return end

    local old_fillMenu = ISEmoteRadialMenu.fillMenu

    function ISEmoteRadialMenu:fillMenu(submenu)
        local playerInv = self.character:getInventory()
        local walletItems = {}
        collectWalletItemsFromInventory(playerInv, walletItems)

        local moved = {}
        for _, item in ipairs(walletItems) do
            local fromInv = item:getContainer()
            local itemFullType = item:getFullType()
            if fromInv and fromInv ~= playerInv and fromInv:contains(item) and string.find(itemFullType, "TAD.BobTA_") then
                fromInv:Remove(item)
                playerInv:AddItem(item)
                moved[#moved + 1] = { item = item, fromInv = fromInv }
            end
        end

        old_fillMenu(self, submenu)

        for i = #moved, 1, -1 do
            local entry = moved[i]
            if playerInv:contains(entry.item) then
                playerInv:Remove(entry.item)
                entry.fromInv:AddItem(entry.item)
            end
        end
    end
end)
