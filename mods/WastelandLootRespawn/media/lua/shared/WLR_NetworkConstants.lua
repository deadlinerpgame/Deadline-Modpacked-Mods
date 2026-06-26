-- Shared network message constants for WastelandLootRespawn
-- This file ensures consistency between client and server message types

WLR_NetworkConstants = WLR_NetworkConstants or {}

-- Network message types
WLR_NetworkConstants.Messages = {
    ZONE_DEFINITIONS = "zoneDefinitions",
    CHUNK_STATUS = "chunkStatus",
    CONFIG_RELOAD = "configReload",
    FORCE_RESPAWN = "forceRespawn",
    ZONE_OPERATION = "zoneOperation"
}

-- Command types
WLR_NetworkConstants.Commands = {
    REQUEST_ZONE_DEFINITIONS = "requestZoneDefinitions",
    REQUEST_CHUNK_STATUS = "requestChunkStatus",
    RELOAD_CONFIG = "reloadConfig",
    FORCE_CHUNK_RESPAWN = "forceChunkRespawn",
    CREATE_ZONE = "createZone",
    UPDATE_ZONE = "updateZone",
    DELETE_ZONE = "deleteZone",
    RESPAWN_ALL_READY = "respawnAllReady",
    RESPAWN_ALL_READY_IN_ZONE = "respawnAllReadyInZone"
}

-- Response status codes
WLR_NetworkConstants.Status = {
    SUCCESS = "success",
    ERROR = "error",
    ACCESS_DENIED = "access_denied",
    NOT_FOUND = "not_found"
}