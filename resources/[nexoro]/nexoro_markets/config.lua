Config = {}

-- Street contacts. Buys: what the contact pays you (pounds, full price). Sells: what you pay the contact.
-- The contact pays Share of the price for what you bring them. Coordinates are placeholders: check in-game.
Config.Markets = {
    contact_drugs = {
        label = 'Corner contact', x = -1420.0, y = -1450.0, z = 4.6, radius = 3.0,
        Share = 0.60, DailyCapPounds = 3000.00, AlarmChance = 25,
        Buys = { narcotics_packet = 250.00 },
        Sells = {},
    },
    contact_weapons = {
        label = 'Back-alley dealer', x = -1077.0, y = -1585.0, z = 4.6, radius = 3.0,
        Share = 0.60, DailyCapPounds = 5000.00, AlarmChance = 40,
        Buys = { pistol_illegal = 1500.00 },
        Sells = { pistol_illegal = 1500.00 },
    },
}
