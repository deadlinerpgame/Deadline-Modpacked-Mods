---
--- WWP_Commodity.lua
--- 12/07/2025
---

WWP_Commodity = {

	FARM_PRODUCE = {
		name = "Farm Produce",
		key = "farmProduce",
		itemType = "Base.ShippingPalletFarm",
		minPrice = 80,
		maxPrice = 110,
		buyWorkPoints = 10,
		recipes = { "PackFarmPallet", "PackFarmPalletDiscounted" },
		workPoints = 55,
	},

	FISH = {
		name = "Fish",
		key = "fish",
		itemType = "Base.ShippingPalletFish",
		minPrice = 100,
		maxPrice = 140,
		buyWorkPoints = 10,
		recipes = {  }, --TODO
		workPoints = 40,
		disabled = true,
	},

	GAME = {
		name = "Hunted Game",
		key = "game",
		itemType = "Base.ShippingPalletGame",
		minPrice = 100,
		maxPrice = 140,
		buyWorkPoints = 10,
		recipes = {  }, --TODO
		workPoints = 40,
		disabled = true,
	},

	LUMBER = {
		name = "Lumber",
		key = "lumber",
		itemType = "Base.ShippingPalletLumber",
		minPrice = 60,
		maxPrice = 90,
		buyWorkPoints = 10,
		recipes = { "PackLumberPallet", "PackLumberPalletDiscounted" },
		workPoints = 40,
	},

	METAL_SALVAGE = {
		name = "Metal Salvage",
		key = "metalSalvage",
		itemType = "Base.ShippingPalletScrap",
		minPrice = 130,
		maxPrice = 170,
		buyWorkPoints = 10,
		recipes = { "PackMetalPallet", "PackMetalPalletDiscounted" },
		workPoints = 75,
	},

	-- Normal game items

	BRASS_SCRAP = {
		name = "Brass Scrap",
		key = "BrassScrap",
		itemType = "Base.BrassScrap",
		minPrice = 23,
		maxPrice = 23,
		buyWorkPoints = 0,
	},

	ZEOLITE = {
		name = "Zeolite",
		key = "Zeolite",
		itemType = "Base.ZeoliteCatalyst",
		minPrice = 100,
		maxPrice = 100,
		buyWorkPoints = 0,
	}
}
