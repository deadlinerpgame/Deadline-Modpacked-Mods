---
--- WAT_LuaReloader.lua
--- 18/04/2025
---

require "GravyUI"
require "ISUI/ISCollapsableWindow"

WLR_LuaReloader = ISCollapsableWindow:derive("WLR_LuaReloader")
WLR_LuaReloader.instance = nil

function WLR_LuaReloader.display()
    if WLR_LuaReloader.instance then return end
    WLR_LuaReloader.instance = WLR_LuaReloader:new()
    WLR_LuaReloader.instance:addToUIManager()
end

function WLR_LuaReloader:new()
    local scale = getTextManager():getFontHeight(UIFont.Small) / 14
    local w = 400 * scale
    local h = 500 * scale
    local md = getPlayer():getModData()
    local x = md.WLR_LuaReloaderX or getCore():getScreenWidth()/2 - w/2
    local y = md.WLR_LuaReloaderY or getCore():getScreenHeight()/2 - h/2
    local o = ISCollapsableWindow:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o:initialise()
    return o
end

function WLR_LuaReloader:initialise()
    self.moveWithMouse = true
    self.resizable = false

    self.availableFiles = {}
    self.filteredFiles = {}
    self.favourites = {}

    local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

    local win = GravyUI.Node(self.width, self.height, self):pad(5, 15, 5, 5)
    local buffer, header, fav1, fav2, fav3, fav4, fav5, searchRow, listRow =
        win:rows({5, 20, 30, 30, 30, 30, 30, 20, 1}, 5)

    local headerBuffer, headerLbl, debugBtn = header:cols({0.2, 0.6, 0.2}, 5)
    headerLbl:makeLabel("Lua Reloader", UIFont.Medium, nil, "center")
    debugBtn:makeButton("Errors", self, function()
        if not self.errorsWindow then
            self.errorsWindow = DebugErrorsWindow:new(self:getX() - 610, self:getY(), 600, 400)
            self.errorsWindow:initialise()
            self.errorsWindow:addToUIManager()
        else
            self.errorsWindow:removeFromUIManager()
            self.errorsWindow = nil
        end
    end)
    local searchFieldCol, toggleBtnCol = searchRow:cols({0.8, 0.2}, 5)

    local md = getPlayer():getModData()
    local lastSearch = md.WLR_LastSearch or ""

    self.searchFieldCol = searchRow:makeTextBox(lastSearch, false)
    self.searchText = lastSearch
    self.lastSearch = lastSearch
    self.searchFieldCol.onTextChange = function() self:onSearchTextChanged() end

    self.scrollList = listRow:makeScrollingListBox(UIFont.Small)
    self.scrollList:clear()
    self.scrollList:setOnMouseDownFunction(self, function(target, item)
        local row = self.scrollList.selected
        if row and row > 0 then
            self:updateButtons(row)
        else
            self.hoverReloadBtn:setVisible(false)
            self.hoverFavBtn:setVisible(false)
        end
    end)

    self.searchEnabled = true
    self.baseHeight = self.height
    self.toggleSearchBtn = toggleBtnCol:makeButton("Hide", self, function()
        self.searchEnabled = not self.searchEnabled
        self.scrollList:setVisible(self.searchEnabled)
        self.scrollList:setEnabled(self.searchEnabled)
        self.toggleSearchBtn:setTitle(self.searchEnabled and "Hide" or "Show")
    
        if self.searchEnabled then
            self:filterFileList(self.searchFieldCol:getInternalText() or "")
            self:setHeight(self.baseHeight)
        else
            self.scrollList:clear()
            self:setHeight(self.baseHeight - self.scrollList:getHeight()-5)
        end
    end)

    self.hoverReloadBtn = ISButton:new(0, 0, 60, FONT_HGT_SMALL, "Reload", self, self.onHoverReload)
    self.hoverReloadBtn:initialise()
    self.hoverReloadBtn:setVisible(false)
    self.scrollList:addChild(self.hoverReloadBtn)

    self.hoverFavBtn = ISButton:new(0, 0, 70, FONT_HGT_SMALL, "Favourite", self, self.onHoverFavourite)
    self.hoverFavBtn:initialise()
    self.hoverFavBtn:setVisible(false)
    self.scrollList:addChild(self.hoverFavBtn)

    self.scrollList.doRepaintStencil = true

    self.favSlots = {fav1, fav2, fav3, fav4, fav5}
    self.favData = {}

    for i, row in ipairs(self.favSlots) do
        local nameLbl, reloadBtn, removeBtn = row:cols({0.6, 0.2, 0.2}, 5)
        self.favData[i] = {name = nil, path = nil}

        nameLbl = nameLbl:makeLabel("Empty", UIFont.Small, nil, "center", true)
        nameLbl:setY(nameLbl:getY() + math.floor((row.height - FONT_HGT_SMALL) / 2))
        reloadBtn:makeButton("Reload", self, function() self:onReloadFavourite(i) end)
        removeBtn:makeButton("Remove", self, function() self:onRemoveFavourite(i) end)

        self.favData[i].lbl = nameLbl
    end

    self.hoverRowIndex = -1

    self.availableFiles = self:getLuaFileList()
    self:filterFileList(lastSearch)
    self:loadFavourites()
end

function WLR_LuaReloader:refreshFileList()
    self.availableFiles = self:getLuaFileList()
    self:filterFileList("")
end

function WLR_LuaReloader:filterFileList(text)
    self.scrollList:clear()
    self.filteredFiles = {}
    text = text:lower()

    for _, file in ipairs(self.availableFiles) do
        if file.name:lower():find(text, 1, true) then
            table.insert(self.filteredFiles, file)

            self.scrollList:addItem(file.name, file)
        end
    end
end

function WLR_LuaReloader:getLuaFileList()
    local files = {}
    local count = getLoadedLuaCount()

    for i = 0, count - 1 do
        local path = getLoadedLua(i)
        if path and path:find("media") then
            local name
            local startIdx = path:find("/lua/") or path:find("\\lua\\")
            name = startIdx and path:sub(startIdx + 5) or path
            table.insert(files, { name = name, path = path })
        end
    end

    table.sort(files, function(a, b) return a.name < b.name end)
    return files
end

function WLR_LuaReloader:onSearchTextChanged()
    if not self.searchEnabled then return end
    local current = self.searchFieldCol:getInternalText() or ""
    if current ~= self.lastSearch then
        self.lastSearch = current
        getPlayer():getModData().WLR_LastSearch = current
        self:filterFileList(current)
    end
end

function WLR_LuaReloader:updateButtons(row)
    local item = self.scrollList.items[row]
    if not item then return end

    local itemY = self.scrollList:topOfItem(row) + 2
    self.hoverReloadBtn:setX(self.scrollList:getWidth() - self.hoverReloadBtn.width - 100)
    self.hoverReloadBtn:setY(itemY + self.scrollList:getYScroll())
    self.hoverReloadBtn:setVisible(true)

    self.hoverFavBtn:setX(self.scrollList:getWidth() - self.hoverFavBtn.width - 20)
    self.hoverFavBtn:setY(itemY + self.scrollList:getYScroll())
    self.hoverFavBtn:setVisible(true)

    self.hoveredFile = item.item
    self.hoverRowIndex = row
end

function WLR_LuaReloader:onHoverReload()
    if self.hoveredFile then
        self:reloadLua(self.hoveredFile.name, self.hoveredFile.path)
    end
end

function WLR_LuaReloader:onHoverFavourite()
    if self.hoveredFile then
        self:addToFavourites(self.hoveredFile)
    end
end

function WLR_LuaReloader:reloadLua(name, path)
    if type(reloadLuaFile) == "function" then
        reloadLuaFile(path)
        print("[WLR] Reloaded: " .. name)
    else
        print("[WLR] reloadLuaFile is not available. Are you in debug mode?")
    end
end

function WLR_LuaReloader:addToFavourites(file)
    for i = 1, #self.favData do
        if not self.favData[i].name then
            self.favData[i].name = file.name
            self.favData[i].path = file.path
            self.favData[i].lbl:setText(file.name)
            self:saveFavourites()
            return
        end
    end
    print("[WLR] Favourite slots full. Please remove one before adding.")
end

function WLR_LuaReloader:onReloadFavourite(i)
    local fav = self.favData[i]
    if fav and fav.path then
        self:reloadLua(fav.name, fav.path)
    end
end

function WLR_LuaReloader:onRemoveFavourite(i)
    local fav = self.favData[i]
    fav.name = nil
    fav.path = nil
    fav.lbl:setText("Empty")
    self:saveFavourites()
end

function WLR_LuaReloader:saveFavourites()
    local data = getPlayer():getModData()
    data.wlrFavourites = {}
    for i, fav in ipairs(self.favData) do
        data.wlrFavourites[i] = {
            name = fav.name,
            path = fav.path
        }
    end
end

function WLR_LuaReloader:loadFavourites()
    local data = getPlayer():getModData()
    local favs = data.wlrFavourites or {}

    for i, fav in ipairs(favs) do
        if fav.name and fav.path then
            self.favData[i].name = fav.name
            self.favData[i].path = fav.path
            self.favData[i].lbl:setText(fav.name)
        end
    end
end

function WLR_LuaReloader:close()
    self:saveFavourites()
    local md = getPlayer():getModData()
    md.WLR_LuaReloaderX = self:getX()
    md.WLR_LuaReloaderY = self:getY()
    md.WLR_LastSearch = self.searchFieldCol:getInternalText() or ""
    WLR_LuaReloader.instance = nil
    ISCollapsableWindow.close(self)
end
