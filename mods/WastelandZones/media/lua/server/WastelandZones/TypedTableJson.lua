local Json = require "WastelandZones/WZJson"

local TypedTableJson = {}

local FORMAT = "wasteland-typed-table"
local DOCUMENT_VERSION = 1
local TABLE_MEMBER = "$wastelandTable"

local function checkedNumber(value, description)
    if type(value) ~= "number" then
        error(description .. " must be a number")
    end
    if value ~= value or value == math.huge or value == -math.huge then
        error(description .. " must be finite")
    end
    return value
end

local function sortedKeys(value)
    local numberKeys = {}
    local stringKeys = {}

    for key, _ in pairs(value) do
        local keyType = type(key)
        if keyType == "number" then
            checkedNumber(key, "table key")
            numberKeys[#numberKeys + 1] = key
        elseif keyType == "string" then
            stringKeys[#stringKeys + 1] = key
        else
            error("unsupported table key type '" .. keyType .. "'")
        end
    end

    table.sort(numberKeys)
    table.sort(stringKeys)

    local keys = {}
    for index = 1, #numberKeys do
        keys[#keys + 1] = numberKeys[index]
    end
    for index = 1, #stringKeys do
        keys[#keys + 1] = stringKeys[index]
    end
    return keys
end

local encodeValue

local function encodeTable(value, seen)
    if seen[value] then
        error("cannot encode a cyclic table")
    end
    seen[value] = true

    local entries = Json.Array()
    local keys = sortedKeys(value)
    for index = 1, #keys do
        local key = keys[index]
        local keyType = type(key)
        entries[index] = {
            key = {
                type = keyType,
                value = key
            },
            value = encodeValue(value[key], seen)
        }
    end

    seen[value] = nil
    return { [TABLE_MEMBER] = entries }
end

encodeValue = function(value, seen)
    local valueType = type(value)
    if valueType == "table" then
        return encodeTable(value, seen)
    elseif valueType == "number" then
        return checkedNumber(value, "table value")
    elseif valueType == "string" or valueType == "boolean" or valueType == "nil" then
        return value
    end
    error("unsupported table value type '" .. valueType .. "'")
end

local function decodeValue(value, path)
    if value == Json.Null then
        return nil
    end

    local valueType = type(value)
    if valueType == "table" then
        local entries = value[TABLE_MEMBER]
        if not Json.IsArray(entries) then
            error(path .. " must contain a JSON array named " .. TABLE_MEMBER)
        end

        local decoded = {}
        for index = 1, #entries do
            local entry = entries[index]
            local entryPath = path .. "." .. TABLE_MEMBER .. "[" .. tostring(index) .. "]"
            if type(entry) ~= "table" or type(entry.key) ~= "table" then
                error(entryPath .. " must contain a key descriptor")
            end

            local keyType = entry.key.type
            local key = entry.key.value
            if keyType == "number" then
                key = checkedNumber(key, entryPath .. ".key.value")
            elseif keyType == "string" then
                if type(key) ~= "string" then
                    error(entryPath .. ".key.value must be a string")
                end
            else
                error(entryPath .. ".key.type must be 'string' or 'number'")
            end

            local encodedValue = rawget(entry, "value")
            if encodedValue == nil then
                error(entryPath .. " must contain a value member")
            end

            -- JSON null decodes to nil. Assignment order intentionally makes
            -- duplicate keys and null removals behave like the legacy Lua table.
            decoded[key] = decodeValue(encodedValue, entryPath .. ".value")
        end
        return decoded
    elseif valueType == "number" then
        return checkedNumber(value, path)
    elseif valueType == "string" or valueType == "boolean" or valueType == "nil" then
        return value
    end
    error(path .. " has unsupported decoded type '" .. valueType .. "'")
end

---@param value table
---@return string
function TypedTableJson.Encode(value)
    if type(value) ~= "table" then
        error("typed-table root value must be a table")
    end

    return Json.Encode({
        format = FORMAT,
        version = DOCUMENT_VERSION,
        value = encodeValue(value, {})
    })
end

---@param source string
---@return table
function TypedTableJson.Decode(source)
    local document = Json.Decode(source)
    if type(document) ~= "table" then
        error("typed-table document root must be an object")
    end
    if document.format ~= FORMAT then
        error("unsupported typed-table format '" .. tostring(document.format) .. "'")
    end
    if document.version ~= DOCUMENT_VERSION then
        error("unsupported typed-table document version '" .. tostring(document.version) .. "'")
    end

    local decoded = decodeValue(document.value, "document.value")
    if type(decoded) ~= "table" then
        error("typed-table root value must decode to a table")
    end
    return decoded
end

return TypedTableJson
