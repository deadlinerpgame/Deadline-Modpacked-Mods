WAT_OverFiller = WAT_OverFiller or {}

local function ItemContainer_hasRoomFor_override(self, itemOrWeight)
    return true
end

function WAT_OverFiller.enable()
    if WAT_OverFiller.enabled then return end
    WAT_OverFiller.enabled = true

    local itemContainerMeta = __classmetatables[ItemContainer.class].__index
    WAT_OverFiller.ItemContainer_hasRoomFor = itemContainerMeta.hasRoomFor
    itemContainerMeta.hasRoomFor = ItemContainer_hasRoomFor_override
end

function WAT_OverFiller.disable()
    if not WAT_OverFiller.enabled then return end
    WAT_OverFiller.enabled = false

    local itemContainerMeta = __classmetatables[ItemContainer.class].__index
    itemContainerMeta.hasRoomFor = WAT_OverFiller.ItemContainer_hasRoomFor
end