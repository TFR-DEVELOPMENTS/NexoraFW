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
env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
local liEnv = env('nexoro_licences', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local L = liEnv.NexoroLicences
local pos = {}
L.getCoords = function(s) return pos[s] end
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
local cid = join(4, 'license:cara', 'Cara', 'Lane')
Core.AddMoney(4, 1000, 'bank', 'licence money')
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local office = liEnv.Config.Licences.Office

H.section('Firearms licence')
H.eq(liEnv.Config.Licences.Weapon.feePounds, 500.0, 'the firearms licence costs £500.00')
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_licences:buyWeapon')), 'too_far', 'the licence is bought at the council office')
at(4, office.x, office.y, office.z)
local b0 = Core.GetPlayerMoney(4, 'bank')
H.check(call(4, 'nexoro_licences:buyWeapon') == true, 'Cara buys a firearms licence')
H.eq(b0 - Core.GetPlayerMoney(4, 'bank'), 500.0, 'the fee is taken from the bank')
H.check(L.Has(cid, 'weapon'), 'the firearms licence is recorded')
H.eq(select(2, call(4, 'nexoro_licences:buyWeapon')), 'already_licensed', 'one firearms licence is enough')
local _, mine = call(4, 'nexoro_licences:mine')
H.check(mine.weapon == true and mine.hunting == false, 'the licence summary shows the firearms licence only')
H.eq(select(2, L.BuySimple(4, 'nothing')), 'unknown_licence', 'an unknown licence kind is refused')
H.eq(select(2, L.BuySimple(4, 'weapon')), 'unknown_licence', 'the firearms licence cannot be bought around its record check')
local cid2 = join(5, 'license:olly', 'Olly', 'Price')
Core.AddMoney(5, 1000, 'bank', 'licence money')
H.check(H.DB.insert("INSERT INTO nexoro_police_records (character_id, kind, detail, status, amount_pence, officer, callsign) VALUES (?,?,?,?,?,?,?)",
    { cid2, 'arrest', 'Assault', 'closed', 0, 'Sam Walker', 'CP-12' }) ~= nil, 'Olly has an arrest on record')
at(5, office.x, office.y, office.z)
H.eq(select(2, call(5, 'nexoro_licences:buyWeapon')), 'criminal_record', 'someone with an arrest on record cannot buy a firearms licence')
H.check(not L.Has(cid2, 'weapon'), 'and no licence is issued')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
