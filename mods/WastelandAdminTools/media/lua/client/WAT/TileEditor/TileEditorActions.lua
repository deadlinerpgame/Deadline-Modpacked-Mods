-- TileEditorActions.lua
-- Fill, Clear, and Partial Fill logic for the Tile Editor system

require "ISMoveableSpriteProps"

TileEditorActions = {}

-- ============================================================================
-- Constructor
-- ============================================================================

function TileEditorActions:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    return o
end

-- ============================================================================
-- State Capture
-- ============================================================================

--- Captures the current state of a square for undo purposes
-- @param square IsoGridSquare
-- @param floorsOnly If true, only capture floor tiles
-- @return Array of tile data
function TileEditorActions:captureSquareState(square, floorsOnly)
    if not square then
        return {}
    end
    
    local state = {}
    local objects = square:getObjects()
    
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local isFloor = obj:isFloor()
            
            if not floorsOnly or isFloor then
                local sprite = obj:getSprite()
                if sprite then
                    table.insert(state, {
                        spriteName = sprite:getName(),
                        isFloor = isFloor
                    })
                end
            end
        end
    end
    
    return state
end

-- ============================================================================
-- Tile Placement
-- ============================================================================
local dummyItem
--- Places a tile on a square
-- @param square IsoGridSquare
-- @param spriteName Sprite name to place
-- @return boolean Success
function TileEditorActions:placeTile(square, spriteName)
    if not square or not spriteName then
        return false
    end

    -- Check if square already has this sprite
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == spriteName then
                -- Already present
                return false
            end
        end
    end
    
    -- Check if sprite is valid
    local sprite = getSprite(spriteName)
    if not sprite then
        TileEditorUtils.error("Invalid sprite:", spriteName)
        return false
    end

    if not dummyItem then
        dummyItem = InventoryItemFactory.CreateItem("Base.Plank")
    end
    
    -- Place using ISMoveableSpriteProps to ensure consistency with cursor tool
    if dummyItem then
        local isoSprite = IsoObject.new(square, spriteName)
        local spriteProps = ISMoveableSpriteProps.new(isoSprite:getSprite())
        spriteProps.rawWeight = 10
        spriteProps:placeMoveableInternal(square, dummyItem, spriteName)
    end
    
    return true
end

-- ============================================================================
-- Clear Actions
-- ============================================================================

--- Clears all floor tiles in the selection
-- @param selection TileEditorSelection instance
-- @param undoManager TileEditorUndo instance
-- @return number Number of tiles cleared
function TileEditorActions:clearFloor(selection, undoManager)
    local changes = {}
    local tiles = selection:getAffectedTiles()
    local clearedCount = 0
    
    for _, pos in ipairs(tiles) do
        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        if square then
            local floor = square:getFloor()
            local oldFloorSprite = floor and floor:getSprite() and floor:getSprite():getName()
            local removed = false
            
            local objects = square:getObjects()
            
            -- Iterate backwards when removing
            for i = objects:size(), 1, -1 do
                local obj = objects:get(i - 1)
                if instanceof(obj, "IsoObject") and
                   not instanceof(obj, "IsoMovingObject") and
                   obj:isFloor() then
                    square:transmitRemoveItemFromSquare(obj)
                    clearedCount = clearedCount + 1
                    removed = true
                end
            end
            
            if removed and oldFloorSprite then
                table.insert(changes, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    ops = {{ type = "undo_set_floor", sprite = oldFloorSprite }}
                })
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("clear_floor", changes)
    end
    
    TileEditorUtils.debug("Cleared", clearedCount, "floor tiles")
    return clearedCount
end

--- Clears all non-floor tiles in the selection
-- @param selection TileEditorSelection instance
-- @param undoManager TileEditorUndo instance
-- @return number Number of tiles cleared
function TileEditorActions:clearOther(selection, undoManager)
    local changes = {}
    local tiles = selection:getAffectedTiles()
    local clearedCount = 0
    
    for _, pos in ipairs(tiles) do
        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        if square then
            local ops = {}
            local objects = square:getObjects()
            
            -- Iterate backwards to remove and capture
            for i = objects:size() - 1, 0, -1 do
                local obj = objects:get(i)
                if instanceof(obj, "IsoObject") and
                   not instanceof(obj, "IsoMovingObject") and
                   not obj:isFloor() then
                    
                    local sprite = obj:getSprite()
                    if sprite and sprite:getName() then
                        table.insert(ops, {
                            type = "undo_add_object",
                            sprite = sprite:getName(),
                            index = i
                        })
                    end
                    
                    square:transmitRemoveItemFromSquare(obj)
                    clearedCount = clearedCount + 1
                end
            end
            
            if #ops > 0 then
                table.insert(changes, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    ops = ops
                })
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("clear_other", changes)
    end
    
    TileEditorUtils.debug("Cleared", clearedCount, "non-floor tiles")
    return clearedCount
end

-- ============================================================================
-- Fill Actions
-- ============================================================================

--- Fills the selection with tiles from the palette
-- @param selection TileEditorSelection instance
-- @param palette TileEditorPalette instance
-- @param mode "single", "random", or "cycle"
-- @param undoManager TileEditorUndo instance
-- @param cycleIndex Current index for cycle mode (1-based)
-- @return number Number of tiles placed
function TileEditorActions:fill(selection, palette, mode, undoManager, cycleIndex)
    if palette:isEmpty() then
        TileEditorUtils.error("Palette is empty")
        return 0
    end
    
    local changes = {}
    local tiles = selection:getAffectedTiles()
    local placedCount = 0
    local currentCycleIndex = cycleIndex or 1
    local paletteSize = palette:getTileCount()
    
    for _, pos in ipairs(tiles) do
        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        
        -- Create square if it doesn't exist
        if not square and TileEditorUtils.isValidSquare(pos.x, pos.y, pos.z) then
            square = getCell():createNewGridSquare(pos.x, pos.y, pos.z, true)
        end
        
        if square then
            local previousFloor = square:getFloor() and square:getFloor():getSprite() and square:getFloor():getSprite():getName()
            local spriteName
            
            -- Select sprite based on mode
            if mode == "single" then
                spriteName = palette:getFirstTile()
            elseif mode == "random" then
                spriteName = palette:getRandomTile()
            elseif mode == "cycle" then
                spriteName = palette:getTile(currentCycleIndex)
                -- Advance to next tile in palette
                currentCycleIndex = (currentCycleIndex % paletteSize) + 1
            end
            
            if spriteName and self:placeTile(square, spriteName) then
                placedCount = placedCount + 1
                
                local ops = {}
                local currentFloor = square:getFloor() and square:getFloor():getSprite() and square:getFloor():getSprite():getName()
                
                if currentFloor ~= previousFloor then
                    -- Floor changed
                    table.insert(ops, { type = "undo_set_floor", sprite = previousFloor })
                else
                    -- Object added
                    table.insert(ops, { type = "undo_remove_object", sprite = spriteName })
                end
                
                table.insert(changes, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    ops = ops
                })
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("fill", changes)
    end
    
    TileEditorUtils.debug("Placed", placedCount, "tiles in", mode, "mode")
    return placedCount
end

--- Fills a random percentage of tiles in the selection
-- @param selection TileEditorSelection instance
-- @param palette TileEditorPalette instance
-- @param mode "single", "random", or "cycle"
-- @param percentage Percentage of tiles to fill (0-100)
-- @param undoManager TileEditorUndo instance
-- @param cycleIndex Current index for cycle mode (1-based)
-- @return number Number of tiles placed
function TileEditorActions:partialFill(selection, palette, mode, percentage, undoManager, cycleIndex)
    if palette:isEmpty() then
        TileEditorUtils.error("Palette is empty")
        return 0
    end
    
    local changes = {}
    local allTiles = selection:getAffectedTiles()
    
    -- Calculate how many tiles to fill
    local numToFill = math.floor(#allTiles * (percentage / 100))
    if numToFill == 0 then
        TileEditorUtils.debug("Percentage too low, no tiles to fill")
        return 0
    end
    
    -- Fisher-Yates shuffle to randomize tile selection
    for i = #allTiles, 2, -1 do
        local j = ZombRand(i) + 1
        allTiles[i], allTiles[j] = allTiles[j], allTiles[i]
    end
    
    -- Take first numToFill tiles
    local tilesToFill = {}
    for i = 1, numToFill do
        table.insert(tilesToFill, allTiles[i])
    end
    
    local placedCount = 0
    local currentCycleIndex = cycleIndex or 1
    local paletteSize = palette:getTileCount()
    
    -- Fill selected tiles
    for _, pos in ipairs(tilesToFill) do
        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        
        -- Create square if it doesn't exist
        if not square and TileEditorUtils.isValidSquare(pos.x, pos.y, pos.z) then
            square = getCell():createNewGridSquare(pos.x, pos.y, pos.z, true)
        end
        
        if square then
            local previousFloor = square:getFloor() and square:getFloor():getSprite() and square:getFloor():getSprite():getName()
            local spriteName
            
            -- Select sprite based on mode
            if mode == "single" then
                spriteName = palette:getFirstTile()
            elseif mode == "random" then
                spriteName = palette:getRandomTile()
            elseif mode == "cycle" then
                spriteName = palette:getTile(currentCycleIndex)
                -- Advance to next tile in palette
                currentCycleIndex = (currentCycleIndex % paletteSize) + 1
            end
            
            if spriteName and self:placeTile(square, spriteName) then
                placedCount = placedCount + 1
                
                local ops = {}
                local currentFloor = square:getFloor() and square:getFloor():getSprite() and square:getFloor():getSprite():getName()
                
                if currentFloor ~= previousFloor then
                    -- Floor changed
                    table.insert(ops, { type = "undo_set_floor", sprite = previousFloor })
                else
                    -- Object added
                    table.insert(ops, { type = "undo_remove_object", sprite = spriteName })
                end
                
                table.insert(changes, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    ops = ops
                })
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("partial_fill", changes)
    end
    
    TileEditorUtils.debug("Placed", placedCount, "tiles (", percentage, "% of", #allTiles, ")")
    return placedCount
end

-- ============================================================================
-- Batch Processing (for large selections)
-- ============================================================================

--- Processes tiles in batches to prevent performance issues
-- @param tiles Array of tile positions
-- @param batchSize Number of tiles per batch
-- @param processFunc Function to process each batch
-- @param callback Function to call when complete
function TileEditorActions:processBatches(tiles, batchSize, processFunc, callback)
    local currentBatch = 1
    local totalBatches = math.ceil(#tiles / batchSize)
    
    local function processBatch()
        local startIdx = (currentBatch - 1) * batchSize + 1
        local endIdx = math.min(currentBatch * batchSize, #tiles)
        
        local batch = {}
        for i = startIdx, endIdx do
            table.insert(batch, tiles[i])
        end
        
        processFunc(batch)
        
        currentBatch = currentBatch + 1
        
        if currentBatch <= totalBatches then
            -- Schedule next batch
            Events.OnTick.Add(function()
                processBatch()
                Events.OnTick.Remove(processBatch)
            end)
        else
            -- All batches complete
            if callback then
                callback()
            end
        end
    end
    
    processBatch()
end

--- Replaces all instances of sourceTile with targetTile in the selection
-- @param selection TileEditorSelection instance
-- @param sourceTile string Sprite name to find
-- @param targetTile string Sprite name to replace with
-- @param undoManager TileEditorUndo instance
-- @return number Number of tiles replaced
function TileEditorActions:replace(selection, sourceTile, targetTile, undoManager)
    if not sourceTile or not targetTile then
        TileEditorUtils.error("Replace called with missing tiles")
        return 0
    end
    
    local changes = {}
    local tiles = selection:getAffectedTiles()
    local replacedCount = 0
    
    for _, pos in ipairs(tiles) do
        local square = getCell():getGridSquare(pos.x, pos.y, pos.z)
        if square then
            local ops = {}
            local squareChanged = false
            
            -- 1. Handle Floor Replacement
            local floor = square:getFloor()
            if floor and floor:getSprite() and floor:getSprite():getName() == sourceTile then
                local oldFloorSprite = floor:getSprite():getName()
                square:addFloor(targetTile)
                squareChanged = true
                replacedCount = replacedCount + 1
                
                table.insert(ops, { type = "undo_set_floor", sprite = oldFloorSprite })
            end
            
            -- 2. Handle Object Replacement
            -- We need to preserve the order of objects.
            -- Strategy: Capture all objects, clear square, re-add (replacing matches)
            
            local objects = square:getObjects()
            local currentObjects = {}
            local hasObjectMatch = false
            
            -- Copy objects to Lua table
            for i = 0, objects:size() - 1 do
                local obj = objects:get(i)
                table.insert(currentObjects, obj)
                
                -- Check for match (excluding floor which we handled/skipped)
                if not obj:isFloor() then
                    local sprite = obj:getSprite()
                    if sprite and sprite:getName() == sourceTile then
                        hasObjectMatch = true
                    end
                end
            end
            
            if hasObjectMatch then
                -- Clear all objects from square
                objects:clear()
                
                for i, obj in ipairs(currentObjects) do
                    if obj:isFloor() then
                        -- Add floor back (it might have been replaced already above, so 'obj' is the current floor)
                        objects:add(obj)
                    else
                        -- It's a non-floor object
                        local sprite = obj:getSprite()
                        if sprite and sprite:getName() == sourceTile then
                            -- Replace this object
                            self:placeTile(square, targetTile)
                            squareChanged = true
                            replacedCount = replacedCount + 1

                            objects:add(obj) -- Add back to transmitRemoveItemFromSquare works
                            -- remove on server
                            square:transmitRemoveItemFromSquare(obj)
                            square:RemoveTileObject(obj)
                            
                            -- Record undo ops
                            -- Undo: Remove new object, Add old object at original index
                            -- Note: i-1 is the original index (0-based)
                            table.insert(ops, { type = "undo_remove_object", sprite = targetTile })
                            table.insert(ops, { type = "undo_add_object", sprite = sourceTile, index = i - 1 })
                        else
                            -- Keep existing object
                            objects:add(obj)
                        end
                    end
                end
            end
            
            if squareChanged then
            square:RecalcProperties();
            square:RecalcAllWithNeighbours(true);
                table.insert(changes, {
                    x = pos.x,
                    y = pos.y,
                    z = pos.z,
                    ops = ops
                })
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("replace", changes)
    end
    
    TileEditorUtils.debug("Replaced", replacedCount, "tiles")
    return replacedCount
end

--- Flood fills from a starting point
-- @param startPoint {x, y, z}
-- @param fillTile string Sprite name to place
-- @param mode string "floor" or "roof"
-- @param maxDistance number Maximum distance to fill
-- @param undoManager TileEditorUndo instance
-- @return number Number of tiles placed
function TileEditorActions:floodFill(startPoint, fillTile, mode, maxDistance, undoManager)
    if not startPoint or not fillTile then return 0 end
    
    local startX, startY, startZ = startPoint.x, startPoint.y, startPoint.z
    local targetZ = startZ
    if mode == "roof" then
        targetZ = startZ + 1
    end
    
    local changes = {}
    local placedCount = 0
    
    -- BFS State
    local queue = {}
    local visited = {} -- Key: "x,y"
    local directions = {
        {x=0, y=1},  -- South
        {x=0, y=-1}, -- North
        {x=1, y=0},  -- East
        {x=-1, y=0}  -- West
    }
    
    -- Add start point
    table.insert(queue, {x=startX, y=startY, dist=0})
    visited[startX .. "," .. startY] = true
    
    local head = 1
    while head <= #queue do
        local current = queue[head]
        head = head + 1
        
        -- Process current tile (Place the tile)
        local placeX, placeY = current.x, current.y
        
        -- Get or create square at target Z for placement
        local placeSquare = getCell():getGridSquare(placeX, placeY, targetZ)
        if not placeSquare and TileEditorUtils.isValidSquare(placeX, placeY, targetZ) then
            placeSquare = getCell():createNewGridSquare(placeX, placeY, targetZ, true)
        end
        
        if placeSquare then
            local previousFloor = placeSquare:getFloor() and placeSquare:getFloor():getSprite() and placeSquare:getFloor():getSprite():getName()

            if placeSquare:addFloor(fillTile) then
                placedCount = placedCount + 1
                
                local ops = {}
                local currentFloor = placeSquare:getFloor() and placeSquare:getFloor():getSprite() and placeSquare:getFloor():getSprite():getName()
                
                if currentFloor ~= previousFloor then
                    -- Floor changed
                    table.insert(ops, { type = "undo_set_floor", sprite = previousFloor })
                else
                    -- Object added
                    table.insert(ops, { type = "undo_remove_object", sprite = fillTile })
                end
                
                table.insert(changes, {
                    x = placeX,
                    y = placeY,
                    z = targetZ,
                    ops = ops
                })
            end
        end
        
        -- Expand to neighbors if within distance
        if current.dist < maxDistance then
            local currentSquare = getCell():getGridSquare(current.x, current.y, startZ)
            -- If current square doesn't exist at startZ, we can't check walls, but we can probably still expand?
            -- Assuming we are walking on "something" or just expanding in space.
            -- If square is nil, it has no walls, so we can expand.
            
            for _, dir in ipairs(directions) do
                local nextX, nextY = current.x + dir.x, current.y + dir.y
                local key = nextX .. "," .. nextY
                
                if not visited[key] then
                    local blocked = false
                    
                    if currentSquare then
                        local nextSquare = getCell():getGridSquare(nextX, nextY, startZ)
                        -- Check for walls/doors
                        if nextSquare and (currentSquare:isWallTo(nextSquare) or currentSquare:isDoorTo(nextSquare) or currentSquare:isWindowTo(nextSquare)) then
                            blocked = true
                        end
                        
                        -- Also check from nextSquare back to currentSquare (walls can be one-sided?)
                        -- Usually isWallTo checks the wall between them.
                        -- But let's stick to the user's instruction: "stop if currentSquare:isWallTo(nextSquare) or currentSquare:isDoorTo(nextSquare) is true"
                    end
                    
                    if not blocked then
                        visited[key] = true
                        table.insert(queue, {x=nextX, y=nextY, dist=current.dist + 1})
                    end
                end
            end
        end
    end
    
    if #changes > 0 then
        undoManager:pushOperation("flood_fill", changes)
    end
    
    TileEditorUtils.debug("Flood filled", placedCount, "tiles")
    return placedCount
end

--- Moves an object up or down in the layer list
-- @param square IsoGridSquare
-- @param object IsoObject The object to move
-- @param direction number -1 for up, 1 for down
-- @param undoManager TileEditorUndo instance
-- @return boolean Success
function TileEditorActions:moveObject(square, object, direction, undoManager)
    if not square or not object then return false end
    
    local objects = square:getObjects()
    local index = objects:indexOf(object)
    
    if index == -1 then return false end
    
    local sprite = object:getSprite()
    local spriteName = sprite and sprite:getName()
    
    if direction == -1 then -- Move Up
        if index > 0 then
            -- Swap with previous
            local prev = objects:get(index - 1)
            objects:set(index - 1, object)
            objects:set(index, prev)
            
            if isClient() then
                sendClientCommand(getPlayer(), 'WAT', 'tileUp', {x=square:getX(), y=square:getY(), z=square:getZ(), i=index})
            end
            
            if undoManager and spriteName then
                undoManager:pushOperation("move_up", {{
                    x = square:getX(),
                    y = square:getY(),
                    z = square:getZ(),
                    ops = {{
                        type = "undo_move_down", -- Undo of move up is move down
                        sprite = spriteName
                    }}
                }})
            end
            return true
        end
    elseif direction == 1 then -- Move Down
        if index < objects:size() - 1 then
            -- Swap with next
            local nextObj = objects:get(index + 1)
            objects:set(index + 1, object)
            objects:set(index, nextObj)
            
            if isClient() then
                sendClientCommand(getPlayer(), 'WAT', 'tileDown', {x=square:getX(), y=square:getY(), z=square:getZ(), i=index})
            end
            
            if undoManager and spriteName then
                undoManager:pushOperation("move_down", {{
                    x = square:getX(),
                    y = square:getY(),
                    z = square:getZ(),
                    ops = {{
                        type = "undo_move_up", -- Undo of move down is move up
                        sprite = spriteName
                    }}
                }})
            end
            return true
        end
    end
    
    return false
end

--- Attaches an object to the one above it (render order wise)
-- @param square IsoGridSquare
-- @param object IsoObject The object to attach
-- @param index number The index of the object in the square's object list
-- @param undoManager TileEditorUndo instance
-- @return boolean Success
function TileEditorActions:attachUp(square, object, index, undoManager)
    if not square or not object or not index then return false end
    
    -- Must have an object above (index - 1)
    if index <= 0 then return false end
    
    local objects = square:getObjects()
    local targetObject = objects:get(index - 1)
    
    if not targetObject then return false end
    
    local sprite = object:getSprite()
    local spriteName = sprite and sprite:getName()
    
    if not spriteName then return false end
    
    -- Perform Attachment
    targetObject:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0)
    
    -- Send to server
    if isClient() then
        sendClientCommand(getPlayer(), 'WAT', 'addAttachedAnim', {
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            targetIndex = index - 1,
            spriteName = spriteName
        })
    end
    
    -- Prepare Undo Operations
    local ops = {}
    
    -- 1. Undo for Attachment: Remove the attached anim
    -- The new attachment should be at the end of the list
    local attachedSprites = targetObject:getAttachedAnimSprite()
    local attachedIndex = attachedSprites and (attachedSprites:size() - 1) or 0
    
    table.insert(ops, {
        type = "undo_remove_attached_anim",
        objectIndex = index - 1,
        attachedIndex = attachedIndex
    })
    
    -- 2. Undo for Deletion: Restore the original object
    -- We are about to delete 'object' at 'index'
    table.insert(ops, {
        type = "undo_add_object",
        sprite = spriteName,
        index = index
    })
    
    -- Delete the original object
    square:transmitRemoveItemFromSquare(object)
    -- square:RemoveTileObject(object) -- transmitRemoveItemFromSquare usually handles removal on client too or syncs it
    
    -- Push Undo
    if undoManager then
        undoManager:pushOperation("attach_up", {{
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            ops = ops
        }})
    end
    
    return true
end

--- Detaches an attached sprite and turns it into a real object
-- @param square IsoGridSquare
-- @param object IsoObject The object with the attachment
-- @param index number The index of the object in the square's object list
-- @param attachedIndex number The index of the attached sprite
-- @param undoManager TileEditorUndo instance
-- @return boolean Success
function TileEditorActions:detachDown(square, object, index, attachedIndex, undoManager)
    if not square or not object or not index or attachedIndex == nil then return false end
    
    local attachedSprites = object:getAttachedAnimSprite()
    if not attachedSprites or attachedIndex >= attachedSprites:size() then return false end
    
    local spriteInstance = attachedSprites:get(attachedIndex)
    local spriteName
    if spriteInstance and spriteInstance:getParentSprite() then
        spriteName = spriteInstance:getParentSprite():getName()
    end
    
    if not spriteName then return false end
    
    -- Remove attachment
    object:RemoveAttachedAnim(attachedIndex)
    
    if isClient() then
        sendClientCommand(getPlayer(), 'WAT', 'removeAttachedAnim', {
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            spriteName = object:getSprite():getName(),
            index = attachedIndex
        })
    end
    
    -- Add new object at index + 1
    local dummyItem = InventoryItemFactory.CreateItem("Base.Plank")
    if dummyItem then
        local isoSprite = IsoObject.new(square, spriteName)
        local props = ISMoveableSpriteProps.new(isoSprite:getSprite())
        props.rawWeight = 10
        
        local objects = square:getObjects()
        local tempArray = ArrayList:new()
        for j=0, objects:size()-1 do
            tempArray:add(objects:get(j))
        end
        
        objects:clear()
        
        -- Add objects up to parent (inclusive)
        for j=0, index do
            objects:add(tempArray:get(j))
        end
        
        -- Add new object
        props:placeMoveableInternal(square, dummyItem, spriteName)
        
        -- Add remaining objects
        for j=index + 1, tempArray:size()-1 do
            objects:add(tempArray:get(j))
        end
    end
    
    if undoManager then
        local ops = {}
        
        -- Undo: Remove the new object
        table.insert(ops, {
            type = "undo_remove_object",
            sprite = spriteName
        })
        
        -- Undo: Add back the attachment
        table.insert(ops, {
            type = "undo_add_attached_anim",
            objectIndex = index,
            spriteName = spriteName
        })
        
        undoManager:pushOperation("detach_down", {{
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            ops = ops
        }})
    end
    
    return true
end

--- Deletes a single tile/object from a square
-- @param square IsoGridSquare
-- @param item table Item struct from cursor (object, type, attachedIndex)
-- @param undoManager TileEditorUndo instance
-- @return boolean Success
function TileEditorActions:deleteTile(square, item, undoManager)
    if not square or not item then return false end
    
    local object = item.object
    local type = item.type
    
    if type == "primary" or type == "object" then
        local sprite = object:getSprite()
        local spriteName = sprite and sprite:getName()
        local index = -1
        local objects = square:getObjects()
        for i=0, objects:size()-1 do
            if objects:get(i) == object then
                index = i
                break
            end
        end
        
        square:transmitRemoveItemFromSquare(object)
        
        if undoManager and spriteName and index ~= -1 then
            undoManager:pushOperation("delete_tile", {{
                x = square:getX(),
                y = square:getY(),
                z = square:getZ(),
                ops = {{
                    type = "undo_add_object",
                    sprite = spriteName,
                    index = index
                }}
            }})
        end
        
    elseif type == "overlay" then
        local overlay = object:getOverlaySprite()
        local spriteName = overlay and overlay:getName()
        
        object:setOverlaySprite(nil)
        -- object:transmitUpdatedSprite() -- If available
        
    elseif type == "attached" then
        local index = item.attachedIndex or item.animIndex
        if index ~= nil then
            object:RemoveAttachedAnim(index)
            -- send to server
            if isClient() then
                sendClientCommand(getPlayer(), 'WAT', 'removeAttachedAnim', {
                    x = square:getX(),
                    y = square:getY(),
                    z = square:getZ(),
                    spriteName = object:getSprite():getName(),
                    index = index
                })
            end
        end
    end
    
    return true
end

return TileEditorActions
