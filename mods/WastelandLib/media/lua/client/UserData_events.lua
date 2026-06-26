require "UserData"

Events.OnServerCommand.Add(function (module, command, args)
    if module ~= "WL_UserData" then return end
    if command == "Data" then
        WL_UserData._onDataReceived(args[1], args[2], args[3])
    end
end)