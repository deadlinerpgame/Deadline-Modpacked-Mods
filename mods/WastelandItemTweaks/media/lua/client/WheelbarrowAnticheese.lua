if not getActivatedMods():contains("WheelbarrowUndeadRelent") then return end

require "TimedActions/PFGPushAction"

local original_ISUnequipAction_perform = ISUnequipAction.perform
function ISUnequipAction:perform()
    if self.item:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" and not self.item:getInventory():isEmpty() then
        ISTimedActionQueue.addAfter(self, ISDropItemAction:new(self.character, self.item, 1))
    end
    original_ISUnequipAction_perform(self)
end

local original_ISInventoryTransferAction_isValid = ISInventoryTransferAction.isValid
function ISInventoryTransferAction:isValid()
    local val = original_ISInventoryTransferAction_isValid(self)
    if not val then return false end
    if self.item:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" and not self.item:getInventory():isEmpty() and not self.destContainer:getType()=="floor" then
        return false
    end
    return val
end

local original_ISGrabItemAction_isValid = ISGrabItemAction.isValid
function ISGrabItemAction:isValid()
    local val = original_ISGrabItemAction_isValid(self)
    if not val then return false end
    if self.item and self.item:getItem():getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" and not self.item:getItem():getInventory():isEmpty() then
        return false
    end
    return val
end

local original_ISEquipHeavyItem_isValid = ISEquipHeavyItem.isValid
function ISEquipHeavyItem:isValid()
    if self.item:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" and not self.item:getInventory():isEmpty() then
        return false
    end
    return original_ISEquipHeavyItem_isValid(self)
end

function PFGPushAction:isValid()
	for i,v in ipairs(PFGMenu.typesTable) do
		if self.character:getInventory():contains(tostring(v)) then
			return false
		end
	end

    if not self.sq then return false end

    local objects = self.sq:getWorldObjects()
    for i=0, objects:size()-1 do
        local object = objects:get(i)
        if object == self.item then
            return true
        end
    end

    return false
end

local original_PFGPushAction_perform = PFGPushAction.perform

function PFGPushAction:perform()
    original_PFGPushAction_perform(self)
    local queue = ISTimedActionQueue.getTimedActionQueue(getPlayer())
    if #queue.queue > 1 then
        queue:resetQueue()
        return
    end
end

local original_PFGPushAction_new = PFGPushAction.new
function PFGPushAction:new( item, player)
    local o = original_PFGPushAction_new(self, item, player)
    o.sq = item:getSquare()
    return o
end

local original_isForceDropHeavyItem = isForceDropHeavyItem
function isForceDropHeavyItem(item)
    return original_isForceDropHeavyItem(item) or (item ~= nil and item:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" and not item:getInventory():isEmpty())
end

local original_ISEnterVehicle_new = ISEnterVehicle.new

function ISEnterVehicle:new(character, vehicle, seat)
    if WL_Utils.checkInventoryForItem(character, "Wheelbarrow.HCWoodenwheelbarrow") then
        getPlayer():setHaloNote("Can't enter vehicle with a wheelbarrow", 255, 0, 0, 300)
        return {ignoreAction = true}
    end
    return original_ISEnterVehicle_new(self, character, vehicle, seat)
end


-- Make Wheelbarrow very tiring to push

local currentBurnMultiplier = 1.0

local function UpdateBurnRate()
    local player = getPlayer()
    if not player then return end
    
    local primaryHandItem = player:getPrimaryHandItem()
    if primaryHandItem and primaryHandItem:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" then
        local inv = primaryHandItem:getInventory()
        
        if inv:isEmpty() then
            currentBurnMultiplier = 0.15
        else
            local weight = inv:getCapacityWeight()
            local capacity = inv:getCapacity()
            local weightRatio = 0
            if capacity > 0 then
                weightRatio = weight / capacity
            end
            
            -- Calculate variety factor
            local items = inv:getItems()
            local uniqueTypes = {}
            local varietyCount = 0
            
            for i=0, items:size()-1 do
                local item = items:get(i)
                local type = item:getFullType()
                if not uniqueTypes[type] then
                    uniqueTypes[type] = true
                    varietyCount = varietyCount + 1
                end
            end
            
            -- Base multiplier for non-empty
            local baseMult = 0.35
            if SandboxVars.WastelandItemTweaks and SandboxVars.WastelandItemTweaks.WheelbarrowBaseMult then
                baseMult = SandboxVars.WastelandItemTweaks.WheelbarrowBaseMult
            end
            
            -- Weight adds up to X (reduced impact)
            local weightMax = 0.5
            if SandboxVars.WastelandItemTweaks and SandboxVars.WastelandItemTweaks.WheelbarrowWeightMult then
                weightMax = SandboxVars.WastelandItemTweaks.WheelbarrowWeightMult
            end
            local weightMult = weightRatio * weightMax
            
            -- Variety adds up to X (capped at 10 types, increased impact)
            local varietyPerType = 0.4
            if SandboxVars.WastelandItemTweaks and SandboxVars.WastelandItemTweaks.WheelbarrowVarietyMult then
                varietyPerType = SandboxVars.WastelandItemTweaks.WheelbarrowVarietyMult
            end
            local varietyMult = math.min(varietyCount, 10) * varietyPerType
            
            currentBurnMultiplier = baseMult + weightMult + varietyMult
            print(currentBurnMultiplier)
        end
    else
        currentBurnMultiplier = 1.0
    end
end

if WL_RealTimeEvents then
    WL_RealTimeEvents.EveryXSeconds(10, UpdateBurnRate)
end

local lastTime = 0
local function BurnStamina(player)
    if not player then return end
    local primaryHandItem = player:getPrimaryHandItem()
    if primaryHandItem and primaryHandItem:getFullType() == "Wheelbarrow.HCWoodenwheelbarrow" then
        local currentTime = getTimestampMs()
        local delta = (currentTime - lastTime) / 1000.0
        lastTime = currentTime
        
        if delta > 1 then return end -- Skip large time jumps
        
        local endurance = player:getStats():getEndurance()
        local baseBurn = 0.01
        
        if player:isSneaking() then
            baseBurn = 0.005
        elseif player:isRunning() then
            baseBurn = 0.03
        elseif player:isSprinting() then
            baseBurn = 0.05
        end
        
        local finalBurn = baseBurn * currentBurnMultiplier
        
        player:getStats():setEndurance(math.max(endurance - (finalBurn * delta), 0))
    end
end

Events.OnPlayerMove.Add(BurnStamina)