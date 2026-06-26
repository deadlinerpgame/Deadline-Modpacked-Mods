require "GravyUI"
local TSP = require("WL_TSP")

local tickTimeout = 5
local function tickRunner()
    if not WAT_SafehouseAudit.instance then return end
    if tickTimeout > 0 then
        tickTimeout = tickTimeout - 1
        return
    end
    WAT_SafehouseAudit.instance:onTick()
    tickTimeout = 5
end

WAT_SafehouseAudit = WAT_SafehouseAudit or ISPanelJoypad:derive("WAT_SafehouseAudit")
WAT_SafehouseAudit.instance = WAT_SafehouseAudit.instance or nil

function WAT_SafehouseAudit.display()
    if WAT_SafehouseAudit.instance == nil then
        WAT_SafehouseAudit.instance = WAT_SafehouseAudit:new()
        WAT_SafehouseAudit.instance:initialise()
    end
    WAT_SafehouseAudit.instance:addToUIManager()
    WAT_SafehouseAudit.instance:setVisible(true)
    WAT_SafehouseAudit.instance:bringToTop()
    WAT_SafehouseAudit.instance:populateList()
end

function WAT_SafehouseAudit:new()
    local o = {}
    local width = 500
    local height = 400
    local cx = getCore():getScreenWidth() / 2
    local cy = getCore():getScreenHeight() / 2
    o = ISPanelJoypad:new(cx - width / 2, cy - height / 2, width, height)
    setmetatable(o, self)
    self.__index = self
    return o
end

-- Helper accessors to normalize WSZ safehouse-like objects to x1,y1,x2,y2
local function SH_getX1(sh) return sh.getX and sh:getX() or sh:getX1() end
local function SH_getY1(sh) return sh.getY and sh:getY() or sh:getY1() end
local function SH_getX2(sh)
    if sh.getX2 then return sh:getX2() end
    -- Treat W as width (number of tiles). Convert to inclusive x2.
    local x1 = SH_getX1(sh)
    local w  = (sh.getW and sh:getW()) or ((sh.getX2 and (sh:getX2() - x1)) or 0)
    if w <= 0 then return x1 end
    return x1 + w - 1
end
local function SH_getY2(sh)
    if sh.getY2 then return sh:getY2() end
    local y1 = SH_getY1(sh)
    local h  = (sh.getH and sh:getH()) or ((sh.getY2 and (sh:getY2() - y1)) or 0)
    if h <= 0 then return y1 end
    return y1 + h - 1
end

function WAT_SafehouseAudit:initialise()
    self:setAlwaysOnTop(true)
    self.moveWithMouse = true
    self.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self.backgroundColor = {r=0, g=0, b=0, a=1}

    local window = GravyUI.Node(self.width, self.height):pad(2)
    local title, lb, btns = window:rows({16, 1, 20}, 3)
    local startButton, stopButton, closeButton = btns:cols(3, 5)

    self.titleSlot = title

    self.listbox = ISScrollingListBox:new(lb.left, lb.top, lb.width, lb.height)
    self.listbox:initialise()
    self.listbox.itemheight = 20
    self.listbox.selected = 0
    self.listbox.joypadParent = self
    self.listbox.font = UIFont.NewSmall
    self.listbox.drawBorder = true
    self.listbox:setOnMouseDoubleClick(self, self.onDblClick)
    self:addChild(self.listbox)

    self.startButton = startButton:makeButton("Start", self, self.start)
    self.stopButton  = stopButton:makeButton("Stop", self, self.stop)
    self.closeButton = closeButton:makeButton("Close", self, self.close)

    self:addChild(self.startButton)
    self:addChild(self.stopButton)
    self:addChild(self.closeButton)
end

function WAT_SafehouseAudit:populateList()
    self.listbox:clear()

    local safehouses = WSZ_System.getSafehouseList()

    local all = {}
    for i = 0, safehouses:size() - 1 do
        local sh = safehouses:get(i)
        table.insert(all, { x = SH_getX1(sh), y = SH_getY1(sh), sh = sh })
    end

    local sorted = TSP.NearestNeighbor(all)
    for _, data in ipairs(sorted) do
        local owner = (data.sh.getOwner and data.sh:getOwner()) or "unknown"
        local title = (data.sh.getTitle and data.sh:getTitle()) or "Safehouse"
        local name = tostring(data.x).."x"..tostring(data.y) .. " - " .. title .. " - " .. owner
        self.listbox:addItem(name, data.sh)
    end
end

function WAT_SafehouseAudit:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre("Safehouse Audit", self.titleSlot.left + self.titleSlot.width / 2, self.titleSlot.top, 1, 1, 1, 1, UIFont.Large)
end

function WAT_SafehouseAudit:start()
    if self.running then return end
    self.running = true
    self.currentIdx = 1
    self.currentTask = "tp"
    self.currentSh = self.listbox.items[self.currentIdx].item
    Events.OnTick.Add(tickRunner)
    WL_Utils.addInfoToChat("Safehouse audit started")
end

function WAT_SafehouseAudit:stop()
    self.running = false
    Events.OnTick.Remove(tickRunner)
    WL_Utils.addInfoToChat("Safehouse audit stopped")
end

function WAT_SafehouseAudit:close()
    self:stop()
    self:removeFromUIManager()
    WAT_SafehouseAudit.instance = nil
end

function WAT_SafehouseAudit:onTick()
    if not self.running then return end

    if self.currentTask == "tp" then
        self.listbox.selected = self.currentIdx
        self.listbox:ensureVisible(self.currentIdx)

        local x1, y1 = SH_getX1(self.currentSh), SH_getY1(self.currentSh)
        local x2, y2 = SH_getX2(self.currentSh), SH_getY2(self.currentSh)

        local x = x1 + math.floor((x2 - x1) / 2)
        local y = y1 + math.floor((y2 - y1) / 2)

        local player = getPlayer()
        WL_Utils.teleportPlayerToCoords(player, x, y, 0)
        self.currentTask = "waitLoad"
        WL_Utils.addInfoToChat("Loading safehouse: " ..
            ((self.currentSh.getTitle and self.currentSh:getTitle()) or "Safehouse") ..
            " (" .. ((self.currentSh.getOwner and self.currentSh:getOwner()) or "unknown") .. ")")
        self.loadCheckCounter = 0

    elseif self.currentTask == "waitLoad" then
        if self:checkLoaded() then
            WL_Utils.addInfoToChat("Loaded safehouse: " ..
                ((self.currentSh.getTitle and self.currentSh:getTitle()) or "Safehouse") ..
                " (" .. ((self.currentSh.getOwner and self.currentSh:getOwner()) or "unknown") .. ")")
            self.currentTask = "runAudit"
            return
        end
        self.loadCheckCounter = self.loadCheckCounter + 1
        if self.loadCheckCounter > 5000 then
            WL_Utils.addInfoToChat("Failed to load safehouse: " ..
                ((self.currentSh.getTitle and self.currentSh:getTitle()) or "Safehouse") ..
                " (" .. ((self.currentSh.getOwner and self.currentSh:getOwner()) or "unknown") .. ")")
            self.currentTask = "runAudit"
        end

    elseif self.currentTask == "runAudit" then
        WL_Utils.addInfoToChat("Auditing safehouse: " ..
            ((self.currentSh.getTitle and self.currentSh:getTitle()) or "Safehouse") ..
            " (" .. ((self.currentSh.getOwner and self.currentSh:getOwner()) or "unknown") .. ")")
        self:auditSafehouse()
        self.currentIdx = self.currentIdx + 1
        if self.currentIdx > #self.listbox.items then
            self:stop()
        else
            self.currentSh = self.listbox.items[self.currentIdx].item
            self.currentTask = "tp"
        end
    end
end

function WAT_SafehouseAudit:checkLoaded()
    local x1, y1 = SH_getX1(self.currentSh), SH_getY1(self.currentSh)
    local x2, y2 = SH_getX2(self.currentSh), SH_getY2(self.currentSh)

    for x = x1, x2 do
        for y = y1, y2 do
            local sq = getCell():getGridSquare(x, y, 0)
            if not sq then return false end
        end
    end
    return true
end

local cleanData = function(data)
    data = tostring(data)
    data = string.gsub(data, "\n", "")
    data = string.gsub(data, "\r", "")
    data = string.gsub(data, ",", "")
    return data
end

local filenameClean = function(data)
    data = tostring(data)
    -- remove all non-letters, numbers, and spaces
    data = string.gsub(data, "[^%w%s]", "")
    return data
end

function WAT_SafehouseAudit:auditSafehouse()
    local items = {}
    local itemsOnGround = {}

    local x1, y1 = SH_getX1(self.currentSh), SH_getY1(self.currentSh)
    local x2, y2 = SH_getX2(self.currentSh), SH_getY2(self.currentSh)

    for x = x1, x2 do
        for y = y1, y2 do
            for z = 0, 7 do
                local sq = getCell():getGridSquare(x, y, z)
                if sq then
                    local itemsHere = WL_Utils.scanGridSquare(sq)
                    for _, foundItem in ipairs(itemsHere) do
                        local item = foundItem.item
                        local itemId = item:getFullType()
                        if not items[itemId] then
                            local itemCat = cleanData(item:getCategory())
                            local displayCat = cleanData(item:getDisplayCategory())
                            local itemName = cleanData(item:getName())
                            local itemDisplayName = cleanData(item:getDisplayName())
                            items[itemId] = {count=0, cat=itemCat, displayCat=displayCat, name=itemName, displayName=itemDisplayName}
                        end
                        items[itemId].count = items[itemId].count + 1
                        if foundItem.foundAt == "ground" then
                            itemsOnGround[itemId] = (itemsOnGround[itemId] or 0) + 1
                        end
                    end
                end
            end
        end
    end

    local owner = (self.currentSh.getOwner and self.currentSh:getOwner()) or "unknown"
    local title = (self.currentSh.getTitle and self.currentSh:getTitle()) or "Safehouse"
    local name = SH_getX1(self.currentSh).."x"..SH_getY1(self.currentSh) .. " - " .. filenameClean(title) .. " - " .. owner .. ".csv"

    local fileWriter = getFileWriter("SafehouseAudits/overall-" .. name, true, false)
    fileWriter:writeln("ItemId,Category,Display Category,Name,Display Name,Count")
    for k,v in pairs(items) do
        fileWriter:writeln(k ..","..v.cat..","..v.displayCat..","..v.name..","..v.displayName..","..v.count)
    end
    fileWriter:close()

    fileWriter = getFileWriter("SafehouseAudits/ground-" .. name, true, false)
    fileWriter:writeln("ItemId,Count")
    for k,v in pairs(itemsOnGround) do
        fileWriter:writeln(k ..","..v)
    end
    fileWriter:close()
end
