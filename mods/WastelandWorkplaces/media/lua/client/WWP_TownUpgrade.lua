---
--- WWP_TownUpgrade.lua
--- 31/08/2024
---
if not isClient() then return end

require "WWP_Commodity"
require "WWP_TownType"

WWP_TownUpgrade = {

	GENERATOR_ONE = { key = "gen1", name = "Wood-Fired Generator", upkeep = { [WWP_Commodity.LUMBER] = 3, },
					banner = "upgrade-woodgen.png", prerequisites = {}, needsTicket = true,
	                  description = "Provides constant power to a public building\nBurns timber inside a steam generator",
	                  requirements = "You must place the generator by a building accessible by\nvisitors, ideally in an area with workplaces and not private homes.\nExcessive strain on the generator will cause it to explode.",
	                  instructions = "You need to open a ticket with a screenshot of where you\nwant staff to place the generator.",
	},

	GENERATOR_TWO = { key = "gen2", name = "Biofuel Generator", upkeep = { [WWP_Commodity.FARM_PRODUCE] = 3, },
						banner = "upgade-biogen.png", prerequisites = {}, needsTicket = true,
	                  description = "Provides constant power to a public building\nUses biofuel from food to generate electricity",
	                  requirements = "You must place the generator by a building accessible by\nvisitors, ideally in an area with workplaces and not private homes.\nExcessive strain on the generator will cause it to explode.",
	                  instructions = "Open a ticket with a screenshot of where you\nwant staff to place the generator.",
	},

	DOCK = { key = "dock", name = "Dock", revenue = 40, upkeep = { [WWP_Commodity.LUMBER] = 2},
			banner = "upgrade-dock.png", prerequisites = {}, needsTicket = true,
	         revenueReason = "Ferry travelers pay docking and passage fees",
	         description = "A dock allows for ferries to transport\n people to and from the town for a small fee",
	         requirements = "You must build a dock of at least 8 x 4 tiles by the water.\nIt should be accessible to all citizens and visitors.",
	         instructions = "Open a ticket with a screenshot of your dock.",
	},

	TOWN_LINK = { key ="townLink", name = "Town Link", revenue=35, upkeep= { [WWP_Commodity.METAL_SALVAGE] = 1},
		banner = "upgrade-shuttle.png", prerequisites = {}, needsTicket = true,
		revenueReason = "Commuters and visitors increase local business revenue and tax income",
		description = "A shuttle service that connects to another town.\nUses metal salvage to repair the shuttle.",
		requirements = "Build a bus stop in your town by the side of a road.\nIt should be accessible to all citizens and visitors.",
		instructions = "Open a ticket with a screenshot of your bus stop.\nState which town you want the shuttle to connect to.",
	},

	TUNNEL_LINK = { key ="tunnelLink", name = "Tunnel Link", upkeep= { [WWP_Commodity.METAL_SALVAGE] = 1},
		banner = "upgrade-shuttle.png", prerequisites = {}, needsTicket = true,
		revenue=50, revenueReason = "Encourages trade and travel, boosting local economy",
		description = "A shuttle that connects to the nearest tunnel entrance.\nUses metal salvage to repair the shuttle.",
		requirements = "Build a bus stop in your town by the side of a road.\nIt should be accessible to all citizens and visitors.",
		instructions = "Open a ticket with a screenshot of your bus stop.",
	},

	FESTIVALS = { key = "festivals", name = "Festival Site", revenue = 60, upkeep = { [WWP_Commodity.FARM_PRODUCE] = 1 },
			banner = "upgrade-festival.png", prerequisites = {}, needsTicket = true,
	         revenueReason = "Event traffic increases stall sales and local trade taxes",
	         description = "Regular festivals attract visitors and commerce\nCharacters in town lose boredom and unhappiness",
	         requirements = "You must build an area suitable for a festival or large party\n(can be indoors or outdoors) and host an open event there.",
	         instructions = "Host a large festival or party, inviting everyone in the region.\nOpen a ticket with screenshots of your event.",
	},

	WOOD_EXPORT = { key = "woodExport", name = "Lumber Export Deal", revenue = 300, upkeep = { [WWP_Commodity.LUMBER] = 5 },
			banner = "upgrade-lumber-export.png", prerequisites = { }, needsTicket = true, townType = WWP_TownType.WOODLAND,
	         revenueReason = "Contracted buyers pay fixed rates for outbound lumber shipments",
	         description = "A profitable trade deal with a regional power\nLumber is exported for a fixed price",
	         requirements = "You must convince a major faction to sign a trade deal\nThe faction may demand concessions or other cooperation",
	         instructions = "Open an event ticket and request a meeting with the faction",
	},

	FOOD_EXPORT = { key = "foodExport", name = "Food Export Deal", revenue = 300, upkeep = { [WWP_Commodity.FARM_PRODUCE] = 4 },
			banner = "upgrade-food-export.png", prerequisites = { }, needsTicket = true, townType = WWP_TownType.FARMING,
	         revenueReason = "Regular farm exports generate guaranteed contract income",
	         description = "A profitable trade deal with a regional power\nFarm Produce is exported for a fixed price",
	         requirements = "You must convince a major faction to sign a trade deal\nThe faction may demand concessions or other cooperation",
	         instructions = "Open an event ticket and request a meeting with the faction",
	},

	METAL_EXPORT = { key = "metalExport", name = "Metal Export Deal", revenue = 300, upkeep = { [WWP_Commodity.METAL_SALVAGE] = 2 },
			banner = "upgrade-metal-export.png", prerequisites = { }, needsTicket = true, townType = WWP_TownType.MOTOR,
	         revenueReason = "Bulk salvage exports are sold at pre-agreed contract prices",
	         description = "A profitable trade deal with a regional power\nMetal Salvage is exported for a fixed price",
	         requirements = "You must convince a major faction to sign a trade deal\nThe faction may demand concessions or other cooperation",
	         instructions = "Open an event ticket and request a meeting with the faction",
	},

}
