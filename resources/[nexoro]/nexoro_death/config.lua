Config = {}

Config.Death = {
    BleedOutSeconds = 300,        -- time before you can give up and respawn at hospital
    -- The server accepts a bleed-out this many seconds early, to allow for network delay.
    Tolerance = 2,
    -- Hospitals you can respawn at. The nearest one to where you fell is used.
    Hospitals = {
        { x = 298.7, y = -584.4, z = 43.3, heading = 70.0 },
    },
    -- Lying-down emote. Plays while you are down.
    Anim = { dict = 'dead', clip = 'dead_a' },
    TickMs = 250,
    RespawnHealth = 150,
    -- Controls disabled while down (movement, attacks, vehicles, interaction).
    DisableControls = { 21, 22, 23, 24, 25, 30, 31, 32, 33, 34, 35, 36, 44, 45, 75, 140, 141, 142, 143, 257, 263, 264, 37, 38, 47, 58 },
}
