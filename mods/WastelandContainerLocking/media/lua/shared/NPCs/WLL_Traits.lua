require('NPCs/MainCreationMethods');

local function onGameBoot()
    -- Locksmith
    local locksmith = TraitFactory.addTrait("Locksmith", getText("UI_trait_locksmith"), 5, getText("UI_trait_locksmithdesc"), false, false)
    locksmith:addXPBoost(Perks.MetalWelding, 1)
    local locksmithRecipes = locksmith:getFreeRecipes()
    locksmithRecipes:add("Craft Padlocks")
    locksmithRecipes:add("Craft Combination Padlocks")
    locksmithRecipes:add("Craft Door Lock")
end

local function updateTraits(idx, player)
    if player:HasTrait("Locksmith") then
        player:learnRecipe("Craft Padlocks")
        player:learnRecipe("Craft Combination Padlocks")
        player:learnRecipe("Craft Door Lock")
    end
end

Events.OnGameBoot.Add(onGameBoot);
Events.OnCreatePlayer.Add(updateTraits);