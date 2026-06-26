-- Simplify favoriting to reduce the size of mod data strings
function ISCraftingUI:getFavoriteModDataString(recipe)
    local text = "craftingFavorite:" .. recipe:getOriginalname();
    return text;
end

function ISCraftingUI:getFavoriteModDataLocalString(recipe) -- For backward compatibility only
    local text = "craftingFavorite:" .. recipe:getName();
    return text;
end

if CHC_main then
    function CHC_main.common.getFavoriteRecipeModDataString(recipe)
        if recipe.recipeData.isSynthetic then return 'testCHC' .. recipe.recipe:getOriginalname() end
        recipe = recipe.recipe
        local text = "craftingFavorite:" .. recipe:getOriginalname();
        return text;
    end
end