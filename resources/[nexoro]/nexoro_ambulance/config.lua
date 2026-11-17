Config = {}

Config.Ambulance = {
    InteractDistance = 4.0,
    ReviveCooldownSeconds = 60,
    ReviveHealth = 150,
    BandageHeal = 25,
    -- UK NHS treatment is free at the point of use. Billing is OFF by default. Enable only if your
    -- roleplay needs charges (for example private healthcare), and check it fits your server's rules.
    BillPatients = false,
    AdmissionFeePounds = 250.00,
    Wards = { 'Ward A', 'Ward B', 'Critical Care' },
    -- Patients can only be admitted while within one of these areas. Names are placeholders.
    Hospitals = { { name = 'Pillbox Hill General', x = 298.7, y = -584.4, z = 43.3, radius = 40.0 } },
}
