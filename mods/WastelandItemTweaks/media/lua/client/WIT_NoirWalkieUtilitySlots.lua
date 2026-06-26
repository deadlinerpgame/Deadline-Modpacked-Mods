require "Hotbar/ISHotbarAttachDefinition"

local function ensureWalkieAttachment(slot, isLeft)
    if type(slot) ~= "table" or type(slot.attachments) ~= "table" then return end
    if slot.attachments.Walkie ~= nil then return end

    local bottleAnchor = slot.attachments.Bottle
    if type(bottleAnchor) ~= "string" or bottleAnchor == "" then
        local slotType = tostring(slot.type or "")
        bottleAnchor = isLeft
            and slotType:gsub("UtilityLeft$", "ulBottle")
            or slotType:gsub("UtilityRight$", "urBottle")
    end

    if type(bottleAnchor) ~= "string" or bottleAnchor == "" then return end
    if isLeft and not bottleAnchor:match("ulBottle$") then return end
    if not isLeft and not bottleAnchor:match("urBottle$") then return end

    slot.attachments.Walkie = bottleAnchor
end

local function patchNoirWalkieUtilitySlots()
    if type(ISHotbarAttachDefinition) ~= "table" then return end

    for _, slot in pairs(ISHotbarAttachDefinition) do
        local slotType = tostring(slot and slot.type or "")
        if slotType:match("UtilityLeft$") then
            ensureWalkieAttachment(slot, true)
        elseif slotType:match("UtilityRight$") then
            ensureWalkieAttachment(slot, false)
        end
    end
end

Events.OnGameBoot.Add(patchNoirWalkieUtilitySlots)
