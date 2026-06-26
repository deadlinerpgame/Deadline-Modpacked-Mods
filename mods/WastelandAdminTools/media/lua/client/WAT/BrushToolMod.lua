function BrushToolTilePickerList:render()
    if not self.sprite_array then return end
    local maxRow = 1
    local tileWidth = 64
    local tileHeight = 128    
    ISPanel.render(self)

    local hover_c = math.floor(self:getMouseX() / tileWidth)
    local hover_r = math.floor(self:getMouseY() / tileHeight)

    local hotbarOverwritingCell = nil
    local holdingTile = nil

    if self.isHotbar then
        local cursor = getCell():getDrag(0)
        if cursor ~= nil then
            holdingTile = cursor.choosenSprite
        end

        if holdingTile and self.isHotbar and hover_r == 0 then
            hotbarOverwritingCell = hover_c
        end
    end        

    local r = 0
    local c = 0

    for i=0,self.sprite_array:size()-1 do
        local v = self.sprite_array:get(i)
        local tileName = v ~= 0 and v:getName()

        local texture = nil
        local opacity = 1.0
        if self.isHotbar and c == hotbarOverwritingCell then
            texture = type(holdingTile) == "string" and getTexture(holdingTile)
            opacity = 0.6
        else
            texture = type(tileName) == "string" and getTexture(tileName)
        end
        if texture and texture ~= 0 then
            self:drawTextureScaledAspect(texture, c * tileWidth, r * tileHeight, tileWidth, tileHeight, opacity, 1.0, 1.0, 1.0)
        end
        
        if c == (hover_c) and r == (hover_r) then
            if self.isHotbar and c == hotbarOverwritingCell then
                self:drawRectBorder(hover_c * tileWidth, hover_r * tileHeight, tileWidth, tileHeight, 0.6, 1, 0.6, 0)
            else
                self:drawRectBorder(hover_c * tileWidth, hover_r * tileHeight, tileWidth, tileHeight, 0.6, 1, 1, 1)
            end
        end

        maxRow = r+1
        c = (c + 1)%8
        if c == 0 then r = r + 1 end
    end
    self:setScrollHeight(maxRow * tileHeight)

    if self.isHotbar then 
        BrushToolHotbar.persistX = BrushToolHotbar.instance:getX()
        BrushToolHotbar.persistY = BrushToolHotbar.instance:getY()
    end
end

local function safe_getSprite(tileName)
    if type(tileName) == "string" and BrushToolChooseTileUI.sm_map:containsKey(tileName) then
        return BrushToolChooseTileUI.sm_map:get(tileName)
    else return 0 end
end

local function fetchField(o, patt)
    for i = 0, getNumClassFields(o) - 1 do
        local f = getClassField(o, i)
        if string.find(tostring(f), patt) then
            return getClassFieldVal(o, f)
        end
    end
end


function BrushToolTilePickerList:onMouseDown(x, y)
    local c = math.floor(x / 64)
    local r = math.floor(y / 128)
    local cursor = getCell():getDrag(0)
    if self.isHotbar and r == 0 and c < 8 then
        if cursor ~= nil then
            if type(cursor.choosenSprite) ~= "string" then
                getCell():setDrag(nil, getPlayer())
                cursor = nil
                return
            end 
            if BrushToolChooseTileUI.sm_map:containsKey(cursor.choosenSprite) then
                self.sprite_array:set(c, BrushToolChooseTileUI.sm_map:get(cursor.choosenSprite))
                BrushToolHotbar:PersistState()
            end
            return
        end
    end
    local i = (r*8)+c
    if c >= 0 and c < 8 and r >= 0 then
        if i < self.sprite_array:size() then
            local sprite = self.sprite_array:get(i)
            local spriteName = sprite ~= 0 and self.sprite_array:get(i):getName()
            if spriteName then
                local cursor = ISBrushToolTileCursor:new(spriteName, spriteName, self.character)
                getCell():setDrag(cursor, self.character:getPlayerNum())
            end
        end
    end
end

function BrushToolTilePickerList:onRightMouseDown(x, y)
    local c = math.floor(x / 64)
    local r = math.floor(y / 128)
    local i = (r*8)+c
    if self.isHotbar and r == 0 and c < 8 and self.sprite_array then
        local sprite = self.sprite_array:get(i)
        if sprite ~= 0 then
            local spritesheet, tileIndex = sprite:getName():match("(.+)_(.+)$")
            tileIndex = tonumber(tileIndex)
            if not BrushToolChooseTileUI.instance then
                BrushToolChooseTileUI.openPanel(100, 100, self.character)
            end
            BrushToolChooseTileUI:generateSpriteArray(spritesheet)
            if BrushToolChooseTileUI.instance.isCollapsed then
                BrushToolChooseTileUI.instance.isCollapsed = false;
                BrushToolChooseTileUI.instance:clearMaxDrawHeight();
                BrushToolChooseTileUI.instance.collapseCounter = -10;
            end
        end
    end
end

BrushToolHotbar = ISCollapsableWindow:derive("BrushToolHotbar");
humanNameTable = nil
BrushToolChooseTileUI.advSearchEnabled = false
BrushToolHotbar.instance = nil

local original_BrushToolChooseTileUI_openPanel = BrushToolChooseTileUI.openPanel
function BrushToolChooseTileUI.openPanel(x, y, playerObj)
    if BrushToolChooseTileUI.instance == nil then
        BrushToolChooseTileUI.sprite_manager = getSpriteManager("")
        BrushToolChooseTileUI.sm_instance = fetchField(BrushToolChooseTileUI.sprite_manager, "instance")
        BrushToolChooseTileUI.sm_map = fetchField(BrushToolChooseTileUI.sm_instance, "NamedMap")
        BrushToolChooseTileUI.playerObj = playerObj
    end
    BrushToolHotbar:LoadState()
    original_BrushToolChooseTileUI_openPanel(x, y, playerObj)
end

function BrushToolHotbar:createChildren()
    ISCollapsableWindow.createChildren(self)

    local th = self:titleBarHeight()

    self.tilesList = BrushToolTilePickerList:new(0, th, self:getWidth(), self:getHeight() - th, self.character)
    self.tilesList.anchorBottom = true;
    self.tilesList.isHotbar = true
    self.tilesList.sprite_array = BrushToolHotbar.persistList
    self.tilesList:initialise();
    self.tilesList:instantiate();
    self:addChild(self.tilesList);
end

function BrushToolHotbar:onMainUIClick()
    if BrushToolHotbar.instance == nil then
        local window = BrushToolHotbar:new(BrushToolHotbar.persistX, BrushToolHotbar.persistY, 522, 128, self.playerObj)
        window:initialise()
        window:addToUIManager()
        BrushToolHotbar.instance = window
    end
end

local humanNameTable = {}

function BrushToolChooseTileUI:onAdvSearchToggled(index, selected)
    if selected then
        BrushToolChooseTileUI.advSearchEnabled = true

        local count = 0
        for k,v in pairs(transformIntoKahluaTable(BrushToolChooseTileUI.sm_map)) do
            local props = v:getProperties();
            local groupName	= props:Is("GroupName") and props:Val("GroupName") or nil;
            local fullName = (groupName and (groupName .. " ") or "") .. (props:Is("CustomName") and props:Val("CustomName") or "");
            if fullName ~= "" then
                if not humanNameTable[fullName] then humanNameTable[fullName] = ArrayList:new() end
                humanNameTable[fullName]:add(v)
            end
        end    
        self:populateList()
    else
        BrushToolChooseTileUI.advSearchEnabled = false
        humanNameTable = {}
        self:populateList()
    end
end

local original_BrushToolChooseTileUI_createChildren = BrushToolChooseTileUI.createChildren
function BrushToolChooseTileUI:createChildren()
    original_BrushToolChooseTileUI_createChildren(self)

    self.tilesList.sprite_array = ArrayList:new()

    local th = self:titleBarHeight()
    self.tickBox = ISTickBox:new(170, th, 50, 20, "", self, BrushToolChooseTileUI.onAdvSearchToggled)
    self.tickBox.tooltip = "Enable searching through names of moveables that have them when picked up. For example, 'green', 'crate', 'tool'."
    self.tickBox:initialise()
    self.tickBox:addOption("Adv.", true)
    self.tickBox:setSelected(1, BrushToolChooseTileUI.advSearchEnabled)
    self:addChild(self.tickBox)


    self.hotbarButton = ISButton:new(220, th, 40, th+4, "HOTBAR", self, BrushToolHotbar.onMainUIClick)
    self.hotbarButton.tooltip = "Right-clicking on tiles on the hotbar will open the spritesheet they belong to. \n Tiles copied from the world can be placed on the hotbar. \n Using '[' and ']' keys to \"rotate\" works for tiles picked from the hotbar too."
    self.hotbarButton:initialise()
	self:addChild(self.hotbarButton)
end

local function instantCollapse(w)
    if((w:getMouseX() < 0 or w:getMouseY() < 0 or w:getMouseX() > w:getWidth() or w:getMouseY() > w:getHeight()) and  not w.pin) then
        w.isCollapsed = true;
        w:setMaxDrawHeight(w:titleBarHeight());
    end
end

function BrushToolChooseTileUI:onMouseDownOutside(x, y)
    instantCollapse(self)
end

function BrushToolHotbar:onMouseDownOutside(x, y)
    instantCollapse(self)
end

function BrushToolChooseTileUI:generateSpriteArray(spritesheet)
    self.instance.tilesList.sprite_array:clear()
    if spritesheet == '[search_results]' then
        local search_text = self.instance.searchEntryBox:getInternalText()
        if string.len(search_text) < 3 then return end
        for k, v in pairs(humanNameTable) do
            if string.contains(string.lower(k), string.lower(search_text)) then
                for i=0,v:size()-1 do
                    self.instance.tilesList.sprite_array:add(v:get(i))
                end
            end
        end
    else
        for r = 1, 256 do
            for c = 1, 8 do
                local tileName = spritesheet .. "_" .. tostring((c-1) + (r-1)*8)
                if BrushToolChooseTileUI.sm_map:containsKey(tileName) then
                    if getTexture(tileName) then
                        self.instance.tilesList.sprite_array:add(BrushToolChooseTileUI.sm_map:get(tileName))
                    else
                        self.instance.tilesList.sprite_array:add(0)
                    end
                end
            end
        end
    end
end

local original_BrushToolChooseTileUI_onSelectImage = BrushToolChooseTileUI.onSelectImage
function BrushToolChooseTileUI.onSelectImage(_, item)
    BrushToolChooseTileUI:generateSpriteArray(item)
end

local original_BrushToolChooseTileUI_populateList = BrushToolChooseTileUI.populateList
function BrushToolChooseTileUI:populateList()
    original_BrushToolChooseTileUI_populateList(self)
    local searchText = self.searchEntryBox:getInternalText()
    if BrushToolChooseTileUI.advSearchEnabled and string.len(searchText) > 2 then
        self.imageList:insertItem(1, "[IN-GAME NAMES SEARCH RESULTS]", "[search_results]");
    end
    if #self.imageList.items ~= 0 and self.tilesList.sprite_array then
        BrushToolChooseTileUI:generateSpriteArray(self.imageList.items[self.imageList.selected].item)
    end
end

function BrushToolHotbar:close()
    BrushToolHotbar.instance = nil
    self:setVisible(false);
    self:removeFromUIManager();
end

function BrushToolHotbar:new(x, y, width, height, character)
    local o = ISCollapsableWindow.new(self, x, y, width, height);
    o:setResizable(false)
    o.title = "Brush Tool Hotbar"
    o.character = character
    return o;
end

function BrushToolHotbar:LoadState()
    if BrushToolHotbar.persistX == nil or BrushToolHotbar.persistY == nil then
        BrushToolHotbar.persistX = 0
        BrushToolHotbar.persistY = 0
    end
    if BrushToolHotbar.persistList == nil then 
        BrushToolHotbar.persistList = ArrayList:new() 
        for i=0,7 do BrushToolHotbar.persistList:add(0) end
        local player = getPlayer()
        local modData = player:getModData()
        if modData.brushToolHotbar == nil then modData.brushToolHotbar = {} end
        if modData.brushToolHotbar.x ~= nil then BrushToolHotbar.persistX = modData.brushToolHotbar.x end
        if modData.brushToolHotbar.y ~= nil then BrushToolHotbar.persistY = modData.brushToolHotbar.y end
        if modData.brushToolHotbar.slots == nil then 
            modData.brushToolHotbar.slots = {}
            for i=1,8 do
                modData.brushToolHotbar.slots[i] = 0
            end
        end
        for i=1,#modData.brushToolHotbar.slots do
            if i <= 8 then
                BrushToolHotbar.persistList:set(i-1, safe_getSprite(modData.brushToolHotbar.slots[i]))
            end
        end
    end
end



function BrushToolHotbar:PersistState() 
    local player = getPlayer()
    local modData = player:getModData()
    if modData.brushToolHotbar == nil then modData.brushToolHotbar = {} end
    modData.brushToolHotbar.x = BrushToolHotbar.persistX
    modData.brushToolHotbar.y = BrushToolHotbar.persistY
    if modData.brushToolHotbar.slots == nil then 
        modData.brushToolHotbar.slots = {}
        for i=1,8 do table.insert(0) end
    end
    for i=0,7 do
        local sprite = BrushToolHotbar.persistList:get(i)
        if sprite ~= 0 then
            modData.brushToolHotbar.slots[i+1] = sprite:getName()
        else 
            modData.brushToolHotbar.slots[i+1] = 0
        end
    end
end