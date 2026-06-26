if WL_TimedItems then
    Events.OnTick.Remove(WL_TimedItems.OnTick)
end

WL_TimedItems = {}
WL_TimedItems.TickCounter = 0

local function isTimedItem(item)
    local modData = item:getModData()
    return modData and modData.WL_ExpireTimeStamp ~= nil
end

---
-- Formats a number of seconds into a compact human-readable string.
-- e.g. 8580 -> "2h23m", 90 -> "1m30s", 45 -> "45s"
local function formatTimeRemaining(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 and m == 0 then
        return string.format("%dh", h)
    elseif h > 0 then
        return string.format("%dh%dm", h, m)
    elseif m > 0 then
        return string.format("%dm%ds", m, s)
    else
        return string.format("%ds", s)
    end
end

---
-- Strips a previously-applied "(... remaining)" suffix from a name string.
local function stripTimeSuffix(name)
    return (name:gsub(" %(%d+[hms][^%)]*remaining%)$", ""))
end

---
-- Adds an expiry time to an item.
-- @param item The InventoryItem to set the expiry on.
-- @param seconds The duration in seconds from now until expiry.
-- @param baseName Optional. The base name of the item. If not provided, it will be taken from the item's current name.
function WL_TimedItems.AddTimedItem(item, seconds, baseName)
    if not item then return end
    local modData = item:getModData()
    -- Store the original base name once so we always strip from the right place
    if not modData.WL_BaseName then
        modData.WL_BaseName = baseName or item:getName()
    end
    modData.WL_ExpireTimeStamp = getTimestamp() + seconds

    -- Immediately apply the label so it shows right away without waiting for the first tick
    local newName = modData.WL_BaseName .. " (" .. formatTimeRemaining(seconds) .. " remaining)"
    item:setName(newName)
    local pdata = getPlayerData(getPlayer():getPlayerNum())
    pdata.playerInventory:refreshBackpacks()
    pdata.lootInventory:refreshBackpacks()
end

function WL_TimedItems.CheckInventory()
    local player = getPlayer()
    if not player then return end

    local itemsToRemove = {}
    local now = getTimestamp()
    local allItems = player:getInventory():getAllEvalRecurse(isTimedItem)
    if not allItems or allItems:isEmpty() then return end

    for i = 0, allItems:size() - 1 do
        local item = allItems:get(i)
        local modData = item:getModData()
        if modData.WL_ExpireTimeStamp then
            if now > modData.WL_ExpireTimeStamp then
                table.insert(itemsToRemove, item)
            else
                -- Update the display name with remaining time
                local remaining = modData.WL_ExpireTimeStamp - now
                local baseName = modData.WL_BaseName or stripTimeSuffix(item:getName())
                local newName = baseName .. " (" .. formatTimeRemaining(remaining) .. " remaining)"
                item:setName(newName)
            end
        end
    end

    -- Remove expired items and notify
    for _, item in ipairs(itemsToRemove) do
        -- Use the stored base name for the notification (no time suffix)
        local modData = item:getModData()
        local itemName = modData.WL_BaseName or stripTimeSuffix(item:getName())

        if item:getContainer() then
            item:getContainer():DoRemoveItem(item)
        end

        local message = itemName .. " has expired."
        if WL_Utils and WL_Utils.addErrorToChat then
            WL_Utils.addErrorToChat(message)
        else
            player:Say(message)
        end
    end
end

function WL_TimedItems.OnTick()
    -- Check every 600 ticks (approx 10 seconds at 60 FPS)
    WL_TimedItems.TickCounter = WL_TimedItems.TickCounter + 1
    if WL_TimedItems.TickCounter >= 600 then
        WL_TimedItems.TickCounter = 0
        WL_TimedItems.CheckInventory()
    end
end

Events.OnTick.Add(WL_TimedItems.OnTick)
