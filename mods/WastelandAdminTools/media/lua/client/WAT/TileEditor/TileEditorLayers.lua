-- TileEditorLayers.lua
-- Handles the "Layers" editing mode for inspecting and modifying tiles on a square

require "ISUI/ISPanel"
require "ISUI/ISScrollingListBox"
require "GravyUI_WL"

TileEditorLayers = ISPanel:derive("TileEditorLayers")

function TileEditorLayers:new(x, y, width, height, mainEditor)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.mainEditor = mainEditor
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    o.preferredHeight = 350 * (mainEditor.scale or 1)
    o.selectedSquare = nil
    return o
end

function TileEditorLayers:createChildren()
    ISPanel.createChildren(self)
    
    local win = GravyUI.Node(self.width, self.height, self):pad(10, 10, 10, 10)
    
    -- Layout: List takes most space, Controls/Status at bottom
    local mainContent, bottomRow = win:rows({1, 30 * (self.mainEditor.scale or 1)}, 5)
    
    -- List Box
    self.listBox = ISScrollingListBox:new(mainContent.left, mainContent.top, mainContent.width, mainContent.height)
    self.listBox:initialise()
    self.listBox:instantiate()
    self.listBox.itemheight = 40 * (self.mainEditor.scale or 1)
    self.listBox.selected = 0
    self.listBox.joypadParent = self
    self.listBox.font = UIFont.Small
    self.listBox.drawBorder = true
    
    -- Override doDrawItem to show textures and buttons
    self.listBox.doDrawItem = function(list, y, item, alt)
        if list.selected == item.index then
            list:drawRect(0, y, list:getWidth(), item.height-1, 0.3, 0.7, 0.35, 0.15)
        end
        list:drawRectBorder(0, y, list:getWidth(), item.height, 0.5, list.borderColor.r, list.borderColor.g, list.borderColor.b)
        
        local itemPadY = (item.height - list.fontHgt) / 2
        local itemPadX = item.item.type == "object" and 2 or 12
        -- Draw Texture
        if item.item and item.item.texture then
            local r, g, b = 0, 0, 0
            if TileEditorMain.instance and TileEditorMain.instance.lightMode then
                r, g, b = 1, 1, 1
            end
            list:drawRect(itemPadX - 1, y + 1, item.height - 2, item.height - 2, 1, r, g, b)
            list:drawTextureScaledAspect(item.item.texture, itemPadX, y + 2, item.height - 4, item.height - 4, 1, 1, 1, 1)
        end
        
        -- Draw Text
        local textX = item.height + 3 + itemPadX
        local r, g, b = 0.9, 0.9, 0.9
        list:drawText(item.text, textX, y + itemPadY, r, g, b, 0.9, list.font)
        
        -- Draw Buttons (Up, Down, Delete)
        local btnSize = item.height - 4
        local pad = 2
        local scrollBarWid = (list.vscroll and list.vscroll:isVisible()) and list.vscroll:getWidth() or 0
        local right = list:getWidth() - scrollBarWid
        
        -- Helper to draw button
        local function drawBtn(x, label, r, g, b)
            list:drawRect(x, y + 2, btnSize, btnSize, 0.2, r, g, b)
            list:drawRectBorder(x, y + 2, btnSize, btnSize, 1, 1, 1, 1)
            local txtW = getTextManager():MeasureStringX(UIFont.Small, label)
            local txtH = getTextManager():getFontHeight(UIFont.Small)
            list:drawText(label, x + (btnSize - txtW)/2, y + 2 + (btnSize - txtH)/2, 1, 1, 1, 1, UIFont.Small)
        end
        
        -- Delete [X]
        local delX = right - btnSize - pad
        drawBtn(delX, "X", 0.5, 0, 0)
        
        if item.item.type == "object" then
            -- Down [v]
            local downX = delX - btnSize - pad
            drawBtn(downX, "v", 0.3, 0.3, 0.3)
            
            -- Up [^]
            local upX = downX - btnSize - pad
            drawBtn(upX, "^", 0.3, 0.3, 0.3)
        
            -- Attach Up [A]
            local attachX = upX - btnSize - pad
            drawBtn(attachX, "A", 0.3, 0.3, 0.6)
        elseif item.item.type == "attached" then
            -- Detach Down [D]
            local detachX = delX - btnSize - pad
            drawBtn(detachX, "D", 0.6, 0.3, 0.3)
        end
        
        return y + item.height
    end
    
    -- Custom Mouse Handling for Buttons
    self.listBox.onMouseDown = function(list, x, y)
        self:onListMouseDown(list, x, y)
    end
    
    self.listBox.onRightMouseDown = function(list, x, y)
        self:onListRightMouseDown(list, x, y)
    end
    
    self:addChild(self.listBox)
    
    -- Bottom Controls
    local btnRefresh, btnSelect, statusLabel = bottomRow:cols({80, 100, 1}, 10)
    
    self.refreshBtn = btnRefresh:makeButton("Refresh", self, self.onRefresh)
    self.refreshBtn.tooltip = "Reload tiles from the selected square"
    
    self.selectModeBtn = btnSelect:makeButton("Select Mode", self, self.onToggleSelectionMode)
    self.selectModeBtn.tooltip = "Toggle selection mode to pick a square"
    
    self.statusLabel = statusLabel:makeLabel("Select a square to inspect", UIFont.Small, {r=0.7,g=1,b=0.7,a=1}, "left")
    
    self:updateButtons()
end

function TileEditorLayers:onListMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then return end
    
    local item = list.items[row]
    if not item then return end
    
    -- Check buttons
    local btnSize = item.height - 4
    local pad = 2
    local scrollBarWid = (list.vscroll and list.vscroll:isVisible()) and list.vscroll:getWidth() or 0
    local right = list:getWidth() - scrollBarWid
    
    -- Delete Button
    local delX = right - btnSize - pad
    if x >= delX and x <= delX + btnSize then
        self:onDelete(item.item)
        return
    end

    if item.item.type == "object" then
        -- Down Button
        local downX = delX - btnSize - pad
        if x >= downX and x <= downX + btnSize then
            self:onMoveDown(item.item)
            return
        end
        
        -- Up Button
        local upX = downX - btnSize - pad
        if x >= upX and x <= upX + btnSize then
            self:onMoveUp(item.item)
            return
        end
        
        -- Attach Up Button
        local attachX = upX - btnSize - pad
        if x >= attachX and x <= attachX + btnSize then
            self:onAttachUp(item.item)
            return
        end
    elseif item.item.type == "attached" then
        -- Detach Down Button
        local detachX = delX - btnSize - pad
        if x >= detachX and x <= detachX + btnSize then
            self:onDetachDown(item.item)
            return
        end
    end
    
    -- Normal Selection
    list.selected = row
    
    -- Left Click Action (Drag)
    self:onLayerLeftClick(item.item)
end

function TileEditorLayers:onListRightMouseDown(list, x, y)
    local row = list:rowAt(x, y)
    if row == -1 then return end
    
    list.selected = row
    local item = list.items[row]
    if not item then return end
    
    -- Right Click Action (Add to Palette)
    self:onCopyToPalette(item.item)
end

function TileEditorLayers:onLayerLeftClick(data)
    if not data then return end
    
    local spriteName = nil
    if data.type == "object" then
        spriteName = data.object:getTextureName()
    elseif data.type == "overlay" then
        spriteName = data.name
    elseif data.type == "attached" then
        spriteName = data.name
    end
    
    if spriteName then
        local player = getPlayer()
        local cursor = ISBrushToolTileCursor:new(spriteName, spriteName, player)
        getCell():setDrag(cursor, player:getPlayerNum())
    end
end

function TileEditorLayers:onRefresh()
    if self.selectedSquare then
        self:refreshList(self.selectedSquare)
    else
        self.statusLabel:setText("No square selected")
    end
end

function TileEditorLayers:refreshList(square)
    self.listBox:clear()
    self.selectedSquare = square
    
    if not square then return end
    
    local objects = square:getObjects()
    local count = 0
    
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        
        -- Normal Sprite
        if object:getTextureName() then
            local item = {}
            item.text = object:getTextureName()
            item.object = object
            item.sq = square
            item.objIndex = i
            item.type = "object"
            item.texture = getTexture(item.text)
            
            self.listBox:addItem(item.text, item)
            count = count + 1
        end
        
        -- Overlay Sprite
        if object:getOverlaySprite() and object:getOverlaySprite():getName() then
            local item = {}
            item.name = object:getOverlaySprite():getName()
            item.text = "Overlay: " .. item.name
            item.object = object
            item.sq = square
            item.objIndex = i
            item.type = "overlay"
            item.texture = getTexture(item.name)
            
            self.listBox:addItem(item.text, item)
            count = count + 1
        end
        
        -- Attached Anim Sprites
        local attachedSprites = object:getAttachedAnimSprite()
        if attachedSprites ~= nil then
            for j = 0, attachedSprites:size()-1 do
                local sprite = attachedSprites:get(j):getParentSprite()
                if sprite and sprite:getName() ~= nil then
                    local item = {}
                    item.name = sprite:getName()
                    item.text = "Attached: " .. item.name
                    item.object = object
                    item.sq = square
                    item.objIndex = i
                    item.animIndex = j
                    item.type = "attached"
                    item.texture = getTexture(item.name)
                    
                    self.listBox:addItem(item.text, item)
                    count = count + 1
                end
            end
        end
    end
    
    self.statusLabel:setText("Found " .. count .. " layers")
    self:updateButtons()
end

function TileEditorLayers:onDelete(data)
    if not data then return end
    
    local undoManager = self.mainEditor.undoManager
    TileEditorActions:deleteTile(data.sq, data, undoManager)
    self.mainEditor:refresh()
end

function TileEditorLayers:onMoveUp(data)
    if not data then return end
    
    if data.type == "object" then
        local undoManager = self.mainEditor.undoManager
        if TileEditorActions:moveObject(data.sq, data.object, -1, undoManager) then
            self.mainEditor:refresh()
        end
    end
end

function TileEditorLayers:onMoveDown(data)
    if not data then return end
    
    if data.type == "object" then
        local undoManager = self.mainEditor.undoManager
        if TileEditorActions:moveObject(data.sq, data.object, 1, undoManager) then
            self.mainEditor:refresh()
        end
    end
end

function TileEditorLayers:onAttachUp(data)
    if not data then return end
    
    if data.type == "object" and data.objIndex > 0 and data.object:getTextureName() then
        -- Attach Up action
        local undoManager = self.mainEditor.undoManager
        if TileEditorActions:attachUp(data.sq, data.object, data.objIndex, undoManager) then
            self.mainEditor.statusMessage = "Attached object to the one above"
            self.mainEditor:refresh()
        else
            self.mainEditor.statusMessage = "Failed to attach object"
        end
    end
end

function TileEditorLayers:onDetachDown(data)
    if not data then return end
    
    if data.type == "attached" then
        -- Detach Down action
        local undoManager = self.mainEditor.undoManager
        if TileEditorActions:detachDown(data.sq, data.object, data.objIndex, data.animIndex, undoManager) then
            self.mainEditor.statusMessage = "Detached attached sprite"
            self.mainEditor:refresh()
        else
            self.mainEditor.statusMessage = "Failed to detach sprite"
        end
    end
end

function TileEditorLayers:onCopyToPalette(data)
    if not data then return end
    
    local spriteName = nil
    if data.type == "object" then
        spriteName = data.object:getTextureName()
    elseif data.type == "overlay" then
        spriteName = data.name
    elseif data.type == "attached" then
        spriteName = data.name
    end
    
    if spriteName and self.mainEditor.palettePanel then
        self.mainEditor.palettePanel:addTile(spriteName)
        self.mainEditor.statusMessage = "Added to palette: " .. spriteName
    end
end

function TileEditorLayers:onToggleSelectionMode()
    self.mainEditor.selectionModeActive = not self.mainEditor.selectionModeActive
    self:updateSelectModeButton()
    
    if self.mainEditor.selectionModeActive then
        -- Force Point selection for Layers mode
        self.mainEditor.selection:setType("point")
        self.mainEditor.statusMessage = "Click a square to inspect layers"
    else
        self.mainEditor.statusMessage = "Selection mode deactivated"
    end
end

function TileEditorLayers:updateSelectModeButton()
    if self.mainEditor.selectionModeActive then
        self.selectModeBtn.backgroundColor = {r=0.2, g=0.8, b=0.2, a=1.0}
    else
        self.selectModeBtn.backgroundColor = {r=0.4, g=0.4, b=0.4, a=1.0}
    end
end

function TileEditorLayers:updateButtons()
    self:updateSelectModeButton()
end

function TileEditorLayers:prerender()
    ISPanel.prerender(self)
    self:updateButtons()
end

-- Called by TileEditorMain when a selection is finished
function TileEditorLayers:onSelectionFinished(selection)
    if not selection then return end
    
    -- We only care about the center point / first point for layers view
    local x, y, z = selection.centerX, selection.centerY, selection.z
    
    local square = getCell():getGridSquare(x, y, z)
    if square then
        self:refreshList(square)
        -- Sticky mode: Do NOT disable selection mode here
    end
end

return TileEditorLayers