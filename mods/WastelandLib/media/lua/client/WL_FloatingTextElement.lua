---
--- WL_FloatingTextElement.lua
--- Floating text UI element used by WL_FloatingText
--- 05/04/2026
---

require "ISUI/ISUIElement"

local textManager = getTextManager()

WL_FloatingTextElement = ISUIElement:derive("WL_FloatingTextElement")

function WL_FloatingTextElement:new(entry)
    local o = ISUIElement:new(0, 0, 0, 0)
    setmetatable(o, self)
    self.__index = self

    o.entry = entry
    o.anchorTop = false
    o.anchorBottom = true

    o:initialise()
    o:addToUIManager()
    o:backMost()
    o:setVisible(true)

    return o
end

function WL_FloatingTextElement:getAnchorPosition()
    local entry = self.entry
    if not entry then return nil end

    if entry.worldItem then
        return entry.worldItem:getWorldPosX(), entry.worldItem:getWorldPosY(), entry.worldItem:getWorldPosZ()
    end

    return entry.x, entry.y, entry.z
end

function WL_FloatingTextElement:render()
    local entry = self.entry
    if not entry or entry.removed then
        return
    end

    if not WL_FloatingText or not WL_FloatingText.isEntryVisible(entry) then
        return
    end

    local x, y, z = self:getAnchorPosition()
    if x == nil or y == nil or z == nil then
        return
    end

    local playerIndex = entry.playerIndex or 0
    local sx = isoToScreenX(playerIndex, x, y, z)
    local sy = isoToScreenY(playerIndex, x, y, z)

    if sx < 0 or sy < 0 or sx > getPlayerScreenWidth(playerIndex) or sy > getPlayerScreenHeight(playerIndex) then
        return
    end

    local lines = entry.textLines or {}
    if #lines == 0 then
        return
    end

    local font = entry.font or UIFont.Small
    local zoom = getCore():getZoom(playerIndex)
    if zoom <= 0 then zoom = 1 end

    local lineHeight = textManager:MeasureStringY(font, "ABC")
    local width = 0

    for i = 1, #lines do
        local lineText = tostring(lines[i].text or "")
        width = math.max(width, textManager:MeasureStringX(font, lineText))
    end

    local height = lineHeight * #lines

    local yOffset = entry.yOffset or 30
    self:setX(sx - (width / 2))
    self:setY(sy - (yOffset * (1 / zoom)))
    self:setWidth(width)
    self:setHeight(height)

    for i = 1, #lines do
        local line = lines[i]
        local lineText = tostring(line.text or "")
        local lineWidth = textManager:MeasureStringX(font, lineText)
        local lineX = (width - lineWidth) / 2

        local color = line.color or entry.color or { r = 1, g = 1, b = 1, a = 1 }
        local r = color.r or 1
        local g = color.g or 1
        local b = color.b or 1
        local a = color.a or 1

        local lineY = (i - 1) * lineHeight
        self:drawText(lineText, lineX, lineY, r, g, b, a, font)
    end
end