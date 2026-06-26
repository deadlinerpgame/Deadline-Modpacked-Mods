require "WL_Utils"
require "GroundHighlighter"
require "ISUI/ISModalDialog"
require "UI/LayoutManager/LayoutManager"

--- @class WF_ManagePlotsUI : ISPanel
WF_ManagePlotsUI = ISPanel:derive("WF_ManagePlotsUI")
WF_ManagePlotsUI.instance = WF_ManagePlotsUI.instance or nil

local function containsInsensitive(haystack, needle)
    local source = tostring(haystack or "")
    local query = tostring(needle or "")
    if query == "" then
        return true
    end
    return string.find(string.lower(source), string.lower(query), 1, true) ~= nil
end

local function parsePlotKey(plotKey)
    local x, y, z = tostring(plotKey or ""):match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
    if not x or not y or not z then
        return nil, nil, nil
    end
    return tonumber(x), tonumber(y), tonumber(z)
end

function WF_ManagePlotsUI:new()
    local scale = LayoutManager:_getScale()
    local w = math.floor(760 * scale)
    local h = math.floor(520 * scale)
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2, getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    self.__index = self

    o.scale = scale
    o.moveWithMouse = true
    o.background = true
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.92 }
    o.borderColor = { r = 0.3, g = 0.3, b = 0.3, a = 1 }
    o.allUsers = {}
    o.filteredUsers = {}
    o.selectedUsername = nil
    o.plots = {}
    o.selectedPlot = nil
    o.highlighter = nil

    return o
end

function WF_ManagePlotsUI:initialise()
    ISPanel.initialise(self)

    self:applyLayout()
    self:requestManagedUsers()
end

function WF_ManagePlotsUI:onResize()
    ISUIElement.onResize(self)
    self:applyLayout()
    self:rebuildUserList()
    self:rebuildPlotsList()
end

function WF_ManagePlotsUI:removeHighlighter()
    if self.highlighter then
        self.highlighter:remove()
        self.highlighter = nil
    end
end

function WF_ManagePlotsUI:getPlotsHeaderText()
    if not self.selectedUsername then
        return "Plots (select a user)"
    end
    return "Plots for " .. tostring(self.selectedUsername)
end

function WF_ManagePlotsUI:buildLayout()
    local scale = LayoutManager:_getScale()
    local pad = 8 * scale
    local topMargin = 10 * scale
    local sideMargin = 10 * scale
    local rootX = sideMargin
    local rootY = topMargin
    local rootWidth = self.width - (sideMargin * 2)
    local rootHeight = self.height - (topMargin * 2)

    local titleHeight = 26 * scale
    local headerHeight = 20 * scale
    local searchHeight = 22 * scale
    local listItemHeight = 20 * scale
    local actionButtonHeight = 26 * scale

    return { type = "rows", x = rootX, y = rootY, width = tostring(rootWidth) .. "px", height = tostring(rootHeight) .. "px", pad = pad, rows = {
        { type = "label", id = "titleLabel", width = "inherit", height = titleHeight, text = "Manage Farming Plots", font = UIFont.Medium, center = true, color = { r = 1, g = 1, b = 1, a = 1 } },
        { type = "columns", id = "listsColumns", width = "inherit", height = "*", pad = pad, columns = {
            { type = "panel", id = "usersPanel", width = "45%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.92 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = { type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                { type = "label", id = "usersHeaderLabel", width = "inherit", height = headerHeight, text = "Users", font = UIFont.Small, color = { r = 0.82, g = 0.9, b = 1, a = 1 } },
                { type = "textbox", id = "userSearchInput", width = "inherit", height = searchHeight, text = "", target = self, onTextChange = self.onUserSearchChanged, clearButton = true, tooltip = "Search users..." },
                { type = "scrollinglistbox", id = "usersList", width = "inherit", height = "*", itemheight = listItemHeight, font = UIFont.Small, target = self, onMouseDown = self.onUserSelected }
            }}},
            { type = "panel", id = "plotsPanel", width = "55%", height = "inherit", backgroundColor = { r = 0.06, g = 0.06, b = 0.06, a = 0.92 }, borderColor = { r = 0.25, g = 0.25, b = 0.25, a = 1 }, child = { type = "rows", width = "inherit", height = "inherit", margin = { 6, 6, 6, 6 }, pad = 6, rows = {
                { type = "label", id = "plotsHeaderLabel", width = "inherit", height = headerHeight, text = function() return self:getPlotsHeaderText() end, font = UIFont.Small, color = { r = 0.82, g = 1, b = 0.82, a = 1 } },
                { type = "scrollinglistbox", id = "plotsList", width = "inherit", height = "*", itemheight = listItemHeight, font = UIFont.Small, target = self, onMouseDown = self.onPlotSelected },
                { type = "columns", id = "plotActionsRow", width = "inherit", height = actionButtonHeight, pad = 6, columns = {
                    { type = "button", id = "refreshUserButton", width = "*", text = "Refresh User", target = self, onClick = self.onRefreshUser, enabled = false },
                    { type = "button", id = "releasePlotButton", width = "*", text = "Release Selected Plot", target = self, onClick = self.onReleaseSelectedPlot, enabled = false }
                }}
            }}}
        }},
        { type = "columns", id = "actionsRow", width = "inherit", height = actionButtonHeight, pad = 8, columns = {
            { type = "button", id = "refreshButton", width = "*", text = "Refresh", target = self, onClick = self.onRefresh },
            { type = "button", id = "closeButton", width = "*", text = "Close", target = self, onClick = self.onClose }
        }}
    }}
end

function WF_ManagePlotsUI:applyLayout()
    self.layout = self:buildLayout()
    self.elements = LayoutManager:applyLayout(self, self.layout)
    self.userSearchInput = self.elements.userSearchInput
    self.usersList = self.elements.usersList
    self.plotsList = self.elements.plotsList
    self.refreshUserButton = self.elements.refreshUserButton
    self.releasePlotButton = self.elements.releasePlotButton

    self:updateActionButtonState()
end

function WF_ManagePlotsUI:getSearchText()
    if not self.userSearchInput then
        return ""
    end
    return self.userSearchInput:getInternalText() or self.userSearchInput:getText() or ""
end

function WF_ManagePlotsUI:requestManagedUsers(preferredSelection)
    local player = getPlayer()
    if not player then
        return
    end

    WF_TokensSystem:getManagedUsers(player, function(users)
        self.allUsers = {}
        for i = 1, #(users or {}) do
            local entry = users[i]
            local username = ""
            local usedPlots = 0
            if type(entry) == "table" then
                username = tostring(entry.username or "")
                usedPlots = tonumber(entry.usedPlots) or 0
            else
                username = tostring(entry or "")
            end
            if username ~= "" then
                self.allUsers[#self.allUsers + 1] = {
                    username = username,
                    usedPlots = usedPlots
                }
            end
        end

        table.sort(self.allUsers, function(a, b)
            return tostring(a.username) < tostring(b.username)
        end)

        self:applyUserFilter(self:getSearchText(), preferredSelection)
    end)
end

function WF_ManagePlotsUI:applyUserFilter(searchText, preferredSelection)
    local previousSelected = self.selectedUsername
    local filtered = {}
    local query = tostring(searchText or "")

    for i = 1, #self.allUsers do
        local user = self.allUsers[i]
        if containsInsensitive(user.username, query) then
            filtered[#filtered + 1] = user
        end
    end

    self.filteredUsers = filtered

    local selectedUsername = nil
    if preferredSelection then
        local preferredName = tostring(preferredSelection)
        for i = 1, #filtered do
            if filtered[i].username == preferredName then
                selectedUsername = preferredName
                break
            end
        end
    end

    if not selectedUsername and previousSelected then
        for i = 1, #filtered do
            if filtered[i].username == previousSelected then
                selectedUsername = previousSelected
                break
            end
        end
    end

    if not selectedUsername and #filtered > 0 then
        selectedUsername = filtered[1].username
    end

    self.selectedUsername = selectedUsername
    if self.selectedUsername ~= previousSelected then
        self.selectedPlot = nil
        self.plots = {}
        self:removeHighlighter()
    end

    self:rebuildUserList()
    self:updateActionButtonState()

    if self.selectedUsername ~= previousSelected then
        self:requestPlotsForSelectedUser()
    elseif not self.selectedUsername then
        self.plots = {}
        self.selectedPlot = nil
        self:rebuildPlotsList()
    end
end

function WF_ManagePlotsUI:rebuildUserList()
    if not self.usersList then
        return
    end

    self.usersList:clear()

    local selectedIndex = 0
    if #self.filteredUsers == 0 then
        self.usersList:addItem("No matching users", nil)
        self.usersList.selected = 0
    else
        for i = 1, #self.filteredUsers do
            local user = self.filteredUsers[i]
            local label = string.format("%s (%d)", user.username, user.usedPlots)
            self.usersList:addItem(label, user)
            if self.selectedUsername == user.username then
                selectedIndex = i
            end
        end
        self.usersList.selected = selectedIndex
    end
end

function WF_ManagePlotsUI:onUserSearchChanged()
    local text = self:getInternalText() or self:getText() or ""
    self.parent:applyUserFilter(text)
end

function WF_ManagePlotsUI:onUserSelected(item)
    local selected = item
    if selected and selected.item then
        selected = selected.item
    end

    if not selected or not selected.username then
        return
    end

    if self.selectedUsername == selected.username then
        return
    end

    self.selectedUsername = selected.username
    self.selectedPlot = nil
    self.plots = {}
    self:removeHighlighter()
    self:rebuildUserList()
    self:rebuildPlotsList()
    self:updateActionButtonState()
    self:requestPlotsForSelectedUser()
end

function WF_ManagePlotsUI:requestPlotsForSelectedUser()
    local username = self.selectedUsername
    if not username then
        self.plots = {}
        self.selectedPlot = nil
        self:rebuildPlotsList()
        return
    end

    local player = getPlayer()
    if not player then
        return
    end

    WF_TokensSystem:getPlotsFor(player, username, function(plotKeys)
        if self.selectedUsername ~= username then
            return
        end

        local selectedPlotKey = self.selectedPlot and self.selectedPlot.plotKey or nil
        self.plots = {}
        for i = 1, #(plotKeys or {}) do
            local plotKey = tostring(plotKeys[i])
            local x, y, z = parsePlotKey(plotKey)
            if x and y and z then
                self.plots[#self.plots + 1] = {
                    plotKey = plotKey,
                    x = x,
                    y = y,
                    z = z,
                    username = username
                }
            end
        end

        table.sort(self.plots, function(a, b)
            if a.z ~= b.z then
                return a.z < b.z
            end
            if a.y ~= b.y then
                return a.y < b.y
            end
            return a.x < b.x
        end)

        self.selectedPlot = nil
        if selectedPlotKey then
            for i = 1, #self.plots do
                if self.plots[i].plotKey == selectedPlotKey then
                    self.selectedPlot = self.plots[i]
                    break
                end
            end
        end

        self:rebuildPlotsList()
    end)
end

function WF_ManagePlotsUI:rebuildPlotsList()
    if not self.plotsList then
        return
    end

    self.plotsList:clear()

    local selectedIndex = 0
    if not self.selectedUsername then
        self.plotsList:addItem("Select a user to view plots", nil)
    elseif #self.plots == 0 then
        self.plotsList:addItem("No plots found", nil)
    else
        for i = 1, #self.plots do
            local plot = self.plots[i]
            local label = string.format("(%d, %d, %d)", plot.x, plot.y, plot.z)
            self.plotsList:addItem(label, plot)
            if self.selectedPlot and self.selectedPlot.plotKey == plot.plotKey then
                selectedIndex = i
            end
        end
    end

    self.plotsList.selected = selectedIndex
    self:updateActionButtonState()
end

function WF_ManagePlotsUI:updateReleaseButtonState()
    if self.releasePlotButton then
        self.releasePlotButton:setEnable(self.selectedPlot ~= nil)
    end
end

function WF_ManagePlotsUI:updateActionButtonState()
    if self.refreshUserButton then
        self.refreshUserButton:setEnable(self.selectedUsername ~= nil)
    end
    self:updateReleaseButtonState()
end

function WF_ManagePlotsUI:onPlotSelected(item)
    local selected = item
    if selected and selected.item then
        selected = selected.item
    end

    if not selected or not selected.plotKey then
        self.selectedPlot = nil
        self:updateActionButtonState()
        return
    end

    self.selectedPlot = selected
    self:updateActionButtonState()

    self:removeHighlighter()

    local player = getPlayer()
    if not player then
        return
    end

    local didTeleport = WL_Utils.teleportPlayerToCoords(player, selected.x, selected.y, selected.z)
    if not didTeleport then
        WL_Utils.addErrorToChat("Unable to teleport while driving. Stop your vehicle first.")
        return
    end

    self.highlighter = GroundHighlighter:new()
    self.highlighter:setColor(0.0, 1.0, 0.0, 0.8)
    self.highlighter:highlightSquare(selected.x, selected.y, selected.x, selected.y, selected.z)
end

function WF_ManagePlotsUI:onReleaseSelectedPlot()
    if not self.selectedPlot or not self.selectedUsername then
        WL_Utils.addErrorToChat("No plot selected.")
        return
    end

    local player = getPlayer()
    if not player or not WL_Utils.canModerate(player) then
        WL_Utils.addErrorToChat("You do not have permission to release plots.")
        return
    end

    local plot = self.selectedPlot
    local username = self.selectedUsername
    local text = "Release plot (" .. plot.x .. ", " .. plot.y .. ", " .. plot.z .. ") from " .. username .. "?"
    local modal = ISModalDialog:new(0, 0, 250, 120, text, true, self, function(target, button)
        if button.internal == "YES" then
            WF_TokensSystem:adminReleasePlot(player, plot.x, plot.y, plot.z)
            WL_Utils.addInfoToChat("Released plot at (" .. plot.x .. ", " .. plot.y .. ", " .. plot.z .. ") from " .. username)
            target.selectedPlot = nil
            target:removeHighlighter()
            target:requestManagedUsers(username)
        end
    end)
    modal:initialise()
    modal:addToUIManager()
end

function WF_ManagePlotsUI:onRefreshUser()
    if not self.selectedUsername then
        WL_Utils.addErrorToChat("No user selected.")
        return
    end

    local player = getPlayer()
    if not player or not WL_Utils.canModerate(player) then
        WL_Utils.addErrorToChat("You do not have permission to refresh users.")
        return
    end

    local username = self.selectedUsername
    WF_TokensSystem:refreshManagedUser(player, username, function(result)
        if self.selectedUsername ~= username then
            return
        end
        WL_Utils.addInfoToChat("Refreshed used plots for " .. username .. ": " .. tostring(result.usedPlots or 0))
        self:requestManagedUsers(username)
    end)
end

function WF_ManagePlotsUI:onRefresh()
    self:requestManagedUsers(self.selectedUsername)
end

function WF_ManagePlotsUI:onClose()
    self:removeHighlighter()

    self:setVisible(false)
    self:removeFromUIManager()
    if WF_ManagePlotsUI.instance == self then
        WF_ManagePlotsUI.instance = nil
    end
end

function WF_ManagePlotsUI.open()
    local player = getPlayer()
    if not player or not WL_Utils.canModerate(player) then
        WL_Utils.addErrorToChat("You do not have permission to manage plots.")
        return
    end

    if WF_ManagePlotsUI.instance then
        WF_ManagePlotsUI.instance:onClose()
    end

    local ui = WF_ManagePlotsUI:new()
    ui:initialise()
    ui:addToUIManager()
    WF_ManagePlotsUI.instance = ui
end
