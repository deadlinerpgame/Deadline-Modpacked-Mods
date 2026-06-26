require "WL_ClientServerBase"

--- @class WF_TokensSystem : WL_ClientServerBase
WF_TokensSystem = WL_ClientServerBase:new("WF_TokensSystem")

WF_TokensSystem.needsPrivateData = true
WF_TokensSystem.myUsedTokens = -1
WF_TokensSystem.callbacks = {}
WF_TokensSystem.adminCallbacks = {}

local function parsePlotKey(plotKey)
    local x, y, z = tostring(plotKey or ""):match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
    if not x or not y or not z then
        return nil, nil, nil
    end
    return tonumber(x), tonumber(y), tonumber(z)
end

function WF_TokensSystem:onModDataInit()
    if not self.privateData then
        self.privateData = {}
    end
    if not self.privateData.userTokens then
        self.privateData.userTokens = {}
    end
    if not self.privateData.plots then
        self.privateData.plots = {}
    end
    self:savePrivateData()
end

function WF_TokensSystem:getAllowedTokens(player)
    if player:isFarmingCheat() then
        return 999
    end
    local farmingLevel = player:getPerkLevel(Perks.Farming)
    local allowedTokens = 0
    if farmingLevel < 6 then
        allowedTokens = 10
    elseif farmingLevel < 8 then
        allowedTokens = 30
    elseif farmingLevel < 10 then
        allowedTokens = 50
    else
        allowedTokens = 100
    end
    return allowedTokens
end

function WF_TokensSystem:canUsePlot(player)
    if player:isFarmingCheat() then
        return true
    end
    local allowedPlots = self:getAllowedTokens(player)
    return self.myUsedTokens < allowedPlots
end

function WF_TokensSystem:usePlot(player, x, y, z)
    if isClient() then
        self:sendToServer(player, "usePlot", x, y, z)
        return
    end
    local username = player:getUsername()
    local plotKey = x .. "," .. y .. "," .. z
    
    if self.privateData.plots[plotKey] then
        local currentOwner = self.privateData.plots[plotKey]
        local currentOwnerUsedPlots = self.privateData.userTokens[currentOwner] or 0
        if currentOwnerUsedPlots > 0 then
            self.privateData.userTokens[currentOwner] = currentOwnerUsedPlots - 1
        end
        self.privateData.plots[plotKey] = nil
        self:sendUpdatedPlots(currentOwner)
    end
    self.privateData.userTokens[username] = (self.privateData.userTokens[username] or 0) + 1
    self.privateData.plots[plotKey] = username
    self:savePrivateData()
    self:sendUpdatedPlots(username)
end

function WF_TokensSystem:adminReleasePlot(player, x, y, z)
    if isClient() then
        self:sendToServer(player, "adminReleasePlot", x, y, z)
        return
    end
    self:logInfo(player:getUsername() .. " released plot at: " .. x .. "," .. y .. "," .. z)
    self:releasePlot(x, y, z)
end

function WF_TokensSystem:releasePlot(x, y, z)
    if isClient() then
        return
    end
    
    local plotKey = x .. "," .. y .. "," .. z
    local username = self.privateData.plots[plotKey]
    if not username then
        return
    end
    local usedPlots = self.privateData.userTokens[username] or 0
    if usedPlots > 0 then
        self.privateData.userTokens[username] = usedPlots - 1
    end
    self.privateData.plots[plotKey] = nil
    self:savePrivateData()
    self:sendUpdatedPlots(username)
end

function WF_TokensSystem:collectValidPlotsForUser(username)
    local plotList = {}
    local removedInvalid = false
    for plotKey, owner in pairs(self.privateData.plots) do
        if owner == username then
            local x, y, z = parsePlotKey(plotKey)
            if x and y and z and self:isValidPlot(x, y, z) then
                plotList[#plotList + 1] = plotKey
            else
                self:logInfo("Invalid plot found for " .. tostring(username) .. " at: " .. tostring(plotKey))
                self.privateData.plots[plotKey] = nil
                removedInvalid = true
            end
        end
    end
    table.sort(plotList, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return plotList, removedInvalid
end

function WF_TokensSystem:recountUserPlots(username)
    local usedPlots = 0
    for _, owner in pairs(self.privateData.plots) do
        if owner == username then
            usedPlots = usedPlots + 1
        end
    end
    self.privateData.userTokens[username] = usedPlots
end

function WF_TokensSystem:listMyPlots(player, _fromServer, _plotList)
    if isClient() then
        if not _fromServer then
            self:sendToServer(player, "listMyPlots")
        else
            if not _plotList or #_plotList == 0 then
                WL_Utils.addInfoToChat("No plots found.", {
                    chatId = WRC.OocTabId
                })
                return
            end
            
            for _, plotLocation in ipairs(_plotList) do
                WL_Utils.addInfoToChat("Plot at: " .. plotLocation, {
                    chatId = WRC.OocTabId
                })
            end
        end
        return
    end
    local username = player:getUsername()
    local plotList, removedInvalid = self:collectValidPlotsForUser(username)
    if removedInvalid then
        self:recountUserPlots(username)
        self:savePrivateData()
    end
    self:sendToClient(player, "listMyPlots", true, plotList)
    if removedInvalid then
        self:sendUpdatedPlots(username)
    end
end

function WF_TokensSystem:isValidPlot(x, y, z)
    local square = getCell():getGridSquare(x, y, z)
    if not square then
        return true -- we don't know, so assume it's valid
    end
    local plant = SFarmingSystem.instance:getLuaObjectAt(x, y, z)
    if plant then
        return true
    end
    return false
end

function WF_TokensSystem:sendUpdatedPlots(username)
    if isClient() then return end
    local player = WL_Utils.findPlayerFromUsername(username)
    if not player then return end
    local usedPlots = self.privateData.userTokens[username] or 0
    self:sendToClient(player, "receiveMyPlots", usedPlots)
end

function WF_TokensSystem:receiveMyPlots(player, usedPlots)
    if isServer() then return end
    if self.myUsedTokens > -1 then
        WL_Utils.addInfoToChat("Farming Plots Available: " .. (self:getAllowedTokens(player) - usedPlots), {
            chatId = WRC.OocTabId
        })
    end
    self.myUsedTokens = usedPlots
end

function WF_TokensSystem:getMyData(player)
    if isClient() then
        self.myUsedTokens = -1
        self:sendToServer(player, "getMyData")
        return
    end
    local usedPlots = self.privateData.userTokens[player:getUsername()] or 0
    self:sendToClient(player, "receiveMyPlots", usedPlots)
end

function WF_TokensSystem:getManagedUsers(player, callback)
    if isClient() then
        if type(callback) == "function" then
            self.adminCallbacks.userList = self.adminCallbacks.userList or {}
            table.insert(self.adminCallbacks.userList, callback)
            self:sendToServer(player, "getManagedUsers")
        else
            local callbacks = self.adminCallbacks.userList or {}
            for _, cb in ipairs(callbacks) do
                if type(cb) == "function" then
                    cb(callback or {})
                end
            end
            self.adminCallbacks.userList = nil
        end
        return
    end

    if not WL_Utils.canModerate(player) then
        self:sendToClient(player, "getManagedUsers", {})
        return
    end

    local usersByName = {}
    for username, usedPlots in pairs(self.privateData.userTokens) do
        if usedPlots and usedPlots > 0 then
            usersByName[username] = usedPlots
        end
    end
    for _, owner in pairs(self.privateData.plots) do
        if owner and owner ~= "" then
            if usersByName[owner] == nil then
                usersByName[owner] = self.privateData.userTokens[owner] or 0
            end
        end
    end

    local users = {}
    for username, usedPlots in pairs(usersByName) do
        users[#users + 1] = {
            username = username,
            usedPlots = usedPlots or 0
        }
    end
    table.sort(users, function(a, b)
        return tostring(a.username) < tostring(b.username)
    end)

    self:sendToClient(player, "getManagedUsers", users)
end

function WF_TokensSystem:refreshManagedUser(player, username, callback)
    if isClient() then
        local callbackKey = tostring(username or "")
        if type(callback) == "function" then
            self.adminCallbacks.refreshManagedUser = self.adminCallbacks.refreshManagedUser or {}
            self.adminCallbacks.refreshManagedUser[callbackKey] = self.adminCallbacks.refreshManagedUser[callbackKey] or {}
            table.insert(self.adminCallbacks.refreshManagedUser[callbackKey], callback)
            self:sendToServer(player, "refreshManagedUser", callbackKey)
        else
            local callbacksByUser = self.adminCallbacks.refreshManagedUser or {}
            local callbacks = callbacksByUser[callbackKey] or {}
            local result = {
                username = callbackKey,
                usedPlots = tonumber(callback) or 0
            }
            for _, cb in ipairs(callbacks) do
                if type(cb) == "function" then
                    cb(result)
                end
            end
            callbacksByUser[callbackKey] = nil
        end
        return
    end

    username = tostring(username or "")
    if username == "" or not WL_Utils.canModerate(player) then
        self:sendToClient(player, "refreshManagedUser", username, 0)
        return
    end

    self:recountUserPlots(username)
    self:savePrivateData()
    self:sendUpdatedPlots(username)
    self:sendToClient(player, "refreshManagedUser", username, self.privateData.userTokens[username] or 0)
end

function WF_TokensSystem:getPlotsFor(player, username, callback)
    if isClient() then
        local callbackKey = tostring(username or "")
        if type(callback) == "function" then
            self.callbacks[callbackKey] = self.callbacks[callbackKey] or {}
            table.insert(self.callbacks[callbackKey], callback)
            self:sendToServer(player, "getPlotsFor", callbackKey)
        else
            for _, cb in ipairs(self.callbacks[callbackKey] or {}) do
                if type(cb) == "function" then
                    cb(callback or {})
                end
            end
            self.callbacks[callbackKey] = nil
        end
        return
    end

    username = tostring(username or "")
    if username == "" then
        self:sendToClient(player, "getPlotsFor", username, {})
        return
    end

    local canViewOtherUsers = WL_Utils.canModerate(player)
    if not canViewOtherUsers and player:getUsername() ~= username then
        self:sendToClient(player, "getPlotsFor", username, {})
        return
    end

    local plots, removedInvalid = self:collectValidPlotsForUser(username)
    if removedInvalid then
        self:recountUserPlots(username)
        self:savePrivateData()
        self:sendUpdatedPlots(username)
    end

    self:sendToClient(player, "getPlotsFor", username, plots)
end

function WF_TokensSystem:recalcAllPlots(player)
    if isClient() then self:sendToServer(player, "recalcAllPlots") return end

    local newCountsByOwner = {}
    for plotKey, owner in pairs(self.privateData.plots) do
        newCountsByOwner[owner] = newCountsByOwner[owner] and (newCountsByOwner[owner] + 1) or 1
    end
    for username, count in pairs(newCountsByOwner) do
        if self.privateData.userTokens[username] ~= count then
            self.privateData.userTokens[username] = count
            self:sendUpdatedPlots(username)
        end
    end
    self:savePrivateData()
end
