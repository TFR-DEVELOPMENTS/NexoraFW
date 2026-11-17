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
env('nexoro_emergency', { 'config.lua', 'server/main.lua' })
local enEnv = env('nexoro_encampments', { 'config.lua', 'server/main.lua' })
local scEnv = env('nexoro_scrapping', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
H.check(H.DB.query('SHOW TABLES LIKE ?', { 'nexoro_pitch_warrants' })[1] ~= nil, 'pitch tables exist')

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
local nowFn = function() return NOW end
enEnv.NexoroEncampments.getCoords = getPos
enEnv.NexoroEncampments.now = nowFn
scEnv.NexoroScrapping.getCoords = getPos
scEnv.NexoroScrapping.now = nowFn
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'Gypsy, Roma or Traveller', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
join(1, 'license:sam', 'Sam', 'Walker')
join(3, 'license:pat', 'Pat', 'Moore')
join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
Core.SetJob(1, 'caledonia_police', 1); Core.SetDuty(1, true)
Core.SetJob(3, 'caledonia_police', 0); Core.SetDuty(3, true)
Core.AddMoney(4, 1000, 'bank', 'pitch money')
Core.AddMoney(5, 1000, 'bank', 'pitch money')

local pitch = enEnv.Config.Encampments.Pitches[1]
local gate = enEnv.Config.Encampments.Gates[1]

H.section('Claiming a pitch')
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_encampments:claim', { pitch = pitch.id })), 'too_far', 'a pitch is claimed on the spot')
at(4, pitch.x, pitch.y, pitch.z)
local b0 = Core.GetPlayerMoney(4, 'bank')
H.check(call(4, 'nexoro_encampments:claim', { pitch = pitch.id }) == true, 'Cara claims the Sandy Shores pitch')
H.eq(b0 - Core.GetPlayerMoney(4, 'bank'), 250.0, 'the claim fee is £250.00')
at(4, 2000.0, 4850.0, 42.0)
H.eq(select(2, call(4, 'nexoro_encampments:claim', { pitch = 'grape_1' })), 'already_claimed', 'one pitch per person')
at(5, pitch.x, pitch.y, pitch.z)
H.eq(select(2, call(5, 'nexoro_encampments:claim', { pitch = pitch.id })), 'pitch_taken', 'a claimed pitch cannot be claimed again')
H.eq(select(2, call(4, 'nexoro_encampments:claim', { pitch = 'nope' })), 'unknown_pitch', 'unknown pitches are refused')

H.section('Notices and warrants')
local notice = call(5, 'nexoro_encampments:notice', { pitch = pitch.id })
H.eq(select(2, call(5, 'nexoro_encampments:notice', { pitch = pitch.id })), 'not_police', 'only police serve notices')
H.eq(select(2, call(1, 'nexoro_encampments:notice', { pitch = 'grape_1' })), 'not_occupied', 'a notice needs someone living there')
local rn, nd = call(3, 'nexoro_encampments:notice', { pitch = pitch.id })
H.check(rn == true and nd.deadline == NOW + 14 * 86400, 'Pat serves a notice with a 14 day deadline')
H.eq(select(2, call(1, 'nexoro_encampments:warrant', { pitch = pitch.id, reason = 'Notice not complied with' })), 'no_expired_notice', 'no warrant before the deadline')
H.eq(select(2, call(3, 'nexoro_encampments:warrant', { pitch = pitch.id, reason = 'Notice not complied with' })), 'not_authorised', 'a constable cannot issue a warrant')
NOW = NOW + 15 * 86400
H.eq(select(2, call(1, 'nexoro_encampments:warrant', { pitch = pitch.id, reason = 'x' })), 'invalid_reason', 'warrants need a real reason')
H.check(call(1, 'nexoro_encampments:warrant', { pitch = pitch.id, reason = 'Notice not complied with' }) == true, 'after the deadline a sergeant issues a warrant')
H.check(enEnv.NexoroEncampments.HasWarrant(pitch.id), 'the warrant is live')

H.section('Gates')
at(4, gate.x, gate.y, gate.z)
local rg1, g1 = call(4, 'nexoro_encampments:gate', { gate = gate.id })
H.check(rg1 == true and g1.open == true, 'the occupant opens their gate')
at(5, gate.x, gate.y, gate.z)
H.eq(select(2, call(5, 'nexoro_encampments:gate', { gate = gate.id })), 'no_access', 'someone else cannot open the gate')
at(1, gate.x, gate.y, gate.z)
local rg2, g2 = call(1, 'nexoro_encampments:gate', { gate = gate.id })
H.check(rg2 == true and g2.open == false, 'police with a warrant close the gate')
at(3, gate.x, gate.y, gate.z)
H.check(call(3, 'nexoro_encampments:gate', { gate = gate.id }) == true, 'an officer on duty can act under the warrant')
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_encampments:gate', { gate = gate.id })), 'too_far', 'the gate must be reached on foot')
NOW = NOW + 25 * 3600
at(1, gate.x, gate.y, gate.z)
H.eq(select(2, call(1, 'nexoro_encampments:gate', { gate = gate.id })), 'no_access', 'the warrant expires after 24 hours')
at(4, gate.x, gate.y, gate.z)
H.check(call(4, 'nexoro_encampments:gate', { gate = gate.id }) == true, 'the occupant still controls their own gate')

H.section('Leaving the pitch')
H.check(call(4, 'nexoro_encampments:vacate') == true, 'Cara vacates the pitch')
H.eq(select(2, call(4, 'nexoro_encampments:vacate')), 'no_pitch', 'nothing left to vacate')
at(5, pitch.x, pitch.y, pitch.z)
H.check(call(5, 'nexoro_encampments:claim', { pitch = pitch.id }) == true, 'the pitch can be claimed by someone new')

H.section('Scrap collector')
local point = scEnv.Config.Scrapping.Points[1]
scEnv.NexoroScrapping.random = function(lo) return lo end
at(5, point.x, point.y, point.z)
H.eq(select(2, call(5, 'nexoro_scrapping:collect', { point = point.id })), 'not_on_shift', 'you need to be on shift')
Core.SetJob(5, 'scrapper', 0)
H.check(call(5, 'nexoro_scrapping:duty') == true, 'Olly starts his shift as a collector')
H.eq(select(2, call(5, 'nexoro_scrapping:collect', { point = 'nowhere' })), 'unknown_point', 'unknown points are refused')
at(5, 0, 0, 0)
H.eq(select(2, call(5, 'nexoro_scrapping:collect', { point = point.id })), 'too_far', 'you collect at the point')
at(5, point.x, point.y, point.z)
local scrap0 = Inv.GetItemCount(5, 'scrap')
local rs, got = call(5, 'nexoro_scrapping:collect', { point = point.id })
H.check(rs == true and got.amount == 2, 'a load of scrap is collected')
H.eq(Inv.GetItemCount(5, 'scrap') - scrap0, 2, 'the scrap is in the inventory')
H.eq(select(2, call(5, 'nexoro_scrapping:collect', { point = point.id })), 'cooldown', 'a point rests between loads')
NOW = NOW + 601
H.check(call(5, 'nexoro_scrapping:collect', { point = point.id }) == true, 'after ten minutes the point is ready again')
H.check(call(5, 'nexoro_scrapping:duty') == true, 'Olly finishes his shift')
H.eq(select(2, call(5, 'nexoro_scrapping:collect', { point = point.id })), 'not_on_shift', 'nothing collected off shift')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
