local function disableItem(itemId)
    local item = ScriptManager.instance:getItem(itemId)
    if item then
        item:DoParam("Hidden = TRUE")
        item:DoParam("OBSOLETE = TRUE")
    end
end

disableItem("Base.Padlock")
disableItem("Base.CombinationPadlock")
