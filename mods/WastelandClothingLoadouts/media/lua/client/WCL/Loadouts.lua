WCL_Loadouts = WCL_Loadouts or {}
local hasWLDi = pcall(require, "WLDi_System")
-- WLDi_System is now available as a global if the require succeeded
WCL_Loadouts.Loadouts = WCL_Loadouts.Loadouts or {}
WCL_Loadouts.PlayerLoadouts = WCL_Loadouts.PlayerLoadouts or {}
WCL_Loadouts.DefaultsCache = WCL_Loadouts.DefaultsCache or {}

-- ============================================================================
-- CONSTANTS
-- ============================================================================

WCL_Loadouts.VERSION = 1

-- Default options for restoration
WCL_Loadouts.DEFAULT_RESTORE_OPTIONS = {
    removeItems = true,      -- Remove items from inventory before restoring
    restoreOutfit = true,    -- Restore worn/equipped/attached items (including makeup)
    restoreItems = true,     -- Restore inventory items
    restoreIdentity = true,  -- Restore WRC identity data
    restoreHair = true,      -- Restore hair and beard style/color
    restoreCharacteristics = true  -- Restore WastelandDisguises characteristics
}

-- ============================================================================
-- HELPER FUNCTIONS - Default Detection
-- ============================================================================

--- Get or create cached default values for an item type
--- @param itemType string The full item type (e.g., "Base.Shirt")
--- @return InventoryItem|nil The default item instance
function WCL_Loadouts.getDefaultItem(itemType)
    if not WCL_Loadouts.DefaultsCache[itemType] then
        local defaultItem = InventoryItemFactory.CreateItem(itemType)
        if defaultItem then
            WCL_Loadouts.DefaultsCache[itemType] = defaultItem
        end
    end
    return WCL_Loadouts.DefaultsCache[itemType]
end

--- Check if two items are identical (for stacking purposes)
--- @param item1 table Serialized item data
--- @param item2 table Serialized item data
--- @return boolean True if items are identical
function WCL_Loadouts.itemsAreIdentical(item1, item2)
    if item1.itemType ~= item2.itemType then
        return false
    end
    
    -- Check if both have same equipped/attached state
    if (item1.equippedLocation ~= nil) ~= (item2.equippedLocation ~= nil) then
        return false
    end
    if item1.equippedLocation and item1.equippedLocation ~= item2.equippedLocation then
        return false
    end
    
    if (item1.equippedPosition ~= nil) ~= (item2.equippedPosition ~= nil) then
        return false
    end
    if item1.equippedPosition and item1.equippedPosition ~= item2.equippedPosition then
        return false
    end
    
    if (item1.attachedSlot ~= nil) ~= (item2.attachedSlot ~= nil) then
        return false
    end
    if item1.attachedSlot and item1.attachedSlot ~= item2.attachedSlot then
        return false
    end
    
    -- Check all properties match
    for key, value in pairs(item1) do
        if key ~= "quantity" and key ~= "itemType" then
            if type(value) == "table" then
                if not WCL_Loadouts.tablesEqual(value, item2[key]) then
                    return false
                end
            elseif value ~= item2[key] then
                return false
            end
        end
    end
    
    -- Check that item2 doesn't have extra properties
    for key, value in pairs(item2) do
        if key ~= "quantity" and key ~= "itemType" then
            if item1[key] == nil then
                return false
            end
        end
    end
    
    return true
end

--- Deep comparison of two tables
--- @param t1 table First table
--- @param t2 table Second table
--- @return boolean True if tables are equal
function WCL_Loadouts.tablesEqual(t1, t2)
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    
    for k, v in pairs(t1) do
        if type(v) == "table" then
            if not WCL_Loadouts.tablesEqual(v, t2[k]) then
                return false
            end
        elseif v ~= t2[k] then
            return false
        end
    end
    
    for k, v in pairs(t2) do
        if t1[k] == nil then
            return false
        end
    end
    
    return true
end

--- Check if a value is different from default
--- @param value any The value to check
--- @param defaultValue any The default value
--- @return boolean True if different from default
function WCL_Loadouts.isDifferentFromDefault(value, defaultValue)
    if type(value) == "number" and type(defaultValue) == "number" then
        return math.abs(value - defaultValue) > 0.001
    end
    return value ~= defaultValue
end

-- ============================================================================
-- SERIALIZATION FUNCTIONS
-- ============================================================================

--- Serialize visual properties of an item
--- @param item InventoryItem The item to serialize
--- @return table|nil Visual properties or nil if all default
function WCL_Loadouts.serializeVisual(item)
    local visual = {}
    local hasChanges = false
    
    local itemVisual = item:getVisual()
    
    if itemVisual then
        -- Base texture
        local baseTexture = itemVisual:getBaseTexture()
        if baseTexture and baseTexture ~= -1 then
            visual.baseTexture = baseTexture
            hasChanges = true
        end
        
        -- Texture choice
        local textureChoice = itemVisual:getTextureChoice()
        if textureChoice and textureChoice ~= -1 then
            visual.textureChoice = textureChoice
            hasChanges = true
        end

        local tint = itemVisual:getTint()
        if tint then
            local tintData = {
                r = tint:getRedFloat(),
                g = tint:getGreenFloat(),
                b = tint:getBlueFloat(),
                a = tint:getAlphaFloat()
            }
            -- Only store if not default (1,1,1,1)
            if tintData.r ~= 1 or tintData.g ~= 1 or tintData.b ~= 1 or tintData.a ~= 1 then
                visual.tint = tintData
                hasChanges = true
            end
        end

        if instanceof(item, "Clothing") then
            local clothingItem = item:getClothingItem()
            if clothingItem then                
                -- Decal
                local decal = itemVisual:getDecal(clothingItem)
                if decal and decal ~= "" then
                    visual.decal = decal
                    hasChanges = true
                end
            end
        end
    end
    
    return hasChanges and visual or nil
end

--- Serialize color properties of an item
--- @param item InventoryItem The item to serialize
--- @return table|nil Color data or nil if default
function WCL_Loadouts.serializeColor(item)
    local color = item:getColor()
    if not color then return nil end
    
    local colorData = {
        r = color:getRedFloat(),
        g = color:getGreenFloat(),
        b = color:getBlueFloat()
    }

    if colorData.r == 1 and colorData.g == 1 and colorData.b == 1 then
        return nil
    end
    
    return colorData
end

--- Serialize container contents recursively
--- @param item InventoryItem The container item
--- @return table|nil Array of serialized items or nil if empty
function WCL_Loadouts.serializeContainer(item)
    if not item:IsInventoryContainer() then
        return nil
    end
    
    local containerInv = item:getInventory()
    if not containerInv then return nil end
    
    local items = containerInv:getItems()
    if items:size() == 0 then return nil end
    
    local containerItems = {}
    for i = 0, items:size() - 1 do
        local containedItem = items:get(i)
        local serialized = WCL_Loadouts.serializeItem(containedItem, false)
        if serialized then
            table.insert(containerItems, serialized)
        end
    end
    
    -- Stack identical items in container
    if #containerItems > 0 then
        containerItems = WCL_Loadouts.stackItems(containerItems)
    end
    
    return #containerItems > 0 and containerItems or nil
end

--- Serialize a single item with only non-default properties
--- @param item InventoryItem The item to serialize
--- @return table|nil Serialized item data or nil on error
function WCL_Loadouts.serializeItem(item)
    if not item then return nil end
    
    local itemType = item:getFullType()
    local defaultItem = WCL_Loadouts.getDefaultItem(itemType)
    
    local data = {
        itemType = itemType,
        quantity = 1  -- Will be updated during stacking
    }
    
    -- Check if equipped or attached
    local player = getPlayer()
    if player then
        -- Check if equipped as a container (backpack, etc.)
        if item:IsInventoryContainer() and item:canBeEquipped() ~= "" then
            local equipSlot = item:canBeEquipped()
            if player:getWornItem(equipSlot) == item then
                data.equippedLocation = equipSlot
            end
        -- Check if equipped as clothing
        elseif item:IsClothing() then
            local bodyLocation = item:getBodyLocation()
            if bodyLocation and bodyLocation ~= "" and player:isEquippedClothing(item) then
                data.equippedLocation = bodyLocation
            end
        end
        
        -- Check if it's the primary or secondary weapon (or both hands)
        if player:isItemInBothHands(item) then
            data.equippedPosition = "both"
        elseif player:getPrimaryHandItem() == item then
            data.equippedPosition = "primary"
        elseif player:getSecondaryHandItem() == item then
            data.equippedPosition = "secondary"
        end
        
        -- Check if attached (on back or belt)
        local attachedItems = player:getAttachedItems()
        for i = 0, attachedItems:size() - 1 do
            local attached = attachedItems:get(i)
            if attached:getItem() == item then
                data.attachedSlot = attached:getLocation()
                
                -- Also capture item's attached properties
                local attachedSlotIndex = item:getAttachedSlot()
                if attachedSlotIndex and attachedSlotIndex >= 0 then
                    data.attachedSlotIndex = attachedSlotIndex
                end
                
                local attachedSlotType = item:getAttachedSlotType()
                if attachedSlotType then
                    data.attachedSlotType = attachedSlotType
                end
                
                local attachedToModel = item:getAttachedToModel()
                if attachedToModel then
                    data.attachedToModel = attachedToModel
                end
                break
            end
        end
    end
    
    -- Core properties
    if item:getAge() > 0 then
        data.age = item:getAge()
    end
    
    local condition = item:getCondition()
    if defaultItem then
        if WCL_Loadouts.isDifferentFromDefault(condition, defaultItem:getCondition()) then
            data.condition = condition
        end
    elseif condition ~= item:getConditionMax() then
        data.condition = condition
    end
    
    if item:isBroken() then
        data.broken = true
    end
    
    if item:isCustomName() then
        data.name = item:getName()
    end
    
    if item:isCustomWeight() then
        data.weight = item:getActualWeight()
    end
    
    if item:isFavorite() then
        data.favorite = true
    end
    
    if item:isInfected() then
        data.infected = true
    end
    
    if item:isWet() then
        data.wet = true
        data.wetCooldown = item:getWetCooldown()
    end
    
    -- Visual properties
    local visual = WCL_Loadouts.serializeVisual(item)
    if visual then
        data.visual = visual
    end
    
    -- Color
    local color = WCL_Loadouts.serializeColor(item)
    if color then
        data.color = color

        if item:isCustomColor() then
            data.customColor = true
        end
    end
    
    -- Type-specific properties
    
    -- Recorded Media (tapes, VHS, etc.)
    if item:isRecordedMedia() then
        data.mediaType = item:getMediaType()
        local mediaData = item:getMediaData()
        if mediaData then
            data.mediaData = mediaData
        end
    end
    
    if instanceof(item, "Food") then
        if item:isCooked() then
            data.cooked = true
            local cookedString = item:getCookedString()
            if cookedString and cookedString ~= "" then
                data.cookedString = cookedString
            end
        end
        if item:isBurnt() then
            data.burnt = true
            local burntString = item:getBurntString()
            if burntString and burntString ~= "" then
                data.burntString = burntString
            end
        end
        -- Store all food stats if they differ from defaults
        if defaultItem then
            local calories = item:getCalories()
            if WCL_Loadouts.isDifferentFromDefault(calories, defaultItem:getCalories()) then
                data.calories = calories
            end
            local carbs = item:getCarbohydrates()
            if WCL_Loadouts.isDifferentFromDefault(carbs, defaultItem:getCarbohydrates()) then
                data.carbohydrates = carbs
            end
            local proteins = item:getProteins()
            if WCL_Loadouts.isDifferentFromDefault(proteins, defaultItem:getProteins()) then
                data.proteins = proteins
            end
            local lipids = item:getLipids()
            if WCL_Loadouts.isDifferentFromDefault(lipids, defaultItem:getLipids()) then
                data.lipids = lipids
            end
            local hungChange = item:getHungChange()
            if WCL_Loadouts.isDifferentFromDefault(hungChange, defaultItem:getHungChange()) then
                data.hungChange = hungChange
            end
            local unhappyChange = item:getUnhappyChange()
            if WCL_Loadouts.isDifferentFromDefault(unhappyChange, defaultItem:getUnhappyChange()) then
                data.unhappyChange = unhappyChange
            end
            local boredomChange = item:getBoredomChange()
            if WCL_Loadouts.isDifferentFromDefault(boredomChange, defaultItem:getBoredomChange()) then
                data.boredomChange = boredomChange
            end
            local stressChange = item:getStressChange()
            if WCL_Loadouts.isDifferentFromDefault(stressChange, defaultItem:getStressChange()) then
                data.stressChange = stressChange
            end
            local enduranceChange = item:getEnduranceChange()
            if WCL_Loadouts.isDifferentFromDefault(enduranceChange, defaultItem:getEnduranceChange()) then
                data.enduranceChange = enduranceChange
            end
            local painReduction = item:getPainReduction()
            if WCL_Loadouts.isDifferentFromDefault(painReduction, defaultItem:getPainReduction()) then
                data.painReduction = painReduction
            end
            local thirstChange = item:getThirstChange()
            if WCL_Loadouts.isDifferentFromDefault(thirstChange, defaultItem:getThirstChange()) then
                data.thirstChange = thirstChange
            end
        end
        if item:isCookedInMicrowave() then
            data.cookedInMicrowave = true
        end
        if item:getSpices() then
            data.spices = item:getSpices()
        end
    end
    
    if instanceof(item, "DrainableComboItem") then
        local usedDelta = item:getUsedDelta()
        if defaultItem then
            if WCL_Loadouts.isDifferentFromDefault(usedDelta, defaultItem:getUsedDelta()) then
                data.usedDelta = usedDelta
            end
        elseif usedDelta < 1.0 then
            data.usedDelta = usedDelta
        end
    end
    
    if instanceof(item, "HandWeapon") then
        -- Handle weapon parts (attachments)
        local parts = item:getAllWeaponParts()
        if parts and parts:size() > 0 then
            local weaponParts = {}
            for i = 0, parts:size() - 1 do
                local part = parts:get(i)
                local partData = WCL_Loadouts.serializeItem(part)
                if partData then
                    table.insert(weaponParts, partData)
                end
            end
            if #weaponParts > 0 then
                data.weaponParts = weaponParts
            end
        end
        
        -- Handle weapons with magazine/clip system
        if item:isContainsClip() then
            data.containsClip = true
            -- Check if there's actually a clip inserted
            local maxClipSize = item:getMaxAmmo()
            if maxClipSize > 0 then
                local currentAmmo = item:getCurrentAmmoCount()
                if currentAmmo > 0 then
                    data.currentAmmo = currentAmmo
                end
            end
        else
            -- Handle weapons without clips (like shotguns, revolvers)
            local currentAmmo = item:getCurrentAmmoCount()
            if currentAmmo > 0 then
                data.currentAmmo = currentAmmo
            end
        end
        
        -- Only store roundChambered if it's true
        if item:haveChamber() and item:isRoundChambered() then
            data.roundChambered = true
        end
        
        -- Store weapon stats if they differ from defaults
        if defaultItem then
            local minDamage = item:getMinDamage()
            if WCL_Loadouts.isDifferentFromDefault(minDamage, defaultItem:getMinDamage()) then
                data.minDamage = minDamage
            end
            local maxDamage = item:getMaxDamage()
            if WCL_Loadouts.isDifferentFromDefault(maxDamage, defaultItem:getMaxDamage()) then
                data.maxDamage = maxDamage
            end
            local minAngle = item:getMinAngle()
            if WCL_Loadouts.isDifferentFromDefault(minAngle, defaultItem:getMinAngle()) then
                data.minAngle = minAngle
            end
            
            -- Handle ranged vs melee min range
            if item:isRanged() then
                local minRangeRanged = item:getMinRangeRanged()
                if WCL_Loadouts.isDifferentFromDefault(minRangeRanged, defaultItem:getMinRangeRanged()) then
                    data.minRangeRanged = minRangeRanged
                end
            else
                local minRange = item:getMinRange()
                if WCL_Loadouts.isDifferentFromDefault(minRange, defaultItem:getMinRange()) then
                    data.minRange = minRange
                end
            end
            
            local maxRange = item:getMaxRange()
            if WCL_Loadouts.isDifferentFromDefault(maxRange, defaultItem:getMaxRange()) then
                data.maxRange = maxRange
            end
            local aimingTime = item:getAimingTime()
            if WCL_Loadouts.isDifferentFromDefault(aimingTime, defaultItem:getAimingTime()) then
                data.aimingTime = aimingTime
            end
            local recoilDelay = item:getRecoilDelay()
            if WCL_Loadouts.isDifferentFromDefault(recoilDelay, defaultItem:getRecoilDelay()) then
                data.recoilDelay = recoilDelay
            end
            local reloadTime = item:getReloadTime()
            if WCL_Loadouts.isDifferentFromDefault(reloadTime, defaultItem:getReloadTime()) then
                data.reloadTime = reloadTime
            end
            local clipSize = item:getClipSize()
            if WCL_Loadouts.isDifferentFromDefault(clipSize, defaultItem:getClipSize()) then
                data.clipSize = clipSize
            end
        end
    end
    
    if instanceof(item, "Literature") then
        if item:canBeWrite() ~= nil then
            data.canBeWrite = item:canBeWrite()
        end
        local lockedBy = item:getLockedBy()
        if lockedBy and lockedBy ~= "" then
            data.lockedBy = lockedBy
        end
        local pages = item:getCustomPages()
        if pages and pages:size() > 0 then
            local customPages = {}
            for i = 0, pages:size() - 1 do
                table.insert(customPages, pages:get(i))
            end
            if #customPages > 0 then
                data.customPages = customPages
            end
        end
    end
    
    if instanceof(item, "Clothing") then
        -- Note: patches are handled via visual copyFrom
        local palette = item:getPalette()
        if palette and palette ~= "Trousers_White" then
            data.palette = palette
        end
        local spriteName = item:getSpriteName()
        if spriteName and not WCL_Loadouts.isDifferentFromDefault(spriteName, defaultItem:getSpriteName()) then
            data.spriteName = spriteName
        end
    end
    
    if instanceof(item, "Key") then
        local keyId = item:getKeyId()
        if keyId and keyId >= 0 then
            data.keyId = keyId
        end
        if item:isDigitalPadlock() then
            data.digitalPadlock = true
        end
        if item:isPadlock() then
            data.padlock = true
        end
        local numberOfKey = item:getNumberOfKey()
        if numberOfKey and numberOfKey > 0 then
            data.numberOfKey = numberOfKey
        end
    end
    
    if instanceof(item, "KeyRing") then
        local keys = item:getKeys()
        if keys and keys:size() > 0 then
            local keysList = {}
            for i = 0, keys:size() - 1 do
                local key = keys:get(i)
                local keyData = WCL_Loadouts.serializeItem(key)
                if keyData then
                    table.insert(keysList, keyData)
                end
            end
            if #keysList > 0 then
                data.keys = keysList
            end
        end
    end
    
    -- ModData
    if item:hasModData() then
        local modData = item:getModData()
        if modData then
            -- Convert KahluaTable to Lua table
            local modDataCopy = {}
            local hasData = false
            for k, v in pairs(modData) do
                modDataCopy[k] = v
                hasData = true
            end
            if hasData then
                data.modData = modDataCopy
            end
        end
    end
    
    -- Container contents (recursive)
    local containerItems = WCL_Loadouts.serializeContainer(item)
    if containerItems then
        data.container = containerItems
    end
    
    return data
end

--- Stack identical items in the serialized data
--- @param items table Array of serialized items
--- @return table Array with stacked items
function WCL_Loadouts.stackItems(items)
    local stacked = {}
    local stackMap = {}
    
    for _, item in ipairs(items) do
        local found = false
        
        -- Try to find identical item to stack with
        for idx, stackedItem in ipairs(stacked) do
            if WCL_Loadouts.itemsAreIdentical(item, stackedItem) then
                stackedItem.quantity = stackedItem.quantity + 1
                found = true
                break
            end
        end
        
        if not found then
            table.insert(stacked, item)
        end
    end

    for _, item in ipairs(stacked) do
        if item.quantity <= 1 then
            item.quantity = nil  -- Remove quantity if only 1, to save space
        end
    end
    
    return stacked
end

-- ============================================================================
-- CAPTURE FUNCTION
-- ============================================================================

--- Capture the entire player inventory as a loadout
--- @param player IsoPlayer The player to capture from
--- @return table The loadout data structure
function WCL_Loadouts.captureCurrent(player)
    local inventory = player:getInventory()
    local items = inventory:getItems()
    
    local serializedItems = {}
    
    -- Serialize all items
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local serialized = WCL_Loadouts.serializeItem(item, true)
        if serialized then
            table.insert(serializedItems, serialized)
        end
    end
    
    -- Stack identical items
    serializedItems = WCL_Loadouts.stackItems(serializedItems)
    
    -- Create loadout structure
    local loadout = {
        version = WCL_Loadouts.VERSION,
        items = serializedItems,
        metadata = {
            captureDate = os.time(),
            playerName = player:getUsername()
        }
    }
    
    -- Store WRC Data
    if WRC and WRC.Meta then
        local username = player:getUsername()
        local wrcName = WRC.Meta.GetName(username)
        local wrcColor = WRC.Meta.GetNameColorRGB(username)
        local wrcStatus = WRC.Meta.GetStatus(username)
        
        loadout.wlrpchat = {
            name = wrcName,
            color = wrcColor,
            status = wrcStatus
        }
    end

    -- Store WRC status
    
    -- Store hair style and color
    local humanVisual = player:getHumanVisual()
    if humanVisual then
        local hairColor = humanVisual:getHairColor()
        loadout.hair = {
            model = humanVisual:getHairModel(),
            color = {
                r = hairColor:getRedFloat(),
                g = hairColor:getGreenFloat(),
                b = hairColor:getBlueFloat()
            }
        }
        
        -- Store beard for male characters
        if not player:isFemale() then
            local beardColor = humanVisual:getBeardColor()
            loadout.beard = {
                model = humanVisual:getBeardModel(),
                color = {
                    r = beardColor:getRedFloat(),
                    g = beardColor:getGreenFloat(),
                    b = beardColor:getBlueFloat()
                }
            }
        end
    end
    
    -- Store WastelandDisguises characteristics
    if hasWLDi and WLDi_System and WLDi_System.getCharacteristicsEntry then
        local characteristics = WLDi_System:getCharacteristicsEntry(player:getUsername())
        if characteristics then
            loadout.wastelandDisguises = characteristics
        end
    end
    
    return loadout
end

-- ============================================================================
-- RESTORATION FUNCTIONS
-- ============================================================================

--- Apply visual properties to an item
--- @param item InventoryItem The item to modify
--- @param visual table Visual properties data
function WCL_Loadouts.applyVisual(item, visual)
    if not visual then return end
    
    local itemVisual = item:getVisual()
    if not itemVisual then return end
    
    if visual.baseTexture then
        itemVisual:setBaseTexture(visual.baseTexture)
    end
    
    if visual.textureChoice then
        itemVisual:setTextureChoice(visual.textureChoice)
    end
    
    if visual.tint then
        local tint = ImmutableColor.new(
            visual.tint.r,
            visual.tint.g,
            visual.tint.b,
            visual.tint.a
        )
        itemVisual:setTint(tint)
    end
    
    if visual.decal and instanceof(item, "Clothing") then
        itemVisual:setDecal(visual.decal)
    end
    
    -- Don't sync here - will be synced after color is applied
end

--- Apply color properties to an item
--- @param item InventoryItem The item to modify
--- @param colorData table Color data
function WCL_Loadouts.applyColor(item, colorData)
    if not colorData then return end
    
    local color = Color.new(colorData.r, colorData.g, colorData.b, 1)
    item:setColor(color)
end

--- Restore a single item to inventory
--- @param itemData table Serialized item data
--- @param container ItemContainer The container to add to
--- @param player IsoPlayer The player (for equipping)
--- @return InventoryItem|nil The created item
function WCL_Loadouts.restoreItem(itemData, container, player)
    if not itemData or not container then return nil end
    
    -- Create the item
    local item = InventoryItemFactory.CreateItem(itemData.itemType)
    if not item then
        print("WCL_Loadouts: Failed to create item: " .. tostring(itemData.itemType))
        return nil
    end
    
    -- Apply core properties
    if itemData.age then
        item:setAge(itemData.age)
    end
    
    if itemData.condition then
        item:setCondition(itemData.condition, false)
    end
    
    if itemData.broken then
        item:setBroken(true)
    end
    
    if itemData.name then
        item:setName(itemData.name)
        item:setCustomName(true)
    end
    
    if itemData.weight then
        item:setActualWeight(itemData.weight)
        item:setCustomWeight(true)
    end
    
    if itemData.favorite then
        item:setFavorite(true)
    end
    
    if itemData.infected then
        item:setInfected(true)
    end
    
    if itemData.wet then
        item:setWet(true)
        if itemData.wetCooldown then
            item:setWetCooldown(itemData.wetCooldown)
        end
    end
    
    -- Apply visual properties
    WCL_Loadouts.applyVisual(item, itemData.visual)
    
    -- Synchronize visual and color
    if itemData.visual then
        item:synchWithVisual()
    end
    
    -- Apply color
    WCL_Loadouts.applyColor(item, itemData.color)
    if itemData.customColor then
        item:setCustomColor(true)
    end
    
    -- Type-specific properties
    
    -- Recorded Media
    if itemData.mediaType then
        item:setMediaType(itemData.mediaType)
        if itemData.mediaData then
            item:setRecordedMediaData(itemData.mediaData)
        end
    end
    
    if instanceof(item, "Food") then
        if itemData.cooked then
            item:setCooked(true)
            if itemData.cookedString then
                item:setCookedString(itemData.cookedString)
            end
        end
        if itemData.burnt then
            item:setBurnt(true)
            if itemData.burntString then
                item:setBurntString(itemData.burntString)
            end
        end
        if itemData.calories then
            item:setCalories(itemData.calories)
        end
        if itemData.carbohydrates then
            item:setCarbohydrates(itemData.carbohydrates)
        end
        if itemData.proteins then
            item:setProteins(itemData.proteins)
        end
        if itemData.lipids then
            item:setLipids(itemData.lipids)
        end
        if itemData.hungChange then
            item:setHungChange(itemData.hungChange)
        end
        if itemData.unhappyChange then
            item:setUnhappyChange(itemData.unhappyChange)
        end
        if itemData.boredomChange then
            item:setBoredomChange(itemData.boredomChange)
        end
        if itemData.stressChange then
            item:setStressChange(itemData.stressChange)
        end
        if itemData.enduranceChange then
            item:setEnduranceChange(itemData.enduranceChange)
        end
        if itemData.painReduction then
            item:setPainReduction(itemData.painReduction)
        end
        if itemData.thirstChange then
            item:setThirstChange(itemData.thirstChange)
        end
        if itemData.cookedInMicrowave then
            item:setCookedInMicrowave(true)
        end
        if itemData.spices then
            item:setSpices(itemData.spices)
        end
    end
    
    if instanceof(item, "DrainableComboItem") then
        if itemData.usedDelta then
            item:setUsedDelta(itemData.usedDelta)
            item:updateWeight()
        end
    end
    
    if instanceof(item, "HandWeapon") then
        -- Restore weapon parts first
        if itemData.weaponParts then
            for _, partData in ipairs(itemData.weaponParts) do
                local part = WCL_Loadouts.restoreItem(partData, container, player)
                if part then
                    item:attachWeaponPart(part)
                    -- Remove the part from container since it's now attached to weapon
                    container:Remove(part)
                end
            end
        end
        
        if itemData.containsClip ~= nil then
            item:setContainsClip(itemData.containsClip)
        end
        if itemData.currentAmmo then
            item:setCurrentAmmoCount(itemData.currentAmmo)
        end
        if itemData.roundChambered ~= nil then
            item:setRoundChambered(itemData.roundChambered)
        end
        
        -- Restore weapon stats
        if itemData.minDamage then
            item:setMinDamage(itemData.minDamage)
        end
        if itemData.maxDamage then
            item:setMaxDamage(itemData.maxDamage)
        end
        if itemData.minAngle then
            item:setMinAngle(itemData.minAngle)
        end
        if itemData.minRangeRanged then
            item:setMinRangeRanged(itemData.minRangeRanged)
        end
        if itemData.minRange then
            item:setMinRange(itemData.minRange)
        end
        if itemData.maxRange then
            item:setMaxRange(itemData.maxRange)
        end
        if itemData.aimingTime then
            item:setAimingTime(itemData.aimingTime)
        end
        if itemData.recoilDelay then
            item:setRecoilDelay(itemData.recoilDelay)
        end
        if itemData.reloadTime then
            item:setReloadTime(itemData.reloadTime)
        end
        if itemData.clipSize then
            item:setClipSize(itemData.clipSize)
        end
    end
    
    if instanceof(item, "Literature") then
        if itemData.canBeWrite ~= nil then
            item:setCanBeWrite(itemData.canBeWrite)
        end
        if itemData.lockedBy then
            item:setLockedBy(itemData.lockedBy)
        end
        if itemData.customPages then
            local pages = ArrayList.new()
            for _, page in ipairs(itemData.customPages) do
                pages:add(page)
            end
            item:setCustomPages(pages)
        end
    end
    
    if instanceof(item, "Clothing") then
        if itemData.patches then
            -- Note: copyPatchesTo requires source item, handled during serialization
            -- Patches are part of visual data
        end
        if itemData.palette then
            item:setPalette(itemData.palette)
        end
        if itemData.spriteName then
            item:setSpriteName(itemData.spriteName)
        end
    end
    
    if instanceof(item, "Key") then
        if itemData.keyId then
            item:setKeyId(itemData.keyId)
        end
        if itemData.digitalPadlock ~= nil then
            item:setDigitalPadlock(itemData.digitalPadlock)
        end
        if itemData.padlock ~= nil then
            item:setPadlock(itemData.padlock)
        end
        if itemData.numberOfKey then
            item:setNumberOfKey(itemData.numberOfKey)
        end
    end
    
    if instanceof(item, "KeyRing") and itemData.keys then
        for _, keyData in ipairs(itemData.keys) do
            local key = WCL_Loadouts.restoreItem(keyData, container, player)
            if key then
                item:addKey(key)
                -- Remove the key from container since it's now in the keyring
                container:Remove(key)
            end
        end
    end
    
    -- ModData
    if itemData.modData then
        for k, v in pairs(itemData.modData) do
            item:getModData()[k] = v
        end
    end
    
    -- Restore container contents recursively
    if itemData.container and item:IsInventoryContainer() then
        local itemContainer = item:getInventory()
        if itemContainer then
            for _, containedItemData in ipairs(itemData.container) do
                WCL_Loadouts.restoreItem(containedItemData, itemContainer, player)
            end
        end
    end

    container:AddItem(item)

    return item
end

--- Reset player by removing all items, equipment, and attachments
--- @param player IsoPlayer The player to reset
--- @param trigger boolean Whether to trigger inventory change events (default: false)
--- @param options table Optional reset options
function WCL_Loadouts.resetPlayer(player, trigger, options)
    options = options or {}
    local removeItems = options.removeItems
    local restoreOutfit = options.restoreOutfit

    local inventory = player:getInventory()

    -- Clear hands
    player:setPrimaryHandItem(nil)
    player:setSecondaryHandItem(nil)

    local unequippedItems = {}
    
    -- Remove all attached items if restoring outfit
    if restoreOutfit then
        local attachedItems = player:getAttachedItems()
        for i = attachedItems:size() - 1, 0, -1 do
            local attached = attachedItems:get(i)
            local item = attached:getItem()
            player:removeAttachedItem(item)
            unequippedItems[item] = true
        end
    end

    -- Properly unequip all worn items
    if restoreOutfit then
        for i = player:getWornItems():size() - 1, 0, -1 do
            local item = player:getWornItems():get(i):getItem()
            player:removeWornItem(item)
            unequippedItems[item] = true
        end
    end

    -- Remove items from inventory if requested
    local items = inventory:getItems()
    for i = items:size() - 1, 0, -1 do
        local item = items:get(i)
        -- Preserve items flagged with WL_keepLoadout across loadout resets
        local md = item:getModData()
        local keep = md and md.WL_keepLoadout
        if (removeItems or (restoreOutfit and unequippedItems[item])) and not keep then
            inventory:Remove(item)
        end
    end

    if trigger then
        getPlayerInventory(player:getPlayerNum()):refreshBackpacks()
        ISInventoryPage.renderDirty = true
        triggerEvent("OnClothingUpdated", player)
        player:resetModel()
        sendVisual(player)
    end
end

--- Apply a loadout to a player with intelligent ordering
--- @param player IsoPlayer The player
--- @param loadout table The loadout data structure
--- @param options table Optional restore options (see DEFAULT_RESTORE_OPTIONS)
function WCL_Loadouts.applyInventory(player, loadout, options)
    if not loadout or not loadout.items then
        print("WCL_Loadouts: Invalid loadout data")
        return
    end
    
    -- Merge options with defaults
    options = options or {}
    for key, defaultValue in pairs(WCL_Loadouts.DEFAULT_RESTORE_OPTIONS) do
        if options[key] == nil then
            options[key] = defaultValue
        end
    end
    
    local inventory = player:getInventory()
    
    -- Phase 1: Reset player
    WCL_Loadouts.resetPlayer(player, false, options)
    
    -- Phase 2: Create all items in inventory
    local createdItems = {}
    for _, itemData in ipairs(loadout.items) do
        -- Restore this item if restoring items or if it's part of the outfit
        local isOutfitItem = itemData.equippedLocation or itemData.attachedSlot
        local restoreForItems = options.restoreItems and not isOutfitItem
        local restoreForOutfit = options.restoreOutfit and isOutfitItem

        if restoreForItems or restoreForOutfit then
            -- Map itemData to created item instances
            local items = {}
            for i = 1, (itemData.quantity or 1) do
                local item = WCL_Loadouts.restoreItem(itemData, inventory, player)
                if item then
                    table.insert(items, item)
                end
            end
            if #items > 0 then
                createdItems[itemData] = items
            end
        end
    end
    
    -- Phase 3: Equip clothing and containers (backpacks, etc.)
    if options.restoreOutfit then
        for _, itemData in ipairs(loadout.items) do
            if itemData.equippedLocation and createdItems[itemData] then
                local item = createdItems[itemData][1]  -- Use first instance
                if item then
                    -- Containers need to be removed from hands before equipping
                    if item:IsInventoryContainer() and item:canBeEquipped() ~= "" then
                        player:removeFromHands(item)
                        player:setWornItem(item:canBeEquipped(), item)
                    -- Regular clothing
                    elseif item:IsClothing() then
                        player:setWornItem(itemData.equippedLocation, item)
                        
                        -- Handle mohawk flattening for hats
                        if player:getHumanVisual():getHairModel():contains("Mohawk") and
                           (itemData.equippedLocation == "Hat" or itemData.equippedLocation == "FullHat") then
                            player:getHumanVisual():setHairModel("MohawkFlat")
                            player:resetModel()
                        end
                    end
                end
            end
        end
           
        -- Phase 4: Equip weapons in hands
        for _, itemData in ipairs(loadout.items) do
            if itemData.equippedPosition and createdItems[itemData] then
                local item = createdItems[itemData][1]  -- Use first instance
                if item then
                    if itemData.equippedPosition == "both" then
                        player:setPrimaryHandItem(item)
                        player:setSecondaryHandItem(item)
                    elseif itemData.equippedPosition == "primary" then
                        player:setPrimaryHandItem(item)
                    elseif itemData.equippedPosition == "secondary" then
                        player:setSecondaryHandItem(item)
                    end
                end
            end
        end
        
        -- Phase 5: Attach items (belts, back slots, makeup, etc.)
        for _, itemData in ipairs(loadout.items) do
            if itemData.attachedSlot and createdItems[itemData] then
                local item = createdItems[itemData][1]  -- Use first instance
                if item then
                    -- Set item's attached properties first
                    if itemData.attachedSlotIndex then
                        item:setAttachedSlot(itemData.attachedSlotIndex)
                    end
                    if itemData.attachedSlotType then
                        item:setAttachedSlotType(itemData.attachedSlotType)
                    end
                    if itemData.attachedToModel then
                        item:setAttachedToModel(itemData.attachedToModel)
                    end
                    
                    -- Then attach to the player
                    player:setAttachedItem(itemData.attachedSlot, item)
                end
            end
        end
    end
    
    -- Restore WRC name and color if available
    if options.restoreIdentity and loadout.wlrpchat and WRC and WRC.Meta then
        if loadout.wlrpchat.name then
            WRC.Meta.SetName(loadout.wlrpchat.name)
        end
        if loadout.wlrpchat.color then
            local color = loadout.wlrpchat.color
            WRC.Meta.SetNameColor(color.r, color.g, color.b)
        end
        if loadout.wlrpchat.status then
            WRC.Meta.SetStatus(loadout.wlrpchat.status)
        end
    end
    
    -- Restore hair style and color if available
    if options.restoreHair and loadout.hair then
        local humanVisual = player:getHumanVisual()
        if humanVisual then
            if loadout.hair.model then
                humanVisual:setHairModel(loadout.hair.model)
            end
            if loadout.hair.color then
                local hairColor = ImmutableColor.new(
                    loadout.hair.color.r,
                    loadout.hair.color.g,
                    loadout.hair.color.b,
                    1
                )
                humanVisual:setHairColor(hairColor)
            end
        end
    end
    
    -- Restore beard for male characters
    if options.restoreHair and loadout.beard and not player:isFemale() then
        local humanVisual = player:getHumanVisual()
        if humanVisual then
            if loadout.beard.model then
                humanVisual:setBeardModel(loadout.beard.model)
            end
            if loadout.beard.color then
                local beardColor = ImmutableColor.new(
                    loadout.beard.color.r,
                    loadout.beard.color.g,
                    loadout.beard.color.b,
                    1
                )
                humanVisual:setBeardColor(beardColor)
            end
        end
    end
    
    -- Restore WastelandDisguises characteristics if available
    if options.restoreCharacteristics and loadout.wastelandDisguises and hasWLDi and WLDi_System and WLDi_System.sendToServer then
        WLDi_System:sendToServer(player, "setCharacteristics", player:getUsername(), loadout.wastelandDisguises)
    end
    
    -- Force inventory UI to redraw (like ISUnequipAction does)
    getPlayerInventory(player:getPlayerNum()):refreshBackpacks()
    ISInventoryPage.renderDirty = true
    
    triggerEvent("OnClothingUpdated", player)
    sendVisual(player)
    player:resetModel()
end

-- ============================================================================
-- PUBLIC API (Backwards compatibility wrappers)
-- ============================================================================

--- Get a loadout by name
--- @param loadoutName string The loadout name
--- @return table|nil The loadout data
function WCL_Loadouts.getLoadout(loadoutName)
    if WCL_Loadouts.PlayerLoadouts[loadoutName] then
        return WCL_Loadouts.PlayerLoadouts[loadoutName]
    end
    return WCL_Loadouts.Loadouts[loadoutName]
end

--- Save a loadout
--- @param player IsoPlayer The player
--- @param name string The loadout name
--- @param loadout table The loadout data
function WCL_Loadouts.saveLoadout(player, name, loadout)
    if isClient() then
        sendClientCommand(player, "WastelandClothingLoadouts", "SaveLoadout", {name = name, loadout = loadout})
    else
        WCL_Loadouts.Loadouts[name] = loadout
    end
end

--- Save a player-specific loadout
--- @param player IsoPlayer The player
--- @param name string The loadout name
--- @param loadout table The loadout data
function WCL_Loadouts.savePlayerLoadout(player, name, loadout)
    if isClient() then
        sendClientCommand(player, "WastelandClothingLoadouts", "SavePlayerLoadout", {name = name, loadout = loadout})
    else
        WCL_Loadouts.PlayerLoadouts[name] = loadout
    end
end

--- Delete a loadout
--- @param player IsoPlayer The player
--- @param name string The loadout name
function WCL_Loadouts.deleteLoadout(player, name)
    if isClient() then
        sendClientCommand(player, "WastelandClothingLoadouts", "DeleteLoadout", {name = name})
    else
        WCL_Loadouts.Loadouts[name] = nil
    end
end

--- Delete a player-specific loadout
--- @param player IsoPlayer The player
--- @param name string The loadout name
function WCL_Loadouts.deletePlayerLoadout(player, name)
    if isClient() then
        sendClientCommand(player, "WastelandClothingLoadouts", "DeletePlayerLoadout", {name = name})
    else
        WCL_Loadouts.PlayerLoadouts[name] = nil
    end
end
