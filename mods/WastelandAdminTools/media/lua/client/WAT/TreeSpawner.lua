WAT_TreeSpawner = ISPanel:derive("WAT_TreeSpawner")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local COLOR_WHITE = {r=1,g=1,b=1,a=1}

function WAT_TreeSpawner.display()
    if WAT_TreeSpawner.instance then
        return
    end
    WAT_TreeSpawner.instance = WAT_TreeSpawner:new()
    WAT_TreeSpawner.instance:initialise()
    WAT_TreeSpawner.instance:addToUIManager()
end

function WAT_TreeSpawner:new()
    local scale = FONT_HGT_SMALL / 12
    local w = 200 * scale
    local h = 130 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WAT_TreeSpawner:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local player = getPlayer()

    local win = GravyUI.Node(self.width, self.height, self):pad(5)

    local header, body = win:rows({FONT_HGT_MEDIUM, win.height - FONT_HGT_MEDIUM - 5}, 5)
    local selectTree, selectAge, selectDensity, selectArea, buttons = body:rows({0.1667, 0.1667, 0.1667, .3333, 0.1667}, 5)

    header:makeLabel("Tree Spawner", UIFont.Medium, COLOR_WHITE, "center")
    local treeLabel, treeDropdown = selectTree:cols({0.25, 0.75}, 5)
    treeLabel:makeLabel("Type", UIFont.Small, COLOR_WHITE, "right")
    self.treeDropdown = treeDropdown:makeComboBox()
    self.treeDropdown:addOption("*Any")
    self.treeDropdown:addOption("*Evergreens")
    self.treeDropdown:addOption("*Deciduous")
    for _, treeName in ipairs(WL_Utils.PossibleTrees) do
        self.treeDropdown:addOption(treeName)
    end

    local ageLabel, ageDropdown = selectAge:cols({0.25, 0.75}, 5)
    ageLabel:makeLabel("Age", UIFont.Small, COLOR_WHITE, "right")
    self.ageDropdown = ageDropdown:makeComboBox()
    self.ageDropdown:addOption("All Ages")
    self.ageDropdown:addOption("Baby")
    self.ageDropdown:addOption("Young")
    self.ageDropdown:addOption("Adult")
    self.ageDropdown:addOption("Jumbo")

    local densityLabel, densityDropdown = selectDensity:cols({0.25, 0.75}, 5)
    densityLabel:makeLabel("Density", UIFont.Small, COLOR_WHITE, "right")
    self.densityDropdown = densityDropdown:makeComboBox()
    self.densityDropdown:addOption("Sparce")
    self.densityDropdown:addOption("Low")
    self.densityDropdown:addOption("Medium")
    self.densityDropdown:addOption("High")
    self.densityDropdown:addOption("Gradual")

    self.areaPicker = selectArea:makeAreaPicker()
    self.areaPicker.forceZ = 0
    self.areaPicker:setValue({
        x1 = math.floor(player:getX() - 5),
        y1 = math.floor(player:getY() - 5),
        z1 = 0,
        x2 = math.floor(player:getX() + 5),
        y2 = math.floor(player:getY() + 5),
        z2 = 0
    })

    local gobutton, deleteButton = buttons:cols(2, 5)
    self.goButton = gobutton:makeButton("Plant Trees", self, self.doSpawn)
    self.goButton.backgroundColor = {r=0,g=0.5,b=0,a=1}

    self.deleteButton = deleteButton:makeButton("Remove Trees", self, self.doRemove)
    self.deleteButton.backgroundColor = {r=0.5,g=0,b=0,a=1}

    -- close button
    win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3):offset(4, -4):makeButton("X", self, self.onClose)
end

function WAT_TreeSpawner:getCoords()
    local value = self.areaPicker:getValue()
    return value.x1, value.y1, value.x2, value.y2
end

function WAT_TreeSpawner:onClose()
    self:removeFromUIManager()
    self.areaPicker:cleanup()
    WAT_TreeSpawner.instance = nil
end

function WAT_TreeSpawner:getTree()
    local treeName = self.treeDropdown:getOptionText(self.treeDropdown.selected)
    if treeName == "*Any" then
        return WL_Utils.PossibleTrees[ZombRand(#WL_Utils.PossibleTrees) + 1]
    elseif treeName == "*Evergreens" then
        return WL_Utils.PossibleTrees[ZombRand(3) + 1]
    elseif treeName == "*Deciduous" then
        return WL_Utils.PossibleTrees[ZombRand(#WL_Utils.PossibleTrees - 3) + 4]
    end
    return treeName
end

function WAT_TreeSpawner:getStage()
    local age = self.ageDropdown:getOptionText(self.ageDropdown.selected)
    if age == "Baby" then
        return ZombRand(2)
    elseif age == "Young" then
        return ZombRand(2) + 1
    elseif age == "Adult" then
        return 3
    elseif age == "Jumbo" then
        return ZombRand(2) + 4
    end
    return ZombRand(5)
end

function WAT_TreeSpawner:getShouldSpawn(square)
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
    elseif density == "Gradual" then
        local x1, y1, x2, y2 = self:getCoords()
        local minX, maxX = math.min(x1, x2), math.max(x1, x2)
        local minY, maxY = math.min(y1, y2), math.max(y1, y2)
        local w = maxX - minX
        local h = maxY - minY

        local cx = (minX + maxX) / 2
        local cy = (minY + maxY) / 2

        local sqX = square:getX()
        local sqY = square:getY()

        local dx = 0
        if w > 0 then dx = math.abs(sqX - cx) / (w / 2) end

        local dy = 0
        if h > 0 then dy = math.abs(sqY - cy) / (h / 2) end

        local dist = math.max(dx, dy)

        local transition_start = 0.5
        local min_denom = 2
        local max_denom = 32
        
        local denom = min_denom
        if dist > transition_start then
            local t = (dist - transition_start) / (1 - transition_start)
            denom = min_denom + (max_denom - min_denom) * t
        end

        return ZombRand(math.floor(denom)) == 0
    else
        return ZombRand(2) == 0
    end
end

function WAT_TreeSpawner:doSpawn()
    local x1, y1, x2, y2 = self:getCoords()

    for x = x1,x2 do
        for y = y1,y2 do
            local sq = getCell():getGridSquare(x, y, 0)
            if self:getShouldSpawn(sq) then
                local tree = self:getTree()
                local stage = self:getStage()
                WL_Utils.SpawnTree(sq, tree, stage)
            end
        end
    end
end

function WAT_TreeSpawner:doRemove()
    local x1, y1, x2, y2 = self:getCoords()

    for x = x1,x2 do
        for y = y1,y2 do
            local sq = getCell():getGridSquare(x, y, 0)
            for i = sq:getObjects():size(),1,-1 do
                local obj = sq:getObjects():get(i-1)
                if obj:getType() == IsoObjectType.tree then
                    sq:transmitRemoveItemFromSquare(obj)
                end
            end
        end
    end
end