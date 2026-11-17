Config = {}

Config.Hud = {
    -- Needs (server-side). Values are 0-100 and stored as character metadata: hunger, thirst, stress.
    TickSeconds = 60,
    HungerPerMinute = 0.6,
    ThirstPerMinute = 0.9,
    StressRecoveryPerMinute = 1.0,
    StarvationDamage = 5,           -- health lost per tick while hunger or thirst is 0

    -- Client
    UpdateIntervalMs = 200,
    DefaultPosition = 'bottom-right',   -- bottom-right | bottom-left | bottom-centre
    SeatbeltKey = 'B',
    -- Minimap off by default: GTA draws its own health and stamina bars on the minimap.
    -- Our HUD shows health and stamina instead. Players can switch the minimap back on in /hud.
    ShowRadar = false,
    -- Sound names are GTA frontend sounds. Adjust to taste.
    BeltSound = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    BeltRemoveSound = { 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    RouteTextScale = 0.28,
    EjectSpeedDropMph = 35,             -- sudden speed drop without a seatbelt throws you out
}
