require "GravyUI"
local TSP = require("WL_TSP")

local tickTimeout = 5
local function tickRunner()
    if not WAT_WorkplaceAudit.instance then
        return
    end
    if tickTimeout > 0 then
        tickTimeout = tickTimeout - 1
        return
    end
    WAT_WorkplaceAudit.instance:onTick()
    tickTimeout = 5
end

WAT_WorkplaceAudit = WAT_WorkplaceAudit or ISPanelJoypad:derive("WAT_WorkplaceAudit")
WAT_WorkplaceAudit.instance = WAT_WorkplaceAudit.instance or nil

function WAT_WorkplaceAudit.display()
    if WAT_WorkplaceAudit.instance == nil then
        WAT_WorkplaceAudit.instance = WAT_WorkplaceAudit:new()
        WAT_WorkplaceAudit.instance:initialise()
    end
    WAT_WorkplaceAudit.instance:addToUIManager()
    WAT_WorkplaceAudit.instance:setVisible(true)
    WAT_WorkplaceAudit.instance:bringToTop()
    WAT_WorkplaceAudit.instance:populateList()
end

function WAT_WorkplaceAudit:new()
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


function WAT_WorkplaceAudit:initialise()
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
    self.stopButton = stopButton:makeButton("Stop", self, self.stop)
    self.closeButton = closeButton:makeButton("Close", self, self.close)

    self:addChild(self.startButton)
    self:addChild(self.stopButton)
    self:addChild(self.closeButton)
end

function WAT_WorkplaceAudit:populateList()
    self.listbox:clear()
    local workplaces = WWP_WorkplaceZone.getAllZones()
    local all = {}
    for _, wp in pairs(workplaces) do
        if wp then
            table.insert(all, {wp = wp, x = wp.minX, y = wp.minY})
        end
    end
    local sorted = TSP.NearestNeighbor(all)

    for _,item in ipairs(sorted) do
        local name = math.floor(item.x).."x"..math.floor(item.y) .. " - " .. item.wp.name
        self.listbox:addItem(name, item.wp)
    end
end

function WAT_WorkplaceAudit:prerender()
    ISPanelJoypad.prerender(self)
    self:drawTextCentre("Workplace Audit", self.titleSlot.left + self.titleSlot.width / 2, self.titleSlot.top, 1, 1, 1, 1, UIFont.Large)
end

function WAT_WorkplaceAudit:start()
    if self.running then
        return
    end
    self.running = true
    self.currentIdx = 1
    self.currentTask = "tp"
    self.currentWp = self.listbox.items[self.currentIdx].item
    Events.OnTick.Add(tickRunner)
    WL_Utils.addInfoToChat("Workplace audit started")
end

function WAT_WorkplaceAudit:stop()
    self.running = false
    Events.OnTick.Remove(tickRunner)
    WL_Utils.addInfoToChat("Workplace audit stopped")
end

function WAT_WorkplaceAudit:close()
    self:stop()
    self:removeFromUIManager()
    WAT_WorkplaceAudit.instance = nil
end

function WAT_WorkplaceAudit:onTick()
    if not self.running then
        return
    end

    if self.currentTask == "tp" then
        self.listbox.selected = self.currentIdx
        self.listbox:ensureVisible(self.currentIdx)
        local x = self.currentWp.minX + (self.currentWp.maxX - self.currentWp.minX) / 2
        local y = self.currentWp.minY + (self.currentWp.maxY - self.currentWp.minY) / 2
        local player = getPlayer()
        WL_Utils.teleportPlayerToCoords(player, x, y, 0)
        self.currentTask = "waitLoad"
        WL_Utils.addInfoToChat("Auditing Workplace: " .. self.currentWp.name)
    elseif self.currentTask == "waitLoad" then
        if self:checkLoaded() then
            self.currentTask = "runAudit"
        end
    elseif self.currentTask == "runAudit" then
        self:auditWorkplace()
        self.currentIdx = self.currentIdx + 1
        if self.currentIdx > #self.listbox.items then
            self:stop()
        else
            self.currentWp = self.listbox.items[self.currentIdx].item
            self.currentTask = "tp"
        end
    end
end

function WAT_WorkplaceAudit:checkLoaded()
    for x = self.currentWp.minX, self.currentWp.maxX do
        for y = self.currentWp.minY, self.currentWp.maxY do
            local sq = getCell():getGridSquare(x, y, 0)
            if not sq then
                return false
            end
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

function WAT_WorkplaceAudit:auditWorkplace()
    local items = {}
    local itemsOnGround = {}

    for x = self.currentWp.minX, self.currentWp.maxX do
        for y = self.currentWp.minY, self.currentWp.maxY do
            for z = self.currentWp.minZ, self.currentWp.maxZ do
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
                            itemsOnGround[itemId] = itemsOnGround[itemId] or 0
                            itemsOnGround[itemId] = itemsOnGround[itemId] + 1
                        end
                    end
                end
            end
        end
    end

    local name = math.floor(self.currentWp.minX).."x"..math.floor(self.currentWp.minY) .. " - " .. filenameClean(self.currentWp.name) ..".csv"
    local fileWriter = getFileWriter("WorkplaceAudits/overall-" .. name, true, false)
    fileWriter:writeln("ItemId,Category,Display Category,Name,Display Name,Count")
    for k,v in pairs(items) do
        fileWriter:writeln(k ..","..v.cat..","..v.displayCat..","..v.name..","..v.displayName..","..v.count)
    end
    fileWriter:close()

    local fileWriter = getFileWriter("WorkplaceAudits/ground-" .. name, true, false)
    fileWriter:writeln("ItemId,Count")
    for k,v in pairs(itemsOnGround) do
        fileWriter:writeln(k ..","..v)
    end
    fileWriter:close()
end