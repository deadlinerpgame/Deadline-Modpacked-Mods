WCL_KeepItemOnLoadout = {}

if WCL_KeepItemOnLoadout.contextMenu then
    Events.OnFillInventoryObjectContextMenu.Remove(WCL_KeepItemOnLoadout.contextMenu)
end

function WCL_KeepItemOnLoadout.contextMenu(playerId, context, items)
    local player = getSpecificPlayer(playerId)
    if not player then return end

    if not WL_Utils.isStaff(player) then
        return
    end

    items = ISInventoryPane.getActualItems(items)

    if not items or #items == 0 then
        return
    end

    local firstItem = items[1]
    if not firstItem then return end

    if not firstItem:isInPlayerInventory() then
        return
    end

    local inverseState = true
    if firstItem:getModData().WL_keepLoadout then
        inverseState = false
    end

    local menuText = "Removable on Loadouts"
    local tooltipText = "Allow this item to be removed when swapping loadouts."
    if inverseState then
        menuText = "Keep Between Loadouts"
        tooltipText = "This item will not be removed when swapping loadouts."
    end
    local option = context:addOption(menuText, WCL_KeepItemOnLoadout, WCL_KeepItemOnLoadout.setKeepLoadout, player, items, inverseState)
    local tooltip = ISToolTip:new()
    tooltip:initialise()
    tooltip.description = tooltipText
    option.toolTip = tooltip
end

function WCL_KeepItemOnLoadout:setKeepLoadout(player, items, keepLoadout)
    for _, item in ipairs(items) do
        item:getModData().WL_keepLoadout = keepLoadout
    end
end

Events.OnFillInventoryObjectContextMenu.Add(WCL_KeepItemOnLoadout.contextMenu)

WCL_KeepItemOnLoadout.keepTex = getTexture("media/ui/WCL_KeepLoadout.png")
local previousRenderDetails = ISInventoryPane.renderdetails
function ISInventoryPane:renderdetails(doDragged)
    previousRenderDetails(self, doDragged)

    local player = getSpecificPlayer(self.player)
     if not WL_Utils.isStaff(player) then
        return
    end

    if not WCL_KeepItemOnLoadout.keepTex then
        return
    end

    local y = 0
    local MOUSEX = self:getMouseX()
    local MOUSEY = self:getMouseY()
    local YSCROLL = self:getYScroll()
    local HEIGHT = self:getHeight()
    -- Go through all the stacks of items.
    for k, v in ipairs(self.itemslist) do
        local count = 1
        -- Go through each item in stack..
        for k2, v2 in ipairs(v.items) do
            local item = v2
            local doIt = true
            local xoff = 0
            local yoff = 0
            local isDragging = false
            if self.dragging ~= nil and self.selected[y+1] ~= nil and self.dragStarted then
                xoff = MOUSEX - self.draggingX
                yoff = MOUSEY - self.draggingY
                if not doDragged then
                    doIt = false
                else
                    isDragging = true
                end
            else
                if doDragged then
                    doIt = false
                end
            end
            local topOfItem = y * self.itemHgt + YSCROLL
            if not isDragging and ((topOfItem + self.itemHgt < 0) or (topOfItem > HEIGHT)) then
                doIt = false
            end
            if doIt == true then
                -- only do icon if header or dragging sub items without header.
                local tex = item:getTex()
                if tex ~= nil then
                    local auxDXY = math.ceil(20 * self.texScale)
                    if count == 1  then
                        if item:getModData().WL_keepLoadout then
                            self:drawTexture(WCL_KeepItemOnLoadout.keepTex, (26+auxDXY+xoff), (y*self.itemHgt)+self.headerHgt-1+yoff, 1, 1, 1, 1);
                        end
                    elseif v.count > 2 or (doDragged and count > 1 and self.selected[(y+1) - (count-1)] == nil) then
                        if item:getModData().WL_keepLoadout then
                            self:drawTexture(WCL_KeepItemOnLoadout.keepTex, (26+auxDXY+16+xoff), (y*self.itemHgt)+self.headerHgt-1+yoff, 1, 1, 1, 1);
                        end
                    end
                end
            end

            y = y + 1;

            if count == 1 and self.collapsed ~= nil and v.name ~= nil and self.collapsed[v.name] then
                break
            end
            if count == ISInventoryPane.MAX_ITEMS_IN_STACK_TO_RENDER + 1 then
                break
            end
            count = count + 1;
        end
    end
end