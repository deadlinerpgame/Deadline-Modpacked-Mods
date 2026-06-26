WastelandSeasons = WastelandSeasons or {}

WastelandSeasons.EVENT_DEFINITION_VERSION = 1
WastelandSeasons.SEASON_NAMES = {
    "Spring",
    "Early Summer",
    "Late Summer",
    "Autumn",
    "Winter",
}
WastelandSeasons.PRECIPITATION_TYPES = {
    "none",
    "lightrain",
    "mediumrain",
    "heavyrain",
    "lightsnow",
    "mediumsnow",
    "heavysnow",
}
WastelandSeasons.TRIGGER_TYPES = {
    "blizzard",
    "tropicalstorm",
}
WastelandSeasons.HARM_TYPES = {
    "none",
    "radiation",
    "acid",
}
WastelandSeasons.TEMP_MODES = {
    "none",
    "adjust",
    "target",
}
WastelandSeasons.DEFAULT_WARNING_HOURS = {
    12,
    6,
    3,
    2,
    1,
}

WastelandSeasons.LegacyEvents = {
    ColdSnap = {
        enabled = true,
        name = "Cold Snap",
        chance = 8,
        tempAdjust = { -20, -10 },
        durationHours = { 96, 168 },
        leadupHours = { 96, 168 },
        messages = {
            [2] = "A subtle coolness brushes the air, hinting at a change.",
            [1] = "The air turns brisk as the cold sharpens, hinting at what's to come.",
            start = "Suddenly, the temperature plummets as a cold front sweeps through the area.",
            ["end"] = "The chill dissipates, and normal temperatures slowly returns to the air.",
        }
    },
    HeatWave = {
        enabled = true,
        name = "Heat Wave",
        chance = 8,
        tempAdjust = { 10, 20 },
        durationHours = { 96, 168 },
        leadupHours = { 96, 168 },
        messages = {
            [2] = "A noticeable warmth flows in the air, hinting at an unusual shift.",
            [1] = "The warmth intensifies, becoming increasingly out of step with the seasonal norm.",
            start = "Temperatures climb higher than expected as the heat wave establishes itself.",
            ["end"] = "The anomalous warmth subsides, returning to more typical temperatures.",
        }
    },
}

if isClient() then return end

-- this is temporarily disabled until we can figure out how why its erroring
-- local function OnInitSeasons(season)
--     local tempMin = SandboxVars.WastelandSeasons.TempMin
--     local tempMax = SandboxVars.WastelandSeasons.TempMax
--     if WastelandSeasons.Data and WastelandSeasons.Data.adjustedTemp then
--         print("WastelandSeasons adjusting temp " .. WastelandSeasons.Data.adjustedTemp)
--         tempMin = tempMin + WastelandSeasons.Data.adjustedTemp
--         tempMax = tempMax + WastelandSeasons.Data.adjustedTemp
--     end
--     print("WastelandSeasons:OnInitSeasons")
--     season:init(
--         SandboxVars.WastelandSeasons.Latitude,
--         tempMin,
--         tempMax,
--         SandboxVars.WastelandSeasons.TempDiff,
--         season:getSeasonLag(),
--         season:getHighNoon(),
--         season:getSeedA(),
--         season:getSeedB(),
--         season:getSeedC()
--     );
-- end

-- Events.OnInitSeasons.Add(OnInitSeasons)
