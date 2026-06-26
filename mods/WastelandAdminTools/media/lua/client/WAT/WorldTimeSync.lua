WAT_WorldTimeSync = WAT_WorldTimeSync or {}

function WAT_WorldTimeSync.apply(args)
    local gameTime = getGameTime()
    local year = tonumber(args.year) or gameTime:getYear()
    local month = tonumber(args.month) or gameTime:getMonth()
    local day = tonumber(args.day) or gameTime:getDay()
    local hour = tonumber(args.hour) or gameTime:getHour()
    local minute = tonumber(args.minute) or gameTime:getMinutes()

    gameTime:setYear(year)
    gameTime:setMonth(month)
    gameTime:setDay(day)
    gameTime:setTimeOfDay(hour + (minute / 60))
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "WAT" then return end
    if command ~= "applyWorldTime" then return end
    WAT_WorldTimeSync.apply(args)
end)
