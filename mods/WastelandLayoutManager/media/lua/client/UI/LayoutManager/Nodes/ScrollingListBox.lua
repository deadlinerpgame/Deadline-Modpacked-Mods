require "ISUI/ISScrollingListBox"

local ScrollingListBoxNode = {}

local function applyColor(target, color)
    if not target or not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function rebuildItems(listBox, def)
    if type(def.items) ~= "table" then
        return
    end

    listBox:clear()

    local items = def.items
    for i = 1, #items do
        local entry = items[i]
        local item

        if type(entry) == "table" then
            item = listBox:addItem(tostring(entry.text or entry.name or ""), entry.item)
            if entry.tooltip ~= nil then
                item.tooltip = entry.tooltip
            end
            if entry.height ~= nil then
                item.height = entry.height
            end
        else
            item = listBox:addItem(tostring(entry), entry)
        end
    end
end

local function updateListBox(listBox, frame, def)
    listBox:setX(frame.x)
    listBox:setY(frame.y)
    listBox:setWidth(frame.width)
    listBox:setHeight(frame.height)

    if def.onMouseDown ~= nil then
        listBox.onmousedown = def.onMouseDown
    end
    if def.onMouseDoubleClick ~= nil then
        listBox.onmousedblclick = def.onMouseDoubleClick
    end
    if def.target ~= nil then
        listBox.target = def.target
    end

    if def.drawBorder ~= nil then
        listBox.drawBorder = def.drawBorder == true
    end

    if def.doRepaintStencil ~= nil then
        listBox.doRepaintStencil = def.doRepaintStencil == true
    end

    if def.resetSelectionOnChangeFocus ~= nil then
        listBox.resetSelectionOnChangeFocus = def.resetSelectionOnChangeFocus == true
    end

    if def.itemPadY ~= nil then
        listBox.itemPadY = def.itemPadY
    end
    if def.itemheight ~= nil then
        listBox.itemheight = def.itemheight
    end

    if def.font ~= nil then
        listBox:setFont(def.font, def.itemPadY)
    end

    applyColor(listBox.backgroundColor, def.backgroundColor)
    applyColor(listBox.borderColor, def.borderColor)
    applyColor(listBox.altBgColor, def.altBgColor)
    applyColor(listBox.listHeaderColor, def.listHeaderColor)

    rebuildItems(listBox, def)

    if type(def.columns) == "table" then
        listBox.columns = {}
        for i = 1, #def.columns do
            local column = def.columns[i]
            if type(column) == "table" then
                listBox:addColumn(column.name, column.size)
            else
                listBox:addColumn(nil, tonumber(column) or 0)
            end
        end
    end

    if def.selected ~= nil then
        local selected = tonumber(def.selected) or 1
        if selected < 1 then
            selected = 1
        end
        if selected > #listBox.items then
            selected = #listBox.items
        end
        listBox.selected = selected
    end

    if def.yScroll ~= nil then
        listBox:setYScroll(def.yScroll)
    end
end

local function createListBox(panel, frame, def)
    local listBox = ISScrollingListBox:new(frame.x, frame.y, frame.width, frame.height)
    listBox:initialise()
    listBox:instantiate()
    panel:addChild(listBox)

    listBox.__layoutType = "scrollinglistbox"

    updateListBox(listBox, frame, def)
    return listBox
end

function ScrollingListBoxNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: scrollinglistbox is missing required id")
        return
    end

    local listBox = state.elementsById[def.id]
    if listBox and listBox.__layoutType ~= "scrollinglistbox" then
        panel:removeChild(listBox)
        listBox = nil
    end

    if not listBox then
        listBox = createListBox(panel, frame, def)
        state.elementsById[def.id] = listBox
    else
        updateListBox(listBox, frame, def)
    end

    elementsOut[def.id] = listBox
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("scrollinglistbox", ScrollingListBoxNode)
end
