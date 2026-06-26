function removeBatteries(items, result, player)
    local inventory = player:getInventory()
    local batteriesRemoved = 0

    local items = inventory:getItems()

    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)

        if item:getType() == "Battery" and item:getUsedDelta() <= 0.01 then
            inventory:Remove(item) 
            batteriesRemoved = batteriesRemoved + 1

            if batteriesRemoved >= 50 then
                break
            end
        end
    end
    
    print("Removed " .. batteriesRemoved .. " dead batteries.")
end
