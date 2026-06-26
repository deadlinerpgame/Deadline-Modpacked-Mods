---
--- WWP_Options.lua
--- 2025-12-18
---

WWP_Options = {
    workInWorkplaces = true,
    workInTowns = true,
    workForFaction = true,
}

if ModOptions and ModOptions.getInstance then
    local settings = ModOptions:getInstance(WWP_Options, "WastelandWorkplaces", "Wasteland Workplaces")
    local workInWorkplaces = settings:getData("workInWorkplaces")
    workInWorkplaces.name = "Work while inside employed workplaces"
    local workInTowns = settings:getData("workInTowns")
    workInTowns.name = "Work while inside employed towns"
    local workForFaction = settings:getData("workForFaction")
    workForFaction.name = "Work for employed faction"
end