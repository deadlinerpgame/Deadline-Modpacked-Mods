---
--- WLSP_SpawnerListWindow.lua
--- Small management window for nearby spawners with Enable/Disable, Edit, and Delete actions
---

WLSP_SpawnerListWindow = ISPanel:derive("WLSP_SpawnerListWindow")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)

local SCALE = FONT_HGT_SMALL / 19
local function scale(px) return px * SCALE end

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_GREEN = { r = 0.3, g = 1, b = 0.3, a = 1 }
local COLOR_RED = { r = 1, g = 0.3, b = 0.3, a = 1 }
local COLOR_GRAY = { r = 0.5, g = 0.5, b = 0.5, a = 1 }

-- Show the spawner list window
function WLSP_SpawnerListWindow:show()
    if WLSP_SpawnerListWindow.instance then
        WLSP_SpawnerListWindow.instance:onClose()
    end
    
    local w = math.floor(scale(400))
    local h = math.floor(scale(300))
    local x = math.floor((getCore():getScreenWidth() - w) / 2)
    local y = math.floor((getCore():getScreenHeight() - h) / 2)
    
    local ui = WLSP_SpawnerListWindow:new(x, y, w, h)
    ui:initialise()
    ui:addToUIManager()
    WLSP_SpawnerListWindow.instance = ui
    return ui
end

function WLSP_SpawnerListWindow:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.player = getPlayer()
    o.nearbyRadius = 200  -- Show spawners within 200 units
    o.lastPlayerX = nil  -- Track player position for movement detection
    o.lastPlayerY = nil
    o.highlighters = {}  -- Track all highlighter instances for cleanup
    o.hoveredSpawner = nil  -- Track currently hovered spawner
    o.hoveredGroupName = nil  -- Track currently hovered group header
    
    o.anchorTop = true
    o.anchorBottom = true
    o.anchorLeft = true
    o.anchorRight = true
    o.resizable = false
    o.moveWithMouse = true
    
    return o
end

function WLSP_SpawnerListWindow:initialise()
    ISPanel.initialise(self)
    
    self.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.9 }
    self.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    
    -- Title
    local titleHeight = FONT_HGT_MEDIUM + scale(10)
    self.titleLabel = ISLabel:new(0, scale(5), titleHeight, "Nearby Spawners", 1, 1, 1, 1, UIFont.Medium, true)
    self:addChild(self.titleLabel)
    self.titleLabel:initialise()
    
    -- Add button
    local btnSize = FONT_HGT_SMALL + scale(4)
    local addBtnWidth = scale(40)
    self.addButton = ISButton:new(self.width - btnSize - addBtnWidth - scale(10), scale(3), addBtnWidth, btnSize, "Add", self, self.onAddSpawner)
    self.addButton:initialise()
    self.addButton.borderColor = { r = 0.3, g = 1, b = 0.3, a = 0.8 }
    self:addChild(self.addButton)
    
    -- Close button
    self.closeButton = ISButton:new(self.width - btnSize - scale(5), scale(3), btnSize, btnSize, "X", self, self.onClose)
    self.closeButton:initialise()
    self.closeButton.borderColor = { r = 1, g = 1, b = 1, a = 0.5 }
    self:addChild(self.closeButton)
    
    -- Scrollable list area
    local listY = titleHeight + scale(5)
    local listHeight = self.height - listY - scale(10)
    
    self.scrollPanel = ISScrollingListBox:new(scale(5), listY, self.width - scale(10), listHeight)
    self.scrollPanel:initialise()
    self.scrollPanel:instantiate()
    self.scrollPanel.backgroundColor = { r = 0, g = 0, b = 0, a = 0.5 }
    self.scrollPanel.doDrawItem = self.drawSpawnerRow
    self.scrollPanel.drawBorder = true
    self.scrollPanel.itemheight = FONT_HGT_SMALL + scale(8)
    self.scrollPanel.selected = 0
    self.scrollPanel.font = UIFont.Small
    self.scrollPanel.parent = self
    
    -- Override scroll panel's mouse down to handle custom buttons
    self.scrollPanel.onMouseDown = function(scrollPanel, x, y)
        local buttonInfo = self:getButtonAtPosition(x, y)
        if buttonInfo then
            if buttonInfo.button == "groupToggle" then
                -- Toggle entire group
                local groupName = buttonInfo.groupName
                WLSP_Client:toggleSpawnerGroup(self.player, groupName)
            elseif buttonInfo.spawner then
                local spawner = buttonInfo.spawner
                
                if buttonInfo.button == "toggle" then
                    WLSP_Client:toggleSpawner(self.player, spawner.id)
                elseif buttonInfo.button == "edit" then
                    WLSP_ManageSpawner:show(self.player, spawner)
                elseif buttonInfo.button == "delete" then
                    WL_Dialogs.showConfirmationDialog("Delete spawner '" .. spawner.id .. "'?", function()
                        sendClientCommand(self.player, "WLSP", "RemoveSpawner", { spawnerId = spawner.id })
                    end)
                end
            end
            return true
        end
        -- Call original handler if no button was clicked
        return ISScrollingListBox.onMouseDown(scrollPanel, x, y)
    end
    
    self:addChild(self.scrollPanel)
    
    -- Track hover state for custom buttons
    self.hoveredButton = nil  -- { row = index, button = "toggle"/"edit"/"delete" }
    
    self:populateList()
end

function WLSP_SpawnerListWindow:populateList()
    self.scrollPanel:clear()
    
    if not self.player then return end
    
    local spawners = WLSP_Client:getAllSpawners()
    if not spawners then return end
    
    local playerX = self.player:getX()
    local playerY = self.player:getY()
    local playerZ = self.player:getZ()
    
    -- Update last known player position
    self.lastPlayerX = playerX
    self.lastPlayerY = playerY
    
    -- Filter by distance
    local nearbySpawners = {}
    for _, spawner in ipairs(spawners) do
        local dx = spawner.position.x - playerX
        local dy = spawner.position.y - playerY
        if spawner.targetLocation then
            dx = spawner.targetLocation.x - playerX
            dy = spawner.targetLocation.y - playerY
        end
        
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance <= self.nearbyRadius then
            table.insert(nearbySpawners, {
                spawner = spawner,
                distance = distance
            })
        end
    end
    
    -- Sort by distance
    table.sort(nearbySpawners, function(a, b)
        return a.distance < b.distance
    end)
    
    -- Group spawners
    local groups = {}
    local ungrouped = {}
    
    for _, entry in ipairs(nearbySpawners) do
        local spawner = entry.spawner
        if spawner.group and spawner.group ~= "" then
            if not groups[spawner.group] then
                groups[spawner.group] = {}
            end
            table.insert(groups[spawner.group], spawner)
        else
            table.insert(ungrouped, spawner)
        end
    end
    
    -- Sort group names alphabetically
    local groupNames = {}
    for groupName, _ in pairs(groups) do
        table.insert(groupNames, groupName)
    end
    table.sort(groupNames)
    
    -- Add grouped spawners to list
    for _, groupName in ipairs(groupNames) do
        -- Add group header
        self.scrollPanel:addItem("GROUP: " .. groupName, { isGroupHeader = true, groupName = groupName })
        
        -- Add spawners in this group
        for _, spawner in ipairs(groups[groupName]) do
            self.scrollPanel:addItem(spawner.id, spawner)
        end
    end
    
    -- Add ungrouped spawners
    if #ungrouped > 0 then
        if #groupNames > 0 then
            -- Add separator if there are grouped spawners
            self.scrollPanel:addItem("GROUP: Ungrouped", { isGroupHeader = true, groupName = nil })
        end
        for _, spawner in ipairs(ungrouped) do
            self.scrollPanel:addItem(spawner.id, spawner)
        end
    end
    
    if #nearbySpawners == 0 then
        self.scrollPanel:addItem("No nearby spawners", nil)
    end
end

function WLSP_SpawnerListWindow:drawSpawnerRow(y, item, alt)
    local a = 0.9
    local parent = self.parent
    
    if not item.item then
        -- Empty state message
        self:drawText(item.text, 10, y + 4, 0.5, 0.5, 0.5, a, self.font)
        return y + self.itemheight
    end
    
    -- Check if this is a group header
    if item.item.isGroupHeader then
        local groupName = item.item.groupName
        local rowIndex = nil
        
        -- Find row index
        for i, listItem in ipairs(self.items) do
            if listItem.item == item.item then
                rowIndex = i
                break
            end
        end
        
        -- Draw group header background
        self:drawRect(0, y, self.width, self.itemheight, 0.5, 0.2, 0.2, 0.3)
        
        -- Draw group name
        self:drawText(item.text, scale(5), y + scale(4), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
        
        -- Draw group toggle button if this group has a name
        if groupName and rowIndex and parent then
            local btnWidth = scale(70)
            local btnHeight = self.itemheight - scale(4)
            local btnY = y + scale(2)
            local btnX = self.width - scale(7) - btnWidth
            
            -- Check if all spawners in this group are enabled
            local allEnabled = parent:isGroupEnabled(groupName)
            
            local isHovered = parent.hoveredButton and parent.hoveredButton.row == rowIndex and parent.hoveredButton.button == "groupToggle"
            
            local toggleColor = allEnabled and COLOR_GREEN or COLOR_RED
            
            -- Button background
            if isHovered then
                self:drawRect(btnX, btnY, btnWidth, btnHeight, 0.7, toggleColor.r * 0.5, toggleColor.g * 0.5, toggleColor.b * 0.5)
            else
                self:drawRect(btnX, btnY, btnWidth, btnHeight, 0.3, toggleColor.r * 0.3, toggleColor.g * 0.3, toggleColor.b * 0.3)
            end
            
            -- Button border
            self:drawRectBorder(btnX, btnY, btnWidth, btnHeight, 1.0, toggleColor.r, toggleColor.g, toggleColor.b)
            
            -- Button text
            local toggleText = allEnabled and "Disable All" or "Enable All"
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, toggleText)
            local textX = btnX + (btnWidth - textWidth) / 2
            local textY = btnY + (btnHeight - FONT_HGT_SMALL) / 2
            self:drawText(toggleText, textX, textY, 1, 1, 1, 1, UIFont.Small)
        end
        
        return y + self.itemheight
    end
    
    -- Regular spawner row
    local spawner = item.item
    local isEnabled = WLSP_Client:isSpawnerEnabled(spawner.id)
    local rowIndex = nil
    
    -- Find row index
    for i, listItem in ipairs(self.items) do
        if listItem.item == spawner then
            rowIndex = i
            break
        end
    end
    
    -- Background based on enabled status
    if isEnabled then
        self:drawRect(0, y, self.width, self.itemheight, 0.4, 0.1, 0.3, 0.1)  -- Green tint
    else
        self:drawRect(0, y, self.width, self.itemheight, 0.4, 0.3, 0.1, 0.1)  -- Red tint
    end
    
    -- Spawner name and type
    local nameText = spawner.id or "Unknown"
    local typeText = " (" .. (spawner.type or "?") .. ")"
    self:drawText(nameText .. typeText, scale(5), y + scale(4), COLOR_WHITE.r, COLOR_WHITE.g, COLOR_WHITE.b, a, UIFont.Small)
    
    -- Draw custom buttons
    if rowIndex then
        local btnWidth = scale(35)
        local btnHeight = self.itemheight - scale(4)
        local btnY = y + scale(2)
        local btnX = self.width - scale(7)
        
        -- Helper function to draw a button
        local function drawButton(x, y, w, h, text, buttonType, color)
            local isHovered = parent.hoveredButton and parent.hoveredButton.row == rowIndex and parent.hoveredButton.button == buttonType
            
            -- Button background
            if isHovered then
                self:drawRect(x, y, w, h, 0.7, color.r * 0.5, color.g * 0.5, color.b * 0.5)
            else
                self:drawRect(x, y, w, h, 0.3, color.r * 0.3, color.g * 0.3, color.b * 0.3)
            end
            
            -- Button border
            self:drawRectBorder(x, y, w, h, 1.0, color.r, color.g, color.b)
            
            -- Button text (centered)
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
            local textX = x + (w - textWidth) / 2
            local textY = y + (h - FONT_HGT_SMALL) / 2
            self:drawText(text, textX, textY, 1, 1, 1, 1, UIFont.Small)
        end
        
        -- Delete button
        btnX = btnX - btnWidth
        drawButton(btnX, btnY, btnWidth, btnHeight, "Del", "delete", COLOR_RED)
        
        -- Edit button
        btnX = btnX - btnWidth - scale(2)
        drawButton(btnX, btnY, btnWidth, btnHeight, "Edit", "edit", { r = 0.3, g = 0.6, b = 1 })
        
        -- Toggle button
        btnX = btnX - btnWidth - scale(2)
        local toggleText = isEnabled and "Off" or "On"
        local toggleColor = isEnabled and COLOR_GREEN or COLOR_RED
        drawButton(btnX, btnY, btnWidth, btnHeight, toggleText, "toggle", toggleColor)
    end
    
    return y + self.itemheight
end

function WLSP_SpawnerListWindow:prerender()
    ISPanel.prerender(self)
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

function WLSP_SpawnerListWindow:getButtonAtPosition(x, y)
    if not self.scrollPanel then return nil end
    
    -- x, y are already content coordinates (scroll offset is handled automatically)
    -- Find which row using the same logic as ISScrollingListBox:rowAt
    local rowY = 0
    local rowIndex = -1
    for i, v in ipairs(self.scrollPanel.items) do
        if not v.height then v.height = self.scrollPanel.itemheight end
        if y >= rowY and y < rowY + v.height then
            rowIndex = i
            break
        end
        rowY = rowY + v.height
    end
    
    if rowIndex < 1 or rowIndex > #self.scrollPanel.items then
        return nil
    end
    
    local item = self.scrollPanel.items[rowIndex]
    if not item.item then return nil end
    
    -- Check if this is a group header
    if item.item.isGroupHeader then
        local groupName = item.item.groupName
        if groupName then
            -- Check group toggle button
            local btnWidth = scale(70)
            local btnHeight = self.scrollPanel.itemheight - scale(4)
            local btnY = rowY + scale(2)
            local btnX = self.scrollPanel.width - scale(7) - btnWidth
            
            if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
                return { row = rowIndex, button = "groupToggle", groupName = groupName }
            end
        end
        return nil
    end
    
    -- Regular spawner row - calculate button positions
    local btnWidth = scale(35)
    local btnHeight = self.scrollPanel.itemheight - scale(4)
    local btnY = rowY + scale(2)
    local btnX = self.scrollPanel.width - scale(7)
    
    -- Check delete button
    btnX = btnX - btnWidth
    if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
        return { row = rowIndex, button = "delete", spawner = item.item }
    end
    
    -- Check edit button
    btnX = btnX - btnWidth - scale(2)
    if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
        return { row = rowIndex, button = "edit", spawner = item.item }
    end
    
    -- Check toggle button
    btnX = btnX - btnWidth - scale(2)
    if x >= btnX and x <= btnX + btnWidth and y >= btnY and y <= btnY + btnHeight then
        return { row = rowIndex, button = "toggle", spawner = item.item }
    end
    
    return nil
end

function WLSP_SpawnerListWindow:onMouseMove(dx, dy)
    ISPanel.onMouseMove(self, dx, dy)
    
    local newHoveredSpawner = nil
    local newHoveredGroupName = nil
    local hoveredButton = nil
    
    -- Only check if mouse is over the scroll panel
    if self.scrollPanel and self.scrollPanel:isMouseOver() then
        -- getMouseX/getMouseY return content coordinates (scroll is handled automatically)
        local x = self.scrollPanel:getMouseX()
        local y = self.scrollPanel:getMouseY()
        
        hoveredButton = self:getButtonAtPosition(x, y)
        local itemAtPosition = self:getSpawnerAtPosition(x, y)
        
        -- Check if it's a group header or a spawner
        if itemAtPosition then
            if itemAtPosition.isGroupHeader then
                newHoveredGroupName = itemAtPosition.groupName
            else
                newHoveredSpawner = itemAtPosition
            end
        end
    end
    
    self.hoveredButton = hoveredButton
    
    -- Update hovered spawner/group for highlighting
    if newHoveredSpawner ~= self.hoveredSpawner or newHoveredGroupName ~= self.hoveredGroupName then
        self.hoveredSpawner = newHoveredSpawner
        self.hoveredGroupName = newHoveredGroupName
        self:updateHighlighters()
    end
end

function WLSP_SpawnerListWindow:onMouseMoveOutside(dx, dy)
    ISPanel.onMouseMoveOutside(self, dx, dy)
    
    -- Clear hover states when mouse leaves the window
    self.hoveredButton = nil
    if self.hoveredSpawner or self.hoveredGroupName then
        self.hoveredSpawner = nil
        self.hoveredGroupName = nil
        self:updateHighlighters()
    end
end

function WLSP_SpawnerListWindow:update()
    ISPanel.update(self)
    
    -- Check if player has moved more than 20 squares
    if self.player and self.lastPlayerX and self.lastPlayerY then
        local currentX = self.player:getX()
        local currentY = self.player:getY()
        local dx = currentX - self.lastPlayerX
        local dy = currentY - self.lastPlayerY
        local distanceMoved = math.sqrt(dx * dx + dy * dy)
        
        if distanceMoved > 20 then
            self:populateList()
            return
        end
    end
end

function WLSP_SpawnerListWindow:onAddSpawner()
    WLSP_ManageSpawner:show(self.player, nil)
end

--- Get spawner at mouse position (for hover highlighting)
function WLSP_SpawnerListWindow:getSpawnerAtPosition(x, y)
    if not self.scrollPanel then return nil end
    
    -- x, y are already content coordinates (scroll offset is handled automatically)
    -- Find which row using the same logic as ISScrollingListBox:rowAt
    local rowY = 0
    for i, v in ipairs(self.scrollPanel.items) do
        if not v.height then v.height = self.scrollPanel.itemheight end
        if y >= rowY and y < rowY + v.height then
            return v.item  -- Returns spawner or nil
        end
        rowY = rowY + v.height
    end
    
    return nil
end

--- Create and configure all highlighters based on hovered spawner or group
function WLSP_SpawnerListWindow:updateHighlighters()
    -- Clear any existing highlighters first
    self:clearHighlighters()
    
    -- If hovering over a group header, highlight all spawners in that group
    if self.hoveredGroupName then
        local spawners = WLSP_Client:getAllSpawners()
        if not spawners then return end
        
        for _, spawner in ipairs(spawners) do
            if spawner.group == self.hoveredGroupName and spawner.position then
                self:createSpawnerHighlighters(spawner)
            end
        end
        return
    end
    
    -- Otherwise, highlight single hovered spawner
    if not self.hoveredSpawner then
        return
    end
    
    local spawner = self.hoveredSpawner
    if not spawner.position then
        return
    end
    
    self:createSpawnerHighlighters(spawner)
end

--- Create highlighters for a single spawner
function WLSP_SpawnerListWindow:createSpawnerHighlighters(spawner)
    if not spawner or not spawner.position then
        return
    end
    
    local pos = spawner.position
    local z = pos.z or 0
    
    -- 1. Spawn Position (Green)
    local spawnPosHL = GroundHighlighter:new()
    spawnPosHL:setColor(0.3, 1.0, 0.3, 1.0)  -- Green
    spawnPosHL:setPriority(0)
    spawnPosHL:highlightSquare(pos.x, pos.y, pos.x, pos.y, z)
    table.insert(self.highlighters, spawnPosHL)
    
    -- 2. Target Location and Line (Red)
    if spawner.targetLocation then
        local target = spawner.targetLocation
        
        -- Target position marker
        local targetHL = GroundHighlighter:new()
        targetHL:setColor(1.0, 0.3, 0.3, 1.0)  -- Red
        targetHL:setPriority(1)
        targetHL:highlightSquare(target.x, target.y, target.x, target.y, target.z or z)
        table.insert(self.highlighters, targetHL)
        
        -- Line from spawn to target
        local lineHL = GroundHighlighter:new()
        lineHL:setColor(1.0, 0.3, 0.3, 0.6)  -- Red, semi-transparent
        lineHL:setPriority(2)
        lineHL:highlightLine(pos.x, pos.y, z, target.x, target.y, target.z or z, 1)
        table.insert(self.highlighters, lineHL)
    end
end

--- Clear all highlighters (called before creating new ones or on window close)
function WLSP_SpawnerListWindow:clearHighlighters()
    for _, hl in ipairs(self.highlighters) do
        if hl then
            hl:remove()  -- Auto-unregisters from HighlighterManager
        end
    end
    self.highlighters = {}
end

--- Check if all spawners in a group are enabled
function WLSP_SpawnerListWindow:isGroupEnabled(groupName)
    if not groupName then return false end
    
    local spawners = WLSP_Client:getAllSpawners()
    if not spawners then return false end
    
    local hasSpawners = false
    for _, spawner in ipairs(spawners) do
        if spawner.group == groupName then
            hasSpawners = true
            if not WLSP_Client:isSpawnerEnabled(spawner.id) then
                return false
            end
        end
    end
    
    return hasSpawners
end

function WLSP_SpawnerListWindow:onClose()
    -- Clear all highlighters before closing
    self:clearHighlighters()
    
    self:removeFromUIManager()
    WLSP_SpawnerListWindow.instance = nil
end