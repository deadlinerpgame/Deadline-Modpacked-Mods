require('NPCs/MainCreationMethods');

local function onGameBoot()

    TraitFactory.addTrait("Lazy", getText("UI_trait_lazy"), -2,
            getText("UI_trait_lazydesc"), false, false)

    TraitFactory.addTrait("Industrious", getText("UI_trait_Industrious"), 2,
            getText("UI_trait_Industriousdesc"), false, false)

    TraitFactory.setMutualExclusive("Lazy", "Industrious")
end


Events.OnGameBoot.Add(onGameBoot);
