WRC_EditTapeWindow = ISCollapsableWindow:derive("WRC_EditTapeWindow")

WRC_EditTapeWindow.instance = nil

function WRC_EditTapeWindow:new(tape)
    if WRC_EditTapeWindow.instance then
        WRC_EditTapeWindow.instance:close()
        return
    end
	local scale =  getTextManager():getFontHeight(UIFont.Small) / 14
	local w = 600 * scale
	local h = 360 * scale
	local o = ISCollapsableWindow:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
	setmetatable(o, self)
    WRC_EditTapeWindow.instance = o
	o.__index = self
    o.tape = tape
	o:initialise()
	return o
end

function WRC_EditTapeWindow:initialise()
    self.moveWithMouse = true
    self.resizable = false

    self.page = 1
    self.pages = 1
    self.entries = {}

    local window = GravyUI.Node(self.width, self.height, self):pad(5, 15, 5, 5)
    local header, body, buttons = window:rows({30, 1, 18}, 10)
    self.headerLabel = header:makeLabel("Edit Tape " .. self.tape:getName(), UIFont.Medium, nil, "center")

    local rows = {body:rows(10, 5)}

    self.rows = {}
    for _, row in ipairs(rows) do
        local textInput = row:makeTextBox("")
        table.insert(self.rows, textInput)
    end

    local prev, save, next = buttons:cols(3, 60)

    self.prev = prev:makeButton("Prev", self, self.onPrev)
    self.next = next:makeButton("Next", self, self.onNext)
    self.save = save:makeButton("Save", self, self.onSave)

    self:updateEntries()
    self:updateRows()
end

function WRC_EditTapeWindow:updateEntries()
    self.entries = WRC.Recorders.GetTapeMessagesTable(self.tape)
    print(#self.entries)
end

function WRC_EditTapeWindow:updateRows()
    self.pages = math.ceil(#self.entries / #self.rows) + 1
    self.page = math.min(self.page, self.pages)

    -- 10 per page
    local firstEntry = (self.page - 1) * 10 + 1
    for i=0, 9 do
        local message = self.entries[firstEntry + i]
        if message then
            self.rows[i+1]:setText(message)
        else
            self.rows[i+1]:setText("")
        end
    end

    if self.page > 1 then
        self.prev:setEnable(true)
    else
        self.prev:setEnable(false)
    end

    if self.page < self.pages then
        self.next:setEnable(true)
    else
        self.next:setEnable(false)
    end
end

function WRC_EditTapeWindow:onPrev()
    self:readEntries()
    self.page = self.page - 1
    self:updateRows()
end

function WRC_EditTapeWindow:onNext()
    self:readEntries()
    self.page = self.page + 1
    self:updateRows()
end

function WRC_EditTapeWindow:readEntries()
    for i, row in ipairs(self.rows) do
        local text = row:getText()
        if text and text ~= "" then
            local index = (self.page - 1) * 10 + i
            self.entries[index] = text
        else
            local index = (self.page - 1) * 10 + i
            self.entries[index] = nil
        end
    end
end

function WRC_EditTapeWindow:onSave()
    self:readEntries()
    local max = 0
    for index,_ in pairs(self.entries) do
        if index > max then
            max = index
        end
    end
    local messages = {}
    for i=1, max do
        if self.entries[i] then
            table.insert(messages, self.entries[i])
        end
    end
    WRC.Recorders.SetTapeMessagesFromTable(self.tape, messages)
    self.entries = messages
    self:updateRows()
end

function WRC_EditTapeWindow:close()
    WRC_EditTapeWindow.instance = nil
    self:setVisible(false)
    self:removeFromUIManager()
end