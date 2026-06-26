local original_farmingPlot_isValid = farmingPlot.isValid
function farmingPlot:isValid(square)
    local result = original_farmingPlot_isValid(self, square)
    if not result then
        return false
    end
    -- make sure square has nothing but just grass on it
    local objects = square:getObjects()
    if objects:size() > 1 then -- more than one object means something is on the square
        return false
    end
    local floorObject = objects:get(0)
    local childSprites = floorObject:getChildSprites()
    if childSprites and childSprites:size() > 0 then
        -- if the floor object has child sprites, it means it's not just grass
        return false
    end
    local animSprites = floorObject:getAttachedAnimSprite()
    if animSprites and animSprites:size() > 0 then
        -- if the floor object has attached anim sprites, it means it's not just grass
        for i = 0, animSprites:size() - 1 do
            local animSprite = animSprites:get(i)
            if animSprite and animSprite:getName():sub(1, 14) ~= "blends_natural" then
                return false
            end
        end
    end
    return true
end