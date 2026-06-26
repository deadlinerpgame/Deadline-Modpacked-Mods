require "ISUI/ISTabPanel"
require "ISUI/ISPanel"

local TabPanelNode = {}

local function applyColor(target, color)
    if not color then
        return
    end

    target.r = color.r or target.r
    target.g = color.g or target.g
    target.b = color.b or target.b
    target.a = color.a or target.a
end

local function clearPanelLayout(panel)
    local layoutState = panel.__wlLayoutState
    if not layoutState then
        return
    end

    for id, child in pairs(layoutState.elementsById) do
        panel:removeChild(child)
        layoutState.elementsById[id] = nil
    end
end

local function collectTabs(def)
    local tabs = {}

    if type(def.tabs) == "table" then
        for i = 1, #def.tabs do
            tabs[#tabs + 1] = def.tabs[i]
        end
    end

    if def.data and def.tabGenerator then
        for i, row in ipairs(def.data) do
            local generatedTab = def.tabGenerator(row, i, def)
            if generatedTab then
                tabs[#tabs + 1] = generatedTab
            end
        end
    end

    return tabs
end

local function updateTabPanel(tabPanel, frame, def)
    tabPanel:setX(frame.x)
    tabPanel:setY(frame.y)
    tabPanel:setWidth(frame.width)
    tabPanel:setHeight(frame.height)

    if def.equalTabWidth ~= nil then
        tabPanel:setEqualTabWidth(def.equalTabWidth == true)
    end

    if def.centerTabs ~= nil then
        tabPanel:setCenterTabs(def.centerTabs == true)
    end

    if def.allowDraggingTabs ~= nil then
        tabPanel.allowDraggingTabs = def.allowDraggingTabs == true
    end

    if def.allowTornOffTabs ~= nil then
        tabPanel.allowTornOffTabs = def.allowTornOffTabs == true
    end

    if def.tabTransparency ~= nil then
        tabPanel:setTabsTransparency(def.tabTransparency)
    end

    if def.textTransparency ~= nil then
        tabPanel:setTextTransparency(def.textTransparency)
    end

    applyColor(tabPanel.borderColor, def.borderColor)
    applyColor(tabPanel.backgroundColor, def.backgroundColor)

    tabPanel.__wlUserOnActivateView = def.onActivateView
    tabPanel.__wlUserTarget = def.target
    tabPanel.target = tabPanel
    tabPanel.onActivateView = TabPanelNode._onActivateView
end

local function createTabContentView(tabPanel)
    local view = ISPanel:new(0, tabPanel.tabHeight, tabPanel.width, math.max(0, tabPanel.height - tabPanel.tabHeight))
    view:initialise()
    view:noBackground()
    return view
end

local function calculateTabWidth(tabPanel, title)
    return getTextManager():MeasureStringX(UIFont.Small, title) + tabPanel.tabPadX
end

function TabPanelNode._onActivateView(_, tabPanel)
    local activeView = tabPanel.activeView
    if activeView and activeView.view then
        tabPanel.__wlActiveTabId = activeView.view.__wlTabId
    end

    local userOnActivateView = tabPanel.__wlUserOnActivateView
    if userOnActivateView then
        local userTarget = tabPanel.__wlUserTarget
        if userTarget ~= nil then
            userOnActivateView(userTarget, tabPanel, tabPanel.__wlActiveTabId)
        else
            userOnActivateView(tabPanel, tabPanel.__wlActiveTabId)
        end
    end
end

function TabPanelNode.apply(layoutManager, panel, state, def, frame, elementsOut, seenIds)
    if not def.id then
        print("LayoutManager: tabpanel is missing required id")
        return
    end

    local tabPanel = state.elementsById[def.id]
    if tabPanel and tabPanel.__layoutType ~= "tabpanel" then
        panel:removeChild(tabPanel)
        tabPanel = nil
    end

    if not tabPanel then
        tabPanel = ISTabPanel:new(frame.x, frame.y, frame.width, frame.height)
        tabPanel:initialise()
        panel:addChild(tabPanel)

        tabPanel.__layoutType = "tabpanel"
        tabPanel.__wlTabViewsById = {}
        tabPanel.__wlFirstApplyDone = false

        state.elementsById[def.id] = tabPanel
    end

    updateTabPanel(tabPanel, frame, def)

    local currentActiveTabId = tabPanel.__wlActiveTabId
    if tabPanel.activeView and tabPanel.activeView.view then
        currentActiveTabId = tabPanel.activeView.view.__wlTabId or currentActiveTabId
    end

    local tabDefs = collectTabs(def)
    local tabIdsInOrder = {}
    local tabIdsUsed = {}
    local tabTitlesById = {}

    for i = 1, #tabDefs do
        local tabDef = tabDefs[i]
        local tabId = tabDef and tabDef.id
        if tabId == nil or tostring(tabId) == "" then
            print("LayoutManager: tabpanel tab entry is missing required id")
        else
            tabId = tostring(tabId)

            if tabIdsUsed[tabId] then
                print("LayoutManager: duplicate tabpanel tab id '" .. tabId .. "'")
            else
                local tabTitle = tabDef.title
                if tabTitle == nil then
                    tabTitle = tabDef.name
                end
                if tabTitle == nil then
                    tabTitle = tabId
                end
                tabTitle = tostring(tabTitle)

                tabIdsUsed[tabId] = true
                tabIdsInOrder[#tabIdsInOrder + 1] = tabId
                tabTitlesById[tabId] = tabTitle

                local tabView = tabPanel.__wlTabViewsById[tabId]
                if not tabView then
                    tabView = createTabContentView(tabPanel)
                    tabView.__wlTabId = tabId

                    tabPanel:addView(tabTitle, tabView)
                    tabPanel.__wlTabViewsById[tabId] = tabView
                end

                tabView.__wlTabId = tabId
                tabView:setX(0)
                tabView:setY(tabPanel.tabHeight)
                tabView:setWidth(tabPanel.width)
                tabView:setHeight(math.max(0, tabPanel.height - tabPanel.tabHeight))

                if tabDef.content then
                    local tabElements = layoutManager:applyLayout(tabView, tabDef.content)
                    for elementId, element in pairs(tabElements) do
                        elementsOut[elementId] = element
                    end
                else
                    clearPanelLayout(tabView)
                end
            end
        end
    end

    for tabId, tabView in pairs(tabPanel.__wlTabViewsById) do
        if not tabIdsUsed[tabId] then
            tabPanel:removeView(tabView)
            tabPanel.__wlTabViewsById[tabId] = nil
        end
    end

    local viewObjectByTabId = {}
    for i = 1, #tabPanel.viewList do
        local viewObject = tabPanel.viewList[i]
        local tabId = viewObject.view and viewObject.view.__wlTabId
        if tabId and tabIdsUsed[tabId] then
            viewObject.name = tabTitlesById[tabId]
            viewObject.tabWidth = calculateTabWidth(tabPanel, viewObject.name)
            viewObjectByTabId[tabId] = viewObject
        end
    end

    local orderedViewList = {}
    local maxLength = 0
    for i = 1, #tabIdsInOrder do
        local tabId = tabIdsInOrder[i]
        local viewObject = viewObjectByTabId[tabId]
        if viewObject then
            orderedViewList[#orderedViewList + 1] = viewObject
            if viewObject.tabWidth > maxLength then
                maxLength = viewObject.tabWidth
            end
        end
    end

    tabPanel.viewList = orderedViewList
    tabPanel.maxLength = maxLength

    if #orderedViewList > 0 then
        local selectedTabId = currentActiveTabId

        if not tabPanel.__wlFirstApplyDone then
            if def.activeTabId ~= nil then
                local initialTabId = tostring(def.activeTabId)
                if tabIdsUsed[initialTabId] then
                    selectedTabId = initialTabId
                end
            end
            tabPanel.__wlFirstApplyDone = true
        end

        if selectedTabId == nil or not tabIdsUsed[selectedTabId] then
            selectedTabId = tabIdsInOrder[1]
        end

        local selectedViewObject = viewObjectByTabId[selectedTabId] or orderedViewList[1]
        tabPanel.activeView = selectedViewObject

        local activeIndex = 1
        for i = 1, #orderedViewList do
            local isActive = orderedViewList[i] == selectedViewObject
            orderedViewList[i].view:setVisible(isActive)
            if isActive then
                activeIndex = i
            end
        end

        tabPanel.__wlActiveTabId = selectedViewObject.view.__wlTabId
        tabPanel:ensureVisible(activeIndex)
    else
        tabPanel.activeView = nil
        tabPanel.__wlActiveTabId = nil
    end

    elementsOut[def.id] = tabPanel
    seenIds[def.id] = true
end

return function(layoutManager)
    layoutManager.registerNode("tabpanel", TabPanelNode)
end
