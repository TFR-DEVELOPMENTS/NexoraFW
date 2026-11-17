Config = {}

Config.Postal = {
    JobName = 'postal',
    StopsPerRound = 3,
    PayPerStopPounds = 35.00,
    CompletionBonusPounds = 60.00,
    StopRadius = 12.0,              -- you must be this close to a drop to deliver
    MinSecondsBetweenStops = 15,    -- stops cannot be cleared faster than this
    -- Drop-off addresses. Coordinates are placeholders: check them in-game.
    Stops = {
        { id = 'high_street_12', label = '12 High Street', x = 143.0, y = -1040.0, z = 29.4 },
        { id = 'elm_close_9', label = '9 Elm Close', x = -1126.0, y = -1468.0, z = 4.6 },
        { id = 'harbour_office', label = 'Harbour Office', x = -270.0, y = -1044.0, z = 26.7 },
        { id = 'mission_row_post', label = 'Post Box, Mission Row', x = 434.0, y = -980.0, z = 30.7 },
        { id = 'vespucci_flats', label = 'Vespucci Flats', x = -1290.0, y = -1113.0, z = 6.9 },
    },
}
