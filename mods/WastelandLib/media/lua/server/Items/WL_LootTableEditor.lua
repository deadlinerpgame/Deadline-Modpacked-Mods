---
--- WL_LootTableEditor.lua
--- Utility class to modify and debug loot tables
--- Written on 11/07/2023
--- Used to be named LootTableEditor and live in the ZoomiesZombieLoot mod
--- Moved here on 06/10/2024
---

WL_LootTableEditor = {}

--- Controls logging for addItemToExistingDistribution.
--- Set to true to print matched table locations.
WL_LootTableEditor.DEBUG_ADD_ITEM_TO_EXISTING_DISTRIBUTION = false

local function findItemIndex(tableToModify, itemClass)
	for i = 1, #tableToModify, 2 do
		if tableToModify[i] == itemClass then
			return i -- Return the index of the item
		end
	end
	return nil -- Return nil if itemClass is not found
end

local function removeItem(tableToModify, itemClass)
	if not tableToModify then return end

	local indexToRemove = findItemIndex(tableToModify, itemClass)
	while indexToRemove do
		table.remove(tableToModify, indexToRemove + 1) -- Remove the number following the item
		table.remove(tableToModify, indexToRemove) -- Remove the item itself
		indexToRemove = findItemIndex(tableToModify, itemClass) --Check if the item is still there
	end
end

local function removeFromSubTables(tableToModify, itemClass)
	for subTableName, subTableContent in pairs(tableToModify) do
		if type(subTableContent) == "table" then
			if subTableContent.items then
				removeItem(subTableContent.items, itemClass)
			end
			if subTableContent.junk and subTableContent.junk.items then
				removeItem(subTableContent.junk.items, itemClass)
			end
			-- Recursively handle sub-tables like procList
			removeFromSubTables(subTableContent, itemClass)
		end
	end
end

local function addMappedItemToItemsTable(itemsTable, itemToMap, itemToAdd, weighting, tableLabel, addedTableLabels, addedTableLabelSet)
	if not itemsTable then return 0 end

	local mappedItemIndex = findItemIndex(itemsTable, itemToMap)
	if not mappedItemIndex then return 0 end

	table.insert(itemsTable, itemToAdd)
	table.insert(itemsTable, weighting)
	if not addedTableLabelSet[tableLabel] then
		addedTableLabelSet[tableLabel] = true
		table.insert(addedTableLabels, tableLabel)
	end
	return 1
end

local function addMappedItemToSubTables(tableToModify, parentLabel, itemToMap, itemToAdd, weighting, addedTableLabels, addedTableLabelSet)
	local modifiedTables = 0

	for subTableName, subTableContent in pairs(tableToModify) do
		if type(subTableContent) == "table" then
			local tableLabel = parentLabel .. "." .. tostring(subTableName)

			if subTableContent.items then
				modifiedTables = modifiedTables + addMappedItemToItemsTable(subTableContent.items, itemToMap, itemToAdd, weighting, tableLabel .. ".items", addedTableLabels, addedTableLabelSet)
			end
			if subTableContent.junk and subTableContent.junk.items then
				modifiedTables = modifiedTables + addMappedItemToItemsTable(subTableContent.junk.items, itemToMap, itemToAdd, weighting, tableLabel .. ".junk.items", addedTableLabels, addedTableLabelSet)
			end

			modifiedTables = modifiedTables + addMappedItemToSubTables(subTableContent, tableLabel, itemToMap, itemToAdd, weighting, addedTableLabels, addedTableLabelSet)
		end
	end

	return modifiedTables
end

function WL_LootTableEditor.removeFromAllTables(itemClass)
	for tableName, tableContent in pairs(ProceduralDistributions.list) do
		if tableContent.items then
			removeItem(tableContent.items, itemClass)
		end
		if tableContent.junk and tableContent.junk.items then
			removeItem(tableContent.junk.items, itemClass)
		end
	end

	for tableName, tableContent in pairs(Distributions) do
		if type(tableContent) == "table" then
			for subTableName, subTableContent in pairs(tableContent) do
				if type(subTableContent) == "table" then
					if subTableContent.items then
						removeItem(subTableContent.items, itemClass)
					end
					if subTableContent.junk and subTableContent.junk.items then
						removeItem(subTableContent.junk.items, itemClass)
					end
				end
			end
			if tableName == "all" then
				removeFromSubTables(tableContent, itemClass)
			end
		end
	end

	for tableName, tableContent in pairs(VehicleDistributions) do
		if type(tableContent) == "table" then
			if tableContent.items then
				removeItem(tableContent.items, itemClass)
			end
			if tableContent.junk and tableContent.junk.items then
				removeItem(tableContent.junk.items, itemClass)
			end
		end
	end
end

function WL_LootTableEditor.removeFromProceduralDistributions(tableName, itemClass)
	local tableContent = ProceduralDistributions.list[tableName]
	if tableContent then
		if tableContent.items then
			removeItem(tableContent.items, itemClass)
		end
	end
end

function WL_LootTableEditor.setProceduralDistributionsWeighting(tableName, itemClass, newWeighting)
	local tableToModify = ProceduralDistributions.list[tableName]
	if not tableToModify or not tableToModify.items then return end

	local indexToModify = findItemIndex(tableToModify.items, itemClass)
	if indexToModify then
		tableToModify.items[indexToModify + 1] = newWeighting
	end
end

function WL_LootTableEditor.addItemToProceduralDistributions(tableName, itemClass, weighting)
	local tableToModify = ProceduralDistributions.list[tableName] or VehicleDistributions[tableName]
	if not tableToModify or not tableToModify.items then
		print("WL_LootTableEditor: Unable to add item to ProceduralDistributions - " .. tableName .. " does not exist or has no items.")
		return
	end

	table.insert(tableToModify.items, itemClass)
	table.insert(tableToModify.items, weighting)
end

--- Adds an item to every distribution table where another item already exists.
---@param itemToMap string Existing item to search for in distributions
---@param itemToAdd string New item to add to matching distributions
---@param weighting number Weighting to use for the new item
---@param includeDistributions boolean|nil When true, also scans Distributions (default false)
---@param includeVehicles boolean|nil When false, skips VehicleDistributions (default true)
---@return number modifiedTables Number of matching item tables modified
function WL_LootTableEditor.addItemToExistingDistribution(itemToMap, itemToAdd, weighting, includeDistributions, includeVehicles)
	local modifiedTables = 0
	local addedTableLabels = {}
	local addedTableLabelSet = {}
	local shouldIncludeDistributions = includeDistributions == true
	local shouldIncludeVehicles = includeVehicles ~= false
	local shouldPrintDebug = WL_LootTableEditor.DEBUG_ADD_ITEM_TO_EXISTING_DISTRIBUTION == true

	modifiedTables = modifiedTables + addMappedItemToSubTables(ProceduralDistributions.list, "ProceduralDistributions.list", itemToMap, itemToAdd, weighting, addedTableLabels, addedTableLabelSet)
	if shouldIncludeDistributions then
		modifiedTables = modifiedTables + addMappedItemToSubTables(Distributions, "Distributions", itemToMap, itemToAdd, weighting, addedTableLabels, addedTableLabelSet)
	end
	if shouldIncludeVehicles then
		modifiedTables = modifiedTables + addMappedItemToSubTables(VehicleDistributions, "VehicleDistributions", itemToMap, itemToAdd, weighting, addedTableLabels, addedTableLabelSet)
	end

	if shouldPrintDebug then
		if modifiedTables == 0 then
			print("WL_LootTableEditor: addItemToExistingDistribution found no distributions containing " .. itemToMap)
		else
			for i = 1, #addedTableLabels do
				print("WL_LootTableEditor: addItemToExistingDistribution added " .. itemToAdd .. " to " .. addedTableLabels[i])
			end
		end
	end

	return modifiedTables
end

--- Given a loot table in the IS structure { "item", weighting, "item2", weighting2" } this function strips all
--- entries for a given itemName.
---@param itemName string must match exactly (don't include Base. if the table doesn't)
---@param itemTable table must be the table with the item number pairs, can be nil (then we do nothing)
function WL_LootTableEditor.removeFromDistributionTable(itemName, itemTable)
	if not itemTable then return end
	local i = 1
	while i <= #itemTable do
		if itemTable[i] == itemName then
			table.remove(itemTable, i) -- Remove the item name
			table.remove(itemTable, i) -- Remove the associated number
		else
			i = i + 2
		end
	end
end

---@param item string
---@param weightBothOrMale number
---@param weightFemale number|nil
function WL_LootTableEditor.addZombieLootItem(item, weightBothOrMale, weightFemale)
	if not weightFemale then weightFemale = weightBothOrMale end
	if weightBothOrMale > 0 then
		table.insert(SuburbsDistributions["all"]["inventorymale"].items, item);
		table.insert(SuburbsDistributions["all"]["inventorymale"].items, weightBothOrMale);
	end
	if weightFemale > 0 then
		table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, item);
		table.insert(SuburbsDistributions["all"]["inventoryfemale"].items, weightFemale);
	end
end

local function lootTableToString(tbl, indent)
	indent = indent or 0
	local result = ""
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			result = result .. string.rep(" ", indent) .. key .. " = {\n"
			result = result .. lootTableToString(value, indent + 4)
			result = result .. string.rep(" ", indent) .. "},\n"
		else
			if type(key) == "number" then
				if key % 2 == 0 then
					result = result .. string.rep(" ", indent) .. '"' .. tbl[key - 1] .. '": ' .. tostring(value) .. ",\n"
				end
			end
		end
	end
	return result
end

function WL_LootTableEditor.printAllProceduralDistributions()
	local listAsString = "ProceduralDistributions.list = {\n"
	listAsString = listAsString .. lootTableToString(ProceduralDistributions.list, 4)
	listAsString = listAsString .. "}\n"

	local fileWriterObj = getFileWriter("ProceduralDistributions.txt", true, false)
	fileWriterObj:write(listAsString)
	fileWriterObj:close()
end

function WL_LootTableEditor.printAllDistributions()
	local listAsString = "Distributions = {\n"
	listAsString = listAsString .. lootTableToString(Distributions, 4)
	listAsString = listAsString .. "}\n"

	local fileWriterObj = getFileWriter("Distributions.txt", true, false)
	fileWriterObj:write(listAsString)
	fileWriterObj:close()
end

