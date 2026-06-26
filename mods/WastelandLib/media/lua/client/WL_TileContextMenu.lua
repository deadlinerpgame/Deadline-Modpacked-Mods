---
--- WL_TileContextMenu.lua
---

--- Registers callbacks that add context-menu options when a matching tile is
--- right-clicked. Callbacks receive the local player, the current context menu,
--- the clicked square, and the matched iso object.
WL_TileContextMenu = WL_TileContextMenu or {}
--- @type table[]
WL_TileContextMenu.registrations = WL_TileContextMenu.registrations or {}

--- Builds a lookup map from a single tile name or a table of tile names.
--- Accepts either `"tile_name"` or `{ "tile_a", "tile_b" }`.
--- @param tileNames string|string[]
--- @return table<string, boolean>|nil
local function buildTileNameLookupMap(tileNames)
    if type(tileNames) == "string" then
        return { [tileNames] = true }
    end

    if type(tileNames) ~= "table" then
        return nil
    end

    local tileNameLookupMap = {}
    local hasEntries = false

    for key, value in pairs(tileNames) do
        if type(key) == "string" then
            tileNameLookupMap[key] = value and true or false
            hasEntries = true
        elseif type(value) == "string" then
            tileNameLookupMap[value] = true
            hasEntries = true
        end
    end

    if not hasEntries then
        return nil
    end

    return tileNameLookupMap
end

--- Finds the first object on a square whose sprite name exists in the lookup map.
--- @param square IsoGridSquare
--- @param tileNameLookupMap table<string, boolean>
--- @return IsoObject|nil
local function getMatchingObjectOnSquare(square, tileNameLookupMap)
    local objects = square:getObjects()
    if not objects then
        return nil
    end

    for i = 0, objects:size() - 1 do
        local isoObject = objects:get(i)
        local sprite = isoObject and isoObject:getSprite()
        local spriteName = sprite and sprite:getName()
        if spriteName and tileNameLookupMap[spriteName] then
            return isoObject
        end
    end

    return nil
end

--- Dispatches the world-object context menu event to all registered tile handlers.
--- @param playerIdx integer
--- @param context ISContextMenu
--- @param worldobjects table
--- @param test boolean
local function onFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    local registrations = WL_TileContextMenu.registrations
    if #registrations == 0 then
        return
    end

    local player = getSpecificPlayer(playerIdx)
    if not player then
        return
    end

    if not worldobjects then
        return
    end

    for i = 1, #registrations do
        local registration = registrations[i]
        for j = 1, #worldobjects do
            local square = worldobjects[j]:getSquare()
            if square then
                local isoObject = getMatchingObjectOnSquare(square, registration.tileNameLookupMap)
                if isoObject then
                    registration.callback(player, context, square, isoObject)
                    break
                end
            end
        end
    end
end

--- Registers or replaces a tile context-menu handler by id.
--- The callback runs when any clicked world object belongs to a square containing a matching tile sprite.
--- Calling this again with the same id replaces the previous tile names and callback instead of adding a duplicate.
--- @param id string Unique registration id used for replacement and deregistration.
--- @param tileNames string|string[] A single tile sprite name or a list of sprite names to match.
--- @param callback fun(player: IsoPlayer, context: ISContextMenu, square: IsoGridSquare, isoObject: IsoObject)
function WL_TileContextMenu.register(id, tileNames, callback)
    if not id then
        return
    end

    if type(callback) ~= "function" then
        return
    end

    local tileNameLookupMap = buildTileNameLookupMap(tileNames)
    if not tileNameLookupMap then
        return
    end

    local registration = {
        id = id,
        tileNameLookupMap = tileNameLookupMap,
        callback = callback,
    }

    for i = 1, #WL_TileContextMenu.registrations do
        if WL_TileContextMenu.registrations[i].id == id then
            WL_TileContextMenu.registrations[i] = registration
            return
        end
    end

    WL_TileContextMenu.registrations[#WL_TileContextMenu.registrations + 1] = registration
end

--- Removes a previously registered tile context-menu handler.
--- @param id string Registration id passed to `register`.
function WL_TileContextMenu.deRegister(id)
    if not id then
        return
    end

    for i = 1, #WL_TileContextMenu.registrations do
        if WL_TileContextMenu.registrations[i].id == id then
            table.remove(WL_TileContextMenu.registrations, i)
            return
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)
