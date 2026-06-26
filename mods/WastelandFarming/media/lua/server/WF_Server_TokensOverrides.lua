local original_farmingPlot_isValid = farmingPlot.isValid
function farmingPlot:isValid(square)
    if not SandboxVars.WastelandFarming.EnableFarmingTokens then
        return original_farmingPlot_isValid(self, square)
    end
    local player = self.character
    if not WF_TokensSystem:canUsePlot(player) then
        player:Say(getText("IGUI_WFTokens_TooManyPlots"))
		getCell():setDrag(nil, self.player)
        return false
    end
    return original_farmingPlot_isValid(self, square)
end

if isClient() then return end

local function noise(message) SFarmingSystem.instance:noise(message) end

local function getPlantAt(x, y, z)
	return SFarmingSystem.instance:getLuaObjectAt(x, y, z)
end

local original_SFarmingSystem_removePlant = SFarmingSystem.removePlant
function SFarmingSystem:removePlant(plant)
    if not SandboxVars.WastelandFarming.EnableFarmingTokens then
        return original_SFarmingSystem_removePlant(self, plant)
    end

    local sq = plant:getSquare()
    WF_TokensSystem:releasePlot(sq:getX(), sq:getY(), sq:getZ())
    return original_SFarmingSystem_removePlant(self, plant)
end

-- its dirty.. i knows
function SFarmingSystemCommands.plow(player, args)
	local gridSquare = getCell():getGridSquare(args.x, args.y, args.z)
	if gridSquare then
		local plant = getPlantAt(args.x, args.y, args.z)
		if plant then
			SFarmingSystem.instance:removePlant(plant)
		end
		SFarmingSystem.instance:plow(gridSquare)
        WF_TokensSystem:usePlot(player, args.x, args.y, args.z)
	else
		noise('no gridSquare at '..args.x..','..args.y..','..args.z)
	end
end

-- disable this stupid thing
function SFarmingSystem.destroyOnWalk()
end