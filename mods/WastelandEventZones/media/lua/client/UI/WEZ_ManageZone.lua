
--- @class WEZ_ManageZone
--- @field zone WEZ_EventZone
WEZ_ManageZone = ISPanel:derive("WEZ_ManageZone")

WEZ_ManageZone.instance = nil

function WEZ_ManageZone:show(zone)
    if zone.external then return end
    if WEZ_ManageZone.instance then
        WEZ_ManageZone.instance:onClose()
    end
    local scale = getTextManager():MeasureStringY(UIFont.Small, "XXX") / 12
    local w = 600 * scale
    local h = 100 * scale
    local o = ISPanel:new(getCore():getScreenWidth()/2-w/2,getCore():getScreenHeight()/2-h/2, w, h)
    setmetatable(o, self)
    o.__index = self
    o.zone = zone
    o.scale = scale
    o:initialise()
    o:addToUIManager()
    WEZ_ManageZone.instance = o
    return o
end

function WEZ_ManageZone:initialise()
    ISPanel.initialise(self)
    self.moveWithMouse = true

    local win = GravyUI.Node(self.width, self.height, self)

    local header, tabs = win:rows({25, 1.0}, 5)
    local title, buttons = header:cols({1.0, 150}, 5)
    local deleteButton, saveButton, closeButton = buttons:pad(5, 2, 5, 2):cols(3, 5)

    title:makeLabel("Manage: " .. self.zone.name, UIFont.Large, {r=1,g=1,b=1,a=1}, "center", true)
    self.tabs = ISTabPanel:new(tabs.left, tabs.top, tabs.width, tabs.height)
    deleteButton:makeButton("Delete", self, self.delete)
    saveButton:makeButton("Save", self, self.save)
    closeButton:makeButton("Close", self, self.onClose)

    self.tabContentTop = self.tabs.tabHeight + tabs.top
    self.singleRowHeight = 18 * self.scale
    self.labelWidth = 150 * self.scale
    
    -- Initialize each tab
    self:initGeneralTab()
    self:initZombiesTab()
    self:initPlayersTab()
    self:initMessagesTab()
    self:initWeatherTab()
    self:initRiftsTab()

    self:addChild(self.tabs)
end

-- Initialize the General tab
function WEZ_ManageZone:initGeneralTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth
    
    -- General tab
    local generalTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 5 + 5 * 2)
    generalTab:initialise()
    local generalWin = GravyUI.Node(generalTab.width, generalTab.height, generalTab):pad(5)
    local nameRow, areaRow, teleportRow = generalWin:rows({singleRowHeight, singleRowHeight * 2, singleRowHeight * 2}, 5)
    local nameLabel, nameInput = nameRow:cols({labelWidth, 1.0}, 5)
    local areaLabel, areaInput = areaRow:cols({labelWidth, 1.0}, 5)
    local teleportLabel, teleportSelect, clearTeleportButton = teleportRow:cols({labelWidth, 0.5, 0.5}, 5)
    nameLabel:makeLabel("Name:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    areaLabel:makeLabel("Area:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    teleportLabel:makeLabel("Teleport:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    self.nameInput = nameInput:makeTextBox(self.zone.name)
    self.areaInput = areaInput:makeAreaPicker()
    self.areaInput:setValue({
        x1 = self.zone.minX,
        y1 = self.zone.minY,
        z1 = self.zone.minZ,
        x2 = self.zone.maxX,
        y2 = self.zone.maxY,
        z2 = self.zone.maxZ,
    })
    self.teleportPointInput = teleportSelect:makePointPicker()
    self.teleportPointInput:setValue({
        x = self.zone.teleportX or 0,
        y = self.zone.teleportY or 0,
        z = self.zone.teleportZ or 0,
    })
    self.teleportClearButton = clearTeleportButton:pad(0, singleRowHeight, 0, 0):makeButton("Clear", self, self.clearTeleport)
    self.tabs:addView("General", generalTab)
end

-- Initialize the Zombies tab
function WEZ_ManageZone:initZombiesTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth

    local zombiesTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 12 + 5 * 10)
    zombiesTab:initialise()
    local zombiesWin = GravyUI.Node(zombiesTab.width, zombiesTab.height, zombiesTab):pad(5)
    local noZombiesRow, sprintersRow, fastShamblersRow, slowShamblersRow,
          spawnInterval, spawnCount, spawnMax, spawnRange,
          spawnCatchup, spawnCheckPlayers, spawnPlayerRange, noThumpRow = zombiesWin:rows({
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
    }, 5)
    local noZombiesLabel, noZombiesInput = noZombiesRow:cols({labelWidth, 1.0}, 5)
    local sprintersLabel, sprintersInput = sprintersRow:cols({labelWidth, 1.0}, 5)
    local fastShamblersLabel, fastShamblersInput = fastShamblersRow:cols({labelWidth, 1.0}, 5)
    local slowShamblersLabel, slowShamblersInput = slowShamblersRow:cols({labelWidth, 1.0}, 5)
    local spawnIntervalLabel, spawnIntervalInput = spawnInterval:cols({labelWidth, 1.0}, 5)
    local spawnCountLabel, spawnCountInput = spawnCount:cols({labelWidth, 1.0}, 5)
    local spawnMaxLabel, spawnMaxInput = spawnMax:cols({labelWidth, 1.0}, 5)
    local spawnRangeLabel, spawnRangeInput = spawnRange:cols({labelWidth, 1.0}, 5)
    local spawnCatchupLabel, spawnCatchupInput = spawnCatchup:cols({labelWidth, 1.0}, 5)
    local spawnCheckPlayersLabel, spawnCheckPlayersInput = spawnCheckPlayers:cols({labelWidth, 1.0}, 5)
    local spawnPlayerRangeLabel, spawnPlayerRangeInput = spawnPlayerRange:cols({labelWidth, 1.0}, 5)
    local noThumpLabel, noThumpInput = noThumpRow:cols({labelWidth, 1.0}, 5)
    noZombiesLabel:makeLabel("No Zombies:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    sprintersLabel:makeLabel("Sprinters:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    fastShamblersLabel:makeLabel("Fast Shamblers:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    slowShamblersLabel:makeLabel("Slow Shamblers:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnIntervalLabel:makeLabel("Spawn Interval (seconds):", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCountLabel:makeLabel("Spawn Count (per interval):", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnMaxLabel:makeLabel("Spawn Max:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnRangeLabel:makeLabel("Spawn Max Range:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCatchupLabel:makeLabel("Catchup Spawns:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCheckPlayersLabel:makeLabel("Check for Players:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnPlayerRangeLabel:makeLabel("Player Check Range:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noThumpLabel:makeLabel("No Thump:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    self.noZombiesInput = noZombiesInput:makeTickBox(self.zone.noZombies)
    self.noZombiesInput:addOption("")
    self.sprintersInput = sprintersInput:pad(0, 0, sprintersInput.width - 30, 0):makeTextBox("0")
    self.sprintersInput:setOnlyNumbers(true)
    self.fastShamblersInput = fastShamblersInput:pad(0, 0, fastShamblersInput.width - 30, 0):makeTextBox("0")
    self.fastShamblersInput:setOnlyNumbers(true)
    self.slowShamblersInput = slowShamblersInput:pad(0, 0, slowShamblersInput.width - 30, 0):makeTextBox("0")
    self.slowShamblersInput:setOnlyNumbers(true)
    self.spawnIntervalInput = spawnIntervalInput:pad(0, 0, spawnIntervalInput.width - 60, 0):makeTextBox("0")
    self.spawnIntervalInput:setOnlyNumbers(true)
    self.spawnCountInput = spawnCountInput:pad(0, 0, spawnCountInput.width - 30, 0):makeTextBox("0")
    self.spawnCountInput:setOnlyNumbers(true)
    self.spawnMaxInput = spawnMaxInput:pad(0, 0, spawnMaxInput.width - 30, 0):makeTextBox("0")
    self.spawnMaxInput:setOnlyNumbers(true)
    self.spawnRangeInput = spawnRangeInput:pad(0, 0, spawnRangeInput.width - 30, 0):makeTextBox("0")
    self.spawnRangeInput:setOnlyNumbers(true)
    self.spawnCatchupInput = spawnCatchupInput:makeTickBox(self.zone.spawnCatchup)
    self.spawnCatchupInput:addOption("")
    self.spawnCheckPlayersInput = spawnCheckPlayersInput:makeTickBox(self.zone.spawnCheckPlayers)
    self.spawnCheckPlayersInput:addOption("")
    self.spawnPlayerRangeInput = spawnPlayerRangeInput:pad(0, 0, spawnPlayerRangeInput.width - 30, 0):makeTextBox("0")
    self.spawnPlayerRangeInput:setOnlyNumbers(true)
    self.noThumpInput = noThumpInput:makeTickBox(self.zone.noThump)
    self.noThumpInput:addOption("")
    if self.zone.preventZombies then
        self.noZombiesInput:setSelected(1, true)
    end
    if self.zone.killZombies then
        self.killZombiesInput:setSelected(1, true)
    end
    if self.zone.spawnCatchup then
        self.spawnCatchupInput:setSelected(1, true)
    end
    if self.zone.spawnCheckPlayers then
        self.spawnCheckPlayersInput:setSelected(1, true)
    end
    self.sprintersInput:setText(tostring(self.zone.percentageSprinters))
    self.fastShamblersInput:setText(tostring(self.zone.percentageFastShamblers))
    self.slowShamblersInput:setText(tostring(self.zone.percentageSlowShamblers))
    self.spawnIntervalInput:setText(tostring(self.zone.spawnInterval))
    self.spawnCountInput:setText(tostring(self.zone.spawnCount))
    self.spawnMaxInput:setText(tostring(self.zone.spawnMax))
    self.spawnRangeInput:setText(tostring(self.zone.spawnRange))
    self.spawnPlayerRangeInput:setText(tostring(self.zone.spawnPlayerRange))
    if self.zone.noThump then
        self.noThumpInput:setSelected(1, true)
    end

    self.noZombiesInput.tooltip = "Removes all zombies from this zone."
    self.killZombiesInput.tooltip = "Kills all zombies in this zone."
    self.sprintersInput.tooltip = "Percentage of zombies that will be sprinters."
    self.fastShamblersInput.tooltip = "Percentage of zombies that will be fast shamblers."
    self.slowShamblersInput.tooltip = "Percentage of zombies that will be slow shamblers."
    self.spawnIntervalInput.tooltip = "If > 0, enabled automated zombie spawns in this zone every X seconds."
    self.spawnCountInput.tooltip = "Number of zombies to spawn per interval."
    self.spawnMaxInput.tooltip = "Maximum number of zombies that can be in this zone at once before no more spawn."
    self.spawnRangeInput.tooltip = "Number of tiles outside the zone to count zombies for maximum spawn."
    self.spawnCatchupInput.tooltip = "If enabled, the zone will spawn all zombies which should have spawned while zone is unloaded."
    self.spawnCheckPlayersInput.tooltip = "If enabled, the zone will stop spawning if players are inside the range."
    self.spawnPlayerRangeInput.tooltip = "Range to check for players when spawnCheckPlayers is enabled."
    self.noThumpInput.tooltip = "If enabled, built structures will not be thumpable. Takes a moment to apply. Newly built structures may take up to an in-game hour to update. Save the event zone to force a faster update."

    self.tabs:addView("Zombies", zombiesTab)
end

-- Initialize the Players tab
function WEZ_ManageZone:initPlayersTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth

    local playersTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 25 + 5 * 16)
    playersTab:initialise()
    local playersWin = GravyUI.Node(playersTab.width, playersTab.height, playersTab):pad(5)
    local adminOnlyRow, playerGatedToggleRow, playerGatedRow, playerGatedItemRow, 
    rpZoneRow, noDamageRow, noFishingRow, quietZoneRow, scrapZoneRow, noDeforestRow, noBuildRow,
    noPickupRow, lockedMannequins, weatherTransitionTicksRow, jailZoneRow, freeDeathRow, 
    unlimitedWaterRow, damageRateRow, damagePreventToggleRow,
    damagePreventItemsRow, moodleIncreaseRow, moodleIncreaseRateRow = playersWin:rows({
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight
    }, 5)
    local adminOnlyLabel, adminOnlyInput = adminOnlyRow:cols({labelWidth, 1.0}, 5)
    local playerGatedToggleLabel, playerGatedToggleInput = playerGatedToggleRow:cols({labelWidth, 0.1, 0.9}, 5)
    local playerGatedLabel, playerGatedInput, playerGatedTextInput = playerGatedRow:cols({labelWidth, 0.1, 0.9}, 5)
    local playerGatedItemLabel, playerGatedItemInput, playerGatedItemTextInput, playerGatedItemNameInput = playerGatedItemRow:cols({labelWidth, 0.1, 0.45, 0.45}, 5)
    local rpZoneLabel, rpZoneInput = rpZoneRow:cols({labelWidth, 1.0}, 5)
    local noDamageLabel, noDamageInput = noDamageRow:cols({labelWidth, 1.0}, 5)
    local noFishingLabel, noFishingInput = noFishingRow:cols({labelWidth, 1.0}, 5)
    local quietZoneLabel, quietZoneInput = quietZoneRow:cols({labelWidth, 1.0}, 5)
    local scrapZoneLabel, scrapZoneInput = scrapZoneRow:cols({labelWidth, 1.0}, 5)
    local noDeforestLabel, noDeforestInput = noDeforestRow:cols({labelWidth, 1.0}, 5)
    local noBuildLabel, noBuildInput = noBuildRow:cols({labelWidth, 1.0}, 5)
    local noPickupLabel, noPickupInput = noPickupRow:cols({labelWidth, 1.0}, 5)
    local lockedMannequinsLabel, lockedMannequinsInput = lockedMannequins:cols({labelWidth, 1.0}, 5)
    local weatherTransitionTicksLabel, weatherTransitionTicksInput = weatherTransitionTicksRow:cols({labelWidth, 1.0}, 5)
    local jailZoneLabel, jailZoneInput = jailZoneRow:cols({labelWidth, 1.0}, 5)
    local freeDeathLabel, freeDeathInput = freeDeathRow:cols({labelWidth, 1.0}, 5)
    local unlimitedWaterLabel, unlimitedWaterInput = unlimitedWaterRow:cols({labelWidth, 1.0}, 5)
    local damageRateLabel, damageRateInput = damageRateRow:cols({labelWidth, 1.0}, 5)
    local damagePreventToggleLabel, damagePreventToggleInput = damagePreventToggleRow:cols({labelWidth, 1.0}, 5)
    local damagePreventItemsLabel, damagePreventItemsInput = damagePreventItemsRow:cols({labelWidth, 1.0}, 5)
    local moddleIncreaseLabel, moodleIncreaseDropdown = moodleIncreaseRow:cols({labelWidth, 1.0}, 5)
    local moodleIncreaseRateLabel, moodleIncreaseRateInput = moodleIncreaseRateRow:cols({labelWidth, 1.0}, 5)
    adminOnlyLabel:makeLabel("Staff Only:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    playerGatedToggleLabel:makeLabel("Player Gated White/Blacklist:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    playerGatedLabel:makeLabel("Player Gated:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    playerGatedItemLabel:makeLabel("Player Gated Item:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    rpZoneLabel:makeLabel("RP Zone:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noDamageLabel:makeLabel("No Damage:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noFishingLabel:makeLabel("No Fishing:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    quietZoneLabel:makeLabel("Quiet Zone:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    scrapZoneLabel:makeLabel("Scrap Zone:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noDeforestLabel:makeLabel("No Deforest:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noBuildLabel:makeLabel("No Build:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noPickupLabel:makeLabel("No Pickup:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    lockedMannequinsLabel:makeLabel("Locked Mannequins:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    weatherTransitionTicksLabel:makeLabel("Weather Transition Ticks:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    jailZoneLabel:makeLabel("Jail Zone:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    freeDeathLabel:makeLabel("Free Deaths:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    unlimitedWaterLabel:makeLabel("Unlimited Water:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    damageRateLabel:makeLabel("Damage Rate:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    damagePreventToggleLabel:makeLabel("Damage Prevent Masks:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    damagePreventItemsLabel:makeLabel("Damage Prevent IDs:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    moddleIncreaseLabel:makeLabel("Moodle Increase:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    moodleIncreaseRateLabel:makeLabel("Moodle Increase Rate:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")


    self.adminOnlyInput = adminOnlyInput:makeTickBox()
    self.adminOnlyInput:addOption("")
    self.playerGatedToggleInput = playerGatedToggleInput:makeTickBox()
    self.playerGatedToggleInput:addOption("")
    self.playerGatedInput = playerGatedInput:makeTickBox()
    self.playerGatedInput:addOption("")
    self.playerGatedTextInput = playerGatedTextInput:makeTextBox(self.zone.playersGated or "")
    self.playerGatedItemInput = playerGatedItemInput:makeTickBox()
    self.playerGatedItemInput:addOption("")
    self.playerGatedItemTextInput = playerGatedItemTextInput:makeTextBox(self.zone.playerItemGated or "")
    self.playerGatedItemNameInput = playerGatedItemNameInput:makeTextBox(self.zone.playerItemNameGated or "")
    self.rpZoneInput = rpZoneInput:makeTickBox()
    self.rpZoneInput:addOption("")
    self.noDamageInput = noDamageInput:makeTickBox()
    self.noDamageInput:addOption("")
    self.noFishingInput = noFishingInput:makeTickBox()
    self.noFishingInput:addOption("")
    self.quietZoneInput = quietZoneInput:makeTickBox()
    self.quietZoneInput:addOption("")
    self.scrapZoneInput = scrapZoneInput:makeTickBox()
    self.scrapZoneInput:addOption("")
    self.noDeforestInput = noDeforestInput:makeTickBox()
    self.noDeforestInput:addOption("")
    self.noBuildInput = noBuildInput:makeTickBox()
    self.noBuildInput:addOption("")
    self.noPickupInput = noPickupInput:makeTickBox()
    self.noPickupInput:addOption("")
    self.lockedMannequinsInput = lockedMannequinsInput:makeTickBox()
    self.lockedMannequinsInput:addOption("")
    self.weatherTransitionTicksInput = weatherTransitionTicksInput:pad(0, 0, weatherTransitionTicksInput.width - 30, 0):makeTextBox(tostring(self.zone.weatherTransitionTicks or 0))
    self.weatherTransitionTicksInput:setOnlyNumbers(true)
    self.jailZoneInput = jailZoneInput:makeTickBox()
    self.jailZoneInput:addOption("")
    self.freeDeathInput = freeDeathInput:makeTickBox()
    self.freeDeathInput:addOption("")
    self.unlimitedWaterInput = unlimitedWaterInput:makeTickBox()
    self.unlimitedWaterInput:addOption("")
    self.damageRateInput = damageRateInput:pad(0, 0, damageRateInput.width - 30, 0):makeTextBox(tostring(self.zone.damageRate))
    self.damageRateInput:setOnlyNumbers(true)
    self.damagePreventToggleInput = damagePreventToggleInput:makeTickBox()
    self.damagePreventToggleInput:addOption("")
    self.damagePreventItemsInput = damagePreventItemsInput:makeTextBox(self.zone.damagePreventItems or "")
    self.moodleIncreaseDropdown = moodleIncreaseDropdown:makeComboBox()
    self.moodleIncreaseDropdown:addOption("None")
    self.moodleIncreaseDropdown:addOption("Boredom")
    self.moodleIncreaseDropdown:addOption("Hungry")
    self.moodleIncreaseDropdown:addOption("Pain")
    self.moodleIncreaseDropdown:addOption("Panic")
    self.moodleIncreaseDropdown:addOption("Stress")
    self.moodleIncreaseDropdown:addOption("Thirsty")
    self.moodleIncreaseDropdown:addOption("Unhappiness")

    self.moodleIncreaseRateInput = moodleIncreaseRateInput:pad(0, 0, moodleIncreaseRateInput.width - 30, 0):makeTextBox(tostring(self.zone.moodleIncreaseRate))
    self.adminOnlyInput:setSelected(1, self.zone.isAdminOnly)
    self.playerGatedToggleInput:setSelected(1, self.zone.isPlayerGatedToggle)
    self.playerGatedInput:setSelected(1, self.zone.isPlayerGated)
    self.playerGatedItemInput:setSelected(1, self.zone.isPlayerGatedItem)
    self.rpZoneInput:setSelected(1, self.zone.isRpZone)
    self.noDamageInput:setSelected(1, self.zone.noDamage)
    self.noFishingInput:setSelected(1, self.zone.noFishing)
    self.quietZoneInput:setSelected(1, self.zone.quietZone)
    self.scrapZoneInput:setSelected(1, self.zone.isScrapZone)
    self.noDeforestInput:setSelected(1, self.zone.noDeforest)
    self.noBuildInput:setSelected(1, self.zone.noBuild)
    self.noPickupInput:setSelected(1, self.zone.noPickup)
    self.lockedMannequinsInput:setSelected(1, self.zone.lockedMannequins)
    self.jailZoneInput:setSelected(1, self.zone.isJail)
    self.freeDeathInput:setSelected(1, self.zone.freeDeathZone)
    self.unlimitedWaterInput:setSelected(1, self.zone.unlimitedWater)
    self.damagePreventToggleInput:setSelected(1, self.zone.damagePreventToggle)
    self.moodleIncreaseDropdown.selected = self.zone.moodleIncrease

    self.adminOnlyInput.tooltip = "Only admins can enter this zone. Players will be teleported outside the zone automatically."
    self.playerGatedToggleInput.tooltip = "If disabled, the player gated list will be used as a whitelist. If enabled, the player gated list will be used as a blacklist."
    self.playerGatedInput.tooltip = "Only players in the list can enter this zone. Players not on the list will be teleported outside the zone automatically."
    self.playerGatedTextInput.tooltip = "Comma separated list of player names. Case sensitive."
    self.playerGatedItemInput.tooltip = "Only players with the item in their inventory can enter this zone. Players without the item will be teleported outside the zone automatically."
    self.playerGatedItemTextInput.tooltip = "Can include one or many. \n Comma separated list of item full types e.g. Base.CreditCard, Base.Bell"
    self.playerGatedItemNameInput.tooltip = "OPTIONAL. If you have more than one item listed, this field will do nothing. \n Name of the item that players must have in their inventory to enter this zone. e.g. Mine Pass"
    self.rpZoneInput.tooltip = "Prevents hunger, thirst, boredom, and unhappiness from increasing."
    self.noDamageInput.tooltip = "Players will have damage negated while in this zone. Only applies if player is fully healthy when entering."
    self.noFishingInput.tooltip = "Players will not be able to fish in this zone."
    self.quietZoneInput.tooltip = "Defaults players chat to /quiet or /mequiet."
    self.scrapZoneInput.tooltip = "Players can scrap items in this zone without using tile tokens."
    self.noDeforestInput.tooltip = "Players will not be able to deforest trees in this zone."
    self.noBuildInput.tooltip = "Players will not be able to build in this zone. They will still be able to place furniture."
    self.noPickupInput.tooltip = "Players will not be able to pick up objects in this zone."
    self.lockedMannequinsInput.tooltip = "If enabled, mannequins will not be able to be accessed in this zone."
    self.jailZoneInput.tooltip = "Players will be locked into this zone."
    self.freeDeathInput.tooltip = "Players will not lose XP or skills when dying in this zone."
    self.unlimitedWaterInput.tooltip = "If enabled, 'plumbed' objects will always have full water."
    self.damageRateInput.tooltip = "If > 0, players will take damage every X damage every tick while in this zone. SET LOW AND TEST."
    self.damagePreventToggleInput.tooltip = "If enabled, players will not take damage while wearing Gas Masks or Hazmat Suits."
    self.damagePreventItemsInput.tooltip = "Comma separated list of item IDs that if worn that will prevent damage from the damageRate setting."
    self.moodleIncreaseRateInput.tooltip = "Min rate is 0. Max rate is 100. \nBoredom is a flat rate, the rate you input doesn't matter. \nPain is a threshhold of 15, 25, 30, and above. \nEverything else is based off the rate you input."

    self.tabs:addView("Players", playersTab)
end

-- Initialize the Messages tab
function WEZ_ManageZone:initMessagesTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth

    local messagesTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 9 + 5 * 8)
    messagesTab:initialise()
    local messagesWin = GravyUI.Node(messagesTab.width, messagesTab.height, messagesTab):pad(5)
    local warningMessageRangeRow, warningMessageRow, enterMessageRow, exitMessageRow, inCarsRow, inCarsMessageRow, rpText = messagesWin:rows({
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight*4
    }, 5)
    local warningMessageRangeLabel, warningMessageRangeInput = warningMessageRangeRow:cols({labelWidth, 1.0}, 5)
    local warningMessageLabel, warningMessageInput = warningMessageRow:cols({labelWidth, 1.0}, 5)
    local enterMessageLabel, enterMessageInput = enterMessageRow:cols({labelWidth, 1.0}, 5)
    local exitMessageLabel, exitMessageInput = exitMessageRow:cols({labelWidth, 1.0}, 5)
    local inCarsLabel, inCarsInput = inCarsRow:cols({labelWidth, 1.0}, 5)
    local inCarsMessageLabel, inCarsMessageInput = inCarsMessageRow:cols({labelWidth, 1.0}, 5)
    local rpTextLabel, rpTextInput = rpText:cols({labelWidth, 1.0}, 5)
    warningMessageRangeLabel:makeLabel("Warning Range:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    warningMessageLabel:makeLabel("Warning Message:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    enterMessageLabel:makeLabel("Enter Message:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    exitMessageLabel:makeLabel("Exit Message:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    inCarsLabel:makeLabel("In Cars:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    inCarsMessageLabel:makeLabel("In Cars Message:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    rpTextLabel:makeLabel("RP Text:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    self.warningMessageRangeInput = warningMessageRangeInput:pad(0, 0, warningMessageRangeInput.width - 30, 0):makeTextBox(tostring(self.zone.warningBuffer))
    self.warningMessageRangeInput:setOnlyNumbers(true)
    self.warningMessageInput = warningMessageInput:makeTextBox(self.zone.warningMessage)
    self.enterMessageInput = enterMessageInput:makeTextBox(self.zone.enterMessage)
    self.exitMessageInput = exitMessageInput:makeTextBox(self.zone.exitMessage)
    self.inCarsInput = inCarsInput:makeTickBox()
    self.inCarsInput:addOption("")
    self.inCarsMessageInput = inCarsMessageInput:makeTextBox(self.zone.inCarsMessage)
    self.inCarsInput:setSelected(1, self.zone.inCars)
    self.rpTextInput = rpTextInput:makeTextBox(self.zone.rpText)
    self.rpTextInput:setMaxLines(4)
    self.rpTextInput:setMultipleLine(true)
    self.tabs:addView("Messages", messagesTab)
end

-- Initialize the Rifts tab
function WEZ_ManageZone:initRiftsTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth

    local riftsTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 6 + 5 * 5)
    riftsTab:initialise()
    local riftsWin = GravyUI.Node(riftsTab.width, riftsTab.height, riftsTab):pad(5)
    local noRiftZoneRow, riftSpawnChanceRow, riftMinCountRow, riftMaxCountRow, riftMinRateRow, riftMaxRateRow = riftsWin:rows({
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight
    }, 5)

    local noRiftZoneLabel, noRiftZoneInput = noRiftZoneRow:cols({labelWidth, 1.0}, 5)
    local riftSpawnChanceLabel, riftSpawnChanceInput = riftSpawnChanceRow:cols({labelWidth, 1.0}, 5)
    local riftMinCountLabel, riftMinCountInput = riftMinCountRow:cols({labelWidth, 1.0}, 5)
    local riftMaxCountLabel, riftMaxCountInput = riftMaxCountRow:cols({labelWidth, 1.0}, 5)
    local riftMinRateLabel, riftMinRateInput = riftMinRateRow:cols({labelWidth, 1.0}, 5)
    local riftMaxRateLabel, riftMaxRateInput = riftMaxRateRow:cols({labelWidth, 1.0}, 5)

    noRiftZoneLabel:makeLabel("No Rift Zone:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    riftSpawnChanceLabel:makeLabel("Rift Spawn Chance:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    riftMinCountLabel:makeLabel("Rift Min Count:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    riftMaxCountLabel:makeLabel("Rift Max Count:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    riftMinRateLabel:makeLabel("Rift Min Rate:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    riftMaxRateLabel:makeLabel("Rift Max Rate:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")

    self.noRiftZoneInput = noRiftZoneInput:makeTickBox(self.zone.noRiftZone)
    self.noRiftZoneInput:addOption("")
    self.noRiftZoneInput:setSelected(1, self.zone.noRiftZone)

    self.riftSpawnChanceInput = riftSpawnChanceInput:pad(0, 0, riftSpawnChanceInput.width - 30, 0):makeTextBox(tostring(self.zone.riftSpawnChance))
    self.riftSpawnChanceInput:setOnlyNumbers(true)

    self.riftMinCountInput = riftMinCountInput:pad(0, 0, riftMinCountInput.width - 30, 0):makeTextBox(tostring(self.zone.riftMinCount))
    self.riftMinCountInput:setOnlyNumbers(true)

    self.riftMaxCountInput = riftMaxCountInput:pad(0, 0, riftMaxCountInput.width - 30, 0):makeTextBox(tostring(self.zone.riftMaxCount))
    self.riftMaxCountInput:setOnlyNumbers(true)

    self.riftMinRateInput = riftMinRateInput:pad(0, 0, riftMinRateInput.width - 30, 0):makeTextBox(tostring(self.zone.riftMinRate))
    self.riftMinRateInput:setOnlyNumbers(true)

    self.riftMaxRateInput = riftMaxRateInput:pad(0, 0, riftMaxRateInput.width - 30, 0):makeTextBox(tostring(self.zone.riftMaxRate))
    self.riftMaxRateInput:setOnlyNumbers(true)

    self.noRiftZoneInput.tooltip = "If enabled, auto rifts will never spawn in this zone."
    self.riftSpawnChanceInput.tooltip = "Chance that a rift spawns on a player every 1 real life minute."
    self.riftMinCountInput.tooltip = "Min number of zombies for rifts in this zone."
    self.riftMaxCountInput.tooltip = "Max number of zombies for rifts in this zone."
    self.riftMinRateInput.tooltip = "Min zombies per second for rifts in this zone."
    self.riftMaxRateInput.tooltip = "Max zombies per second for rifts in this zone."

    self.tabs:addView("Rifts", riftsTab)
end

-- Initialize the Weather tab
function WEZ_ManageZone:initWeatherTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth

    local weatherTab = ISAdmPanelClimate:new(0, 0, self.tabs.width, 540)
    weatherTab:initialise()
    weatherTab.prerender = function(_s) end
    weatherTab.onClick = function() end
    weatherTab.onMadeActive = function() end
    weatherTab.onTicked = function() end
    weatherTab.onSliderChange = function() end
    weatherTab.oCreateChildren = weatherTab.createChildren
    weatherTab.createChildren = function (_s)
        _s:oCreateChildren()

        for _, child in pairs(_s.children) do
            if child.Type == "ISButton" then
                _s:removeChild(child)
            end
        end

        _s.tickBoxWind:setSelected(1, self.zone.weatherWindEnabled)
        _s.tickBoxClouds:setSelected(1, self.zone.weatherCloudsEnabled)
        _s.tickBoxFog:setSelected(1, self.zone.weatherFogEnabled)
        _s.tickBoxPrecip:setSelected(1, self.zone.weatherPrecipitationEnabled)
        _s.tickBoxPrecipIsSnow:setSelected(1, self.zone.weatherPrecipitationIsSnow)
        _s.tickBoxTemp:setSelected(1, self.zone.weatherTemperatureEnabled)
        _s.tickBoxDarkness:setSelected(1, self.zone.weatherDarknessEnabled)
        _s.tickBoxDesaturation:setSelected(1, self.zone.weatherDesaturationEnabled)
        _s.tickBoxLightR_ext:setSelected(1, self.zone.weatherLightEnabled)

        _s.sliderWindSlider:setCurrentValue(self.zone.weatherWind)
        _s.sliderCloudsSlider:setCurrentValue(self.zone.weatherClouds)
        _s.sliderFogSlider:setCurrentValue(self.zone.weatherFog)
        _s.sliderPrecipSlider:setCurrentValue(self.zone.weatherPrecipitation)
        _s.sliderTempSlider:setCurrentValue(self.zone.weatherTemperature)
        _s.sliderDarknessSlider:setCurrentValue(self.zone.weatherDarkness)
        _s.sliderDesaturationSlider:setCurrentValue(self.zone.weatherDesaturation)
        _s.sliderLightR_extSlider:setCurrentValue(self.zone.weatherLightExtR)
        _s.sliderLightG_extSlider:setCurrentValue(self.zone.weatherLightExtG)
        _s.sliderLightB_extSlider:setCurrentValue(self.zone.weatherLightExtB)
        _s.sliderLightA_extSlider:setCurrentValue(self.zone.weatherLightExtA)
        _s.sliderLightR_intSlider:setCurrentValue(self.zone.weatherLightIntR)
        _s.sliderLightG_intSlider:setCurrentValue(self.zone.weatherLightIntG)
        _s.sliderLightB_intSlider:setCurrentValue(self.zone.weatherLightIntB)
        _s.sliderLightA_intSlider:setCurrentValue(self.zone.weatherLightIntA)
    end
    self.weatherTab = weatherTab
    self.tabs:addView("Weather", weatherTab)
end

function WEZ_ManageZone:onClose()
    self:close()
    WEZ_ManageZone.instance = nil
    self.areaInput:cleanup()
    self.teleportPointInput:cleanup()
end

function WEZ_ManageZone:prerender()
    ISPanel.prerender(self)
    local targetHeight = self.tabContentTop + self.tabs:getActiveView().height
    if self.height ~= targetHeight then
        self:setHeight(targetHeight)
        self.tabs:setHeight(self.height - self.tabContentTop + self.tabs.tabHeight)
    end
    if self.tabs:getActiveViewIndex() == 1 and not self.areaInput.showAlways then
        self.areaInput.showAlways = true
        self.areaInput:_updateGroundHighlight()

        self.teleportPointInput.showAlways = true
        self.teleportPointInput:_updateGroundHighlight()
    elseif self.tabs:getActiveViewIndex() ~= 1 and self.areaInput.showAlways then
        self.areaInput.showAlways = false
        self.areaInput:_updateGroundHighlight()

        self.teleportPointInput.showAlways = false
        self.teleportPointInput:_updateGroundHighlight()
    end
end

function WEZ_ManageZone:render()
    ISPanel.render(self)
end

-- Initialize the Zombies tab
function WEZ_ManageZone:initZombiesTab()
    local singleRowHeight = self.singleRowHeight
    local labelWidth = self.labelWidth
    
    -- Zombies tab
    local zombiesTab = ISPanel:new(0, 0, self.tabs.width, self.tabs.tabHeight + singleRowHeight * 13 + 5 * 10)
    zombiesTab:initialise()
    local zombiesWin = GravyUI.Node(zombiesTab.width, zombiesTab.height, zombiesTab):pad(5)
    local noZombiesRow, killZombiesRow, sprintersRow, fastShamblersRow, slowShamblersRow,
          spawnInterval, spawnCount, spawnMax, spawnRange,
          spawnCatchup, spawnCheckPlayers, spawnPlayerRange, noThumpRow = zombiesWin:rows({
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
        singleRowHeight, singleRowHeight, singleRowHeight, singleRowHeight,
    }, 5)
    
    local noZombiesLabel, noZombiesInput = noZombiesRow:cols({labelWidth, 1.0}, 5)
    local killZombiesLabel, killZombiesInput = killZombiesRow:cols({labelWidth, 1.0}, 5)
    local sprintersLabel, sprintersInput = sprintersRow:cols({labelWidth, 1.0}, 5)
    local fastShamblersLabel, fastShamblersInput = fastShamblersRow:cols({labelWidth, 1.0}, 5)
    local slowShamblersLabel, slowShamblersInput = slowShamblersRow:cols({labelWidth, 1.0}, 5)
    local spawnIntervalLabel, spawnIntervalInput = spawnInterval:cols({labelWidth, 1.0}, 5)
    local spawnCountLabel, spawnCountInput = spawnCount:cols({labelWidth, 1.0}, 5)
    local spawnMaxLabel, spawnMaxInput = spawnMax:cols({labelWidth, 1.0}, 5)
    local spawnRangeLabel, spawnRangeInput = spawnRange:cols({labelWidth, 1.0}, 5)
    local spawnCatchupLabel, spawnCatchupInput = spawnCatchup:cols({labelWidth, 1.0}, 5)
    local spawnCheckPlayersLabel, spawnCheckPlayersInput = spawnCheckPlayers:cols({labelWidth, 1.0}, 5)
    local spawnPlayerRangeLabel, spawnPlayerRangeInput = spawnPlayerRange:cols({labelWidth, 1.0}, 5)
    local noThumpLabel, noThumpInput = noThumpRow:cols({labelWidth, 1.0}, 5)
    
    noZombiesLabel:makeLabel("No Zombies:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    killZombiesLabel:makeLabel("Kill Zombies:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    sprintersLabel:makeLabel("Sprinters:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    fastShamblersLabel:makeLabel("Fast Shamblers:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    slowShamblersLabel:makeLabel("Slow Shamblers:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnIntervalLabel:makeLabel("Spawn Interval (seconds):", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCountLabel:makeLabel("Spawn Count (per interval):", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnMaxLabel:makeLabel("Spawn Max:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnRangeLabel:makeLabel("Spawn Max Range:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCatchupLabel:makeLabel("Catchup Spawns:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnCheckPlayersLabel:makeLabel("Check for Players:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    spawnPlayerRangeLabel:makeLabel("Player Check Range:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    noThumpLabel:makeLabel("No Thump:", UIFont.Small, {r=1,g=1,b=1,a=1}, "left")
    
    self.noZombiesInput = noZombiesInput:makeTickBox(self.zone.noZombies)
    self.noZombiesInput:addOption("")
    self.killZombiesInput = killZombiesInput:makeTickBox(self.zone.killZombies)
    self.killZombiesInput:addOption("")
    self.sprintersInput = sprintersInput:pad(0, 0, sprintersInput.width - 30, 0):makeTextBox("0")
    self.sprintersInput:setOnlyNumbers(true)
    self.fastShamblersInput = fastShamblersInput:pad(0, 0, fastShamblersInput.width - 30, 0):makeTextBox("0")
    self.fastShamblersInput:setOnlyNumbers(true)
    self.slowShamblersInput = slowShamblersInput:pad(0, 0, slowShamblersInput.width - 30, 0):makeTextBox("0")
    self.slowShamblersInput:setOnlyNumbers(true)
    self.spawnIntervalInput = spawnIntervalInput:pad(0, 0, spawnIntervalInput.width - 60, 0):makeTextBox("0")
    self.spawnIntervalInput:setOnlyNumbers(true)
    self.spawnCountInput = spawnCountInput:pad(0, 0, spawnCountInput.width - 30, 0):makeTextBox("0")
    self.spawnCountInput:setOnlyNumbers(true)
    self.spawnMaxInput = spawnMaxInput:pad(0, 0, spawnMaxInput.width - 30, 0):makeTextBox("0")
    self.spawnMaxInput:setOnlyNumbers(true)
    self.spawnRangeInput = spawnRangeInput:pad(0, 0, spawnRangeInput.width - 30, 0):makeTextBox("0")
    self.spawnRangeInput:setOnlyNumbers(true)
    self.spawnCatchupInput = spawnCatchupInput:makeTickBox(self.zone.spawnCatchup)
    self.spawnCatchupInput:addOption("")
    self.spawnCheckPlayersInput = spawnCheckPlayersInput:makeTickBox(self.zone.spawnCheckPlayers)
    self.spawnCheckPlayersInput:addOption("")
    self.spawnPlayerRangeInput = spawnPlayerRangeInput:pad(0, 0, spawnPlayerRangeInput.width - 30, 0):makeTextBox("0")
    self.spawnPlayerRangeInput:setOnlyNumbers(true)
    self.noThumpInput = noThumpInput:makeTickBox(self.zone.noThump)
    self.noThumpInput:addOption("")
    
    -- Set initial values
    if self.zone.preventZombies then
        self.noZombiesInput:setSelected(1, true)
    end
    if self.zone.spawnCatchup then
        self.spawnCatchupInput:setSelected(1, true)
    end
    if self.zone.spawnCheckPlayers then
        self.spawnCheckPlayersInput:setSelected(1, true)
    end
    self.sprintersInput:setText(tostring(self.zone.percentageSprinters))
    self.fastShamblersInput:setText(tostring(self.zone.percentageFastShamblers))
    self.slowShamblersInput:setText(tostring(self.zone.percentageSlowShamblers))
    self.spawnIntervalInput:setText(tostring(self.zone.spawnInterval))
    self.spawnCountInput:setText(tostring(self.zone.spawnCount))
    self.spawnMaxInput:setText(tostring(self.zone.spawnMax))
    self.spawnRangeInput:setText(tostring(self.zone.spawnRange))
    self.spawnPlayerRangeInput:setText(tostring(self.zone.spawnPlayerRange))
    if self.zone.noThump then
        self.noThumpInput:setSelected(1, true)
    end

    -- Set tooltips
    self.noZombiesInput.tooltip = "Removes all zombies from this zone."
    self.sprintersInput.tooltip = "Percentage of zombies that will be sprinters."
    self.fastShamblersInput.tooltip = "Percentage of zombies that will be fast shamblers."
    self.slowShamblersInput.tooltip = "Percentage of zombies that will be slow shamblers."
    self.spawnIntervalInput.tooltip = "If > 0, enabled automated zombie spawns in this zone every X seconds."
    self.spawnCountInput.tooltip = "Number of zombies to spawn per interval."
    self.spawnMaxInput.tooltip = "Maximum number of zombies that can be in this zone at once before no more spawn."
    self.spawnRangeInput.tooltip = "Number of tiles outside the zone to count zombies for maximum spawn."
    self.spawnCatchupInput.tooltip = "If enabled, the zone will spawn all zombies which should have spawned while zone is unloaded."
    self.spawnCheckPlayersInput.tooltip = "If enabled, the zone will stop spawning if players are inside the range."
    self.spawnPlayerRangeInput.tooltip = "Range to check for players when spawnCheckPlayers is enabled."
    self.noThumpInput.tooltip = "If enabled, built structures will not be thumpable. Takes a moment to apply. Newly built structures may take up to an in-game hour to update. Save the event zone to force a faster update."

    self.tabs:addView("Zombies", zombiesTab)
end

function WEZ_ManageZone:clearTeleport()
    self.teleportPointInput:setValue({x=0, y=0, z=0})
end

function WEZ_ManageZone:delete()
    self.zone:delete()
    self:onClose()
end

function WEZ_ManageZone:save()
    --general
    self.zone.name = self.nameInput:getText()
    local area = self.areaInput:getValue()
    self.zone.minX = area.x1
    self.zone.minY = area.y1
    self.zone.minZ = area.z1
    self.zone.maxX = area.x2
    self.zone.maxY = area.y2
    self.zone.maxZ = area.z2
    local teleport = self.teleportPointInput:getValue()
    self.zone.teleportX = teleport.x
    self.zone.teleportY = teleport.y
    self.zone.teleportZ = teleport.z

    --players
    self.zone.isAdminOnly = self.adminOnlyInput:isSelected(1)
    self.zone.isPlayerGatedToggle = self.playerGatedToggleInput:isSelected(1)
    self.zone.isPlayerGated = self.playerGatedInput:isSelected(1)
    self.zone.playersGated = self.playerGatedTextInput:getText()
    self.zone.isPlayerGatedItem = self.playerGatedItemInput:isSelected(1)
    self.zone.playerItemGated = self.playerGatedItemTextInput:getText()
    self.zone.playerItemNameGated = self.playerGatedItemNameInput:getText()
    self.zone.isRpZone = self.rpZoneInput:isSelected(1)
    self.zone.noDamage = self.noDamageInput:isSelected(1)
    self.zone.noFishing = self.noFishingInput:isSelected(1)
    self.zone.isQuiet = self.quietZoneInput:isSelected(1)
    self.zone.isScrapZone = self.scrapZoneInput:isSelected(1)
    self.zone.noDeforest = self.noDeforestInput:isSelected(1)
    self.zone.noBuild = self.noBuildInput:isSelected(1)
    self.zone.noPickup = self.noPickupInput:isSelected(1)
    self.zone.lockedMannequins = self.lockedMannequinsInput:isSelected(1)
    self.zone.weatherTransitionTicks = tonumber(self.weatherTransitionTicksInput:getText() or "0") or 0
    self.zone.isJail = self.jailZoneInput:isSelected(1)
    self.zone.freeDeathZone = self.freeDeathInput:isSelected(1)
    self.zone.unlimitedWater = self.unlimitedWaterInput:isSelected(1)
    self.zone.damageRate = tonumber(self.damageRateInput:getText() or "0") or 0
    self.zone.damagePreventToggle = self.damagePreventToggleInput:isSelected(1)
    self.zone.damagePreventItems = self.damagePreventItemsInput:getText()
    self.zone.moodleIncrease = self.moodleIncreaseDropdown.selected
    self.zone.moodleIncreaseRate = tonumber(self.moodleIncreaseRateInput:getText() or "0") or 0

    --zombies
    self.zone.preventZombies = self.noZombiesInput:isSelected(1)
    self.zone.killZombies = self.killZombiesInput:isSelected(1)
    self.zone.percentageSprinters = tonumber(self.sprintersInput:getText() or "0") or 0
    self.zone.percentageFastShamblers = tonumber(self.fastShamblersInput:getText() or "0") or 0
    self.zone.percentageSlowShamblers = tonumber(self.slowShamblersInput:getText() or "0") or 0
    self.zone.spawnInterval = tonumber(self.spawnIntervalInput:getText() or "0") or 0
    self.zone.spawnCount = tonumber(self.spawnCountInput:getText() or "0") or 0
    self.zone.spawnMax = tonumber(self.spawnMaxInput:getText() or "0") or 0
    self.zone.spawnRange = tonumber(self.spawnRangeInput:getText() or "0") or 0
    self.zone.spawnCatchup = self.spawnCatchupInput:isSelected(1)
    self.zone.spawnCheckPlayers = self.spawnCheckPlayersInput:isSelected(1)
    self.zone.spawnPlayerRange = tonumber(self.spawnPlayerRangeInput:getText() or "0") or 0
    self.zone.noThump = self.noThumpInput:isSelected(1)

    --messages
    self.zone.warningBuffer = tonumber(self.warningMessageRangeInput:getText() or "0") or 0
    self.zone.warningMessage = self.warningMessageInput:getText()
    self.zone.enterMessage = self.enterMessageInput:getText()
    self.zone.exitMessage = self.exitMessageInput:getText()
    self.zone.inCars = self.inCarsInput:isSelected(1)
    self.zone.inCarsMessage = self.inCarsMessageInput:getText()
    self.zone.rpText = self.rpTextInput:getText()

    --weather
    self.zone.weatherWind = self.weatherTab.sliderWindSlider:getCurrentValue()
    self.zone.weatherWindEnabled = self.weatherTab.tickBoxWind:isSelected(1)
    self.zone.weatherClouds = self.weatherTab.sliderCloudsSlider:getCurrentValue()
    self.zone.weatherCloudsEnabled = self.weatherTab.tickBoxClouds:isSelected(1)
    self.zone.weatherFog = self.weatherTab.sliderFogSlider:getCurrentValue()
    self.zone.weatherFogEnabled = self.weatherTab.tickBoxFog:isSelected(1)
    self.zone.weatherPrecipitation = self.weatherTab.sliderPrecipSlider:getCurrentValue()
    self.zone.weatherPrecipitationEnabled = self.weatherTab.tickBoxPrecip:isSelected(1)
    self.zone.weatherPrecipitationIsSnow = self.weatherTab.tickBoxPrecipIsSnow:isSelected(1)
    self.zone.weatherTemperature = self.weatherTab.sliderTempSlider:getCurrentValue()
    self.zone.weatherTemperatureEnabled = self.weatherTab.tickBoxTemp:isSelected(1)
    self.zone.weatherDarkness = self.weatherTab.sliderDarknessSlider:getCurrentValue()
    self.zone.weatherDarknessEnabled = self.weatherTab.tickBoxDarkness:isSelected(1)
    self.zone.weatherDesaturationEnabled = self.weatherTab.tickBoxDesaturation:isSelected(1)
    self.zone.weatherDesaturation = self.weatherTab.sliderDesaturationSlider:getCurrentValue()
    self.zone.weatherLightExtR = self.weatherTab.sliderLightR_extSlider:getCurrentValue()
    self.zone.weatherLightExtG = self.weatherTab.sliderLightG_extSlider:getCurrentValue()
    self.zone.weatherLightExtB = self.weatherTab.sliderLightB_extSlider:getCurrentValue()
    self.zone.weatherLightExtA = self.weatherTab.sliderLightA_extSlider:getCurrentValue()
    self.zone.weatherLightIntR = self.weatherTab.sliderLightR_intSlider:getCurrentValue()
    self.zone.weatherLightIntG = self.weatherTab.sliderLightG_intSlider:getCurrentValue()
    self.zone.weatherLightIntB = self.weatherTab.sliderLightB_intSlider:getCurrentValue()
    self.zone.weatherLightIntA = self.weatherTab.sliderLightA_intSlider:getCurrentValue()
    self.zone.weatherLightEnabled = self.weatherTab.tickBoxLightR_ext:isSelected(1)

    --rifts
    self.zone.noRiftZone = self.noRiftZoneInput:isSelected(1)
    self.zone.riftSpawnChance = tonumber(self.riftSpawnChanceInput:getText() or "0") or 0
    self.zone.riftMinCount = tonumber(self.riftMinCountInput:getText() or "0") or 0
    self.zone.riftMaxCount = tonumber(self.riftMaxCountInput:getText() or "0") or 0
    self.zone.riftMinRate = tonumber(self.riftMinRateInput:getText() or "0") or 0
    self.zone.riftMaxRate = tonumber(self.riftMaxRateInput:getText() or "0") or 0

    self.zone:save()
end
