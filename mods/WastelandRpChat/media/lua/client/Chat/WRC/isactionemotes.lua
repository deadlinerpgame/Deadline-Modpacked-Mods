WRC = WRC or {}

local walkiePhrases = {
    "interacted with their walkie.",
    "adjusted a walkie's settings.",
    "tweaked their walkie.",
    "checked a walkie.",
    "handled a walkie.",
    "poked at their walkie."
}

local original_ISRadioAction_perform = ISRadioAction.perform
function ISRadioAction:perform()
    original_ISRadioAction_perform(self)
    if self.device
    and instanceof(self.device, "InventoryItem")
    and self.character:getInventory():containsRecursive(self.device)
    and (self.device:getType():sub(1, 12) == "WalkieTalkie" or self.device:getType():sub(1, 8) == "HamRadio") then
        local num = ZombRand(#walkiePhrases - 1) + 1
        WRC.SendLocalEmote(walkiePhrases[num])
    end
end