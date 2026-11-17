Config = Config or {}

Config.Framework = {
    Name = 'Nexoro',
    Version = 'v1.0.0-beta',
    Debug = false,
    Locale = 'en-GB',

    -- Resources that must be started before nexoro_core will accept players.
    RequiredResources = { 'oxmysql', 'nexoro_database' },

    AutosaveMinutes = 5,
    -- Stops GTA's own police (wanted stars, NPC cops, dispatch). Nexoro police replaces it.
    DisableGtaPolice = true,

    -- Money (amounts are given to the API in pounds, stored as integer pence).
    Accounts = { 'cash', 'bank' },
    MaxSingleTransactionPounds = 1000000.00,
    MaxBalancePounds = 1000000000.00,

    DefaultJob = { name = 'unemployed', grade = 0 },

    -- Fallback spawn when a character has no saved position.
    DefaultSpawn = { x = 195.17, y = -933.77, z = 30.69, heading = 144.5 },
}

Config.Security = {
    CallbackRateLimit = { max = 30, windowMs = 5000 },
    ViolationsBeforeKick = 8,
}

Config.Logging = {
    Console = true,
    Database = true,
    FlushIntervalMs = 5000,
    BatchSize = 25,
}
