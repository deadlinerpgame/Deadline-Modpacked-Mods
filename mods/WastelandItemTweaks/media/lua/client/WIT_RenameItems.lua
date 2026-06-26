---
--- WIT_RenameItems.lua
--- 18/05/2025
---

if getActivatedMods():contains("Authentic Z - Current") then

	WL_Utils.setItemProperties("AuthenticZClothing.Hat_BandanaMaskDesert", {
		["DisplayName"] = "Makeshift Bandana (Face)",
	})

	WL_Utils.setItemProperties("AuthenticZClothing.Hat_BandanaDesert", {
		["DisplayName"] = "Makeshift Bandana (Head)",
	})

	WL_Utils.setItemProperties("AuthenticZClothing.Hat_BandanaTiedDesert", {
		["DisplayName"] = "Makeshift Bandana (Tied)",
	})

end