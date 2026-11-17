Config = {}

Config.Map = {
    UnitRefreshMs = 4000,            -- how often unit positions are sent to other units
    IncidentSprite = 161,
    -- Priority 1 (immediate) flashes red, 2 orange, 3 yellow.
    IncidentColour = { [1] = 1, [2] = 47, [3] = 5 },
    -- Unit dots: police blue, ambulance green, fire red.
    CategoryColour = { police = 3, ambulance = 2, fire = 1 },
    -- Always-visible places. Coordinates are placeholders for your map: adjust them in-game.
    Static = {
        { label = 'Police station', x = 425.1, y = -979.5, z = 30.5, sprite = 60, colour = 3 },
        { label = 'Hospital', x = 298.7, y = -584.4, z = 43.3, sprite = 61, colour = 2 },
        { label = 'Fire station', x = 199.8, y = -1643.4, z = 29.8, sprite = 436, colour = 1 },
        { label = 'Job centre', x = -265.0, y = -963.6, z = 31.2, sprite = 408, colour = 5 },
        { label = 'Bank', x = 149.9, y = -1040.5, z = 29.4, sprite = 108, colour = 2 },
        { label = '24/7 shop', x = 25.7, y = -1347.3, z = 29.5, sprite = 52, colour = 2 },
    },
}
