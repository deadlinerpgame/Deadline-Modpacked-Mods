---
--- WIT_AdBoard.lua
--- 21/10/2024
---

if not getActivatedMods():contains("SC_Boards") then return end

require "ISUI/ISBoard"
require "WL_Utils"

if WIT_AdBoard then
    Events.OnFillWorldObjectContextMenu.Remove(WIT_AdBoard.contextMenuAdd)
end

WIT_AdBoard = {}

local function changeAdBoard(player, x, y, z, option)
    local boardID = SC_Board:getID(x, y, z)
    if boardID then
        local board = SC_Board:getBoard(boardID)
        local scale = getTextManager():getFontHeight(UIFont.Small) / 14
        local width = 220 * scale
        local height = 180 * scale
        local x = (getCore():getScreenWidth() / 2) - (width / 2)
        local y = (getCore():getScreenHeight() / 2) - (height / 2)
        if option == "limit" then
            local modal = ISTextBox:new(x, y, width, height, "Enter new limit:", tostring(board.limit), nil, function (_, button)
                if button.internal == "OK" then
                    local newLimit = tonumber(button.target.entry:getText())
                    if newLimit then
                        board.limit = newLimit
                    end
                end
            end, nil)
            modal:initialise()
            modal.entry:setOnlyNumbers(true)
            modal:addToUIManager()
            local originalDestroy = modal.destroy
            modal.destroy = function(self)
                originalDestroy(self)
            end
        elseif option == "name" then 
            local modal = ISTextBox:new(x, y, width, height, "Enter new name:", board.title, nil, function (_, button)
                if button.internal == "OK" then
                    board.title = button.target.entry:getText()
                end
            end, nil)
            modal:initialise()
            modal:addToUIManager()
            local originalDestroy = modal.destroy
            modal.destroy = function(self)
                originalDestroy(self)
            end
        end
    else
        print("No board found at the specified location.")
    end
end

function WIT_AdBoard.contextMenuAdd(player, context, worldobjects, test)
    local sq = {};
    local x,y,z = 0,0,0;
    for i,v in ipairs(worldobjects) do
		local sq = v:getSquare();
        if sq then
            x = sq:getX();
            y = sq:getY();
            z = sq:getZ();
            break; 
        end
    end
    if SC_Board:isBoard(x,y,z) and WL_Utils.isStaff(getPlayer()) then
        local optionLimit = context:addOption("Change Board Limit", worldobjects, function() changeAdBoard(player, x, y, z, "limit") end)
        optionLimit.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
        local optionName = context:addOption("Change Board Name", worldobjects, function() changeAdBoard(player, x, y, z, "name") end)
        optionName.iconTexture = getTexture("media/ui/icons/SC_Board_ContextMenu.png");
    end
end

Events.OnFillWorldObjectContextMenu.Add(WIT_AdBoard.contextMenuAdd)