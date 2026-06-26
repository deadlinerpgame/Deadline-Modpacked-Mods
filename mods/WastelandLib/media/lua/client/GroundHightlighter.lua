--- @class Bounds
--- @field x1 number
--- @field y1 number
--- @field x2 number
--- @field y2 number
--- @field z1 number
--- @field z2 number
---
--- @class Color
--- @field r number
--- @field g number
--- @field b number
--- @field a number
---
--- @class Center
--- @field x number
--- @field y number
--- @field z number
---
--- @class GroundHighlighter
--- @field type string none | square | box | circle | circle_manhattan | ring | line
--- @field bounds Bounds
--- @field radius number
--- @field center Center
--- @field color table<number, Color>
--- @field xray boolean
--- @field priority number
--- @field ringThickness number
--- @field boxThickness number
--- @field lineStart table
--- @field lineEnd table
--- @field lineThickness number
--- @field onlyFloor boolean
GroundHighlighter = {}

--- @return GroundHighlighter
function GroundHighlighter:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.type = "none"
    o.bounds = {x1 = 0, y1 = 0, x2 = 0, y2 = 0, z1 = 0, z2 = 0}
    o.radius = 0
    o.center = {x = 0, y = 0, z = 0}
    o.color = {
        [0] = {r = 0.0, g = 1.0, b = 0, a = 1.0}
    }
    o.xray = false
    o.colorPickerFunc = nil
    o.priority = 1  -- Lower = higher priority
    o.ringThickness = 1
    o.boxThickness = 1
    o.lineStart = {x = 0, y = 0, z = 0}
    o.lineEnd = {x = 0, y = 0, z = 0}
    o.lineThickness = 1
    o.onlyFloor = false
    return o
end

function GroundHighlighter:setPriority(priority)
    self.priority = priority or 1
    if self.managerId then
        HighlighterManager:sortByPriority()
        HighlighterManager:refreshAll()
    end
end

function GroundHighlighter:setColorPickerFunc(func)
    self.colorPickerFunc = func
end

function GroundHighlighter:getColor(x, y, z)
    if self.colorPickerFunc then
        local color = self.colorPickerFunc(x, y, z)
        if color then
            return color
        end
    end
    local dist = 0
    if self.type == "circle_manhattan" then
        local dx = math.abs(x - self.center.x)
        local dy = math.abs(y - self.center.y)
        dist = math.floor(dx + dy)
    else
        local dx = x - self.center.x
        local dy = y - self.center.y
        dist = math.floor(math.sqrt((dx * dx) + (dy * dy)))
    end
    for i = dist, 0, -1 do
        if self.color[i] then
            return self.color[i]
        end
    end
end

function GroundHighlighter:isPointInRadius(x, y)
    local dx = x - self.center.x
    local dy = y - self.center.y
    return (dx * dx) + (dy * dy) <= (self.radius * self.radius)
end

function GroundHighlighter:isPointInManhattenRadius(x, y)
    local dx = math.abs(x - self.center.x)
    local dy = math.abs(y - self.center.y)
    return dx + dy <= self.radius
end

function GroundHighlighter:isVisible(x, y, z)
    if self.type == "square" then
        return x >= self.bounds.x1 and
               x <= self.bounds.x2 and
               y >= self.bounds.y1 and
               y <= self.bounds.y2 and
               z >= self.bounds.z1 and
               z <= self.bounds.z2
    end
    if self.type == "box" then
        -- Box is a border/outline of a rectangle with configurable thickness
        local inBounds = x >= self.bounds.x1 and
                        x <= self.bounds.x2 and
                        y >= self.bounds.y1 and
                        y <= self.bounds.y2 and
                        z >= self.bounds.z1 and
                        z <= self.bounds.z2
        if not inBounds then
            return false
        end
        
        -- Calculate distance from each edge
        local distFromLeft = x - self.bounds.x1
        local distFromRight = self.bounds.x2 - x
        local distFromTop = y - self.bounds.y1
        local distFromBottom = self.bounds.y2 - y
        
        -- Check if within thickness distance from any edge
        local minDist = math.min(distFromLeft, distFromRight, distFromTop, distFromBottom)
        return minDist < self.boxThickness
    end
    if self.type == "circle_edge" then
        -- should only highlight the edge of the circle
        local dx = x - self.center.x
        local dy = y - self.center.y
        local dist = (dx * dx) + (dy * dy)
        local r2 = self.radius * self.radius
        return dist >= r2 - 1.5 and dist <= r2 + 1.5
    end
    if self.type == "circle_manhattan" then
        return self:isPointInManhattenRadius(x, y)
    end
    if self.type == "ring" then
        local dx = x - self.center.x
        local dy = y - self.center.y
        local dist = math.sqrt((dx * dx) + (dy * dy))
        local innerRadius = self.radius - self.ringThickness / 2
        local outerRadius = self.radius + self.ringThickness / 2
        return dist >= innerRadius and dist <= outerRadius
    end
    if self.type == "line" then
        -- Check if z is within the line's z range
        if z < self.lineStart.z and z < self.lineEnd.z then
            return false
        end
        if z > self.lineStart.z and z > self.lineEnd.z then
            return false
        end
        
        -- Calculate perpendicular distance from point to line segment
        local x1, y1 = self.lineStart.x, self.lineStart.y
        local x2, y2 = self.lineEnd.x, self.lineEnd.y
        
        -- Vector from line start to end
        local dx = x2 - x1
        local dy = y2 - y1
        
        -- Length squared of the line segment
        local lengthSq = (dx * dx) + (dy * dy)
        
        if lengthSq == 0 then
            -- Line start and end are the same point
            local pdx = x - x1
            local pdy = y - y1
            return math.sqrt((pdx * pdx) + (pdy * pdy)) <= self.lineThickness / 2
        end
        
        -- Project point onto line (clamped to segment)
        local t = math.max(0, math.min(1, (((x - x1) * dx) + ((y - y1) * dy)) / lengthSq))
        
        -- Find closest point on line segment
        local closestX = x1 + t * dx
        local closestY = y1 + t * dy
        
        -- Calculate distance from point to closest point on line
        local distX = x - closestX
        local distY = y - closestY
        local distance = math.sqrt((distX * distX) + (distY * distY))
        
        return distance <= self.lineThickness / 2
    end
    return self:isPointInRadius(x, y)
end

function GroundHighlighter:tryHighlightWorldSquare(sq, enabled)
    if enabled and not self:isVisible(sq:getX(), sq:getY(), sq:getZ()) then
        return
    end
    
    -- Check with manager if we should render this square
    if enabled and not HighlighterManager:shouldRender(self, sq:getX(), sq:getY(), sq:getZ()) then
        return  -- Higher priority highlighter is rendering this square
    end
    
    local color = self:getColor(sq:getX(), sq:getY(), sq:getZ())

    if self.onlyFloor then
        local floor = sq:getFloor()
        if floor then
            floor:setHighlighted(enabled, false)
            if enabled then
                floor:setHighlightColor(color.r, color.g, color.b, color.a)
            end
        end
        return
    end

    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if (obj:isFloor() or self.xray or not enabled) and obj:getType() ~= IsoObjectType.tree then
            obj:setHighlighted(enabled, false)
            if enabled then
                obj:setHighlightColor(color.r, color.g, color.b, color.a)
            end
        end
    end
    objs = sq:getSpecialObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj:isFloor() or self.xray or not enabled then
            obj:setHighlighted(enabled, false)
            if enabled then
                obj:setHighlightColor(color.r, color.g, color.b, color.a)
            end
        end
    end
end

function GroundHighlighter:setHightlighted(enabled)
    local cell = getCell()
    if enabled and self.removeSnow then
        getSandboxOptions():getOptionByName("EnableSnowOnGround"):setValue(false)
    elseif not enabled and self.removeSnow then
        getSandboxOptions():getOptionByName("EnableSnowOnGround"):setValue(true)
    end
    
    -- Auto-register with manager when enabling
    if enabled and not self.managerId then
        self.managerId = HighlighterManager:register(self)
    end
    
    for x = self.bounds.x1, self.bounds.x2 do
        for y = self.bounds.y1, self.bounds.y2 do
            for z = self.bounds.z1, self.bounds.z2 do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    self:tryHighlightWorldSquare(sq, enabled)
                end
            end
        end
    end
end

function GroundHighlighter:remove()
    if self.type ~= "none" then
        -- Store bounds before clearing them
        local oldBounds = {
            x1 = self.bounds.x1,
            y1 = self.bounds.y1,
            x2 = self.bounds.x2,
            y2 = self.bounds.y2,
            z1 = self.bounds.z1,
            z2 = self.bounds.z2
        }
        
        self:setHightlighted(false)
        
        -- Auto-unregister from manager
        if self.managerId then
            HighlighterManager:unregister(self)
            self.managerId = nil
        end
        
        self.type = "none"
        self.bounds.x1 = 0
        self.bounds.y1 = 0
        self.bounds.x2 = 0
        self.bounds.y2 = 0
        self.bounds.z1 = 0
        self.bounds.z2 = 0
        
        -- Refresh the affected area so other highlighters can re-render
        HighlighterManager:refreshBounds(oldBounds)
    end
end

function GroundHighlighter:setColor(r, g, b, a)
    self.color = { [0] = {r = r, g = g, b = b, a = a or 1.0} }
    if self.type ~= "none" then
        self:setHightlighted(false)
        self:setHightlighted(true)
    end
end

function GroundHighlighter:resetColor()
    self.color = { [0] = {r = 0.0, g = 1.0, b = 0, a = 1.0} }
    if self.type ~= "none" then
        self:setHightlighted(false)
        self:setHightlighted(true)
    end
end

function GroundHighlighter:addColorStop(d, r, g, b, a)
    self.color[d] = {r = r, g = g, b = b, a = a or 1.0}
    if self.type ~= "none" then
        self:setHightlighted(false)
        self:setHightlighted(true)
    end
end

function GroundHighlighter:enableXray(enabled, removeSnow)
    if self.type ~= "none" then
        self:remove()
    end
    self.xray = enabled
    self.removeSnow = removeSnow or false
    if self.type ~= "none" then
        self:setHightlighted(true)
    end
end

function GroundHighlighter:highlightSquare(x1, y1, x2, y2, z)
    self:remove()
    self.type = "square"
    self.bounds.x1 = math.floor(x1)
    self.bounds.y1 = math.floor(y1)
    self.bounds.x2 = math.floor(x2)
    self.bounds.y2 = math.floor(y2)
    self.bounds.z1 = math.floor(z or 0)
    self.bounds.z2 = math.floor(z or 0)
    self.center.x = math.floor((x1 + x2) / 2)
    self.center.y = math.floor((y1 + y2) / 2)
    self.center.z = math.floor(z or 0)
    self:setHightlighted(true)
end

function GroundHighlighter:highlightCube(x1, y1, x2, y2, z1, z2)
    self:remove()
    self.type = "square"
    self.bounds.x1 = math.floor(x1)
    self.bounds.y1 = math.floor(y1)
    self.bounds.x2 = math.floor(x2)
    self.bounds.y2 = math.floor(y2)
    self.bounds.z1 = math.floor(z1)
    self.bounds.z2 = math.floor(z2)
    self.center.x = math.floor((x1 + x2) / 2)
    self.center.y = math.floor((y1 + y2) / 2)
    self.center.z = math.floor((z1 + z2) / 2)
    self:setHightlighted(true)
end

function GroundHighlighter:highlightBox(x1, y1, x2, y2, z, thickness)
    self:remove()
    self.type = "box"
    self.boxThickness = thickness or 1
    self.bounds.x1 = math.floor(x1)
    self.bounds.y1 = math.floor(y1)
    self.bounds.x2 = math.floor(x2)
    self.bounds.y2 = math.floor(y2)
    self.bounds.z1 = math.floor(z or 0)
    self.bounds.z2 = math.floor(z or 0)
    self.center.x = math.floor((x1 + x2) / 2)
    self.center.y = math.floor((y1 + y2) / 2)
    self.center.z = math.floor(z or 0)
    self:setHightlighted(true)
end

function GroundHighlighter:highlightCircle(x, y, radius, z)
    self:remove()
    self.type = "circle"
    self.radius = radius
    self.center.x = math.floor(x)
    self.center.y = math.floor(y)
    self.center.z = z or 0
    self.bounds.x1 = math.floor(x - radius)
    self.bounds.y1 = math.floor(y - radius)
    self.bounds.x2 = math.floor(x + radius)
    self.bounds.y2 = math.floor(y + radius)
    self.bounds.z1 = z or 0
    self.bounds.z2 = z or 0
    self:setHightlighted(true)
end

function GroundHighlighter:highlightCircleManhattan(x, y, radius, z1, z2)
    self:remove()
    self.type = "circle_manhattan"
    self.radius = radius
    self.center.x = math.floor(x)
    self.center.y = math.floor(y)
    self.center.z = z1 or 0
    self.bounds.x1 = math.floor(x - radius)
    self.bounds.y1 = math.floor(y - radius)
    self.bounds.x2 = math.floor(x + radius)
    self.bounds.y2 = math.floor(y + radius)
    self.bounds.z1 = z1 or 0
    self.bounds.z2 = z2 or 0
    self:setHightlighted(true)
end

function GroundHighlighter:highlightRing(x, y, radius, thickness, z)
    self:remove()
    self.type = "ring"
    self.radius = radius
    self.ringThickness = thickness or 1
    self.center.x = math.floor(x)
    self.center.y = math.floor(y)
    self.center.z = z or 0
    local maxExtent = radius + self.ringThickness
    self.bounds.x1 = math.floor(x - maxExtent)
    self.bounds.y1 = math.floor(y - maxExtent)
    self.bounds.x2 = math.floor(x + maxExtent)
    self.bounds.y2 = math.floor(y + maxExtent)
    self.bounds.z1 = z or 0
    self.bounds.z2 = z or 0
    self:setHightlighted(true)
end

function GroundHighlighter:highlightLine(x1, y1, z1, x2, y2, z2, thickness)
    self:remove()
    self.type = "line"
    self.lineStart.x = math.floor(x1)
    self.lineStart.y = math.floor(y1)
    self.lineStart.z = z1 or 0
    self.lineEnd.x = math.floor(x2)
    self.lineEnd.y = math.floor(y2)
    self.lineEnd.z = z2 or 0
    self.lineThickness = thickness or 1
    
    -- Calculate center point
    self.center.x = math.floor((x1 + x2) / 2)
    self.center.y = math.floor((y1 + y2) / 2)
    self.center.z = math.floor((z1 + z2) / 2)
    
    -- Calculate bounds with thickness padding
    local minX = math.min(x1, x2) - self.lineThickness
    local maxX = math.max(x1, x2) + self.lineThickness
    local minY = math.min(y1, y2) - self.lineThickness
    local maxY = math.max(y1, y2) + self.lineThickness
    
    self.bounds.x1 = math.floor(minX)
    self.bounds.y1 = math.floor(minY)
    self.bounds.x2 = math.floor(maxX)
    self.bounds.y2 = math.floor(maxY)
    self.bounds.z1 = math.min(z1 or 0, z2 or 0)
    self.bounds.z2 = math.max(z1 or 0, z2 or 0)
    self:setHightlighted(true)
end

--- this is broken.. do not use yet
-- function GroundHighlighter:highlightCircleEdge(x, y, radius, z)
--     self:remove()
--     self.type = "circle_edge"
--     self.radius = radius
--     self.center.x = math.floor(x)
--     self.center.y = math.floor(y)
--     self.center.z = z or 0
--     self.bounds.x1 = math.floor(x - radius)
--     self.bounds.y1 = math.floor(y - radius)
--     self.bounds.x2 = math.floor(x + radius)
--     self.bounds.y2 = math.floor(y + radius)
--     self:setHightlighted(true)
-- end