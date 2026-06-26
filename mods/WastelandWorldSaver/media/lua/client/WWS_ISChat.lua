local function infoLine(msg)
    WL_Utils.addInfoToChat(msg)
end

local function finishChat(command)
    ISChat.instance:unfocus()
    ISChat.instance:logChatCommand(command)
    doKeyPress(false)
    ISChat.instance.timerTextEntry = 20
end

local ctRed = "<RGB:1.0,0.5,0.5>"
local ctGreen = "<RGB:0.5,1.0,0.5>"
-- local ctBlue = "<RGB:0.5,0.5,1.0>"
local ctLBlue = "<RGB:0.7,0.7,1.0>"
-- local ctLGrey = "<RGB:0.7,0.7,0.7>"
local ctGrey = "<RGB:0.5,0.5,0.5>"
-- local ctWhite = "<RGB:1.0,1.0,1.0>"

local setX1 = "<SETX:10>"
-- local setX2 = "<SETX:30>"
-- local setX3 = "<SETX:80>"
-- local setX4 = "<SETX:130>"
-- local setX5 = "<SETX:175>"

local original_ISChat_onCommandEntered = ISChat.onCommandEntered
function ISChat:onCommandEntered()
    local command = ISChat.instance.textEntry:getText()
    if command == "/tt" then
        infoLine(ctLBlue .. "Tile Tokens")
        if WWS_Main.availablePickups > 0 then
            infoLine(setX1 .. ctGreen .. "Available: " .. WWS_Main.availablePickups .. " / " .. SandboxVars.WastelandWorldSaver.InitialTokens)
        else
            infoLine(setX1 .. ctRed .. "Available: " .. WWS_Main.availablePickups .. " / " .. SandboxVars.WastelandWorldSaver.InitialTokens)
        end
        if SandboxVars.WastelandWorldSaver.TokensPerRegen and SandboxVars.WastelandWorldSaver.TokenRegenInterval then
            if WWS_Main.availablePickups >= SandboxVars.WastelandWorldSaver.InitialTokens then
                infoLine(setX1 .. ctGrey .. "Regen: At max tokens")
            else
                local hoursRemaining = math.max(0, SandboxVars.WastelandWorldSaver.TokenRegenInterval - math.floor((getTimestamp() - WWS_Main.lastIssued) / 3600))
                if hoursRemaining > 0 then
                    infoLine(setX1 .. ctGrey .. "Regen: " .. hoursRemaining .. " hours")
                else
                    infoLine(setX1 .. ctGrey .. "Regen: shortly")
                end
            end
        end
        finishChat(command)
        return
    end
    return original_ISChat_onCommandEntered(self)
end