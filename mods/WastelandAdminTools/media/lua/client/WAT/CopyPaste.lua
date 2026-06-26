WAT_CopyPaste = ISCollapsableWindow:derive("WAT_CopyPaste")
WAT_CopyPaste.instance = nil

function WAT_CopyPaste:display()
    if WAT_CopyPaste.instance then
        WAT_CopyPaste.instance:close()
    end
    local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12
    local width = scale * 315
    local height = scale * 250
    local x = getCore():getScreenWidth() / 2 - width / 2
    local y = getCore():getScreenHeight() / 2 - height / 2
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.scale = scale
    o:initialise()
    o:addToUIManager()
    WAT_CopyPaste.instance = o
    return o
end

function WAT_CopyPaste:initialise()
    ISCollapsableWindow.initialise(self)

    self.moveWithMouse = true
    self:setResizable(false)

    self.contents = nil

    local win = GravyUI.Node(self.width, self.height, self):pad(5 * self.scale, 20 * self.scale, 5 * self.scale, 5 * self.scale)
    
    local header, body, footer = win:rows({20 * self.scale, 1.0, 50 * self.scale}, 5 * self.scale)
    
    local sourceSection, destSection, togglesSection = body:rows({0.4, 0.4, 0.2}, 5 * self.scale)
    
    -- Source Section
    local sourceRow1, sourceRow2 = sourceSection:rows({0.66, 0.34}, 2 * self.scale)
    local sourceLabelNode, sourceSelectorNode = sourceRow1:cols({0.3, 0.7}, 5 * self.scale)
    local sourceClearBtnNode, sourceStatusNode, copyBtnNode = sourceRow2:cols({0.25, 0.5, 0.25}, 5 * self.scale)
    
    -- Dest Section
    local destRow1, destRow2 = destSection:rows({0.66, 0.34}, 2 * self.scale)
    local destLabelNode, destSelectorNode = destRow1:cols({0.3, 0.7}, 5 * self.scale)
    local destClearBtnNode, destStatusNode, pasteBtnNode = destRow2:cols({0.25, 0.5, 0.25}, 5 * self.scale)
    
    -- Footer Section
    local footerRow1, footerRow2 = footer:rows({0.5, 0.5}, 2 * self.scale)
    local resetBtnNode, exportBtnNode, importBtnNode = footerRow1:cols({0.33, 0.33, 0.33}, 5 * self.scale)
    local footerSpacerNode, fileExportBtnNode, fileImportBtnNode = footerRow2:cols({0.33, 0.33, 0.33}, 5 * self.scale)

    self.line1Y = math.floor(sourceSection.bottom)
    self.line2Y = math.floor(destSection.bottom)

    self.header = header:makeLabel("Tile Copy Paste", UIFont.Large, {r=1, g=1, b=1, a=1}, "center")

    -- Source Controls
    self.areaSelectorLabel = sourceLabelNode:makeLabel("Select Source:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.areaSelector = sourceSelectorNode:makeAreaPicker()
    self.areaSelector.groundHighlighter:setColor(0.5, 1.0, 0.5, 1.0)

    self.copyButton = copyBtnNode:makeButton("Copy", self, self.onCopy)
    self.copyButton.tooltip = "Copy enabled tiles from the copy area."

    self.deleteButton = sourceClearBtnNode:makeButton("Clear", self, self.onDeleteButtonClick)
    self.deleteButton.tooltip = "Delete the enabled tiles copy area."
    
    self.sourceStatus = sourceStatusNode:makeLabel("", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")

    -- Dest Controls
    self.pointSelectorLabel = destLabelNode:makeLabel("Select Destination:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    self.pointSelector = destSelectorNode:makePointPicker()
    self.pointSelector.groundHighlighter:setColor(0.5, 0.5, 1.0, 1.0)

    self.pasteButton = pasteBtnNode:makeButton("Paste", self, self.onPaste)
    self.pasteButton.tooltip = "Paste the copied tiles to the paste area."

    self.clearButton = destClearBtnNode:makeButton("Clear", self, self.onClearButtonClick)
    self.clearButton.tooltip = "Delete the enabled tiles from the paste area."
    
    self.status = destStatusNode:makeLabel("", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")

    -- Toggles
    local toggle1, toggle2, toggle3 = togglesSection:cols({0.33, 0.33, 0.33}, 2 * self.scale)
    
    self.toggleGround = toggle1:makeTickBox()
    self.toggleGround:addOption("Ground")
    self.toggleGround:setSelected(1, true)
    
    self.toggleFloors = toggle2:makeTickBox()
    self.toggleFloors:addOption("Floors")
    self.toggleFloors:setSelected(1, true)
    
    self.toggleRoofHide = toggle3:makeTickBox()
    self.toggleRoofHide:addOption("Roof Hide")
    
    local tooltip = "Ground: Include floor tiles on ground level.<br>Floors: Include floor tiles on upper levels.<br>Roof Hide: Add floor tiles to hide roofs properly."
    self.toggleGround.tooltip = tooltip
    self.toggleFloors.tooltip = tooltip
    self.toggleRoofHide.tooltip = tooltip

    -- Footer Controls
    self.resetButton = resetBtnNode:makeButton("Reset", self, self.onReset)
    self.resetButton.tooltip = "Reset the copy and paste area and clear the clipboard."

    self.exportButton = exportBtnNode:makeButton("Save Clipboard", self, self.onExport)
    self.exportButton.tooltip = "Export the clipboard."

    self.importButton = importBtnNode:makeButton("Load Clipboard", self, self.onImport)
    self.importButton.tooltip = "Import a previous exported clipboard."

    self.fileExportButton = fileExportBtnNode:makeButton("Save File", self, self.onFileExport)
    self.fileExportButton.tooltip = "Export the clipboard to a file."

    self.fileImportButton = fileImportBtnNode:makeButton("Load File", self, self.onFileImport)
    self.fileImportButton.tooltip = "Import a previous exported clipboard from a file."

    self.pasteArea = GroundHighlighter:new()
    self.pasteArea:setColor(0.5, 0.5, 1.0, 1.0)

    self.pendingAdds = nil
    self.pendingActionCooldown = 0
    self.isActive = false

end

function WAT_CopyPaste:render()
    ISCollapsableWindow.render(self)

    self:drawRectBorder(0, self.line1Y, self:getWidth(), 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
    self:drawRectBorder(0, self.line2Y, self:getWidth(), 1, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);
end

function WAT_CopyPaste:prerender()

    local area = self.areaSelector:getValue()
    local point = self.pointSelector:getValue()

    local isAreaSet = not (area.x1 == 0 and area.y1 == 0 and area.z1 == 0 and area.x2 == 0 and area.y2 == 0 and area.z2 == 0)
    local isPointSet = not (point.x == 0 and point.y == 0 and point.z == 0)

    if self.copyButton:isEnabled() ~= isAreaSet then
        self.copyButton:setEnable(isAreaSet)
    end
    if self.deleteButton:isEnabled() ~= isAreaSet then
        self.deleteButton:setEnable(isAreaSet)
    end
    if self.pasteButton:isEnabled() ~= isPointSet then
        self.pasteButton:setEnable(isPointSet)
    end
    if self.clearButton:isEnabled() ~= isPointSet then
        self.clearButton:setEnable(isPointSet)
    end

    ISCollapsableWindow.prerender(self)

    if self.pendingActionCooldown <= getTimestampMs() then
        self:processNextPendingAdd()
        if self.pendingActionCooldown <= getTimestampMs() then
            self.pendingActionCooldown = getTimestampMs() + 20
        end
    end

    if self.contents then
        local point = self.pointSelector:getValue()
        local x = point.x
        local y = point.y
        local z = point.z
        local bounds = self.pasteArea.bounds
        if x ~= bounds.x1 or
           y ~= bounds.y1 or
           z ~= bounds.z1 or
           x + self.contents.width - 1 ~= bounds.x2 or
           y + self.contents.height - 1 ~= bounds.y2 or
           z + self.contents.depth - 1 ~= bounds.z2 then
            self.areaSelector:_updateGroundHighlight(true)
            self.pointSelector:_updateGroundHighlight(true)
            self.pasteArea:highlightCube(x, y, x + self.contents.width - 1, y + self.contents.height - 1, z, z + self.contents.depth - 1)
        end
    end
end

function WAT_CopyPaste:onReset()
    self.contents = nil
    self.pendingAdds = nil
    self.pasteObjectMap = nil
    self.status:setText("")
    self.sourceStatus:setText("")
    self.resetButton.tooltipUI:setVisible(false)
    self.resetButton.tooltipUI:removeFromUIManager()
    self.areaSelector:setValue({x1 = 0, y1 = 0, z1 = 0, x2 = 0, y2 = 0, z2 = 0})
    self.pointSelector:setValue({x = 0, y = 0, z = 0})
    self.areaSelector:cleanup()
    self.pointSelector:cleanup()
    self.areaSelector.cleanedUp = false
    self.pasteArea:remove()
    self.isActive = false
end

local function exportHeader(contents)
    return string.format("%d,%d,%d", contents.width, contents.height, contents.depth)
end

local function exportLine(data)
    return string.format("%d,%d,%d,%s,%s,%s,%s", data.x, data.y, data.z, data.spriteName, tostring(data.isFloor), tostring(data.isSupport), tostring(data.isAttached))
end

local function importHeader(contents, line)
    local parts = line:split(",")
    if #parts ~= 3 then
        return false
    end
    contents.width = tonumber(parts[1])
    contents.height = tonumber(parts[2])
    contents.depth = tonumber(parts[3])
    contents.objects = {}
    return true
end

local function importLine(contents, line)
    local parts = line:split(",")
    if #parts ~= 6 and #parts ~= 7 then
        return false
    end
    local data = {
        x = tonumber(parts[1]),
        y = tonumber(parts[2]),
        z = tonumber(parts[3]),
        spriteName = parts[4],
        isFloor = parts[5] == "true",
        isSupport = parts[6] == "true",
        isAttached = parts[7] == "true",
    }
    table.insert(contents.objects, data)
    return true
end

function WAT_CopyPaste:onExport()
    if not self.contents then
        return
    end
    local lines = {}
    table.insert(lines, exportHeader(self.contents))
    for _, data in ipairs(self.contents.objects) do
        table.insert(lines, exportLine(data))
    end
    local window = ISPanel:new(self.x, self.y, 400, 400)
    window:initialise()
    local textEntry = ISTextEntryBox:new(table.concat(lines, "\n"), 0, 0, 400, 400)
    textEntry:initialise()
    textEntry:instantiate()
    textEntry:setMultipleLine(true)
    window:addChild(textEntry)
    local closeBtn = ISButton:new(380, 0, 20, 20, "X", window, function() window:removeFromUIManager() end)
    closeBtn:initialise()
    window:addChild(closeBtn)
    window:addToUIManager()
end

function WAT_CopyPaste:onImport()
    local window = ISPanel:new(self.x, self.y, 400, 400)
    window:initialise()
    local textEntry = ISTextEntryBox:new("", 0, 0, 400, 400)
    textEntry:initialise()
    textEntry:instantiate()
    textEntry:setMultipleLine(true)
    window:addChild(textEntry)
    local closeBtn = ISButton:new(380, 0, 20, 20, "X", window, function() window:removeFromUIManager() end)
    closeBtn:initialise()
    window:addChild(closeBtn)
    local submitBtn = ISButton:new(340, 380, 60, 20, "Import", window, function()
        local lines = textEntry:getText():split("\n")
        local header = table.remove(lines, 1)
        local contents = {}
        importHeader(contents, header)
        for _, line in ipairs(lines) do
            importLine(contents, line)
        end
        self.contents = contents
        self.sourceStatus:setText("Imported " .. #self.contents.objects .. " objects")
        window:removeFromUIManager()
    end)
    submitBtn:initialise()
    window:addChild(submitBtn)
    window:addToUIManager()
end

function WAT_CopyPaste:onFileExport()
    if not self.contents then
        return
    end
    WL_TextEntryPanel:show("Export: Filename?", self, self.doFileExport)
end

function WAT_CopyPaste:doFileExport(filename)
    if not filename or filename == "" then
        return
    end
    -- remove special characters
    filename = filename:gsub("[^a-zA-Z0-9_\\-\\.]", "")
    local fileWriter = getFileWriter("WastelandCopyPaste/" .. filename .. ".txt", true, false)
    if not fileWriter then
        return
    end
    fileWriter:writeln(exportHeader(self.contents))
    for _, data in ipairs(self.contents.objects) do
        fileWriter:writeln(exportLine(data))
    end
    fileWriter:close()
end

function WAT_CopyPaste:onFileImport()
    WL_TextEntryPanel:show("Import: Filename?", self, self.doFileImport)
end

function WAT_CopyPaste:doFileImport(filename)
    if not filename or filename == "" then
        return
    end
    -- remove special characters
    filename = filename:gsub("[^a-zA-Z0-9_\\-\\.]", "")
    local fileReader = getFileReader("WastelandCopyPaste/" .. filename .. ".txt", false)
    local contents = {}
    local line = fileReader:readLine()
    if not importHeader(contents, line) then
        fileReader:close()
        return
    end
    line = fileReader:readLine()
    while line do
        importLine(contents, line)
        line = fileReader:readLine()
    end
    fileReader:close()
    self.contents = contents
    self.sourceStatus:setText("Imported " .. #self.contents.objects .. " objects")
end

function WAT_CopyPaste:onCopy()
    local area = self.areaSelector:getValue()
    local doGround = self.toggleGround:isSelected(1)
    local doFloor = self.toggleFloors:isSelected(1)
    local doSupports = self.toggleRoofHide:isSelected(1)
    self.contents = {
        width = area.x2 - area.x1 + 1,
        height = area.y2 - area.y1 + 1,
        depth = area.z2 - area.z1 + 1,
        objects = {}
    }
    for z = area.z1, area.z2 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                local square = getCell():getGridSquare(x, y, z)
                if square then
                    local objects = square:getObjects()
                    if objects:size() > 0 and not objects:get(0):isFloor() and doSupports then
                        local data = {}
                        data.x = x - area.x1
                        data.y = y - area.y1
                        data.z = z - area.z1
                        data.spriteName = "carpentry_02_57"
                        data.isFloor = true
                        data.isSupport = true
                        data.isAttached = false
                        table.insert(self.contents.objects, data)
                    end
                    for i = 1, objects:size() do
                        local object = objects:get(i - 1)
                        if instanceof(object, "IsoObject") and not instanceof(object, "IsoMovingObject") then
                            if not object:isFloor() or ((z == 0 or doFloor) and (z > 0 or doGround)) then
                                if instanceof(object, "IsoDoor") and object:IsOpen() then
                                    object:ToggleDoorSilent()
                                end
                                local sprite = object:getSprite()
                                if sprite then
                                    local data = {}
                                    data.x = x - area.x1
                                    data.y = y - area.y1
                                    data.z = z - area.z1
                                    data.spriteName = object:getSprite():getName()
                                    data.isFloor = object:isFloor()
                                    data.isSupport = false
                                    data.isAttached = false
                                    if data.spriteName then
                                        table.insert(self.contents.objects, data)
                                        local children = object:getChildSprites()
                                        if children then
                                            for j = 1, children:size() do
                                                local child = children:get(j - 1)
                                                local data = {}
                                                data.x = x - area.x1
                                                data.y = y - area.y1
                                                data.z = z - area.z1
                                                data.spriteName = child:getName()
                                                data.isFloor = false
                                                data.isSupport = false
                                                data.isAttached = true
                                                if data.spriteName then
                                                    table.insert(self.contents.objects, data)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    self.sourceStatus:setText("Copied " .. #self.contents.objects .. " objects")
end

local dummyItem
function WAT_CopyPaste:processNextPendingAdd()
    if not self.pendingAdds then
        self.isActive = false
        return
    end
    if #self.pendingAdds == 0 then
        self.pendingAdds = nil
        self.pasteObjectMap = nil
        self.status:setText("Paste complete!")
        self.pasteArea:remove()
        self.isActive = false
        return
    end

    local action = self.pendingAdds[1]
    if action.type == "WAIT" then
        table.remove(self.pendingAdds, 1)
        self.pendingActionCooldown = getTimestampMs() + action.delay
        return
    end

    table.remove(self.pendingAdds, 1)
    
    self.status:setText(#self.pendingAdds .. " objects pending creation")
    local square = getCell():getGridSquare(action.x, action.y, action.z)
    if square == nil and getWorld():isValidSquare(action.x, action.y, action.z) then
        square = getCell():createNewGridSquare(action.x, action.y, action.z, true)
    end
    if not square then
        return
    end

    local key = action.x .. "," .. action.y .. "," .. action.z

    if action.isAttached then
        local targetObject
        if self.pasteObjectMap[key] then
            targetObject = self.pasteObjectMap[key][action.attachToIndex]
        end

        if targetObject then
            local sprite = getSprite(action.spriteName)
            if sprite then
                targetObject:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0)
                if isClient() then
                    sendClientCommand(getPlayer(), 'WAT', 'addAttachedAnim', {
                        x = square:getX(),
                        y = square:getY(),
                        z = square:getZ(),
                        targetIndex = action.attachToIndex,
                        spriteName = action.spriteName
                    })
                end
            end
        end
        return
    end

    if action.isFloor then
        square:addFloor(action.spriteName)
        if not self.pasteObjectMap[key] then self.pasteObjectMap[key] = {} end
        self.pasteObjectMap[key][action.relativeIndex] = square:getObjects():get(0)
        return
    end

    local tileAlreadyOnSquare = false
    local objects = square:getObjects()
    local newObject
    for i=0, objects:size() - 1 do
        if objects:get(i):getSprite() ~= nil and objects:get(i):getSprite():getName() == action.spriteName then
            tileAlreadyOnSquare = true
            newObject = objects:get(i)
            break
        end
    end
    if not tileAlreadyOnSquare then
        if not dummyItem then
            dummyItem = InventoryItemFactory.CreateItem("Base.Plank")
        end
        local props = ISMoveableSpriteProps.new(IsoObject.new(square, action.spriteName):getSprite())
        props.rawWeight = 10
        props:placeMoveableInternal(square, dummyItem, action.spriteName)
        local objects = square:getObjects()
        newObject = objects:get(objects:size() - 1)
    end

    if newObject then
        if not self.pasteObjectMap[key] then self.pasteObjectMap[key] = {} end
        self.pasteObjectMap[key][action.relativeIndex] = newObject
    end
end

local function mergeSortByKey(t)

    local n = #t
    if n <= 1 then return end

    local buf = {}
    local width = 1

    while width < n do
        local i = 1

        while i <= n do
            local left = i
            local mid = i + width
            local right = i + 2 * width

            if mid > n + 1 then mid = n + 1 end
            if right > n + 1 then right = n + 1 end

            local a = left
            local b = mid
            local out = left

            while a < mid and b < right do
                local A = t[a]
                local B = t[b]

                local ar = A.isAttached and A.attachToIndex or A.relativeIndex
                local br = B.isAttached and B.attachToIndex or B.relativeIndex

                local takeA
                if ar < br then
                    takeA = true
                elseif ar > br then
                    takeA = false
                else
                    local ay = A.y
                    local by = B.y
                    if ay < by then
                        takeA = true
                    elseif ay > by then
                        takeA = false
                    else
                        local ax = A.x
                        local bx = B.x
                        if ax < bx then
                            takeA = true
                        elseif ax > bx then
                            takeA = false
                        else
                            -- Stable tie-breaker
                            local au = A._uid or 0
                            local bu = B._uid or 0
                            takeA = (au <= bu)
                        end
                    end
                end

                if takeA then
                    buf[out] = A
                    a = a + 1
                else
                    buf[out] = B
                    b = b + 1
                end
                out = out + 1
            end

            while a < mid do
                buf[out] = t[a]
                a = a + 1
                out = out + 1
            end

            while b < right do
                buf[out] = t[b]
                b = b + 1
                out = out + 1
            end

            for k = left, right - 1 do
                t[k] = buf[k]
            end

            i = i + 2 * width
        end

        width = width * 2
    end
end

function WAT_CopyPaste:onPaste()
    local point = self.pointSelector:getValue()
    local x = point.x
    local y = point.y
    local z = point.z

    if not self.contents then
        return
    end

    self.pendingAdds = {}
    self.pasteObjectMap = {}

    local doGround = self.toggleGround:isSelected(1)
    local doFloor = self.toggleFloors:isSelected(1)
    local doSupports = self.toggleRoofHide:isSelected(1)

    local zLayers = {}
    local minZ, maxZ = 100, -100
    local squareCounts = {}
    local uid = 0

    for _, data in ipairs(self.contents.objects) do
        if (doSupports or not data.isSupport) and (not data.isFloor or (data.z == 0 and doGround) or (data.z > 0 and doFloor)) then
            local targetZ = z + data.z
            if not zLayers[targetZ] then
                zLayers[targetZ] = { objects = {}, attachments = {} }
                if targetZ < minZ then minZ = targetZ end
                if targetZ > maxZ then maxZ = targetZ end
            end
            local layer = zLayers[targetZ]
            
            local key = (x + data.x) .. "," .. (y + data.y) .. "," .. (z + data.z)
            if not squareCounts[key] then squareCounts[key] = 0 end

            local action = {
                x = x + data.x,
                y = y + data.y,
                z = z + data.z,
                spriteName = data.spriteName,
                isAttached = data.isAttached,
                isFloor = data.isFloor,
            }

            if data.isAttached then
                if squareCounts[key] > 0 then
                    action.attachToIndex = squareCounts[key] - 1
                    table.insert(layer.attachments, action)
                end
            else
                action.relativeIndex = squareCounts[key]
                squareCounts[key] = squareCounts[key] + 1
                table.insert(layer.objects, action)
            end
        end
    end

    for layerZ = minZ, maxZ do
        local layer = zLayers[layerZ]
        if layer then
            mergeSortByKey(layer.objects)
            mergeSortByKey(layer.attachments)

            for _, obj in ipairs(layer.objects) do
                table.insert(self.pendingAdds, obj)
            end

            if #layer.objects > 0 then
                 table.insert(self.pendingAdds, { type = "WAIT", delay = 500 })
            end

            for _, att in ipairs(layer.attachments) do
                table.insert(self.pendingAdds, att)
            end

            if #layer.attachments > 0 then
                table.insert(self.pendingAdds, { type = "WAIT", delay = 500 })
            end
        end
    end

    self.isActive = true
    self.status:setText(#self.pendingAdds .. " objects pending creation")
end

function WAT_CopyPaste:onClearButtonClick()
    local modal = ISModalDialog:new(0, 0, 250, 150, "Are you sure you want to clear all tiles from the paste area?", true, self, self.onClearConfirm)
    modal:initialise()
    modal:addToUIManager()
end

function WAT_CopyPaste:onClearConfirm(button)
    if button.internal == "YES" then
        self:onClear()
    end
end

function WAT_CopyPaste:onClear()
    local point = self.pointSelector:getValue()
    local xMin = point.x
    local yMin = point.y
    local zMin = point.z
    local xMax = point.x + self.contents.width - 1
    local yMax = point.y + self.contents.height - 1
    local zMax = point.z + self.contents.depth - 1
    local doGround = self.toggleGround:isSelected(1)
    local doFloor = self.toggleFloors:isSelected(1)
    for z = zMin, zMax do
        for y = yMin, yMax do
            for x = xMin, xMax do
                local square = getCell():getGridSquare(x, y, z)
                if square then
                    local objects = square:getObjects()
                    for i=objects:size(),1,-1 do
                        local object = objects:get(i-1)
                        if instanceof(object, "IsoObject") and not instanceof(object, "IsoMovingObject") then
                            if not object:isFloor() or ((z == 0 or doFloor) and (z > 0 or doGround)) then
                                square:transmitRemoveItemFromSquare(object)
                            end
                        end
                    end
                end
            end
        end
    end
end

function WAT_CopyPaste:onDelete()
    local area = self.areaSelector:getValue()
    local doGround = self.toggleGround:isSelected(1)
    local doFloor = self.toggleFloors:isSelected(1)
    for z = area.z1, area.z2 do
        for y = area.y1, area.y2 do
            for x = area.x1, area.x2 do
                local square = getCell():getGridSquare(x, y, z)
                if square then
                    local objects = square:getObjects()
                    for i=objects:size(),1,-1 do
                        local object = objects:get(i-1)
                        if instanceof(object, "IsoObject") and not instanceof(object, "IsoMovingObject") then
                            if not object:isFloor() or ((z == 0 or doFloor) and (z > 0 or doGround)) then
                                square:transmitRemoveItemFromSquare(object)
                            end
                        end
                    end
                end
            end
        end
    end
end

function WAT_CopyPaste:onDeleteButtonClick()
    local modal = ISModalDialog:new(0, 0, 250, 150, "Are you sure you want to delete all tiles from the source area?", true, self, self.onDeleteConfirm)
    modal:initialise()
    modal:addToUIManager()
end

function WAT_CopyPaste:onDeleteConfirm(button)
    if button.internal == "YES" then
        self:onDelete()
    end
end

function WAT_CopyPaste:close()
    self.areaSelector:cleanup()
    self.pointSelector:cleanup()
    self.pasteArea:remove()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
end
