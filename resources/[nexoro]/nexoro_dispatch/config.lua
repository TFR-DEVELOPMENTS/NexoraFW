Config = {}

Config.Dispatch = {
    -- Numbers the phone can dial. Each creates an incident at the caller's position.
    Calls = {
        ['999'] = { kind = 'emergency', priority = 1 },
        ['101'] = { kind = 'police', priority = 3 },
        ['111'] = { kind = 'medical', priority = 3 },
    },
    PriorityLabels = { [1] = 'Immediate', [2] = 'Urgent', [3] = 'Routine' },
    -- Which unit categories an incident kind can be sent to. emergency = any service.
    KindCategories = {
        police = { police = true },
        medical = { ambulance = true },
        fire = { fire = true },
        emergency = { police = true, ambulance = true, fire = true },
    },
    AssignDistanceNote = 'Assignment is by dispatcher choice; the server checks rank, duty and availability.',
    WaypointLabelPrefix = 'Incident',

    Radio = {
        PublicMax = 99,          -- channels 1-99: anyone holding a radio item
        Channels = { [101] = 'police', [102] = 'ambulance', [103] = 'fire' },   -- on duty members of that service
        DispatchChannel = 900,   -- dispatchers only
    },
}
