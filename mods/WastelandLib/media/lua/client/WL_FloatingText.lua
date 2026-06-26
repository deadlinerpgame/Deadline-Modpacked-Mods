---
--- WL_FloatingText.lua
--- Simple API for floating world text attached to world items or world coordinates.
--- 05/04/2026
---

require "WL_FloatingTextElement"

WL_FloatingText = {}
WL_FloatingText.entries = {}
WL_FloatingText.nextId = 1

--- How often to prune invalid entries.
WL_FloatingText.checkInterval = 10
WL_FloatingText.checkTimeout = 0

local function wlft_getNamedColor(colorName)
    if not colorName then
        return nil
    end

    local key = string.lower(tostring(colorName))

    if key == "red" then
        return { r = 1, g = 0, b = 0, a = 1 }
    elseif key == "blue" then
        return { r = 0, g = 0, b = 1, a = 1 }
    elseif key == "green" then
        return { r = 0, g = 1, b = 0, a = 1 }
    elseif key == "white" then
        return { r = 1, g = 1, b = 1, a = 1 }
    end

    return nil
end

local function wlft_copyColor(color)
    if not color then
        return { r = 1, g = 1, b = 1, a = 1 }
    end

    if type(color) == "string" then
        local named = wlft_getNamedColor(color)
        if named then
            return named
        end

        return { r = 1, g = 1, b = 1, a = 1 }
    end

    return {
        r = color.r or 1,
        g = color.g or 1,
        b = color.b or 1,
        a = color.a or 1,
    }
end

local function wlft_normalizeText(text, defaultColor)
    local lines = {}

    if text == nil then
        return lines
    end

    if type(text) == "string" then
        lines[1] = {
            text = text,
            color = wlft_copyColor(defaultColor)
        }
        return lines
    end

    if type(text) ~= "table" then
        lines[1] = {
            text = tostring(text),
            color = wlft_copyColor(defaultColor)
        }
        return lines
    end

    for i = 1, #text do
        local line = text[i]

        if type(line) == "string" then
            lines[#lines + 1] = {
                text = line,
                color = wlft_copyColor(defaultColor)
            }
        elseif type(line) == "table" then
            lines[#lines + 1] = {
                text = tostring(line.text or ""),
                color = wlft_copyColor(line.color or defaultColor)
            }
        else
            lines[#lines + 1] = {
                text = tostring(line),
                color = wlft_copyColor(defaultColor)
            }
        end
    end

    return lines
end

local function wlft_getPlayer(entry)
    local playerIndex = entry and entry.playerIndex or 0
    return getSpecificPlayer(playerIndex)
end

local function wlft_getSquareFromCoords(x, y, z)
    if x == nil or y == nil or z == nil then
        return nil
    end
    return getCell():getGridSquare(math.floor(x), math.floor(y), math.floor(z))
end

local function wlft_distanceToPlayerSquare(playerSquare, square)
    if not playerSquare or not square then
        return math.huge
    end
    return playerSquare:DistTo(square)
end

local function wlft_getEntrySquare(entry)
    if not entry then return nil end

    if entry.worldItem then
        return entry.worldItem:getSquare()
    end

    return wlft_getSquareFromCoords(entry.x, entry.y, entry.z)
end

local function wlft_generateId()
    local id = "WL_FloatingText_" .. tostring(WL_FloatingText.nextId)
    WL_FloatingText.nextId = WL_FloatingText.nextId + 1
    return id
end

function WL_FloatingText.get(id)
    return WL_FloatingText.entries[id]
end

function WL_FloatingText.exists(id)
    return WL_FloatingText.entries[id] ~= nil
end

function WL_FloatingText.remove(idOrEntry)
    local id = idOrEntry
    if type(idOrEntry) == "table" then
        id = idOrEntry.id
    end

    local entry = WL_FloatingText.entries[id]
    if not entry then
        return false
    end

    entry.removed = true

    if entry.element then
        entry.element:removeFromUIManager()
        entry.element = nil
    end

    WL_FloatingText.entries[id] = nil
    return true
end

function WL_FloatingText.clearAll()
    for id, entry in pairs(WL_FloatingText.entries) do
        if entry.element then
            entry.element:removeFromUIManager()
            entry.element = nil
        end
        entry.removed = true
        WL_FloatingText.entries[id] = nil
    end
end

function WL_FloatingText.isValidEntry(entry)
    if not entry or entry.removed then
        return false
    end

    local player = wlft_getPlayer(entry)
    if not player then
        return false
    end

    if entry.worldItem then
        if not entry.worldItem:getSquare() then
            return false
        end
    else
        if entry.x == nil or entry.y == nil or entry.z == nil then
            return false
        end
    end

    if entry.duration and entry.duration > 0 then
        if getGameTime():getWorldAgeHours() >= entry.expireAt then
            return false
        end
    end

    return true
end

function WL_FloatingText.isEntryVisible(entry)
    if not WL_FloatingText.isValidEntry(entry) then
        return false
    end

    local player = wlft_getPlayer(entry)
    if not player then
        return false
    end

    local playerSquare = player:getSquare()
    local square = wlft_getEntrySquare(entry)
    if not square then
        return false
    end

    if entry.requireCanSee ~= false and not square:isCanSee(entry.playerIndex or 0) then
        return false
    end

    local range = entry.range or 4
    if wlft_distanceToPlayerSquare(playerSquare, square) > range then
        return false
    end

    return true
end

function WL_FloatingText.update(idOrEntry, args)
    local entry = idOrEntry
    if type(idOrEntry) ~= "table" then
        entry = WL_FloatingText.entries[idOrEntry]
    end

    if not entry or not args then
        return nil
    end

    if args.text ~= nil then
        entry.textLines = wlft_normalizeText(args.text, entry.color)
    end

    if args.color ~= nil then
        entry.color = wlft_copyColor(args.color)
    end

    if args.range ~= nil then
        entry.range = tonumber(args.range) or entry.range
    end

    if args.yOffset ~= nil then
        entry.yOffset = tonumber(args.yOffset) or entry.yOffset
    end

    if args.font ~= nil then
        entry.font = args.font
    end

    if args.playerIndex ~= nil then
        entry.playerIndex = args.playerIndex
    end

    if args.requireCanSee ~= nil then
        entry.requireCanSee = args.requireCanSee
    end

    if args.duration ~= nil then
        entry.duration = tonumber(args.duration)
        if entry.duration and entry.duration > 0 then
            entry.expireAt = getGameTime():getWorldAgeHours() + (entry.duration / 3600)
        else
            entry.expireAt = nil
        end
    end

    if args.worldItem ~= nil then
        entry.worldItem = args.worldItem
        entry.x = nil
        entry.y = nil
        entry.z = nil
    end

    if args.x ~= nil then entry.x = args.x end
    if args.y ~= nil then entry.y = args.y end
    if args.z ~= nil then entry.z = args.z end

    return entry
end

function WL_FloatingText.create(args)
    if not args then return nil end

    local id = args.id or wlft_generateId()
    local existing = WL_FloatingText.entries[id]
    if existing then
        return WL_FloatingText.update(existing, args)
    end

    local entry = {
        id = id,
        worldItem = args.worldItem,
        x = args.x,
        y = args.y,
        z = args.z or 0,
        color = wlft_copyColor(args.color),
        textLines = wlft_normalizeText(args.text, args.color),
        range = tonumber(args.range) or 4,
        yOffset = tonumber(args.yOffset) or 30,
        font = args.font or UIFont.Small,
        playerIndex = args.playerIndex or 0,
        requireCanSee = args.requireCanSee ~= false,
        duration = tonumber(args.duration),
        removed = false
    }

    if entry.duration and entry.duration > 0 then
        entry.expireAt = getGameTime():getWorldAgeHours() + (entry.duration / 3600)
    end

    entry.element = WL_FloatingTextElement:new(entry)
    WL_FloatingText.entries[id] = entry

    return entry
end

--- Create floating text attached to a world item.
--- args:
--- {
---     id = "optional_unique_id",
---     text = "Hello" or {"Line 1", "Line 2"},
---     color = {r=1,g=1,b=1,a=1},
---     range = 4,
---     yOffset = 30,
---     font = UIFont.Small,
---     playerIndex = 0,
---     requireCanSee = true,
---     duration = 10 -- seconds, optional
--- }
function WL_FloatingText.showForWorldItem(worldItem, args)
    if not worldItem then return nil end
    args = args or {}
    args.worldItem = worldItem
    return WL_FloatingText.create(args)
end

--- Create floating text attached to world coordinates.
--- args:
--- {
---     id = "optional_unique_id",
---     text = "Hello" or {"Line 1", "Line 2"},
---     color = {r=1,g=1,b=1,a=1},
---     range = 4,
---     yOffset = 30,
---     font = UIFont.Small,
---     playerIndex = 0,
---     requireCanSee = true,
---     duration = 10 -- seconds, optional
--- }
function WL_FloatingText.showAtCoords(x, y, z, args)
    args = args or {}
    args.x = x
    args.y = y
    args.z = z or 0
    return WL_FloatingText.create(args)
end

function WL_FloatingText.pruneInvalidEntries()
    local toRemove = {}

    for id, entry in pairs(WL_FloatingText.entries) do
        if not WL_FloatingText.isValidEntry(entry) then
            table.insert(toRemove, id)
        end
    end

    for i = 1, #toRemove do
        WL_FloatingText.remove(toRemove[i])
    end
end

function WL_FloatingText.onTick()
    if WL_FloatingText.checkTimeout > 0 then
        WL_FloatingText.checkTimeout = WL_FloatingText.checkTimeout - 1
        return
    end

    WL_FloatingText.checkTimeout = WL_FloatingText.checkInterval
    WL_FloatingText.pruneInvalidEntries()
end

Events.OnTick.Add(WL_FloatingText.onTick)