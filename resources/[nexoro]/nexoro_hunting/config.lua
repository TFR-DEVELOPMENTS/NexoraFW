Config = {}

Config.Hunting = {
    CooldownSeconds = 45,
    -- Catch weights add up to 100. Nothing in the woods is also possible.
    Catches = {
        { item = 'venison', weight = 60 },
        { item = 'pelt', weight = 30 },
        { item = nil, weight = 10 },
    },
    -- Woodland spots. Coordinates are placeholders: check them in-game.
    Spots = {
        { id = 'paleto_woods', label = 'Paleto Woods', x = -670.0, y = 5550.0, z = 40.0, radius = 25.0 },
    },
}
