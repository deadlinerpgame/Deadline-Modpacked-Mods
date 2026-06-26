WAT_GrassSpawner = ISPanel:derive("WAT_GrassSpawner")

WAT_GrassSpawner.spawnables = {}
for i=0, 11 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Grass", age = "Young"} end
for i=12, 17 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Grass", age = "Baby"} end
for i=18, 23 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Grass", age = "Adult"} end
for i=24, 29 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Grass", age = "Young"} end
for i=30, 35 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Grass", age = "Baby"} end

for i=0, 7 do WAT_GrassSpawner.spawnables["d_generic_1_" .. i] = {type = "Plants", age = "Young"} end
for i=32, 39 do WAT_GrassSpawner.spawnables["d_generic_1_" .. i] = {type = "Plants", age = "Baby"} end
for i=48, 55 do WAT_GrassSpawner.spawnables["d_generic_1_" .. i] = {type = "Plants", age = "Young"} end
for i=80, 87 do WAT_GrassSpawner.spawnables["d_generic_1_" .. i] = {type = "Plants", age = "Adult"} end

for i=36, 99 do WAT_GrassSpawner.spawnables["e_newgrass_1_" .. i] = {type = "Other", age = "Other"} end
for i=0, 99 do WAT_GrassSpawner.spawnables["d_plants_1_" .. i] = {type = "Other", age = "Other"} end
for i=0, 99 do WAT_GrassSpawner.spawnables["vegetation_farm_01_" .. i] = {type = "Other", age = "Other"} end

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local COLOR_WHITE = {r=1,g=1,b=1,a=1}

function WAT_GrassSpawner.display()
    if WAT_GrassSpawner.instance then
        return
    end
    WAT_GrassSpawner.instance = WAT_GrassSpawner:new()
    WAT_GrassSpawner.instance:initialise()
    WAT_GrassSpawner.instance:addToUIManager()
end

function WAT_GrassSpawner:new()
    local scale = FONT_HGT_SMALL / 12
    local w = 200 * scale
    local h = 130 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WAT_GrassSpawner:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local player = getPlayer()

    local win = GravyUI.Node(self.width, self.height, self):pad(5)

    local header, body = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - 5}, 5)
    local type, selectAge, selectDensity, selectArea, buttons = body:rows({0.1667, 0.1667, 0.1667, .3333, 0.1667}, 5)

    header:makeLabel("Grass Spawner", UIFont.Medium, COLOR_WHITE, "center")
    local typeLabel1, typeSlider, typeLabel2 = type:cols({0.25, 0.5, 0.25}, 5)
    typeLabel1:makeLabel("Grass", UIFont.Small, COLOR_WHITE, "right")
    typeLabel2:makeLabel("Plants", UIFont.Small, COLOR_WHITE, "left")
    self.typeSlider = typeSlider:makeSlider()

    local ageLabel, ageDropdown = selectAge:cols({0.25, 0.75}, 5)
    ageLabel:makeLabel("Age", UIFont.Small, COLOR_WHITE, "right")
    self.ageDropdown = ageDropdown:makeComboBox()
    self.ageDropdown:addOption("All Ages")
    self.ageDropdown:addOption("Baby")
    self.ageDropdown:addOption("Young")
    self.ageDropdown:addOption("Adult")

    local densityLabel, densityDropdown = selectDensity:cols({0.25, 0.75}, 5)
    densityLabel:makeLabel("Density", UIFont.Small, COLOR_WHITE, "right")
    self.densityDropdown = densityDropdown:makeComboBox()
    self.densityDropdown:addOption("Sparce")
    self.densityDropdown:addOption("Low")
    self.densityDropdown:addOption("Medium")
    self.densityDropdown:addOption("High")

    self.areaPicker = selectArea:makeAreaPicker()
    self.areaPicker.singleZ = true
    self.areaPicker:setValue({
        x1 = math.floor(player:getX() - 5),
        y1 = math.floor(player:getY() - 5),
        z1 = 0,
        x2 = math.floor(player:getX() + 5),
        y2 = math.floor(player:getY() + 5),
        z2 = 0
    })

    local gobutton, deleteButton = buttons:cols(2, 5)
    self.goButton = gobutton:makeButton("Plant Grasses", self, self.doSpawn)
    self.goButton.backgroundColor = {r=0,g=0.5,b=0,a=1}

    self.deleteButton = deleteButton:makeButton("Clear Grasses", self, self.doRemove)
    self.deleteButton.backgroundColor = {r=0.5,g=0,b=0,a=1}

    -- close button
    win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3):offset(4, -4):makeButton("X", self, self.onClose)
end

function WAT_GrassSpawner:getCoords()
    local value = self.areaPicker:getValue()
    return value.x1, value.y1, value.x2, value.y2, value.z1
end

function WAT_GrassSpawner:onClose()
    self:removeFromUIManager()
    self.areaPicker:cleanup()
    WAT_GrassSpawner.instance = nil
end

function WAT_GrassSpawner:getPlant()
    local type
    if ZombRand(100) < self.typeSlider.currentValue then
        type = "Plants"
    else
        type = "Grass"
    end
    local possibleItems = {}
    for k,v in pairs(WAT_GrassSpawner.spawnables) do
        if v.type == type then
            if self.ageDropdown.selected == 1 or v.age == self.ageDropdown:getOptionText(self.ageDropdown.selected) then
                table.insert(possibleItems, k)
            end
        end
    end
    return possibleItems[ZombRand(#possibleItems)+1]
end

function WAT_GrassSpawner:isValidSquare(square)
    if square == nil then
        return false
    end
    if not square:isOutside() then
        return false
    end
    local objects = square:getObjects()
    if objects:size() > 1 then
        return false
    end
    local object = objects:get(0)
    if object and object:getSprite() and not luautils.stringStarts(object:getSprite():getName(), "blends_natural_01") then
        return false
    end
    return true
end

function WAT_GrassSpawner:getShouldSpawn(square)
    if not self:isValidSquare(square) then
        return false
    end
    -- always spawn if the area is a single square
    if self.areaPicker.value.x1 == self.areaPicker.value.x2 and self.areaPicker.value.y1 == self.areaPicker.value.y2 then
        return true
    end
    local density = self.densityDropdown:getOptionText(self.densityDropdown.selected)
    if density == "Sparce" then
        return ZombRand(32) == 0
    elseif density == "Low" then
        return ZombRand(16) == 0
    elseif density == "Medium" then
        return ZombRand(4) == 0
    else
        return ZombRand(2) == 0
    end
end

function WAT_GrassSpawner:doSpawn()
    local x1, y1, x2, y2, z = self:getCoords()

    for x = x1,x2 do
        for y = y1,y2 do
            local sq = getCell():getGridSquare(x, y, z)
            if sq and self:getShouldSpawn(sq) then
                local plant = self:getPlant()
                local object = IsoObject.new(sq, plant, false)
                sq:AddTileObject(object)
                object:transmitCompleteItemToServer()
            end
        end
    end
end

function WAT_GrassSpawner:doRemove()
    local x1, y1, x2, y2, z = self:getCoords()

    for x = x1,x2 do
        for y = y1,y2 do
            local sq = getCell():getGridSquare(x, y, z)
            for i = sq:getObjects():size(),1,-1 do
                local obj = sq:getObjects():get(i-1)
                if obj then
                    if WAT_GrassSpawner.spawnables[obj:getSprite():getName()] then
                        sq:transmitRemoveItemFromSquare(obj)
                    else
                        local animSprites = obj:getAttachedAnimSprite()
                        if animSprites then
                            for j = animSprites:size()-1,0,-1 do
                                local animSprite = animSprites:get(j)
                                if animSprite and WAT_GrassSpawner.spawnables[animSprite:getName()] then
                                    obj:RemoveAttachedAnim(j)
                                    print("Removed attached anim sprite from object")
                                    sendClientCommand(getPlayer(), 'WAT', 'removeAttachedAnim', {x = x, y = y, z = z, spriteName = obj:getSprite():getName(), index = j})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end