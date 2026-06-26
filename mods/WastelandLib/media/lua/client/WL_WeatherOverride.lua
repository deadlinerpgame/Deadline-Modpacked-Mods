if not isClient() then return end

if WL_WeatherOverride and WL_WeatherOverride.OnClimateTick then
    -- If the module is already loaded, remove the existing event handler
    Events.OnTick.Remove(WL_WeatherOverride.OnClimateTick)
end

-- Initialize the WeatherOverride module
WL_WeatherOverride = WL_WeatherOverride or {}

-- Climate manager constants
local FLOAT_DESATURATION = 0
local FLOAT_GLOBAL_LIGHT_INTENSITY = 1
local FLOAT_NIGHT_STRENGTH = 2
local FLOAT_PRECIPITATION_INTENSITY = 3
local FLOAT_TEMPERATURE = 4
local FLOAT_FOG_INTENSITY = 5
local FLOAT_WIND_INTENSITY = 6
local FLOAT_WIND_ANGLE_INTENSITY = 7
local FLOAT_CLOUD_INTENSITY = 8
local FLOAT_AMBIENT = 9
local FLOAT_VIEW_DISTANCE = 10
local FLOAT_DAYLIGHT_STRENGTH = 11
local FLOAT_HUMIDITY = 12
local COLOR_GLOBAL_LIGHT = 0
local COLOR_NEW_FOG = 1
local BOOL_IS_SNOW = 0

-- Data structures to track overrides
-- Format: overrides[type][key] = {
--   value = value,
--   timestamp = timestamp,
--   startValue = startValue (for transitions),
--   finalValue = finalValue (for transitions),
--   transitionTicks = transitionTicks (for transitions),
--   currentTick = currentTick (for transitions)
-- }
WL_WeatherOverride.overrides = {}
-- Format: activeOverrides[type] = { key = key, value = value, isTransitioning = boolean, isTransitioningOut = boolean }
WL_WeatherOverride.activeOverrides = {}
-- Format: originalValues[type] = { value = originalValue, timestamp = timestamp }
WL_WeatherOverride.originalValues = {}

-- Weather types
WL_WeatherOverride.WEATHER_TYPES = {
    "Wind",
    "Clouds",
    "Fog",
    "Precipitation",
    "Temperature",
    "Darkness",
    "Desaturation",
    "Light"
}

-- Initialize the overrides tables
for _, weatherType in ipairs(WL_WeatherOverride.WEATHER_TYPES) do
    WL_WeatherOverride.overrides[weatherType] = {}
end

-----------------------------------------------------------
-- API Functions
-----------------------------------------------------------

--- Sets a weather override with the specified key. Original weather values are automatically
--- stored when the first override is applied and can be transitioned back to when cleared.
--- @param key string A unique identifier for the mod setting the override
--- @param weatherType string The type of weather override (Wind, Clouds, Fog, etc.)
--- @param value table The value to set for the override, format depends on weatherType:
--- @param transitionTicks number|nil Optional number of ticks to transition over (nil for instant)
---   - Wind: { intensity = number } (0.0 to 1.0)
---   - Clouds: { intensity = number } (0.0 to 1.0)
---   - Fog: { intensity = number } (0.0 to 1.0)
---   - Precipitation: { intensity = number, isSnow = boolean } (intensity 0.0 to 1.0)
---   - Temperature: { value = number } (in Celsius)
---   - Darkness: { value = number } (0.0 to 1.0)
---   - Desaturation: { value = number } (0.0 to 1.0)
---   - Light: { intR = number, intG = number, intB = number, intA = number,
---              extR = number, extG = number, extB = number, extA = number } (0-255)
function WL_WeatherOverride.SetOverride(key, weatherType, value, transitionTicks)
    if not key or not weatherType or not value then
        print("WL_WeatherOverride.SetOverride: Missing required parameters")
        return false
    end
    
    -- Validate weather type
    if not WL_WeatherOverride.IsValidWeatherType(weatherType) then
        print("WL_WeatherOverride.SetOverride: Invalid weather type: " .. weatherType)
        return false
    end
    
    -- Validate value based on weather type
    if not WL_WeatherOverride.IsValidValue(weatherType, value) then
        print("WL_WeatherOverride.SetOverride: Invalid value for weather type: " .. weatherType)
        return false
    end
    
    -- Check if we already have an override for this key
    local existingOverride = WL_WeatherOverride.overrides[weatherType][key]
    
    -- If we have an existing override with the same final value, don't restart transition
    if existingOverride then
        if existingOverride.finalValue and WL_WeatherOverride.AreValuesEqual(weatherType, existingOverride.finalValue, value) then
            -- Just update the timestamp to maintain priority
            existingOverride.timestamp = getTimestampMs()
            return true
        elseif existingOverride.value and WL_WeatherOverride.AreValuesEqual(weatherType, existingOverride.value, value) then
            existingOverride.timestamp = getTimestampMs()
            return true
        end
    end
    
    -- Prepare override data
    local overrideData = {
        value = value,
        timestamp = getTimestampMs()
    }
    
    -- Handle transition if specified
    if transitionTicks and transitionTicks > 0 then
        local startValue = WL_WeatherOverride.GetCurrentClimateValue(weatherType)
        if startValue then
            overrideData.value = startValue -- Store the current value as startValue
            overrideData.startValue = startValue
            overrideData.finalValue = value
            overrideData.transitionTicks = transitionTicks
            overrideData.currentTick = 0
        end
    end
    
    -- Store the override
    WL_WeatherOverride.overrides[weatherType][key] = overrideData
    
    -- Update active override if this is now the most recent
    WL_WeatherOverride.UpdateActiveOverride(weatherType)
    
    return true
end

--- Unsets a weather override with the specified key. If this was the active override,
--- it can optionally transition back to the original weather values.
--- @param key string The identifier for the mod that set the override
--- @param weatherType string The type of weather override to unset
--- @param transitionTicks number|nil Optional number of ticks to transition back to original values (nil for instant)
function WL_WeatherOverride.UnsetOverride(key, weatherType, transitionTicks)
    if not key or not weatherType then
        print("WL_WeatherOverride.UnsetOverride: Missing required parameters")
        return false
    end
    
    -- Validate weather type
    if not WL_WeatherOverride.IsValidWeatherType(weatherType) then
        print("WL_WeatherOverride.UnsetOverride: Invalid weather type: " .. weatherType)
        return false
    end
    
    -- Check if this is the active override before removing
    local wasActive = false
    local activeOverride = WL_WeatherOverride.activeOverrides[weatherType]
    if activeOverride and activeOverride.key == key then
        wasActive = true
    end
    
    -- Remove the override
    WL_WeatherOverride.overrides[weatherType][key] = nil
    
    -- Update active override with transition support
    WL_WeatherOverride.UpdateActiveOverride(weatherType, wasActive and transitionTicks or nil)
    
    return true
end

--- Unsets all weather overrides set by a specific key. Active overrides can optionally
--- transition back to the original weather values.
--- @param key string The identifier for the mod that set the overrides
--- @param transitionTicks number|nil Optional number of ticks to transition back to original values (nil for instant)
function WL_WeatherOverride.UnsetAllOverrides(key, transitionTicks)
    if not key then
        print("WL_WeatherOverride.UnsetAllOverrides: Missing required parameter")
        return false
    end
    
    -- Remove all overrides for this key
    for weatherType, _ in pairs(WL_WeatherOverride.overrides) do
        -- Only process if this key actually has an override for this weather type
        if WL_WeatherOverride.overrides[weatherType][key] then
            -- Check if this is the active override before removing
            local wasActive = false
            local activeOverride = WL_WeatherOverride.activeOverrides[weatherType]
            if activeOverride and activeOverride.key == key then
                wasActive = true
            end
            
            WL_WeatherOverride.overrides[weatherType][key] = nil
            WL_WeatherOverride.UpdateActiveOverride(weatherType, wasActive and transitionTicks or nil)
        end
    end
    
    return true
end

--- Sets multiple weather overrides at once with the specified key. Weather types not included
--- in the overrides table will be unset and can optionally transition back to original values.
--- @param key string A unique identifier for the mod setting the overrides
--- @param overrides table A table of weather overrides where keys are weather types and values are the override values
--- @param transitionTicks number|nil Optional number of ticks to transition over (nil for instant). Also applies to transition-out for unset weather types.
--- @return boolean True if all overrides were set successfully, false otherwise. If false, some values may still have been set.
function WL_WeatherOverride.SetBulkOverrides(key, overrides, transitionTicks)
    if not key or not overrides then
        print("WL_WeatherOverride.SetBulkOverrides: Missing required parameters")
        return false
    end
    
    if type(overrides) ~= "table" then
        print("WL_WeatherOverride.SetBulkOverrides: Overrides must be a table")
        return false
    end
    
    local timestamp = getTimestampMs()
    local success = true
    local processedWeatherTypes = {}
    
    -- Process each override
    for weatherType, value in pairs(overrides) do
        processedWeatherTypes[weatherType] = true
        local isValid = true
        
        -- Validate weather type
        if not WL_WeatherOverride.IsValidWeatherType(weatherType) then
            print("WL_WeatherOverride.SetBulkOverrides: Invalid weather type: " .. weatherType)
            success = false
            isValid = false
        end
        
        -- Validate value based on weather type
        if isValid and not WL_WeatherOverride.IsValidValue(weatherType, value) then
            print("WL_WeatherOverride.SetBulkOverrides: Invalid value for weather type: " .. weatherType)
            success = false
            isValid = false
        end
        
        -- Only store and update if valid
        if isValid then
            -- Check if we already have an override for this key with the same final value
            local existingOverride = WL_WeatherOverride.overrides[weatherType][key]
            
            if existingOverride and existingOverride.finalValue and WL_WeatherOverride.AreValuesEqual(weatherType, existingOverride.finalValue, value) then
                -- Just update the timestamp to maintain priority
                existingOverride.timestamp = timestamp
            elseif existingOverride and existingOverride.value and WL_WeatherOverride.AreValuesEqual(weatherType, existingOverride.value, value) then
                existingOverride.timestamp = timestamp
            else
                -- Prepare override data
                local overrideData = {
                    value = value,
                    timestamp = timestamp
                }
                
                -- Handle transition if specified
                if transitionTicks and transitionTicks > 0 then
                    local startValue = WL_WeatherOverride.GetCurrentClimateValue(weatherType)
                    if startValue then
                        overrideData.value = startValue -- Store the current value as startValue
                        overrideData.startValue = startValue
                        overrideData.finalValue = value
                        overrideData.transitionTicks = transitionTicks
                        overrideData.currentTick = 0
                    end
                end
                
                -- Store the override
                WL_WeatherOverride.overrides[weatherType][key] = overrideData
            end
        end
    end

    -- Clear any overrides for weather types that weren't included in the bulk set
    for weatherType, _ in pairs(WL_WeatherOverride.overrides) do
        if not processedWeatherTypes[weatherType] then
            -- Only process if this key actually had an override for this weather type
            if WL_WeatherOverride.overrides[weatherType][key] then
                -- Check if this is the active override before removing
                local wasActive = false
                local activeOverride = WL_WeatherOverride.activeOverrides[weatherType]
                if activeOverride and activeOverride.key == key then
                    wasActive = true
                end
                
                WL_WeatherOverride.overrides[weatherType][key] = nil
                WL_WeatherOverride.UpdateActiveOverride(weatherType, wasActive and transitionTicks or nil)
            end
        else
            WL_WeatherOverride.UpdateActiveOverride(weatherType)
        end
    end
    
    return success
end

--- Gets the currently active override for a specific type
--- @param weatherType string The type of weather override
--- @return table|nil The active override value or nil if none is active
function WL_WeatherOverride.GetActiveOverride(weatherType)
    if not weatherType then
        print("WL_WeatherOverride.GetActiveOverride: Missing required parameter")
        return nil
    end
    
    -- Validate weather type
    if not WL_WeatherOverride.IsValidWeatherType(weatherType) then
        print("WL_WeatherOverride.GetActiveOverride: Invalid weather type: " .. weatherType)
        return nil
    end
    
    local activeOverride = WL_WeatherOverride.activeOverrides[weatherType]
    if activeOverride then
        return activeOverride.value
    end
    
    return nil
end

--- Transitions out of all active weather overrides back to original values
--- @param transitionTicks number Number of ticks to transition over
--- @return boolean True if transition was started, false if no active overrides
function WL_WeatherOverride.TransitionOutAll(transitionTicks)
    if not transitionTicks or transitionTicks <= 0 then
        print("WL_WeatherOverride.TransitionOutAll: Invalid transition ticks")
        return false
    end
    
    local hasActiveOverrides = false
    
    -- Start transition out for all active overrides
    for weatherType, activeOverride in pairs(WL_WeatherOverride.activeOverrides) do
        if activeOverride and not activeOverride.isTransitioningOut then
            hasActiveOverrides = true
            
            if WL_WeatherOverride.originalValues[weatherType] then
                WL_WeatherOverride.activeOverrides[weatherType] = {
                    key = "_transition_out_",
                    value = activeOverride.value,
                    isTransitioning = true,
                    isTransitioningOut = true,
                    startValue = activeOverride.value,
                    finalValue = WL_WeatherOverride.originalValues[weatherType].value,
                    transitionTicks = transitionTicks,
                    currentTick = 0
                }
            else
                -- No original value stored, clear immediately
                WL_WeatherOverride.activeOverrides[weatherType] = nil
                WL_WeatherOverride.ClearOverride(weatherType)
            end
        end
    end
    
    return hasActiveOverrides
end

-----------------------------------------------------------
-- Internal Functions
-----------------------------------------------------------

--- Gets the current climate value for a specific weather type
--- @param weatherType string The type of weather
--- @return table|nil The current climate value or nil if unable to retrieve
function WL_WeatherOverride.GetCurrentClimateValue(weatherType)
    local cm = getClimateManager()
    
    if weatherType == "Wind" then
        return { intensity = cm:getClimateFloat(FLOAT_WIND_INTENSITY):getFinalValue() }
    elseif weatherType == "Clouds" then
        return { intensity = cm:getClimateFloat(FLOAT_CLOUD_INTENSITY):getFinalValue() }
    elseif weatherType == "Fog" then
        return { intensity = cm:getClimateFloat(FLOAT_FOG_INTENSITY):getFinalValue() }
    elseif weatherType == "Precipitation" then
        return {
            intensity = cm:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):getFinalValue(),
            isSnow = cm:getClimateBool(BOOL_IS_SNOW):getInternalValue()
        }
    elseif weatherType == "Temperature" then
        return { value = cm:getClimateFloat(FLOAT_TEMPERATURE):getFinalValue() + 40 } -- Adjust for game's temperature scale
    elseif weatherType == "Darkness" then
        return { value = cm:getClimateFloat(FLOAT_NIGHT_STRENGTH):getFinalValue() }
    elseif weatherType == "Desaturation" then
        return { value = cm:getClimateFloat(FLOAT_DESATURATION):getFinalValue() }
    elseif weatherType == "Light" then
        local color = cm:getClimateColor(COLOR_GLOBAL_LIGHT):getFinalValue()
        local intColor = color:getInterior()
        local extColor = color:getExterior()
        return {
            intR = intColor:getRedFloat() * 255,
            intG = intColor:getGreenFloat() * 255,
            intB = intColor:getBlueFloat() * 255,
            intA = intColor:getAlphaFloat() * 255,
            extR = extColor:getRedFloat() * 255,
            extG = extColor:getGreenFloat() * 255,
            extB = extColor:getBlueFloat() * 255,
            extA = extColor:getAlphaFloat() * 255
        }
    end
    
    return nil
end

--- Interpolates between two weather values based on progress
--- @param weatherType string The type of weather
--- @param startValue table The starting value
--- @param finalValue table The final value
--- @param progress number Progress from 0.0 to 1.0
--- @return table The interpolated value
function WL_WeatherOverride.InterpolateValue(weatherType, startValue, finalValue, progress)
    if weatherType == "Wind" or weatherType == "Clouds" or weatherType == "Fog" then
        return {
            intensity = startValue.intensity + (finalValue.intensity - startValue.intensity) * progress
        }
    elseif weatherType == "Precipitation" then
        return {
            intensity = startValue.intensity + (finalValue.intensity - startValue.intensity) * progress,
            isSnow = finalValue.isSnow or startValue.isSnow
        }
    elseif weatherType == "Temperature" or weatherType == "Darkness" or weatherType == "Desaturation" then
        return {
            value = startValue.value + (finalValue.value - startValue.value) * progress
        }
    elseif weatherType == "Light" then
        return {
            intR = startValue.intR + (finalValue.intR - startValue.intR) * progress,
            intG = startValue.intG + (finalValue.intG - startValue.intG) * progress,
            intB = startValue.intB + (finalValue.intB - startValue.intB) * progress,
            intA = startValue.intA + (finalValue.intA - startValue.intA) * progress,
            extR = startValue.extR + (finalValue.extR - startValue.extR) * progress,
            extG = startValue.extG + (finalValue.extG - startValue.extG) * progress,
            extB = startValue.extB + (finalValue.extB - startValue.extB) * progress,
            extA = startValue.extA + (finalValue.extA - startValue.extA) * progress
        }
    end
    
    return finalValue -- Fallback
end

--- Compares two weather values to check if they are equal
--- @param weatherType string The type of weather
--- @param value1 table The first value to compare
--- @param value2 table The second value to compare
--- @return boolean True if values are equal, false otherwise
function WL_WeatherOverride.AreValuesEqual(weatherType, value1, value2)
    if not value1 or not value2 then
        return false
    end
    
    if weatherType == "Wind" or weatherType == "Clouds" or weatherType == "Fog" then
        return value1.intensity == value2.intensity
    elseif weatherType == "Precipitation" then
        return value1.intensity == value2.intensity and value1.isSnow == value2.isSnow
    elseif weatherType == "Temperature" or weatherType == "Darkness" or weatherType == "Desaturation" then
        return value1.value == value2.value
    elseif weatherType == "Light" then
        return value1.intR == value2.intR and value1.intG == value2.intG and
               value1.intB == value2.intB and value1.intA == value2.intA and
               value1.extR == value2.extR and value1.extG == value2.extG and
               value1.extB == value2.extB and value1.extA == value2.extA
    end
    
    return false
end

--- Checks if a weather type is valid
--- @param weatherType string The weather type to check
--- @return boolean True if valid, false otherwise
function WL_WeatherOverride.IsValidWeatherType(weatherType)
    for _, validType in ipairs(WL_WeatherOverride.WEATHER_TYPES) do
        if weatherType == validType then
            return true
        end
    end
    return false
end

--- Validates a value based on the weather type
--- @param weatherType string The type of weather
--- @param value table The value to validate
--- @return boolean True if valid, false otherwise
function WL_WeatherOverride.IsValidValue(weatherType, value)
    if weatherType == "Wind" or weatherType == "Clouds" or weatherType == "Fog" then
        return value.intensity ~= nil and type(value.intensity) == "number"
    elseif weatherType == "Precipitation" then
        return value.intensity ~= nil and type(value.intensity) == "number" and
               value.isSnow ~= nil and type(value.isSnow) == "boolean"
    elseif weatherType == "Temperature" or weatherType == "Darkness" or weatherType == "Desaturation" then
        return value.value ~= nil and type(value.value) == "number"
    elseif weatherType == "Light" then
        return value.intR ~= nil and value.intG ~= nil and value.intB ~= nil and value.intA ~= nil and
               value.extR ~= nil and value.extG ~= nil and value.extB ~= nil and value.extA ~= nil
    end
    return false
end

--- Updates the active override for a specific weather type
--- @param weatherType string The type of weather override
--- @param transitionOutTicks number|nil Optional number of ticks to transition out (nil for instant)
function WL_WeatherOverride.UpdateActiveOverride(weatherType, transitionOutTicks)
    local overridesForType = WL_WeatherOverride.overrides[weatherType]
    local mostRecentKey = nil
    local mostRecentTimestamp = 0
    local mostRecentValue = nil
    
    -- Find the most recent override
    for key, override in pairs(overridesForType) do
        if override.timestamp > mostRecentTimestamp then
            mostRecentKey = key
            mostRecentTimestamp = override.timestamp
            mostRecentValue = override.value
        end
    end
    
    -- Update active override
    if mostRecentKey then
        local mostRecentOverride = overridesForType[mostRecentKey]
        local isTransitioning = mostRecentOverride.transitionTicks and
                               mostRecentOverride.currentTick < mostRecentOverride.transitionTicks
        
        -- Store original values if this is the first override for this weather type
        if not WL_WeatherOverride.originalValues[weatherType] then
            local originalValue = WL_WeatherOverride.GetCurrentClimateValue(weatherType)
            if originalValue then
                WL_WeatherOverride.originalValues[weatherType] = {
                    value = originalValue,
                    timestamp = getTimestampMs()
                }
            end
        end
        
        WL_WeatherOverride.activeOverrides[weatherType] = {
            key = mostRecentKey,
            value = mostRecentValue,
            isTransitioning = isTransitioning,
            isTransitioningOut = false
        }
        -- Will get applied in the next climate tick
    else
        -- No active overrides, handle transition out or clear immediately
        if transitionOutTicks and transitionOutTicks > 0 and WL_WeatherOverride.originalValues[weatherType] then
            -- Start transition back to original values
            local currentActiveOverride = WL_WeatherOverride.activeOverrides[weatherType]
            if currentActiveOverride and currentActiveOverride.value then
                WL_WeatherOverride.activeOverrides[weatherType] = {
                    key = "_transition_out_",
                    value = currentActiveOverride.value,
                    isTransitioning = true,
                    isTransitioningOut = true,
                    startValue = currentActiveOverride.value,
                    finalValue = WL_WeatherOverride.originalValues[weatherType].value,
                    transitionTicks = transitionOutTicks,
                    currentTick = 0
                }
            else
                -- No current override to transition from, clear immediately
                WL_WeatherOverride.activeOverrides[weatherType] = nil
                WL_WeatherOverride.originalValues[weatherType] = nil
                WL_WeatherOverride.ClearOverride(weatherType)
            end
        else
            -- Clear immediately without transition
            WL_WeatherOverride.activeOverrides[weatherType] = nil
            WL_WeatherOverride.originalValues[weatherType] = nil
            WL_WeatherOverride.ClearOverride(weatherType)
        end
    end
end

--- Applies a specific weather override
--- @param weatherType string The type of weather override
--- @param value table The value to apply
function WL_WeatherOverride.ApplyOverride(weatherType, value)
    local cm = getClimateManager()
    
    if weatherType == "Wind" then
        cm:getClimateFloat(FLOAT_WIND_INTENSITY):setModdedValue(value.intensity)
        cm:getClimateFloat(FLOAT_WIND_INTENSITY):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_WIND_INTENSITY):setEnableModded(true)
        cm:getClimateFloat(FLOAT_WIND_INTENSITY):setEnableOverride(false)
    elseif weatherType == "Clouds" then
        cm:getClimateFloat(FLOAT_CLOUD_INTENSITY):setModdedValue(value.intensity)
        cm:getClimateFloat(FLOAT_CLOUD_INTENSITY):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_CLOUD_INTENSITY):setEnableModded(true)
        cm:getClimateFloat(FLOAT_CLOUD_INTENSITY):setEnableOverride(false)
    elseif weatherType == "Fog" then
        cm:getClimateFloat(FLOAT_FOG_INTENSITY):setModdedValue(value.intensity)
        cm:getClimateFloat(FLOAT_FOG_INTENSITY):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_FOG_INTENSITY):setEnableModded(true)
        cm:getClimateFloat(FLOAT_FOG_INTENSITY):setEnableOverride(false)
    elseif weatherType == "Precipitation" then
        cm:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setModdedValue(value.intensity)
        cm:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableModded(true)
        cm:getClimateFloat(FLOAT_PRECIPITATION_INTENSITY):setEnableOverride(false)
        cm:getClimateBool(BOOL_IS_SNOW):setModdedValue(value.isSnow)
        cm:getClimateBool(BOOL_IS_SNOW):setEnableModded(true)
        cm:getClimateBool(BOOL_IS_SNOW):setEnableOverride(false)
    elseif weatherType == "Temperature" then
        cm:getClimateFloat(FLOAT_TEMPERATURE):setModdedValue(value.value - 40) -- Adjust for game's temperature scale
        cm:getClimateFloat(FLOAT_TEMPERATURE):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_TEMPERATURE):setEnableModded(true)
        cm:getClimateFloat(FLOAT_TEMPERATURE):setEnableOverride(false)
    elseif weatherType == "Darkness" then
        cm:getClimateFloat(FLOAT_DAYLIGHT_STRENGTH):setModdedValue(1.0 - value.value)
        cm:getClimateFloat(FLOAT_DAYLIGHT_STRENGTH):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_DAYLIGHT_STRENGTH):setEnableModded(true)
        cm:getClimateFloat(FLOAT_DAYLIGHT_STRENGTH):setEnableOverride(false)
        cm:getClimateFloat(FLOAT_NIGHT_STRENGTH):setModdedValue(value.value)
        cm:getClimateFloat(FLOAT_NIGHT_STRENGTH):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_NIGHT_STRENGTH):setEnableModded(true)
        cm:getClimateFloat(FLOAT_NIGHT_STRENGTH):setEnableOverride(false)
        cm:getClimateFloat(FLOAT_AMBIENT):setModdedValue(1.0 - value.value)
        cm:getClimateFloat(FLOAT_AMBIENT):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_AMBIENT):setEnableModded(true)
        cm:getClimateFloat(FLOAT_AMBIENT):setEnableOverride(false)
    elseif weatherType == "Desaturation" then
        cm:getClimateFloat(FLOAT_DESATURATION):setModdedValue(value.value)
        cm:getClimateFloat(FLOAT_DESATURATION):setModdedInterpolate(1.0)
        cm:getClimateFloat(FLOAT_DESATURATION):setEnableModded(true)
        cm:getClimateFloat(FLOAT_DESATURATION):setEnableOverride(false)
    elseif weatherType == "Light" then
        local overrideColor = ClimateColorInfo.new(
            value.intR/255, value.intG/255, value.intB/255, value.intA/255,
            value.extR/255, value.extG/255, value.extB/255, value.extA/255
        )
        cm:getClimateColor(COLOR_GLOBAL_LIGHT):setModdedValue(overrideColor)
        cm:getClimateColor(COLOR_GLOBAL_LIGHT):setModdedInterpolate(1.0)
        cm:getClimateColor(COLOR_GLOBAL_LIGHT):setEnableModded(true)
        cm:getClimateColor(COLOR_GLOBAL_LIGHT):setEnableOverride(false)
    end
end

--- Clears a specific weather override
--- @param weatherType string The type of weather override to clear
function WL_WeatherOverride.ClearOverride(weatherType)
    local cm = getClimateManager()
    
    if weatherType == "Wind" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_WIND_INTENSITY)
    elseif weatherType == "Clouds" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_CLOUD_INTENSITY)
    elseif weatherType == "Fog" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_FOG_INTENSITY)
    elseif weatherType == "Precipitation" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_PRECIPITATION_INTENSITY)
        cm:getClimateBool(BOOL_IS_SNOW):setEnableModded(false)
        cm:getClimateBool(BOOL_IS_SNOW):setEnableOverride(true)
    elseif weatherType == "Temperature" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_TEMPERATURE)
    elseif weatherType == "Darkness" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_DAYLIGHT_STRENGTH)
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_NIGHT_STRENGTH)
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_AMBIENT)
    elseif weatherType == "Desaturation" then
        WL_WeatherOverride.ResetWeatherFloat(FLOAT_DESATURATION)
    elseif weatherType == "Light" then
        WL_WeatherOverride.ResetWeatherColor(COLOR_GLOBAL_LIGHT)
    end
end

--- Resets a weather float parameter
--- @param floatType number The climate float type to reset
function WL_WeatherOverride.ResetWeatherFloat(floatType)
    getClimateManager():getClimateFloat(floatType):setEnableModded(false)
    getClimateManager():getClimateFloat(floatType):setEnableOverride(true)
end

--- Resets a weather color parameter
--- @param colorType number The climate color type to reset
function WL_WeatherOverride.ResetWeatherColor(colorType)
    getClimateManager():getClimateColor(colorType):setEnableModded(false)
    getClimateManager():getClimateColor(colorType):setEnableOverride(true)
end

--- Reapplies all active weather overrides
function WL_WeatherOverride.ReapplyOverrides()
    for weatherType, activeOverride in pairs(WL_WeatherOverride.activeOverrides) do
        if activeOverride and activeOverride.value then
            local shouldApplyOverride = true
            
            -- Check if we need to advance any transitions
            if activeOverride.isTransitioning then
                if activeOverride.isTransitioningOut then
                    -- Handle transition out (back to original values)
                    activeOverride.currentTick = activeOverride.currentTick + 1
                    
                    -- Calculate interpolated value
                    local progress = activeOverride.currentTick / activeOverride.transitionTicks
                    local interpolatedValue = WL_WeatherOverride.InterpolateValue(
                        weatherType,
                        activeOverride.startValue,
                        activeOverride.finalValue,
                        progress
                    )
                    
                    -- Update the active override value
                    activeOverride.value = interpolatedValue
                    
                    -- Check if transition is complete
                    if activeOverride.currentTick >= activeOverride.transitionTicks then
                        -- Transition out complete, clear the override
                        WL_WeatherOverride.activeOverrides[weatherType] = nil
                        WL_WeatherOverride.originalValues[weatherType] = nil
                        WL_WeatherOverride.ClearOverride(weatherType)
                        -- Skip applying override since we're clearing it
                        shouldApplyOverride = false
                    end
                else
                    -- Handle normal transition in (to override values)
                    local overrideData = WL_WeatherOverride.overrides[weatherType][activeOverride.key]
                    if overrideData and overrideData.transitionTicks and overrideData.currentTick < overrideData.transitionTicks then
                        -- Advance the transition
                        overrideData.currentTick = overrideData.currentTick + 1
                        
                        -- Calculate interpolated value
                        local progress = overrideData.currentTick / overrideData.transitionTicks
                        local interpolatedValue = WL_WeatherOverride.InterpolateValue(
                            weatherType,
                            overrideData.startValue,
                            overrideData.finalValue,
                            progress
                        )
                        
                        -- Update the active override value
                        activeOverride.value = interpolatedValue
                        overrideData.value = interpolatedValue
                        
                        -- Check if transition is complete
                        if overrideData.currentTick >= overrideData.transitionTicks then
                            activeOverride.isTransitioning = false
                            activeOverride.value = overrideData.finalValue
                            overrideData.value = overrideData.finalValue
                            -- Clean up transition data
                            overrideData.startValue = nil
                            overrideData.currentTick = nil
                            overrideData.transitionTicks = nil
                        end
                    end
                end
            end
            
            if shouldApplyOverride then
                WL_WeatherOverride.ApplyOverride(weatherType, activeOverride.value)
            end
        end
    end
end

--- Climate tick event handler to reapply all active overrides
function WL_WeatherOverride.OnClimateTick()
    WL_WeatherOverride.ReapplyOverrides()
end

-- Register the climate tick event handler
Events.OnTick.Add(WL_WeatherOverride.OnClimateTick)

-- Print initialization message
print("WL_WeatherOverride: Library initialized")
