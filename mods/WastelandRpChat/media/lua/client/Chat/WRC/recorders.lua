WRC = WRC or {}
WRC.Recorders = WRC.Recorders or {}
WRC.Recorders.RunningRecorders = WRC.Recorders.RunningRecorders or {}
WRC.Recorders.IsChecking = false

function WRC.Recorders.CheckRecorders()
    for i = #WRC.Recorders.RunningRecorders, 1, -1 do
        local player = WRC.Recorders.RunningRecorders[i].player
        local recorder = WRC.Recorders.RunningRecorders[i].recorder
        WRC.Recorders.CheckRecorder(player, recorder)
    end

    if #WRC.Recorders.RunningRecorders == 0 then
        WRC.Recorders.IsChecking = false
        Events.OnTick.Remove(WRC.Recorders.CheckRecorders)
    end
end

function WRC.Recorders.CheckRecorder(player, recorder)
    local isInHand = player:getPrimaryHandItem() == recorder or player:getSecondaryHandItem() == recorder

    if not isInHand then
        WRC.Recorders.StopRecording(player, recorder)
    end
end

function WRC.Recorders.IsRecording(recorder)
    for _, data in ipairs(WRC.Recorders.RunningRecorders) do
        if data.recorder:getID() == recorder:getID() then
            return true
        end
    end
    return false
end

function WRC.Recorders.CanRecord(recorder)
    local md = recorder:getModData()
    return md.WRC_HasTape and md.WRC_HasBattery and md.WRC_TapeUsed < 30
end

function WRC.Recorders.StartRecording(player, recorder)
    local md = recorder:getModData()
    player:playSound("WRCRecorderStart")
    local soundId = player:playSound("WRCRecorderWhirr")
    table.insert(WRC.Recorders.RunningRecorders, {player = player, recorder = recorder, sound = soundId})
    WRC.Recorders.IsChecking = true
    Events.OnTick.Add(WRC.Recorders.CheckRecorders)
end

function WRC.Recorders.StopRecording(player, recorder)
    player:playSound("WRCRecorderStop")
    for i = #WRC.Recorders.RunningRecorders, 1, -1 do
        if WRC.Recorders.RunningRecorders[i].recorder == recorder then
            player:stopOrTriggerSound(WRC.Recorders.RunningRecorders[i].sound)
            table.remove(WRC.Recorders.RunningRecorders, i)
        end
    end
end

function WRC.Recorders.SaveToRecorder(player, recorder, message)
    local md = recorder:getModData()
    local ind = md.WRC_TapeUsed + 1

    if message:sub(1, 10) == "[Recorder]" then
        local newMessage = ""
        local inBracket = false
        local inCommand = false
        for i = 11, #message do
            local c = message:sub(i, i)
            local isSpace = c == " "
            if c == "[" then
                inBracket = true
            end
            if c == "/" then
                inCommand = true
            end
            if inCommand and isSpace then
                inCommand = false
            end
            if not isSpace and not inBracket and not inCommand and ZombRand(10) == 0 then
                c = "*"
            end
            if inBracket and c == "]" then
                inBracket = false
            end
            newMessage = newMessage .. c
        end
        message = newMessage
    end

    md["WRC_Message" .. ind] = message
    md.WRC_TapeUsed = ind
    if ind >= 30 then
        WRC.Recorders.StopRecording(player, recorder)
        WL_Utils.addErrorToChat("The recorder's tape is full!")
    end
    local bat = md.WRC_BatteryLevel
    if bat > 0 then
        md.WRC_BatteryLevel = math.max(0, bat - 0.01)
    end
    if bat == 0 then
        md.WRC_HasBattery = false
        WRC.Recorders.StopRecording(player, recorder)
        WL_Utils.addErrorToChat("The recorder's battery is dead!")
    end
end

function WRC.Recorders.CanPlay(recorder)
    local md = recorder:getModData()
    return md.WRC_HasTape and md.WRC_HasBattery and md.WRC_TapeUsed > 0
end

function WRC.Recorders.GetTapeMessagesTable(tape)
    local md = tape:getModData()
    if not md.WRC_TapeUsed then return {} end
    local messages = {}
    for i = 1, md.WRC_TapeUsed do
        table.insert(messages, md["WRC_Message" .. i])
    end
    return messages
end

function WRC.Recorders.SetTapeMessagesFromTable(tape, messages)
    local md = tape:getModData()
    md.WRC_TapeUsed = #messages
    for i = 1, #messages do
        md["WRC_Message" .. i] = messages[i]
    end
end

function WRC.Recorders.GetRecorderMessages(recorder)
    local md = recorder:getModData()
    return md.WRC_TapeUsed
end

function WRC.Recorders.PlayRecorderMessage(player, recorder, index)
    local md = recorder:getModData()
    local message = md["WRC_Message" .. index]
    if message then
        local mutedRadios = {}
        local radiosOn = WRU_Utils.getPlayerRadios(player, true)
        for _, radio in ipairs(radiosOn) do
            if WRU_Utils.isRadioBroadcasting(radio) then
                WRU_Utils.setRadioBroadcastingInstant(player, radio, false)
                table.insert(mutedRadios, radio)
            end
        end
        processSayMessage("[Recorder]" .. message)
        for _, radio in ipairs(mutedRadios) do
            WRU_Utils.setRadioBroadcastingInstant(player, radio, true)
        end
        
        md.WRC_BatteryLevel = math.max(0, md.WRC_BatteryLevel - 0.001)
    end
end

function WRC.Recorders.HasTape(recorder)
    local md = recorder:getModData()
    return md.WRC_HasTape
end

function WRC.Recorders.InsertTape(recorder, tape)
    local md = recorder:getModData()
    md.WRC_HasTape = true
    local tapeMd = tape:getModData()
    if tapeMd.WRC_TapeUsed then
        md.WRC_TapeUsed = tapeMd.WRC_TapeUsed
        for i = 1, tapeMd.WRC_TapeUsed do
            md["WRC_Message" .. i] = tapeMd["WRC_Message" .. i]
        end
    else
        md.WRC_TapeUsed = 0
    end
    if tape:isCustomName() then
        md.WRC_TapeName = tape:getName()
    else
        md.WRC_TapeName = nil
    end
end

function WRC.Recorders.RemoveTape(recorder)
    local md = recorder:getModData()
    md.WRC_HasTape = false
    local tape = InventoryItemFactory.CreateItem("WRCRecorderTape")
    local tapeMd = tape:getModData()

    tapeMd["WRC_Processed"] = true
    tapeMd.WRC_TapeUsed = md.WRC_TapeUsed
    for i = 1, md.WRC_TapeUsed do
        tapeMd["WRC_Message" .. i] = md["WRC_Message" .. i]
    end
    if md.WRC_TapeName then
        tape:setName(md.WRC_TapeName)
        tape:setCustomName(true)
    else
        tape:setName("Recordable Tape")
        tape:setCustomName(false)
    end
    md.WRC_TapeUsed = 0
    md.WRC_HasTape = false
    return tape
end

function WRC.Recorders.ClearTape(recorder)
    local md = recorder:getModData()
    md.WRC_TapeUsed = 0
end

function WRC.Recorders.HasBattery(recorder)
    local md = recorder:getModData()
    return md.WRC_HasBattery and md.WRC_BatteryLevel > 0
end

function WRC.Recorders.InsertBattery(recorder, battery)
    local md = recorder:getModData()
    md.WRC_HasBattery = true
    md.WRC_BatteryLevel = battery:getUsedDelta() -- TODO see how this works
end

function WRC.Recorders.RemoveBattery(recorder)
    local md = recorder:getModData()
    if not md.WRC_HasBattery then return end
    md.WRC_HasBattery = false
    local battery = InventoryItemFactory.CreateItem("Battery")
    battery:setUsedDelta(md.WRC_BatteryLevel)
    md.WRC_BatteryLevel = 0
    return battery
end

local function isBlankTape(item)
    if item:getType() ~= "WRCRecorderTape" then return false end
    local md = item:getModData()
    return not md.WRC_TapeUsed or md.WRC_TapeUsed == 0
end

ISInventoryMenuElements = ISInventoryMenuElements or {}
local MAXIMUM_RENAME_LENGTH = 28
function ISInventoryMenuElements.ContextWRCTapeRecorder()
    local self = ISMenuElement.new()
    self.invMenu = ISContextManager.getInstance().getInventoryMenu()

    function self.init()
        self.recorder = nil
        self.tape = nil
    end

    function self.createMenu(item)
        if item:getType() == "WRCRecorder" then
            self.recorder = item
            self.doRecorderMenu()
            return
        else
            self.recorder = nil
        end

        if item:getType() == "WRCRecorderTape" then
            self.tape = item
            self.doTapeMenu()
            return
        else
            self.tape = nil
        end
    end

    function self.doTapeMenu()
        local recorder = self.invMenu.player:getInventory():FindAndReturn("WRCRecorder")

        if recorder and not WRC.Recorders.HasTape(recorder) then
            self.recorder = recorder
            self.invMenu.context:addOption(getText("UI_WRC_InsertToRecorder"), nil, self.insertTape)
        end

        self.invMenu.context:addOption(getText("UI_WRC_RenameTape"), nil, self.renameTape)

        if getDebug() then
            self.invMenu.context:addOption("Debug: Randomize", self.tape, WRC_RandomizeTape)
        end

        if WL_Utils.isStaff(self.invMenu.player) then
            self.invMenu.context:addOption("Edit Recordable Tape", self, self.editTape)
        end
    end

    function self.doRecorderMenu()
        local hasTape = WRC.Recorders.HasTape(self.recorder)
        local hasBattery = WRC.Recorders.HasBattery(self.recorder)
        local isRecording = WRC.Recorders.IsRecording(self.recorder)
        local canRecord = WRC.Recorders.CanRecord(self.recorder)
        local canPlay = WRC.Recorders.CanPlay(self.recorder)

        if hasTape and hasBattery and not isRecording then
            if canRecord then
                self.invMenu.context:addOption(getText("UI_WRC_StartRecording"), nil, self.startRecording)
            end
            if canPlay then
                local menu = WL_ContextMenuUtils.getOrCreateSubMenu(self.invMenu.context, getText("UI_WRC_PlayTape"))
                menu:addOption(getText("UI_WRC_NormalSpeed"), 3000, self.playTape)
                menu:addOption(getText("UI_WRC_FastSpeed"), 1500, self.playTape)
                menu:addOption(getText("UI_WRC_SlowSpeed"), 4500, self.playTape)
                self.invMenu.context:addOption(getText("UI_WRC_ClearTape"), nil, self.clearTape)
            end
        end
        if isRecording and canRecord then
            self.invMenu.context:addOption(getText("UI_WRC_StopRecording"), nil, self.stopRecording)
        end
        if not hasTape then
            local tape = self.invMenu.player:getInventory():getFirstEvalRecurse(isBlankTape)
            if tape then
                self.tape = tape
                self.invMenu.context:addOption(getText("UI_WRC_InsertBlankTape"), nil, self.insertTape)
            end
        end
        if not hasBattery then
            local invBattery = self.invMenu.player:getInventory():getFirstTypeRecurse("Battery")
            if invBattery then
                self.invMenu.context:addOption(getText("UI_WRC_InsertBattery"), invBattery, self.insertBattery)
            end
        end
        if hasTape and not isRecording then
            self.invMenu.context:addOption(getText("UI_WRC_RemoveTape"), nil, self.removeTape)
        end
        if hasBattery and not isRecording then
            self.invMenu.context:addOption(getText("UI_WRC_RemoveBattery"), nil, self.removeBattery)
        end
    end

    function self.startRecording()
        local playerObj = self.invMenu.player
        if playerObj:getPrimaryHandItem() ~= self.recorder and playerObj:getSecondaryHandItem() ~= self.recorder then
            ISWorldObjectContextMenu.equip(playerObj, playerObj:getSecondaryHandItem(), self.recorder, false, false)
        end
        ISTimedActionQueue.add(WRCStartRecordingAction:new(self.invMenu.player, self.recorder))
    end

    function self.stopRecording()
        ISTimedActionQueue.add(WRCStopRecordingAction:new(self.invMenu.player, self.recorder))
    end

    function self.playTape(speed)
        local playerObj = self.invMenu.player
        if playerObj:getPrimaryHandItem() ~= self.recorder and playerObj:getSecondaryHandItem() ~= self.recorder then
            ISWorldObjectContextMenu.equip(playerObj, playerObj:getSecondaryHandItem(), self.recorder, false, false)
        end
        ISTimedActionQueue.add(WRCPlayTapeAction:new(self.invMenu.player, self.recorder, speed))
    end

    function self.clearTape()
        ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.recorder)
        ISTimedActionQueue.add(WRCClearTapeAction:new(self.invMenu.player, self.recorder))
    end

    function self.insertTape()
        ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.recorder)
        ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.tape)
        ISTimedActionQueue.add(WRCInsertTapeAction:new(self.invMenu.player, self.recorder, self.tape))
    end

    function self.removeTape()
        ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.recorder)
        ISTimedActionQueue.add(WRCRemoveTapeAction:new(self.invMenu.player, self.recorder))
    end

    function self.insertBattery(battery)
        if battery then
            ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.recorder)
            ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, battery)
            ISTimedActionQueue.add(WRCInsertBatteryAction:new(self.invMenu.player, self.recorder, battery))
        end
    end

    function self.removeBattery()
        ISInventoryPaneContextMenu.transferIfNeeded(self.invMenu.player, self.recorder)
        ISTimedActionQueue.add(WRCRemoveBatteryAction:new(self.invMenu.player, self.recorder))
    end

    function self.renameTape()
        local modal = ISTextBox:new(0, 0, 280, 180, getText("ContextMenu_NameThisBag"), self.tape:getName(), nil, self.renameTapeClick, self.invMenu.playerNum, self.tape)
        modal:initialise()
        modal:addToUIManager()
    end

    function self.editTape()
        local modal = WRC_EditTapeWindow:new(self.tape)
        modal:addToUIManager()
    end

    function self.renameTapeClick(_, button, tape)
        if button.internal == "OK" then

            local length = button.parent.entry:getInternalText():len()
            if button.parent.entry:getText() and button.parent.entry:getText() ~= "" then
                if length <= MAXIMUM_RENAME_LENGTH then
                    tape:setName(button.parent.entry:getText())
                    tape:setCustomName(true)
                else
                    getPlayer():Say(getText("IGUI_PlayerText_ItemNameTooLong"));
                end
            end
        end
    end

    return self
end

WRCInsertTapeAction = WRCInsertTapeAction or ISBaseTimedAction:derive("WRCInsertTapeAction")

function WRCInsertTapeAction:new(character, recorder, tape)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.tape = tape
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCInsertTapeAction:isValid()
    return self.recorder:isInPlayerInventory() and self.tape:isInPlayerInventory()
end

function WRCInsertTapeAction:perform()
    WRC.Recorders.InsertTape(self.recorder, self.tape)
    self.character:getInventory():Remove(self.tape)
    ISBaseTimedAction.perform(self)
end

WRCRemoveTapeAction = WRCRemoveTapeAction or ISBaseTimedAction:derive("WRCRemoveTapeAction")

function WRCRemoveTapeAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCRemoveTapeAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCRemoveTapeAction:perform()
    local tape = WRC.Recorders.RemoveTape(self.recorder)
    self.character:getInventory():AddItem(tape)
    ISBaseTimedAction.perform(self)
end

WRCInsertBatteryAction = WRCInsertBatteryAction or ISBaseTimedAction:derive("WRCInsertBatteryAction")

function WRCInsertBatteryAction:new(character, recorder, battery)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.battery = battery
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCInsertBatteryAction:isValid()
    return self.recorder:isInPlayerInventory() and self.battery:isInPlayerInventory()
end

function WRCInsertBatteryAction:perform()
    WRC.Recorders.InsertBattery(self.recorder, self.battery)
    self.character:getInventory():Remove(self.battery)
    ISBaseTimedAction.perform(self)
end

WRCRemoveBatteryAction = WRCRemoveBatteryAction or ISBaseTimedAction:derive("WRCRemoveBatteryAction")

function WRCRemoveBatteryAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCRemoveBatteryAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCRemoveBatteryAction:perform()
    local battery = WRC.Recorders.RemoveBattery(self.recorder)
    self.character:getInventory():AddItem(battery)
    ISBaseTimedAction.perform(self)
end

WRCStartRecordingAction = WRCStartRecordingAction or ISBaseTimedAction:derive("WRCStartRecordingAction")

function WRCStartRecordingAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCStartRecordingAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCStartRecordingAction:perform()
    WRC.Recorders.StartRecording(self.character, self.recorder)
    ISBaseTimedAction.perform(self)
end

WRCStopRecordingAction = WRCStopRecordingAction or ISBaseTimedAction:derive("WRCStopRecordingAction")

function WRCStopRecordingAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCStopRecordingAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCStopRecordingAction:perform()
    WRC.Recorders.StopRecording(self.character, self.recorder)
    ISBaseTimedAction.perform(self)
end

WRCStopPlayingAction = WRCStopPlayingAction or ISBaseTimedAction:derive("WRCStopPlayingAction")

function WRCStopPlayingAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 20
    return o
end

function WRCStopPlayingAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCStopPlayingAction:perform()
    WRC.Recorders.StopPlaying(self.recorder)
    ISBaseTimedAction.perform(self)
end

WRCClearTapeAction = WRCClearTapeAction or ISBaseTimedAction:derive("WRCClearTapeAction")

function WRCClearTapeAction:new(character, recorder)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.stopOnWalk = true
    o.stopOnRun = true
    o.maxTime = 100
    return o
end

function WRCClearTapeAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCClearTapeAction:perform()
    WRC.Recorders.ClearTape(self.recorder)
    ISBaseTimedAction.perform(self)
end

WRCPlayTapeAction = WRCPlayTapeAction or ISBaseTimedAction:derive("WRCPlayTapeAction")

function WRCPlayTapeAction:new(character, recorder, speed)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, self)
    self.__index = self
    o.recorder = recorder
    o.speed = speed
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = -1
    return o
end

function WRCPlayTapeAction:isValid()
    return self.recorder:isInPlayerInventory()
end

function WRCPlayTapeAction:start()
    self.lastPlay = 0
    self.lastIndx = 0
    self.maxIndx = WRC.Recorders.GetRecorderMessages(self.recorder)
    self.character:playSound("WRCRecorderStart")
    self.sound = self.character:playSound("WRCRecorderWhirr")
end

function WRCPlayTapeAction:update()
    local now = getTimestampMs()
    if now - self.lastPlay > self.speed then
        self.lastPlay = now
        self.lastIndx = self.lastIndx + 1
        if self.lastIndx > self.maxIndx or not WRC.Recorders.HasBattery(self.recorder) then
            self:forceComplete()
            return
        end
        WRC.Recorders.PlayRecorderMessage(self.character, self.recorder, self.lastIndx)
    end
end

function WRCPlayTapeAction:perform()
    self.character:stopOrTriggerSound(self.sound)
    self.character:playSound("WRCRecorderStop")
    ISBaseTimedAction.perform(self)
end

function WRCPlayTapeAction:stop()
    self.character:stopOrTriggerSound(self.sound)
    self.character:playSound("WRCRecorderStop")
    ISBaseTimedAction.stop(self)
end

local original_ISToolTipInv_removeFromUIManager = ISToolTipInv.removeFromUIManager
function ISToolTipInv:removeFromUIManager()
    original_ISToolTipInv_removeFromUIManager(self)
    if self.WRC_Tooltip then
        self.WRC_Tooltip:removeFromUIManager()
        self.WRC_Tooltip = nil
    end
end

local original_ISToolTipInv_setVisible = ISToolTipInv.setVisible
function ISToolTipInv:setVisible(visible)
    original_ISToolTipInv_setVisible(self, visible)
    if self.WRC_Tooltip and not visible then
        self.WRC_Tooltip:setVisible(false)
        self.WRC_Tooltip = nil
    end
end

local original_ISToolTipInv_render = ISToolTipInv.render
function ISToolTipInv:render()
    original_ISToolTipInv_render(self)
    local x = self.tooltip:getX() - 11
    local y = self.tooltip:getY() + self.tooltip:getHeight()

    if self.item and self.item:getType() == "WRCRecorder" then
        if not self.WRC_Tooltip then
            self.WRC_Tooltip = ISToolTip:new()
            self.WRC_Tooltip:initialise()
            self.WRC_Tooltip:addToUIManager()
        end
        self.WRC_Tooltip.description = self:WRC_GetTapeRecorderInfo()
        self.WRC_Tooltip:setVisible(true)
        self.WRC_Tooltip:setDesiredPosition(x, y)
    elseif self.item and self.item:getType() == "WRCRecorderTape" then
        if not self.WRC_Tooltip then
            self.WRC_Tooltip = ISToolTip:new()
            self.WRC_Tooltip:initialise()
            self.WRC_Tooltip:addToUIManager()
        end
        self.WRC_Tooltip.description = self:WRC_GetTapeInfo()
        self.WRC_Tooltip:setVisible(true)
        self.WRC_Tooltip:setDesiredPosition(x, y)
    elseif self.WRC_Tooltip then
        self.WRC_Tooltip:setVisible(false)
    end
end

function ISToolTipInv:WRC_GetTapeRecorderInfo()
    local desc = ""
    if WRC.Recorders.IsRecording(self.item) then
        desc = desc .. "** Recording **\n\n"
    end

    if WRC.Recorders.HasBattery(self.item) then
        desc = desc .. "Battery Level: " .. math.floor(self.item:getModData().WRC_BatteryLevel * 100) .. "%\n"
    else
        desc = desc .. "No Battery\n"
    end

    if WRC.Recorders.HasTape(self.item) then
        if self.item:getModData().WRC_TapeName then
            desc = desc .. "Tape Name: " .. self.item:getModData().WRC_TapeName .. "\n"
        end
        desc = desc .. "Messages on Tape: " .. WRC.Recorders.GetRecorderMessages(self.item) .. "/30"
    else
        desc = desc .. "No Tape Inserted"
    end
    return desc
end

function ISToolTipInv:WRC_GetTapeInfo()
    local md = self.item:getModData()
    if md.WRC_TapeUsed then
        return "Messages on Tape: " .. md.WRC_TapeUsed .. "/30"
    else
        return "Blank Tape"
    end
end