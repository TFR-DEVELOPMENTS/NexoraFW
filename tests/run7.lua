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
local emEnv = env('nexoro_emergency', { 'config.lua', 'server/main.lua' })
local amEnv = env('nexoro_ambulance', { 'config.lua', 'server/main.lua' })
local deEnv = env('nexoro_death', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply on a fresh database', err)
H.check(H.DB.query('SHOW TABLES LIKE ?', { 'nexoro_staff_assignments' })[1] ~= nil, 'staff assignment table exists')

---------------------------------------------------------------- First owner
H.section('First player becomes owner')
Nexoro.LoadJobs()
H.addPlayerStub(1, 'FirstPlayer', { 'license:first' })
local p1 = Nexoro.RegisterExistingPlayer(1)
H.eq(p1.staffRank, 'owner', 'the first account to join is made owner automatically')
H.eq(H.DB.scalar("SELECT assigned_by FROM nexoro_staff_assignments WHERE player_id = ?", { p1.playerId }), 'first-join', 'recorded as a first-join assignment')
H.addPlayerStub(2, 'SecondPlayer', { 'license:second' })
local p2 = Nexoro.RegisterExistingPlayer(2)
H.check(p2.staffRank == nil, 'a later joiner is not given owner')
H.addPlayerStub(3, 'ThirdPlayer', { 'license:third' })
Nexoro.RegisterExistingPlayer(3)
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_staff_assignments'), 1, 'exactly one owner is ever created by the first-join rule')
H.check(Nexoro.Permissions.Has(1, 'nexoro.admin.economy'), 'the first owner has every admin permission')
H.check(not Nexoro.Permissions.Has(2, 'nexoro.admin.economy'), 'other players do not')
H.check(Nexoro.ClaimFirstOwner(p2) == false, 'claiming again does nothing')

---------------------------------------------------------------- Characters and death
H.section('Death: bleed-out timing')
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, first, last)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first .. ' ' .. tostring(d and d.message or d))
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
local cid1 = join(1, 'Olivia', 'Hart')
local cid2 = join(2, 'Mo', 'Khan')
local cid3 = join(3, 'Pat', 'Moore')
Core.SetJob(2, 'metro_ambulance', 1)
local T = os.time()
local dead, pos = {}, {}
deEnv.NexoroDeath.isDead = function(s) return dead[s] == true end
deEnv.NexoroDeath.now = function() return T end
amEnv.NexoroAmbulance.isDead = function(s) return dead[s] == true end
amEnv.NexoroAmbulance.now = function() return T end
amEnv.NexoroAmbulance.getCoords = function(s) return pos[s] end
pos[1], pos[2] = { x = 0, y = 0, z = 0 }, { x = 1, y = 0, z = 0 }
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
H.check(call(2, 'nexoro_emergency:toggleDuty'), 'paramedic clocks on')
H.check(Core.GetJob(2).onDuty == true, 'paramedic is on duty')

H.eq(select(2, call(1, 'nexoro_death:report')), 'not_dead', 'a living player cannot report going down')
dead[1] = true
local rr, report1 = call(1, 'nexoro_death:report')
H.check(rr == true and report1.seconds == 300, 'downed players are recorded with a 300 second bleed-out')
H.eq(report1.startedAt, T, 'the bleed-out starts on the server clock')
local _, report2 = call(1, 'nexoro_death:report')
H.eq(report2.startedAt, T, 'reporting twice does not restart the timer')
T = T + 100
H.eq(select(2, call(1, 'nexoro_death:bleedout')), 'too_early', 'cannot give up at 100 seconds')
T = T + 200
H.check(call(1, 'nexoro_death:bleedout') == true, 'can respawn once 300 seconds have passed')
H.eq(select(2, call(1, 'nexoro_death:bleedout')), 'not_downed', 'a second respawn with no bleed-out is refused')
H.check(deEnv.NexoroDeath.IsDowned(1) == false, 'state is cleared after respawn')

H.section('Death: clothes and character are kept')
dead[1] = true
call(1, 'nexoro_death:report')
H.check(Core.GetCharacter(1) and Core.GetCharacter(1).id == cid1, 'the same character is still loaded while down')
H.check(H.DB.scalar('SELECT COUNT(*) FROM nexoro_character_appearance WHERE character_id = ?', { cid1 }) == 1, 'appearance and clothing are still stored')
H.eq(select(2, call(1, 'nexoro_death:bleedout')), 'too_early', 'bleed-out is measured from the moment of going down')
T = T + 400
dead[1] = false
H.eq(select(2, call(1, 'nexoro_death:bleedout')), 'not_dead', 'a player revived in the meantime cannot respawn from the timer')
dead[1] = true
H.check(call(1, 'nexoro_death:report') == true, 'report again for a new downing')

H.section('Death: emergency revive ends the bleed-out')
pos[2] = { x = 1, y = 0, z = 0 }
H.check(call(2, 'nexoro_ambulance:revive', { target = 1 }) == true, 'a paramedic revives the downed player')
H.check(deEnv.NexoroDeath.IsDowned(1) == false, 'revive clears the downed state on the server')
dead[1] = false
H.eq(select(2, call(1, 'nexoro_death:bleedout')), 'not_downed', 'a revived player cannot use the bleed-out path afterwards')
H.eq(H.DB.scalar("SELECT COUNT(*) FROM nexoro_medical_records WHERE character_id = ? AND kind = 'revive'", { cid1 }), 1, 'the revive is recorded in the medical record')

H.section('Death: configuration')
H.eq(deEnv.Config.Death.BleedOutSeconds, 300, 'bleed-out is 300 seconds')
H.check(#deEnv.Config.Death.Hospitals >= 1, 'at least one hospital to respawn at')
H.check(select(2, call(3, 'nexoro_death:report')) ~= nil, 'report endpoint answers for everyone with a character')

H.section('Identity: traveller option')
local found = false
for _, n in ipairs(H.registry.nexoro_identity.GetOptions().nationalities) do if n == 'Gypsy, Roma or Traveller' then found = true end end
H.check(found, 'the character creator offers Gypsy, Roma or Traveller')
H.check(H.registry.nexoro_identity.GetOptions().nationalities[#H.registry.nexoro_identity.GetOptions().nationalities] == 'Other', 'Other stays the last option')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
