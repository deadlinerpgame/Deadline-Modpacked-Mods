if not isClient() then return end

WAT = WAT or {}
WAT.InvisibleIndicator = WAT.InvisibleIndicator or {}
WAT.InvisibleIndicator.Elements = WAT.InvisibleIndicator.Elements or {}
WAT.InvisibleIndicator.ShowEventPreference = WAT.InvisibleIndicator.ShowEventPreference or false

function WAT.InvisibleIndicator.enableEventPreference()
    WAT.InvisibleIndicator.ShowEventPreference = true
end

function WAT.InvisibleIndicator.disableEventPreference()
    WAT.InvisibleIndicator.ShowEventPreference = false
end

function WAT.InvisibleIndicator.toggleEventPreference()
    if WAT.InvisibleIndicator.ShowEventPreference then
        WAT.InvisibleIndicator.disableEventPreference()
    else
        WAT.InvisibleIndicator.enableEventPreference()
    end
end

local FONT = UIFont.Small
local MODULE_INVISIBLE = "Invisible"
local MODULE_DISGUISED = "Disguised"
local MODULE_OPEN = "Open"
local MODULE_DND = "DND"
local LINE_HEIGHT = getTextManager():MeasureStringY(FONT, "[Invisible]")

local PRIMARY_COLOR = { r = 0.6, g = 0.6, b = 0.6, a = 1.0 }
local OPEN_COLOR = { r = 0.2, g = 0.9, b = 0.2, a = 1.0 }
local DND_COLOR = { r = 0.9, g = 0.2, b = 0.2, a = 1.0 }

local function buildIndicatorText(username, isGhost, isDisguised)
    local modules = {}
    local textColor = PRIMARY_COLOR

    if isGhost then
        modules[#modules + 1] = MODULE_INVISIBLE
    end
    if isDisguised then
        modules[#modules + 1] = MODULE_DISGUISED
    end

    if WAT.InvisibleIndicator.ShowEventPreference then
        local playerStatus = WPC_System:getStatus(username)
        if playerStatus then
            if playerStatus.status == "Open" then
                modules[#modules + 1] = MODULE_OPEN
                textColor = OPEN_COLOR
            elseif playerStatus.status == "DND" then
                modules[#modules + 1] = MODULE_DND
                textColor = DND_COLOR
            end
        end
    end

    if #modules == 0 then return nil, nil end

    return "[" .. table.concat(modules, " / ") .. "]", textColor
end

function WAT.InvisibleIndicator.ShowInvisibleIndicators()
    for _,x in pairs(WAT.InvisibleIndicator.Elements) do x.seen = false end

    local allPlayers = getOnlinePlayers()
    if not allPlayers then return end

    local ownPlayer = getPlayer()
    if not ownPlayer then return end
    
    -- Only show indicators if the current player is staff
    if not WL_Utils or not WL_Utils.isStaff(ownPlayer) then
        -- Remove all indicators if player is not staff
        for k,v in pairs(WAT.InvisibleIndicator.Elements) do
            v:removeFromUIManager()
            WAT.InvisibleIndicator.Elements[k] = nil
        end
        return
    end
    
    -- Show indicators for other invisible players
    for i=0, allPlayers:size()-1 do
        local player = allPlayers:get(i)
        local username = player:getUsername()

        local indicatorText, indicatorColor = buildIndicatorText(username, player:isGhostMode(), WLDi_System:isDisguised(username))
        if indicatorText then
            local x = isoToScreenX(0, player:getX(), player:getY(), player:getZ())
            local y = isoToScreenY(0, player:getX(), player:getY(), player:getZ())

            if x > 0 and x < getCore():getScreenWidth() and
               y > 0 and y < getCore():getScreenHeight() then

                local width = getTextManager():MeasureStringX(FONT, indicatorText)
                local height = LINE_HEIGHT

                local ele = WAT.InvisibleIndicator.Elements[username]
                if ele then
                    ele:setX(x - (width / 2))
                    ele:setY(y)
                    ele.width = width
                    ele.height = height
                else
                    ele = ISUIElement:new(x - (width / 2), y, width, height)
                    ele.anchorTop = false
                    ele.anchorBottom = true
                    ele:initialise()
                    ele:addToUIManager()
                    ele:backMost()
                    ele.render = function(self)
                        self:drawTextCentre(self.indicatorText, self.width / 2, 0, self.indicatorColor.r, self.indicatorColor.g, self.indicatorColor.b, self.indicatorColor.a, FONT)
                    end
                    WAT.InvisibleIndicator.Elements[username] = ele
                end

                ele.indicatorText = indicatorText
                ele.indicatorColor = indicatorColor
                ele.seen = true
            end
        end
    end

    -- Remove unseen indicators
    for k,v in pairs(WAT.InvisibleIndicator.Elements) do
        if not v.seen then
            v:removeFromUIManager()
            WAT.InvisibleIndicator.Elements[k] = nil
        end
    end
end

Events.OnTick.Remove(WAT.InvisibleIndicator.ShowInvisibleIndicators)
Events.OnTick.Add(WAT.InvisibleIndicator.ShowInvisibleIndicators)
