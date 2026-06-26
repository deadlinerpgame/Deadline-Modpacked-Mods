---
--- WL_Utils.lua
---
--- Utility functions for Wasteland RP
---
--- 17/10/2023
---

-- quick fix for ISFastTeleportMove breaking Z sometimes

local original_ISFastTeleportMove_moveZ = ISFastTeleportMove.moveZ
ISFastTeleportMove.moveZ = function(self, z)
    original_ISFastTeleportMove_moveZ(self, z)
    ISFastTeleportMove.currentZ = math.max(0, math.floor(ISFastTeleportMove.currentZ))
end

WL_Utils = WL_Utils or {}
WL_Utils_Privates = WL_Utils_Privates or {}

-- Global logging configuration
-- TO ENABLE DEBUG LOGGING: Set WL_DEBUG_LOGGING = true in the console or modify this line
WL_DEBUG_LOGGING = false -- Set to true to enable debug logging

-- Logging function
-- Usage: WL_Utils.log("Your message here", "CATEGORY")
-- Categories help organize log output (e.g., "COOLER_ICE", "COOLER_FOOD", etc.)
function WL_Utils.log(message, category)
    if not WL_DEBUG_LOGGING then
        return
    end

    local timestamp = os.date("%H:%M:%S")
    local logCategory = category or "DEBUG"
    local logMessage = string.format("[%s][%s] %s", timestamp, logCategory, tostring(message))
    print(logMessage)
end

-- Throttled logging for high-frequency functions
-- This prevents spam from functions that are called very frequently (like update loops)
-- Usage: WL_Utils.logThrottled("Message", "CATEGORY", "unique_key", 100)
-- Will only show the message every 100 calls to prevent console spam
WL_Utils.logThrottleCounters = {}

function WL_Utils.logThrottled(message, category, throttleKey, maxCount)
    if not WL_DEBUG_LOGGING then
        return
    end

    throttleKey = throttleKey or "default"
    maxCount = maxCount or 100

    WL_Utils.logThrottleCounters[throttleKey] = (WL_Utils.logThrottleCounters[throttleKey] or 0) + 1

    if WL_Utils.logThrottleCounters[throttleKey] >= maxCount then
        WL_Utils.log(message .. " (throttled - shown every " .. maxCount .. " calls)", category)
        WL_Utils.logThrottleCounters[throttleKey] = 0
    end
end

--- Add a WL_FakeMessage to the chat window
--- @param message WL_FakeMessage
function WL_Utils.addFakeMessageToChatWindow(message)
    if not ISChat or not ISChat.instance or not ISChat.instance.chatText then return end
    local line = message:getTextWithPrefix()
    local chatText = ISChat.instance.chatText
    if message:getChatID() then
        for _,v in ipairs(ISChat.instance.tabs) do
            if v.tabID == message:getChatID() then
                chatText = v
                break
            end
        end
    end
    if chatText.tabTitle ~= ISChat.instance.chatText.tabTitle then
        local alreadyExist = false;
        for i,blinkedTab in ipairs(ISChat.instance.panel.blinkTabs) do
            if blinkedTab == chatText.tabTitle then
                alreadyExist = true;
                break;
            end
        end
        if alreadyExist == false then
            table.insert(ISChat.instance.panel.blinkTabs, chatText.tabTitle);
        end
    end
    local vscroll = chatText.vscroll
    local scrolledToBottom = (chatText:getScrollHeight() <= chatText:getHeight()) or (vscroll and vscroll.pos == 1)
    if #chatText.chatTextLines > ISChat.maxLine then
        local newLines = {}
        for i,v in ipairs(chatText.chatTextLines) do
            if i ~= 1 then
                table.insert(newLines, v)
            end
        end
        table.insert(newLines, line .. " <LINE> ")
        chatText.chatTextLines = newLines
    else
        table.insert(chatText.chatTextLines, line .. " <LINE> ")
    end
    chatText.text = ""
    local newText = ""
    for i,v in ipairs(chatText.chatTextLines) do
        if i == #chatText.chatTextLines then
            v = string.gsub(v, " <LINE> $", "")
        end
        newText = newText .. v
    end
    chatText.text = newText
    table.insert(chatText.chatMessages, message)
    chatText:paginate()
    if scrolledToBottom then
        chatText:setYScroll(-100000)
    end
end

--- Add a message to the chat window
--- @param text string
--- @param options WL_ChatOptions|nil
function WL_Utils.addToChat(text, options)
    local message = WL_FakeMessage:new(text, options)
    WL_Utils.addFakeMessageToChatWindow(message)
end

--- Add a message to the chat window with a red color
--- @param text string
--- @param options WL_ChatOptions|nil
function WL_Utils.addErrorToChat(text, options)
    options = options or {}
    options.color = "1.0,0.4,0.4"
    WL_Utils.addToChat(text, options)
end

--- Add a message to the chat window with a blue color
--- @param text string
--- @param options WL_ChatOptions|nil
function WL_Utils.addInfoToChat(text, options)
    options = options or {}
    options.color = "0.4,0.4,1.0"
    WL_Utils.addToChat(text, options)
end

local function filterPlayer(player, distanceSq, maxDistSq, excludeSelf, excludeUsernames, zRange, onlyInLOS)
    local localPlayer = getPlayer()
    if excludeSelf and player == localPlayer then return false end   -- Don't list yourself
    if player:isGhostMode() then return false end  -- Don't show ghost-mode staff
    if onlyInLOS and not localPlayer:CanSee(player) then return false end -- If LOS only, check if we can see them
    if excludeUsernames[player:getUsername()] then return false end -- If excluded, don't show
    if zRange and math.abs(math.floor(player:getZ()) - math.floor(localPlayer:getZ())) > zRange then return false end
    if maxDistSq and distanceSq > maxDistSq then return false end
    return true
end

--TODO make the param sorting type using an enum or nil as options

---@class findPlayersConfig
---@field maxDistance number maximum distance to search for players
---@field excludeSelf? boolean if true, the local player will not be included in the results
---@field zRange? number if set, the search will only include players within this many Z levels of the local player.
---@field onlyInLOS? boolean if true, only players that are visible to the local player will be included
---@field staffOverride? boolean if true, all players will be included regardless of distance or visibility. But only if
---@field excludeUsernames? table a dictionary/table of usernames to exclude from the results e.g. { ["Player1"] = true }
---@field alphabeticalSort? boolean if true, the results will be sorted alphabetically by rp name instead of closest first
---@return table found players, entries contain the fields: player, username, rpName, distanceSq

---@param findPlayersConfig findPlayersConfig|nil
---@return table players found, entries contain the fields: player, username, rpName, distanceSq
function WL_Utils.findPlayers(findPlayersConfig)
    if not findPlayersConfig then findPlayersConfig = {} end
    local localPlayer = getPlayer()
    local maxDistSq = findPlayersConfig.maxDistance and (findPlayersConfig.maxDistance * findPlayersConfig.maxDistance) or nil
    local excludeSelf = findPlayersConfig.excludeSelf or false
    local zRange = findPlayersConfig.zRange or nil
    local onlyInLOS = findPlayersConfig.onlyInLOS or false
    local includeEveryone = findPlayersConfig.staffOverride and WL_Utils.isStaff(localPlayer)
    local excludeUsernames = findPlayersConfig.excludeUsernames or {}
    local alphabeticalSort = findPlayersConfig.alphabeticalSort or false

    local players = getOnlinePlayers()
    if not players then -- Single Player graceful failure
        players = ArrayList.new()
    end

    local playersFound = {}
    for playerIndex = 0, players:size() -1 do
        local player = players:get(playerIndex)
        local distanceSq = localPlayer:getDistanceSq(player)
        if includeEveryone
                or filterPlayer(player, distanceSq, maxDistSq, excludeSelf, excludeUsernames, zRange, onlyInLOS) then
            table.insert(playersFound, {
                player = player,
                username = player:getUsername(),
                rpName = WL_Utils.getRolePlayChatName(player:getUsername()),
                distanceSq = distanceSq
            })
        end
    end

    if alphabeticalSort then
        table.sort(playersFound, function(a, b) return a.rpName < b.rpName end)
    else
        table.sort(playersFound, function(a, b) return a.distanceSq < b.distanceSq end)
    end

    return playersFound
end

--- Local utility function to write chat messages for item spawning
--- @return string the translated name of the item that was added or nil if no such item existed
local function addItemGainedMessage(itemID, newItem, quantity)
    if not newItem then
        WL_Utils.addToChat("ERROR item not found: " .. itemID, { color = "1.0,0,0", })
        return nil
    end

    local numberString
    if quantity and quantity > 1 then
        numberString =  " (" .. quantity .. ")"
    else
        numberString = ""
    end

    WL_Utils.addToChat("Gained Item: " .. newItem:getName() .. numberString, { color = "1.0,0.8,0.2", })
    return newItem:getName()
end

--- Adds one or more instances of an item to the player's inventory and sends a chat window message informing them
--- @param itemID string of the item's type, e.g Base.Pistol
--- @param quantity number|nil optional parameter defining how many of this item to add
--- @return string the translated name of the item that was added or nil if no such item existed
function WL_Utils.addItemToInventory(itemID, quantity)
    assert(type(itemID) == "string", "itemID must be a string")
    assert(quantity == nil or type(quantity) == "number", "quantity must be a number or nil")
    local inventory = getPlayer():getInventory()
    local newItem

    if quantity then
        for _ = 1, quantity do
            newItem = inventory:AddItem(itemID)
        end
        return addItemGainedMessage(itemID, newItem, quantity)
    else
        newItem = inventory:AddItem(itemID)
        return addItemGainedMessage(itemID, newItem)
    end
end

---@param playerFrom IsoPlayer to take from
---@param itemID string full ID of the item
---@param amount number number of items to take
---@return boolean true if successful taking the items, otherwise false
function WL_Utils.attemptTakeItems(playerFrom, itemID, amount)
    if not amount then amount = 1 end
    if amount < 1 then return true end
    if playerFrom:getInventory():getItemCountFromTypeRecurse(itemID) < amount then
        return false
    end
    for i = 1, amount do
        local item = playerFrom:getInventory():getFirstTypeRecurse(itemID)
        if item then
            item:getContainer():Remove(item)
        end
    end
    return true
end

---@param player IsoPlayer
---@param itemID string full ID of the item e.g. Base.Pistol
---@param amount number number of items required
---@return boolean true if the player has at least the specified amount of the item in their inventory
function WL_Utils.checkInventoryForItem(player, itemID, amount)
    if not amount then amount = 1 end
    if amount < 1 then return true end
    if player:getInventory():getItemCountFromTypeRecurse(itemID) < amount then
        return false
    end
    return true
end

--- Returns the first item with this fullType from the player's main inventory container only.
--- This does not search nested bags/containers.
--- @param player IsoPlayer
--- @param fullType string
--- @return InventoryItem|nil
function WL_Utils.getFirstTypeInMainInventory(player, fullType)
    if not player or not fullType then
        return nil
    end

    local mainInventory = player:getInventory()
    if not mainInventory then
        return nil
    end

    local items = mainInventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getFullType() == fullType and item:getContainer() == mainInventory then
            return item
        end
    end

    return nil
end

--- Gives XP to a player and sends a chat window message informing them
--- Does not factor in perk bonuses, adding the XP value exactly as it is, which makes the message reporting
--- how much XP the player gained be correct at all times (Though this isn't what is wanted in many cases)
--- @param perk PerkFactory.Perks object NOT the string ID e.g Perks.Cooking
--- @param amount number how much XP to give the player
--- @param applyXpMultiplier boolean if true, the XP will be multiplied by the player traits (25% to 215%).
function WL_Utils.gainXP(perk, amount, applyXpMultiplier)
    applyXpMultiplier = applyXpMultiplier or false -- To avoid nil
    getPlayer():getXp():AddXP(perk, amount, false, applyXpMultiplier, false);
    --TODO this message is bugged for applyXpMultiplier=true bc it doesn't account for the multiplier
    WL_Utils.addToChat("Gained " .. perk:getName() .. ": " .. tostring(amount) .. "XP",
            { color = "0.85,0.5,1.0", })
end

--- Reduces XP from a player silently. Unlike gainXP, this function does not send a chat message
--- If needed, this function will drop them down to the previous level.
--- WARNING: This function does not work properly for fitness XP over level 6 when the player is underweight as it
--- can't add XP back due to AddXP being blocked by vanilla Zomboid. It will drop the entire level down instead.
--- @param perk PerkFactory.Perks object NOT the string ID e.g Perks.Cooking
--- @param amount number how much XP to take from the player
function WL_Utils.reduceXP(perk, amount)
    local player = getPlayer()
    local currentLevel = player:getPerkLevel(perk)
    local currentLevelStartXp = perk:getTotalXpForLevel(currentLevel)
    local xp = player:getXp()
    local targetXP = xp:getXP(perk) - amount
    local targetLevel = currentLevel
    if (targetXP < currentLevelStartXp) and currentLevel > 0 then
        targetLevel = targetLevel - 1
        player:LoseLevel(perk)
    end

    local xpToRestore = targetXP - perk:getTotalXpForLevel(targetLevel)
    xp:setXPToLevel(perk, targetLevel);
    if xpToRestore > 0 then
        xp:AddXP(perk, xpToRestore, false, false, false)
    end
    SyncXp(player)
end

---@param itemID string full ID of the item e.g. Base.Pistol
---@return zombie.core.textures.Texture|nil the icon texture of the item, or nil if we cannot find it
function WL_Utils.getIconTexture(itemID)
	local item = getScriptManager():getItem(itemID)
	if not item then
		return
	end
	local icon = item:getIcon()

	if item:getIconsForTexture() and not item:getIconsForTexture():isEmpty() then
		icon = item:getIconsForTexture():get(0)
	end

	local texture = nil
	if icon then
		texture = getTexture("Item_" .. icon)
	end

	if not texture then
		texture = getTexture("media/textures/Item_" .. icon .. ".png") -- Try our best to guess
	end

	return texture
end


--- Makes the player safe from zombies for a short time
--- @param time number how long to make the player safe for in seconds
function WL_Utils.makePlayerSafe(moveTime, stillTime)
    local player = getPlayer()
    if not player then return end
    if WL_Utils.isStaff(player) then return end -- Admins can choose to be safe on their own
    stillTime = stillTime or moveTime * 10
    WL_SafePlayer:start(player, moveTime, stillTime)
end


local function scanItem(holder, item, foundAt)
    table.insert(holder, {item = item, foundAt = foundAt})
    if instanceof(item, "InventoryContainer") then
        local container = item:getItemContainer()
        if container then
            local items = container:getItems()
            if items then
                for i = 0, items:size() - 1 do
                    local innerItem = items:get(i)
                    if innerItem then
                        scanItem(holder, innerItem, "bag")
                    end
                end
            end
        end
    end
end

-- Scans a gridSquare for all items, and returns them in a table
function WL_Utils.scanGridSquare(x, y, z)
    if not instanceof(x, "IsoGridSquare") then
        if not x or not y or not z then return {} end
        x = getCell():getGridSquare(x, y, z)
    end
    if not x then return {} end
    local items = {}

    worldObjects = x:getWorldObjects()
    if worldObjects then
        for j = 0, worldObjects:size() - 1 do
            object = worldObjects:get(j):getItem()
            if object then
                scanItem(items, object, "ground")
            end
        end
    end

    objects = x:getObjects()
    if objects then
        for j = 0, objects:size() - 1 do
            object = objects:get(j)
            if object then
                container = object:getContainer()
                if container then
                    for k = 0, container:getItems():size() - 1 do
                        item = container:getItems():get(k)
                        if item then
                            scanItem(items, item, "container")
                        end
                    end
                end
            end
        end
    end

    movingObjects = x:getMovingObjects()
    if movingObjects then
        for j = 0, movingObjects:size() - 1 do
            object = movingObjects:get(j)
            if instanceof(object, "BaseVehicle") then
                for k = 0, object:getPartCount() - 1 do
                    local part = object:getPartByIndex(k)
                    if part then
                        container = part:getItemContainer()
                        if container then
                            for l = 0, container:getItems():size() - 1 do
                                item = container:getItems():get(l)
                                if item then
                                    scanItem(items, item, "vehicle")
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return items
end

WL_Utils_Privates.currentMoveBoosts = WL_Utils_Privates.currentMoveBoosts or {}
WL_Utils_Privates.currentMoveBoostAdds = WL_Utils_Privates.currentMoveBoostAdds or {}
local wasLastBooted = false
function WL_Utils_Privates.handleMoveBoost(player)
    if not player then return end
    if player:getVehicle() then return end
    if player:getPathFindBehavior2():isMovingUsingPathFind() then return end -- disable for auto-walks
    if player:isCollided() then return end -- no wall clip
    if wasLastBooted then
        wasLastBooted = false
        return
    end
    local boost = WL_Utils_Privates.currentMoveBoosts[player:getPlayerNum()]
    if not boost then
        boost = 0
    end
    if boost == 0 then return end
    local dX = player:getX() - player:getLx()
    local dY = player:getY() - player:getLy()
    if dX ~= 0 or dY ~= 0 then
        local vec = Vector2.new(dX * boost, dY * boost)
        wasLastBooted = true
        player:Move(vec)
    end
end

function WL_Utils_Privates.resetMoveBoost()
    wasLastBooted = false
end

function WL_Utils_Privates.initBoost()
    local player = getPlayer()
    if not player then return end
end

--- Get the current total move boost for a player
--- @param player IsoPlayer
--- @return number the current move boost
function WL_Utils.getMoveBoostTotal(player)
    return WL_Utils_Privates.currentMoveBoosts[player:getPlayerNum()] or 0
end

--- Set the total move boost for a player
--- @param player IsoPlayer
--- @param boost number the new move boost to set
function WL_Utils.setMoveBoostTotal(player, boost)
    if boost == 0 then
        WL_Utils_Privates.currentMoveBoosts[player:getPlayerNum()] = nil
        return
    end
    WL_Utils_Privates.currentMoveBoosts[player:getPlayerNum()] = boost
end

--- Get the current move boost for a player/type
--- @param player IsoPlayer
--- @param boostType string the type of boost to get
function WL_Utils.getMoveBoostType(player, boostType)
    return WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()] and WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()][boostType] or 0
end

--- Add a move boost for a player/type
--- @param player IsoPlayer
--- @param boostType string the type of boost to add
--- @param boost number the amount of boost to add
function WL_Utils.setMoveBoostType(player, boostType, boost)
    if not WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()] then
        WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()] = {}
    end
    if boost == 0 then
        WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()][boostType] = nil
    else
        WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()][boostType] = boost
    end
    local totalBoost = 0
    for _,v in pairs(WL_Utils_Privates.currentMoveBoostAdds[player:getPlayerNum()]) do
        totalBoost = totalBoost + v
    end
    WL_Utils.setMoveBoostTotal(player, totalBoost)
end

--- Remove a move boost from a player/type
--- @param player IsoPlayer
--- @param boostType string the type of boost to remove
function WL_Utils.removeMoveBoostType(player, boostType)
    WL_Utils.setMoveBoostType(player, boostType, 0)
end


WL_Utils_Privates.currentActionBoosts = WL_Utils_Privates.currentActionBoosts or {}
WL_Utils_Privates.currentActionBoostAdds = WL_Utils_Privates.currentActionBoostAdds or {}
WL_Utils_Privates.original_ISBaseTimedAction_adjustMaxTime = WL_Utils_Privates.original_ISBaseTimedAction_adjustMaxTime or ISBaseTimedAction.adjustMaxTime
function ISBaseTimedAction:adjustMaxTime(maxTime)
    maxTime = WL_Utils_Privates.original_ISBaseTimedAction_adjustMaxTime(self, maxTime)
    local player = self.character
    if not player then player = getPlayer() end
    local boost = WL_Utils_Privates.currentActionBoosts[player:getPlayerNum()] or 0
    if boost == 0 or maxTime <= 1 then return maxTime end
    if boost < 0 then
        maxTime = maxTime / (1 - -boost)
    else
        maxTime = maxTime * (1 - boost)
    end
    return math.max(1, math.floor(maxTime))
end

function WL_Utils.setActionBoostTotal(player, boost)
    if boost == 0 then
        WL_Utils_Privates.currentActionBoosts[player:getPlayerNum()] = nil
        return
    end
    WL_Utils_Privates.currentActionBoosts[player:getPlayerNum()] = boost
end

function WL_Utils.getActionBoostTotal(player)
    return WL_Utils_Privates.currentActionBoosts[player:getPlayerNum()] or 0
end

function WL_Utils.setActionBoostType(player, boostType, boost)
    if not WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()] then
        WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()] = {}
    end
    if boost == 0 then
        WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()][boostType] = nil
    else
        WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()][boostType] = boost
    end
    local totalBoost = 0
    for _,v in pairs(WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()]) do
        totalBoost = totalBoost + v
    end
    totalBoost = math.min(1, math.max(-1, totalBoost))
    WL_Utils.setActionBoostTotal(player, totalBoost)
end

function WL_Utils.getActionBoostType(player, boostType)
    return WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()] and WL_Utils_Privates.currentActionBoostAdds[player:getPlayerNum()][boostType] or 0
end

if WL_Utils_Privates.didBindPlayerMove then
    Events.OnPlayerMove.Remove(WL_Utils_Privates.handleMoveBoost)
end
Events.OnPlayerMove.Add(WL_Utils_Privates.handleMoveBoost)
WL_Utils_Privates.didBindPlayerMove = true


WL_Utils_Privates.mapMarkers = WL_Utils_Privates.mapMarkers or {}
WL_Utils_Privates.nextMarkerID = WL_Utils_Privates.nextMarkerID or 1
WL_Utils_Privates.mapMarkerDefinitions = WL_Utils_Privates.mapMarkerDefinitions or {}
WL_Utils_Privates.pendingMapMarkerAdds = WL_Utils_Privates.pendingMapMarkerAdds or {}
WL_Utils_Privates.pendingMapMarkerRemovals = WL_Utils_Privates.pendingMapMarkerRemovals or {}
WL_Utils_Privates.didBindMapMarkerTick = WL_Utils_Privates.didBindMapMarkerTick or false

local function _makeMarkerID()
    local markerID = "WL_MARKER_" .. tostring(WL_Utils_Privates.nextMarkerID)
    WL_Utils_Privates.nextMarkerID = WL_Utils_Privates.nextMarkerID + 1
    return markerID
end

local function _copyMarkerOptions(options)
    return {
        x = options.x,
        y = options.y,
        symbolId = options.symbolId,
        r = options.r,
        g = options.g,
        b = options.b,
        a = options.a,
        scale = options.scale,
        markerID = options.markerID,
    }
end

local function _markerOptionsEqual(a, b)
    if not a or not b then return false end
    return a.x == b.x
        and a.y == b.y
        and a.symbolId == b.symbolId
        and a.r == b.r
        and a.g == b.g
        and a.b == b.b
        and a.a == b.a
        and a.scale == b.scale
end

local function _getSymbolsAPI()
    if not ISWorldMap_instance or not ISWorldMap_instance.mapAPI then
        return nil
    end
    return ISWorldMap_instance.mapAPI:getSymbolsAPI()
end

local function _findSymbolIndex(symbolsAPI, symbol)
    if not symbolsAPI or not symbol then return nil end
    local symbolCount = symbolsAPI:getSymbolCount()
    for i = 0, symbolCount - 1 do
        local currentSymbol = symbolsAPI:getSymbolByIndex(i)
        if currentSymbol == symbol then
            return i
        end
    end
    return nil
end

local function _removeMarkerNow(markerID, symbolsAPI)
    symbolsAPI = symbolsAPI or _getSymbolsAPI()
    if not symbolsAPI then
        return false
    end

    local symbol = WL_Utils_Privates.mapMarkers[markerID]
    if not symbol then
        return true
    end

    local idx = _findSymbolIndex(symbolsAPI, symbol)
    if idx ~= nil then
        symbolsAPI:removeSymbolByIndex(idx)
    end
    WL_Utils_Privates.mapMarkers[markerID] = nil
    return true
end

local function _addMarkerNow(markerID, markerOptions, symbolsAPI)
    symbolsAPI = symbolsAPI or _getSymbolsAPI()
    if not symbolsAPI then
        return false
    end

    local symbolDef = MapSymbolDefinitions.getInstance():getSymbolById(markerOptions.symbolId)
    if not symbolDef then
        print("addMarkerToMap: Invalid symbolId '" .. tostring(markerOptions.symbolId) .. "'")
        return false
    end

    _removeMarkerNow(markerID, symbolsAPI)

    local symbol = symbolsAPI:addTexture(markerOptions.symbolId, markerOptions.x, markerOptions.y)
    if not symbol then
        return false
    end

    symbol:setRGBA(markerOptions.r or 0, markerOptions.g or 0, markerOptions.b or 0, markerOptions.a or 1.0)
    symbol:setAnchor(0.5, 0.5)
    symbol:setScale(markerOptions.scale or ISMap.SCALE)
    WL_Utils_Privates.mapMarkers[markerID] = symbol
    return true
end

local function _tableHasEntries(t)
    if not t then return false end
    for _, _ in pairs(t) do
        return true
    end
    return false
end

local function _hasMapMarkerWork()
    if _tableHasEntries(WL_Utils_Privates.pendingMapMarkerAdds) then return true end
    if _tableHasEntries(WL_Utils_Privates.pendingMapMarkerRemovals) then return true end
    if _tableHasEntries(WL_Utils_Privates.mapMarkerDefinitions) then return true end
    return false
end

function WL_Utils_Privates.mapMarkerTick()
    if not _hasMapMarkerWork() then
        if WL_Utils_Privates.didBindMapMarkerTick then
            Events.OnTick.Remove(WL_Utils_Privates.mapMarkerTick)
            WL_Utils_Privates.didBindMapMarkerTick = false
        end
        return
    end

    local symbolsAPI = _getSymbolsAPI()
    if not symbolsAPI then
        return
    end

    for markerID, _ in pairs(WL_Utils_Privates.pendingMapMarkerRemovals) do
        _removeMarkerNow(markerID, symbolsAPI)
        WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = nil
    end

    for markerID, markerOptions in pairs(WL_Utils_Privates.pendingMapMarkerAdds) do
        if _addMarkerNow(markerID, markerOptions, symbolsAPI) then
            WL_Utils_Privates.pendingMapMarkerAdds[markerID] = nil
        end
    end

    for markerID, markerOptions in pairs(WL_Utils_Privates.mapMarkerDefinitions) do
        if not WL_Utils_Privates.pendingMapMarkerRemovals[markerID] then
            local symbol = WL_Utils_Privates.mapMarkers[markerID]
            local symbolIdx = _findSymbolIndex(symbolsAPI, symbol)
            if symbolIdx == nil then
                _addMarkerNow(markerID, markerOptions, symbolsAPI)
            end
        end
    end
end

local function _ensureMapMarkerTickBound()
    if WL_Utils_Privates.didBindMapMarkerTick then
        return
    end
    Events.OnTick.Add(WL_Utils_Privates.mapMarkerTick)
    WL_Utils_Privates.didBindMapMarkerTick = true
end

---@class WL_MapMarkerOptions
---@field x number World X coordinate
---@field y number World Y coordinate
---@field symbolId string|nil Symbol ID from MapSymbolDefinitions (e.g., "Circle")
---@field r number|nil Red color component (0-1), default 0
---@field g number|nil Green color component (0-1), default 0
---@field b number|nil Blue color component (0-1), default 0
---@field a number|nil Alpha component (0-1), default 1
---@field scale number|nil Scale multiplier, default ISMap.SCALE
---@field markerID string|nil Optional stable marker ID. If omitted, one is generated.

--- @param WL_MapMarkerOptions table
--- @return string|nil The marker ID, or nil if options are invalid
function WL_Utils.addMarkerToMap(WL_MapMarkerOptions)
    if not WL_MapMarkerOptions or type(WL_MapMarkerOptions) ~= "table" then
        print("addMarkerToMap: WL_MapMarkerOptions must be a table")
        return nil
    end
    
    if not WL_MapMarkerOptions.x or not WL_MapMarkerOptions.y then
        print("addMarkerToMap: x and y coordinates are required")
        return nil
    end

    if not WL_MapMarkerOptions.symbolId then
        print("addMarkerToMap: 'symbolId' must be provided")
        return nil
    end

    local markerID = WL_MapMarkerOptions.markerID
    if not markerID or type(markerID) ~= "string" or markerID == "" then
        markerID = _makeMarkerID()
    end

    local markerOptions = {
        x = WL_MapMarkerOptions.x,
        y = WL_MapMarkerOptions.y,
        symbolId = WL_MapMarkerOptions.symbolId,
        r = WL_MapMarkerOptions.r or 0,
        g = WL_MapMarkerOptions.g or 0,
        b = WL_MapMarkerOptions.b or 0,
        a = WL_MapMarkerOptions.a or 1.0,
        scale = WL_MapMarkerOptions.scale or ISMap.SCALE,
        markerID = markerID,
    }

    local existingDefinition = WL_Utils_Privates.mapMarkerDefinitions[markerID]
    if existingDefinition and _markerOptionsEqual(existingDefinition, markerOptions) then
        local symbolsAPI = _getSymbolsAPI()
        if symbolsAPI then
            local existingSymbol = WL_Utils_Privates.mapMarkers[markerID]
            if _findSymbolIndex(symbolsAPI, existingSymbol) ~= nil then
                WL_Utils_Privates.pendingMapMarkerAdds[markerID] = nil
                WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = nil
                _ensureMapMarkerTickBound()
                return markerID
            end
        end

        if WL_Utils_Privates.pendingMapMarkerAdds[markerID] then
            WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = nil
            _ensureMapMarkerTickBound()
            return markerID
        end
    end

    WL_Utils_Privates.mapMarkerDefinitions[markerID] = _copyMarkerOptions(markerOptions)
    WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = nil

    local symbolsAPI = _getSymbolsAPI()
    if symbolsAPI and _addMarkerNow(markerID, markerOptions, symbolsAPI) then
        WL_Utils_Privates.pendingMapMarkerAdds[markerID] = nil
        print("Added map marker with ID: " .. markerID)
    else
        local wasAlreadyQueued = WL_Utils_Privates.pendingMapMarkerAdds[markerID] ~= nil
        WL_Utils_Privates.pendingMapMarkerAdds[markerID] = _copyMarkerOptions(markerOptions)
        _ensureMapMarkerTickBound()
        if not wasAlreadyQueued then
            print("Queued map marker with ID: " .. markerID)
        end
    end

    _ensureMapMarkerTickBound()
    return markerID
end

--- Remove a marker from the world map by its unique ID
--- @param markerID string The unique ID of the marker (returned by addMarkerToMap)
--- @return boolean True if the marker was successfully removed, false otherwise
function WL_Utils.removeMarkerFromMap(markerID)
    if not markerID or type(markerID) ~= "string" then
        print("removeMarkerFromMap: markerID must be a string")
        return false
    end
    
    local hadAnyMarkerData = (WL_Utils_Privates.mapMarkerDefinitions[markerID] ~= nil)
        or (WL_Utils_Privates.mapMarkers[markerID] ~= nil)
        or (WL_Utils_Privates.pendingMapMarkerAdds[markerID] ~= nil)
        or (WL_Utils_Privates.pendingMapMarkerRemovals[markerID] ~= nil)

    if not hadAnyMarkerData then
        return true
    end

    WL_Utils_Privates.mapMarkerDefinitions[markerID] = nil
    WL_Utils_Privates.pendingMapMarkerAdds[markerID] = nil

    local symbolsAPI = _getSymbolsAPI()
    if symbolsAPI then
        _removeMarkerNow(markerID, symbolsAPI)
        WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = nil
        print("Removed map marker with ID: " .. markerID)
    else
        local wasAlreadyQueued = WL_Utils_Privates.pendingMapMarkerRemovals[markerID] ~= nil
        WL_Utils_Privates.pendingMapMarkerRemovals[markerID] = true
        _ensureMapMarkerTickBound()
        if not wasAlreadyQueued then
            print("Queued marker removal with ID: " .. markerID)
        end
    end

    return true
end

function WL_Utils.isBodyPartAmputated(player, bodyPartType)
    if bodyPartType == BodyPartType.Foot_L or bodyPartType == BodyPartType.LowerLeg_L or bodyPartType == BodyPartType.UpperLeg_L then
        return player:getWornItems():getItem("Amputation_LL") ~= nil
    elseif bodyPartType == BodyPartType.Foot_R or bodyPartType == BodyPartType.LowerLeg_R or bodyPartType == BodyPartType.UpperLeg_R then
        return player:getWornItems():getItem("Amputation_RL") ~= nil
    elseif bodyPartType == BodyPartType.Hand_L or bodyPartType == BodyPartType.ForeArm_L or bodyPartType == BodyPartType.UpperArm_L then
        return player:getWornItems():getItem("Amputation_LA") ~= nil or player:getWornItems():getItem("Amputation_BA") ~= nil
    elseif bodyPartType == BodyPartType.Hand_R or bodyPartType == BodyPartType.ForeArm_R or bodyPartType == BodyPartType.UpperArm_R then
        return player:getWornItems():getItem("Amputation_RA") ~= nil or player:getWornItems():getItem("Amputation_BA") ~= nil
    end
    
    return false
end
