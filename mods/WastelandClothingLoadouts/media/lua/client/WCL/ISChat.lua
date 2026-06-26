require "Chat/ISChat"
require "WCL/Loadouts"
require "WCL/CustomLoadDialog"
require "WL_Utils"
require "WL_UserData"
require "WL_PlayerReady"

-- Store original ISChat functions
WCL_ISChatOriginal = WCL_ISChatOriginal or {}

-- Store favorites data
WCL_FavoriteLoadouts = WCL_FavoriteLoadouts or nil

-- Helper functions for chat messages
local function errorLine(msg)
    WL_Utils.addErrorToChat(msg)
end

local function infoLine(msg)
    WL_Utils.addInfoToChat(msg)
end

-- Check if user is staff
local function isStaff()
    local player = getPlayer()
    return player:getAccessLevel() ~= "None"
end

-- Check if user can save global loadouts
local function canSaveGlobal()
    local player = getPlayer()
    return WL_Utils.canModerate(player)
end

-- ============================================================================
-- FAVORITES MANAGEMENT
-- ============================================================================

-- Initialize favorites from UserData
local function initializeFavorites()
    WL_UserData.Fetch("WCL_FavoriteLoadouts", function(data)
        WCL_FavoriteLoadouts = data or {}
    end)
end

-- Generate a unique key for a loadout (handles same names in private/public)
local function getFavoriteKey(loadoutName, isPublic)
    return (isPublic and "public:" or "private:") .. loadoutName
end

-- Check if a loadout is favorited
local function isFavorite(loadoutName, isPublic)
    if not WCL_FavoriteLoadouts then return false end
    
    local key = getFavoriteKey(loadoutName, isPublic)
    for _, fav in ipairs(WCL_FavoriteLoadouts) do
        if getFavoriteKey(fav.name, fav.isPublic) == key then
            return true
        end
    end
    return false
end

-- Add a loadout to favorites
local function addToFavorites(loadoutName, isPublic)
    if not WCL_FavoriteLoadouts then
        WCL_FavoriteLoadouts = {}
    end
    
    -- Don't add if already favorited
    if isFavorite(loadoutName, isPublic) then
        return
    end
    
    table.insert(WCL_FavoriteLoadouts, {
        name = loadoutName,
        isPublic = isPublic
    })
    
    -- Update UserData
    WL_UserData.Set("WCL_FavoriteLoadouts", WCL_FavoriteLoadouts)
    infoLine("Added to favorites: " .. loadoutName)
end

-- Remove a loadout from favorites
local function removeFromFavorites(loadoutName, isPublic)
    if not WCL_FavoriteLoadouts then return end
    
    local key = getFavoriteKey(loadoutName, isPublic)
    for i = #WCL_FavoriteLoadouts, 1, -1 do
        local fav = WCL_FavoriteLoadouts[i]
        if getFavoriteKey(fav.name, fav.isPublic) == key then
            table.remove(WCL_FavoriteLoadouts, i)
            
            -- Update UserData
            WL_UserData.Set("WCL_FavoriteLoadouts", WCL_FavoriteLoadouts)
            infoLine("Removed from favorites: " .. loadoutName)
            return
        end
    end
end

-- Toggle favorite status
local function toggleFavorite(loadoutName, isPublic)
    if isFavorite(loadoutName, isPublic) then
        removeFromFavorites(loadoutName, isPublic)
    else
        addToFavorites(loadoutName, isPublic)
    end
end

-- ============================================================================
-- BUTTON AND MENU HANDLERS
-- ============================================================================

function ISChat:onLoadoutButtonClick()
    local player = getPlayer()
    
    -- Staff only check
    if not isStaff() then
        errorLine("Staff only feature")
        return
    end
    
    local context = ISContextMenu.get(0, self:getAbsoluteX() + self:getWidth() / 2, self:getAbsoluteY() + self.gearButton:getY())
    if not context then return end
    
    -- Favorites at the top (load immediately when clicked)
    if WCL_FavoriteLoadouts and #WCL_FavoriteLoadouts > 0 then
        for _, favorite in ipairs(WCL_FavoriteLoadouts) do
            local loadout = nil
            local prefix = ""
            
            if favorite.isPublic then
                loadout = WCL_Loadouts.Loadouts[favorite.name]
                prefix = "[Public] "
            else
                loadout = WCL_Loadouts.PlayerLoadouts[favorite.name]
                prefix = "[Private] "
            end
            
            -- Only show if loadout still exists
            if loadout then
                context:addOption(prefix .. favorite.name, self, ISChat.onLoadLoadout, favorite.name)
            end
        end
        
        context:addOption("---")
    end
    
    -- Private loadouts submenu
    local privateLoadouts = WCL_Loadouts.PlayerLoadouts
    local privateNames = {}
    for name, _ in pairs(privateLoadouts) do
        table.insert(privateNames, name)
    end
    table.sort(privateNames)
    
    if #privateNames > 0 then
        local privateSubmenu = context:getNew(context)
        context:addSubMenu(context:addOption("Private"), privateSubmenu)
        for _, name in ipairs(privateNames) do
            local loadoutSubmenu = privateSubmenu:getNew(privateSubmenu)
            privateSubmenu:addSubMenu(privateSubmenu:addOption(name), loadoutSubmenu)
            loadoutSubmenu:addOption("Load", self, ISChat.onLoadLoadout, name)
            loadoutSubmenu:addOption("Load Outfit Only", self, ISChat.onLoadOutfitLoadout, name)
            loadoutSubmenu:addOption("Load Custom", self, ISChat.onLoadCustomLoadout, name)
            loadoutSubmenu:addOption("Overwrite", self, ISChat.onOverwritePrivateLoadout, name)
            loadoutSubmenu:addOption("Remove", self, ISChat.onRemovePrivateLoadout, name)
            
            -- Add favorite toggle option
            if isFavorite(name, false) then
                loadoutSubmenu:addOption("Remove From Favorites", self, ISChat.onToggleFavorite, name, false)
            else
                loadoutSubmenu:addOption("Add To Favorites", self, ISChat.onToggleFavorite, name, false)
            end
        end
    end
    
    -- Public loadouts submenu
    local publicLoadouts = WCL_Loadouts.Loadouts
    local publicNames = {}
    for name, _ in pairs(publicLoadouts) do
        table.insert(publicNames, name)
    end
    table.sort(publicNames)
    
    if #publicNames > 0 then
        local publicSubmenu = context:getNew(context)
        context:addSubMenu(context:addOption("Public"), publicSubmenu)
        for _, name in ipairs(publicNames) do
            local loadoutSubmenu = publicSubmenu:getNew(publicSubmenu)
            publicSubmenu:addSubMenu(publicSubmenu:addOption(name), loadoutSubmenu)
            loadoutSubmenu:addOption("Load", self, ISChat.onLoadLoadout, name)
            loadoutSubmenu:addOption("Load Outfit Only", self, ISChat.onLoadOutfitLoadout, name)
            loadoutSubmenu:addOption("Load Custom", self, ISChat.onLoadCustomLoadout, name)
            if canSaveGlobal() then
                loadoutSubmenu:addOption("Remove", self, ISChat.onRemovePublicLoadout, name)
            end
            
            -- Add favorite toggle option
            if isFavorite(name, true) then
                loadoutSubmenu:addOption("Remove From Favorites", self, ISChat.onToggleFavorite, name, true)
            else
                loadoutSubmenu:addOption("Add To Favorites", self, ISChat.onToggleFavorite, name, true)
            end
        end
    end
    
    -- Save submenu
    local saveSubmenu = context:getNew(context)
    context:addSubMenu(context:addOption("Save"), saveSubmenu)
    saveSubmenu:addOption("Private", self, ISChat.onSavePrivateLoadout)
    if canSaveGlobal() then
        saveSubmenu:addOption("Public", self, ISChat.onSavePublicLoadout)
    end
    
    -- Reset player option
    context:addOption("Reset Player", self, ISChat.onResetPlayer)
    
    -- Change Gender option
    local genderSubmenu = context:getNew(context)
    context:addSubMenu(context:addOption("Change Gender"), genderSubmenu)
    local info = genderSubmenu:addOption("!!! ONLY LOCAL - NOT SYNCED !!!")
    info.notAvailable = true
    genderSubmenu:addOption("Male", self, ISChat.onChangeGender, false)
    genderSubmenu:addOption("Female", self, ISChat.onChangeGender, true)
end

function ISChat:onSavePrivateLoadout()
    local player = getPlayer()
    local modal = ISTextBox:new(
        getCore():getScreenWidth() / 2 - 200,
        getCore():getScreenHeight() / 2 - 100,
        280,
        180,
        "Enter loadout name:",
        "",
        nil,
        function(target, button)
            if button.internal == "OK" then
                local name = button.parent.entry:getText()
                if name and name ~= "" then
                    local loadout = WCL_Loadouts.captureCurrent(player)
                    WCL_Loadouts.savePlayerLoadout(player, name, loadout)
                    infoLine("Saved private loadout: " .. name)
                else
                    errorLine("Loadout name cannot be empty")
                end
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function ISChat:onSavePublicLoadout()
    if not canSaveGlobal() then
        errorLine("Admin/Moderator only")
        return
    end
    
    local player = getPlayer()
    local modal = ISTextBox:new(
        getCore():getScreenWidth() / 2 - 200,
        getCore():getScreenHeight() / 2 - 100,
        280,
        180,
        "Enter public loadout name:",
        "",
        nil,
        function(target, button)
            if button.internal == "OK" then
                local name = button.parent.entry:getText()
                if name and name ~= "" then
                    local loadout = WCL_Loadouts.captureCurrent(player)
                    WCL_Loadouts.saveLoadout(player, name, loadout)
                    infoLine("Saved public loadout: " .. name)
                else
                    errorLine("Loadout name cannot be empty")
                end
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function ISChat:onLoadLoadout(loadoutName)
    local player = getPlayer()
    local loadout = WCL_Loadouts.getLoadout(loadoutName)
    
    if not loadout then
        errorLine("Loadout not found: " .. loadoutName)
        return
    end
    
    WCL_Loadouts.applyInventory(player, loadout, {})
    infoLine("Loaded loadout: " .. loadoutName)
end

function ISChat:onLoadOutfitLoadout(loadoutName)
    local player = getPlayer()
    local loadout = WCL_Loadouts.getLoadout(loadoutName)
    
    if not loadout then
        errorLine("Loadout not found: " .. loadoutName)
        return
    end
    
    WCL_Loadouts.applyInventory(player, loadout, {
        removeItems = false,
        restoreOutfit = true,
        restoreItems = false,
        restoreIdentity = false,
        restoreHair = true,
        restoreCharacteristics = false
    })
    
    infoLine("Loaded outfit from loadout: " .. loadoutName)
end

function ISChat:onLoadCustomLoadout(loadoutName)
    local player = getPlayer()
    local loadout = WCL_Loadouts.getLoadout(loadoutName)
    
    if not loadout then
        errorLine("Loadout not found: " .. loadoutName)
        return
    end
    
    -- Show custom dialog
    WCL_CustomLoadDialog.show(loadoutName, function(options)
        WCL_Loadouts.applyInventory(player, loadout, options)
        infoLine("Loaded loadout with custom options: " .. loadoutName)
    end)
end

function ISChat:onOverwritePrivateLoadout(loadoutName)
    local player = getPlayer()
    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 75,
        300,
        150,
        "Are you sure you want to overwrite the private loadout '" .. loadoutName .. "'?",
        true,
        nil,
        function(target, button)
            if button.internal == "YES" then
                local loadout = WCL_Loadouts.captureCurrent(player)
                WCL_Loadouts.savePlayerLoadout(player, loadoutName, loadout)
                infoLine("Overwritten private loadout: " .. loadoutName)
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function ISChat:onRemovePrivateLoadout(loadoutName)
    local player = getPlayer()
    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 75,
        300,
        150,
        "Are you sure you want to remove the private loadout '" .. loadoutName .. "'?",
        true,
        nil,
        function(target, button)
            if button.internal == "YES" then
                WCL_Loadouts.deletePlayerLoadout(player, loadoutName)
                infoLine("Removed private loadout: " .. loadoutName)
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function ISChat:onRemovePublicLoadout(loadoutName)
    if not canSaveGlobal() then
        errorLine("Admin/Moderator only")
        return
    end
    
    local player = getPlayer()
    local modal = ISModalDialog:new(
        getCore():getScreenWidth() / 2 - 150,
        getCore():getScreenHeight() / 2 - 75,
        300,
        150,
        "Are you sure you want to remove the public loadout '" .. loadoutName .. "'?",
        true,
        nil,
        function(target, button)
            if button.internal == "YES" then
                WCL_Loadouts.deleteLoadout(player, loadoutName)
                infoLine("Removed public loadout: " .. loadoutName)
            end
        end
    )
    modal:initialise()
    modal:addToUIManager()
end

function ISChat:onToggleFavorite(loadoutName, isPublic)
    toggleFavorite(loadoutName, isPublic)
end

function ISChat:onResetPlayer()
    local player = getPlayer()
    WCL_Loadouts.resetPlayer(player, true, {removeItems = true, restoreOutfit = true, restoreMakeup = true})
    infoLine("Reset player inventory")
end

function ISChat:onChangeGender(isFemale)
    local player = getPlayer()
    player:setFemale(isFemale)
    player:resetModel()
    if isFemale then
        infoLine("Changed gender to Female")
    else
        infoLine("Changed gender to Male")
    end
end

-- ============================================================================
-- ISCHAT OVERRIDES
-- ============================================================================

WCL_ISChatOriginal.createChildren = WCL_ISChatOriginal.createChildren or ISChat.createChildren
function ISChat:createChildren()
    WCL_ISChatOriginal.createChildren(self)
    
    -- Create loadout button next to gear button
    self.loadoutButton = ISButton:new(self.gearButton:getX() - 120, 1, 20, 16, "", self, ISChat.onLoadoutButtonClick)
    self.loadoutButton.anchorRight = true
    self.loadoutButton.anchorLeft = false
    self.loadoutButton:initialise()
    self.loadoutButton.borderColor.a = 0.0
    self.loadoutButton.backgroundColor.a = 0.0
    self.loadoutButton.backgroundColorMouseOver.a = 0.0
    
    -- Try to load a loadout icon texture, fall back to text if not available
    local texture = getTexture("media/ui/WCL_loadout.png")
    if texture then
        self.loadoutButton:setImage(texture)
    else
        self.loadoutButton:setTitle("LO")
        self.loadoutButton.borderColor.a = 0.5
    end
    
    self.loadoutButton:setUIName("clothing loadouts menu")
    self:addChild(self.loadoutButton)
    
    -- Only show button to staff members
    self.loadoutButton:setVisible(isStaff())
end

Events.OnPlayerUpdate.Add(function()
    if ISChat.instance and ISChat.instance.loadoutButton then
        ISChat.instance.loadoutButton:setVisible(isStaff())
    end
end)

-- Initialize favorites when player is ready
WL_PlayerReady.Add(function(playerIndex, player)
    initializeFavorites()
end)