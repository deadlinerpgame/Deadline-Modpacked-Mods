local lockTexture = getTexture("media/textures/ats_lock.png")
local original_renderdetails = ISInventoryPane.renderdetails
function ISInventoryPane:renderdetails(doDragged)
	original_renderdetails(self, doDragged)

	local y = 0
	local MOUSEX = self:getMouseX()
	local MOUSEY = self:getMouseY()
	local YSCROLL = self:getYScroll()
	local HEIGHT = self:getHeight()
	for k, v in ipairs(self.itemslist) do
		local count = 1
		for k2, v2 in ipairs(v.items) do
			local item = v2
            if item:getModData().WWP_ATS_Applied then
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
                    if count == 1  then
                        self:drawTexture(lockTexture, xoff, (y*self.itemHgt)+self.headerHgt+yoff, 1, 1, 1, 1)
                    elseif v.count > 2 or (doDragged and count > 1 and self.selected[(y+1) - (count-1)] == nil) then
                        self:drawTexture(lockTexture, xoff+16, (y*self.itemHgt)+self.headerHgt+yoff, 1, 1, 1, 1)
                    end
				end
			end
			y = y + 1
			if count == 1 and self.collapsed ~= nil and v.name ~= nil and self.collapsed[v.name] then
				break
			end
			if count == 51 then
				break
			end
			count = count + 1
		end
	end
end