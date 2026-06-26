if isServer() and getActivatedMods():contains("ImmersiveHunting") then
    Events.OnGameBoot.Add(function()
        Events.EveryOneMinute.Remove(SIHOneMinuteDropThatBeat)
    end)
end
