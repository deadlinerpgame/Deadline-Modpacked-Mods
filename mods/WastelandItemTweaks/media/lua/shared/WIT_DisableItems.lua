local function RemoveDist(name)
    print("Removing dist: " .. name)
    for category, list in pairs(ProceduralDistributions["list"]) do
        for i, v in ipairs(list.items) do
            if v == name then
                print("Removing dist: " .. name .. " from " .. category)
                table.remove(list.items, i)
                table.remove(list.items, i)
                break
            end
        end
    end
end

local itemsToRemove = {}

local function DisableItem(itemId)
    print("Disabling item: " .. itemId)
    local item = ScriptManager.instance:getItem(itemId)
	if not item then
		print("ERROR: Item not found to modify: " .. itemId)
		return
	end
    item:DoParam("Weight = 999") -- to make any that happen to exist somehow be unmovable
    item:DoParam("OBSOLETE = TRUE")
    if itemId:contains(".") then
        local split = itemId:split(".")
        table.insert(itemsToRemove, split[2])
    end
    table.insert(itemsToRemove, itemId)

end

Events.OnDistributionMerge.Add(function()
    for _, v in ipairs(itemsToRemove) do
        RemoveDist(v)
    end
end)

--- Disable items

if getActivatedMods():contains("PertsPartyTiles") then
    DisableItem("Perts.BatLeth")
    DisableItem("Perts.MekLeth")
    DisableItem("Perts.AZZK_pistol")
    DisableItem("Perts.FirePoker")
    DisableItem("Perts.Trophy1")
    DisableItem("Perts.Trophy2")
    DisableItem("Perts.UmbrellaSword")
end

if getActivatedMods():contains("Trelai_4x4_Steam") then
    DisableItem("Trelai.Tshirt_TACADEMY")
    DisableItem("Trelai.Hat_TFireman")
    DisableItem("Trelai.Trousers_TFireman")
    DisableItem("Trelai.Jacket_TFireman")
    DisableItem("Trelai.Hat_TrelaiPolice")
    DisableItem("Trelai.Trousers_TrelaiPolice")
    DisableItem("Trelai.TrelaiJacket_Police")
    DisableItem("Trelai.BaseballBatTrelai")
    DisableItem("Trelai.TrelaiGoldBar")
    DisableItem("Trelai.trelainotes_01")
    DisableItem("Trelai.trelainotes_02")
    DisableItem("Trelai.TrelaiGuidePage0")
    DisableItem("Trelai.TrelaiGuidePage1")
    DisableItem("Trelai.TrelaiGuidePage2")
    DisableItem("Trelai.TrelaiGuidePage3")
    DisableItem("Trelai.TrelaiGuidePage4")
end

if getActivatedMods():contains("Daisy County") then
    DisableItem("Base.SuperMushroom")
    DisableItem("Base.556ClipofBill")
    DisableItem("Base.Boomerbileofjar")
    DisableItem("Base.VinifanBagSatchel")
    DisableItem("Base.SuperMugSpiffo")
    DisableItem("Base.SuperWaterMugSpiffo")
    DisableItem("Base.GoldenFertilizer")
    DisableItem("Base.PillsCrudestimulant")
    DisableItem("Base.Shisanxiang")
    DisableItem("Base.L4D2acousticequipment1")
    DisableItem("Base.L4D2acousticequipment2")
    DisableItem("Base.L4D2acousticequipment3")
    DisableItem("Base.vanillaalarmacousticequipment")
    DisableItem("Base.ScavengeSandwich")
    DisableItem("Base.BagofCatfood")
    DisableItem("Base.SpiffoPancakes")
    DisableItem("Base.SuperFlashlight")
    DisableItem("Base.DeveloperRevolverLong")
    DisableItem("Base.OneBarrelShotgun")
    DisableItem("Base.SuperTableLeg")
    DisableItem("Base.AssaultRifleofBill")
    DisableItem("Base.SuperWoodAxe")
    DisableItem("Base.SteelPickAxe")
    DisableItem("Base.ChurchPistol")
    DisableItem("Base.YZstick")
end

if getActivatedMods():contains("Authentic Z - Current") then
    DisableItem("AuthenticZClothing.Hat_SamuraiHelmet")
    DisableItem("AuthenticZClothing.Mask_Samurai")
    DisableItem("AuthenticZClothing.Vest_SamuraiBreastPlate")
    DisableItem("AuthenticZClothing.Leg_SamuraiShinGuards")
    DisableItem("AuthenticZClothing.GreeneZ_F")
    DisableItem("AuthenticZClothing.MandoSpear")
    DisableItem("AuthenticZClothing.Skin_Charcoal_Zed_M")
    DisableItem("AuthenticZClothing.Skin_Charcoal_Zed_W")
end

if getActivatedMods():contains("GanydeBielovzki's Frockin Wiseguys") then
    DisableItem("JW_Suit_Jacket")
    DisableItem("JW_Suit_Jacket_O")
    DisableItem("JW_Suit_Pants")
end

if getActivatedMods():contains("NewEkron") then
    DisableItem("Base.Rusty")
end

if getActivatedMods():contains("NewAlbany") then
    DisableItem("Base.BunkerMap")
end

if getActivatedMods():contains("SGarden-Homestead") then
    DisableItem("Sprout.RubberSeed")
    DisableItem("Sprout.RubberBagSeed")
    DisableItem("Sprout.TreeLatex")
end
