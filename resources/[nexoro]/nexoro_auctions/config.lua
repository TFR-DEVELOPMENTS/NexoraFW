Config = {}

Config.Auctions = {
    House = { label = 'Auction House', x = 216.0, y = -810.0, z = 30.7, radius = 4.0 },
    FeePercent = 5,               -- the auction house keeps this share of a sale
    MinMinutes = 5,
    MaxMinutes = 120,
    MinIncreasePounds = 1.00,     -- each bid must beat the current one by at least this
    MinIncreasePercent = 5,
    MaxListingsPerSeller = 5,
    SettleSeconds = 10,
}
