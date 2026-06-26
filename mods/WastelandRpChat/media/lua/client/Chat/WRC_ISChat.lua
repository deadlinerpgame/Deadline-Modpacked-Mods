---@diagnostic disable: duplicate-set-field
if not isClient() then return end -- only in MP

-- TODO: Refactor this file. Its a mess.

require "Chat/ISChat"
require "Chat/WRC"
require "GroundHighlighter"

WRC = WRC or {}
WRC.ISChatOriginal = WRC.ISChatOriginal or {}

local fntSize = getTextManager():getFontFromEnum(UIFont.Small):getLineHeight()

local function estimateLineCount(text, font, innerWidth)
    if not text or text == "" then return 1 end
    if innerWidth < 1 then innerWidth = 1 end
    local tm = getTextManager()
    local spaceW = tm:MeasureStringX(font, " ")
    local total = 0
    for segment in (text .. "\n"):gmatch("([^\n]*)\n") do
        local segLines = 1
        local lineW = 0
        local pos = 1
        local segLen = #segment
        while pos <= segLen do
            local nextSpace = segment:find(" ", pos, true)
            local wordEnd = nextSpace and (nextSpace - 1) or segLen
            local word = segment:sub(pos, wordEnd)
            local wordW = tm:MeasureStringX(font, word)
            if wordW > innerWidth then
                if lineW > 0 then
                    segLines = segLines + 1
                    lineW = 0
                end
                segLines = segLines + math.floor(wordW / innerWidth)
                lineW = wordW % innerWidth
            else
                local needed = (lineW > 0 and spaceW or 0) + wordW
                if lineW + needed > innerWidth then
                    segLines = segLines + 1
                    lineW = wordW
                else
                    lineW = lineW + needed
                end
            end
            if nextSpace then
                pos = nextSpace + 1
                -- trailing-space wraps the same way: counts toward lineW
                if lineW + spaceW > innerWidth then
                    segLines = segLines + 1
                    lineW = 0
                else
                    lineW = lineW + spaceW
                end
            else
                pos = segLen + 1
            end
        end
        total = total + segLines
    end
    return math.max(1, total)
end

local function wrcInputGeom(self)
    local desired = self.textEntryLines or 1
    local inputH = self.textEntryBaseHeight + (desired - 1) * (self.textEntryLineHgt or 0)
    local inputY = self.height - 8 - self.inset - inputH
    return desired, inputH, inputY
end

-- Places the input + message panel for the current window height. Safe to run every frame
-- (including during a drag-resize): only touches input + panel, diff-guarded. The panel has
-- anchorBottom=false so window-grow doesn't stretch the chat area, which means vanilla never tracks
-- it on a drag - we must, every frame, or it freezes at a stale height and overlaps the input.
local function applyInputPlacement(self)
    if not self.textEntry or not self.textEntryBaseHeight then return end
    local desired, inputH, inputY = wrcInputGeom(self)

    if math.abs(self.textEntry.height - inputH) > 0.5 then self.textEntry:setHeight(inputH) end
    if math.abs(self.textEntry.y - inputY) > 0.5 then self.textEntry:setY(inputY) end

    local wantPanelH = inputY - self.panel:getY() - self.inset
    if wantPanelH > 0 and math.abs(self.panel:getHeight() - wantPanelH) > 0.5 then
        self.panel:setHeight(wantPanelH)
    end

    -- Below the scroll cap all lines fit, so the internal yscroll must be 0; scrollEntryToCursor
    -- owns it only at the cap.
    if desired < (self.maxInputLines or 8) then
        local jo = self.textEntry.javaObject
        if jo and jo.setYScroll then
            local okY, ys = pcall(function() return jo:getYScroll() end)
            if okY and ys and ys ~= 0 then pcall(function() jo:setYScroll(0) end) end
        end
    end
end

-- Re-pins the resize widgets + scroll button to the window bottom. Run ONLY in the burst right
-- after OUR OWN window resize, NEVER during a user drag: moving a resize widget mid-drag yanks it
-- out from under the mouse (its drag math is relative to its own position) and the resize fights.
-- The Java anchor re-pin lags a frame behind our height change, stranding the bottom widget one
-- line up (a dead click-zone); the burst nails them to the real bottom.
local function repinResizeChrome(self)
    if not self.textEntry then return end
    local _, inputH = wrcInputGeom(self)
    local rh = self:resizeWidgetHeight()
    if self.resizeWidget2 and math.abs(self.resizeWidget2.y - (self.height - rh)) > 0.5 then
        self.resizeWidget2:setY(self.height - rh)
    end
    if self.resizeWidget and math.abs(self.resizeWidget.y - (self.height - rh)) > 0.5 then
        self.resizeWidget:setY(self.height - rh)
    end
    if self.scrollToBottomButton then
        local sbY = self.height - inputH - 30
        if math.abs(self.scrollToBottomButton.y - sbY) > 0.5 then self.scrollToBottomButton:setY(sbY) end
    end
    self.textEntry:bringToTop()
end

-- Engine's UITextBox2.keepCursorVisible() early-returns for multi-line boxes
-- (UITextBox2.java), so a multi-line entry never scrolls to follow the caret.
-- We do it ourselves: keep the caret's display line inside the visible window.
local function scrollEntryToCursor(self)
    local entry = self.textEntry
    local jo = entry and entry.javaObject
    if not jo then return end
    local okL, line = pcall(function() return jo:getCursorLine() end)
    if not okL or not line then return end
    local okY, yscroll = pcall(function() return jo:getYScroll() end)
    if not okY or not yscroll then return end

    local lh = self.textEntryLineHgt
    if not lh or lh < 1 then return end
    -- The chat entry is framed (ISChat setHasFrame(true)), so getInset() == EdgeSize (5),
    -- not the unframed default of 2. Read it to be safe; fall back to 5.
    local inset = 5
    local okI, gi = pcall(function() return jo:getInset() end)
    if okI and gi and gi > 0 then inset = gi end
    -- Count of FULLY visible lines (engine adds a partial line on top of this; we keep the
    -- caret within the fully-visible range so it never sits on the clipped bottom edge).
    local visible = math.floor((entry.height - inset * 2) / lh)
    if visible < 1 then visible = 1 end

    local top = math.floor((-yscroll + inset) / lh)
    local newTop = top
    if line < top then
        newTop = line
    elseif line > top + visible - 1 then
        newTop = line - visible + 1
    end
    if newTop < 0 then newTop = 0 end
    if newTop ~= top then
        pcall(function() jo:setYScroll(-newTop * lh) end)
    end
end

WRC.ISChatOriginal.initialise = WRC.ISChatOriginal.initialise or ISChat.initialise
function ISChat:initialise()
    WRC.ISChatOriginal.initialise(self)

    -- Panel Overrides for Prod
    self.panel.render = WRC.ISTabPanel.render
    self.panel.getTabIndexAtX = WRC.ISTabPanel.getTabIndexAtX
    -- Panel Overrides for Dev
    -- self.panel.render = function (s) WRC.ISTabPanel.render(s) end
    -- self.panel.getTabIndexAtX = function (s, x, scrollX) return WRC.ISTabPanel.getTabIndexAtX(s, x, scrollX) end

    local nextTabId = 90
    local nextStreamId = #ISChat.allChatStreams+1

    WRC.FocusTabId = nextTabId
    WRC.FocusStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "Focused", command = "/focusedchat", tabID = nextTabId+1}

    nextStreamId = nextStreamId+1
    nextTabId = nextTabId+1
    WRC.PrivateTabId = nextTabId
    WRC.PrivateStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "Private", command = "/privatechat", tabID = nextTabId+1}

    nextStreamId = nextStreamId+1
    nextTabId = nextTabId+1
    WRC.RadioTabId = nextTabId
    WRC.RadioStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "Radio", command = "/radiochat", tabID = nextTabId+1}

    nextStreamId = nextStreamId+1
    nextTabId = nextTabId+1
    WRC.EventTabId = nextTabId
    WRC.EventStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "Event", command = "/eventchat", tabID = nextTabId+1}

    nextStreamId = nextStreamId+1
    nextTabId = nextTabId+1
    WRC.OocTabId = nextTabId
    WRC.OocStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "OOC", command = "/oocchat", tabID = nextTabId+1}

    nextStreamId = nextStreamId+1
    nextTabId = nextTabId+1
    WRC.StaffTabId = nextTabId
    WRC.StaffStreamId = nextStreamId
    ISChat.allChatStreams[nextStreamId] = {name = "Staff", command = "/staff", tabID = nextTabId+1}

    ISChat.allChatStreams[7].tabID = 7
    ISChat.defaultTabStream[7] = ISChat.allChatStreams[7]
end

WRC.ISChatOriginal.onTextChange = WRC.ISChatOriginal.onTextChange or ISChat.onTextChange
function ISChat:onTextChange()
    local instance = ISChat.instance
    -- Multi-line entry: UITextBox2 turns Enter into a newline. Any newline
    -- (regardless of position) submits; embedded newlines are stripped first.
    do
        local entry = instance.textEntry
        local raw = entry:getInternalText() or ""
        if raw:find("\n") or raw:find("\r") then
            entry:setText((raw:gsub("[\r\n]+", "")))
            instance:onCommandEntered()
            return
        end
    end
    if instance.currentTabID > 6 then
        WRC.ISChatOriginal.onTextChange(self)
        WRC.Indicator.onCleared()
        instance:recomputeChatInputHeight()
        return
    end

    local text = instance.textEntry:getInternalText()
    local textLen = text:len()

    local firstLetter = text:sub(1, 1)
    local firstSpace = text:find(" ")
    if firstLetter == "/" and textLen > 2 and firstSpace then
        local ending = text:sub(firstSpace , textLen)
        if ending == " /" then
            WRC.Indicator.onCleared()
            instance.textEntry:setText("/")
            instance:recomputeChatInputHeight()
            return
        end
    end

    if textLen == 0 then
        WRC.Indicator.onCleared()
        instance:recomputeChatInputHeight()
        return
    end

    local xyRange, zRange = WRC.GetRangeFromMessage(text)
    if xyRange and xyRange > 0 then
        WRC.Indicator.onTyping(xyRange, zRange)
        instance:recomputeChatInputHeight()
        return
    end

    WRC.Indicator.onCleared()
    instance:recomputeChatInputHeight()
end

WRC.ISChatOriginal.calcTabSize = WRC.ISChatOriginal.calcTabSize or ISChat.calcTabSize
function ISChat:calcTabSize()
    local tabSize = WRC.ISChatOriginal.calcTabSize(self)
    -- Make room for the typing indicator
    tabSize.height = tabSize.height - fntSize - 4
    return tabSize
end

WRC.ISChatOriginal.render = WRC.ISChatOriginal.render or ISChat.render
function ISChat:render()
    WRC.ISChatOriginal.render(self)
    if not ISChat.instance or not ISChat.instance.chatText then return end

    -- Keeps input + panel tracking the window every frame (incl. during a user drag-resize).
    applyInputPlacement(self)

    -- Resize widgets + scroll button get re-pinned only in the burst after our own resize.
    if (self.wrcPlaceTicks or 0) > 0 then
        self.wrcPlaceTicks = self.wrcPlaceTicks - 1
        repinResizeChrome(self)
    end

    -- Poll for a newline in the entry. UITextBox2 in multi-line mode does not
    -- fire onTextChange for newline-only edits, and OnKeyPressed does not fire
    -- for keys the textbox swallows. A trailing/embedded newline = submit.
    -- Run while the entry is actually being edited. NB: locking the chat sets
    -- ISChat.focused = false (ISChat:pin()) even though the text entry stays focused and
    -- editable, so gate on the entry's own focus too or scroll/cursor-follow dies when locked.
    if self.textEntry and (ISChat.focused or self.textEntry:isFocused()) then
        local raw = self.textEntry:getInternalText() or ""
        if raw:find("[\r\n]") then
            self.textEntry:setText((raw:gsub("[\r\n]+", "")))
            self:onCommandEntered()
            return
        end
        -- Remember the caret's display line as of this frame (before any keypress).
        -- onPressUp/onPressDown compare against this: the engine moves the caret line
        -- BEFORE calling them (Core.java), so a same-line value means we were already
        -- at the top/bottom boundary and should recall history instead of moving.
        local jo = self.textEntry.javaObject
        if jo then
            local ok, cl = pcall(function() return jo:getCursorLine() end)
            if ok and cl then self.wrcPrevCursorLine = cl end
            -- Keep the caret visible (engine's keepCursorVisible bails on multi-line).
            -- When the caret pos changes (typing, arrows, history recall) we scroll for a
            -- few frames - the engine re-paginates a frame late, so a single scroll would
            -- chase a stale line. Once those frames lapse we stop, leaving the mouse wheel
            -- free instead of re-pinning the scroll every frame.
            local okP, pos = pcall(function() return jo:getCursorPos() end)
            if okP and pos and pos ~= self.wrcLastCaretPos then
                self.wrcLastCaretPos = pos
                self.wrcScrollTicks = 4
            end
            if (self.wrcScrollTicks or 0) > 0 then
                self.wrcScrollTicks = self.wrcScrollTicks - 1
                scrollEntryToCursor(self)
            end
        end
    end


    -- Only show scroll to bottom button if we're not scrolled to the bottom
    if ISChat.instance.chatText then
        local chatText = ISChat.instance.chatText
        local scrolledToBottom = (chatText:getScrollHeight() <= chatText:getHeight()) or (chatText.vscroll and chatText.vscroll.pos == 1)
        if self.scrollToBottomButton:getIsVisible() == scrolledToBottom then
            self.scrollToBottomButton:setVisible(not scrolledToBottom)
        end
    end

    -- Toggle the range indicator
    if ISChat.instance.showRangeTicks > 0 then
        if self.showRangeTicks % 20 == 0 then
            if self.showRangeSwitch then
                self.groundHighlighter:setColor(0.8, 0.8, 0.8, 1.0)
            else
                self.groundHighlighter:setColor(0.2, 0.2, 0.2, 1.0)
            end
            self.showRangeSwitch = not self.showRangeSwitch
        end

        if ISChat.instance.showRangeTicks == 1 then
            self.groundHighlighter:remove()
        end
        ISChat.instance.showRangeTicks = ISChat.instance.showRangeTicks - 1
    end

    local tabID = ISChat.instance.tabs[ISChat.instance.currentTabID].tabID
    local hasNoText = ISChat.instance.textEntry:getInternalText():len() == 0

    -- Placeholders!
    if hasNoText then
        if tabID == 0 then
            WRC.Handlers.DrawGeneralPlaceholder(self)
        elseif tabID == WRC.RadioTabId then
            WRC.Handlers.DrawRadioPlaceholder(self)
        elseif tabID == WRC.FocusTabId then
            WRC.Handlers.DrawFocusPlaceholder(self)
        elseif tabID == WRC.PrivateTabId then
            -- WRC.Handlers.DrawPrivatePlaceholder(self) TODO: Implement
        end
    end

    WRC.Afk.ShowAfkOnPlayers()
    WRC.StatusIndicator.ShowStatusIndicatorOnHovered()
    WRC.InjuredStatus.ShowInjuredIndicatorOnApproach()
    WRC.StreamingStatus.ShowStreamingIndicatorOnApproach()

    if WRC.Meta.GetOverheadTypingIndicator() then
        WRC.Indicator.DrawOverheads()
    end

    WRC.Indicator.DrawTypingInChat(self)
end

WRC.ISChatOriginal.createChildren = WRC.ISChatOriginal.createChildren or ISChat.createChildren
function ISChat:createChildren()
    WRC.ISChatOriginal.createChildren(self)

    self.muteTypingButton = ISButton:new(self.gearButton:getX() - 30, 1, 20, 16, "", self, ISChat.onMuteTypingButtonClick)
    self.muteTypingButton.anchorRight = true
    self.muteTypingButton.anchorLeft = false
    self.muteTypingButton:initialise()
    self.muteTypingButton.borderColor.a = 0.0
    self.muteTypingButton.backgroundColor.a = 0.0
    self.muteTypingButton.backgroundColorMouseOver.a = 0.0
    if WRC.Indicator.muteTyping == "all" then
        self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_off.png"))
    elseif WRC.Indicator.muteTyping == "staff" then
        self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_on_staff.png"))
    else -- "default"
        self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_on.png"))
    end
    self.muteTypingButton:setUIName("toggle typing indicator")
    self:addChild(self.muteTypingButton)
    self.muteTypingButton:setVisible(true)

    self.showRangeButton = ISButton:new(self.muteTypingButton:getX() - 30, 1, 20, 16, "", self, ISChat.onShowRangeButtonClick)
    self.showRangeButton.anchorRight = true
    self.showRangeButton.anchorLeft = false
    self.showRangeButton:initialise()
    self.showRangeButton.borderColor.a = 0.0
    self.showRangeButton.backgroundColor.a = 0.0
    self.showRangeButton.backgroundColorMouseOver.a = 0.0
    self.showRangeButton:setImage(getTexture("media/ui/WRC_range.png"))
    self.showRangeButton:setUIName("toggle range indicator")
    self:addChild(self.showRangeButton)
    self.showRangeButton:setVisible(true)
    self.showRangeTicks = 0

    self.scrollToBottomButton = ISButton:new(self.width - 20, self.height - self.textEntry.height - 30, 20, 16, "", self, ISChat.onScrollToBottomClick)
    self.scrollToBottomButton.anchorRight = true
    self.scrollToBottomButton.anchorLeft = false
    self.scrollToBottomButton.anchorBottom = true
    self.scrollToBottomButton.anchorTop = false
    self.scrollToBottomButton:initialise()
    self.scrollToBottomButton.borderColor.a = 0.0
    self.scrollToBottomButton.backgroundColor.a = 0.0
    self.scrollToBottomButton.backgroundColorMouseOver.a = 0.0
    self.scrollToBottomButton:setImage(getTexture("media/ui/WRC_scrollBottom.png"))
    self.scrollToBottomButton:setUIName("scroll to bottom")
    self:addChild(self.scrollToBottomButton)
    self.scrollToBottomButton:setVisible(false)

    self.groundHighlighter = GroundHighlighter:new()
    self.groundHighlighter:setColor(0.8, 0.8, 0.8, 0.5)

    self.textEntry:setMultipleLine(true)
    self.textEntry:setMaxLines(99)
    self.textEntryBaseHeight = self.textEntry.height -- the input's height at exactly 1 line
    self.textEntryLines = 1                          -- line count currently applied to geometry
    self.textEntryLineHgt = getTextManager():getFontFromEnum(UIFont.Medium):getLineHeight()

    -- Multi-line input grows the whole window rather than resizing the message panel (resizing
    -- chatText broke scroll/pagination - commit 2b07f43c0). anchorBottom=false keeps the panel a
    -- fixed height so window-grow never stretches it; applyInputPlacement drives it instead.
    self.panel:setAnchorBottom(false)
    self.maxInputLines = 8
    self.wrcSizeDelta = 0       -- running total of px added to the window/input beyond 1 line
    self.wrcPrevCursorLine = 0  -- caret display line as of last render (see render/onPressUp)
end

function ISChat:recomputeChatInputHeight()
    if not self.textEntry or not self.textEntryBaseHeight then return end
    local rawText = self.textEntry:getInternalText() or ""
    local desired
    if rawText == "" then
        desired = 1
    else
        local innerWidth = self.textEntry.width - 10
        desired = estimateLineCount(rawText, UIFont.Medium, innerWidth)
        local jo = self.textEntry.javaObject
        if jo and jo.getCursorLine then
            local ok, cursorLine = pcall(function() return jo:getCursorLine() end)
            if ok and cursorLine and (cursorLine + 1) > desired then
                desired = cursorLine + 1
            end
        end
    end

    local maxLines = self.maxInputLines or 8
    if desired > maxLines then desired = maxLines end
    if desired < 1 then desired = 1 end

    local newTotal = (desired - 1) * self.textEntryLineHgt

    -- Resize the window only on a line-count change, applying (new total - old total) on top of the
    -- CURRENT size so a manual drag-resize is preserved; on submit the total returns to 0, removing
    -- everything we added in one shot.
    if desired ~= (self.textEntryLines or 1) then
        self.textEntryLines = desired
        local change = newTotal - (self.wrcSizeDelta or 0)
        self.wrcSizeDelta = newTotal

        local newWinH = self.height + change
        local newY = self.y - change -- grow upward / shrink downward, bottom edge stays put
        local screenH = getCore():getScreenHeight()
        if newY < 0 then newY = 0 end
        if newY + newWinH > screenH then newY = screenH - newWinH end

        self:setHeight(newWinH)
        self:setY(newY)
    end

    -- The burst (wrcPlaceTicks) re-applies for a few frames because the Java anchor re-pin lands a
    -- frame after our resize.
    applyInputPlacement(self)
    repinResizeChrome(self)
    self.wrcPlaceTicks = 3
end

WRC.ISChatOriginal.onGearButtonClick = WRC.ISChatOriginal.onGearButtonClick or ISChat.onGearButtonClick
function ISChat:onGearButtonClick()
    WRC.ISChatOriginal.onGearButtonClick(self)
    local context = getPlayerContextMenu(0)
    if context then
        local myPlayer = getPlayer()
        local players = getOnlinePlayers()
        WRC.Meta.CreateActionsContext(context, myPlayer, players)
        WRC.Meta.CreateCharacterContext(context, myPlayer)
        WRC.Meta.CreateChatSettingsContext(context)
        if WRC.Override(true) then
            WRC.Meta.CreateAdminContext(context, myPlayer, players)
        end
    end
end

WRC.ISChatOriginal.onTabAdded = WRC.ISChatOriginal.onTabAdded or ISChat.onTabAdded
function ISChat.onTabAdded(title, tabID)
    if tabID == 0 then
        WRC.ISChatOriginal.onTabAdded(title, tabID)
        WRC.ISChatOriginal.onTabAdded("Focused", WRC.FocusTabId)
        WRC.ISChatOriginal.onTabAdded("Private", WRC.PrivateTabId)
        WRC.ISChatOriginal.onTabAdded("Radio", WRC.RadioTabId)
        WRC.ISChatOriginal.onTabAdded("Event", WRC.EventTabId)
        WRC.ISChatOriginal.onTabAdded("OOC", WRC.OocTabId)
        WRC.ISChatOriginal.onTabAdded("Staff", WRC.StaffTabId)
    elseif tabID == 1 then
        WRC.ISChatOriginal.onTabAdded(title, 6)
    else
        WRC.ISChatOriginal.onTabAdded(title, tabID)
    end
end

WRC.ISChatOriginal.onTabRemoved = WRC.ISChatOriginal.onTabRemoved or ISChat.onTabRemoved
function ISChat.onTabRemoved(tabTitle, tabID)
    if tabID == 0 then
        WRC.ISChatOriginal.onTabRemoved(tabTitle, tabID)
        WRC.ISChatOriginal.onTabRemoved("Focus", WRC.FocusTabId)
        WRC.ISChatOriginal.onTabRemoved("Private", WRC.PrivateTabId)
        WRC.ISChatOriginal.onTabRemoved("Radio", WRC.RadioTabId)
        WRC.ISChatOriginal.onTabRemoved("Event", WRC.EventTabId)
        WRC.ISChatOriginal.onTabRemoved("OOC", WRC.OocTabId)
        WRC.ISChatOriginal.onTabAdded("Staff", WRC.StaffTabId)
    elseif tabID == 1 then
        WRC.ISChatOriginal.onTabRemoved(tabTitle, 6)
    else
        WRC.ISChatOriginal.onTabRemoved(tabTitle, tabID)
    end
end

-- Engine moves the caret one display line BEFORE calling onPressUp/onPressDown
-- (Core.java). So compare the post-move line against the line we recorded last
-- render (wrcPrevCursorLine): if it changed, the keypress just moved the caret
-- between lines - leave it alone. If it's unchanged, the caret couldn't move, i.e.
-- we're at the top (Up) / bottom (Down) boundary, so do history recall.
local function caretMoved(instance)
    local jo = instance.textEntry and instance.textEntry.javaObject
    local cur = instance.wrcPrevCursorLine or 0
    if jo then
        local ok, cl = pcall(function() return jo:getCursorLine() end)
        if ok and cl then cur = cl end
    end
    local prev = instance.wrcPrevCursorLine or 0
    instance.wrcPrevCursorLine = cur
    return cur ~= prev
end

-- Records the gap since the previous arrow press (any direction) and updates the marker.
-- Used to debounce ONLY the moment we'd first enter history: when Up is held or tapped fast
-- and the caret runs into the top edge, that same burst shouldn't snap straight into history.
-- A held key autorepeats far faster than this gap, so it just stops at the edge; once a quiet
-- gap passes, a fresh press recalls. Walking within history (Up/Down) is not gated.
local HISTORY_DEBOUNCE_MS = 150
local function arrowGapMs(instance)
    local now = getTimestampMs()
    local sinceLast = now - (instance.wrcLastArrowMs or 0)
    instance.wrcLastArrowMs = now
    return sinceLast
end

WRC.ISChatOriginal.onPressUp = WRC.ISChatOriginal.onPressUp or ISChat.onPressUp
function ISChat:onPressUp()
    local instance = ISChat.instance
    local moved = caretMoved(instance)
    local gap = arrowGapMs(instance)
    if moved then return end -- caret moved up a line; not at the top boundary

    local chatText = instance.chatText
    if not chatText then return end
    -- Entering history from "composing": debounce so a line-nav burst that hits the top edge
    -- doesn't immediately recall, then stash what we were typing so Down restores it.
    if (chatText.logIndex or 0) <= 0 then
        if gap < HISTORY_DEBOUNCE_MS then return end
        instance.wrcComposeStash = instance.textEntry:getInternalText() or ""
    end
    WRC.ISChatOriginal.onPressUp(self)
    instance:recomputeChatInputHeight()
end

WRC.ISChatOriginal.onPressDown = WRC.ISChatOriginal.onPressDown or ISChat.onPressDown
function ISChat:onPressDown()
    local instance = ISChat.instance
    local moved = caretMoved(instance)
    arrowGapMs(instance) -- keep the arrow-press marker current; Down never enters history
    if moved then return end -- caret moved down a line; not at the bottom boundary

    local chatText = instance.chatText
    if not chatText or (chatText.logIndex or 0) <= 0 then return end -- not in history: nothing to do
    if chatText.logIndex == 1 then
        -- Stepping back out of history to "composing": restore stashed text instead of blanking.
        chatText.logIndex = 0
        instance.textEntry:setText(instance.wrcComposeStash or "")
        instance.wrcComposeStash = nil
        instance:recomputeChatInputHeight()
        return
    end
    WRC.ISChatOriginal.onPressDown(self)
    instance:recomputeChatInputHeight()
end

function ISChat:unfocus()
    self.textEntry:unfocus()
    if ISChat.focused then
        self.fade:reset()
    end
    ISChat.focused = false
    self.textEntry:setEditable(false)
    WRC.Indicator.onCleared()
    self:recomputeChatInputHeight()
end

function ISChat:focus()
    self:setVisible(true)
    ISChat.focused = true
    self.wrcPrevCursorLine = 0
    self.textEntry:setEditable(true)
    self.textEntry:focus()
    self.textEntry:ignoreFirstInput()
    self.fade:reset()
    self.fade:update()
    if ISChat.instance.currentTabID == 5 then
        self.textEntry:setText(WRC.Meta.IsSaveLastChatEnabled() and WRC.Meta.LastFocus or "/event ")
    elseif ISChat.instance.currentTabID == 6 then
        self.textEntry:setText(WRC.Meta.IsSaveLastChatEnabled() and WRC.Meta.LastOoc or "/ooc ")
    elseif ISChat.instance.currentTabID < 8 and self.textEntry:getText() == "" then
        self.textEntry:setText(WRC.Meta.IsSaveLastChatEnabled() and WRC.Meta.LastChat or "")
    end
end

WRC.ISChatOriginal.onCommandEntered = WRC.ISChatOriginal.onCommandEntered or ISChat.onCommandEntered
function ISChat:onCommandEntered()
    local text = ISChat.instance.textEntry:getInternalText()

    ISChat.instance.wrcComposeStash = nil -- message sent: drop any stashed in-progress text
    WRC.Indicator.onCleared(true)
    local currentTabId = ISChat.instance.tabs[ISChat.instance.currentTabID].tabID
    if currentTabId ~= WRC.PrivateTabId then
        WRC.Indicator.doLog(text)
    end

    if WRC.Handlers.SpecialCommand(text) or WRC.Handlers.CommandEntered(text) or WRC.Handlers.IsOutdated(text) then
        ISChat.instance:logChatCommand(text)
        ISChat.instance:unfocus()
        ISChat.instance.textEntry:setText("")
        ISChat.instance:recomputeChatInputHeight()
        doKeyPress(false)
        ISChat.instance.timerTextEntry = 20
        return
    end

    WRC.ISChatOriginal.onCommandEntered(self)
    ISChat.instance.textEntry:setText("")
    ISChat.instance:recomputeChatInputHeight()
end

function ISChat:onMuteTypingButtonClick()
    local isStaff = WL_Utils.isStaff(getPlayer())
    
    if isStaff then
        -- Staff can cycle through all 3 states: default -> staff -> all -> default
        if WRC.Indicator.muteTyping == "default" then
            WRC.Indicator.muteTyping = "staff"
            self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_on_staff.png"))
        elseif WRC.Indicator.muteTyping == "staff" then
            WRC.Indicator.muteTyping = "all"
            self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_off.png"))
        else -- "all"
            WRC.Indicator.muteTyping = "default"
            self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_on.png"))
        end
    else
        -- Non-staff can only toggle between default and all
        if WRC.Indicator.muteTyping == "default" then
            WRC.Indicator.muteTyping = "all"
            self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_off.png"))
        else
            WRC.Indicator.muteTyping = "default"
            self.muteTypingButton:setImage(getTexture("media/ui/WRC_typing_on.png"))
        end
    end
end

function ISChat:onShowRangeButtonClick()
    if self.showRangeTicks > 0 then
        self.showRangeTicks = 1
    end

    local context = ISContextMenu.get(0, self:getAbsoluteX() + self:getWidth() / 2, self:getAbsoluteY() + self.showRangeButton:getY())
    if not context then return end

    for chatType, data in pairs(WRC.ChatTypes) do
        context:addOption(chatType, ISChat.instance, ISChat.instance.showMessageRange, data.xyRange)
    end
end

function ISChat:onScrollToBottomClick()
    if ISChat.instance.chatText then
        ISChat.instance.chatText:setYScroll(-10000)
    end
end

function ISChat:showMessageRange(range)
    local p = getPlayer()
    local x = p:getX()
    local y = p:getY()
    local z = p:getZ()
    self.lastRange = range
    self.showRangeTicks = 100
    self.showRangeSwitch = false
    self.groundHighlighter:highlightCircle(x, y, range + .99, z)
end

WRC.ISChatOriginal.addLineInChat = WRC.ISChatOriginal.addLineInChat or ISChat.addLineInChat
function ISChat.addLineInChat(chatMessage, tabID)
    if WRC.Handlers.AddLineInChat(chatMessage, tabID) then
        return
    end

    if tabID == 1 then
        tabID = 6 -- Admin Chat
    end

    WRC.ISChatOriginal.addLineInChat(chatMessage, tabID)
end

-- We have to override this to stop the focusOnTab issue
function ISChat:onActivateView()
    if self.tabCnt > 1 then
        self.chatText = self.panel.activeView.view
    end
    for i,blinkedTab in ipairs(self.panel.blinkTabs) do
        if self.chatText.tabTitle and self.chatText.tabTitle == blinkedTab then
            table.remove(self.panel.blinkTabs, i)
            break
        end
    end
    for i,tab in ipairs(self.tabs) do
        if tab.tabTitle == self.chatText.tabTitle then
            self.currentTabID = i
            break
        end
    end
    if not self.chatText.tabTitle then
        self.currentTabID = 0
        return
    end
    if self.chatText.tabID == WRC.FocusTabId
    or self.chatText.tabID == WRC.RadioTabId
    or self.chatText.tabID == WRC.OocTabId
    or self.chatText.tabID == WRC.EventTabId
    or self.chatText.tabID == WRC.PrivateTabId
    or self.chatText.tabID == WRC.StaffTabId then
        focusOnTab(0)
    elseif self.chatText.tabID == 6 then
        focusOnTab(1)
    else
        focusOnTab(self.chatText.tabID)
    end
end

-- We have to override this entire thing to handle tab complete
WRC.ISChatOriginal.onSwitchStream = WRC.ISChatOriginal.onSwitchStream or ISChat.onSwitchStream
function ISChat.onSwitchStream()
    local tabId = ISChat.instance.currentTabID
    if tabId > 6 then
        WRC.ISChatOriginal.onSwitchStream()
        return
    end

    if not ISChat.focused then return end

    local t = ISChat.instance.textEntry
    ---@type string
    local internalText = t:getInternalText()
    local parts = WRC.SplitString(internalText)
    local possibleCommands = {}
    for command, data in pairs(WRC.SpecialCommands) do
        if not data.adminOnly or WRC.Override() then
            table.insert(possibleCommands, command)
        end
    end
    if #parts == 0 then return end

    if #parts == 1 and internalText:sub(internalText:len(), internalText:len()) ~= " " then
        local complete = WRC.TabListHandler(possibleCommands, parts[1])
        if complete then
            t:setText(complete)
            return
        end
    end

    if not WRC.SpecialCommands[parts[1]] then return end
    local cnt = #parts
    local text = ""
    if internalText:sub(internalText:len(), internalText:len()) == " " then
        cnt = cnt + 1
    else
        text = parts[cnt]
    end
    local tabHandlers = WRC.SpecialCommands[parts[1]].tabHandlers
    if cnt - 1 > #tabHandlers then
        return
    end
    local handler =  tabHandlers[cnt - 1]
    if not handler or handler == "" then
        return
    end
    local complete = WRC.TabHandlers[handler](text)
    if not complete then
        return
    end
    local newText = ""
    for i=1,cnt-1 do
        if parts[i]:find(" ") then
            newText = newText .. '"' .. parts[i] .. '" '
        else
            newText = newText .. parts[i] .. " "
        end
    end
    if complete:find(" ") then
        newText = newText .. '"' .. complete .. '"'
    else
        newText = newText .. complete
    end
    t:setText(newText)
end


WRC.ISTabPanel = {}
-- An alternative panel render which doesn't blink tabs, but changes the text to red instead
function WRC.ISTabPanel:render()
    local showPrivate = WRC.Meta.HasPrivate(true)
    local showFocused = WRC.Meta.HasFocus()
    local showRadio = WRU_Utils.AreAnyRadiosOn(getPlayer())
    local showStaff = WL_Utils.isStaff(getPlayer())
    local showEvent = WRC.Meta.HasEvent()

    if not showStaff and self.activeView.name == "Staff" then
        for i,v in ipairs(self.viewList) do
            if v.name == "Staff" then
                local next = self.viewList[i % #self.viewList + 1].name
                self:activateView(next)
                break
            end
        end
    end

    if not showPrivate and self.activeView.name == "Private" then
        for i,v in ipairs(self.viewList) do
            if v.name == "Private" then
                local next = self.viewList[i % #self.viewList + 1].name
                self:activateView(next)
                break
            end
        end
    end

    if not showFocused and self.activeView.name == "Focused" then
        for i,v in ipairs(self.viewList) do
            if v.name == "Focused" then
                local next = self.viewList[i % #self.viewList + 1].name
                self:activateView(next)
                break
            end
        end
    end

    if not showRadio and self.activeView.name == "Radio" then
        for i,v in ipairs(self.viewList) do
            if v.name == "Radio" then
                local next = self.viewList[i % #self.viewList + 1].name
                self:activateView(next)
                break
            end
        end
    end

    if not showEvent and self.activeView.name == "Event" then
        for i,v in ipairs(self.viewList) do
            if v.name == "Event" then
                local next = self.viewList[i % #self.viewList + 1].name
                self:activateView(next)
                break
            end
        end
    end

	local newViewList = {}
	local tabDragSelected = -1
	if self.draggingTab and not self.isDragging and ISTabPanel.xMouse > -1 and ISTabPanel.xMouse ~= self:getMouseX() then -- do we move the mouse since we have let the left button down ?
		self.isDragging = self.allowDraggingTabs
	end
	local tabWidth = self.maxLength
	local inset = 1 -- assumes a 1-pixel window border on the left to avoid
	local gap = 1 -- gap between tabs
	if self.isDragging and not ISTabPanel.mouseOut then
		-- we fetch all our view to remove the tab of the view we're dragging
		for i,viewObject in ipairs(self.viewList) do
			if i ~= (self.draggingTab + 1) then
				table.insert(newViewList, viewObject)
			else
				ISTabPanel.viewDragging = viewObject
			end
		end
		-- in wich tab slot are we dragging our tab
		tabDragSelected = self:getTabIndexAtX(self:getMouseX()) - 1
		tabDragSelected = math.min(#self.viewList - 1, math.max(tabDragSelected, 0))
		-- we draw a white rectangle to show where our tab is going to be
		self:drawRectBorder(inset + (tabDragSelected * (tabWidth + gap)), 0, tabWidth, self.tabHeight - 1, 1,1,1,1)
	else -- no dragging, we display all our tabs
		newViewList = self.viewList
	end
	-- our principal rect, wich display our different view
	self:drawRect(0, self.tabHeight, self.width, self.height - self.tabHeight, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b)
	self:drawRectBorder(0, self.tabHeight, self.width, self.height - self.tabHeight, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b)
	local x = inset
	if self.centerTabs and (self:getWidth() >= self:getWidthOfAllTabs()) then
		x = (self:getWidth() - self:getWidthOfAllTabs()) / 2
	else
		x = x + self.scrollX
	end
	local widthOfAllTabs = self:getWidthOfAllTabs()
	local overflowLeft = self.scrollX < 0
	local overflowRight = x + widthOfAllTabs > self.width
    self.blinkAlphaDirection = self.blinkAlphaDirection or 1
    self.blinkAlpha = (self.blinkAlpha or 0) + (self.blinkAlphaDirection * (UIManager.getMillisSinceLastRender() / 500))
    if self.blinkAlpha >= 1 then
        self.blinkAlpha = 1
        self.blinkAlphaDirection = -1
    elseif self.blinkAlpha <= 0 then
        self.blinkAlpha = 0
        self.blinkAlphaDirection = 1
    end
    local unreadTextColor, unreadBackgroundColor, unreadBlinking = WRC.Meta.GetUnreadTabOptions()
	if widthOfAllTabs > self.width then
		self:setStencilRect(0, 0, self.width, self.tabHeight)
	end
	for i,viewObject in ipairs(newViewList) do
        if  (showFocused or viewObject.name ~= "Focused")
        and (showRadio or viewObject.name ~= "Radio")
        and (showPrivate or viewObject.name ~= "Private")
        and (showStaff or viewObject.name ~= "Staff")
        and (showEvent or viewObject.name ~= "Event")
        then
            tabWidth = self.equalTabWidth and self.maxLength or viewObject.tabWidth
            -- if we drag a tab over an existing one, we move the other
            if tabDragSelected ~= -1 and i == (tabDragSelected + 1) then
                x = x + tabWidth + gap
            end
            self.shouldBlink = self.blinkTab
            if self.blinkTabs then
                for j,tab in ipairs(self.blinkTabs) do
                    if tab and tab == viewObject.name then
                        self.shouldBlink = true
                    end
                end
            end
            -- if this tab is the active one, we make the tab btn lighter
            if viewObject.name == self.activeView.name and not self.isDragging and not ISTabPanel.mouseOut then
                self:drawTextureScaled(ISTabPanel.tabSelected, x, 0, tabWidth, self.tabHeight - 1, self.tabTransparency,1,1,1)
                self.shouldBlink = false
            else
                self:drawTextureScaled(ISTabPanel.tabUnSelected, x, 0, tabWidth, self.tabHeight - 1, self.tabTransparency,1,1,1)
                if self:getMouseY() >= 0 and self:getMouseY() < self.tabHeight and self:isMouseOver() and self:getTabIndexAtX(self:getMouseX()) == i then
                    viewObject.fade:setFadeIn(true)
                else
                    viewObject.fade:setFadeIn(false)
                end
                viewObject.fade:update()
                self:drawTextureScaled(ISTabPanel.tabSelected, x, 0, tabWidth, self.tabHeight - 1, 0.2 * viewObject.fade:fraction(),1,1,1)
            end

            if self.shouldBlink then
                self:drawTextureScaled(ISTabPanel.tabSelected, x, 0, tabWidth, self.tabHeight - 1, self.tabTransparency,1,1,1)
                self:drawRect(x, 0,
                              tabWidth, self.tabHeight - 1,
                              (unreadBlinking and self.blinkAlpha or (0.5 * self.tabTransparency)) * 0.8,
                              unreadBackgroundColor.r, unreadBackgroundColor.g, unreadBackgroundColor.b)

                self:drawTextCentre(viewObject.name, x + (tabWidth / 2), 3, unreadTextColor.r, unreadTextColor.g, unreadTextColor.b, self.textTransparency, UIFont.Small)
            else
                self:drawTextCentre(viewObject.name, x + (tabWidth / 2), 3, 1, 1, 1, self.textTransparency, UIFont.Small)
            end
            x = x + tabWidth + gap
        end
	end
	local butPadX = 3
	if overflowLeft then
		local tex = getTexture("media/ui/ArrowLeft.png")
		local butWid = tex:getWidthOrig() + butPadX * 2
		self:drawRect(inset, 0, butWid, self.tabHeight, 1, 0, 0, 0)
		self:drawRectBorder(inset, 0, butWid, self.tabHeight, 1, 1, 1, 1)
		self:drawTexture(tex, inset + butPadX, (self.tabHeight - tex:getHeight()) / 2, 1, 1, 1, 1)
	end
	if overflowRight then
		local tex = getTexture("media/ui/ArrowRight.png")
		local butWid = tex:getWidthOrig() + butPadX * 2
		self:drawRect(self.width - inset - butWid, 0, butWid, self.tabHeight, 1, 0, 0, 0)
		self:drawRectBorder(self.width - inset - butWid, 0, butWid, self.tabHeight, 1, 1, 1, 1)
		self:drawTexture(tex, self.width - butWid + butPadX, (self.tabHeight - tex:getHeight()) / 2, 1, 1, 1, 1)
	end
	if widthOfAllTabs > self.width then
		self:clearStencilRect()
	end
	-- we draw a ghost of our tab we currently dragging
	if self.draggingTab and self.isDragging and not ISTabPanel.mouseOut then
		if self.draggingTab > 0 then
			self:drawTextureScaled(ISTabPanel.tabSelected, inset + (self.draggingTab * (tabWidth + gap)) + (self:getMouseX() - ISTabPanel.xMouse), 0, tabWidth, self.tabHeight - 1, 0.8,1,1,1)
			self:drawTextCentre(ISTabPanel.viewDragging.name, inset + (self.draggingTab * (tabWidth + gap)) + (self:getMouseX() - ISTabPanel.xMouse) + (tabWidth / 2), 3, 1, 1, 1, 1, UIFont.Normal)
		else
			self:drawTextureScaled(ISTabPanel.tabSelected, inset + (self:getMouseX() - ISTabPanel.xMouse), 0, tabWidth, self.tabHeight - 1, 0.8,1,1,1)
			self:drawTextCentre(ISTabPanel.viewDragging.name, inset + (self:getMouseX() - ISTabPanel.xMouse) + (tabWidth / 2), 3, 1, 1, 1, 1, UIFont.Normal)
		end
    end
end

function WRC.ISTabPanel:getTabIndexAtX(x, scrollX)
	local inset = 1
	local gap = 1
	local left = inset
	if self.centerTabs and (self:getWidth() >= self:getWidthOfAllTabs()) then
		left = (self:getWidth() - self:getWidthOfAllTabs()) / 2
	else
		left = left + (scrollX or self.scrollX)
	end

    local showFocused = WRC.Meta.HasFocus()
    local showRadio = WRU_Utils.AreAnyRadiosOn(getPlayer())
    local showPrivate = WRC.Meta.HasPrivate(true)
    local showStaff = WL_Utils.isStaff(getPlayer())
    local showEvent = WRC.Meta.HasEvent()
	for index,viewObject in ipairs(self.viewList) do
        if  (showFocused or viewObject.name ~= "Focused")
        and (showRadio or viewObject.name ~= "Radio")
        and (showPrivate or viewObject.name ~= "Private")
        and (showStaff or viewObject.name ~= "Staff")
        and (showEvent or viewObject.name ~= "Event")
        then
            local tabWidth = self.equalTabWidth and self.maxLength or viewObject.tabWidth
            if x >= left and x < left + tabWidth + gap then
                return index
            end
            left = left + tabWidth + gap
        end
	end
	return -1
end

function WRC.MakeShowDialogPrompt(message, callback, prefill)
    return function()
        local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12

        local width = 200 * scale
        local height = 130 * scale
        local x = (getCore():getScreenWidth() / 2) - (width / 2)
        local y = (getCore():getScreenHeight() / 2) - (height / 2)
        local modal = ISTextBox:new(x, y, width, height, message, "", nil, function (_, button)
            if callback and button.internal == "OK" then
                callback(button.parent.entry:getText())
            end
        end, nil)
        modal:initialise()
        modal:addToUIManager()
        if prefill then
            modal.entry:setText(prefill)
        end
        return modal
    end
end
local function getColors(numColors, numBrights)
    local colors = {}
    for bright=0,(numBrights-1) * 2,1 do
        table.insert(colors, {r=bright/((numBrights-1) * 2), g=bright/((numBrights-1) * 2), b=bright/((numBrights-1) * 2), a=1})
    end
    for hue=0,numColors-2,1 do
        for bright=1,numBrights,1 do
            local color = Color.HSBtoRGB(hue/(numColors-1), 1.0, bright/numBrights)
            table.insert(colors, {r=color:getRedFloat(), g=color:getGreenFloat(), b=color:getBlueFloat(), a=1})
        end
        for sat=0,numBrights-2,1 do
            local color = Color.HSBtoRGB(hue/(numColors-1), 1.0 - sat/numBrights, 1.0)
            table.insert(colors, {r=color:getRedFloat(), g=color:getGreenFloat(), b=color:getBlueFloat(), a=1})
        end
    end
    return colors
end
function WRC.MakeColorDialogPrompt(message, callback)
    return function()
        local modal = WRC.MakeShowDialogPrompt(message, callback)()
        modal.colorPicker.buttonSize = 14
        modal.colorPicker:setColors(getColors(18, 10), 19, 18)
        modal:enableColorPicker()
        modal.colorBtn.onclick = function (self, btn)
            local x = (getCore():getScreenWidth() / 2) - (self.colorPicker.width / 2)
            local y = (getCore():getScreenHeight() / 2) - (self.colorPicker.height / 2)
            self.colorPicker:setX(x)
            self.colorPicker:setY(y)
            self.colorPicker:setVisible(true)
            self.colorPicker:bringToTop()
            self.colorPicker.pickedFunc = modal.onPickedColor
        end
        modal.onPickedColor = function(self, color)
            self.currentColor = ColorInfo.new(color.r, color.g, color.b,1)
            self.colorBtn.backgroundColor = {r = color.r, g = color.g, b = color.b, a = 1}
            self.colorPicker:setVisible(false)
            local r = math.floor(color.r * 255)
            local g = math.floor(color.g * 255)
            local b = math.floor(color.b * 255)
            self.entry:setText(r .. "," .. g .. "," .. b)
        end
        modal.entry.onTextChange = function ()
            local r,g,b = modal.entry.javaObject:getInternalText():match("(%d+),(%d+),(%d+)")
            if r and g and b then
                modal.currentColor = ColorInfo.new(r/255, g/255, b/255,1)
                modal.colorBtn.backgroundColor = {r = r/255, g = g/255, b = b/255, a = 1}
            end
        end
        return modal
    end
end

