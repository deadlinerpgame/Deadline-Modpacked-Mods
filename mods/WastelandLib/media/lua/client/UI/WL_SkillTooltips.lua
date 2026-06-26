---
--- WL_SkillTooltips.lua
--- 12/10/2024
---

WL_SkillTooltips = {}
WL_SkillTooltips.tooltips = {}

--- Allow one skill level or one optional perk to give a special tooltip to this item. So having EITHER of them will
--- show the tooltip. You don't need both.
---@param itemID string cannot be nil
---@param tooltip string cannot be nil
---@param perk PerkFactory.Perk example: Perks.MetalWelding OPTIONAL
---@param minLevel number minimum level required for the skill, mandatory if a perk is provided
---@param trait string example: "Herbalist" OPTIONAL
function WL_SkillTooltips.addTooltip(itemID, tooltip, perk, minLevel, trait)
	WL_SkillTooltips.tooltips[itemID] = {
		text = tooltip,
		perk = perk,
		minLevel = minLevel,
		trait = trait,
	}
end

local function getTraitName(traitKey)
	local traitList = TraitFactory.getTraits()
	for i=1,traitList:size() do
		local trait = traitList:get(i-1)
		if trait:getType() == traitKey then
			return trait:getLabel()
		end
	end
	return traitKey
end

function WL_SkillTooltips.getTooltip(itemID)
	local tooltip = WL_SkillTooltips.tooltips[itemID]
	if not tooltip then return nil end

	local passedWith
	if tooltip.perk and getPlayer():getPerkLevel(tooltip.perk) >= tooltip.minLevel then
		passedWith = tooltip.perk:getName() .. " " .. tostring(tooltip.minLevel)
	end

	if tooltip.trait and getPlayer():HasTrait(tooltip.trait) then
		passedWith = getTraitName(tooltip.trait)
	end

	if not passedWith then
		return nil
	end

	local text = "<RGB:0,1,0> " .. passedWith .. ": <RGB:1,1,1> " .. WL_Utils.MagicSpace .. tooltip.text
	return text, tooltip.perk, tooltip.trait
end

-- Test/Example
--WL_SkillTooltips.addTooltip("Axe", "This is a fire axe made from steel and can be broken down for scrap", Perks.MetalWelding, 2)

local original_ISToolTipInv_removeFromUIManager = ISToolTipInv.removeFromUIManager
function ISToolTipInv:removeFromUIManager()
	original_ISToolTipInv_removeFromUIManager(self)
	if self.Skill_Tooltip then
		self.Skill_Tooltip:removeFromUIManager()
		self.Skill_Tooltip = nil
	end
end

local original_ISToolTipInv_setVisible = ISToolTipInv.setVisible
function ISToolTipInv:setVisible(visible)
	original_ISToolTipInv_setVisible(self, visible)
	if self.Skill_Tooltip and not visible then
		self.Skill_Tooltip:setVisible(false)
		self.Skill_Tooltip = nil
	end
end

local function getTextureName(perk, trait)
	if perk == Perks.Doctor then
		return "profession_doctor2"
	end
	if trait == "Herbalist" then
		return "d_plants_1_48"
	end
	if perk == Perks.Brewing then
		return "profession_brewmaster"
	end

	-- We can add more here, maybe using other profession icons

	return "books&misc_02_0" -- Default
end

local original_ISToolTipInv_render = ISToolTipInv.render
function ISToolTipInv:render()
	original_ISToolTipInv_render(self)
	local x = self.tooltip:getX() - 11
	local y = self.tooltip:getY() + self.tooltip:getHeight()

	if self.item then
		local tooltip, perk, trait = WL_SkillTooltips.getTooltip(self.item:getType())
		if tooltip then
			if not self.Skill_Tooltip then
				self.Skill_Tooltip = ISToolTip:new()
				self.Skill_Tooltip:initialise()
				self.Skill_Tooltip:addToUIManager()
			end
			self.Skill_Tooltip.description = tooltip
			self.Skill_Tooltip:setTexture(getTextureName(perk, trait))
			self.Skill_Tooltip:setVisible(true)
			self.Skill_Tooltip:setDesiredPosition(x, y)
		elseif self.Skill_Tooltip then
			self.Skill_Tooltip:setVisible(false)
		end
	end
end