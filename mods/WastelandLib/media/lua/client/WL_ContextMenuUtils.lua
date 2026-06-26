---
--- WL_ContextMenuUtils.lua
--- 18/10/2023
--- 13/10/2024 - getOrCreateSubMenuOnTop & missingRequirement add
---

WL_ContextMenuUtils = {}

--- Gets a submenu for the context menu if it exists, otherwise creates it
--- Allows multiple mods to share the same submenu, the first one to use the function makes it for the next ones.
function WL_ContextMenuUtils.getOrCreateSubMenu(context, name)
	local option = context:getOptionFromName(name)
	if not option or not option.subOption then -- Needs to be created
		option = context:addOption(name, nil, nil)
		local submenu = ISContextMenu:getNew(context)
		context:addSubMenu(option, submenu)
		return submenu, option
	else -- already exists
		return context:getSubMenu(option.subOption), option
	end
end

--- Does the same as above, but adds the submenu on top of the list
function WL_ContextMenuUtils.getOrCreateSubMenuOnTop(context, name)
	local option = context:getOptionFromName(name)
	if not option then -- Needs to be created
		option = context:addOptionOnTop(name, nil, nil)
		local submenu = ISContextMenu:getNew(context)
		context:addSubMenu(option, submenu)
		return submenu
	else -- already exists
		return context:getSubMenu(option.subOption)
	end
end

--- Creates a menu option that is not available and has a tooltip explaining why
--- Has an optional position parameter that can be "top" to add the option on top of the list
--- Has an optional texture parameter that can be a path to a texture (i.e. "appliances_com_01_73" or "Item_Screwdriver") to display in the tooltip
function WL_ContextMenuUtils.missingRequirement(context, name, description, position, texture)
	local option
	if position == "top" then
		option = context:addOptionOnTop(name, nil, nil)
	else
		option = context:addOption(name, nil, nil)
	end
	option.notAvailable = true
	local tooltip = ISToolTip:new()
	tooltip:initialise()
	tooltip:setName(name)
	tooltip:setVisible(false)

	if description then
		tooltip.description = " <RGB:1,0,0> " .. description
	end
	if texture then
		tooltip:setTexture(texture)
	end
	option.toolTip = tooltip
	return tooltip
end

--- Creates a disabled menu option with a requirement checklist tooltip.
--- @param context ISContextMenu
--- @param name string
--- @param requirements table[] Array entries: { text = string, met = boolean }
--- @param position string|nil Optional. "top" to insert at top.
--- @param texture string|nil Optional texture for tooltip.
--- @param heading string|nil Optional heading line, defaults to "Requirements:".
--- @return ISToolTip
function WL_ContextMenuUtils.missingRequirementsList(context, name, requirements, position, texture, heading)
	local tooltip = WL_ContextMenuUtils.missingRequirement(context, name, nil, position, texture)
	local lines = {}
	local title = heading or "Requirements:"

	if title ~= "" then
		lines[#lines + 1] = " <RGB:1,1,1> " .. title
	end

	for i = 1, #requirements do
		local requirement = requirements[i]
		local text = requirement.text or ""
		if text ~= "" then
			local color = "<RGB:1,0,0>"
			if requirement.met then
				color = "<RGB:0,1,0>"
			end
			lines[#lines + 1] = " " .. color .. " - " .. text
		end
	end

	if #lines > 0 then
		tooltip.description = table.concat(lines, "\n")
	end

	return tooltip
end

--- Adds a tooltip to a context menu option
--- @param context ISContextMenu Optional. The context menu to set as the owner of the tooltip
--- @param name string The name of the tooltip
--- @param description string The description of the tooltip
--- @param texture string|nil Optional. The path to a texture to display in the tooltip
--- @return ISToolTip The created tooltip
function WL_ContextMenuUtils.addToolTip(context, name, description, texture)
	if context then
		local tooltip = ISToolTip:new()
		tooltip:initialise()
		tooltip:setName(name)
		tooltip:setVisible(false)
		tooltip.description = description
		if texture then
			tooltip:setTexture(texture)
		end
		context.toolTip = tooltip
		return tooltip
	end
end
