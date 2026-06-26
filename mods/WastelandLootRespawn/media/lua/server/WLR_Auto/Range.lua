if isClient() then return end

WLR_Auto = WLR_Auto or {}

--- @class WLR_Auto.Range
--- @field x1 number
--- @field y1 number
--- @field x2 number
--- @field y2 number
WLR_Auto.Range = WLR_Auto.Range or WLBaseObject:derive("Range")

--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
function WLR_Auto.Range:new(x1, y1, x2, y2)
    local o = self:super()
    o.x1 = x1
    o.y1 = y1
    o.x2 = x2
    o.y2 = y2
    return o
end

--- @param self WLR_Auto.Range
--- @param x number
--- @param y number
--- @return boolean
function WLR_Auto.Range:contains(x, y)
    return x >= self.x1 and x <= self.x2 and y >= self.y1 and y <= self.y2
end

--- @param self WLR_Auto.Range
--- @param other WLR_Auto.Range
--- @return boolean
function WLR_Auto.Range:intersects(other)
    if self.x1 > other.x2 or self.x2 < other.x1 then
        return false
    end
    if self.y1 > other.y2 or self.y2 < other.y1 then
        return false
    end
    return true
end

--- @param self WLR_Auto.Range
--- @param other WLR_Auto.Range
--- @return WLR_Auto.Range
function WLR_Auto.Range:intersection(other)
    local x1 = math.max(self.x1, other.x1)
    local y1 = math.max(self.y1, other.y1)
    local x2 = math.min(self.x2, other.x2)
    local y2 = math.min(self.y2, other.y2)
    return WLR_Auto.Range:new(x1, y1, x2, y2)
end

--- @param self WLR_Auto.Range
--- @return string
function WLR_Auto.Range:__tostring()
    return self.x1 .. "," .. self.y1 .. " - " .. self.x2 .. "," .. self.y2
end