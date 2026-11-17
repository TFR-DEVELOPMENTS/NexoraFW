Config = {}

-- Prices live here on the server. Clients only ever send a model name, never a price.
-- garage: where the new vehicle is delivered (must exist in nexoro_garages as a public garage).
Config.Dealerships = {
    premium_deluxe = { label = 'Premium Deluxe Motorsport', x = -56.8, y = -1097.0, z = 26.4, radius = 4.5, garage = 'legion_garage', catalogue = {
        { model = 'panto', label = 'Benefactor Panto', price = 6500, category = 'City' },
        { model = 'blista', label = 'Dinka Blista', price = 9800, category = 'City' },
        { model = 'asea', label = 'Declasse Asea', price = 8500, category = 'Saloon' },
        { model = 'sultan', label = 'Karin Sultan', price = 24000, category = 'Saloon' },
        { model = 'schafter2', label = 'Benefactor Schafter', price = 32000, category = 'Saloon' },
        { model = 'felon', label = 'Lampadati Felon', price = 41000, category = 'Executive' },
        { model = 'baller', label = 'Gallivanter Baller', price = 52000, category = 'SUV' },
        { model = 'speedo', label = 'Vapid Speedo', price = 18000, category = 'Van' },
        -- Stock GTA vans for the Traveller and scrap trades. Spawn codes from the realistic handling pack's list; check them on your build.
        { model = 'burrito3', label = 'Declasse Burrito', price = 21000, category = 'Van' },
        { model = 'rumpo', label = 'Bravado Rumpo', price = 19500, category = 'Van' },
        { model = 'bison', label = 'Bravado Bison', price = 24500, category = 'Pickup' },
        -- Optional: cars from SpiritsCreations' Lore-Friendly Car Pack. Listed only while that resource is running on the server.
        -- The pack is not part of Nexoro. Install it yourself into your server's resources. Prices are placeholders: set your own.
        { model = 'zr3806str', label = '6STR Annis ZR380 Custom', price = 85000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'elegyrh6', label = 'Annis Elegy RH6', price = 72000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'sultanrsv8', label = 'Karin Sultan RS V8 TwinTurbo', price = 68000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'monroer', label = 'Pegassi Monroe Roadster', price = 150000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'mantis', label = 'Ocelot Mantis', price = 54000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'sentinelmk4', label = 'Ubermacht Sentinel Mk.4', price = 61000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
        { model = 'domgtcoupe', label = 'Vapid Dominator GT Coupe', price = 58000, category = 'Lore Friendly', requires = 'Lore-Friendly-Car-Pack' },
    } },
    cycle_shop = { label = 'Pegassi Bikes and Cycles', x = 266.0, y = -1155.0, z = 29.3, radius = 4.0, garage = 'legion_garage', catalogue = {
        { model = 'bmx', label = 'BMX', price = 250, category = 'Cycles' },
        { model = 'scorcher', label = 'Scorcher Mountain Bike', price = 450, category = 'Cycles' },
        { model = 'faggio', label = 'Pegassi Faggio Scooter', price = 3500, category = 'Mopeds' },
        { model = 'bati', label = 'Pegassi Bati 801', price = 14000, category = 'Motorbikes' },
    } },
}
