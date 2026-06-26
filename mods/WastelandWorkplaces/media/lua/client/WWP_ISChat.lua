local original_onGearButtonClick = ISChat.onGearButtonClick
function ISChat:onGearButtonClick()
    original_onGearButtonClick(self)
    local context = getPlayerContextMenu(0)
    if context then
        local myPlayer = getPlayer()
        local x = myPlayer:getX()
        local y = myPlayer:getY()
        local z = myPlayer:getZ()
        local workplaces = WWP_WorkplaceZone.getZonesAt(x, y, z)
        for _, workplace in ipairs(workplaces) do
            if workplace:isEmployee(myPlayer) then
                local md = myPlayer:getModData()
                if md["WWP_DisableAlertFor_" .. workplace.id] then
                    context:addOptionOnTop("Enable Workplace Alerts", nil, function()
                        md["WWP_DisableAlertFor_" .. workplace.id] = nil
                    end)
                else
                    context:addOptionOnTop("Disable Workplace Alerts", nil, function()
                        md["WWP_DisableAlertFor_" .. workplace.id] = true
                    end)
                end
            end
        end
    end
end