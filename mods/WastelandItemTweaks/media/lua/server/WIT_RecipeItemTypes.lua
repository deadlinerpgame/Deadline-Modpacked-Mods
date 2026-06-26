require "recipecode"

local BULLET_HELMET_NAMES = {
    ["Flecktarn_Camo_Helmet"] = true,
    ["Flecktarn_Camo_Helmet_NoBelts"] = true,
    ["OCP_Camo_Helmet"] = true,
    ["Medic_Helmet_Patriot"] = true,
    ["PrepperHelmet"] = true,
    ["Hat_Army_Desert"] = true,
    ["Hat_Army_Urban"] = true,
    ["Hat_Army"] = true,
    ["Rustic_Helmet_01"] = true,
    ["Black_Camo_Helmet_Patriot"] = true,
    ["Black_Camo_Helmet_Patriot_NoBelts"] = true,
    ["Desert_Camo_Helmet_Patriot"] = true,
    ["Desert_Camo_Helmet_Patriot_NoBelts"] = true,
    ["Forest_Camo_Helmet_Patriot"] = true,
    ["Forest_Camo_Helmet_Patriot_NoBelts"] = true,
    ["Alpine_Camo_Helmet_Patriot"] = true,
    ["Alpine_Camo_Helmet_Patriot_NoBelts"] = true,
    ["Woodland_Camo_Helmet_Patriot"] = true,
    ["Woodland_Camo_Helmet_Patriot_NoBelts"] = true,
    ["Alpine_Camo_Helmet_NoBelts"] = true,
    ["Alpine_Camo_Helmet"] = true,
    ["Black_Camo_Helmet"] = true,
    ["Black_Camo_Helmet_NoBelts"] = true,
    ["Caution_Helmet_Rook_FaceShield"] = true,
    ["Caution_Helmet_Rook_FaceShieldUp"] = true,
    ["Desert_Camo_Helmet"] = true,
    ["Desert_Camo_Helmet_NoBelts"] = true,
    ["EMR_Camo_Helmet"] = true,
    ["EMR_Camo_Helmet_NoBelts"] = true,
    ["Forest_Camo_Helmet"] = true,
    ["Forest_Camo_Helmet_NoBelts"] = true,
    ["SWAT_Helmet_AM-95_VisorDown"] = true,
    ["SWAT_Helmet_AM-95_VisorUp"] = true,
    ["SWAT_Helmet_Rook_FaceShield"] = true,
    ["SWAT_Helmet_Rook_FaceShieldUp"] = true,
    ["SWAT_Helmet"] = true,
    ["SWAT_Helmet_NoBelts"] = true,
    ["SWAT_Helmet_Patriot"] = true,
    ["SWAT_Helmet_Patriot_NoBelts"] = true,
    ["XKU_Camo_Helmet"] = true,
    ["XKU_Camo_Helmet_NoBelts"] = true,
}

local MELEE_HELMET_NAMES = {
    ["Hat_CrashHelmetFULL"] = true,
    ["Hat_CrashHelmet_Police"] = true,
    ["Hat_CrashHelmet_Stars"] = true,
    ["Hat_AuthenticCrashHelmet"] = true,
    ["Hat_RiotHelmet"] = true,
    ["Js_MotoHelmet_VisorDown"] = true,
    ["Js_MotoHelmet_VisorUp"] = true,
    ["Js_ScrapMotoHelmet_VisorDown"] = true,
    ["Js_ScrapMotoHelmet_VisorUp"] = true,
    ["Js_PunkScrapMotoHelmet_VisorDown"] = true,
    ["Js_PunkScrapMotoHelmet_VisorUp"] = true,
}

function Recipe.GetItemTypes.BulletHelmets(scriptItems)
    local allScriptItems = getScriptManager():getAllItems()
    for i=0, allScriptItems:size()-1 do
        local scriptItem = allScriptItems:get(i)
        if BULLET_HELMET_NAMES[scriptItem:getName()] then
            scriptItems:add(scriptItem)
        end
    end
end

function Recipe.GetItemTypes.MeleeHelmets(scriptItems)
    local allScriptItems = getScriptManager():getAllItems()
    for i=0, allScriptItems:size()-1 do
        local scriptItem = allScriptItems:get(i)
        if MELEE_HELMET_NAMES[scriptItem:getName()] then
            scriptItems:add(scriptItem)
        end
    end
end

function Recipe.GetItemTypes.CassetteSongs(scriptItems)
    local allScriptItems = getScriptManager():getAllItems()
    for i=0, allScriptItems:size()-1 do
        local scriptItem = allScriptItems:get(i)
        local displayName = scriptItem:getDisplayName() or ""
        if scriptItem:getModuleName() == "Tsarcraft"
            and string.find(scriptItem:getName(), "Cassette")
            and not (string.find(displayName, "%[ST%]") or string.find(displayName, "%[RARE%]")) then
            scriptItems:add(scriptItem)
        end
    end
end
