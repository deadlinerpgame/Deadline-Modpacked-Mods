local newCassetteProps = { ["Weight"] = 0.02 }

if GlobalMusic and type(GlobalMusic) == "table" then
    for item, _ in pairs(GlobalMusic) do
        WL_Utils.setItemProperties("Tsarcraft." .. item, newCassetteProps)
    end
end