---
--- WL_ItemRecipeExporter.lua
---
--- Manual debug exporter for item and recipe data.
--- Run from the Lua console with WL_ItemRecipeExporter.exportAll()
---

WL_ItemRecipeExporter = WL_ItemRecipeExporter or {}

WL_ItemRecipeExporter.SCHEMA_VERSION = "2"
WL_ItemRecipeExporter.FILE_PREFIX = "WL_ItemRecipeExport_"

local NEWLINE = "\n"

local function exporterLog(message)
    print("[WL_ItemRecipeExporter] " .. tostring(message))
end

local function exporterNotify(message)
    exporterLog(message)
    if WL_Utils and WL_Utils.addToChat then
        WL_Utils.addToChat("[WL Item Recipe Exporter] " .. tostring(message))
    end
end

local function hasDebugAccess()
    if getDebug and getDebug() == true then
        return true
    end

    if isDebugEnabled and isDebugEnabled() == true then
        return true
    end

    return false
end

local function safeMethod(target, methodName, ...)
    if not target then return nil end

    local method = target[methodName]
    if type(method) ~= "function" then return nil end

    local ok, result = pcall(method, target, ...)
    if ok then
        return result
    end

    return nil
end

local function safeCreateItem(fullType)
    if not fullType or fullType == "" then return nil end

    if instanceItem then
        local ok, item = pcall(instanceItem, fullType)
        if ok and item then
            return item
        end
    end

    local ok, item = pcall(InventoryItemFactory.CreateItem, fullType)
    if ok then
        return item
    end

    return nil
end

local function listSize(list)
    if not list then return 0 end

    local size = safeMethod(list, "size")
    if not size then return 0 end

    return size
end

local function trimText(value)
    if value == nil then return "" end

    value = tostring(value)
    value = value:gsub("^%s+", "")
    value = value:gsub("%s+$", "")
    return value
end

local function normalizeText(value)
    if value == nil then return "" end

    value = tostring(value)
    value = value:gsub("\r\n", "\n")
    value = value:gsub("\r", "\n")
    value = value:gsub("\n", "\\n")
    return value
end

local function boolToString(value)
    if value then
        return "true"
    end

    return "false"
end

local function csvEscape(value)
    local text = normalizeText(value)
    text = text:gsub('"', '""')
    return '"' .. text .. '"'
end

local function splitFullType(fullType)
    if not fullType or fullType == "" then
        return "", ""
    end

    local dotIndex = string.find(fullType, ".", 1, true)
    if not dotIndex then
        return "", fullType
    end

    return string.sub(fullType, 1, dotIndex - 1), string.sub(fullType, dotIndex + 1)
end

local function normalizeIdPart(value)
    value = normalizeText(value)
    value = value:gsub("|", "/")
    return value
end

local function buildRecipeId(recipeKind, sortIndex, moduleName, originalName)
    return table.concat({
        recipeKind,
        tostring(sortIndex or ""),
        normalizeIdPart(moduleName),
        normalizeIdPart(originalName)
    }, "|")
end

local function addRow(rows, row)
    rows[#rows + 1] = row
end

local function incrementCount(counter, key, amount)
    if not key or key == "" then return end
    counter[key] = (counter[key] or 0) + (amount or 1)
end

local function toNumberString(value)
    if value == nil then return "" end
    return tostring(value)
end

local function getDrainableUseDelta(item)
    if not item then return "" end
    if safeMethod(item, "IsDrainable") ~= true then return "" end

    return safeMethod(item, "getUseDelta") or ""
end

local function getDrainableUses(item, useDelta)
    if not item then return "" end
    if safeMethod(item, "IsDrainable") ~= true then return "" end

    local uses = safeMethod(item, "getDrainableUsesInt")
    if uses ~= nil then
        return uses
    end

    if type(useDelta) == "number" and useDelta > 0 then
        local usedDelta = safeMethod(item, "getUsedDelta")
        if type(usedDelta) == "number" and usedDelta > 0 then
            return math.floor((usedDelta / useDelta) + 0.0001)
        end
    end

    return ""
end

local function collectJavaListValues(list, mapper)
    local values = {}
    if not list then return values end

    for i = 0, list:size() - 1 do
        local value = list:get(i)
        if mapper then
            value = mapper(value, i)
        end

        if value ~= nil and value ~= "" then
            values[#values + 1] = tostring(value)
        end
    end

    return values
end

local function joinValues(values, separator)
    local cleaned = {}
    local seen = {}

    for i = 1, #values do
        local value = trimText(values[i])
        if value ~= "" and not seen[value] then
            seen[value] = true
            cleaned[#cleaned + 1] = value
        end
    end

    table.sort(cleaned)
    return table.concat(cleaned, separator or "|")
end

local function getTextureName(item)
    if not item then return "" end

    local texture = safeMethod(item, "getTex")
    if not texture then return "" end

    return safeMethod(texture, "getName") or ""
end

local function getModuleName(moduleValue)
    if not moduleValue then return "" end
    if type(moduleValue) == "string" then return moduleValue end

    return safeMethod(moduleValue, "getName") or tostring(moduleValue)
end

local function resolveItemToken(itemToken, itemIndex)
    itemToken = trimText(itemToken)
    if itemToken == "" then return "" end

    if string.find(itemToken, ".", 1, true) then
        if itemIndex.byFullType[itemToken] then
            return itemToken
        end

        local _, typeName = splitFullType(itemToken)
        local baseCandidate = "Base." .. typeName
        if itemIndex.byFullType[baseCandidate] then
            return baseCandidate
        end

        return ""
    end

    local baseFullType = "Base." .. itemToken
    if itemIndex.byFullType[baseFullType] then
        return baseFullType
    end

    local candidates = itemIndex.byType[itemToken]
    if not candidates or #candidates == 0 then
        return ""
    end

    if #candidates == 1 then
        return candidates[1].full_type
    end

    return candidates[1].full_type
end

local function sortCellValue(value)
    if value == nil then return "" end

    local valueType = type(value)
    if valueType == "string" or valueType == "number" then
        return tostring(value)
    end

    if valueType == "boolean" then
        return value and "true" or "false"
    end

    return ""
end

local function buildRowSortKey(row, keys)
    local parts = {}

    for i = 1, #keys do
        parts[i] = sortCellValue(row[keys[i]])
    end

    return table.concat(parts, "\t")
end

local function sortRows(rows, keys)
    local rowCount = #rows
    if rowCount <= 1 then return end

    local sortKeys = {}
    local bufferRows = {}
    local bufferKeys = {}

    for i = 1, rowCount do
        sortKeys[i] = buildRowSortKey(rows[i], keys)
    end

    local width = 1
    while width < rowCount do
        local startIndex = 1

        while startIndex <= rowCount do
            local left = startIndex
            local middle = math.min(startIndex + width - 1, rowCount)
            local right = math.min(startIndex + (width * 2) - 1, rowCount)

            local leftIndex = left
            local rightIndex = middle + 1
            local targetIndex = left

            while leftIndex <= middle and rightIndex <= right do
                if sortKeys[leftIndex] <= sortKeys[rightIndex] then
                    bufferRows[targetIndex] = rows[leftIndex]
                    bufferKeys[targetIndex] = sortKeys[leftIndex]
                    leftIndex = leftIndex + 1
                else
                    bufferRows[targetIndex] = rows[rightIndex]
                    bufferKeys[targetIndex] = sortKeys[rightIndex]
                    rightIndex = rightIndex + 1
                end
                targetIndex = targetIndex + 1
            end

            while leftIndex <= middle do
                bufferRows[targetIndex] = rows[leftIndex]
                bufferKeys[targetIndex] = sortKeys[leftIndex]
                leftIndex = leftIndex + 1
                targetIndex = targetIndex + 1
            end

            while rightIndex <= right do
                bufferRows[targetIndex] = rows[rightIndex]
                bufferKeys[targetIndex] = sortKeys[rightIndex]
                rightIndex = rightIndex + 1
                targetIndex = targetIndex + 1
            end

            startIndex = startIndex + (width * 2)
        end

        for i = 1, rowCount do
            rows[i] = bufferRows[i]
            sortKeys[i] = bufferKeys[i]
        end

        width = width * 2
    end
end

local function writeCsvFile(fileName, headers, rows)
    local writer = getFileWriter(fileName, true, false)
    if not writer then
        error("Failed to open file writer for " .. tostring(fileName))
    end

    local headerValues = {}
    for i = 1, #headers do
        headerValues[i] = csvEscape(headers[i])
    end
    writer:write(table.concat(headerValues, ",") .. NEWLINE)

    for rowIndex = 1, #rows do
        local row = rows[rowIndex]
        local values = {}
        for headerIndex = 1, #headers do
            values[headerIndex] = csvEscape(row[headers[headerIndex]])
        end
        writer:write(table.concat(values, ",") .. NEWLINE)
    end

    writer:close()
    return #rows
end

local function collectItemRecord(scriptItem, itemIndexId)
    local fullType = safeMethod(scriptItem, "getFullName")
    if not fullType or fullType == "" then
        return nil
    end

    local inventoryItem = safeCreateItem(fullType)
    local moduleName = getModuleName(safeMethod(scriptItem, "getModule"))
    local _, typeName = splitFullType(fullType)

    local tagList = collectJavaListValues(
        safeMethod(scriptItem, "getTags") or safeMethod(inventoryItem, "getTags")
    )
    local categoryList = collectJavaListValues(
        safeMethod(inventoryItem, "getCategories") or safeMethod(scriptItem, "getCategories")
    )
    local taughtRecipes = collectJavaListValues(
        safeMethod(inventoryItem, "getTeachedRecipes") or safeMethod(scriptItem, "getTeachedRecipes")
    )
    local useDelta = getDrainableUseDelta(inventoryItem)
    local uses = getDrainableUses(inventoryItem, useDelta)

    return {
        item_id = tostring(itemIndexId),
        full_type = fullType,
        module = moduleName,
        type = typeName,
        script_name = safeMethod(inventoryItem, "getName") or safeMethod(scriptItem, "getName") or typeName,
        display_name = safeMethod(inventoryItem, "getDisplayName") or typeName,
        mod_name = safeMethod(inventoryItem, "getModName") or "",
        category = safeMethod(scriptItem, "getTypeString") or safeMethod(inventoryItem, "getCategory") or "",
        display_category = safeMethod(inventoryItem, "getDisplayCategory") or safeMethod(scriptItem, "getDisplayCategory") or "",
        icon_name = safeMethod(scriptItem, "getIcon") or "",
        texture_name = getTextureName(inventoryItem),
        world_sprite = safeMethod(inventoryItem, "getWorldSprite") or "",
        weight = safeMethod(inventoryItem, "getWeight") or safeMethod(scriptItem, "getActualWeight") or "",
        actual_weight = safeMethod(inventoryItem, "getActualWeight") or "",
        count = safeMethod(inventoryItem, "getCount") or 1,
        hidden = safeMethod(scriptItem, "isHidden") == true,
        obsolete = safeMethod(scriptItem, "getObsolete") == true,
        is_vanilla = safeMethod(inventoryItem, "isVanilla") == true,
        is_drainable = safeMethod(inventoryItem, "IsDrainable") == true,
        uses = uses,
        use_delta = useDelta,
        food_type = safeMethod(inventoryItem, "getFoodType") or "",
        is_spice = safeMethod(inventoryItem, "isSpice") == true,
        can_store_water = safeMethod(inventoryItem, "canStoreWater") == true,
        body_location = safeMethod(inventoryItem, "getBodyLocation") or "",
        replace_on_use = safeMethod(scriptItem, "getReplaceOnUseOn") or "",
        replace_on_deplete = safeMethod(scriptItem, "getReplaceOnDeplete") or "",
        tags = joinValues(tagList, "|"),
        categories = joinValues(categoryList, "|"),
        taught_recipe_count = #taughtRecipes,
        taught_recipes = joinValues(taughtRecipes, "|"),
    }
end

local function collectItems()
    local allItems = getAllItems()
    local items = {}
    local itemIndex = {
        byFullType = {},
        byType = {},
    }

    for i = 0, allItems:size() - 1 do
        local scriptItem = allItems:get(i)
        if not safeMethod(scriptItem, "getObsolete") then
            local record = collectItemRecord(scriptItem, #items + 1)
            if record and not itemIndex.byFullType[record.full_type] then
                itemIndex.byFullType[record.full_type] = record
                items[#items + 1] = record

                local typeRecords = itemIndex.byType[record.type]
                if not typeRecords then
                    typeRecords = {}
                    itemIndex.byType[record.type] = typeRecords
                end
                typeRecords[#typeRecords + 1] = record
            end
        end
    end

    sortRows(items, { "full_type" })
    for _, records in pairs(itemIndex.byType) do
        table.sort(records, function(a, b)
            return a.full_type < b.full_type
        end)
    end

    return items, itemIndex
end

local function collectRegularRecipeSkills(recipe, recipeId, recipeSkillRows)
    local requiredSkillCount = safeMethod(recipe, "getRequiredSkillCount") or 0
    local skillNames = {}

    for skillIndex = 0, requiredSkillCount - 1 do
        local skill = safeMethod(recipe, "getRequiredSkill", skillIndex)
        if skill then
            local perkEnum = safeMethod(skill, "getPerk")
            local perk = perkEnum and PerkFactory.getPerk(perkEnum) or nil
            local perkId = perk and safeMethod(perk, "getId") or (perkEnum and safeMethod(perkEnum, "name") or "")
            local perkName = perk and safeMethod(perk, "getName") or perkId
            local level = safeMethod(skill, "getLevel") or 0

            if level > 0 then
                addRow(recipeSkillRows, {
                    recipe_id = recipeId,
                    recipe_kind = "regular",
                    skill_index = tostring(skillIndex + 1),
                    perk_id = perkId,
                    perk_name = perkName,
                    level = tostring(level),
                })
                skillNames[#skillNames + 1] = tostring(perkName) .. ":" .. tostring(level)
            end
        end
    end

    return requiredSkillCount, joinValues(skillNames, "|")
end

local function getRecipeResultData(result, itemIndex)
    if not result then
        return {
            item_full_type = "",
            item_display_name = "",
            item_exists = false,
            result_count = "",
            drainable_count = "",
            item_token = "",
        }
    end

    local resultFullType = safeMethod(result, "getFullType") or ""
    local resultModule = getModuleName(safeMethod(result, "getModule"))
    local resultType = safeMethod(result, "getType") or ""

    if resultFullType == "" and resultType ~= "" then
        if resultModule ~= "" then
            resultFullType = resultModule .. "." .. resultType
        else
            resultFullType = resolveItemToken(resultType, itemIndex)
        end
    end

    local itemRecord = itemIndex.byFullType[resultFullType]

    return {
        item_full_type = resultFullType,
        item_display_name = itemRecord and itemRecord.display_name or "",
        item_exists = itemRecord ~= nil,
        result_count = safeMethod(result, "getCount") or 1,
        drainable_count = safeMethod(result, "getDrainableCount") or "",
        item_token = resultType,
    }
end

local function collectRegularRecipeSources(recipe, recipeId, itemIndex, recipeSourceRows, counters)
    local sourceRowsWritten = 0
    local sourceList = safeMethod(recipe, "getSource")
    if not sourceList then
        return sourceRowsWritten
    end

    for sourceIndex = 0, sourceList:size() - 1 do
        local source = sourceList:get(sourceIndex)
        local sourceItems = safeMethod(source, "getItems")
        local itemTokens = collectJavaListValues(sourceItems, function(value)
            return trimText(value)
        end)

        table.sort(itemTokens)

        local sourceCount = safeMethod(source, "getCount") or 1
        local sourceUse = safeMethod(source, "getUse") or ""
        local keep = safeMethod(source, "isKeep") == true
        local destroy = safeMethod(source, "isDestroy") == true

        for candidateIndex = 1, #itemTokens do
            local itemToken = itemTokens[candidateIndex]
            local resolvedFullType = resolveItemToken(itemToken, itemIndex)
            local itemRecord = itemIndex.byFullType[resolvedFullType]

            addRow(recipeSourceRows, {
                recipe_id = recipeId,
                recipe_kind = "regular",
                source_role = "ingredient",
                source_index = tostring(sourceIndex + 1),
                candidate_index = tostring(candidateIndex),
                source_group_size = tostring(#itemTokens),
                source_count = toNumberString(sourceCount),
                source_use = toNumberString(sourceUse),
                keep = boolToString(keep),
                destroy = boolToString(destroy),
                item_token = itemToken,
                item_full_type = resolvedFullType,
                item_display_name = itemRecord and itemRecord.display_name or "",
                item_exists = boolToString(itemRecord ~= nil),
                is_spice = "",
            })
            sourceRowsWritten = sourceRowsWritten + 1

            if resolvedFullType ~= "" then
                incrementCount(counters.sourceByItem, resolvedFullType)
            end
        end
    end

    return sourceRowsWritten
end

local function collectRegularRecipes(itemIndex, recipeRows, recipeSourceRows, recipeResultRows, recipeSkillRows, counters)
    local allRecipes = getAllRecipes()

    for i = 0, allRecipes:size() - 1 do
        local recipe = allRecipes:get(i)
        local result = safeMethod(recipe, "getResult")
        if result then
            local moduleName = getModuleName(safeMethod(recipe, "getModule"))
            local originalName = safeMethod(recipe, "getOriginalname") or safeMethod(recipe, "getName") or ("recipe_" .. tostring(i + 1))
            local displayName = safeMethod(recipe, "getName") or originalName
            local recipeId = buildRecipeId("regular", i + 1, moduleName, originalName)
            local resultData = getRecipeResultData(result, itemIndex)

            local requiredSkillCount, requiredSkillSummary = collectRegularRecipeSkills(recipe, recipeId, recipeSkillRows)
            local sourceRowCount = collectRegularRecipeSources(recipe, recipeId, itemIndex, recipeSourceRows, counters)
            local sourceGroupCount = listSize(safeMethod(recipe, "getSource"))

            addRow(recipeRows, {
                recipe_id = recipeId,
                recipe_kind = "regular",
                sort_index = tostring(i + 1),
                module = moduleName,
                original_name = originalName,
                untranslated_name = "",
                display_name = displayName,
                category = safeMethod(recipe, "getCategory") or "General",
                hidden = boolToString(safeMethod(recipe, "isHidden") == true),
                time_to_make = toNumberString(safeMethod(recipe, "getTimeToMake") or ""),
                near_item = safeMethod(recipe, "getNearItem") or "",
                need_to_be_learn = boolToString(safeMethod(recipe, "needToBeLearn") == true),
                can_be_done_from_floor = boolToString(safeMethod(recipe, "getCanBeDoneFromFloor") == true),
                remove_result_item = boolToString(safeMethod(recipe, "isRemoveResultItem") == true),
                no_broken_items = boolToString(safeMethod(recipe, "noBrokenItems") == true),
                heat = toNumberString(safeMethod(recipe, "getHeat") or ""),
                water_amount_needed = toNumberString(safeMethod(recipe, "getWaterAmountNeeded") or ""),
                lua_test = safeMethod(recipe, "getLuaTest") or "",
                lua_create = safeMethod(recipe, "getLuaCreate") or "",
                lua_give_xp = safeMethod(recipe, "getLuaGiveXP") or "",
                lua_can_perform = safeMethod(recipe, "getCanPerform") or "",
                sound = safeMethod(recipe, "getSound") or "",
                anim_node = safeMethod(recipe, "getAnimNode") or "",
                prop1 = safeMethod(recipe, "getProp1") or "",
                prop2 = safeMethod(recipe, "getProp2") or "",
                source_group_count = tostring(sourceGroupCount),
                source_row_count = tostring(sourceRowCount),
                required_skill_count = tostring(requiredSkillCount),
                required_skills = requiredSkillSummary,
                base_item = "",
                max_items = "",
                is_cookable = "",
                allow_frozen_item = "",
                add_ingredient_sound = "",
                result_full_type = resultData.item_full_type,
                result_display_name = resultData.item_display_name,
                result_exists = boolToString(resultData.item_exists),
                result_count = toNumberString(resultData.result_count),
                result_drainable_count = toNumberString(resultData.drainable_count),
            })

            addRow(recipeResultRows, {
                recipe_id = recipeId,
                recipe_kind = "regular",
                result_index = "1",
                item_token = resultData.item_token,
                item_full_type = resultData.item_full_type,
                item_display_name = resultData.item_display_name,
                item_exists = boolToString(resultData.item_exists),
                result_count = toNumberString(resultData.result_count),
                drainable_count = toNumberString(resultData.drainable_count),
            })

            if resultData.item_full_type ~= "" then
                incrementCount(counters.resultByItem, resultData.item_full_type)
            end
        end
    end
end

local function collectEvolvedRecipeSources(recipe, recipeId, itemIndex, recipeSourceRows, counters)
    local sourceRowsWritten = 0

    local baseItemToken = safeMethod(recipe, "getBaseItem") or ""
    local resolvedBaseItem = resolveItemToken(baseItemToken, itemIndex)
    local baseItemRecord = itemIndex.byFullType[resolvedBaseItem]
    addRow(recipeSourceRows, {
        recipe_id = recipeId,
        recipe_kind = "evolved",
        source_role = "base_item",
        source_index = "1",
        candidate_index = "1",
        source_group_size = "1",
        source_count = "1",
        source_use = "",
        keep = "false",
        destroy = "false",
        item_token = baseItemToken,
        item_full_type = resolvedBaseItem,
        item_display_name = baseItemRecord and baseItemRecord.display_name or "",
        item_exists = boolToString(baseItemRecord ~= nil),
        is_spice = "",
    })
    sourceRowsWritten = sourceRowsWritten + 1
    if resolvedBaseItem ~= "" then
        incrementCount(counters.sourceByItem, resolvedBaseItem)
    end

    local possibleItems = safeMethod(recipe, "getPossibleItems")
    if possibleItems then
        for i = 0, possibleItems:size() - 1 do
            local possibleItem = possibleItems:get(i)
            local possibleFullType = safeMethod(possibleItem, "getFullType") or ""
            local itemRecord = itemIndex.byFullType[possibleFullType]
            addRow(recipeSourceRows, {
                recipe_id = recipeId,
                recipe_kind = "evolved",
                source_role = "ingredient",
                source_index = "2",
                candidate_index = tostring(i + 1),
                source_group_size = tostring(possibleItems:size()),
                source_count = "1",
                source_use = toNumberString(safeMethod(possibleItem, "getUse") or ""),
                keep = "false",
                destroy = "false",
                item_token = safeMethod(possibleItem, "getName") or "",
                item_full_type = possibleFullType,
                item_display_name = itemRecord and itemRecord.display_name or "",
                item_exists = boolToString(itemRecord ~= nil),
                is_spice = boolToString(safeMethod(possibleItem, "isSpice") == true),
            })
            sourceRowsWritten = sourceRowsWritten + 1

            if possibleFullType ~= "" then
                incrementCount(counters.sourceByItem, possibleFullType)
            end
        end
    end

    return sourceRowsWritten, baseItemToken, resolvedBaseItem
end

local function getEvolvedResultData(recipe, itemIndex)
    local resultFullType = safeMethod(recipe, "getFullResultItem") or ""
    if resultFullType ~= "" and not string.find(resultFullType, ".", 1, true) then
        local resolved = resolveItemToken(resultFullType, itemIndex)
        if resolved ~= "" then
            resultFullType = resolved
        else
            resultFullType = "Base." .. resultFullType
        end
    end

    local itemRecord = itemIndex.byFullType[resultFullType]
    return {
        item_full_type = resultFullType,
        item_display_name = itemRecord and itemRecord.display_name or "",
        item_exists = itemRecord ~= nil,
    }
end

local function collectEvolvedRecipes(itemIndex, recipeRows, recipeSourceRows, recipeResultRows, counters)
    local allEvolvedRecipes = RecipeManager.getAllEvolvedRecipes()

    for i = 0, allEvolvedRecipes:size() - 1 do
        local recipe = allEvolvedRecipes:get(i)
        local moduleName = getModuleName(safeMethod(recipe, "getModule"))
        local originalName = safeMethod(recipe, "getOriginalname") or safeMethod(recipe, "getName") or ("evolved_recipe_" .. tostring(i + 1))
        local displayName = safeMethod(recipe, "getName") or originalName
        local recipeId = buildRecipeId("evolved", i + 1, moduleName, originalName)

        local sourceRowCount, baseItemToken, resolvedBaseItem = collectEvolvedRecipeSources(recipe, recipeId, itemIndex, recipeSourceRows, counters)
        local resultData = getEvolvedResultData(recipe, itemIndex)
        local possibleItems = safeMethod(recipe, "getPossibleItems")
        local possibleItemCount = listSize(possibleItems)

        addRow(recipeRows, {
            recipe_id = recipeId,
            recipe_kind = "evolved",
            sort_index = tostring(i + 1),
            module = moduleName,
            original_name = originalName,
            untranslated_name = safeMethod(recipe, "getUntranslatedName") or "",
            display_name = displayName,
            category = "Evolved",
            hidden = boolToString(safeMethod(recipe, "isHidden") == true),
            time_to_make = "",
            near_item = "",
            need_to_be_learn = "false",
            can_be_done_from_floor = "",
            remove_result_item = "",
            no_broken_items = "",
            heat = "",
            water_amount_needed = "",
            lua_test = "",
            lua_create = "",
            lua_give_xp = "",
            lua_can_perform = "",
            sound = "",
            anim_node = "",
            prop1 = "",
            prop2 = "",
            source_group_count = possibleItemCount > 0 and "2" or "1",
            source_row_count = tostring(sourceRowCount),
            required_skill_count = "0",
            required_skills = "",
            base_item = resolvedBaseItem ~= "" and resolvedBaseItem or baseItemToken,
            max_items = toNumberString(safeMethod(recipe, "getMaxItems") or ""),
            is_cookable = boolToString(safeMethod(recipe, "isCookable") == true),
            allow_frozen_item = boolToString(safeMethod(recipe, "isAllowFrozenItem") == true),
            add_ingredient_sound = safeMethod(recipe, "getAddIngredientSound") or "",
            result_full_type = resultData.item_full_type,
            result_display_name = resultData.item_display_name,
            result_exists = boolToString(resultData.item_exists),
            result_count = "1",
            result_drainable_count = "",
        })

        addRow(recipeResultRows, {
            recipe_id = recipeId,
            recipe_kind = "evolved",
            result_index = "1",
            item_token = safeMethod(recipe, "getResultItem") or "",
            item_full_type = resultData.item_full_type,
            item_display_name = resultData.item_display_name,
            item_exists = boolToString(resultData.item_exists),
            result_count = "1",
            drainable_count = "",
        })

        if resultData.item_full_type ~= "" then
            incrementCount(counters.resultByItem, resultData.item_full_type)
        end
    end
end

local function buildItemRows(items, regularCounters, evolvedCounters)
    local itemRows = {}

    for i = 1, #items do
        local item = items[i]
        addRow(itemRows, {
            item_id = item.item_id,
            full_type = item.full_type,
            module = item.module,
            type = item.type,
            script_name = item.script_name,
            display_name = item.display_name,
            mod_name = item.mod_name,
            category = item.category,
            display_category = item.display_category,
            icon_name = item.icon_name,
            texture_name = item.texture_name,
            world_sprite = item.world_sprite,
            weight = toNumberString(item.weight),
            actual_weight = toNumberString(item.actual_weight),
            count = toNumberString(item.count),
            hidden = boolToString(item.hidden),
            obsolete = boolToString(item.obsolete),
            is_vanilla = boolToString(item.is_vanilla),
            is_drainable = boolToString(item.is_drainable),
            uses = toNumberString(item.uses),
            use_delta = toNumberString(item.use_delta),
            food_type = item.food_type,
            is_spice = boolToString(item.is_spice),
            can_store_water = boolToString(item.can_store_water),
            body_location = item.body_location,
            replace_on_use = item.replace_on_use,
            replace_on_deplete = item.replace_on_deplete,
            tags = item.tags,
            categories = item.categories,
            taught_recipe_count = toNumberString(item.taught_recipe_count),
            taught_recipes = item.taught_recipes,
            regular_recipe_source_count = tostring(regularCounters.sourceByItem[item.full_type] or 0),
            regular_recipe_result_count = tostring(regularCounters.resultByItem[item.full_type] or 0),
            evolved_recipe_source_count = tostring(evolvedCounters.sourceByItem[item.full_type] or 0),
            evolved_recipe_result_count = tostring(evolvedCounters.resultByItem[item.full_type] or 0),
        })
    end

    sortRows(itemRows, { "full_type" })
    return itemRows
end

local function exportAllInternal()
    if isServer() then
        exporterNotify("Export refused: this must run from the client-side Lua console.")
        return nil
    end

    if not hasDebugAccess() then
        exporterNotify("Export refused: debug mode must be enabled before running WL_ItemRecipeExporter.exportAll().")
        return nil
    end

    exporterNotify("Starting item and recipe export via getFileWriter().")

    local items, itemIndex = collectItems()
    local recipeRows = {}
    local recipeSourceRows = {}
    local recipeResultRows = {}
    local recipeSkillRows = {}

    local regularCounters = {
        sourceByItem = {},
        resultByItem = {},
    }
    local evolvedCounters = {
        sourceByItem = {},
        resultByItem = {},
    }

    collectRegularRecipes(itemIndex, recipeRows, recipeSourceRows, recipeResultRows, recipeSkillRows, regularCounters)
    collectEvolvedRecipes(itemIndex, recipeRows, recipeSourceRows, recipeResultRows, evolvedCounters)

    sortRows(recipeRows, { "recipe_kind", "sort_index", "recipe_id" })
    sortRows(recipeSourceRows, { "recipe_kind", "recipe_id", "source_index", "candidate_index", "item_full_type", "item_token" })
    sortRows(recipeResultRows, { "recipe_kind", "recipe_id", "result_index", "item_full_type" })
    sortRows(recipeSkillRows, { "recipe_kind", "recipe_id", "skill_index", "perk_id" })

    local itemRows = buildItemRows(items, regularCounters, evolvedCounters)

    local files = {
        {
            file_name = WL_ItemRecipeExporter.FILE_PREFIX .. "items.csv",
            headers = {
                "item_id",
                "full_type",
                "module",
                "type",
                "script_name",
                "display_name",
                "mod_name",
                "category",
                "display_category",
                "icon_name",
                "texture_name",
                "world_sprite",
                "weight",
                "actual_weight",
                "count",
                "hidden",
                "obsolete",
                "is_vanilla",
                "is_drainable",
                "uses",
                "use_delta",
                "food_type",
                "is_spice",
                "can_store_water",
                "body_location",
                "replace_on_use",
                "replace_on_deplete",
                "tags",
                "categories",
                "taught_recipe_count",
                "taught_recipes",
                "regular_recipe_source_count",
                "regular_recipe_result_count",
                "evolved_recipe_source_count",
                "evolved_recipe_result_count",
            },
            rows = itemRows,
        },
        {
            file_name = WL_ItemRecipeExporter.FILE_PREFIX .. "recipes.csv",
            headers = {
                "recipe_id",
                "recipe_kind",
                "sort_index",
                "module",
                "original_name",
                "untranslated_name",
                "display_name",
                "category",
                "hidden",
                "time_to_make",
                "near_item",
                "need_to_be_learn",
                "can_be_done_from_floor",
                "remove_result_item",
                "no_broken_items",
                "heat",
                "water_amount_needed",
                "lua_test",
                "lua_create",
                "lua_give_xp",
                "lua_can_perform",
                "sound",
                "anim_node",
                "prop1",
                "prop2",
                "source_group_count",
                "source_row_count",
                "required_skill_count",
                "required_skills",
                "base_item",
                "max_items",
                "is_cookable",
                "allow_frozen_item",
                "add_ingredient_sound",
                "result_full_type",
                "result_display_name",
                "result_exists",
                "result_count",
                "result_drainable_count",
            },
            rows = recipeRows,
        },
        {
            file_name = WL_ItemRecipeExporter.FILE_PREFIX .. "recipe_sources.csv",
            headers = {
                "recipe_id",
                "recipe_kind",
                "source_role",
                "source_index",
                "candidate_index",
                "source_group_size",
                "source_count",
                "source_use",
                "keep",
                "destroy",
                "item_token",
                "item_full_type",
                "item_display_name",
                "item_exists",
                "is_spice",
            },
            rows = recipeSourceRows,
        },
        {
            file_name = WL_ItemRecipeExporter.FILE_PREFIX .. "recipe_results.csv",
            headers = {
                "recipe_id",
                "recipe_kind",
                "result_index",
                "item_token",
                "item_full_type",
                "item_display_name",
                "item_exists",
                "result_count",
                "drainable_count",
            },
            rows = recipeResultRows,
        },
        {
            file_name = WL_ItemRecipeExporter.FILE_PREFIX .. "recipe_skills.csv",
            headers = {
                "recipe_id",
                "recipe_kind",
                "skill_index",
                "perk_id",
                "perk_name",
                "level",
            },
            rows = recipeSkillRows,
        },
    }

    local exportedAt = os.date("!%Y-%m-%dT%H:%M:%SZ")
    local manifestRows = {}

    for i = 1, #files do
        local fileSpec = files[i]
        local rowCount = writeCsvFile(fileSpec.file_name, fileSpec.headers, fileSpec.rows)
        addRow(manifestRows, {
            schema_version = WL_ItemRecipeExporter.SCHEMA_VERSION,
            exported_at = exportedAt,
            file_name = fileSpec.file_name,
            row_count = tostring(rowCount),
        })
    end

    writeCsvFile(
        WL_ItemRecipeExporter.FILE_PREFIX .. "manifest.csv",
        { "schema_version", "exported_at", "file_name", "row_count" },
        manifestRows
    )

    exporterNotify("Export complete. Files written with prefix '" .. WL_ItemRecipeExporter.FILE_PREFIX .. "' to the Project Zomboid user folder.")
    exporterNotify("Call completed: items=" .. tostring(#itemRows) .. ", recipes=" .. tostring(#recipeRows) .. ", sources=" .. tostring(#recipeSourceRows) .. ", results=" .. tostring(#recipeResultRows) .. ", skills=" .. tostring(#recipeSkillRows))

    return {
        schemaVersion = WL_ItemRecipeExporter.SCHEMA_VERSION,
        exportedAt = exportedAt,
        items = #itemRows,
        recipes = #recipeRows,
        recipeSources = #recipeSourceRows,
        recipeResults = #recipeResultRows,
        recipeSkills = #recipeSkillRows,
    }
end

function WL_ItemRecipeExporter.exportAll()
    local ok, result = pcall(exportAllInternal)
    if ok then
        return result
    end

    exporterNotify("Export failed: " .. tostring(result))
    return nil
end
