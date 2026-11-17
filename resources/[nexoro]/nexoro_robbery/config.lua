Config = {}

Config.Robbery = {
    -- Targets. Coordinates are placeholders: check them in-game.
    Targets = {
        { id = 'corner_store', label = 'Corner Store', kind = 'store', x = 25.7, y = -1347.3, z = 29.5, radius = 3.0,
          min = 200, max = 900, cooldownMinutes = 60, requires = 'lockpick', seconds = 12 },
        { id = 'atm_high_street', label = 'ATM, High Street', kind = 'atm', x = 149.9, y = -1040.5, z = 29.4, radius = 2.0,
          min = 300, max = 1200, cooldownMinutes = 120, requires = 'lockpick', seconds = 20 },
    },
}
