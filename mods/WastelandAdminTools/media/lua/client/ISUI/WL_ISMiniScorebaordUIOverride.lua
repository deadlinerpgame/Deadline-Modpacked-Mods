-- sort the list
function ISMiniScoreboardUI:populateList()
    self.playerList:clear();
    if not self.scoreboard then return end
    local playersNames = {}
    local players = {}
    for i=1,self.scoreboard.usernames:size() do
        local username = self.scoreboard.usernames:get(i-1)
        local displayName = self.scoreboard.displayNames:get(i-1)
        if username ~= self.admin:getUsername() then
            playersNames[username] = displayName
            table.insert(players, username)
        end
    end
    table.sort(players)
    for _, username in ipairs(players) do
        local item = {}
        local displayName = playersNames[username]
        local name = displayName
        item.username = username
        item.displayName = displayName
        local item0 = self.playerList:addItem(name, item);
        if username ~= displayName then
            item0.tooltip = username
        end
    end
end