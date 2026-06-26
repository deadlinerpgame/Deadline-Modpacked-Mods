---
--- WIT_HideBlueprinted.lua
---
--- Hide duplicate non-blueprint recipes while keeping Wasteland blueprint-gated variants visible.
---

local WIT_recipeBlueprintRequirement = {
    -- SWAT
    ["Craft SWAT Enforcer Vest"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Protector Vest"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Enforcer Vest [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Protector Vest [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Helmet Rook [Visor][Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Helmet [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Helmet [Patriot][Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Cap [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Balaclava [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Jacket [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Make SWAT Gloves [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Pants [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Boots [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT TacBoots [Olive]"] = "SWAT_Clothing_Blueprints_Final",
    ["Craft SWAT Gasmask [Olive]"] = "SWAT_Clothing_Blueprints_Final",

    -- Trauma responder
    ["Craft Trauma Responder Helmet [Visor]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Helmet [Defender]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Helmet [Patriot]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Cap"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Balaclava [1 Hole]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Balaclava [2 Hole]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Balaclava [3 Hole]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Jacket"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Vest"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Gloves"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Pants"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Boots"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder TacBoots"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Backpack [Radio]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Gasmask"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Trauma Responder Container [Medium]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Utility Leg Pouch [Medic]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Small Storm Pouch [Medic]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Medium Storm Pouch [Medic]"] = "Trauma_Responder_Blueprints_Final",
    ["Craft Large Storm Pouch [Medic]"] = "Trauma_Responder_Blueprints_Final",

    -- Caution
    ["Craft Caution Visor Helmet"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Cap"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Balaclava"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Jacket"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Light Vest"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Gloves"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Pants"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Boots"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Backpack"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Gasmask"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Container [Large]"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Container [Medium]"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Container [Small]"] = "CautionPack_Blueprints_Final",
    ["Craft Caution Hazmat Suit"] = "CautionPack_Blueprints_Final",
    ["Craft Caution GasTank Backpack"] = "CautionPack_Blueprints_Final",

    -- Medic
    ["Craft Medic Patch"] = "Camo_Medic_Clothing_Blueprints_Final",
    ["Craft Patriot Camo Vest [Medic]"] = "Camo_Medic_Clothing_Blueprints_Final",
    ["Craft Medic Camo Helmet"] = "Camo_Medic_Clothing_Blueprints_Final",

    -- Single-use recipes that are blueprint-gated
    ["Upgrade Belt (Both)"] = "UpgradedBeltBlueprint_Final",
    ["CraftRattlerMK1"] = "RattlerSmgBlueprints_Final",
    ["CraftThompson"] = "ThompsonSmgBlueprints_Final",
}

local function WIT_sourceHasBlueprintIngredient(recipe, requiredItem)
    local sources = recipe:getSource()

    for i = 0, sources:size() - 1 do
        local source = sources:get(i)
        local sourceItems = source:getItems()

        for j = 0, sourceItems:size() - 1 do
            local itemType = sourceItems:get(j)
            if itemType == requiredItem or itemType == ("Base." .. requiredItem) then
                return true
            end
        end
    end

    return false
end

local function WIT_hideDuplicateNonBlueprintRecipes()
    local recipes = getScriptManager():getAllRecipes()

    for i = 0, recipes:size() - 1 do
        local recipe = recipes:get(i)
        local recipeName = recipe:getName()
        local requiredBlueprint = WIT_recipeBlueprintRequirement[recipeName]

        if requiredBlueprint then
            local hasBlueprintIngredient = WIT_sourceHasBlueprintIngredient(recipe, requiredBlueprint)
            if not hasBlueprintIngredient then
                recipe:setNeedToBeLearn(true)
                recipe:setIsHidden(true)
                recipe:setLuaTest("WIT_recipes.OnTest_False")
            end
        end
    end
end

Events.OnGameBoot.Add(WIT_hideDuplicateNonBlueprintRecipes)
