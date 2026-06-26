WL_PlayerReady = WL_PlayerReady or {}
WL_PlayerReady._callbacks = WL_PlayerReady._callbacks or {}
WL_PlayerReady._pendingReadyPlayers = {}

function WL_PlayerReady.Add(callback)
    table.insert(WL_PlayerReady._callbacks, callback)
end

function WL_PlayerReady.Remove(callback)
    for i, v in ipairs(WL_PlayerReady._callbacks) do
        if v == callback then
            table.remove(WL_PlayerReady._callbacks, i)
            return
        end
    end
end

function WL_PlayerReady._onTick()
    for i = #WL_PlayerReady._pendingReadyPlayers, 1, -1 do
        local pendingReadyPlayer = WL_PlayerReady._pendingReadyPlayers[i]
        pendingReadyPlayer.ticks = pendingReadyPlayer.ticks - 1
        if pendingReadyPlayer.ticks <= 0 then
            for _, callback in ipairs(WL_PlayerReady._callbacks) do
                callback(pendingReadyPlayer.playerIndex, pendingReadyPlayer.player)
            end
            table.remove(WL_PlayerReady._pendingReadyPlayers, i)
        end
    end
    if #WL_PlayerReady._pendingReadyPlayers == 0 then
        Events.OnTick.Remove(WL_PlayerReady._onTick)
    end
end

function WL_PlayerReady._onCreatePlayer(playerIndex, player)
    table.insert(WL_PlayerReady._pendingReadyPlayers, {
        playerIndex = playerIndex,
        player = player,
        ticks = 20,
    })
    if #WL_PlayerReady._pendingReadyPlayers == 1 then
        Events.OnTick.Add(WL_PlayerReady._onTick)
    end
end

Events.OnCreatePlayer.Add(WL_PlayerReady._onCreatePlayer)