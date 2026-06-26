# WL_CountdownTimer API Documentation

## Overview

The WL_CountdownTimer system provides a robust, client-server synchronized countdown timer framework for Project Zomboid mods. It supports multiple simultaneous timers with different configurations, automatic cleanup, and flexible positioning options.

## System Architecture

The countdown timer system consists of three main components:

1. **[`WL_CountdownTimer`](WL_CountdownTimer.lua)** - Core timer management system (shared)
2. **[`WL_CountdownTimerUI`](../client/WL_CountdownTimerUI.lua)** - Client-side UI rendering (client-only)
3. **Timer Data Synchronization** - Automatic client-server data sync via WL_ClientServerBase

### Key Features

- **Multiple Timer Support**: Run unlimited simultaneous timers with unique IDs
- **Global & Local Timers**: Global timers visible to all players, local timers visible within a specified range
- **Flexible Positioning**: Display timers at top, center, or bottom of screen
- **Customizable Appearance**: Configure colors, text, and visual styling
- **Automatic Cleanup**: Optional auto-removal of expired timers
- **Client-Server Sync**: Seamless synchronization across all connected clients
- **Performance Optimized**: Efficient rendering and minimal network overhead

## Timer Configuration

### TimerConfig Object

```lua
--- @class TimerConfig
--- @field id string|nil Unique identifier (auto-generated if not provided)
--- @field text string Display text for the timer
--- @field duration number Duration in seconds
--- @field color table|nil RGB color {r, g, b} with values 0-1 (default: white)
--- @field position string|nil Screen position: "top", "center", "bottom" (default: "top")
--- @field locationType string Timer type: "global" or "local" (default: "global")
--- @field x number|nil X coordinate for local timers (required for local)
--- @field y number|nil Y coordinate for local timers (required for local)
--- @field range number|nil Visibility range for local timers (required for local)
--- @field autoRemove boolean|nil Auto-remove when expired (default: true)
```

### Position Constants

```lua
WL_CountdownTimer.POSITION_TOP = "top"       -- Top of screen
WL_CountdownTimer.POSITION_CENTER = "center" -- Center of screen
WL_CountdownTimer.POSITION_BOTTOM = "bottom" -- Bottom of screen
```

### Location Type Constants

```lua
WL_CountdownTimer.LOCATION_GLOBAL = "global" -- Visible to all players
WL_CountdownTimer.LOCATION_LOCAL = "local"   -- Visible within range
```

## Core API Methods

### Timer Creation

#### [`createTimer(config, player)`](WL_CountdownTimer.lua:79)

Creates a new countdown timer with full configuration options.

**Parameters:**
- `config` (TimerConfig): Complete timer configuration
- `player` (IsoPlayer|nil): Player creating the timer (for client-side calls)

**Returns:**
- `string|nil`: Timer ID if successful (server-side), nil for client-side calls

**Example:**
```lua
local config = {
    text = "Event Starting",
    duration = 300,
    color = {r = 1, g = 0, b = 0},
    position = WL_CountdownTimer.POSITION_CENTER,
    locationType = WL_CountdownTimer.LOCATION_GLOBAL,
    autoRemove = true
}
local timerId = WL_CountdownTimer:createTimer(config)
```

#### [`createGlobalTimer(id, text, duration, color, position, autoRemove)`](WL_CountdownTimer.lua:286)

Simplified method for creating global timers.

**Parameters:**
- `id` (string|nil): Unique timer ID (auto-generated if nil)
- `text` (string): Display text
- `duration` (number): Duration in seconds
- `color` (table|nil): RGB color {r, g, b}, defaults to white
- `position` (string|nil): Position (top/center/bottom), defaults to top
- `autoRemove` (boolean|nil): Auto-remove when expired, defaults to true

**Example:**
```lua
WL_CountdownTimer:createGlobalTimer(
    "my_timer_id",
    "Server Restart", 
    600, 
    {r = 1, g = 0, b = 0}, 
    WL_CountdownTimer.POSITION_CENTER
)
```

#### [`createLocalTimer(id, text, duration, x, y, range, color, position, autoRemove)`](WL_CountdownTimer.lua:308)

Simplified method for creating local area timers.

**Parameters:**
- `id` (string|nil): Unique timer ID (auto-generated if nil)
- `text` (string): Display text
- `duration` (number): Duration in seconds
- `x` (number): X coordinate
- `y` (number): Y coordinate
- `range` (number): Visibility range
- `color` (table|nil): RGB color {r, g, b}, defaults to white
- `position` (string|nil): Position (top/center/bottom), defaults to top
- `autoRemove` (boolean|nil): Auto-remove when expired, defaults to true

**Example:**
```lua
WL_CountdownTimer:createLocalTimer(
    "my_timer_id",
    "Area Effect", 
    120, 
    100, 200, 50,  -- x, y, range
    {r = 0, g = 1, b = 0}, 
    WL_CountdownTimer.POSITION_TOP
)
```

### Timer Management

#### [`removeTimer(timerId, player)`](WL_CountdownTimer.lua:151)

Removes a timer by its ID.

**Parameters:**
- `timerId` (string): Timer ID to remove
- `player` (IsoPlayer|nil): Player removing the timer (for client-side calls)

**Example:**
```lua
WL_CountdownTimer:removeTimer("my_timer_id")
```

#### [`getRemainingTime(timerId)`](WL_CountdownTimer.lua:221)

Gets the remaining time for a specific timer.

**Parameters:**
- `timerId` (string): Timer ID

**Returns:**
- `number|nil`: Remaining time in seconds, nil if timer doesn't exist

**Example:**
```lua
local remaining = WL_CountdownTimer:getRemainingTime("my_timer_id")
if remaining then
    print("Timer has " .. remaining .. " seconds left")
end
```

#### [`isTimerExpired(timerId)`](WL_CountdownTimer.lua:235)

Checks if a timer has expired.

**Parameters:**
- `timerId` (string): Timer ID

**Returns:**
- `boolean`: True if timer has expired

**Example:**
```lua
if WL_CountdownTimer:isTimerExpired("my_timer_id") then
    print("Timer has expired!")
end
```

### Timer Queries

#### [`getActiveTimers()`](WL_CountdownTimer.lua:176)

Gets all active timers in the system.

**Returns:**
- `table<string, TimerConfig>`: All active timers indexed by ID

**Example:**
```lua
local allTimers = WL_CountdownTimer:getActiveTimers()
for timerId, timer in pairs(allTimers) do
    print("Timer: " .. timerId .. " - " .. timer.text)
end
```

#### [`getVisibleTimers(player)`](WL_CountdownTimer.lua:186)

Gets timers visible to a specific player at their current location.

**Parameters:**
- `player` (IsoPlayer): Player to check visibility for

**Returns:**
- `table<string, TimerConfig>`: Visible timers indexed by ID

**Example:**
```lua
local player = getPlayer()
local visibleTimers = WL_CountdownTimer:getVisibleTimers(player)
print("Player can see " .. #visibleTimers .. " timers")
```

#### [`isTimerVisibleToPlayer(timer, playerX, playerY)`](WL_CountdownTimer.lua:205)

Checks if a specific timer is visible to a player at given coordinates.

**Parameters:**
- `timer` (TimerConfig): Timer to check
- `playerX` (number): Player X coordinate
- `playerY` (number): Player Y coordinate

**Returns:**
- `boolean`: True if timer is visible
