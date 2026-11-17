Config = {}

Config.Transport = {
    BaseFarePounds = 1.50,
    PerKmFarePounds = 0.60,
    MinFarePounds = 1.50,
    RoadFactor = 1.3,              -- road distance is longer than the straight line between stops
    StopRadius = 10.0,             -- tap on and off within this distance of the stop
    -- Stop coordinates are placeholders: check them in-game.
    Routes = {
        { id = 'route_1', label = 'Route 1: High Street to Harbour', stops = {
            { id = 'hs_1', label = 'High Street', x = 150.0, y = -1036.0, z = 29.4 },
            { id = 'mr_1', label = 'Mission Row', x = 430.0, y = -978.0, z = 30.7 },
            { id = 'hb_1', label = 'Harbour', x = -261.0, y = -1040.0, z = 26.7 },
        } },
    },
}
