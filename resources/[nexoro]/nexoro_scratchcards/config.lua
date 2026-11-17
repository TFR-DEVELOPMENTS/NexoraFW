Config = {}

Config.Scratch = {
    Counter = { label = 'Corner Shop Counter', x = 26.5, y = -1345.8, z = 29.5, radius = 3.0 },
    PricePounds = 5.00,
    -- Prize table. Weights add up to 1000, so the chance of each prize is weight / 1000.
    -- Expected return is about 97% of the stake, so it pays out less than it takes.
    Prizes = {
        { prize = 0, weight = 800 },
        { prize = 5, weight = 120 },
        { prize = 10, weight = 50 },
        { prize = 50, weight = 25 },
        { prize = 500, weight = 5 },
    },
}
