local function StopFallingItems()
    local allScriptItems = getScriptManager():getAllItems()
    for i = 0, allScriptItems:size() - 1 do
        local item = allScriptItems:get(i)
        if item:getChanceToFall() > 0 then
            item:DoParam("ChanceToFall = 0")
        end
    end
end

Events.OnGameBoot.Add(StopFallingItems)
Events.OnLoad.Add(StopFallingItems)