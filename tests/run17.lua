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
local dvEnv = env('nexoro_devtools', { 'config.lua', 'server/main.lua' })
local D = dvEnv.NexoroDev

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
end
join(1, 'license:sam', 'Sam', 'Walker')   -- first join: owner
join(4, 'license:cara', 'Cara', 'Lane')   -- civilian

H.section('Dev mode is off by default')
H.convars['nexoro_devmode'] = nil
H.eq(select(2, D.Authorised(1)), 'dev_mode_off', 'dev commands do nothing unless dev mode is on')
H.check(D.MakeToken() == nil, 'no reset token is made when dev mode is off')
H.eq(select(2, D.Give(1, 'money', 100)), 'dev_mode_off', 'giving money is refused when dev mode is off')

H.convars['nexoro_devmode'] = 'true'

H.section('Who may use the dev tools')
H.check(D.Authorised(1) == true, 'the owner may use them in dev mode')
H.eq(select(2, D.Authorised(4)), 'not_authorised', 'a civilian may not')
H.eq(select(2, D.Authorised(0)), 'console', 'the console is not a player')
H.eq(select(2, D.Give(4, 'money', 100)), 'not_authorised', 'a civilian cannot give themselves money')

H.section('Quick test setup')
local c0 = Core.GetPlayerMoney(1, 'cash')
H.check(D.Give(1, 'money', 500, 'cash') == true, 'owner adds £500 cash')
H.eq(Core.GetPlayerMoney(1, 'cash') - c0, 500.0, 'the cash arrives')
H.eq(select(2, D.Give(1, 'money', 2000000)), 'invalid_amount', 'huge amounts are refused')
H.eq(select(2, D.Give(1, 'money', 0)), 'invalid_amount', 'zero is refused')
H.check(D.Give(1, 'item', 3, 'lockpick') == true, 'owner adds three lockpicks')
H.eq(select(2, D.Give(1, 'item', 500, 'lockpick')), 'invalid_amount', 'too many items at once are refused')
H.eq(select(2, D.Give(1, 'nothing', 1)), 'unknown_kind', 'unknown kinds are refused')

H.section('Teleport and heal')
H.eq(select(2, D.Teleport(1, 'nowhere')), 'unknown_location', 'unknown locations are refused')
H.sent = {}
H.check(D.Teleport(1, 'legion') == true, 'owner teleports to Legion Square')
local tp = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_devtools:teleport' and e.target == 1 then tp = true end end
H.check(tp, 'the teleport is sent to the owner')
H.eq(select(2, D.Teleport(4, 'legion')), 'not_authorised', 'a civilian cannot teleport')
H.check(D.Heal(1) == true, 'owner heals')

H.section('Self-check')
local cfg = dvEnv.Config.DevTools
local function fakeDeps(opts)
    return {
        query = function(sql, params)
            if sql == 'SELECT 1' then return opts.ping and 1 or nil end
            if sql:find('information_schema', 1, true) then
                local t = params[1]
                if opts.missing == t then return 0 end
                return 1
            end
            if sql:find('owner', 1, true) then return opts.owners end
            error('unexpected query')
        end,
        resources = function() return opts.resources end,
    }
end
local good = D.SelfCheck(fakeDeps({ ping = true, owners = 1, resources = { { name = 'nexoro_core', state = 'started' }, { name = 'nexoro_shops', state = 'started' } } }))
H.eq(good.passed, good.total, 'a healthy server passes every check')
H.eq(good.total, #cfg.CoreTables + 3, 'one check per core table, plus ping, owner and resources')
local missing = D.SelfCheck(fakeDeps({ ping = true, owners = 1, missing = 'nexoro_pitches', resources = {} }))
local tableFail
for _, r in ipairs(missing.results) do if r.name == 'table nexoro_pitches' then tableFail = r end end
H.check(tableFail and not tableFail.ok and tableFail.detail:find('migrations'), 'a missing table is reported, pointing at the migrations')
local noOwner = D.SelfCheck(fakeDeps({ ping = true, owners = 0, resources = {} }))
local ownerFail
for _, r in ipairs(noOwner.results) do if r.name == 'an owner exists' then ownerFail = r end end
H.check(ownerFail and not ownerFail.ok, 'no owner is reported with the way to fix it')
local stopped = D.SelfCheck(fakeDeps({ ping = true, owners = 1, resources = { { name = 'nexoro_shops', state = 'stopped' }, { name = 'oxmysql', state = 'started' } } }))
local resFail
for _, r in ipairs(stopped.results) do if r.name == 'Nexoro resources started' then resFail = r end end
H.check(resFail and not resFail.ok and resFail.detail:find('nexoro_shops %(stopped%)'), 'a stopped Nexoro resource is named (other resources are ignored)')
local db = D.SelfCheck(fakeDeps({ ping = false, owners = 1, resources = {} }))
H.check(db.results[1].ok == false, 'an unreachable database is reported')

H.section('Database reset')
local dropped = {}
local deps = {
    tables = function() return { 'nexoro_characters', 'nexoro_shops' } end,
    execute = function(sql) dropped[#dropped + 1] = sql end,
}
H.eq(select(2, D.ResetDatabase(1, 'x', deps)), 'console_only', 'the reset is console only')
H.eq(select(2, D.ResetDatabase(0, 'x', deps)), 'wrong_token', 'the reset needs the token printed at startup')
local tok = D.MakeToken()
H.check(type(tok) == 'string' and #tok == 9, 'a nine digit token is printed at startup in dev mode')
H.eq(select(2, D.ResetDatabase(0, '000', deps)), 'wrong_token', 'a wrong token is refused')
local rok, rr = D.ResetDatabase(0, tok, deps)
H.check(rok == true and rr.dropped == 2, 'the right token drops every Nexoro table')
H.check(dropped[1] == 'SET FOREIGN_KEY_CHECKS = 0' and dropped[#dropped] == 'SET FOREIGN_KEY_CHECKS = 1', 'foreign key checks are turned off for the drop and back on after')
H.eq(select(2, D.ResetDatabase(0, tok, deps)), 'wrong_token', 'the token works once')
local tok2 = D.MakeToken()
H.check(type(tok2) == 'string' and tok2 ~= tok, 'a new token is made for the next reset')
H.convars['nexoro_devmode'] = 'false'
H.eq(select(2, D.ResetDatabase(0, D.MakeToken() or 'x', deps)), 'dev_mode_off', 'the reset is refused when dev mode is off')
H.convars['nexoro_devmode'] = 'true'

H.section('Job switching for tests')
H.eq(select(2, D.SetJob(4, 'caledonia_police', 0)), 'not_authorised', 'a civilian cannot switch jobs')
H.check(D.SetJob(1, 'caledonia_police', 0) ~= false, 'the owner can switch to a job for testing')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
