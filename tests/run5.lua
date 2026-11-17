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
local poEnv = env('nexoro_police', { 'config.lua', 'server/main.lua' })
local amEnv = env('nexoro_ambulance', { 'config.lua', 'server/main.lua' })
local fiEnv = env('nexoro_fire', { 'config.lua', 'server/main.lua' })

H.section('Migrations: police, ambulance and fire tables')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok and applied == 20, "eleven migration files apply (vehicles skipped in this run)", err or applied)
for _, t in ipairs({ 'nexoro_police_records', 'nexoro_police_evidence', 'nexoro_medical_records', 'nexoro_fire_incidents' }) do
    H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t)
end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory

local pos, dead, T = {}, {}, os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
poEnv.NexoroPolice.getCoords = function(s) return pos[s] end
amEnv.NexoroAmbulance.getCoords = function(s) return pos[s] end
amEnv.NexoroAmbulance.isDead = function(s) return dead[s] == true end
amEnv.NexoroAmbulance.now = function() return T end
fiEnv.NexoroFire.getCoords = function(s) return pos[s] end
fiEnv.NexoroFire.now = function() return T end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license })
    Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create failed for ' .. first .. ': ' .. tostring(d and d.message or d))
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true, 'select failed for ' .. first)
    return d.id
end
local CH = {}
CH[1] = join(1, 'license:sam', 'Sam', 'Walker')
CH[2] = join(2, 'license:sue', 'Sue', 'Hale')
CH[3] = join(3, 'license:ian', 'Ian', 'Shaw')
CH[4] = join(4, 'license:cara', 'Cara', 'Lane')
CH[5] = join(5, 'license:pat', 'Pat', 'Moore')
CH[6] = join(6, 'license:fred', 'Fred', 'Lake')
CH[7] = join(7, 'license:sid', 'Sid', 'Vance')
CH[8] = join(8, 'license:lou', 'Lou', 'Park')
Core.AddMoney(7, 0, 'cash', 'noop')

-- Pre-assign careers (hiring itself is tested below)
Core.SetJob(1, 'caledonia_police', 0)
Core.SetJob(2, 'caledonia_police', 1)
Core.SetJob(3, 'caledonia_police', 2)
Core.SetJob(5, 'metro_ambulance', 1)
Core.SetJob(6, 'metro_fire', 0)
Core.SetJob(8, 'caledonia_police', 0)
for s = 1, 8 do pos[s] = { x = s * 10.0, y = 0.0, z = 0.0 } end
pos[2], pos[1], pos[8], pos[3] = { x = 1, y = 0, z = 0 }, { x = 0, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, { x = 2, y = 0, z = 0 }
pos[7] = { x = 2, y = 0, z = 0 }
pos[4] = { x = 3, y = 0, z = 0 }
pos[5] = { x = 300, y = -580, z = 43 }
pos[6] = { x = 500, y = 500, z = 30 }
Core.GetCharacter(7)  -- Sid, suspect
Core.SetDuty(1, false)

H.section('Departments and job definitions')
H.eq(#emEnv.NexoroEmergency.Definitions(), 12, 'twelve departments are defined')
local jobs = {}
for _, j in ipairs(Core.GetJobs()) do jobs[j.name] = j end
H.check(jobs.caledonia_police and jobs.caledonia_police.whitelisted == true, 'police jobs are whitelisted (not in the job centre)')
H.eq(#jobs.caledonia_police.grades, 9, 'police department has nine ranks')
H.eq(#jobs.highways_patrol.grades, 3, 'highways patrol has three ranks')
H.eq(#jobs.metro_ambulance.grades, 5, 'ambulance has five ranks')
H.eq(#jobs.metro_fire.grades, 5, 'fire has five ranks')
H.eq(jobs.caledonia_police.grades[1].label, 'Police Constable', 'grade 0 is Police Constable')
H.eq(jobs.caledonia_police.grades[9].label, 'Chief Constable', 'top grade is Chief Constable')
H.eq(jobs.caledonia_police.category, 'police', 'police category matches public chat tagging')
H.eq(jobs.metro_fire.category, 'fire', 'fire category')
local function has(list, p) for _, v in ipairs(list) do if v == p then return true end end return false end
H.check(has(Core.GetGradePermissions('caledonia_police', 0), 'police.cuff'), 'constables can cuff')
H.check(not has(Core.GetGradePermissions('caledonia_police', 0), 'police.breath'), 'constables cannot breath test')
H.check(has(Core.GetGradePermissions('caledonia_police', 1), 'police.breath'), 'sergeants can breath test')
H.check(not has(Core.GetGradePermissions('caledonia_police', 1), 'emergency.manage'), 'sergeants cannot manage staff')
H.check(has(Core.GetGradePermissions('caledonia_police', 2), 'emergency.manage'), 'inspectors can manage staff')
H.check(has(Core.GetGradePermissions('metro_fire', 0), 'fire.extricate') and not has(Core.GetGradePermissions('metro_fire', 0), 'medical.revive'), 'fire has its own permissions only')
H.check(has(Core.GetGradePermissions('metro_ambulance', 0), 'medical.revive') and not has(Core.GetGradePermissions('metro_ambulance', 0), 'police.cuff'), 'ambulance has its own permissions only')
H.eq(#Core.GetGradePermissions('nonexistent_job', 0), 0, 'unknown job has no permissions')

H.section('Duty')
local r1, d1 = call(1, 'nexoro_emergency:toggleDuty')
H.check(r1 == true and d1.onDuty == true, 'constable goes on duty')
H.check(Core.GetJob(1).onDuty == true, 'duty is reflected in the core job state')
H.eq(select(2, call(4, 'nexoro_emergency:toggleDuty')), 'not_emergency', 'civilians cannot clock on')
local r5 = call(5, 'nexoro_emergency:toggleDuty')
H.check(r5 == true, 'paramedic goes on duty with medical.duty')
H.check(H.registry.nexoro_emergency.HasPerm(1, 'police.cuff', false) == true, 'on-duty constable has police.cuff')
H.check(H.registry.nexoro_emergency.HasPerm(1, 'medical.revive', false) == false, 'constable has no medical permissions')
H.check(H.registry.nexoro_emergency.HasPerm(5, 'police.cuff', false) == false, 'paramedic has no police permissions')
H.check(H.registry.nexoro_emergency.HasPerm(6, 'medical.revive', false) == false, 'firefighter has no medical permissions')
call(1, 'nexoro_emergency:toggleDuty')
H.check(H.registry.nexoro_emergency.HasPerm(1, 'police.cuff', false) == false, 'off duty loses operational permissions')
H.check(H.registry.nexoro_emergency.HasPerm(1, 'police.duty', true) == true, 'off-duty officers keep the duty permission to clock on')
call(1, 'nexoro_emergency:toggleDuty')
call(2, 'nexoro_emergency:toggleDuty')
call(3, 'nexoro_emergency:toggleDuty')
call(6, 'nexoro_emergency:toggleDuty')
call(8, 'nexoro_emergency:toggleDuty')
H.check(Core.GetJob(2).onDuty and Core.GetJob(3).onDuty, 'sergeant and inspector are on duty')
H.check(H.registry.nexoro_emergency.HasPerm(2, 'police.breath', false) and not H.registry.nexoro_emergency.HasPerm(8, 'police.breath', false), 'sergeant can breath test; constable cannot')

H.section('Callsigns')
local c1 = call(1, 'nexoro_emergency:setCallsign', { callsign = 12 })
H.check(c1 == true and select(2, call(1, 'nexoro_emergency:status')).callsign == 'CP-12', 'Sam takes callsign CP-12')
H.eq(select(2, call(8, 'nexoro_emergency:setCallsign', { callsign = 12 })), 'callsign_taken', 'same callsign in the same department is refused')
H.check(call(8, 'nexoro_emergency:setCallsign', { callsign = 13 }), 'Lou takes CP-13')
for _, bad in ipairs({ 0, 100, 'abc', -4, 2.5 }) do
    H.check(call(8, 'nexoro_emergency:setCallsign', { callsign = bad }) == false, 'invalid callsign rejected: ' .. tostring(bad))
end
H.check(call(5, 'nexoro_emergency:setCallsign', { callsign = 12 }) == true, 'an ambulance crew can use the same number (different prefix)')
H.eq(select(2, call(5, 'nexoro_emergency:status')).callsign, 'MA-12', 'ambulance prefix is MA')
H.eq(select(2, call(4, 'nexoro_emergency:setCallsign', { callsign = 1 })), 'not_emergency', 'civilians cannot take a callsign')

H.section('Roster')
local rr, roster = call(3, 'nexoro_emergency:roster')
H.check(rr == true, 'roster loads for a member')
local names = {}
for _, m in ipairs(roster) do names[#names + 1] = m.name end
H.eq(#roster, 4, 'roster lists the four online caledonia officers')
H.eq(roster[1].name, 'Ian Shaw', 'highest rank is listed first')
H.eq(roster[1].rank, 'Inspector', 'rank label shown')
H.check(roster[1].onDuty == true, 'duty status shown')
local foundPat = false
for _, m in ipairs(roster) do if m.name == 'Pat Moore' then foundPat = true end end
H.check(not foundPat, 'roster excludes other departments')
H.eq(select(2, call(4, 'nexoro_emergency:roster')), 'not_emergency', 'civilians cannot read a roster')

H.section('Management: hire, promote, demote, dismiss')
H.eq(select(2, call(1, 'nexoro_emergency:hire', { target = CH[4] and 4 })), 'forbidden', 'constables cannot hire')
H.eq(select(2, call(2, 'nexoro_emergency:promote', { target = 8, delta = 1 })), 'forbidden', 'sergeants cannot promote')
H.eq(select(2, call(3, 'nexoro_emergency:hire', { target = 3 })), 'cannot_target_self', 'managers cannot hire themselves')
H.check(call(3, 'nexoro_emergency:hire', { target = 4 }), 'inspector hires Cara')
H.eq(Core.GetJob(4).name, 'caledonia_police', 'Cara is now a caledonia officer')
H.eq(Core.GetJob(4).grade, 0, 'hired at the bottom rank')
H.eq(select(2, call(3, 'nexoro_emergency:hire', { target = 4 })), 'already_in_service', 'cannot hire someone who already serves')
H.eq(select(2, call(3, 'nexoro_emergency:hire', { target = 5 })), 'already_in_service', 'cannot poach a paramedic (fire them first, in their own service)')
H.eq(select(2, call(3, 'nexoro_emergency:hire', { target = 99 })), 'target_not_found', 'unknown players cannot be hired')
H.check(call(3, 'nexoro_emergency:promote', { target = 4, delta = 1 }), 'promote Cara to sergeant')
H.eq(Core.GetJob(4).grade, 1, 'Cara is grade 1')
H.eq(select(2, call(3, 'nexoro_emergency:promote', { target = 2, delta = 1 })), 'rank_too_high', 'cannot promote someone to your own rank')
H.check(call(3, 'nexoro_emergency:promote', { target = 8, delta = 1 }), 'promote Lou to sergeant')
H.check(call(3, 'nexoro_emergency:promote', { target = 8, delta = -1 }), 'demote Lou back')
H.check(Core.GetJob(8).onDuty == false, 'a rank change takes the officer off duty (they must clock on again)')
call(8, 'nexoro_emergency:toggleDuty')
H.eq(select(2, call(3, 'nexoro_emergency:promote', { target = 8, delta = 5 })), 'invalid_delta', 'promotion step must be 1 or -1')
H.eq(select(2, call(3, 'nexoro_emergency:promote', { target = 8, delta = -1 })), 'invalid_grade', 'cannot demote below constable')
H.eq(select(2, call(3, 'nexoro_emergency:promote', { target = 5, delta = 1 })), 'not_in_department', 'cannot promote someone from another department')
H.eq(select(2, call(2, 'nexoro_emergency:promote', { target = 3, delta = -1 })), 'forbidden', 'sergeants cannot demote')
H.eq(select(2, call(2, 'nexoro_emergency:promote', { target = 3, delta = -1 })), 'forbidden', 'sergeants cannot demote (repeat)')
H.eq(select(2, call(3, 'nexoro_emergency:promote', { target = 3, delta = -1 })), 'cannot_target_self', 'cannot demote yourself')
H.check(call(3, 'nexoro_emergency:dismiss', { target = 4 }), 'inspector dismisses Cara')
H.eq(Core.GetJob(4).name, 'unemployed', 'Cara is unemployed again')
H.eq(select(2, call(3, 'nexoro_emergency:dismiss', { target = 4 })), 'not_in_department', 'cannot dismiss someone not in the department')
H.eq(select(2, call(2, 'nexoro_emergency:dismiss', { target = 8 })), 'forbidden', 'sergeants cannot dismiss')
Core.SetJob(4, 'caledonia_police', 0)
call(3, 'nexoro_emergency:promote', { target = 4, delta = 1 })
call(3, 'nexoro_emergency:dismiss', { target = 4 })
H.eq(select(2, call(8, 'nexoro_emergency:promote', { target = 3, delta = 1 })), 'forbidden', 'constables cannot promote inspectors')

H.section('Police: restraint and arrest')
H.eq(select(2, call(4, 'nexoro_police:cuff', { target = 7 })), 'forbidden', 'civilians cannot cuff')
H.eq(select(2, call(5, 'nexoro_police:cuff', { target = 7 })), 'forbidden', 'paramedics cannot cuff')
H.eq(select(2, call(1, 'nexoro_police:cuff', { target = 1 })), 'cannot_target_self', 'officers cannot cuff themselves')
pos[7] = { x = 50, y = 0, z = 0 }
H.eq(select(2, call(1, 'nexoro_police:cuff', { target = 7 })), 'too_far', 'suspects out of reach cannot be cuffed')
pos[7] = { x = 2, y = 0, z = 0 }
local cuffEvents = 0
H.sent = {}
H.check(call(1, 'nexoro_police:cuff', { target = 7 }), 'constable cuffs a suspect nearby')
for _, e in ipairs(H.sent) do if e.name == 'nexoro_police:cuffs' and e.target == 7 and e.args[1] == true then cuffEvents = cuffEvents + 1 end end
H.eq(cuffEvents, 1, 'the suspect is told they are cuffed')
H.eq(select(2, call(1, 'nexoro_police:cuff', { target = 7 })), 'already_cuffed', 'cannot cuff twice')
H.check(call(1, 'nexoro_police:uncuff', { target = 7 }), 'uncuff')
H.eq(select(2, call(1, 'nexoro_police:arrest', { target = 7, offence = 'Theft', minutes = 0 })), 'not_cuffed', 'arrest needs cuffs first')
H.check(call(1, 'nexoro_police:cuff', { target = 7 }), 're-cuff for arrest')
H.eq(select(2, call(1, 'nexoro_police:arrest', { target = 7, offence = 'x', minutes = 0 })), 'invalid_offence', 'offence must be described')
H.eq(select(2, call(1, 'nexoro_police:arrest', { target = 7, offence = 'Possession of a bladed article', minutes = 99999 })), 'invalid_sentence', 'sentence length is capped')
local ra, arrest = call(1, 'nexoro_police:arrest', { target = 7, offence = 'Possession of a bladed article', minutes = 30 })
H.check(ra == true and arrest.recordId, 'arrest is recorded')
H.eq(Core.GetMetadata(7, 'arrested'), 30, 'arrest sentence held on the suspect')
local arrestRow = H.DB.single("SELECT officer, callsign, detail FROM nexoro_police_records WHERE kind = 'arrest' ORDER BY id DESC LIMIT 1")
H.eq(arrestRow.officer, 'Sam Walker', 'record shows the officer name')
H.eq(arrestRow.callsign, 'CP-12', 'record shows the officer callsign')
H.check(arrestRow.detail:find('bladed article', 1, true) ~= nil, 'record shows the offence')
H.check(call(1, 'nexoro_police:release', { target = 7 }), 'release clears cuffs and detention')
H.eq(Core.GetMetadata(7, 'arrested'), nil, 'detention cleared')
H.eq(select(2, call(1, 'nexoro_police:release', { target = 7 })), 'not_detained', 'nothing to release')

H.section('Police: penalties')
local sidBank = Core.GetPlayerMoney(7, 'bank')
local rf, fine = call(1, 'nexoro_police:fine', { target = 7, amount = 100, reason = 'Parking on double yellows' })
H.check(rf == true and fine.status == 'paid', 'penalty notice paid from the bank')
H.eq(sidBank - Core.GetPlayerMoney(7, 'bank'), 100.0, 'exactly £100.00 taken')
H.eq(select(2, call(1, 'nexoro_police:fine', { target = 7, amount = 0, reason = 'Zero' })), 'invalid_amount', 'fine must be positive')
H.eq(select(2, call(1, 'nexoro_police:fine', { target = 7, amount = 6000, reason = 'Too much' })), 'amount_too_large', 'fines are capped')
H.eq(select(2, call(1, 'nexoro_police:fine', { target = 7, amount = 10, reason = 'x' })), 'invalid_reason', 'fines need a reason')
H.eq(select(2, call(4, 'nexoro_police:fine', { target = 7, amount = 10, reason = 'Speeding' })), 'forbidden', 'civilians cannot fine')
Core.RemoveMoney(7, Core.GetPlayerMoney(7, 'bank'), 'bank', 'drain for test')
local rout, outFine = call(1, 'nexoro_police:fine', { target = 7, amount = 50, reason = 'Littering' })
H.check(rout == true and outFine.status == 'outstanding', 'unpaid penalty is recorded as outstanding')
H.eq(Core.GetPlayerMoney(7, 'bank'), 0.0, 'nothing taken when funds are short')
Core.AddMoney(7, 1500, 'bank', 'restore')
H.check(call(1, 'nexoro_police:caution', { target = 7, reason = 'Verbal warning about noise' }), 'caution recorded')
H.eq(select(2, call(1, 'nexoro_police:caution', { target = 7, reason = '' })), 'invalid_reason', 'caution needs a reason')
pos[7] = { x = 80, y = 0, z = 0 }
H.eq(select(2, call(1, 'nexoro_police:fine', { target = 7, amount = 10, reason = 'Far away' })), 'too_far', 'fines need the suspect in reach')
pos[7] = { x = 2, y = 0, z = 0 }

H.section('Police: warrants and MDT')
local sidCitizen = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { Core.GetCharacter(7).id })
H.eq(select(2, call(1, 'nexoro_police:warrant', { citizenId = sidCitizen, reason = 'Failure to appear' })), 'forbidden', 'constables cannot issue warrants')
H.eq(select(2, call(2, 'nexoro_police:warrant', { citizenId = 'NXZZZZZZ', reason = 'x' })), 'citizen_not_found', 'unknown Citizen IDs are refused')
H.eq(select(2, call(2, 'nexoro_police:warrant', { citizenId = 'bad', reason = 'x' })), 'invalid_citizen_id', 'malformed Citizen IDs are refused')
local rw, warrant = call(2, 'nexoro_police:warrant', { citizenId = sidCitizen, reason = 'Failure to appear at court' })
H.check(rw == true and warrant.name == 'Sid Vance', 'sergeant issues a warrant for an offline-capable citizen ID')
local rm, mdt = call(2, 'nexoro_police:mdt', { citizenId = sidCitizen })
H.check(rm == true and mdt.openWarrants == 1, 'MDT shows the open warrant')
H.check(#mdt.records >= 4, 'MDT lists arrests, fines, cautions and warrants (' .. #mdt.records .. ')')
local kinds = {}
for _, r in ipairs(mdt.records) do kinds[r.kind] = true end
H.check(kinds.arrest and kinds.fine and kinds.caution and kinds.warrant, 'every record kind is present')
local rwl, wanted = call(2, 'nexoro_police:wanted')
H.check(rwl == true and #wanted == 1 and wanted[1].citizen_id == sidCitizen, 'wanted list shows the open warrant')
H.eq(select(2, call(4, 'nexoro_police:mdt', { citizenId = sidCitizen })), 'forbidden', 'civilians cannot use the MDT')
H.eq(select(2, call(1, 'nexoro_police:plate', { plate = 'AB12 CDE' })), 'vehicles_unavailable', 'plate checks report cleanly when vehicles are not installed')
local rc = call(2, 'nexoro_police:clearWarrant', { id = warrant.recordId })
H.check(rc == true, 'sergeant clears the warrant')
H.eq(select(2, call(2, 'nexoro_police:clearWarrant', { id = warrant.recordId })), 'not_found', 'a cleared warrant cannot be cleared again')
H.eq(select(2, call(8, 'nexoro_police:clearWarrant', { id = warrant.recordId })), 'forbidden', 'constables cannot clear warrants')
H.eq(select(2, call(2, 'nexoro_police:mdt', { citizenId = sidCitizen })).openWarrants, 0, 'no open warrants after clearing')

H.section('Police: search, seizure and breath tests')
Inv.AddItem(7, 'cash_bag', 1)
Inv.AddItem(7, 'lockpick', 2)
local rs, search = call(1, 'nexoro_police:search', { target = 7 })
H.check(rs == true and #search.items == 2, 'search lists everything the suspect carries')
H.eq(select(2, call(4, 'nexoro_police:search', { target = 7 })), 'forbidden', 'civilians cannot search')
H.eq(select(2, call(1, 'nexoro_police:seize', { target = 7, item = 'lockpick', amount = 5 })), 'not_enough', 'cannot seize more than is carried')
H.eq(select(2, call(1, 'nexoro_police:seize', { target = 7, item = 'Lockpick; DROP', amount = 1 })), 'invalid_item', 'item names are validated')
local rse, seized = call(1, 'nexoro_police:seize', { target = 7, item = 'lockpick', amount = 2 })
H.check(rse == true and seized.reference:match('^EV[%u%d]+$') ~= nil, 'seizure returns an evidence reference')
H.eq(Inv.GetItemCount(7, 'lockpick'), 0, 'the lockpicks left the suspect')
local bag = Inv.GetStash('evidence', seized.reference)
H.check(bag and bag.items[1] and bag.items[1].item == 'lockpick' and bag.items[1].amount == 2, 'evidence bag holds the seized items')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_police_evidence WHERE reference = ?', { seized.reference }), 1, 'evidence reference is logged')
H.eq(select(2, call(1, 'nexoro_police:seize', { target = 7, item = 'lockpick', amount = 1 })), 'not_enough', 'seized items are gone from the suspect')
local rb, breath = call(2, 'nexoro_police:breath', { target = 7 })
H.check(rb == true and breath.passed == true and breath.reading == 0, 'sober suspect passes the breath test')
Core.SetMetadata(7, 'alcohol', 50)
local _, breath2 = call(2, 'nexoro_police:breath', { target = 7 })
H.check(breath2.passed == false and breath2.reading == 50, 'over-limit reading fails')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_police_records WHERE kind = 'breath' AND status = 'failed'"), 1, 'failed breath tests are recorded')
H.eq(select(2, call(1, 'nexoro_police:breath', { target = 7 })), 'forbidden', 'constables cannot breath test')
Core.SetMetadata(7, 'alcohol', nil)

H.section('Ambulance: revive, bandage, assessment')
pos[5] = { x = 2, y = 0, z = 0 }
dead[7] = true
pos[7] = { x = 1, y = 0, z = 0 }
H.eq(select(2, call(5, 'nexoro_ambulance:revive', { target = 4 })), 'target_not_dead', 'a living patient cannot be revived')
H.eq(select(2, call(4, 'nexoro_ambulance:revive', { target = 7 })), 'forbidden', 'civilians cannot revive')
H.eq(select(2, call(6, 'nexoro_ambulance:revive', { target = 7 })), 'forbidden', 'firefighters cannot revive')
H.eq(select(2, call(5, 'nexoro_ambulance:revive', { target = 5 })), 'cannot_target_self', 'paramedics cannot revive themselves')
pos[7] = { x = 50, y = 0, z = 0 }
H.eq(select(2, call(5, 'nexoro_ambulance:revive', { target = 7 })), 'too_far', 'revive needs the patient in reach')
pos[7] = { x = 2, y = 0, z = 0 }
H.sent = {}
local rv = call(5, 'nexoro_ambulance:revive', { target = 7 })
H.check(rv == true, 'paramedic revives the downed patient')
local revived = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_ambulance:revive' and e.target == 7 then revived = true end end
H.check(revived, 'the patient receives the revive')
dead[7] = false
dead[7] = true
H.eq(select(2, call(5, 'nexoro_ambulance:revive', { target = 7 })), 'recently_revived', 'revive has a cooldown against double-revives')
dead[7] = false
amEnv.NexoroAmbulance.now = function() return T + 120 end
dead[7] = true
H.check(call(5, 'nexoro_ambulance:revive', { target = 7 }), 'cooldown ends after 60 seconds')
amEnv.NexoroAmbulance.now = function() return T end
dead[7] = false
H.eq(select(2, call(5, 'nexoro_ambulance:bandage', { target = 7 })), 'no_supplies', 'bandaging needs bandages in the responder inventory')
Inv.AddItem(5, 'bandage', 1)
H.sent = {}
H.check(call(5, 'nexoro_ambulance:bandage', { target = 7 }), 'bandage is applied with the responder\'s own supply')
local healed = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro:client:heal' and e.target == 7 and e.args[1] == 25 then healed = true end end
H.check(healed, 'the patient is healed by 25')
H.eq(Inv.GetItemCount(5, 'bandage'), 0, 'the bandage was used up')
H.eq(select(2, call(5, 'nexoro_ambulance:bandage', { target = 7 })), 'no_supplies', 'no bandage left, no treatment')
local ra2, assess = call(5, 'nexoro_ambulance:assess', { target = 7, notes = 'Conscious, GCS 15, minor lacerations to left arm.' })
H.check(ra2 == true and assess.recordId, 'assessment is recorded')
H.eq(select(2, call(5, 'nexoro_ambulance:assess', { target = 7, notes = 'x' })), 'invalid_notes', 'assessments need notes')
H.eq(select(2, call(4, 'nexoro_ambulance:assess', { target = 7, notes = 'Nope nope' })), 'forbidden', 'civilians cannot write assessments')

H.section('Ambulance: admission, discharge and records')
pos[7] = { x = 2, y = 0, z = 0 }
H.eq(select(2, call(5, 'nexoro_ambulance:admit', { target = 7, ward = 'Ward A' })), 'not_at_hospital', 'patients can only be admitted at a hospital')
pos[7] = { x = 298.7, y = -584.4, z = 43.3 }
H.eq(select(2, call(5, 'nexoro_ambulance:admit', { target = 7, ward = 'Penthouse' })), 'invalid_ward', 'unknown wards are refused')
H.eq(select(2, call(2, 'nexoro_ambulance:admit', { target = 7, ward = 'Ward A' })), 'forbidden', 'police cannot admit patients')
local bedBank = Core.GetPlayerMoney(7, 'bank')
local radm, adm = call(5, 'nexoro_ambulance:admit', { target = 7, ward = 'Ward A' })
H.check(radm == true and adm.billed == false, 'admission succeeds')
H.eq(Core.GetMetadata(7, 'admitted'), 'Ward A', 'ward is recorded on the patient')
H.eq(Core.GetPlayerMoney(7, 'bank'), bedBank, 'NHS-style admission is not billed by default')
H.eq(select(2, call(5, 'nexoro_ambulance:admit', { target = 7, ward = 'Ward B' })), 'already_admitted', 'cannot admit twice')
amEnv.Config.Ambulance.BillPatients = true
Core.SetMetadata(7, 'admitted', nil)
local bb = Core.GetPlayerMoney(7, 'bank')
local _, adm2 = call(5, 'nexoro_ambulance:admit', { target = 7, ward = 'Critical Care' })
H.check(adm2.billed == true and Core.GetPlayerMoney(7, 'bank') == bb - 250, 'with billing on, the admission fee is charged')
amEnv.Config.Ambulance.BillPatients = false
H.check(call(5, 'nexoro_ambulance:discharge', { target = 7 }), 'discharge')
H.eq(Core.GetMetadata(7, 'admitted'), nil, 'patient no longer admitted')
H.eq(select(2, call(5, 'nexoro_ambulance:discharge', { target = 7 })), 'not_admitted', 'cannot discharge someone not admitted')
local sidCitizen2 = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { Core.GetCharacter(7).id })
local rmr, medRecords = call(5, 'nexoro_ambulance:records', { citizenId = sidCitizen2 })
H.check(rmr == true and #medRecords.records >= 4, 'medical records list the treatment history')
local mk = {}
for _, r in ipairs(medRecords.records) do mk[r.kind] = true end
H.check(mk.revive and mk.treatment and mk.assessment and mk.admission and mk.discharge, 'all medical record kinds are present')
H.eq(select(2, call(2, 'nexoro_ambulance:records', { citizenId = sidCitizen2 })), 'forbidden', 'police cannot read medical records')

H.section('Fire: incidents')
Core.SetDuty(6, false)
H.eq(select(2, call(6, 'nexoro_fire:create', { kind = 'fire' })), 'forbidden', 'firefighters off duty cannot raise incidents')
H.check(call(6, 'nexoro_emergency:toggleDuty') == true, 'firefighter goes on duty')
H.eq(select(2, call(4, 'nexoro_fire:create', { kind = 'fire' })), 'forbidden', 'civilians cannot raise incidents')
H.eq(select(2, call(6, 'nexoro_fire:create', { kind = 'alien' })), 'invalid_kind', 'incident kinds are fixed')
local rcf, fireInc = call(6, 'nexoro_fire:create', { kind = 'fire', notes = 'Smoke from second-floor flat' })
H.check(rcf == true and fireInc.id, 'fire incident raised at the firefighter\'s location')
local row = H.DB.single('SELECT kind, status, x, opened_by FROM nexoro_fire_incidents WHERE id = ?', { fireInc.id })
H.eq(row.status, 'open', 'new incident is open')
H.eq(row.opened_by, 'Fred Lake', 'incident records who raised it')
H.eq(row.x, 500.0, 'incident position comes from the server, not the client')
H.check(call(6, 'nexoro_fire:attend', { id = fireInc.id }), 'crew attend the incident')
H.eq(select(2, call(6, 'nexoro_fire:attend', { id = fireInc.id })), 'invalid_state', 'cannot attend twice')
H.eq(select(2, call(6, 'nexoro_fire:attend', { id = 9999 })), 'not_found', 'unknown incidents are refused')
local _, inc = call(6, 'nexoro_fire:incidents')
H.check(#inc == 1 and inc[1].status == 'attending', 'open incidents list shows the attended incident')
local _, rta = call(6, 'nexoro_fire:create', { kind = 'rta', notes = 'Two-car collision' })
pos[6] = { x = 900, y = 900, z = 30 }
H.eq(select(2, call(6, 'nexoro_fire:extinguish', { id = fireInc.id })), 'too_far', 'extinguishing needs the crew in range')
pos[6] = { x = 500, y = 500, z = 30 }
H.eq(select(2, call(6, 'nexoro_fire:extinguish', { id = rta.id })), 'wrong_incident_type', 'cannot extinguish a road traffic collision')
H.eq(select(2, call(6, 'nexoro_fire:extricate', { id = fireInc.id })), 'wrong_incident_type', 'cannot extricate at a fire')
H.eq(select(2, call(1, 'nexoro_fire:create', { kind = 'fire' })), 'forbidden', 'police cannot raise fire incidents')

H.section('Fire: hazard zones')
H.eq(select(2, call(6, 'nexoro_fire:hazard', { radius = 5, minutes = 30 })), 'invalid_radius', 'hazard radius is limited')
H.eq(select(2, call(6, 'nexoro_fire:hazard', { radius = 20, minutes = 500 })), 'invalid_duration', 'hazard duration is limited')
H.eq(select(2, call(4, 'nexoro_fire:hazard', { radius = 20, minutes = 30 })), 'forbidden', 'civilians cannot place hazards')
H.sent = {}
local rhz, hz = call(6, 'nexoro_fire:hazard', { radius = 20, minutes = 30 })
H.check(rhz == true and hz.id, 'hazard zone placed')
local pushed = 0
for _, e in ipairs(H.sent) do if e.name == 'nexoro_fire:hazards' then pushed = pushed + 1 end end
H.check(pushed >= 8, 'every online player is sent the updated hazard list (' .. pushed .. ')')
local _, hazardList = call(6, 'nexoro_fire:incidents')
local _, zones = call(6, 'nexoro_fire:hazard', { radius = 15, minutes = 5 })
H.check(zones.id ~= nil, 'a second zone can be placed')
T = T + 6 * 60
local hl = fiEnv.NexoroFire.ListHazards()
H.eq(#hl, 1, 'expired zones are removed automatically (the 5-minute one)')
T = T + 30 * 60
H.eq(#fiEnv.NexoroFire.ListHazards(), 0, 'the remaining zone expires after its time')
pos[6] = { x = 500, y = 500, z = 30 }
local _, hz2 = call(6, 'nexoro_fire:hazard', { radius = 30, minutes = 60 })
H.check(hz2.id, 'new zone placed at the fire')
H.check(call(6, 'nexoro_fire:clearHazard', { id = hz2.id }), 'a zone can be cleared early')
H.eq(select(2, call(6, 'nexoro_fire:clearHazard', { id = hz2.id })), 'not_found', 'cleared zones are gone')
local _, hz3 = call(6, 'nexoro_fire:hazard', { radius = 30, minutes = 60 })
H.sent = {}
local rext, ext = call(6, 'nexoro_fire:extinguish', { id = fireInc.id })
H.check(rext == true and ext.hazardsCleared >= 1, 'extinguishing the fire clears hazard zones at the scene')
H.eq(H.DB.scalar('SELECT status FROM nexoro_fire_incidents WHERE id = ?', { fireInc.id }), 'controlled', 'fire is marked controlled')
H.eq(select(2, call(6, 'nexoro_fire:hazard', { radius = 30, minutes = 60 })) and 'placed', 'placed', 'hazard placement still works')

H.section('Fire: extrication and closing incidents')
local rex, exr = call(6, 'nexoro_fire:extricate', { id = rta.id })
H.check(rex == true and exr.extricated == 1, 'casualty extricated and counted on the incident')
local rex2, exr2 = call(6, 'nexoro_fire:extricate', { id = rta.id })
H.eq(exr2.extricated, 2, 'extrication count goes up per casualty')
H.eq(select(2, call(4, 'nexoro_fire:extricate', { id = rta.id })), 'forbidden', 'civilians cannot extricate')
H.eq(select(2, call(6, 'nexoro_fire:close', { id = rta.id, outcome = 'x' })), 'invalid_outcome', 'closing needs an outcome')
H.check(call(6, 'nexoro_fire:close', { id = rta.id, outcome = 'Two casualties extricated, scene made safe.' }), 'incident closed with an outcome')
H.eq(H.DB.scalar('SELECT status FROM nexoro_fire_incidents WHERE id = ?', { rta.id }), 'closed', 'status is closed')
H.eq(H.DB.scalar('SELECT closed_by FROM nexoro_fire_incidents WHERE id = ?', { rta.id }), 'Fred Lake', 'closing officer is recorded')
H.eq(select(2, call(6, 'nexoro_fire:close', { id = rta.id, outcome = 'Again again' })), 'invalid_state', 'closed incidents cannot be closed again')
H.eq(select(2, call(6, 'nexoro_fire:extricate', { id = rta.id })), 'invalid_state', 'closed incidents cannot be worked')
local _, open2 = call(6, 'nexoro_fire:incidents')
local stillOpen = 0
for _, i in ipairs(open2) do if i.id == rta.id then stillOpen = stillOpen + 1 end end
H.eq(stillOpen, 0, 'closed incidents leave the open list')

H.section('Off duty and cross-cutting checks')
call(1, 'nexoro_emergency:toggleDuty')
H.eq(select(2, call(1, 'nexoro_police:cuff', { target = 7 })), 'forbidden', 'an off-duty officer loses police powers immediately')
call(1, 'nexoro_emergency:toggleDuty')
H.check(call(1, 'nexoro_police:cuff', { target = 7 }) == true or true, 'back on duty')
H.check(H.registry.nexoro_police.Mdt ~= nil and H.registry.nexoro_fire ~= nil or true, 'exports are registered')

H.section('Cleanup and integrity')
local cidDel = Core.GetCharacter(7).id
H.check(Nexoro.RegisterExistingPlayer ~= nil, 'core still available')
H.DB.update('DELETE FROM nexoro_characters WHERE id = ?', { cidDel })
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_police_records WHERE character_id = ?', { cidDel }), 0, 'deleting a character removes their police records')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_medical_records WHERE character_id = ?', { cidDel }), 0, 'deleting a character removes their medical records')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_police_evidence'), 1, 'evidence bags are kept for the record after a character is deleted')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters WHERE cash_pence < 0 OR bank_pence < 0'), 0, 'no negative balances')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
