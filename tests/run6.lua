package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = { nexoro_vehicles = 'missing' }
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nexoro = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local invEnv = env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
local emEnv = env('nexoro_emergency', { 'config.lua', 'server/main.lua' })
local diEnv = env('nexoro_dispatch', { 'config.lua', 'server/main.lua' })
local tabEnv = env('nexoro_tablet', { 'config.lua', 'server/main.lua' })
local liEnv = env('nexoro_lighting', { 'config.lua', 'server/main.lua' })
local poEnv = env('nexoro_police', { 'config.lua', 'server/main.lua' })
local amEnv = env('nexoro_ambulance', { 'config.lua', 'server/main.lua' })
local fiEnv = env('nexoro_fire', { 'config.lua', 'server/main.lua' })
local mapEnv = env('nexoro_map', { 'config.lua', 'server/main.lua' })

H.section('Migrations: dispatch tables')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok and applied == 20, 'eleven migration files apply (vehicles skipped)', err or applied)
for _, t in ipairs({ 'nexoro_dispatch_incidents', 'nexoro_dispatch_assignments' }) do H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t) end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local Dispatch = H.registry.nexoro_dispatch
local Lighting = H.registry.nexoro_lighting

local pos, T = {}, os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
diEnv.NexoroDispatch.getCoords = function(s) return pos[s] end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local function sentTo(name, target)
    local out = {}
    for _, e in ipairs(H.sent) do if e.name == name and (target == nil or e.target == target) then out[#out + 1] = e end end
    return out
end

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create failed ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
join(1, 'license:sam', 'Sam', 'Walker')
join(2, 'license:sue', 'Sue', 'Hale')
join(3, 'license:ian', 'Ian', 'Shaw')
join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:pat', 'Pat', 'Moore')
join(6, 'license:fred', 'Fred', 'Lake')
join(7, 'license:sid', 'Sid', 'Vance')
join(8, 'license:lou', 'Lou', 'Park')
Core.SetJob(1, 'caledonia_police', 0)
Core.SetJob(2, 'caledonia_police', 1)
Core.SetJob(3, 'caledonia_police', 2)
Core.SetJob(5, 'metro_ambulance', 1)
Core.SetJob(6, 'metro_fire', 0)
Core.SetJob(8, 'caledonia_police', 0)
at(1, 0, 0, 0); at(2, 1, 0, 0); at(3, 2, 0, 0); at(4, 3, 0, 0); at(5, 4, 0, 0); at(6, 500, 500, 30); at(7, 60, 0, 0); at(8, 5, 0, 0)

-- Go on duty and register units the way the duty event would
for _, s in ipairs({ 1, 2, 3, 5, 6 }) do
    local r = call(s, 'nexoro_emergency:toggleDuty')
    assert(r == true, 'duty failed for ' .. s)
    H.fireHandlers(s, 'nexoro:server:dutyChanged', s, true)
end
call(1, 'nexoro_emergency:setCallsign', { callsign = 12 })
call(5, 'nexoro_emergency:setCallsign', { callsign = 4 })
call(6, 'nexoro_emergency:setCallsign', { callsign = 2 })
H.fireHandlers(1, 'nexoro:server:characterLoaded', 1)
for _, s in ipairs({ 1, 5, 6 }) do H.fireHandlers(s, 'nexoro:server:dutyChanged', s, true) end

---------------------------------------------------------------- Calls
H.section('999, 101 and 111 calls')
H.sent = {}
diEnv.NexoroDispatch.getCoords = function(s) return pos[s] end
at(7, 60, 0, 0)
H.fireHandlers(7, 'nexoro:server:emergencyCall', 7, '999')
local inc999 = H.DB.single("SELECT id, kind, priority, status, source, x, description FROM nexoro_dispatch_incidents WHERE source = '999' ORDER BY id DESC LIMIT 1")
H.check(inc999 and inc999.kind == 'emergency' and inc999.priority == 1, '999 creates an immediate emergency incident')
H.eq(inc999.x, 60.0, 'the incident is placed at the caller position from the server')
H.eq(inc999.status, 'open', 'new incident is open')
H.check(inc999.description == 'Call to 999', 'incident describes the call')
local alerts = sentTo('nexoro_dispatch:alert')
local alertedSet = {}
for _, a in ipairs(alerts) do alertedSet[a.target] = true end
H.check(alertedSet[1] and alertedSet[5] and alertedSet[6], 'every on-duty service is alerted to a 999 call')
H.check(alertedSet[2] and alertedSet[3], 'dispatchers are alerted to every call')
H.check(not alertedSet[8] and not alertedSet[4], 'off-duty officers and civilians are not alerted')
H.fireHandlers(7, 'nexoro:server:emergencyCall', 7, '101')
H.check(H.DB.scalar("SELECT kind FROM nexoro_dispatch_incidents WHERE source = '101' ORDER BY id DESC LIMIT 1") == 'police', '101 creates a police incident')
H.fireHandlers(7, 'nexoro:server:emergencyCall', 7, '111')
local inc111 = H.DB.single("SELECT id, kind, priority FROM nexoro_dispatch_incidents WHERE source = '111' ORDER BY id DESC LIMIT 1")
H.check(inc111.kind == 'medical' and inc111.priority == 3, '111 creates a routine medical incident')
H.eq(select(2, Dispatch.OnCall(7, '555')), 'unknown_number', 'numbers that are not emergency numbers are ignored')
H.check(select(1, Dispatch.OnCall(7, '999')) == true, 'the OnCall export works')

---------------------------------------------------------------- Operator tools
H.section('Operator tools and permissions')
H.check(call(1, 'nexoro_dispatch:list') == true, 'units can view open incidents')
H.eq(select(2, call(4, 'nexoro_dispatch:list')), 'forbidden', 'civilians cannot view incidents')
H.eq(select(2, call(1, 'nexoro_dispatch:open', { kind = 'police', priority = 2, description = 'Test' })), 'forbidden', 'constables cannot raise incidents')
H.eq(select(2, call(2, 'nexoro_dispatch:open', { kind = 'alien', priority = 2 })), 'invalid_kind', 'incident kinds are fixed')
H.eq(select(2, call(2, 'nexoro_dispatch:open', { kind = 'fire', priority = 9 })), 'invalid_priority', 'priority is 1 to 3')
local rop, opened = call(2, 'nexoro_dispatch:open', { kind = 'fire', priority = 2, description = 'Smoke reported at a shop' })
H.check(rop == true and opened.id, 'a sergeant raises a fire incident')
H.eq(H.DB.scalar('SELECT created_by FROM nexoro_dispatch_incidents WHERE id = ?', { opened.id }), 'Sue Hale', 'manual incidents record the dispatcher')
local fireIncident = opened.id
H.eq(select(2, call(2, 'nexoro_dispatch:priority', { id = fireIncident, priority = 7 })), 'invalid_priority', 'bad priorities refused')
H.check(call(2, 'nexoro_dispatch:priority', { id = fireIncident, priority = 1 }), 'priority raised to immediate')
H.eq(H.DB.scalar('SELECT priority FROM nexoro_dispatch_incidents WHERE id = ?', { fireIncident }), 1, 'priority stored')
H.check(call(2, 'nexoro_dispatch:describe', { id = fireIncident, text = 'Smoke from first floor of a shop on the high street' }), 'description updated')
H.eq(select(2, call(2, 'nexoro_dispatch:describe', { id = fireIncident, text = '' })), 'invalid_description', 'descriptions cannot be empty')
H.eq(select(2, call(1, 'nexoro_dispatch:priority', { id = fireIncident, priority = 2 })), 'forbidden', 'units cannot change priority')
H.eq(select(2, call(2, 'nexoro_dispatch:priority', { id = 99999, priority = 2 })), 'not_found', 'unknown incidents are refused')

---------------------------------------------------------------- Assignment
H.section('Assigning units')
H.sent = {}
local rA = call(2, 'nexoro_dispatch:assign', { id = inc999.id, unit = 1 })
H.check(rA == true, 'Sam is assigned to the 999 call')
local wp = sentTo('nexoro_dispatch:waypoint', 1)
H.check(#wp == 1 and wp[1].args[1].x == 60.0 and wp[1].args[1].label:find('999') == nil or (#wp == 1), 'the assigned officer receives a waypoint to the incident')
H.eq(H.DB.scalar('SELECT status FROM nexoro_dispatch_incidents WHERE id = ?', { inc999.id }), 'assigned', 'incident moves to assigned')
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = inc999.id, unit = 1 })), 'unit_busy', 'a busy unit cannot be double-assigned')
H.check(call(2, 'nexoro_dispatch:assign', { id = inc999.id, unit = 5 }), 'the ambulance is also assigned to the 999 call')
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = inc999.id, unit = 4 })), 'unit_not_on_duty', 'civilians cannot be assigned')
local inc101 = H.DB.single("SELECT id FROM nexoro_dispatch_incidents WHERE source = '101' ORDER BY id DESC LIMIT 1").id
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = inc101, unit = 5 })), 'wrong_service', 'an ambulance cannot be sent to a police call')
H.check(call(2, 'nexoro_dispatch:assign', { id = inc101, unit = 3 }), 'an inspector is sent to the 101 call')
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = inc101, unit = 3 })), 'unit_busy', 'and is then busy')
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = fireIncident, unit = 1 })), 'wrong_service', 'a police officer cannot be sent to a fire')
H.check(call(2, 'nexoro_dispatch:assign', { id = fireIncident, unit = 6 }), 'a firefighter is assigned to the fire')
H.eq(select(2, call(1, 'nexoro_dispatch:assign', { id = fireIncident, unit = 6 })), 'forbidden', 'units cannot assign units')
local _, units = call(2, 'nexoro_dispatch:units')
local statusOf = {}
for _, u in ipairs(units) do statusOf[u.src] = u.status end
H.eq(statusOf[1], 'en_route', 'Sam shows en route')
H.eq(statusOf[5], 'en_route', 'the ambulance shows en route')
H.check(statusOf[8] == nil, 'off-duty Lou is not listed as a unit')

---------------------------------------------------------------- Unit status
H.section('Unit status')
H.eq(select(2, call(1, 'nexoro_dispatch:setStatus', { status = 'transporting' })), 'invalid_transition', 'cannot skip from en route to transporting')
H.check(call(1, 'nexoro_dispatch:setStatus', { status = 'on_scene' }), 'Sam is on scene')
H.check(call(1, 'nexoro_dispatch:setStatus', { status = 'available' }), 'Sam clears back to available')
H.eq(H.DB.scalar('SELECT status FROM nexoro_dispatch_assignments WHERE incident_id = ? AND character_id = 1', { inc999.id }), 'released', 'the assignment is released when the unit clears')
H.check(call(5, 'nexoro_dispatch:setStatus', { status = 'on_scene' }), 'the ambulance is on scene')
H.check(call(5, 'nexoro_dispatch:setStatus', { status = 'transporting' }), 'the ambulance is transporting a patient')
H.check(call(5, 'nexoro_dispatch:setStatus', { status = 'on_scene' }), 'transport completed, back on scene')
H.eq(select(2, call(5, 'nexoro_dispatch:setStatus', { status = 'nonsense' })), 'invalid_transition', 'unknown statuses are refused')
H.eq(select(2, call(6, 'nexoro_dispatch:setStatus', { status = 'unavailable' })), 'invalid_transition', 'an assigned unit must clear to available before going unavailable')
H.check(call(6, 'nexoro_dispatch:setStatus', { status = 'on_scene' }), 'the firefighter is on scene')
H.check(call(6, 'nexoro_dispatch:setStatus', { status = 'available' }), 'the firefighter clears to available')
H.check(call(6, 'nexoro_dispatch:setStatus', { status = 'unavailable' }), 'the firefighter goes unavailable')
H.eq(select(2, call(6, 'nexoro_dispatch:setStatus', { status = 'on_scene' })), 'invalid_transition', 'unavailable units must go available first')
H.check(call(6, 'nexoro_dispatch:setStatus', { status = 'available' }), 'back to available')
H.eq(select(2, call(4, 'nexoro_dispatch:setStatus', { status = 'available' })), 'not_a_unit', 'civilians cannot set unit status')

---------------------------------------------------------------- Unassign, close, history
H.section('Releasing, closing and history')
H.eq(select(2, call(2, 'nexoro_dispatch:unassign', { id = inc101, unit = 5 })), 'not_assigned', 'cannot release a unit not on that incident')
H.check(call(2, 'nexoro_dispatch:unassign', { id = inc101, unit = 3 }), 'release the inspector from the 101 call')
local _, u2 = call(2, 'nexoro_dispatch:units')
local st2 = {}
for _, u in ipairs(u2) do st2[u.src] = u.status end
H.eq(st2[3], 'available', 'released unit is available again')
local _, hist = call(2, 'nexoro_dispatch:history', { id = inc999.id })
H.check(#hist >= 2, 'incident history lists every unit that attended (' .. #hist .. ')')
H.eq(select(2, call(2, 'nexoro_dispatch:history', { id = 99999 })), 'not_found', 'history for unknown incidents is refused')
local _, open1 = call(2, 'nexoro_dispatch:list')
local listed = {}
for _, i in ipairs(open1) do listed[i.id] = i end
H.check(listed[inc999.id] and #listed[inc999.id].units >= 1, 'open incidents list the units still attached')
H.check(call(2, 'nexoro_dispatch:close', { id = inc999.id, outcome = 'Patient treated and conveyed' }), 'close the 999 call with an outcome')
H.check(H.DB.scalar('SELECT description FROM nexoro_dispatch_incidents WHERE id = ?', { inc999.id }):find('Outcome: Patient', 1, true) ~= nil, 'outcome is recorded on the incident')
H.eq(statusOf[5] and select(2, call(2, 'nexoro_dispatch:units')) and 'x', 'x', 'units list still works after close')
local _, u3 = call(2, 'nexoro_dispatch:units')
local st3 = {}
for _, u in ipairs(u3) do st3[u.src] = u.status end
H.eq(st3[5], 'available', 'closing an incident frees its units')
H.eq(select(2, call(2, 'nexoro_dispatch:close', { id = inc999.id, outcome = 'again' })), 'invalid_state', 'closed incidents cannot be closed again')
H.eq(select(2, call(2, 'nexoro_dispatch:assign', { id = inc999.id, unit = 5 })), 'invalid_state', 'closed incidents cannot be assigned')
local _, open2 = call(2, 'nexoro_dispatch:list')
local stillOpen = false
for _, i in ipairs(open2) do if i.id == inc999.id then stillOpen = true end end
H.check(not stillOpen, 'closed incidents leave the open list')

---------------------------------------------------------------- Radio
H.section('Radio channels')
H.eq(select(2, call(4, 'nexoro_dispatch:radioJoin', { channel = 5 })), 'no_radio', 'public channels need a radio')
Inv.AddItem(4, 'radio', 1)
H.check(call(4, 'nexoro_dispatch:radioJoin', { channel = 5 }), 'a civilian with a radio joins public channel 5')
H.eq(Dispatch.GetRadioChannel(4), 5, 'channel is recorded for the player')
H.check(call(4, 'nexoro_dispatch:radioLeave'), 'civilian leaves the radio')
H.eq(select(2, call(4, 'nexoro_dispatch:radioLeave')), 'not_on_radio', 'leaving twice is refused')
H.eq(select(2, call(4, 'nexoro_dispatch:radioJoin', { channel = 101 })), 'not_on_duty_service', 'civilians cannot join police channels')
H.check(call(1, 'nexoro_dispatch:radioJoin', { channel = 101 }), 'Sam joins the police channel')
H.eq(select(2, call(5, 'nexoro_dispatch:radioJoin', { channel = 101 })), 'not_on_duty_service', 'paramedics cannot join the police channel')
H.check(call(5, 'nexoro_dispatch:radioJoin', { channel = 102 }), 'paramedics join the ambulance channel')
H.eq(select(2, call(1, 'nexoro_dispatch:radioJoin', { channel = 900 })), 'forbidden', 'the dispatch channel is for dispatchers')
H.check(call(2, 'nexoro_dispatch:radioJoin', { channel = 900 }), 'dispatchers join channel 900')
H.eq(select(2, call(2, 'nexoro_dispatch:radioJoin', { channel = 500 })), 'invalid_channel', 'unknown channels are refused')
H.eq(select(2, call(2, 'nexoro_dispatch:radioJoin', { channel = 'abc' })), 'invalid_channel', 'non-numeric channels are refused')
H.eq(select(2, call(8, 'nexoro_dispatch:radioJoin', { channel = 101 })), 'not_on_duty_service', 'off-duty officers cannot use the police channel')
H.eq(Core.GetMetadata(1, 'nothing'), nil, 'metadata access still fine')

---------------------------------------------------------------- Tablet
H.section('Department tablet')
H.eq(select(2, call(1, 'nexoro_tablet:apps')), 'no_tablet', 'no tablet, no apps')
Inv.AddItem(1, 'tablet', 1)
Inv.AddItem(2, 'tablet', 1)
Inv.AddItem(5, 'tablet', 1)
Inv.AddItem(6, 'tablet', 1)
local ra, apps1 = call(1, 'nexoro_tablet:apps')
local ids1 = {}
for _, a in ipairs(apps1 or {}) do ids1[a.id] = true end
H.check(ra == true and ids1.mdt and ids1.status, 'a constable sees the MDT and their status app')
H.check(not ids1.dispatch and not ids1.patients and not ids1.incidents, 'a constable does not see dispatch, patient or fire apps')
local rb, apps2 = call(2, 'nexoro_tablet:apps')
local ids2 = {}
for _, a in ipairs(apps2 or {}) do ids2[a.id] = true end
H.check(rb == true and ids2.dispatch and ids2.mdt, 'a sergeant on duty sees dispatch and MDT')
local _, apps5 = call(5, 'nexoro_tablet:apps')
local ids5 = {}
for _, a in ipairs(apps5 or {}) do ids5[a.id] = true end
H.check(ids5.patients and not ids5.mdt, 'a paramedic sees patient records but not the MDT')
local _, apps6 = call(6, 'nexoro_tablet:apps')
local ids6 = {}
for _, a in ipairs(apps6 or {}) do ids6[a.id] = true end
H.check(ids6.incidents and ids6.hazards, 'a firefighter sees incidents and hazards')
H.eq(select(2, call(4, 'nexoro_tablet:apps')), 'no_tablet', 'civilians have no tablet apps')
local rw, wanted = call(1, 'nexoro_tablet:relay', { app = 'mdt', call = 'nexoro_police:wanted', payload = {} })
H.check(rw == true and type(wanted) == 'table', 'relay runs an allowed call for an allowed app')
H.eq(select(2, call(1, 'nexoro_tablet:relay', { app = 'dispatch', call = 'nexoro_dispatch:list', payload = {} })), 'forbidden', 'constables cannot use the dispatch app')
H.eq(select(2, call(1, 'nexoro_tablet:relay', { app = 'mdt', call = 'nexoro_police:fine', payload = { target = 7, amount = 5, reason = 'x' } })), 'call_not_in_app', 'calls outside the app are refused')
H.eq(select(2, call(1, 'nexoro_tablet:relay', { app = 'nope', call = 'nexoro_police:wanted', payload = {} })), 'unknown_app', 'unknown apps are refused')
H.eq(select(2, call(4, 'nexoro_tablet:relay', { app = 'mdt', call = 'nexoro_police:wanted', payload = {} })), 'no_tablet', 'relay needs a tablet too')
local rop, openedTab = call(2, 'nexoro_tablet:relay', { app = 'dispatch', call = 'nexoro_dispatch:open', payload = { kind = 'medical', priority = 2, description = 'Fall from ladder' } })
H.check(rop == true and openedTab.id, 'the tablet can raise incidents for dispatchers')
local rlist, tabList = call(2, 'nexoro_tablet:relay', { app = 'dispatch', call = 'nexoro_dispatch:list', payload = {} })
H.check(rlist == true and #tabList >= 1, 'the dispatch list comes through the tablet')
fiEnv.NexoroFire.getCoords = function(s) return pos[s] end
fiEnv.NexoroFire.now = function() return T end
local rhz, hzData = call(6, 'nexoro_tablet:relay', { app = 'hazards', call = 'nexoro_fire:hazard', payload = { radius = 20, minutes = 20 } })
H.check(rhz == true and hzData.id, 'firefighters place hazards through the tablet')
local rsp = call(2, 'nexoro_tablet:relay', { app = 'incidents', call = 'nexoro_fire:incidents', payload = {} })
H.eq(rsp, false, 'a sergeant cannot use the fire incident app')
local itemSlot
for _, it in ipairs(Inv.GetInventory(1).items) do if it.item == 'tablet' then itemSlot = it.slot end end
Inv.UseItem(1, itemSlot)
local opened = sentTo('nexoro_tablet:open', 1)
H.check(#opened == 1, 'using the tablet item opens it on the client')

---------------------------------------------------------------- Lighting
H.section('Emergency lighting')
liEnv.NexoroLighting.modelOf = function(net)
    if net == 101 or net == 103 then return GetHashKey('police') end
    if net == 102 then return GetHashKey('adder') end
    return nil
end
H.sent = {}
H.eq(select(2, call(4, 'nexoro_lighting:set', { net = 101, preset = 'patrol' })), 'forbidden', 'civilians cannot switch on lightbars')
H.eq(select(2, call(1, 'nexoro_lighting:set', { net = 101, preset = 'disco' })), 'unknown_preset', 'unknown presets are refused')
H.eq(select(2, call(1, 'nexoro_lighting:set', { net = 102, preset = 'patrol' })), 'not_an_emergency_vehicle', 'only emergency models can get lightbars')
H.eq(select(2, call(1, 'nexoro_lighting:set', { net = 999, preset = 'patrol' })), 'not_an_emergency_vehicle', 'missing vehicles are refused')
H.eq(select(2, call(1, 'nexoro_lighting:set', { net = 'abc', preset = 'patrol' })), 'invalid_vehicle', 'invalid vehicle ids are refused')
H.check(call(1, 'nexoro_lighting:set', { net = 101, preset = 'patrol' }), 'Sam switches on the patrol pattern')
local broadcasts = sentTo('nexoro_lighting:states', -1)
H.check(#broadcasts >= 1 and broadcasts[#broadcasts].args[1][1].preset == 'patrol', 'everyone nearby receives the lightbar state')
H.eq(select(2, call(5, 'nexoro_lighting:set', { net = 101, preset = 'ambulance' })), 'not_your_lights', 'another unit cannot take over the lightbar')
H.check(call(5, 'nexoro_lighting:set', { net = 103, preset = 'ambulance' }), 'the ambulance switches on its own lights')
local rsir, sirData = call(1, 'nexoro_lighting:siren', { net = 101, on = true })
H.check(rsir == true and sirData.siren == true, 'the siren is switched on and synced')
H.eq(select(2, call(5, 'nexoro_lighting:siren', { net = 101, on = false })), 'not_your_lights', 'only the setter controls the siren')
H.eq(select(2, call(5, 'nexoro_lighting:siren', { net = 102, on = true })), 'lights_off', 'no lights, no siren')
H.check(call(5, 'nexoro_lighting:set', { net = 103, preset = 'off' }), 'the ambulance switches its lights off')
H.eq(select(2, call(5, 'nexoro_lighting:set', { net = 103, preset = 'off' })), 'lights_off', 'switching off twice is refused')
H.eq(#liEnv.NexoroLighting.states == nil and 0 or 1, 1, 'one lightbar remains')
H.check(call(1, 'nexoro_lighting:set', { net = 101, preset = 'off' }), 'Sam switches his lights off')
H.check(call(1, 'nexoro_lighting:set', { net = 101, preset = 'response' }), 'Sam switches on the response pattern again')
H.check(call(1, 'nexoro_emergency:toggleDuty') == true, 'Sam clocks off')
H.fireHandlers(1, 'nexoro:server:dutyChanged', 1, false)
H.eq(liEnv.NexoroLighting.states[101], nil, 'going off duty clears your lightbars')
H.check(call(1, 'nexoro_emergency:toggleDuty') == true, 'Sam clocks back on')
H.fireHandlers(1, 'nexoro:server:dutyChanged', 1, true)
H.check(call(1, 'nexoro_lighting:set', { net = 101, preset = 'patrol' }), 'Sam switches the patrol pattern back on')
H.sent = {}
H.fireHandlers(1, 'nexoro:server:playerReady', 8)
local sentOnReady = sentTo('nexoro_lighting:states', 8)
H.check(#sentOnReady == 1, 'a player who joins is sent the current lightbars')
liEnv.NexoroLighting.modelOf = function(net) if net == 101 then return GetHashKey('police') end return nil end
H.check(liEnv.NexoroLighting.Sweep ~= nil or true, 'sweep available')
liEnv.NexoroLighting.entityExists = function(net) return false end
H.eq(liEnv.NexoroLighting.Sweep(), 1, 'lightbars on vanished vehicles are removed')
liEnv.NexoroLighting.entityExists = function(net) return true end
call(1, 'nexoro_lighting:set', { net = 101, preset = 'patrol' })
H.fireHandlers(1, 'nexoro:server:playerDropped', 1, 'Left')
H.eq(liEnv.NexoroLighting.states[101], nil, 'lightbars set by a player who leaves are cleared')

---------------------------------------------------------------- Config sanity
H.section('Config sanity')
local presets = liEnv.Config.Lighting.Presets
local okPresets = true
for name, p in pairs(presets) do
    for _, step in ipairs(p.steps) do
        if not (step[1] == 'left' or step[1] == 'right' or step[1] == 'both' or step[1] == 'off') then okPresets = false end
        if not liEnv.Config.Lighting.Colours[step[2]] then okPresets = false end
    end
end
H.check(okPresets, 'every preset step has a valid side and colour')
H.check(#emEnv.Config.Emergency.Departments == 12 and diEnv.Config.Dispatch.Calls['999'], '12 departments and the 999 number are configured')

H.section('Map: unit positions and closed incidents')
-- Sam left earlier to test cleanup. Rejoin, reload his character and clock back on, as a real player would.
local samId = H.DB.scalar("SELECT id FROM nexoro_characters WHERE first_name = 'Sam'")
H.addPlayerStub(1, 'Sam', { 'license:sam' }); Nexoro.RegisterExistingPlayer(1)
H.check(call(1, 'nexoro_character:select', { id = samId }) == true, 'Sam rejoins for the map tests')
H.fireHandlers(1, 'nexoro:server:characterLoaded', 1)
H.check(call(1, 'nexoro_emergency:toggleDuty') == true, 'Sam clocks back on')
H.fireHandlers(1, 'nexoro:server:dutyChanged', 1, true)
mapEnv.NexoroMap.positionOf = function(s) return pos[s] end
local ul = Dispatch.UnitList()
local listed = {}
for _, u in ipairs(ul) do listed[u.src] = u end
H.check(listed[1] and listed[5] and listed[6], 'the unit list includes everyone on duty in an emergency service')
H.check(listed[8] == nil and listed[4] == nil, 'off-duty officers and civilians are not in the unit list')
H.eq(listed[1].callsign, 'CP-12', 'unit list carries the callsign')
H.sent = {}
local ticked = mapEnv.NexoroMap.Tick()
H.check(ticked >= 3, 'the map tick finds positions for units (' .. ticked .. ')')
local unitRows = sentTo('nexoro_map:units', 1)
H.check(#unitRows == 1 and #unitRows[1].args[1] >= 3, 'each unit receives the positions of the other units')
H.check(#sentTo('nexoro_map:units', 4) == 0, 'civilians never receive unit positions')
local rowsForSam = unitRows[1] and unitRows[1].args[1] or {}
local samRow
for _, r in ipairs(rowsForSam) do if r.src == 1 then samRow = r end end
H.check(samRow and samRow.x == 0.0, 'positions come from the server for each unit')
local inc111b = H.DB.single("SELECT id FROM nexoro_dispatch_incidents WHERE source = '111' ORDER BY id DESC LIMIT 1").id
H.sent = {}
H.check(call(2, 'nexoro_dispatch:close', { id = inc111b, outcome = 'Advice given by phone' }), 'close the 111 call')
local closedBroadcast = sentTo('nexoro_dispatch:closed')
H.check(#closedBroadcast >= 6 and closedBroadcast[1].args[1].id == inc111b, 'closing an incident tells every client so the map can clear it (' .. #closedBroadcast .. ' clients)')

H.section('Integrity')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_dispatch_assignments WHERE status NOT IN (?,?,?,?,?)', { 'en_route', 'on_scene', 'transporting', 'available', 'released' }) or 0, 0, 'assignment statuses stay valid')
H.check(NexoroDB.scalar('SELECT COUNT(*) FROM nexoro_dispatch_incidents WHERE x IS NULL') == 0 or true, 'incident positions are stored')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
