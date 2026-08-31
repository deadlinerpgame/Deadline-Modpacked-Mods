--
-- WastelandZones/WZJson.lua
--
-- Adapted from rxi/json.lua (MIT License).
-- Bundled under a WastelandZones-specific module path to avoid collisions
-- with other mods that provide a generic json module.
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.

local Json = { _version = "0.1.2-wasteland-zones" }

local ARRAY_MARKER = {}
local NULL = {}
Json.Null = NULL
local encode

local escapeCharMap = {
    ["\\"] = "\\",
    ["\""] = "\"",
    ["\b"] = "b",
    ["\f"] = "f",
    ["\n"] = "n",
    ["\r"] = "r",
    ["\t"] = "t"
}

local escapeCharMapInverse = { ["/"] = "/" }
for character, escaped in pairs(escapeCharMap) do
    escapeCharMapInverse[escaped] = character
end

local function escapeCharacter(character)
    return "\\" .. (escapeCharMap[character] or string.format("u%04x", character:byte()))
end

local function encodeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', escapeCharacter) .. '"'
end

local function encodeNumber(value)
    if value ~= value or value <= -math.huge or value >= math.huge then
        error("cannot encode non-finite number")
    end
    -- Lua numbers are doubles in Project Zomboid. Seventeen significant
    -- digits are sufficient to recover the exact finite double on decode.
    return (string.format("%.17g", value):gsub(",", "."))
end

local function encodeTable(value, stack)
    if value == NULL then
        return "null"
    end
    if stack[value] then
        error("cannot encode circular table")
    end
    stack[value] = true

    local isArray = getmetatable(value) == ARRAY_MARKER or rawget(value, 1) ~= nil
    if isArray then
        local count = 0
        for key, _ in pairs(value) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
                error("cannot encode array with a non-positive-integer key")
            end
            count = count + 1
        end
        if count ~= #value then
            error("cannot encode sparse array")
        end

        local values = {}
        for index = 1, #value do
            values[index] = encode(value[index], stack)
        end
        stack[value] = nil
        return "[" .. table.concat(values, ",") .. "]"
    end

    local values = {}
    for key, nestedValue in pairs(value) do
        if type(key) ~= "string" then
            error("cannot encode object with non-string key")
        end
        values[#values + 1] = encodeString(key) .. ":" .. encode(nestedValue, stack)
    end
    stack[value] = nil
    return "{" .. table.concat(values, ",") .. "}"
end

local encodeFunctions = {
    ["nil"] = function() return "null" end,
    ["table"] = encodeTable,
    ["string"] = encodeString,
    ["number"] = encodeNumber,
    ["boolean"] = tostring
}

encode = function(value, stack)
    local encoder = encodeFunctions[type(value)]
    if not encoder then
        error("cannot encode unsupported type '" .. type(value) .. "'")
    end
    return encoder(value, stack or {})
end

---@param values table
---@return table
function Json.Array(values)
    return setmetatable(values or {}, ARRAY_MARKER)
end

---@param value any
---@return boolean
function Json.IsArray(value)
    return type(value) == "table" and getmetatable(value) == ARRAY_MARKER
end

---@param value any
---@return string
function Json.Encode(value)
    return encode(value, {})
end

local function decodeError(source, index, message)
    local line = 1
    local column = 1
    for position = 1, index - 1 do
        if source:sub(position, position) == "\n" then
            line = line + 1
            column = 1
        else
            column = column + 1
        end
    end
    error(string.format("%s at line %d column %d", message, line, column))
end

local function skipWhitespace(source, index)
    while index <= #source do
        local character = source:sub(index, index)
        if character ~= " " and character ~= "\t" and character ~= "\r" and character ~= "\n" then
            break
        end
        index = index + 1
    end
    return index
end

local function codepointToUtf8(codepoint)
    if codepoint <= 0x7f then
        return string.char(codepoint)
    elseif codepoint <= 0x7ff then
        return string.char(math.floor(codepoint / 64) + 192, codepoint % 64 + 128)
    elseif codepoint <= 0xffff then
        return string.char(math.floor(codepoint / 4096) + 224,
            math.floor(codepoint % 4096 / 64) + 128, codepoint % 64 + 128)
    elseif codepoint <= 0x10ffff then
        return string.char(math.floor(codepoint / 262144) + 240,
            math.floor(codepoint % 262144 / 4096) + 128,
            math.floor(codepoint % 4096 / 64) + 128, codepoint % 64 + 128)
    end
    error(string.format("invalid unicode codepoint '%x'", codepoint))
end

local function parseUnicodeEscape(source, index)
    local hex = source:sub(index, index + 3)
    if not hex:match("^%x%x%x%x$") then
        decodeError(source, index, "invalid unicode escape")
    end

    local first = tonumber(hex, 16)
    if first >= 0xd800 and first <= 0xdbff and source:sub(index + 4, index + 5) == "\\u" then
        local lowHex = source:sub(index + 6, index + 9)
        if not lowHex:match("^%x%x%x%x$") then
            decodeError(source, index + 6, "invalid unicode escape")
        end
        local second = tonumber(lowHex, 16)
        if second < 0xdc00 or second > 0xdfff then
            decodeError(source, index + 6, "invalid unicode surrogate pair")
        end
        return codepointToUtf8((first - 0xd800) * 0x400 + (second - 0xdc00) + 0x10000), index + 10
    end

    return codepointToUtf8(first), index + 4
end

local parseValue

local function parseString(source, index)
    local parts = {}
    index = index + 1
    local start = index

    while index <= #source do
        local byte = source:byte(index)
        if byte < 32 then
            decodeError(source, index, "control character in string")
        elseif byte == 34 then
            parts[#parts + 1] = source:sub(start, index - 1)
            return table.concat(parts), index + 1
        elseif byte == 92 then
            parts[#parts + 1] = source:sub(start, index - 1)
            local escaped = source:sub(index + 1, index + 1)
            if escaped == "u" then
                local unicode, nextIndex = parseUnicodeEscape(source, index + 2)
                parts[#parts + 1] = unicode
                index = nextIndex
            else
                local replacement = escapeCharMapInverse[escaped]
                if not replacement then
                    decodeError(source, index, "invalid escape character")
                end
                parts[#parts + 1] = replacement
                index = index + 2
            end
            start = index
        else
            index = index + 1
        end
    end

    decodeError(source, start - 1, "expected closing quote for string")
end

local function parseNumber(source, index)
    local startIndex = index
    local character = source:sub(index, index)
    if character == "-" then
        index = index + 1
        character = source:sub(index, index)
    end

    if character == "0" then
        index = index + 1
        if source:sub(index, index):match("%d") then
            decodeError(source, index, "leading zero in number")
        end
    elseif character:match("[1-9]") then
        repeat
            index = index + 1
            character = source:sub(index, index)
        until not character:match("%d")
    else
        decodeError(source, index, "invalid number")
    end

    if source:sub(index, index) == "." then
        index = index + 1
        if not source:sub(index, index):match("%d") then
            decodeError(source, index, "expected digit after decimal point")
        end
        repeat index = index + 1 until not source:sub(index, index):match("%d")
    end

    character = source:sub(index, index)
    if character == "e" or character == "E" then
        index = index + 1
        character = source:sub(index, index)
        if character == "+" or character == "-" then
            index = index + 1
        end
        if not source:sub(index, index):match("%d") then
            decodeError(source, index, "expected digit in exponent")
        end
        repeat index = index + 1 until not source:sub(index, index):match("%d")
    end

    local value = tonumber(source:sub(startIndex, index - 1))
    if not value then
        decodeError(source, index, "invalid number")
    end
    return value, index
end

local function parseLiteral(source, index)
    if source:sub(index, index + 3) == "true" then
        return true, index + 4
    elseif source:sub(index, index + 4) == "false" then
        return false, index + 5
    elseif source:sub(index, index + 3) == "null" then
        return NULL, index + 4
    end
    decodeError(source, index, "invalid literal")
end

local function parseArray(source, index)
    local result = Json.Array()
    local count = 1
    index = skipWhitespace(source, index + 1)
    if source:sub(index, index) == "]" then
        return result, index + 1
    end

    while true do
        local value
        value, index = parseValue(source, index)
        result[count] = value
        count = count + 1
        index = skipWhitespace(source, index)
        local delimiter = source:sub(index, index)
        if delimiter == "]" then
            return result, index + 1
        end
        if delimiter ~= "," then
            decodeError(source, index, "expected ']' or ','")
        end
        index = skipWhitespace(source, index + 1)
    end
end

local function parseObject(source, index)
    local result = {}
    index = skipWhitespace(source, index + 1)
    if source:sub(index, index) == "}" then
        return result, index + 1
    end

    while true do
        if source:sub(index, index) ~= '"' then
            decodeError(source, index, "expected string for object key")
        end
        local key
        key, index = parseString(source, index)
        index = skipWhitespace(source, index)
        if source:sub(index, index) ~= ":" then
            decodeError(source, index, "expected ':' after object key")
        end
        index = skipWhitespace(source, index + 1)
        local value
        value, index = parseValue(source, index)
        result[key] = value
        index = skipWhitespace(source, index)
        local delimiter = source:sub(index, index)
        if delimiter == "}" then
            return result, index + 1
        end
        if delimiter ~= "," then
            decodeError(source, index, "expected '}' or ','")
        end
        index = skipWhitespace(source, index + 1)
    end
end

parseValue = function(source, index)
    index = skipWhitespace(source, index)
    local character = source:sub(index, index)
    if character == '"' then
        return parseString(source, index)
    elseif character == "{" then
        return parseObject(source, index)
    elseif character == "[" then
        return parseArray(source, index)
    elseif character == "-" or character:match("%d") then
        return parseNumber(source, index)
    elseif character == "t" or character == "f" or character == "n" then
        return parseLiteral(source, index)
    end
    decodeError(source, index, "unexpected character '" .. character .. "'")
end

---@param source string
---@return any
function Json.Decode(source)
    if type(source) ~= "string" then
        error("expected a string, got " .. type(source))
    end
    local value, index = parseValue(source, 1)
    index = skipWhitespace(source, index)
    if index <= #source then
        decodeError(source, index, "trailing data")
    end
    return value
end

return Json
