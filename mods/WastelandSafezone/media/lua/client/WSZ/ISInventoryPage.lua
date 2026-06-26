-- refresh backpacks is called to determine which items to display in the inventory
-- if its a locked container, and the player is not staff, then remove any items it has
-- in it's itemslist
local original_ISInventoryPage_refreshBackpacks = ISInventoryPage.refreshBackpacks
function ISInventoryPage:refreshBackpacks()
    local result = original_ISInventoryPage_refreshBackpacks(self)

    if not self.onCharacter and not WSZ_Client.currentPermissions.canViewItems then
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

    if not self.onCharacter and not WSZ_Client.currentPermissions.canViewItems then
        local lockedText = "Safezoned"

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
