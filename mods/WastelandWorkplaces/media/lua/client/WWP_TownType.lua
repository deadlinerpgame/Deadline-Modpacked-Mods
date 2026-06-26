---
--- WWP_TownType.lua
--- 18/07/2024
---
require "WWP_Commodity"

WWP_TownType = {
	NPC_HUB = { displayName = "Trade Hub (NPC)", key = "hub_npc", banner = "npc-hub-town.png",
	            bonusIcon = "trade-bonus.png", bonusText = "+50%", isHub = true, customerWorkplaceBonus = 50,
	            bonusTooltip = "This town has a +50% bonus for all salaries provided in customer reliant workplaces.",
	            improvedWorkplaces = {}, openSound = "TownTradeHub", workPointMultipliers = {}, priceModifiers = {} },

	HUB = { displayName = "Trade Hub", key = "hub", banner = "hub-town.png",
	        bonusIcon = "trade-bonus.png", bonusText = "+50%", customerWorkplaceBonus = 50, isHub = true,
	        bonusTooltip = "This town has a +50% bonus for all salaries provided in customer reliant workplaces.",
	        improvedWorkplaces = {}, openSound = "TownTradeHub", workPointMultipliers = {}, priceModifiers = {} },

	FARMING = { displayName = "Farming Hamlet", key = "farminghamlet", banner = "farming-town.png",
	            bonusIcon = "grain-bonus.png", bonusText = "-50%", openSound = "TownFarm", improvedWorkplaces = { },
	            bonusTooltip = "This town has a 50% discount on work points when preparing Farm Produce for trade.\nFarm Produce requires fewer materials to pack here.\nTrade prices for Farm Produce are lower when buying or selling in this town.",
	            workPointMultipliers = {
		            [WWP_Commodity.FARM_PRODUCE] = 0.5,
	            },
	            priceModifiers = {
		            [WWP_Commodity.FARM_PRODUCE] = -20,
	            }
	},

	WOODLAND = { displayName = "Woodland Outpost", key = "woodlandoutpost", banner = "forest-town.png",
	             improvedWorkplaces = { }, openSound = "TownWoodland", bonusIcon = "tree-bonus.png", bonusText = "-50%",
	             bonusTooltip = "This town has a 50% discount on work points when preparing lumber for trade.\nLumber requires fewer materials to pack here.\nTrade prices for Lumber are lower when buying or selling in this town.",
	             workPointMultipliers = {
		             [WWP_Commodity.LUMBER] = 0.5,
	             },
	             priceModifiers = {
		             [WWP_Commodity.LUMBER] = -20,
	             }
	},

	-- Disabled for now as we removed stone commodity
--	MINING = { displayName = "Mining Town", key = "miningtown", banner = "mining-town.png", customerWorkplaceBonus = 10,
--	           improvedWorkplaces = {}, bonusIcon = "mine-bonus.png", bonusText = "-50%", openSound = "TownMining",
--	           bonusTooltip = "This town has a 50% discount on work points when preparing Quarried Stone for trade.\nQuarried Stone requires fewer materials to pack here.\nTrade prices for Quarried Stone are lower when buying or selling in this town.",
--	           workPointMultipliers = {
--		           [WWP_Commodity.STONE] = 0.5,
--	           },
--	           priceModifiers = {
--		           [WWP_Commodity.STONE] = -20,
--	           }
--	},

	DEN = { displayName = "Trapper's Den", key = "den", banner = "drifter-den.png",
	        bonusIcon = "meat-bonus.png", bonusText = "-50%", improvedWorkplaces = {}, openSound = "TownDrifers",
	        bonusTooltip = "This town has a 50% discount on work points when preparing hunted game for trade.\nHunted Game requires fewer materials to pack here.\nTrade prices for Hunted Game are lower when buying or selling in this town.",
	        workPointMultipliers = {
		        [WWP_Commodity.GAME] = 0.5,
	        },
	        priceModifiers = {
		        [WWP_Commodity.GAME] = -20,
	        }
	},

	FISHING = { displayName = "Fishing Village", key = "fishingvillage", banner = "fishing-village.png",
	            bonusIcon = "fishing-bonus.png", bonusText = "-50%", improvedWorkplaces = { }, openSound = "TownFishing",
	            bonusTooltip = "This town has a 50% discount on work points when preparing fish for trade.\nFish requires fewer materials to pack here.\nTrade prices for Fish are lower when buying or selling in this town.",
	            workPointMultipliers = {
		            [WWP_Commodity.FISH] = 0.5,
	            },
	            priceModifiers = {
		            [WWP_Commodity.FISH] = -20,
	            }
	},

	MOTOR = { displayName = "Motorworks", key = "motorworks", banner = "motorworks.png",
	          bonusIcon = "salvage-bonus.png", bonusText = "-50%", improvedWorkplaces = {}, openSound = "TownMotorworks",
	          bonusTooltip = "This town has a 50% discount on work points when preparing Metal Salvage for trade.\nMetal Salvage requires fewer materials to pack here.\nTrade prices for Metal Salvage are lower when buying or selling in this town.",
	          workPointMultipliers = {
		          [WWP_Commodity.METAL_SALVAGE] = 0.5,
	          },
	          priceModifiers = {
		          [WWP_Commodity.METAL_SALVAGE] = -30,
	          }
	},


	--FACTORY = { displayName = "Factory Town", key = "factorytown", banner="factory-town.png",
	--            bonusIcon="shells-bonus.png", bonusText="+10%",
	--            improvedWorkplaces = {"munitions_factory", "gun-crafter"}, openSound="TownFactory"},

}