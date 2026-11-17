Config = {}

Config.Lottery = {
    Office = { label = 'National Lottery Counter', x = 127.0, y = -1292.0, z = 29.3, radius = 3.0 },
    TicketPricePounds = 2.00,
    NumbersPerTicket = 6,
    PoolSize = 49,                    -- numbers are 1 to 49
    MaxTicketsPerDraw = 10,           -- per character
    DrawIntervalSeconds = 7 * 86400,  -- weekly
    PotShare = 0.5,                   -- share of each ticket that goes into the prize pot
    -- Each tier takes this share of the pot, split between the winners. A tier with no winner rolls over.
    Tiers = { { match = 6, share = 0.60 }, { match = 5, share = 0.25 }, { match = 4, share = 0.15 } },
}
