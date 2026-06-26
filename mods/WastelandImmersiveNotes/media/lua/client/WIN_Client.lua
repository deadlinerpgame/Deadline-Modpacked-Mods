---
--- WIN_Client.lua
--- 2025-12-08
---

if not isClient() then return end

WIN_Client = {}

--- Sends a message to other players to show them an ID card window.
--- @param playerUsernames table list of all usernames to send the ID card to
--- @param pageContent string the content of the page to show
--- @param fontKey string the font key to use for rendering the page text
--- @param skinKey string the skin key to use for rendering the page background
--- @param languageKey string the language code the note is written in
function WIN_Client.showPageToPlayers(playerUsernames, pageContent, fontKey, skinKey, languageKey)
	if not playerUsernames then error("playerUsernames is missing") end
	if not pageContent then error("pageContent is missing") end
	if not fontKey then error("fontKey is missing") end
	if not skinKey then error("skinKey is missing") end
    local cardData = {
        usernames = playerUsernames,
        pageContent = pageContent,
        fontKey = fontKey,
        skinKey = skinKey,
        languageKey = languageKey
    }
	sendClientCommand(getPlayer(), "WastelandImmersiveNotes", "showPageToPlayers", cardData)
end

local serverCommands = {}

function serverCommands.showPage(pageData)
	if not pageData then
        error("pageData is missing from showPage")
    end
    if not pageData.pageContent then
        error("pageContent is missing from pageData")
    end
    if not pageData.fontKey then
        error("fontKey is missing from pageData")
    end
    if not pageData.skinKey then
        error("skinKey is missing from pageData")
    end

    local pageContent = pageData.pageContent
    local languageKey = pageData.languageKey
    if languageKey and not WIN_Utils.canUnderstandLanguage(languageKey) then
        pageContent = "You can't read this. It is written in " .. WIN_Utils.getLanguageDisplayName(languageKey) .. "."
    end

    WIN_NotePaperWindow.displayFromServerMessage(pageContent, pageData.fontKey, pageData.skinKey)
end

local function processServerCommand(module, command, args)
	if module ~= "WastelandImmersiveNotes" then return end
	if not serverCommands[command] then return end
	serverCommands[command](args)
end

Events.OnServerCommand.Add(processServerCommand)
