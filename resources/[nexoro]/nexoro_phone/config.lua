Config = {}

Config.Phone = {
    OpenKey = 'F1',
    RequireItem = 'phone',                 -- set to false to let everyone use a phone
    EmergencyNumbers = { ['999'] = 'emergency', ['101'] = 'police', ['111'] = 'medical' },
    MaxContacts = 100,
    MaxMessageLength = 250,
    RingSeconds = 30,
    EmailDomain = 'nexoro.co.uk',

    BatteryDrainMinutes = 6,               -- lose 1% every N minutes
    ChargeItem = 'phone_charger',
    ChargeAmount = 50,

    AdCostPounds = 25.00,
    AdLifetimeHours = 24,
    AdCooldownSeconds = 300,

    Voice = 'pma-voice',                   -- 'pma-voice' joins callers to a call channel; 'none' disables

    Wallpapers = { 'nexoro_black', 'nexoro_yellow', 'nexoro_grid', 'nexoro_dusk' },
    Ringtones = { 'default', 'michael', 'franklin', 'trevor' },

    -- GPS app destinations (edit freely)
    GPS = {
        { name = 'Mission Row Police Station', x = 425.1, y = -979.5 },
        { name = 'Pillbox Hill Hospital', x = 298.7, y = -584.4 },
        { name = 'Davis Fire Station', x = 199.8, y = -1643.4 },
        { name = 'Legion Square (High Street)', x = 195.2, y = -933.8 },
        { name = 'Job Centre', x = -265.0, y = -963.6 },
        { name = 'Los Santos Bank', x = 149.9, y = -1040.5 },
    },
}
