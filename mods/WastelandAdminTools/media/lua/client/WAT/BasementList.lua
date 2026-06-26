require "GravyUI_WL"
require "ISUI/ISPanel"
require "ISUI/ISCollapsableWindow"

---@class WAT_BasementList : ISCollapsableWindow
---@field instance WAT_BasementList|nil
WAT_BasementList = ISCollapsableWindow:derive("WAT_BasementList")
WAT_BasementList.instance = nil

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local COLOR_WHITE = {r=1, g=1, b=1, a=1}
local COLOR_YELLOW = {r=1, g=1, b=0, a=1}
local COLOR_GREEN = {r=0.5, g=1, b=0.5, a=1}
local COLOR_RED = {r=1, g=0.5, b=0.5, a=1}
local COLOR_GRAY = {r=0.7, g=0.7, b=0.7, a=1}

local SCALE = FONT_HGT_SMALL / 19
local function scale(px)
    return px * SCALE
end

local PROXIMITY_DISTANCE = 20  -- Default proximity filter distance

--- Shows the Basement List window
--- @return WAT_BasementList
function WAT_BasementList.show()
    if WAT_BasementList.instance then
        WAT_BasementList.instance:setVisible(true)
        WAT_BasementList.instance:refreshList()
        return WAT_BasementList.instance
    end

    local w = scale(500)
    local h = scale(450)
    local o = WAT_BasementList:new(
        getCore():getScreenWidth()/2 - w/2,
        getCore():getScreenHeight()/2 - h/2,
        w, h
    )
    o:initialise()
    o:addToUIManager()
    WAT_BasementList.instance = o
    o:refreshList()
    return o
end

--- Constructor
--- @param x number
--- @param y number
--- @param width number
--- @param height number
--- @return WAT_BasementList
function WAT_BasementList:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.title = "Nearby Basements"

    -- Filter settings
    o.showNearby = true
    o.proximityDistance = PROXIMITY_DISTANCE

    -- Selected basement
    o.selectedBasement = nil

    return o
end

--- Initialize the UI
function WAT_BasementList:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)

    local win = GravyUI.Node(self.width, self.height, self):pad(scale(10), scale(30), scale(10), scale(10))
    local stack = win:makeVerticalStack(scale(8))

    -- Filter section
    local filterRow = stack:makeNode(scale(60))
    self.filterCheckbox = filterRow:makeTickBox()
    self.filterCheckbox:addOption("Show nearby (" .. PROXIMITY_DISTANCE .. " tiles)")
    self.filterCheckbox:addOption("Show all")
    self.filterCheckbox:setSelected(1, true)
    self.filterCheckbox.changeOptionMethod = function() self:onFilterChanged() end

    -- List header
    local headerRow = stack:makeNode(scale(20))
    local nameHeader, locationHeader = headerRow:cols({0.5, 0.5}, scale(5))
    nameHeader:makeLabel("Basement", UIFont.Small, COLOR_YELLOW, "left")
    locationHeader:makeLabel("Entrance Location", UIFont.Small, COLOR_YELLOW, "left")

    -- Basement list box
    local listBoxContainer = stack:makeNode(scale(205))
    self.basementListBox = ISScrollingListBox:new(
        listBoxContainer.left, listBoxContainer.top,
        listBoxContainer.width, listBoxContainer.height
    )
    self.basementListBox:initialise()
    self.basementListBox:instantiate()
    self.basementListBox.itemheight = scale(25)
    self.basementListBox.selected = 0
    self.basementListBox.joypadParent = self
    self.basementListBox.font = UIFont.Small
    self.basementListBox.doDrawItem = self.drawBasementListItem
    self.basementListBox:setOnMouseDownFunction(self, self.onBasementSelected)
    self:addChild(self.basementListBox)

    -- Status label
    local statusRow = stack:makeNode(scale(25))
    self.statusLabel = statusRow:makeLabel("", UIFont.Small, COLOR_WHITE, "center")

    -- Action buttons
    local actionRow = stack:makeNode(scale(30))
    local editBtn, tpEntranceBtn, tpBasementBtn, deleteBtn = actionRow:cols(4, scale(5))
    self.editButton = editBtn:makeButton("Edit", self, self.onEditBasement)
    self.tpEntranceButton = tpEntranceBtn:makeButton("TP Entrance", self, self.onTeleportToEntrance)
    self.tpBasementButton = tpBasementBtn:makeButton("TP Basement", self, self.onTeleportToBasement)
    self.deleteButton = deleteBtn:makeButton("Delete", self, self.onDeleteBasement)

    -- Bottom buttons
    local bottomRow = stack:makeNode(scale(30))
    local refreshBtn, closeBtn = bottomRow:cols(2, scale(10))
    self.refreshButton = refreshBtn:makeButton("Refresh", self, self.refreshList)
    self.closeButton = closeBtn:makeButton("Close", self, self.close)

    -- Initial state
    self:updateButtonStates()
end

--- Draws a basement list item
--- @param y number
--- @param item table
--- @param alt boolean
function WAT_BasementList:drawBasementListItem(y, item, alt)
    local itemPadY = scale(3)

    if self.selected == item.index then
        self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
    end

    local basement = item.item
    local displayName = basement.name or ("Unnamed " .. basement.key)
    local locationText = string.format("%d, %d, %d", basement.outX1, basement.outY1, basement.outZ1)

    -- Draw name
    self:drawText(displayName, 10, y + itemPadY, 1, 1, 1, 0.9, self.font)

    -- Draw location (right side)
    local locationX = self:getWidth() * 0.5
    self:drawText(locationText, locationX, y + itemPadY, 0.7, 0.7, 0.7, 0.9, self.font)

    return y + self.itemheight
end

--- Called when filter checkbox changes
function WAT_BasementList:onFilterChanged()
    self.showNearby = self.filterCheckbox:isSelected(1)
    self:refreshList()
end

--- Refreshes the basement list based on current filter
function WAT_BasementList:refreshList()
    self.basementListBox:clear()
    self.selectedBasement = nil

    local player = getPlayer()
    local playerX = math.floor(player:getX())
    local playerY = math.floor(player:getY())
    local playerZ = math.floor(player:getZ())

    local basements = WAT_BasementZoneManager.basementsData or {}
    local filteredBasements = {}

    for key, basement in pairs(basements) do
        -- Ensure basement has required fields
        if basement and basement.outX1 and basement.outY1 and basement.inX1 and basement.inY1 then
            -- Ensure basement has a key field
            if not basement.key then
                basement.key = key
            end
            
            local include = true

            if self.showNearby then
                -- Check if entrance OR basement arrival is within proximity
                local entranceDist = self:calculateDistance(playerX, playerY, basement.outX1, basement.outY1)
                local basementDist = self:calculateDistance(playerX, playerY, basement.inX1, basement.inY1)

                include = (entranceDist <= self.proximityDistance) or (basementDist <= self.proximityDistance)
            end

            if include then
                table.insert(filteredBasements, basement)
            end
        end
    end

    -- Sort by name/key
    table.sort(filteredBasements, function(a, b)
        local nameA = a.name or a.key or ""
        local nameB = b.name or b.key or ""
        return nameA < nameB
    end)

    -- Add to list
    for _, basement in ipairs(filteredBasements) do
        local displayName = basement.name or ("Unnamed " .. tostring(basement.key or ""))
        self.basementListBox:addItem(displayName, basement)
    end

    local totalCount = 0
    for _ in pairs(basements) do totalCount = totalCount + 1 end

    self.statusLabel:setText(#filteredBasements .. " of " .. totalCount .. " basements shown")
    self:updateButtonStates()
end

--- Calculates 2D distance between two points
--- @param x1 number
--- @param y1 number
--- @param x2 number
--- @param y2 number
--- @return number
function WAT_BasementList:calculateDistance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- Called when a basement is selected in the list
--- @param item table The selected basement item
function WAT_BasementList:onBasementSelected(item)
    self.selectedBasement = item
    self:updateButtonStates()
end

--- Updates button enabled states
function WAT_BasementList:updateButtonStates()
    local hasSelection = self.selectedBasement ~= nil
    self.editButton:setEnable(hasSelection)
    self.tpEntranceButton:setEnable(hasSelection)
    self.tpBasementButton:setEnable(hasSelection)
    self.deleteButton:setEnable(hasSelection)
end

--- Called when Edit button is clicked
function WAT_BasementList:onEditBasement()
    if not self.selectedBasement then return end

    -- Open the basement editor with the selected basement
    if WAT_BasementEditor then
        WAT_BasementEditor.show(self.selectedBasement)
    end
end

--- Called when Teleport to Entrance button is clicked
function WAT_BasementList:onTeleportToEntrance()
    if not self.selectedBasement then return end

    local basement = self.selectedBasement
    WL_Utils.teleportPlayerToCoords(getPlayer(), basement.outX1, basement.outY1, basement.outZ1)
end

--- Called when Teleport to Basement button is clicked
function WAT_BasementList:onTeleportToBasement()
    if not self.selectedBasement then return end

    local basement = self.selectedBasement
    WL_Utils.teleportPlayerToCoords(getPlayer(), basement.inX1, basement.inY1, basement.inZ1)
end

--- Called when Delete button is clicked
function WAT_BasementList:onDeleteBasement()
    if not self.selectedBasement then return end

    local modal = ISModalDialog:new(0, 0, 300, 150,
        "Are you sure you want to delete this basement?\n" ..
        (self.selectedBasement.name or self.selectedBasement.key),
        true, self, self.onDeleteConfirm)
    modal:initialise()
    modal:addToUIManager()
end

--- Called when delete confirmation is received
--- @param button table
function WAT_BasementList:onDeleteConfirm(button)
    if button.internal == "YES" and self.selectedBasement then
        WAT_BasementZoneManager.removeBasement(self.selectedBasement.key)
        self.selectedBasement = nil
        -- Refresh after a short delay to allow server to process
        self.refreshDelay = 20
    end
end

--- Prerender
function WAT_BasementList:prerender()
    ISCollapsableWindow.prerender(self)

    -- Handle refresh delay after delete
    if self.refreshDelay then
        self.refreshDelay = self.refreshDelay - 1
        if self.refreshDelay <= 0 then
            self.refreshDelay = nil
            self:refreshList()
        end
    end
end

--- Close the window
function WAT_BasementList:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    WAT_BasementList.instance = nil
end