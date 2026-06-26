WLCustomCases = WLCustomCases or {}
WLCustomCases.Organizer = WLCustomCases.Organizer or {}

local Organizer = WLCustomCases.Organizer

Organizer.ORGANIZER_ID_KEY = Organizer.ORGANIZER_ID_KEY or "WLCustomCases.OrganizerId"

function Organizer.GetOrganizerId(item)
    if not item then
        return nil
    end
    local md = item:getModData()
    return md and md[Organizer.ORGANIZER_ID_KEY] or nil
end

function Organizer.EnsureOrganizerId(item)
    if not item then
        return nil
    end
    local md = item:getModData()
    local id = md and md[Organizer.ORGANIZER_ID_KEY] or nil
    if not id or id == "" then
        if getRandomUUID then
            id = getRandomUUID()
            md[Organizer.ORGANIZER_ID_KEY] = id
        end
    end
    return id
end

function Organizer.ApplyOrganizerId(item, organizerId, clear)
    if not item then
        return
    end
    local md = item:getModData()
    if organizerId then
        md[Organizer.ORGANIZER_ID_KEY] = organizerId
        return
    end
    if clear then
        md[Organizer.ORGANIZER_ID_KEY] = nil
    end
end
