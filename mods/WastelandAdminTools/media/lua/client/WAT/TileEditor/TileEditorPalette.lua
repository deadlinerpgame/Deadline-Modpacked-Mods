-- TileEditorPalette.lua
-- Palette management and UI for the Tile Editor system

require "ISUI/ISPanel"

TileEditorPalette = ISPanel:derive("TileEditorPalette")

-- ============================================================================
-- Constructor
-- ============================================================================

function TileEditorPalette:new(x, y, width, height)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.tiles = {}  -- Array of sprite names
    o.selectedIndex = nil
    o.singleIndex = 1
    o.tileWidth = 0  -- Will be calculated dynamically
    o.tileHeight = 0  -- Will be set to full panel height minus padding
    o.padding = 4
    o.tilesPerRow = 1  -- Will be calculated dynamically
    o.currentRow = 0  -- Which row we're currently viewing (0-based)
    o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.8}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.selectedColor = {r=0.2, g=0.8, b=0.2, a=1}
    o.scrollIndicatorColor = {r=1, g=1, b=0, a=0.8}
    
    return o
end

-- ============================================================================
-- Initialization
-- ============================================================================

function TileEditorPalette:initialise()
    ISPanel.initialise(self)
    self:calculateLayout()
end

function TileEditorPalette:createChildren()
    ISPanel.createChildren(self)
end

--- Calculates the number of columns based on available width
function TileEditorPalette:calculateLayout()
    -- Tile height is the full panel height minus padding
    self.tileHeight = self.height - (self.padding * 2)
    
    -- Tile width is half the height (2:1 height:width ratio)
    self.tileWidth = self.tileHeight / 2
    
    -- Calculate how many tiles fit horizontally
    local availableWidth = self.width - (self.padding * 2)
    local tileWithPadding = self.tileWidth + self.padding
    self.tilesPerRow = math.max(1, math.floor((availableWidth + self.padding) / tileWithPadding))
end

--- Gets the total number of rows needed (including space for next tile)
function TileEditorPalette:getTotalRows()
    if #self.tiles == 0 then return 0 end
    -- Add 1 to account for the potential next tile that will be added
    return math.ceil((#self.tiles + 1) / self.tilesPerRow)
end

--- Gets the first and last tile index for the current row
function TileEditorPalette:getCurrentRowRange()
    local firstIndex = self.currentRow * self.tilesPerRow + 1
    local lastIndex = math.min(firstIndex + self.tilesPerRow - 1, #self.tiles)
    return firstIndex, lastIndex
end

-- ============================================================================
-- Palette Management
-- ============================================================================

--- Adds a tile to the palette
-- @param spriteName Sprite name to add
-- @return boolean Success
-- Note: Duplicates are allowed to enable ratio-based random selection
function TileEditorPalette:addTile(spriteName)
    if not spriteName or spriteName == "" then
        return false
    end
    
    -- Check if sprite is valid
    if not TileEditorUtils.isValidSprite(spriteName) then
        TileEditorUtils.error("Invalid sprite:", spriteName)
        return false
    end
    
    -- Always allow duplicates for ratio-based random selection
    table.insert(self.tiles, spriteName)
    TileEditorUtils.debug("Added tile to palette:", spriteName)
    for _, tile in ipairs(self.tiles) do
        TileEditorUtils.debug(" - " .. tile)
    end
    return true
end

--- Removes a tile from the palette by index
-- @param index Index to remove (1-based)
-- @return boolean Success
function TileEditorPalette:removeTile(index)
    if index < 1 or index > #self.tiles then
        return false
    end
    
    local removed = table.remove(self.tiles, index)
    TileEditorUtils.debug("Removed tile from palette:", removed)
    
    -- Clear selection if we removed the selected tile
    if self.selectedIndex == index then
        self.selectedIndex = nil
    elseif self.selectedIndex and self.selectedIndex > index then
        self.selectedIndex = self.selectedIndex - 1
    end

    -- Adjust singleIndex
    if self.singleIndex >= index then
        if self.singleIndex == index then
             self.singleIndex = 1
        else
             self.singleIndex = self.singleIndex - 1
        end
    end
    
    return true
end

--- Clears all tiles from the palette
function TileEditorPalette:clearPalette()
    self.tiles = {}
    self.selectedIndex = nil
    self.singleIndex = 1
    TileEditorUtils.debug("Cleared palette")
end

--- Gets a tile by index
-- @param index Index (1-based)
-- @return string Sprite name or nil
function TileEditorPalette:getTile(index)
    if index < 1 or index > #self.tiles then
        return nil
    end
    return self.tiles[index]
end

--- Gets a random tile from the palette
-- @return string Sprite name or nil
function TileEditorPalette:getRandomTile()
    if #self.tiles == 0 then
        return nil
    end
    
    local index = ZombRand(#self.tiles) + 1
    return self.tiles[index]
end

--- Gets the first tile in the palette (or the one marked as Single)
-- @return string Sprite name or nil
function TileEditorPalette:getFirstTile()
    if #self.tiles == 0 then
        return nil
    end
    -- Ensure singleIndex is valid
    if self.singleIndex < 1 or self.singleIndex > #self.tiles then
        self.singleIndex = 1
    end
    return self.tiles[self.singleIndex]
end

--- Checks if palette is empty
-- @return boolean
function TileEditorPalette:isEmpty()
    return #self.tiles == 0
end

--- Gets the number of tiles in the palette
-- @return number
function TileEditorPalette:getCount()
    return #self.tiles
end

--- Gets the number of tiles in the palette (alias for getCount)
-- @return number
function TileEditorPalette:getTileCount()
    return #self.tiles
end

-- ============================================================================
-- Rendering
-- ============================================================================

function TileEditorPalette:prerender()
    ISPanel.prerender(self)
    
    -- Draw background
    self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a,
                  self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
    
    -- Draw border
    self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a,
                       self.borderColor.r, self.borderColor.g, self.borderColor.b)
end

function TileEditorPalette:render()
    ISPanel.render(self)
    
    if #self.tiles == 0 then
        -- Draw "empty" message
        local text = "No tiles in palette"
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
        local r, g, b = 0.5, 0.5, 0.5
        self:drawText(text, (self.width - textWidth) / 2, self.height / 2 - 10,
                     r, g, b, 1.0, UIFont.Small)
        
        -- Still show cursor preview even if palette is empty
        local cursor = getCell():getDrag(0)
        if cursor ~= nil and cursor.choosenSprite then
            local mouseX = self:getMouseX()
            local mouseY = self:getMouseY()
            
            if mouseX >= 0 and mouseX < self.width and mouseY >= 0 and mouseY < self.height then
                local hover_c = math.floor((mouseX - self.padding) / (self.tileWidth + self.padding))
                
                if hover_c >= 0 and hover_c < self.tilesPerRow then
                    local hoverX = self.padding + hover_c * (self.tileWidth + self.padding)
                    local hoverY = self.padding
                    
                    -- Draw preview of tile that will be added
                    local texture = getTexture(cursor.choosenSprite)
                    if texture then
                        self:drawTextureScaledAspect(texture, hoverX, hoverY,
                                                    self.tileWidth, self.tileHeight,
                                                    0.6, 1.0, 1.0, 1.0)
                    end
                    
                    -- Draw green border to indicate it will be added
                    self:drawRectBorder(hoverX, hoverY, self.tileWidth, self.tileHeight,
                                       0.8, 0, 1, 0)
                end
            end
        end
        
        return
    end
    
    -- Get the range of tiles to display for the current row
    local firstIndex, lastIndex = self:getCurrentRowRange()
    
    -- Render only tiles in the current row
    for i = firstIndex, lastIndex do
        local spriteName = self.tiles[i]
        local col = (i - 1) % self.tilesPerRow
        
        local x = self.padding + col * (self.tileWidth + self.padding)
        local y = self.padding
        
        -- Draw tile background
        local bgAlpha = 1.0
        if i == self.selectedIndex then
            -- Highlight selected tile
            self:drawRect(x - 2, y - 2, self.tileWidth + 4, self.tileHeight + 4,
                         self.selectedColor.a, self.selectedColor.r,
                         self.selectedColor.g, self.selectedColor.b)
        end
        
        local tileBgR, tileBgG, tileBgB = 0, 0, 0
        if TileEditorMain.instance and TileEditorMain.instance.lightMode then
            tileBgR, tileBgG, tileBgB = 1,1,1
        end
        self:drawRect(x, y, self.tileWidth, self.tileHeight, bgAlpha, tileBgR, tileBgG, tileBgB)
        
        -- Draw tile sprite
        local texture = getTexture(spriteName)
        if texture then
            self:drawTextureScaledAspect(texture, x, y, self.tileWidth, self.tileHeight,
                                        1.0, 1.0, 1.0, 1.0)
        else
            -- Draw error indicator
            self:drawText("?", x + self.tileWidth / 2 - 5, y + self.tileHeight / 2 - 10,
                         1.0, 0.0, 0.0, 1.0, UIFont.Large)
        end
        
        -- Draw index number
        if i == self.singleIndex then
            -- Mark single tile (used in Single mode)
            local r, g, b = 1.0, 1.0, 0.0
            if TileEditorMain.instance and TileEditorMain.instance.lightMode then
                r, g, b = 0.5, 0.5, 0.0
            end
            self:drawText("Single", x + 2, y + 2, r, g, b, 1.0, UIFont.Small)
        end

        -- Draw Next indicator if in Cycle mode
        if TileEditorMain.instance and TileEditorMain.instance.mode == "cycle" then
             if i == TileEditorMain.instance.cycleIndex then
                local r, g, b = 0.0, 1.0, 1.0
                if TileEditorMain.instance.lightMode then
                    r, g, b = 0.0, 0.5, 0.5
                end
                self:drawText("Next", x + 2, y + self.tileHeight - 14, r, g, b, 1.0, UIFont.Small)
             end
        end
    end
    
    -- Show cursor preview when hovering over palette with active cursor
    local cursor = getCell():getDrag(0)
    if cursor ~= nil and cursor.choosenSprite then
        local mouseX = self:getMouseX()
        local mouseY = self:getMouseY()
        
        if mouseX >= 0 and mouseX < self.width and mouseY >= 0 and mouseY < self.height then
            local hover_c = math.floor((mouseX - self.padding) / (self.tileWidth + self.padding))
            
            if hover_c >= 0 and hover_c < self.tilesPerRow then
                local hoverX = self.padding + hover_c * (self.tileWidth + self.padding)
                local hoverY = self.padding
                
                local hoverIndex = self.currentRow * self.tilesPerRow + hover_c + 1
                local isExistingTile = hoverIndex >= 1 and hoverIndex <= #self.tiles
                
                if not isExistingTile or isCtrlKeyDown() then
                    -- Draw preview of tile that will be added/replaced
                    local texture = getTexture(cursor.choosenSprite)
                    if texture then
                        self:drawTextureScaledAspect(texture, hoverX, hoverY,
                                                    self.tileWidth, self.tileHeight,
                                                    0.6, 1.0, 1.0, 1.0)
                    end
                    
                    -- Draw green border to indicate it will be added/replaced
                    self:drawRectBorder(hoverX, hoverY, self.tileWidth, self.tileHeight,
                                       0.8, 0, 1, 0)
                else
                    -- Draw yellow border to indicate selection/pickup
                    self:drawRectBorder(hoverX, hoverY, self.tileWidth, self.tileHeight,
                                       0.8, 1, 1, 0)
                end
            end
        end
    end
    
    -- Draw scroll indicators if there are more rows
    local totalRows = self:getTotalRows()
    if totalRows > 1 then
        local indicatorSize = 12
        local indicatorX = self.width - indicatorSize - 4
        
        -- Up arrow indicator (if not at first row)
        if self.currentRow > 0 then
            self:drawText("^", indicatorX, 4,
                         self.scrollIndicatorColor.r, self.scrollIndicatorColor.g,
                         self.scrollIndicatorColor.b, self.scrollIndicatorColor.a, UIFont.Medium)
        end
        
        -- Down arrow indicator (if not at last row)
        if self.currentRow < totalRows - 1 then
            self:drawText("v", indicatorX, self.height - 16,
                         self.scrollIndicatorColor.r, self.scrollIndicatorColor.g,
                         self.scrollIndicatorColor.b, self.scrollIndicatorColor.a, UIFont.Medium)
        end
        
        -- Row indicator (e.g., "1/3")
        local rowText = (self.currentRow + 1) .. "/" .. totalRows
        local textWidth = getTextManager():MeasureStringX(UIFont.Small, rowText)
        local r, g, b = 0.7, 0.7, 0.7
        if TileEditorMain.instance and TileEditorMain.instance.lightMode then
            r, g, b = 0, 0, 0
        end
        self:drawText(rowText, self.width - textWidth - 4, self.height / 2 - 6,
                     r, g, b, 1.0, UIFont.Small)
    end
end

-- ============================================================================
-- Mouse Handling
-- ============================================================================

function TileEditorPalette:onMouseDown(x, y)
    -- Calculate which column was clicked in the current row
    local tileX = math.floor((x - self.padding) / (self.tileWidth + self.padding))
    local index = self.currentRow * self.tilesPerRow + tileX + 1
    
    -- Check if we have an active building cursor
    local cursor = getCell():getDrag(0)
    if cursor ~= nil and cursor.choosenSprite then
        local spriteName = cursor.choosenSprite
        
        -- Validate sprite name
        if type(spriteName) == "string" and spriteName ~= "" then
            -- Add or replace tile at this position
            if index >= 1 and index <= #self.tiles then
                if isCtrlKeyDown() then
                    -- Replace existing tile
                    self.tiles[index] = spriteName
                    TileEditorUtils.debug("Replaced palette tile at index " .. index .. ": " .. spriteName)
                    -- Clear the cursor
                    getCell():setDrag(nil, 0)
                else
                    -- Switch cursor to the clicked tile
                    local clickedSprite = self.tiles[index]
                    if clickedSprite then
                        local player = getPlayer()
                        if player then
                            local newCursor = ISBrushToolTileCursor:new(clickedSprite, clickedSprite, player)
                            getCell():setDrag(newCursor, player:getPlayerNum())
                            TileEditorUtils.debug("Switched cursor to tile: " .. clickedSprite)
                        end
                    end
                end
            else
                -- Add new tile to the end (fill row first, then next row)
                table.insert(self.tiles, spriteName)
                TileEditorUtils.debug("Added palette tile at index " .. #self.tiles .. ": " .. spriteName)
                -- Clear the cursor
                getCell():setDrag(nil, 0)
            end
        end
        
        return true
    end
    
    -- No cursor active - handle normal click behavior
    if #self.tiles == 0 then
        return true
    end
    
    -- Left click: Create cursor for manual placement
    if index >= 1 and index <= #self.tiles then
        local spriteName = self.tiles[index]
        if spriteName then
            local player = getPlayer()
            if player then
                local cursor = ISBrushToolTileCursor:new(spriteName, spriteName, player)
                getCell():setDrag(cursor, player:getPlayerNum())
                TileEditorUtils.debug("Created cursor for tile: " .. spriteName)
            end
        end
    end
    
    return true
end

function TileEditorPalette:onRightMouseDown(x, y)
    if #self.tiles == 0 then
        return true
    end
    
    -- Calculate which column was clicked in the current row
    local tileX = math.floor((x - self.padding) / (self.tileWidth + self.padding))
    local index = self.currentRow * self.tilesPerRow + tileX + 1
    
    if index >= 1 and index <= #self.tiles then
        if isCtrlKeyDown() then
            -- Open picker and select tilesheet
            local spriteName = self.tiles[index]
            if spriteName and TileEditorMain.instance then
                -- Extract sheet name (e.g. "SheetName_01" -> "SheetName")
                -- Usually format is SheetName_Index
                local lastUnderscore = string.find(spriteName, "_[^_]*$")
                if lastUnderscore then
                    local sheetName = string.sub(spriteName, 1, lastUnderscore - 1)
                    TileEditorMain.instance:switchToPickerAndSelect(sheetName)
                end
            end
        else
            -- Right-click to remove
            self:removeTile(index)
            TileEditorUtils.debug("Removed tile at index " .. index)
        end
    end
    
    return true
end

function TileEditorPalette:onMouseWheel(del)
    -- Handle row-by-row scrolling
    local totalRows = self:getTotalRows()
    local maxRow = math.max(0, totalRows - 1)
    
    -- Scroll one row at a time
    if del > 0 then
        -- Scroll down (next row)
        self.currentRow = math.min(maxRow, self.currentRow + 1)
    else
        -- Scroll up (previous row)
        self.currentRow = math.max(0, self.currentRow - 1)
    end
    
    return true
end

function TileEditorPalette:setWidth(width)
    ISPanel.setWidth(self, width)
    self:calculateLayout()
end

function TileEditorPalette:setHeight(height)
    ISPanel.setHeight(self, height)
    self:calculateLayout()
end

-- ============================================================================
-- Serialization (for future save/load)
-- ============================================================================

--- Exports palette to a table
-- @return table Palette data
function TileEditorPalette:export()
    return {
        tiles = self.tiles
    }
end

--- Imports palette from a table
-- @param data Palette data
function TileEditorPalette:import(data)
    if not data or not data.tiles then
        return false
    end
    
    self:clearPalette()
    
    for _, spriteName in ipairs(data.tiles) do
        self:addTile(spriteName)
    end
    
    return true
end

-- ============================================================================
-- Save/Load to File
-- ============================================================================

local PALETTE_FILE = "TileEditorPalettes.txt"

--- Loads all saved palettes from disk
-- @return table Array of palette entries {name=string, tiles=table}
function TileEditorPalette.loadPalettesFromDisk()
    local palettes = {}
    
    local fileReaderObj = getFileReader(PALETTE_FILE, true)
    if not fileReaderObj then
        TileEditorUtils.debug("No palette file found, starting fresh")
        return palettes
    end
    
    local line = fileReaderObj:readLine()
    while line ~= nil do
        -- Parse format: "Name: tile1,tile2,tile3"
        local colonPos = string.find(line, ":")
        if colonPos then
            local name = string.sub(line, 1, colonPos - 1)
            local tilesStr = string.sub(line, colonPos + 2) -- Skip ": "
            
            local tiles = {}
            for tile in string.gmatch(tilesStr, "[^,]+") do
                table.insert(tiles, tile)
            end
            
            if name and #tiles > 0 then
                table.insert(palettes, {name = name, tiles = tiles})
                TileEditorUtils.debug("Loaded palette: " .. name .. " with " .. #tiles .. " tiles")
            end
        end
        line = fileReaderObj:readLine()
    end
    fileReaderObj:close()
    
    TileEditorUtils.debug("Loaded " .. #palettes .. " palettes from disk")
    return palettes
end

--- Saves all palettes to disk
-- @param palettes Array of palette entries {name=string, tiles=table}
function TileEditorPalette.savePalettesToDisk(palettes)
    local fileWriterObj = getFileWriter(PALETTE_FILE, true, false)
    
    -- Build the entire content as a single string
    local content = ""
    for _, palette in ipairs(palettes) do
        if palette.name and palette.tiles and #palette.tiles > 0 then
            local tilesStr = table.concat(palette.tiles, ",")
            local line = palette.name .. ": " .. tilesStr .. "\n"
            content = content .. line
        end
    end
    
    -- Write all content at once
    fileWriterObj:write(content)
    fileWriterObj:close()
    TileEditorUtils.debug("Saved " .. #palettes .. " palettes to disk")
end

--- Saves the current palette with a given name
-- @param name Palette name
-- @return boolean Success
function TileEditorPalette:savePalette(name)
    if not name or name == "" then
        TileEditorUtils.error("Cannot save palette: name is empty")
        return false
    end
    
    if #self.tiles == 0 then
        TileEditorUtils.error("Cannot save palette: no tiles in palette")
        return false
    end
    
    -- Load existing palettes
    local palettes = TileEditorPalette.loadPalettesFromDisk()
    
    -- Check if palette with this name already exists and replace it
    local found = false
    for i, palette in ipairs(palettes) do
        if palette.name == name then
            palette.tiles = {}
            for _, tile in ipairs(self.tiles) do
                table.insert(palette.tiles, tile)
            end
            found = true
            TileEditorUtils.debug("Replaced existing palette: " .. name)
            break
        end
    end
    
    -- If not found, add new palette
    if not found then
        table.insert(palettes, {name = name, tiles = self.tiles})
        TileEditorUtils.debug("Added new palette: " .. name)
    end
    
    -- Save all palettes back to disk
    TileEditorPalette.savePalettesToDisk(palettes)
    return true
end

--- Loads a palette by name
-- @param name Palette name
-- @return boolean Success
function TileEditorPalette:loadPalette(name)
    if not name or name == "" then
        TileEditorUtils.error("Cannot load palette: name is empty")
        return false
    end
    
    -- Load all palettes from disk
    local palettes = TileEditorPalette.loadPalettesFromDisk()
    
    -- Find the palette with the given name
    for _, palette in ipairs(palettes) do
        if palette.name == name then
            self:clearPalette()
            -- Directly assign tiles to preserve duplicates for ratio-based random selection
            for _, tile in ipairs(palette.tiles) do
                table.insert(self.tiles, tile)
            end
            TileEditorUtils.debug("Loaded palette: " .. name .. " with " .. #palette.tiles .. " tiles")
            return true
        end
    end
    
    TileEditorUtils.error("Palette not found: " .. name)
    return false
end

--- Deletes a saved palette by name
-- @param name Palette name
-- @return boolean Success
function TileEditorPalette.deleteSavedPalette(name)
    if not name or name == "" then
        return false
    end
    
    -- Load all palettes
    local palettes = TileEditorPalette.loadPalettesFromDisk()
    
    -- Remove the palette with the given name
    local found = false
    for i = #palettes, 1, -1 do
        if palettes[i].name == name then
            table.remove(palettes, i)
            found = true
            TileEditorUtils.debug("Deleted palette: " .. name)
            break
        end
    end
    
    if found then
        -- Save the updated list back to disk
        TileEditorPalette.savePalettesToDisk(palettes)
        return true
    end
    
    return false
end

--- Gets a list of all saved palette names
-- @return table Array of palette names
function TileEditorPalette.getSavedPaletteNames()
    local palettes = TileEditorPalette.loadPalettesFromDisk()
    local names = {}
    for _, palette in ipairs(palettes) do
        table.insert(names, palette.name)
    end
    return names
end

return TileEditorPalette