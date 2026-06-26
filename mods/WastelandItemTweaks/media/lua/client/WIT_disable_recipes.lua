local ToDisable = {};

local function doDisable()
    local allRecipes = getAllRecipes()
    for i=0, allRecipes:size()-1 do
        local recipe = allRecipes:get(i);
        if recipe ~= nil then
            for _,v in pairs(ToDisable) do
                if recipe:getName() == v then
                    recipe:setNeedToBeLearn(true);
                    recipe:setIsHidden(true);
                    recipe:setLuaTest("WIT_recipes.OnTest_False");
                end
            end
        end
    end
end

local function DisableRecipe(recipe)
    table.insert(ToDisable, recipe);
end
Events.OnGameBoot.Add(doDisable);

DisableRecipe("Make Cheese Sandwich")

if not getActivatedMods():contains("MoreBrews") then
    DisableRecipe("Exchange for Alternate Currency")
end

-- Disables Churn Butter

if getActivatedMods():contains("WLsapphcooking") then
    DisableRecipe("Churn Butter")
end

-- Disables Spinning Thread and Spinning yarn in Favour of our own.

if getActivatedMods():contains("SGarden-Homestead") then
    DisableRecipe("Spin Thread")
end

if getActivatedMods():contains("SGarden-Homestead") then
    DisableRecipe("Spin Yarn")
end

-- Disables some Sprout recipes for rebalance + typo fixing
if getActivatedMods():contains("SGarden-Homestead") then
    DisableRecipe("Make PortaSmoker")
    DisableRecipe("Smoke MuttonChop")
    DisableRecipe("Smoke Rabbitmeat")
    DisableRecipe("Smoke PorkChop")
    DisableRecipe("Make Canned Bass")
    DisableRecipe("Make Canned Catfish")
    DisableRecipe("Make Canned Chicken")
    DisableRecipe("Make Canned MuttonChop")
    DisableRecipe("Make Canned Ham")
    DisableRecipe("Make Canned Pike")
    DisableRecipe("Make Canned PorkChop")
    DisableRecipe("Make Canned Rabbitmeat")
    DisableRecipe("Make Canned Salmon")
    DisableRecipe("Make Canned Steak")
    DisableRecipe("Make Canned Sunfish")
    DisableRecipe("Make Canned Trout")
    DisableRecipe("Make Jar of Preserved Mushrooms")
    DisableRecipe("Make Jar of Preserved Lemongrass")
    DisableRecipe("Make Jar of Preserved Ginseng")
    DisableRecipe("Make Jar of Preserved Ginger")
    DisableRecipe("Make Jar of Preserved Eggplant")
    DisableRecipe("Make Jar of Preserved BellPepper")
    DisableRecipe("Make Jar of Preserved Leek")
    DisableRecipe("Make Yeast")
    DisableRecipe("Make Tofu")
    DisableRecipe("Make Butter")
    DisableRecipe("Make Cheese")
    DisableRecipe("Make Pasta")
    DisableRecipe("Make Vinegar")
end

if getActivatedMods():contains("SGarden-Homestead") then
    DisableRecipe("Destory Rose Bouquet")
    DisableRecipe("Destory Geranium Bouquet")
    DisableRecipe("Destory Delphinium Bouquet")
    DisableRecipe("Destory Penta Bouquet")
    DisableRecipe("Destory Dahlia Bouquet")
    DisableRecipe("Destory Larkspur Bouquet")
end

-- Disables Gun Diassembly from the Workshop to avoid confusion
if getActivatedMods():contains("TheWorkshop(new version)") then
   DisableRecipe("Disassamble Gun")
end


