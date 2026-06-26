local knownPlants = {}
local numKnownPlants = 0

local CheckField = ISBaseTimedAction:derive("CheckField")

function CheckField:new(character, field)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.field = field
    o.maxTime = 50
    o.stopOnWalk = true
    return o
end


function CheckField:waitToStart()
	self.character:faceLocation(self.field[1]:getX(), self.field[1]:getY())
	return self.character:shouldBeTurning()
end

function CheckField:update()
	self.character:faceLocation(self.field[1]:getX(), self.field[1]:getY())
end

function CheckField:isValid()
    return #self.field > 0
end

function CheckField:perform()
    local next = table.remove(self.field, 1)
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(next)
    if not plant then
	    ISBaseTimedAction.perform(self)
        return
    end
    local farmingLevel = CFarmingSystem.instance:getXp(self.character)
    if not knownPlants[next] then
        numKnownPlants = numKnownPlants + 1
        knownPlants[next] = {
            time = getTimestamp(),
            plant = plant,
            isDead = not plant:isAlive(),
            isReady = plant:canHarvest(),
            water = ISFarmingInfo.getWaterLvl(plant, farmingLevel),
            disease = ISFarmingInfo.getDiseaseName({character = self.character, plant = plant}),
        }
    else
        knownPlants[next].time = getTimestamp()
        knownPlants[next].isDead = not plant:isAlive()
        knownPlants[next].isReady = plant:canHarvest()
        knownPlants[next].water = ISFarmingInfo.getWaterLvl(plant, farmingLevel)
        knownPlants[next].disease = ISFarmingInfo.getDiseaseName({character = self.character, plant = plant})
        if knownPlants[next].element then
            knownPlants[next].element:removeFromUIManager()
            knownPlants[next].element = nil
        end
    end
    if #self.field > 0 then
        ISFarmingMenu.walkToPlant(self.character, self.field[1])
        ISTimedActionQueue.add(CheckField:new(self.character, self.field))
    end
	ISBaseTimedAction.perform(self)
end

function OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end

    if numKnownPlants > 0 then
        context:addOption("Forget Field Checks", nil, function()
            for _, plantData in pairs(knownPlants) do
                if plantData.element then
                    plantData.element:removeFromUIManager()
                end
            end
            knownPlants = {}
            numKnownPlants = 0
        end)
    end

    local square = worldobjects[1]:getSquare()
    if not square then return end
    local plant = CFarmingSystem.instance:getLuaObjectOnSquare(square)
    if not plant then return end

    local playerObj = getSpecificPlayer(playerIdx)

    local field = WF_Lib.ScanArea(square, 20, function(sq)
        return CFarmingSystem.instance:getLuaObjectOnSquare(sq) ~= nil
    end)
    if #field > 1 then
        context:addOption("Check Field", nil, function()
            ISFarmingMenu.walkToPlant(playerObj, field[1])
            ISTimedActionQueue.add(CheckField:new(playerObj, field))
        end)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(OnPreFillWorldObjectContextMenu)

local textManager = getTextManager()
local overheadEle = ISUIElement:derive("WF_OverheadEle")
function overheadEle:new(square, text)
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self
    o.square = square
    o.text = text
    o.anchorTop = false
    o.anchorBottom = true
    o:initialise()
    o:addToUIManager()
    o:backMost()
    o:setVisible(true)
    return o
end
function overheadEle:render()
    local x = self.square:getX()
    local y = self.square:getY()
    local z = self.square:getZ()
    local sx = isoToScreenX(0, x, y, z)
    local sy = isoToScreenY(0, x, y, z)
    if sx < 0 or sy < 0 or sx > getPlayerScreenWidth(0) or sy > getPlayerScreenHeight(0) then
        return
    end
    local w = 0
    for i = 1, #self.text do
        w = math.max(w, textManager:MeasureStringX(UIFont.Small, self.text[i]))
    end
    local h = textManager:MeasureStringY(UIFont.Small, self.text[1]) * #self.text
    self:setX(sx - w/2)
    self:setY(sy)
    self:setWidth(w)
    self:setHeight(h)
    self:drawRect(0, 0, w, h, 0.5, 0, 0, 0)
    for i = 1, #self.text do
        local k = (i - 1) * h / #self.text
        self:drawText(self.text[i], 0, k, 1, 1, 1, 1, UIFont.Small)
    end
end

local function renderPlantData()
    local toRemove = {}
    local now = getTimestamp()
    for i, plantData in pairs(knownPlants) do
        local square = plantData.plant:getSquare()
        if not square or now - plantData.time > 300 then
            table.insert(toRemove, i)
        elseif not plantData.element then
            local text = {}
            if plantData.isDead then
                table.insert(text, "Dead")
            elseif plantData.isReady then
                table.insert(text, "Ready")
            end
            if plantData.water ~= getText("Farming_Well_watered") then
                table.insert(text, plantData.water)
            end
            if plantData.disease.text ~= getText("UI_No") then
                if plantData.disease.text == getText("UI_Yes") then
                    table.insert(text, "Diseased")
                else
                    table.insert(text, plantData.disease.text)
                end
            end
            if #text > 0 then
                plantData.element = overheadEle:new(square, text)
            else
                table.insert(toRemove, i)
            end
        end
    end

    for i = #toRemove, 1, -1 do
        local idx = toRemove[i]
        if knownPlants[idx].element then
            knownPlants[idx].element:removeFromUIManager()
        end
        knownPlants[idx] = nil
        numKnownPlants = numKnownPlants - 1
    end
end

Events.OnTick.Add(renderPlantData)