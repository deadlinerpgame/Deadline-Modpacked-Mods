---
--- WIN_NewspaperWindow.lua
--- 2026-06-28
---

require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISCollapsableWindow"
require "ISUI/ISLabel"
require "ISUI/ISTextEntryBox"
require "TimedActions/WIN_ReadWriteTimedAction"
require "WL_Utils"
require "WIN_NewspaperData"
require "WIN_Utils"

WIN_NewspaperWindow = ISCollapsableWindow:derive("WIN_NewspaperWindow")

local TEXTURE_WIDTH = 1137
local TEXTURE_HEIGHT = 854
local NEWSPAPER_TEXTURE = "media/textures/BlankNewspaper.png"
local SAVE_ICON = "media/textures/ui/SaveDiskIcon.png"
local CLOSE_ICON = "media/textures/ui/CancelIcon.png"
local PREVIOUS_PAGE_ICON = "media/textures/ui/PreviousPageIcon.png"
local NEXT_PAGE_ICON = "media/textures/ui/NextPageIcon.png"
local FONT_SCALE_SAMPLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
local FONT_REFERENCE_METRICS = {
    { font = UIFont.Small, height = 19, width = 550 },
    { font = UIFont.Medium, height = 25, width = 675 },
    { font = UIFont.Large, height = 30, width = 809 },
}
local TEXT_COLOR = ColorInfo.new(0.04, 0.04, 0.04, 1)
local LABEL_COLOR = { r = 0.08, g = 0.08, b = 0.08, a = 1 }
local TITLE_TEXT_COLOR = { r = 0.04, g = 0.04, b = 0.04, a = 1 }
local NEWSPAPER_LOCATION = "Knox, KY"
local RULE_COLOR = { r = 70 / 255, g = 70 / 255, b = 70 / 255, a = 1 }
local PAGE_CONFIG_COMBO_LEFT = 50
local PAGE_CONFIG_COMBO_BOTTOM = 20
local PAGE_CONFIG_COMBO_WIDTH = 350
local PAGE_CONFIG_COMBO_HEIGHT = 24
local IMAGE_COMBO_GAP = 12
local IMAGE_COMBO_WIDTH = 180
local PAGE_LABEL_WIDTH = 50

local function getNewspaperScale()
    local textManager = getTextManager()
    local scale = 0
    for _, metrics in ipairs(FONT_REFERENCE_METRICS) do
        local heightScale = textManager:getFontHeight(metrics.font) / metrics.height
        local widthScale = textManager:MeasureStringX(metrics.font, FONT_SCALE_SAMPLE) / metrics.width
        scale = math.max(scale, heightScale, widthScale)
    end
    return scale
end

local function doAnimation(player, newspaperItem, isNewspaperInInventory, isReadOnly)
    if not isNewspaperInInventory then
        return nil
    end

    local queue = ISTimedActionQueue.getTimedActionQueue(player)
    if #queue.queue > 0 then
        return nil
    end

    local writingImplement = nil
    if not isReadOnly then
        local playerInv = player:getInventory()
        if playerInv:containsTagRecurse("Pencil") then
            writingImplement = "Base.Pencil"
        else
            writingImplement = "Base.Pen"
        end
    end

    local action = WIN_ReadWriteTimedAction:new(player, newspaperItem:getFullType(), writingImplement)
    ISTimedActionQueue.add(action)
    return action
end

function WIN_NewspaperWindow.displayFromContextMenu(newspaperItem, forceReadOnly)
    local player = getPlayer()
    local isNewspaperInInventory = player:getInventory():getFirstTypeEvalRecurse(
        newspaperItem:getFullType(), function(item) return item == newspaperItem end)

    local isReadOnly = forceReadOnly == true or WIN_NewspaperData.isPlayerNewspaper(newspaperItem)
    if not isNewspaperInInventory then
        isReadOnly = true
    end

    if newspaperItem:getLockedBy()
        and newspaperItem:getLockedBy() ~= player:getUsername()
        and not WL_Utils.isStaff(player) then
        isReadOnly = true
    end

    local action = doAnimation(player, newspaperItem, isNewspaperInInventory, isReadOnly)
    local newspaperWindow = WIN_NewspaperWindow:new(
        newspaperItem,
        isReadOnly,
        action,
        WIN_NewspaperData.loadFromItem(newspaperItem)
    )
    newspaperWindow:addToUIManager()
end

function WIN_NewspaperWindow.displayFromServerMessage(newspaperData)
    local newspaperWindow = WIN_NewspaperWindow:new(nil, true, nil, newspaperData)
    newspaperWindow:addToUIManager()
end

function WIN_NewspaperWindow:new(newspaperItem, isReadOnly, action, newspaperData)
    local newspaperScale = getNewspaperScale()
    local fitScale = math.min(
        (getCore():getScreenWidth() * 0.9) / TEXTURE_WIDTH,
        (getCore():getScreenHeight() * 0.9) / TEXTURE_HEIGHT
    )
    local windowScale = math.min(newspaperScale, fitScale)

    local w = math.floor(TEXTURE_WIDTH * windowScale)
    local h = math.floor(TEXTURE_HEIGHT * windowScale)
    local o = ISCollapsableWindow:new(
        getCore():getScreenWidth() / 2 - w / 2,
        getCore():getScreenHeight() / 2 - h / 2,
        w,
        h
    )
    setmetatable(o, self)
    self.__index = self
    o.resizable = false
    o.layoutScale = windowScale
    o.readOnly = isReadOnly
    o.newspaperItem = newspaperItem
    o.action = action
    o.currentPage = 1
    o.newspaperData = WIN_NewspaperData.normalize(newspaperData)
    o.originalNewspaperData = WIN_NewspaperData.normalize(newspaperData)
    o.newspaperTexture = getTexture(NEWSPAPER_TEXTURE)
    o.columnTitleTextBoxes = {}
    o.columnAuthorTextBoxes = {}
    o.columnBodyTextBoxes = {}
    o:initialise()
    return o
end

function WIN_NewspaperWindow:scale(px)
    return math.floor(px * self.layoutScale)
end

function WIN_NewspaperWindow:drawRule(x, y, w, h, lightLevel)
    self:drawRect(
        self:scale(x),
        self:scale(y),
        math.max(1, self:scale(w)),
        math.max(1, self:scale(h)),
        RULE_COLOR.a,
        RULE_COLOR.r * lightLevel,
        RULE_COLOR.g * lightLevel,
        RULE_COLOR.b * lightLevel
    )
end

function WIN_NewspaperWindow:drawRuleData(rule, lightLevel)
    self:drawRule(rule.x, rule.y, rule.w, rule.h, lightLevel)
end

function WIN_NewspaperWindow:drawPageRules(lightLevel)
    for _, rule in ipairs(WIN_NewspaperData.PAGE_LAYOUT.headerRules) do
        self:drawRuleData(rule, lightLevel)
    end

    for _, rule in ipairs(self.pageConfigLayout.verticalRules) do
        self:drawRuleData(rule, lightLevel)
    end
end

local function makeIconButton(button, texturePath)
    button.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    button.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    button.backgroundColorMouseOver = { r = 0.6, g = 0.6, b = 0.6, a = 0.8 }
    button:setImage(getTexture(texturePath))
end

function WIN_NewspaperWindow:createIconButton(x, y, buttonSize, texturePath, callback)
    local button = ISButton:new(x, y, buttonSize, buttonSize, "", self, callback)
    button:initialise()
    button:instantiate()
    makeIconButton(button, texturePath)
    self:addChild(button)
    return button
end

function WIN_NewspaperWindow:getCurrentPageData()
    return self.newspaperData.pages[self.currentPage]
end

function WIN_NewspaperWindow:createPageConfigComboBox()
    local pageData = self:getCurrentPageData()
    local comboBox = ISComboBox:new(
        self:scale(PAGE_CONFIG_COMBO_LEFT),
        self.height - self:scale(PAGE_CONFIG_COMBO_BOTTOM + PAGE_CONFIG_COMBO_HEIGHT),
        self:scale(PAGE_CONFIG_COMBO_WIDTH),
        self:scale(PAGE_CONFIG_COMBO_HEIGHT),
        self,
        self.onPageConfigChanged
    )
    comboBox:initialise()
    comboBox:instantiate()
    comboBox:createChildren()
    for _, pageConfigKey in ipairs(WIN_NewspaperData.getPageConfigOrder(self.currentPage)) do
        comboBox:addOptionWithData(WIN_NewspaperData.getPageConfigName(pageConfigKey), pageConfigKey)
    end
    comboBox:selectData(pageData.pageConfigKey)
    self:addChild(comboBox)
    return comboBox
end

function WIN_NewspaperWindow:createImageComboBox()
    local pageData = self:getCurrentPageData()
    local comboBox = ISComboBox:new(
        self:scale(PAGE_CONFIG_COMBO_LEFT + PAGE_CONFIG_COMBO_WIDTH + IMAGE_COMBO_GAP),
        self.height - self:scale(PAGE_CONFIG_COMBO_BOTTOM + PAGE_CONFIG_COMBO_HEIGHT),
        self:scale(IMAGE_COMBO_WIDTH),
        self:scale(PAGE_CONFIG_COMBO_HEIGHT),
        self,
        self.onImageChanged
    )
    comboBox:initialise()
    comboBox:instantiate()
    comboBox:createChildren()
    for _, imageOption in ipairs(WIN_NewspaperData.getPageConfigImageOptions(pageData)) do
        comboBox:addOptionWithData(imageOption.name, imageOption.key)
    end
    comboBox:selectData(pageData.imageKey)
    self:addChild(comboBox)
    return comboBox
end

function WIN_NewspaperWindow:createTextBox(text, x, y, w, h, font, isMultipleLine, maxLength, maxLines)
    local textBox = ISTextEntryBox:new(text or "", x, y, w, h)
    textBox.font = font
    textBox.anchorTop = true
    textBox.anchorLeft = true
    textBox:initialise()
    textBox:instantiate()
    textBox.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    textBox.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    textBox.javaObject:setTextColor(TEXT_COLOR)
    textBox.javaObject:setMaxTextLength(maxLength)
    if isMultipleLine then
        textBox:setMultipleLine(true)
        local lineLimit = maxLines or math.max(1, math.floor(h / getTextManager():getFontHeight(font)))
        textBox.javaObject:setMaxLines(lineLimit)
    end
    if self.readOnly then
        textBox:setEditable(false)
        textBox.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    end
    self:addChild(textBox)
    return textBox
end

function WIN_NewspaperWindow:setupLayoutMetrics()
    local pageLayout = WIN_NewspaperData.PAGE_LAYOUT
    self.pageConfigLayout = WIN_NewspaperData.getPageConfigLayout(self:getCurrentPageData())
    self.contentLeft = self:scale(pageLayout.contentLeft)
    self.nameTop = self:scale(pageLayout.nameTop)
    self.contentWidth = self:scale(pageLayout.contentWidth)
    self.nameLeft = self.contentLeft
    self.nameWidth = self.contentWidth
    self.nameHeight = self:scale(pageLayout.nameHeight)
    self.headerTextLeft = self.contentLeft
    self.headerTextTop = self:scale(pageLayout.headerTextTop)
    self.headerTextWidth = self.contentWidth
end

function WIN_NewspaperWindow:clearColumnTextBoxes()
    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        if self.columnTitleTextBoxes[i] then
            self:removeChild(self.columnTitleTextBoxes[i])
            self.columnTitleTextBoxes[i] = nil
        end
        if self.columnAuthorTextBoxes[i] then
            self:removeChild(self.columnAuthorTextBoxes[i])
            self.columnAuthorTextBoxes[i] = nil
        end
        if self.columnBodyTextBoxes[i] then
            self:removeChild(self.columnBodyTextBoxes[i])
            self.columnBodyTextBoxes[i] = nil
        end
    end
end

function WIN_NewspaperWindow:rebuildColumnTextBoxes()
    self:clearColumnTextBoxes()
    local pageData = self:getCurrentPageData()
    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        local columnData = pageData.columns[i]
        local columnLayout = self.pageConfigLayout.columns[i]
        if columnLayout.title then
            self.columnTitleTextBoxes[i] = self:createTextBox(
                columnData.title,
                self:scale(columnLayout.title.x),
                self:scale(columnLayout.title.y),
                self:scale(columnLayout.title.w),
                self:scale(columnLayout.title.h),
                UIFont.Large,
                true,
                columnLayout.title.maxLength,
                columnLayout.title.maxLines
            )
        end
        if columnLayout.author then
            self.columnAuthorTextBoxes[i] = self:createTextBox(
                columnData.author,
                self:scale(columnLayout.author.x),
                self:scale(columnLayout.author.y),
                self:scale(columnLayout.author.w),
                self:scale(columnLayout.author.h),
                UIFont.Small,
                false,
                columnLayout.author.maxLength,
                columnLayout.author.maxLines
            )
        end
        self.columnBodyTextBoxes[i] = self:createTextBox(
            columnData.body,
            self:scale(columnLayout.body.x),
            self:scale(columnLayout.body.y),
            self:scale(columnLayout.body.w),
            self:scale(columnLayout.body.h),
            UIFont.Small,
            true,
            columnLayout.body.maxLength,
            columnLayout.body.maxLines
        )
    end
end

function WIN_NewspaperWindow:removeImageComboBox()
    if self.imageComboBox then
        self:removeChild(self.imageComboBox)
        self.imageComboBox = nil
    end
end

function WIN_NewspaperWindow:removePageConfigComboBox()
    if self.pageConfigComboBox then
        self:removeChild(self.pageConfigComboBox)
        self.pageConfigComboBox = nil
    end
end

function WIN_NewspaperWindow:rebuildPageConfigComboBox()
    self:removePageConfigComboBox()
    if not self.readOnly then
        self.pageConfigComboBox = self:createPageConfigComboBox()
    end
end

function WIN_NewspaperWindow:rebuildImageComboBox()
    self:removeImageComboBox()
    if not self.readOnly and WIN_NewspaperData.hasPageConfigImageOptions(self:getCurrentPageData()) then
        self.imageComboBox = self:createImageComboBox()
    end
end

function WIN_NewspaperWindow:initialise()
    ISCollapsableWindow.initialise(self)
    self:noBackground()
    self.borderColor = { r = 0, g = 0, b = 0, a = 0 }
    self.backgroundColor = { r = 0, g = 0, b = 0, a = 0 }
    self.moveWithMouse = true

    self:setupLayoutMetrics()

    if not self.readOnly then
        self:rebuildPageConfigComboBox()
        self:rebuildImageComboBox()
    end

    self:rebuildColumnTextBoxes()

    local buttonSize = self:scale(30)
    local buttonGap = self:scale(8)
    local buttonTop = self:scale(20)
    local closeLeft = self.width - self:scale(34) - buttonSize
    if not self.readOnly then
        local saveLeft = closeLeft - buttonSize - buttonGap
        self.saveButton = self:createIconButton(saveLeft, buttonTop, buttonSize, SAVE_ICON, self.onSave)
    end
    self.newspaperCloseButton = self:createIconButton(closeLeft, buttonTop, buttonSize, CLOSE_ICON, self.close)

    if self.newspaperData.pageCount > 1 then
        local pageButtonTop = self.height - self:scale(PAGE_CONFIG_COMBO_BOTTOM + 30)
        local nextPageLeft = self.width - self:scale(34) - buttonSize
        local pageLabelWidth = self:scale(PAGE_LABEL_WIDTH)
        local pageLabelLeft = nextPageLeft - pageLabelWidth - buttonGap
        local prevPageLeft = pageLabelLeft - buttonSize - buttonGap
        self.prevPageButton = self:createIconButton(prevPageLeft, pageButtonTop, buttonSize, PREVIOUS_PAGE_ICON, self.onPrevPage)
        self.prevPageButton.sounds.activate = "NotebookTurnPage1"
        self.nextPageButton = self:createIconButton(nextPageLeft, pageButtonTop, buttonSize, NEXT_PAGE_ICON, self.onNextPage)
        self.nextPageButton.sounds.activate = "NotebookTurnPage2"
        self.pageLabelLeft = pageLabelLeft
        self.pageLabelTop = pageButtonTop
        self.pageLabelWidth = pageLabelWidth
        self.pageLabelHeight = buttonSize
    end
end

function WIN_NewspaperWindow:getCurrentData(pageConfigKeyOverride)
    local currentData = WIN_NewspaperData.normalize(self.newspaperData)
    local pageData = currentData.pages[self.currentPage]
    if self.pageConfigComboBox then
        pageData.pageConfigKey = WIN_NewspaperData.getValidPageConfigKey(
            self.currentPage,
            pageConfigKeyOverride or self.pageConfigComboBox:getOptionData(self.pageConfigComboBox.selected)
        )
    end
    if self.imageComboBox then
        pageData.imageKey = self.imageComboBox:getOptionData(self.imageComboBox.selected)
    end
    for i = 1, WIN_NewspaperData.COLUMN_COUNT do
        if self.columnTitleTextBoxes[i] then
            pageData.columns[i].title = self.columnTitleTextBoxes[i]:getText()
        end
        if self.columnAuthorTextBoxes[i] then
            pageData.columns[i].author = self.columnAuthorTextBoxes[i]:getText()
        end
        pageData.columns[i].body = self.columnBodyTextBoxes[i]:getText()
    end
    return WIN_NewspaperData.normalize(currentData)
end

function WIN_NewspaperWindow:storeCurrentPageFromControls(pageConfigKeyOverride)
    self.newspaperData = self:getCurrentData(pageConfigKeyOverride)
end

function WIN_NewspaperWindow:refreshCurrentPageControls()
    self:setupLayoutMetrics()
    self:rebuildPageConfigComboBox()
    self:rebuildImageComboBox()
    self:rebuildColumnTextBoxes()
end

function WIN_NewspaperWindow:onPageConfigChanged(comboBox)
    local pageConfigKey = comboBox:getOptionData(comboBox.selected)
    if pageConfigKey == self:getCurrentPageData().pageConfigKey then
        return
    end

    self:storeCurrentPageFromControls(self:getCurrentPageData().pageConfigKey)
    self.newspaperData = WIN_NewspaperData.applyPageConfigKey(self.newspaperData, self.currentPage, pageConfigKey)
    self:setupLayoutMetrics()
    self:rebuildColumnTextBoxes()
    self:rebuildImageComboBox()
end

function WIN_NewspaperWindow:onImageChanged(comboBox)
    local imageKey = comboBox:getOptionData(comboBox.selected)
    if imageKey == self:getCurrentPageData().imageKey then
        return
    end

    self:storeCurrentPageFromControls()
end

function WIN_NewspaperWindow:onSave()
    if self.readOnly then
        self:close()
        return
    end

    self:storeCurrentPageFromControls()
    local hasChanges = WIN_NewspaperData.hasChanges(self.originalNewspaperData, self.newspaperData)
    local savedData = WIN_NewspaperData.saveToItem(self.newspaperItem, self.newspaperData, hasChanges)
    WIN_Utils.writeNewspaperChangeLog(getPlayer(), self.newspaperItem, self.originalNewspaperData, savedData)
    self:close()
end

function WIN_NewspaperWindow:showPage(pageIndex)
    if pageIndex < 1 or pageIndex > self.newspaperData.pageCount or pageIndex == self.currentPage then
        return
    end

    self:storeCurrentPageFromControls()
    self.currentPage = pageIndex
    self:refreshCurrentPageControls()
end

function WIN_NewspaperWindow:onPrevPage()
    self:showPage(self.currentPage - 1)
end

function WIN_NewspaperWindow:onNextPage()
    self:showPage(self.currentPage + 1)
end

function WIN_NewspaperWindow:getLightLevelToDraw()
    local player = getPlayer()
    if not player then
        return 1
    end

    local square = player:getSquare()
    if not square then
        return 1
    end

    local lightLevel = square:getLightLevel(player:getPlayerNum())
    if lightLevel < 0.75 then lightLevel = lightLevel - 0.27 end
    if lightLevel < 0.05 then lightLevel = 0.05 end

    if not self.currLightLevel then
        self.currLightLevel = lightLevel
    elseif self.currLightLevel < lightLevel then
        self.currLightLevel = math.min(self.currLightLevel + 0.04, lightLevel)
    elseif self.currLightLevel > lightLevel then
        self.currLightLevel = math.max(self.currLightLevel - 0.04, lightLevel)
    end
    return self.currLightLevel
end

function WIN_NewspaperWindow:drawNewspaperName()
    local textY = self.nameTop + math.floor((self.nameHeight - getTextManager():getFontHeight(UIFont.Intro)) / 2)
    self:drawTextCentre(
        self.newspaperData.paperName,
        self.nameLeft + (self.nameWidth / 2),
        textY,
        TITLE_TEXT_COLOR.r,
        TITLE_TEXT_COLOR.g,
        TITLE_TEXT_COLOR.b,
        TITLE_TEXT_COLOR.a,
        UIFont.Intro
    )
end

function WIN_NewspaperWindow:drawHeaderMetadata()
    self:drawText(
        NEWSPAPER_LOCATION,
        self.headerTextLeft,
        self.headerTextTop,
        LABEL_COLOR.r,
        LABEL_COLOR.g,
        LABEL_COLOR.b,
        LABEL_COLOR.a,
        UIFont.Medium
    )
    self:drawTextCentre(
        WIN_NewspaperData.getIssueDateText(self.newspaperData),
        self.headerTextLeft + (self.headerTextWidth / 2),
        self.headerTextTop,
        LABEL_COLOR.r,
        LABEL_COLOR.g,
        LABEL_COLOR.b,
        LABEL_COLOR.a,
        UIFont.Medium
    )
    self:drawTextRight(
        WIN_NewspaperData.getIssueLabel(self.newspaperData),
        self.headerTextLeft + self.headerTextWidth,
        self.headerTextTop,
        LABEL_COLOR.r,
        LABEL_COLOR.g,
        LABEL_COLOR.b,
        LABEL_COLOR.a,
        UIFont.Medium
    )
end

function WIN_NewspaperWindow:getImageTexturePath(imageData)
    local imageOption = WIN_NewspaperData.getImageOption(self:getCurrentPageData().imageKey)
    if imageOption then
        return imageOption.texture
    end
    return imageData.texture
end

function WIN_NewspaperWindow:drawPageImages(lightLevel)
    for _, imageData in ipairs(self.pageConfigLayout.images) do
        local imageTexture = getTexture(self:getImageTexturePath(imageData))
        self:drawTextureScaled(
            imageTexture,
            self:scale(imageData.x),
            self:scale(imageData.y),
            self:scale(imageData.w),
            self:scale(imageData.h),
            1,
            lightLevel,
            lightLevel,
            lightLevel
        )
    end
end

function WIN_NewspaperWindow:updateIconButtonLightLevel(lightLevel)
    if self.saveButton then
        self.saveButton:setTextureRGBA(lightLevel, lightLevel, lightLevel, 1)
    end
    self.newspaperCloseButton:setTextureRGBA(lightLevel, lightLevel, lightLevel, 1)
    if self.prevPageButton then
        self.prevPageButton:setTextureRGBA(lightLevel, lightLevel, lightLevel, 1)
    end
    if self.nextPageButton then
        self.nextPageButton:setTextureRGBA(lightLevel, lightLevel, lightLevel, 1)
    end
end

function WIN_NewspaperWindow:drawPageLabel(lightLevel)
    if not self.pageLabelLeft then
        return
    end

    local pageLabel = tostring(self.currentPage) .. "/" .. tostring(self.newspaperData.pageCount)
    local textY = self.pageLabelTop + math.floor((self.pageLabelHeight - getTextManager():getFontHeight(UIFont.Large)) / 2)
    self:drawTextCentre(
        pageLabel,
        self.pageLabelLeft + (self.pageLabelWidth / 2),
        textY,
        LABEL_COLOR.r * lightLevel,
        LABEL_COLOR.g * lightLevel,
        LABEL_COLOR.b * lightLevel,
        LABEL_COLOR.a,
        UIFont.Large
    )
end

function WIN_NewspaperWindow:prerender()
    local lightLevel = self:getLightLevelToDraw()
    self:updateIconButtonLightLevel(lightLevel)
    self.pinButton:setVisible(false)
    self.collapseButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:drawTextureScaled(self.newspaperTexture, 0, 0, self.width, self.height, 1.0, lightLevel, lightLevel, lightLevel)
    self:drawNewspaperName()
    self:drawHeaderMetadata()
    self:drawPageImages(lightLevel)
    self:drawPageRules(lightLevel)
    self:drawPageLabel(lightLevel)
end

function WIN_NewspaperWindow:close()
    if self.action then
        local queue = ISTimedActionQueue.getTimedActionQueue(getPlayer())
        if #queue.queue > 0 and queue.queue[1] == self.action then
            ISTimedActionQueue.clear(getPlayer())
        end
    end
    ISPanelJoypad.removeFromUIManager(self)
end
