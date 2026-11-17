Config = {}

Config.Vehicles = {
    -- UK plates look like AB12 CDE (area letters, age identifier, random letters). I, Q and Z are never used.
    AgeIdentifiers = { '21', '22', '23', '24', '25', '26', '71', '72', '73', '74', '75', '76' },

    MaxSharedKeys = 5,
    TransferOfferSeconds = 60,
    TransferMaxDistance = 6.0,
    TransferMaxPricePounds = 5000000,

    -- Fuel
    FuelPricePerLitre = 1.45,
    FuelTankLitres = 60,            -- fuel is stored as 0-100 percent; litres = percent * tank / 100
    Pumps = {
        { x = 49.4, y = 2778.8, z = 58.0 }, { x = 263.9, y = 2606.5, z = 44.9 }, { x = -724.6, y = -935.2, z = 19.2 },
        { x = -70.2, y = -1761.8, z = 29.5 }, { x = 265.6, y = -1261.3, z = 29.3 }, { x = 819.7, y = -1028.8, z = 26.4 },
        { x = 1208.9, y = -1402.6, z = 35.2 }, { x = -2096.2, y = -320.3, z = 13.2 },
    },
    PumpRadius = 7.0,

    -- Insurance: price = purchase price x rate for the plan (minimum applies). Days are real days.
    InsurancePlans = { [7] = 0.02, [14] = 0.035, [30] = 0.06 },
    InsuranceMinimumPounds = 25,
    InsuranceExcessRate = 0.10,      -- paid when claiming for a wrecked vehicle

    -- MOT (UK maximum fee is 54.85)
    MotFeePounds = 54.85,
    MotValidDays = 30,
    MotMinEngine = 500,
    MotMinBody = 400,
    MotStations = { { x = -337.4, y = -136.9, z = 39.0 }, { x = 731.8, y = -1088.8, z = 22.2 } },
    MotRadius = 12.0,

    -- Finance
    FinanceMinDepositRate = 0.10,
    FinanceInterestRate = 0.08,
    FinancePayments = 8,
    FinancePeriodDays = 7,
    FinanceRepossessAfterMissed = 3,

    -- Dealer buyback
    BuybackRate = 0.5,

    -- Vehicles left outside
    OutVehiclesOnRestart = 'stored',     -- they return to their garage when the server restarts
    SpawnConfirmSeconds = 30,            -- a retrieved vehicle that never appears returns to its garage
    AbandonAfterSeconds = 600,           -- a vehicle whose entity vanished is impounded
    AbandonedFeePounds = 150,

    ImpoundLots = {
        mrpd_lot = { label = 'Mission Row Police Impound', garage = 'mrpd_lot' },
    },
    DefaultGarage = 'legion_garage',
    StateReportSeconds = 30,

    -- Car washes. Coordinates are placeholders: check them in-game.
    CarWashes = { { x = -699.6, y = -932.0, z = 19.0 } },
    CarWashRadius = 8.0,
    WashPriceFine = 15.00,
    -- Dirt builds up while driving (0 clean, 15 filthy). Scale: metres per second times this rate.
    DirtRate = 0.00025,
    -- A hard enough impact can puncture a tyre. Body health lost in one tick triggers the check.
    PunctureImpact = 120.0,
    PunctureChance = 0.35,

    -- Client: fuel burn in percent per second (idle, and extra at full RPM)
    FuelConsumption = { idle = 0.002, load = 0.02 },
    LockKey = 'L',
}
