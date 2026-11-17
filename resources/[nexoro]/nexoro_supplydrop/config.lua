Config = {}

Config.SupplyDrop = {
    -- Coordinates are placeholders: check Legion Square in-game.
    Location = { label = 'Legion Square', x = 195.5, y = -933.5, z = 30.7 },
    -- Times are on the in-game clock (nexoro_world), 24-hour.
    Times = {
        { label = '18:00', minutes = 18 * 60 },
        { label = '21:00', minutes = 21 * 60 },
    },
    AnnounceMinutes = 5,              -- players are told this long before a drop
    -- The team that may claim a crate: a job name from nexoro_core. Set to nil to let anyone claim.
    Team = 'caledonia_police',
    TeamLabel = 'Caledonia Police',
    ClaimRadius = 5.0,
    CrateLifetimeMinutes = 15,        -- an unclaimed crate is removed after this long
    TickSeconds = 30,
    -- Loot. weight decides how likely each prize is. Cash is in pence.
    Loot = {
        { kind = 'cash', min = 50000, max = 150000, weight = 40, label = 'cash' },
        { kind = 'item', item = 'cash_bag', amount = 1, weight = 20 },
        { kind = 'item', item = 'repair_kit', amount = 1, weight = 15 },
        { kind = 'item', item = 'steel_part', amount = 3, weight = 15 },
        { kind = 'item', item = 'lockpick', amount = 2, weight = 10 },
    },
}
