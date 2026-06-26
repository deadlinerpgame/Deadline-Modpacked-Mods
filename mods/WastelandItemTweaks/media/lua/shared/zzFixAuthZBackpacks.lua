---
--- zzFixAuthZBackpacks.lua
--- Reduces the absurd number of slots on AuthZ backpacks that push your quick bar into the chat window
--- 2023/07/28
---

--TODO School Bag
--TODO Normal Hiking Bag

-- Big Hiking Bag
local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_BigHikingBag_Tier_1")
if item then
	item:DoParam("	AttachmentsProvided = BigHikingbagSecondary;BigHikingbagFlashlight;BigHikingbagItemSlot1;BigHikingBagBottleLeft;BigHikingbagPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_BigHikingBag_Tier_2")
if item then
	item:DoParam("	AttachmentsProvided = BigHikingbagSecondary;BigHikingbagFlashlight;BigHikingbagItemSlot1;BigHikingbagItemSlot2;BigHikingBagBottleLeft;BigHikingbagPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_BigHikingBag_Tier_3")
if item then
	item:DoParam("	AttachmentsProvided  = 	BigHikingbagSecondary;BigHikingbagFlashlight;BigHikingbagItemSlot1;BigHikingbagItemSlot2;BigHikingBagBottleLeft;BigHikingbagPlushie")
end

-- Regular Alice Pack
local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Tier_1")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Tier_2")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Tier_3")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackItemSlot1;AlicepackBottleLeft;AlicepackPlushie")
end

-- Armybro Alice Pack
local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Army_Tier_1")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Army_Tier_2")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Army_Tier_3")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackItemSlot1;AlicepackBottleLeft;AlicepackPlushie")
end

-- Urban Camo Alice Pack
local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_UrbanCamo_Tier_1")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_UrbanCamo_Tier_2")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_UrbanCamo_Tier_3")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackItemSlot1;AlicepackBottleLeft;AlicepackPlushie")
end


-- Festive Alice Pack
local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Festive_Tier_1")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Festive_Tier_2")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackBottleLeft;AlicepackPlushie")
end

local item = ScriptManager.instance:getItem("AuthenticZClothing.Bag_ALICEpack_Festive_Tier_3")
if item then
	item:DoParam("AttachmentsProvided = AlicepackFlashlight;AlicepackItemSlot1;AlicepackBottleLeft;AlicepackPlushie")
end


