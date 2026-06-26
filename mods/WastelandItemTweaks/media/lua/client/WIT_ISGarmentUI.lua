---
--- WIT_ISGarmentUI.lua
--- 15/11/2024
--- 

--local original_dopatch = ISGarmentUI.doPatch
function ISGarmentUI:doPatch(fabric, thread, needle, part, context, submenu)
	
	if not self.clothing:getFabricType() then
		return;
	end
	
	local hole = self.clothing:getVisual():getHole(part) > 0;
	local patch = self.clothing:getPatchType(part);
	
	local text;
	local allText;
	local tailorLvl = self.chr:getPerkLevel(Perks.Tailoring);

	if hole then
		text = getText("ContextMenu_PatchHole");
		allText = getText("ContextMenu_PatchAllHoles") .. fabric:getDisplayName();
	elseif not patch then
		if self.clothing:getFabricType() ~= "Kevlar" then
			if fabric:getType() ~= "PatchKit" or fabric:getType() ~= "KevlarKit" then
					text = getText("ContextMenu_AddPadding");
					allText = getText("ContextMenu_AddPaddingAll") .. fabric:getDisplayName();
			else
				return
			end
		else
			return
		end
	else
		error "patch ~= nil"
	end
	
	if not submenu then
		local option = context:addOption(text);
		submenu = context:getNew(context);
		context:addSubMenu(option, submenu);
	end

	local option = submenu:addOption(fabric:getDisplayName(), self.chr, ISInventoryPaneContextMenu.repairClothing, self.clothing, part, fabric, thread, needle)
	local tooltip = ISInventoryPaneContextMenu.addToolTip();
    if fabric:getType() == "PatchKit" or fabric:getType() == "KevlarKit" then
        tooltip.description = getText("Tooltip_FullyRestore");
	elseif self.clothing:canFullyRestore(self.chr, part, fabric) then
		tooltip.description = getText("IGUI_perks_Tailoring") .. " :" .. self.chr:getPerkLevel(Perks.Tailoring) .. " <LINE>" .. ISGarmentUI.ghs .. getText("Tooltip_FullyRestore");
    else
		tooltip.description = getText("IGUI_perks_Tailoring") .. " :" .. self.chr:getPerkLevel(Perks.Tailoring) .. " <LINE>" .. ISGarmentUI.ghs .. getText("Tooltip_ScratchDefense")  .. " +" .. Clothing.getScratchDefenseFromItem(self.chr, fabric) .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " +" .. Clothing.getBiteDefenseFromItem(self.chr, fabric);
	end

	if fabric:getDisplayName() == "Kevlar Kit" and tailorLvl < 6 and self.clothing:getFabricType() == "Kevlar" then
		option.notAvailable = true;
		tooltip.description = getText("IGUI_perks_Tailoring") .. ": " .. tailorLvl .. " / 6 <LINE>" .. "You must be at least Level 6 in Tailoring to use this item.";
		option.toolTip = tooltip;
	else
		option.toolTip = tooltip;
	end

	-- Patch/Add pad all
	local allOption;
	local allTooltip = ISInventoryPaneContextMenu.addToolTip();

	if(self.chr:getInventory():getItemCount(fabric:getType(), true) > 1) or self.chr:getInventory():getItemCount(fabric:getType(), true) > 0 then
		if hole and (self.clothing:getHolesNumber() > 1) then
			if fabric:getDisplayName() == "Kevlar Kit" and tailorLvl < 6 and self.clothing:getFabricType() == "Kevlar" then
				allOption = submenu:addOption(allText)
				allOption.notAvailable = true;
				allTooltip.description = getText("IGUI_perks_Tailoring") .. ": " .. tailorLvl .. " / 6 <LINE>" .. "You must be at least Level 6 in Tailoring to use this item.";
				allOption.toolTip = allTooltip;
			else
				allOption = submenu:addOption(allText, self.chr, ISInventoryPaneContextMenu.repairAllClothing, self.clothing, self.parts, fabric, thread, needle, true)
				allTooltip.description = getText("Tooltip_PatchAllHoles") .. fabric:getDisplayName();
				allOption.toolTip = allTooltip;
			end
		elseif not hole and not patch and (ISGarmentUI:getPaddablePartsNumber(self.clothing, self.parts) > 1) then
			allOption = submenu:addOption(allText, self.chr, ISInventoryPaneContextMenu.repairAllClothing, self.clothing, self.parts, fabric, thread, needle, false)
			allTooltip.description = getText("Tooltip_AddPaddingToAll") .. fabric:getDisplayName();
			allOption.toolTip = allTooltip;
		end
	end

	return submenu;
end

function ISGarmentUI:doContextMenu(part, x, y)
	local context = ISContextMenu.get(self.chr:getPlayerNum(), x, y);
	
	local thread = self.chr:getInventory():getItemFromType("Thread", true, true);
	local needle = self.chr:getInventory():getItemFromType("Needle", true, true) or self.chr:getInventory():getFirstTagRecurse("SewingNeedle");
	local fabric1 = self.chr:getInventory():getItemFromType("RippedSheets", true, true);
	local fabric2 = self.chr:getInventory():getItemFromType("DenimStrips", true, true);
	local fabric3 = self.chr:getInventory():getItemFromType("LeatherStrips", true, true);
    local patchKit = self.chr:getInventory():getItemFromType("PatchKit", true, true);
	local kevlarKit = self.chr:getInventory():getItemFromType("KevlarKit", true, true);
	local patch = self.clothing:getPatchType(part)
    local tailorLvl = self.chr:getPerkLevel(Perks.Tailoring);
	if patch then
		local removeOption = context:addOption(getText("ContextMenu_RemovePatch"), self.chr, ISInventoryPaneContextMenu.removePatch, self.clothing, part, needle)
		local tooltip = ISInventoryPaneContextMenu.addToolTip();
		removeOption.toolTip = tooltip;

		local patchesCount = self.clothing:getPatchesNumber();
		local removeAllOption;
		local removeAllTooltip;
		if (patchesCount > 1) then
			removeAllOption = context:addOption(getText("ContextMenu_RemoveAllPatches"), self.chr, ISInventoryPaneContextMenu.removeAllPatches, self.clothing, self.parts, needle);
			removeAllTooltip = ISInventoryPaneContextMenu.addToolTip();
			removeAllOption.toolTip = removeAllTooltip;
		end

		if needle then
			tooltip.description = getText("Tooltip_GetPatchBack", ISRemovePatch.chanceToGetPatchBack(self.chr)) .. " <LINE>" .. ISGarmentUI.bhs .. getText("Tooltip_ScratchDefense")  .. " -" .. patch:getScratchDefense() .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " -" .. patch:getBiteDefense();
			if(removeAllTooltip ~= nil) then
				removeAllTooltip.description = getText("Tooltip_GetPatchesBack", ISRemovePatch.chanceToGetPatchBack(self.chr)) .. " <LINE>" .. ISGarmentUI.bhs .. getText("Tooltip_ScratchDefense")  .. " -" .. (patch:getScratchDefense() * patchesCount) .. " <LINE> " .. getText("Tooltip_BiteDefense") .. " -" .. (patch:getBiteDefense() * patchesCount);
			end
		else
			tooltip.description = getText("ContextMenu_CantRemovePatch");
			removeOption.notAvailable = true
			if(removeAllTooltip ~= nil) then
				removeAllTooltip.description = getText("ContextMenu_CantRemovePatch");
				removeAllOption.notAvailable = true;
			end
		end
		return context;
	end

	if self.clothing:getVisual():getHole(part) == 0 then
		local function addHole(character, clothing, part)
			clothing:getVisual():setHole(part)
			clothing:setCondition(clothing:getCondition() - clothing:getCondLossPerHole())
			clothing:synchWithVisual()
			sendVisual(character)
			triggerEvent("OnClothingUpdated", character)
			character:resetModel()
		end
		local addHoleOption = context:addOption("Add Hole", self.chr, function() addHole(self.chr, self.clothing, part) end)
		local tooltip = ISInventoryPaneContextMenu.addToolTip();
		tooltip.description = "Add a hole to the clothing.";
		addHoleOption.toolTip = tooltip;
	end
	
	if not thread or not needle or (not fabric1 and not fabric2 and not fabric3 and not patchKit and not kevlarKit) then
		local patchOption = context:addOption(getText("ContextMenu_Patch"));
		patchOption.notAvailable = true;
		local tooltip = ISInventoryPaneContextMenu.addToolTip();
		tooltip.description = getText("ContextMenu_CantRepair");
		patchOption.toolTip = tooltip;
		if not self.chr:isGodMod() then
			return context;
		end
	end
	
	if thread and needle and (fabric1 or fabric2 or fabric3 or patchKit or kevlarKit) then
		local submenu;
		local allSubmenu;
		if fabric1 then
			submenu = self:doPatch(fabric1, thread, needle, part, context, submenu);
		end
		if fabric2 then
			submenu = self:doPatch(fabric2, thread, needle, part, context, submenu);
		end
		if fabric3 then
			submenu = self:doPatch(fabric3, thread, needle, part, context, submenu);
		end
		if patchKit and self.clothing:getFabricType() ~= "Kevlar" then
			submenu = self:doPatch(patchKit, thread, needle, part, context, submenu);
		end
		if kevlarKit and self.clothing:getFabricType() == "Kevlar" then
			submenu = self:doPatch(kevlarKit, thread, needle, part, context, submenu);
		end
	end
    if self.chr:isGodMod() then
        if self.clothing:getVisual():getHole(part) > 0 then
			local function removeHole(clothing, part)
				clothing:getVisual():removeHole(part:index())
				clothing:setCondition(clothing:getCondition() + clothing:getCondLossPerHole())
			end
			local removeHole = context:addOption("Remove Hole", self.chr, function() removeHole(self.clothing, part) end)
            local tooltip = ISInventoryPaneContextMenu.addToolTip();
            tooltip.description = "Remove the hole from the clothing.";
            removeHole.toolTip = tooltip;
        end
    end
	return context;
end
