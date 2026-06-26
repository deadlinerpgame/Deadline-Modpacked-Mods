if isServer() then return end

require "WLR_ClientSync"

-- WLR Zone Options UI Panel
WLRZoneOptionsUI = ISPanelJoypad:derive("WLRZoneOptionsUI")

function WLRZoneOptionsUI:new(x, y, map)
    local o = ISPanelJoypad.new(self, x, y, 240, 10)
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.resizable = false
    o.map = map
    o.currentTop = 10
    o.controls = {}
    return o
end

function WLRZoneOptionsUI:initialise()
    ISPanelJoypad.initialise(self)
end

function WLRZoneOptionsUI:synchUI()
    -- Clear existing controls
    for _, control in pairs(self.controls) do
        self:removeChild(control)
    end
    self.controls = {}
    self.currentTop = 10
    
    -- Title
    local titleLabel = ISLabel:new(10, self.currentTop, 20, "WLR Loot Zone Overlay", 1, 1, 1, 1, UIFont.Medium, true)
    titleLabel:initialise()
    self:addChild(titleLabel)
    table.insert(self.controls, titleLabel)
    self.currentTop = self.currentTop + titleLabel:getHeight() + 10
    
    -- Zone Boundary Controls
    local boundaryLabel = ISLabel:new(10, self.currentTop, 20, "Zone Boundaries:", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    boundaryLabel:initialise()
    self:addChild(boundaryLabel)
    table.insert(self.controls, boundaryLabel)
    self.currentTop = self.currentTop + boundaryLabel:getHeight() + 2
    
    self.showBoundariesTick = ISTickBox:new(20, self.currentTop, 200, 20, "", self, WLRZoneOptionsUI.onToggleBoundaries)
    self.showBoundariesTick:initialise()
    self.showBoundariesTick:addOption("Show Zone Boundaries", nil)
    self.showBoundariesTick:setSelected(1, self.map.wlrOverlaySettings.showZoneBoundaries)
    self:addChild(self.showBoundariesTick)
    table.insert(self.controls, self.showBoundariesTick)
    self.currentTop = self.currentTop + self.showBoundariesTick:getHeight() + 5
    
    -- Chunk Grid Controls
    local chunkLabel = ISLabel:new(10, self.currentTop, 20, "Chunk Visualization:", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    chunkLabel:initialise()
    self:addChild(chunkLabel)
    table.insert(self.controls, chunkLabel)
    self.currentTop = self.currentTop + chunkLabel:getHeight() + 2
    
    self.showChunkStatusTick = ISTickBox:new(20, self.currentTop, 200, 20, "", self, WLRZoneOptionsUI.onToggleChunkStatus)
    self.showChunkStatusTick:initialise()
    self.showChunkStatusTick:addOption("Show Chunk Status Colors", nil)
    self.showChunkStatusTick:setSelected(1, self.map.wlrOverlaySettings.showChunkStatus)
    self:addChild(self.showChunkStatusTick)
    table.insert(self.controls, self.showChunkStatusTick)
    self.currentTop = self.currentTop + self.showChunkStatusTick:getHeight() + 5
    
    -- Zone Category Filters
    local filterLabel = ISLabel:new(10, self.currentTop, 20, "Zone Filters:", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    filterLabel:initialise()
    self:addChild(filterLabel)
    table.insert(self.controls, filterLabel)
    self.currentTop = self.currentTop + filterLabel:getHeight() + 2
    
    self.showEnabledZonesTick = ISTickBox:new(20, self.currentTop, 200, 20, "", self, WLRZoneOptionsUI.onToggleEnabledZones)
    self.showEnabledZonesTick:initialise()
    self.showEnabledZonesTick:addOption("Show Enabled Zones", nil)
    self.showEnabledZonesTick:setSelected(1, self.map.wlrOverlaySettings.showEnabledZones)
    self:addChild(self.showEnabledZonesTick)
    table.insert(self.controls, self.showEnabledZonesTick)
    self.currentTop = self.currentTop + self.showEnabledZonesTick:getHeight() + 2
    
    self.showDisabledZonesTick = ISTickBox:new(20, self.currentTop, 200, 20, "", self, WLRZoneOptionsUI.onToggleDisabledZones)
    self.showDisabledZonesTick:initialise()
    self.showDisabledZonesTick:addOption("Show Disabled Zones", nil)
    self.showDisabledZonesTick:setSelected(1, self.map.wlrOverlaySettings.showDisabledZones)
    self:addChild(self.showDisabledZonesTick)
    table.insert(self.controls, self.showDisabledZonesTick)
    self.currentTop = self.currentTop + self.showDisabledZonesTick:getHeight() + 10
    
    -- Status Legend
    local legendLabel = ISLabel:new(10, self.currentTop, 20, "Chunk Status Legend:", 0.8, 0.8, 0.8, 1, UIFont.Small, true)
    legendLabel:initialise()
    self:addChild(legendLabel)
    table.insert(self.controls, legendLabel)
    self.currentTop = self.currentTop + legendLabel:getHeight() + 5
    
    -- Color legend items
    local legendItems = {
        {"Green: Recently respawned (< 24h)", {0, 1, 0}},
        {"Yellow: Ready for respawn", {1, 1, 0}},
        {"Red: Overdue for respawn", {1, 0, 0}},
    }
    
    for _, item in ipairs(legendItems) do
        local legendItem = ISLabel:new(20, self.currentTop, 12, item[1], item[2][1], item[2][2], item[2][3], 1, UIFont.Small, true)
        legendItem:initialise()
        self:addChild(legendItem)
        table.insert(self.controls, legendItem)
        self.currentTop = self.currentTop + legendItem:getHeight() + 2
    end
    
    self.currentTop = self.currentTop + 5
    
    -- Refresh Button
    self.refreshButton = ISButton:new(10, self.currentTop, 100, 25, "Refresh Data", self, WLRZoneOptionsUI.onRefreshData)
    self.refreshButton:initialise()
    self.refreshButton:setFont(UIFont.Small)
    self:addChild(self.refreshButton)
    table.insert(self.controls, self.refreshButton)
    self.currentTop = self.currentTop + self.refreshButton:getHeight() + 5
    
    -- Admin Management Buttons
    if isAdmin() then
        -- Zone Manager Button
        self.zoneManagerButton = ISButton:new(10, self.currentTop, 100, 25, "Zone Manager", self, WLRZoneOptionsUI.onOpenZoneManager)
        self.zoneManagerButton:initialise()
        self.zoneManagerButton:setFont(UIFont.Small)
        self:addChild(self.zoneManagerButton)
        table.insert(self.controls, self.zoneManagerButton)
        self.currentTop = self.currentTop + self.zoneManagerButton:getHeight() + 5
        
        -- Manual Chunk Status Request Button
        self.requestChunkStatusButton = ISButton:new(10, self.currentTop, 120, 25, "Request Chunk Status", self, WLRZoneOptionsUI.onRequestChunkStatus)
        self.requestChunkStatusButton:initialise()
        self.requestChunkStatusButton:setFont(UIFont.Small)
        self:addChild(self.requestChunkStatusButton)
        table.insert(self.controls, self.requestChunkStatusButton)
        self.currentTop = self.currentTop + self.requestChunkStatusButton:getHeight() + 10
    end
    
    -- Update panel height
    self:setHeight(self.currentTop + 10)
end

function WLRZoneOptionsUI:onToggleBoundaries(index, selected)
    self.map.wlrOverlaySettings.showZoneBoundaries = selected
end

function WLRZoneOptionsUI:onToggleChunkStatus(index, selected)
    self.map.wlrOverlaySettings.showChunkStatus = selected
end

function WLRZoneOptionsUI:onToggleEnabledZones(index, selected)
    self.map.wlrOverlaySettings.showEnabledZones = selected
end

function WLRZoneOptionsUI:onToggleDisabledZones(index, selected)
    self.map.wlrOverlaySettings.showDisabledZones = selected
end

function WLRZoneOptionsUI:onRefreshData()
    local player = getPlayer()
    if player and isAdmin() then
        WLR_ClientSync.RequestZoneDefinitions()
        
        -- Show feedback
        player:Say("Refreshing WLR zone data...")
    end
end

function WLRZoneOptionsUI:onOpenZoneManager()
    require "WLR_ZoneManager"
    WLR_ZoneManager:show()
end

function WLRZoneOptionsUI:onRequestChunkStatus()
    local player = getPlayer()
    if player and isAdmin() then
        WLR_ClientSync.RequestChunkStatus()
        
        -- Show feedback
        player:Say("Requesting chunk status data...")
    end
end

-- Event handlers for real-time updates
Events.WLR_ZoneDefinitionsUpdated.Add(function(data)
    -- Update any open map overlay UI
    local worldMap = ISWorldMap_instance
    if worldMap and worldMap.WLRZonesOptionsUI and worldMap.WLRZonesOptionsUI:isVisible() then
        worldMap.WLRZonesOptionsUI:synchUI()
    end
end)

Events.WLR_ChunkStatusUpdated.Add(function(data)
    -- Force map redraw when chunk status updates
    local worldMap = ISWorldMap_instance
    if worldMap then
        worldMap:setVisible(worldMap:isVisible())
    end
end)

Events.WLR_ZoneOperationResponse.Add(function(data)
    -- Handle zone operation responses
    if data.success then
        local operation = data.operation or "unknown"
        if operation == "createZone" or operation == "updateZone" or operation == "deleteZone" then
            -- Update any open zone manager
            if WLR_ZoneManager.instance then
                WLR_ZoneManager.instance:updateZoneList()
                WLR_ZoneManager.instance:updateRightPanel()
            end
        end
    end
end)

-- Global functions for easy access
function WLR_ShowZoneManager()
    require "WLR_ZoneManager"
    WLR_ZoneManager:show()
end

function WLR_ShowZoneEditor(zoneId)
    require "WLR_ZoneEditor"
    WLR_ZoneEditor:show(zoneId)
end