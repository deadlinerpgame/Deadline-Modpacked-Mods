require "WLBaseObject"

--- @class WL_ClientServerBase
--- @field publicData table
--- @field privateData table
--- @field needsPublicData boolean
--- @field needsPrivateData boolean
--- @field systemName string
--- @private _serverWriteLog fun(player:KahluaTable, message:string):void
WL_ClientServerBase = {}

--- @type WL_ClientServerBase[]
WL_ClientServerBase.registeredSystems = {}

function WL_ClientServerBase:new(systemName)
    local o = WLBaseObject.new(self)
    o.systemName = systemName
    o.needsPrivateData = false
    o.needsPublicData = false
    o.privateData = {}
    o.publicData = {}
    o.lastPublicData = {}
    o.enablePartialTransmit = false
    WL_ClientServerBase.registeredSystems[systemName] = o
    return o
end

-- Overridable callbacks
function WL_ClientServerBase:onPublicDataUpdated() end
function WL_ClientServerBase:onModDataInit() end

function WL_ClientServerBase:sendToServer(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if isClient() then
        sendClientCommand(player, self.systemName, command, {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8})
    else
        self:receiveFromClient(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
end

function WL_ClientServerBase:sendToClient(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if isServer() then
        sendServerCommand(player, self.systemName, command, {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8})
    else
        self:receiveFromServer(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
end

function WL_ClientServerBase:sendToAllClients(command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if isServer() then
        sendServerCommand(self.systemName, command, {arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8})
    else
        self:receiveFromServer(getPlayer(), command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    end
end

function WL_ClientServerBase:receiveFromClient(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if self[command] then
        self[command](self, player, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    else
        print("Unknown command: " .. command) -- Todo better logging
    end
end

function WL_ClientServerBase:receiveFromServer(player, command, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    if self[command] then
        self[command](self, player, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
    else
        print("Unknown command: " .. command) -- Todo better logging
    end
end

function WL_ClientServerBase:savePrivateData()
    if isClient() then
        print("Only the server can save private data") -- Todo better logging
    end

    ModData.add(self.systemName .. ":private", self.privateData)
end

-- Function to recursively duplicate a table
local function duplicateTable(original, seenTables)
    if type(original) ~= "table" then
        return original
    end
    seenTables = seenTables or {}
    if seenTables[original] then
        return seenTables[original]
    end

    local currentCopy = {}
    seenTables[original] = currentCopy
    for key, value in pairs(original) do
        if type(value) == "table" then
            currentCopy[key] = duplicateTable(value, seenTables)
        else
            currentCopy[key] = value
        end
    end

    return currentCopy
end

local DIFF_SET = 1
local DIFF_CHANGE = 2
local DIFF_REMOVE = 3
local function getDiff(newData, oldData)
    if type(newData) ~= "table" or type(oldData) ~= "table" then
        return newData
    end

    local diff = {}
    for key, value in pairs(newData) do
        if oldData[key] == nil then
            diff[key] = {DIFF_SET, value}
        elseif oldData[key] ~= value then
            if type(value) == "table" and type(oldData[key]) == "table" then
                diff[key] = {DIFF_CHANGE, getDiff(value, oldData[key])}
            else
                diff[key] = {DIFF_SET, value}
            end
        end
    end
    for key, _ in pairs(oldData) do
        if newData[key] == nil then
            diff[key] = {DIFF_REMOVE}
        end
    end
    return diff
end

--- Function to apply a set of differences to a data table
local function applyDiff(data, diff)
    for key, change in pairs(diff) do
        if change[1] == DIFF_SET then
            data[key] = change[2]
        elseif change[1] == DIFF_CHANGE then
            if type(data[key]) ~= "table" then
                data[key] = {}
            end
            applyDiff(data[key], change[2])
        elseif change[1] == DIFF_REMOVE then
            data[key] = nil
        end
    end
    return data
end

local function recursiveTableAppend(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            recursiveTableAppend(target[key], value)
        else
            target[key] = value
        end
    end
end

--- Appends the data to public data, and transmits just this diff
--- to clients. This is useful for large data sets where we don't want
--- to transmit the entire data set every time.
--- @param data table The data to append
function WL_ClientServerBase:appendPublicData(data)
    if isClient() then
        print("Only the server can append public data") -- Todo better logging
    end

    if not self.publicData then
        self.publicData = {}
    end

    for key, value in pairs(data) do
        if type(value) == "table" then
            if not self.publicData[key] then
                self.publicData[key] = {}
            end
            recursiveTableAppend(self.publicData[key], value)
        else
            self.publicData[key] = value
        end
    end

    self:sendToAllClients("receivePartialPublicData", data)
end

function WL_ClientServerBase:receivePartialPublicData(player, data)
    if isServer() then
        print("Only the client can receive partial public data") -- Todo better logging
    else
        if not self.publicData then
            self.publicData = {}
        end

        for key, value in pairs(data) do
            if type(value) == "table" then
                if not self.publicData[key] then
                    self.publicData[key] = {}
                end
                recursiveTableAppend(self.publicData[key], value)
            else
                self.publicData[key] = value
            end
        end

        self:onPublicDataUpdated()
    end
end

--- Saves the public data
--- @param transmit boolean|nil Transmit the data to clients, defaults true
function WL_ClientServerBase:savePublicData(transmit)
    if isClient() then
        print("Only the server can save public data") -- Todo better logging
    end

    ModData.add(self.systemName .. ":public", self.publicData)
    if transmit == nil or transmit == true then
        if isServer() then
            if not self.enablePartialTransmit then
                ModData.transmit(self.systemName .. ":public", self.publicData)
            else
                local diff = getDiff(self.publicData, self.lastPublicData)
                self:sendToAllClients("receivePublicDataDiff", diff)
                self.lastPublicData = duplicateTable(self.publicData)
            end
        else
            self:onPublicDataUpdated()
        end
    end
end

function WL_ClientServerBase:receivePublicDataDiff(player, diff)
    if isServer() then
        print("Only the client can receive client data") -- Todo better logging
    else
        applyDiff(self.publicData, diff)
        self:onPublicDataUpdated()
    end
end

function WL_ClientServerBase:receivePublicData(data)
    if isServer() then
        print("Only the client can receive client data") -- Todo better logging
    else
        self.publicData = data
        self:onPublicDataUpdated()
    end
end

function WL_ClientServerBase:modDataInit()
    if isClient() then
        if self.needsPublicData then
            ModData.request(self.systemName .. ":public")
        end
    else
        if self.needsPrivateData then
            self.privateData = ModData.getOrCreate(self.systemName .. ":private")
            self.privateData = self.privateData or self.defaultPrivateData or {}
        end
        if self.needsPublicData then
            self.publicData = ModData.getOrCreate(self.systemName .. ":public")
            self.publicData = self.publicData or self.defaultPublicData or {}
            if self.enablePartialTransmit then
                self.lastPublicData = duplicateTable(self.publicData)
            end
        end
        self:onModDataInit()
    end
end

local function showMessagePopup(message)
    local player = getPlayer():getPlayerNum()
    local w = 300
    local h = 100
    local x = getPlayerScreenLeft(player) + getPlayerScreenWidth(player) / 2 - w / 2
    local y = getPlayerScreenTop(player) + getPlayerScreenHeight(player) / 2 - h / 2
    local popup = ISModalDialog:new(x, y, w, h, message, false)
    popup:initialise()
    popup:addToUIManager()
end

--- this is only needed because client/server communication requires a player object
--- but we don't need it for logging, so this is a workaround
function WL_ClientServerBase:_serverWriteLog(player, message)
    self:writeLog(message)
end

function WL_ClientServerBase:writeLog(message, onServer)
    if isClient() and onServer then
        self:sendToServer(getPlayer(), "_serverWriteLog", message)
        return
    end
    writeLog(self.systemName, message)
end

function WL_ClientServerBase:debugPrint(message)
    if type(message) == "table" then
        message = WL_Utils.tableToString(message)
        print("===[" .. self.systemName .. "]===")
        print(message)
        print("======")
        return
    end
    print("[" .. self.systemName .. "]: " .. tostring(message))
end

function WL_ClientServerBase:logInfo(message, onServer)
    self:writeLog("[INFO]: " .. tostring(message), onServer)
end

function WL_ClientServerBase:logError(message, onServer)
    self:writeLog("[ERROR]: " .. tostring(message), onServer)
end

function WL_ClientServerBase:showPlayerError(player, message)
    if isServer() then
        self:sendToClient(player, "showPlayerError", message)
    else
        showMessagePopup(message)
    end
end

function WL_ClientServerBase:__DEBUG__reset()
    if isClient() then
        self:sendToServer(getPlayer(), "__DEBUG__reset")
    else
        self.privateData = {}
        self.publicData = {}
        self.lastPublicData = {}
        self:onModDataInit()
        self:savePrivateData()
        self:savePublicData()
    end
end

Events.OnReceiveGlobalModData.Add(function (key, data)
    for _, system in pairs(WL_ClientServerBase.registeredSystems) do
        if key == system.systemName .. ":public" then
            system:receivePublicData(data)
        end
    end
end)

Events.OnInitGlobalModData.Add(function()
    for _, system in pairs(WL_ClientServerBase.registeredSystems) do
        system:modDataInit()
    end
end)

Events.OnClientCommand.Add(function(systemName, command, player, args)
    if WL_ClientServerBase.registeredSystems[systemName] then
        if args and #args then
            WL_ClientServerBase.registeredSystems[systemName]:receiveFromClient(player, command, unpack(args))
        else
            WL_ClientServerBase.registeredSystems[systemName]:receiveFromClient(player, command)
        end
    end
end)

Events.OnServerCommand.Add(function(systemName, command, args)
    local player = getPlayer()
    if WL_ClientServerBase.registeredSystems[systemName] then
        if args and #args then
            WL_ClientServerBase.registeredSystems[systemName]:receiveFromServer(player, command, unpack(args))
        else
            WL_ClientServerBase.registeredSystems[systemName]:receiveFromServer(player, command)
        end
    end
end)
