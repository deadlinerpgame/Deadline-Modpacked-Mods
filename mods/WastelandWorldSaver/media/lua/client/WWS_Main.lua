WWS_Main = WWS_Main or {
    availablePickups = 0,
    takenItems = {},
    lastIssued = 0,
}

function WWS_Main.save()
    WL_UserData.Set("WastelandWorldSaver", {
        availablePickups = WWS_Main.availablePickups,
        takenItems = WWS_Main.takenItems,
        lastIssued = WWS_Main.lastIssued,
    },  getPlayer():getUsername(), true)
end

function WWS_Main.checkAdd()
    if WWS_Main.lastIssued == 0 then return end

    if SandboxVars.WastelandWorldSaver.TokensPerRegen and SandboxVars.WastelandWorldSaver.TokenRegenInterval then
        local hoursPassed = math.floor((getTimestamp() - WWS_Main.lastIssued) / 3600)
        if hoursPassed >= SandboxVars.WastelandWorldSaver.TokenRegenInterval then
            WWS_Main.availablePickups = math.min(WWS_Main.availablePickups + SandboxVars.WastelandWorldSaver.TokensPerRegen, SandboxVars.WastelandWorldSaver.InitialTokens)
            WWS_Main.lastIssued = getTimestamp()
            WWS_Main.save()
        end
    end
end

local function getTileSpriteKey(square, spriteName)
    return tostring(square:getX()) .. "," .. tostring(square:getY()) .. "," .. tostring(square:getZ()) .. "," .. tostring(spriteName)
end

local function isFreeItem(spriteName)
    return WWS_TileLists.Free[spriteName] or false
end

local function isProhibitedItem(spriteName)
    return WWS_TileLists.Prohibited[spriteName] or false
end

local function isNoPickupZone(x, y, z)
    local rules = WastelandZones and WastelandZones.Classes and WastelandZones.Classes.InteractionRules
    if rules and rules.getIsNoPickupZone and rules.getIsNoPickupZone(x, y, z) then
        return true
    end

    if WEZ_EventZone and WEZ_EventZone.getIsNoPickupZone and WEZ_EventZone.getIsNoPickupZone(x, y, z) then
        return true
    end

    return false
end

local function isScrapZone(x, y, z)
    local rules = WastelandZones and WastelandZones.Classes and WastelandZones.Classes.InteractionRules
    if rules and rules.getIsScrapZone and rules.getIsScrapZone(x, y, z) then
        return true
    end

    if WEZ_EventZone and WEZ_EventZone.getIsScrapZone and WEZ_EventZone.getIsScrapZone(x, y, z) then
        return true
    end

    return false
end

local function isOpenSquare(player, square, mode, spriteName)
    -- Check if the square is within a no pickup zone
    if isNoPickupZone(square:getX(), square:getY(), square:getZ()) then
        if not WL_Utils.isStaff(player) then
            HaloTextHelper.addText(player, "You cannot pick up objects in this area", HaloTextHelper.getColorRed());
            return false
        end
    end

    if mode == "place" or mode == "rotate" then return true end

    -- Check if the player has the movables cheat
    if player:isMovablesCheat() or ISMoveableDefinitions.cheat then
        return true
    end

    -- If we only care about map room, check if the square is not within a room
    if SandboxVars.WastelandWorldSaver.OnlyInRooms and not square:getRoom() then
        return true
    end

    -- Check if the square is within a safehouse
    local safehouse = SafeHouse.getSafeHouse(square)
    if safehouse then
        if safehouse:isOwner(player) or safehouse:playerAllowed(player) then
            return true
        end
    end

    -- Safezones
    if WSZ_Client then
        local safezones = WSZ_Client.getZonesAt(square:getX(), square:getY(), square:getZ()) or {}
        if #safezones > 0 then
            if WSZ_Client.currentPermissions.canMoveItems then
                return true
            end
        end
    end

    -- Check if the square is within a workplace
    local workplaces = WWP_WorkplaceZone and WWP_WorkplaceZone.getZonesAt(square:getX(), square:getY(), square:getZ()) or {}
    if #workplaces > 0 then
        return true
    end

    -- Check if the square is within a scrap zone
    if isScrapZone(square:getX(), square:getY(), square:getZ()) then
        return true
    end

    if isProhibitedItem(spriteName) then
        player:setHaloNote("Prohibited item.", 255, 0, 0, 5)
        return false
    end

    if isFreeItem(spriteName) then
        return true
    end

    -- Check not pickup mode or no more pickups available and show message
    if mode ~= "pickup" or WWS_Main.availablePickups <= 0 then
        player:setHaloNote("You can't do that here.", 255, 0, 0, 5)
        return false
    end

    -- Check already picked up
    local itemKey = getTileSpriteKey(square, spriteName)
    if WWS_Main.takenItems[itemKey] then
        player:setHaloNote("You already picked up this item.", 255, 0, 0, 5)
        return false
    end

    player:setHaloNote("You can pick up " .. tostring(WWS_Main.availablePickups) .. " more tiles.", 0, 255, 0, 5)
    return true
end

local function onPlayerReady()
    WWS_Main.original_ISMoveablesAction_isValid = WWS_Main.original_ISMoveablesAction_isValid or ISMoveablesAction.isValid
    WWS_Main.original_ISMoveableCursor_isValid = WWS_Main.original_ISMoveableCursor_isValid or ISMoveableCursor.isValid
    -- WWS_Main.original_ISDestroyCursor_isValid = WWS_Main.original_ISDestroyCursor_isValid or ISDestroyCursor.isValid

    function ISMoveablesAction:isValid()
        if not WWS_Main.original_ISMoveablesAction_isValid(self) then return false end
        return isOpenSquare(getPlayer(), self.square, self.mode, self.spriteName)
    end

    function ISMoveableCursor:isValid(square)
        if not WWS_Main.original_ISMoveableCursor_isValid(self, square) then return false end
        return isOpenSquare(getPlayer(), square, ISMoveableCursor.mode[self.player], self.origSpriteName)
    end

    -- function ISDestroyCursor:isValid(square)
    --     local playerObj = getPlayer()
    --     if WWS_Main.original_ISDestroyCursor_isValid(self, square) and isOpenSquare(playerObj, square) then
    --         return true
    --     else
    --         showCantDoThat(playerObj)
    --         return false
    --     end
    -- end

    WL_UserData.Listen("WastelandWorldSaver", function(data)
        WWS_Main.availablePickups = data.availablePickups or SandboxVars.WastelandWorldSaver.InitialTokens
        WWS_Main.takenItems = data.takenItems or {}
        WWS_Main.lastIssued = data.lastIssued and data.lastIssued > 0 and data.lastIssued or getTimestamp()
        WWS_Main.checkAdd()
    end)
    WL_UserData.Fetch("WastelandWorldSaver")
    Events.EveryHours.Add(WWS_Main.checkAdd)

    WL_PlayerReady.Remove(onPlayerReady)
end

WL_PlayerReady.Add(onPlayerReady)

function ISMoveableSpriteProps:pickUpMoveableInternal( _character, _square, _object, _sprInstance, _spriteName, _createItem, _rotating )
    --if _object and self:canPickUpMoveable( _character, _square, not _sprInstance and _object or nil ) then
    local objIsIsoWindow = self.type == "Window" and instanceof(_object,"IsoWindow")
    local item 	= self:instanceItem(_spriteName)

    if item or (objIsIsoWindow and _object:isDestroyed()) then      -- destroyed windows return nil for instanceItem()
        local windowGotSmashed = false
        if not objIsIsoWindow or not _object:isDestroyed() then     -- when its a destroyed window skip this
            if not _rotating and self:doBreakTest( _character ) then
                if self.type ~= "Window" then
                    self:playBreakSound( _character, _object )
                    self:addBreakDebris( _square )
                elseif objIsIsoWindow then
                    if not _object:isDestroyed() then               -- in case of a window, when it breaks and isnt broken yet smash it, leaves no debris.
                        _object:smashWindow()
                        windowGotSmashed = true
                    end
                end
            elseif item then
                if instanceof(_object, "IsoThumpable") then
                    item:getModData().name = _object:getName() or ""
                    item:getModData().health = _object:getHealth()
                    item:getModData().maxHealth = _object:getMaxHealth()
                    item:getModData().thumpSound = _object:getThumpSound()
                    item:getModData().color = _object:getCustomColor()
                    if _object:hasModData() then
                        item:getModData().modData = copyTable(_object:getModData())
                    end
                else
                    if _object:hasModData() and _object:getModData().movableData then
                        item:getModData().movableData = copyTable(_object:getModData().movableData)
                    end

                    if _object:hasModData() and _object:getModData().itemCondition then
                        item:setConditionMax(_object:getModData().itemCondition.max)
                        item:setCondition(_object:getModData().itemCondition.value)
                    end
                end
                if _createItem then
                    if self.isMultiSprite then
                        _square:AddWorldInventoryItem(item, ZombRandFloat(0.1,0.9), ZombRandFloat(0.1,0.9), 0)
                    else
                        _character:getInventory():AddItem(item)        -- add the item if it aint got broken
                    end
                end
            end
        end

        -- custom/modified light info (custom bulb, use battery etc) for the various lamps can by copied to movable item and retrieved uppon placing
        if instanceof(_object,"IsoLightSwitch") and _sprInstance==nil then
            _object:setCustomSettingsToItem(item)
            --item:getLightSettings(obj)
        end

        if instanceof(_object, "IsoMannequin") then
            _object:setCustomSettingsToItem(item)
        end

        -- Exit early if we're duplicating the item
        if not isOpenSquare(_character, _square, nil, _object:getSprite():getName()) then
            local itemKey = getTileSpriteKey(_object, _object:getSprite():getName())
            WWS_Main.takenItems[itemKey] = true
            WWS_Main.availablePickups = WWS_Main.availablePickups - 1
            WWS_Main.save()
            return item
        end

        -- Remove stuff from the world
        if self.type == "WallOverlay" then
            -- A Mirror on the east or south edge of a square.
            if _object:getSprite() and _spriteName and (_object:getSprite():getName() == _spriteName) then
                triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
                _square:transmitRemoveItemFromSquare(_object)
            elseif _sprInstance then
                local sprList = _object:getChildSprites()
                local sprIndex = sprList and sprList:indexOf(_sprInstance) or -1
                if sprIndex == -1 then
                else
                    _object:RemoveAttachedAnim(sprIndex)
                    if isClient() then _object:transmitUpdatedSpriteToServer() end
                end
            end
        elseif self.type == "FloorTile" then
            local floor = _square:getFloor()
            local moveableDefinitions = ISMoveableDefinitions:getInstance()
            if moveableDefinitions and moveableDefinitions.floorReplaceSprites then
                local repSprs = moveableDefinitions.floorReplaceSprites
                local floor = _square:getFloor()
                local spr = getSprite( repSprs[ ZombRand(1,#repSprs) ] )
                if floor and spr then
                    floor:setSprite(spr)
                    if isClient() then floor:transmitUpdatedSpriteToServer() end --:transmitCompleteItemToServer() end
                end
            end
        elseif self.isoType == "IsoBrokenGlass" then
            -- add random damage to hands if no gloves
            if not _character:getClothingItem_Hands() and ZombRand(3) == 0 then
                local handPart = _character:getBodyDamage():getBodyPart(BodyPartType.FromIndex(ZombRand(BodyPartType.ToIndex(BodyPartType.Hand_L),BodyPartType.ToIndex(BodyPartType.Hand_R) + 1)))
                handPart:setScratched(true, true)
                -- possible glass in hands
                if ZombRand(5) == 0 then
                    handPart:setHaveGlass(true)
                end
            end
            triggerEvent("OnObjectAboutToBeRemoved", _object)
            _square:transmitRemoveItemFromSquare(_object)
        elseif self.type == "Window" then
            if objIsIsoWindow and not windowGotSmashed then
                if isClient() then _square:transmitRemoveItemFromSquare(_object) end
                _square:RemoveTileObject(_object)
            end
        elseif not _sprInstance then --Objects, Vegitation, WallObjects etc
            if self.isoType == "IsoRadio" or self.isoType == "IsoTelevision" then
                if instanceof(_object,"IsoWaveSignal") then
                    local deviceData = _object:getDeviceData()
                    if deviceData then
                        item:setDeviceData(deviceData)
                    else
                        print("Warning: device data missing?>?")
                    end
                end
            end
            if self.spriteProps and not self.spriteProps:Is(IsoFlagType.waterPiped) then
                --print("water check")
                if _object:hasModData() then
                    --print("water check mod data")
                    if _object:getModData().waterAmount then
                        item:getModData().waterAmount = _object:getModData().waterAmount
                        item:getModData().taintedWater = _object:isTaintedWater()
                    end
                else
                    --print("water check no mod")
                    local waterAmount = tonumber(_object:getWaterAmount())
                    if waterAmount then
                        item:getModData().waterAmount = waterAmount
                        item:getModData().taintedWater = _object:isTaintedWater()
                end
                end
                --print("ITEM WATER AMOUNT = "..tostring(item:getModData().waterAmount))
            end
            triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
            _square:transmitRemoveItemFromSquare(_object)
        end
        _square:RecalcProperties()
        _square:RecalcAllWithNeighbours(true)

        --ISMoveableCursor.clearCacheForAllPlayers()

        triggerEvent("OnContainerUpdate")

        IsoGenerator.updateGenerator(_square)
        return item
    end
    --end
end
