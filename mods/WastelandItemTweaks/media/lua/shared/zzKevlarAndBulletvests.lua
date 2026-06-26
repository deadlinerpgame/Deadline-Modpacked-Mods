---
--- zzKevlarAndBulletvests.lua
--- 03/08/2023
---

-- This doesn't actually work to patch holes, but we need to override the mod making vests leather so I left it in

require 'RepairAnyAuthenticZ'

ClothingRecipesDefinitions["FabricType"]["Kevlar"] = {}
ClothingRecipesDefinitions["FabricType"]["Kevlar"].material = "Base.KevlarSheet";
ClothingRecipesDefinitions["FabricType"]["Kevlar"].tools = "Base.Scissors";
ClothingRecipesDefinitions["FabricType"]["Kevlar"].noSheetRope = true;


local itemsToFuckOffItemTweaker = {}

local function makeVestKevlarAndHeavier(vest)
    if vest then
        local item = ScriptManager.instance:getItem(vest)
        if item then
            table.insert(itemsToFuckOffItemTweaker, vest)
            item:DoParam("FabricType = Kevlar")
            item:DoParam("Weight = 2.0")
        end
    end
end

local function addBulletProtectionToHelmet(helmet)
    if helmet then
        local item = ScriptManager.instance:getItem(helmet)
        if item then
            table.insert(itemsToFuckOffItemTweaker, helmet)
            item:DoParam("BulletDefense = 10")
        end
    end
end

local bulletVests = { "Base.Vest_BulletArmy", "Base.Vest_BulletCivilian", "Base.Vest_BulletPolice"}
for i=1, #bulletVests do
	makeVestKevlarAndHeavier(bulletVests[i])
end

if getActivatedMods():contains("WastelandClothing") then
	local wastelandVests = { "Base.Vest_BulletArmy_IB", "Base.Chinatown_Sheriff_Vest"}
	for i=1, #wastelandVests do
		makeVestKevlarAndHeavier(wastelandVests[i])
	end

	addBulletProtectionToHelmet("Base.Hat_Army_IB")
end

if getActivatedMods():contains("Authentic Z - Current") then
	local authZBulletVests = { "AuthenticZClothing.Vest_BulletBlack", "AuthenticZClothing.Vest_BulletRPD",
	                           "AuthenticZClothing.Vest_BulletKilla", "AuthenticZClothing.Vest_BulletTagilla",
	                           "AuthenticZClothing.Vest_BulletTV110_BulletVest"}
	for i=1, #authZBulletVests do
		makeVestKevlarAndHeavier(authZBulletVests[i])
	end
end

if getActivatedMods():contains("Swatpack-Wasteland") then
	makeVestKevlarAndHeavier("Base.Vest_BulletSwat")
	addBulletProtectionToHelmet("Base.Hat_SwatHelmet")
end

addBulletProtectionToHelmet("Base.Hat_Army")

if getActivatedMods():contains("UndeadSuvivorTweaked-Wasteland") then
	addBulletProtectionToHelmet("UndeadSurvivor.PrepperHelmet")
end

if getActivatedMods():contains("JordanExtraStuff") then
	local jordanVests = { "Base.Vest_BulletArmy_Urban", "Base.Vest_BulletArmy_Desert", "Base.Olive_BulletproofVest",
	                      "Base.FDRF_BulletproofVest_01", "Base.Press_BulletproofVest", "Base.BastionVest" }
	for i=1, #jordanVests do
		makeVestKevlarAndHeavier(jordanVests[i])
	end
end

if getActivatedMods():contains("JordansExtraStuff 2.0") then
	local jordanTwoVests = { "Base.Olive_BulletproofVest", "Alpine_Camo_Vest", "Alpine_Camo_LightVest", "Black_Camo_Vest", "Black_Camo_LightVest",
							"Caution_BulletproofVest", "Desert_Camo_Vest", "Desert_Camo_LightVest", "EMR_Camo_Vest", "EMR_Camo_LightVest",
							"Flecktarn_Camo_Vest", "Flecktarn_Camo_LightVest", "Forest_Camo_Vest", "Forest_Camo_LightVest", "OCP_Camo_Vest", 
							"OCP_Camo_LightVest", "Tintable_BulletproofVest", "Urban_Camo_Vest", "Urban_Camo_LightVest",
							"Woodland_Camo_Vest", "Woodland_Camo_LightVest", "XKU_Camo_Vest", "XKU_Camo_LightVest", "Medic_BulletproofVest_Patriot", 
							"Medical_Red_BulletproofVest_Patriot", "Caution_BulletproofVest", "Vest_BulletArmy_Desert", "Press_BulletproofVest",
							"Vest_BulletArmy_Urban", "Base.Firefighter_BulletproofVest_Patriot", "Base.Neon_Vandals_Vest", "Umbrella_Corp_Vest", "95_Camo_LightVest",  "95_Camo_Vest",
							"SWAT_Enforcer_Vest", "SWAT-Green_Enforcer_Vest", "SWAT_Vest", "SWAT_LightVest", "SWAT_Protector_Vest"}
	local jordanFactionVests = { "PlayerFaction_BedequePD_Vest", "PlayerFaction_CEF_LightVest", "PlayerFaction_SIN_LightVest", "Haven_BulletproofVest_01", 
	                             "PlayerFaction_RUBY_Vest", "PlayerFaction_Crows_Vest",  }
	for i=1, #jordanTwoVests do
		makeVestKevlarAndHeavier(jordanTwoVests[i])
	end
	for i=1, #jordanFactionVests do
		makeVestKevlarAndHeavier(jordanFactionVests[i])
	end
end

if getActivatedMods():contains("WastelandS4") then
	local cornVests = { "Base.Vest_BulletHounds", "Base.Vest_BulletExodus" }
	for i=1, #cornVests do
		makeVestKevlarAndHeavier(cornVests[i])
	end
end

Events.OnGameBoot.Add(function ()
	if TweakItemData then
		for _, item in ipairs(itemsToFuckOffItemTweaker) do
			TweakItemData[item] = nil
		end
	end
end)