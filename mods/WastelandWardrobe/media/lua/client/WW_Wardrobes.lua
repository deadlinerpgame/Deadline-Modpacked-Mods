---
--- WW_Wardrobes.lua
--- 21/10/2024
---

WW_Wardrobes = {}
WW_Wardrobes.dataByUsername = {}

function WW_Wardrobes.migrateOldData(player)
    local modData = player:getModData()
    local username = player:getUsername()

    if modData.WW_Wardrobes then
        for k, v in pairs(modData.WW_Wardrobes) do
            WW_Wardrobes.dataByUsername[username][k] = v
        end
        modData.WW_Wardrobes = nil
        WW_Wardrobes.savePlayerData(player)
    end
end

function WW_Wardrobes.getWornItems(player)
    local wornItems = {}
    local playerInventory = player:getInventory()

    for i = 0, playerInventory:getItems():size() - 1 do
        local item = playerInventory:getItems():get(i)

        if instanceof(item, "InventoryContainer") and item:canBeEquipped() == "Back" and player:isEquipped(item) then
            local location = "Back"
            local color = item:getColor()
            local tint = item:getVisual():getTint(item:getClothingItem())

            local clothingData = {
                type = "clothing",
                itemName = item:getName(),
                itemType = item:getFullType(),
                location = location,
                red = color:getRedFloat(),
                green = color:getGreenFloat(),
                blue = color:getBlueFloat(),
                tintRed = tint and tint:getRedFloat() or 1.0,
                tintGreen = tint and tint:getGreenFloat() or 1.0,
                tintBlue = tint and tint:getBlueFloat() or 1.0,
                tintAlpha = tint and tint:getAlphaFloat() or 1.0,
                baseTexture = item:getVisual():getBaseTexture(),
                textureChoice = item:getVisual():getTextureChoice(),
                decal = item:getVisual():getDecal(item:getClothingItem()) or nil
            }

            table.insert(wornItems, clothingData)
        elseif player:isEquippedClothing(item) then
            local location = item:getBodyLocation()
            if location and location ~= "" then
                local color = item:getColor()
                local tint = item:getVisual():getTint(item:getClothingItem())
                local clothingData = {
                    type = "clothing",
                    itemName = item:getName(),
                    itemType = item:getFullType(),
                    location = location,
                    red = color:getRedFloat(),
                    green = color:getGreenFloat(),
                    blue = color:getBlueFloat(),
                    tintRed = tint and tint:getRedFloat() or 1.0,
                    tintGreen = tint and tint:getGreenFloat() or 1.0,
                    tintBlue = tint and tint:getBlueFloat() or 1.0,
                    tintAlpha = tint and tint:getAlphaFloat() or 1.0,
                    baseTexture = item:getVisual():getBaseTexture(),
                    textureChoice = item:getVisual():getTextureChoice(),
                    decal = item:getVisual():getDecal(item:getClothingItem()) or nil
                }
                table.insert(wornItems, clothingData)
            end
        end
    end

    local attachedItems = player:getAttachedItems()
    for i=0, attachedItems:size()-1 do
        local attachedItem = attachedItems:get(i)
        local item = attachedItem:getItem()

        table.insert(wornItems, {
            type = "attached",
            slotType = item:getAttachedSlotType(),
            itemType = item:getFullType(),
        })
    end

    return wornItems
end

local function getNearbyContainers(player)
    local containers = {}
    table.insert(containers, player:getInventory())

    local playerNum = player and player:getPlayerNum() or -1
    local lootContainers = getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks
    for _, lootContainer in ipairs(lootContainers) do
        table.insert(containers, lootContainer.inventory)
    end

    local playerSquare = player:getSquare()
    if playerSquare then
        for i = 0, playerSquare:getObjects():size() - 1 do
            local obj = playerSquare:getObjects():get(i)
            if obj:getContainer() then
                table.insert(containers, obj:getContainer())
            end
        end
    end

    return containers
end

function WW_Wardrobes.wearWardrobe(player, wardrobe)
    local nearbyContainers = getNearbyContainers(player)
    local itemsToRemove = {}
    local wornItems = WW_Wardrobes.getWornItems(player)

    local validContainers = {}
    for _, container in ipairs(nearbyContainers) do
        if container ~= player:getInventory() and container:getType() ~= "floor" then
            table.insert(validContainers, container)
        end
    end

    local function clothingItemsMatch(wornItem, wardrobeItem)
        local tolerance = 0.001
        local function floatEqual(a, b)
            if type(a) == "number" and type(b) == "number" then
                return math.abs(a - b) <= tolerance
            end
            return a == b
        end

        return wornItem.itemType == wardrobeItem.itemType and
               floatEqual(wornItem.red, wardrobeItem.red) and
               floatEqual(wornItem.green, wardrobeItem.green) and
               floatEqual(wornItem.blue, wardrobeItem.blue) and
               floatEqual(wornItem.tintRed, wardrobeItem.tintRed) and
               floatEqual(wornItem.tintGreen, wardrobeItem.tintGreen) and
               floatEqual(wornItem.tintBlue, wardrobeItem.tintBlue) and
               floatEqual(wornItem.tintAlpha, wardrobeItem.tintAlpha) and
               wornItem.baseTexture == wardrobeItem.baseTexture and
               wornItem.textureChoice == wardrobeItem.textureChoice and
               (wornItem.decal or "") == (wardrobeItem.decal or "")
    end

    local function itemExistsInInventoryOrContainer(wardrobeItem)
        local inventoryItems = player:getInventory():getItems()
        for i = 0, inventoryItems:size() - 1 do
            local item = inventoryItems:get(i)
            if item:getFullType() == wardrobeItem.itemType then
                return true
            end
        end

        for _, container in ipairs(nearbyContainers) do
            local containerItems = container:getItems()
            for i = 0, containerItems:size() - 1 do
                local item = containerItems:get(i)
                if item:getFullType() == wardrobeItem.itemType then
                    return true
                end
            end
        end
        return false
    end

    local availableItems = 0
    local missingItems = 0

    for _, wardrobeItemData in ipairs(wardrobe) do
        if itemExistsInInventoryOrContainer(wardrobeItemData) then
            availableItems = availableItems + 1
        else
            missingItems = missingItems + 1
        end
    end

    if availableItems < (#wardrobe / 2) then
        player:Say(getText("UI_WW_HalfMissing"))
        return
    end

    for _, wornItemData in ipairs(wornItems) do
        local foundInWardrobe = false
        for _, wardrobeItemData in ipairs(wardrobe) do
            if clothingItemsMatch(wornItemData, wardrobeItemData) then
                foundInWardrobe = true
                break
            end
        end

        if not foundInWardrobe then
            local inventoryItems = player:getInventory():getItems()
            for i = 0, inventoryItems:size() - 1 do
                local item = inventoryItems:get(i)
                if item:getFullType() == wornItemData.itemType and wornItemData.type == "clothing" then
                    ISTimedActionQueue.add(ISUnequipAction:new(player, item, 25))
                    table.insert(itemsToRemove, item)
                    break
                elseif item:getFullType() == wornItemData.itemType and wornItemData.type == "attached" then
                    table.insert(itemsToRemove, item)
                    break
                end
            end
        end
    end

    for _, wardrobeItemData in ipairs(wardrobe) do
        local alreadyWorn = false
        for _, wornItemData in ipairs(wornItems) do
            if wardrobeItemData.type == "attached" and wornItemData.type == "attached" then
                if wardrobeItemData.itemType == wornItemData.itemType then
                    alreadyWorn = true
                    break
                end
            elseif wardrobeItemData.type == "clothing" and wornItemData.type == "clothing" then
                if clothingItemsMatch(wornItemData, wardrobeItemData) then
                    alreadyWorn = true
                    break
                end
            end
        end

        if not alreadyWorn then
            local itemFound = false
            for _, container in ipairs(nearbyContainers) do
                local containerItems = container:getItems()
                for i = 0, containerItems:size() - 1 do
                    local item = containerItems:get(i)
                    if wardrobeItemData.type == "attached" then
                        if item:getFullType() == wardrobeItemData.itemType then
                            ISInventoryPaneContextMenu.transferIfNeeded(player, item)
                            local action = WWAttachItem:new(player, item, wardrobeItemData.slotType)
                            ISTimedActionQueue.add(action)
                            itemFound = true
                            break
                        end
                    else
                        if item:getFullType() == wardrobeItemData.itemType then
                            local color = item:getColor()
                            local tint = item:getVisual():getTint(item:getClothingItem())
                            if color:getRedFloat() == wardrobeItemData.red and
                            color:getGreenFloat() == wardrobeItemData.green and
                            color:getBlueFloat() == wardrobeItemData.blue and
                            tint:getRedFloat() == wardrobeItemData.tintRed and
                            tint:getGreenFloat() == wardrobeItemData.tintGreen and
                            tint:getBlueFloat() == wardrobeItemData.tintBlue and
                            item:getVisual():getBaseTexture() == wardrobeItemData.baseTexture and
                            item:getVisual():getTextureChoice() == wardrobeItemData.textureChoice and
                            (item:getVisual():getDecal(item:getClothingItem()) or "") == (wardrobeItemData.decal or "") then
                                ISInventoryPaneContextMenu.transferIfNeeded(player, item)
                                ISTimedActionQueue.add(ISWearClothing:new(player, item, 25))
                                itemFound = true
                                break
                            end
                        end
                    end
                end
                if itemFound then break end
            end
            if not itemFound then
                player:Say(wardrobeItemData.itemName .. getText("UI_WW_ItemMissing"))
            end
        end
    end

    if #itemsToRemove > 0 then
        ISTimedActionQueue.add(ISClothingTransferAction:new(player, itemsToRemove, validContainers, player:getInventory()))
    end

    triggerEvent("OnClothingUpdated", player)
end

function WW_Wardrobes.getWardrobes(player)
    if not player then
        return {}
    end

    local username = player:getUsername()
    if not WW_Wardrobes.dataByUsername[username] then
        return {}
    end

    return WW_Wardrobes.dataByUsername[username]
end

function WW_Wardrobes.savePlayerData(player)
    if not player then return end
    if not WW_Wardrobes.dataByUsername[player:getUsername()] then return end
    WL_UserData.Set("WW_Wardrobes", WW_Wardrobes.dataByUsername[player:getUsername()], player:getUsername())
end

function WW_Wardrobes.deleteAllWardrobes(player)
    WW_Wardrobes.dataByUsername[player:getUsername()] = {}
    WW_Wardrobes.savePlayerData(player)
end

function WW_Wardrobes.setWardrobe(player, name, wardrobeData)
    local enrichedWardrobeData = {}
    for _, item in ipairs(wardrobeData) do
        if item.type == "clothing" then
            local enrichedItemData = {
                type = item.type,
                itemType = item.itemType,
                itemName = item.itemName,
                red = item.red or 1.0,
                green = item.green or 1.0,
                blue = item.blue or 1.0,
                tintRed = item.tintRed or 1.0,
                tintGreen = item.tintGreen or 1.0,
                tintBlue = item.tintBlue or 1.0,
                tintAlpha = item.tintAlpha or 1.0,
                baseTexture = item.baseTexture or "",
                textureChoice = item.textureChoice or 0,
                decal = item.decal or ""
            }
            table.insert(enrichedWardrobeData, enrichedItemData)
        elseif item.type == "attached" then
            local enrichedItemData = {
                type = item.type,
                itemType = item.itemType,
                slotType = item.slotType
            }
            table.insert(enrichedWardrobeData, enrichedItemData)
        end
    end
    WW_Wardrobes.dataByUsername[player:getUsername()][name] = enrichedWardrobeData
    WW_Wardrobes.savePlayerData(player)
end

function WW_Wardrobes.deletePlayerWardrobe(player, name)
    WW_Wardrobes.dataByUsername[player:getUsername()][name] = nil
    WW_Wardrobes.savePlayerData(player)
end

WL_PlayerReady.Add(function(pIdx, player)
    local username = player:getUsername()
    WL_UserData.Fetch("WW_Wardrobes", username, function (data)
        WW_Wardrobes.dataByUsername[username] = data or {}
        WW_Wardrobes.migrateOldData(player)
    end)
end)

