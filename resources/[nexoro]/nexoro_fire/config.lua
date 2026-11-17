Config = {}

Config.Fire = {
    InteractDistance = 50.0,        -- how close a crew must be to an incident to act on it
    ExtinguishRadius = 40.0,        -- hazard zones inside this radius of a fire are cleared when it is controlled
    HazardMinRadius = 10,
    HazardMaxRadius = 80,
    HazardMaxMinutes = 120,
    Kinds = { fire = true, rta = true, rescue = true },
}
