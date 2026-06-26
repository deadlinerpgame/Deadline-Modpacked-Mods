--- 
--- WIT_TweakFlashlights.lua
--- 
--- 

local flashlights = {
    {"Base.KATTAJ1_TacticalFlashlight", "high"},
    {"Base.HandTorch", "low"},
    {"Base.Torch", "medium"},
    {"LTN_SL.Lantern", "low"},
    {"LTN_SL.GasLantern", "medium"},
    {"AuthenticZClothing.HandTorch2", "low"},
    {"AuthenticZClothing.Torch2", "medium"},
    {"AuthenticZClothing.Authentic_MilitaryFlashlightGrey", "low"},
    {"AuthenticZClothing.Authentic_MilitaryFlashlightGreen", "low"},
    {"AuthenticZClothing.Authentic_MinerLightbulb", "high"},
    {"UndeadSurvivor.PrepperFlashlight", "high"},
}

for _, data in ipairs(flashlights) do
    local fullType = data[1]
    local level = data[2]
    if getScriptManager():getItem(fullType) then
        local item = getScriptManager():getItem(fullType)
        if level == "low" then
            WL_Utils.setItemProperties(fullType, {
                ["UseDelta"] = 0.0002,
                ["LightStrength"] = 1,
                ["LightDistance"] = 15
            })
        elseif level == "medium" then
            WL_Utils.setItemProperties(fullType, {
                ["UseDelta"] = 0.0003,
                ["LightStrength"] = 2,
                ["LightDistance"] = 25
            })
        elseif level == "high" then
            WL_Utils.setItemProperties(fullType, {
                ["UseDelta"] = 0.0001,
                ["LightStrength"] = 1.5,
                ["LightDistance"] = 20
            })
        end
    end
end