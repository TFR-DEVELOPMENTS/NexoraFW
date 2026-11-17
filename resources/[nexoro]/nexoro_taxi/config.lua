Config = {}

Config.Taxi = {
    JobName = 'taxi',
    BaseFarePounds = 3.20,
    PerMileFarePounds = 1.80,
    MinFarePounds = 4.50,
    DriverShare = 0.80,          -- the driver keeps this share of the fare
    RoadFactor = 1.25,           -- road distance is about 25% longer than the straight line
    MaxMph = 90,                 -- a fare cannot finish faster than this allows (anti-cheat)
    PickupRadius = 12.0,         -- passenger must be this close to the driver to be offered a fare
    DropRadius = 12.0,           -- passenger must be this close to the driver to finish the fare
    OfferSeconds = 45,
}
