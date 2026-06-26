---
--- WIT_ZumeoMedicalEffects.lua
---

if not getActivatedMods():contains("WastelandMedical") then return end

require "WME_FoodMedicalCondition"

local ZUMEO_FOOD_TYPES = {
	"Base.Chocolate",
	"Base.Crisps",
	"Base.Crisps2",
	"Base.Crisps3",
	"Base.Crisps4",
	"Base.GranolaBar",
	"Base.Cereal",
	"Base.CerealBowl",
	"Base.TortillaChips",
	"Base.HiHis",
	"Base.Pop",
	"Base.JuiceBox",
	"Base.SnoGlobes",
}

for _, fullType in ipairs(ZUMEO_FOOD_TYPES) do
	WME_FoodMedicalCondition.registerBuiltInCondition(fullType, WME_Condition.ZUMEO_DOPAMINE, 10)
end
