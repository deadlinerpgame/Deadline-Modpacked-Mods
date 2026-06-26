if isClient() then return end

WL_UserData = WL_UserData or {}
WL_UserData._data = {}
WL_UserData._usersListening = {}

local function getModDataKey(dataKey)
    return "WL_UserData:" .. dataKey
end

local function ensureData(dataKey, username)
    if not WL_UserData._data[dataKey] then
        WL_UserData._data[dataKey] = ModData.getOrCreate(getModDataKey(dataKey)) or {}
    end
    if not WL_UserData._data[dataKey][username] then
        WL_UserData._data[dataKey][username] = {}
    end
    if not WL_UserData._usersListening[dataKey] then
        WL_UserData._usersListening[dataKey] = {}
    end
    if not WL_UserData._usersListening[dataKey][username] then
        WL_UserData._usersListening[dataKey][username] = {}
    end
end

local function clientFetch(player, dataKey, username)
    local data = WL_UserData.GetServer(username, dataKey)
    sendServerCommand(player, "WL_UserData", "Data", {dataKey, username, data})
end

local function clientSet(dataKey, username, data, skipBroadcast)
    WL_UserData.SetServer(username, dataKey, data, skipBroadcast)
end

local function clientAppend(dataKey, username, data, skipBroadcast)
    local currentData = WL_UserData.GetServer(username, dataKey)
    if not currentData then
        currentData = {}
    end
    for k, v in pairs(data) do
        currentData[k] = v
    end
    WL_UserData.SetServer(username, dataKey, currentData, skipBroadcast)
end

local function clientListen(player, dataKey, username)
    ensureData(dataKey, username)
    WL_UserData._usersListening[dataKey][username][player:getUsername()] = true
end

local function clientStopListening(player, dataKey, username)
    ensureData(dataKey, username)
    WL_UserData._usersListening[dataKey][username][player:getUsername()] = nil
end

function WL_UserData.GetServer(username, dataKey)
    ensureData(dataKey, username)
    return WL_UserData._data[dataKey][username]
end

function WL_UserData.SetServer(username, dataKey, data, skipBroadcast)
    ensureData(dataKey, username)
    WL_UserData._data[dataKey][username] = data
    ModData.add(getModDataKey(dataKey), WL_UserData._data[dataKey])

    if skipBroadcast then return end

    local players = getOnlinePlayers()
    for i=0, players:size()-1 do
        local player = players:get(i)
        local playerUsername = player:getUsername()
        if WL_UserData._usersListening[dataKey][username][playerUsername] then
            sendServerCommand(player, "WL_UserData", "Data", {dataKey, username, data})
        end
    end
end

Events.OnClientCommand.Add(function (module, command, player, args)
    if module ~= "WL_UserData" then return end
    if command == "Fetch" then
        clientFetch(player, args[1], args[2])
    elseif command == "Set" then
        clientSet(args[1], args[2], args[3], args[4])
    elseif command == "Append" then
        clientAppend(args[1], args[2], args[3], args[4])
    elseif command == "Listen" then
        clientListen(player, args[1], args[2])
    elseif command == "StopListening" then
        clientStopListening(player, args[1], args[2])
    end
end)