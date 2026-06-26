if getActivatedMods():contains("Lifestyle")  then
    require("TimedActions/ToneDeafSuffering")
    require("TimedActions/PraiseMusician")
    require("TimedActions/BooingMusician")

    ToneDeafSuffering.isValid = function()
        return false
    end
    PraiseMusician.isValid = function()
        return false
    end
    BooingMusician.isValid = function()
        return false
    end
end