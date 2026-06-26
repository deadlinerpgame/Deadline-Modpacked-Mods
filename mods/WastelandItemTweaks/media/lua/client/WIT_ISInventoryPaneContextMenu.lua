---
--- WIT_ISInventoryPaneContextMenu.lua
--- 07/11/2024
---

require "ISUI/ISInventoryPaneContextMenu"
require "ISUI/ISToolTip"

local CraftTooltip = ISRecipeTooltip

local function sortTableKeys(tbl)
    local keys = {}
    for key in pairs(tbl) do
        table.insert(keys, key)
    end
    table.sort(keys)
    return keys
end

local function createRecipeTooltip(playerObj, recipe)
    local resultItem = InventoryItemFactory.CreateItem(recipe:getResult():getFullType());
    local tooltip = CraftTooltip.addToolTip();
    tooltip.character = playerObj
    tooltip.recipe = recipe
    tooltip:setName(recipe:getName());
    if not resultItem then 
        print("Broken Recipe for " .. recipe:getName())
        return tooltip 
    end
    if resultItem:getTexture() and resultItem:getTexture():getName() ~= "Question_On" then
        tooltip:setTexture(resultItem:getTexture():getName());
    end
    return tooltip;
end

local function addRecipeOptions(context, submenu, recipe, playerObj, containerList, selectedItem)
    local numberOfTimes = RecipeManager.getNumberOfTimesRecipeCanBeDone(recipe, playerObj, containerList, selectedItem)
    if selectedItem:getType() == "Candle" and numberOfTimes >= 2 then
        numberOfTimes = 1; --prevent players from lighting more than one candle at a time
    end
    local option = submenu:addOption(recipe:getName(), selectedItem, nil)

    if playerObj:isDriving() then
        option.notAvailable = true
        local tooltip = ISInventoryPaneContextMenu.addToolTip();
        tooltip.description = getText("Tooltip_CantCraftDriving")
        option.toolTip = tooltip;
        return
    end

    local inventoryItems = playerObj:getInventory():getItems()
    for j=1,inventoryItems:size() do
        local item = inventoryItems:get(j-1)
        if item:getType() == "CandleLit" and selectedItem:getType() == "Candle" then
            option.notAvailable = true;
            local tooltip = ISInventoryPaneContextMenu.addToolTip();
            tooltip.description = getText("Tooltip_CantCraftSecondLitCandle");
            option.toolTip = tooltip;
            return
        end
    end
    if not playerObj:isDriving() then
        local subMenuCraft = submenu:getNew(context)
        submenu:addSubMenu(option, subMenuCraft)
        local subOption = subMenuCraft:addOption(getText("ContextMenu_One"), selectedItem, function()
            ISInventoryPaneContextMenu.OnCraft(selectedItem, recipe, playerObj:getPlayerNum(), false)
            context:closeAll()
        end)
        local tooltip = createRecipeTooltip(playerObj, recipe)
        subOption.toolTip = tooltip

        if numberOfTimes > 1 then
            subOption = subMenuCraft:addOption(getText("ContextMenu_AllWithCount", numberOfTimes), selectedItem, function()
                ISInventoryPaneContextMenu.OnCraft(selectedItem, recipe, playerObj:getPlayerNum(), true)
                context:closeAll()
            end)
        else
            subOption = subMenuCraft:addOption(getText("ContextMenu_All"), selectedItem, function()
                ISInventoryPaneContextMenu.OnCraft(selectedItem, recipe, playerObj:getPlayerNum(), true)
                context:closeAll()
            end)
        end
        subOption.toolTip = tooltip
    end
end

local function categorizeRecipes(recipeList)
    local categorizedRecipes = {}
    for i = 0, recipeList:size() - 1 do
        local recipe = recipeList:get(i)
        local category = recipe:getCategory() or "General"
        if category == "Tailoring" then
            local resultItem = InventoryItemFactory.CreateItem(recipe:getResult():getFullType())
            local clothingType = (resultItem and resultItem:getClothingItem()) and resultItem:getBodyLocation() or "Other"
            categorizedRecipes[category] = categorizedRecipes[category] or {}
            categorizedRecipes[category][clothingType] = categorizedRecipes[category][clothingType] or {}
            table.insert(categorizedRecipes[category][clothingType], recipe)
        elseif category ~= "Juryrig" then
            categorizedRecipes[category] = categorizedRecipes[category] or {}
            table.insert(categorizedRecipes[category], recipe)
        end
    end
    return categorizedRecipes
end

local function createCategorySubMenu(context, category)
    local submenu = context:getNew(context)
    local categoryOption = context:addOption(category, nil, nil)
    context:addSubMenu(categoryOption, submenu)
    return submenu
end

local function handleTailoringCategory(context, category, recipesOrSubcategories, playerObj, containerList, selectedItem)
    local tailoringSubmenu = createCategorySubMenu(context, category)
    local sortedClothingTypes = sortTableKeys(recipesOrSubcategories)
    for _, clothingType in ipairs(sortedClothingTypes) do
        local recipes = recipesOrSubcategories[clothingType]
        table.sort(recipes, function(a, b) return a:getName() < b:getName() end)

        local clothingTypeSubmenu = tailoringSubmenu:getNew(context)
        local clothingTypeOption = tailoringSubmenu:addOption(clothingType, nil, nil)
        tailoringSubmenu:addSubMenu(clothingTypeOption, clothingTypeSubmenu)

        for _, recipe in ipairs(recipes) do
            addRecipeOptions(context, clothingTypeSubmenu, recipe, playerObj, containerList, selectedItem)
        end
    end
end

ISInventoryPaneContextMenu.doEvorecipeMenu = function(context, items, player, evolvedRecipeList, baseItem, containerList)
    for i = 0, evolvedRecipeList:size() - 1 do
        local listOfAddedItems = {}
        local evorecipe = evolvedRecipeList:get(i)
        local availableItems = evorecipe:getItemsCanBeUse(getSpecificPlayer(player), baseItem, containerList)

        if availableItems:size() == 0 then
            break
        end

        local subOptionName = evorecipe:isResultItem(baseItem) 
                                and getText("ContextMenu_EvolvedRecipe_" .. evorecipe:getUntranslatedName()) 
                                or getText("ContextMenu_Create_From_Ingredient", getText("ContextMenu_EvolvedRecipe_" .. evorecipe:getUntranslatedName()))
        local subOption = context:addOption(subOptionName, nil)
        local subMenuRecipe = context:getNew(context)
        context:addSubMenu(subOption, subMenuRecipe)

        local catList = ISInventoryPaneContextMenu.getEvoItemCategories(availableItems, evorecipe)
        for cat, itemsInCategory in pairs(catList) do
            local categoryText = getText("ContextMenu_FoodType_" .. cat)
            if categoryText ~= "ContextMenu_FoodType_" .. cat then
                local txt = evorecipe:isResultItem(baseItem) 
                            and getText("ContextMenu_AddRandom", categoryText) 
                            or getText("ContextMenu_FromRandom", categoryText)
                subMenuRecipe:addOption(txt, evorecipe, ISInventoryPaneContextMenu.onAddItemInEvoRecipe, baseItem, itemsInCategory[ZombRand(1, #itemsInCategory + 1)], player)
            end
        end

        for j = 0, availableItems:size() - 1 do
            local evoItem = availableItems:get(j)
            local extraInfo = ""

            if instanceof(evoItem, "Food") then
                local itemType = evoItem:getType()
                local use = ISInventoryPaneContextMenu.getRealEvolvedItemUse(evoItem, evorecipe, getSpecificPlayer(player):getPerkLevel(Perks.Cooking))

                if evoItem:isSpice() then
                    extraInfo = getText("ContextMenu_EvolvedRecipe_Spice")
                    if listOfAddedItems[itemType] then
                        evoItem = nil
                    else
                        listOfAddedItems[itemType] = true
                    end
                elseif evoItem:getPoisonLevelForRecipe() then
                    if evoItem:getHerbalistType() and evoItem:getHerbalistType() ~= "" and getSpecificPlayer(player):isRecipeKnown("Herbalist") then
                        extraInfo = getText("ContextMenu_EvolvedRecipe_Poison")
                    end
                    if use then
                        extraInfo = extraInfo .. "(" .. use .. ")"
                    end
                    local key = itemType .. "_poison"
                    if listOfAddedItems[key] then
                        evoItem = nil
                    else
                        listOfAddedItems[key] = true
                    end
                elseif not evoItem:isPoison() then
                    extraInfo = "(" .. use .. ")"
                    local key = itemType .. "_" .. tostring(use)
                    if listOfAddedItems[key] then
                        evoItem = nil
                    else
                        listOfAddedItems[key] = true
                    end
                end
            end

            if evoItem then
                ISInventoryPaneContextMenu.addItemInEvoRecipe(subMenuRecipe, baseItem, evoItem, extraInfo, evorecipe, player)
            end
        end
    end
end


ISInventoryPaneContextMenu.addDynamicalContextMenu = function(selectedItem, context, recipeList, player, containerList)
    local playerObj = getSpecificPlayer(player)
    local categorizedRecipes = categorizeRecipes(recipeList)

    for category, recipesOrSubcategories in pairs(categorizedRecipes) do
        if category == "Tailoring" then
            handleTailoringCategory(context, category, recipesOrSubcategories, playerObj, containerList, selectedItem)
        elseif #recipesOrSubcategories >= 5 then
            local submenu = createCategorySubMenu(context, category)
            table.sort(recipesOrSubcategories, function(a, b) return a:getName() < b:getName() end)
            for _, recipe in ipairs(recipesOrSubcategories) do
                addRecipeOptions(context, submenu, recipe, playerObj, containerList, selectedItem)
            end
        else
            table.sort(recipesOrSubcategories, function(a, b) return a:getName() < b:getName() end)
            for _, recipe in ipairs(recipesOrSubcategories) do
                addRecipeOptions(context, context, recipe, playerObj, containerList, selectedItem)
            end
        end
    end
end

ISInventoryPaneContextMenu.repairAllClothing = function(player, clothing, parts, fabric, thread, needle, onlyHoles)

    local fabricArray = player:getInventory():getItemsFromType(fabric:getType(), true);
    local fabricCount = player:getInventory():getItemCount(fabric:getType(), true);
    local threadArray = player:getInventory():getItemsFromType(thread:getType(), true);
    local threadCount = player:getInventory():getItemCount(thread:getType(), true);

    local successfulActionsAdded = 0;
    local currentThreadUsed = 0;
    local currentPatchUsed = 0;
    local totalPatchUses = 0;

    if fabric:getType() == "PatchKit" or fabric:getType() == "KevlarKit" then
        for i=1, fabricArray:size() do
            totalPatchUses = (totalPatchUses + fabricArray:get(i-1):getUsedDelta()) * 5
        end
    end

    for i=1, #parts do

        local part = parts[i];
        local hole = clothing:getVisual():getHole(part) > 0;
        local patch = clothing:getPatchType(part);

        if fabric:getType() == "PatchKit" or fabric:getType() == "KevlarKit" then
            if (successfulActionsAdded > 0) and ((threadArray:get(currentThreadUsed):getUsedDelta() - (successfulActionsAdded * 0.1)) < 0.1) and ((fabricArray:get(currentPatchUsed):getUsedDelta() - (successfulActionsAdded * 0.1)) < 0.1) then
                currentThreadUsed = currentThreadUsed + 1;
                currentPatchUsed = currentPatchUsed + 1;
                if(currentThreadUsed >= threadCount) and (currentPatchUsed >= totalPatchUses) then return; end
            end
        else
            if (successfulActionsAdded > 0) and ((threadArray:get(currentThreadUsed):getUsedDelta() - (successfulActionsAdded * 0.1)) < 0.1) then
                currentThreadUsed = currentThreadUsed + 1;
                if(currentThreadUsed >= threadCount) then return; end
            end
        end
        
        if fabric:getType() == "PatchKit" or fabric:getType() == "KevlarKit" then
            if hole and onlyHoles and fabric:getUsedDelta() > 0 then
                ISInventoryPaneContextMenu.repairClothing(player, clothing, part, fabricArray:get(currentPatchUsed), threadArray:get(currentThreadUsed), needle);
                successfulActionsAdded = successfulActionsAdded + 1;
            end

            if(successfulActionsAdded >= totalPatchUses) then return; end
        else
            if hole and onlyHoles then -- Patch all holes
                ISInventoryPaneContextMenu.repairClothing(player, clothing, part, fabricArray:get(successfulActionsAdded), threadArray:get(currentThreadUsed), needle);
                successfulActionsAdded = successfulActionsAdded + 1;
            elseif (not patch) and (not hole) and (not onlyHoles) then -- Pad every non-hole
                ISInventoryPaneContextMenu.repairClothing(player, clothing, part, fabricArray:get(successfulActionsAdded), threadArray:get(currentThreadUsed), needle);
                successfulActionsAdded = successfulActionsAdded + 1;
            end

            if(successfulActionsAdded >= fabricCount) then return; end
        end
    end

end
