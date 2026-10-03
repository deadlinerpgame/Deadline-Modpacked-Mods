if not isClient() then return end
require "WRU_Utils"
require "WL_Utils"
WRC = WRC or {}
WRC.RadioInterference = WRC.RadioInterference or {}
local Radio = WRC.RadioInterference

-- Add new full item IDs here. Tier 1: no reduction; 2: -1%; 3: -2%.
Radio.Tiers = {
    ["Radio.WalkieTalkie1"] = 1,
    ["Radio.WalkieTalkie2"] = 1,
    ["Radio.WalkieTalkie3"] = 2,
    ["Radio.WalkieTalkie4"] = 2,
    ["Radio.WalkieTalkie5"] = 3,
    ["Radio.WalkieTalkieMakeShift"] = 1,
    ["Radio.WalkieTalkiePremiumTuned"] = 2, -- new radios will go here
    ["Radio.WalkieTalkieTacticaTuned"] = 3, -- new radios will go here
    ["Radio.HamRadio1"] = 2,
    ["Radio.HamRadio2"] = 3,
    ["Radio.HamRadioMakeShift"] = 1,
    ["Radio.RadioRed"] = 2,
    ["Radio.RadioBlack"] = 1,
    ["Radio.RadioMakeShift"] = 1,
}

function Radio.GetStrength()
    local value = WRC.GlobalState and WRC.GlobalState.radioInterferenceStrength
    if value == 0.5 or value == 2 then return value end
    return 1
end

function Radio.GetChance(player, message, sender)
    if WRC.GlobalState and WRC.GlobalState.radioInterferenceEnabled == false then return 0 end
    local pos = message.pos
    if not pos and sender then pos = {x = sender:getX(), y = sender:getY()} end
    if not pos then return 0 end -- Cannot determine distance like when data gets converted to <bzzt> by client side java
    local dx, dy = player:getX() - pos.x, player:getY() - pos.y
    local distanceSq = dx * dx + dy * dy
    local chance = 20 -- Also applies beyond 5000 tiles
    if distanceSq < 500 * 500 then chance = 5
    elseif distanceSq < 1000 * 1000 then chance = 10
    elseif distanceSq < 2000 * 2000 then chance = 15 end

    local tier = 1
    for _, item in ipairs(WRU_Utils.getPlayerRadios(player, true)) do
        local data = item:getDeviceData()
        if data:getChannel() == message.radioFrequency and data:getDeviceVolume() > 0
            and not data:isPlayingMedia() and not data:getIsTelevision() then
            tier = math.max(tier, Radio.Tiers[item:getFullType()] or 1)
        end
    end
    return math.floor((chance - (tier - 1)) * Radio.GetStrength())
end

function Radio.SetSetting(key, value)
    sendClientCommand(getPlayer(), "WRC", "SetGlobalState", {key, value})
end

function Radio.AddAdminOptions(context, player)
    if not player or not WL_Utils.canModerate(player) then return end
    local root = context:addOption("Radio interference", nil, nil)
    local menu = context:getNew(context)
    context:addSubMenu(root, menu)
    local enabled = not WRC.GlobalState or WRC.GlobalState.radioInterferenceEnabled ~= false
    local option = menu:addOption("Enabled", "radioInterferenceEnabled", Radio.SetSetting, not enabled)
    menu:setOptionChecked(option, enabled)
    for _, preset in ipairs({{"Light", 0.5}, {"Normal", 1}, {"Strong", 2}}) do
        local choice = menu:addOption(preset[1], "radioInterferenceStrength", Radio.SetSetting, preset[2])
        menu:setOptionChecked(choice, Radio.GetStrength() == preset[2])
    end
end
