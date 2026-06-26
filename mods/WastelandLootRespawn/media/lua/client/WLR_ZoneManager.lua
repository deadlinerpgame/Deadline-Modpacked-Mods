if isServer() then return end

require "WLR_ClientSync"
require "WLR_NetworkConstants"

-- Zone Manager - Main zone management interface
WLR_ZoneManager = ISCollapsableWindow:derive("WLR_ZoneManager")
WLR_ZoneManager.instance = nil

function WLR_ZoneManager:show()
    -- Admin check
    if not isAdmin() then
        getPlayer():Say("Access denied - admin privileges required")
        return
    end
    
    if self.instance then
        self.instance:close()
    end
    
    local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12
    local w = 700 * scale
    local h = 600 * scale
    local o = WLR_ZoneManager:new(getCore():getScreenWidth()/2-w/2, getCore():getScreenHeight()/2-h/2, w, h)
    o.scale = scale
    o.alwaysOnTop = true
    setmetatable(o, self)
    self.__index = self
    o:initialise()
    o:addToUIManager()
    self.instance = o
    return o
end

function WLR_ZoneManager:initialise()
    ISCollapsableWindow.initialise(self)
    self.moveWithMouse = true
    self:setResizable(false)
    self.title = "Zone Manager"
    
    self.selectedZone = nil
    self.zoneEditor = nil
    self.chunkPanel = nil
    self.rightPanelElements = {}
    
    local win = GravyUI.Node(self.width, self.height, self):pad(5, 21, 5, 16)
    
    -- Main layout: zones list on left, details on right
    local leftPanel, rightPanel = win:cols({0.4, 0.6}, 10 * self.scale)
    
    -- Left panel: zone list and controls
    local zoneListHeader, zoneListContent, zoneListButtons = leftPanel:rows({30, 1.0, 40}, 5)
    
    -- Zone list header
    self.zoneListHeaderLabel = zoneListHeader:makeLabel("Respawn Zones", UIFont.Medium, {r=1, g=1, b=1, a=1}, "center")
    
    -- Zone list
    self.zoneListBox = zoneListContent:makeScrollingListBox()
    self.zoneListBox.onmousedown = function()
        if self.zoneListBox.selected > 0 then
            local zones = WLR_ClientSync.GetZoneDefinitions()
            local zoneIds = {}
            for id, _ in pairs(zones) do
                table.insert(zoneIds, id)
            end
            table.sort(zoneIds)
            
            if zoneIds[self.zoneListBox.selected] then
                self.selectedZone = zoneIds[self.zoneListBox.selected]
                self:updateRightPanel()
            end
        end
    end
    
    -- Zone list buttons
    local createButton, editButton, deleteButton = zoneListButtons:cols(3, 5)
    self.createZoneButton = createButton:makeButton("Create New", self, self.onCreateZone)
    self.editZoneButton = editButton:makeButton("Edit Zone", self, self.onEditZone)
    self.deleteZoneButton = deleteButton:makeButton("Delete Zone", self, self.onDeleteZone)
    
    -- Right panel: zone details and chunk panel
    local zoneDetailsHeader, zoneDetailsContent = rightPanel:rows({30, 1.0}, 5)
    
    -- Zone details header
    self.zoneDetailsHeaderLabel = zoneDetailsHeader:makeLabel("Zone Details", UIFont.Medium, {r=1, g=1, b=1, a=1}, "center")
    
    -- Zone details content (will be populated dynamically)
    self.zoneDetailsContent = zoneDetailsContent
    
    -- Initialize with empty state
    self:updateZoneList()
    self:updateRightPanel()
    
    -- Listen for data updates
    Events.WLR_ZoneDefinitionsUpdated.Add(function() self:updateZoneList() end)
    Events.WLR_ChunkStatusUpdated.Add(function() self:updateRightPanel() end)
end

function WLR_ZoneManager:updateZoneList()
    if not self.zoneListBox then return end
    
    self.zoneListBox:clear()
    
    local zones = WLR_ClientSync.GetZoneDefinitions()
    local zoneIds = {}
    for id, _ in pairs(zones) do
        table.insert(zoneIds, id)
    end
    table.sort(zoneIds)
    
    for _, zoneId in ipairs(zoneIds) do
        local zone = zones[zoneId]
        local status = zone.enabled and "Enabled" or "Disabled"
        local displayText = zoneId .. " (" .. status .. ")"
        self.zoneListBox:addItem(displayText, zone)
    end
end

function WLR_ZoneManager:updateRightPanel()
    if not self.zoneDetailsContent then return end
    
    -- Clear existing content by removing all child UI elements
    if self.rightPanelElements then
        for _, element in ipairs(self.rightPanelElements) do
            self:removeChild(element)
        end
    end
    self.rightPanelElements = {}
    
    if not self.selectedZone then
        return
    end
    
    local zone = WLR_ClientSync.GetZoneDefinition(self.selectedZone)
    if not zone then
        return
    end
    
    -- Zone info section and chunk panel
    local zoneInfoSection, chunkPanelSection = self.zoneDetailsContent:rows({0.4, 0.6}, 10)
    
    -- Zone info
    local infoGrid = {zoneInfoSection:grid({25, 25, 25, 25, 25, 25, 25, 25}, {100, 1.0}, 5, 2)}
    
    -- Create labels and track them for cleanup
    local zoneIdLabel1 = infoGrid[1][1]:makeLabel("Zone ID:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local zoneIdLabel2 = infoGrid[1][2]:makeLabel(zone.id, UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, zoneIdLabel1)
    table.insert(self.rightPanelElements, zoneIdLabel2)
    
    local statusLabel1 = infoGrid[2][1]:makeLabel("Status:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local statusColor = zone.enabled and {r=0.3, g=1, b=0.3, a=1} or {r=1, g=0.3, b=0.3, a=1}
    local statusText = zone.enabled and "Enabled" or "Disabled"
    local statusLabel2 = infoGrid[2][2]:makeLabel(statusText, UIFont.Small, statusColor, "left")
    table.insert(self.rightPanelElements, statusLabel1)
    table.insert(self.rightPanelElements, statusLabel2)
    
    local coordLabel1 = infoGrid[3][1]:makeLabel("Coordinates:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local coordText = string.format("(%d,%d) to (%d,%d)", zone.x1, zone.y1, zone.x2, zone.y2)
    local coordLabel2 = infoGrid[3][2]:makeLabel(coordText, UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, coordLabel1)
    table.insert(self.rightPanelElements, coordLabel2)
    
    local containerLabel1 = infoGrid[4][1]:makeLabel("Container Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local containerLabel2 = infoGrid[4][2]:makeLabel(string.format("%.1f%%", zone.containerChance * 100), UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, containerLabel1)
    table.insert(self.rightPanelElements, containerLabel2)
    
    local itemLabel1 = infoGrid[5][1]:makeLabel("Item Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local itemLabel2 = infoGrid[5][2]:makeLabel(string.format("%.1f%%", zone.itemChance * 100), UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, itemLabel1)
    table.insert(self.rightPanelElements, itemLabel2)
    
    local freqLabel1 = infoGrid[6][1]:makeLabel("Frequency:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local freqLabel2 = infoGrid[6][2]:makeLabel(zone.frequencyHours .. " hours", UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, freqLabel1)
    table.insert(self.rightPanelElements, freqLabel2)
    
    local countLabel1 = infoGrid[7][1]:makeLabel("Item Count Ignore:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local countLabel2 = infoGrid[7][2]:makeLabel(tostring(zone.itemCountToIgnore), UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, countLabel1)
    table.insert(self.rightPanelElements, countLabel2)
    
    local gasLabel1 = infoGrid[8][1]:makeLabel("Gas Fill Chance:", UIFont.Small, {r=1, g=1, b=1, a=1}, "right")
    local gasLabel2 = infoGrid[8][2]:makeLabel(string.format("%.1f%%", zone.gasFillChance), UIFont.Small, {r=0.8, g=0.8, b=0.8, a=1}, "left")
    table.insert(self.rightPanelElements, gasLabel1)
    table.insert(self.rightPanelElements, gasLabel2)
    
    -- Chunk panel section
    local chunkHeader, chunkContent, chunkButtons = chunkPanelSection:rows({25, 1.0, 30}, 5)
    
    local chunkHeaderLabel = chunkHeader:makeLabel("Chunks in Zone", UIFont.Small, {r=1, g=1, b=1, a=1}, "center")
    table.insert(self.rightPanelElements, chunkHeaderLabel)
    
    -- Chunk list
    self.chunkListBox = chunkContent:makeScrollingListBox()
    table.insert(self.rightPanelElements, self.chunkListBox)
    self:updateChunkList()
    
    -- Chunk buttons
    local forceRespawnButton, respawnAllButton = chunkButtons:cols(2, 5)
    self.forceRespawnButton = forceRespawnButton:makeButton("Force Respawn Selected", self, self.onForceRespawnChunk)
    self.respawnAllButton = respawnAllButton:makeButton("Respawn All Ready", self, self.onRespawnAllReady)
    table.insert(self.rightPanelElements, self.forceRespawnButton)
    table.insert(self.rightPanelElements, self.respawnAllButton)
end

function WLR_ZoneManager:updateChunkList()
    if not self.chunkListBox or not self.selectedZone then return end
    
    self.chunkListBox:clear()
    
    local chunks = WLR_ClientSync.GetChunksInZone(self.selectedZone)
    local currentTime = getTimestamp()
    
    for chunkKey, chunkData in pairs(chunks) do
        local coords = chunkKey:match("([^,]+),([^,]+)")
        local x, y = tonumber(coords:match("([^,]+)")), tonumber(coords:match(",(.+)"))
        
        local lastRespawn = chunkData.lastRespawn
        local nextRespawn = chunkData.nextRespawn
        local ready = chunkData.ready
        
        -- Format time displays
        local lastRespawnText = "Never"
        if lastRespawn and lastRespawn > 0 then
            local timeSince = currentTime - lastRespawn
            lastRespawnText = self:formatTimeAgo(timeSince)
        end
        
        local nextRespawnText = "Unknown"
        if nextRespawn then
            local timeUntil = nextRespawn - currentTime
            if timeUntil <= 0 then
                nextRespawnText = "Ready now"
            else
                nextRespawnText = "In " .. self:formatTimeUntil(timeUntil)
            end
        end
        
        local status = ready and "Ready" or "Waiting"
        local statusColor = ready and " [READY]" or ""
        
        local displayText = string.format("(%d,%d) - Last: %s, Next: %s%s", 
            x or 0, y or 0, lastRespawnText, nextRespawnText, statusColor)
        
        self.chunkListBox:addItem(displayText, {chunkKey = chunkKey, chunkData = chunkData})
    end
end

function WLR_ZoneManager:formatTimeAgo(seconds)
    if seconds < 60 then
        return "Just now"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. " minutes ago"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. " hours ago"
    else
        return math.floor(seconds / 86400) .. " days ago"
    end
end

function WLR_ZoneManager:formatTimeUntil(seconds)
    if seconds < 60 then
        return "1 minute"
    elseif seconds < 3600 then
        return math.floor(seconds / 60) .. " minutes"
    elseif seconds < 86400 then
        return math.floor(seconds / 3600) .. " hours"
    else
        return math.floor(seconds / 86400) .. " days"
    end
end

function WLR_ZoneManager:onCreateZone()
    if self.zoneEditor then
        self.zoneEditor:close()
    end
    
    -- Import and show zone editor
    require "WLR_ZoneEditor"
    self.zoneEditor = WLR_ZoneEditor:show(nil) -- nil for new zone
end

function WLR_ZoneManager:onEditZone()
    if not self.selectedZone then
        getPlayer():Say("Please select a zone to edit")
        return
    end
    
    if self.zoneEditor then
        self.zoneEditor:close()
    end
    
    -- Import and show zone editor
    require "WLR_ZoneEditor"
    self.zoneEditor = WLR_ZoneEditor:show(self.selectedZone)
end

function WLR_ZoneManager:onDeleteZone()
    if not self.selectedZone then
        getPlayer():Say("Please select a zone to delete")
        return
    end
    
    local modal = ISModalDialog:new(getCore():getScreenWidth()/2-150, getCore():getScreenHeight()/2-75, 300, 150, 
        "Delete zone '" .. self.selectedZone .. "'?\n\nThis action cannot be undone.", true, self, self.confirmDeleteZone)
    modal:initialise()
    modal:addToUIManager()
end

function WLR_ZoneManager:confirmDeleteZone(button)
    if button.internal == "YES" and self.selectedZone then
        -- Send delete command to server
        sendClientCommand(getPlayer(), "WLR_Auto", "deleteZone", { zoneId = self.selectedZone })
        self.selectedZone = nil
        self:updateRightPanel()
    end
end

function WLR_ZoneManager:onForceRespawnChunk()
    if not self.chunkListBox or self.chunkListBox.selected <= 0 then
        getPlayer():Say("Please select a chunk to force respawn")
        return
    end
    
    local selectedItem = self.chunkListBox.items[self.chunkListBox.selected]
    if selectedItem and selectedItem.item and selectedItem.item.chunkKey then
        WLR_ClientSync.RequestForceChunkRespawn(selectedItem.item.chunkKey)
        getPlayer():Say("Force respawn requested for chunk " .. selectedItem.item.chunkKey)
    end
end

function WLR_ZoneManager:onRespawnAllReady()
    if not self.selectedZone then
        getPlayer():Say("Please select a zone")
        return
    end
    
    -- Send command to respawn all ready chunks in zone
    sendClientCommand(getPlayer(), "WLR_Auto", "respawnAllReadyInZone", { zoneId = self.selectedZone })
    getPlayer():Say("Respawn all ready chunks requested for zone " .. self.selectedZone)
end

function WLR_ZoneManager:close()
    if self.zoneEditor then
        self.zoneEditor:close()
        self.zoneEditor = nil
    end
    
    if self.chunkPanel then
        self.chunkPanel:close()
        self.chunkPanel = nil
    end
    
    self:setVisible(false)
    self:removeFromUIManager()
    WLR_ZoneManager.instance = nil
end

-- Global function to show zone manager
function WLR_ShowZoneManager()
    WLR_ZoneManager:show()
end