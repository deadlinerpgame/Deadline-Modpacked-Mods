if isClient() then return end
WLR_Auto = WLR_Auto or {}

--- @class WLR_Auto.Instance
--- @field definition WLR_Auto.Definition
--- @field range WLR_Auto.Range
--- @field stage string
--- @field parts table<number, WLR_Auto.Range>
--- @field stats table
WLR_Auto.Instance = WLR_Auto.Instance or WLBaseObject:derive("Instance")

--- @param definition WLR_Auto.Definition
--- @param range WLR_Auto.Range
--- @return WLR_Auto.Instance
function WLR_Auto.Instance:new(definition, range)
    local o = self:super()
    o.definition = definition
    o.range = range
    o.stats = {
        containersProcessed = 0,
        lockedContainers = 0
    }
    o:_init()
    return o
end

local function checkIsUnclaimed(vehicle)
    if WastelandAutoClaimsCore then
        return not WastelandAutoClaimsCore:isClaimed(vehicle)
    end
    if AVCS then
        local vehicleSQL = nil
        if type(vehicle) ~= "number" then
            vehicleSQL = AVCS.getVehicleID(vehicle)
        else
            vehicleSQL = vehicle
        end
        if vehicleSQL == nil then
            return true
        end
        if AVCS.dbByVehicleSQLID[vehicleSQL] == nil then
            return true
        end
        return false
    end
    return false
end

--- @param self WLR_Auto.Instance
--- @return boolean isDone
function WLR_Auto.Instance:run()
    if not self.parts[1] then
        -- All parts complete - log summary
        WLR_Auto.InfoLog(string.format(
            "Chunk respawn completed: %s | Zone: %s | Containers: %d | Locked: %d",
            tostring(self.range),
            self.definition.id,
            self.stats.containersProcessed,
            self.stats.lockedContainers
        ))
        return true
    end

    --- @type WLR_Auto.Range
    local part = table.remove(self.parts, 1)
    local containers, vehicles = self:_getContainersAndVehiclesInPart(part)
    if containers[1] then -- are containers to respawn
        local containerCompare = self.definition.containerChance * 100
        WLR_Auto.DebugLog("Respawning " .. #containers .. " containers in part: " .. tostring(part))
        for _, container in ipairs(containers) do
            if ZombRand(0, 100) <= containerCompare then
                self:_respawnContainer(container)
                self:_pruneContainer(container)
                self.stats.containersProcessed = self.stats.containersProcessed + 1
                local parent = container:getParent()
                if parent then
                    if parent:getModData().WLL_PadLockKeyId then
                        parent:getModData().WLL_PadLockKeyId = nil
                        parent:transmitModData()
                    end
                    ItemPicker.updateOverlaySprite(parent)
                    sendItemsInContainer(parent, container)
                    WLR_Auto.TraceLog("Respawned container at: " .. parent:getX() .. ", " .. parent:getY() .. ", " .. parent:getZ())
                end
            end
        end
        if getActivatedMods():contains("WastelandContainerLocks") and self.definition.chanceLocked > 0 then
            local anyLocked = false
            for _, container in ipairs(containers) do
                local parent = container:getParent()
                if parent and parent:getModData().WLL_PadLockKeyId then
                    anyLocked = true
                    break
                end
            end
            if not anyLocked then
                WLR_Auto.TraceLog("No locked containers found in part: " .. tostring(part))
                for _, container in ipairs(containers) do
                    if ZombRand(self.definition.chanceLocked) == 0 then
                        local parent = container:getParent()
                        if parent then
                            parent:getModData().WLL_PadLockKeyId = ZombRand(1, 2000000000)
                            self:_respawnLockedLoot(container)
                            self.stats.lockedContainers = self.stats.lockedContainers + 1
                            WLR_Auto.TraceLog("Created locked container at: " .. parent:getX() .. ", " .. parent:getY() .. ", " .. parent:getZ())
                            ItemPicker.updateOverlaySprite(parent)
                            sendItemsInContainer(parent, container)
                            parent:transmitModData()
                        else
                            WLR_Auto.TraceLog("Locked container missing parent object")
                        end
                    end
                end
            end
        end
    end

    -- Gas Respawn
    for _, vehicle in ipairs(vehicles) do
        for i=1,vehicle:getPartCount() do
            local vPart = vehicle:getPartByIndex(i-1)
            if not vehicle:isEngineStarted() and vPart:isContainer() and vPart:getContainerContentType() == "Gasoline" and vPart:getContainerContentAmount() <= 2 then
                if ZombRand(100) <= self.definition.gasFillChance then
                    local amount = ZombRand(self.definition.gasFillRange[1], self.definition.gasFillRange[2])
                    vPart:setContainerContentAmount(amount)
                    vehicle:transmitPartModData(vPart)
                    WLR_Auto.TraceLog("WLR_Auto.Instance:_stageRespawnNextPart() - Filled Gasoline: " .. tostring(vehicle:getX()) .. ", " .. tostring(vehicle:getY()) .. ", " .. tostring(vehicle:getZ()) .. " - " .. tostring(amount))
                end
            end
        end
    end

    return false
end

--- @param self WLR_Auto.Instance
function WLR_Auto.Instance:_init()
    self.parts = {}
    local partSize = 10
    for x = self.range.x1, self.range.x2, partSize do
        for y = self.range.y1, self.range.y2, partSize do
            table.insert(self.parts, WLR_Auto.Range:new(x, y, x + partSize - 1, y + partSize - 1))
        end
    end
    WLR_Auto.DebugLog("Initialized " .. #self.parts .. " parts for chunk: " .. tostring(self.range))
end

--- @param self WLR_Auto.Instance
--- @param part WLR_Auto.Range
--- @return table<number, IsoObject>, table<number, BaseVehicle>
function WLR_Auto.Instance:_getContainersAndVehiclesInPart(part)
    local containers = {}
    local vehicles = {}
    for x = part.x1, part.x2, 1 do
        for y = part.y1, part.y2, 1 do
            for z = 0, 7, 1 do
                local wasAnyInZ = false
                local square = getSquare(x, y, z)
                if square then
                    self:_getContainersInSquare(square, containers)
                    self:_getVehiclesInSquare(square, vehicles)
                    wasAnyInZ = true
                end
                if not wasAnyInZ then
                    break
                end
            end
        end
    end
    WLR_Auto.TraceLog("Found " .. #containers .. " containers and " .. #vehicles .. " vehicles in part")
    return containers, vehicles
end

--- @param self WLR_Auto.Instance
--- @param square IsoGridSquare
--- @param containers table<number, IsoObject>
function WLR_Auto.Instance:_getContainersInSquare(square, containers)
    if WWP_Server and WWP_Server.IsWorkplace(square:getX(), square:getY(), square:getZ()) then
        return
    end

    local isSafehouse = SafeHouse.getSafeHouse(square)
    if not isSafehouse and WSZ_System then
        isSafehouse = WSZ_System:isSafezoneAt(square:getX(), square:getY(), square:getZ())
    end

    if  square:getRoom() and
        square:getRoom():getRoomDef() and
        square:getRoom():getRoomDef():getProceduralSpawnedContainer() and
        not isSafehouse
    then
        local objects = square:getObjects()
        for j = 0, objects:size() - 1, 1 do
            local object = objects:get(j)
            local cnt = object:getContainerCount()-1
            for k=0, cnt do
                local container = object:getContainerByIndex(k)
                if container then
                    local isLocked = false
                    local parent = container:getParent()
                    if parent then
                        local modData = parent:getModData()
                        if modData.WLL_StaffLockedBy or modData.WLL_FrozenBy then
                            isLocked = true
                        end
                    end
                    if  not isLocked and
                        container:isExplored() and
                        container:getItems():size() < self.definition.itemCountToIgnore
                    then
                        table.insert(containers, container)
                    end
                end
            end
        end
    end
end

--- @param self WLR_Auto.Instance
--- @param square IsoGridSquare
--- @param containers table<number, BaseVehicle>
function WLR_Auto.Instance:_getVehiclesInSquare(square, containers)
    if WWP_Server and WWP_Server.IsWorkplace(square:getX(), square:getY(), square:getZ()) then
        return
    end

    local isSafehouse = SafeHouse.getSafeHouse(square)
    if not isSafehouse and WSZ_System then
        isSafehouse = WSZ_System:isSafezoneAt(square:getX(), square:getY(), square:getZ())
    end
    if isSafehouse then
        return
    end

    local movingObjects = square:getMovingObjects()
    for i = 0, movingObjects:size() - 1, 1 do
        local object = movingObjects:get(i)
        if instanceof(object, "BaseVehicle") then
            if checkIsUnclaimed(object) then
                table.insert(containers, object)
            end
        end
    end

    return containers
end

--- @param self WLR_Auto.Instance
--- @param container IsoObject
function WLR_Auto.Instance:_respawnContainer(container)
    container:getSourceGrid():getRoom():getRoomDef():getProceduralSpawnedContainer():clear()
    container:removeItemsFromProcessItems()
    container:clear()
    ItemPicker.fillContainer(container, nil)
    container:setExplored(true)
end

local itemsForLockedContainers = {
    {item = "Base.Bullets9mm", chance = 1000},
    {item = "Base.Bullets45", chance = 1000},
    {item = "Base.Bullets44", chance = 1000},
    {item = "Base.Bullets38", chance = 1000},
    {item = "Base.ShotgunShells", chance = 1000},
    {item = "Base.223Bullets", chance = 1000},
    {item = "Base.308Bullets", chance = 1000},
    {item = "Base.556Bullets", chance = 1000},
    {item = "Base.Bullets4440", chance = 1000},
    {item = "Base.Bullets357", chance = 1000},
    {item = "Base.Bullets3006", chance = 1000},

    {item = "Base.CBX_ANAT", chance = 100}, -- Assult Backpack
    {item = "Base.CBX_Ras_amry", chance = 200}, -- Bank Robber Chest Rig
    {item = "Base.BackSlingBackpack", chance = 200}, -- Black Backpack
    {item = "Base.CBX_Sumk_7_L", chance = 50}, -- Drop Leg Pouch
    {item = "Base.CBX_HR", chance = 200}, -- Field Backpack
    {item = "Base.CBX_RUKSAK2", chance = 200}, -- SPOSN Tortilla Pack

    {item = "AuthenticZClothing.Vest_BulletBlack", chance = 100}, -- Black Bulletproof Vest
    {item = "Base.Vest_BulletArmy_Urban", chance = 50}, -- Urban Camo Bulletproof Vest
    {item = "Base.Vest_BulletSwat", chance = 10}, -- Swat Vest
    {item = "Base.Hat_Army", chance = 60}, -- Military Helmet

    {item = "AuthenticZClothing.Hat_GasMask", chance = 20}, -- Gas Mask
    {item = "Base.Caution_GasMask", chance = 20}, -- Caution Gas Mask
    {item = "UndeadSurvivor.PrepperMask", chance = 20}, -- Prepper Mask
    {item = "Base.Hat_GasMask", chance = 20}, -- Gas Mask (Base)

    {item = "Base.22Silencer", chance = 10},
    {item = "Base.Katana", chance = 1},
    {item = "UndeadSurvivor.StalkerKnife", chance = 10},

    {item = "Base.GoldCurrencyTen", chance = 1000},
    {item = "Base.GoldCurrencyFifty", chance = 500},

    {item = "Base.PetrolCan", chance = 50}, -- Petrol Can

    -- Very small samples of drugs
    {item = "Base.MorphineVial", chance = 10},
    {item = "Base.MorphineSyringe", chance = 4},
    {item = "Base.AdrenalineVial", chance = 50},
    {item = "Base.AdrenalineSyringe", chance = 1},
    {item = "Base.SedativeVial", chance = 150},
    {item = "Base.SedativeSyringe", chance = 15},
    {item = "Base.OpioidsCureVial", chance = 25},
    {item = "Base.OpioidsCureSyringe", chance = 15},
    {item = "Base.MentholCreamPot", chance = 20},
    {item = "Base.BurnCreamTube", chance = 20},
    {item = "Base.PotassiumIodide", chance = 3},
    {item = "Base.PillsChloroquine", chance = 15},
    {item = "Base.PillsOxycodone", chance = 5},
    {item = "Base.PillsXanax", chance = 2},
    {item = "Base.CocaineBaggie", chance = 10},
    {item = "Base.CocaineBrick", chance = 1},
    {item = "Base.SpeedBaggie", chance = 10},
    {item = "Base.SpeedBox", chance = 1},
    {item = "Base.DrugsPipe", chance = 40},
    {item = "Base.CrackCocaine", chance = 2},
    {item = "Base.DrugsPipeCrack", chance = 10},
    {item = "Base.Methamphetamine", chance = 1},
    {item = "Base.DrugsPipeMeth", chance = 15},
    {item = "Base.BlackTarHeroin", chance = 1},
    {item = "Base.HeroinSpoon", chance = 20},
    {item = "Base.HeroinSyringe", chance = 20},
    {item = "Base.PillsFluCure", chance = 10},
    {item = "Base.PillsIvermectin", chance = 35},
    {item = "Base.No2CureVial", chance = 3},
    {item = "Base.CyanideCureVial", chance = 3},
    {item = "Base.SulfideCureVial", chance = 3},
}

if getActivatedMods():contains("WastelandHorse") then
    itemsForLockedContainers[#itemsForLockedContainers + 1] = {item = "Base.SaddleBags_Jumbo", chance = 100}
end

local function skewedTowardCenter(min, max, center, sharpness)
    -- sharpness = how strong the peak is around center (2~5 typical)
    local sum = 0
    local samples = sharpness

    for i = 1, samples do
        sum = sum + ZombRandFloat(0.0, 1.0)
    end

    local avg = sum / samples -- roughly bell-shaped in [0,1]

    -- Now map it to the range, centering around 'center'
    -- Shift the avg so that 0.5 aligns with your center
    local centerRatio = (center - min) / (max - min) -- 0..1 position of center

    local skewedRatio = avg

    -- You can optionally "nudge" the curve toward center by warping avg:
    if skewedRatio < centerRatio then
        skewedRatio = skewedRatio * centerRatio / 0.5
    else
        skewedRatio = centerRatio + (skewedRatio - 0.5) * (1 - centerRatio) / 0.5
    end

    local value = min + skewedRatio * (max + 1 - min)

    return math.floor(math.min(math.max(value, min), max))
end

-- function testSkewedRandom(l, t, c, s)
--     local results = {}
--     for i = 1, 1000 do
--         local value = skewedTowardCenter(l, t, c, s)
--         results[value] = (results[value] or 0) + 1
--     end
--     for x = l,t do
--         print(string.format("Value %d: %d occurrences", x, results[x] or 0))
--     end
-- end

function WLR_Auto.Instance:_respawnLockedLoot(container)
    container:getSourceGrid():getRoom():getRoomDef():getProceduralSpawnedContainer():clear()
    container:removeItemsFromProcessItems()
    container:clear()
    container:setExplored(true)
    for i = 1, skewedTowardCenter(1, 8, 3, 4) do
        local item = WL_Utils.weightedRandom(itemsForLockedContainers).item
        local inst = container:AddItem(item)
        if item == "Base.PetrolCan" then
            inst:setUsedDelta(ZombRand(10, 90) / 100)
        end
    end
end

--- @param self WLR_Auto.Instance
--- @param container IsoObject
function WLR_Auto.Instance:_pruneContainer(container)
    local toRemove = {}
    local items = container:getItems()
    local numItems = items:size()
    local fillCompare = self.definition.itemChance * 100
    if items and numItems > 0 then
        for i=0, numItems-1 do
            local item = items:get(i)
            if self.definition.ignoredCategories[item:getDisplayCategory()] or ZombRand(0, 100) > fillCompare then
                table.insert(toRemove, item)
            end
        end
    end
    for _, v in ipairs(items) do
        container:DoRemoveItem(v)
    end
end