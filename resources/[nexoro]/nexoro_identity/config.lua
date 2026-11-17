Config = {}

Config.Identity = {
    Genders = { 'male', 'female', 'non-binary' },
    Nationalities = {
        'British', 'English', 'Scottish', 'Welsh', 'Northern Irish', 'Irish', 'Polish', 'Romanian', 'Lithuanian',
        'Indian', 'Pakistani', 'Bangladeshi', 'Nigerian', 'Jamaican', 'French', 'German', 'Spanish', 'Italian',
        'Portuguese', 'Gypsy, Roma or Traveller', 'Other',
    },
    MinNameLength = 2,
    MaxNameLength = 24,
    MinAge = 18,
    MaxAge = 90,
    MinHeight = 140,
    MaxHeight = 210,
    MaxBiography = 500,

    -- Names containing any of these (case-insensitive) are rejected, so players cannot pose as staff or services.
    BlockedNameParts = {
        'admin', 'moderator', 'staff', 'nexoro', 'police', 'officer', 'ambulance', 'paramedic',
        'fire brigade', 'dispatcher', 'owner', 'developer', 'system',
    },

    -- Citizen ID = prefix + random characters (no 0/O/1/I to avoid confusion), e.g. NX4K7P2Q
    CitizenIdPrefix = 'NX',
    CitizenIdRandomLength = 6,
}
