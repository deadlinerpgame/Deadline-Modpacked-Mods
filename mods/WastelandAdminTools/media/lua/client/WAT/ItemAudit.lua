require "GravyUI"
require "GroundHighlighter"

WAT_ItemAudit = ISPanelJoypad:derive("WAT_ItemAudit")
WAT_ItemAudit.instance = nil

function WAT_ItemAudit:display()
    if WAT_ItemAudit.instance ~= nil then
        WAT_ItemAudit.instance:close()
    end
    local o = ISPanelJoypad.new(self, 200, 200, 450, 450)
    o:initialise()
    WAT_ItemAudit.instance = o
end

function WAT_ItemAudit:initialise()
    ISPanelJoypad.initialise(self)
    self:addToUIManager()
    self:setAlwaysOnTop(true)
    self.moveWithMouse = true
    self.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self.backgroundColor = {r=0, g=0, b=0, a=1}
    self.groundHighlighter = GroundHighlighter:new()
    self.groundHighlighter:enableXray(true, true)
    self.rangeX = 20
    self.rangeY = 20
    self.rangeMax = 200
    self.rangeMin = 5
    self.showOverlay = false
    self.byCategory = true
    self.duplicates = false
    self.extractPackages = false
    self.showHeatMap = false
    self.heatMap = {}

    local window = GravyUI.Node(self.width, self.height, self):pad(2)
    local header, rangeXSlot, rangeYSlot, buttons, checks, log = window:rows({20, 12, 12, 20, 18, 1}, 5)

    local rangeXLabel, rangeXInput = rangeXSlot:cols({0.3, 0.7}, 2)
    local rangeYLabel, rangeYInput = rangeYSlot:cols({0.3, 0.7}, 2)
    local scanButton, toggleButton, writeButton, closeButton = buttons:cols(4, 3)
    local byCategory, duplicates, extractPackages, showHeatMap, heatmapMax = checks:cols(5, 4)

    self.headerLabel = header
    self.rangeXLabel = rangeXLabel
    self.rangeYLabel = rangeYLabel

    self.rangeXInput = rangeXInput:makeSlider(self, self.rangeXInputChange)
    self.rangeYInput = rangeYInput:makeSlider(self, self.rangeYInputChange)

    self.scanButton = scanButton:makeButton("Scan", self, self.scan)
    self.toggleOverlayButton = toggleButton:makeButton("Toggle Overlay", self, self.toggleOverlay)
    self.writeButton = writeButton:makeButton("Write", self, self.write)
    self.closeButton = closeButton:makeButton("Close", self, self.close)

    self.byCategoryCheck = byCategory:makeTickBox(self, self.categoryCheckChanged)
    self.duplicatesCheck = duplicates:makeTickBox(self, self.duplicatesCheckChanged)
    self.extractPackagesCheck = extractPackages:makeTickBox(self, self.extractPackagesCheckChanged)
    self.showHeatMapCheck = showHeatMap:makeTickBox(self, self.showHeatMapCheckChanged)
    self.heatMapMaxInput = heatmapMax:makeTextBox("Heat Map Max")
    self.heatMapMaxInput:setText(tostring(300))
    self.heatMapMaxInput:setOnlyNumbers(true)

    self.logTextBox = log:makeTextBox("Log")

    self.rangeXInput:setCurrentValue(self.rangeX)
    self.rangeXInput:setValues(self.rangeMin, self.rangeMax, 1, 5, false)

    self.rangeYInput:setCurrentValue(self.rangeY)
    self.rangeYInput:setValues(self.rangeMin, self.rangeMax, 1, 5, false)

    self.byCategoryCheck:addOption("By Category?")
    self.byCategoryCheck:setSelected(1, true)

    self.duplicatesCheck:addOption("Duplicates?")

    self.extractPackagesCheck:addOption("Packages?")

    self.showHeatMapCheck:addOption("Heat Map?")

    self.logTextBox:setMultipleLine(true)
    self.logTextBox:setEditable(true)
    self.logTextBox:setSelectable(true)
	self.logTextBox:addScrollBars()
end

function WAT_ItemAudit:rangeXInputChange()
    self.rangeX = self.rangeXInput:getCurrentValue()
    if self.groundHighlighter.type ~= "none" then
        self.groundHighlighter:remove()
        self:toggleOverlay()
    end
end

function WAT_ItemAudit:rangeYInputChange()
    self.rangeY = self.rangeYInput:getCurrentValue()
    if self.groundHighlighter.type ~= "none" then
        self.groundHighlighter:remove()
        self:toggleOverlay()
    end
end

function WAT_ItemAudit:categoryCheckChanged()
    self.byCategory = self.byCategoryCheck:isSelected(1)
end

function WAT_ItemAudit:duplicatesCheckChanged()
    self.duplicates = self.duplicatesCheck:isSelected(1)
end

function WAT_ItemAudit:extractPackagesCheckChanged()
    self.extractPackages = self.extractPackagesCheck:isSelected(1)
end

function WAT_ItemAudit:showHeatMapCheckChanged()
    self.showHeatMap = self.showHeatMapCheck:isSelected(1)
end

function WAT_ItemAudit:prerender()
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)

    self:drawText("Item Audit", self.headerLabel.left, self.headerLabel.top, 1, 1, 1, 1, UIFont.Medium)
    self:drawText("Range West/East", self.rangeXLabel.left, self.rangeXLabel.top, 1, 1, 1, 1, UIFont.Small)
    self:drawText("Range North/South", self.rangeYLabel.left, self.rangeYLabel.top, 1, 1, 1, 1, UIFont.Small)
end

function WAT_ItemAudit:render()
	ISPanelJoypad.render(self)
end

function WAT_ItemAudit:scan()
    local sx, sy, ex, ey = self:getRange()
    local items = {}
    local itemIds = {}
    local duplicates = {}
    local totalItems = 0
    local totalItemsOnGround = 0
    local totalItemsInContainers = 0
    local totalItemInCars = 0
    local totalDuplicates = 0
    local numInBags = 0
    local checkedSquares = 0
    local packageItemsSeen = 0
    local packageItemsExtracted = 0
    local packageItemsMissingData = 0
    self.heatMap = {}
    self.dupMap = {}

    local function addItem(itemsTable, byCategoryEnabled, itemName, amount, categoryName)
        if byCategoryEnabled then
            local category = categoryName or ""
            itemsTable[category] = itemsTable[category] or {}
            itemsTable[category][itemName] = (itemsTable[category][itemName] or 0) + amount
        else
            itemsTable[itemName] = (itemsTable[itemName] or 0) + amount
        end
    end

    local cell = getCell()
    for x = sx, ex do
    for y = sy, ey do
    for z = 0, 7  do
        local iSquare = cell:getGridSquare(x, y, z)
        if iSquare then
            local squareItems = WL_Utils.scanGridSquare(iSquare)
            if #squareItems > 0 then
                self.heatMap[x] = self.heatMap[x] or {}
                self.heatMap[x][y] = #squareItems
            end
            for _, foundItem in ipairs(squareItems) do
                local item = foundItem.item
                local foundAt = foundItem.foundAt

                local id = item:getID()
                local name = item:getName()
                local category = item:getDisplayCategory() or item:getCategory() or ""
                addItem(items, self.byCategory, name, 1, category)
                totalItems = totalItems + 1

                if itemIds[id] then
                    if self.duplicates then
                        duplicates[name] = (duplicates[name] or 0) + 1
                    end
                    totalDuplicates = totalDuplicates + 1
                    if not self.dupMap[x] then self.dupMap[x] = {} end
                    if not self.dupMap[x][y] then self.dupMap[x][y] = 0 end
                    self.dupMap[x][y] = self.dupMap[x][y] + 1
                else
                    itemIds[id] = true
                end

                if foundAt == "ground" then
                    totalItemsOnGround = totalItemsOnGround + 1
                elseif foundAt == "container" then
                    totalItemsInContainers = totalItemsInContainers + 1
                elseif foundAt == "vehicle" then
                    totalItemInCars = totalItemInCars + 1
                elseif foundAt == "bag" then
                    numInBags = numInBags + 1
                end

                if self.extractPackages and item:getFullType() == "Base.WPI_Package" then
                    packageItemsSeen = packageItemsSeen + 1
                    local modData = item:getModData()
                    local packageData = modData["WPIPackages"]
                    if packageData and packageData.contents then
                        local contentName = packageData.contents.itemName
                        local contentQuantity = tonumber(packageData.contents.quantity) or 0
                        if contentName and contentQuantity > 0 then
                            local extractedCategory = "Packaged Items"
                            local extractedName = contentName
                            local scriptItem = getScriptManager():FindItem(contentName)
                            if scriptItem then
                                extractedName = scriptItem:getDisplayName() or extractedName
                                extractedCategory = scriptItem:getDisplayCategory() or scriptItem:getTypeString() or extractedCategory
                            end

                            addItem(items, self.byCategory, extractedName, contentQuantity, extractedCategory)
                            totalItems = totalItems + contentQuantity
                            packageItemsExtracted = packageItemsExtracted + 1

                            if foundAt == "ground" then
                                totalItemsOnGround = totalItemsOnGround + contentQuantity
                            elseif foundAt == "container" then
                                totalItemsInContainers = totalItemsInContainers + contentQuantity
                            elseif foundAt == "vehicle" then
                                totalItemInCars = totalItemInCars + contentQuantity
                            elseif foundAt == "bag" then
                                numInBags = numInBags + contentQuantity
                            end
                        else
                            packageItemsMissingData = packageItemsMissingData + 1
                        end
                    else
                        packageItemsMissingData = packageItemsMissingData + 1
                    end
                end

            end
    end end end end

    self.logTextBox:clear()

    local lines = {}
    local player = getPlayer()
    table.insert(lines, "===Item Audit===")
    table.insert(lines, string.format("Scanned %d squares from %d,%d with range %dx%d", checkedSquares, player:getX(), player:getY(), self.rangeX, self.rangeY))
    table.insert(lines, string.format("%d items found in %d Categories, %d duplicates", totalItems, #items, totalDuplicates))
    table.insert(lines, string.format("%d on the ground, %d in containers, %d in vehicles, %d in bags", totalItemsOnGround, totalItemsInContainers, totalItemInCars, numInBags))
    table.insert(lines, "")

    if self.duplicates then
        table.insert(lines, "===Duplicates===")
        table.insert(lines, "")
        local duppedItems = {}
        for name, count in pairs(duplicates) do
            table.insert(duppedItems, {name=name, count=count})
        end
        table.sort(duppedItems, function(a, b)
            if a.count == b.count then
                return a.name < b.name
            end
            return a.count > b.count
        end)
        for _, item in ipairs(duppedItems) do
            table.insert(lines, string.format("    %7d: %s", item.count, item.name))
        end
        table.insert(lines, "")
    end

    if self.byCategory then
        table.insert(lines, "===By Category===")
        table.insert(lines, "")

        local categories = {}

        for category, _ in pairs(items) do
            table.insert(categories, category)
        end
        table.sort(categories)

        for _, category in ipairs(categories) do
            table.insert(lines, "")
            local itemsInCategory = items[category]
            local categoryItems = {}
            for name, count in pairs(itemsInCategory) do
                table.insert(categoryItems, {name=name, count=count})
            end
            table.sort(categoryItems, function(a, b)
                if a.count == b.count then
                    return a.name < b.name
                end
                return a.count > b.count
            end)
            table.insert(lines, string.format("%s (%d items)", category, #categoryItems))
            for _, item in ipairs(categoryItems) do
                table.insert(lines, string.format("    %7d: %s", item.count, item.name))
            end
        end
    else
        table.insert(lines, "===All Items===")
        table.insert(lines, "")
        local is = {}
        for name, count in pairs(items) do
            table.insert(is, {name=name, count=count})
        end
        table.sort(is, function(a, b)
            if a.count == b.count then
                return a.name < b.name
            end
            return a.count > b.count
        end)
        for _, item in ipairs(is) do
            table.insert(lines, string.format("    %7d: %s", item.count, item.name))
        end
    end

    table.insert(lines, "")

    if self.extractPackages then
        table.insert(lines, string.format("Package extraction debug: %d package items seen, %d extracted, %d missing data", packageItemsSeen, packageItemsExtracted, packageItemsMissingData))
        table.insert(lines, "")
    end

    self.logTextBox:setText(table.concat(lines, "\n"))
end

function WAT_ItemAudit:toggleOverlay()
    if self.groundHighlighter.type == "none" then
        local sx, sy, ex, ey = self:getRange()
        self.groundHighlighter:highlightSquare(sx, sy, ex, ey)
    else
        self.groundHighlighter:remove()
    end
end

function WAT_ItemAudit:close()
    self:setVisible(false)
    self:removeFromUIManager()
    WAT_ItemAudit.instance = nil
end

function WAT_ItemAudit:removeFromUIManager()
    self.groundHighlighter:remove()
    ISPanelJoypad.removeFromUIManager(self)
end

function WAT_ItemAudit:getRange()
    local square = getPlayer():getCurrentSquare()
    if not square then
        return 0, 0, 0, 0
    end
    local start_x = square:getX()
    local start_y = square:getY()
    return start_x - self.rangeX, start_y - self.rangeY,
           start_x + self.rangeX, start_y + self.rangeY
end

function WAT_ItemAudit:write()
    local timestamp = getTimestamp()
    local filename = "ItemAudit_" .. timestamp .. ".txt"
    local writer = getFileWriter(filename, true, false)
    writer:write(self.logTextBox:getText())
    writer:close()
    getPlayer():setHaloNote("Saved to " .. filename)
end


local function map_override(self)
    if not WAT_ItemAudit.instance or self.isometric then
        return
    end
    local sx, sy, ex, ey = WAT_ItemAudit.instance:getRange()

    local tlX = self.mapAPI:worldToUIX(sx, sy)
    local tlY = self.mapAPI:worldToUIY(sx, sy)
    local brX = self.mapAPI:worldToUIX(ex, ey)
    local brY = self.mapAPI:worldToUIY(ex, ey)
    self:drawRect(tlX, tlY, brX - tlX, brY - tlY, 0.2, 0, 1, 0)

    local max = tonumber(WAT_ItemAudit.instance.heatMapMaxInput:getText() or 300)
    if WAT_ItemAudit.instance.showHeatMap then
        for x, yMap in pairs(WAT_ItemAudit.instance.heatMap) do
            for y, count in pairs(yMap) do
                tlX = self.mapAPI:worldToUIX(x, y)
                tlY = self.mapAPI:worldToUIY(x, y)
                brX = self.mapAPI:worldToUIX(x + 1, y + 1)
                brY = self.mapAPI:worldToUIY(x + 1, y + 1)
                local alpha = math.min(count / max, 1)
                self:drawRect(tlX, tlY, brX - tlX, brY - tlY, alpha, 1, 0, 0)
            end
        end
    end

    if WAT_ItemAudit.instance.duplicates then
        for x, yMap in pairs(WAT_ItemAudit.instance.dupMap) do
            for y, count in pairs(yMap) do
                tlX = self.mapAPI:worldToUIX(x, y)
                tlY = self.mapAPI:worldToUIY(x, y)
                brX = self.mapAPI:worldToUIX(x + 1, y + 1)
                brY = self.mapAPI:worldToUIY(x + 1, y + 1)
                local alpha = math.min(count / max, 1)
                self:drawRect(tlX, tlY, brX - tlX, brY - tlY, alpha, 1, 0, 0)
            end
        end
    end
end

if not WAT_ItemAudit.original_ISWorldMap_render then
    WAT_ItemAudit.original_ISWorldMap_render = ISWorldMap.render
    function ISWorldMap:render()
        WAT_ItemAudit.original_ISWorldMap_render(self)
        map_override(self)
    end
end
