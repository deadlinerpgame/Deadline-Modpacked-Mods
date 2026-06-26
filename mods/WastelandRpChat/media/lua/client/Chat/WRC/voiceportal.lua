if not isClient() then return end -- only in MP
WRC = WRC or {}
WRC_VoicePortal = WRC_VoicePortal or {}

WRC_VoicePortal.DEBUG = false
WRC_VoicePortal.registeredPortals = {}
WRC_VoicePortal.portalIdCounter = 0
WRC_VoicePortal.lastTriggerTime = {}  -- Debounce tracking per portal
WRC_VoicePortal.receiveDebounceTime = 1000  -- 1 second in milliseconds
WRC_VoicePortal.DEBOUNCE_TIME = 3000  -- 3 seconds in milliseconds

--- @alias MessageTable table<"whisper"|"low"|"say"|"loud"|"shout", string|boolean> A table mapping chat types to messages

--- Register a new voice portal
--- @param point1 table First portal point {x = number, y = number, z = number}
--- @param point2 table Second portal point {x = number, y = number, z = number}
--- @param inLevelMessages MessageTable|boolean if true, portal actual text. if table, show message or text for each type
--- @param outLevelMessages MessageTable|boolean if true, portal actual text. if table, show message or text for each type
--- @return table Portal object with id and unregister() method
function WRC_VoicePortal:register(point1, point2, inLevelMessages, outLevelMessages)
    self.portalIdCounter = self.portalIdCounter + 1
    local portalId = "portal_" .. self.portalIdCounter
    
    local portal = {
        id = portalId,
        point1 = point1,
        point2 = point2,
        inLevelMessages = inLevelMessages or nil,   -- point1 -> point2
        outLevelMessages = outLevelMessages or nil, -- point2 -> point1
    }
    
    self.registeredPortals[portalId] = portal
    
    -- Return portal object with unregister method
    return {
        id = portalId,
        unregister = function()
            WRC_VoicePortal.registeredPortals[portalId] = nil
            WRC_VoicePortal.lastTriggerTime[portalId] = nil
        end
    }
end

--- Check if player is within range of a point
--- @param player IsoPlayer
--- @param point table {x, y, z}
--- @param xyRange number
--- @param zRange number
--- @return boolean
function WRC_VoicePortal:isPlayerNearPoint(player, point, xyRange, zRange)
    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local dx = px - point.x
    local dy = py - point.y
    local dz = math.abs(pz - point.z)
    
    local distSq = dx * dx + dy * dy
    return distSq <= (xyRange * xyRange) and dz <= zRange
end

--- Check debounce for a portal
--- @param portalId string
--- @return boolean
function WRC_VoicePortal:canTrigger(portalId)
    local lastTime = self.lastTriggerTime[portalId]
    local currentTime = getTimestampMs()
    
    if not lastTime or (currentTime - lastTime) >= self.DEBOUNCE_TIME then
        self.lastTriggerTime[portalId] = currentTime
        return true
    end
    return false
end

--- Chat callback - called when local player speaks
--- @param parsedMessage table
function WRC_VoicePortal:onChatMessage(parsedMessage)
    -- Only process regular speech (not OOC, emotes, alerts, etc.)
    if parsedMessage.chatModifier == "me" then
        local hasWords = false
        for _, part in ipairs(parsedMessage.parts) do
            if part.type == "text" then
                hasWords = true
            end
        end
        if not hasWords then
            if self.DEBUG then
                print("WRC_VoicePortal: Ignoring /me with no text")
            end
            return
        end
    elseif parsedMessage.chatModifier ~= "say" and parsedMessage.chatModifier ~= nil then
        if self.DEBUG then
            print("WRC_VoicePortal: Ignoring non-say chat modifier: " .. tostring(parsedMessage.chatModifier))
        end
        return
    end
    
    local chatType = parsedMessage.chatType
    local player = getPlayer()
    if not player then
        if self.DEBUG then
            print("WRC_VoicePortal: No local player found")
        end
        return
    end
    
    -- Get range for this chat type
    local chatTypeConfig = WRC.ChatTypes[chatType]
    if not chatTypeConfig then
        if self.DEBUG then
            print("WRC_VoicePortal: Unknown chat type: " .. tostring(chatType))
        end
        return
    end
    
    local xyRange = chatTypeConfig.xyRange
    local zRange = chatTypeConfig.zRange
    
    -- Check each registered portal
    for portalId, portal in pairs(self.registeredPortals) do
        local sourcePoint = nil
        local targetMessage = nil
        
        -- Check if player is near point1
        if self:isPlayerNearPoint(player, portal.point1, xyRange, zRange) then
            if self.DEBUG then
                print("WRC_VoicePortal: Player is near point1 of portal " .. portalId)
            end
            if type(portal.inLevelMessages) == "boolean" and portal.inLevelMessages == true then
                sourcePoint = "point1"
                targetMessage = WRC.Parsing.GetTextOnly(parsedMessage)
            elseif type(portal.inLevelMessages) == "table" and portal.inLevelMessages[chatType] then
                sourcePoint = "point1"
                targetMessage = type(portal.inLevelMessages[chatType]) == "string" and portal.inLevelMessages[chatType] or WRC.Parsing.GetTextOnly(parsedMessage)
            elseif self.DEBUG then
                print("WRC_VoicePortal: No in-level message for chat type " .. chatType .. " at portal " .. portalId)
            end
        -- Check if player is near point2
        elseif self:isPlayerNearPoint(player, portal.point2, xyRange, zRange) then
            if self.DEBUG then
                print("WRC_VoicePortal: Player is near point2 of portal " .. portalId)
            end
            if type(portal.outLevelMessages) == "boolean" and portal.outLevelMessages == true then
                sourcePoint = "point2"
                targetMessage = WRC.Parsing.GetTextOnly(parsedMessage)
            elseif type(portal.outLevelMessages) == "table" and portal.outLevelMessages[chatType] then
                sourcePoint = "point2"
                targetMessage = type(portal.outLevelMessages[chatType]) == "string" and portal.outLevelMessages[chatType] or WRC.Parsing.GetTextOnly(parsedMessage)
            elseif self.DEBUG then
                print("WRC_VoicePortal: No out-level message for chat type " .. chatType .. " at portal " .. portalId)
            end
        end
        
        -- If near a portal point with a matching message, trigger it
        if sourcePoint and targetMessage then
            if self:canTrigger(portalId) then
                -- Send to server for relay to other players
                sendClientCommand(player, "WRC_VoicePortal", "TriggerPortal", {
                    portalId = portalId,
                    sourcePoint = sourcePoint,
                    chatType = chatType,
                    message = targetMessage,
                    targetPoint = sourcePoint == "point1" and portal.point2 or portal.point1,
                    xyRange = xyRange,
                    zRange = zRange,
                })
                if self.DEBUG then
                    print("WRC_VoicePortal: Triggered portal " .. portalId .. " from " .. sourcePoint)
                end
            elseif self.DEBUG then
                print("WRC_VoicePortal: Debounced trigger for portal " .. portalId)
            end
        end
    end
end

--- Receive portal message from server
--- @param message string
function WRC_VoicePortal:receivePortalMessage(message)
    if not message or message == "" then return end
    local currentTime = getTimestampMs()
    if self.lastReceiveTime and (currentTime - self.lastReceiveTime) < self.receiveDebounceTime then
        if self.DEBUG then
            print("WRC_VoicePortal: Debounced received portal message")
        end
        return
    end
    self.lastReceiveTime = currentTime
    local formattedMessage = WRC.ChatColors["environment"] .. "[[ " .. message .. " ]]" .. WL_Utils.MagicSpace
    
    local fakeMessage = WL_FakeMessage:new(formattedMessage, {
        author = nil,
        radioChannel = nil,
    })
    
    WRC.ISChatOriginal.addLineInChat(fakeMessage, 0)  -- General tab
end

-- Server command handler
local function onServerCommand(module, command, args)
    if module ~= "WRC_VoicePortal" then return end
    
    if command == "ReceivePortalMessage" then
        WRC_VoicePortal:receivePortalMessage(args[1])
    end
end

Events.OnServerCommand.Add(onServerCommand)