---
--- WL_Stress.lua
---
--- Safe helpers for reading and changing Project Zomboid stress.
---
--- This file exists because `stats:getStress()` returns total visible stress,
--- which includes cigarette stress, but `stats:setStress()` only writes the
--- base stress value. If code does `setStress(getStress() + delta)` then smoker
--- stress gets counted twice and the final total can rise unexpectedly.
---
--- Always use this helper when changing stress in Wasteland code. It keeps the
--- total stress correct by separating base stress from cigarette stress first.
--- All stress values in this file are expected to use the game's normalized
--- stress range: `0.0` means no stress and `1.0` means maximum stress.
---

WL_Stress = WL_Stress or {}

--- Clamp a normalized stress value to the valid Project Zomboid range.
--- Expected range is `0.0` to `1.0`.
--- @param value number
--- @return number
local function clampStress(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Fetch the stats object from a player.
--- @param player IsoGameCharacter|nil
--- @return Stats
local function getStats(player)
    return (player or getPlayer()):getStats()
end

--- Read the smoker-only portion of stress.
--- @param stats Stats
--- @return number
local function getCigaretteStress(stats)
    return clampStress(stats:getStressFromCigarettes())
end

--- Get the player's total visible stress, including cigarette stress.
--- Expected return range is `0.0` to `1.0`.
--- If `player` is omitted, the local player from `getPlayer()` is used.
--- @param player IsoGameCharacter|nil
--- @return number
function WL_Stress.getTotal(player)
    return clampStress(getStats(player):getStress())
end

--- Set the player's total stress safely.
---
--- `totalStress` is expected to be in the normalized range `0.0` to `1.0`.
--- This accepts the visible total stress you want after cigarette stress is
--- accounted for. The helper subtracts smoker stress before calling the base
--- game setter so the final total ends up where you intended.
--- If `player` is omitted, the local player from `getPlayer()` is used.
---
--- @param totalStress number
--- @param player IsoGameCharacter|nil
function WL_Stress.set(totalStress, player)
    local stats = getStats(player)

    if totalStress <= 0 then
        stats:setStress(0)
        return
    end

    local baseStress = clampStress(totalStress) - getCigaretteStress(stats)

    if baseStress < 0 then
        baseStress = 0
    end

    stats:setStress(baseStress)
end

--- Adjust the player's total stress by a delta safely.
---
--- `delta` is expected to use the same normalized stress scale as the base
--- game, where `0.1` is 10% stress. Positive deltas increase stress and
--- negative deltas reduce it.
--- If `player` is omitted, the local player from `getPlayer()` is used.
--- Example: `WL_Stress.adjust(-0.1)` lowers the local player's total stress
--- by 10%.
---
--- @param delta number
--- @param player IsoGameCharacter|nil
function WL_Stress.adjust(delta, player)
    WL_Stress.set(WL_Stress.getTotal(player) + delta, player)
end
