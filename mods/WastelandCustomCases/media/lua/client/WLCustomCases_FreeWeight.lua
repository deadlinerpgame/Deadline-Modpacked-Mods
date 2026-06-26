WLCustomCases = WLCustomCases or {}
WLCustomCases.FreeWeight = WLCustomCases.FreeWeight or {}

local FreeWeight = WLCustomCases.FreeWeight

local freeWeight = {
    ["WLCustomCases.Manilla_Folder"] = 0.1,
    ["WLCustomCases.FloppyDisk_Binder"] = 0.1,
    ["WLCustomCases.Cassette_Case"] = 0.2,
    ["Base.Wallet"] = 0.2,
    ["Base.Wallet2"] = 0.2,
    ["Base.Wallet3"] = 0.2,
    ["Base.Wallet4"] = 0.2,
}

local function GetInternalWeight(bag)
    local weight = 0
    for i = 0, bag:getItems():size() - 1 do
        weight = weight + bag:getItems():get(i):getActualWeight()
    end
    return weight
end

function FreeWeight.ApplyForPlayer(playerObj)
    if not playerObj then
        return
    end
    local items = playerObj:getInventory():getItems()

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local adjust = freeWeight[item:getFullType()]
        if adjust then
            if item:isEquipped() or not playerObj:getInventory():contains(item) then
                item:setActualWeight(GetInternalWeight(item:getInventory()) + adjust)
            else
                item:setActualWeight(-1 * GetInternalWeight(item:getInventory()) + adjust)
            end
            item:setCustomWeight(true)
        end
    end
end

function FreeWeight.Apply()
    FreeWeight.ApplyForPlayer(getPlayer())
end
