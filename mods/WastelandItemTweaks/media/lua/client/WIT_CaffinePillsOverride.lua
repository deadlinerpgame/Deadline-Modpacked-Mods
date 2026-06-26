local original_ISTakePillAction_perform = ISTakePillAction.perform
function ISTakePillAction:perform()
    if self.item:getType() == "PillsCaffeine" then
        local playerStats = self.character:getStats()
        local newEndurance = math.min(1, playerStats:getEndurance() + 0.3)
        playerStats:setEndurance(newEndurance)
    end
    return original_ISTakePillAction_perform(self)
end