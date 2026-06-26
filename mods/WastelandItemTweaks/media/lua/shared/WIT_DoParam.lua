require "WL_Utils"

if getActivatedMods():contains("Ellie'sTattooParlor") then
    --ellies tattoo parlor
    local items = {"ElliesTattooParlor.TattoosInkBox","ElliesTattooParlor.LacticAcid"}
    for i=1, #items do
        if items[i] then
            ScriptManager.instance:getItem(items[i]):DoParam("Weight = 8")
            ScriptManager.instance:getItem(items[i]):DoParam("UseDelta = 0.5")
        end
    end
end