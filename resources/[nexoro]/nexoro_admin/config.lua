Config = {}

Config.Admin = {
    OpenKey = 'F9',                  -- players can rebind in FiveM key bindings
    RequireStaffDuty = false,        -- true: staff must run /staffduty before using the menu
    MaxBanMinutes = 525600,          -- 1 year ceiling for timed bans (0 = permanent is a separate permission-gated choice)
    ModMaxBanMinutes = 10080,        -- 7 days: the most a moderator with nexoro.mod.temporaryban can issue
    SuspiciousTransactionPounds = 50000,
    Weathers = { 'EXTRASUNNY', 'CLEAR', 'CLOUDS', 'OVERCAST', 'RAIN', 'THUNDER', 'FOGGY', 'SMOG', 'CLEARING', 'SNOW' },
    RestartBlocked = { nexoro_database = true },
    QuickVehicles = { 'police', 'police2', 'ambulance', 'firetruk', 'taxi', 'bus', 'sultan', 'blista', 'panto', 'speedo', 'bmx' },
}
