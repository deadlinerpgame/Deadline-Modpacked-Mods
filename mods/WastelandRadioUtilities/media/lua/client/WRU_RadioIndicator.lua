require "ISUI/ISPanel"
require "WRU_Utils"
require "WRU_Options"

local textures = {
    micOn = getTexture("media/ui/WRU_MicOn.png"),
    micOff = getTexture("media/ui/WRU_MicOff.png"),
    radioOff = getTexture("media/ui/WRU_RadioOff.png"),
}

WRU_RadioIndicator = ISPanel:derive("WRU_RadioIndicator")
WRU_RadioIndicator.instances = {}

function WRU_RadioIndicator:new(radio)
    local o = ISPanel:new(0, 0, 25, 25)
    setmetatable(o, self)
    self.__index = self
    o.radio = radio
    o.moveWithMouse = true
    o.isBroadcasting = false
    o.isOn = false
    return o
end

function WRU_RadioIndicator:setInitialPosition()
    local modData = self.radio:getModData()
    local screenWidth = getCore():getScreenWidth()
    local screenHeight = getCore():getScreenHeight()

    if not modData.WRU_indicator_x or modData.WRU_indicator_x < 0 or modData.WRU_indicator_x > screenWidth - 15 then
        modData.WRU_indicator_x = screenWidth / 2 - 8
    end
    if not modData.WRU_indicator_y or modData.WRU_indicator_y < 0 or modData.WRU_indicator_y > screenHeight - 15 then
        modData.WRU_indicator_y = screenHeight - 115
    end

    -- check for collisions with other indicators
    local didCollide = true
    local tries = 100
    while didCollide do
        didCollide = false
        tries = tries - 1
        for _, other in pairs(WRU_RadioIndicator.instances) do
            if other ~= self and other.radio ~= self.radio then
                if other:getX() < modData.WRU_indicator_x + self:getWidth() and other:getX() + other:getWidth() > modData.WRU_indicator_x and other:getY() < modData.WRU_indicator_y + self:getHeight() and other:getY() + other:getHeight() > modData.WRU_indicator_y then
                    modData.WRU_indicator_x = modData.WRU_indicator_x + 20
                    didCollide = true
                end
            end
        end
        if didCollide and modData.WRU_indicator_x > screenWidth - 15 then
            modData.WRU_indicator_x = 0
        end
        if tries <= 0 then
            didCollide = false
        end
    end

    self:setX(modData.WRU_indicator_x)
    self:setY(modData.WRU_indicator_y)
end

function WRU_RadioIndicator:initialise()
    ISPanel.initialise(self)
    self:addToUIManager()
    self:setInitialPosition()
    self:setAlwaysOnTop(true)
    WRU_RadioIndicator.instances[self.radio] = self
end

-- store the position of the indicator on the radio if moved
-- toggle radio broadcasting on/off if clicked
WRU_RadioIndicator.WRU_onMouseUpOrig = WRU_RadioIndicator.onMouseUp
function WRU_RadioIndicator:onMouseUp(x, y)
    self:WRU_onMouseUpOrig(x, y)

    local modData = self.radio:getModData()
    local winX = self:getX()
    local winY = self:getY()

    if modData.WRU_indicator_x ~= winX or modData.WRU_indicator_y ~= winY then
        modData.WRU_indicator_x = winX
        modData.WRU_indicator_y = winY
    else
        if not self.isOn then
            WRU_Utils.setRadioPower(getPlayer(), self.radio, true)
        end
        WRU_Utils.setRadioBroadcasting(getPlayer(), self.radio, not self.isBroadcasting)
    end
end

-- toggle radio on/off
WRU_RadioIndicator.WRU_onRightMouseUpOrig = WRU_RadioIndicator.onRightMouseUp
function WRU_RadioIndicator:onRightMouseUp(x, y)
    self:WRU_onRightMouseUpOrig(x, y)
    WRU_Utils.setRadioPower(getPlayer(), self.radio, not self.isOn)
end

-- no prerender so no background box
WRU_RadioIndicator.prerender = function() end

-- render the indicator and frequency
function WRU_RadioIndicator:render()
    if not self.isOn then
        self:drawTextureScaled(textures.radioOff, 0, 0, self:getWidth(), self:getHeight(), 1, 1, 1, 1)
    elseif self.isBroadcasting then
        self:drawTextureScaled(textures.micOn, 0, 0, self:getWidth(), self:getHeight(), 1, 1, 1, 1)
    else
        self:drawTextureScaled(textures.micOff, 0, 0, self:getWidth(), self:getHeight(), 1, 1, 1, 1)
    end
    self:drawTextCentre(tostring(WRU_Utils.getRadioFrequency(self.radio)/1000), self:getWidth()/2, self:getHeight(), 1, 1, 1, 1, UIFont.DebugConsole)
end

function WRU_RadioIndicator.updateStatus(self)
    self.isOn = WRU_Utils.isRadioOn(self.radio)
    self.isBroadcasting = WRU_Utils.isRadioBroadcasting(self.radio)
end

function WRU_RadioIndicator:destroy()
    self:removeFromUIManager()
    WRU_RadioIndicator.instances[self.radio] = nil
end

-- hide the indicators if the world map is open
local ISWorldMap_initialiseOrig = ISWorldMap.initialise
function ISWorldMap:initialise()
    ISWorldMap_initialiseOrig(self)
    for _, indicator in pairs(WRU_RadioIndicator.instances) do
        indicator:setVisible(false)
    end
end

-- hide the indicators if the world map is open
local ISWorldMap_setVisibleOrig = ISWorldMap.setVisible
function ISWorldMap:setVisible(visible)
    print("ISWorldMap:setVisible " .. tostring(visible))
    ISWorldMap_setVisibleOrig(self, visible)
    for _, indicator in pairs(WRU_RadioIndicator.instances) do
        indicator:setVisible(not visible)
    end
end

local tickDelay = 0
local function onTick()
    if not WRU_Options.show_broadcast_indicator then
        Events.OnTick.Remove(onTick)
        return
    end

    if tickDelay > 0 then
        tickDelay = tickDelay - 1
        return
    end

    tickDelay = 30

    local playerRadios = WRU_Utils.getPlayerRadios(getPlayer())

    -- remove any radio not in the player's inventory
    for radio, indicator in pairs(WRU_RadioIndicator.instances) do
        local wasFound = false
        -- this tight loop is okay because there should only be a few radios
        for _, playerRadio in pairs(playerRadios) do
            if radio == playerRadio then
                wasFound = true
            end
        end
        if not wasFound then
            indicator:destroy()
        end
    end

    -- create indicators for any new radios
    for _, playerRadio in pairs(playerRadios) do
        if not WRU_RadioIndicator.instances[playerRadio] then
            local radioIndicator = WRU_RadioIndicator:new(playerRadio)
            radioIndicator:initialise()
        end
    end

    -- update the status of all indicators
    for _, indicator in pairs(WRU_RadioIndicator.instances) do
        indicator:updateStatus()
    end
end

-- start the tick loop if the option is enabled to display indicators
local function onGameStart()
    if WRU_Options.show_broadcast_indicator then
        Events.OnTick.Add(onTick)
    end
end

-- start/stop the tick loop if the option is changed
local function showBroadcastIndicatorOptionChanged()
    if WRU_Options.show_broadcast_indicator then
        tickDelay = 0
        Events.OnTick.Add(onTick)
    else
        tickDelay = 1000 -- fairly large delay just to be safe
        Events.OnTick.Remove(onTick)
    end
end

WRU_Options_Callbacks.show_broadcast_indicator = showBroadcastIndicatorOptionChanged
Events.OnGameStart.Add(onGameStart)