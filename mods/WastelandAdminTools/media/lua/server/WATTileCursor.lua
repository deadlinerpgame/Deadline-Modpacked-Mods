WATTileCursor = ISBuildingObject:derive("WATTileCursor")

function WATTileCursor:new(character, mode, tileEditorMain)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:init()
    o.character = character
    o.player = character:getPlayerNum()
    o.mode = mode
    o.tileEditorMain = tileEditorMain
    o.noNeedHammer = true
    o.skipBuildAction = true
    o.skipWalk2 = true
    o.canBeAlwaysPlaced = true
    
    o.selectableItems = {}
    o.currentIndex = 1
    o.currentSquare = nil
    o.targetObject = nil
    o.targetSprite = nil
    
    -- Create tooltip
    o.tooltip = ISUIElement:new(0, 0, 0, 0)
    o.tooltip:setAlwaysOnTop(true)
    o.tooltip.prerender = function(self)
        o:renderTooltip(self)
    end
    o.tooltip:addToUIManager()
    
    return o
end

function WATTileCursor:deactivate()
    if self.tooltip then
        self.tooltip:removeFromUIManager()
        self.tooltip = nil
    end
end

function WATTileCursor:renderTooltip(tooltipUI)
    if not self.selectableItems or #self.selectableItems == 0 then
        return
    end
    
    local text = ""
    local index = self.currentIndex
    if index > #self.selectableItems then index = 1 end
    local item = self.selectableItems[index]
    if item then
         text = item.desc
         if #self.selectableItems > 1 then
             text = text .. " (" .. index .. "/" .. #self.selectableItems .. ")"
         end
    end
    
    if text == "" then
        return
    end
    
    local font = UIFont.Small
    local width = getTextManager():MeasureStringX(font, text)
    local height = getTextManager():getFontHeight(font)
    local padding = 4
    
    tooltipUI:setWidth(width + padding * 2)
    tooltipUI:setHeight(height + padding * 2)
    
    local mx = getMouseX()
    local my = getMouseY()
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()
    
    local x = mx + 20
    local y = my + 10
    
    if x + tooltipUI.width > screenWidth then x = mx - tooltipUI.width - 10 end
    if y + tooltipUI.height > screenHeight then y = my - tooltipUI.height - 10 end
    
    tooltipUI:setX(x)
    tooltipUI:setY(y)
    
    tooltipUI:drawRect(0, 0, tooltipUI.width, tooltipUI.height, 0.8, 0.0, 0.0, 0.0)
    tooltipUI:drawRectBorder(0, 0, tooltipUI.width, tooltipUI.height, 0.5, 1, 1, 1)
    tooltipUI:drawText(text, padding, padding, 1, 1, 1, 1, font)
end

function WATTileCursor:render(x, y, z, square)
    -- Update state
    if self.currentSquare ~= square then
        self.currentSquare = square
        self:buildSelectableItemsList(square)
        self.currentIndex = 1
    end
    
    -- Update target
    self:updateTarget()
    
    -- Render highlight
    if self.targetSprite then
        local r, g, b, a = 0, 1, 0, 1.0
        if self.mode == "delete" then r, g, b, a = 1, 0, 0, 1.0 end
        
        if not self.RENDER_SPRITE then self.RENDER_SPRITE = IsoSprite.new() end
        if self.RENDER_SPRITE_NAME ~= self.targetSprite then
            self.RENDER_SPRITE:LoadFramesNoDirPageSimple(self.targetSprite)
            self.RENDER_SPRITE_NAME = self.targetSprite
        end
        self.RENDER_SPRITE:RenderGhostTileColor(x, y, z, r, g, b, a)
    end
end

function WATTileCursor:buildSelectableItemsList(sq)
    self.selectableItems = {}
    if not sq then return end
    
    local objects = sq:getObjects()
    for i=0, objects:size()-1 do
        local obj = objects:get(i)
        
        -- 1. Primary Sprite
        local sprite = obj:getSprite()
        if sprite and sprite:getName() then
            table.insert(self.selectableItems, {
                type = "primary",
                object = obj,
                spriteName = sprite:getName(),
                desc = sprite:getName()
            })
        end
        
        -- 2. Overlay Sprite
        local overlay = obj:getOverlaySprite()
        if overlay and overlay:getName() then
             table.insert(self.selectableItems, {
                type = "overlay",
                object = obj,
                spriteName = overlay:getName(),
                desc = "Overlay: " .. overlay:getName()
            })
        end
        
        -- 3. Attached Anim Sprites
        local attached = obj:getAttachedAnimSprite()
        if attached then
            for j=0, attached:size()-1 do
                local attachedSprite = attached:get(j):getParentSprite()
                if attachedSprite and attachedSprite:getName() then
                    table.insert(self.selectableItems, {
                        type = "attached",
                        object = obj,
                        spriteName = attachedSprite:getName(),
                        desc = "Attached: " .. attachedSprite:getName(),
                        attachedIndex = j
                    })
                end
            end
        end
    end
end

function WATTileCursor:updateTarget()
    if self.selectableItems and #self.selectableItems > 0 then
        if self.currentIndex > #self.selectableItems then self.currentIndex = 1 end
        if self.currentIndex < 1 then self.currentIndex = #self.selectableItems end
        
        local item = self.selectableItems[self.currentIndex]
        self.targetObject = item.object
        self.targetSprite = item.spriteName
    else
        self.targetObject = nil
        self.targetSprite = nil
    end
end

function WATTileCursor:onKeyPressed(key)
    if key == Keyboard.KEY_LBRACKET then
        self.currentIndex = self.currentIndex - 1
    elseif key == Keyboard.KEY_RBRACKET then
        self.currentIndex = self.currentIndex + 1
    end
end

function WATTileCursor:create(x, y, z, north, sprite)
    if self.mode == "select" then
        if self.targetSprite then
            self.tileEditorMain.palettePanel:addTile(self.targetSprite)
            self.tileEditorMain.statusMessage = "Added " .. self.targetSprite .. " to palette"
        end
    elseif self.mode == "delete" then
        if self.selectableItems and #self.selectableItems > 0 then
            local item = self.selectableItems[self.currentIndex]
            if item then
                if self.tileEditorMain.actions:deleteTile(self.currentSquare, item, self.tileEditorMain.undoManager) then
                    self.tileEditorMain.statusMessage = "Deleted " .. (self.targetSprite or "object")
                    self:buildSelectableItemsList(self.currentSquare)
                end
            end
        end
    end
end

function WATTileCursor:isValid(square)
    return true 
end
