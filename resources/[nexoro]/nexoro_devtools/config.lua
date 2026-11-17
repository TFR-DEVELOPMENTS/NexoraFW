Config = {}

Config.DevTools = {
    -- Set `set nexoro_devmode "true"` in server.cfg to turn these on. Never on a live server.
    ConvarName = 'nexoro_devmode',
    Permission = 'nexoro.dev',           -- owners have this. Other staff do not, unless you grant it.
    ResourcePrefix = 'nexoro_',
    -- Tables the self-check looks for. If one is missing, the migrations did not run.
    CoreTables = { 'nexoro_characters', 'nexoro_staff_assignments', 'nexoro_police_records', 'nexoro_properties',
                   'nexoro_vehicles', 'nexoro_auctions', 'nexoro_lottery_draws', 'nexoro_pitches' },
    -- Teleport points for /devtp. Coordinates are placeholders; they match the rest of the framework's test points.
    Locations = {
        legion = { label = 'Legion Square', x = 195.5, y = -933.5, z = 30.7 },
        council = { label = 'Council licensing office', x = 252.0, y = -1048.0, z = 29.3 },
        pawn = { label = 'Pawn shop', x = 300.0, y = -1380.0, z = 31.0 },
        hospital = { label = 'Hospital', x = 298.7, y = -584.4, z = 43.3 },
        paleto = { label = 'Paleto Woods', x = -670.0, y = 5550.0, z = 40.0 },
        sandy = { label = 'Sandy Shores pitch 1', x = 1690.0, y = 3580.0, z = 35.0 },
        farm = { label = 'North Field', x = 2400.0, y = 4980.0, z = 46.0 },
    },
}
