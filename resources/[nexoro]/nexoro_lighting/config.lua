Config = {}

Config.Lighting = {
    -- Only these vehicle models can be given emergency lighting.
    Models = { 'police', 'police2', 'police3', 'policeb', 'sheriff', 'ambulance', 'firetruk', 'lguard' },

    -- Each pattern is a loop of steps: { side, colour, milliseconds }. side = left | right | both.
    Presets = {
        patrol = { label = 'Patrol', steps = { { 'left', 'blue', 90 }, { 'off', 'blue', 60 }, { 'left', 'blue', 90 }, { 'off', 'blue', 280 },
            { 'right', 'blue', 90 }, { 'off', 'blue', 60 }, { 'right', 'blue', 90 }, { 'off', 'blue', 280 } } },
        traffic = { label = 'Traffic', steps = { { 'both', 'amber', 180 }, { 'off', 'amber', 120 } } },
        response = { label = 'Response', steps = { { 'left', 'red', 120 }, { 'right', 'blue', 120 }, { 'left', 'red', 120 }, { 'right', 'blue', 120 } } },
        ambulance = { label = 'Ambulance', steps = { { 'left', 'red', 150 }, { 'right', 'white', 150 }, { 'right', 'red', 150 }, { 'left', 'white', 150 } } },
        fire = { label = 'Fire appliance', steps = { { 'both', 'red', 160 }, { 'off', 'red', 110 } } },
    },

    -- Light positions relative to the vehicle centre (metres): front and roof-bar points.
    -- These are approximate for the models above. Adjust per model after testing in-game.
    LightPoints = {
        { x = -0.45, y = 2.05, z = 0.55, side = 'left' }, { x = 0.45, y = 2.05, z = 0.55, side = 'right' },
        { x = -0.40, y = 0.20, z = 1.20, side = 'left' }, { x = 0.40, y = 0.20, z = 1.20, side = 'right' },
        { x = -0.55, y = -2.30, z = 0.90, side = 'left' }, { x = 0.55, y = -2.30, z = 0.90, side = 'right' },
    },
    Colours = { blue = { 0, 90, 255 }, red = { 255, 25, 25 }, amber = { 255, 150, 0 }, white = { 255, 255, 255 } },
    DrawRange = 14.0,           -- how far each light reaches
    DrawIntensity = 5.0,
    ViewDistance = 150.0,       -- only draw for vehicles this close to the player

    LightKey = 'G',             -- cycles the lightbar presets while driving
    SirenKey = 'H',             -- toggles the siren
    AirhornKey = 'J',           -- holds the airhorn (local only)
}
