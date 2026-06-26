ISInventoryMenuElements = ISInventoryMenuElements or {}

function ISInventoryMenuElements.ContextZombieEars()
    local self = ISMenuElement.new()
    self.invMenu = ISContextManager.getInstance().getInventoryMenu()

    function self.init()
        self.zombieEar = nil
        self.zombieEarRope = nil
    end

    function self.createMenu(item)
        self.zombieEar = nil
        self.zombieEarRope = nil

        if item:getType() == "ZombieEar" then
            if not self.invMenu.player:getInventory():containsRecursive(item) then return end
            self.zombieEar = item
            self.doEarMenu()
        end

        if item:getType() == "ZombieEarRope" then
            if not self.invMenu.player:getInventory():contains(item) then return end
            self.zombieEarRope = item

            self.doRopeMenu()
        end
    end

    function self.doEarMenu()
        self.zombieEarRope = self.invMenu.player:getInventory():getFirstTypeEval("ZombieEarRope", function(x) return x:getModData().countUsed < 500 end)

        if self.zombieEarRope then
            self.invMenu.context:addOption(getText("ContextMenu_Tie1Ear"), 1, self.tieEars)
        end
    end

    function self.doRopeMenu()
        local countUsed = self.zombieEarRope:getModData().countUsed or 0
        local countEars = self.invMenu.player:getInventory():getCountTypeRecurse("ZombieEar")
        if countEars > 0 and countUsed < 300 then
            self.invMenu.context:addOption(getText("ContextMenu_Tie1Ear"), 1, self.tieEars)
        end
        if countEars >= 5 and countUsed < 296 then
            self.invMenu.context:addOption(getText("ContextMenu_Tie5Ears"), 5, self.tieEars)
        end
        if countEars > 1 and countUsed < 299 then
            self.invMenu.context:addOption(getText("ContextMenu_TieAllEars"), countEars, self.tieEars)
        end
        if countUsed > 0 then
            self.invMenu.context:addOption(getText("ContextMenu_Untie1Ear"), 1, self.untieEars)
        end
        if countUsed >= 5 then
            self.invMenu.context:addOption(getText("ContextMenu_Untie5Ears"), 5, self.untieEars)
        end
        if countUsed > 1 then
            self.invMenu.context:addOption(getText("ContextMenu_UntieAllEars"), countUsed, self.untieEars)
        end
    end

    function self.tieEars(count)
        if not self.zombieEar then
            self.zombieEar = self.invMenu.player:getInventory():getFirstTypeRecurse("ZombieEar")
        end
        if not self.zombieEar then return end
        ISTimedActionQueue.add(TieEarAction:new(self.invMenu.player, self.zombieEarRope, self.zombieEar, count))
    end

    function self.untieEars(count)
        ISTimedActionQueue.add(UntieEarAction:new(self.invMenu.player, self.zombieEarRope, count))
    end

    return self
end

TieEarAction = ISBaseTimedAction:derive("TieEarAction")

function TieEarAction:new(character, rope, ear, count)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.ear = ear
    o.rope = rope
    o.count = count
    o.maxTime = 10
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function TieEarAction:isValid()
    return self.character:getInventory():containsRecursive(self.ear) and
           self.character:getInventory():contains(self.rope) and
           self.rope:getModData().countUsed < 500
end

function TieEarAction:perform()
    self.ear:getContainer():DoRemoveItem(self.ear)
    local ropeMd = self.rope:getModData()
    ropeMd.countUsed = (ropeMd.countUsed or 0) + 1
    self.rope:setName("Zombie Ear Rope [" .. ropeMd.countUsed .. "]")

    if self.count > 1 then
        local ear = self.character:getInventory():getFirstTypeEvalRecurse("ZombieEar", function(x) return x ~= self.ear end)
        if ear and ropeMd.countUsed < 500 then
            ISTimedActionQueue.add(TieEarAction:new(self.character, self.rope, ear, self.count - 1))
        end
    end
    ISBaseTimedAction.perform(self)
end

UntieEarAction = ISBaseTimedAction:derive("UntieEarAction")

function UntieEarAction:new(character, rope, count)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
    o.rope = rope
    o.count = count or 1
    o.maxTime = 10
    o.stopOnWalk = true
    o.stopOnRun = true
    return o
end

function UntieEarAction:isValid()
    return self.character:getInventory():contains(self.rope) and self.rope:getModData().countUsed > 0
end

function UntieEarAction:perform()
    local ropeMd = self.rope:getModData()
    ropeMd.countUsed = (ropeMd.countUsed or 0) - 1
    self.rope:setName("Zombie Ear Rope [" .. ropeMd.countUsed .. "]")
    self.character:getInventory():AddItem("ZombieEar")
    if ropeMd.countUsed == 0 then
        self.character:getInventory():DoRemoveItem(self.rope)
        local twine = self.character:getInventory():AddItem("Twine")
        twine:setUsedDelta(0.2)
    end
    if self.count > 1 then
        ISTimedActionQueue.add(UntieEarAction:new(self.character, self.rope, self.count - 1))
    end
    ISBaseTimedAction.perform(self)
end

local myZombieEarDrops = {}

local function OnGotZombieDropData(data)
    myZombieEarDrops = data
end

local function OnZombieDead(zombie)
    local event = SandboxVars.WastelandItemTweaks.CurrentZombieEarEvent
    if not event or event == "" or event == "None" then return end

    local attackedBy = zombie:getAttackedBy()
    if attackedBy ~= getPlayer() then return end

    if not myZombieEarDrops[event] then
        myZombieEarDrops[event] = 0
    end
    if myZombieEarDrops[event] >= SandboxVars.WastelandItemTweaks.MaxZombieEarsPerPlayer then return end

    if myZombieEarDrops[event] < SandboxVars.WastelandItemTweaks.EarsFullDrop or ZombRand(2) == 0 then
        local item = "ZombieEar"
        local inventory = zombie:getInventory()
        inventory:AddItem(item)
        myZombieEarDrops[event] = myZombieEarDrops[event] + 1
        WL_UserData.Append("WIT_EarDrops", { [event] = myZombieEarDrops[event] }, attackedBy:getUsername(), true)
    end
end

WL_PlayerReady.Add(function(playerNum, playerObj)
    local username = playerObj:getUsername()
    WL_UserData.Fetch("WIT_EarDrops", username, OnGotZombieDropData)
end)
Events.OnPlayerDeath.Add(function(player)
    myZombieEarDrops = {}
end)
Events.OnZombieDead.Add(OnZombieDead)