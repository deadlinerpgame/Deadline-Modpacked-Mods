if not getActivatedMods():contains("MoreSmokes") then
    return
end

local SmokesTable = {}
SmokesTable["MoreSmokes.MSCigarettePack"] = {recipe = "MoreSmokes.Take Out Cigarette", itemType = "MoreSmokes.MSCigarette"}
SmokesTable["MoreSmokes.CigarilloPack"] = {recipe = "MoreSmokes.Take One Cigarillo", itemType = "MoreSmokes.Cigarillo"}
SmokesTable["MoreSmokes.CigarBox"] = {recipe = "MoreSmokes.Take Out One Cigar", itemType = "MoreSmokes.MSCigar"}
SmokesTable["MoreSmokes.JointsPackNorthernLights"] = {recipe = "MoreSmokes.Take One Joint Northern Lights", itemType = "MoreSmokes.JointNorthernLights"}
SmokesTable["MoreSmokes.JointsPackPurpleHaze"] = {recipe = "MoreSmokes.Take One Joint Purple Haze", itemType = "MoreSmokes.JointPurpleHaze"}
SmokesTable["MoreSmokes.JointsPackSourDiesel"] = {recipe = "MoreSmokes.Take One Joint Sour Diesel", itemType = "MoreSmokes.JointSourDiesel"}
SmokesTable["MoreSmokes.BluntsPackNorthernLights"] = {recipe = "MoreSmokes.Take One Blunt Northern Lights", itemType = "MoreSmokes.BluntNorthernLights"}
SmokesTable["MoreSmokes.BluntsPackPurpleHaze"] = {recipe = "MoreSmokes.Take One Blunt Purple Haze", itemType = "MoreSmokes.BluntPurpleHaze"}
SmokesTable["MoreSmokes.BluntsPackSourDiesel"] = {recipe = "MoreSmokes.Take One Blunt Sour Diesel", itemType = "MoreSmokes.BluntSourDiesel"}
SmokesTable["MoreSmokes.SpliffsPackNorthernLights"] = {recipe = "MoreSmokes.Take One Spliff Northern Lights", itemType = "MoreSmokes.SpliffNorthernLights"}
SmokesTable["MoreSmokes.SpliffsPackPurpleHaze"] = {recipe = "MoreSmokes.Take One Spliff Purple Haze", itemType = "MoreSmokes.SpliffPurpleHaze"}
SmokesTable["MoreSmokes.SpliffsPackSourDiesel"] = {recipe = "MoreSmokes.Take One Spliff Sour Diesel", itemType = "MoreSmokes.SpliffSourDiesel"}
SmokesTable["MoreSmokes.JointsPackIndigoFog"] = {recipe = "MoreSmokes.Take One Joint Indigo Fog", itemType = "MoreSmokes.JointIndigoFog"}
SmokesTable["MoreSmokes.BluntsPackBackwoods"] = {recipe = "MoreSmokes.Take One Blunt Backwoods", itemType = "MoreSmokes.BluntBackwoods"}

local function SmokeFromPack(playerIdx, pack, recipeName, itemType)
    local player = getSpecificPlayer(playerIdx)
    local originalContainer = pack:getContainer()
    ISInventoryPaneContextMenu.transferIfNeeded(player, pack)
    local recipe = getScriptManager():getRecipe(recipeName)
    local craftAction = ISCraftAction:new(player, pack, recipe:getTimeToMake(), recipe, player:getInventory(), nil)
    craftAction.stopOnWalk = false
    -- makes it so you can remove from pack while driving
    craftAction.isValid = function (self)
        return RecipeManager.IsRecipeValid(self.recipe, self.character, self.item, self.containers)
    end
    craftAction:setOnComplete(function()
        if pack and pack:getContainer() and pack:getContainer() ~= originalContainer then
			ISTimedActionQueue.add(ISInventoryTransferAction:new(player, pack, pack:getContainer(), originalContainer))
        end
        local item = player:getInventory():FindAndReturn(itemType)
        if item then
            ISInventoryPaneContextMenu.eatItem(item, 100, playerIdx)
        end
    end)
    ISTimedActionQueue.add(craftAction)
end

local function AddMoreSmokesSmokePackContextOption(playerIdx, context, items)
    local item;
    if instanceof(items[1], "InventoryItem") then
        item = items[1]
    elseif items[1] and items[1].items and instanceof(items[1].items[1], "InventoryItem") then
        item = items[1].items[1]
    end

    if not item then
        return
    end

    local itemType = item:getFullType()
    if SmokesTable[itemType] then
        local recipe = SmokesTable[itemType].recipe
        local itemType = SmokesTable[itemType].itemType
        context:addOption("Take and Smoke One", playerIdx, SmokeFromPack, item, recipe, itemType)
    end
end

Events.OnPreFillInventoryObjectContextMenu.Add(AddMoreSmokesSmokePackContextOption)