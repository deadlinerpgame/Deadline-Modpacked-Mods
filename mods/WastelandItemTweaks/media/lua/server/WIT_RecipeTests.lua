WIT_RecipeTests = {}

local function isInPlayerInventory(item, player)
    local container = item:getContainer()
    return container and (container == player:getInventory() or container:isInCharacterInventory(player))
end

function WIT_RecipeTests.BlowTorchInPlayerInventory(item)
    if item:getFullType() ~= "Base.BlowTorch" then
        return true
    end

    for playerIndex = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(playerIndex)
        if player and isInPlayerInventory(item, player) then
            return true
        end
    end

    return false
end
