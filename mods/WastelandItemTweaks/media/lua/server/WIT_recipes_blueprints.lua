WIT_recipes = WIT_recipes or {}

local WIT_BLUEPRINT_COMMAND_MODULE = "WIT_Blueprints"
local WIT_BLUEPRINT_COMMAND_LOG_OPEN = "logBlueprintOpen"

WIT_recipes.BlueprintConfig = {
    packScrapOutput = {
        general = 1,
        event = 2,
        dungeon = 3,
    },
    entries = {
        upgraded_belt = {
            scrapType = "Base.UpgradedBeltBlueprintScrap",
            finalType = "Base.UpgradedBeltBlueprint",
        },
        rattler_smg = {
            scrapType = "Base.RattlerSmgBlueprintScrap",
            finalType = "Base.RattlerSmgBlueprints",
        },
        thompson_smg = {
            scrapType = "Base.ThompsonSmgBlueprintScrap",
            finalType = "Base.ThompsonSmgBlueprints",
        },
        camo_medic_clothing = {
            scrapType = "Base.CamoMedicClothingBlueprintScrap",
            finalType = "Base.Camo_Medic_Clothing_Blueprints",
        },
        caution_pack = {
            scrapType = "Base.CautionPackBlueprintScrap",
            finalType = "Base.CautionPack_Blueprints",
        },
        swat_clothing = {
            scrapType = "Base.SwatClothingBlueprintScrap",
            finalType = "Base.SWAT_Clothing_Blueprints",
        },
        trauma_responder = {
            scrapType = "Base.TraumaResponderBlueprintScrap",
            finalType = "Base.Trauma_Responder_Blueprints",
        },
    },
    packs = {
        general = {
            { id = "upgraded_belt", sandboxWeight = "BlueprintWeightGeneralUpgradedBelt" },
            { id = "rattler_smg", sandboxWeight = "BlueprintWeightGeneralRattlerSmg" },
            { id = "thompson_smg", sandboxWeight = "BlueprintWeightGeneralThompsonSmg" },
            { id = "camo_medic_clothing", sandboxWeight = "BlueprintWeightGeneralCamoMedicClothing" },
            { id = "caution_pack", sandboxWeight = "BlueprintWeightGeneralCautionPack" },
        },
        event = {
            { id = "upgraded_belt", sandboxWeight = "BlueprintWeightEventUpgradedBelt" },
            { id = "rattler_smg", sandboxWeight = "BlueprintWeightEventRattlerSmg" },
            { id = "thompson_smg", sandboxWeight = "BlueprintWeightEventThompsonSmg" },
            { id = "camo_medic_clothing", sandboxWeight = "BlueprintWeightEventCamoMedicClothing" },
            { id = "caution_pack", sandboxWeight = "BlueprintWeightEventCautionPack" },
            { id = "swat_clothing", sandboxWeight = "BlueprintWeightEventSwatClothing" },
            { id = "trauma_responder", sandboxWeight = "BlueprintWeightEventTraumaResponder" },
        },
        dungeon = {
            entries = {
                { id = "upgraded_belt", sandboxWeight = "BlueprintWeightDungeonUpgradedBelt" },
                { id = "rattler_smg", sandboxWeight = "BlueprintWeightDungeonRattlerSmg" },
                { id = "thompson_smg", sandboxWeight = "BlueprintWeightDungeonThompsonSmg" },
                { id = "camo_medic_clothing", sandboxWeight = "BlueprintWeightDungeonCamoMedicClothing" },
                { id = "caution_pack", sandboxWeight = "BlueprintWeightDungeonCautionPack" },
                { id = "swat_clothing", sandboxWeight = "BlueprintWeightDungeonSwatClothing" },
                { id = "trauma_responder", sandboxWeight = "BlueprintWeightDungeonTraumaResponder" },
            },
            guaranteed = {
                ids = {
                    "swat_clothing",
                    "trauma_responder",
                },
            },
        },
    },
}

local function WIT_getBlueprintWeight(packEntry)
    local sandboxWeight = SandboxVars.WastelandItemTweaks[packEntry.sandboxWeight]
    if sandboxWeight == nil then
        return 0
    end

    return sandboxWeight
end

local function WIT_rollWeightedBlueprintIndex(packEntries)
    local totalWeight = 0
    for i = 1, #packEntries do
        local entry = packEntries[i]
        totalWeight = totalWeight + WIT_getBlueprintWeight(entry)
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = ZombRand(totalWeight) + 1
    local cumulative = 0
    for i = 1, #packEntries do
        local entry = packEntries[i]
        cumulative = cumulative + WIT_getBlueprintWeight(entry)
        if roll <= cumulative then
            return i
        end
    end

    return #packEntries
end

local function WIT_getPackEntries(packConfig)
    if not packConfig then
        return nil
    end

    if packConfig.entries then
        return packConfig.entries, packConfig
    end

    return packConfig, nil
end

local function WIT_isBlueprintIdInList(blueprintId, idList)
    if not idList then
        return false
    end

    for i = 1, #idList do
        if idList[i] == blueprintId then
            return true
        end
    end

    return false
end

local function WIT_rollGuaranteedBlueprintIndex(packEntries, guaranteedIds)
    local guaranteedEntries = {}
    for i = 1, #packEntries do
        local entry = packEntries[i]
        if WIT_isBlueprintIdInList(entry.id, guaranteedIds) then
            guaranteedEntries[#guaranteedEntries + 1] = entry
        end
    end

    if #guaranteedEntries == 0 then
        return nil
    end

    local selectedGuaranteedIndex = WIT_rollWeightedBlueprintIndex(guaranteedEntries)
    if not selectedGuaranteedIndex then
        return nil
    end

    local selectedGuaranteedEntry = guaranteedEntries[selectedGuaranteedIndex]
    for i = 1, #packEntries do
        if packEntries[i].id == selectedGuaranteedEntry.id then
            return i
        end
    end

    return nil
end

local function WIT_writeBlueprintOpenLog(playerName, playerX, playerY, playerZ, packId, blueprintId)
    writeLog("blueprints", string.format(
        "[BLUEPRINT] %s opened a %s pack and received %s damaged blueprint at %.0f,%.0f,%.0f",
        tostring(playerName),
        tostring(packId),
        tostring(blueprintId),
        playerX,
        playerY,
        playerZ
    ))
end

local function WIT_processBlueprintClientCommand(module, command, player, args)
    if module ~= WIT_BLUEPRINT_COMMAND_MODULE then
        return
    end

    if command ~= WIT_BLUEPRINT_COMMAND_LOG_OPEN then
        return
    end

    if not player or not args then
        return
    end

    WIT_writeBlueprintOpenLog(
        player:getUsername(),
        player:getX(),
        player:getY(),
        player:getZ(),
        args.packId,
        args.blueprintId
    )
end

if isServer() then
    Events.OnClientCommand.Add(WIT_processBlueprintClientCommand)
end

local function WIT_logBlueprintOpen(player, packId, blueprintId, entry, rollIndex, rollTotal)
    local playerName = player:getUsername()
    local playerX = player:getX()
    local playerY = player:getY()
    local playerZ = player:getZ()

    if isServer() then
        WIT_writeBlueprintOpenLog(playerName, playerX, playerY, playerZ, packId, blueprintId)
        return
    end

    sendClientCommand(player, WIT_BLUEPRINT_COMMAND_MODULE, WIT_BLUEPRINT_COMMAND_LOG_OPEN, {
        packId = packId,
        blueprintId = blueprintId,
    })
end

local function WIT_giveBlueprintPackScraps(player, packId)
    local config = WIT_recipes.BlueprintConfig
    local packConfig = config.packs[packId]
    local packEntries, packMeta = WIT_getPackEntries(packConfig)
    if not packEntries or #packEntries == 0 then
        return
    end

    local rollTotal = config.packScrapOutput[packId] or 1
    if rollTotal > #packEntries then
        rollTotal = #packEntries
    end

    local guaranteedConfig = packMeta and packMeta.guaranteed or nil
    local guaranteedIds = guaranteedConfig and guaranteedConfig.ids or nil
    local guaranteedRollIndex = 3
    local guaranteedSatisfied = false

    for rollIndex = 1, rollTotal do
        local selectedIndex

        if guaranteedIds and rollIndex == guaranteedRollIndex and not guaranteedSatisfied then
            selectedIndex = WIT_rollGuaranteedBlueprintIndex(packEntries, guaranteedIds)
        end

        if not selectedIndex then
            selectedIndex = WIT_rollWeightedBlueprintIndex(packEntries)
        end

        if not selectedIndex then
            return
        end

        local selectedPackEntry = packEntries[selectedIndex]
        local blueprintId = selectedPackEntry.id
        local entry = config.entries[blueprintId]
        if not entry then
            writeLog("blueprints", string.format("[BLUEPRINT] Missing config for pack='%s' blueprintId='%s'", tostring(packId), tostring(blueprintId)))
        else
            if guaranteedIds and WIT_isBlueprintIdInList(blueprintId, guaranteedIds) then
                guaranteedSatisfied = true
            end

            WIT_logBlueprintOpen(player, packId, blueprintId, entry, rollIndex, rollTotal)
            player:getInventory():AddItem(entry.scrapType)
        end
    end
end

function Recipe.OnCreate.OpenBlueprintPackGeneral(items, result, player)
    WIT_giveBlueprintPackScraps(player, "general")
end

function Recipe.OnCreate.OpenBlueprintPackEvent(items, result, player)
    WIT_giveBlueprintPackScraps(player, "event")
end

function Recipe.OnCreate.OpenBlueprintPackDungeon(items, result, player)
    WIT_giveBlueprintPackScraps(player, "dungeon")
end
