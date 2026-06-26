local PrepareField = ISBaseTimedAction:derive("PrepareField")

function PrepareField:new(character, field, handItem)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.field = field
    o.handItem = handItem
    o.maxTime = 1
    o.stopOnWalk = true
    return o
end

function PrepareField:waitToStart()
	self.character:faceLocation(self.field[1]:getX(), self.field[1]:getY())
	return self.character:shouldBeTurning()
end

function PrepareField:update()
	self.character:faceLocation(self.field[1]:getX(), self.field[1]:getY())
end

function PrepareField:isValid()
    return #self.field > 0
end

function PrepareField:perform()
    local next = table.remove(self.field, 1)
	ISTimedActionQueue.add(ISPlowAction:new(self.character, next, self.handItem, 110))
    if #self.field > 0 then
        ISFarmingMenu.walkToPlant(self.character, self.field[1])
        ISTimedActionQueue.add(PrepareField:new(self.character, self.field, self.handItem))
    end
	ISBaseTimedAction.perform(self)
end

local function isValidFarmingSquare(square)
	if CFarmingSystem.instance:getLuaObjectOnSquare(square) then
		return false
	end
	if not square:isFreeOrMidair(true, true) then return false end
	-- farming plot have to be on natural floor (no road, concrete etc.)
	for i = 0, square:getObjects():size() - 1 do
		local item = square:getObjects():get(i)
		-- IsoRaindrop and IsoRainSplash have no sprite/texture
		if item:getTextureName() and (luautils.stringStarts(item:getTextureName(), "floors_exterior_natural") or
				luautils.stringStarts(item:getTextureName(), "blends_natural_01")) then
			return true
		end
	end
--~ 	if result then
--~ 		result = square:getSpecialObjects():size() == 0
--~ 	end
	return false
end

local PrepareAreaPicker = ISPanel:derive("WF_PrepareAreaPicker")
PrepareAreaPicker.instance = nil

function PrepareAreaPicker:new(player, handItem, startSquare)
    local w = 300
    local h = 150
    local x = getPlayerScreenLeft(player:getPlayerNum()) + getPlayerScreenWidth(player:getPlayerNum()) / 2 - w / 2
    local y = getPlayerScreenTop(player:getPlayerNum()) + getPlayerScreenHeight(player:getPlayerNum()) / 2 - h / 2
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.handItem = handItem
    o.startSquare = startSquare
    o.moveWithMouse = true
    o:initialise()
    o:addToUIManager()
    o:setAlwaysOnTop(true)
    PrepareAreaPicker.instance = o
end

function PrepareAreaPicker:initialise()
    ISPanel.initialise(self)
    local win = GravyUI.Node(self.width, self.height, self):pad(10)

    local picker, buttons = win:rows({0.66, 0.34}, 5)
    self.picker = picker:makeAreaPicker()
    self.picker:setValue({
        x1 = self.startSquare:getX() - 1,
        y1 = self.startSquare:getY() - 1,
        z1 = self.startSquare:getZ(),
        x2 = self.startSquare:getX() + 1,
        y2 = self.startSquare:getY() + 1,
        z2 = self.startSquare:getZ()
    })
    self.picker.forceZ = self.startSquare:getZ()
    self.picker.groundHighlighter:setColorPickerFunc(function (x, y, z)
        local sq = getCell():getGridSquare(x, y, z)
        if sq then
            if isValidFarmingSquare(sq) then
                return {r = 1, g = 1, b = 0, a = 1}
            end
            return {r = 1, g = 0, b = 0, a = 1}
        end
    end)
    self.picker.groundHighlighter.xray = false
    self.picker.groundHighlighter:setColor(1, 1, 0, 1)
    self.picker.showAlways = true

    local goButton, cancelButton = buttons:cols(2, 5)
    goButton:makeButton("Go", self, self.onGo)
    cancelButton:makeButton("Cancel", self, self.close)
end

function PrepareAreaPicker:onGo()
    local area = self.picker:getValue()
    local field = {}
    for x = area.x1, area.x2 do
        for y = area.y1, area.y2 do
            local sq = getCell():getGridSquare(x, y, self.startSquare:getZ())
            if sq then
                if isValidFarmingSquare(sq) then
                    table.insert(field, sq)
                end
            end
        end
    end
    
    if #field > 0 then
        -- Only apply token limitations if the farming tokens system is enabled
        if SandboxVars.WastelandFarming.EnableFarmingTokens then
            -- Check how many tokens the player has available
            local availableTokens = WF_TokensSystem:getAllowedTokens(self.player) - WF_TokensSystem.myUsedTokens
            local originalCount = #field
            
            -- Limit the field to the number of available tokens
            if #field > availableTokens then
                if availableTokens <= 0 then
                    WL_Utils.addInfoToChat("You don't have any farming tokens available.", {
                        chatId = WRC.OocTabId
                    })
                    self:close()
                    return
                end
                
                -- Truncate the field array to the available tokens
                while #field > availableTokens do
                    table.remove(field)
                end
                
                WL_Utils.addInfoToChat("You only have " .. availableTokens .. " farming tokens available. Preparing " .. #field .. " out of " .. originalCount .. " selected plots.", {
                    chatId = WRC.OocTabId
                })
            end
        end
        
        WF_Lib.SnakeSortSquares(field)
        ISInventoryPaneContextMenu.equipWeapon(self.handItem, true, self.handItem:isTwoHandWeapon(), self.player:getPlayerNum())
        ISFarmingMenu.walkToPlant(self.player, field[1])
        ISTimedActionQueue.add(PrepareField:new(self.player, field, self.handItem))
    end
    self:close()
end

function PrepareAreaPicker:close()
    self:setVisible(false)
    self:removeFromUIManager()
    self.picker:cleanup()
    PrepareAreaPicker.instance = nil
end

local function OnPreFillWorldObjectContextMenu(playerIdx, context, worldobjects, test)
    if test then return end

    local playerObj = getSpecificPlayer(playerIdx)
    local square = worldobjects[1]:getSquare()
    if not square then return end

    local handItem = ISFarmingMenu.getShovel(playerObj)

    if not handItem then return end

    if ISFarmingMenu.canDigHere(worldobjects) then
        context:addOption("Prepare Field", PrepareAreaPicker, PrepareAreaPicker.new, playerObj, handItem, square)
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(OnPreFillWorldObjectContextMenu)