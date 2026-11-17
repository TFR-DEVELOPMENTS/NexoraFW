Config = {}

-- Department and rank names here are FICTIONAL PLACEHOLDERS. Real service names, crests and
-- branding (police forces, NHS trusts, fire services) must not be used without permission, because
-- it can imply official affiliation. Rename labels to your own original names.
--
-- Salaries are paid on each payday (see nexoro_banking). They are shown per payday here, so tune them
-- against your economy.

Config.Emergency = {
    -- Each template defines the ranks (grade 0 = first rank) and the permissions gained at each grade.
    Templates = {
        police = { category = 'police', dutyPerm = 'police.duty', ranks = {
            { label = 'Police Constable', salary = 14.50 }, { label = 'Sergeant', salary = 17.00 }, { label = 'Inspector', salary = 20.00 },
            { label = 'Chief Inspector', salary = 22.50 }, { label = 'Superintendent', salary = 25.00 }, { label = 'Chief Superintendent', salary = 27.50 },
            { label = 'Assistant Chief Constable', salary = 30.00 }, { label = 'Deputy Chief Constable', salary = 32.50 }, { label = 'Chief Constable', salary = 35.00 } },
            perms = {
                { minGrade = 0, list = { 'police.duty', 'police.cuff', 'police.caution', 'police.fine', 'police.search', 'police.seize', 'police.mdt' } },
                { minGrade = 1, list = { 'police.breath', 'police.warrant', 'dispatch.operate' } },
                { minGrade = 2, list = { 'emergency.manage' } },
            } },
        highways = { category = 'police', dutyPerm = 'police.duty', ranks = {
            { label = 'Traffic Officer', salary = 13.50 }, { label = 'Traffic Sergeant', salary = 16.00 }, { label = 'Traffic Inspector', salary = 19.00 } },
            perms = {
                { minGrade = 0, list = { 'police.duty', 'police.cuff', 'police.caution', 'police.fine', 'police.search', 'police.seize', 'police.mdt' } },
                { minGrade = 1, list = { 'police.breath', 'police.warrant', 'dispatch.operate' } },
                { minGrade = 2, list = { 'emergency.manage', 'dispatch.operate' } },
            } },
        ambulance = { category = 'ambulance', dutyPerm = 'medical.duty', ranks = {
            { label = 'Trainee Paramedic', salary = 13.00 }, { label = 'Paramedic', salary = 15.50 }, { label = 'Senior Paramedic', salary = 17.50 },
            { label = 'Team Leader', salary = 19.50 }, { label = 'Operations Manager', salary = 22.00 } },
            perms = {
                { minGrade = 0, list = { 'medical.duty', 'medical.revive', 'medical.treat', 'medical.mdt' } },
                { minGrade = 1, list = { 'medical.admit' } },
                { minGrade = 3, list = { 'emergency.manage', 'dispatch.operate' } },
            } },
        fire = { category = 'fire', dutyPerm = 'fire.duty', ranks = {
            { label = 'Firefighter', salary = 13.00 }, { label = 'Crew Manager', salary = 15.50 }, { label = 'Watch Manager', salary = 18.00 },
            { label = 'Station Manager', salary = 20.50 }, { label = 'Group Manager', salary = 23.00 } },
            perms = {
                { minGrade = 0, list = { 'fire.duty', 'fire.mdt', 'fire.extinguish', 'fire.extricate', 'fire.hazard' } },
                { minGrade = 2, list = { 'emergency.manage' } },
            } },
    },

    -- job = internal id (lowercase, underscores). prefix = callsign prefix, e.g. CP-12.
    Departments = {
        { job = 'caledonia_police', label = 'Caledonia Police', template = 'police', prefix = 'CP' },
        { job = 'metro_police', label = 'Metro City Police', template = 'police', prefix = 'MP' },
        { job = 'northvale_police', label = 'Northvale Constabulary', template = 'police', prefix = 'NP' },
        { job = 'midland_police', label = 'Midland Constabulary', template = 'police', prefix = 'MC' },
        { job = 'harbourside_police', label = 'Harbourside Police', template = 'police', prefix = 'HP' },
        { job = 'rail_police', label = 'Rail Transport Police', template = 'police', prefix = 'RP' },
        { job = 'highways_patrol', label = 'Highways Traffic Patrol', template = 'highways', prefix = 'HT' },
        { job = 'caledonia_ambulance', label = 'Caledonia Ambulance Service', template = 'ambulance', prefix = 'CA' },
        { job = 'metro_ambulance', label = 'Metro City Ambulance Service', template = 'ambulance', prefix = 'MA' },
        { job = 'northern_ambulance', label = 'Northern Ambulance Trust', template = 'ambulance', prefix = 'NA' },
        { job = 'caledonia_fire', label = 'Caledonia Fire and Rescue', template = 'fire', prefix = 'CF' },
        { job = 'metro_fire', label = 'Metro City Fire Brigade', template = 'fire', prefix = 'MF' },
    },

    CallsignMax = 99,
    MenuKey = 'F6',

    -- PLACEHOLDER uniform component IDs: { drawable, texture }. Replace with your uniform items after testing in-game.
    -- Components: 3 torso, 4 legs, 6 shoes, 8 undershirt, 11 tops. Props: 0 hats.
    Uniforms = {
        police = { components = { [3] = { 0, 0 }, [4] = { 35, 0 }, [6] = { 25, 0 }, [8] = { 58, 0 }, [11] = { 55, 0 } }, props = { [0] = { -1, 0 } } },
        ambulance = { components = { [3] = { 1, 0 }, [4] = { 36, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 86, 0 } }, props = { [0] = { -1, 0 } } },
        fire = { components = { [3] = { 2, 0 }, [4] = { 37, 0 }, [6] = { 25, 0 }, [8] = { 15, 0 }, [11] = { 88, 0 } }, props = { [0] = { -1, 0 } } },
    },
}
