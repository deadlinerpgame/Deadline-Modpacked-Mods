Events.OnCreatePlayer.Add(function()
    if getActivatedMods():contains("CharacterBio") and SandboxVars.WastelandOptions.NagCharacterBio then
        local ISWriteBio = require "ISWriteBio"
        local didLoad = false
        local delay = 120

        local function OnTick()
            if didLoad then
                Events.OnTick.Remove(OnTick)
                return
            end

            if delay > 0 then
                delay = delay - 1
                return
            end

            local player = getPlayer()
            if not player then
                delay = 20
                return
            end

            sendClientCommand(player, "CharacterBio", "load", {player:getUsername()})
            delay = 120
        end

        local function OnServerCommand(module, command, args)
            if module == "CharacterBio" and command == "load" then
                didLoad = true
                Events.OnServerCommand.Remove(OnServerCommand)
                local bio = args and args.description or "No Bio Set."
                if bio == "No Bio Set." then
                    local FONT_SCALE = getTextManager():getFontHeight(UIFont.Small) / 14
                    local core = getCore()
                    local width = 400 * FONT_SCALE
                    local height = 600 * FONT_SCALE
                    local ui = ISWriteBio:new((core:getScreenWidth() - width)/2, (core:getScreenHeight() - height)/2, width, height, getPlayer(), true)
                    ui:initialise()
                    ui:addToUIManager()
                end
            end
        end

        Events.OnServerCommand.Add(OnServerCommand)
        Events.OnTick.Add(OnTick)
    end
end)