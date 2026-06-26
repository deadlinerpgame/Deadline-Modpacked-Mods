-- TileEditorSelection.lua
-- Selection shapes and visualization for the Tile Editor system

require "GroundHighlighter"

TileEditorSelection = {}
TileEditorSelection.instance = nil

-- ============================================================================
-- Constructor
-- ============================================================================

function TileEditorSelection:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    o.type = "point"  -- point, rect, circle, box, ring
    o.isSelecting = false
    o.startPoint = nil  -- {x, y, z}
    o.endPoint = nil    -- {x, y, z}
    o.highlighter = nil
    
    -- Selection parameters
    o.centerX = 0
    o.centerY = 0
    o.z = 0
    o.x1 = 0
    o.y1 = 0
    o.x2 = 0
    o.y2 = 0
    o.radius = 5
    o.innerRadius = 3
    o.ringThickness = 2  -- Thickness for ring selection
    o.boxThickness = 1   -- Thickness for box selection
    
    -- Highlighting settings
    o.highlightColor = {r=0.2, g=0.8, b=0.2, a=0.8}
    o.maxHighlightDistance = 50  -- Limit highlighting to prevent performance issues
    
    return o
end

-- ============================================================================
-- Singleton Access
-- ============================================================================

function TileEditorSelection:getInstance()
    if not TileEditorSelection.instance then
        TileEditorSelection.instance = TileEditorSelection:new()
    end
    return TileEditorSelection.instance
end

-- ============================================================================
-- Selection Type Management
-- ============================================================================

--- Sets the selection type
-- @param selectionType Type (point, rect, circle, box, ring)
function TileEditorSelection:setType(selectionType)
    local validTypes = {point=true, rect=true, circle=true, box=true, ring=true}
    
    if not validTypes[selectionType] then
        TileEditorUtils.error("Invalid selection type:", selectionType)
        return false
    end
    
    self.type = selectionType
    TileEditorUtils.debug("Selection type set to:", selectionType)
    
    -- Update highlight if we have an active selection
    if self.startPoint then
        self:updateHighlight()
    end
    
    return true
end

--- Gets the current selection type
-- @return string Selection type
function TileEditorSelection:getType()
    return self.type
end

-- ============================================================================
-- Selection Process
-- ============================================================================

--- Starts a new selection
-- @param x World X coordinate
-- @param y World Y coordinate
-- @param z World Z coordinate
function TileEditorSelection:startSelection(x, y, z)
    self.isSelecting = true
    self.startPoint = {x = x, y = y, z = z}
    self.endPoint = {x = x, y = y, z = z}
    self.z = z
    
    TileEditorUtils.debug("Started selection at", x, y, z)
    
    self:updateSelectionParams()
    self:updateHighlight()
end

--- Updates the selection endpoint
-- @param x World X coordinate
-- @param y World Y coordinate
function TileEditorSelection:updateSelection(x, y)
    if not self.isSelecting or not self.startPoint then
        return
    end
    
    self.endPoint = {x = x, y = y, z = self.z}
    
    self:updateSelectionParams()
    self:updateHighlight()
end

--- Finishes the current selection
function TileEditorSelection:finishSelection()
    if not self.isSelecting then
        return
    end
    
    self.isSelecting = false
    TileEditorUtils.debug("Finished selection")
    
    -- Keep the highlight active to show the final selection
end

--- Cancels the current selection
function TileEditorSelection:cancelSelection()
    self.isSelecting = false
    self.startPoint = nil
    self.endPoint = nil
    self:clearHighlight()
    
    TileEditorUtils.debug("Cancelled selection")
end

--- Clears the selection
function TileEditorSelection:clearSelection()
    self.startPoint = nil
    self.endPoint = nil
    self:clearHighlight()
    
    TileEditorUtils.debug("Cleared selection")
end

-- ============================================================================
-- Selection Parameter Calculation
-- ============================================================================

--- Updates selection parameters based on start and end points
function TileEditorSelection:updateSelectionParams()
    if not self.startPoint or not self.endPoint then
        return
    end
    
    local sx, sy = self.startPoint.x, self.startPoint.y
    local ex, ey = self.endPoint.x, self.endPoint.y
    
    if self.type == "point" then
        self.centerX = sx
        self.centerY = sy
        
    elseif self.type == "rect" or self.type == "box" then
        self.x1 = math.min(sx, ex)
        self.y1 = math.min(sy, ey)
        self.x2 = math.max(sx, ex)
        self.y2 = math.max(sy, ey)
        
    elseif self.type == "circle" or self.type == "ring" then
        self.centerX = sx
        self.centerY = sy
        self.radius = math.floor(TileEditorUtils.distance(sx, sy, ex, ey))
        
        if self.type == "ring" then
            -- Calculate inner/outer radius to match GroundHighlighter
            -- Ring is centered around the radius with thickness extending both ways
            self.innerRadius = math.max(0, self.radius - self.ringThickness / 2)
            self.outerRadius = self.radius + self.ringThickness / 2
        end
    end
end

-- ============================================================================
-- Tile Retrieval
-- ============================================================================

--- Gets all affected tiles in the current selection
-- @return Array of {x, y, z} coordinates
function TileEditorSelection:getAffectedTiles()
    if not self.startPoint then
        return {}
    end
    
    local selection = {
        type = self.type,
        centerX = self.centerX,
        centerY = self.centerY,
        z = self.z,
        x1 = self.x1,
        y1 = self.y1,
        x2 = self.x2,
        y2 = self.y2,
        radius = self.radius,
        innerRadius = self.innerRadius,
        ringThickness = self.ringThickness,
        boxThickness = self.boxThickness
    }
    
    return TileEditorUtils.getSelectionTiles(selection)
end

--- Gets the number of tiles in the current selection
-- @return number Tile count
function TileEditorSelection:getTileCount()
    local tiles = self:getAffectedTiles()
    return #tiles
end

-- ============================================================================
-- Visualization
-- ============================================================================

--- Updates the ground highlight based on current selection
function TileEditorSelection:updateHighlight()
    if not self.startPoint then
        self:clearHighlight()
        return
    end
    
    -- Check distance from player to limit performance impact
    -- local player = getPlayer()
    -- if player then
    --     local px, py = player:getX(), player:getY()
    --     local dist = TileEditorUtils.distance(px, py, self.centerX, self.centerY)
        
    --     if dist > self.maxHighlightDistance then
    --         self:clearHighlight()
    --         return
    --     end
    -- end
    
    -- Create highlighter if needed
    if not self.highlighter then
        self.highlighter = GroundHighlighter:new()
        self.highlighter:enableXray(true, true)
        self.highlighter:setColor(
            self.highlightColor.r,
            self.highlightColor.g,
            self.highlightColor.b,
            self.highlightColor.a
        )
    end
    
    -- Clear previous highlights
    if self.highlighter then
        self.highlighter:remove()
    end
    
    -- Add highlights based on selection type
    if self.type == "point" then
        self.highlighter:highlightSquare(
            self.centerX, self.centerY,
            self.centerX, self.centerY,
            self.z
        )
        
    elseif self.type == "rect" then
        -- Filled rectangle
        self.highlighter:highlightSquare(
            self.x1, self.y1,
            self.x2, self.y2,
            self.z
        )
        
    elseif self.type == "box" then
        -- Box (border only) - use the new highlightBox method with thickness
        self.highlighter:highlightBox(
            self.x1, self.y1,
            self.x2, self.y2,
            self.z,
            self.boxThickness
        )
        
    elseif self.type == "circle" then
        -- Filled circle - use the highlightCircle method
        self.highlighter:highlightCircle(
            self.centerX, self.centerY,
            self.radius,
            self.z
        )
        
    elseif self.type == "ring" then
        -- Ring (border only) - use the highlightRing method
        self.highlighter:highlightRing(
            self.centerX, self.centerY,
            self.radius,
            self.ringThickness,
            self.z
        )
    end
end

--- Clears the ground highlight
function TileEditorSelection:clearHighlight()
    if self.highlighter then
        self.highlighter:remove()
        self.highlighter = nil
    end
end

-- ============================================================================
-- Cleanup
-- ============================================================================

--- Cleans up resources
function TileEditorSelection:cleanup()
    self:clearHighlight()
    self.startPoint = nil
    self.endPoint = nil
    self.isSelecting = false
end

-- ============================================================================
-- Utility Methods
-- ============================================================================

--- Checks if a selection is active
-- @return boolean
function TileEditorSelection:hasSelection()
    return self.startPoint ~= nil
end

--- Checks if currently selecting
-- @return boolean
function TileEditorSelection:isCurrentlySelecting()
    return self.isSelecting
end

--- Gets selection info as a string
-- @return string Selection description
function TileEditorSelection:getSelectionInfo()
    if not self.startPoint then
        return "No selection"
    end
    
    local count = self:getTileCount()
    local typeStr = self.type:sub(1,1):upper() .. self.type:sub(2)
    
    -- Add thickness info for ring and box
    if self.type == "ring" then
        return string.format("%s: %d tiles (R:%d, T:%d)", typeStr, count, self.radius, self.ringThickness)
    elseif self.type == "box" then
        return string.format("%s: %d tiles (T:%d)", typeStr, count, self.boxThickness)
    end
    
    return string.format("%s: %d tiles", typeStr, count)
end

--- Sets the highlight color
-- @param r Red (0-1)
-- @param g Green (0-1)
-- @param b Blue (0-1)
-- @param a Alpha (0-1)
function TileEditorSelection:setHighlightColor(r, g, b, a)
    self.highlightColor = {r=r, g=g, b=b, a=a}
    
    if self.highlighter then
        self.highlighter:setColor(r, g, b, a)
    end
end

--- Adjusts the thickness for ring or box selections
-- @param delta Amount to change thickness by (positive or negative)
function TileEditorSelection:adjustThickness(delta)
    if self.type == "ring" then
        self.ringThickness = math.max(1, math.min(self.radius * 2, self.ringThickness + delta))
        -- Recalculate inner and outer radius to match GroundHighlighter
        self.innerRadius = math.max(0, self.radius - self.ringThickness / 2)
        self.outerRadius = self.radius + self.ringThickness / 2
        self:updateHighlight()
        TileEditorUtils.debug("Ring thickness adjusted to:", self.ringThickness)
        return true
    elseif self.type == "box" then
        -- Calculate max thickness based on box dimensions
        local width = math.abs(self.x2 - self.x1) + 1
        local height = math.abs(self.y2 - self.y1) + 1
        local maxThickness = math.floor(math.min(width, height) / 2)
        
        self.boxThickness = math.max(1, math.min(maxThickness, self.boxThickness + delta))
        self:updateHighlight()
        TileEditorUtils.debug("Box thickness adjusted to:", self.boxThickness)
        return true
    end
    return false
end

--- Gets the current thickness value
-- @return number Current thickness or nil if not applicable
function TileEditorSelection:getThickness()
    if self.type == "ring" then
        return self.ringThickness
    elseif self.type == "box" then
        return self.boxThickness
    end
    return nil
end

return TileEditorSelection