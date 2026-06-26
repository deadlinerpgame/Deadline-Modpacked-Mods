---
--- WL_PlayerStatsUIOverride.lua
--- 28/10/2023
---

require "WL_Utils"
require "ISUI/PlayerStats/ISPlayerStatsUI"

-- This is combined with the global function canModifyPlayerStats() which appears to be true for
-- overseer, moderator and admin but not observer and gm
-- The Indie Stone function is bugged though, because it checks for Admin OR (Moderator AND (observer or gm etc)) and
-- a moderator is never also a gm/observer, so it always fails. This override just fixes that bug.
function ISPlayerStatsUI:canModifyThis()
	return ((self.char:getCurrentSquare() and self.char:isExistInTheWorld()) or not self.char:getCurrentSquare())
			and WL_Utils.isStaff(getPlayer())
end