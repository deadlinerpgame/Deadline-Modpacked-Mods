# WL_WeatherOverride Library

A library for Project Zomboid mods to manage weather overrides with conflict resolution.

## Overview

The `WL_WeatherOverride` library provides a simple API for mods to set and unset weather overrides. It handles conflicts between different mods by using a timestamp-based system, where the most recently set override takes precedence. When an override is unset, the system automatically reverts to the next most recent override.

## Features

- Set weather overrides with a unique key for your mod
- Set multiple weather overrides at once with a single call
- Automatically handle conflicts between different mods
- Revert to previous overrides when a mod unsets its overrides
- Apply overrides every climate tick to ensure they remain active
- Support for all weather types: Wind, Clouds, Fog, Precipitation, Temperature, Darkness, Desaturation, and Light

## API Reference

### Setting Weather Overrides

```lua
WL_WeatherOverride.SetOverride(key, weatherType, value)
```

- `key`: A unique identifier for your mod (e.g., "my_mod_name")
- `weatherType`: The type of weather to override (see Weather Types below)
- `value`: A table with the override values (format depends on weatherType)

### Setting Multiple Weather Overrides at Once

```lua
WL_WeatherOverride.SetBulkOverrides(key, overrides)
```

- `key`: A unique identifier for your mod (e.g., "my_mod_name")
- `overrides`: A table where keys are weather types and values are the override values
- Returns: `true` if all overrides were set successfully, `false` otherwise

This method is more efficient when setting multiple weather types at once, as it uses a single timestamp for all overrides.

### Unsetting Weather Overrides

```lua
WL_WeatherOverride.UnsetOverride(key, weatherType)
```

- `key`: The identifier for your mod
- `weatherType`: The type of weather override to unset

### Unsetting All Weather Overrides

```lua
WL_WeatherOverride.UnsetAllOverrides(key)
```

- `key`: The identifier for your mod

### Getting Active Overrides

```lua
local value = WL_WeatherOverride.GetActiveOverride(weatherType)
```

- `weatherType`: The type of weather override to get
- Returns: The currently active override value or nil if none is active

## Weather Types and Values

### Wind

```lua
WL_WeatherOverride.SetOverride("my_mod", "Wind", { intensity = 0.5 })
```

- `intensity`: Wind intensity from 0.0 to 1.0

### Clouds

```lua
WL_WeatherOverride.SetOverride("my_mod", "Clouds", { intensity = 0.7 })
```

- `intensity`: Cloud coverage from 0.0 to 1.0

### Fog

```lua
WL_WeatherOverride.SetOverride("my_mod", "Fog", { intensity = 0.3 })
```

- `intensity`: Fog density from 0.0 to 1.0

### Precipitation

```lua
WL_WeatherOverride.SetOverride("my_mod", "Precipitation", { 
    intensity = 0.8, 
    isSnow = false 
})
```

- `intensity`: Precipitation intensity from 0.0 to 1.0
- `isSnow`: Boolean indicating if precipitation is snow (true) or rain (false)

### Temperature

```lua
WL_WeatherOverride.SetOverride("my_mod", "Temperature", { value = 25 })
```

- `value`: Temperature in Celsius

### Darkness

```lua
WL_WeatherOverride.SetOverride("my_mod", "Darkness", { value = 0.5 })
```

- `value`: Darkness level from 0.0 (bright) to 1.0 (dark)

### Desaturation

```lua
WL_WeatherOverride.SetOverride("my_mod", "Desaturation", { value = 0.2 })
```

- `value`: Color desaturation from 0.0 (normal) to 1.0 (grayscale)

### Light

```lua
WL_WeatherOverride.SetOverride("my_mod", "Light", {
    intR = 255, intG = 200, intB = 150, intA = 255,
    extR = 255, extG = 200, extB = 150, extA = 255
})
```

- `intR`, `intG`, `intB`, `intA`: Interior light color (RGBA, 0-255)
- `extR`, `extG`, `extB`, `extA`: Exterior light color (RGBA, 0-255)

## Example Usage

See `WL_WeatherOverride_Example.lua` for complete examples of how to use the library.

Basic usage:

```lua
-- Required at the top of your file
require "WL_WeatherOverride"

-- Set a unique key for your mod
local MOD_KEY = "my_awesome_mod"

-- Set foggy weather (individual calls)
function setFoggyWeatherIndividual()
    -- Set heavy fog
    WL_WeatherOverride.SetOverride(MOD_KEY, "Fog", { intensity = 0.8 })
    
    -- Set light rain
    WL_WeatherOverride.SetOverride(MOD_KEY, "Precipitation", {
        intensity = 0.3,
        isSnow = false
    })
    
    -- Set cloudy
    WL_WeatherOverride.SetOverride(MOD_KEY, "Clouds", { intensity = 0.7 })
end

-- Set foggy weather (bulk set - more efficient)
function setFoggyWeatherBulk()
    -- Set all weather parameters at once
    WL_WeatherOverride.SetBulkOverrides(MOD_KEY, {
        Fog = { intensity = 0.8 },
        Precipitation = { intensity = 0.3, isSnow = false },
        Clouds = { intensity = 0.7 }
    })
end

-- Clear all weather overrides set by your mod
function clearWeather()
    WL_WeatherOverride.UnsetAllOverrides(MOD_KEY)
end
```

## Notes

- Weather overrides are applied every climate tick to ensure they remain active
- When multiple mods set the same weather type, the most recently set override takes precedence
- When a mod unsets its override, the system automatically reverts to the next most recent override
- If no overrides are active for a weather type, the game's default weather is used
