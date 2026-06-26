local WALKMAN_FULL_TYPE = "Tsarcraft.TCWalkman"
local CASE_FULL_TYPE = "WLCustomCases.Cassette_Case"
local CASE_MODE_MODDATA_KEY = "WLCustomCases.CassetteCasePlaybackMode"
local CASE_MODE_RANDOM = "random"
local CASE_MODE_REPEAT = "repeat"

local function isWalkmanEligible(player, device)
  return device
      and device:getFullType() == WALKMAN_FULL_TYPE
      and device:getContainer() == player:getInventory()
      and device:getDeviceData()
      and device:getDeviceData():getIsTurnedOn()
      and device:getModData().tcmusic
      and device:getModData().tcmusic.deviceType == "InventoryItem"
end

local function getCurrentPlayingWalkman(player)
  local inventory = player:getInventory()
  local items = inventory:getItems()

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if isWalkmanEligible(player, item) and item:getModData().tcmusic.mediaItem and item:getModData().tcmusic.isPlaying then
      return item
    end
  end

  return nil
end

local function findCassetteCaseInMainInventory(player)
  local inventory = player:getInventory()
  local items = inventory:getItems()

  for i = 0, items:size() - 1 do
    local item = items:get(i)
    if item:getFullType() == CASE_FULL_TYPE and item:getContainer() == inventory then
      return item, item:getItemContainer()
    end
  end

  return nil, nil
end

local function getCasePlaybackMode(caseItem)
  local modData = caseItem:getModData()
  local mode = modData[CASE_MODE_MODDATA_KEY]

  if mode ~= CASE_MODE_RANDOM and mode ~= CASE_MODE_REPEAT then
    mode = CASE_MODE_RANDOM
    modData[CASE_MODE_MODDATA_KEY] = mode
  end

  return mode
end

local function setCasePlaybackMode(caseItem, mode)
  local modData = caseItem:getModData()
  modData[CASE_MODE_MODDATA_KEY] = mode
end

local function toggleCasePlaybackMode(caseItem)
  if getCasePlaybackMode(caseItem) == CASE_MODE_REPEAT then
    setCasePlaybackMode(caseItem, CASE_MODE_RANDOM)
    return
  end

  setCasePlaybackMode(caseItem, CASE_MODE_REPEAT)
end

local function getCaseModeOptionText(caseItem)
  if getCasePlaybackMode(caseItem) == CASE_MODE_REPEAT then
    return "Cassette Case: Swap to Random"
  end

  return "Cassette Case: Swap to Repeat"
end

local function getCassetteCaseFromContextItems(items)
  for i = 1, #items do
    local item = items[i]

    if not instanceof(item, "InventoryItem") then
      item = item.items[1]
    end

    if item and item:getFullType() == CASE_FULL_TYPE then
      return item
    end
  end

  return nil
end

local function onFillInventoryObjectContextMenu(_, context, items)
  local caseItem = getCassetteCaseFromContextItems(items)
  if not caseItem then
    return
  end

  context:addOptionOnTop(getCaseModeOptionText(caseItem), caseItem, toggleCasePlaybackMode)
end

local function isCassetteItem(item)
  local fullType = item:getFullType()
  return fullType and string.find(fullType, "^Tsarcraft%.Cassette") ~= nil
end

local function getRandomCassetteFromCase(caseContainer)
  local caseItems = caseContainer:getItems()
  local cassetteCount = 0

  for i = 0, caseItems:size() - 1 do
    if isCassetteItem(caseItems:get(i)) then
      cassetteCount = cassetteCount + 1
    end
  end

  if cassetteCount == 0 then
    return nil
  end

  local selectedIndex = ZombRand(cassetteCount)
  local cassetteIndex = 0

  for i = 0, caseItems:size() - 1 do
    local cassette = caseItems:get(i)
    if isCassetteItem(cassette) then
      if cassetteIndex == selectedIndex then
        return cassette
      end
      cassetteIndex = cassetteIndex + 1
    end
  end

  return nil
end

local function getMusicId(player)
  if isClient() then
    return player:getOnlineID()
  end
  return player:getUsername()
end

local function startWalkmanPlayback(player, walkman)
  local emitter = player:getEmitter()
  local previousMusicId = player:getModData().tcmusicid

  if previousMusicId then
    emitter:stopSound(previousMusicId)
  end

  player:getModData().tcmusicid = emitter:playSoundImpl(walkman:getModData().tcmusic.mediaItem, nil)
  emitter:setVolume(player:getModData().tcmusicid, walkman:getDeviceData():getDeviceVolume() * 0.4)

  local musicId = getMusicId(player)
  ModData.getOrCreate("trueMusicData")["now_play"][musicId] = {
    volume = walkman:getDeviceData():getDeviceVolume(),
    headphone = walkman:getDeviceData():getHeadphoneType() >= 0,
    timestamp = "update",
    musicName = walkman:getModData().tcmusic.mediaItem,
    itemid = walkman:getID(),
  }
end

local function cycleWalkmanCassette(player, walkman)
  local _, caseContainer = findCassetteCaseInMainInventory(player)
  if not caseContainer then
    return false
  end

  local nextCassette = getRandomCassetteFromCase(caseContainer)
  if not nextCassette then
    return false
  end

  local oldMediaItem = walkman:getModData().tcmusic.mediaItem
  caseContainer:DoRemoveItem(nextCassette)

  local oldCassette = InventoryItemFactory.CreateItem("Tsarcraft." .. oldMediaItem)
  if oldCassette then
    caseContainer:AddItem(oldCassette)
  end

  walkman:getModData().tcmusic.mediaItem = nextCassette:getType()
  walkman:getModData().tcmusic.isPlaying = true

  startWalkmanPlayback(player, walkman)
  return true
end

local function tryAutoCycleWalkmanCassette()
  local player = getPlayer()
  if not player then
    return
  end

  local walkman = getCurrentPlayingWalkman(player)
  if not walkman then
    return
  end

  local tcmusic = walkman:getModData().tcmusic
  if not tcmusic.mediaItem then
    return
  end

  local soundId = player:getModData().tcmusicid
  if not soundId then
    return
  end

  if not player:getEmitter():isPlaying(soundId) then
    local caseItem = findCassetteCaseInMainInventory(player)
    if caseItem and getCasePlaybackMode(caseItem) == CASE_MODE_REPEAT then
      startWalkmanPlayback(player, walkman)
      return
    end

    cycleWalkmanCassette(player, walkman)
  end
end

local original_OnRenderTickClientCheckMusic = OnRenderTickClientCheckMusic

if original_OnRenderTickClientCheckMusic then
  function OnRenderTickClientCheckMusic()
    original_OnRenderTickClientCheckMusic()
    tryAutoCycleWalkmanCassette()
  end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
