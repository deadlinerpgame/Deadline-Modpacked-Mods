require "AuthenticZ_RecipeCode"

-- Only run is AuthenticZ is installed
if not AZRecipe then return end

-- Override XP from 20 to 6
function AZRecipe.OnGiveXP.Tailoring20(AZRecipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Tailoring, 6);
end

Give20TailoringXP = AZRecipe.OnGiveXP.Tailoring20
