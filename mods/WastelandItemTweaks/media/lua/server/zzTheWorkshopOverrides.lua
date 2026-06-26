---
--- zzTheWorkshopOverrides.lua
--- 11/07/2023
---

function DeconstructGun_OnCreate(items, result, player)
	player:getInventory():AddItem("Base.MetalPipe")
	player:getInventory():AddItem("Base.ScrapMetal")
	player:getInventory():AddItem("Base.ScrapMetal")
end

