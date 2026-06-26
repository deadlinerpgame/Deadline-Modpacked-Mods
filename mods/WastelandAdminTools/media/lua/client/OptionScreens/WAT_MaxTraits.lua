function CharacterCreationProfession:getTraitStats()
    local numTraits = 0
    local numPositiveTraits = 0
    local numNegativeTraits = 0
    local pointsPositiveTraits = 0
    local pointsNegativeTraits = 0
    for i=1,#self.listboxTraitSelected.items do
        local trait = self.listboxTraitSelected.items[i]
        local cost = trait.item:getCost()
        -- This is shown in the tooltip, in WDC_OverrideTooltips.lua - so change the text there if you adjust this!
        if cost > 0 then
            numPositiveTraits = numPositiveTraits + 1
            pointsPositiveTraits = pointsPositiveTraits + cost
            numTraits = numTraits + 1
        elseif cost < 0 then
            numNegativeTraits = numNegativeTraits + 1
            pointsNegativeTraits = pointsNegativeTraits + (cost * -1)
            numTraits = numTraits + 1
        end
    end
    if self.profession then
        local cost = self.profession:getCost()
        if cost then
            pointsPositiveTraits = pointsPositiveTraits + (cost * -1)
        end
    end
    return {
        numTraits = numTraits,
        numPositiveTraits = numPositiveTraits,
        numNegativeTraits = numNegativeTraits,
        pointsPositiveTraits = pointsPositiveTraits,
        pointsNegativeTraits = pointsNegativeTraits,
    }
end

function CharacterCreationProfession:getTraitIssues()
    local stats = self:getTraitStats()
    local maxTraits = SandboxVars.WastelandAdminTools.MaxTraits
    local maxPositiveTraits = SandboxVars.WastelandAdminTools.MaxPositiveTraitsCount
    local maxNegativeTraits = SandboxVars.WastelandAdminTools.MaxNegativeTraitsCount
    local maxPositivePoints = SandboxVars.WastelandAdminTools.MaxPositiveTraitPoints
    local maxNegativePoints = SandboxVars.WastelandAdminTools.MaxNegativeTraitPoints
    if maxTraits > 0 and stats.numTraits > maxTraits then
        return "Too Many Traits"
    end
    if maxPositiveTraits > 0 and stats.numPositiveTraits > maxPositiveTraits then
        return "Too Many Positive Traits"
    end
    if maxNegativeTraits > 0 and stats.numNegativeTraits > maxNegativeTraits then
        return "Too Many Negative Traits"
    end
    if maxPositivePoints > 0 and stats.pointsPositiveTraits > maxPositivePoints then
        return "Too Many Positive Trait Points"
    end
    if maxNegativePoints > 0 and stats.pointsNegativeTraits > maxNegativePoints then
        return "Too Many Negative Trait Points"
    end
    return nil
end

local original_CharacterCreationProfession_onOptionMouseDown = CharacterCreationProfession.onOptionMouseDown;
function CharacterCreationProfession:onOptionMouseDown(button, x, y)
    print("CharacterCreationProfession:onOptionMouseDown override")
    if button.internal == "NEXT" then
        local issue = self:getTraitIssues()
        if issue then
            print(issue)
            return
        end
    end
    return original_CharacterCreationProfession_onOptionMouseDown(self, button, x, y);
end

local original_CharacterCreationProfession_render = CharacterCreationProfession.render;
function CharacterCreationProfession:render()
    original_CharacterCreationProfession_render(self)
    local issue = self:getTraitIssues()
    if issue and self.playButton.enable then
        self.listboxTraitSelected.borderColor = {r=1, g=0, b=0, a=1}
        self.playButton:setEnable(false);
        self.playButton:setTooltip(issue);
    else
        self.listboxTraitSelected.borderColor = {r=1, g=1, b=1, a=1}
    end
    local x = self.mainPanel:getX() + self.listboxTraitSelected:getX()

    local stats = self:getTraitStats()

    if SandboxVars.WastelandAdminTools.MaxTraits > 0 then
        local text = stats.numTraits .. "/" .. SandboxVars.WastelandAdminTools.MaxTraits .. " traits"
        if stats.numTraits > SandboxVars.WastelandAdminTools.MaxTraits then
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 1, 0.2, 0.2, 1, UIFont.Small)
        else
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 0.2, 1.0, 0.2, 1, UIFont.Small)
        end
        x = x + getTextManager():MeasureStringX(UIFont.Small, text) + 5
    end
    if SandboxVars.WastelandAdminTools.MaxPositiveTraitsCount > 0 then
        local text = stats.numPositiveTraits .. "/" .. SandboxVars.WastelandAdminTools.MaxPositiveTraitsCount .. " positive traits"
        if stats.numPositiveTraits > SandboxVars.WastelandAdminTools.MaxPositiveTraitsCount then
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 1, 0.2, 0.2, 1, UIFont.Small)
        else
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 0.2, 1.0, 0.2, 1, UIFont.Small)
        end
        x = x + getTextManager():MeasureStringX(UIFont.Small, text) + 5
    end
    if SandboxVars.WastelandAdminTools.MaxNegativeTraitsCount > 0 then
        local text = stats.numNegativeTraits .. "/" .. SandboxVars.WastelandAdminTools.MaxNegativeTraitsCount .. " negative traits"
        if stats.numNegativeTraits > SandboxVars.WastelandAdminTools.MaxNegativeTraitsCount then
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 1, 0.2, 0.2, 1, UIFont.Small)
        else
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 0.2, 1.0, 0.2, 1, UIFont.Small)
        end
        x = x + getTextManager():MeasureStringX(UIFont.Small, text) + 5
    end
    if SandboxVars.WastelandAdminTools.MaxPositiveTraitPoints > 0 then
        local text = stats.pointsPositiveTraits .. "/" .. SandboxVars.WastelandAdminTools.MaxPositiveTraitPoints .. " positive points"
        if stats.pointsPositiveTraits > SandboxVars.WastelandAdminTools.MaxPositiveTraitPoints then
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 1, 0.2, 0.2, 1, UIFont.Small)
        else
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 0.2, 1.0, 0.2, 1, UIFont.Small)
        end
        x = x + getTextManager():MeasureStringX(UIFont.Small, text) + 5
    end
    if SandboxVars.WastelandAdminTools.MaxNegativeTraitPoints > 0 then
        local text = stats.pointsNegativeTraits .. "/" .. SandboxVars.WastelandAdminTools.MaxNegativeTraitPoints .. " negative points"
        if stats.pointsNegativeTraits > SandboxVars.WastelandAdminTools.MaxNegativeTraitPoints then
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 1, 0.2, 0.2, 1, UIFont.Small)
        else
            self:drawText(text, x, self.listboxTraitSelected:getAbsoluteY() - self.smallFontHgt*2 + 2, 0.2, 1.0, 0.2, 1, UIFont.Small)
        end
        x = x + getTextManager():MeasureStringX(UIFont.Small, text) + 5
    end
end