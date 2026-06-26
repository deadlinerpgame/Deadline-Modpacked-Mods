--- @class WL_ChatOptions
--- @field author string|nil
--- @field radioChannel number|nil
--- @field datetimeStr string|nil
--- @field color string|nil
--- @field showOverhead boolean|nil
--- @field chatId number|nil


--- @class WL_FakeMessage
--- @field text string
--- @field author string
--- @field radioChannel number
--- @field datetimeStr string
--- @field color string
--- @field showOverhead boolean
--- @field chatId number
WL_FakeMessage = {}

---Create a new WL_FakeMessage
---@param text string
---@param options WL_ChatOptions|nil
---@return WL_FakeMessage
function WL_FakeMessage:new(text, options)
    options = options or {}

    local o = {}
    setmetatable(o, self)
    o.__index = self

    o.text = text
    o.author = options.author or ""
    o.radioChannel = options.radioChannel or 0
    o.datetimeStr = options.datetimeStr or nil
    o.color = options.color or nil
    o.showOverhead = options.showOverhead or false
    o.chatId = options.chatId or 1
    return o
end

function WL_FakeMessage:setText(text)
    self.text = text
end
function WL_FakeMessage:getText()
    if self.color then
        return "<RGB:" .. self.color .. ">" .. self.text
    end
    return self.text
end
function WL_FakeMessage:getAuthor()
    return self.author
end
function WL_FakeMessage:getRadioChannel()
    return self.radioChannel
end
function WL_FakeMessage:isServerAlert()
    return false
end
function WL_FakeMessage:getTextWithPrefix()
    local message = self:getText()
    if ISChat.instance.showTimestamp and self.datetimeStr then
        message = "<RGB:0.4,0.4,0.4>[" .. self.datetimeStr .. "] " .. message
    end
    if ISChat.instance.chatFont then
        message = "<SIZE:" .. ISChat.instance.chatFont .. ">" .. message
    end
    return message
end
function WL_FakeMessage:isOverHeadSpeech()
    return self.showOverhead
end
function WL_FakeMessage:getChatID()
    return self.chatId
end
function WL_FakeMessage:getDatetimeStr()
    return self.datetimeStr
end

function WL_FakeMessage:setOverHeadSpeech() end
function WL_FakeMessage:setShouldAttractZombies() end
