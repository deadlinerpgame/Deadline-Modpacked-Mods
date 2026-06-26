---
--- WIT_ISRepairClothing.lua
--- 15/11/2024
--- 

local original_ISRepairClothing_perform = ISRepairClothing.perform
function ISRepairClothing:perform()
    if self.fabric:getType() == "PatchKit" then
        local patchFab1 = InventoryItemFactory.CreateItem("Base.RippedSheets");
        local patchFab2 = InventoryItemFactory.CreateItem("Base.DenimStrips");
        local patchFab3 = InventoryItemFactory.CreateItem("Base.LeatherStrips");
        local patchKit = self.character:getInventory():getItemFromType("PatchKit", true, true);
        local patch
        if self.clothing:getFabricType() == "Cotton" then
            patch = patchFab1
        elseif self.clothing:getFabricType() == "Denim" then
            patch = patchFab2
        elseif self.clothing:getFabricType() == "Leather" then
            patch = patchFab3
        else
            return
        end
        self.clothing:getVisual():removeHole(self.part:index());
        self.clothing:setCondition(self.clothing:getCondition() + self.clothing:getCondLossPerHole());

        self.character:resetModel();
        patchKit:Use()
        self.thread:Use()
        
        triggerEvent("OnClothingUpdated", self.character)

        ISBaseTimedAction.perform(self);
    elseif  self.fabric:getType() == "KevlarKit" then
        local kevlarKit = self.character:getInventory():getItemFromType("KevlarKit", true, true);
        local patch
        self.clothing:getVisual():removeHole(self.part:index());
        self.clothing:setCondition(self.clothing:getCondition() + self.clothing:getCondLossPerHole());

        self.character:resetModel();
        kevlarKit:Use()
        self.thread:Use()

        triggerEvent("OnClothingUpdated", self.character)

        ISBaseTimedAction.perform(self);
    else
        original_ISRepairClothing_perform(self)
    end    
end