WL_Moodle = ISUIElement:derive("WL_Moodle")
WL_Moodle.instances = {}
WL_Moodle.orderedInstances = {}

-- API: var moodle = WL_Moodle:get("ModId", playerId)
function WL_Moodle:get(modId, playerId)
    local key = modId .. "_" .. tostring(playerId)
    if WL_Moodle.instances[key] then
        return WL_Moodle.instances[key]
    end

    local o = ISUIElement:new(0, 0, 32, 32)
    setmetatable(o, self)
    self.__index = self
    
    o.modId = modId
    o.playerId = playerId
    o.isVisible = false
    o.isGood = true
    o.level = 1
    o.icon = nil
    o.title = ""
    o.description = ""
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    
    -- Oscillation vars
    o.oscillationLevel = 0
    o.oscillatorScalar = 15.6
    o.oscillatorDecelerator = 0.84
    o.oscillatorRate = 0.8
    o.oscillatorStep = 0
    o.oscillatorXOffset = 0
    
    WL_Moodle.instances[key] = o
    table.insert(WL_Moodle.orderedInstances, o)

    return o
end

function WL_Moodle:getCharacter()
    return getSpecificPlayer(self.playerId)
end

-- API: moodle.setIcon(texture)
function WL_Moodle:setIcon(texture)
    self.icon = texture
end

-- API: moodle.setState(true/false, 1-4)
function WL_Moodle:setState(isGood, level)
    if self.isGood ~= isGood or self.level ~= level then
        self.oscillationLevel = 1
    end
    self.isGood = isGood
    self.level = level
end

-- API: moodle.show()
function WL_Moodle:show()
    if not self.isVisible then
        self:addToUIManager()
        self.isVisible = true
    end
end

-- API: moodle.hide()
function WL_Moodle:hide()
    if self.isVisible then
        self:removeFromUIManager()
        self.isVisible = false
    end
end

-- API: moodle.setTitle(string)
function WL_Moodle:setTitle(str)
    self.title = str
end

-- API: moodle.setDescription(string)
function WL_Moodle:setDescription(str)
    self.description = str
end

function WL_Moodle:getXYPosition()
    local playerNum = self.playerId
    local x = getPlayerScreenLeft(playerNum) + getPlayerScreenWidth(playerNum) - 18 - 32
    local y = getPlayerScreenTop(playerNum) + 100
    
    local char = self:getCharacter()
    if not char then return x, y end

    -- Vanilla moodles
    local moodles = char:getMoodles()
    for i = 0, 23 do
        if moodles:getMoodleLevel(MoodleType.FromIndex(i)) ~= 0 then
            y = y + 36
        end
    end
    
    -- Aiteron MoodleManager (compatibility)
    local aiteronMM = char:getModData().MoodleManager
    if aiteronMM and aiteronMM.moodles then
        for _, moodleObj in pairs(aiteronMM.moodles) do
            if moodleObj.getLevel and moodleObj:getLevel() > 0 then
                y = y + 36
            end
        end
    end

    -- MF Moodles (compatibility)
    if char:getModData().Moodles then
        for k, v in pairs(char:getModData().Moodles) do
            if v.Level ~= 0 then
                y = y + 36
            end
        end
    end
    
    -- WL_Moodles stacking
    for _, moodle in ipairs(WL_Moodle.orderedInstances) do
        if moodle == self then
            break
        end
        if moodle.playerId == self.playerId and moodle.isVisible then
            y = y + 36
        end
    end
    
    return x, y
end

function WL_Moodle:updateOscillator()
    if self.oscillationLevel > 0 then
        local fpsFrac = PerformanceSettings.getLockFPS() / 30.0
        if not fpsFrac or fpsFrac <= 0 then fpsFrac = 1 end

        self.oscillationLevel = self.oscillationLevel - self.oscillationLevel * (1.0 - self.oscillatorDecelerator) / fpsFrac
        if self.oscillationLevel < 0.015 then self.oscillationLevel = 0 end
        
        if self.oscillationLevel > 0 then
            self.oscillatorStep = self.oscillatorStep + self.oscillatorRate / fpsFrac
            local osc = math.sin(self.oscillatorStep)
            self.oscillatorXOffset = osc * self.oscillatorScalar * self.oscillationLevel
        else
            self.oscillatorXOffset = 0
            self.oscillatorStep = 0
        end
    else
        self.oscillatorXOffset = 0
    end
end

function WL_Moodle:render()
    if not self.isVisible then return end
    
    self:updateOscillator()
    local wiggle = self.oscillatorXOffset
    
    local x, y = self:getXYPosition()
    self:setX(x)
    self:setY(y)
    
    -- Background
    local bkgName = "media/ui/Moodle_Bkg_" .. (self.isGood and "Good" or "Bad") .. "_" .. self.level .. ".png"
    local bkg = getTexture(bkgName)
    if bkg then
        self:drawTexture(bkg, wiggle, 0, 1, 1, 1, 1)
    end
    
    -- Icon
    if self.icon then
        local tex = self.icon
        if type(tex) == "string" then tex = getTexture(tex) end
        if tex then
             self:drawTexture(tex, wiggle, 0, 1, 1, 1, 1)
        end
    end
    
    -- Tooltip
    if self:isMouseOver() then
        self:drawTooltip()
    end
end

function WL_Moodle:drawTooltip()
    local text = self.title
    if self.description and self.description ~= "" then
        text = text .. "\n" .. self.description
    end
    
    local font = UIFont.Small
    local width = getTextManager():MeasureStringX(font, text) + 20
    local height = getTextManager():MeasureStringY(font, text) + 10
    
    -- Draw to the left of the moodle
    local tx = -width - 10
    local ty = 0
    
    self:drawRect(tx, ty, width, height, 0.7, 0, 0, 0)
    self:drawRectBorder(tx, ty, width, height, 1, 1, 1, 1)
    self:drawText(text, tx + 10, ty + 5, 1, 1, 1, 1, font)
end

function WL_Moodle.onPlayerDeath(player)
    local toRemove = {}
    for key, moodle in pairs(WL_Moodle.instances) do
        if moodle.playerId == player:getPlayerNum() then
            table.insert(toRemove, key)
        end
    end
    for _, key in ipairs(toRemove) do
        local moodle = WL_Moodle.instances[key]
        if moodle then
            moodle:hide()
            WL_Moodle.instances[key] = nil
            for i, m in ipairs(WL_Moodle.orderedInstances) do
                if m == moodle then
                    table.remove(WL_Moodle.orderedInstances, i)
                    break
                end
            end
        end
    end
end