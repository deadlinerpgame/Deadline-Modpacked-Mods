---
--- WWP_WorkplaceAction.lua
--- 02/08/2024
---

WWP_WorkplaceAction = {

	BANDAGES = {
		name = "Prepare Bandages",
		skill = Perks.Doctor,
		animation = "Craft",
		minSkill = 2,
		work = 10,
		rollsMin = 2,
		rollsMax = 6,
		items = {
			["Base.Bandage"] = 1,
		},
	},

	BREADS = {
		name = "Bake Breads",
		skill = Perks.Cooking,
		work = 25,
		rollsMin = 1,
		rollsMax = 4,
		animation = "VehicleWorkOnMid",
		items = {
			["Base.Bread"] = 3,
			["Base.Baguette"] = 4,
			["Base.BagelPoppy"] = 3,
			["Base.BagelSesame"] = 3,
			["Base.Biscuit"] = 2,
		},
	},

	BOOKS = {
		name = "Find Lost Books",
		work = 10,
		rollsMin = 2,
		rollsMax = 5,
		items = {
			["Base.Book"] = 8,
			["Base.Magazine"] = 1,
		},
	},

	CAKES = {
		name = "Bake Cakes",
		skill = Perks.Cooking,
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Cupcake"] = 3,
			["Base.CakeCarrot"] = 3,
			["Base.CakeChocolate"] = 3,
			["Base.CakeRedVelvet"] = 5,
			["Base.CakeCheeseCake"] = 1,
			["Base.CakeBlackForest"] = 1,
			["Base.CakeStrawberryShortcake"] = 4,
		},
	},

	CANS = {
		name = "Stock Cans",
		work = 10,
		rollsMin = 1,
		rollsMax = 4,
		items = {
			["Base.TinnedBeans"] = 1,
			["Base.CannedCorn"] = 1,
			["Base.CannedCornedBeef"] = 1,
			["Base.CannedFruitCocktail"] = 1,
			["Base.CannedMushroomSoup"] = 1,
			["Base.CannedPeaches"] = 1,
			["Base.CannedPeas"] = 1,
			["Base.CannedPineapple"] = 1,
			["Base.CannedPotato2"] = 1,
			["Base.CannedSardines"] = 2,
			["Base.TinnedSoup"] = 1,
			["Base.CannedBolognese"] = 1,
			["Base.CannedTomato2"] = 1,
			["Base.TunaTin"] = 1,
			["Base.Dogfood"] = 1,
		},
	},

	CHINESE_FOOD = {
		name = "Defrost Chinese Food",
		skill = Perks.Cooking,
		work = 20,
		rollsMin = 1,
		rollsMax = 4,
		items = {
			["Base.MeatDumpling"] = 3,
			["Base.ShrimpDumpling"] = 3,
			["Base.Springroll"] = 3,
			["Base.TofuFried"] = 2,
			["Base.Ramen"] = 2,
			["Base.Seaweed"] = 1,
			["Base.Wasabi"] = 1,
		},
	},

	DONUTS = {
		name = "Make Donuts",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		animation = "VehicleWorkOnMid",
		items = {
			["Base.DoughnutPlain"] = 1,
			["Base.DoughnutFrosted"] = 3,
			["Base.DoughnutChocolate"] = 3,
			["Base.DoughnutJelly"] = 3,
		},
	},

	FEATHERS = {
		name = "Pluck a Chicken",
		skill = Perks.Farming,
		work = 10,
		rollsMin = 3,
		rollsMax = 5,
		multiplier = 5,
		animation = "VehicleTrailer",
		items = {
			["Base.WLFeather"] = 1,
		},
	},
	JARS = {
		name = "Stock Jarred Foods",
		work = 10,
		rollsMin = 1,
		rollsMax = 4,
		items = {
			["Base.CannedBellPepper"] = 1,
			["Base.CannedBroccoli"] = 1,
			["Base.CannedCabbage"] = 1,
			["Base.CannedCarrots"] = 1,
			["Base.CannedEggplant"] = 1,
			["Base.CannedLeek"] = 2,
			["Base.CannedPotato"] = 1,
			["Base.CannedRedRadish"] = 1,
			["Base.CannedTomato"] = 1,
		},
	},

	METAL_SHEETS = {
		name = "Detach Car Panels",
		skill = Perks.MetalWelding,
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		animation = "RemoveCurtain",
		items = {
			["Base.SheetMetal"] = 1,
			["Base.SmallSheetMetal"] = 2,
		},
	},

	MUSTARD = {
		name = "Make Mustard",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Mustard"] = 3,
		},
	},

	SPEED = {
		name = "Cook Speed",
		mod = "WastelandMedical",
		work = 80,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["SpeedBox"] = 1,
		},
	},

	XANAX = {
		name = "Make Xanax Pills",
		mod = "WastelandMedical",
		work = 70,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["PillsXanax"] = 1,
		},
	},

	CRACK = {
		name = "Make Crack",
		mod = "WastelandMedical",
		work = 80,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["CrackCocaine"] = 1,
		},
	},

	COCAINE = {
		name = "Cut Cocaine",
		mod = "WastelandMedical",
		work = 80,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["CocaineBrick"] = 1,
		},
	},

	OXYCODONE = {
		name = "Formulate Oxycodone",
		mod = "WastelandMedical",
		work = 70,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["PillsOxycodone"] = 1,
		},
	},

	METH = {
		name = "Cook Meth",
		mod = "WastelandMedical",
		work = 80,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Methamphetamine"] = 1,
		},
	},

	HEROIN = {
		name = "Create Heroin Tar",
		mod = "WastelandMedical",
		work = 80,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["BlackTarHeroin"] = 1,
		},
	},

	PAINTS = {
		name = "Mix Paints",
		skill = Perks.Carpentry,
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.PaintRed"] = 1,
			["Base.PaintBlue"] = 1,
			["Base.PaintYellow"] = 1,
			["Base.PaintGreen"] = 1,
			["Base.PaintPurple"] = 1,
			["Base.PaintOrange"] = 1,
			["Base.PaintWhite"] = 1,
			["Base.PaintBlack"] = 1,
			["Base.PaintGrey"] = 1,
		},
	},

	RARE_SEEDS = {
		name = "Gather Rare Seeds",
		mod = "SGarden-Homestead",
		skill = Perks.Farming,
		minSkill = 8,
		work = 10,
		rollsMin = 2,
		rollsMax = 5,
		multiplier = 5,
		items = {
			["Sprout.PearSeeds"] = 1,
			["Sprout.CommonMallowSeeds"] = 1,
			["Sprout.PlantainSeeds"] = 1,
			["Sprout.ComfreySeeds"] = 1,
			["Sprout.GarlicSeeds"] = 1,
			["Sprout.BlackSageSeeds"] = 1,
			["Sprout.AppleSeed"] = 1,
			["Sprout.AvocadoSeed"] = 1,
			["Sprout.BananaSeed"] = 1,
			["Sprout.BellPepperSeed"] = 1,
			["Sprout.BerryBlackSeed"] = 1,
			["Sprout.BerryBlueSeed"] = 1,
			["Sprout.CherrySeed"] = 1,
			["Sprout.CornSeed"] = 1,
			["Sprout.EggplantSeed"] = 1,
			["Sprout.GingerSeed"] = 1,
			["Sprout.GinsengSeed"] = 1,
			["Sprout.GrapefruitSeed"] = 1,
			["Sprout.GrapeSeed"] = 1,
			["Sprout.LeekSeed"] = 1,
			["Sprout.LemongrassSeed"] = 1,
			["Sprout.LemonSeed"] = 1,
			["Sprout.LettuceSeed"] = 1,
			["Sprout.LimeSeed"] = 1,
			["Sprout.MangoSeed"] = 1,
			["Sprout.MushroomSpores"] = 1,
			["Sprout.OliveSeed"] = 1,
			["Sprout.OnionSeed"] = 1,
			["Sprout.OrangeSeed"] = 1,
			["Sprout.PeachSeed"] = 1,
			["Sprout.PineappleSeed"] = 1,
			["Sprout.PumpkinSeed"] = 1,
			["Sprout.SoyBeanSeed"] = 1,
			["Sprout.SugarCaneSeed"] = 1,
			["Sprout.WatermelonSeed"] = 1,
			["Sprout.WheatSeed"] = 1,
			["Sprout.ZucchiniSeed"] = 1,
			["Sprout.RiceSeed"] = 1,
			["Sprout.PepperPlantSeed"] = 1,
			["Sprout.CottonSeed"] = 1,
			["Sprout.HopsSeed"] = 1,
			["Sprout.TeaSeed"] = 1,
			["Sprout.CoffeeSeed"] = 1,
		},
	},

	RUM = {
		name = "Brew Rum",
		mod = "WLsapphcooking",
		skill = Perks.Brewing,
		work = 15,
		rollsMin = 2,
		rollsMax = 5,
		items = {
			["SapphCooking.RumFull"] = 1,
		},
	},

	SAKE = {
		name = "Brew Sake",
		mod = "WLsapphcooking",
		skill = Perks.Brewing,
		work = 15,
		rollsMin = 2,
		rollsMax = 5,
		items = {
			["SapphCooking.SakeFull"] = 1,
		},
	},

	SEEDS = {
		name = "Gather Common Seeds",
		mod = "SGarden-Homestead",
		skill = Perks.Farming,
		minSkill = 4,
		work = 5,
		rollsMin = 2,
		rollsMax = 5,
		multiplier = 5,
		items = {
			["farming.TomatoSeed"] = 3,
			["farming.PotatoSeed"] = 3,
			["farming.CabbageSeed"] = 3,
			["farming.CarrotSeed"] = 3,
			["farming.BroccoliSeed"] = 2,
			["farming.RedRadishSeed"] = 2,
			["farming.StrewberrieSeed"] = 2,
			["Sprout.BellPepperSeed"] = 2,
			["Sprout.GrapeSeed"] = 1,
			["Sprout.LemongrassSeed"] = 1,
			["Sprout.CornSeed"] = 2,
			["Sprout.RiceSeed"] = 1,
		},
	},

	SOUP = {
		name = "Cook big soup",
		skill = Perks.Cooking,
		minSkill = 4,
		work = 15,
		rollsMin = 2,
		rollsMax = 8,
		items = {
			["Base.SoupBowl"] = 1,
		},
	},

	SOY_SAUCE = {
		name = "Make Soy Sauce",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Soysauce"] = 1,
		},
	},

	WONTON = {
		name = "Make Wonton Wrappers",
		mod = "WLsapphcooking",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.BagofWontonWrappers"] = 1,
		},
	},

	YEAST = {
		name = "Ferment Yeast",
		skill = Perks.Brewing,
		work = 25,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Yeast"] = 1,
		},
	},

	YARN = {
		name = "Spin Yarn",
		skill = Perks.Tailoring,
		minSkill = 4,
		work = 5,
		rollsMin = 1,
		rollsMax = 5,
		items = {
			["Base.Yarn"] = 1,
		},
	},

	--- Kaostic Added

	BREWING_SUPPLIES = {
		name = "Unbox Brewing Supplies",
		mod = "MoreBrews",
		skill = Perks.Brewing,
		minSkill = 3,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["MoreBrews.CorksBag"] = 2,
			["MoreBrews.RubberBandsBag"] = 3,
			["MoreBrews.BottleCapsBag"] = 2,
			["Base.BeerCanEmpty"] = 3,
			["Base.BeerEmpty"] = 3,
			["Base.WineEmpty"] = 3,
			["Base.WineEmpty2"] = 3,
			["MoreBrews.EmptyCarboy"] = 1,
			["MoreBrews.EmptyBarrelDispenserSmall"] = 1,
		},
	},

	BREAKROOM = {
		name = "Visit Break Room",
		skill = Perks.Maintenance,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Coffee2"] = 3,
			["Base.Teabag2"] = 3,
			["Base.Sugar"] = 1,
			["Base.DoughnutPlain"] = 3,
			["Base.DoughnutFrosted"] = 3,
			["Base.DoughnutJelly"] = 3,
			["Base.MuffinFruit"] = 3,
			["Base.Plonkies"] = 1,
		},
	},

	BUTTER = {
		name = "Churn Butter",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.Butter"] = 1,
		},
	},

	COOKINGUTENSILS = {
		name = "Unpack Cooking Utensils",
		mod = "WLsapphcooking",
		skill = Perks.Cooking,
		minSkill = 1,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.MetalWhisk"] = 1,
			["SapphCooking.DoughnutCutter"] = 1,
			["SapphCooking.PipingBags"] = 1,
			["SapphCooking.BakingMolds"] = 1,
			["SapphCooking.ClothFilter"] = 1,
			["SapphCooking.WoodenSkewers"] = 1,
			["SapphCooking.MessTray"] = 1,
			["SapphCooking.PizzaCutter"] = 1,
			["SapphCooking.Laddle"] = 1,
			["SapphCooking.MeatTenderizer"] = 1,
			["SapphCooking.WokPan"] = 1,
			["SapphCooking.EmptyThermos"] = 1,
			["SapphCooking.PlasticFilterHolder"] = 1,
			["SapphCooking.CoffeeGrinder"] = 1,
		},
	},

	CHOCOLATE = {
		name = "Unwrap Chocolate",
		mod = "WLsapphcooking",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.Chocolate"] = 1,
			["SapphCooking.WhiteChocolate"] = 1,
		},
	},

	CLOTH = {
		name = "Tear Strips",
		skill = Perks.Tailoring,
		animation = "Craft",
		work = 5,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 10,
		items = {
			["Base.LeatherStrips"] = 1,
			["Base.DenimStrips"] = 1,
			["Base.RippedSheets"] = 1,
		},
	},

	ENGINE_PARTS = {
		name = "Dismantle an Old Engine",
		skill = Perks.Mechanics,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 5,
		items = {
			["Base.EngineParts"] = 1,
		},
	},

	FERTILIZER = {
		name = "Shovel Manure",
		skill = Perks.Farming,
		animation = CharacterActionAnims.DigShovel,
		work = 25,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 4,
		items = {
			["Base.Fertilizer"] = 1,
		},
	},

	SEAWEED = {
		name = "Dredge Up Seaweed",
		skill = Perks.Fishing,
		minSkill = 2,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 10,
		multiplier = 2,
		items = {
			["Base.Seaweed"] = 10,
			["Base.BaitFish"] = 1,
		},
	},

	FISH_ROE = {
		name = "Gather Roe",
		skill = Perks.Fishing,
		minSkill = 4,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 5,
		items = {
			["Base.FishRoe"] = 4,
		},
	},

	SHRIMP = {
		name = "Net Shrimp",
		skill = Perks.Fishing,
		minSkill = 5,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 5,
		items = {
			["Base.Shrimp"] = 4,
		},
	},

	OYSTERS = {
		name = "Dive for Oysters",
		skill = Perks.Fishing,
		minSkill = 7,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 7,
		multiplier = 2,
		items = {
			["Base.Oysters"] = 1,
		},
	},

	LOBSTER = {
		name = "Trap Lobster",
		skill = Perks.Fishing,
		minSkill = 9,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.Lobster"] = 1,
		},
	},

	SQUID = {
		name = "Catch Squid",
		skill = Perks.Fishing,
		minSkill = 10,
		animation = "Craft",
		work = 25,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Squid"] = 1,
		},
	},

	FISHING_SUPPLIES = {
		name = "Unpack Fishing Supplies",
		skill = Perks.Fishing,
		minSkill = 2,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.FishingLine"] = 4,
			["Base.FishingTackle"] = 4,
			["Base.FishingTackle2"] = 4,
			["Base.FishingRod"] = 1,
		},
	},

	FORAGE = {
		name = "Forage the Grounds",
		skill = Perks.PlantScavenging,
		minSkill = 3,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Apple"] = 3,
			["Base.Banana"] = 3,
			["Base.BellPepper"] = 3,
			["Base.Carrots"] = 5,
			["farming.Cabbage"] = 3,
			["Base.Cockroach"] = 8,
			["Base.Cricket"] = 8,
			["Base.Grasshopper"] = 8,
			["Base.Lettuce"] = 3,
			["Base.Peanuts"] = 4,
			["Base.PeanutButter"] = 1,
			["Base.Worm"] = 8,
			["farming.Potato"] = 3,
			["farming.Tomato"] = 3,
		},
	},

	GASTANK = {
		name = "Repair Old Gas Tanks",
		skill = Perks.Mechanics,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.NormalGasTank1"] = 2,
			["Base.NormalGasTank2"] = 2,
			["Base.NormalGasTank3"] = 2,
			["Base.BigGasTank1"] = 1,
			["Base.BigGasTank2"] = 1,
			["Base.BigGasTank3"] = 1,
		},
	},

	GUNPARTS = {
		name = "Pull apart Guns",
		mod = "WastelandFirearms",
		skill = Perks.Gunsmith,
		minSkill = 5,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.ClipSpring"] = 3,
			["Base.MachinedClipSteel"] = 1,
			["Base.MachinedFirearmComponents"] = 1,
		},
	},

	GUNPOWDERSHELL = {
		name = "Pull apart Bullets",
		mod = "WastelandFirearms",
		skill = Perks.Gunsmith,
		minSkill = 5,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.GunPowder"] = 10,
			["Base.ShellCasings"] = 5,
			["Base.ShellCasingsBox"] = 1
		},
	},

	GUNTOOLS = {
		name = "Search for Tools",
		skill = Perks.GunSmith,
		minSkill = 1,
		work = 15,
		rollsMin = 1,
		rollsMax = 2,
		animation = "RemoveCurtain",
		items = {
			["Base.Wrench"] = 1,
			["Base.Screwdriver"] = 1,
			["Base.BallPeenHammer"] = 1,
		},
	},

	GUNMETAL = {
		name = "Pry Apart Metal",
		skill = Perks.MetalWelding,
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		animation = "Craft",
		items = {
			["Base.SheetMetal"] = 1,
			["Base.SmallSheetMetal"] = 3,
			["Base.MetalPipe"] = 3,
		},
	},

	HOTDRINK = {
		name = "Find Beverage Powders",
		mod = "WLsapphcooking",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Coffee2"] = 4,
			["Base.CocoaPowder"] = 2,
			["SapphCooking.CoffeePacket"] = 2,
			["SapphCooking.BoxofTeaBags"] = 3,
			["SapphCooking.PackofCoffeeFilters"] = 5,
			["SapphCooking.CoffeeBeansBag"] = 5,
		},
	},

	HUNT = {
		name = "Hunt for Small Game",
		skill = Perks.Trapping,
		minSkill = 6,
		animation = "Craft",
		work = 30,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.DeadBird"] = 15,
			["Base.DeadMouse"] = 20,
			["Base.DeadRabbit"] = 10,
			["Base.DeadRat"] = 20,
			["Base.DeadSquirrel"] = 20,
		},
	},

	INSTRUMENTS = {
		name = "Unpack Instrument",
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.Saxophone"] = 1,
			["Base.Trumpet"] = 1,
			["Base.Violin"] = 1,
			["Base.Drumstick"] = 1,
			["Base.Flute"] = 1,
			["Base.GuitarAcoustic"] = 1,
		},
	},

	ELECTRIC_GUITARS = {
		name = "Paint Electric Guitar",
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.GuitarElectricBassBlack"] = 1,
			["Base.GuitarElectricBassBlue"] = 1,
			["Base.GuitarElectricBassRed"] = 1,
			["Base.GuitarElectricBlack"] = 1,
			["Base.GuitarElectricBlue"] = 1,
			["Base.GuitarElectricRed"] = 1,
		},
	},

	JUICE = {
		name = "Mix Juice Bottles",
		mod = "WLsapphcooking",
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.BottleofOrangeJuice"] = 1,
			["SapphCooking.BottleofAppleJuice"] = 1,
			["SapphCooking.BottleofStrawberryJuice"] = 1,
			["SapphCooking.BottleofPeachJuice"] = 1,
			["SapphCooking.BottleofGrapeJuice"] = 1,
			["SapphCooking.BottleofWatermelonJuice"] = 1,
			["SapphCooking.BottleofLemonJuice"] = 1,
		},
	},

	KEVLAR = {
		name = "Weave Kevlar",
		mod = "WastelandItemTweaks",
		skill = Perks.Tailoring,
		minSkill = 8,
		animation = "Craft",
		work = 15,
		rollsMin = 2,
		rollsMax = 6,
		items = {
			["Base.KevlarSheet"] = 1,
		},
	},

	FROGS = {
		name = "Chop up Frogs",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.FrogMeat"] = 4,
		},
	},

	PORK = {
		name = "Chop Pork",
		skill = Perks.Cooking,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.PorkChop"] = 4,
		},
	},

	MECHTOOLS = {
		name = "Find Mechanic Tools",
		skill = Perks.Mechanics,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Wrench"] = 1,
			["Base.Jack"] = 1,
			["Base.LugWrench"] = 1,
			["Base.TirePump"] = 1,
		},
	},

	MINE = {
		name = "Mine for Stone",
		mod = "WastelandBuilds",
		skill = Perks.Strength,
		minSkill = 6,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 7,
		items = {
			["Base.Stone"] = 12,
			["Base.WastelandBuildsPyrite"] = 1,
			["Base.WastelandBuildsSaltpeter"] = 1,
			["Base.WastelandBuildsLimestone"] = 1,
			["Base.WastelandBuildsIronOre"] = 2,
			["Base.WastelandBuildsNahcolite"] = 1,
		},
	},

	MINE_IRON = {
		name = "Mine for Iron Ore",
		mod = "WastelandBuilds",
		skill = Perks.Strength,
		minSkill = 6,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 7,
		items = {
			["Base.WastelandBuildsIronOre"] = 12,
			["Base.Stone"] = 5,
			["Base.WastelandBuildsPyrite"] = 1,
			["Base.WastelandBuildsSaltpeter"] = 1,
			["Base.WastelandBuildsLimestone"] = 1,
			["Base.WastelandBuildsNahcolite"] = 1,
		},
	},

	MINEZEOLITE = {
		name = "Mine for Zeolite",
		mod = "WastelandBuilds",
		skill = Perks.Strength,
		minSkill = 6,
		animation = "Craft",
		work = 45,
		rollsMin = 1,
		rollsMax = 1,
		multiplier = 1,
		items = {
			["Base.ZeoliteCatalyst"] = 1,
		},
	},

	MINETOOLS = {
		name = "Find New Tools",
		mod = "WastelandBuilds",
		skill = Perks.Strength,
		animation = "Craft",
		work = 50,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.Shovel"] = 5,
			["Base.PickAxe"] = 3,
		},
	},

	MUFFLER = {
		name = "Repair Old Mufflers",
		skill = Perks.Mechanics,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.NormalCarMuffler1"] = 2,
			["Base.NormalCarMuffler2"] = 2,
			["Base.NormalCarMuffler3"] = 2,
			["Base.ModernCarMuffler1"] = 1,
			["Base.ModernCarMuffler2"] = 1,
			["Base.ModernCarMuffler3"] = 1,
		},
	},

	NAILS = {
		name = "Gather Nails",
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.NailsBox"] = 4,
			["Base.Nails"] = 1,
		},
	},

	PROTEIN = {
		name = "Open Protein Package",
		mod = "WLsapphcooking",
		skill = Perks.Strength,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.CanofProteinPowder"] = 1,
			["SapphCooking.BottlewithProteinShake"] = 23,
			["SapphCooking.ProteinBar"] = 8,
		},
	},

	SCREWS = {
		name = "Gather Screws",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.ScrewsBox"] = 1,
			["Base.Screws"] = 2,
		},
	},

	SNACKS = {
		name = "Put out Snacks",
		animation = "Craft",
		work = 5,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Peanuts"] = 5,
			["Base.Crisps"] = 1,
			["Base.Crisps2"] = 1,
			["Base.Pop"] = 1,
			["Base.Pop2"] = 1,
			["Base.TortillaChips"] = 1,
		},
	},

	SOUPTOOLS = {
		name = "Find Utensils",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Saucepan"] = 1,
			["Base.Pot"] = 1,
			["Base.Fork"] = 1,
			["Base.Spoon"] = 1,
		},
	},

	SPIRITS = {
		name = "Distill Spirits",
		mod = "WLsapphcooking",
		skill = Perks.Brewing,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.WhiskeyFull"] = 5,
			["SapphCooking.SakeFull"] = 3,
			["SapphCooking.RumFull"] = 4,
			["SapphCooking.GinFull"] = 3,
			["SapphCooking.TequilaFull"] = 2,
			["SapphCooking.LiqueurBottle"] = 2,
			["SapphCooking.VodkaFull"] = 8,
		},
	},

	VERMOUTH = {
		name = "Produce Vermouth",
		mod = "WLsapphcooking",
		skill = Perks.Brewing,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.Vermouth"] = 8,
		},
	},

	STATIONARY = {
		name = "Get New Stationary",
		skill = Perks.Maintenance,
		animation = "Craft",
		work = 5,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.SheetPaper2"] = 4,
			["Base.Notebook"] = 1,
			["Base.RedPen"] = 1,
			["Base.Pencil"] = 1,
			["Base.BluePen"] = 1,
			["Base.Eraser"] = 1,
			["Base.Scissors"] = 1,
			["Base.MugRed"] = 1,
			["Base.MugWhite"] = 1,
			["Base.MugSpiffo"] = 1,
		},
	},

	SUSPENSION = {
		name = "Repair Old Suspension",
		skill = Perks.Mechanics,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.NormalSuspension1"] = 2,
			["Base.NormalSuspension2"] = 2,
			["Base.NormalSuspension3"] = 2,
			["Base.ModernSuspension1"] = 1,
			["Base.ModernSuspension2"] = 1,
			["Base.ModernSuspension3"] = 1,
		},
	},

	THREAD = {
		name = "Spool Thread",
		skill = Perks.Tailoring,
		minSkill = 1,
		animation = "Craft",
		work = 5,
		rollsMin = 1,
		rollsMax = 4,
		items = {
			["Base.Thread"] = 1,
		},
	},

	TOWEL = {
		name = "Clean & Dry Towels",
		skill = Perks.Strength,
		animation = "Craft",
		work = 5,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.BathTowel"] = 15,
			["Base.BathTowelWet"] = 1,
		},
	},

	AXE = {
		name = "Find a new Axe",
		skill = Perks.Axe,
		minSkill = 1,
		animation = "Craft",
		work = 45,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.WoodAxe"] = 1,
		},
	},

	LOGTRASH = {
		name = "Clean Up Workspace",
		skill = Perks.Woodwork,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 15,
		items = {
			["Base.Twigs"] = 8,
			["Base.TreeBranch"] = 6,
			["Base.BirdNest"] = 1,
		},
	},

	ROPE = {
		name = "Coil Rope",
		skill = Perks.Woodwork,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 8,
		items = {
			["Base.Rope"]=1,
		},
	},

	WOODREPAIR = {
		name = "Repair Tools",
		skill = Perks.Woodwork,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.Woodglue"] = 3,
			["Base.Glue"] = 1,
			["Base.DuctTape"] = 1,
			["Base.Scotchtape"] = 1,
		},
	},

	SCRAP_METAL = {
		name = "Pull Apart Scrap",
		skill = Perks.MetalWelding,
		minSkill = 3,
		work = 20,
		rollsMin = 2,
		rollsMax = 10,
		multiplier = 1,
		items = {
			["Base.ScrapMetal"] = 10,
			["Base.UnusableMetal"] = 4,
			["Base.MetalBar"] = 3,
			["Base.LeadPipe"] = 1,
			["Base.MetalPipe"] = 1,
			["Base.Wire"] = 2,
			["Base.Screws"] = 1,
			["Base.Hinge"] = 1,
		},
	},

	SCRAP_ELECTRONICS = {
		name = "Salvage Electronic Parts",
		skill = Perks.Electricity,
		minSkill = 3,
		work = 20,
		rollsMin = 2,
		rollsMax = 10,
		multiplier = 1,
		items = {
			["Base.ElectronicsScrap"] = 10,
			["Radio.ElectricWire"] = 3,
			["Base.Battery"] = 1,
			["Base.Aluminum"] = 1,
			["Base.Amplifier"] = 1,
			["Radio.RadioTransmitter"] = 1,
			["Radio.RadioReceiver"] = 1,
		},
	},

	TIRES = {
		name = "Detach Old Tires",
		animation = "Craft",
		skill = Perks.Mechanics,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 1,
		items = {
			["Base.OldTire1"] = 2,
			["Base.OldTire2"] = 2,
			["Base.OldTire3"] = 2,
			["Base.NormalTire1"] = 1,
			["Base.NormalTire2"] = 1,
			["Base.NormalTire3"] = 1,
			["Base.ModernTire1"] = 1,
			["Base.ModernTire2"] = 1,
			["Base.ModernTire3"] = 1,
		},
	},

	PROPANE = {
		name = "Refill Propane Storage",
		mod = "TheWorkshop(new version)",
		animation = "Craft",
		skill = Perks.MetalWelding,
		work = 15,
		rollsMin = 1,
		rollsMax = 2,
		items = {
			["Base.BlowTorch"] = 30,
			["Base.PropaneTank"] = 5,
			["TW.LargePropaneTank"] = 1,
		},
	},

	FRIES = {
		name = "Cook Fries",
		mod = "WLsapphcooking",
		animation = "Craft",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Fries"] = 5,
			["Base.FriedOnionRings"] = 1,
		},
	},

	NUGGETS = {
		name = "Cook Chicken Nuggets",
		animation = "Craft",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.ChickenNuggets"] = 1,
		},
	},

	FRYFOOD = {
		name = "Fry Food",
		mod = "WLsapphcooking",
		animation = "Craft",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.FriedBirdMeat"] = 1,
			["Base.FishFried"] = 1,
			["Base.ShrimpFried"] = 1,
			["Base.Corndog"] = 1,
		},
	},

	PAPER_BAGS = {
		name = "Find Paper Bags",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.PaperBag"] = 5,
		},
	},

	POPDRINK = {
		name = "Grab some Pop",
		animation = "Craft",
		skill = Perks.Cooking,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Pop"] = 1,
			["Base.Pop2"] = 1,
			["Base.Pop3"] = 1,
		},
	},

	FRUIT = {
		name = "Unbox Fruit",
		animation = "Craft",
		skill = Perks.Farming,
		work = 10,
		rollsMin = 1,
		rollsMax = 4,
		multiplier = 3,
		items = {
			["Base.Apple"] = 5,
			["Base.Avocado"] = 2,
			["Base.Pear"] = 5,
			["Base.Banana"] = 5,
			["Base.Cherry"] = 2,
			["Base.Grapefruit"] = 2,
			["Base.Grapes"] = 2,
			["Base.Orange"] = 5,
			["Base.Peach"] = 5,
			["Base.Pineapple"] = 2,
			["Base.Watermelon"] = 1,
		},
	},

	VEGETABLES = {
		name = "Unbox Vegetables",
		animation = "Craft",
		skill = Perks.Farming,
		work = 10,
		rollsMin = 1,
		rollsMax = 4,
		multiplier = 3,
		items = {
			["Base.BellPepper"] = 5,
			["Base.Broccoli"] = 2,
			["Base.Cabbage"] = 5,
			["Base.Carrots"] = 5,
			["Base.Corn"] = 1,
			["Base.Eggplant"] = 2,
			["Base.Leek"] = 5,
			["Base.Onion"] = 5,
			["Base.Potato"] = 1,
			["Base.Radish"] = 5,
			["Base.Zucchini"] = 2,
		},
	},

	SACKS = {
		name = "Find Sacks",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.EmptySandbag"] = 5,
		},
	},

	MUSIC_SHEET = {
		name = "Compose a Song",
		mod = "WastelandMusicians",
		work = 30,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["MOTW.SheetMusic"] = 1,
		},
	},

	-- DO NOT DELETE. IS NOT EMPTY. FILLS FUNCTION AT BOTTOM
	CASSETTES = {
		name = "Sort Cassette Tapes",
		mod = "Project Songboid Too",
		animation = "Craft",
		skill = Perks.PseudonymousEdPiano,
		work = 15,
		rollsMin = 2,
		rollsMax = 4,
		items = {},
	},
	-- DO NOT DELETE. IS NOT EMPTY. FILLS FUNCTION AT BOTTOM

	CLEAN_TAPES = {
		name = "Wipe Tapes for Broadcast",
		mod = "WastelandRpChat",
		animation = "Craft",
		skill = Perks.Electricity,
		minSkill = 4,
		work = 30,
		rollsMin = 1,
		rollsMax = 4,
		items = {
			["Base.WRCRecorderTape"] = 10,
			["Base.WRCRecorder"] = 1,
		},
	},

	FIX_RADIOS = {
		name = "Fix Old Radios",
		mod = "WastelandItemTweaks",
		animation = "Craft",
		skill = Perks.Electricity,
		minSkill = 5,
		work = 30,
		rollsMin = 1,
		rollsMax = 2,
		multiplier = 1,
		items = {
			["Radio.WalkieTalkie2"] = 20,
			["Radio.WalkieTalkie3"] = 15,
			["Radio.WalkieTalkie4"] = 1,
		},
	},

	BREAK_TIME = {
		name = "Go on a Break",
		animation = "Craft",
		mod = "WLsapphcooking",
		work = 5,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Cigarettes"] = 5,
			["SapphCooking.MugBrewCoffee"] = 3,
			["SapphCooking.MugBrewCoffee2"] = 3,
			["SapphCooking.MugBrewCoffee3"] = 3,
			["SapphCooking.MugBrewCoffee4"] = 3,
			["SapphCooking.CakeSlice_Chocolate"] = 1,
			["Base.TortillaChips"] = 1,
		},
	},

	RECHARGE_INK = {
		name = "Recharge Your Inks",
		mod = "Ellie'sTattooParlor",
		animation = "Craft",
		skill = Perks.Nimble,
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 2,
		items = {
			["ElliesTattooParlor.FilledTattooNeedle"] = 15,
			["ElliesTattooParlor.EmptyTattooNeedle"] = 1,
		},
	},

	ORDER_INK = {
		name = "Order More Ink",
		mod = "Ellie'sTattooParlor",
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["ElliesTattooParlor.TattoosInkBox"] = 1,
		},
	},

	STERALISE_SURFACE = {
		name = "Sterilize Workspace",
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		multiplier = 2,
		items = {
			["Base.AlcoholWipes"] = 10,
			["Base.Disinfectant"] = 1,
		},
	},

	PROCESS_LUMBER = {
		name = "Process Lumber",
		animation = "Craft",
		skill = Perks.Woodwork,
		minSkill = 2,
		work = 15,
		rollsMin = 1,
		rollsMax = 4,
		multiplier = 5,
		items = {
			["Base.Plank"] = 10,
			["Base.UnusableWood"] = 1,
		},
	},

	PREPAREMEAT = {
        name = "Prepare Meats",
        mod = "WLsapphcooking",
        animation = "Craft",
        skill = Perks.Trapping,
        work = 10,
        rollsMin = 1,
        rollsMax = 3,
        multiplier = 2,
        items = {
            ["Base.Baloney"] = 4,
            ["Base.Chicken"] = 4,
            ["Base.ChickenFoot"] = 1,
            ["Base.FrogMeat"] = 1,
            ["Base.Pepperoni"] = 4,
            ["Base.Rabbitmeat"] = 5,
            ["Base.Salami"] = 4,
            ["Base.Sausage"] = 5,
            ["SapphCooking.FrankfurterSausage"] = 4,
            ["SapphCooking.ViennaSausage"] = 4,
            ["Base.Ham"] = 1,
            ["Base.MuttonChop"] = 4,
            ["Base.PorkChop"] = 4,
            ["SapphCooking.TurkeyLegs"] = 3,
        },
    },

    PREPAREFISH = {
        name = "Prepare Fish",
        animation = "Craft",
        skill = Perks.Fishing,
        work = 20,
        rollsMin = 1,
        rollsMax = 3,
        multiplier = 2,
        items = {
            ["Base.Bass"] = 1,
            ["Base.Catfish"] = 3,
            ["Base.Crappie"] = 5,
            ["Base.Crayfish"] = 2,
            ["Base.Oysters"] = 5,
            ["Base.Perch"] = 2,
            ["Base.Pike"] = 1,
            ["Base.Salmon"] = 5,
            ["Base.Shrimp"] = 5,
            ["Base.Squid"] = 5,
            ["Base.Panfish"] = 5,
            ["Base.Trout"] = 1,
        },
    },

    MEATUTENSILS = {
        name = "Find Essential Utensils",
        mod = "WLsapphcooking",
        animation = "Craft",
        skill = Perks.Cooking,
        work = 20,
        rollsMin = 1,
        rollsMax = 3,
        items = {
            ["SapphCooking.MeatTenderizer"] = 1,
            ["SapphCooking.Meatgrinder"] = 1,
            ["SapphCooking.ChefKnife1"] = 1,
        },
    },

    MEATEXTRAS = {
        name = "Unpack Extra Meat Products",
        mod = "WLsapphcooking",
        animation = "Craft",
        skill = Perks.Cooking,
        work = 10,
        rollsMin = 1,
        rollsMax = 3,
        multiplier = 3,
        items = {
            ["SapphCooking.FryBatter"] = 1,
            ["SapphCooking.BeefBroth"] = 1,
            ["SapphCooking.ChickenBroth"] = 1,
			["SapphCooking.SausageCasing"] = 1,
        },
    },

	SPIRITSBAR = {
		name = "Unbox Spirits",
		mod = "WLsapphcooking",
		skill = Perks.Brewing,
		animation = "Craft",
		work = 15,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.WhiskeyFull"] = 5,
			["SapphCooking.SakeFull"] = 3,
			["SapphCooking.RumFull"] = 4,
			["SapphCooking.GinFull"] = 3,
			["SapphCooking.TequilaFull"] = 2,
			["SapphCooking.LiqueurBottle"] = 2,
			["SapphCooking.VodkaFull"] = 8,
		},
	},


	BEERS = {
		name = "Unbox Brewing Supplies",
		mod = "MoreBrews",
		skill = Perks.Brewing,
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.BeerCan"] = 3,
			["MoreBrews.BeerCanAmericanLager"] = 2,
			["MoreBrews.BeerCanAPA1"] = 2,
			["MoreBrews.BeerCanIPA2"] = 2,
			["MoreBrews.BeerCanAPA2"] = 2,
			["MoreBrews.BeerCanLightLager"] = 2,
			["MoreBrews.BeerCanPilsner"] = 2,
			["MoreBrews.BeerCanPorter"] = 2,
			["MoreBrews.BeerCanSkunked"] = 1,
			["MoreBrews.BeerCanStout"] = 2,
		},
	},

	GLASSES = {
		name = "Unbox Glasses",
		mod = "WLsapphcooking",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["SapphCooking.LowballGlass"] = 1,
			["Base.GlassTumbler"] = 1,
			["SapphCooking.CocktailGlass"] = 1,
			["Base.GlassWine"] = 1,
		},
	},

	CROCKWARE = {
		name = "Unbox Crockware",
		animation = "Craft",
		work = 10,
		rollsMin = 1,
		rollsMax = 3,
		items = {
			["Base.Mugl"] = 1,
			["Base.MugRed"] = 1,
			["Base.MugSpiffo"] = 1,
			["Base.MugWhite"] = 1,
			["Base.Plate"] = 1,
			["Base.Teacup"] = 1,
		},
	},

	FABRICGLUE = {
		name = "Mix Fabric Glue",
		skill = Perks.Tailoring,
		minSkill = 6,
		animation = "Craft",
		work = 20,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.FabricGlue"] = 1,
		},
	},

	INJECTABLES1 = {
	        name = "Synthesize Narcotics",
	        skill = Perks.Doctor,
 		work = 20,
		minSkill = 8,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.MorphineVial"] = 1,
			["Base.SedativeVial"] = 1,
			["Base.OpioidsCureVial"] = 1,
		},
	},

	INJECTABLES2 = {
		name = "Prepare Injectable Medications",
		skill = Perks.Doctor,
		work = 80,
		minSkill = 8,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.CyanideCureVial"] = 1,
			["Base.AdrenalineVial"] = 1,
			["Base.No2CureVial"] = 1,
			["Base.SulfideCureVial"] = 1,
		},
	},

	ORAL = {
		name = "Formulate Oral Medications",
		skill = Perks.Doctor,
		work = 80,
		minSkill = 8,
		rollsMin = 1,
		rollsMax = 1,
		items = {
			["Base.PillsFluCure"] = 1,
			["Base.PillsChloroquine"] = 1,
			["Base.PotassiumIodide"] = 1,
			["Base.Antibiotics"] = 1,
		},
	},

}

Events.OnGameBoot.Add(function()
    local allScriptItems = getScriptManager():getAllItems()
    for i=0, allScriptItems:size()-1 do
        local scriptItem = allScriptItems:get(i)
        if scriptItem:getModuleName() == "Tsarcraft" and string.find(scriptItem:getName(), "Cassette") and not (string.find(scriptItem:getDisplayName(), "%[ST%]") or string.find(scriptItem:getDisplayName(), "%[RARE%]")) then
            WWP_WorkplaceAction.CASSETTES.items[scriptItem:getFullName()] = 1
        end
    end
end)

