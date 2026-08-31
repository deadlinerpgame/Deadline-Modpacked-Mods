---
--- WIN_NewspaperPageConfigs.lua
--- 2026-06-29
---

WIN_NewspaperPageConfigs = {}

WIN_NewspaperPageConfigs.COLUMN_COUNT = 3
WIN_NewspaperPageConfigs.NEW_ARTICLE_COLUMN_TYPE = "NewArticle"
WIN_NewspaperPageConfigs.CONTINUED_ARTICLE_COLUMN_TYPE = "ContinuedArticle"

WIN_NewspaperPageConfigs.IMAGE_OPTIONS = {
    {
        key = "FenceBreach",
        name = "Fence Breach",
        texture = "media/textures/newspaper-images/FenceBreach.png",
    },
    {
        key = "Truck",
        name = "Truck",
        texture = "media/textures/newspaper-images/Truck.png",
    },
    {
        key = "BlockedRoad",
        name = "Blocked Road",
        texture = "media/textures/newspaper-images/BlockedRoad.png",
    },
    {
        key = "Witness",
        name = "Witness",
        texture = "media/textures/newspaper-images/Witness.png",
    },
    {
        key = "AbandonedHouse",
        name = "Abandoned House",
        texture = "media/textures/newspaper-images/AbandonedHouse.png",
    },
    {
        key = "FightingRing",
        name = "Fighting Ring",
        texture = "media/textures/newspaper-images/FightingRing.png",
    },
    {
        key = "Safehouse",
        name = "Safehouse",
        texture = "media/textures/newspaper-images/Safehouse.png",
    },
    {
        key = "Survivor",
        name = "Survivor",
        texture = "media/textures/newspaper-images/Survivor.png",
    },
    {
        key = "Traveller",
        name = "Traveller",
        texture = "media/textures/newspaper-images/Traveller.png",
    },
    {
        key = "Winter",
        name = "Winter",
        texture = "media/textures/newspaper-images/Winter.png",
    },
}

WIN_NewspaperPageConfigs.PAGE_LAYOUT = {
    contentLeft = 70,
    contentWidth = 997,
    nameTop = 48,
    nameHeight = 40,
    headerTextTop = 105,
    headerRules = {
        { x = 55, y = 96, w = 1015, h = 2 },
        { x = 55, y = 137, w = 1015, h = 2 },
    },
}

-- Edit this table for new page layouts. Rectangles are unscaled newspaper-pixel coordinates.
WIN_NewspaperPageConfigs.PAGE_CONFIG_DEFINITIONS = {
    {
        key = "LongHeaderImage",
        name = "Article + Feature Image",
        default = true,
        validForFirstPage = true,
        columns = {
            {
                title = { x = 70, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 70, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 70, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                body = { x = 410, y = 599, w = 419, h = 197, maxLength = 3000, maxLines = 10 },
            },
            {
                body = { x = 853, y = 162, w = 213, h = 630, maxLength = 3000, maxLines = 33 },
            },
        },
        images = {
            { x = 410, y = 170, w = 419, h = 419 },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 841, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "ThreeColumnBig",
        name = "Article + Two Body Columns",
        validForFirstPage = true,
        columns = {
            {
                title = { x = 70, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 70, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 70, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                body = { x = 410, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                body = { x = 750, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "BodyArticleBody",
        name = "Body + Article + Body",
        columns = {
            {
                body = { x = 70, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                title = { x = 410, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 410, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 410, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                body = { x = 750, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "TwoBodyColumnsArticle",
        name = "Two Body Columns + Article",
        columns = {
            {
                body = { x = 70, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                body = { x = 410, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                title = { x = 750, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 750, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 750, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "TwoArticlesBodyColumn",
        name = "Two Articles + Body Column",
        validForFirstPage = true,
        columns = {
            {
                title = { x = 70, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 70, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 70, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                title = { x = 410, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 410, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 410, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                body = { x = 750, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "TwoColumnBigOneSmall",
        name = "Article + Body + Article",
        validForFirstPage = true,
        columns = {
            {
                title = { x = 70, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 70, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 70, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                body = { x = 410, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                title = { x = 750, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 750, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 750, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "BodyColumnTwoArticles",
        name = "Body Column + Two Articles",
        columns = {
            {
                body = { x = 70, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                title = { x = 410, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 410, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 410, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                title = { x = 750, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 750, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 750, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "ThreeArticles",
        name = "Three Articles",
        validForFirstPage = true,
        columns = {
            {
                title = { x = 70, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 70, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 70, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                title = { x = 410, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 410, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 410, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
            {
                title = { x = 750, y = 165, w = 316, h = 72, maxLength = 80, maxLines = 2 },
                author = { x = 750, y = 241, w = 316, h = 20, maxLength = 80, maxLines = 1 },
                body = { x = 750, y = 276, w = 316, h = 520, maxLength = 2500, maxLines = 22 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
    {
        key = "ThreeBodyColumns",
        name = "Three Body Columns",
        columns = {
            {
                body = { x = 70, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                body = { x = 410, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
            {
                body = { x = 750, y = 162, w = 316, h = 630, maxLength = 3000, maxLines = 33 },
            },
        },
        verticalRules = {
            { x = 393.33333333333, y = 173, w = 1, h = 644 },
            { x = 731.66666666667, y = 173, w = 1, h = 644 },
        },
    },
}

local function createImageOptionsByKey()
    local imageOptionsByKey = {}
    for _, imageOption in ipairs(WIN_NewspaperPageConfigs.IMAGE_OPTIONS) do
        imageOptionsByKey[imageOption.key] = imageOption
    end
    return imageOptionsByKey
end

WIN_NewspaperPageConfigs.IMAGE_OPTIONS_BY_KEY = createImageOptionsByKey()

function WIN_NewspaperPageConfigs.getImageOption(imageKey)
    return WIN_NewspaperPageConfigs.IMAGE_OPTIONS_BY_KEY[imageKey]
end

function WIN_NewspaperPageConfigs.getDefaultImageOption()
    return WIN_NewspaperPageConfigs.IMAGE_OPTIONS[1]
end

local function copyTextRegion(region)
    return {
        x = region.x,
        y = region.y,
        w = region.w,
        h = region.h,
        maxLength = region.maxLength,
        maxLines = region.maxLines,
    }
end

local function copyRule(rule)
    return {
        x = rule.x,
        y = rule.y,
        w = rule.w,
        h = rule.h,
    }
end

local function createColumnLayout(columnDefinition)
    local columnLayout = {
        body = copyTextRegion(columnDefinition.body),
    }
    if columnDefinition.title then
        columnLayout.title = copyTextRegion(columnDefinition.title)
    end
    if columnDefinition.author then
        columnLayout.author = copyTextRegion(columnDefinition.author)
    end
    return columnLayout
end

local function getColumnType(columnDefinition)
    if columnDefinition.title then
        return WIN_NewspaperPageConfigs.NEW_ARTICLE_COLUMN_TYPE
    end
    return WIN_NewspaperPageConfigs.CONTINUED_ARTICLE_COLUMN_TYPE
end

local function createImageLayout(imageDefinition)
    local imageOption = WIN_NewspaperPageConfigs.getDefaultImageOption()
    if not imageOption then
        error("Newspaper image slot has no image options")
    end

    return {
        imageKey = imageOption.key,
        texture = imageOption.texture,
        x = imageDefinition.x,
        y = imageDefinition.y,
        w = imageDefinition.w,
        h = imageDefinition.h,
    }
end

local function createImages(definition)
    local images = {}
    if definition.images then
        for _, imageDefinition in ipairs(definition.images) do
            table.insert(images, createImageLayout(imageDefinition))
        end
    end
    return images
end

local function createVerticalRules(definition)
    local verticalRules = {}
    for _, rule in ipairs(definition.verticalRules) do
        table.insert(verticalRules, copyRule(rule))
    end
    return verticalRules
end

local function createPageConfig(definition)
    local columns = {}
    local columnTypes = {}
    for i = 1, WIN_NewspaperPageConfigs.COLUMN_COUNT do
        columns[i] = createColumnLayout(definition.columns[i])
        columnTypes[i] = getColumnType(definition.columns[i])
    end

    return {
        name = definition.name,
        validForFirstPage = definition.validForFirstPage == true,
        columnTypes = columnTypes,
        imageOptions = definition.images and WIN_NewspaperPageConfigs.IMAGE_OPTIONS or {},
        layout = {
            columns = columns,
            images = createImages(definition),
            verticalRules = createVerticalRules(definition),
        },
    }
end

local function createPageConfigs()
    local pageConfigs = {}
    local pageConfigOrder = {}
    local defaultPageConfigKey = nil
    for _, definition in ipairs(WIN_NewspaperPageConfigs.PAGE_CONFIG_DEFINITIONS) do
        if not defaultPageConfigKey or definition.default then
            defaultPageConfigKey = definition.key
        end
        table.insert(pageConfigOrder, definition.key)
        pageConfigs[definition.key] = createPageConfig(definition)
    end
    return pageConfigs, pageConfigOrder, defaultPageConfigKey
end

WIN_NewspaperPageConfigs.PAGE_CONFIGS,
WIN_NewspaperPageConfigs.PAGE_CONFIG_ORDER,
WIN_NewspaperPageConfigs.DEFAULT_PAGE_CONFIG_KEY = createPageConfigs()
