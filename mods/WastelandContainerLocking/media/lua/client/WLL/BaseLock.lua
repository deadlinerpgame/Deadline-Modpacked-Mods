WLL = WLL or {}
WLL.BaseLock = WLL.BaseLock or {}

function WLL.BaseLock.IsLockableContainer(container)
    local parent = container:getParent()
    if parent then
        return true
    end
    local item = container:getContainingItem()
    if item then
        -- TODO: Check if approved bag
        return true
    end
    return false
end

function WLL.BaseLock.GetContainerModData(container)
    local parent = container:getParent()
    if parent then
        return parent:getModData()
    end
    local item = container:getContainingItem()
    if item then
        return item:getModData()
    end
    return nil
end

function WLL.BaseLock.SetContainerModData(container, values)
    local parent = container:getParent()
    if parent then
        local modData = parent:getModData()
        for k, v in pairs(values) do
            modData[k] = v
        end
        parent:transmitModData()
    end
    local item = container:getContainingItem()
    if item then
        local modData = item:getModData()
        for k, v in pairs(values) do
            modData[k] = v
        end
    end
end

function WLL.BaseLock.ClearContainerModData(container, keys)
    local parent = container:getParent()
    if parent then
        local modData = parent:getModData()
        for _, k in ipairs(keys) do
            modData[k] = nil
        end
        parent:transmitModData()
    end
    local item = container:getContainingItem()
    if item then
        local modData = item:getModData()
        for _, k in ipairs(keys) do
            modData[k] = nil
        end
    end
end

function WLL.BaseLock.GetSquareForContainer(container)
    local parent = container:getParent()
    if parent then
        return parent:getSquare()
    end
    return nil
end

function WLL.BaseLock.PlayerCanPickLock(player, paperclip, screwdriver)

    if not player:HasTrait("Locksmith") and
       not player:HasTrait("Burglar") and
       not WL_Utils.isAtLeastGM(player) then
        return false
    end

    if not paperclip then
        if not player:getInventory():contains("Paperclip") then
            return false
        end
    else
        -- make sure in primary hand
        if player:getPrimaryHandItem() ~= paperclip then
            return false
        end
    end

    if not screwdriver then
        if not player:getInventory():contains("Screwdriver") then
            return false
        end
    else
        -- make sure in secondary hand
        if player:getSecondaryHandItem() ~= screwdriver then
            return false
        end
    end

    return true
end

function WLL.BaseLock.OnPickLock(player, system, container)
    ISTimedActionQueue.add(WLLPickLockAction:new(player, system, container))
end

function WLL.BaseLock.IsClearTile(container)
    local parent = container:getParent()
    if not parent or not parent:getSprite() then return false end
    return WLL.BaseLock.ClearTiles[parent:getSprite():getName()] or false
end

WLL.BaseLock.ClearTiles = {
    ["BZM_Arcade_BERT_01_16"] = true,
    ["BZM_Arcade_BERT_01_17"] = true,
    ["BZM_Arcade_BERT_01_18"] = true,
    ["BZM_Arcade_BERT_01_19"] = true,
    ["BZM_Arcade_BERT_01_20"] = true,
    ["BZM_Arcade_BERT_01_21"] = true,
    ["BZM_Arcade_BERT_01_22"] = true,
    ["BZM_Arcade_BERT_01_23"] = true,
    ["BZM_GrassStation_WeedDispensery_0"] = true,
    ["BZM_GrassStation_WeedDispensery_1"] = true,
    ["BZM_GrassStation_WeedDispensery_2"] = true,
    ["BZM_GrassStation_WeedDispensery_3"] = true,
    ["BZM_GrassStation_WeedDispensery_4"] = true,
    ["BZM_GrassStation_WeedDispensery_5"] = true,
    ["BZM_GrassStation_WeedDispensery_6"] = true,
    ["BZM_GrassStation_WeedDispensery_7"] = true,
    ["BZM_Half-Cocked_Gunstore_01_24"] = true,
    ["BZM_Half-Cocked_Gunstore_01_25"] = true,
    ["BZM_Half-Cocked_Gunstore_01_26"] = true,
    ["BZM_Half-Cocked_Gunstore_01_27"] = true,
    ["BZM_Half-Cocked_Gunstore_01_28"] = true,
    ["BZM_Half-Cocked_Gunstore_01_29"] = true,
    ["BZM_Half-Cocked_Gunstore_01_30"] = true,
    ["BZM_Half-Cocked_Gunstore_01_31"] = true,
    ["BZM_QuickSTOP_2_40"] = true,
    ["BZM_QuickSTOP_2_41"] = true,
    ["BZM_QuickSTOP_2_42"] = true,
    ["BZM_QuickSTOP_2_43"] = true,
    ["BZM_QuickSTOP_2_44"] = true,
    ["BZM_QuickSTOP_2_45"] = true,
    ["BZM_QuickSTOP_2_46"] = true,
    ["BZM_QuickSTOP_2_47"] = true,
    ["BZM_ToddysOffence_24"] = true,
    ["BZM_ToddysOffence_25"] = true,
    ["BZM_ToddysOffence_26"] = true,
    ["BZM_ToddysOffence_27"] = true,
    ["BZM_ToddysOffence_28"] = true,
    ["BZM_ToddysOffence_29"] = true,
    ["BZM_ToddysOffence_30"] = true,
    ["BZM_ToddysOffence_31"] = true,
    ["Chinatown_EX_military_1_10"] = true,
    ["Chinatown_EX_military_1_11"] = true,
    ["Chinatown_EX_military_1_16"] = true,
    ["Chinatown_EX_military_1_17"] = true,
    ["Chinatown_EX_military_1_18"] = true,
    ["Chinatown_EX_military_1_19"] = true,
    ["Chinatown_EX_military_1_8"] = true,
    ["Chinatown_EX_military_1_9"] = true,
    ["Chinatown_EX_military"] = true,
    ["d_furniture_bedroom_01_40"] = true,
    ["d_furniture_bedroom_01_41"] = true,
    ["d_furniture_bedroom_01_42"] = true,
    ["d_furniture_bedroom_01_43"] = true,
    ["d_furniture_bedroom_05_40"] = true,
    ["d_furniture_bedroom_05_41"] = true,
    ["d_furniture_bedroom_05_42"] = true,
    ["d_furniture_bedroom_05_43"] = true,
    ["decoration_Simon_MD_64"] = true,
    ["decoration_Simon_MD_65"] = true,
    ["decoration_Simon_MD_72"] = true,
    ["decoration_Simon_MD_73"] = true,
    ["edit_ddd_RUS_furniture_storage_03_10"] = true,
    ["edit_ddd_RUS_furniture_storage_03_11"] = true,
    ["edit_ddd_RUS_furniture_storage_03_34"] = true,
    ["edit_ddd_RUS_furniture_storage_03_35"] = true,
    ["edit_ddd_RUS_furniture_storage_03_72"] = true,
    ["edit_ddd_RUS_furniture_storage_03_73"] = true,
    ["edit_ddd_RUS_furniture_storage_03_74"] = true,
    ["edit_ddd_RUS_furniture_storage_03_75"] = true,
    ["edit_ddd_RUS_furniture_storage_03_8"] = true,
    ["edit_ddd_RUS_furniture_storage_03_82"] = true,
    ["edit_ddd_RUS_furniture_storage_03_83"] = true,
    ["edit_ddd_RUS_furniture_storage_03_9"] = true,
    ["furniture_02_Simon_MD_10"] = true,
    ["furniture_02_Simon_MD_11"] = true,
    ["furniture_02_Simon_MD_16"] = true,
    ["furniture_02_Simon_MD_17"] = true,
    ["furniture_02_Simon_MD_18"] = true,
    ["furniture_02_Simon_MD_19"] = true,
    ["furniture_02_Simon_MD_46"] = true,
    ["furniture_02_Simon_MD_47"] = true,
    ["furniture_02_Simon_MD_5"] = true,
    ["furniture_02_Simon_MD_8"] = true,
    ["furniture_02_Simon_MD_9"] = true,
    ["honeywood_Simon_MD_62"] = true,
    ["honeywood_Simon_MD_63"] = true,
    ["honeywood_Simon_MD_64"] = true,
    ["honeywood_Simon_MD_65"] = true,
    ["location_entertainment_theatre_01_4"] = true,
    ["location_entertainment_theatre_01_5"] = true,
    ["location_entertainment_theatre_01_6"] = true,
    ["location_entertainment_theatre_01_7"] = true,
    ["location_resaurant_pie_01_48"] = true,
    ["location_resaurant_pie_01_49"] = true,
    ["location_resaurant_pie_01_50"] = true,
    ["location_resaurant_pie_01_51"] = true,
    ["location_restaurant_pizzawhirled_01_64"] = true,
    ["location_restaurant_pizzawhirled_01_65"] = true,
    ["location_restaurant_pizzawhirled_01_66"] = true,
    ["location_restaurant_pizzawhirled_01_67"] = true,
    ["location_restaurant_seahorse_01_56"] = true,
    ["location_restaurant_seahorse_01_57"] = true,
    ["location_restaurant_seahorse_01_58"] = true,
    ["location_restaurant_seahorse_01_59"] = true,
    ["location_shop_generic_01_32"] = true,
    ["location_shop_generic_01_33"] = true,
    ["location_shop_generic_01_34"] = true,
    ["location_shop_generic_01_35"] = true,
    ["location_shop_generic_ddd_01_100"] = true,
    ["location_shop_generic_ddd_01_101"] = true,
    ["location_shop_generic_ddd_01_102"] = true,
    ["location_shop_generic_ddd_01_103"] = true,
    ["location_shop_generic_ddd_01_104"] = true,
    ["location_shop_generic_ddd_01_105"] = true,
    ["location_shop_generic_ddd_01_106"] = true,
    ["location_shop_generic_ddd_01_107"] = true,
    ["location_shop_generic_ddd_01_32"] = true,
    ["location_shop_generic_ddd_01_33"] = true,
    ["location_shop_generic_ddd_01_34"] = true,
    ["location_shop_generic_ddd_01_35"] = true,
    ["location_shop_generic_ddd_01_96"] = true,
    ["location_shop_generic_ddd_01_97"] = true,
    ["location_shop_generic_ddd_01_98"] = true,
    ["location_shop_generic_ddd_01_99"] = true,
    ["Vaulttec_3_34"] = true,
    ["Vaulttec_3_35"] = true,
    ["Vaulttec_3_48"] = true,
    ["Vaulttec_3_49"] = true,
}