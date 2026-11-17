Config = {}

-- Every app lists the server callbacks it may call. The server refuses anything not listed here,
-- and each callback keeps its own permission checks. A tablet cannot reach beyond these lists.
Config.Tablet = {
    Item = 'tablet',
    Apps = {
        dispatch = { label = 'Dispatch', perm = 'dispatch.operate', calls = { 'nexoro_dispatch:list', 'nexoro_dispatch:units', 'nexoro_dispatch:history', 'nexoro_dispatch:open', 'nexoro_dispatch:priority', 'nexoro_dispatch:describe', 'nexoro_dispatch:assign', 'nexoro_dispatch:unassign', 'nexoro_dispatch:close' } },
        status = { label = 'My status', unit = true, calls = { 'nexoro_dispatch:setStatus', 'nexoro_dispatch:list' } },
        mdt = { label = 'MDT', perm = 'police.mdt', calls = { 'nexoro_police:mdt', 'nexoro_police:wanted', 'nexoro_police:plate' } },
        patients = { label = 'Patient records', perm = 'medical.mdt', calls = { 'nexoro_ambulance:records' } },
        incidents = { label = 'Fire incidents', perm = 'fire.mdt', calls = { 'nexoro_fire:incidents', 'nexoro_fire:create', 'nexoro_fire:attend', 'nexoro_fire:close', 'nexoro_fire:extinguish', 'nexoro_fire:extricate' } },
        hazards = { label = 'Hazards', perm = 'fire.hazard', calls = { 'nexoro_fire:hazard', 'nexoro_fire:clearHazard' } },
    },
    -- Form definitions for the screen. auto = load when the app opens (no fields needed).
    Forms = {
        ['nexoro_dispatch:list'] = { label = 'Open incidents', auto = true },
        ['nexoro_dispatch:units'] = { label = 'Units on duty', auto = true },
        ['nexoro_dispatch:open'] = { label = 'Raise incident', hint = 'Creates a manual incident at your position. Priority 1 is immediate, 3 is routine.', fields = {
            { name = 'kind', label = 'Kind', type = 'select', options = { 'police', 'medical', 'fire', 'emergency' } },
            { name = 'priority', label = 'Priority', type = 'select', options = { '1', '2', '3' } },
            { name = 'description', label = 'Description', type = 'text' } } },
        ['nexoro_dispatch:priority'] = { label = 'Change priority', fields = {
            { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'priority', label = 'Priority', type = 'select', options = { '1', '2', '3' } } } },
        ['nexoro_dispatch:describe'] = { label = 'Update description', fields = {
            { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'text', label = 'Description', type = 'text' } } },
        ['nexoro_dispatch:assign'] = { label = 'Assign unit', hint = "Enter the incident ID and the unit's server ID from the Units list. The unit must be on duty and free.", fields = {
            { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'unit', label = 'Unit server ID', type = 'number' } } },
        ['nexoro_dispatch:unassign'] = { label = 'Release unit', fields = {
            { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'unit', label = 'Unit server ID', type = 'number' } } },
        ['nexoro_dispatch:close'] = { label = 'Close incident', fields = {
            { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'outcome', label = 'Outcome', type = 'text' } } },
        ['nexoro_dispatch:history'] = { label = 'Incident history', fields = { { name = 'id', label = 'Incident ID', type = 'number' } } },
        ['nexoro_dispatch:setStatus'] = { label = 'Set my status', hint = 'Tells dispatch what you are doing. Some changes are only allowed from certain statuses.', fields = {
            { name = 'status', label = 'Status', type = 'select', options = { 'available', 'en_route', 'on_scene', 'transporting', 'unavailable' } } } },
        ['nexoro_police:mdt'] = { label = 'Person lookup', hint = "Enter the person's Citizen ID from their ID card. Shows records and any open warrants.", fields = { { name = 'citizenId', label = 'Citizen ID', type = 'text' } } },
        ['nexoro_police:wanted'] = { label = 'Wanted persons', auto = true },
        ['nexoro_police:plate'] = { label = 'Vehicle lookup', fields = { { name = 'plate', label = 'Plate', type = 'text' } } },
        ['nexoro_ambulance:records'] = { label = 'Patient records', fields = { { name = 'citizenId', label = 'Citizen ID', type = 'text' } } },
        ['nexoro_fire:incidents'] = { label = 'Open incidents', auto = true },
        ['nexoro_fire:create'] = { label = 'Raise incident', fields = {
            { name = 'kind', label = 'Kind', type = 'select', options = { 'fire', 'rta', 'rescue' } }, { name = 'notes', label = 'Notes', type = 'text' } } },
        ['nexoro_fire:attend'] = { label = 'Attend', fields = { { name = 'id', label = 'Incident ID', type = 'number' } } },
        ['nexoro_fire:close'] = { label = 'Close', fields = { { name = 'id', label = 'Incident ID', type = 'number' }, { name = 'outcome', label = 'Outcome', type = 'text' } } },
        ['nexoro_fire:extinguish'] = { label = 'Extinguish', fields = { { name = 'id', label = 'Incident ID', type = 'number' } } },
        ['nexoro_fire:extricate'] = { label = 'Extricate casualty', fields = { { name = 'id', label = 'Incident ID', type = 'number' } } },
        ['nexoro_fire:hazard'] = { label = 'Place hazard zone', hint = 'Shows as a red zone on every player map. Radius 10 to 80 metres; it expires after the minutes you set.', fields = {
            { name = 'radius', label = 'Radius (10-80 m)', type = 'number' }, { name = 'minutes', label = 'Minutes (1-120)', type = 'number' } } },
        ['nexoro_fire:clearHazard'] = { label = 'Clear hazard', fields = { { name = 'id', label = 'Zone ID', type = 'number' } } },
    },
}
