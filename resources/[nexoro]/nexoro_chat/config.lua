Config = {}

Config.Chat = {
    MaxLength = 240,
    HistorySize = 60,          -- public messages replayed to players who join
    OpenKey = 'T',

    -- Job prefix shown by the SERVER. Players can never choose or type their own.
    -- Looked up by job name first, then job category, otherwise Default.
    Prefixes = {
        byName = {
            mechanic = { label = 'MECHANIC', colour = '#f59e0b' },
            taxi = { label = 'TAXI', colour = '#eab308' },
        },
        byCategory = {
            police = { label = 'POLICE', colour = '#3b82f6', requireDuty = true },
            ambulance = { label = 'AMBULANCE', colour = '#22c55e', requireDuty = true },
            fire = { label = 'FIRE & RESCUE', colour = '#ef4444', requireDuty = true },
            government = { label = 'COUNCIL', colour = '#a78bfa' },
        },
        default = { label = 'CITIZEN', colour = '#d1d5db' },
    },

    -- Which job categories count as emergency services (for the emergency channel).
    EmergencyCategories = { police = true, ambulance = true, fire = true },

    -- distance is in metres; permission/emergency/department gates are enforced on the server.
    Channels = {
        ['local'] = { label = 'LOCAL', distance = 20.0, cooldownMs = 700, colour = '#ffffff' },
        global = { label = 'OOC', cooldownMs = 4000, colour = '#9ca3af' },
        me = { label = 'ME', distance = 20.0, cooldownMs = 1500, colour = '#c4b5fd', action = true },
        ['do'] = { label = 'DO', distance = 20.0, cooldownMs = 1500, colour = '#c4b5fd', action = true },
        department = { label = 'DEPT', cooldownMs = 700, colour = '#93c5fd', department = true },
        emergency = { label = '999', cooldownMs = 700, colour = '#60a5fa', emergency = true },
        staff = { label = 'STAFF', cooldownMs = 500, colour = '#f472b6', permission = 'nexoro.staff.chat' },
        pm = { label = 'PM', cooldownMs = 1500, colour = '#fbbf24' },
        radio = { label = 'RADIO', cooldownMs = 800, colour = '#fbbf24', radio = true },
    },

    Spam = { windowMs = 10000, maxMessages = 8, duplicateWindowMs = 15000, muteSecondsOnSpam = 30 },

    Profanity = {
        enabled = true,
        words = { 'fuck', 'shit', 'cunt', 'wanker', 'bastard', 'bollocks' },
    },
}
