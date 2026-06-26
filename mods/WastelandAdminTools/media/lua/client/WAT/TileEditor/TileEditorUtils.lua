-- TileEditorUtils.lua
-- Shared utility functions and data structures for the Tile Editor system

TileEditorUtils = TileEditorUtils or {}

-- ============================================================================
-- Data Structure Constructors
-- ============================================================================

--- Creates a new TileData structure
-- @param x World X coordinate
-- @param y World Y coordinate
-- @param z World Z coordinate
-- @param spriteName Sprite identifier
-- @param isFloor Whether tile is a floor tile
-- @return TileData table
function TileEditorUtils.createTileData(x, y, z, spriteName, isFloor)
    return {
        x = x or 0,
        y = y or 0,
        z = z or 0,
        spriteName = spriteName or "",
        isFloor = isFloor or false
    }
end

--- Creates a new Palette structure
-- @param name Optional palette name
-- @return Palette table
function TileEditorUtils.createPalette(name)
    return {
        tiles = {},
        name = name or ""
    }
end

--- Creates a new Selection structure
-- @param selectionType Type of selection (point, rect, circle, box, ring)
-- @return Selection table
function TileEditorUtils.createSelection(selectionType)
    return {
        type = selectionType or "point",
        centerX = 0,
        centerY = 0,
        z = 0,
        x1 = 0,
        y1 = 0,
        x2 = 0,
        y2 = 0,
        radius = 0,
        innerRadius = 0
    }
end

--- Creates a new UndoOperation structure
-- @param action Action type (fill, clear_floor, clear_other, partial_fill)
-- @return UndoOperation table
function TileEditorUtils.createUndoOperation(action)
    return {
        action = action or "",
        timestamp = getTimestampMs(),
        changes = {}
    }
end

-- ============================================================================
-- Tile Query Functions
-- ============================================================================

--- Returns all tile data from a square
-- @param x World X coordinate
-- @param y World Y coordinate
-- @param z World Z coordinate
-- @param floorsOnly If true, only return floor tiles
-- @return Array of TileData
function TileEditorUtils.getSquareTiles(x, y, z, floorsOnly)
    local tiles = {}
    local square = getCell():getGridSquare(x, y, z)
    
    if not square then
        return tiles
    end
    
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local isFloor = obj:isFloor()
            
            if not floorsOnly or isFloor then
                local sprite = obj:getSprite()
                if sprite then
                    table.insert(tiles, TileEditorUtils.createTileData(
                        x, y, z,
                        sprite:getName(),
                        isFloor
                    ))
                end
            end
        end
    end
    
    return tiles
end

--- Checks if an object is a floor tile
-- @param object IsoObject to check
-- @return boolean
function TileEditorUtils.isFloorTile(object)
    if not object then return false end
    if not instanceof(object, "IsoObject") then return false end
    if instanceof(object, "IsoMovingObject") then return false end
    return object:isFloor()
end

--- Returns all coordinates in a selection
-- @param selection Selection structure
-- @return Array of {x, y, z} coordinates
function TileEditorUtils.getSelectionTiles(selection)
    local tiles = {}
    
    if selection.type == "point" then
        table.insert(tiles, {x = selection.centerX, y = selection.centerY, z = selection.z})
        
    elseif selection.type == "rect" then
        TileEditorUtils.iterateRect(
            selection.x1, selection.y1, selection.x2, selection.y2, selection.z,
            function(x, y, z)
                table.insert(tiles, {x = x, y = y, z = z})
            end,
            false
        )
        
    elseif selection.type == "box" then
        TileEditorUtils.iterateBox(
            selection.x1, selection.y1, selection.x2, selection.y2, selection.z,
            selection.boxThickness or 1,
            function(x, y, z)
                table.insert(tiles, {x = x, y = y, z = z})
            end
        )
        
    elseif selection.type == "circle" then
        TileEditorUtils.iterateCircle(
            selection.centerX, selection.centerY, selection.radius, selection.z,
            function(x, y, z)
                table.insert(tiles, {x = x, y = y, z = z})
            end,
            nil
        )
        
    elseif selection.type == "ring" then
        TileEditorUtils.iterateCircle(
            selection.centerX, selection.centerY, selection.radius, selection.z,
            function(x, y, z)
                table.insert(tiles, {x = x, y = y, z = z})
            end,
            selection.ringThickness or 1
        )
    end
    
    return tiles
end

--- Returns a random tile from palette
-- @param palette Palette structure
-- @return string Sprite name or nil
function TileEditorUtils.randomFromPalette(palette)
    if not palette or not palette.tiles or #palette.tiles == 0 then
        return nil
    end
    
    local index = ZombRand(#palette.tiles) + 1
    return palette.tiles[index]
end

-- ============================================================================
-- Coordinate Iteration Functions
-- ============================================================================

--- Iterates over rectangle or box coordinates
-- @param x1 Start X
-- @param y1 Start Y
-- @param x2 End X
-- @param y2 End Y
-- @param z Z level
-- @param callback Function(x, y, z) to call for each coordinate
-- @param borderOnly If true, only iterate border
function TileEditorUtils.iterateRect(x1, y1, x2, y2, z, callback, borderOnly)
    -- Ensure x1 <= x2 and y1 <= y2
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    
    for x = x1, x2 do
        for y = y1, y2 do
            if not borderOnly or x == x1 or x == x2 or y == y1 or y == y2 then
                callback(x, y, z)
            end
        end
    end
end

--- Iterates over box (hollow rectangle) coordinates with thickness
-- @param x1 Start X
-- @param y1 Start Y
-- @param x2 End X
-- @param y2 End Y
-- @param z Z level
-- @param thickness Thickness of the box border
-- @param callback Function(x, y, z) to call for each coordinate
function TileEditorUtils.iterateBox(x1, y1, x2, y2, z, thickness, callback)
    -- Ensure x1 <= x2 and y1 <= y2
    if x1 > x2 then x1, x2 = x2, x1 end
    if y1 > y2 then y1, y2 = y2, y1 end
    
    thickness = thickness or 1
    
    for x = x1, x2 do
        for y = y1, y2 do
            -- Calculate distance from each edge
            local distFromLeft = x - x1
            local distFromRight = x2 - x
            local distFromTop = y - y1
            local distFromBottom = y2 - y
            
            -- Check if within thickness distance from any edge
            local minDist = math.min(distFromLeft, distFromRight, distFromTop, distFromBottom)
            if minDist < thickness then
                callback(x, y, z)
            end
        end
    end
end

--- Iterates over circle or ring coordinates
-- @param centerX Center X
-- @param centerY Center Y
-- @param radius Outer radius (or center radius for rings)
-- @param z Z level
-- @param callback Function(x, y, z) to call for each coordinate
-- @param ringThickness If provided, creates a ring centered around radius
function TileEditorUtils.iterateCircle(centerX, centerY, radius, z, callback, ringThickness)
    -- Match GroundHighlighter's ring calculation
    local innerRadius, outerRadius
    if ringThickness then
        -- Ring is centered around radius with thickness extending both ways
        innerRadius = radius - ringThickness / 2
        outerRadius = radius + ringThickness / 2
    else
        -- Filled circle
        innerRadius = 0
        outerRadius = radius
    end
    
    -- Expand iteration bounds to include outer radius
    local maxExtent = math.ceil(outerRadius)
    for x = centerX - maxExtent, centerX + maxExtent do
        for y = centerY - maxExtent, centerY + maxExtent do
            local dx = x - centerX
            local dy = y - centerY
            local dist = math.sqrt(dx * dx + dy * dy)
            
            -- Check if point is within the ring/circle
            if dist >= innerRadius and dist <= outerRadius then
                callback(x, y, z)
            end
        end
    end
end

-- ============================================================================
-- World Coordinate Helpers
-- ============================================================================

--- Gets the world coordinates from mouse position
-- @param mouseX Screen X
-- @param mouseY Screen Y
-- @param z Z level
-- @return x, y World coordinates
function TileEditorUtils.screenToWorld(mouseX, mouseY, z)
    local player = getPlayer()
    if not player then return nil, nil end
    
    local isoX = screenToIsoX(0, mouseX, mouseY, z)
    local isoY = screenToIsoY(0, mouseX, mouseY, z)
    
    return math.floor(isoX), math.floor(isoY)
end

--- Checks if a square is valid for placement
-- @param x World X
-- @param y World Y
-- @param z World Z
-- @return boolean
function TileEditorUtils.isValidSquare(x, y, z)
    return getWorld():isValidSquare(x, y, z)
end

--- Gets or creates a grid square
-- @param x World X
-- @param y World Y
-- @param z World Z
-- @return IsoGridSquare or nil
function TileEditorUtils.getOrCreateSquare(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    
    if not square and TileEditorUtils.isValidSquare(x, y, z) then
        square = getCell():createNewGridSquare(x, y, z, true)
    end
    
    return square
end

-- ============================================================================
-- Sprite Helpers
-- ============================================================================

--- Checks if a sprite name is valid
-- @param spriteName Sprite name to check
-- @return boolean
function TileEditorUtils.isValidSprite(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    
    local sprite = getSprite(spriteName)
    return sprite ~= nil
end

--- Gets sprite properties
-- @param spriteName Sprite name
-- @return IsoSpriteInstance or nil
function TileEditorUtils.getSprite(spriteName)
    if not spriteName or spriteName == "" then
        return nil
    end
    
    return getSprite(spriteName)
end

--- Checks if a sprite is a floor tile
-- @param spriteName Sprite name
-- @return boolean
function TileEditorUtils.isSpriteFloor(spriteName)
    local sprite = TileEditorUtils.getSprite(spriteName)
    if not sprite then return false end
    
    local props = sprite:getProperties()
    if not props then return false end
    
    return props:Is("IsFloor")
end

-- ============================================================================
-- Math Helpers
-- ============================================================================

--- Clamps a value between min and max
-- @param value Value to clamp
-- @param min Minimum value
-- @param max Maximum value
-- @return number Clamped value
function TileEditorUtils.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Calculates distance between two points
-- @param x1 First point X
-- @param y1 First point Y
-- @param x2 Second point X
-- @param y2 Second point Y
-- @return number Distance
function TileEditorUtils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- ============================================================================
-- Debug Helpers
-- ============================================================================

--- Prints debug information
-- @param ... Values to print
function TileEditorUtils.debug(...)
    if getDebug() then
        print("[TileEditor]", ...)
    end
end

--- Prints error information
-- @param ... Values to print
function TileEditorUtils.error(...)
    print("[TileEditor ERROR]", ...)
end

return TileEditorUtils