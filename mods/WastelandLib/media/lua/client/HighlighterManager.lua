--- Global manager for coordinating multiple GroundHighlighter instances
--- Automatically manages registration and priority-based rendering
--- @class HighlighterManager
HighlighterManager = HighlighterManager or {
    highlighters = {},  -- Array of highlighter instances
    nextId = 1
}

--- Automatically called by GroundHighlighter when it starts highlighting
--- @param highlighter GroundHighlighter The highlighter instance to register
--- @return string Unique ID for this highlighter
function HighlighterManager:register(highlighter)
    -- Generate unique ID and store in highlighter
    local id = "highlighter_" .. self.nextId
    self.nextId = self.nextId + 1
    highlighter.managerId = id
    
    -- Add highlighter to array
    table.insert(self.highlighters, highlighter)
    
    -- Sort by priority (lower number = higher priority)
    self:sortByPriority()
    
    return id
end

--- Automatically called by GroundHighlighter when it's removed
--- @param highlighter GroundHighlighter The highlighter instance to unregister
function HighlighterManager:unregister(highlighter)
    -- Find and remove the highlighter from array
    for i = #self.highlighters, 1, -1 do
        if self.highlighters[i] == highlighter then
            table.remove(self.highlighters, i)
            break
        end
    end
end

--- Sort highlighters by priority (lower number = higher priority)
function HighlighterManager:sortByPriority()
    table.sort(self.highlighters, function(a, b)
        return (a.priority or 1) < (b.priority or 1)
    end)
end

--- Determine if a specific highlighter should render at a coordinate
--- @param highlighter GroundHighlighter The highlighter asking if it should render
--- @param x number X coordinate
--- @param y number Y coordinate
--- @param z number Z coordinate
--- @return boolean True if this highlighter should render at this coordinate
function HighlighterManager:shouldRender(highlighter, x, y, z)
    -- Iterate through highlighters from highest priority (lowest number) to lowest
    for i = 1, #self.highlighters do
        local h = self.highlighters[i]
        
        -- Skip if type is none
        if h.type ~= "none" then
            -- Check if this highlighter is visible at this coordinate
            if h:isVisible(x, y, z) then
                -- If it's the one asking, return true (it's the highest priority visible)
                if h == highlighter then
                    return true
                end
                -- If it's a different one, return false (something higher priority is visible)
                return false
            end
        end
    end
    
    -- If we get here, nothing higher priority was found
    return true
end

--- Refresh all highlighters (turn off then on)
function HighlighterManager:refreshAll()
    for i = 1, #self.highlighters do
        local h = self.highlighters[i]
        if h.type ~= "none" then
            h:setHightlighted(false)
            h:setHightlighted(true)
        end
    end
end

--- Refresh specific bounds after a highlighter is removed
--- This ensures any remaining highlighters can re-render their overlapping squares
--- @param bounds Bounds The bounds to refresh
function HighlighterManager:refreshBounds(bounds)
    local cell = getCell()
    for x = bounds.x1, bounds.x2 do
        for y = bounds.y1, bounds.y2 do
            for z = bounds.z1, bounds.z2 do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    -- First clear the square
                    local objs = sq:getObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        obj:setHighlighted(false, false)
                    end
                    objs = sq:getSpecialObjects()
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        obj:setHighlighted(false, false)
                    end
                    
                    -- Then check if any remaining highlighter should render this square
                    for i = 1, #self.highlighters do
                        local h = self.highlighters[i]
                        if h.type ~= "none" and h:isVisible(x, y, z) then
                            if self:shouldRender(h, x, y, z) then
                                h:tryHighlightWorldSquare(sq, true)
                                break  -- Only the highest priority one renders
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Clear all registered highlighters
function HighlighterManager:clearAll()
    -- Make a copy of the array since remove() will modify it
    local highlightersCopy = {}
    for i = 1, #self.highlighters do
        table.insert(highlightersCopy, self.highlighters[i])
    end
    
    -- Remove each highlighter
    for i = 1, #highlightersCopy do
        highlightersCopy[i]:remove()
    end
end