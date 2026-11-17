Config = {}

Config.Housing = {
    -- Estate agents sell and buy back property. Coordinates are placeholders: check them in-game.
    Agents = {
        high_street = { label = 'Estate Agent, High Street', x = 150.0, y = -1040.0, z = 29.4, radius = 4.0 },
    },
    Properties = {
        { id = 'flat_12_high_street', label = 'Flat 1, 12 High Street', price = 85000, weekly = 60, agent = 'high_street',
          entrance = { x = 152.0, y = -1036.0, z = 29.4 }, interior = { x = 266.0, y = -1007.0, z = -101.0 } },
        { id = 'house_9_elm_close', label = '9 Elm Close', price = 180000, weekly = 95, agent = 'high_street',
          entrance = { x = 153.0, y = -1030.0, z = 29.4 }, interior = { x = 346.0, y = -1012.0, z = -99.0 } },
    },
    -- Bills are taken from the bank once a week. Missing payments build up arrears; enough of them and the property is repossessed.
    BillIntervalSeconds = 7 * 86400,
    MaxArrearsWeeks = 4,
    SellBackRate = 0.6,          -- estate agent pays this fraction of the price back
    MaxKeys = 5,
    StashSlots = 40,
    StashWeightGrams = 60000,
    BillCheckSeconds = 300,
}
