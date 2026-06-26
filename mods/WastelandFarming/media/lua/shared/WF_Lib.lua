WF_Lib = WF_Lib or {}

local function sortSquares(a, b)
    if a:getX() == b:getX() then
        if a:getX() % 2 == 1 then
            return a:getY() > b:getY()
        else
            return a:getY() < b:getY()
        end
    end
    return a:getX() < b:getX()
end

function WF_Lib.SnakeSortSquares(squares)
    table.sort(squares, sortSquares)
end

function WF_Lib.ScanArea(startSquare, maxRange, predicate)
    local field = {}
    local visited = {}
    local queue = {}
    if not predicate(startSquare) then
        return field
    end
    table.insert(field, startSquare)
    table.insert(queue, startSquare)
    visited[startSquare] = true
    while #queue > 0 do
        local sq = table.remove(queue, 1)
        local x = sq:getX()
        local y = sq:getY()
        local z = sq:getZ()
        for dx = -1, 1 do
            for dy = -1, 1 do
                local nx = x + dx
                local ny = y + dy
                local nsq = getCell():getGridSquare(nx, ny, z)
                if nsq and not visited[nsq] and nsq:DistTo(startSquare) < maxRange then
                    visited[nsq] = true
                    if predicate(nsq) then
                        table.insert(field, nsq)
                        table.insert(queue, nsq)
                    end
                end
            end
        end
    end
    table.sort(field, sortSquares)
    return field
end

