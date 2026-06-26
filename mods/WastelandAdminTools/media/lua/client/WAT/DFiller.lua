WAT_DFiller = ISPanel:derive("WAT_DFiller")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local COLOR_WHITE = {r=1,g=1,b=1,a=1}

function WAT_DFiller.display()
    if WAT_DFiller.instance then
        return
    end
    WAT_DFiller.instance = WAT_DFiller:new()
    WAT_DFiller.instance:initialise()
    WAT_DFiller.instance:addToUIManager()
end

function WAT_DFiller:new()
    local scale = FONT_HGT_SMALL / 12
    local w = 400 * scale
    local h = 300 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self
    return o
end

function WAT_DFiller:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true
    self.backgroundColor = {r=0, g=0, b=0, a=0.8}
    self.borderColor = {r=1, g=1, b=1, a=0.5}

    local win = GravyUI.Node(self.width, self.height, self):pad(5)

    local header, body = win:rows({FONT_HGT_MEDIUM + 10, 1}, 5)
    
    header:makeLabel("D-Filler", UIFont.Medium, COLOR_WHITE, "center")
    
    -- Close button
    win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3):offset(4, -4):makeButton("X", self, self.onClose)

    local areaRow, listLabelRow, listRow, buttonRow = body:rows({0.2, FONT_HGT_SMALL + 5, 0.6, 0.1}, 5)

    -- Area Picker
    self.areaPicker = areaRow:makeAreaPicker()
    local player = getPlayer()
    self.areaPicker:setValue({
        x1 = math.floor(player:getX() - 5),
        y1 = math.floor(player:getY() - 5),
        z1 = math.floor(player:getZ()),
        x2 = math.floor(player:getX() + 5),
        y2 = math.floor(player:getY() + 5),
        z2 = math.floor(player:getZ())
    })

    -- Lists
    local catLabel, locLabel = listLabelRow:cols(2, 5)
    catLabel:makeLabel("Categories:", UIFont.Small, COLOR_WHITE, "left")
    locLabel:makeLabel("Body Locations:", UIFont.Small, COLOR_WHITE, "left")

    local catListCol, locListCol = listRow:cols(2, 5)
    
    -- Category List
    self.categoryList = catListCol:makeScrollingListBox(UIFont.Small)
    self.categoryList.drawBorder = true
    self.categoryList.doDrawItem = function(list, y, item, alt)
        return self:drawCategoryItem(list, y, item, alt)
    end
    self.categoryList.onMouseDown = function(list, x, y)
        if list.items then
            local row = list:rowAt(x, y)
            if row >= 1 and row <= #list.items then
                local item = list.items[row]
                item.item.selected = not item.item.selected
                self:populateBodyLocations()
            end
        end
    end

    -- Body Location List
    self.bodyLocationList = locListCol:makeScrollingListBox(UIFont.Small)
    self.bodyLocationList.drawBorder = true
    self.bodyLocationList.doDrawItem = function(list, y, item, alt)
        return self:drawCategoryItem(list, y, item, alt)
    end
    self.bodyLocationList.onMouseDown = function(list, x, y)
        if list.items then
            local row = list:rowAt(x, y)
            if row >= 1 and row <= #list.items then
                local item = list.items[row]
                item.item.selected = not item.item.selected
            end
        end
    end

    self:populateCategories()
    self:populateBodyLocations()

    -- Buttons
    local clearCol, goCol = buttonRow:cols(2, 5)
    
    self.clearButton = clearCol:makeButton("Clear Containers", self, self.onClear)
    self.clearButton.backgroundColor = {r=0.5,g=0,b=0,a=1}

    self.goButton = goCol:makeButton("Go", self, self.onGo)
    self.goButton.backgroundColor = {r=0,g=0.5,b=0,a=1}
end

function WAT_DFiller:drawCategoryItem(list, y, item, alt)
    local a = 0.9
    local height = list.itemheight
    
    if alt then
        list:drawRect(0, y, list:getWidth(), height, 0.3, 0.3, 0.3, 0.3)
    end
    
    list:drawRectBorder(0, y, list:getWidth(), height, a, list.borderColor.r, list.borderColor.g, list.borderColor.b)
    
    -- Checkbox
    local checkSize = height - 4
    local checkX = 4
    local checkY = y + 2
    
    list:drawRectBorder(checkX, checkY, checkSize, checkSize, 1, 1, 1, 1)
    if item.item.selected then
        list:drawRect(checkX + 2, checkY + 2, checkSize - 4, checkSize - 4, 1, 0, 1, 0)
    end
    
    list:drawText(item.text, checkX + checkSize + 5, y + (height - FONT_HGT_SMALL) / 2, 1, 1, 1, a, list.font)
    
    return y + height
end

function WAT_DFiller:populateCategories()
    local scriptManager = getScriptManager()
    local allItems = scriptManager:getAllItems()
    local categories = {}
    
    for i=0, allItems:size()-1 do
        local item = allItems:get(i)
        if not item:getObsolete() and not item:isHidden() then
            local cat = item:getDisplayCategory()
            if cat then
                local bodyLoc = item:getBodyLocation()
                if bodyLoc and bodyLoc ~= "" then
                    categories[cat] = true
                end
            end
        end
    end
    
    local sortedCats = {}
    for cat, _ in pairs(categories) do
        table.insert(sortedCats, cat)
    end
    table.sort(sortedCats)
    
    for _, cat in ipairs(sortedCats) do
        self.categoryList:addItem(cat, {selected = false, name = cat})
    end
end

function WAT_DFiller:populateBodyLocations()
    -- Capture currently selected locations
    local previouslySelected = {}
    for _, item in ipairs(self.bodyLocationList.items) do
        if item.item.selected then
            previouslySelected[item.item.name] = true
        end
    end

    self.bodyLocationList:clear()
    
    local selectedCategories = {}
    for _, item in ipairs(self.categoryList.items) do
        if item.item.selected then
            selectedCategories[item.item.name] = true
        end
    end
    
    local scriptManager = getScriptManager()
    local allItems = scriptManager:getAllItems()
    local locations = {}
    
    for i=0, allItems:size()-1 do
        local item = allItems:get(i)
        if not item:getObsolete() and not item:isHidden() then
            local cat = item:getDisplayCategory()
            if selectedCategories[cat] then
                local bodyLoc = item:getBodyLocation()
                if bodyLoc and bodyLoc ~= "" then
                    locations[bodyLoc] = true
                end
            end
        end
    end
    
    local sortedLocs = {}
    for loc, _ in pairs(locations) do
        table.insert(sortedLocs, loc)
    end
    table.sort(sortedLocs)
    
    for _, loc in ipairs(sortedLocs) do
        local isSelected = previouslySelected[loc] or false
        self.bodyLocationList:addItem(loc, {selected = isSelected, name = loc})
    end
end

function WAT_DFiller:onClose()
    self:removeFromUIManager()
    if self.areaPicker then
        self.areaPicker:cleanup()
    end
    WAT_DFiller.instance = nil
end

function WAT_DFiller:onClear()
    local area = self.areaPicker:getValue()
    local containers = self:findContainers(area)
    
    if #containers == 0 then
        local modal = ISModalDialog:new(getCore():getScreenWidth()/2 - 100, getCore():getScreenHeight()/2 - 50, 200, 100, "No containers found in area", false)
        modal:initialise()
        modal:addToUIManager()
        return
    end
    
    for _, container in ipairs(containers) do
        for i=container:getItems():size(), 1, -1 do
            local item = container:getItems():get(i-1)
            container:DoRemoveItem(item)
            if isClient() then
                container:removeItemOnServer(item)
            end
        end
        if isClient() then
            container:setExplored(true)
        end
    end
    
    local msg = string.format("%d containers cleared", #containers)
    local modal = ISModalDialog:new(getCore():getScreenWidth()/2 - 100, getCore():getScreenHeight()/2 - 50, 200, 100, msg, false)
    modal:initialise()
    modal:addToUIManager()
end

function WAT_DFiller:onGo()
    local selectedCategories = {}
    local anySelected = false
    for _, item in ipairs(self.categoryList.items) do
        if item.item.selected then
            selectedCategories[item.item.name] = true
            anySelected = true
        end
    end
    
    if not anySelected then
        return -- No categories selected
    end

    local selectedLocations = {}
    local anyLocSelected = false
    for _, item in ipairs(self.bodyLocationList.items) do
        if item.item.selected then
            selectedLocations[item.item.name] = true
            anyLocSelected = true
        end
    end
    
    local area = self.areaPicker:getValue()
    local containers = self:findContainers(area)
    
    if #containers == 0 then
        print("No containers found in area")
        return
    end
    
    local itemsToSpawn = self:gatherItems(selectedCategories, selectedLocations, anyLocSelected)
    self:distributeItems(itemsToSpawn, containers)
end

function WAT_DFiller:findContainers(area)
    local containers = {}
    local cell = getCell()
    
    for z = area.z1, area.z2 do
        for x = area.x1, area.x2 do
            for y = area.y1, area.y2 do
                local sq = cell:getGridSquare(x, y, z)
                if sq then
                    local objects = sq:getObjects()
                    for i=0, objects:size()-1 do
                        local obj = objects:get(i)
                        local container = obj:getContainer()
                        if container and container:getType() ~= "floor" then
                            -- Ignore mannequins
                            local isMannequin = instanceof(obj, "IsoMannequin")
                            if not isMannequin then
                                table.insert(containers, container)
                            end
                        end
                    end
                end
            end
        end
    end
    
    return containers
end

function WAT_DFiller:gatherItems(categories, locations, filterLocations)
    local scriptManager = getScriptManager()
    local allItems = scriptManager:getAllItems()
    local groupedItems = {} -- [BodyLocation][Category] = {items...}
    
    for i=0, allItems:size()-1 do
        local item = allItems:get(i)
        if not item:getObsolete() and not item:isHidden() then
            local cat = item:getDisplayCategory()
            if categories[cat] then
                local bodyLoc = item:getBodyLocation() or "Unknown"
                
                if not filterLocations or locations[bodyLoc] then
                    if not groupedItems[bodyLoc] then groupedItems[bodyLoc] = {} end
                    if not groupedItems[bodyLoc][cat] then groupedItems[bodyLoc][cat] = {} end
                    
                    table.insert(groupedItems[bodyLoc][cat], item:getFullName())
                end
            end
        end
    end
    
    return groupedItems
end

function WAT_DFiller:distributeItems(groupedItems, containers)
    local totalItems = 0
    
    -- Clear containers first
    for _, container in ipairs(containers) do
        for i=container:getItems():size(), 1, -1 do
            local item = container:getItems():get(i-1)
            container:DoRemoveItem(item)
            if isClient() then
                container:removeItemOnServer(item)
            end
        end
    end

    -- Flatten the groups into a list of item batches to keep them together
    local batches = {}
    for bodyLoc, catGroups in pairs(groupedItems) do
        for cat, items in pairs(catGroups) do
            table.insert(batches, items)
        end
    end
    
    -- Sort batches by size (largest first)
    table.sort(batches, function(a,b) return #a > #b end)
    
    -- Track item counts per container
    local containerData = {}
    for i, container in ipairs(containers) do
        table.insert(containerData, {
            container = container,
            count = 0
        })
    end
    
    for _, batch in ipairs(batches) do
        local i = 1
        while i <= #batch do
            -- Find container with lowest count
            local bestC = containerData[1]
            for j=2, #containerData do
                if containerData[j].count < bestC.count then
                    bestC = containerData[j]
                end
            end
            
            local space = 50 - bestC.count
            local remaining = #batch - i + 1
            
            local countToAdd = 1
            if space > 0 then
                countToAdd = math.min(space, remaining)
            end
            
            for k=0, countToAdd-1 do
                local item = batch[i+k]
                local newItem = bestC.container:AddItem(item)
                if newItem and isClient() then
                    bestC.container:addItemOnServer(newItem)
                end
                bestC.count = bestC.count + 1
                totalItems = totalItems + 1
            end
            
            i = i + countToAdd
        end
    end
    
    -- Sync changes
    local usedContainers = 0
    for _, data in ipairs(containerData) do
        if data.count > 0 then
            usedContainers = usedContainers + 1
        end
        local container = data.container
        if isClient() then
            container:setExplored(true)
        end
    end
    
    local msg = string.format("%d containers filled with %d items", usedContainers, totalItems)
    local modal = ISModalDialog:new(getCore():getScreenWidth()/2 - 100, getCore():getScreenHeight()/2 - 50, 200, 100, msg, false)
    modal:initialise()
    modal:addToUIManager()
end