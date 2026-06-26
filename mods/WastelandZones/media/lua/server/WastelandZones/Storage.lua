require("WLBaseObject")

---@class WastelandZones.Classes.Storage: WLBaseObject
---@field fileName string
---@field serializerVersion integer
local Storage = WastelandZones.Classes.Storage or WLBaseObject:derive("WastelandZones.Classes.Storage")
if not WastelandZones.Classes.Storage then
    WastelandZones.Classes.Storage = Storage
end

local MAGIC = "--WZDATA"
local INDENT = "\t"

-- Stable sort keys: numbers first (ascending), then strings (lex)
local function sortedKeys(t)
    local nums, strs = {}, {}
    for k, _ in pairs(t) do
        if type(k) == "number" then
            nums[#nums+1] = k
        elseif type(k) == "string" then
            strs[#strs+1] = k
        else
            error("Unsupported table key type: " .. type(k))
        end
    end
    table.sort(nums)
    table.sort(strs)
    local out = {}
    for i=1,#nums do out[#out+1] = nums[i] end
    for i=1,#strs do out[#out+1] = strs[i] end
    return out
end

local function isArrayLike(t)
    -- We treat as array-like if keys are 1..n with no gaps and no non-integer number keys.
    local n = 0
    for k,_ in pairs(t) do
        if type(k) ~= "number" or k % 1 ~= 0 or k < 1 then
            return false
        end
        if k > n then n = k end
    end
    for i=1,n do
        if rawget(t,i) == nil then return false end
    end
    return true
end

local function isNumberArrayLike(t)
    if not isArrayLike(t) then
        return false
    end

    local n = #t
    for i=1,n do
        if type(t[i]) ~= "number" then
            return false
        end
    end

    return true
end

local function writeLine(writer, indent, text)
    writer:writeln(string.rep(INDENT, indent) .. text)
end

local function serializeAtom(v)
    local tv = type(v)

    if tv == "boolean" then
        return v and "true" or "false"

    elseif tv == "number" then
        if v ~= v then error("Cannot serialize NaN") end
        if v == math.huge then error("Cannot serialize +inf") end
        if v == -math.huge then error("Cannot serialize -inf") end
        -- tostring is fine; if you care about locale, ensure dot decimal in your runtime.
        return tostring(v)

    elseif tv == "string" then
        -- %q does correct escaping and wraps in quotes
        return string.format("%q", v)

    else
        error("Unsupported type: " .. tv)
    end
end

local function serializeValue(writer, v, seen, indent, prefix, trailingComma)
    local tv = type(v)
    prefix = prefix or ""

    if tv ~= "table" then
        local line = prefix .. serializeAtom(v)
        if trailingComma then
            line = line .. ","
        end
        writeLine(writer, indent, line)
        return
    end

    if seen[v] then error("Cannot serialize cyclic table") end
    seen[v] = true

    if isNumberArrayLike(v) then
        local n = #v
        local parts = {}
        for i=1,n do
            parts[i] = serializeAtom(v[i])
        end

        local line = prefix .. "{" .. table.concat(parts, ", ") .. "}"
        if trailingComma then
            line = line .. ","
        end

        writeLine(writer, indent, line)
        seen[v] = nil
        return
    end

    writeLine(writer, indent, prefix .. "{")

    if isArrayLike(v) then
        local n = #v
        for i=1,n do
            serializeValue(writer, v[i], seen, indent + 1, nil, i < n)
        end
    else
        local keys = sortedKeys(v)
        for i=1,#keys do
            local k = keys[i]
            local vk = rawget(v, k)
            local tk = type(k)
            local keyPrefix
            if tk == "string" and k:match("^[A-Za-z_][A-Za-z0-9_]*$") then
                keyPrefix = k .. " = "
            else
                keyPrefix = "[" .. serializeAtom(k) .. "] = "
            end
            serializeValue(writer, vk, seen, indent + 1, keyPrefix, i < #keys)
        end
    end

    seen[v] = nil

    local closeLine = "}"
    if trailingComma then
        closeLine = closeLine .. ","
    end
    writeLine(writer, indent, closeLine)
end

local function serializeRoot(writer, data)
    local seen = {}
    serializeValue(writer, data, seen, 0, "return ", false)
end

local function parseHeader(line)
    -- "WZDATA|v=1"
    local magic, v = line:match("^([^|]+)|v=(%d+)$")
    if magic ~= MAGIC or not v then return nil end
    return tonumber(v)
end

---@return WastelandZones.Classes.Storage
function Storage:new()
    local o = Storage.parentClass.new(self)
    o.fileName = "WastelandZones_Data.lua"
    o.serializerVersion = 1
    return o
end

---@param data table
function Storage:save(data)
    local writer = getFileWriter(self.fileName, true, false)
    writer:writeln(MAGIC .. "|v=" .. tostring(self.serializerVersion))
    serializeRoot(writer, data)
    writer:close()
end

---@return table|nil
function Storage:load()
    local reader = getFileReader(self.fileName, true)
    if not reader then return nil end

    local header = reader:readLine()
    if not header or header == "" then
        reader:close()
        return nil
    end

    local fileVersion = parseHeader(header)
    if not fileVersion then
        reader:close()
        error("Storage:load() invalid header: " .. tostring(header))
    end

    local chunkLines = {}
    while true do
        local line = reader:readLine()
        if line == nil then break end
        chunkLines[#chunkLines+1] = line
    end
    reader:close()

    if #chunkLines == 0 then return nil end

    local chunk = table.concat(chunkLines, "\n")
    if chunk == "" then return nil end

    -- Compile safely. Prefer loadstring signature: loadstring(code, chunkname)
    local fn, err = loadstring(chunk, "@" .. self.fileName)
    if not fn then
        error("Storage:load() loadstring failed: " .. tostring(err))
    end

    local data = fn()

    -- Migration hook
    if fileVersion ~= self.serializerVersion then
        data = self:migrate(data, fileVersion, self.serializerVersion)
    end

    return data
end

---@param data table
---@param fromVersion integer
---@param toVersion integer
---@return table
function Storage:migrate(data, fromVersion, toVersion)
    return data
end
