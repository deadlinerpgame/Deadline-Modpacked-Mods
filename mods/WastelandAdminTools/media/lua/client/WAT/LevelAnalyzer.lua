-- Extracted from: BetterTilesPicker
-- https://steamcommunity.com/sharedfiles/filedetails/?id=2792714394
-- Modified by: Gravy

local instance = nil
function WAT_ShowLevelAnalyzer()
    if instance then
        instance:close()
    end
    instance = WAT_LevelAnalyzer:new()
    instance:initialise()
    instance:addToUIManager()
end

ISWAT_ScrollingListBox = ISPanelJoypad:derive("ISWAT_ScrollingListBox");
ISWAT_ScrollingListBox.joypadListIndex = 1;

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)

function ISWAT_ScrollingListBox:initialise()
    ISPanelJoypad.initialise(self);
end

function ISWAT_ScrollingListBox:setJoypadFocused(focused, joypadData)
    if focused then
        joypadData.focus = self;
        updateJoypadFocus(joypadData);
        if self.selected == -1 then
            self.selected = 1;
            if self.resetSelectionOnChangeFocus then
                if self.items[self.selectedBeforeReset] then
                    self.selected = self.selectedBeforeReset
                end
                self.selectedBeforeReset = nil
            end
            if self.onmousedown and self.items[self.selected] then
                self.onmousedown(self.target, self.items[self.selected].item);
            end
        end
    end
    self.joypadFocused = focused;
end

function ISWAT_ScrollingListBox:onJoypadDirRight(joypadData)
    if self.joypadParent then
        self.joypadParent:onJoypadDirRight(joypadData);
    end
end

function ISWAT_ScrollingListBox:onJoypadDirLeft(joypadData)
    if self.joypadParent then
        self.joypadParent:onJoypadDirLeft(joypadData);
    end
end

function ISWAT_ScrollingListBox:instantiate()

	--self:initialise();
	self.javaObject = UIElement.new(self);
	self.javaObject:setX(self.x);
	self.javaObject:setY(self.y);
	self.javaObject:setHeight(self.height);
	self.javaObject:setWidth(self.width);
	self.javaObject:setAnchorLeft(self.anchorLeft);
	self.javaObject:setAnchorRight(self.anchorRight);
	self.javaObject:setAnchorTop(self.anchorTop);
	self.javaObject:setAnchorBottom(self.anchorBottom);
	self:addScrollBars();
end

function ISWAT_ScrollingListBox:rowAt(x, y)
	local y0 = 0
	for i,v in ipairs(self.items) do
		if not v.height then v.height = self.itemheight end -- compatibililty
		if y >= y0 and y < y0 + v.height then
			return i
		end
		y0 = y0 + v.height
	end
	return -1
end

function ISWAT_ScrollingListBox:topOfItem(index)
	local y = 0
	for k,v in ipairs(self.items) do
		if k == index then
			return y
		end
		y = y + v.height
	end
	return -1
end

function ISWAT_ScrollingListBox:prevVisibleIndex(index)
	if index <= 1 then return -1 end
	for i=index-1,1,-1 do
		local item = self.items[i]
		if item and item.height and item.height > 0 then
			return i
		end
	end
	return -1
end

function ISWAT_ScrollingListBox:nextVisibleItem(index)
	if index >= #self.items then return -1 end
	for i=index+1,#self.items do
		if self.items[i] and self.items[i].height and self.items[i].height > 0 then
			return i
		end
	end
	return -1
end

ISWAT_ScrollingListBox.nextVisibleIndex = ISWAT_ScrollingListBox.nextVisibleItem

function ISWAT_ScrollingListBox:isMouseOverScrollBar()
	return self:isVScrollBarVisible() and self.vscroll:isMouseOver()
end

function ISWAT_ScrollingListBox:onMouseMove(dx, dy)
	if self:isMouseOverScrollBar() then return end
	self.mouseoverselected = self:rowAt(self:getMouseX(), self:getMouseY())
end

function ISWAT_ScrollingListBox:onMouseMoveOutside(x, y)
	self.mouseoverselected = -1;
end

function ISWAT_ScrollingListBox:onMouseUpOutside(x, y)
	if self.vscroll then
		self.vscroll.scrolling = false;
	end
end

function ISWAT_ScrollingListBox:onMouseUp(x, y)
	if self.vscroll then
		self.vscroll.scrolling = false;
	end
end

function ISWAT_ScrollingListBox:addItem(name, item)
    local i = {}
    i.text=name;
    i.item=item;
	i.tooltip = nil;
    i.itemindex = self.count + 1;
	i.height = self.itemheight
    table.insert(self.items, i);
    self.count = self.count + 1;
    self:setScrollHeight(self:getScrollHeight()+i.height);
    return i;
end

function ISWAT_ScrollingListBox:insertItem(index, name, item)
	local i = {}
	i.text = name
	i.item = item
	i.tooltip = nil
	i.height = self.itemheight
	if #self.items == 0 or index > #self.items then
		i.itemindex = 1
		table.insert(self.items, i)
	elseif index < 1 then
		i.itemindex = 1
		table.insert(self.items, 1, i)
	else
		i.itemindex = index
		table.insert(self.items, index, i)
	end
	self.count = self.count + 1
	self:setScrollHeight(self:getScrollHeight() + i.height)
	return i
end

function ISWAT_ScrollingListBox:removeItem(itemText)
	for i,v in ipairs(self.items) do
		if v.text == itemText then
			table.remove(self.items, i);
			self.count = self.count - 1;
			if not v.height then v.height = self.itemheight end -- compatibililty
			self:setScrollHeight(self:getScrollHeight()-v.height);
			if self.selected > self.count then
				self.selected = self.count
			end
            return v;
		end
	end
    return nil;
end

function ISWAT_ScrollingListBox:removeItemByIndex(itemIndex)
	if itemIndex >= 1 and itemIndex <= #self.items then
		local item = self.items[itemIndex]
		table.remove(self.items, itemIndex)
		self.count = self.count - 1
		if not item.height then item.height = self.itemheight end -- compatibililty
		self:setScrollHeight(self:getScrollHeight() - item.height)
		if self.selected > self.count then
			self.selected = self.count
		end
		return item
	end
	return nil
end


function ISWAT_ScrollingListBox:removeFirst()
    if self.count == 0 then return end
    local item = self.items[1]
    table.remove(self.items, 0);
    self.count = self.count - 1;
	if not item.height then item.height = self.itemheight end -- compatibililty
    self:setScrollHeight(self:getScrollHeight()-item.height);
end

function ISWAT_ScrollingListBox:size()
    return self.count;
end

function ISWAT_ScrollingListBox:setOnMouseDownFunction(target, onmousedown)
	self.onmousedown = onmousedown;
	self.target = target;
end

function ISWAT_ScrollingListBox:setOnMouseDoubleClick(target, onmousedblclick)
	self.onmousedblclick = onmousedblclick;
	self.target = target;
end

function ISWAT_ScrollingListBox:doDrawItem(y, item, alt)
	if not item.height then item.height = self.itemheight end -- compatibililty
    if self.selected == item.index then
        self:drawRect(0, (y), self:getWidth(), item.height-1, 0.3, 0.7, 0.35, 0.15);

    end
	self:drawRectBorder(0, (y), self:getWidth(), item.height, 0.5, self.borderColor.r, self.borderColor.g, self.borderColor.b);
	local itemPadY = self.itemPadY or (item.height - self.fontHgt) / 2
	self:drawText(tostring(item.objindex).."."..item.text, 15, (y)+itemPadY, 0.9, 0.9, 0.9, 0.9, self.font);


	self:drawTextureScaledAspect(item.texture,0 ,(y)+itemPadY, 128, 128, 1, 1, 1, 1)

	y = y + item.height;
	return y;

end
function ISWAT_ScrollingListBox:clear()
	self.items = {}
	self.selected = 1;
	self.itemheightoverride = {}
    self.count = 0;
end

function ISWAT_ScrollingListBox:onMouseWheel(del)
	local yScroll = self.smoothScrollTargetY or self:getYScroll()
	local topRow = self:rowAt(0, -yScroll)
	if self.items[topRow] then
		if not self.smoothScrollTargetY then self.smoothScrollY = self:getYScroll() end
		local y = self:topOfItem(topRow)
		if del < 0 then
			if yScroll == -y and topRow > 1 then
				local prev = self:prevVisibleIndex(topRow)
				y = self:topOfItem(prev)
			end
			self.smoothScrollTargetY = -y;
		else
			self.smoothScrollTargetY = -(y + self.items[topRow].height);
		end
	else
		self:setYScroll(self:getYScroll() - (del*18));
	end
    return true;
end

function ISWAT_ScrollingListBox:scrollToSelected()

end

function ISWAT_ScrollingListBox.sortByName(a, b)
    return not string.sort(a.text, b.text);

end
function ISWAT_ScrollingListBox:sort()
    table.sort(self.items, ISWAT_ScrollingListBox.sortByName);
    for i,item in ipairs(self.items) do
        item.itemindex = i;
    end
end

function ISWAT_ScrollingListBox:updateTooltip()
	local row = -1
	local lx = getMouseX() - self:getAbsoluteX()
	local ly = getMouseY() - self:getAbsoluteY()
	local sbarWid = 0
	if self.vscroll and self.vscroll:getHeight() < self:getScrollHeight() then
		sbarWid = self.vscroll:getWidth()
	end
	if lx >= 0 and lx < self.width - sbarWid and ly >= 0 and ly < self.height then
		row = self:rowAt(self:getMouseX(), self:getMouseY())
		-- Hack - don't show tooltip if another window is in front
		local root = self.parent or self
		while root.parent do
			root = root.parent
		end
		local uis = UIManager.getUI()
		for i=1,uis:size() do
			local ui = uis:get(i-1)
			if ui:isMouseOver() and (not self.tooltipUI or ui ~= self.tooltipUI.javaObject) and ui ~= root.javaObject then
				row = -1
				break
			end
		end
	end
	if self.items[row] and self.items[row].tooltip then
		local text = self.items[row].tooltip
		if not self.tooltipUI then
			self.tooltipUI = ISToolTip:new()
			self.tooltipUI:setOwner(self)
			self.tooltipUI:setVisible(false)
			self.tooltipUI:setAlwaysOnTop(true)
			self.tooltipUI.maxLineWidth = 1000 -- don't wrap the lines
		end
		if not self.tooltipUI:getIsVisible() then
			self.tooltipUI:addToUIManager()
			self.tooltipUI:setVisible(true)
		end
		self.tooltipUI.description = text
		self.tooltipUI:setX(self:getMouseX() + 23)
		self.tooltipUI:setY(self:getMouseY() + 23)
	else
		if self.tooltipUI and self.tooltipUI:getIsVisible() then
			self.tooltipUI:setVisible(false)
			self.tooltipUI:removeFromUIManager()
		end
    end
end

function ISWAT_ScrollingListBox:updateSmoothScrolling()
	if not self.smoothScrollTargetY or #self.items == 0 then return end
	local dy = self.smoothScrollTargetY - self.smoothScrollY
	local maxYScroll = self:getScrollHeight() - self:getHeight()
	local frameRateFrac = UIManager.getMillisSinceLastRender() / 33.3
	local itemHeightFrac = 160 / (self:getScrollHeight() / #self.items)
	local targetY = self.smoothScrollY + dy * math.min(0.5, 0.25 * frameRateFrac * itemHeightFrac)
	if frameRateFrac > 1 then
		targetY = self.smoothScrollY + dy * math.min(1.0, math.min(0.5, 0.25 * frameRateFrac * itemHeightFrac) * frameRateFrac)
	end
	if targetY > 0 then targetY = 0 end
	if targetY < -maxYScroll then targetY = -maxYScroll end
	if math.abs(targetY - self.smoothScrollY) > 0.1 then
		self:setYScroll(targetY)
		self.smoothScrollY = targetY
	else
		self:setYScroll(self.smoothScrollTargetY)
		self.smoothScrollTargetY = nil
		self.smoothScrollY = nil
	end
end

function ISWAT_ScrollingListBox:prerender()
	if self.items == nil then
		return;
	end

	local stencilX = 0
	local stencilY = 0
	local stencilX2 = self.width
	local stencilY2 = self.height

    self:drawRect(0, -self:getYScroll(), self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	if self.drawBorder then
		self:drawRectBorder(0, -self:getYScroll(), self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
		stencilX = 1
		stencilY = 1
		stencilX2 = self.width - 1
		stencilY2 = self.height - 1
	end

	if self:isVScrollBarVisible() then
		stencilX2 = self.vscroll.x + 3 -- +3 because the scrollbar texture is narrower than the scrollbar width
	end

	-- This is to handle this listbox being inside a scrolling parent.
	if self.parent and self.parent:getScrollChildren() then
		stencilX = self.javaObject:clampToParentX(self:getAbsoluteX() + stencilX) - self:getAbsoluteX()
		stencilX2 = self.javaObject:clampToParentX(self:getAbsoluteX() + stencilX2) - self:getAbsoluteX()
		stencilY = self.javaObject:clampToParentY(self:getAbsoluteY() + stencilY) - self:getAbsoluteY()
		stencilY2 = self.javaObject:clampToParentY(self:getAbsoluteY() + stencilY2) - self:getAbsoluteY()
	end
	self:setStencilRect(stencilX, stencilY, stencilX2 - stencilX, stencilY2 - stencilY)

	local y = 0;
	local alt = false;

--	if self.selected ~= -1 and self.selected < 1 then
--		self.selected = 1
	if self.selected ~= -1 and self.selected > #self.items then
		self.selected = #self.items
	end

	local altBg = self.altBgColor

	self.listHeight = 0;
	 local i = 1;
	 for k, v in ipairs(self.items) do
		if not v.height then v.height = self.itemheight end -- compatibililty

		 if alt and altBg then
			self:drawRect(0, y, self:getWidth(), v.height-1, altBg.r, altBg.g, altBg.b, altBg.a);
		 else

		 end
		 v.index = i;
		 local y2 = self:doDrawItem(y, v, alt);
		 self.listHeight = y2;
		 v.height = y2 - y
		 y = y2

		 alt = not alt;
		 i = i + 1;
	 end

	self:setScrollHeight((y));
	self:clearStencilRect();
	if self.doRepaintStencil then
		self:repaintStencilRect(stencilX, stencilY, stencilX2 - stencilX, stencilY2 - stencilY)
	end

	local mouseY = self:getMouseY()
	self:updateSmoothScrolling()
	if mouseY ~= self:getMouseY() and self:isMouseOver() then
		self:onMouseMove(0, self:getMouseY() - mouseY)
	end
	self:updateTooltip()

	if #self.columns > 0 then
--		print(self:getScrollHeight())
		self:drawRectBorderStatic(0, 0 - self.itemheight, self.width, self.itemheight - 1, 1, self.borderColor.r, self.borderColor.g, self.borderColor.b);
		self:drawRectStatic(0, 0 - self.itemheight - 1, self.width, self.itemheight-2,self.listHeaderColor.a,self.listHeaderColor.r, self.listHeaderColor.g, self.listHeaderColor.b);
		local dyText = (self.itemheight - FONT_HGT_SMALL) / 2
		for i,v in ipairs(self.columns) do
			self:drawRectStatic(v.size, 0 - self.itemheight, 1, self.itemheight + math.min(self.height, self.itemheight * #self.items - 1), 1, self.borderColor.r, self.borderColor.g, self.borderColor.b);
			if v.name then
				self:drawText(v.name, v.size + 10, 0 - self.itemheight - 1 + dyText - self:getYScroll(), 1,1,1,1,UIFont.Small);

			end
		end
	end
end

function ISWAT_ScrollingListBox:onMouseDoubleClick(x, y)
	if self.onmousedblclick and self.items[self.selected] ~= nil then
		self.onmousedblclick(self.target, self.items[self.selected].item);
	end
end


function ISWAT_ScrollingListBox:onMouseDown(x, y)
	if #self.items == 0 then return end
	local row = self:rowAt(x, y)

	if row > #self.items then
		row = #self.items;
	end
	if row < 1 then
		row = 1;
	end

	-- RJ: If you select the same item it unselect it
	--if self.selected == y then
	--if self.selected == y then
		--self.selected = -1;
		--return;
	--end

	getSoundManager():playUISound("UISelectListItem")

	self.selected = row;

	if self.onmousedown then
		self.onmousedown(self.target, self.items[self.selected].item);
	end
end


function ISWAT_ScrollingListBox:onJoypadDirUp()
    self.selected = self:prevVisibleIndex(self.selected)

    if self.selected <= 0 then
        self.selected = self:prevVisibleIndex(self.count + 1);
    end

    getSoundManager():playUISound("UISelectListItem")

    self:ensureVisible(self.selected)

	if self.onmousedown and self.items[self.selected] then
		self.onmousedown(self.target, self.items[self.selected].item);
	end
end

function ISWAT_ScrollingListBox:onJoypadDirDown()
        self.selected = self:nextVisibleIndex(self.selected)
        if self.selected == -1 then
            self.selected = self:nextVisibleIndex(0);
        end

    getSoundManager():playUISound("UISelectListItem")

    self:ensureVisible(self.selected)

	if self.onmousedown and self.items[self.selected] then
		self.onmousedown(self.target, self.items[self.selected].item);
	end
end

function ISWAT_ScrollingListBox:ensureVisible(index)
    if not index or index < 1 or index > #self.items then return end
    local y = 0
    local height = 0
    for k, v in ipairs(self.items) do
		if k == index then
			height = v.height
			break
		end
		y = y + v.height
	end
	if not self.smoothScrollTargetY then self.smoothScrollY = self:getYScroll() end
	if y < 0-self:getYScroll() then
		self.smoothScrollTargetY = 0 - y
	elseif y + height > 0 - self:getYScroll() + self.height then
		self.smoothScrollTargetY = 0 - (y + height - self.height)
	end
end

function ISWAT_ScrollingListBox:render()
    if self.joypadFocused then
        self:drawRectBorder(0, -self:getYScroll(), self:getWidth(), self:getHeight(), 0.4, 0.2, 1.0, 1.0);
        self:drawRectBorder(1, 1-self:getYScroll(), self:getWidth()-2, self:getHeight()-2, 0.4, 0.2, 1.0, 1.0);
    end
end

function ISWAT_ScrollingListBox:onJoypadDown(button, joypadData)
    if button == Joypad.AButton and self.onmousedblclick then
		if (#self.items > 0) and (self.selected ~= -1) then
			local previousSelected = self.selected;
			self.onmousedblclick(self.target, self.items[self.selected].item);
			self.selected = previousSelected;
		end
    elseif button == Joypad.BButton and self.joypadParent then
        self.joypadFocused = false;
        joypadData.focus = self.joypadParent;
        updateJoypadFocus(joypadData);
    else
        ISPanelJoypad.onJoypadDown(self, button);
    end
end

function ISWAT_ScrollingListBox:onLoseJoypadFocus(joypadData)
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
    self:setJoypadFocused(false, joypadData)
    if self.resetSelectionOnChangeFocus then
        self.selectedBeforeReset = self.selected
        self.selected = -1;
    end
end

function ISWAT_ScrollingListBox:setFont(font, padY)
    self.font = UIFont[font] or font
    self.fontHgt = getTextManager():getFontFromEnum(self.font):getLineHeight()
    self.itemPadY = padY
    self.itemheight = self.fontHgt + (self.itemPadY or 0) * 2;
end

function ISWAT_ScrollingListBox:addColumn(columnName, size)
	table.insert(self.columns, {name = columnName, size = size});
end

function ISWAT_ScrollingListBox:new (x, y, width, height)
	local o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
	self.__index = self
	o.x = x;
	o.y = y;
	o:noBackground();
	o.backgroundColor = {r=0, g=0, b=0, a=0.8};
	o.borderColor = {r=0.4, g=0.4, b=0.4, a=0.9};
	o.altBgColor = {r=0.2, g=0.3, b=0.2, a=0.1 }
	o.listHeaderColor = {r=0.4, g=0.4, b=0.4, a=0.3};
	o.altBgColor = nil
	o.drawBorder = false
	o.width = width;
	o.height = height;
	o.anchorLeft = true;
	o.anchorRight = false;
	o.anchorTop = true;
	o.anchorBottom = false;
	o.font = UIFont.Large
	o.fontHgt = getTextManager():getFontFromEnum(o.font):getLineHeight()
	o.itemPadY = 7
	o.itemheight = o.fontHgt + o.itemPadY * 2;
	o.selected = 1;
    o.count = 0;
	o.itemheightoverride = {}
	o.items = {}
	o.columns = {};
	return o
end

WAT_LevelAnalyzer = ISPanel:derive("WAT_LevelAnalyzer")

function WAT_LevelAnalyzer:initialise()
	ISPanel.initialise(self)
end

function WAT_LevelAnalyzer:noBackground()
	self.background = false
end

function WAT_LevelAnalyzer:close()
	self:setVisible(false)
    self:removeFromUIManager()
    instance = nil
end

function WAT_LevelAnalyzer.WATdeleteDialog(self,button,item)
    if button.internal == "YES" then
		if item.type == 1 then
			if isClient() then
				sledgeDestroy(item.object)
			else
				item.objects:remove(item.object)
			end
		elseif item.type == 2 then
			item.object:RemoveAttachedAnim(item.animIndex)
			sendClientCommand(getPlayer(), 'WAT', 'removeAttachedAnim', {x=item.sq:getX(), y=item.sq:getY(), z=item.sq:getZ(), spriteName=item.object:getSprite():getName(), i=item.animIndex})
		end
    end
end

function WAT_LevelAnalyzer:WATdelete()
    local listitem = self.scrolllist.items[self.scrolllist.selected]
    local modaldialog = ISModalDialog:new(0,0, 250, 150, "Delete?", true, nil, self.WATdeleteDialog, 0,listitem)
    modaldialog:initialise()
    modaldialog:addToUIManager()
end

function WAT_LevelAnalyzer:WATcopy()
    local listitem = self.scrolllist.items[self.scrolllist.selected]

    local object =listitem.name
    local cursor = ISBrushToolTileCursor:new(object,object, self.character)
    getCell():setDrag(cursor,0)
end

function WAT_LevelAnalyzer:modal(button, backuppos,player,instance)
    if button.internal ~= "OK" then return end
end

function WAT_LevelAnalyzer:WATdown()
    local arraylist =ArrayList:new()
    local item = self.scrolllist.items[self.scrolllist.selected]
    local index = item.objects:indexOf(item.object)

    if index  ~= item.objects:size()-1 then
        for z=1,item.objects:size() do
            if z-1 == index then
                arraylist:add(item.objects:get(z-1 +1))
            elseif z-1 ==index+1 then
                arraylist:add(item.objects:get(z-2))
            else
                arraylist:add(item.objects:get(z-1))
            end
        end

		item.objects:clear()
		for g=1,arraylist:size() do
			item.objects:add(arraylist:get(g-1))
		end

		if isClient() then
			sendClientCommand(getPlayer(), 'WAT', 'tileDown', {x=item.sq:getX(), y=item.sq:getY(), z=item.sq:getZ(), i=index})
		end
    end
end

function WAT_LevelAnalyzer:WATup()
    local arraylist =ArrayList:new()
    local item = self.scrolllist.items[self.scrolllist.selected]
    local index = item.objects:indexOf(item.object)

    if index  ~= 0 then
        for z=1,item.objects:size() do
            if z-1 == index-1 then
                arraylist:add(item.objects:get(z-1 +1))
            elseif z-1 ==index then
                arraylist:add(item.objects:get(z-2))
            else
                arraylist:add(item.objects:get(z-1))
            end
        end

		item.objects:clear()
		for g=1,arraylist:size() do
			item.objects:add(arraylist:get(g-1))
		end

		if isClient() then
			sendClientCommand(getPlayer(), 'WAT', 'tileUp', {x=item.sq:getX(), y=item.sq:getY(), z=item.sq:getZ(), i=index})
		end
	end
end


function WAT_LevelAnalyzer:createChildren()
	ISPanel.createChildren(self)

    local emptyhight = self.height/80
    local lblheighth = self.height/12
    self.lbl = ISLabel:new(6*emptyhight, emptyhight, lblheighth, "Level Analyzer", 1, 1, 1, 1.0, UIFont.Large, true)
    self.lbl:initialise()
    self.lbl:instantiate()
    self:addChild(self.lbl)

    local scrollwidth = self.width*0.6
    local scrollheight = self.height - 3*emptyhight -lblheighth

    self.scrolllist = ISWAT_ScrollingListBox:new(self.width - emptyhight-scrollwidth, 2*emptyhight + lblheighth, scrollwidth, scrollheight)
	self.scrolllist:initialise()
	self.scrolllist:instantiate()
	self.scrolllist.drawBorder = true
	self.scrolllist:setFont(UIFont.Large, 10)
	self.scrolllist:setOnMouseDownFunction(self, self.onMapSelected)
	self:addChild(self.scrolllist)

    local buttonheight = self.height/12
    local buttonwidth = self.width - 7*emptyhight - scrollwidth

    self.buttonclose = ISButton:new(3*emptyhight, self.height -emptyhight -buttonheight ,buttonwidth,buttonheight , "Close", self, self.close)
    self.buttonclose.anchorTop = false
    self.buttonclose.anchorBottom = false
    self.buttonclose:initialise()
    self.buttonclose:instantiate()
    self.buttonclose.borderColor = {r=1, g=1, b=1, a=0.5}
    self:addChild(self.buttonclose)

    local buttonnewy = 2*emptyhight + lblheighth
    self.buttondelete = ISButton:new(3*emptyhight,  buttonnewy ,buttonwidth,buttonheight , "Delete", self, self.WATdelete)
    self.buttondelete.anchorTop = false
    self.buttondelete.anchorBottom = false
    self.buttondelete:initialise()
    self.buttondelete:instantiate()
    self.buttondelete.borderColor = {r=1, g=1, b=1, a=0.5}
    -- self.buttonnew:setEnabled(false)
    self:addChild(self.buttondelete)


    buttonnewy = buttonnewy + buttonheight + emptyhight
    self.buttonup = ISButton:new(3*emptyhight, buttonnewy  ,buttonwidth,buttonheight , "Up", self, self.WATup)
    self.buttonup.anchorTop = false
    self.buttonup.anchorBottom = false
    self.buttonup:initialise()
    self.buttonup:instantiate()
    self.buttonup.borderColor = {r=1, g=1, b=1, a=0.5}
    self:addChild(self.buttonup)

    buttonnewy = buttonnewy + buttonheight + emptyhight
    self.buttondown = ISButton:new(3*emptyhight, buttonnewy  ,buttonwidth,buttonheight , "Down", self, self.WATdown)
    self.buttondown.anchorTop = false
    self.buttondown.anchorBottom = false
    self.buttondown:initialise()
    self.buttondown:instantiate()
    self.buttondown.borderColor = {r=1, g=1, b=1, a=0.5}
    -- self.buttondelete:setEnabled(false)
    self:addChild(self.buttondown)

    buttonnewy = buttonnewy + buttonheight + emptyhight
    self.buttoncopy = ISButton:new(3*emptyhight, buttonnewy  ,buttonwidth,buttonheight , "Copy", self, self.WATcopy)
    self.buttoncopy.anchorTop = false
    self.buttoncopy.anchorBottom = false
    self.buttoncopy:initialise()
    self.buttoncopy:instantiate()
    self.buttoncopy.borderColor = {r=1, g=1, b=1, a=0.5}
    self:addChild(self.buttoncopy)
end

function WAT_LevelAnalyzer:prerender()
	if self.background then
		self:drawRectStatic(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
		self:drawRectBorderStatic(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
	end

    if self.clicksquare then
        local sqObjs = self.clicksquare:getObjects()
        local sqSize = sqObjs:size()
        local l_items = {}
        for k=1,sqSize do
            local object = sqObjs:get(k-1)

            if object:getTextureName() then
                local i={}
                i.text = object:getTextureName()
                i.objects = sqObjs
                i.name = object:getTextureName()
                i.object = object
                i.sq = self.clicksquare
                i.objindex = k-1
                i.type = 1

                local texturez = getTexture(i.text)

                i.texture = texturez
                i.height = self.scrolllist.itemheight*3
                table.insert(l_items, i)
            end

            if object:getOverlaySprite() and object:getOverlaySprite():getName() then

                local i={}
                i.text = object:getOverlaySprite():getName()
                i.objects = sqObjs
                i.name = object:getOverlaySprite():getName()
                i.object = object
                i.sq = self.clicksquare
                i.objindex = k-1
                i.type = 0
                local texturez = getTexture(i.text)
                i.text = "Attached: "..object:getOverlaySprite():getName()
                i.texture = texturez
                i.height = self.scrolllist.itemheight*3
                table.insert(l_items, i)
            end

            local attachedSprites = object:getAttachedAnimSprite()
            if attachedSprites ~= nil then
                for i = 0, attachedSprites:size()-1 do
                    local sprite = attachedSprites:get(i):getParentSprite()
                    if sprite and sprite:getName() ~= nil then

                        local j={}
                        j.text = sprite:getName()
                        j.objects = sqObjs
                        j.name = sprite:getName()
                        j.object = object
                        j.sq = self.clicksquare
                        j.objindex = k-1
                        j.type = 2
						j.animIndex = i
                        local texturez = getTexture(j.text)
                        j.text = "Attached: "..sprite:getName()
                        j.texture = texturez
                        j.height = self.scrolllist.itemheight*3
                        table.insert(l_items, j)
                    end
                end
            end
        end
        self.scrolllist.items = l_items
    end

    local listselected = self.scrolllist.selected


    self.buttondelete:setVisible(false)
    self.buttonup:setVisible(false)
    self.buttondown:setVisible(false)
    self.buttoncopy:setVisible(false)

    if listselected >0 then
        self.buttoncopy:setVisible(true)
        if self.scrolllist.items[listselected] and self.scrolllist.items[listselected].type == 1 then
            self.buttondelete:setVisible(true)
			if listselected > 1 then
				self.buttonup:setVisible(true)
			end
			if listselected < #self.scrolllist.items then
				self.buttondown:setVisible(true)
			end
		elseif self.scrolllist.items[listselected] and self.scrolllist.items[listselected].type == 2 then
			self.buttondelete:setVisible(true)
        end
    end
end

function WAT_LevelAnalyzer:onMouseUp(x, y)
    if not self.moveWithMouse then return end
    if not self:getIsVisible() then
        return
    end

    self.moving = false
    if ISMouseDrag.tabPanel then
        ISMouseDrag.tabPanel:onMouseUp(x,y)
    end

    ISMouseDrag.dragView = nil
end

function WAT_LevelAnalyzer:onMouseUpOutside(x, y)
    if not self.moveWithMouse then return end
    if not self:getIsVisible() then
        return
    end
    self.moving = false
    ISMouseDrag.dragView = nil
    if x >=0 and x<=500  and y>=0 and y<=600 then return end
    local dx = getMouseXScaled()
	local dy = getMouseYScaled()
	local z = self.character:getZ()
	local wx, wy = ISCoordConversion.ToWorld(dx, dy, z)
	wx = math.floor(wx)
	wy = math.floor(wy)

    local cell = getWorld():getCell()
	local sq = cell:getGridSquare(wx, wy, z)
	if sq == nil then return false end

    self.clicksquare = sq
end

function WAT_LevelAnalyzer:onMouseDown(x, y)
    if not self.moveWithMouse then return true end
    if not self:getIsVisible() then
        return
    end
    if not self:isMouseOver() then
        return
    end

    self.downX = x
    self.downY = y
    self.moving = true
    self:bringToTop()
end

function WAT_LevelAnalyzer:onMouseMoveOutside(dx, dy)
    if not self.moveWithMouse then return end
    self.mouseOver = false

    if self.moving then
        if self.parent then
            self.parent:setX(self.parent.x + dx)
            self.parent:setY(self.parent.y + dy)
        else
            self:setX(self.x + dx)
            self:setY(self.y + dy)
            self:bringToTop()
        end
    end
end

function WAT_LevelAnalyzer:onMouseMove(dx, dy)
    if not self.moveWithMouse then return end
    self.mouseOver = true

    if self.moving then
        if self.parent then
            self.parent:setX(self.parent.x + dx)
            self.parent:setY(self.parent.y + dy)
        else
            self:setX(self.x + dx)
            self:setY(self.y + dy)
            self:bringToTop()
        end
    end
end

--************************************************************************--
--** ISPanel:new
--**
--************************************************************************--
function WAT_LevelAnalyzer:new ()
	local width = 500
    local height = 600
    local x = (getCore():getScreenWidth() / 2) - (width / 2)
    local y = (getCore():getScreenHeight() / 2) - (height / 2)
	local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
	o.x = x
	o.y = y
	o.background = true
	o.backgroundColor = {r=0, g=0, b=0, a=0.5}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.width = width
	o.height = height
	o.anchorLeft = false
	o.anchorRight = false
	o.anchorTop = false
	o.anchorBottom = false
    o.moveWithMouse = true
    o.character = getPlayer()
   return o
end

