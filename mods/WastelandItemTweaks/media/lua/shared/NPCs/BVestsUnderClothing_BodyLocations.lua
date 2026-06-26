--***********************************************************
--**                    THE INDIE STONE                    **
--***********************************************************

-- Locations must be declared in render-order.
-- Location IDs must match BodyLocation= and CanBeEquipped= values in items.txt.
local group = BodyLocations.getGroup("Human")

--Create vests under Jackets Shirts and Sweaters
group:getOrCreateLocation("TorsoExtraVestUnderJS")

--Can't wear Vests under Jackets and Sweaters with other Vests
group:setExclusive("TorsoExtraVestUnderJS", "TorsoExtraVest")
group:setExclusive("TorsoExtraVestUnderJS", "TorsoExtra")

--Hiding vests
group:setHideModel("Sweater", "TorsoExtraVestUnderJS")
group:setHideModel("SweaterHat", "TorsoExtraVestUnderJS")
group:setHideModel("FullTop", "TorsoExtraVestUnderJS")
group:setHideModel("BathRobe", "TorsoExtraVestUnderJS")
group:setHideModel("BodyCostume", "TorsoExtraVestUnderJS")
group:setHideModel("TorsoExtra", "TorsoExtraVestUnderJS")
group:setHideModel("JacketSuit", "TorsoExtraVestUnderJS")
group:setHideModel("Jacket_Bulky", "TorsoExtraVestUnderJS")
group:setHideModel("JacketHat_Bulky", "TorsoExtraVestUnderJS")
group:setHideModel("Tshirt", "TorsoExtraVestUnderJS")
group:setHideModel("ShortSleeveShirt", "TorsoExtraVestUnderJS")
group:setHideModel("Shirt", "TorsoExtraVestUnderJS")

