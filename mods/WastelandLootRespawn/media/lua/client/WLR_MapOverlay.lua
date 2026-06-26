if isServer() then return end

require "WLR_ClientSync"

-- Extend ISWorldMap to add WLR loot zone visualization
ISWorldMap.WLR_original_createChildren = ISWorldMap.WLR_original_createChildren or ISWorldMap.createChildren;
function ISWorldMap:createChildren()
    ISWorldMap.WLR_original_createChildren(self)

    local btnSize = self.texViewIsometric and self.texViewIsometric:getWidth() or 48
    local buttons = self.buttonPanel.joypadButtons

    -- Shift existing buttons to make room for our button
    for _, btn in ipairs(buttons) do
        btn:setX(btn.x + btnSize + 20)
    end

    -- Create "Loot Zones" button (admin only)
    self.showWLRZonesButton = ISButton:new(buttons[1].x - 20 - btnSize, 0, btnSize, btnSize, "LR", self, ISWorldMap.WLRZonesOpenOptions)
    self.showWLRZonesButton:setVisible(false) -- Initially hidden, shown only for admins

    table.insert(buttons, 1, self.showWLRZonesButton)
    self.buttonPanel:addChild(self.showWLRZonesButton)
    self.buttonPanel:insertNewListOfButtons(buttons)

    local btnCount = #buttons
    self.buttonPanel:setX(self.width - 20 - (btnSize * btnCount + 20 * (btnCount - 1)))
    self.buttonPanel:setWidth(btnSize * btnCount + 20 * (btnCount - 1))

    -- Initialize WLR overlay settings
    self.wlrOverlaySettings = {
        showZoneBoundaries = false,
        showChunkStatus = false,
        showEnabledZones = true,
        showDisabledZones = false
    }
end

ISWorldMap.WLR_original_render = ISWorldMap.WLR_original_render or ISWorldMap.render;
function ISWorldMap:render()
    ISWorldMap.WLR_original_render(self)

    local player = getPlayer()
    
    -- Show/hide button based on admin status
    if self.showWLRZonesButton:isVisible() then
        if not isAdmin() or self.isometric then
            self.showWLRZonesButton:setVisible(false)
        end
    else
        if isAdmin() and not self.isometric then
            self.showWLRZonesButton:setVisible(true)
        end
    end

    -- Don't render overlay in isometric mode or if player is not admin
    if self.isometric or not isAdmin() then return end

    -- Only render if we have data and overlay is enabled
    if not WLR_ClientSync.IsInitialized() or not self.wlrOverlaySettings then return end

    -- Get viewport bounds for efficient rendering
    local minx = math.max(self.mapAPI:uiToWorldX(0, 0), self.mapAPI:getMinXInSquares())
    local miny = math.max(self.mapAPI:uiToWorldY(0, 0), self.mapAPI:getMinYInSquares())
    local maxx = math.min(self.mapAPI:uiToWorldX(self.width, self.height), self.mapAPI:getMaxXInSquares())
    local maxy = math.min(self.mapAPI:uiToWorldY(self.width, self.height), self.mapAPI:getMaxYInSquares())

    -- Render zone boundaries and chunk overlays
    self:renderWLRZones(minx, miny, maxx, maxy)
end

function ISWorldMap:renderWLRZones(minx, miny, maxx, maxy)
    local zoneDefinitions = WLR_ClientSync.GetZoneDefinitions()
    local chunkStatus = WLR_ClientSync.GetChunkStatus()

    if not zoneDefinitions then return end
    
    local rects = {}
    local texts = {}
    local chunkRects = {}
    local chunkTexts = {}
    
    local textHeight = getTextManager():getFontHeight(UIFont.Medium)
    local smallTextHeight = getTextManager():getFontHeight(UIFont.Small)

    -- Get current zoom level to determine detail level
    local zoomLevel = self.mapAPI:getZoomF()
    local showChunkDetails = zoomLevel > 8 -- Only show chunk details when zoomed in enough
    local showChunkLabels = zoomLevel > 16 -- Only show chunk labels when very zoomed in

    for zoneId, zone in pairs(zoneDefinitions) do
        local x1, y1, x2, y2 = zone.x1, zone.y1, zone.x2, zone.y2
        
        -- Skip zones outside viewport
        if not (x2 < minx or x1 > maxx or y2 < miny or y1 > maxy) then
            -- Check if we should show this zone based on enabled/disabled filter
            local shouldShow = (zone.enabled and self.wlrOverlaySettings.showEnabledZones) or
                              (not zone.enabled and self.wlrOverlaySettings.showDisabledZones)
            
            if shouldShow then
                -- Convert world coordinates to UI coordinates
                local tlX = self.mapAPI:worldToUIX(x1, y1)
                local tlY = self.mapAPI:worldToUIY(x1, y1)
                local brX = self.mapAPI:worldToUIX(x2, y2)
                local brY = self.mapAPI:worldToUIY(x2, y2)

                local centerX = tlX + ((brX - tlX) / 2)
                local centerY = tlY + ((brY - tlY) / 2)

                -- Zone boundary color based on enabled status
                local zoneColor = zone.enabled and {0.2, 0.8, 0.2} or {0.8, 0.2, 0.2} -- Green for enabled, red for disabled
                
                -- Draw zone boundary
                if self.wlrOverlaySettings.showZoneBoundaries then
                    if brX - tlX < 20 and brY - tlY < 20 then
                        -- Small zones get a dot
                        table.insert(rects, {centerX - 2, centerY - 2, 5, 5, 1, zoneColor[1], zoneColor[2], zoneColor[3]})
                    else
                        -- Large zones get a boundary rectangle
                        table.insert(rects, {tlX, tlY, math.max(1, brX - tlX), math.max(1, brY - tlY), 0.3, zoneColor[1], zoneColor[2], zoneColor[3]})
                        
                        -- Zone label
                        local zoneLabel = zoneId .. (zone.enabled and " (ON)" or " (OFF)")
                        table.insert(texts, {zoneLabel, centerX, centerY - textHeight/2, 1, 1, 1, 1, UIFont.Medium})
                    end
                end

                -- Draw chunk grid and status if enabled and zoomed in enough
                if chunkStatus and showChunkDetails and (self.wlrOverlaySettings.showChunkStatus) then
                    self:renderChunkGrid(x1, y1, x2, y2, zoneId, chunkStatus, chunkRects, chunkTexts, showChunkLabels)
                end
            end
        end
    end

    -- Draw all rectangles (zones first, then chunks)
    for _, v in ipairs(rects) do
        self:drawRect(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end
    
    for _, v in ipairs(chunkRects) do
        self:drawRect(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end

    -- Draw all text labels
    for _, v in ipairs(texts) do
        self:drawTextCentre(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end
    
    for _, v in ipairs(chunkTexts) do
        self:drawTextCentre(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8])
    end
end

function ISWorldMap:renderChunkGrid(zoneX1, zoneY1, zoneX2, zoneY2, zoneId, chunkStatus, chunkRects, chunkTexts, showLabels)
    local chunkSize = 50 -- 50x50 chunk size
    local currentTime = getTimestamp()
    
    -- Calculate chunk boundaries within the zone
    local startChunkX = math.floor(zoneX1 / chunkSize) * chunkSize
    local startChunkY = math.floor(zoneY1 / chunkSize) * chunkSize
    local endChunkX = math.ceil(zoneX2 / chunkSize) * chunkSize
    local endChunkY = math.ceil(zoneY2 / chunkSize) * chunkSize
    
    for chunkX = startChunkX, endChunkX - chunkSize, chunkSize do
        for chunkY = startChunkY, endChunkY - chunkSize, chunkSize do
            -- Check if chunk intersects with zone
            if chunkX + chunkSize > zoneX1 and chunkX < zoneX2 and 
               chunkY + chunkSize > zoneY1 and chunkY < zoneY2 then
                
                local chunkKey = tostring(chunkX) .. "," .. tostring(chunkY)
                local chunk = chunkStatus[chunkKey]

                -- Draw chunk status color
                if chunk then
                    -- Convert chunk coordinates to UI coordinates
                    local chunkTlX = self.mapAPI:worldToUIX(chunkX, chunkY)
                    local chunkTlY = self.mapAPI:worldToUIY(chunkX, chunkY)
                    local chunkBrX = self.mapAPI:worldToUIX(chunkX + chunkSize, chunkY + chunkSize)
                    local chunkBrY = self.mapAPI:worldToUIY(chunkX + chunkSize, chunkY + chunkSize)
                    
                    local chunkCenterX = chunkTlX + ((chunkBrX - chunkTlX) / 2)
                    local chunkCenterY = chunkTlY + ((chunkBrY - chunkTlY) / 2)

                    local statusColor = self:getChunkStatusColor(chunk, currentTime)
                    if statusColor then
                        table.insert(chunkRects, {chunkTlX + 1, chunkTlY + 1, math.max(1, chunkBrX - chunkTlX - 2), math.max(1, chunkBrY - chunkTlY - 2), 0.4, statusColor[1], statusColor[2], statusColor[3]})
                    end
                    
                    -- Add chunk coordinate label if zoomed in enough
                    if showLabels then
                        local chunkLabel = chunkX .. "," .. chunkY
                        table.insert(chunkTexts, {chunkLabel, chunkCenterX, chunkCenterY, 0, 0, 0, 0.8, UIFont.Small})
                    end
                end
            end
        end
    end
end

function ISWorldMap:getChunkStatusColor(chunk, currentTime)
    if not chunk.active then
        return nil
    end
    
    local timeSinceRespawn = currentTime - chunk.lastRespawn
    local hoursSinceRespawn = timeSinceRespawn / (60 * 60)
    
    if chunk.ready then
        return {1.0, 1.0, 0.0} -- Yellow for ready to respawn
    elseif hoursSinceRespawn < 24 then
        return {0.0, 1.0, 0.0} -- Green for recently respawned (< 24 hours)
    elseif currentTime >= chunk.nextRespawn then
        return {1.0, 0.0, 0.0} -- Red for overdue
    else
        return nil -- No color for normal waiting period
    end
end

function ISWorldMap:WLRZonesOpenOptions(button)
    if self.WLRZonesOptionsUI == nil then
        local ui = WLRZoneOptionsUI:new(self.width - 250, button.y - 200, self)
        self:addChild(ui)
        ui:setVisible(false)
        self.WLRZonesOptionsUI = ui
    end
    
    if self.WLRZonesOptionsUI:isVisible() then
        self.WLRZonesOptionsUI:setVisible(false)
        return
    end
    
    self.WLRZonesOptionsUI:synchUI()
    self.WLRZonesOptionsUI:setX(math.min(self.width - 20 - self.WLRZonesOptionsUI.width, button.parent.x + button.x))
    self.WLRZonesOptionsUI:setY(button.parent.y + button.y - self.WLRZonesOptionsUI.height)
    self.WLRZonesOptionsUI:setVisible(true)
    
    if JoypadState.players[self.playerNum+1] then
        setJoypadFocus(self.playerNum, self.WLRZonesOptionsUI)
    end
end
