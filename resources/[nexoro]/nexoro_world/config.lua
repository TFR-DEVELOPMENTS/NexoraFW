Config = {}

Config.World = {
    -- true: the in-game clock follows UK time (GMT in winter, BST in summer). Uses the server's clock.
    RealTime = true,
    StartWeather = 'CLEAR',
    StartHour = 12,
    -- When RealTime is off: game minutes that pass per tick (tick = TickMs). 1 minute per 10 seconds
    -- means a full in-game day takes four real hours.
    GameMinutesPerTick = 1,
    TickMs = 10000,
    -- How often the weather is allowed to change. The next state is always a neighbour, so
    -- weather moves realistically (clear to clouds to rain to thunder, never clear to thunder).
    WeatherIntervalMinutes = 25,
    TransitionSeconds = 45,      -- how long the sky takes to blend between weathers on every client
    -- Weathers where roads are wet: vehicles lose grip (see nexoro_driving).
    WetWeather = { RAIN = true, THUNDER = true, CLEARING = true },
    -- Traffic and pedestrian density, 0.0 (none) to 1.0 (GTA default).
    Traffic = { moving = 0.7, parked = 0.6, pedestrians = 0.8 },
    -- Night (22:00 to 06:00 in-game): quieter streets, so night traffic is lighter. This replaces the
    -- traffic-light control that GTA does not let scripts change.
    NightHours = { from = 22, to = 6 },
    NightTraffic = { moving = 0.3, parked = 0.5, pedestrians = 0.4 },
    -- Allowed next weathers from each current weather.
    Transitions = {
        CLEAR = { 'EXTRASUNNY', 'CLOUDS' },
        EXTRASUNNY = { 'CLEAR' },
        CLOUDS = { 'CLEAR', 'OVERCAST', 'CLEARING' },
        CLEARING = { 'CLEAR', 'CLOUDS' },
        OVERCAST = { 'CLOUDS', 'RAIN', 'FOGGY' },
        RAIN = { 'OVERCAST', 'THUNDER', 'CLEARING' },
        THUNDER = { 'RAIN' },
        FOGGY = { 'OVERCAST', 'CLEAR' },
        SMOG = { 'FOGGY', 'CLOUDS' },
    },
}
