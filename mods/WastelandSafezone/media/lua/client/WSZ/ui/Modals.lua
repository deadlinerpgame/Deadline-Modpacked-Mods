---
--- WSZ_Modals.lua
--- Modal dialog utilities for Wasteland Safezone membership requests
---

WSZ_Modals = {}

--- Client: manager receives prompt to accept/reject/accept timed
--- @param _ IsoPlayer
--- @param requestId string
--- @param zoneId string
--- @param zoneName string
--- @param requesterUsername string
function WSZ_Modals.membershipRequestPrompt(_, requestId, zoneId, zoneName, requesterUsername)
    if isServer() then
        WSZ_System:logError("membershipRequestPrompt should not be called on server")
        return
    end

    local function sendDecision(decision, minutes)
        local me = getPlayer()
        WSZ_System:sendToServer(me, "membershipRequestDecision", requestId, decision, minutes or 0)
    end

    -- First modal: Accept?
    local msg = string.format("%s requests membership to '%s'. Accept?", tostring(requesterUsername), tostring(zoneName))
    local x = getCore():getScreenWidth() / 2 - 175
    local y = getCore():getScreenHeight() / 2 - 75
    local modal = ISModalDialog:new(x, y, 350, 150, msg, true, nil, function(_, button)
        if button.internal == "YES" then
            -- Second modal: timed or permanent via text box minutes input (blank/0 = permanent)
            local tbMsg = "Enter minutes for temporary membership (leave blank or 0 for permanent):"
            local tb = ISTextBox:new(x, y, 400, 180, tbMsg, "", nil, function(tbObj, button2)
                if button2.internal == "OK" then
                    local txt = button2.parent.entry:getText() or ""
                    local minutes = tonumber(txt) or 0
                    if minutes > 0 then
                        sendDecision("accept_timed", minutes)
                    else
                        sendDecision("accept", 0)
                    end
                else
                    sendDecision("reject", 0)
                end
            end, nil)
            tb:initialise()
            tb:addToUIManager()
            tb.entry:focus()
        else
            sendDecision("reject", 0)
        end
    end)
    modal:initialise()
    modal:addToUIManager()
end

--- Client: general notices regarding membership requests (requester or manager)
--- @param _ IsoPlayer
--- @param status string
--- @param message string
function WSZ_Modals.membershipRequestNotice(_, status, message)
    if isServer() then
        WSZ_System:logError("membershipRequestNotice should not be called on server")
        return
    end
    message = tostring(message or "")
    if WL_Dialogs and WL_Dialogs.showMessageDialog then
        WL_Dialogs.showMessageDialog(message)
    else
        local x = getCore():getScreenWidth() / 2 - 175
        local y = getCore():getScreenHeight() / 2 - 75
        local modal = ISModalDialog:new(x, y, 350, 150, message, false, nil, nil)
        modal:initialise()
        modal:addToUIManager()
    end
end

--- Client: requester receives final result
--- @param _ IsoPlayer
--- @param result "accepted"|"accepted_timed"|"rejected"
--- @param zoneId string
--- @param zoneName string
--- @param managerUsername string
--- @param minutes number
function WSZ_Modals.membershipRequestResult(_, result, zoneId, zoneName, managerUsername, minutes)
    if isServer() then
        WSZ_System:logError("membershipRequestResult should not be called on server")
        return
    end

    local msg = ""
    if result == "rejected" then
        msg = string.format("Your membership request to '%s' was rejected by %s.", tostring(zoneName), tostring(managerUsername))
    elseif result == "accepted_timed" then
        local mins = tonumber(minutes) or 0
        msg = string.format("Your membership request to '%s' was accepted by %s for %d minutes.", tostring(zoneName), tostring(managerUsername), mins)
    else
        msg = string.format("Your membership request to '%s' was accepted by %s.", tostring(zoneName), tostring(managerUsername))
    end

    if WL_Dialogs and WL_Dialogs.showMessageDialog then
        WL_Dialogs.showMessageDialog(msg)
    else
        local x = getCore():getScreenWidth() / 2 - 175
        local y = getCore():getScreenHeight() / 2 - 75
        local modal = ISModalDialog:new(x, y, 350, 150, msg, false, nil, nil)
        modal:initialise()
        modal:addToUIManager()
    end
end