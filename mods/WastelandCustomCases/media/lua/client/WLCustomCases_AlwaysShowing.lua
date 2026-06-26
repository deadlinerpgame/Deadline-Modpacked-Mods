WLCustomCases = WLCustomCases or {}
WLCustomCases.AlwaysShowing = WLCustomCases.AlwaysShowing or {}

local AlwaysShowing = WLCustomCases.AlwaysShowing

local alwaysShowingTypes = {
    ["WLCustomCases.Manilla_Folder"] = true,
    ["WLCustomCases.FloppyDisk_Binder"] = true,
    ["WLCustomCases.Empty_Book"] = true,
    ["WLCustomCases.Cassette_Case"] = true,
    ["Base.Wallet"] = true,
    ["Base.Wallet2"] = true,
    ["Base.Wallet3"] = true,
    ["Base.Wallet4"] = true,
}

function AlwaysShowing.AddContainerButtons(inventoryPage)
    if not inventoryPage or not inventoryPage.onCharacter then
        return
    end
    local playerObj = getSpecificPlayer(inventoryPage.player)
    if not playerObj then
        return
    end
    local items = playerObj:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if alwaysShowingTypes[item:getFullType()] and not playerObj:isEquipped(item) then
            inventoryPage:addContainerButton(item:getInventory(), item:getTex(), item:getName(), item:getName())
        end
    end
end
