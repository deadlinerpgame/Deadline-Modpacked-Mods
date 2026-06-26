---
--- WIT_CleanUpMenu.lua
--- 09/11/2025
--- 

require "ISBlacksmithMenu"
WIT_CleanUpMenu = {}

function WIT_CleanUpMenu.BlackSmithMenu(player, context, worldObjects, test)
    local numOptions = context.numOptions or (context.options and #context.options) or 0
    for i = 1, numOptions do
        local option = context.options[i]
        if option and option.name == getText("ContextMenu_LitDrum") then
            local subOption = context:getSubMenu(option.subOption)
            for j = subOption.numOptions, 1, -1 do
                local newOption = subOption.options[j]
                if newOption and newOption.name then
                    local function getDisplayName(itemType)
                        local item = InventoryItemFactory.CreateItem(itemType)
                        return item:getDisplayName()
                    end
                    local items = {
                        {type = "Base.Twigs", displayName = getDisplayName("Base.Twigs")},
                        {type = "Base.SheetPaper2", displayName = getDisplayName("Base.SheetPaper2")},
                        {type = "Base.RippedSheets", displayName = getDisplayName("Base.RippedSheets")},
                        {type = "Base.RippedSheetsDirty", displayName = getDisplayName("Base.RippedSheetsDirty")},
                    }
                    local match = false
                    for _, item in ipairs(items) do
                        if string.find(newOption.name, item.displayName, 1, true) then
                            match = true
                            break
                        end
                    end
                    if not match then
                        subOption:removeOptionByName(newOption.name)
                    end
                end
            end
        end
    end
end


Events.OnFillWorldObjectContextMenu.Add(WIT_CleanUpMenu.BlackSmithMenu)