package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = { nexoro_vehicles = 'missing' }
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nex = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
env('nexoro_dispatch', { 'config.lua', 'server/main.lua' })
local mkEnv = env('nexoro_markets', { 'config.lua', 'server/main.lua' })
local ciEnv = env('nexoro_civilian', { 'config.lua', 'server/main.lua' })
local M = mkEnv.NexoroMarkets
local CV = ciEnv.NexoroCivilian

H.section('Migrations')
Nex.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local pos, NOW = {}, os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
M.getCoords = function(s) return pos[s] end
M.now = function() return NOW end
M.random = function() return 100 end
CV.getCoords = function(s) return pos[s] end
CV.now = function() return NOW end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nex.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
end
join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
Core.AddMoney(4, 500, 'cash', 'test')

H.section('Illegal market: contact buys narcotics')
local contact = mkEnv.Config.Markets.contact_drugs
at(4, 900, 900, 30)
Inv.AddItem(4, 'narcotics_packet', 2)
H.eq(select(2, call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'narcotics_packet', amount = 1 })), 'too_far', 'deals are done in person at the contact')
at(4, contact.x, contact.y, contact.z)
H.eq(select(2, call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'bread', amount = 1 })), 'not_wanted', 'the contact only buys what it wants')
H.eq(select(2, call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'narcotics_packet', amount = 5 })), 'not_enough', 'you cannot sell what you do not have')
local c0 = Core.GetPlayerMoney(4, 'cash')
local rs, deal = call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'narcotics_packet', amount = 2 })
H.check(rs == true and deal.received == '£300.00', 'two packets at 60% of £250 each (£300)')
H.eq(Core.GetPlayerMoney(4, 'cash') - c0, 300.0, 'the cash is paid out')
M.random = function() return 1 end
H.localEvents = {}
Inv.AddItem(4, 'narcotics_packet', 1)
call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'narcotics_packet', amount = 1 })
local alarmed = false
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:alarm' then alarmed = true end end
H.check(alarmed, 'a deal can raise an alarm (a roll inside the chance)')
M.random = function() return 100 end
Inv.AddItem(4, 'narcotics_packet', 8)
H.eq(select(2, call(4, 'nexoro_markets:sell', { market = 'contact_drugs', item = 'narcotics_packet', amount = 20 })), 'daily_cap', 'the contact stops buying at £3,000 a day (£300 + £3,000 would be over)')

H.section('Illegal market: weapons')
local dealer = mkEnv.Config.Markets.contact_weapons
at(4, dealer.x, dealer.y, dealer.z)
Core.AddMoney(4, 3000, 'cash', 'weapons money')
local rb, bought = call(4, 'nexoro_markets:buy', { market = 'contact_weapons', item = 'pistol_illegal', amount = 1 })
H.check(rb == true and bought.paid == '£1,500.00', 'an unregistered pistol costs £1,500')
H.eq(Inv.GetItemCount(4, 'pistol_illegal'), 1, 'the pistol is in the inventory')
H.eq(select(2, call(4, 'nexoro_markets:buy', { market = 'contact_weapons', item = 'narcotics_packet', amount = 1 })), 'not_for_sale', 'the dealer only sells what it lists')
Core.RemoveMoney(4, Core.GetPlayerMoney(4, 'cash'), 'cash', 'drain')
H.eq(select(2, call(4, 'nexoro_markets:buy', { market = 'contact_weapons', item = 'pistol_illegal', amount = 1 })), 'insufficient_funds', 'no money, no pistol')

H.section('Civilian: the job centre')
local jc = ciEnv.Config.Civilian.JobCentre
at(5, 900, 900, 30)
H.eq(select(2, call(5, 'nexoro_civilian:hire', { job = 'cleaner' })), 'too_far', 'jobs are taken at the job centre')
at(5, jc.x, jc.y, jc.z)
H.eq(select(2, call(5, 'nexoro_civilian:hire', { job = 'astronaut' })), 'unknown_job', 'unknown jobs are refused')
H.check(call(5, 'nexoro_civilian:hire', { job = 'cleaner' }) == true, 'Olly takes the cleaner job')
local job = Core.GetJob(5)
H.eq(job.name, 'cleaner', 'Olly is now a cleaner')
H.eq(select(2, call(5, 'nexoro_civilian:task', { point = 'office_block' })), 'not_on_duty', 'you must be on duty to work')
H.check(call(5, 'nexoro_civilian:duty') == true, 'Olly goes on duty')
H.eq(select(2, call(4, 'nexoro_civilian:task', { point = 'office_block' })), 'no_job', 'someone without a job cannot work')

H.section('Civilian: tasks and pay')
local office = ciEnv.Config.Civilian.Jobs.cleaner.points[1]
at(5, 900, 900, 30)
H.eq(select(2, call(5, 'nexoro_civilian:task', { point = 'office_block' })), 'too_far', 'tasks are done at the job point')
at(5, office.x, office.y, office.z)
H.eq(select(2, call(5, 'nexoro_civilian:task', { point = 'bus_depot' })), 'unknown_point', 'a point from another job is not yours')
local b0 = Core.GetPlayerMoney(5, 'bank')
local rt, pay = call(5, 'nexoro_civilian:task', { point = 'office_block' })
H.check(rt == true and pay.paid == '£25.00', 'a cleaning task pays £25.00')
H.eq(Core.GetPlayerMoney(5, 'bank') - b0, 25.0, 'the pay goes to the bank')
H.eq(select(2, call(5, 'nexoro_civilian:task', { point = 'office_block' })), 'cooldown', 'the same point cannot pay again straight away')
NOW = NOW + 181
H.check(call(5, 'nexoro_civilian:task', { point = 'office_block' }) == true, 'after the cooldown it pays again')
H.check(call(5, 'nexoro_civilian:duty') == true, 'Olly goes off duty')
H.eq(select(2, call(5, 'nexoro_civilian:task', { point = 'office_block' })), 'not_on_duty', 'no pay off duty')
H.check(call(5, 'nexoro_civilian:quit') == true, 'Olly leaves the job')
H.eq(Core.GetJob(5).name, 'unemployed', 'and is unemployed again')

H.section('Night traffic')
local wcfg = dbEnv and nil
local wEnv = H.newEnv('nexoro_world_cfg')
H.loadFiles(wEnv, 'nexoro_world', { 'config.lua' })
local wc = wEnv.Config.World
H.check(wc.NightTraffic.moving < wc.Traffic.moving and wc.NightTraffic.pedestrians < wc.Traffic.pedestrians, 'night traffic is lighter than day traffic')
H.check(wc.NightHours.from > wc.NightHours.to, 'the night window wraps past midnight (22 to 6)')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
