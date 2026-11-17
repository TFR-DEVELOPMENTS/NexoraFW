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
env('nexoro_emergency', { 'config.lua', 'server/main.lua' })   -- registers the caledonia_police job
local sdEnv = env('nexoro_supplydrop', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local S = sdEnv.NexoroSupplyDrop
local cfg = sdEnv.Config.SupplyDrop

local pos = {}
local NOW = os.time()
S.now = function() return NOW end
S.getCoords = function(s) return pos[s] end
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local function sentTo(name, target)
    for _, e in ipairs(H.sent) do if e.name == name and e.target == target then return true end end
    return false
end
local function sentAny(name)
    for _, e in ipairs(H.sent) do if e.name == name then return true end end
    return false
end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end

join(1, 'license:sam', 'Sam', 'Walker')
join(4, 'license:cara', 'Cara', 'Lane')
Core.SetJob(1, 'caledonia_police', 0)
Core.SetDuty(1, true)
Core.AddMoney(1, 0, 'cash', 'noop')

local crate = cfg.Location

H.section('Announcements')
H.sent = {}
local ev = S.Schedule(17, 50)
H.eq(#ev, 0, 'nothing happens before the announcement window')
H.sent = {}
ev = S.Schedule(17, 56)
H.eq(ev[1], 'announce:18:00', 'the 18:00 drop is announced five minutes ahead')
H.check(sentTo('nexoro:notify', -1) and sentAny('nexoro_supplydrop:announce'), 'everyone is told, with the location')
H.sent = {}
ev = S.Schedule(17, 57)
H.eq(#ev, 0, 'the announcement is made once, not on every tick')
H.check(not sentAny('nexoro_supplydrop:announce'), 'no repeat announcement is sent')

H.section('Dropping the crate')
H.sent = {}
ev = S.Schedule(18, 0)
H.eq(ev[1], 'drop:18:00', 'the crate drops at 18:00')
H.check(sentAny('nexoro_supplydrop:spawn'), 'everyone gets the crate on their map')
H.eq(#S.List(), 1, 'one crate exists')
ev = S.Schedule(18, 1)
H.eq(#ev, 0, 'the 18:00 drop does not repeat')
H.eq(#S.List(), 1, 'and there is still one crate')
local crateId = S.List()[1].id

H.section('Claiming the crate')
at(4, crate.x, crate.y, crate.z)
S.random = function(lo) return lo end    -- first loot entry (cash) and the smallest amount
H.eq(select(2, call(4, 'nexoro_supplydrop:claim', { id = crateId })), 'not_team', 'civilians cannot open a police crate')
at(1, 900, 900, 30)
H.eq(select(2, call(1, 'nexoro_supplydrop:claim', { id = crateId })), 'too_far', 'the team member must be at the crate')
at(1, crate.x, crate.y, crate.z)
Core.SetDuty(1, false)
H.eq(select(2, call(1, 'nexoro_supplydrop:claim', { id = crateId })), 'not_team', 'off duty does not count as the team')
Core.SetDuty(1, true)
local cash0 = Core.GetPlayerMoney(1, 'cash')
local rc, got = call(1, 'nexoro_supplydrop:claim', { id = crateId })
H.check(rc == true and got.received == '£500.00', 'a team member opens the crate and takes the smallest cash prize')
H.eq(Core.GetPlayerMoney(1, 'cash') - cash0, 500.0, 'the cash is paid out')
H.eq(#S.List(), 0, 'the crate is gone once opened')
H.eq(select(2, call(1, 'nexoro_supplydrop:claim', { id = crateId })), 'gone', 'a crate can only be opened once')

H.section('Item loot')
ev = S.Schedule(21, 0)
local dropped21 = false
for _, e in ipairs(ev) do if e == 'drop:21:00' then dropped21 = true end end
H.check(dropped21, 'the 21:00 drop lands')
local crate2 = S.List()[1].id
S.random = function(lo, hi)
    if lo == 1 and hi == 100 then return 41 end   -- the loot roll lands in the cash bag band (41 to 60)
    return lo
end
local before = Inv.GetItemCount(1, 'cash_bag')
local ri, rg = call(1, 'nexoro_supplydrop:claim', { id = crate2 })
H.check(ri == true and rg.item == 'cash_bag', 'a roll past the cash band gives the next prize: a cash bag')
H.eq(Inv.GetItemCount(1, 'cash_bag') - before, 1, 'the cash bag is in the inventory')

H.section('Expiry')
S.random = function(lo) return lo end
S.Schedule(18, 0) -- already dropped today; a fresh crate is dropped by hand for this test
S.Drop()
local live = #S.List()
H.check(live >= 1, 'a crate is waiting')
NOW = NOW + cfg.CrateLifetimeMinutes * 60 + 1
H.eq(S.Expire(), live, 'crates nobody opened are removed after 15 minutes')
H.eq(#S.List(), 0, 'nothing is left on the map')

H.section('Team setting')
local teamSaved = cfg.Team
cfg.Team = nil
S.Drop()
local open = S.List()
H.check(#open >= 1, 'a crate for everyone is dropped')
at(4, cfg.Location.x, cfg.Location.y, cfg.Location.z)
local rany = call(4, 'nexoro_supplydrop:claim', { id = open[1].id })
H.check(rany == true, 'with no team set, anyone can open it')
cfg.Team = teamSaved

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
