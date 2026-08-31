---
--- WIN_NewspaperTooltip.lua
--- 2026-07-19
---

require "ISUI/ISToolTipInv"
require "WIN_NewspaperData"

WIN_NewspaperTooltip = WIN_NewspaperTooltip or {}

local TOOLTIP_PADDING = 5
local PREVIEW_MARGIN_TOP = 4
local FIELD_MARGIN_TOP = 4
local ARTICLE_PREVIEW_MAX_LENGTH = 120
local ISSUE_DATE_TEXT_COLOR = { r = 0.82, g = 0.68, b = 0.50 }
local HEADLINE_TEXT_COLOR = { r = 0.95, g = 0.60, b = 0.30 }
local ARTICLE_PREVIEW_COLOR = { r = 0.94, g = 0.78, b = 0.56 }
local MONTH_NUMBERS = {
    January = 1,
    February = 2,
    March = 3,
    April = 4,
    May = 5,
    June = 6,
    July = 7,
    August = 8,
    September = 9,
    October = 10,
    November = 11,
    December = 12,
}
local DAYS_BEFORE_MONTH = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 }
local DAYS_IN_MONTH = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

local function normalizeInlineText(text)
    local normalizedText = string.gsub(text or "", "\r\n", " ")
    normalizedText = string.gsub(normalizedText, "[\r\n]", " ")
    normalizedText = string.gsub(normalizedText, "%s+", " ")
    return normalizedText
end

local function truncateArticlePreview(body)
    if string.len(body) <= ARTICLE_PREVIEW_MAX_LENGTH then
        return body
    end

    local preview = string.sub(body, 1, ARTICLE_PREVIEW_MAX_LENGTH)
    local lastSpace = string.match(preview, "^.*()%s")
    if lastSpace then
        preview = string.sub(preview, 1, lastSpace - 1)
    end
    return preview .. "..."
end

local function isLeapYear(year)
    return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function isValidDate(year, month, day)
    if not year or not month or not day or year < 1 or month < 1 or month > 12 or day < 1 then
        return false
    end

    local maximumDay = DAYS_IN_MONTH[month]
    if month == 2 and isLeapYear(year) then
        maximumDay = maximumDay + 1
    end
    return day <= maximumDay
end

local function getDateOrdinal(year, month, day)
    local previousYear = year - 1
    local ordinal = previousYear * 365
        + math.floor(previousYear / 4)
        - math.floor(previousYear / 100)
        + math.floor(previousYear / 400)
        + DAYS_BEFORE_MONTH[month]
        + day
    if month > 2 and isLeapYear(year) then
        ordinal = ordinal + 1
    end
    return ordinal
end

local function parseIssueDate(issueDate)
    local normalizedDate = normalizeInlineText(issueDate)
    local yearText, monthText, dayText = string.match(normalizedDate, "^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
    if yearText then
        return tonumber(yearText), tonumber(monthText), tonumber(dayText)
    end

    local monthName
    monthName, dayText, yearText = string.match(normalizedDate, "^(%a+)%s+(%d+),%s+(%d+)$")
    return tonumber(yearText), MONTH_NUMBERS[monthName], tonumber(dayText)
end

local function getIssueAgeText(year, month, day)
    local gameTime = getGameTime()
    local currentYear = gameTime:getYear()
    local currentMonth = gameTime:getMonth() + 1
    local currentDay = gameTime:getDay() + 1
    local daysAgo = getDateOrdinal(currentYear, currentMonth, currentDay) - getDateOrdinal(year, month, day)

    if daysAgo == 0 then
        return "today"
    end
    if daysAgo == 1 then
        return "1 day ago"
    end
    if daysAgo > 1 then
        return tostring(daysAgo) .. " days ago"
    end
    if daysAgo == -1 then
        return "in 1 day"
    end
    return "in " .. tostring(-daysAgo) .. " days"
end

local function getIssueDateText(issueDate)
    local normalizedDate = normalizeInlineText(issueDate)
    if normalizedDate == "" then
        return ""
    end

    local year, month, day = parseIssueDate(normalizedDate)
    if not isValidDate(year, month, day) then
        return normalizedDate
    end

    local formattedDate = string.format("%04d-%02d-%02d", year, month, day)
    return formattedDate .. " (" .. getIssueAgeText(year, month, day) .. ")"
end

local function getTooltipText(newspaperItem)
    local newspaperData = WIN_NewspaperData.loadFromItem(newspaperItem)
    local headline, body = WIN_NewspaperData.getFirstArticle(newspaperData)
    headline = normalizeInlineText(headline)
    body = normalizeInlineText(body)

    if body == "" or WIN_NewspaperData.isDefaultArticleBody(body) then
        body = ""
    else
        body = truncateArticlePreview(body)
    end
    return getIssueDateText(newspaperData.issueDate), headline, body
end

local function wrapText(textManager, font, text, maxWidth)
    local lines = {}
    local line = ""

    for word in string.gmatch(text, "%S+") do
        local candidate = line == "" and word or line .. " " .. word
        if line == "" or textManager:MeasureStringX(font, candidate) <= maxWidth then
            line = candidate
        else
            lines[#lines + 1] = line
            line = word
        end
    end

    if line ~= "" then
        lines[#lines + 1] = line
    end
    return lines
end

local function canRenderPanelBelow(tooltipInv, offsetY, extraHeight)
    local panelBottom = offsetY + extraHeight + 1
    local absoluteBottom = tooltipInv:getAbsoluteY() + panelBottom
    return absoluteBottom <= getCore():getScreenHeight()
end

function WIN_NewspaperTooltip.renderTooltipPanel(tooltipInv)
    if not tooltipInv.item
        or not tooltipInv.tooltip
        or not WIN_NewspaperData.isNewspaperIssue(tooltipInv.item) then
        return
    end

    local issueDateText, headline, articlePreview = getTooltipText(tooltipInv.item)
    if issueDateText == "" and headline == "" then
        return
    end

    local font = tooltipInv.tooltip:getFont()
    local textManager = getTextManager()
    local lineHeight = textManager:MeasureStringY(font, "X")
    local maxTextWidth = math.max(10, tooltipInv.width - TOOLTIP_PADDING * 2)
    local issueDateLines = wrapText(textManager, font, issueDateText, maxTextWidth)
    local headlineLines = wrapText(textManager, font, headline, maxTextWidth)
    local previewLines = wrapText(textManager, font, articlePreview, maxTextWidth)
    local headlineMargin = #issueDateLines > 0 and #headlineLines > 0 and FIELD_MARGIN_TOP or 0
    local previewMargin = (#issueDateLines > 0 or #headlineLines > 0) and #previewLines > 0 and PREVIEW_MARGIN_TOP or 0
    local mainContentHeight = TOOLTIP_PADDING * 2
        + lineHeight * (#issueDateLines + #headlineLines)
        + headlineMargin
    local previewHeight = 0
    if #previewLines > 0 then
        previewHeight = previewMargin + lineHeight * #previewLines
    end
    local extraHeight = mainContentHeight + previewHeight
    local offsetY = tooltipInv.tooltip:getHeight() - 1

    if not canRenderPanelBelow(tooltipInv, offsetY, extraHeight) then
        previewLines = {}
        extraHeight = mainContentHeight
        if not canRenderPanelBelow(tooltipInv, offsetY, extraHeight) then
            return
        end
    end

    tooltipInv:drawRect(
        0,
        offsetY,
        tooltipInv.width,
        extraHeight,
        tooltipInv.backgroundColor.a,
        tooltipInv.backgroundColor.r,
        tooltipInv.backgroundColor.g,
        tooltipInv.backgroundColor.b
    )
    tooltipInv:drawRectBorder(
        0,
        offsetY,
        tooltipInv.width,
        extraHeight,
        tooltipInv.borderColor.a,
        tooltipInv.borderColor.r,
        tooltipInv.borderColor.g,
        tooltipInv.borderColor.b
    )

    local y = offsetY + TOOLTIP_PADDING
    for i = 1, #issueDateLines do
        tooltipInv.tooltip:DrawText(
            font,
            issueDateLines[i],
            TOOLTIP_PADDING,
            y,
            ISSUE_DATE_TEXT_COLOR.r,
            ISSUE_DATE_TEXT_COLOR.g,
            ISSUE_DATE_TEXT_COLOR.b,
            1.0
        )
        y = y + lineHeight
    end

    if #issueDateLines > 0 and #headlineLines > 0 then
        y = y + FIELD_MARGIN_TOP
    end
    for i = 1, #headlineLines do
        tooltipInv.tooltip:DrawText(
            font,
            headlineLines[i],
            TOOLTIP_PADDING,
            y,
            HEADLINE_TEXT_COLOR.r,
            HEADLINE_TEXT_COLOR.g,
            HEADLINE_TEXT_COLOR.b,
            1.0
        )
        y = y + lineHeight
    end

    if #previewLines > 0 then
        y = y + PREVIEW_MARGIN_TOP
        for i = 1, #previewLines do
            tooltipInv.tooltip:DrawText(
                font,
                previewLines[i],
                TOOLTIP_PADDING,
                y,
                ARTICLE_PREVIEW_COLOR.r,
                ARTICLE_PREVIEW_COLOR.g,
                ARTICLE_PREVIEW_COLOR.b,
                1.0
            )
            y = y + lineHeight
        end
    end

    tooltipInv:setHeight(offsetY + extraHeight + 1)
end

function WIN_NewspaperTooltip.bindOverrides()
    if WIN_NewspaperTooltip.didBind then
        return
    end

    local originalRender = ISToolTipInv.render
    function ISToolTipInv:render()
        originalRender(self)
        WIN_NewspaperTooltip.renderTooltipPanel(self)
    end

    WIN_NewspaperTooltip.didBind = true
end

WIN_NewspaperTooltip.bindOverrides()
