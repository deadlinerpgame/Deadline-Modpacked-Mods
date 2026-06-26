WL_UserData = WL_UserData or {}

WL_UserData._callbacks = WL_UserData._callbacks or {}
WL_UserData._listeners = WL_UserData._listeners or {}

local function appendCallback(tbl, func)
    table.insert(tbl, func)
end

local function removeCallback(tbl, func)
    if not tbl then return end
    for i, v in ipairs(tbl) do
        if v == func then
            table.remove(tbl, i)
            return
        end
    end
end

local function executeCallbacks(tbl, data, username, dataKey)
    if not tbl then return end
    for _, v in ipairs(tbl) do
        v(data, username, dataKey)
    end
end

local function getPlayerUsername()
    return getPlayer():getUsername()
end

local function parseUsernameCallback(usernameOrCallback, callback)
    if callback == nil then
        callback = usernameOrCallback
        usernameOrCallback = getPlayerUsername()
    end
    return usernameOrCallback, callback
end

local function ensureUsernameData(username, dataKey)
    if not WL_UserData._callbacks[username] then
        WL_UserData._callbacks[username] = {}
    end
    if not WL_UserData._callbacks[username][dataKey] then
        WL_UserData._callbacks[username][dataKey] = {}
    end
    if not WL_UserData._listeners[username] then
        WL_UserData._listeners[username] = {}
    end
    if not WL_UserData._listeners[username][dataKey] then
        WL_UserData._listeners[username][dataKey] = {}
    end
end

function WL_UserData._onDataReceived(dataKey, username, data)
    ensureUsernameData(username, dataKey)
    executeCallbacks(WL_UserData._callbacks[username][dataKey], data, username, dataKey)
    executeCallbacks(WL_UserData._listeners[username][dataKey], data, username, dataKey)
    WL_UserData._callbacks[username][dataKey] = {}
end

--- Get the data for a specific key
--- @param dataKey string The key to get the data for
--- @param usernameOrCallback string|function|nil The username to get the data for, or a callback function
--- @param callback function|nil The callback function
function WL_UserData.Fetch(dataKey, usernameOrCallback, callback)
    local username, callback = parseUsernameCallback(usernameOrCallback, callback)
    ensureUsernameData(username, dataKey)
    if callback then
        appendCallback(WL_UserData._callbacks[username][dataKey], callback)
    end
    sendClientCommand(getPlayer(), "WL_UserData", "Fetch", {dataKey, username})
end

--- Set the data for a specific key
--- @param dataKey string The key to set the data for
--- @param data any The data to set
--- @param username string|nil The username to set the data for
function WL_UserData.Set(dataKey, data, username, skipBroadcast)
    if skipBroadcast == nil then skipBroadcast = false end
    if not username then username = getPlayerUsername() end
    sendClientCommand(getPlayer(), "WL_UserData", "Set", {dataKey, username, data, skipBroadcast})
end

--- Append the data for a specific key
--- @param dataKey string The key to append the data for
--- @param data any The data to append
--- @param username string|nil The username to append the data for
--- @param skipBroadcast boolean|nil Whether to skip broadcasting the change to other clients
function WL_UserData.Append(dataKey, data, username, skipBroadcast)
    if skipBroadcast == nil then skipBroadcast = false end
    if not username then username = getPlayerUsername() end
    sendClientCommand(getPlayer(), "WL_UserData", "Append", {dataKey, username, data, skipBroadcast})
end

--- Listen for changes to a specific key
--- @param dataKey string The key to listen for changes to
--- @param usernameOrCallback string|function The username to listen for changes to, or a callback function
--- @param callback function|nil The callback function
function WL_UserData.Listen(dataKey, usernameOrCallback, callback)
    local username, callback = parseUsernameCallback(usernameOrCallback, callback)
    ensureUsernameData(username, dataKey)
    appendCallback(WL_UserData._listeners[username][dataKey], callback)
    sendClientCommand(getPlayer(), "WL_UserData", "Listen", {dataKey, username})
end

--- Stop listening for changes to a specific key
--- @param dataKey string The key to stop listening for changes to
--- @param usernameOrCallback string|function The username to stop listening for changes to, or a callback function
--- @param callback function|nil The callback function
function WL_UserData.StopListening(dataKey, usernameOrCallback, callback)
    local username, callback = parseUsernameCallback(usernameOrCallback, callback)
    ensureUsernameData(username, dataKey)
    removeCallback(WL_UserData._listeners[username][dataKey], callback)
    if #WL_UserData._listeners[username][dataKey] == 0 then
        sendClientCommand(getPlayer(), "WL_UserData", "StopListening", {dataKey, username})
    end
end
