require "WL_TileContextMenu"
require "PlayerReady"
require "scavenging/WWP_ScavengeType"
require "scavenging/WWP_TileScavengingData"
require "scavenging/WWP_ScavengeTileAction"

WWP_ScavengeMenu = WWP_ScavengeMenu or {}
WWP_ScavengeMenu.REGISTRATION_ID_PREFIX = "WWP_Scavenging_"

local SCAVENGE_ICON_TEXTURE = getTexture("media/ui/scavenge-tile.png")

local function addTooltip(option, text)
    local toolTip = ISWorldObjectContextMenu.addToolTip()
    toolTip:setVisible(false)
    toolTip.description = text
    option.toolTip = toolTip
end

local function addDisabledTooltip(option, text)
    addTooltip(option, text)
    option.notAvailable = true
end

local function queueUnequipHandItems(player)
    local primaryItem = player:getPrimaryHandItem()
    local secondaryItem = player:getSecondaryHandItem()

    if primaryItem then
        ISTimedActionQueue.add(ISUnequipAction:new(player, primaryItem, 50))
    end

    if secondaryItem and secondaryItem ~= primaryItem then
        ISTimedActionQueue.add(ISUnequipAction:new(player, secondaryItem, 50))
    end
end

function WWP_ScavengeMenu.onScavenge(player, square, isoObject, scavengeType)
    local adjacent = AdjacentFreeTileFinder.Find(square, player)
    if not adjacent then
        player:Say("I can't reach that.")
        return
    end

    ISTimedActionQueue.add(ISWalkToTimedAction:new(player, adjacent))
    queueUnequipHandItems(player)
    ISTimedActionQueue.add(WWP_ScavengeTileAction:new(player, scavengeType, square, isoObject))
end

function WWP_ScavengeMenu.addContextOption(player, context, square, isoObject, scavengeType)
    local optionText = scavengeType.contextOption or scavengeType.name
    local option = context:addOption(optionText, player, WWP_ScavengeMenu.onScavenge, square, isoObject, scavengeType)
    option.iconTexture = SCAVENGE_ICON_TEXTURE
    if not WWP_PlayerStats.hasPointsAvailable(player, scavengeType.workPoints) then
        addDisabledTooltip(option, "Not enough work points <LINE> " .. WWP_PlayerStats.getWorkPointsRemainingString(player))
    end
    if WWP_TileScavengingData.isRecentlySearched(player, square) then
        addDisabledTooltip(option, "You searched here recently.")
    end
    if not option.notAvailable then
        addTooltip(option, (scavengeType.tooltip or "Scavenge here for resources.") .. " <LINE> Uses " ..
                tostring(scavengeType.workPoints) .. " work points.")
    end
end

local function registerScavengeType(scavengeKey, scavengeType, player)
    local registrationId = WWP_ScavengeMenu.REGISTRATION_ID_PREFIX .. scavengeKey
    if player:HasTrait(scavengeType.trait) then
        WL_TileContextMenu.register(
            registrationId,
            scavengeType.tiles,
            function(menuPlayer, context, square, isoObject)
                WWP_ScavengeMenu.addContextOption(menuPlayer, context, square, isoObject, scavengeType)
            end)
    else
        WL_TileContextMenu.deRegister(registrationId)
    end
end

function WWP_ScavengeMenu.onPlayerReady(_, player)
    for scavengeKey, scavengeType in pairs(WWP_ScavengeType) do
        registerScavengeType(scavengeKey, scavengeType, player)
    end
end

WL_PlayerReady.Add(WWP_ScavengeMenu.onPlayerReady)
