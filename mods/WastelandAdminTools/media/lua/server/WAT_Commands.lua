local function WAT_moveHordeToPosition(x, y, z, d)
    local sx = math.floor(x) - d
    local sy = math.floor(y) - d
    local ex = sx + d*2
    local ey = sy + d*2
    for cx = sx,ex do for cy = sy,ey do for cz = 0,7 do
        local square = getCell():getGridSquare(cx, cy, cz)
        if square then
            local movingEntities = square:getMovingObjects()
            for i=0,movingEntities:size()-1 do
                local movingEntity = movingEntities:get(i)
                if instanceof(movingEntity, "IsoZombie") then
                    movingEntity:pathToLocationF(x, y, z)
                end
            end
        end
    end end end
end

local BasementData = {}
local BasementTemplateData = {}
local BasementGridConfig = {
    startX = 10000,
    startY = 10000,
    spacingX = 50,
    spacingY = 50,
    maxX = 20,
    maxY = 20
}

--- Saves or updates a basement instance
--- @param args table Basement instance data with key field
local function WAT_FinishBasement(args)
    BasementData[args.key] = args
    ModData.add("WAT_Basements", BasementData)
    ModData.transmit("WAT_Basements")
end

--- Removes a basement instance
--- @param args table Contains key field
local function WAT_RemoveBasement(args)
    BasementData[args.key] = nil
    ModData.add("WAT_Basements", BasementData)
    ModData.transmit("WAT_Basements")
end

--- Updates an existing basement's teleport points and/or name
--- @param args table Contains key and updated fields
local function WAT_UpdateBasement(args)
    if not args.key or not BasementData[args.key] then
        return
    end
    local basement = BasementData[args.key]
    -- Update only provided fields
    if args.name ~= nil then basement.name = args.name end
    if args.outX1 ~= nil then basement.outX1 = args.outX1 end
    if args.outY1 ~= nil then basement.outY1 = args.outY1 end
    if args.outZ1 ~= nil then basement.outZ1 = args.outZ1 end
    if args.inX1 ~= nil then basement.inX1 = args.inX1 end
    if args.inY1 ~= nil then basement.inY1 = args.inY1 end
    if args.inZ1 ~= nil then basement.inZ1 = args.inZ1 end
    if args.outX2 ~= nil then basement.outX2 = args.outX2 end
    if args.outY2 ~= nil then basement.outY2 = args.outY2 end
    if args.outZ2 ~= nil then basement.outZ2 = args.outZ2 end
    if args.inX2 ~= nil then basement.inX2 = args.inX2 end
    if args.inY2 ~= nil then basement.inY2 = args.inY2 end
    if args.inZ2 ~= nil then basement.inZ2 = args.inZ2 end
    if args.templateId ~= nil then basement.templateId = args.templateId end
    ModData.add("WAT_Basements", BasementData)
    ModData.transmit("WAT_Basements")
end

--- Adds or updates a basement template (pure async - only responds to requesting player)
--- @param args table Template data with id field
--- @param player IsoPlayer The player who sent the command
local function WAT_AddBasementTemplate(args, player)
    if not args.id then
        sendServerCommand(player, "WAT", "basementTemplateAdded", {
            error = "No template ID provided"
        })
        return
    end
    BasementTemplateData[args.id] = args
    ModData.add("WAT_BasementTemplates", BasementTemplateData)
    -- Send confirmation back to the requesting player only
    sendServerCommand(player, "WAT", "basementTemplateAdded", {
        id = args.id,
        name = args.name
    })
end

--- Removes a basement template (pure async - only responds to requesting player)
--- @param args table Contains id field
--- @param player IsoPlayer The player who sent the command
local function WAT_DeleteBasementTemplate(args, player)
    if not args.id then
        sendServerCommand(player, "WAT", "basementTemplateDeleted", {
            error = "No template ID provided"
        })
        return
    end
    BasementTemplateData[args.id] = nil
    ModData.add("WAT_BasementTemplates", BasementTemplateData)
    -- Send confirmation back to the requesting player only
    sendServerCommand(player, "WAT", "basementTemplateDeleted", {
        id = args.id
    })
end

--- Sends the list of template names/metadata to a specific player (async request/response)
--- @param player IsoPlayer The player to send the list to
local function WAT_SendTemplateList(player)
    local templateList = {}
    for id, template in pairs(BasementTemplateData) do
        table.insert(templateList, {
            id = id,
            name = template.name or "Unnamed"
        })
    end
    sendServerCommand(player, "WAT", "basementTemplateList", {
        templates = templateList,
        gridConfig = BasementGridConfig
    })
end

--- Sends a specific template's full data to a requesting player (async request/response)
--- @param args table Contains templateId field
--- @param player IsoPlayer The player requesting the template
local function WAT_RequestTemplate(args, player)
    if not args.templateId then
        sendServerCommand(player, "WAT", "basementTemplateData", {
            error = "No template ID provided"
        })
        return
    end
    local template = BasementTemplateData[args.templateId]
    if not template then
        sendServerCommand(player, "WAT", "basementTemplateData", {
            error = "Template not found",
            templateId = args.templateId
        })
        return
    end
    -- Send the full template data to the requesting player only
    sendServerCommand(player, "WAT", "basementTemplateData", {
        template = template,
        gridConfig = BasementGridConfig
    })
end
local function WAT_tileUp(x, y, z, i)
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local arraylist = ArrayList:new()
        local objs = square:getObjects()
        for j=1, objs:size() do
            if j-1 == i-1 then
                arraylist:add(objs:get(j))
            elseif j-1 == i then
                arraylist:add(objs:get(j-2))
            else
                arraylist:add(objs:get(j-1))
            end
        end
        objs:clear()
        for j=1, arraylist:size() do
            objs:add(arraylist:get(j-1))
        end
    else
        print("WAT_tileUp: square is nil: " .. x .. ", " .. y .. ", " .. z)
    end
end

local function WAT_tileDown(x, y, z, i)
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local arraylist = ArrayList:new()
        local objs = square:getObjects()
        for j=1, objs:size() do
            if j-1 == i then
                arraylist:add(objs:get(j))
            elseif j-1 ==i+1 then
                arraylist:add(objs:get(j-2))
            else
                arraylist:add(objs:get(j-1))
            end
        end
        objs:clear()
        for j=1, arraylist:size() do
            objs:add(arraylist:get(j-1))
        end
    else
        print("WAT_tileDown: square is nil: " .. x .. ", " .. y .. ", " .. z)
    end
end

function WAT_RemoveAttachedAnim(x, y, z, spriteName, index)
    if not index then return end
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local objs = square:getObjects()
        for i=1, objs:size() do
            local obj = objs:get(i-1)
            if obj and obj:getSprite():getName() == spriteName and obj:getAttachedAnimSprite() then
                obj:RemoveAttachedAnim(index)
            end
        end
    else
        print("WAT_RemoveAttachedAnim: square is nil: " .. x .. ", " .. y .. ", " .. z)
    end
end

local function WAT_AddAttachedAnim(x, y, z, targetIndex, spriteName)
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local objects = square:getObjects()
        if targetIndex >= 0 and targetIndex < objects:size() then
            local object = objects:get(targetIndex)
            local sprite = getSprite(spriteName)
            if object and sprite then
                object:AttachExistingAnim(sprite, 0, 0, false, 0, false, 0)
            end
        end
    end
end

local function WAT_moveObjectToIndex(x, y, z, fromIndex, toIndex)
    local square = getCell():getGridSquare(x, y, z)
    if square then
        local objects = square:getObjects()
        if fromIndex < 0 or fromIndex >= objects:size() or toIndex < 0 or toIndex >= objects:size() then
            return
        end

        local tempArray = ArrayList:new()
        for j=0, objects:size()-1 do
            if j == fromIndex then
                -- skip
            elseif j == toIndex then
                tempArray:add(objects:get(fromIndex))
            else
                tempArray:add(objects:get(j))
            end
        end
        objects:clear()
        for j=0, tempArray:size()-1 do
            objects:add(tempArray:get(j))
            square:transmitAddObjectToSquare(tempArray:get(j), j)
        end
    end
end

--- Updates the global grid configuration
--- @param args table Contains gridConfig fields
--- @param player IsoPlayer The player who sent the command
local function WAT_UpdateGridConfig(args, player)
    if args.startX then BasementGridConfig.startX = args.startX end
    if args.startY then BasementGridConfig.startY = args.startY end
    if args.spacingX then BasementGridConfig.spacingX = args.spacingX end
    if args.spacingY then BasementGridConfig.spacingY = args.spacingY end
    if args.maxX then BasementGridConfig.maxX = args.maxX end
    if args.maxY then BasementGridConfig.maxY = args.maxY end
    
    ModData.add("WAT_BasementGridConfig", BasementGridConfig)
    
    -- Send confirmation back to the requesting player
    sendServerCommand(player, "WAT", "gridConfigUpdated", {
        gridConfig = BasementGridConfig
    })
end

local function WAT_SetWorldTime(args, player)
    if not player then return end

    local year = tonumber(args.year) or getGameTime():getYear()
    local month = (tonumber(args.month) or (getGameTime():getMonth() + 1)) - 1
    local day = (tonumber(args.day) or (getGameTime():getDay() + 1)) - 1
    local hour = tonumber(args.hour) or getGameTime():getHour()
    local minute = tonumber(args.minute) or getGameTime():getMinutes()

    year = math.floor(year)
    month = math.max(0, math.min(11, math.floor(month)))
    day = math.max(0, math.min(30, math.floor(day)))
    hour = math.max(0, math.min(23, math.floor(hour)))
    minute = math.max(0, math.min(59, math.floor(minute)))

    local gameTime = getGameTime()
    gameTime:setYear(year)
    gameTime:setMonth(month)
    gameTime:setDay(day)
    gameTime:setTimeOfDay(hour + (minute / 60))

    sendServerCommand("WAT", "applyWorldTime", {
        year = year,
        month = month,
        day = day,
        hour = hour,
        minute = minute,
    })
end

--- Sends the current grid configuration to a requesting player
--- @param player IsoPlayer The player requesting the config
local function WAT_RequestGridConfig(player)
    sendServerCommand(player, "WAT", "gridConfigData", {
        gridConfig = BasementGridConfig
    })
end

Events.OnClientCommand.Add(function (module, command, player, args)
    if module ~= "WAT" then
        return
    end

    if command == "reboot" then
        PzWebStats.RequestReboot("", "medium")
    elseif command == "simpleRepair" then
        WAT_simpleRepair(args.vehicle)
    elseif command == "moveHordeToPosition" then
        WAT_moveHordeToPosition(args.x, args.y, args.z, args.d)
    elseif command == "finishBasement" then
        WAT_FinishBasement(args)
    elseif command == "removeBasement" then
        WAT_RemoveBasement(args)
    elseif command == "updateBasement" then
        WAT_UpdateBasement(args)
    elseif command == "addBasementTemplate" then
        WAT_AddBasementTemplate(args, player)
    elseif command == "deleteBasementTemplate" then
        WAT_DeleteBasementTemplate(args, player)
    elseif command == "requestTemplateList" then
        WAT_SendTemplateList(player)
    elseif command == "requestTemplate" then
        WAT_RequestTemplate(args, player)
    elseif command == "updateGridConfig" then
        WAT_UpdateGridConfig(args, player)
    elseif command == "requestGridConfig" then
        WAT_RequestGridConfig(player)
    elseif command == "setWorldTime" then
        WAT_SetWorldTime(args, player)
    elseif command == "tileUp" then
        WAT_tileUp(args.x, args.y, args.z, args.i)
    elseif command == "tileDown" then
        WAT_tileDown(args.x, args.y, args.z, args.i)
    elseif command == "removeAttachedAnim" then
        WAT_RemoveAttachedAnim(args.x, args.y, args.z, args.spriteName, args.index)
    elseif command == "moveObjectToIndex" then
        WAT_moveObjectToIndex(args.x, args.y, args.z, args.fromIndex, args.toIndex)
    elseif command == "addAttachedAnim" then
        WAT_AddAttachedAnim(args.x, args.y, args.z, args.targetIndex, args.spriteName)
    end
end)

Events.OnInitGlobalModData.Add(function()
    BasementData = ModData.getOrCreate("WAT_Basements") or {}
    BasementTemplateData = ModData.getOrCreate("WAT_BasementTemplates") or {}
    local loadedGridConfig = ModData.getOrCreate("WAT_BasementGridConfig")
    if loadedGridConfig and loadedGridConfig.startX then
        BasementGridConfig = loadedGridConfig
    end
end)
