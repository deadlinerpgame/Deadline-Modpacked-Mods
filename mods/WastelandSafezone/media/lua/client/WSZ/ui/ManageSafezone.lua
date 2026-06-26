---
--- WSZ_ManageSafezone.lua
--- Manage Safezone UI implemented using Workplace-style panels
---

require "GravyUI_WL"

WSZ_ManageSafezone = ISPanel:derive("WSZ_ManageSafezone")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local FONT_HGT_LARGE = getTextManager():getFontHeight(UIFont.Large)

local COLOR_WHITE = { r = 1, g = 1, b = 1, a = 1 }
local COLOR_BLUE = { r = 0.3, g = 0.5, b = 1, a = 1 }
local COLOR_RED = { r = 1, g = 0.3, b = 0.3, a = 1 }
local COLOR_YELLOW = { r = 1, g = 1, b = 0, a = 1 }

local SCALE = FONT_HGT_SMALL / 19
local function scale(px) return px * SCALE end

-- Role helpers
local function getMember(zone, username)
    if not zone or not zone.members then return nil end
    return zone.members[username]
end

local function isOfficer(zone, username)
    local m = getMember(zone, username)
    if not m then return false end
    return m.type == "officer" or m.type == "owner"
end

local function isOwner(zone, username)
    local m = getMember(zone, username)
    return m and m.type == "owner"
end

local function isStaff()
    local player = getPlayer()
    if not player then return false end
    return WL_Utils.isStaff(player)
end

-- Container/show
function WSZ_ManageSafezone:show(player, zone)
    if WSZ_ManageSafezone.instance then
        WSZ_ManageSafezone.instance:onClose()
    end
    local w = math.floor(scale(600))
    local h = math.floor(scale(600))
    local x = math.floor((getCore():getScreenWidth() - w) / 2)
    local y = math.floor((getCore():getScreenHeight() - h) / 2)
    local ui = WSZ_ManageSafezone:new(x, y, w, h, player, zone)
    ui:initialise()
    ui:addToUIManager()
    WSZ_ManageSafezone.instance = ui
    return ui
end

function WSZ_ManageSafezone:new(x, y, width, height, player, zone)
    local o = ISPanel:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.player = player
    o.zone = zone
    o.anchorTop = true
    o.anchorBottom = true
    o.anchorLeft = true
    o.anchorRight = true
    o.resizable = false
    o.moveWithMouse = true
    o.images = {}
    o.highlightPicker = nil
    return o
end

-- Subpanels as locals (in-file classes) to keep file count minimal for first pass

-- Info Panel: shows basic info and Leave button
local InfoPanel = ISPanel:derive("WSZ_SafezoneInfoSubPanel")

function InfoPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o:initialise()
    return o
end

function InfoPanel:initialise()
    ISPanel.initialise(self)
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))

    local vstack = win:makeVerticalStack(scale(12))

    -- Title and zone name
    local titleRow = vstack:makeNode(FONT_HGT_LARGE)
    local titleLabelArea, renameArea = titleRow:cols({ 0.75, 0.25 }, scale(10))
    self.nameLabel = titleLabelArea:makeLabel("Safezone", UIFont.Large, COLOR_WHITE, "left")

    self.renameButton = renameArea:makeButton("Rename", self, self.onRename)

    -- Membership status
    self.memberStatusRow = vstack:makeNode(FONT_HGT_LARGE)
    self.memberLabel = self.memberStatusRow:makeLabel("", UIFont.Medium, COLOR_WHITE, "left")


    -- Action buttons in a single row
    local actionRow = vstack:makeNode(FONT_HGT_LARGE)
    local leaveArea, transferArea, deleteArea = actionRow:cols({ 0.33, 0.34, 0.33 }, scale(10))
    self.leaveButton = leaveArea:makeButton("Leave Safezone", self, self.onLeave)
    self.transferOwnershipButton = transferArea:makeButton("Transfer Ownership", self, self.onTransferOwnership)
    self.deleteButton = deleteArea:makeButton("Delete Safezone", self, self.onDelete)
end

function InfoPanel:updateState()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    self.nameLabel:setText("Safezone: " .. tostring(zone.name or "Unnamed"))

    local m = getMember(zone, player:getUsername())
    if m then
        local role = m.type or "member"
        self.memberLabel:setText("Membership: You are " .. role)
        self.leaveButton:setVisible(true)
        self.leaveButton.enable = true

        -- Owners can still leave if there are other owners? For now, allow owners to leave but warn on staff gate elsewhere.
        self.leaveButton:setTooltip(nil)
    else
        self.memberLabel:setText("Membership: You are not a member")
        self.leaveButton:setVisible(false)
    end


    -- Permissions for rename
    local canRename = isOwner(zone, player:getUsername()) or isStaff()
    self.renameButton:setVisible(canRename)

    -- Permissions for transfer ownership
    local canTransferOwnership = isOwner(zone, player:getUsername()) or isStaff()
    self.transferOwnershipButton:setVisible(canTransferOwnership)

    -- Permissions for delete safezone
    local canDelete = isOwner(zone, player:getUsername()) or isStaff()
    self.deleteButton:setVisible(canDelete)
end

function InfoPanel:onLeave()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local username = player:getUsername()
    local member = getMember(zone, username)
    local message = "Are you sure you want to leave this safezone?"

    if member and member.type == "owner" then
        local successor = WSZ_System:getEligibleOwnerSuccessor(zone, username)
        if successor then
            message = "Are you sure you want to leave this safezone? Ownership will transfer to " .. tostring(successor.username) .. "."
        else
            message = "Are you sure you want to leave this safezone? No eligible officer can take ownership, so the safezone will be deleted if you leave."
        end
    end

    WL_Dialogs.showConfirmationDialog(message, function()
        WSZ_System:removeMember(player, zone.id, username)
    end)
end

function InfoPanel:onRename()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    if not (isOwner(zone, player:getUsername()) or isStaff()) then return end

    WL_TextEntryPanel:show("Enter the new name for this safezone", nil, function(_, newName)
        if not newName or newName == "" then return end
        if WSZ_System.renameZone then
            WSZ_System:renameZone(player, zone.id, newName)
        else
            zone.name = newName
            self.parentPanel:updateState()
        end
    end, zone.name or "", false, false)
end

function InfoPanel:onTransferOwnership()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    if not (isOwner(zone, player:getUsername()) or isStaff()) then return end

    -- Use the same player selector UX as "Add Member", allowing manual entry and non-members
    WL_SelectPlayersPanel:show(nil, function(_, target)
        if not target or target == "" then return end

        -- Optional: avoid no-op if already owner
        local m = zone.members and zone.members[target]
        if m and m.type == "owner" then
            WL_Dialogs.showMessageDialog(target .. " is already the owner.")
            return
        end

        if not isStaff() and not WSZ_System:canUserOwnZone(target, zone.id) then
            WL_Dialogs.showMessageDialog(target .. " cannot receive ownership because they are already at the safezone ownership limit.")
            return
        end

        WL_Dialogs.showConfirmationDialog("Transfer ownership to " .. target .. "?", function()
            if WSZ_System and WSZ_System.reassignOwner then
                WSZ_System:reassignOwner(player, zone.id, target)
            else
                -- Local fallback: demote current owners to officer, then ensure/upgrade target to owner
                for uname, mem in pairs(zone.members or {}) do
                    if mem.type == "owner" and uname ~= target then
                        zone.members[uname] = {
                            username = mem.username,
                            type = "officer",
                            addedBy = mem.addedBy,
                            addedAt = mem.addedAt,
                            lastVisitedAt = mem.lastVisitedAt,
                            expiration = mem.expiration
                        }
                    end
                end

                local tm = zone.members and zone.members[target]
                if not tm then
                    zone.members = zone.members or {}
                    zone.members[target] = {
                        username = target,
                        type = "owner",
                        addedBy = player:getUsername(),
                        addedAt = getTimestamp(),
                        lastVisitedAt = 0,
                        expiration = nil
                    }
                else
                    zone.members[target] = {
                        username = tm.username,
                        type = "owner",
                        addedBy = tm.addedBy,
                        addedAt = tm.addedAt,
                        lastVisitedAt = tm.lastVisitedAt,
                        expiration = tm.expiration
                    }
                end

                if WSZ_Client and WSZ_Client.updateZone then
                    WSZ_Client.updateZone(zone)
                end
            end
        end)
    end, {
        includeSelf = false,
        onlyInLOS = false,
        allowManual = true,
    })
end

function InfoPanel:onDelete()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    if not (isOwner(zone, player:getUsername()) or isStaff()) then return end

    WL_Dialogs.showConfirmationDialog("Are you sure you want to delete this safezone? This action cannot be undone!", function()
        WSZ_System:deleteZone(player, zone.id)
        -- Close the management window after deletion
        if self.parentPanel and self.parentPanel.onClose then
            self.parentPanel:onClose()
        end
    end)
end

-- Manage Panel: members list and actions
local ManagePanel = ISPanel:derive("WSZ_SafezoneManageSubPanel")

function ManagePanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o:initialise()
    return o
end

-- Formats an expiration timestamp (seconds) into a simple badge text
local function _formatExpirationBadge(expTs)
    if not expTs then return "" end
    local now = getTimestamp()
    local delta = expTs - now
    if delta <= 0 then
        return " - expired"
    end
    -- Show days/hours/minutes
    local secInMin = 60
    local secInHour = 60 * secInMin
    local secInDay = 24 * secInHour

    local days = math.floor(delta / secInDay)
    local hours = math.floor((delta % secInDay) / secInHour)
    local minutes = math.floor((delta % secInHour) / secInMin)

    if days > 0 then
        return string.format(" - exp in %dd %dh", days, hours)
    elseif hours > 0 then
        return string.format(" - exp in %dh %dm", hours, minutes)
    else
        if minutes > 0 then
            return string.format(" - exp in %dm", minutes)
        else
            return " - exp in <1m"
        end
    end
end

function ManagePanel:initialise()
    ISPanel.initialise(self)
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))

    local top, body = win:rows({ FONT_HGT_LARGE, 1 }, scale(12))
    top:makeLabel(" Members", UIFont.Large, COLOR_WHITE, "left")

    local listArea, buttonsArea = body:cols({ 0.7, 0.3 }, scale(12))
    self.memberList = listArea:makeScrollingListBox()
    
    -- Set custom row height (reduced since "Added by" moved to tooltip)
    self.memberList.itemheight = scale(64)
    
    -- Add selection change handler
    self.memberList.onmousedown = function(_, item, _)
        self:onMemberSelectionChanged()
    end

        
    -- Colors for different roles
    local roleColors = {
        owner = COLOR_YELLOW,
        officer = COLOR_BLUE,
        member = COLOR_WHITE
    }

    -- Custom row rendering for member information
    function self.memberList:doDrawItem(y, item, alt)
        local zone = self.parent.parentPanel.zone
        if not zone or not zone.members then
            return y + self.itemheight
        end
        
        local memberData = zone.members[item.item]
        if not memberData then
            return y + self.itemheight
        end
        local roleColor = roleColors[memberData.type] or COLOR_WHITE
        
        -- Background highlight for selected item
        if self.selected == item.index then
            self:drawRect(0, y, self:getWidth(), self.itemheight, 0.3, 0.7, 0.35, 0.15)
        end
        
        -- Draw border
        self:drawRectBorder(0, y, self:getWidth(), self.itemheight, 0.3, 0.4, 0.4, 0.4)
        
        local padding = scale(8)
        local lineHeight = FONT_HGT_SMALL + scale(2)
        local currentY = y + padding
        
        -- Line 1: Username and Role
        local username = memberData.username or "Unknown"
        local role = string.upper(memberData.type or "member")
        self:drawText(username, padding, currentY, roleColor.r, roleColor.g, roleColor.b, roleColor.a, UIFont.Medium)
        self:drawTextRight("[" .. role .. "]", self.width - padding - scale(15), currentY, roleColor.r, roleColor.g, roleColor.b, roleColor.a, UIFont.Small)
        currentY = currentY + lineHeight + scale(2)
        
        -- Line 2: Last Visit Time (expiration badge on right)
        local lastVisitText = "Last Visit: "
        if memberData.lastVisitedAt and memberData.lastVisitedAt > 0 then
            local now = getTimestamp()
            local timeDiff = now - memberData.lastVisitedAt
            if timeDiff < 60 then
                lastVisitText = lastVisitText .. "Just now"
            elseif timeDiff < 3600 then
                lastVisitText = lastVisitText .. math.floor(timeDiff / 60) .. "m ago"
            elseif timeDiff < 86400 then
                lastVisitText = lastVisitText .. math.floor(timeDiff / 3600) .. "h ago"
            else
                lastVisitText = lastVisitText .. math.floor(timeDiff / 86400) .. "d ago"
            end
        else
            lastVisitText = lastVisitText .. "Never"
        end
        -- Draw left text
        self:drawText(lastVisitText, padding, currentY, 0.8, 0.8, 0.8, 1, UIFont.Small)
        -- Draw expiration badge on same line (right aligned), if any
        if memberData.expiration then
            local expText = _formatExpirationBadge(memberData.expiration)
            if expText and expText ~= "" then
                -- Remove the " - " prefix from the badge format
                expText = string.gsub(expText, "^%s*-%s*", "")
                local expColor = COLOR_RED
                local now = getTimestamp()
                if memberData.expiration > now then
                    expColor = COLOR_YELLOW
                end
                self:drawTextRight(expText, self.width - padding, currentY, expColor.r, expColor.g, expColor.b, expColor.a, UIFont.Small)
            end
        end
        currentY = currentY + lineHeight
        
        return y + self.itemheight
    end

    local addRow, promoteRow, demoteRow, removeRow, setExpRow, clearExpRow = buttonsArea:rows(
        { FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE, FONT_HGT_LARGE },
        scale(10)
    )
    self.addButton = addRow:makeButton("Add Member", self, self.onAdd)
    self.promoteButton = promoteRow:makeButton("Promote to Officer", self, self.onPromote)
    self.demoteButton = demoteRow:makeButton("Demote to Member", self, self.onDemote)
    self.removeButton = removeRow:makeButton("Remove", self, self.onRemove)
    self.setExpirationButton = setExpRow:makeButton("Set Expiration", self, self.onSetExpiration)
    self.clearExpirationButton = clearExpRow:makeButton("Clear Expiration", self, self.onClearExpiration)
end

local function sortMembers(zone)
    local arr = {}
    for uname, m in pairs(zone.members or {}) do
        table.insert(arr, {
            username = uname,
            type = m.type or "member",
            addedAt = m.addedAt or 0,
            expiration = m.expiration
        })
    end
    table.sort(arr, function(a, b)
        local rank = { owner = 3, officer = 2, member = 1 }
        local ra = rank[a.type] or 0
        local rb = rank[b.type] or 0
        if ra ~= rb then return ra > rb end
        return a.username:lower() < b.username:lower()
    end)
    return arr
end

function ManagePanel:updateState()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end

    self.memberList:clear()
    for _, entry in ipairs(sortMembers(zone)) do
        -- Pass the username as both display text and item data for the custom renderer
        local item = self.memberList:addItem(entry.username, entry.username)

        -- Tooltip: show "Added by" info (moved out of inline rendering)
        local m = zone.members and zone.members[entry.username]
        if m then
            local tip = nil
            if m.addedBy and m.addedBy ~= "" then
                tip = "Added by: " .. tostring(m.addedBy)
                if m.addedAt and m.addedAt > 0 then
                    local now = getTimestamp()
                    local td = now - m.addedAt
                    if td < 86400 then
                        tip = tip .. " (today)"
                    else
                        tip = tip .. " (" .. math.floor(td / 86400) .. "d ago)"
                    end
                end
            end
            item.tooltip = tip
        end
    end

    -- Select the first item if there are any members
    if #self.memberList.items > 0 then
        self.memberList.selected = 1
    end

    local user = player:getUsername()
    local canOfficer = isOfficer(zone, user) or isStaff()
    local canOwner = isOwner(zone, user) or isStaff()

    -- Visibility according to roles (always visible if user has permission)
    self.addButton:setVisible(canOfficer)
    self.addButton.enable = canOfficer

    self.removeButton:setVisible(canOfficer)
    self.promoteButton:setVisible(canOwner)
    self.demoteButton:setVisible(canOwner)

    -- Expiration controls: officer+ can manage
    if self.setExpirationButton then
        self.setExpirationButton:setVisible(canOfficer)
    end
    if self.clearExpirationButton then
        self.clearExpirationButton:setVisible(canOfficer)
    end

    -- Update button states based on selection
    self:updateButtonStates()
end

function ManagePanel:getSelectedUsername()
    local selected = self.memberList.items[self.memberList.selected]
    if not selected then return nil end
    return selected.item
end

function ManagePanel:onMemberSelectionChanged()
    self:updateButtonStates()
end

function ManagePanel:updateButtonStates()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end

    local user = player:getUsername()
    local canOfficer = isOfficer(zone, user) or isStaff()
    local canOwner = isOwner(zone, user) or isStaff()
    local hasSelection = self.memberList.selected > 0
    local selectedUsername = self:getSelectedUsername()
    
    -- Get selected member info for additional checks
    local selectedMember = nil
    if selectedUsername and zone.members then
        selectedMember = zone.members[selectedUsername]
    end

    -- Promote button: only enabled if user can promote AND has selection AND selected member is member (not officer or owner)
    local canPromote = canOwner and hasSelection and selectedMember and selectedMember.type == "member"
    self.promoteButton.enable = canPromote

    -- Demote button: only enabled if user can demote AND has selection AND selected member is officer (not owner or regular member)
    local canDemote = canOwner and hasSelection and selectedMember and selectedMember.type == "officer"
    self.demoteButton.enable = canDemote

    -- Remove button: Owners can remove any but owner, officers can remove members only
    local canRemove = hasSelection and selectedMember and (canOwner or (canOfficer and selectedMember.type == "member")) and selectedMember.type ~= "owner"
    self.removeButton.enable = canRemove
    
    -- Expiration buttons: only enabled for members (not officers or owners)
    local canSetExpiration = canOfficer and hasSelection and selectedMember and selectedMember.type == "member"
    if self.setExpirationButton then
        self.setExpirationButton.enable = canSetExpiration
    end
    if self.clearExpirationButton then
        self.clearExpirationButton.enable = canSetExpiration
    end
end

function ManagePanel:onAdd()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    WL_SelectPlayersPanel:show(nil, function(_, username)
        if not username or username == "" then return end
        if zone.members[username] then
            WL_Dialogs.showMessageDialog(username .. " is already a member.")
            return
        end
        local memberObject = {
            username = username,
            type = "member",
            addedBy = player:getUsername(),
            addedAt = getTimestamp(),
            lastVisitedAt = 0,
            expiration = nil
        }
        WSZ_System:addMember(player, zone.id, memberObject)
    end, {
        includeSelf = false,
        onlyInLOS = false,
        allowManual = true,
    })
end

function ManagePanel:onPromote()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local username = self:getSelectedUsername()
    if not username then return end
    local m = zone.members[username]
    if not m then return end
    if m.type == "owner" then return end
    m = {
        username = username,
        type = "officer",
        addedBy = m.addedBy,
        addedAt = m.addedAt,
        lastVisitedAt = m.lastVisitedAt,
        expiration = m.expiration
    }
    WSZ_System:modifyMember(player, zone.id, m)
end

function ManagePanel:onDemote()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local username = self:getSelectedUsername()
    if not username then return end
    local m = zone.members[username]
    if not m then return end
    if m.type ~= "officer" then return end
    m = {
        username = username,
        type = "member",
        addedBy = m.addedBy,
        addedAt = m.addedAt,
        lastVisitedAt = m.lastVisitedAt,
        expiration = m.expiration
    }
    WSZ_System:modifyMember(player, zone.id, m)
end

function ManagePanel:onRemove()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local username = self:getSelectedUsername()
    if not username then return end

    -- Prevent removing owner unless staff
    local entry = zone.members[username]
    if entry and entry.type == "owner" and not isStaff() then
        WL_Dialogs.showMessageDialog("You cannot remove the owner.")
        return
    end

    WL_Dialogs.showConfirmationDialog("Remove " .. username .. " from this safezone?", function()
        WSZ_System:removeMember(player, zone.id, username)
    end)
end

-- Officers+ can set an expiration for the selected member
function ManagePanel:onSetExpiration()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local actor = player:getUsername()
    if not (isOfficer(zone, actor) or isStaff()) then return end

    local username = self:getSelectedUsername()
    if not username then return end
    local m = zone.members[username]
    if not m then return end
    if m.type == "owner" then
        WL_Dialogs.showMessageDialog("Owners cannot have an expiration.")
        return
    end

    local prompt = "Enter duration (e.g., 30m, 12h, 7d). Empty to cancel."
    WL_TextEntryPanel:show(prompt, nil, function(_, text)
        if not text or text == "" then return end

        local s = string.lower(string.gsub(text, "%s+", ""))
        local numStr, rawUnit = string.match(s, "^(%d+)(%a*)$")
        local num = numStr and tonumber(numStr) or nil
        if not num or num <= 0 then
            WL_Dialogs.showMessageDialog("Invalid duration.")
            return
        end

        -- Support multiple aliases for units
        local unitAliases = {
            s = "s", sec = "s", secs = "s", second = "s", seconds = "s",
            m = "m", min = "m", mins = "m", minute = "m", minutes = "m",
            h = "h", hr = "h", hrs = "h", hour = "h", hours = "h",
            d = "d", day = "d", days = "d"
        }
        local unit = rawUnit ~= "" and (unitAliases[rawUnit] or rawUnit) or "h"

        local secPer = { s = 1, m = 60, h = 60 * 60, d = 24 * 60 * 60 }
        local per = secPer[unit]
        if not per then
            WL_Dialogs.showMessageDialog("Invalid unit. Use s/sec, m/min, h/hr, or d/day.")
            return
        end

        local now = getTimestamp()
        local newExp = now + (num * per)

        local updated = {
            username = m.username,
            type = m.type,
            addedBy = m.addedBy,
            addedAt = m.addedAt,
            lastVisitedAt = m.lastVisitedAt,
            expiration = newExp
        }
        WSZ_System:modifyMember(player, zone.id, updated)
    end, "", false, false)
end

-- Officers+ can clear expiration
function ManagePanel:onClearExpiration()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    local actor = player:getUsername()
    if not (isOfficer(zone, actor) or isStaff()) then return end

    local username = self:getSelectedUsername()
    if not username then return end
    local m = zone.members[username]
    if not m then return end

    if m.expiration == nil then
        WL_Dialogs.showMessageDialog("No expiration is set.")
        return
    end

    WL_Dialogs.showConfirmationDialog("Clear expiration for " .. username .. "?", function()
        local updated = {
            username = m.username,
            type = m.type,
            addedBy = m.addedBy,
            addedAt = m.addedAt,
            lastVisitedAt = m.lastVisitedAt,
            expiration = nil
        }
        WSZ_System:modifyMember(player, zone.id, updated)
    end)
end

-- Admin Panel: resize (staff only)
local AdminPanel = ISPanel:derive("WSZ_SafezoneAdminSubPanel")

function AdminPanel:new(x, y, w, h, parent)
    local o = ISPanel:new(x, y, w, h)
    setmetatable(o, self)
    self.__index = self
    o.parentPanel = parent
    o:initialise()
    return o
end

function AdminPanel:initialise()
    ISPanel.initialise(self)
    local win = GravyUI.Node(self.width, self.height, self)
    win = win:pad(scale(16), scale(16), scale(16), scale(16))

    local stack = win:makeVerticalStack(scale(14))

    -- Area picker for resize (staff only)
    local areaBlock = stack:makeNode(scale(220))
    local apTitle, apPickerRow, apButtons = areaBlock:rows({ FONT_HGT_LARGE, 0.65, 0.35 }, scale(10))
    apTitle:makeLabel("Safezone Area (Staff Only)", UIFont.Large, COLOR_YELLOW, "left")
    self.apPicker = apPickerRow:makeAreaPicker()
    self.apPicker.showAlways = false
    self.apPicker.fullZ = false
    local apResetArea, apSaveArea = apButtons:cols({ 0.5, 0.5 }, scale(10))
    self.apReset = apResetArea:makeButton("Reset", self, self.onApReset)
    self.apSave = apSaveArea:makeButton("Save", self, self.onApSave)
end

function AdminPanel:updateState()
    local zone = self.parentPanel.zone
    if not zone then return end
    -- Set picker to current zone area
    self.apPicker:setValue({
        x1 = zone.x1, y1 = zone.y1, z1 = zone.z1,
        x2 = zone.x2, y2 = zone.y2, z2 = zone.z2
    })
 
    -- Staff-only area picker visibility
    local staff = isStaff()
    self.apPicker:setVisible(staff)
    self.apReset:setVisible(staff)
    self.apSave:setVisible(staff)
end


function AdminPanel:onApReset()
    local zone = self.parentPanel.zone
    if not zone then return end
    self.apPicker:setValue({
        x1 = zone.x1, y1 = zone.y1, z1 = zone.z1,
        x2 = zone.x2, y2 = zone.y2, z2 = zone.z2
    })
end

function AdminPanel:onApSave()
    local zone = self.parentPanel.zone
    local player = getPlayer()
    if not (zone and player) then return end
    if not isStaff() then return end
    local v = self.apPicker:getValue()
    local bounds = { x1 = v.x1, y1 = v.y1, z1 = v.z1, x2 = v.x2, y2 = v.y2, z2 = v.z2 }

    if WSZ_System.modifyZoneBounds then
        WSZ_System:modifyZoneBounds(player, zone.id, bounds)
    else
        -- Local preview fallback
        zone.x1, zone.y1, zone.z1 = bounds.x1, bounds.y1, bounds.z1
        zone.x2, zone.y2, zone.z2 = bounds.x2, bounds.y2, bounds.z2
        if WSZ_Client and WSZ_Client.updateZone then
            WSZ_Client.updateZone(zone)
        end
    end
end

-- Panel lifecycle
function WSZ_ManageSafezone:initialise()
    ISPanel.initialise(self)

    -- Styling similar to Workplace panel
    self.backgroundColor = { r = 0.1, g = 0.1, b = 0.1, a = 0.6 }
    self.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    self.moveWithMouse = true

    local win = GravyUI.Node(self.width, self.height, self)
    local closeButtonNode = win:corner("topRight", FONT_HGT_SMALL + 3, FONT_HGT_SMALL + 3)
    win = win:pad(0, scale(5), 0, 0)

    local rowPadding = scale(5)
    local bannerArea, bodyArea = win:rows({ 0.15, 0.85 }, rowPadding)
    self.bannerArea = bannerArea

    local titleArea, subTitleArea, _ = bannerArea:rows({ FONT_HGT_LARGE, FONT_HGT_MEDIUM, bannerArea.height - FONT_HGT_LARGE - FONT_HGT_MEDIUM - rowPadding * 2 }, rowPadding)
    self.titleLabel = titleArea:makeLabel("", UIFont.Large, COLOR_WHITE, "center")
    self.subtitleLabel = subTitleArea:makeLabel("", UIFont.Medium, COLOR_WHITE, "center")

    -- TabPanel like the Workplace UI
    self.tabs = bodyArea:makeTabPanel()
    self.tabs.borderColor = { r = 0.1, g = 0.1, b = 0.1, a = 1 }
    local tabX, tabY, tabW, tabH = self.tabs.x, self.tabs.y, self.tabs.width, self.tabs.height - self.tabs.tabHeight

    -- Build tabs based on permissions
    local player = getPlayer()
    local zone = self.zone

    -- Overview tab always present
    self.infoPanel = InfoPanel:new(tabX, tabY, tabW, tabH, self)
    self.tabs:addView("Overview", self.infoPanel)

    if zone and player then
        if isOfficer(zone, player:getUsername()) or isStaff() then
            self.managePanel = ManagePanel:new(tabX, tabY, tabW, tabH, self)
            self.tabs:addView("Members", self.managePanel)
        end
        if isStaff() then
            self.adminPanel = AdminPanel:new(tabX, tabY, tabW, tabH, self)
            self.tabs:addView("Admin", self.adminPanel)
        end
    end

    self.closeButton = closeButtonNode:makeButton("X", self, self.onClose)
    
    self:updateState()
    
    -- Ensure zone area highlight is shown while window is open (admins and non-admins)
    do
        local zone = self.zone
        if zone then
            local picker = nil
            if self.adminPanel and self.adminPanel.apPicker then
                picker = self.adminPanel.apPicker
            else
                if not self.highlightPicker then
                    local overlay = GravyUI.Node(self.width, self.height, self)
                    self.highlightPicker = overlay:makeAreaPicker()
                    if self.highlightPicker.setVisible then self.highlightPicker:setVisible(false) end
                    self.highlightPicker.fullZ = false
                end
                picker = self.highlightPicker
            end
            if picker and picker.setValue then
                picker:setValue({ x1 = zone.x1, y1 = zone.y1, z1 = zone.z1, x2 = zone.x2, y2 = zone.y2, z2 = zone.z2 })
                picker.showAlways = true
                if picker.groundHighlighter then
                    picker.groundHighlighter:enableXray(false, false)
                end
                if picker._updateGroundHighlight then picker:_updateGroundHighlight() end
            end
        end
    end
end

-- With TabPanel, visibility is managed by the Tab control; keep for compatibility
function WSZ_ManageSafezone:setPanelVisibility(panelName)
    if self.infoPanel then self.infoPanel:setVisible(panelName == "info") end
    if self.managePanel then self.managePanel:setVisible(panelName == "manage") end
    if self.adminPanel then self.adminPanel:setVisible(panelName == "admin") end
end



function WSZ_ManageSafezone:onTabInfo() end
function WSZ_ManageSafezone:onTabManage() end
function WSZ_ManageSafezone:onTabAdmin() end

function WSZ_ManageSafezone:setActivePanel(which)
    self.activePanel = which
    self:updateState()
end

function WSZ_ManageSafezone:updateState()
    local zone = self.zone
    if not zone then return end

    -- Title/subtitle like Workplace panel
    self.titleLabel:setText(tostring(zone.name or "Safezone"))
    self.subtitleLabel:setText("Safezone")

    if self.infoPanel and self.infoPanel.updateState then self.infoPanel:updateState() end
    if self.managePanel and self.managePanel.updateState then self.managePanel:updateState() end
    if self.adminPanel and self.adminPanel.updateState then self.adminPanel:updateState() end

    -- Keep area highlight in sync while window is open
    do
        local picker = nil
        if self.adminPanel and self.adminPanel.apPicker then
            picker = self.adminPanel.apPicker
        else
            if not self.highlightPicker then
                local overlay = GravyUI.Node(self.width, self.height, self)
                self.highlightPicker = overlay:makeAreaPicker()
                if self.highlightPicker.setVisible then self.highlightPicker:setVisible(false) end
                self.highlightPicker.fullZ = false
            end
            picker = self.highlightPicker
        end
        if picker and picker.setValue then
            picker:setValue({ x1 = zone.x1, y1 = zone.y1, z1 = zone.z1, x2 = zone.x2, y2 = zone.y2, z2 = zone.z2 })
            picker.showAlways = true
            if picker._updateGroundHighlight then picker:_updateGroundHighlight() end
        end
    end
end

function WSZ_ManageSafezone:prerender()
    ISPanel.prerender(self)
    GravyUI.prerender(self)
    -- Optional banner draw could be added here similar to Workplace panel if you have textures
end

function WSZ_ManageSafezone:onClose()
    -- Cleanup the Admin panel's area picker to remove any highlights/markers
    if self.adminPanel and self.adminPanel.apPicker and self.adminPanel.apPicker.cleanup then
        self.adminPanel.apPicker:cleanup()
    end
    -- Cleanup hidden highlighter if present
    if self.highlightPicker and self.highlightPicker.cleanup then
        self.highlightPicker:cleanup()
    end

    self:removeFromUIManager()
    WSZ_ManageSafezone.instance = nil
end
