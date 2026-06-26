local function openZoneEditor(player, zone)
    if not zone then return end
    WastelandZones.Classes.ZoneEditorWindow:show(zone)
end

function createNewZone(player)
    local square = player:getCurrentSquare()
    if not square then return end

    local zone = WastelandZones.Classes.Zone:new()
    openZoneEditor(player, zone)
end

local function listAllZones(player)
    if not player then return end
    WastelandZones.Classes.ZoneListWindow:show(player)
end

local function distanceSqToZone(zone, px, py, pz)
    local bounds = zone and zone.bounds or nil
    if bounds then
        local dx = 0
        local dy = 0
        local dz = 0

        if px < bounds.x1 then
            dx = bounds.x1 - px
        elseif px > bounds.x2 then
            dx = px - bounds.x2
        end

        if py < bounds.y1 then
            dy = bounds.y1 - py
        elseif py > bounds.y2 then
            dy = py - bounds.y2
        end

        if pz < bounds.z1 then
            dz = bounds.z1 - pz
        elseif pz > bounds.z2 then
            dz = pz - bounds.z2
        end

        return (dx * dx) + (dy * dy) + (dz * dz)
    end

    local center = zone and zone.center or nil
    if not center and zone and zone.calcCenter then
        center = zone:calcCenter()
    end

    local zx = center and center.x or px
    local zy = center and center.y or py
    local zz = center and center.z or pz
    local dx = zx - px
    local dy = zy - py
    local dz = zz - pz
    return (dx * dx) + (dy * dy) + (dz * dz)
end

local function getNearbyZonesSorted(player, range)
    local results = {}
    if not player or not WastelandZones or not WastelandZones.Zones then
        return results
    end

    local zonesRegistry = WastelandZones.Zones

    local px, py, pz = player:getX(), player:getY(), player:getZ()
    local nearMap = zonesRegistry:getAllNear(px, py, pz, range)

    for zoneId, zone in pairs(nearMap) do
        if not zone.isClientTemporary then
            results[#results + 1] = {
                zone = zone,
                id = zoneId,
                distSq = distanceSqToZone(zone, px, py, pz)
            }
        end
    end

    table.sort(results, function(a, b)
        if a.distSq == b.distSq then
            local aName = tostring((a.zone and a.zone.name) or a.id or "")
            local bName = tostring((b.zone and b.zone.name) or b.id or "")
            return aName < bName
        end
        return a.distSq < b.distSq
    end)

    return results
end

function AddWastelandZonesMenu(playerNum, context, worldobjects, test)
    local player = getSpecificPlayer(playerNum)
    if WL_Utils.isStaff(player) then
        local wlAdmin = WL_ContextMenuUtils.getOrCreateSubMenu(context, "WL Admin")
        local worldManagement = WL_ContextMenuUtils.getOrCreateSubMenu(wlAdmin, "World Management")
        local zones = WL_ContextMenuUtils.getOrCreateSubMenu(worldManagement, "Zones")

        zones:addOption("Create New Zone", player, createNewZone)
        zones:addOption("List All Zones", player, listAllZones)

        local nearbyZones = getNearbyZonesSorted(player, 100)

        if #nearbyZones > 0 then
            local nearbyZonesSubMenu = WL_ContextMenuUtils.getOrCreateSubMenu(context, "Nearby Zones")
            
            for i = 1, #nearbyZones do
                local entry = nearbyZones[i]
                local zone = entry.zone
                local zoneName = zone and zone.name or ("Zone " .. tostring(entry.id))
                local distance = math.sqrt(entry.distSq)
                local label = string.format("%s (%.1f)", tostring(zoneName), distance)
                nearbyZonesSubMenu:addOption(label, player, openZoneEditor, zone)
            end
        end

        
    end
end

Events.OnFillWorldObjectContextMenu.Add(AddWastelandZonesMenu)
