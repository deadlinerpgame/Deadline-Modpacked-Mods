local replacements = {
    ["Old"] = "Normal",
    ["Modern"] = "Normal",
    ["Small"] = "Normal",
    ["Big"] = "Normal"
}

local function updatePart(part, item)
    for old, new in pairs(replacements) do
        if luautils.stringStarts(item:getType(), old) then
            local newType = item:getType():gsub(old, new)
            item = InventoryItemFactory.CreateItem(newType)
            if item then
                part:setInventoryItem(item)
                return
            end
        end
    end
end

function WAT_simpleRepair(vehicleId)
	local vehicle = getVehicleById(vehicleId)
    if not vehicle then
        return
    end
    local partCount = vehicle:getPartCount()
    for i=0, partCount-1 do
        local part = vehicle:getPartByIndex(i)
        if part:getId() == "Engine" then
            part:repair()
            vehicle:transmitEngine()
        elseif part:getId() == "Heater" then
            part:repair()
            vehicle:transmitPartCondition(part)
        elseif string.find(part:getId(), "Armor") then
            part:setInventoryItem(nil)
            vehicle:transmitPartItem(part)
        else
            local item = part:getInventoryItem()
            if item then
                updatePart(part, item)
                part:repair()
                vehicle:transmitPartCondition(part)
                vehicle:transmitPartItem(part)
            end
        end
    end

end