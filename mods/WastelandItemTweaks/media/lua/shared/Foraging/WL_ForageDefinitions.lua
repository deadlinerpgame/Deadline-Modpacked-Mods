require 'Foraging/forageSystem'

Events.onAddForageDefs.Add(function()

	local birdNest = {
		type = "Base.BirdNest",
		xp=10,
		rainChance = -20,
		snowChance = -20,
        categories = { "Animals" },
		zones = {
			Forest      = 5,
			DeepForest  = 10,
			Vegitation  = 5,
			FarmLand    = 5,
			Farm        = 5,
		},
		canBeAboveFloor = true,
	};
	forageSystem.addItemDef(birdNest);
end)