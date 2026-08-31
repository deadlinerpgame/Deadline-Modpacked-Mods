require("WLBaseObject")

local TypedTableJson = require "WastelandZones/TypedTableJson"

---@class WastelandZones.Classes.Storage: WLBaseObject
---@field fileName string
---@field legacyFileName string
---@field serializerVersion integer
local Storage = WastelandZones.Classes.Storage or WLBaseObject:derive("WastelandZones.Classes.Storage")
if not WastelandZones.Classes.Storage then
    WastelandZones.Classes.Storage = Storage
end

local MAGIC = "--WZDATA"
local CURRENT_VERSION = 2

local function parseHeader(line)
    local magic, version = line:match("^([^|]+)|v=(%d+)$")
    if magic ~= MAGIC or not version then
        return nil
    end
    return tonumber(version)
end

local function legacyConversionMessage(fileName)
    return "Legacy WastelandZones Lua-table saves are not read in-game. "
        .. "The v1 source may be " .. tostring(fileName) .. " or WastelandZones_Data.lua. "
        .. "Stop the server and convert that source with scripts/convert_legacy_lua_tables.py "
        .. "--profile zones --zone-header -o WastelandZones_Data.v2.txt. "
        .. "Verify the separate v2 file, back up the v1 source, then explicitly replace "
        .. tostring(fileName) .. ". See docs/legacy-lua-table-converter.md."
end

---@return WastelandZones.Classes.Storage
function Storage:new()
    local o = Storage.parentClass.new(self)
    -- Build 42.20 only permits ini/cfg/txt/log through getFileReader/getFileWriter.
    -- The .txt file contains a v2 header followed by lossless typed-table JSON.
    o.fileName = "WastelandZones_Data.txt"
    o.legacyFileName = "WastelandZones_Data.lua"
    o.serializerVersion = CURRENT_VERSION
    return o
end

---@param data table
function Storage:save(data)
    -- Encode before opening with overwrite=true so an unsupported value cannot
    -- truncate the previous valid save.
    local payload = TypedTableJson.Encode(data)
    local writer = getFileWriter(self.fileName, true, false)
    if not writer then
        error("Storage:save() failed to open " .. tostring(self.fileName))
    end

    local ok, writeError = pcall(function()
        writer:writeln(MAGIC .. "|v=" .. tostring(self.serializerVersion))
        writer:write(payload)
        writer:close()
    end)
    if not ok then
        pcall(function() writer:close() end)
        error("Storage:save() write failed for " .. tostring(self.fileName) .. ": " .. tostring(writeError))
    end
end

---@param fileName string
---@return table|nil
function Storage:_loadFile(fileName)
    local reader = getFileReader(fileName, true)
    if not reader then
        return nil
    end

    local header = reader:readLine()
    if not header or header == "" then
        reader:close()
        return nil
    end

    local fileVersion = parseHeader(header)
    if not fileVersion then
        reader:close()
        error("Storage:load() invalid header in " .. tostring(fileName) .. ": " .. tostring(header))
    end
    if fileVersion ~= self.serializerVersion then
        reader:close()
        if fileVersion < self.serializerVersion then
            error("Storage:load() found legacy v" .. tostring(fileVersion) .. " data in "
                .. tostring(fileName) .. ". " .. legacyConversionMessage(fileName))
        end
        error("Storage:load() cannot read future serializer v" .. tostring(fileVersion)
            .. " data (runtime supports v" .. tostring(self.serializerVersion) .. ")")
    end

    local payloadLines = {}
    while true do
        local line = reader:readLine()
        if line == nil then
            break
        end
        payloadLines[#payloadLines + 1] = line
    end
    reader:close()

    if #payloadLines == 0 then
        return nil
    end

    local payload = table.concat(payloadLines, "\n")
    if payload:match("^%s*$") then
        return nil
    end

    local ok, data = pcall(TypedTableJson.Decode, payload)
    if not ok then
        error("Storage:load() JSON decode failed for " .. tostring(fileName) .. ": " .. tostring(data))
    end
    return data
end

---@return table|nil
function Storage:load()
    local data = self:_loadFile(self.fileName)
    if data then
        return data
    end

    print("[WastelandZones] No v2 storage found at " .. tostring(self.fileName) .. ". "
        .. legacyConversionMessage(self.fileName))
    return nil
end

return Storage
