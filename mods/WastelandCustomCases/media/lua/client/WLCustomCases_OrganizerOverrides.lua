require "WLCustomCases_OrganizerShared"
require "WLCustomCases_OrganizerClient"
require "WLCustomCases_Piles"
require "WLCustomCases_AlwaysShowing"
require "WLCustomCases_FreeWeight"

WLCustomCases = WLCustomCases or {}

local Organizer = WLCustomCases.Organizer
local Piles = WLCustomCases.Piles
local AlwaysShowing = WLCustomCases.AlwaysShowing
local FreeWeight = WLCustomCases.FreeWeight

local processedContainers = {}

local function ApplyVirtualButtonLayout(inventoryPage, button, virtualData, index)
    if not button or not virtualData or button.MovedVirtual then
        return
    end
    local reduction = math.floor(inventoryPage.buttonSize * 0.25)
    local y = ((index - 1) * inventoryPage.buttonSize) + inventoryPage:titleBarHeight() - 1 + reduction
    button:setWidth(inventoryPage.buttonSize - reduction)
    button:setHeight(inventoryPage.buttonSize - reduction)
    button:setX(inventoryPage.width - inventoryPage.buttonSize + reduction)
    button:setY(y)
    button:forceImageSize(math.min(inventoryPage.buttonSize - 2 - reduction, math.floor(32 * reduction)), math.min(inventoryPage.buttonSize - 2 - reduction, math.floor(32 * reduction)))
    button.MovedVirtual = true
end

local function RefreshInventoryPages(playerNum)
    ISInventoryPage.renderDirty = true
    local pdata = getPlayerData(playerNum)
    pdata.lootInventory:refreshBackpacks()
    pdata.lootInventory.inventoryPane:refreshContainer()
    pdata.playerInventory:refreshBackpacks()
    pdata.playerInventory.inventoryPane:refreshContainer()
end

local original_ISInventoryTransferAction_new = ISInventoryTransferAction.new
function ISInventoryTransferAction:new(character, item, srcContainer, destContainer, time)
    if not srcContainer or not destContainer then
        return original_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
    end
    local srcItem = srcContainer:getContainingItem()
    local destItem = destContainer:getContainingItem()
    if (Piles and Piles.IsFastPileItem and Piles.IsFastPileItem(srcItem))
        or (Piles and Piles.IsFastPileItem and Piles.IsFastPileItem(destItem)) then
        time = 5
    end

    if Organizer.IsStorageOrganizer(srcItem) then
        Organizer.EnsureOrganizerId(srcItem)
    end

    local action = original_ISInventoryTransferAction_new(self, character, item, srcContainer, destContainer, time)
    if type(action) ~= "table" or action.ignoreAction then
        return action
    end

    local realSrc, srcVirtual = Organizer.ResolveContainer(srcContainer)
    local realDest, destVirtual = Organizer.ResolveContainer(destContainer)
    if not srcVirtual and not destVirtual then
        return action
    end

    if destVirtual
        and destVirtual.mode == Organizer.VIRTUAL_MODE_ORGANIZER
        and Organizer.IsStorageOrganizer(srcItem) then
        return { ignoreAction = true }
    end

    if realSrc == realDest then
        action.maxTime = 5
    end

    if destVirtual
        and destVirtual.mode == Organizer.VIRTUAL_MODE_ORGANIZER
        and Organizer.IsStorageOrganizer(destItem) then
        return { ignoreAction = true }
    end

    local organizerId, clear = Organizer.GetOrganizerChange(srcVirtual, destVirtual)
    action.WLCustomCases_virtual = {
        srcVirtual = srcVirtual,
        destVirtual = destVirtual,
        realSrc = realSrc,
        realDest = realDest,
        organizerId = organizerId,
        clear = clear,
    }

    local original_isValid = action.isValid
    function action:isValid()
        local virtual = self.WLCustomCases_virtual
        if not virtual then
            return original_isValid(self)
        end

        local mappedSrc = virtual.realSrc or self.srcContainer
        local mappedDest = virtual.realDest or self.destContainer
        if mappedSrc == mappedDest then
            return Organizer.ShouldApplyOrganizerChange(self.item, virtual.organizerId, virtual.clear)
        end

        local originalSrc = self.srcContainer
        local originalDest = self.destContainer
        self.srcContainer = mappedSrc
        self.destContainer = mappedDest
        local valid = original_isValid(self)
        self.srcContainer = originalSrc
        self.destContainer = originalDest
        return valid
    end

    local original_transferItem = action.transferItem
    function action:transferItem(itemToTransfer)
        local virtual = self.WLCustomCases_virtual
        if not virtual then
            return original_transferItem(self, itemToTransfer)
        end

        local mappedSrc = virtual.realSrc or self.srcContainer
        local mappedDest = virtual.realDest or self.destContainer
        local shouldChange = Organizer.ShouldApplyOrganizerChange(itemToTransfer, virtual.organizerId, virtual.clear)
        if mappedSrc == mappedDest then
            if shouldChange then
                Organizer.ApplyOrganizerChange(self.character, itemToTransfer, mappedDest, virtual.organizerId, virtual.clear, true)
            end

            RefreshInventoryPages(self.character:getPlayerNum())
            return
        end

        if shouldChange then
            Organizer.ApplyOrganizerChange(self.character, itemToTransfer, mappedDest, virtual.organizerId, virtual.clear, false)
        end

        local originalSrc = self.srcContainer
        local originalDest = self.destContainer
        self.srcContainer = mappedSrc
        self.destContainer = mappedDest
        original_transferItem(self, itemToTransfer)
        self.srcContainer = originalSrc
        self.destContainer = originalDest

        RefreshInventoryPages(self.character:getPlayerNum())
    end

    return action
end

local function OnRefreshInventoryWindowContainers(inventoryPage, eventType)
    if eventType == "begin" then
        processedContainers = {}
        return
    end

    if eventType == "buttonsAdded" then
        AlwaysShowing.AddContainerButtons(inventoryPage)
        return
    end

    if eventType == "end" then
        FreeWeight.Apply()
    end
end

local original_ISInventoryPage_addContainerButton = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
    local button = original_ISInventoryPage_addContainerButton(self, container, texture, name, tooltip)
    if not button or not container or self.onCharacter then
        return button
    end
    button:setWidth(self.buttonSize)
    button:setHeight(self.buttonSize)
    button:forceImageSize(math.min(self.buttonSize - 2, 32), math.min(self.buttonSize - 2, 32))
    button.MovedVirtual = false

    local containerType = container:getType()
    if containerType == "floor" or containerType == "local" or containerType == "proxInv" then
        return button
    end
    if processedContainers[container] then
        return button
    end

    processedContainers[container] = true
    local organizers = Organizer.GetOrganizersInContainer(container)
    if #organizers == 0 then
        return button
    end

    local index = #self.backpacks
    local baseName = "Unorganized"
    local baseTooltip = "Unorganized"
    local unorganized = Organizer.GetOrCreateVirtualContainer(
        self.player,
        container,
        Organizer.VIRTUAL_MODE_UNORGANIZED
    )
    local playerObj = getSpecificPlayer(self.player)
    local unorganizedButton = original_ISInventoryPage_addContainerButton(
        self,
        unorganized,
        button.image,
        baseName,
        baseTooltip
    )
    if unorganizedButton then
        index = index + 1
        unorganizedButton.MovedVirtual = false
        unorganizedButton.capacity = container:getEffectiveCapacity(playerObj)
        unorganizedButton.name = baseName
        unorganizedButton.tooltip = baseTooltip
        ApplyVirtualButtonLayout(self, unorganizedButton, Organizer.GetVirtualContainerData(unorganized), index)
    end
    if self.inventoryPane and self.inventoryPane.lastinventory == container then
        self.inventoryPane.lastinventory = unorganized
    end

    for _, organizer in ipairs(organizers) do
        local virtualContainer = Organizer.GetOrCreateVirtualContainer(
            self.player,
            container,
            Organizer.VIRTUAL_MODE_ORGANIZER,
            organizer.id
        )
        local organizerButton = original_ISInventoryPage_addContainerButton(
            self,
            virtualContainer,
            organizer.item:getTex(),
            organizer.item:getName(),
            organizer.item:getName()
        )
        if organizerButton then
            index = index + 1
            organizerButton.MovedVirtual = false
            organizerButton.capacity = container:getEffectiveCapacity(playerObj)
            ApplyVirtualButtonLayout(self, organizerButton, Organizer.GetVirtualContainerData(virtualContainer), index)
        end
    end

    return button
end

local original_ISInventoryPage_refreshWeight = ISInventoryPage.refreshWeight
function ISInventoryPage:refreshWeight()
    original_ISInventoryPage_refreshWeight(self)
    FreeWeight.Apply()
end

local original_ISInventoryPage_loadWeight = ISInventoryPage.loadWeight
function ISInventoryPage.loadWeight(inv)
    if inv then
        local virtualData = Organizer.GetVirtualContainerData(inv)
        if virtualData and virtualData.parent then
            inv = virtualData.parent
        end
    end
    return original_ISInventoryPage_loadWeight(inv)
end

local original_ISInventoryPage_update = ISInventoryPage.update
function ISInventoryPage:update()
    original_ISInventoryPage_update(self)
    if self.inventory then
        local virtualData = Organizer.GetVirtualContainerData(self.inventory)
        if virtualData and virtualData.parent then
            local playerObj = getSpecificPlayer(self.player)
            self.capacity = virtualData.parent:getEffectiveCapacity(playerObj)
        end
    end
end

local original_ISInventoryPane_refreshContainer = ISInventoryPane.refreshContainer
function ISInventoryPane:refreshContainer()
    if not self.inventory then
        return original_ISInventoryPane_refreshContainer(self)
    end

    local virtualData = Organizer.GetVirtualContainerData(self.inventory)
    if not virtualData or not virtualData.parent then
        return original_ISInventoryPane_refreshContainer(self)
    end

    local originalInventory = self.inventory
    self.inventory = virtualData.parent
    local result = original_ISInventoryPane_refreshContainer(self)
    self.inventory = originalInventory

    local organizerIdMap = nil
    if virtualData.mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
        organizerIdMap = Organizer.BuildOrganizerIdMap(virtualData.parent)
    end

    local filteredItemsList = {}
    for i = 1, #self.itemslist do
        local entry = self.itemslist[i]
        local newItemsEntry = {}
        for j = 1, #entry.items do
            local item = entry.items[j]
            local itemOrganizerId = Organizer.GetOrganizerId(item)
            local addItem = true
            if virtualData.mode == Organizer.VIRTUAL_MODE_ORGANIZER then
                if itemOrganizerId ~= virtualData.organizerId or Organizer.IsStorageOrganizer(item) then
                    addItem = false
                end
            elseif virtualData.mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
                if itemOrganizerId
                    and organizerIdMap
                    and organizerIdMap[itemOrganizerId] then
                    addItem = false
                end
            end
            if addItem then
                table.insert(newItemsEntry, item)
            end
        end

        if #newItemsEntry > 0 then
            local weight = 0
            for j = 1, #newItemsEntry do
                weight = weight + newItemsEntry[j]:getUnequippedWeight()
            end
            table.insert(filteredItemsList, {
                items = newItemsEntry,
                name = entry.name,
                invPanel = entry.invPanel,
                cat = entry.cat,
                count = #newItemsEntry,
                weight = weight,
                equipped = entry.equipped,
                inHotbar = entry.inHotbar,
            })
        end
    end

    self.itemslist = filteredItemsList
    self:updateScrollbars()
    self.inventory:setDrawDirty(false)

    return result
end

local original_ISInventoryPane_update = ISInventoryPane.update
function ISInventoryPane:update()
    if self.inventory then
        local virtualData = Organizer.GetVirtualContainerData(self.inventory)
        if virtualData and virtualData.parent then
            local originalInventory = self.inventory
            self.inventory = virtualData.parent
            original_ISInventoryPane_update(self)
            self.inventory = originalInventory
            return
        end
    end
    original_ISInventoryPane_update(self)
end

local function BuildFilteredVirtualItems(virtualData)
    if not virtualData or not virtualData.parent then
        return {}
    end

    local organizerIdMap = nil
    if virtualData.mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
        organizerIdMap = Organizer.BuildOrganizerIdMap(virtualData.parent)
    end

    local filteredItems = {}
    local items = virtualData.parent:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        local itemOrganizerId = Organizer.GetOrganizerId(item)
        local addItem = true
        if virtualData.mode == Organizer.VIRTUAL_MODE_ORGANIZER then
            if itemOrganizerId ~= virtualData.organizerId or Organizer.IsStorageOrganizer(item) then
                addItem = false
            end
        elseif virtualData.mode == Organizer.VIRTUAL_MODE_UNORGANIZED then
            if itemOrganizerId
                and organizerIdMap
                and organizerIdMap[itemOrganizerId] then
                addItem = false
            end
        end

        if addItem then
            table.insert(filteredItems, item)
        end
    end

    return filteredItems
end

local function IsStorageOrganizerWithContents(item)
    if not Organizer.IsStorageOrganizer(item) then
        return false
    end
    if item and item.getInventory then
        local inv = item:getInventory()
        if inv and not inv:isEmpty() then
            return true
        end
    end
    return false
end

local original_ISInventoryPane_lootAll = ISInventoryPane.lootAll
function ISInventoryPane:lootAll()
    if self.inventory then
        local virtualData = Organizer.GetVirtualContainerData(self.inventory)
        if virtualData and virtualData.parent then
            local playerObj = getSpecificPlayer(self.player)
            local playerInv = getPlayerInventory(self.player).inventory
            local items = BuildFilteredVirtualItems(virtualData)
            local transferable = {}
            local heavyItem = nil

            if luautils.walkToContainer(virtualData.parent, self.player) then
                for _, item in ipairs(items) do
                    if IsStorageOrganizerWithContents(item) then
                        -- Skip looting organizers that contain items.
                    elseif isForceDropHeavyItem(item) then
                        heavyItem = item
                    else
                        table.insert(transferable, item)
                    end
                end
                if heavyItem and #items == 1 then
                    ISInventoryPaneContextMenu.equipHeavyItem(playerObj, heavyItem)
                    return
                end
                self:transferItemsByWeight(transferable, playerInv)
            end

            self.selected = {}
            getPlayerLoot(self.player).inventoryPane.selected = {}
            getPlayerInventory(self.player).inventoryPane.selected = {}
            return
        end
    end

    return original_ISInventoryPane_lootAll(self)
end

local function OnPreFillInventoryObjectContextMenu(player, context, items)
    local item = nil
    for i, v in ipairs(items) do
        item = v
        if not instanceof(v, "InventoryItem") then
            item = v.items[1]
        end
    end

    if item and Organizer.IsStorageOrganizer(item) and WL_RenameItem then
        context:addOption("Rename " .. item:getName(), item, WL_RenameItem.onRenameItem, player)
    end
end

Events.OnRefreshInventoryWindowContainers.Add(OnRefreshInventoryWindowContainers)
Events.OnPreFillInventoryObjectContextMenu.Add(OnPreFillInventoryObjectContextMenu)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "WLCustomCases" then
        return
    end
    if command ~= "refreshOrganizerContainer" then
        return
    end
    local container = Organizer.ResolveContainerFromServerArgs(args)
    if container then
        container:requestServerItemsForContainer()
    end
end)
