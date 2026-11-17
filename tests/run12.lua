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
local trEnv = env('nexoro_transport', { 'config.lua', 'server/main.lua' })
local pwEnv = env('nexoro_pawn', { 'config.lua', 'server/main.lua' })
local auEnv = env('nexoro_auctions', { 'config.lua', 'server/main.lua' })
local roEnv = env('nexoro_robbery', { 'config.lua', 'server/main.lua' })
local faEnv = env('nexoro_farming', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, t in ipairs({ 'nexoro_auctions', 'nexoro_farm_plots' }) do H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t) end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory

local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
trEnv.NexoroTransport.getCoords = getPos
pwEnv.NexoroPawn.getCoords = getPos
auEnv.NexoroAuctions.getCoords = getPos
auEnv.NexoroAuctions.now = function() return NOW end
roEnv.NexoroRobbery.getCoords = getPos
roEnv.NexoroRobbery.now = function() return NOW end
faEnv.NexoroFarming.getCoords = getPos
faEnv.NexoroFarming.now = function() return NOW end

local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local function bank(src) return Core.GetPlayerMoney(src, 'bank') end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
join(3, 'license:pat', 'Pat', 'Moore')
join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
join(6, 'license:lou', 'Lou', 'Park')
Core.AddMoney(4, 2000, 'bank', 'test money')

-- ---------------------------------------------------------------- transport
H.section('Public transport')
local route = trEnv.Config.Transport.Routes[1]
local s1, s2, s3 = route.stops[1], route.stops[2], route.stops[3]
at(3, 900, 900, 30)
H.eq(select(2, call(3, 'nexoro_transport:board', { route = 'route_1', stop = 1 })), 'too_far', 'you must tap on at the stop')
at(3, s1.x, s1.y, s1.z)
H.eq(select(2, call(3, 'nexoro_transport:board', { route = 'nope', stop = 1 })), 'unknown_route', 'unknown routes are refused')
H.eq(select(2, call(3, 'nexoro_transport:board', { route = 'route_1', stop = 9 })), 'unknown_stop', 'unknown stops are refused')
H.check(call(3, 'nexoro_transport:board', { route = 'route_1', stop = 1 }) == true, 'Pat taps on at High Street')
H.eq(select(2, call(3, 'nexoro_transport:board', { route = 'route_1', stop = 1 })), 'already_boarded', 'you cannot tap on twice')
H.eq(select(2, call(3, 'nexoro_transport:alight', { route = 'route_1', stop = 1 })), 'same_stop', 'you cannot tap off where you got on')
local fare = trEnv.Config.Transport and nil
local expected = math.max(1.50, 1.50 + 0.60 * (math.sqrt((s1.x - s3.x)^2 + (s1.y - s3.y)^2 + (s1.z - s3.z)^2) * 1.3 / 1000))
at(3, s3.x, s3.y, s3.z)
local bb = bank(3)
local rt, trip = call(3, 'nexoro_transport:alight', { route = 'route_1', stop = 3 })
H.check(rt == true and trip.stop == 'Harbour', 'Pat taps off at the harbour')
H.check(math.abs((bb - bank(3)) - math.floor(expected * 100 + 0.5) / 100) < 0.001, 'the fare follows the road distance between the stops')
H.eq(select(2, call(3, 'nexoro_transport:alight', { route = 'route_1', stop = 3 })), 'not_boarded', 'the trip is finished')
at(3, s1.x, s1.y, s1.z)
call(3, 'nexoro_transport:board', { route = 'route_1', stop = 1 })
Core.RemoveMoney(3, bank(3), 'bank', 'drain for fare')
at(3, s2.x, s2.y, s2.z)
H.eq(select(2, call(3, 'nexoro_transport:alight', { route = 'route_1', stop = 2 })), 'cannot_pay', 'with no money the fare is refused')
local _, st = call(3, 'nexoro_transport:status')
H.check(st.boarded == true, 'and Pat stays on the bus until he can pay')
Core.AddMoney(3, 100, 'bank', 'fare money')
H.check(call(3, 'nexoro_transport:alight', { route = 'route_1', stop = 2 }) == true, 'once paid, Pat gets off')

-- ---------------------------------------------------------------- pawn
H.section('Pawn shop')
local shop = pwEnv.Config.Pawn.Shop
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_pawn:sell', { item = 'radio', amount = 1 })), 'too_far', 'the pawn shop is visited on foot')
at(4, shop.x, shop.y, shop.z)
Inv.AddItem(4, 'radio', 2)
H.eq(select(2, call(4, 'nexoro_pawn:sell', { item = 'bread', amount = 1 })), 'not_accepted', 'the pawn shop only takes what it prices')
H.eq(select(2, call(4, 'nexoro_pawn:sell', { item = 'radio', amount = 5 })), 'not_enough', 'you cannot sell what you do not have')
H.eq(select(2, call(4, 'nexoro_pawn:sell', { item = 'radio', amount = 0 })), 'invalid_amount', 'amounts must be at least one')
local cash0 = Core.GetPlayerMoney(4, 'cash')
local rp, pawn = call(4, 'nexoro_pawn:sell', { item = 'radio', amount = 2 })
H.check(rp == true and pawn.received == '£40.00', 'two radios sell for £40.00')
H.eq(Core.GetPlayerMoney(4, 'cash') - cash0, 40.0, 'the cash is paid out')
H.eq(Inv.GetItemCount(4, 'radio'), 0, 'the radios are gone')

-- ---------------------------------------------------------------- auctions
H.section('Auction house')
local house = auEnv.Config.Auctions.House
at(5, house.x, house.y, house.z); at(6, house.x, house.y, house.z)
Inv.AddItem(5, 'repair_kit', 2)
H.eq(select(2, call(5, 'nexoro_auctions:create', { item = 'repair_kit', amount = 1, price = 100, minutes = 1 })), 'invalid_duration', 'auctions run 5 to 120 minutes')
local rc, auc = call(5, 'nexoro_auctions:create', { item = 'repair_kit', amount = 1, price = 100, minutes = 10 })
H.check(rc == true and auc.id, 'Olly lists a repair kit at £100')
H.eq(Inv.GetItemCount(5, 'repair_kit'), 1, 'the item is held by the auction house')
H.eq(select(2, call(5, 'nexoro_auctions:bid', { id = auc.id, price = 150 })), 'own_listing', 'you cannot bid on your own item')
at(4, house.x, house.y, house.z)
H.eq(select(2, call(4, 'nexoro_auctions:bid', { id = auc.id, price = 99 })), 'bid_too_low', 'the first bid must meet the starting price')
local cb0 = bank(4)
H.check(call(4, 'nexoro_auctions:bid', { id = auc.id, price = 100 }) == true, 'Cara bids £100')
H.eq(cb0 - bank(4), 100.0, 'Cara\'s bid is taken from her bank')
H.eq(select(2, call(6, 'nexoro_auctions:bid', { id = auc.id, price = 101 })), 'bid_too_low', 'a bid must beat the current one by the minimum step')
local lb0 = bank(6)
H.check(call(6, 'nexoro_auctions:bid', { id = auc.id, price = 105 }) == true, 'Lou bids £105')
H.eq(lb0 - bank(6), 105.0, 'Lou pays his bid')
H.eq(bank(4), cb0, 'Cara is refunded the moment she is outbid')
NOW = NOW + 10 * 60 + 1
local sellerBefore = H.DB.scalar('SELECT bank_pence FROM nexoro_characters WHERE id = (SELECT seller_id FROM nexoro_auctions WHERE id = ?)', { auc.id })
local settle = auEnv.NexoroAuctions.Settle()
H.eq(settle.sold, 1, 'the auction sells when its time is up')
local sellerAfter = H.DB.scalar('SELECT bank_pence FROM nexoro_characters WHERE id = (SELECT seller_id FROM nexoro_auctions WHERE id = ?)', { auc.id })
H.eq(sellerAfter - sellerBefore, 9975, 'the seller receives £105 less the 5% house fee (£99.75)')
H.eq(select(2, call(4, 'nexoro_auctions:claim', { id = auc.id })), 'not_yours', 'the losing bidder cannot claim the item')
H.check(call(6, 'nexoro_auctions:claim', { id = auc.id }) == true, 'the winner claims the repair kit')
H.eq(Inv.GetItemCount(6, 'repair_kit'), 1, 'the item is in the winner\'s inventory')
H.eq(select(2, call(6, 'nexoro_auctions:claim', { id = auc.id })), 'not_yours', 'an item can only be claimed once')
local _, lst = call(5, 'nexoro_auctions:list')
H.eq(#lst, 0, 'nothing is left active')
-- unsold
local _, auc2 = call(5, 'nexoro_auctions:create', { item = 'repair_kit', amount = 1, price = 50, minutes = 5 })
NOW = NOW + 5 * 60 + 1
local s2 = auEnv.NexoroAuctions.Settle()
H.eq(s2.unsold, 1, 'an auction with no bids goes unsold')
H.eq(select(2, call(6, 'nexoro_auctions:claim', { id = auc2.id })), 'not_yours', 'the buyer cannot claim an unsold item')
H.check(call(5, 'nexoro_auctions:claim', { id = auc2.id }) == true, 'the seller takes back an unsold item')
H.eq(select(2, call(5, 'nexoro_auctions:bid', { id = auc2.id, price = 10 })), 'not_active', 'closed auctions cannot be bid on')

-- ---------------------------------------------------------------- robberies
H.section('Robberies')
emEnv.NexoroEmergency = emEnv.NexoroEmergency
local atm = roEnv.Config.Robbery.Targets[2]
at(6, atm.x, atm.y, atm.z)
H.eq(select(2, call(6, 'nexoro_robbery:check', { target = 'atm_high_street' })), 'no_lockpick', 'a lockpick is needed')
Inv.AddItem(6, 'lockpick', 2)
at(6, 900, 900, 30)
H.eq(select(2, call(6, 'nexoro_robbery:check', { target = 'atm_high_street' })), 'too_far', 'you must be at the ATM')
at(6, atm.x, atm.y, atm.z)
local rck, chk = call(6, 'nexoro_robbery:check', { target = 'atm_high_street' })
H.check(rck == true and chk.seconds == 20, 'the robbery can start, taking 20 seconds')
roEnv.NexoroRobbery.random = function(lo) return lo end
H.localEvents = {}
local lcash = Core.GetPlayerMoney(6, 'cash')
local rcomp, took = call(6, 'nexoro_robbery:complete', { target = 'atm_high_street' })
H.check(rcomp == true and took.taken == '£300.00', 'the ATM gives up its smallest amount (£300)')
H.eq(Core.GetPlayerMoney(6, 'cash') - lcash, 300.0, 'the cash is in Lou\'s pocket')
H.eq(Inv.GetItemCount(6, 'lockpick'), 1, 'one lockpick was used up')
local alarm
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:alarm' then alarm = e[2] end end
H.check(alarm ~= nil, 'the robbery raises an alarm')
H.fireHandlers(6, 'nexoro:server:alarm', alarm)
local inc = H.DB.single("SELECT kind, priority, created_by FROM nexoro_dispatch_incidents WHERE created_by = 'Alarm' ORDER BY id DESC LIMIT 1")
H.check(inc and inc.kind == 'police' and inc.priority == 1, 'the alarm becomes an immediate police incident in dispatch')
H.eq(select(2, call(6, 'nexoro_robbery:check', { target = 'atm_high_street' })), 'cooldown', 'the same ATM cannot be robbed again straight away')
NOW = NOW + 121 * 60
Inv.AddItem(6, 'lockpick', 1)
H.check(call(6, 'nexoro_robbery:check', { target = 'atm_high_street' }) == true, 'after two hours the ATM is ready again')

-- ---------------------------------------------------------------- farming
H.section('Farming')
local plot1 = faEnv.Config.Farming.Plots[1]
local plot2 = faEnv.Config.Farming.Plots[2]
faEnv.NexoroFarming.random = function(lo) return lo end
at(5, plot1.x, plot1.y, plot1.z)
H.eq(select(2, call(5, 'nexoro_farming:plant', { plot = plot1.id })), 'not_enough', 'planting needs a wheat seed')
Inv.AddItem(5, 'seed_wheat', 2)
local rpl, planted = call(5, 'nexoro_farming:plant', { plot = plot1.id })
H.check(rpl == true and planted.ready_in == 600, 'Olly plants a seed; it is ready in 10 minutes')
H.eq(Inv.GetItemCount(5, 'seed_wheat'), 1, 'one seed used')
H.eq(select(2, call(5, 'nexoro_farming:plant', { plot = plot1.id })), 'occupied', 'a plot can only hold one crop')
H.eq(Inv.GetItemCount(5, 'seed_wheat'), 1, 'a refused planting gives the seed back')
H.eq(select(2, call(5, 'nexoro_farming:harvest', { plot = plot1.id })), 'not_ready', 'the crop is not ready yet')
NOW = NOW + 600
local rh, crop = call(5, 'nexoro_farming:harvest', { plot = plot1.id })
H.check(rh == true and crop.crop == 'wheat' and crop.amount == 2, 'the crop is harvested when ready (2 wheat at the bottom of the range)')
H.eq(Inv.GetItemCount(5, 'wheat'), 2, 'the wheat is in the inventory')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_farm_plots WHERE plot_id = ?', { plot1.id }), 0, 'the plot is empty again')
H.eq(select(2, call(5, 'nexoro_farming:harvest', { plot = plot1.id })), 'empty', 'nothing to harvest on an empty plot')
Inv.AddItem(4, 'seed_wheat', 1)
at(4, plot2.x, plot2.y, plot2.z)
call(4, 'nexoro_farming:plant', { plot = plot2.id })
at(5, plot2.x, plot2.y, plot2.z)
NOW = NOW + 600
H.eq(select(2, call(5, 'nexoro_farming:harvest', { plot = plot2.id })), 'not_yours', 'only the planter can harvest a plot')
at(4, plot2.x, plot2.y, plot2.z)
H.check(call(4, 'nexoro_farming:harvest', { plot = plot2.id }) == true, 'the planter harvests their own plot')
Inv.AddItem(4, 'seed_wheat', 1)
at(4, plot1.x, plot1.y, plot1.z)
call(4, 'nexoro_farming:plant', { plot = plot1.id })
for _ = 1, 40 do if not Inv.AddItem(4, 'cash_bag', 1) then break end end
for _ = 1, 40 do if not Inv.AddItem(4, 'bandage', 1) then break end end
NOW = NOW + 600
H.check(select(1, call(4, 'nexoro_farming:harvest', { plot = plot1.id })) == false, 'a full inventory refuses the harvest')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_farm_plots WHERE plot_id = ?', { plot1.id }), 1, 'and the crop stays in the ground for later')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
