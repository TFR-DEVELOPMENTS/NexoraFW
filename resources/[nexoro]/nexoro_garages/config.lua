Config = {}

-- type: 'public' garages store and release vehicles; 'impound' lots hold seized vehicles (owner pays the fee to release).
-- The key (legion_garage, mrpd_lot...) is the garage id stored on each vehicle. mrpd_lot must match nexoro_vehicles ImpoundLots.
Config.Garages = {
    legion_garage = { label = 'Legion Square Car Park', type = 'public', x = 215.9, y = -810.0, z = 30.7, radius = 14.0,
        spawns = { { x = 223.8, y = -804.4, z = 30.5, h = 248.0 }, { x = 227.3, y = -797.3, z = 30.5, h = 248.0 }, { x = 231.0, y = -789.2, z = 30.5, h = 248.0 } } },
    pillbox_garage = { label = 'Pillbox Hill Garage', type = 'public', x = 215.1, y = -791.2, z = 30.8, radius = 14.0,
        spawns = { { x = 228.5, y = -787.0, z = 30.4, h = 158.0 }, { x = 233.5, y = -787.0, z = 30.4, h = 158.0 } } },
    vinewood_garage = { label = 'Vinewood High Street Garage', type = 'public', x = 365.7, y = 295.6, z = 103.5, radius = 14.0,
        spawns = { { x = 363.0, y = 298.7, z = 103.4, h = 255.0 }, { x = 360.4, y = 305.0, z = 103.4, h = 255.0 } } },
    mrpd_lot = { label = 'Mission Row Police Impound', type = 'impound', x = 409.2, y = -1623.0, z = 29.3, radius = 14.0,
        spawns = { { x = 401.0, y = -1631.5, z = 29.3, h = 228.0 }, { x = 404.5, y = -1637.0, z = 29.3, h = 228.0 } } },
}
