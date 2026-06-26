WIT_CombineGoldAction = ISBaseTimedAction:derive("WIT_CombineGoldAction")

function WIT_CombineGoldAction:isValid()
    return true
end

function WIT_CombineGoldAction:perform()
    local container = self.goldItem:getContainer()
    WIT_Gold.combineAllOnPlayer(self.character, container)
    WIT_CombineGoldAction:stop()
    ISBaseTimedAction.perform(self)
end

function WIT_CombineGoldAction:start()
	self.sound = self.character:playSound(WIT_Gold.CurrencySound)
end

function WIT_CombineGoldAction:stop()
	if self.sound and self.sound ~= 0 then
		self.character:getEmitter():stopOrTriggerSound(self.sound)
	end
end

function WIT_CombineGoldAction:new(player, goldItem)
    local i = ISBaseTimedAction.new(self, player)
    setmetatable(i, self)
    self.__index = self
    i.goldItem = goldItem
    i.maxTime = 5
    if player:isTimedActionInstant() then
        i.maxTime = 1
    end
    return i
end

local function combineGold(player, goldItem)
    if not goldItem then return end
    local action = WIT_CombineGoldAction:new(player, goldItem)
    ISTimedActionQueue.add(action)
end

Events.OnPreFillInventoryObjectContextMenu.Add(function (playerIdx, context, items, test)
    if test then return end
    local item = ISInventoryPane.getActualItems(items)[1]
    if item and WIT_Gold.ItemAmounts[item:getFullType()] then
        local player = getSpecificPlayer(playerIdx)
        if not player:getInventory():containsRecursive(item) then return end
        local option = context:addOption(getText("ContextMenu_CombineGold"), player, combineGold, item)
        local tooltip = ISInventoryPaneContextMenu.addToolTip()
        tooltip:setName(getText("ContextMenu_CombineGold"))
        tooltip.description = getText("Tooltip_CombineGold")
        option.toolTip = tooltip
    end
end)