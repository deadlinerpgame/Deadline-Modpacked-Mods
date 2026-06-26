---
--- WIT_BlockWaterJug.lua
--- 30/10/2024
---
if not ISTakeGasolineFromVehicle then return end

local original_ISTakeGasolineFromVehicle_start = ISTakeGasolineFromVehicle.start
function ISTakeGasolineFromVehicle:start()
    original_ISTakeGasolineFromVehicle_start(self)
    if self.item and (self.item:getType() == "WaterJugPetrolFull" or self.item:getType() == "WaterJugEmpty") then
        self.character:Say("I can't add gas to a Water Jug")
        self:forceStop()
    end
end