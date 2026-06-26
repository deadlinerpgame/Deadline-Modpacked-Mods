---
--- WIT_ClipboardAction.lua
--- 14/11/2024
---

require "TimedActions/ISBaseTimedAction"

WIT_ClipboardAction = ISBaseTimedAction:derive("ISReadAdBoard");

local function doEmote(emote, playerObject)
    --local playerObject = getSpecificPlayer(0)
    playerObject:playEmote(emote)
    if SandboxVars.TTRPPoses.ToggleGhosting then
    playerObject:setGhostMode(true)
    end
end

local function cancelEmote(emote, playerObject)
    --local playerObject = getSpecificPlayer(0)
    playerObject:playEmote(emote)
    if not isAdmin() then
        playerObject:setGhostMode(false)
    end
end

function WIT_ClipboardAction:isValid() 
    return true;
end

function WIT_ClipboardAction:stop() 
    ISBaseTimedAction.stop(self); 
    if self.readOnly then
        cancelEmote("BobRPS_Cancel", self.character)
    end
end


function WIT_ClipboardAction:update()

end

function WIT_ClipboardAction:waitToStart()
    return false;
end

function WIT_ClipboardAction:start()
    if not self.readOnly then
        self:setAnimVariable("ReadType", "newspaper");
        self:setActionAnim(CharacterActionAnims.Read);
        self:setOverrideHandModels(nil, self.item)        
    else
        doEmote("TTRP_Pondering", self.character)
    end
end

function WIT_ClipboardAction:perform()
    ISBaseTimedAction.perform(self);
end

function WIT_ClipboardAction:new(character, clipboard, readOnly)
    local o = {};
    setmetatable(o, self);
    self.__index = self;
    o.character = character;
    o.item = clipboard;
    o.readOnly = readOnly;
    o.useProgressBar = false;
    o.stopOnWalk = false;
    o.maxDistance = 5;
    o.delay = 5;
    o.stopOnRun = true;
    o.maxTime = -1;
    return o;
end
