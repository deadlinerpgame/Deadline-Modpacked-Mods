---
--- WWP_TownRank.lua
--- 24/07/2024
---
---
WWP_TownRank = {
	STAFF = 30,

	TOWN_LEADER = 20,
	GOVERNMENT_HIGHEST = 15,
	GOVERNMENT_ADVISOR = 14,
	GOVERNMENT_MANAGER = 13,
	GOVERNMENT_CLERK = 12,
	GOVERNMENT_LOWEST = 11,

	ENFORCEMENT_LEADER = 10,
	ENFORCEMENT_HIGHEST = 5,
	ENFORCEMENT_LIEUTENANT = 4,
	ENFORCEMENT_MANAGER = 3,
	ENFORCEMENT_OFFICER = 2,
	ENFORCEMENT_LOWEST = 1,

	CITIZEN = 0,
}

WWP_TownRank.DEFAULT_RANK_NAMES = {
	[WWP_TownRank.TOWN_LEADER] = "Mayor",
	[WWP_TownRank.GOVERNMENT_HIGHEST] = "Deputy Mayor",
	[WWP_TownRank.GOVERNMENT_ADVISOR] = "Advisor",
	[WWP_TownRank.GOVERNMENT_MANAGER] = "Manager",
	[WWP_TownRank.GOVERNMENT_CLERK] = "Clerk",
	[WWP_TownRank.GOVERNMENT_LOWEST] = "Intern",

	[WWP_TownRank.ENFORCEMENT_LEADER] = "Chief of Police",
	[WWP_TownRank.ENFORCEMENT_HIGHEST] = "Captain",
	[WWP_TownRank.ENFORCEMENT_LIEUTENANT] = "Lieutenant",
	[WWP_TownRank.ENFORCEMENT_MANAGER] = "Sergeant",
	[WWP_TownRank.ENFORCEMENT_OFFICER] = "Officer",
	[WWP_TownRank.ENFORCEMENT_LOWEST] = "Deputy",
}

function WWP_TownRank.isGovernment(rank)
	if rank >= WWP_TownRank.GOVERNMENT_LOWEST and rank <= WWP_TownRank.GOVERNMENT_HIGHEST then return true end
	return rank == WWP_TownRank.TOWN_LEADER
end

function WWP_TownRank.isEnforcement(rank)
	if rank >= WWP_TownRank.ENFORCEMENT_LOWEST and rank <= WWP_TownRank.ENFORCEMENT_HIGHEST then return true end
	return rank == WWP_TownRank.ENFORCEMENT_LEADER
end

function WWP_TownRank.getNextPromotion(rank)
	if rank == WWP_TownRank.TOWN_LEADER or rank == WWP_TownRank.ENFORCEMENT_LEADER then return nil end
	if rank == WWP_TownRank.GOVERNMENT_HIGHEST then return WWP_TownRank.TOWN_LEADER end
	if rank == WWP_TownRank.ENFORCEMENT_HIGHEST then return WWP_TownRank.ENFORCEMENT_LEADER end
	return rank + 1
end

function WWP_TownRank.getNextDemotion(rank)
	if rank == WWP_TownRank.GOVERNMENT_LOWEST or rank == WWP_TownRank.ENFORCEMENT_LOWEST then return nil end
	if rank == WWP_TownRank.TOWN_LEADER then return WWP_TownRank.GOVERNMENT_HIGHEST end
	if rank == WWP_TownRank.ENFORCEMENT_LEADER then return WWP_TownRank.ENFORCEMENT_HIGHEST end
	return rank - 1
end