---
--- WIT_RadioBackpack.lua
--- 22/10/2025
--- 

require "WL_Utils"

local group = AttachedLocations.getGroup("Human")
group:getOrCreateLocation("RadioBackpack"):setAttachmentName("HAM Radio")

local radios = {
    "Radio.HamRadio1",
    "Radio.HamRadio2",
    "Radio.HamRadioMakeShift",
}

for _, radio in ipairs(radios) do
    local item = ScriptManager.instance:getItem(radio)
    if item then
        item:DoParam("AttachmentType = RadioBackpack")
    end
end

local backpacks = {
    "Base.Tintable_Backpack_Radio_Tight",
    "Base.Tintable_Backpack_Radio",
    "Base.Urban_Camo_Backpack_Radio",
    "Base.Woodland_Camo_Backpack_Radio",
    "Base.Tactical_Radio_Backpack",
    "Base.Tactical_Radio_Backpack",
    "Base.Caution_Backpack_Radio"
}

for _, backpack in ipairs(backpacks) do
    local item = ScriptManager.instance:getItem(backpack)
    if item then
        WL_Utils.setItemProperties(backpack, {
            ["AttachmentsProvided"] = "RadioBackpack",
            ["Capacity"] = "22",
        })
    end
end

local jammerItem = ScriptManager.instance:getItem("Base.Military_Radio_Backpack")
if jammerItem then
    WL_Utils.setItemProperties("Base.Military_Radio_Backpack", {
        ["AttachmentsProvided"] = "RadioBackpack",
    })
end

local function isRadioBackpack(item)
    if not item then return false end
    for _, backpack in ipairs(backpacks) do
        if item:getFullType() == backpack then
            return true
        end
    end
    return false
end

local function fixBackpackCapacity()
    if not isClient() then return end
    local player = getPlayer()
    local inventoryItems = player:getInventory():getItems()

    for i = 0, inventoryItems:size() - 1 do
        local item = inventoryItems:get(i)
        if item and isRadioBackpack(item) then
            if item:getFullType() ~= "Base.Military_Radio_Backpack" then
                local capacity = item:getCapacity()
                if capacity ~= 22 then
                    item:setCapacity(22)
                end
            end
        end
    end
end


Events.OnClothingUpdated.Add(fixBackpackCapacity)
