---
--- WWP_GovernmentType.lua
--- 22/07/2024
---

WWP_GovernmentType = {
	ANARCHY = {displayName = "Anarchy", key = "anarchy", bonusIcon="red-coins.png", bonusText="0%", incomeBonus=0,
	           bonusTextColor={r=1,g=0,b=0,a=1 },
	           tooltip="The town is in complete disarray, with no government structure in place. Taxes are locked at 0%."},

	ARISTOCRACY = {displayName = "Aristocracy", key = "aristocracy", bonusIcon="coins-bonus.png",
					bonusText="+15%", incomeBonus=15, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a small group of wealthy and powerful individuals who hold all the political power. Ordinary citizens must curry favor with the nobility to get anything done."},

    COUNCIL = {displayName = "Council", key = "council", bonusIcon="coins-bonus.png",
				bonusText="+15%", incomeBonus=15, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is governed by a tight-knit council of representatives who make decisions collectively."},

	AUTOCRACY = {displayName = "Autocracy", key = "autocracy", bonusIcon="coins-bonus.png",
	             bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a single powerful despot who holds all of the power."},

	JUNTA = { displayName = "Military Junta", key = "junta", bonusIcon="coins-bonus.png",
	          bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
	          tooltip="This town is ruled by a military junta that has taken control by force. Martial law is in permanent effect."},

	MONARCHY = {displayName = "Monarchy", key = "monarchy", bonusIcon="coins-bonus.png",
	            bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a monarch and their royal family, who will inherit the throne if the ruler dies. It might also have nobles, knights and all that other weird medieval stuff."},

	TECHNOCRACY = {displayName = "Technocracy", key = "technocracy", bonusIcon="coins-bonus.png",
	             bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is governed by engineers and experts in old world technology and science, prioritizing technical solutions to problems."},

	COMMUNIST = {displayName = "Communism", key = "communist", bonusIcon="coins-bonus.png",
				bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a communist party that controls all aspects of life. Resources are distributed equally among the population... in theory."},

	THEOCRACY = {displayName = "Theocracy", key = "theocracy", bonusIcon="coins-bonus.png",
	             bonusText="+18%", incomeBonus=18, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a supreme religious leader, with laws and policies based on religious doctrine. Committing blasphemy here is a really bad idea."},

	OLIGARCHY = {displayName = "Oligarchy", key = "oligarchy", bonusIcon="coins-bonus.png",
	             bonusText="+21%", incomeBonus=21, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by a small group of powerful individuals from different factions working together. This can cause lengthy discussions, but collaboration brings benefits."},

	REPUBLIC = {displayName = "Republic", key = "republic", bonusIcon="coins-bonus.png",
				bonusText="+21%", incomeBonus=21, bonusTextColor={r=1,g=1,b=0,a=1 },
				tooltip="This town is ruled by an elected president who represents the interests of the citizens. Elections are held regularly and policies may swing with the political winds."},


}