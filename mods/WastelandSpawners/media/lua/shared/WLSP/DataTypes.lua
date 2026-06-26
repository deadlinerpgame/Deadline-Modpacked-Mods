--- @class WLSP_Spawner
--- @field id string Unique identifier for the spawner
--- @field position WLSP_Point Coordinates
--- @field type WLSP_SpawnerType Type of spawner
--- @field lifespan number Lifespan of the spawner in minutes (0 for infinite)
--- @field countType WLSP_CountType Method to determine the number of zombies to spawn
--- @field count number Number of zombies to spawn (interpretation depends on countType)
--- @field spawnInterval number Time interval between spawns in seconds
--- @field group? string Optional group name for organizing spawners
--- @field outfit? string Optional outfit name for spawned zombies (nil = default random outfits)
--- @field targetLocation? WLSP_Point Target location where zombies will path after spawning (optional for all types)
--- @field spawnRadius? number Radius for circular spawn areas (used by radius and ring types)
--- @field area? WLSP_Offset Area offsets (dx, dy) from position for rectangular spawn zone (used by area type)
--- @field perPlayerInAreaPoint? WLSP_Point Point to check for players when using perPlayerInArea count type
--- @field perPlayerInAreaRadius? number Radius to check for players when using perPlayerInArea count type
--- @field zombieProperties? WLSP_ZombieProperties Custom zombie property overrides
--- @field triggers? WLSP_Trigger[] Array of triggers (optional)
--- @field triggerMode? "disabled"|"OR"|"AND" How triggers interact (default: "OR")
--- @field conditions? WLSP_Condition[] Array of spawn conditions (optional)
--- @field conditionMode? "disabled"|"OR"|"AND" How conditions interact (default: "AND")

--- Spawner Types
--- - "point": A single point in space where zombies spawn.
--- - "area": A rectangular area where zombies spawn randomly within bounds defined by position + area offsets.
--- - "radius": A circular area where zombies spawn randomly within the radius.
--- - "ring": Zombies spawn on the perimeter of a circle with the specified radius.
--- @alias WLSP_SpawnerType "point"|"area"|"radius"|"ring"

--- @alias WLSP_CountType "fixed"|"perPlayerInArea"|"totalOnlinePlayers"

--- @class WLSP_Point
--- @field x number
--- @field y number
--- @field z number

--- @class WLSP_Offset
--- @field x number
--- @field y number

--- @class WLSP_ZombieProperties
--- @field speed? "slowShambler"|"shambler"|"sprinter" Custom movement speed (nil = use default/random)
--- @field cognition? "smart"|"default"|"random" Custom cognition level (nil = use default/random)
--- @field healthModifier? number Multiplier for zombie toughness (nil = default, typical range 0.1-5.0)
--- @field forceCrawling? boolean Force zombies to crawl (nil = default/false)

--- @class WLSP_PendingZombieMod
--- @field zombieId number ID of the zombie to modify
--- @field position WLSP_Point Position of the zombie
--- @field properties? WLSP_ZombieProperties Properties to apply to the zombie
--- @field targetLocation? WLSP_Point Target location for the zombie to path to

--- @class WLSP_Condition
--- @field type WLSP_ConditionType Type of condition
--- @field enabled boolean Whether this condition is currently active

--- Base condition type
--- @alias WLSP_ConditionType "timeOfDay"|"weather"|"playerCount"|"zombieCount"

--- @class WLSP_TimeOfDayCondition : WLSP_Condition
--- @field type "timeOfDay"
--- @field startHour number Start time (0-23)
--- @field endHour number End time (0-23)

--- @class WLSP_WeatherCondition : WLSP_Condition
--- @field type "weather"
--- @field rainMin? number Minimum rain level (0-1)
--- @field rainMax? number Maximum rain level (0-1)
--- @field requireSnow? boolean Whether snow is required
--- @field prohibitSnow? boolean Whether snow is prohibited
--- @field fogMin? number Minimum fog level (0-1)
--- @field fogMax? number Maximum fog level (0-1)

--- @class WLSP_PlayerCountCondition : WLSP_Condition
--- @field type "playerCount"
--- @field checkType "rangeSpawner"|"rangeTarget"|"online" Type of player condition check
--- @field minCount number Minimum number of players required
--- @field radius? number Radius to check for players (required for "rangeSpawner" and "rangeTarget" types)

--- @class WLSP_ZombieCountCondition : WLSP_Condition
--- @field type "zombieCount"
--- @field checkType "spawn"|"target" Type of zombie condition check
--- @field radius number Radius to check for zombies
--- @field maxCount number Maximum number of zombies allowed

--- @class WLSP_Trigger
--- @field type WLSP_TriggerType Type of trigger
--- @field enabled boolean Whether this trigger is currently active
--- @field cooldown number Cooldown time in seconds before trigger can activate again
--- @field lastActivation? number Timestamp of last activation (in game seconds)

--- Base trigger type
--- @alias WLSP_TriggerType "time"|"area"

--- @class WLSP_TimeTrigger : WLSP_Trigger
--- @field type "time"
--- @field times table<number> Array of daily times in format {hour, minute} e.g., {{14,0}, {8,30}, {22,15}}

--- @class WLSP_AreaTrigger : WLSP_Trigger
--- @field type "area"
--- @field position WLSP_Point Center point of trigger area
--- @field radius number Radius in tiles
--- @field minPlayers number Minimum number of players required to activate