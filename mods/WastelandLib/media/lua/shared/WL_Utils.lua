---
--- WL_Utils.lua
---
--- Utility functions for Wasteland RP
---
--- 17/10/2023
---

WL_Utils = WL_Utils or {}
WL_Utils.MagicSpace = "� �� "

--- Checks to see if a table is empty and returns true if so. Also returns true if the table is nil.
--- @param table table to check, can be nil
function WL_Utils.isEmpty(table)
    if table == nil then return true end
    for _, _ in pairs(table) do
        return false
    end
    return true
end

--- Uses DoParam to set the properties of an item.
--- WARNING: This often seems to only affect newly created instances and not existing ones.
--- @param itemID string class id of the item e.g. Base.Pistol
--- @param propertiesTable table of props, e.g. { ["MinDamage"] = 0.45, ["MaxDamage"] = 1.65 }
function WL_Utils.setItemProperties(itemID, propertiesTable)
    local item = ScriptManager.instance:getItem(itemID)
    if not item then
        print("ERROR: Item not found to modify: " .. itemID)
        return
    end

    for key, value in pairs(propertiesTable) do
        item:DoParam(key .." = " .. tostring(value))
    end
end

---@param userName string can be nil (you just get nil back then)
---@return IsoPlayer|nil player found or nil if cannot be found
function WL_Utils.findPlayerFromUsername(userName)
    if not userName then return nil end
    local players = getOnlinePlayers()
    if not players then  -- Cope for single player gracefully
        local localPlayer = getPlayer()
        return localPlayer:getUsername() == userName and localPlayer or nil
    end
    for playerIndex = 0, players:size() -1 do
        local player = players:get(playerIndex)
        if player:getUsername() == userName then
            return player
        end
    end
    return nil
end

---@param userName string can be nil (you just get nil back then)
---@return string the name of the player from wasteland RP chat if the mod is running, otherwise the userName
function WL_Utils.getRolePlayChatName(userName)
    if not userName then return nil end
    if WRC and WRC.Meta then
        return WRC.Meta.GetName(userName)
    else
        return userName
    end
end

local afterTpData = nil

--- Teleports a player to a given location
--- If the player is in a vehicle, it will be stopped and the player will be ejected
--- May need to be called multiple times, as the player may be in a moving vehicle
--- @param player IsoPlayer
--- @param x number
--- @param y number
--- @param z number
--- @param afterTp function|nil called after the teleport is complete
--- @return boolean True if the player was teleported, false if they were in a moving vehicle
function WL_Utils.teleportPlayerToCoords(player, x, y, z, afterTp)
    local vehicle = player:getVehicle()
    if vehicle then
        if vehicle:getDriver() == player and vehicle:getSpeed2D() > 0 then
            vehicle:setForceBrake()
            return false
        end
        vehicle:exit(player)
    end

    if x - math.ceil(x) == 0 and y - math.ceil(y) == 0 then
        x = x + 0.5
        y = y + 0.5
    end

    player:setX(x)
    player:setY(y)
    player:setZ(z)
    player:setLx(x)
    player:setLy(y)
    player:setLz(z)

    if WLHorse then
        if WLHorse.isOnHorse(player) then
            WLHorse.resetPosition()
        end
    end

    if afterTp then
        afterTpData = {
            player = player,
            afterTp = afterTp,
            x = x,
            y = y,
            z = z,
            delay = 20,
        }
        Events.OnTick.Add(WL_Utils.afterTpCheck)
    end

    return true
end

function WL_Utils.afterTpCheck()
    if not afterTpData then
        Events.OnTick.Remove(WL_Utils.afterTpCheck)
        return
    end

    local square = getCell():getGridSquare(afterTpData.x, afterTpData.y, afterTpData.z)
    if not square then
        return
    end

    if afterTpData.player:getCurrentSquare() == square then
        afterTpData.delay = afterTpData.delay - 1
        if afterTpData.delay > 0 then
            return
        end
        Events.OnTick.Remove(WL_Utils.afterTpCheck)
        afterTpData.afterTp()
        afterTpData = nil
    end
end

--- Returns true if the player is a moderator or admin
--- @param player IsoPlayer|nil will use getPlayer() if nil
--- @return boolean
function WL_Utils.canModerate(player)
    if not isClient() and not isServer() then return true end -- SP
    if not player then player = getPlayer() end
    local accessLevel = player:getAccessLevel()
    return accessLevel == "Moderator" or accessLevel == "Admin"
end

--- Returns true if the player has any staff access level (Admin, Moderator, Overseer, GM or Observer)
--- @param player IsoPlayer
--- @return boolean
function WL_Utils.isStaff(player)
    if not isClient() and not isServer() then return true end -- SP
    if not player then return false end
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None"
end

--- Returns true if the player has GM level or higher (Admin, Moderator, Overseer or GM)
--- @param player IsoPlayer
--- @return boolean
function WL_Utils.isAtLeastGM(player)
    if not isClient() and not isServer() then return true end -- SP
    if not player then return false end
    local accessLevel = player:getAccessLevel()
    return accessLevel ~= "None" and accessLevel ~= "Observer"
end

--- Expensive function to determine the distance between two X,Y coordinates.
--- Do not use this to check if you are within a certain distance, for that purpose just compare the squared products
function WL_Utils.distance2d(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

local function prettyPrintTable(tbl, indent, seen)
    indent = indent or 0
    seen = seen or {}

    if seen[tbl] then
        return "{<self-reference>}"
    end
    seen[tbl] = true

    local toprint = "{\n"
    local indentString = string.rep("  ", indent + 1)

    for k, v in pairs(tbl) do
        toprint = toprint .. indentString .. "[" .. tostring(k) .. "] = "
        if type(v) == "table" then
            toprint = toprint .. prettyPrintTable(v, indent + 1, seen)
        else
            toprint = toprint .. tostring(v)
        end
        toprint = toprint .. ",\n"
    end

    seen[tbl] = nil
    return toprint .. string.rep("  ", indent) .. "}"
end

--- Function to convert a table to a string for debugging
function WL_Utils.tableToString(tbl)
    if not tbl then
        return "nil"
    end

    return prettyPrintTable(tbl)
end

function WL_Utils.toHumanReadableTime(milliseconds, options)
    options = options or {}
    local totalMinutes = milliseconds / 60000
    local days = math.floor(totalMinutes / 1440)  -- 1440 minutes in a day
    local hours = math.floor((totalMinutes % 1440) / 60)
    local minutes = math.floor(totalMinutes % 60)
    local seconds = math.floor((milliseconds / 1000) % 60)

    local parts = {}
    if days > 0 then
        table.insert(parts, string.format("%d Days", days))
    end
    if not (options.hideHours or false) and hours > 0 then
        table.insert(parts, string.format("%d Hours", hours))
    end
    if not (options.hideMinutes or false) and minutes > 0 then
        table.insert(parts, string.format("%d Minutes", minutes))
    end
    if not (options.hideSeconds or false) and (seconds > 0) then
        table.insert(parts, string.format("%d Seconds", seconds))
    end

    if #parts == 0 then -- Fallback if days = 0 and others are hidden
        return "Recently"
    end

    return table.concat(parts, " ") .. (options.suffix or "")
end

--- Clones an InventoryItem
--- @param item InventoryItem the item to be cloned
--- @return InventoryItem|nil the cloned item
function WL_Utils.cloneItem(item)
    if not item then return end
    local newItem = InventoryItemFactory.CreateItem(item:getFullType())
    if not newItem then return end

    newItem:setAge(item:getAge())
    newItem:setCondition(item:getCondition(), false)
    local vis = item:getVisual()
    if vis then
        newItem:getVisual():copyFrom(vis)
        newItem:synchWithVisual()
    end
    newItem:setBroken(item:isBroken())
    newItem:setCustomColor(item:isCustomColor())
    newItem:setColor(item:getColor())

    newItem:setName(item:getName())
    newItem:setCustomName(item:isCustomName())

    newItem:setCustomWeight(item:isCustomWeight())
    newItem:setActualWeight(item:getActualWeight())

    newItem:setCooked(item:isCooked())
    if item:isCooked() then
        newItem:setCookedString(item:getCookedString())
    end

    newItem:setBurnt(item:isBurnt())
    if item:isBurnt() then
        newItem:setBurntString(item:getBurntString())
    end

    if item:hasModData() then
        newItem:copyModData(item:getModData())
    end

    if item:isRecordedMedia() then
        newItem:setMediaType(item:getMediaType())
        newItem:setRecordedMediaData(item:getMediaData())
    end

    if instanceof(item, "Literature") then
        newItem:setCanBeWrite(item:canBeWrite())
        newItem:setLockedBy(item:getLockedBy())
        newItem:setCustomPages(item:getCustomPages())
    end

    if instanceof(item, "Clothing") then
        item:copyPatchesTo(newItem)
        newItem:setPalette(item:getPalette())
        newItem:setSpriteName(item:getSpriteName())
    end

    if instanceof(item, "DrainableComboItem") then
        newItem:setUsedDelta(item:getUsedDelta())
        newItem:updateWeight()
    end

    if instanceof(item, "Food") then
        newItem:setCalories(item:getCalories())
        newItem:setCarbohydrates(item:getCarbohydrates())
        newItem:setProteins(item:getProteins())
        newItem:setLipids(item:getLipids())
        newItem:setWeight(item:getWeight())
        newItem:setHungChange(item:getHungChange())
        newItem:setUnhappyChange(item:getUnhappyChange())
        newItem:setBoredomChange(item:getBoredomChange())
        newItem:setStressChange(item:getStressChange())
        newItem:setEnduranceChange(item:getEnduranceChange())
        newItem:setPainReduction(item:getPainReduction())
        newItem:setThirstChange(item:getThirstChange())
        newItem:setCookedInMicrowave(item:isCookedInMicrowave())
        newItem:setSpices(item:getSpices())
    end

    if instanceof(item, "HandWeapon") then
        local parts = item:getAllWeaponParts()
        for i=0,parts:size()-1 do
            local newPart = WL_Utils.cloneItem(parts:get(i))
            if newPart then
                newItem:attachWeaponPart(newPart)
            end
        end
        if item:isContainsClip() then
            newItem:setContainsClip(item:isContainsClip())
            newItem:setCurrentAmmoCount(item:getCurrentAmmoCount())
        end
        if item:haveChamber() then
            newItem:setRoundChambered(item:isRoundChambered())
        end
        newItem:setMinDamage(item:getMinDamage())
        newItem:setMaxDamage(item:getMaxDamage())
        newItem:setMinAngle(item:getMinAngle())
        if newItem:isRanged() then
            newItem:setMinRangeRanged(item:getMinRangeRanged())
        else
            newItem:setMinRange(item:getMinRange())
        end
        newItem:setMaxRange(item:getMaxRange())
        newItem:setAimingTime(item:getAimingTime())
        newItem:setRecoilDelay(item:getRecoilDelay())
        newItem:setReloadTime(item:getReloadTime())
        newItem:setClipSize(item:getClipSize())
    end

    if instanceof(item, "Key") then
        newItem:setKeyId(item:getKeyId())
        newItem:setDigitalPadlock(item:isDigitalPadlock())
        newItem:setPadlock(item:isPadlock())
        newItem:setNumberOfKey(item:getNumberOfKey())
    end

    if instanceof(item, "KeyRing") then
        local keys = item:getKeys()
        for i=0,keys:size()-1 do
            local newKey = WL_Utils.cloneItem(keys:get(i))
            if newKey then
                newItem:addKey(newKey)
            end
        end
    end

    if item:IsInventoryContainer() then
        local items = item:getInventory():getItems()
        for i=0,items:size()-1 do
            local newItem2 = WL_Utils.cloneItem(items:get(i))
            if newItem2 then
                newItem:getInventory():AddItem(newItem2)
            end
        end
    end

    return newItem
end

--- @class WeightedObject
--- @field chance number

-- function to take in a table of objects and pick one at random
-- based on the the weight of each object.
--- @param objects WeightedObject[] The objects to choose from
--- @return WeightedObject
function WL_Utils.weightedRandom(objects, field)
    if not field then field = "chance" end
    local totalWeight = 0
    for _, object in ipairs(objects) do
        totalWeight = totalWeight + object[field]
    end
    local random = ZombRand(totalWeight)
    local currentWeight = 0
    for _, object in ipairs(objects) do
        currentWeight = currentWeight + object[field]
        if random < currentWeight then
            return object
        end
    end
    return objects[#objects]
end

WL_Utils.PossibleTrees = {
    "American Holly",
    "Canadian Hemlock",
    "Virginia Pine",
    "Riverbirch",
    "Cockspur Hawthorn",
    "Dogwood",
    "Carolina Silverbell",
    "Yellowwood",
    "Eastern Redbud",
    "Redmaple",
    "American Linden",
}
--- Spawns a tree at the given square
--- @param square IsoGridSquare
--- @param tree string|nil the tree to spawn, if nil a random tree will be chosen
--- @param stage number|nil the stage of the tree to spawn, if nil a random stage will be chosen
function WL_Utils.SpawnTree(square, tree, stage)
    tree = tree or WL_Utils.PossibleTrees[ZombRand(#WL_Utils.PossibleTrees) + 1]
    stage = stage or ZombRand(6)
    if isClient() then
        sendClientCommand(getPlayer(), "WL_Utils", "SpawnTree", {
            squareX = square:getX(),
            squareY = square:getY(),
            squareZ = square:getZ(),
            tree = tree,
            stage = stage
        })
    else
        if spawnTree(square, tree, stage) then
            print("Spawned stage " .. stage .. " " .. tree .. " at " .. square:getX() .. "," .. square:getY() .. "," .. square:getZ())
        else
            print("Failed to spawn " .. tree .. " at " .. square:getX() .. "," .. square:getY() .. "," .. square:getZ())
        end
    end
end

function WL_Utils.GrowTree(square)
    if isClient() then
        sendClientCommand(getPlayer(), "WL_Utils", "GrowTree", {
            squareX = square:getX(),
            squareY = square:getY(),
            squareZ = square:getZ()
        })
    else
        if growTree(square) then
            print("Grew tree at " .. square:getX() .. "," .. square:getY() .. "," .. square:getZ())
        else
            print("Failed to grow tree at " .. square:getX() .. "," .. square:getY() .. "," .. square:getZ())
        end
    end
end

function WL_Utils.clearCorpses(x1, y1, z1, x2, y2, z2)
    local cell = getCell()
    for x = x1,x2 do for y = y1,y2 do for z = z1,z2 do
        local sq = cell:getGridSquare(x, y, z)
        if sq then
            local bodies = {}
            for i=0, sq:getStaticMovingObjects():size()-1 do
                if instanceof(sq:getStaticMovingObjects():get(i), "IsoDeadBody") then
                    table.insert(bodies, sq:getStaticMovingObjects():get(i))
                end
            end
            for i, body in ipairs(bodies) do
                sq:removeCorpse(body, false)
            end
        end
    end end end
end

function WL_Utils.removeBlood(x1, y1, z1, x2, y2, z2)
    local cell = getCell()
    for x = x1,x2 do for y = y1,y2 do for z = z1,z2 do
        local sq = cell:getGridSquare(x, y, z)
        if sq and sq:haveBlood() then
            sq:removeBlood(false, false)
        end
    end end end
end

--- Writes a line to a server log from either server or client context.
--- @param logName string The log category/file name used by writeLog.
--- @param message string The message to write.
function WL_Utils.writeLog(logName, message)
    if isClient() then
        sendClientCommand(getPlayer(), "WL_Utils", "WriteLog", {
            logName = logName,
            message = message,
        })
        return
    end

    writeLog(tostring(logName), tostring(message))
end

function WL_Utils.setGamedate(year, month, day)
    if isClient() then
        sendClientCommand(getPlayer(), "WL_Utils", "setGamedate", {
            year = year,
            month = month,
            day = day,
        })
        return
    end
    local gameTime = getGameTime()
    gameTime:setYear(year)
    gameTime:setMonth(month)
    gameTime:setDay(day)
    sendServerCommand("WL_Utils", "applyGamedate", {
        year = year,
        month = month,
        day = day,
    })
end

function WL_Utils.applyGamedate(year, month, day)
    local gameTime = getGameTime()
    gameTime:setYear(year)
    gameTime:setMonth(month)
    gameTime:setDay(day)
end

if not isClient() then
    function WL_Utils.getTimestamp()
        return getTimestamp()
    end
    function WL_Utils.getTimestampMs()
        return getTimestampMs()
    end
else
    local drift = 0
    function WL_Utils.getTimestamp()
        return math.floor((getTimestampMs() + drift) / 1000)
    end
    function WL_Utils.getTimestampMs()
        return getTimestampMs() + drift
    end
    function WL_Utils.setDrift(mySendTs, serverTs)
        local myCurrentTs = getTimestampMs()
        local halfRoundTripTime = (myCurrentTs - mySendTs)/2
        drift = serverTs - (mySendTs + halfRoundTripTime)
        print("Timestamp Drift: " .. tostring(drift) .. "ms")
    end
    
    Events.OnGameBoot.Add(function()
        WL_PlayerReady.Add(function()
            local myTs = getTimestampMs()
            sendClientCommand(getPlayer(), "WL_Utils", "SyncTimestamp", {myTs})
        end)
    end)
end

if isServer() then
    Events.OnClientCommand.Add(function(module, command, player, args)
        if module ~= "WL_Utils" then return end

        if command == "SpawnTree" then
            local square = getCell():getGridSquare(args.squareX, args.squareY, args.squareZ)
            if square then
                WL_Utils.SpawnTree(square, args.tree, args.stage)
            end
        elseif command == "GrowTree" then
            local square = getCell():getGridSquare(args.squareX, args.squareY, args.squareZ)
            if square then
                WL_Utils.GrowTree(square)
            end
        elseif command == "clearCorpse" then
            WL_Utils.clearCorpses(args.x1, args.y1, args.z1, args.x2, args.y2, args.z2)
        elseif command == "removeBlood" then
            WL_Utils.removeBlood(args.x1, args.y1, args.z1, args.x2, args.y2, args.z2)
        elseif command == "SyncTimestamp" then
            sendServerCommand(player, "WL_Utils", "setDrift", {args[1], getTimestampMs()})
        elseif command == "setGamedate" then
            WL_Utils.setGamedate(args.year, args.month, args.day)
        elseif command == "WriteLog" then
            WL_Utils.writeLog(args.logName, args.message)
        end
    end)
end

if isClient() then
    Events.OnServerCommand.Add(function(module, command, args)
        if module ~= "WL_Utils" then return end

        if command == "setDrift" then
            WL_Utils.setDrift(args[1], args[2])
        end
        if command == "applyGamedate" then
            WL_Utils.applyGamedate(args.year, args.month, args.day)
        end
    end)
end
