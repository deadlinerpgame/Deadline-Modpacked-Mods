-- Override the right click on container icon menu in the inventory page
-- to add the freeze and lock options
local original_ISInventoryPage_new = ISInventoryPage.onBackpackRightMouseDown
function ISInventoryPage:onBackpackRightMouseDown(x, y)
    local result = original_ISInventoryPage_new(self, x, y)
    local page = self.parent
    local container = self.inventory
    local player = getPlayer()
    local context = getPlayerContextMenu(page.player)
    if not context or not context:isReallyVisible() then
        context = ISContextMenu.get(page.player, getMouseX(), getMouseY())
    end

    if WL_Utils.isAtLeastGM(player) then
        local descriptions = WLL.GetContainerDescriptions(self.inventory)
        for _, description in ipairs(descriptions) do
            context:addOption(description)
        end
    end
    for _, system in ipairs(WLL.Systems) do
        system.OnContainerContext(player, context, container)
    end
    if context.numOptions > 0 then
        context.forceVisible = true
        context:setVisible(true)
    else
        context.forceVisible = false
        context:setVisible(false)
    end
    return result
end

-- refresh backpacks is called to determine which items to display in the inventory
-- if its a locked container, and the player is not staff, then remove any items it has
-- in it's itemslist
local original_ISInventoryPage_refreshBackpacks = ISInventoryPage.refreshBackpacks
function ISInventoryPage:refreshBackpacks()
    local result = original_ISInventoryPage_refreshBackpacks(self)
    local player = getPlayer()

    if not WLL.CanViewContainer(player, self.inventory) then
        self.inventoryPane.itemslist = {}
        self.inventoryPane:updateScrollbars()
        self.inventoryPane.inventory:setDrawDirty(false)
    end

    return result
end

-- Override the render to add some indication that the container is locked or frozen
local original_ISInventoryPage_prerender = ISInventoryPage.prerender
function ISInventoryPage:prerender()
    local result = original_ISInventoryPage_prerender(self)
    local container = self.inventory

    local text = WLL.GetContainerTitle(container)

    if text then
        if not self.onCharacter then
            local w = self.lootAll:getRight() + 10
            if self.toggleStove.visible then
                w = self.toggleStove:getRight() + 10
            elseif self.removeAll.visible then
                w = self.removeAll:getRight() + 10
            end
            self:drawText(text, w, 1, 1, 1, 1, 1, UIFont.Small)
        else
            local textWidth = getTextManager():MeasureStringX(UIFont.Small, text)
            local w = self.transferAll:getX() - textWidth - 10
            self:drawText(text, w, 1, 1, 1, 1, 1, UIFont.Small)
        end
    end

    if not WLL.CanViewContainer(getPlayer(), self.inventory) then
        local lockedText = "Locked"

        if WLL.CanPutIntoContainer(getPlayer(), self.inventory) then
            lockedText = "Drop Box"
        end

        local lockedTextFont = UIFont.NewLarge
        local lockedTextWidth = getTextManager():MeasureStringX(lockedTextFont, lockedText)
        local lockedTextHeight = getTextManager():MeasureStringY(lockedTextFont, lockedText)

        local x = self.inventoryPane.width / 2 - lockedTextWidth / 2
        local y = self.inventoryPane.height / 2 - lockedTextHeight / 2
        self:drawText(lockedText, x, y, 1, 0.4, 0.4, 1, lockedTextFont)

        if #self.inventoryPane.itemslist > 0 then
            self.inventoryPane.itemslist = {}
            self.inventoryPane:updateScrollbars()
            self.inventoryPane.inventory:setDrawDirty(false)
        end
    end

    return result
end

local original_ISInventoryPage_addContainerButton = ISInventoryPage.addContainerButton
function ISInventoryPage:addContainerButton(container, texture, name, tooltip)
    local button = original_ISInventoryPage_addContainerButton(self, container, texture, name, tooltip)
    if not WLL.CanViewContainer(getPlayer(), container) then
        if WLL.CanPutIntoContainer(getPlayer(), container) then
            button:setTextureRGBA(1.0, 1.0, 0.4, 1.0) -- Yellow: dropbox
        else
            button:setTextureRGBA(1.0, 0.4, 0.4, 1.0) -- Red: locked and can't view
        end
    elseif WLL.IsAnyLocked(container) then
        button:setTextureRGBA(0.4, 1.0, 0.4, 1.0) -- Green: locked but can view
    elseif WLL.Frozen.IsFrozen(container) then
        button:setTextureRGBA(0.4, 0.4, 1.0, 1.0) -- Blue: frozen
    end
    return button
end