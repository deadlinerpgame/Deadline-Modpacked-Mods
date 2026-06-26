require "Hotbar/ISHotbarAttachDefinition"
if not ISHotbarAttachDefinition then
    return
end

local RadioBackpack = {
    type = "RadioBackpack",
    name = "HAM Radio",
    animset = "back",
    attachments = {
        RadioBackpack = "RadioBackpack",
    }
}

table.insert(ISHotbarAttachDefinition, RadioBackpack)