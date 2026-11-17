Config = {}

-- Anyone can claim a pitch and anyone can be served a notice. Background, including the Gypsy, Roma and Traveller
-- background, has no effect on claims, notices, warrants or gates.
Config.Encampments = {
    ClaimFeePounds = 250.00,
    NoticeDays = 14,              -- time given to move on after a notice is served
    WarrantHours = 24,            -- how long a warrant lasts once issued
    WarrantRank = 1,              -- police grade needed to issue a warrant (1 = sergeant)
    NoticeRank = 0,               -- police grade needed to serve a notice
    -- Sites where pitches can be claimed. Coordinates and pitches are placeholders for Sandy Shores and Grapeseed.
    Sites = {
        { id = 'sandy_shores', label = 'Sandy Shores' },
        { id = 'grapeseed', label = 'Grapeseed' },
    },
    Pitches = {
        { id = 'sandy_1', site = 'sandy_shores', label = 'Sandy Shores pitch 1', x = 1690.0, y = 3580.0, z = 35.0, radius = 15.0 },
        { id = 'sandy_2', site = 'sandy_shores', label = 'Sandy Shores pitch 2', x = 1720.0, y = 3600.0, z = 35.0, radius = 15.0 },
        { id = 'grape_1', site = 'grapeseed', label = 'Grapeseed pitch 1', x = 2000.0, y = 4850.0, z = 42.0, radius = 15.0 },
    },
    -- Gates belong to a pitch. Only the occupant, or police with a live warrant for that pitch, can open or close them.
    Gates = {
        { id = 'sandy_1_gate', pitch = 'sandy_1', x = 1685.0, y = 3575.0, z = 35.0, radius = 6.0,
          -- The gate prop placed in the MLO. Replace the model with your gate's model name.
          model = 'prop_fncsec_04', openHeading = 90.0, closedHeading = 0.0 },
    },
}
