require "WL_Utils"

-- ** 
-- ** Simple Infinite Generators
-- ** Mod Author: github.com/buffyuwu
-- ** If you are using this work, please don't remove credit. Doing so fragments the modding community and makes
-- ** it harder for newbies to learn.
-- **
-- ** MODIFIED FOR WASTELAND: Allow staff levels below Admin to create admin generators
-- **

local original_ISTakeGenerator_isValid = ISTakeGenerator.isValid
function ISTakeGenerator:isValid()
    local result = original_ISTakeGenerator_isValid(self)
    if not result then return false end

    if self.generator:getFuel() > 100 and not WL_Utils.isAtLeastGM(getPlayer()) then
        WL_Utils.addErrorToChat("Only staff may take infinite generators.")
        return false
    end

    return true
end

local function SetIsGeneratorInfinite(object, infinite)
    local cell = getWorld():getCell()
    local square = object:getSquare()

    local item = InventoryItemFactory.CreateItem("Base.Generator")
    if item == nil then
        return
    end
    if infinite then
        item:setCondition(999999999)
        item:getModData().fuel = 999999999
        item:getModData()._isFuelInfinite = true; --if you want to display the infinite status somewhere, check for this
    else
        item:setCondition(100)
        item:getModData().fuel = 100
        item:getModData()._isFuelInfinite = false;
    end
    square:transmitRemoveItemFromSquare(object)
    local javaObject = IsoGenerator.new(item, cell, square)
    javaObject:transmitCompleteItemToClients()
    WL_Utils.addInfoToChat("Generator set to infinite fuel.");
end

Events.OnFillWorldObjectContextMenu.Add(function(player, context, worldObjects, test)
    for _,obj in ipairs(worldObjects) do --filter for what we find when we right click
        if not WL_Utils.isAtLeastGM(getPlayer()) then return; end
        local objTextureName = obj:getTextureName()
        if objTextureName and luautils.stringStarts(objTextureName, "appliances_misc_01_0") then
            local modData = obj:getModData()
            -- TODO: this check always fails, FIX IT
            if modData and modData._isFuelInfinite then
                context:addOption("[Staff] Unset Infinite Fuel", obj, SetIsGeneratorInfinite, false)
                return
            else
                context:addOption("[Staff] Set Infinite Fuel", obj, SetIsGeneratorInfinite, true)
                return
            end
        end
    end
end)
