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

local attachedContainerSlotSuffixes = {
    "Secondary",
    "Container",
    "ContainerSmallLeft",
    "ContainerSmallRight",
}

local function EndsWith(value, suffix)
    return type(value) == "string" and string.sub(value, -string.len(suffix)) == suffix
end

local function IsSupportedAttachedContainer(playerObj, item)
    if item:getCategory() ~= "Container" or not playerObj:isAttachedItem(item) then
        return false
    end

    local slotType = item:getAttachedSlotType()
    for _, suffix in ipairs(attachedContainerSlotSuffixes) do
        if EndsWith(slotType, suffix) then
            return true
        end
    end

    return false
end

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
        local shouldShow = alwaysShowingTypes[item:getFullType()]
            or IsSupportedAttachedContainer(playerObj, item)
        if shouldShow and not playerObj:isEquipped(item) then
            inventoryPage:addContainerButton(item:getInventory(), item:getTex(), item:getName(), item:getName())
        end
    end
end
