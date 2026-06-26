-- TileEditorUndo.lua
-- Undo stack management for the Tile Editor system

require "ISMoveableSpriteProps"

TileEditorUndo = {}

-- ============================================================================
-- Constructor
-- ============================================================================

function TileEditorUndo:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    o.stack = {}
    o.maxStackSize = 50
    
    return o
end

-- ============================================================================
-- Stack Management
-- ============================================================================

--- Pushes a new operation onto the undo stack
-- @param actionType Type of action (fill, clear_floor, clear_other, partial_fill)
-- @param changes Array of change records
function TileEditorUndo:pushOperation(actionType, changes)
    if not changes or #changes == 0 then
        TileEditorUtils.debug("No changes to push to undo stack")
        return
    end
    
    local operation = {
        action = actionType,
        timestamp = getTimestampMs(),
        changes = changes
    }
    
    table.insert(self.stack, operation)
    
    -- Limit stack size
    while #self.stack > self.maxStackSize do
        table.remove(self.stack, 1)
    end
    
    TileEditorUtils.debug("Pushed", actionType, "operation with", #changes, "changes to undo stack")
end

--- Performs an undo operation
-- @return boolean Success
function TileEditorUndo:undo()
    if #self.stack == 0 then
        TileEditorUtils.debug("Undo stack is empty")
        return false
    end
    
    local operation = table.remove(self.stack)
    
    TileEditorUtils.debug("Undoing", operation.action, "with", #operation.changes, "changes")
    
    for _, change in ipairs(operation.changes) do
        self:applyChange(change)
    end
    
    if TileEditorMain.instance then
        TileEditorMain.instance:refresh()
    end
    
    return true
end

--- Applies a change to a square
-- @param change Change record containing coordinates and operations
function TileEditorUndo:applyChange(change)
    local square = getCell():getGridSquare(change.x, change.y, change.z)
    
    if not square then
        TileEditorUtils.debug("Square doesn't exist at", change.x, change.y, change.z, "- skipping undo")
        return
    end

    for _, op in ipairs(change.ops) do
        if op.type == "undo_add_object" then
            self:restoreObject(square, op.sprite, op.index)
        elseif op.type == "undo_remove_object" then
            self:removeObject(square, op.sprite)
        elseif op.type == "undo_set_floor" then
            self:restoreFloor(square, op.sprite)
        elseif op.type == "undo_move_up" then
            self:moveUp(square, op.sprite)
        elseif op.type == "undo_move_down" then
            self:moveDown(square, op.sprite)
        elseif op.type == "undo_remove_attached_anim" then
            self:removeAttachedAnim(square, op.objectIndex, op.attachedIndex)
        elseif op.type == "undo_add_attached_anim" then
            self:addAttachedAnim(square, op.objectIndex, op.spriteName)
        end
    end
end

--- Moves an object up in the list (swaps with previous)
-- @param square IsoGridSquare
-- @param spriteName Sprite name to move
function TileEditorUndo:moveUp(square, spriteName)
    local objects = square:getObjects()
    local index = -1
    local object = nil
    
    -- Find object
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == spriteName then
                index = i
                object = obj
                break
            end
        end
    end
    
    if index > 0 and object then
        -- Swap with previous
        local prev = objects:get(index - 1)
        objects:set(index - 1, object)
        objects:set(index, prev)
        
        if isClient() then
            sendClientCommand(getPlayer(), 'WAT', 'tileUp', {x=square:getX(), y=square:getY(), z=square:getZ(), i=index})
        end
    end
end

--- Moves an object down in the list (swaps with next)
-- @param square IsoGridSquare
-- @param spriteName Sprite name to move
function TileEditorUndo:moveDown(square, spriteName)
    local objects = square:getObjects()
    local index = -1
    local object = nil
    
    -- Find object
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == spriteName then
                index = i
                object = obj
                break
            end
        end
    end
    
    if index ~= -1 and index < objects:size() - 1 and object then
        -- Swap with next
        local nextObj = objects:get(index + 1)
        objects:set(index + 1, object)
        objects:set(index, nextObj)
        
        if isClient() then
            sendClientCommand(getPlayer(), 'WAT', 'tileDown', {x=square:getX(), y=square:getY(), z=square:getZ(), i=index})
        end
    end
end

--- Restores an object to the square
-- @param square IsoGridSquare
-- @param spriteName Sprite name
-- @param index Optional index to insert at
function TileEditorUndo:restoreObject(square, spriteName, index)
    local sprite = getSprite(spriteName)
    if not sprite then
        TileEditorUtils.error("Cannot restore object - sprite not found:", spriteName)
        return
    end

    local dummyItem = InventoryItemFactory.CreateItem("Base.Plank")
    if dummyItem then
        local isoSprite = IsoObject.new(square, spriteName)
        local props = ISMoveableSpriteProps.new(isoSprite:getSprite())
        props.rawWeight = 10

        
        if index ~= nil then
            local objects = square:getObjects()
            local tempArray = ArrayList:new()
            for j=0, objects:size()-1 do
                tempArray:add(objects:get(j))
            end
            square:getObjects():clear()
            if index > 0 then
                for j=0, index - 1 do
                    square:getObjects():add(tempArray:get(j))
                end
            end
            props:placeMoveableInternal(square, dummyItem, spriteName)
            if index < tempArray:size() then
                for j=index, tempArray:size()-1 do
                    square:getObjects():add(tempArray:get(j))
                end
            end
        else
            props:placeMoveableInternal(square, dummyItem, spriteName)
        end
    end
end

--- Removes an attached animation
-- @param square IsoGridSquare
-- @param objectIndex Index of the object having the attachment
-- @param attachedIndex Index of the attached animation
function TileEditorUndo:removeAttachedAnim(square, objectIndex, attachedIndex)
    if not square or not objectIndex or not attachedIndex then return end
    
    local objects = square:getObjects()
    if objectIndex >= 0 and objectIndex < objects:size() then
        local object = objects:get(objectIndex)
        if object then
            object:RemoveAttachedAnim(attachedIndex)
            if isClient() then
                local sprite = object:getSprite()
                local spriteName = sprite and sprite:getName()
                if spriteName then
                    sendClientCommand(getPlayer(), 'WAT', 'removeAttachedAnim', {
                        x = square:getX(),
                        y = square:getY(),
                        z = square:getZ(),
                        spriteName = spriteName,
                        index = attachedIndex
                    })
                end
            end
        end
    end
end

--- Adds an attached animation (for undoing detach)
-- @param square IsoGridSquare
-- @param objectIndex Index of the object to attach to
-- @param spriteName Sprite to attach
function TileEditorUndo:addAttachedAnim(square, objectIndex, spriteName)
    if not square or not objectIndex or not spriteName then return end
    
    local objects = square:getObjects()
    if objectIndex >= 0 and objectIndex < objects:size() then
        local object = objects:get(objectIndex)
        if object then
            local sprite = getSprite(spriteName)
            if sprite then
                object:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0)
                
                if isClient() then
                    sendClientCommand(getPlayer(), 'WAT', 'addAttachedAnim', {
                        x = square:getX(),
                        y = square:getY(),
                        z = square:getZ(),
                        targetIndex = objectIndex,
                        spriteName = spriteName
                    })
                end
            end
        end
    end
end

--- Removes an object from the square
-- @param square IsoGridSquare
-- @param spriteName Sprite name to remove
function TileEditorUndo:removeObject(square, spriteName)
    local objects = square:getObjects()
    -- Iterate backwards to safely remove
    -- We remove the most recently added one (highest index) that matches
    for i = objects:size(), 1, -1 do
        local obj = objects:get(i - 1)
        if instanceof(obj, "IsoObject") and not instanceof(obj, "IsoMovingObject") then
            local sprite = obj:getSprite()
            if sprite and sprite:getName() == spriteName then
                square:transmitRemoveItemFromSquare(obj)
                square:RemoveTileObject(obj)
                return -- Remove only one instance
            end
        end
    end
end

--- Restores a floor tile
-- @param square IsoGridSquare
-- @param spriteName Sprite name
function TileEditorUndo:restoreFloor(square, spriteName)
    if spriteName then
        square:addFloor(spriteName)
    end
end

--- Legacy: Restores a single tile
function TileEditorUndo:restoreTileLegacy(square, tileData)
    if not square or not tileData or not tileData.spriteName then
        return
    end
    
    local spriteName = tileData.spriteName
    local isFloor = tileData.isFloor
    
    local sprite = getSprite(spriteName)
    if not sprite then return end
    
    if isFloor then
        square:addFloor(spriteName)
    else
        local dummyItem = InventoryItemFactory.CreateItem("Base.Plank")
        if dummyItem then
            local isoSprite = IsoObject.new(square, spriteName)
            local props = ISMoveableSpriteProps.new(isoSprite:getSprite())
            props.rawWeight = 10
            props:placeMoveableInternal(square, dummyItem, spriteName)
        end
    end
end

--- Clears the undo stack
function TileEditorUndo:clear()
    self.stack = {}
    TileEditorUtils.debug("Cleared undo stack")
end

--- Checks if undo is available
-- @return boolean
function TileEditorUndo:canUndo()
    return #self.stack > 0
end

--- Gets the current stack size
-- @return number
function TileEditorUndo:getStackSize()
    return #self.stack
end

--- Gets the maximum stack size
-- @return number
function TileEditorUndo:getMaxStackSize()
    return self.maxStackSize
end

--- Sets the maximum stack size
-- @param size New maximum size
function TileEditorUndo:setMaxStackSize(size)
    if size < 1 then
        TileEditorUtils.error("Invalid max stack size:", size)
        return
    end
    
    self.maxStackSize = size
    
    -- Trim stack if needed
    while #self.stack > self.maxStackSize do
        table.remove(self.stack, 1)
    end
    
    TileEditorUtils.debug("Set max stack size to", size)
end

--- Gets info about the last operation
-- @return string Description or nil
function TileEditorUndo:getLastOperationInfo()
    if #self.stack == 0 then
        return nil
    end
    
    local operation = self.stack[#self.stack]
    local actionName = operation.action:gsub("_", " "):gsub("^%l", string.upper)
    
    return string.format("%s (%d changes)", actionName, #operation.changes)
end

--- Gets the entire stack info
-- @return Array of operation descriptions
function TileEditorUndo:getStackInfo()
    local info = {}
    
    for i, operation in ipairs(self.stack) do
        local actionName = operation.action:gsub("_", " "):gsub("^%l", string.upper)
        table.insert(info, string.format("%d. %s (%d changes)", 
                                        i, actionName, #operation.changes))
    end
    
    return info
end

--- Peeks at the top operation without removing it
-- @return table Operation or nil
function TileEditorUndo:peek()
    if #self.stack == 0 then
        return nil
    end
    
    return self.stack[#self.stack]
end

--- Gets memory usage estimate
-- @return number Approximate bytes used
function TileEditorUndo:getMemoryUsage()
    local totalChanges = 0
    
    for _, operation in ipairs(self.stack) do
        totalChanges = totalChanges + #operation.changes
    end
    
    -- Rough estimate: each change is about 200 bytes
    -- (coordinates, sprite names, metadata)
    return totalChanges * 200
end

--- Optimizes the stack by removing old operations if memory is high
-- @param maxMemoryBytes Maximum memory to use (default: 10MB)
function TileEditorUndo:optimize(maxMemoryBytes)
    maxMemoryBytes = maxMemoryBytes or 10485760 -- 10MB default
    
    while self:getMemoryUsage() > maxMemoryBytes and #self.stack > 1 do
        table.remove(self.stack, 1)
        TileEditorUtils.debug("Removed old operation to optimize memory")
    end
end

return TileEditorUndo