Config = {}

Config.Driving = {
    LeftIndicatorKey = 'Q',
    RightIndicatorKey = 'R',
    IndicatorAutoCancelMs = 12000,     -- indicators switch off by themselves after this long
    BeltWarnMph = 15,                  -- chime when moving faster than this without a belt
    BeltChimeSeconds = 8,
    BeltChimeSound = { 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET' },
    -- Wet roads reduce grip, so cornering and braking feel more like the real thing.
    WetGrip = true,
}
