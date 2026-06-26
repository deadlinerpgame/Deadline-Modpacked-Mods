local SmallBeltFrontLeft = {
	type = "SmallBeltFrontLeft",
	name = "Belt Front Left", -- Name shown in the slot icon
	animset = "belt left",
	attachments = { -- list of possible item category and their modelAttachement group, the item category is defined in the item script
		Knife = "Belt Front Left Upside", -- defined in AttachedLocations.lua
		Hammer = "Belt Front Left",
		HammerRotated = "Belt Rotated Front Left",
		Nightstick = "Nightstick Front Left",
		Screwdriver  = "Belt Front Left Screwdriver",
		Wrench = "Wrench Front Left",
		MeatCleaver = "MeatCleaver Belt Front Left",
		Walkie = "Walkie Belt Front Left",
	},
}
table.insert(ISHotbarAttachDefinition, SmallBeltFrontLeft);

local SmallBeltFrontRight = {
	type = "SmallBeltFrontRight",
	name = "Belt front Right",
	animset = "belt right",
	attachments = {
		Knife = "Belt Front Right Upside",
		Hammer = "Belt Front Right",
		HammerRotated = "Belt Rotated Front Right",
		Nightstick = "Nightstick Front Right",
		Screwdriver  = "Belt Front Right Screwdriver",
		Wrench = "Wrench Front Right",
		MeatCleaver = "MeatCleaver Belt Front Right",
		Walkie = "Walkie Belt Front Right",
	},
}
table.insert(ISHotbarAttachDefinition, SmallBeltFrontRight);
