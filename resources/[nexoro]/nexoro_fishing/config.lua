Config = {}

Config.Fishing = {
    CooldownSeconds = 20,
    -- Catch weights add up to 100. Junk is what you get when the fish do not bite.
    Catches = {
        { item = 'fish_raw', weight = 70 },
        { item = 'fish_large', weight = 8 },
        { item = 'scrap', weight = 22 },
    },
    -- Fishing spots. Coordinates are placeholders: check them in-game.
    Spots = {
        { id = 'harbour_pier', label = 'Harbour Pier', x = -1850.0, y = -1210.0, z = 13.0, radius = 8.0 },
        { id = 'river_bank', label = 'River Bank', x = 1290.0, y = 4330.0, z = 37.0, radius = 8.0 },
    },
}
