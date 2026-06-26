---
--- WWP_InventoryMenu.lua
--- Right click context for managing anti-theft strips
--- 18/06/2023
---
---
if not isClient() then return end

require "WL_ContextMenuUtils"
require "WL_Utils"


WWP_AddStripAction = ISBaseTimedAction:derive("WWP_AddStripAction")
function ISBaseTimedAction:isValid() return true end
function WWP_AddStripAction:perform()
	self.item:getModData().WWP_ATS_Applied = true
	self.item:getModData().WWP_ATS_AppliedTo = self.workplaceId
	self.strip:getContainer():DoRemoveItem(self.strip)
	ISBaseTimedAction.perform(self)
end
function WWP_AddStripAction:new(character, item, strip, workplaceId)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
	o.strip = strip
	o.workplaceId = workplaceId
    o.maxTime = 5
    if o.character:isTimedActionInstant() then o.maxTime = 1 end
	return o
end

WWP_RemoveStripAction = ISBaseTimedAction:derive("WWP_RemoveStripAction")
function WWP_RemoveStripAction:isValid() return true end
function WWP_RemoveStripAction:perform()
	self.item:getModData().WWP_ATS_Applied = nil
	self.item:getModData().WWP_ATS_AppliedTo = nil
	self.character:getInventory():AddItem("Base.AntiTheftStrip")
	ISBaseTimedAction.perform(self)
end
function WWP_RemoveStripAction:new(character, item)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
	o.maxTime = 5
	if o.character:isTimedActionInstant() then o.maxTime = 1 end
	return o
end

local WWP_InventoryMenu = {}

function WWP_InventoryMenu.doMenu(playerIdx, context, items)
	local player = getPlayer(playerIdx)
    items = ISInventoryPane.getActualItems(items)
	local currentWorkplaces = WWP_WorkplaceZone.getZonesAt(player:getX(), player:getY(), player:getZ())
	if not currentWorkplaces or #currentWorkplaces == 0 then return end
	local currentWorkplace = currentWorkplaces[1]

	if not currentWorkplace:isEmployee(player) and not WL_Utils.isStaff(player) then return end

	local hasStrips = false
	for _, item in ipairs(items) do
		if item:getModData().WWP_ATS_Applied then
			hasStrips = true
			break
		end
	end

	local needsStrips = false
	for _, item in ipairs(items) do
		if not item:getModData().WWP_ATS_Applied then
			needsStrips = true
			break
		end
	end

	if hasStrips and currentWorkplace:isPartner(player:getUsername()) then
		context:addOption("Remove Anti Theft Strips", items, WWP_InventoryMenu.removeStrips)
	end

	if needsStrips then
		local strips = player:getInventory():getAllTypeRecurse("Base.AntiTheftStrip")
		if strips:size() > 0 then
			context:addOption("Apply Anti Theft Strips", items, WWP_InventoryMenu.applyStrips, strips, currentWorkplace)
		end
	end
end

function WWP_InventoryMenu.removeStrips(items)
	local player = getPlayer()
	for _, item in ipairs(items) do
		if item:getModData().WWP_ATS_Applied then
			ISInventoryPaneContextMenu.transferIfNeeded(player, item)
			ISTimedActionQueue.add(WWP_RemoveStripAction:new(player, item))
		end
	end
end

function WWP_InventoryMenu.applyStrips(items, strips, workplace)
	local i = 0
	local player = getPlayer()
	for _, item in ipairs(items) do
		if not item:getModData().WWP_ATS_Applied and i < strips:size() then
			local strip = strips:get(i)
			i = i + 1
			if strip then
				ISInventoryPaneContextMenu.transferIfNeeded(player, item)
				ISInventoryPaneContextMenu.transferIfNeeded(player, strip)
				ISTimedActionQueue.add(WWP_AddStripAction:new(player, item, strip, workplace.id))
			end
		end
	end
end

Events.OnFillInventoryObjectContextMenu.Add(WWP_InventoryMenu.doMenu)