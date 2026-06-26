WRU_Utils = WRU_Utils or {}

-- Known "radio" devices which are not actually radios
local knownRadios = ArrayList.new()
knownRadios:add("Tsarcraft.TCWalkman")
knownRadios:add("Tsarcraft.TCBoombox")

function WRU_Utils.isRadio(item)
    if not item then return false end
    if knownRadios:contains(item:getFullType()) then return false end
    return instanceof(item, "Radio")
end

function WRU_Utils.isRadioOn(radio)
    return radio:getDeviceData():getIsTurnedOn()
end

function WRU_Utils.isRadioBroadcasting(radio)
    local data = radio:getDeviceData()
    return data:getIsTurnedOn() and not data:getMicIsMuted()
end

function WRU_Utils.getRadioRange(radio)
    return radio:getDeviceData():getTransmitRange()
end

function WRU_Utils.getRadioFrequency(radio)
    return radio:getDeviceData():getChannel()
end

function WRU_Utils.getRadioFrequencyString(radio)
    return tostring(WRU_Utils.getRadioFrequency(radio)/1000).." MHz"
end

function WRU_Utils.AreAnyRadiosOn(player)
    local inv = player:getInventory()
    if not inv then return false end

    local items = inv:getItems()
    for i=0,items:size()-1 do
        local item = items:get(i)
        if WRU_Utils.isRadio(item) and WRU_Utils.isRadioOn(item) then
            return true
        end
    end

    return false
end

function WRU_Utils.AreAnyRadiosTransmitting(player)
    local inv = player:getInventory()
    if not inv then return false end

    local items = inv:getItems()
    for i=0,items:size()-1 do
        local item = items:get(i)
        if WRU_Utils.isRadio(item) and WRU_Utils.isRadioBroadcasting(item) then
            return true
        end
    end

    return false
end

function WRU_Utils.getPlayerRadios(player, onlyOn, onlyTransmitting)
    local radios = {}

    local inv = player:getInventory()
    if not inv then return radios end

    local items = inv:getItems()
    for i=0,items:size()-1 do
        local item = items:get(i)
        if WRU_Utils.isRadio(item)
        and (not onlyOn or WRU_Utils.isRadioOn(item))
        and (not onlyTransmitting or WRU_Utils.isRadioBroadcasting(item))
        then
            table.insert(radios, item)
        end
    end
    return radios
end

function WRU_Utils.getRadioRanges(radios)
    local ranges = {}

    local player = getPlayer()
    local sq = player:getSquare()
    if not sq then return {} end

    local centerX = sq:getX()
    local centerY = sq:getY()

    for _, item in pairs(radios) do
        if WRU_Utils.isRadioOn(item) then
            local range = WRU_Utils.getRadioRange(item)
            if ranges[range] then
                ranges[range].freq = ranges[range].freq .. ", " .. WRU_Utils.getRadioFrequencyString(item)
            else
                ranges[range] = {
                    x1 = centerX-range,
                    y1 = centerY-range,
                    x2 = centerX+range,
                    y2 = centerY+range,
                    freq = getText("IGUI_RadioFrequency").. ": " .. WRU_Utils.getRadioFrequencyString(item)
                }
            end
        end
    end

    return ranges
end

function WRU_Utils.setRadioBroadcasting(player, radio, shouldBroadcast)
    if radio:getDeviceData():getMicIsMuted() == shouldBroadcast then
        ISTimedActionQueue.add(ISRadioAction:new("MuteMicrophone", player, radio, not shouldBroadcast));
    end
end

function WRU_Utils.setRadioBroadcastingInstant(player, radio, shouldBroadcast)
    if radio:getDeviceData():getMicIsMuted() == shouldBroadcast then
        radio:getDeviceData():setMicIsMuted(not shouldBroadcast)
    end
end

function WRU_Utils.setRadioPower(player, radio, shouldBeOn)
    if radio:getDeviceData():getIsTurnedOn() ~= shouldBeOn then
        ISTimedActionQueue.add(ISRadioAction:new("ToggleOnOff", player, radio));
    end
end

function WRU_Utils.setRadioPowerInstant(player, radio, shouldBeOn)
    if radio:getDeviceData():getIsTurnedOn() ~= shouldBeOn then
        radio:getDeviceData():setIsTurnedOn(shouldBeOn)
    end
end