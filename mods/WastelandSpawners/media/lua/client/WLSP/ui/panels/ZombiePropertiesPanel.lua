---
--- ZombiePropertiesPanel.lua
--- Zombie properties panel for spawner configuration
---

WLSP_ZombiePropertiesPanel = ISPanel:derive("WLSP_ZombiePropertiesPanel")

function WLSP_ZombiePropertiesPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o:initialise()
    return o
end

function WLSP_ZombiePropertiesPanel:initialise()
    ISPanel.initialise(self)
    
    -- Store conditional UI elements for show/hide
    self.zombiePropertiesElements = {}
    self.targetElements = {}
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16), WLSP_UI_Constants.scale(16))

    local vstack = win:makeVerticalStack(WLSP_UI_Constants.scale(8))

    -- Title
    local titleRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_LARGE)
    titleRow:makeLabel("Zombie Properties", UIFont.Large, WLSP_UI_Constants.COLOR_WHITE, "left")

    -- Outfit (optional) - Always visible, not part of zombie properties
    local outfitRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local outfitLabel, outfitField = outfitRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    outfitLabel:makeLabel("Outfit (optional):", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left")
    self.outfitCombo = outfitField:makeComboBox()
    self.outfitCombo:setToolTipMap({
        defaultTooltip = "Select an outfit for spawned zombies (optional). Blank for random.",
    })
    
    -- Populate outfit options
    self.maleOutfits = getAllOutfits(false)
    self.femaleOutfits = getAllOutfits(true)
    self.outfitCombo:addOption("None")

    local outfitSet = {}
    
    for i=0, self.maleOutfits:size()-1 do
        local outfitName = self.maleOutfits:get(i)
        local text = outfitName
        if not self.femaleOutfits:contains(outfitName) then
            text = outfitName .. " - Male Only"
        end
        table.insert(outfitSet, {text, outfitName})
    end
    
    for i=0, self.femaleOutfits:size()-1 do
        local outfitName = self.femaleOutfits:get(i)
        if not self.maleOutfits:contains(outfitName) then
            table.insert(outfitSet, {outfitName .. " - Female Only", outfitName})
        end
    end

    table.sort(outfitSet, function(a, b) return a[1] < b[1] end)

    for _, outfit in ipairs(outfitSet) do
        self.outfitCombo:addOptionWithData(outfit[1], outfit[2])
    end

    -- Enable checkbox
    local enableHeaderRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    local enableCheck, _ = enableHeaderRow:cols({ WLSP_UI_Constants.scale(30), 1 }, WLSP_UI_Constants.scale(5))
    self.enableCheckbox = enableCheck:makeTickBox(self, self.onZombiePropsCheckChanged)
    self.enableCheckbox:addOption("")
    enableHeaderRow:offset(WLSP_UI_Constants.scale(35), 0):makeLabel("Override Zombie Properties", UIFont.Medium, WLSP_UI_Constants.COLOR_HEADER, "left")
    
    -- Row 1: Speed and Cognition (2 columns)
    local row1 = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local speedCol, cognitionCol = row1:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(10))
    
    -- Speed (left column)
    local speedLabel, speedField = speedCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    table.insert(self.zombiePropertiesElements, speedLabel:makeLabel("Speed:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left"))
    self.speedCombo = speedField:makeComboBox()
    table.insert(self.zombiePropertiesElements, self.speedCombo)
    self.speedCombo:addOption("Default")
    self.speedCombo:addOption("Slow Shambler")
    self.speedCombo:addOption("Fast Shambler")
    self.speedCombo:addOption("Sprinter")
    
    -- Cognition (right column)
    local cognitionLabel, cognitionField = cognitionCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    table.insert(self.zombiePropertiesElements, cognitionLabel:makeLabel("Cognition:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left"))
    self.cognitionCombo = cognitionField:makeComboBox()
    table.insert(self.zombiePropertiesElements, self.cognitionCombo)
    self.cognitionCombo:addOption("Default")
    self.cognitionCombo:addOption("Smart")
    self.cognitionCombo:addOption("Random")
    
    -- Row 2: Health Modifier and Force Crawling (2 columns)
    local row2 = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8))
    local healthCol, crawlCol = row2:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(10))
    
    -- Health Modifier (left column)
    local healthLabel, healthField = healthCol:cols({ 0.35, 0.65 }, WLSP_UI_Constants.scale(5))
    table.insert(self.zombiePropertiesElements, healthLabel:makeLabel("Health Mod:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left"))
    self.healthModifier = healthField:makeTextBox("", true)
    self.healthModifier:setTooltip("Multiplier for zombie toughness\\n\\n1.0 = default\\n0.5 = half health\\n2.0 = double health)")
    table.insert(self.zombiePropertiesElements, self.healthModifier)
    
    -- Force Crawling (right column)
    local crawlLabel, crawlField = crawlCol:cols({ 0.5, 0.5 }, WLSP_UI_Constants.scale(5))
    table.insert(self.zombiePropertiesElements, crawlLabel:makeLabel("Force Crawl:", UIFont.Small, WLSP_UI_Constants.COLOR_WHITE, "left"))
    self.forceCrawling = crawlField:makeTickBox()
    table.insert(self.zombiePropertiesElements, self.forceCrawling)
    self.forceCrawling:addOption("")
    
    -- Target Location Section
    local targetHeaderRow = vstack:makeNode(WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(6))
    local targetCheck, _ = targetHeaderRow:cols({ WLSP_UI_Constants.scale(30), 1 }, WLSP_UI_Constants.scale(5))
    self.targetCheckbox = targetCheck:makeTickBox(self, self.onTargetCheckChanged)
    self.targetCheckbox:addOption("")
    targetHeaderRow:offset(WLSP_UI_Constants.scale(35), 0):makeLabel("Use Target Location", UIFont.Medium, WLSP_UI_Constants.COLOR_HEADER, "left")
    
    -- Target Position - 2x normal row height
    local targetRow = vstack:makeNode((WLSP_UI_Constants.FONT_HGT_MEDIUM + WLSP_UI_Constants.scale(8)) * 2 + WLSP_UI_Constants.scale(5))
    local targetLabel, targetField = targetRow:cols({ 0.3, 0.7 }, WLSP_UI_Constants.scale(10))
    table.insert(self.targetElements, targetLabel:makeLabel("Target Position:", UIFont.Small, WLSP_UI_Constants.COLOR_TARGET, "left"))
    self.targetPicker = targetField:makePointPicker()
    table.insert(self.targetElements, self.targetPicker)
end

function WLSP_ZombiePropertiesPanel:onZombiePropsCheckChanged()
    self:updateZombiePropertiesVisibility()
end

function WLSP_ZombiePropertiesPanel:onTargetCheckChanged()
    self:updateTargetVisibility()
end

function WLSP_ZombiePropertiesPanel:updateZombiePropertiesVisibility()
    local visible = self.enableCheckbox:isSelected(1)
    for _, element in ipairs(self.zombiePropertiesElements) do
        element:setVisible(visible)
    end
end

function WLSP_ZombiePropertiesPanel:updateTargetVisibility()
    local targetVisible = self.targetCheckbox:isSelected(1)
    for _, element in ipairs(self.targetElements) do
        element:setVisible(targetVisible)
    end
end

function WLSP_ZombiePropertiesPanel:loadData(spawner)
    if spawner and spawner.zombieProperties then
        self.enableCheckbox:setSelected(1, true)
        
        -- Speed mapping: slowShambler→2, shambler→3, sprinter→4, nil/other→1
        local speed = spawner.zombieProperties.speed
        if speed == "slowShambler" then
            self.speedCombo.selected = 2
        elseif speed == "shambler" then
            self.speedCombo.selected = 3
        elseif speed == "sprinter" then
            self.speedCombo.selected = 4
        else
            self.speedCombo.selected = 1
        end
        
        -- Cognition mapping: smart→2, random→3, nil/other→1
        local cognition = spawner.zombieProperties.cognition
        if cognition == "smart" then
            self.cognitionCombo.selected = 2
        elseif cognition == "random" then
            self.cognitionCombo.selected = 3
        else
            self.cognitionCombo.selected = 1
        end
        
        -- Health modifier
        if spawner.zombieProperties.healthModifier then
            self.healthModifier:setText(tostring(spawner.zombieProperties.healthModifier))
        else
            self.healthModifier:setText("")
        end
        
        -- Force crawling
        self.forceCrawling:setSelected(1, spawner.zombieProperties.forceCrawling or false)
    else
        -- Defaults for no zombie properties
        self.enableCheckbox:setSelected(1, false)
        self.speedCombo.selected = 1
        self.cognitionCombo.selected = 1
        self.healthModifier:setText("")
        self.forceCrawling:setSelected(1, false)
    end
    
    -- Outfit
    if spawner and spawner.outfit then
        -- Find the outfit in the combo box
        for i = 1, #self.outfitCombo.options do
            if self.outfitCombo:getOptionData(i) == spawner.outfit then
                self.outfitCombo.selected = i
                break
            end
        end
    else
        self.outfitCombo.selected = 1 -- "None"
    end
    
    -- Target Location
    if spawner then
        if spawner.targetLocation then
            self.targetCheckbox:setSelected(1, true)
            self.targetPicker:setValue({
                x = spawner.targetLocation.x,
                y = spawner.targetLocation.y,
                z = spawner.targetLocation.z
            })
        else
            self.targetCheckbox:setSelected(1, false)
        end
    else
        self.targetCheckbox:setSelected(1, false)
        local player = getPlayer()
        if player then
            self.targetPicker:setValue({
                x = player:getX() + 10,
                y = player:getY() + 10,
                z = player:getZ()
            })
        end
    end
    
    self:updateZombiePropertiesVisibility()
    self:updateTargetVisibility()
end

function WLSP_ZombiePropertiesPanel:getData()
    local data = {}
    
    if self.enableCheckbox:isSelected(1) then
        data.zombieProperties = {}
        
        -- Speed: only include if not "Default"
        local selectedSpeed = self.speedCombo.selected
        if selectedSpeed == 2 then
            data.zombieProperties.speed = "slowShambler"
        elseif selectedSpeed == 3 then
            data.zombieProperties.speed = "shambler"
        elseif selectedSpeed == 4 then
            data.zombieProperties.speed = "sprinter"
        end
        -- Don't include speed if Default (selectedSpeed == 1)
        
        -- Cognition: only include if not "Default"
        local selectedCognition = self.cognitionCombo.selected
        if selectedCognition == 2 then
            data.zombieProperties.cognition = "smart"
        elseif selectedCognition == 3 then
            data.zombieProperties.cognition = "random"
        end
        -- Don't include cognition if Default (selectedCognition == 1)
        
        -- Health modifier: only include if not empty and valid number
        local healthText = self.healthModifier:getText()
        if healthText and healthText ~= "" then
            local healthNum = tonumber(healthText)
            if healthNum then
                data.zombieProperties.healthModifier = healthNum
            end
        end
        
        -- Force crawling: only include if checked (true value)
        if self.forceCrawling:isSelected(1) then
            data.zombieProperties.forceCrawling = true
        end
        
        -- If no properties were set, don't include zombieProperties at all
        if not data.zombieProperties.speed and
           not data.zombieProperties.cognition and
           not data.zombieProperties.healthModifier and
           not data.zombieProperties.forceCrawling then
            data.zombieProperties = nil
        end
    end
    
    -- Outfit: saved on main spawner object, not in zombieProperties
    local outfitData = self.outfitCombo:getOptionData(self.outfitCombo.selected)
    if outfitData then
        data.outfit = outfitData
    end
    
    -- Target Location
    if self.targetCheckbox:isSelected(1) then
        local target = self.targetPicker:getValue()
        data.targetLocation = { x = target.x, y = target.y, z = target.z }
    end
    
    return data
end