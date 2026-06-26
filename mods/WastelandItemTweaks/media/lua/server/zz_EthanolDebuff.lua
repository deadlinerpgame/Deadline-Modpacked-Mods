local scriptManager = getScriptManager()
local spoonEthanol = scriptManager:getItem("Base.SpoonEthanol")
if not spoonEthanol then return end
print("SpoonEthanol found, attempting to clear tags ===")
local fields = getNumClassFields(spoonEthanol)
for i=0,fields-1 do
    local field = getClassField(spoonEthanol, i)
    local fieldName = tostring(field)
    if fieldName == "public final java.util.ArrayList zombie.scripting.objects.Item.Tags" then
        print("=== tags field found, clearing...")
        local tagsList = getClassFieldVal(spoonEthanol, field)
        tagsList:clear()
    end
end