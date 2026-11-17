Config = {}

Config.Crime = {
    LockpickItem = 'lockpick',
    -- Vehicle theft: a street car that belongs to someone else. The lockpick is used up either way.
    Theft = {
        CaptureRadius = 6.0,
        SuccessChance = 60,          -- percent
        CooldownMinutes = 30,        -- per plate
    },
    -- House robbery: only when the owner is not online. Takes from the property stash.
    Robbery = {
        CooldownMinutes = 120,       -- per property
        MaxStacks = 3,
        MaxPerStack = 5,
        -- Doors match the properties in nexoro_housing. Coordinates are placeholders: check in-game.
        Houses = {
            { id = 'flat_12_high_street', label = 'Flat 1, 12 High Street', x = 152.0, y = -1036.0, z = 29.4 },
            { id = 'house_9_elm_close', label = '9 Elm Close', x = 153.0, y = -1030.0, z = 29.4 },
        },
    },
    -- The fence buys stolen goods and sells lockpicks. Share is the fraction of the pawn price paid for goods.
    Fence = {
        label = 'Back-room fence',
        x = -1152.0, y = -1532.0, z = 4.6, radius = 3.0,
        Share = 0.40,
        DailyCapPounds = 1500.00,
        AlarmChance = 15,           -- percent chance a sale is reported
        Buys = { cash_bag = 300.00, radio = 20.00, phone = 60.00, repair_kit = 30.00, steel_part = 6.00, scrap = 3.00 },
        Sells = { lockpick = 150.00 },
    },
}
