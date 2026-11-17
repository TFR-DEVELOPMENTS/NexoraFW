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
local liEnv = env('nexoro_licences', { 'config.lua', 'server/main.lua' })
local crEnv = env('nexoro_crews', { 'config.lua', 'server/main.lua' })
local huEnv = env('nexoro_hunting', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
H.check(H.DB.query('SHOW TABLES LIKE ?', { 'nexoro_crew_members' })[1] ~= nil, 'crew tables exist')

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
liEnv.NexoroLicences.getCoords = getPos
huEnv.NexoroHunting.getCoords = getPos
huEnv.NexoroHunting.now = function() return NOW end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
local cidSam = join(1, 'license:sam', 'Sam', 'Walker')
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
local cidOlly = join(5, 'license:olly', 'Olly', 'Price')
join(6, 'license:lou', 'Lou', 'Park')
Core.AddMoney(1, 2000, 'bank', 'crew money')
Core.AddMoney(4, 2000, 'bank', 'licence money')
Core.AddMoney(5, 2000, 'bank', 'licence money')

H.section('Crews: forming')
H.eq(select(2, call(1, 'nexoro_crews:create', { name = 'ab' })), 'invalid_name', 'crew names need three letters or more')
local rc, crew = call(1, 'nexoro_crews:create', { name = 'Harbour Lads' })
H.check(rc == true and crew.name == 'Harbour Lads', 'Sam creates the crew Harbour Lads')
H.eq(select(2, call(1, 'nexoro_crews:create', { name = 'Second Crew' })), 'already_in_crew', 'you can only be in one crew')
H.eq(select(2, call(4, 'nexoro_crews:create', { name = 'harbour lads' })), 'name_taken', 'crew names are not reused')
H.eq(select(2, call(5, 'nexoro_crews:invite', { target = 4 })), 'not_in_crew', 'only crew members can invite')
H.eq(select(2, call(1, 'nexoro_crews:accept')), 'already_in_crew', 'Sam is already in a crew')
H.check(call(1, 'nexoro_crews:invite', { target = 4 }) == true, 'Sam invites Cara')
H.check(call(4, 'nexoro_crews:accept') == true, 'Cara accepts')
H.check(crEnv.NexoroCrews.SameCrew(cidSam, cidCara) == true, 'Cara joins: she and Sam are in the same crew')
H.eq(select(2, call(1, 'nexoro_crews:invite', { target = 4 })), 'target_in_crew', 'an invite to someone already in a crew is refused')
H.eq(select(2, call(4, 'nexoro_crews:accept')), 'already_in_crew', 'nothing left to accept')

H.section('Crews: membership rules')
H.check(call(1, 'nexoro_crews:invite', { target = 5 }) == true, 'Sam invites Olly')
NOW = NOW + 0
crEnv.NexoroCrews.now = function() return os.time() + 61 end
H.eq(select(2, call(5, 'nexoro_crews:accept')), 'no_invite', 'an invite expires after 60 seconds')
crEnv.NexoroCrews.now = os.time
call(1, 'nexoro_crews:invite', { target = 5 })
H.check(call(5, 'nexoro_crews:accept') == true, 'Olly accepts a fresh invite')
H.check(crEnv.NexoroCrews.SameCrew(cidSam, cidOlly), 'Olly is in the crew')
local _, mine = call(4, 'nexoro_crews:mine')
H.check(mine.crew and #mine.crew.members == 3, 'the crew has three members')
H.check(call(4, 'nexoro_crews:leave') == true, 'Cara leaves')
H.check(crEnv.NexoroCrews.SameCrew(cidSam, cidCara) == false, 'Cara is no longer in the crew')
H.eq(select(2, call(1, 'nexoro_crews:leave')), 'leader_must_disband', 'the leader cannot leave, only disband')
H.eq(select(2, call(5, 'nexoro_crews:kick', { characterId = cidCara })), 'not_leader', 'an ordinary member cannot kick')
H.check(call(1, 'nexoro_crews:kick', { characterId = cidOlly }) == true, 'Sam removes Olly')
H.eq(select(2, call(1, 'nexoro_crews:kick', { characterId = cidSam })), 'invalid_request', 'the leader cannot kick themselves')
H.check(call(1, 'nexoro_crews:disband') == true, 'Sam disbands the crew')
H.check(crEnv.NexoroCrews.CrewOf(cidSam) == nil, 'nobody is in a crew after disbanding')

H.section('Hunting licence')
at(5, liEnv.Config.Licences.Office.x, liEnv.Config.Licences.Office.y, liEnv.Config.Licences.Office.z)
local hb = Core.GetPlayerMoney(5, 'bank')
H.check(call(5, 'nexoro_licences:buyHunting') == true, 'Olly buys a hunting licence')
H.eq(hb - Core.GetPlayerMoney(5, 'bank'), 40.0, 'the hunting licence costs £40.00')
H.check(liEnv.NexoroLicences.Has(cidOlly, 'hunting'), 'the hunting licence is recorded')
H.eq(select(2, call(5, 'nexoro_licences:buyHunting')), 'already_licensed', 'one hunting licence is enough')

H.section('Hunting')
local spot = huEnv.Config.Hunting.Spots[1]
huEnv.NexoroHunting.random = function(n) return 1 end
at(4, spot.x, spot.y, spot.z)
H.eq(select(2, call(4, 'nexoro_hunting:hunt', { spot = 'paleto_woods' })), 'no_licence', 'no licence, no hunting')
at(5, spot.x + 500, spot.y, spot.z)
H.eq(select(2, call(5, 'nexoro_hunting:hunt', { spot = 'paleto_woods' })), 'too_far', 'you must be in the woods')
at(5, spot.x, spot.y, spot.z)
H.eq(select(2, call(5, 'nexoro_hunting:hunt', { spot = 'nowhere' })), 'unknown_spot', 'unknown spots are refused')
local rh, cat = call(5, 'nexoro_hunting:hunt', { spot = 'paleto_woods' })
H.check(rh == true and cat.item == 'venison', 'the first roll is venison')
H.eq(Inv.GetItemCount(5, 'venison'), 1, 'the venison is in the inventory')
H.eq(select(2, call(5, 'nexoro_hunting:hunt', { spot = 'paleto_woods' })), 'cooldown', 'a rest is needed between hunts')
NOW = NOW + 46
huEnv.NexoroHunting.random = function(n) return n end
local rn, none = call(5, 'nexoro_hunting:hunt', { spot = 'paleto_woods' })
H.check(rn == true and none.item == nil, 'the top of the table is a empty hunt: nothing caught, still a valid try')
H.eq(Inv.GetItemCount(5, 'venison'), 1, 'and nothing was added')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
