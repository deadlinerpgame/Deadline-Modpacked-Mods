local function isWorldSink(sink)
    return sink:hasWater() and sink:getProperties():Is(IsoFlagType.waterPiped) and not sink:getUsesExternalWaterSource()
end

local function isPlumbedSink(sink)
    return sink:hasWater() and sink:getProperties():Is(IsoFlagType.waterPiped) and sink:getUsesExternalWaterSource()
end

local original_ISWorldObjectContextMenu_doFillWaterMenu = ISWorldObjectContextMenu.doFillWaterMenu

ISWorldObjectContextMenu.doFillWaterMenu = function(sink, playerNum, context)
    if SandboxVars.WastelandItemTweaks.BadWater then
        if isWorldSink(sink) and not sink:isTaintedWater() then
            sink:setTaintedWater(true)
            sink:transmitCompleteItemToServer()
        elseif isPlumbedSink(sink) and sink:isTaintedWater() then
            sink:setTaintedWater(false)
            sink:transmitCompleteItemToServer()
        end
    end

    original_ISWorldObjectContextMenu_doFillWaterMenu(sink, playerNum, context)
end