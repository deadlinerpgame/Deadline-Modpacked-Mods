---
--- AttractorListWindow.lua
--- List window for managing zombie attractors
---

WLZA_AttractorListWindow = ISPanel:derive("WLZA_AttractorListWindow")

function WLZA_AttractorListWindow:show(player)
    if WLZA_AttractorListWindow.instance then
        WLZA_AttractorListWindow.instance:onClose()
    end
    
    local w = math.floor(WLZA_UI_Constants.scale(450))
    local h = math.floor(WLZA_UI_Constants.scale(300))
    local x = math.floor((getCore():getScreenWidth() - w) / 2)
    local y = math.floor((getCore():getScreenHeight() - h) / 2)
    local ui = WLZA_AttractorListWindow:new(x, y, w, h, player)
    ui:initialise()
    ui:addToUIManager()
    WLZA_AttractorListWindow.instance = ui
    return ui
end

function WLZA_AttractorListWindow:new(x, y, width, height, player)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.highlighters = {}  -- Track all highlighter instances for cleanup
    o.hoveredAttractor = nil  -- Track currently hovered attractor
    o.hoveredButton = nil  -- Track hovered button state
    o.anchorTop = true
    o.anchorBottom = true
    o.anchorLeft = true
    o.anchorRight = true
    o.resizable = false
    o.moveWithMouse = true
    return o
end

function WLZA_AttractorListWindow:initialise()
    ISPanel.initialise(self)
    
    -- Styling
    self.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
    self.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    self.moveWithMouse = true
    
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(WLZA_UI_Constants.scale(16), WLZA_UI_Constants.scale(16), WLZA_UI_Constants.scale(16), WLZA_UI_Constants.scale(16))
    
    local vstack = win:makeVerticalStack(WLZA_UI_Constants.scale(8))
    
    -- Title
    local titleRow = vstack:makeNode(WLZA_UI_Constants.FONT_HGT_LARGE)
    titleRow:makeLabel("Zombie Attractors", UIFont.Large, WLZA_UI_Constants.COLOR_WHITE, "left")
    
    -- Header buttons (Add and Close) - made thinner
    local buttonRow = vstack:makeNode(WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(2))
    local buttonLeft, buttonRight = buttonRow:cols(2, WLZA_UI_Constants.scale(8))
    self.addButton = buttonLeft:makeButton("Add", self, self.onAddAttractor)
    self.closeButton = buttonRight:makeButton("Close", self, self.onClose)

    -- Reserve space for list
    local listHeight = self.height - WLZA_UI_Constants.scale(32) - WLZA_UI_Constants.FONT_HGT_LARGE - (WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(2)) - WLZA_UI_Constants.scale(24)
    local listPlaceholder = vstack:makeNode(listHeight)
    
    -- Create scroll area
    local listY = WLZA_UI_Constants.scale(16) + WLZA_UI_Constants.FONT_HGT_LARGE + WLZA_UI_Constants.scale(8) + WLZA_UI_Constants.FONT_HGT_MEDIUM + WLZA_UI_Constants.scale(10)
    self.attractorScrollArea = ISScrollingListBox:new(WLZA_UI_Constants.scale(16), listY, self.width - WLZA_UI_Constants.scale(32), listHeight)
    self.attractorScrollArea:initialise()
    self.attractorScrollArea:instantiate()
    self.attractorScrollArea.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.attractorScrollArea.drawBorder = true
    self.attractorScrollArea.itemheight = WLZA_UI_Constants.FONT_HGT_SMALL + WLZA_UI_Constants.scale(40)
    self.attractorScrollArea.font = UIFont.Small
    self.attractorScrollArea.doDrawItem = WLZA_AttractorListWindow.drawAttractorItem
    self.attractorScrollArea.onMouseUp = function(scrollArea, x, y)
        return self:onAttractorListMouseUp(scrollArea, x, y)
    end
    self:addChild(self.attractorScrollArea)
    
    self:populateList()
end

function WLZA_AttractorListWindow:populateList()
    self.attractorScrollArea:clear()
    
    local attractors = WLZA_Client:getAllAttractors()
    local player = getPlayer()
    
    -- Calculate distances and sort by distance
    local attractorsWithDistance = {}
    for _, attractor in ipairs(attractors) do
        local distance = 0
        if player and attractor.position then
            local dx = player:getX() - attractor.position.x
            local dy = player:getY() - attractor.position.y
            distance = math.sqrt(dx * dx + dy * dy)
        end
        table.insert(attractorsWithDistance, {
            attractor = attractor,
            distance = distance
        })
    end
    
    -- Sort by distance
    table.sort(attractorsWithDistance, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Add to list
    for _, item in ipairs(attractorsWithDistance) do
        self.attractorScrollArea:addItem(item.attractor.id, {
            attractor = item.attractor,
            distance = item.distance
        })
    end
end

function WLZA_AttractorListWindow:drawAttractorItem(y, item, alt)
    local a = 0.9
    local parent = self.parent
    
    if not item.item then
        return y + self.itemheight
    end
    
    local attractor = item.item.attractor
    local distance = item.item.distance
    local rowIndex = nil
    
    -- Find row index
    for i, listItem in ipairs(self.items) do
        if listItem.item == item.item then
            rowIndex = i
            break
        end
    end
    
    -- Background
    self:drawRect(0, y, self.width, self.itemheight, 0.3, 0.1, 0.1, 0.1)
    
    -- Enabled indicator
    local isEnabled = WLZA_Client:isAttractorEnabled(attractor.id)
    local statusColor = isEnabled and { r = 0.3, g = 1, b = 0.3 } or { r = 1.0, g = 0.3, b = 0.3 }
    self:drawRect(WLZA_UI_Constants.scale(5), y + WLZA_UI_Constants.scale(5), WLZA_UI_Constants.scale(10), WLZA_UI_Constants.scale(45), a, statusColor.r, statusColor.g, statusColor.b)
    
    -- Name
    self:drawText(attractor.name or "Unknown", WLZA_UI_Constants.scale(20), y + WLZA_UI_Constants.scale(4), WLZA_UI_Constants.COLOR_HEADER.r, WLZA_UI_Constants.COLOR_HEADER.g, WLZA_UI_Constants.COLOR_HEADER.b, a, UIFont.Small)
    
    -- Details - Line 1
    local detailsLine1 = string.format("Owner: %s  |  Range: %d-%d",
        attractor.owner or "Unknown",
        attractor.minRange or 0,
        attractor.maxRange or 0)
    self:drawText(detailsLine1, WLZA_UI_Constants.scale(20), y + WLZA_UI_Constants.scale(18), 0.8, 0.8, 0.8, a, UIFont.Small)
    
    -- Details - Line 2
    local detailsLine2 = string.format("Interval: %ds  |  Distance: %.0f tiles",
        attractor.interval or 0,
        distance)
    self:drawText(detailsLine2, WLZA_UI_Constants.scale(20), y + WLZA_UI_Constants.scale(33), 0.8, 0.8, 0.8, a, UIFont.Small)
    
    -- Draw Toggle, Edit, and Delete buttons on the right
    if rowIndex and parent then
        local buttonWidth = WLZA_UI_Constants.scale(50)
        local buttonHeight = WLZA_UI_Constants.scale(16)
        local buttonY = y + (self.itemheight - buttonHeight) / 2
        local deleteX = self.width - buttonWidth - WLZA_UI_Constants.scale(5)
        local editX = deleteX - buttonWidth - WLZA_UI_Constants.scale(5)
        local toggleX = editX - buttonWidth - WLZA_UI_Constants.scale(5)
        
        -- Helper function to draw a button with hover effect
        local function drawButton(x, y, w, h, text, buttonType, baseColor, borderColor)
            local isHovered = parent.hoveredButton and parent.hoveredButton.row == rowIndex and parent.hoveredButton.button == buttonType
            
            -- Button background
            if isHovered then
                self:drawRect(x, y, w, h, 0.7, baseColor.r * 0.5, baseColor.g * 0.5, baseColor.b * 0.5)
            else
                self:drawRect(x, y, w, h, a, baseColor.r, baseColor.g, baseColor.b)
            end
            
            -- Button border
            self:drawRectBorder(x, y, w, h, a, borderColor.r, borderColor.g, borderColor.b)
            
            -- Button text (centered)
            self:drawTextCentre(text, x + w / 2, y + (h - WLZA_UI_Constants.FONT_HGT_SMALL) / 2, 1, 1, 1, a, UIFont.Small)
        end
        
        -- Draw Toggle button
        local toggleColor = isEnabled and { r = 0.2, g = 0.6, b = 0.2 } or { r = 0.6, g = 0.2, b = 0.2 }
        local toggleBorder = isEnabled and { r = 0.4, g = 0.8, b = 0.4 } or { r = 0.8, g = 0.4, b = 0.4 }
        local toggleText = isEnabled and "On" or "Off"
        drawButton(toggleX, buttonY, buttonWidth, buttonHeight, toggleText, "toggle", toggleColor, toggleBorder)
        
        -- Draw Edit button
        drawButton(editX, buttonY, buttonWidth, buttonHeight, "Edit", "edit", { r = 0.2, g = 0.4, b = 0.6 }, { r = 0.4, g = 0.6, b = 0.8 })
        
        -- Draw Delete button
        drawButton(deleteX, buttonY, buttonWidth, buttonHeight, "Delete", "delete", { r = 0.6, g = 0.2, b = 0.2 }, { r = 0.8, g = 0.4, b = 0.4 })
    end
    
    return y + self.itemheight
end

function WLZA_AttractorListWindow:onAttractorListMouseUp(scrollArea, x, y)
    -- Find which row was clicked
    local row = scrollArea:rowAt(x, y)
    if row < 1 or row > #scrollArea.items then
        return false
    end
    
    local item = scrollArea.items[row].item
    if not item then
        return false
    end
    
    -- Calculate the Y position of the row
    local rowY = 0
    for i = 1, row - 1 do
        local v = scrollArea.items[i]
        if not v.height then v.height = scrollArea.itemheight end
        rowY = rowY + v.height
    end
    
    -- Button coordinates
    local buttonWidth = WLZA_UI_Constants.scale(50)
    local buttonHeight = WLZA_UI_Constants.scale(16)
    local buttonY = (scrollArea.itemheight - buttonHeight) / 2
    local deleteX = scrollArea.width - buttonWidth - WLZA_UI_Constants.scale(5)
    local editX = deleteX - buttonWidth - WLZA_UI_Constants.scale(5)
    local toggleX = editX - buttonWidth - WLZA_UI_Constants.scale(5)
    
    -- Check if Toggle button was clicked
    if x >= toggleX and x <= toggleX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        self:onToggleAttractor(item.attractor)
        return true
    end
    
    -- Check if Edit button was clicked
    if x >= editX and x <= editX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        self:onEditAttractor(item.attractor)
        return true
    end
    
    -- Check if Delete button was clicked
    if x >= deleteX and x <= deleteX + buttonWidth and
       y >= rowY + buttonY and y <= rowY + buttonY + buttonHeight then
        self:onDeleteAttractor(item.attractor)
        return true
    end
    
    return false
end

function WLZA_AttractorListWindow:onToggleAttractor(attractor)
    WLZA_Client:toggleAttractor(self.player, attractor.id)
end

function WLZA_AttractorListWindow:onEditAttractor(attractor)
    WLZA_ManageAttractor:show(self.player, attractor)
end

function WLZA_AttractorListWindow:onDeleteAttractor(attractor)
    WL_Dialogs.showConfirmationDialog("Delete attractor '" .. attractor.name .. "'? This cannot be undone!", function()
        sendClientCommand(self.player, "WLZA", "RemoveAttractor", { attractorId = attractor.id })
        print("[WLZA] Deleted attractor: " .. attractor.id)
    end)
end

function WLZA_AttractorListWindow:onAddAttractor()
    WLZA_ManageAttractor:show(self.player, nil)
end

function WLZA_AttractorListWindow:getButtonAtPosition(x, y)
    if not self.attractorScrollArea then return nil end
    
    -- x, y are already content coordinates (scroll offset is handled automatically)
    -- Find which row using the same logic as ISScrollingListBox:rowAt
    local rowY = 0
    local rowIndex = -1
    for i, v in ipairs(self.attractorScrollArea.items) do
        if not v.height then v.height = self.attractorScrollArea.itemheight end
        if y >= rowY and y < rowY + v.height then
            rowIndex = i
            break
        end
        rowY = rowY + v.height
    end
    
    if rowIndex < 1 or rowIndex > #self.attractorScrollArea.items then
        return nil
    end
    
    local item = self.attractorScrollArea.items[rowIndex]
    if not item.item then return nil end
    
    -- Regular attractor row - calculate button positions
    local buttonWidth = WLZA_UI_Constants.scale(50)
    local buttonHeight = WLZA_UI_Constants.scale(16)
    local buttonY = rowY + (self.attractorScrollArea.itemheight - buttonHeight) / 2
    local deleteX = self.attractorScrollArea.width - buttonWidth - WLZA_UI_Constants.scale(5)
    local editX = deleteX - buttonWidth - WLZA_UI_Constants.scale(5)
    local toggleX = editX - buttonWidth - WLZA_UI_Constants.scale(5)
    
    -- Check delete button
    if x >= deleteX and x <= deleteX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        return { row = rowIndex, button = "delete", attractor = item.item.attractor }
    end
    
    -- Check edit button
    if x >= editX and x <= editX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        return { row = rowIndex, button = "edit", attractor = item.item.attractor }
    end
    
    -- Check toggle button
    if x >= toggleX and x <= toggleX + buttonWidth and y >= buttonY and y <= buttonY + buttonHeight then
        return { row = rowIndex, button = "toggle", attractor = item.item.attractor }
    end
    
    return nil
end

function WLZA_AttractorListWindow:getAttractorAtPosition(x, y)
    if not self.attractorScrollArea then return nil end
    
    -- x, y are already content coordinates (scroll offset is handled automatically)
    -- Find which row using the same logic as ISScrollingListBox:rowAt
    local rowY = 0
    for i, v in ipairs(self.attractorScrollArea.items) do
        if not v.height then v.height = self.attractorScrollArea.itemheight end
        if y >= rowY and y < rowY + v.height then
            return v.item and v.item.attractor  -- Returns attractor or nil
        end
        rowY = rowY + v.height
    end
    
    return nil
end

function WLZA_AttractorListWindow:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)
    
    local newHoveredAttractor = nil
    local hoveredButton = nil
    
    -- Only check if mouse is over the scroll panel
    if self.attractorScrollArea and self.attractorScrollArea:isMouseOver() then
        -- getMouseX/getMouseY return content coordinates (scroll is handled automatically)
        local x = self.attractorScrollArea:getMouseX()
        local y = self.attractorScrollArea:getMouseY()
        
        hoveredButton = self:getButtonAtPosition(x, y)
        newHoveredAttractor = self:getAttractorAtPosition(x, y)
    end
    
    self.hoveredButton = hoveredButton
    
    -- Update hovered attractor for highlighting
    if newHoveredAttractor ~= self.hoveredAttractor then
        self.hoveredAttractor = newHoveredAttractor
        self:updateHighlighters()
    end
end

function WLZA_AttractorListWindow:onMouseMoveOutside(dx, dy)
    ISPanel.onMouseMoveOutside(self, dx, dy)
    
    -- Clear hover states when mouse leaves the window
    self.hoveredButton = nil
    if self.hoveredAttractor then
        self.hoveredAttractor = nil
        self:updateHighlighters()
    end
end

function WLZA_AttractorListWindow:updateHighlighters()
    -- Clear any existing highlighters first
    self:clearHighlighters()
    
    -- Highlight single hovered attractor
    if not self.hoveredAttractor then
        return
    end
    
    local attractor = self.hoveredAttractor
    if not attractor.position then
        return
    end
    
    self:createAttractorHighlighters(attractor)
end

function WLZA_AttractorListWindow:createAttractorHighlighters(attractor)
    if not attractor or not attractor.position then
        return
    end
    
    local pos = attractor.position
    local z = pos.z or 0
    
    -- Priority scheme (lower = higher priority):
    -- 0 = Attractor position (green) - highest priority
    -- 1 = Min range (yellow)
    -- 2 = Max range (orange)
    -- 3 = Cardinal lines (red) connecting min to max range - lowest priority
    
    -- 1. Attractor Position (Green) - Priority 0
    local attractorPosHL = GroundHighlighter:new()
    local c = WLZA_UI_Constants.COLOR_ATTRACTOR_POINT
    attractorPosHL:setColor(c.r, c.g, c.b, c.a)
    attractorPosHL:setPriority(0)
    attractorPosHL:enableXray(true)
    attractorPosHL:highlightSquare(pos.x, pos.y, pos.x, pos.y, z)
    table.insert(self.highlighters, attractorPosHL)
    
    -- 2. Min Range Circle (Yellow) - Priority 1
    if attractor.minRange and attractor.minRange > 0 then
        local minRangeHL = GroundHighlighter:new()
        c = WLZA_UI_Constants.COLOR_MIN_RANGE
        minRangeHL:setColor(c.r, c.g, c.b, c.a)
        minRangeHL:setPriority(1)
        minRangeHL:enableXray(true)
        minRangeHL:highlightRing(pos.x, pos.y, attractor.minRange, 1, z)
        table.insert(self.highlighters, minRangeHL)
    end
    
    -- 3. Max Range Circle (Orange) - Priority 2
    if attractor.maxRange and attractor.maxRange > 0 and attractor.maxRange < 100 then
        local maxRangeHL = GroundHighlighter:new()
        c = WLZA_UI_Constants.COLOR_MAX_RANGE
        maxRangeHL:setColor(c.r, c.g, c.b, c.a)
        maxRangeHL:setPriority(2)
        maxRangeHL:enableXray(true)
        maxRangeHL:highlightRing(pos.x, pos.y, attractor.maxRange, 1, z)
        table.insert(self.highlighters, maxRangeHL)
    end
    
    -- 4. Cardinal Lines connecting min range to max range - Priority 3
    if attractor.maxRange and attractor.maxRange > 0 then
        -- Use a color between min and max range colors for the lines
        c = WLZA_UI_Constants.COLOR_INSIDE_RANGE
        
        -- North line (positive Y direction)
        local northLineHL = GroundHighlighter:new()
        northLineHL:setColor(c.r, c.g, c.b, c.a)
        northLineHL:setPriority(3)
        northLineHL:enableXray(true)
        northLineHL:highlightLine(pos.x, pos.y + attractor.minRange, z, pos.x, pos.y + math.min(100, attractor.maxRange), z, 1)
        table.insert(self.highlighters, northLineHL)
        
        -- South line (negative Y direction)
        local southLineHL = GroundHighlighter:new()
        southLineHL:setColor(c.r, c.g, c.b, c.a)
        southLineHL:setPriority(3)
        southLineHL:enableXray(true)
        southLineHL:highlightLine(pos.x, pos.y - attractor.minRange, z, pos.x, pos.y - math.min(100, attractor.maxRange), z, 1)
        table.insert(self.highlighters, southLineHL)
        
        -- East line (positive X direction)
        local eastLineHL = GroundHighlighter:new()
        eastLineHL:setColor(c.r, c.g, c.b, c.a)
        eastLineHL:setPriority(3)
        eastLineHL:enableXray(true)
        eastLineHL:highlightLine(pos.x + attractor.minRange, pos.y, z, pos.x + math.min(100, attractor.maxRange), pos.y, z, 1)
        table.insert(self.highlighters, eastLineHL)
        
        -- West line (negative X direction)
        local westLineHL = GroundHighlighter:new()
        westLineHL:setColor(c.r, c.g, c.b, c.a)
        westLineHL:setPriority(3)
        westLineHL:enableXray(true)
        westLineHL:highlightLine(pos.x - attractor.minRange, pos.y, z, pos.x - math.min(100, attractor.maxRange), pos.y, z, 1)
        table.insert(self.highlighters, westLineHL)
    end
end

function WLZA_AttractorListWindow:clearHighlighters()
    for _, hl in ipairs(self.highlighters) do
        if hl then
            hl:remove()
        end
    end
    self.highlighters = {}
end

function WLZA_AttractorListWindow:onClose()
    -- Clear all highlighters before closing
    self:clearHighlighters()
    
    self:removeFromUIManager()
    WLZA_AttractorListWindow.instance = nil
end