WRU_Options = {
    show_broadcast_indicator = true,
}

WRU_Options_Callbacks = {
    show_broadcast_indicator = function() end,
}

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(WRU_Options, "WastelandRadioUtilites", "Wasteland Radio Utilities")
    local sbiData = settings:getData("show_broadcast_indicator")
    sbiData.name = "UI_WRU_ShowBroadcastIndicator"
    sbiData.tooltip = "UI_WRU_ShowBroadcastIndicator_Tooltip"
    function sbiData:OnApplyInGame()
        WRU_Options_Callbacks.show_broadcast_indicator()
    end
else
    print("Didn't find Mod Options")
    WRU_Options.show_broadcast_indicator = true
end