WIT_recipes = {}

function WIT_recipes.OnMakePropaneTank(items, result, player)
    result:setUsedDelta(0)
end

function WIT_recipes.OnMakeZombieEarRope(items, result, player)
    result:getModData().countUsed = 1
    result:setName("Zombie Ear Rope [1]")
    result:setCustomName(true)
end

function WIT_recipes.OnGiveXP_CraftLamp(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Electricity, 5)
end

function WIT_recipes.OnGiveXP_Tailoring10(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Tailoring, 10)
end

function WIT_recipes.OnGiveXp_Doctor10(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Doctor, 10)
end

function WIT_recipes.Give5TailoringXP(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Tailoring, 5)
end

-- These are because sprouts forgot to add it....
function Recipe.OnGiveXP.Cooking5(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Cooking, 5)
end
function Recipe.OnGiveXP.Cooking15(recipe, ingredients, result, player)
    player:getXp():AddXP(Perks.Cooking, 15)
end

function WIT_recipes.OnTest_False()
    return false
end

---@param result InventoryItem
---@param player IsoPlayer
function Recipe.OnCreate.extractKevlar(items, result, player)

    -- Check the ingredients for the vest to see if it has holes, and if we're dealing with a light vest
    local lightVestOnly = false
    local hasHoles = false
    for i=0,items:size() - 1 do
        local item = items:get(i)
        if(item:getType() == "Vest_BulletLight") then
            lightVestOnly = true
        end

        if item:IsClothing() and item:getHolesNumber() > 0 then
            hasHoles = true
        end
    end

    -- Figure out how many kevlar sheets we will give back
    local sheets = 7 -- 8 total, because +1 from the recipe script
    if lightVestOnly then
        sheets = 4 -- 5 total, because +1 from the recipe script
    end

    if hasHoles then -- Vest is damaged
        if lightVestOnly then
            sheets = sheets - (ZombRand(0, 3) + 1) -- Subtract 1 to 3 sheets because of the damage
        else
            sheets = sheets - (ZombRand(0, 3) + 2) -- Subtract 2 to 4 sheets because of the damage
        end
    end

    for i = 1, sheets do
        player:getInventory():AddItem("Base.KevlarSheet")
    end

    if not lightVestOnly then -- Normal vests only
        if hasHoles then
            if ZombRand(0, 3) > 0 then  -- 2/3 chance we get it as ZombRand returns 0, 1, or 2
                player:getInventory():AddItem("Base.SmallSheetMetal")
            end
        else -- No damage, so they get the metal plate out!
            player:getInventory():AddItem("Base.SmallSheetMetal")
        end
    end
end
--- Unstack gold. One comes from the recipe already
function Recipe.OnCreate.unstackCoins(items, result, player)
    local coinsToAdd = 0
    for i=0,items:size()-1 do
        local item = items:get(i)
        if item:getFullType() == "Base.GoldCurrencyFive" then
            coinsToAdd = 4
        elseif item:getFullType() == "Base.GoldCurrencyTen" then
            coinsToAdd = 9
        elseif item:getFullType() == "Base.GoldCurrencyFifty" then
            coinsToAdd = 49
        elseif item:getFullType() == "Base.GoldCurrencyHundred" then
            coinsToAdd = 99
        elseif item:getFullType() == "Base.GoldCurrencyFiveHundred" then
            coinsToAdd = 499
        elseif item:getFullType() == "Base.GoldCurrencyThousand" then
            coinsToAdd = 999
        end
    end
    for i=1,coinsToAdd do
        player:getInventory():AddItem("Base.GoldCurrency")
    end
end

function Recipe.OnTest.checkZombieEarRopeForTrade(item, result)
    if item:getFullType() == "Base.ZombieEarRope" and item:getModData().countUsed ~= 300 then
        return false
    end
    return true
end

function Recipe.OnCreate.addOneMag(items, result, player)
    player:getInventory():AddItem(result:getMagazineType())
end

function Recipe.OnCreate.addTwoMags(items, result, player)
    player:getInventory():AddItem(result:getMagazineType())
    player:getInventory():AddItem(result:getMagazineType())
end

function Recipe.OnCreate.bribeTalentScout(items, result, player)
    result:setName("Benefactor's Business Card")
    result:setCustomName(true)

    local fakeMessage = WL_FakeMessage:new("[npc][UN:Talent Scout (NPC)]/me takes the money and hands you a business card. \"Hey, it's your grave...\"")
    ISChat.addLineInChat(fakeMessage)

    fakeMessage = WL_FakeMessage:new("[npc][UN:Talent Scout (NPC)]/say Take this to my boss. He's just outside the southern gates of Hope.")
    ISChat.addLineInChat(fakeMessage)
end

function Recipe.OnCreate.PullApartNest(items, result, player)
    local eggs = ZombRand(0, 4)  -- 50% chance of 1-2 wild eggs
    if eggs > 0 then eggs = eggs - 1 end
    for i = 1, eggs do
        player:getInventory():AddItem("Base.WildEggs");
    end

    local feathers = ZombRand(1, 16)
    for i = 1, feathers do
        player:getInventory():AddItem("Base.WLFeather");
    end
end

local function WIT_purifyWater(item, player)
    local water = item:getUsedDelta() * (1 / item:getUseDelta()) -- give us total water in item
    local neededTablets = math.max(1, math.ceil(water / 10))
    if water == 0 then
        water = (item:getUseDelta() / 1)
    end

    if player:getInventory():getCountTypeRecurse("Base.WITCharcoalTablet") < neededTablets then
        return
    end

    for i = 1, neededTablets do
        local tablet = player:getInventory():getFirstTypeRecurse("Base.WITCharcoalTablet")
        if tablet then
            tablet:getContainer():DoRemoveItem(tablet)
        end
    end

    item:setTaintedWater(false)
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerIdx, context, items)
    items = ISInventoryPane.getActualItems(items)
    local player = getSpecificPlayer(playerIdx)

    for _, item in ipairs(items) do
        if player:getInventory():containsRecursive(item) and item:canStoreWater() and item:isTaintedWater() then
            -- lets calculate how much water is in the item
            local water = item:getUsedDelta() * (1 / item:getUseDelta())-- give us total water in item
            if water == 0 then
                water = (item:getUseDelta() / 1)
            end
            -- each 5 water needs one tablet
            local neededTablets = math.max(1, math.ceil(water / 10))
            -- check if player has enough tables on person
            local option = context:addOption("Purify Water in " .. item:getName(), item, WIT_purifyWater, player)
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            if player:getInventory():getCountTypeRecurse("Base.WITCharcoalTablet") >= neededTablets then
                tooltip.description = "Purify water using " .. neededTablets .. " charcoal tablets."
            else
                tooltip.description = "You need " .. neededTablets .. " charcoal tablets to purify this water."
                option.notAvailable = true
            end
            option.toolTip = tooltip
        end
    end

    if items and items[1] and items[1]:getFullType() == "Base.WITCharcoalTablet" then
        local totalTablets = player:getInventory():getCountTypeRecurse("Base.WITCharcoalTablet")
        local inventory = player:getInventory()
        local items = inventory:getItems()
        for i=0,items:size()-1 do
            local item = items:get(i)
            if item:canStoreWater() and item:isTaintedWater() then
                local water = item:getUsedDelta() * (1 / item:getUseDelta())
                if water == 0 then
                    water = (item:getUseDelta() / 1)
                end
                local neededTablets = math.max(1, math.ceil(water / 10))
                if totalTablets >= neededTablets then
                    local option = context:addOption("Purify Water in " .. item:getName(), item, WIT_purifyWater, player)
                    local tooltip = ISInventoryPaneContextMenu.addToolTip()
                    tooltip.description = "Purify water using " .. neededTablets .. " charcoal tablets."
                    option.toolTip = tooltip
                end
            end
        end
    end
end)

function Recipe.OnCreate.GivePot(items, result, player)
    player:getInventory():AddItem("Pot")
end


local ChainsawAPI = require("Chainsaw/ChainsawAPI");

function WIT_OnTest_RechainChainsaw(item)
    if not ChainsawAPI then
        print("Error: ChainsawAPI is not available.")
        return false
    end

    if instanceof(item, "InventoryItem") then
        local modData = item:getModData()
        modData.onTestDataIsEquipped = item:isEquipped()
        if ChainsawAPI.predicateChainsaw(item) then
            modData.onTestCurrentFuel = modData.CurrentFuel or 0
        end
    else
        print("Error: The item is not an instance of InventoryItem.")
        return false
    end

    return true
end

function WIT_OnCreate_RechainChainsaw(items, result, character)
    for i = 0, items:size() - 1 do
        local item = items:get(i);
        if instanceof(item, "InventoryItem") then
            if ChainsawAPI.predicateChainsaw(item) and ChainsawAPI.predicateChainsaw(result) then
                local modData = item:getModData();
                result:setFavorite(item:isFavorite());
                result:getModData().CurrentFuel = modData.CurrentFuel or 0;
                result:setCondition(30);
                if item:isEquipped() then
                    character:setPrimaryHandItem(result);
                    character:setSecondaryHandItem(result);
                end
            end
        end
    end
end

-- Give Chainsaws more Gas Life and Condition
WL_Utils.setItemProperties("AuthenticZClothing.Chainsaw", {
    FuelConsumption = 0.1,
    ConditionMax = 30,
})
WL_Utils.setItemProperties("AuthenticZClothing.ChainsawOff", {
    FuelConsumption = 0.1,
    ConditionMax = 30,
})

-- Recipe.GetItemTypes.CassetteSongs was moved to WIT_RecipeItemTypes (If you're looking for it)

function WIT_recipes.getCassetteSongs()
    if WIT_recipes.cassetteSongs then return WIT_recipes.cassetteSongs end
    WIT_recipes.cassetteSongs = {}
    local allScriptItems = getScriptManager():getAllItems()
    for i=0, allScriptItems:size()-1 do
        local scriptItem = allScriptItems:get(i)
        local displayName = scriptItem:getDisplayName() or ""
        if scriptItem:getModuleName() == "Tsarcraft" and string.find(scriptItem:getName(), "Cassette") then
            if not (string.find(displayName, "%[ST%]") or string.find(displayName, "%[RARE%]")) then
                table.insert(WIT_recipes.cassetteSongs, scriptItem:getFullName())
            end
        end
    end
    return WIT_recipes.cassetteSongs
end

function Recipe.OnCreate.WindCassette(items, result, player)
    local chance = 10
    local roll = ZombRand(100)
    local success = roll >= chance

    if success then
        local songs = WIT_recipes.getCassetteSongs()
        if songs and #songs > 0 then
            local randomTape = songs[ZombRand(#songs) + 1]
            player:getInventory():AddItem(randomTape)
        else
            player:getInventory():AddItem("Base.ElectronicsScrap")
        end
    else
        player:getInventory():AddItem("Base.ElectronicsScrap")
    end
end

local function getRandomValue(valmin, valmax, perkLevel)
    local range = valmax-valmin;
    local r = ZombRandFloat(range*((perkLevel-1)/10),range*(perkLevel/10));
    return valmin+r;
end

function Recipe.OnCreate.RadioCraft_New(items, result, player)
    --TransmitRange		= 5000,
    if result and result:getDeviceData() then
        local data = result:getDeviceData();
        local perk = player:getPerkLevel(Perks.Electricity);
        local perkInvert = 10-perk+1;
        data:setUseDelta(getRandomValue(0.007,0.030,perkInvert));
        data:setBaseVolumeRange(getRandomValue(8,16,perk));
        data:setMinChannelRange(getRandomValue(200,88000,perkInvert));
        data:setMaxChannelRange(getRandomValue(108000,1000000,perk));
        data:setTransmitRange(getRandomValue(500,5000,perk));
        data:setHasBattery(false);
        data:setPower(0);
        data:transmitBattryChange();
        if perk == 10 then
            if ZombRand(0,100)<15 then --on max level 15% chance to craft a hightier device. Superior range, very low power consumption.
                data:setIsHighTier(true);
                data:setTransmitRange(ZombRand(5500,7500));
                data:setUseDelta(ZombRand(0.002,0.007));
            end
        end
    end
end
