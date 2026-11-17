Config = {}

Config.Police = {
    InteractDistance = 4.0,
    MaxFine = 5000,                    -- pounds, per penalty notice
    MaxSentenceMinutes = 20160,        -- prison sentences are handled by the prison system (Phase 7)
    -- Breath reading limit in micrograms of alcohol per 100 ml of breath. Set to match your server's rules.
    BreathLimit = 35,
    EvidenceSlots = 10,
    EvidenceMaxWeight = 20000,         -- grams
}
