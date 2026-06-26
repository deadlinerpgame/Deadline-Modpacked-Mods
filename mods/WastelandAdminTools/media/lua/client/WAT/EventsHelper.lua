require "GravyUI"

-- Require the WL_WeatherOverride library for the clear weather functionality
require "WL_WeatherOverride"

if WAT_EventsHelper then
    Events.OnTick.Remove(WAT_EventsHelper.onTickFollowMe)
end

WAT_EventsHelper = WAT_EventsHelper or ISCollapsableWindow:derive("WAT_EventsHelper")

function WAT_EventsHelper:display()
    if WAT_EventsHelper.instance ~= nil then
        return
    end
    local md = getPlayer():getModData()
    md.WAT_EventsHelper_Hidden = false

    local buttons = {
        {type="single", id="invisibleButton", short="IV", tooltip="Toggle invisiblity / Ghost Mode", func=self.toggleInivisible},
        {type="single", id="godModeButton", short="GM", tooltip="Toggle God Mode", func=self.toggleGodMode},
        {type="single", id="movingButton", short="FM", tooltip="Toggle Fast Move / No Clip", func=self.toggleMoving},
        {type="single", id="seePlayersButton", short="SP", tooltip="Toggle See All Players", func=self.toggleSeePlayers},
        {type="single", id="zombieRadarButton", short="ZR", tooltip="Toggle Zombie Radar", func=self.toggleZombieRadar},
        {type="single", id="zombiesFollowButton", short="ZF", tooltip="Toggle Zombies Follow Me", func=self.toggleZombiesFollow},
        {type="increaseDecrese", tooltip="Zombie Follow Range: ", property="zombieFollowRange", min=5, max=30},
        {type="single", id="moveHordeButton", short="MH", tooltip="Move Horde to Position", func=self.moveHorde},
        {type="increaseDecrese", tooltip="Move Horde Range: ", property="moveHordeRange", min=5, max=30},
        {type="single", id="quickHordeButton", short="QH", tooltip="Quick Horde Spawn", func=self.startQuickHorde},
        {type="increaseDecrese", tooltip="Quick Horde Size: ", property="quickHordeSize", min=1, max=100},
        {type="single", id="aoeKillButton", short="AK", tooltip="AOE Kill All", func=self.aoeKill},
        {type="increaseDecrese", tooltip="AOE Kill Range: ", property="aoeKillRange", min=5, max=30},
        {type="single", id="sucideButton", short="SC", tooltip="Instant Sucide", func=self.sucide},
        {type="single", id="soundboardButton", short="SB", tooltip="Open Soundboard", func=self.soundboard},
        {type="single", id="itemPickerButton", short="IP", tooltip="Item Picker", func=self.openItemPicker},
        {type="single", id="tilePickerButton", short="TL", tooltip="Tile Picker", func=self.openTilePicker},
        {type="single", id="levelAnayzerButton", short="LA", tooltip="Level Analyzer", func=self.openLevelAnalyzer},
        {type="single", id="makeFire", short="FU", tooltip="Fire UI", func=self.makeFire},
        {type="single", id="massFactionButton", short="MF", tooltip="Mass Faction", func=self.massFaction},
        {type="single", id="clearCorpseButton", short="CC", tooltip="Clear Corpses", func=self.clearCorpses},
        {type="single", id="clearBloodButton", short="CB", tooltip="Clear Blood", func=self.clearBlood},
        {type="increaseDecrese", tooltip="Clear Size: ", property="clearSize", min=1, max=50},
        {type="single", id="clearWeatherButton", short="CW", tooltip="Toggle Clear Weather", func=self.toggleClearWeather},
        {type="single", id="overFill", tooltip="Allow Container Overfilling", short="OF", func=self.toggleOverfill},
        {type="single", id="eventPref", tooltip="Show Event Preference", short="EP", func=self.toggleEventPreference},
    }

    local numFullBtn = 0
    local numIncDecBtn = 0
    for _, btnDef in ipairs(buttons) do
        if btnDef.type == "single" then
            numFullBtn = numFullBtn + 1
        elseif btnDef.type == "increaseDecrese" then
            numIncDecBtn = numIncDecBtn + 1
        end
    end
    local height = numFullBtn * 18 + numIncDecBtn * 12 + 25
    local x = md.WAT_EventsHelperX or getCore():getScreenWidth() - 40
    local y = md.WAT_EventsHelperY or getCore():getScreenHeight() / 2 - height / 2
    local o = ISCollapsableWindow:new(x, y, 40, height)
	setmetatable(o, self)
	self.__index = self
    o.title = ""
    o.resizable = false
    o.buttons = buttons
    o.numFullBtn = numFullBtn
    o.numIncDecBtn = numIncDecBtn
    o:initialise()
    o:collapse()
    WAT_EventsHelper.instance = o
end

function WAT_EventsHelper:initialise()
    ISCollapsableWindow.initialise(self)

    self.zombiesFollowMe = false
    self.zombieRadarEnabled = false
    self.tickDelay = 0
    self.selectingSquare = false
    self.clearWeatherEnabled = false

    self.zombieFollowRange = 15
    self.moveHordeRange = 15
    self.quickHordeSize = 10
    self.aoeKillRange = 15
    self.clearSize = 50

    self:addToUIManager()
    self:setAlwaysOnTop(true)
    self.moveWithMouse = true
    self.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self.backgroundColor = {r=0, g=0, b=0, a=1}

    local slotParts = {}
    for _, btnDef in ipairs(self.buttons) do
        if btnDef.type == "single" then
            table.insert(slotParts, 15)
        elseif btnDef.type == "increaseDecrese" then
            table.insert(slotParts, 9)
        end
    end

    local window = GravyUI.Node(self.width, self.height):pad(5, 20, 5, 5)
    local slots = {window:rows(slotParts, 3)}

    for idx, btnDef in ipairs(self.buttons) do
        if btnDef.type == "single" then
            local btn = slots[idx]:makeButton(btnDef.short, self, btnDef.func)
            btn:setWidth(window.width or 20)
            btn.tooltip = btnDef.tooltip
            self:addChild(btn)
            self[btnDef.id] = btn
        elseif btnDef.type == "increaseDecrese" then
            local left, right = slots[idx]:cols(2)

            local decreaseBtn = left:makeButton("-", self, self.adjustValue, {btnDef, -1})
            decreaseBtn:setWidth(left.width or 10)
            decreaseBtn.tooltip = btnDef.tooltip..self[btnDef.property].." <LINE>Hold Shift to decrement by 5"
            self:addChild(decreaseBtn)
            self[btnDef.property.."DecreaseButton"] = decreaseBtn

            local increaseBtn = right:makeButton("+", self, self.adjustValue, {btnDef, 1})
            increaseBtn:setWidth(right.width or 10)
            increaseBtn.tooltip = btnDef.tooltip..self[btnDef.property].." <LINE>Hold Shift to increment by 5"
            self:addChild(increaseBtn)
            self[btnDef.property.."IncreaseButton"] = increaseBtn
        end
    end

end

function WAT_EventsHelper:adjustValue(btn, btnDef, direction)
    local amount = direction
    if isKeyDown(Keyboard.KEY_LSHIFT) then
        amount = amount * 5
    end
    self[btnDef.property] = math.min(math.max(self[btnDef.property] + amount, btnDef.min), btnDef.max)
    self[btnDef.property.."DecreaseButton"].tooltip = btnDef.tooltip..self[btnDef.property].." <LINE>Hold Shift to decrement by 5"
    self[btnDef.property.."IncreaseButton"].tooltip = btnDef.tooltip..self[btnDef.property].." <LINE>Hold Shift to increment by 5"
end

local greenButtonColor = {r=0, g=0.7, b=0, a=1}
local redButtonColor = {r=0.7, g=0, b=0, a=1}
local zombieRadarZDiffAlpha = {
    [0] = 0,
    [1] = 0.5,
    [2] = 0.8,
}
function WAT_EventsHelper:updateButtons()
    local player = getPlayer()

    if not player then return end

    self.invisibleButton.backgroundColor = player:isInvisible() and greenButtonColor or redButtonColor
    self.godModeButton.backgroundColor = player:isGodMod() and greenButtonColor or redButtonColor
    self.movingButton.backgroundColor = ISFastTeleportMove.cheat and greenButtonColor or redButtonColor
    self.seePlayersButton.backgroundColor = player:isCanSeeAll() and greenButtonColor or redButtonColor
    self.zombiesFollowButton.backgroundColor = self.zombiesFollowMe and greenButtonColor or redButtonColor
    self.zombieRadarButton.backgroundColor = self.zombieRadarEnabled and greenButtonColor or redButtonColor
    self.clearWeatherButton.backgroundColor = self.clearWeatherEnabled and greenButtonColor or redButtonColor
    self.overFill.backgroundColor = WAT_OverFiller.enabled and greenButtonColor or redButtonColor
    local showEventPreference = WAT and WAT.InvisibleIndicator and WAT.InvisibleIndicator.ShowEventPreference
    self.eventPref.backgroundColor = showEventPreference and greenButtonColor or redButtonColor

    -- min 5, max 30
    if self.zombieFollowRangeDecreaseButton.enabled and self.zombieFollowRange <= 5 then
        self.zombieFollowRangeDecreaseButton:setEnable(false)
    elseif not self.zombieFollowRangeDecreaseButton.enabled and self.zombieFollowRange > 5 then
        self.zombieFollowRangeDecreaseButton:setEnable(true)
    end
    if self.zombieFollowRangeIncreaseButton.enabled and self.zombieFollowRange >= 30 then
        self.zombieFollowRangeIncreaseButton:setEnable(false)
    elseif not self.zombieFollowRangeIncreaseButton.enabled and self.zombieFollowRange < 30 then
        self.zombieFollowRangeIncreaseButton:setEnable(true)
    end

    -- min 5, max 30
    if self.moveHordeRangeDecreaseButton.enabled and self.moveHordeRange <= 5 then
        self.moveHordeRangeDecreaseButton:setEnable(false)
    elseif not self.moveHordeRangeDecreaseButton.enabled and self.moveHordeRange > 5 then
        self.moveHordeRangeDecreaseButton:setEnable(true)
    end
    if self.moveHordeRangeIncreaseButton.enabled and self.moveHordeRange >= 30 then
        self.moveHordeRangeIncreaseButton:setEnable(false)
    elseif not self.moveHordeRangeIncreaseButton.enabled and self.moveHordeRange < 30 then
        self.moveHordeRangeIncreaseButton:setEnable(true)
    end

    -- min 1, max 100
    if self.quickHordeSizeDecreaseButton.enabled and self.quickHordeSize <= 1 then
        self.quickHordeSizeDecreaseButton:setEnable(false)
    elseif not self.quickHordeSizeDecreaseButton.enabled and self.quickHordeSize > 1 then
        self.quickHordeSizeDecreaseButton:setEnable(true)
    end
    if self.quickHordeSizeIncreaseButton.enabled and self.quickHordeSize >= 100 then
        self.quickHordeSizeIncreaseButton:setEnable(false)
    elseif not self.quickHordeSizeIncreaseButton.enabled and self.quickHordeSize < 100 then
        self.quickHordeSizeIncreaseButton:setEnable(true)
    end

    -- min 5, max 30
    if self.aoeKillRangeDecreaseButton.enabled and self.aoeKillRange <= 5 then
        self.aoeKillRangeDecreaseButton:setEnable(false)
    elseif not self.aoeKillRangeDecreaseButton.enabled and self.aoeKillRange > 5 then
        self.aoeKillRangeDecreaseButton:setEnable(true)
    end
    if self.aoeKillRangeIncreaseButton.enabled and self.aoeKillRange >= 30 then
        self.aoeKillRangeIncreaseButton:setEnable(false)
    elseif not self.aoeKillRangeIncreaseButton.enabled and self.aoeKillRange < 30 then
        self.aoeKillRangeIncreaseButton:setEnable(true)
    end

end

function WAT_EventsHelper:toggleInivisible()
    local player = getPlayer()
    if player:isInvisible() then
        player:setInvisible(false)
    else
        player:setInvisible(true)
    end
    sendPlayerExtraInfo(player)
end

function WAT_EventsHelper:toggleGodMode()
    local player = getPlayer()
    if player:isGodMod() then
        player:setGodMod(false)
    else
        player:setGodMod(true)
    end
    sendPlayerExtraInfo(player)
end

function WAT_EventsHelper:toggleMoving()
    local player = getPlayer()
    ISFastTeleportMove.cheat = not ISFastTeleportMove.cheat
    player:setNoClip(ISFastTeleportMove.cheat)
    sendPlayerExtraInfo(player)
end

function WAT_EventsHelper:toggleSeePlayers()
    local player = getPlayer()
    if player:isCanSeeAll() then
        player:setCanSeeAll(false)
    else
        player:setCanSeeAll(true)
    end
    sendPlayerExtraInfo(player)
end

function WAT_EventsHelper:toggleZombiesFollow()
    self.zombiesFollowMe = not self.zombiesFollowMe
    if self.zombiesFollowMe then
        Events.OnTick.Add(WAT_EventsHelper.onTickFollowMe)
    else
        Events.OnTick.Remove(WAT_EventsHelper.onTickFollowMe)
    end
end

function WAT_EventsHelper:toggleZombieRadar()
    self.zombieRadarEnabled = not self.zombieRadarEnabled
end

function WAT_EventsHelper:startQuickHorde()
    self.selectingSquare = "quickHorde"
end

function WAT_EventsHelper:spawnQuickHorde(x, y, z)
    SendCommandToServer(string.format("/createhorde2 -x %d -y %d -z %d -count %d -radius %d -crawler %s -isFallOnFront %s -isFakeDead %s -knockedDown %s -health %s -outfit %s ", x, y, z, self.quickHordeSize, 1, "false", "false", "false", "false", 1.0, ""))
end

function WAT_EventsHelper:aoeKill()
    self.selectingSquare = "aoeKill"
end

function WAT_EventsHelper:doAoeKill(x, y, z)
    local square = getCell():getGridSquare(math.floor(x), math.floor(y), z)
    if not square then
        return
    end
    local allZombies = getCell():getZombieList()
    local tempZombie = getCell():getFakeZombieForHit()
    for i=0,allZombies:size()-1 do
        local zombie = allZombies:get(i)
        if not zombie:isDead() and zombie:isLocal() and square:DistTo(zombie) <= self.aoeKillRange then
            zombie:Kill(tempZombie)
        end
    end
end

function WAT_EventsHelper:sucide()
    local x = getCore():getScreenWidth() / 2 - 100
    local y = getCore():getScreenHeight() / 2 - 25
    local modal = ISModalDialog:new(x, y, 200, 50, "Suicide?", true, nil, function(_, b)
        if b.internal == "YES" then
            getPlayer():setHealth(0)
        end
    end)
    modal:initialise()
    modal:addToUIManager()
end

function WAT_EventsHelper:soundboard()
    if WSB_SoundboardWindow then
        WSB_SoundboardWindow.show()
    end
end

function WAT_EventsHelper:moveHorde()
    self.selectingSquare = "moveHorde"
end

function WAT_EventsHelper:makeFire()
    local x = getCore():getScreenWidth() / 2 - 100
    local y = getCore():getScreenHeight() / 2 - 200
    FireBrushUI.openPanel(x, y, getPlayer())
end

function WAT_EventsHelper:massFaction()
    local x = getCore():getScreenWidth() / 2 - 100
    local y = getCore():getScreenHeight() / 2 - 25
    local s = self
    local modal = ISModalDialog:new(x, y, 200, 50, "Create mass faction?", true, nil, function(_, b)
        if b.internal == "YES" then
            s:doCreateMassFaction()
        end
    end)
    modal:initialise()
    modal:addToUIManager()
end

function WAT_EventsHelper:doCreateMassFaction()
    local me = getPlayer()
    local faction = Faction.getFaction("Temporary Event Faction")
    if faction then
        local players = faction:getPlayers()
        for i=0,players:size()-1 do
            faction:removePlayer(players:get(i))
        end
        faction:setOwner(me:getUsername())
    else
        faction = Faction.createFaction("Temporary Event Faction", me:getUsername())
        faction:setTag("TEF")
    end
    if not faction then
        WL_Utils.addErrorToChat("Something went wrong making the temporary event faction")
        return
    end
    -- Get all nearby players
    local players = getOnlinePlayers()
    -- Add all players to the faction
    for i=0,players:size()-1 do
        local player = players:get(i)
        if player:getDistanceSq(me) < 50*50 then
            if not WL_Utils.isStaff(player) then
                local currentFaction = Faction.getPlayerFaction(player:getUsername())
                if currentFaction then
                    currentFaction:removePlayer(player:getUsername())
                    if currentFaction:getOwner() == player:getUsername() then
                        currentFaction:removeFaction()
                    end
                    currentFaction:syncFaction()
                end
                faction:addPlayer(player:getUsername())
            end
        end
    end
    faction:syncFaction()
    local modal = ISFactionUI:new(getCore():getScreenWidth() / 2 - 250, getCore():getScreenHeight() / 2 - 225, 500, 450, faction, me)
    modal:initialise()
    modal:addToUIManager()
    WL_Utils.addInfoToChat("Temporary event faction created. Make sure to disband the faction after the event.")
end

function WAT_EventsHelper:openItemPicker()
    if ISItemsListViewer.instance then
        ISItemsListViewer.instance:close()
    end
    local modal = ISItemsListViewer:new(50, 200, 850, 650, getPlayer())
    modal:initialise()
    modal:addToUIManager()
end

function WAT_EventsHelper:openTilePicker()
    if TileEditorMain then
        TileEditorMain:display()
    else
        BrushToolChooseTileUI.openPanel((getCore():getScreenWidth()/2) - 411, (getCore():getScreenHeight()/2) - 330, getPlayer())
    end
end

function WAT_EventsHelper:openLevelAnalyzer()
    WAT_ShowLevelAnalyzer()
end

function WAT_EventsHelper:close()
    if self.gridSquareMarker then
        getWorldMarkers():removeGridSquareMarker(self.gridSquareMarker)
        self.gridSquareMarker = nil
    end
    local md = getPlayer():getModData()
    md.WAT_EventsHelperX = self:getX()
    md.WAT_EventsHelperY = self:getY()
    md.WAT_EventsHelper_Hidden = true
    self:setVisible(false)
    self:removeFromUIManager()
    WAT_EventsHelper.instance = nil
end

function WAT_EventsHelper:prerender()
    ISCollapsableWindow.prerender(self)
    self:updateButtons()
    if self.selectingSquare then
        local player = getPlayer()
        if not self.gridSquareMarker then
            local square = player:getCurrentSquare()
            self.gridSquareMarker = getWorldMarkers():addGridSquareMarker(square, 1, 0.5, 0.5, false, 1)
        end
        local sx = getMouseX()
        local sy = getMouseY()
        local z = player:getZ()
        local x = screenToIsoX(0, sx, sy, z)
        local y = screenToIsoY(0, sx, sy, z)
        self.gridSquareMarker:setPos(x, y, z)

        if isKeyDown(Keyboard.KEY_ESCAPE) then
            self.selectingSquare = false
            getWorldMarkers():removeGridSquareMarker(self.gridSquareMarker)
            self.gridSquareMarker = nil
        elseif isMouseButtonDown(0) then
            if self.selectingSquare == "moveHorde" then
                self:moveHordeToPosition(x, y, z, self.moveHordeRange)
            elseif self.selectingSquare == "quickHorde" then
                self:spawnQuickHorde(x, y, z)
            elseif self.selectingSquare == "aoeKill" then
                self:doAoeKill(x, y, z)
            end
            self.selectingSquare = false
            getWorldMarkers():removeGridSquareMarker(self.gridSquareMarker)
            self.gridSquareMarker = nil
        end
    elseif self.gridSquareMarker then
        getWorldMarkers():removeGridSquareMarker(self.gridSquareMarker)
        self.gridSquareMarker = nil
    end
end

function WAT_EventsHelper.onTickFollowMe()
    local self = WAT_EventsHelper.instance
    if not self or not self.zombiesFollowMe then
        Events.OnTick.Remove(WAT_EventsHelper.onTickFollowMe)
        return
    end
    if self.tickDelay == 0 then
        self.tickDelay = 60
        self:makeNearbyZombiesMoveToMe()
    else
        self.tickDelay = self.tickDelay - 1
    end
end

function WAT_EventsHelper.onPostFloorLayerDrawZombieRadar()
    local instance = WAT_EventsHelper.instance
    if not instance or not instance.zombieRadarEnabled then
        return
    end

    instance:scanAndRenderZombieRadarSquares()
end
function WAT_EventsHelper:scanAndRenderZombieRadarSquares()
    local player = getPlayer()
    if not player then
        return
    end

    local cell = getCell()
    if not cell then
        return
    end

    local zombies = cell:getZombieList()
    if not zombies then
        return
    end

    local zombiesSize = zombies:size()
    if zombiesSize == 0 then
        return
    end

    local playerZ = math.floor(player:getZ())
    local renderedCount = 0

    -- Limit radar work to the currently visible screen-space converted into iso bounds.
    local core = getCore()
    local screenWidth = core:getScreenWidth()
    local screenHeight = core:getScreenHeight()
    local isoX1 = screenToIsoX(0, 0, 0, 0)
    local isoY1 = screenToIsoY(0, 0, 0, 0)
    local isoX2 = screenToIsoX(0, screenWidth, 0, 0)
    local isoY2 = screenToIsoY(0, screenWidth, 0, 0)
    local isoX3 = screenToIsoX(0, 0, screenHeight, 0)
    local isoY3 = screenToIsoY(0, 0, screenHeight, 0)
    local isoX4 = screenToIsoX(0, screenWidth, screenHeight, 0)
    local isoY4 = screenToIsoY(0, screenWidth, screenHeight, 0)

    local minIsoX = math.floor(math.min(isoX1, isoX2, isoX3, isoX4)) - 1
    local maxIsoX = math.ceil(math.max(isoX1, isoX2, isoX3, isoX4)) + 1
    local minIsoY = math.floor(math.min(isoY1, isoY2, isoY3, isoY4)) - 1
    local maxIsoY = math.ceil(math.max(isoY1, isoY2, isoY3, isoY4)) + 1

    local maxRadarSquaresPerTick = 1000

    for i = 0, zombiesSize - 1 do
        local zombie = zombies:get(i)
        if zombie and not zombie:isDead() then
            local zx, zy, zz = zombie:getX(), zombie:getY(), zombie:getZ()
            if zx >= minIsoX and zx <= maxIsoX and zy >= minIsoY and zy <= maxIsoY then
                local zDiff = math.floor(math.abs(zz - playerZ))
                local adj = zombieRadarZDiffAlpha[zDiff] or 0.95
                renderIsoCircle(zx, zy, zz, 0.25, 1, adj, 0, 1, 1)
                renderedCount = renderedCount + 1
                if renderedCount >= maxRadarSquaresPerTick then
                    break
                end
            end
        end
    end
end

function WAT_EventsHelper:makeNearbyZombiesMoveToMe()
    local player = getPlayer()
    local x = player:getX()
    local y = player:getY()
    local z = player:getZ()

    self:moveHordeToPosition(x, y, z, self.zombieFollowRange)
end

function WAT_EventsHelper:moveHordeToPosition(x, y, z, d)
    local sx = math.floor(x) - d
    local sy = math.floor(y) - d
    local ex = sx + d*2
    local ey = sy + d*2
    for cx = sx,ex do for cy = sy,ey do for cz = 0,7 do
        local square = getCell():getGridSquare(cx, cy, cz)
        if square then
            local movingEntities = square:getMovingObjects()
            for i=0,movingEntities:size()-1 do
                local movingEntity = movingEntities:get(i)
                if instanceof(movingEntity, "IsoZombie") then
                    movingEntity:pathToLocationF(x, y, z)
                end
            end
        end
    end end end
    sendClientCommand(getPlayer(), 'WAT', 'moveHordeToPosition', {x=x, y=y, z=z, d=d})
end

function WAT_EventsHelper:clearCorpses()
    local player = getPlayer()
    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local sx = x - self.clearSize
    local sy = y - self.clearSize
    local ex = sx + self.clearSize*2
    local ey = sy + self.clearSize*2
    WL_Utils.clearCorpses(sx, sy, 0, ex, ey, 7)
end

function WAT_EventsHelper:clearBlood()
    local player = getPlayer()
    local x = math.floor(player:getX())
    local y = math.floor(player:getY())
    local sx = x - self.clearSize
    local sy = y - self.clearSize
    local ex = sx + self.clearSize*2
    local ey = sy + self.clearSize*2
    WL_Utils.removeBlood(sx, sy, 0, ex, ey, 7)
end

function WAT_EventsHelper:toggleClearWeather()
    self.clearWeatherEnabled = not self.clearWeatherEnabled
    
    if self.clearWeatherEnabled then
        -- Set clear weather conditions
        local weatherOverrides = {
            -- No darkness
            Darkness = { value = 0.0 },
            -- No rain
            Precipitation = { intensity = 0.0, isSnow = false },
            -- Mid-level light
            Light = {
                intR = 128, intG = 128, intB = 128, intA = 0,
                extR = 128, extG = 128, extB = 128, extA = 255
            },
            -- No fog
            Fog = { intensity = 0.0 },
            -- Clear clouds
            Clouds = { intensity = 0.0 },
            -- No desaturation
            Desaturation = { value = 0.0 },
        }
        
        WL_WeatherOverride.SetBulkOverrides("WAT_ClearWeather", weatherOverrides)
        getSandboxOptions():getOptionByName("EnableSnowOnGround"):setValue(false)
    else
        -- Remove clear weather overrides
        WL_WeatherOverride.UnsetAllOverrides("WAT_ClearWeather")
        getSandboxOptions():getOptionByName("EnableSnowOnGround"):setValue(true)
    end
end

function WAT_EventsHelper:toggleOverfill()
    if WAT_OverFiller.enabled then
        WAT_OverFiller.disable()
    else
        WAT_OverFiller.enable()
    end
end

function WAT_EventsHelper:toggleEventPreference()
    WAT = WAT or {}
    WAT.InvisibleIndicator = WAT.InvisibleIndicator or {}
    WAT.InvisibleIndicator.ShowEventPreference = not WAT.InvisibleIndicator.ShowEventPreference
end

if not WAT_EventsHelper.didBind then
    WL_PlayerReady.Add(function (playerIndex, player)
        local player = getPlayer()
        if WL_Utils.isAtLeastGM(player) and not player:getModData().WAT_EventsHelper_Hidden then
            WAT_EventsHelper:display()
        end
    end)

    Events.OnPostFloorLayerDraw.Add(function() WAT_EventsHelper.onPostFloorLayerDrawZombieRadar() end)

    WAT_EventsHelper.didBind = true
end
