local Commands = {}

--- Handle full sync from server (attractors + enabled states)
--- @param args table
function Commands.FullSync(args)
    if args and args.attractors and args.enabledStates then
        WLZA_Client:updateFullSync(args.attractors, args.enabledStates)
        if WLZA_AttractorListWindow and WLZA_AttractorListWindow.instance then
            WLZA_AttractorListWindow.instance:populateList()
        end
    end
end

--- Handle single attractor add/update from server
--- @param args table
function Commands.AddAttractor(args)
    if args and args.attractor then
        WLZA_Client:addAttractor(args.attractor)
        if WLZA_AttractorListWindow and WLZA_AttractorListWindow.instance then
            WLZA_AttractorListWindow.instance:populateList()
        end
    end
end

--- Handle attractor removal from server
--- @param args table
function Commands.RemoveAttractor(args)
    if args and args.attractorId then
        WLZA_Client:removeAttractor(args.attractorId)
        if WLZA_AttractorListWindow and WLZA_AttractorListWindow.instance then
            WLZA_AttractorListWindow.instance:populateList()
        end
    end
end

--- Handle attractor toggle from server
--- @param args table
function Commands.ToggleAttractor(args)
    if args and args.attractorId and args.enabled ~= nil then
        WLZA_Client:updateAttractorEnabled(args.attractorId, args.enabled)
        if WLZA_AttractorListWindow and WLZA_AttractorListWindow.instance then
            WLZA_AttractorListWindow.instance:populateList()
        end
    end
end

--- Handle delete all attractors from server
--- @param args table
function Commands.DeleteAllAttractors(args)
    WLZA_Client:clearAttractors()
    print("[WLZA_Client] All attractors deleted")
    if WLZA_AttractorListWindow and WLZA_AttractorListWindow.instance then
        WLZA_AttractorListWindow.instance:populateList()
    end
end

local function OnServerCommand(module, command, args)
    if module == "WLZA" then
        if Commands[command] then
            Commands[command](args)
        end
    end
end

Events.OnServerCommand.Add(OnServerCommand)