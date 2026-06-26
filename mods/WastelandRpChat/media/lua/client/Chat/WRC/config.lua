if not isClient() then return end -- only in MP
WRC = WRC or {}

-- Define chat types
WRC.ChatTypes = {}
WRC.ChatTypes["whisper"] = {
    name = "Whisper",
    command = {"whisper", "w"},
    xyRange = SandboxVars.WastelandRpChat.RangeXYWhisper,
    zRange = SandboxVars.WastelandRpChat.RangeZWhisper,
    questionPrefix = "whisper asks",
    exclamationPrefix = "whisper exclaims",
    defaultPrefix = "whispers",
    volumePrefix = "Whisper",
}
WRC.ChatTypes["low"] = {
    name = "Low",
    command = {"low", "l", "quiet", "q"},
    xyRange = SandboxVars.WastelandRpChat.RangeXYLow,
    zRange = SandboxVars.WastelandRpChat.RangeZLow,
    questionPrefix = "quietly asks",
    exclamationPrefix = "quietly exclaims",
    defaultPrefix = "quietly says",
    volumePrefix = "Quiet",
}
WRC.ChatTypes["say"] = {
    name = "Say",
    command = {"say", ""},
    xyRange = SandboxVars.WastelandRpChat.RangeXYSay,
    zRange = SandboxVars.WastelandRpChat.RangeZSay,
    questionPrefix = "asks",
    exclamationPrefix = "exclaims",
    defaultPrefix = "says",
    volumePrefix = "Normal",
}
WRC.ChatTypes["loud"] = {
    name = "Loud",
    command = {"loud", "yell", "y"},
    xyRange = SandboxVars.WastelandRpChat.RangeXYLoud,
    zRange = SandboxVars.WastelandRpChat.RangeZLoud,
    questionPrefix = "loudly asks",
    exclamationPrefix = "loudly exclaims",
    defaultPrefix = "loudly says",
    volumePrefix = "Loud",
}
WRC.ChatTypes["shout"] = {
    name = "Shout",
    command = {"shout", "s"},
    xyRange = SandboxVars.WastelandRpChat.RangeXYShout,
    zRange = SandboxVars.WastelandRpChat.RangeZShout,
    questionPrefix = "shouts",
    exclamationPrefix = "shouts",
    defaultPrefix = "shouts",
    volumePrefix = "Shout",
}

-- Define chat modifiers
WRC.ChatModifiers = {}
WRC.ChatModifiers["me"] = {
    command = {"me", "m"},
    type = "emote",
    staffOnly = false,
}
WRC.ChatModifiers["env"] = {
    command = {"env", "e"},
    type = "environment",
    hideName = true,
    staffOnly = false,
}
WRC.ChatModifiers["ooc"] = {
    command = {"ooc", "o"},
    type = "ooc",
    singleLine = true,
    staffOnly = false,
}
WRC.ChatModifiers["event"] = {
    command = {"event", "v"},
    type = "event",
    singleLine = true,
    staffOnly = false,
}
WRC.ChatModifiers["alert"] = {
    command = {"alert", "a"},
    type = "alert",
    singleLine = true,
    staffOnly = true,
}

-- Define chat colors for each modifier type
WRC.ChatColors = {}
-- light grey
WRC.ChatColors["playerDefault"] = { r = 0.8, g = 0.8, b = 0.8 }
-- pastel blue
WRC.ChatColors["emote"] = "<RGB:0.5,0.5,1>"
-- darker pastel blue
WRC.ChatColors["emotemuted"] = "<RGB:0.3,0.3,0.8>"
-- pastel green
WRC.ChatColors["environment"] = "<RGB:0.5,1,0.5>"
-- dark blue
WRC.ChatColors["ooc"] = "<RGB:0.3,0.3,0.8>"
-- red
WRC.ChatColors["alert"] = "<RGB:1,0,0>"
-- yellow
WRC.ChatColors["event"] = "<RGB:1,1,0.4>"
-- light grey
WRC.ChatColors["text"] = "<RGB:0.8,0.8,0.8>"
-- grey
WRC.ChatColors["textmuted"] = "<RGB:0.5,0.5,0.5>"
-- red
WRC.ChatColors["error"] = "<RGB:1,0,0>"
-- blue
WRC.ChatColors["info"] = "<RGB:0.4,0.4,1>"
-- grey
WRC.ChatColors["langprefix"] = "<RGB:0.5,0.5,0.5>"
-- white
WRC.ChatColors["radiochannel"] = "<RGB:1,1,1>"
-- green
WRC.ChatColors["admintag"] = "<RGB:0,1,0>"
-- yellow
WRC.ChatColors["npctag"] = "<RGB:1,1,0>"
-- orange
WRC.ChatColors["roll"] = "<RGB:1,0.5,0>"
-- light green
WRC.ChatColors["fromRadio"] = "<RGB:0.4,1,0.4>"

WRC.ChatColors["volumeprefixes"] = {}
WRC.ChatColors["volumeprefixes"]["whisper"] = "<RGB:0.4,0.4,0.4>"
WRC.ChatColors["volumeprefixes"]["low"] = "<RGB:0.5,0.5,0.5>"
WRC.ChatColors["volumeprefixes"]["say"] = "<RGB:0.6,0.6,0.6>"
WRC.ChatColors["volumeprefixes"]["loud"] = "<RGB:0.7,0.7,0.7>"
WRC.ChatColors["volumeprefixes"]["shout"] = "<RGB:1,0.4,0.4>"

WRC.SpecialCommands = {}
WRC.SpecialCommands["/roll"] = {
    handler = "Roll",
    tabHandlers = {},
    usage = "/roll [NumSides] <LINE> /roll [NumDice]d[NumSides] <LINE> /roll [NumDice]d[NumSides]+[Bonus]",
    help = "Roll a set of dice.",
    adminOnly = false,
}
WRC.SpecialCommands["/name"] = {
    handler = "SetName",
    tabHandlers = {},
    usage = "/name <name>",
    help = "Change your display name.",
    adminOnly = false,
}
WRC.SpecialCommands["/color"] = {
    handler = "SetColor",
    tabHandlers = {},
    usage = "/color <color code>",
    help = "Change your display name color.",
    adminOnly = false,
}
WRC.SpecialCommands["/radiosync"] = {
    handler = "RadioSync",
    tabHandlers = {"RadioFrequencies"},
    usage = "/radiosync",
    help = "Sync one radio station with General Chat.",
    adminOnly = false,
}
WRC.SpecialCommands["/lang"] = {
    handler = "SetLang",
    tabHandlers = {"MyLangs"},
    usage = "/lang <language code>",
    help = "Change you current language.",
    adminOnly = false,
}
WRC.SpecialCommands["/addlang"] = {
    handler = "AddLang",
    tabHandlers = {"Username", "AnyLang"},
    usage = "/addlang \"User Name\" <language code>",
    help = "Add a language to a players known languages.",
    adminOnly = true,
}
WRC.SpecialCommands["/removelang"] = {
    handler = "RemoveLang",
    tabHandlers = {"Username", "AnyLang"},
    usage = "/removelang \"User Name\" <language code>",
    help = "Remove a language from a players known languages.",
    adminOnly = true,
}
WRC.SpecialCommands["/focus"] = {
    handler = "Focus",
    tabHandlers = {"UsernameNotSelf"},
    usage = "/focus \"User Name\"",
    help = "Focus on a player. Only see messages from that player.",
    adminOnly = false,
}
WRC.SpecialCommands["/unfocus"] = {
    handler = "Unfocus",
    tabHandlers = {"FocusedUsername"},
    usage = "/unfocus \"User Name\"",
    help = "Unfocus on a player. Stop focusing messages from that player.",
    adminOnly = false,
}
WRC.SpecialCommands["/hammer"] = {
    handler = "Hammer",
    tabHandlers = {"OnOff"},
    usage = "/hammer on/off",
    help = "Toggle admin hammer.",
    adminOnly = true,
}
WRC.SpecialCommands["/npc"] = {
    handler = "NpcTag",
    tabHandlers = {"OnOff"},
    usage = "/npc on/off",
    help = "Toggle npc tag",
    adminOnly = true,
}
WRC.SpecialCommands["/injured"] = {
    handler = "InjuredAbove",
    tabHandlers = {"OnOff"},
    usage = "/injured on/off",
    help = "Toggle injured tag above head",
    adminOnly = false,
}
WRC.SpecialCommands["/streaming"] = {
    handler = "StreamingAbove",
    tabHandlers = {"OnOff"},
    usage = "/streaming on/off",
    help = "Toggle streaming tag above head",
    adminOnly = false,
}
WRC.SpecialCommands["/limpleft"] = {
    handler = "LimpLeft",
    tabHandlers = {"OnOff"},
    usage = "/limpleft on/off",
    help = "Toggle limping with your left leg",
    adminOnly = false,
}
WRC.SpecialCommands["/limpright"] = {
    handler = "LimpRight",
    tabHandlers = {"OnOff"},
    usage = "/limpright on/off",
    help = "Toggle limping with your right leg",
    adminOnly = false,
}
WRC.SpecialCommands["/pm"] = {
    handler = "SendPM",
    tabHandlers = {"Username"},
    usage = "/pm \"User Name\" <message>",
    help = "Send a private message to a player.",
    adminOnly = false,
}
WRC.SpecialCommands["/afk"] = {
    handler = "GoAFK",
    tabHandlers = {},
    usage = "/afk",
    help = "Go AFK. Will alert nearby players you are AFK.",
    adminOnly = false,
}
WRC.SpecialCommands["/coords"] = {
    handler = "Coords",
    tabHandlers = {},
    usage = "/coords",
    help = "Get your current coordinates.",
    adminOnly = false,
}
WRC.SpecialCommands["/growbeard"] = {
    handler = "GrowBeard",
    tabHandlers = {},
    usage = "/growbeard",
    help = "Grow a beard.",
    adminOnly = false,
}
WRC.SpecialCommands["/growhair"] = {
    handler = "GrowHair",
    tabHandlers = {},
    usage = "/growhair",
    help = "Grow hair.",
    adminOnly = false,
}
WRC.SpecialCommands["/sethaircolor"] = {
    handler = "SetHairColor",
    tabHandlers = {},
    usage = "/sethaircolor <color code>",
    help = "Set hair color.",
    adminOnly = false,
}
WRC.SpecialCommands["/setbeardcolor"] = {
    handler = "SetBeardColor",
    tabHandlers = {},
    usage = "/setbeardcolor <color code>",
    help = "Set beard color.",
    adminOnly = false,
}
WRC.SpecialCommands["/hairgrowth"] = {
    handler = "HairGrowth",
    tabHandlers = {},
    usage = "/hairgrowth",
    help = "Stop hair growth.",
    adminOnly = false,
}
WRC.SpecialCommands["/override"] = {
    handler = "Override",
    tabHandlers = {"OnOff"},
    usage = "/override on/off",
    help = "Enable or Disable the admin chat override.",
    adminOnly = true,
}
WRC.SpecialCommands["/keeplast"] = {
    handler = "KeepLast",
    tabHandlers = {"OnOff"},
    usage = "/keeplast on/off",
    help = "Enable or Disable keeping the last chat type in the chat box.",
    adminOnly = false,
}
WRC.SpecialCommands["/trade"] = {
    handler = "Trade",
    tabHandlers = {"UsernameNotSelf"},
    usage = "/trade \"User Name\"",
    help = "Trade with a player.",
    adminOnly = false,
}
WRC.SpecialCommands["/injure"] = {
    handler = "Injure",
    tabHandlers = {"BodyPart", "InjuryType"},
    usage = "/injure <body part> <injury type>",
    help = "Injure a body part.",
    adminOnly = false,
}
WRC.SpecialCommands["/status"] = {
    handler = "SetStatus",
    tabHandlers = {},
    usage = "/status clear or <status message>",
    help = "Shows, sets, or clears your current status.",
    adminOnly = false,
}
WRC.SpecialCommands["/statusinvert"] = {
    handler = "InvertStatus",
    tabHandlers = {"OnOff"},
    usage = "/statusinvert",
    help = "Invert the colour of status'.",
    adminOnly = false,
}
WRC.SpecialCommands["/private"] = {
    handler = "PrivateChat",
    tabHandlers = {"UsernameNotSelf"},
    usage = "/private <username>",
    help = "Send a private message to a player.",
    adminOnly = false,
}
WRC.SpecialCommands["/stopprivate"] = {
    handler = "StopPrivateChat",
    tabHandlers = {},
    usage = "/stopprivate",
    help = "Stop a private chat",
    adminOnly = false,
}
WRC.SpecialCommands["/howto"] = {
    handler = "ListAllCommands",
    tabHandlers = {},
    usage = "/howto",
    help = "Shows all the possible chat combinations for RP Chat.",
    adminOnly = false,
}
WRC.SpecialCommands["/help"] = {
    handler = "Help",
    tabHandlers = {},
    usage = "/help <command>",
    help = "Get help on a command.",
    adminOnly = false,
}
WRC.SpecialCommands["/jammer"] = {
    handler = "RadioJammer",
    tabHandlers = {"OnOff"},
    usage = "/jammer on/off",
    help = "Toggle radio jammer.",
    adminOnly = true,
}
WRC.SpecialCommands["/stopsound"] = {
    handler = "StopSound",
    tabHandlers = {},
    usage = "/stopsound",
    help = "Stop all sounds.",
    adminOnly = false,
}
WRC.SpecialCommands["/ss"] = {
    handler = "StopSound",
    tabHandlers = {},
    usage = "/ss",
    help = "Stop all sounds.",
    adminOnly = false,
}