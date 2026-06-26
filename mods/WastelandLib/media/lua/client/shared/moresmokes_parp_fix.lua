if getActivatedMods():contains("MoreSmokes") then
    PARP = PARP or {}
    function PARP:escapeString(str)
        if not str then return "" end
        return str:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
    end
end