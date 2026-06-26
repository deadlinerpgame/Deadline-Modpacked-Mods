require "ISMoveableSpriteProps"

local original_placeMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal

function ISMoveableSpriteProps:placeMoveableInternal(_square, _item, _spriteName)
    -- Check if we should capture undo state
    -- We only want to do this for the Tile Cursor tool, as other tools (Bulk) handle their own undo
    
    local shouldCapture = false
    local drag = getCell():getDrag(0)
    
    -- Check if active drag is the Tile Cursor
    if drag and drag.isTileCursor then
        -- Check if Tile Editor is open
        if TileEditorMain and TileEditorMain.instance then
            shouldCapture = true
        end
    end
    
    if shouldCapture then
        local undoManager = TileEditorMain.instance.undoManager
        if undoManager then
            local ops = {}
            
            -- Determine if we are placing a floor or object
            -- We create a temporary object to check its properties
            local tempObj = IsoObject.new(_square, _spriteName)
            local isFloor = tempObj:isFloor()
            
            if isFloor then
                -- We are replacing the floor
                local currentFloor = _square:getFloor()
                local oldFloorSprite = currentFloor and currentFloor:getSprite() and currentFloor:getSprite():getName()
                
                if oldFloorSprite then
                    table.insert(ops, { type = "undo_set_floor", sprite = oldFloorSprite })
                end
            else
                -- We are adding an object
                -- Undo: Remove the added object
                table.insert(ops, { type = "undo_remove_object", sprite = _spriteName })
            end
            
            if #ops > 0 then
                local change = {
                    x = _square:getX(),
                    y = _square:getY(),
                    z = _square:getZ(),
                    ops = ops
                }
                
                -- Push to undo stack
                undoManager:pushOperation("place_tile_cursor", {change})
            end
        end
    end

    -- Call original function
    local ret = original_placeMoveableInternal(self, _square, _item, _spriteName)

    if drag and drag.isTileCursor then
        -- Check if Tile Editor is open
        if TileEditorMain and TileEditorMain.instance then
            TileEditorMain.instance:refresh()
        end
    end

    return ret
end
