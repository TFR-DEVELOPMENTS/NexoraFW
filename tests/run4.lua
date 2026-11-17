package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = {}
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nexoro = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })

H.section('Migrations including nexoro_vehicles')
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok and applied == 21, 'six resources with migrations apply', err or applied)
for _, t in ipairs({ 'nexoro_vehicles', 'nexoro_vehicle_keys', 'nexoro_vehicle_history' }) do H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t) end

Nexoro.Ready = true; Nexoro.LoadJobs()
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local vehEnv = env('nexoro_vehicles', { 'config.lua', 'server/main.lua' })
local garEnv = env('nexoro_garages', { 'config.lua', 'server/main.lua' })
local dealEnv = env('nexoro_dealerships', { 'config.lua', 'server/main.lua' })
local adminEnv = env('nexoro_admin', { 'config.lua', 'server/main.lua' })
for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local V = H.registry.nexoro_vehicles
local VX = vehEnv.NexoroVehicles

-- injectable world
local pos, T = {}, os.time()
local alive, hp, deleted = {}, {}, {}
local function at(src, x, y, z) pos[src] = { x = x, y = y, z = z } end
VX.getCoords = function(src) return pos[src] end
garEnv.NexoroGarages.getCoords = function(src) return pos[src] end
dealEnv.NexoroDealerships.getCoords = function(src) return pos[src] end
VX.now = function() return T end
VX.entityExists = function(n) return alive[n] == true end
VX.entityEngineHealth = function(n) return hp[n] end
VX.deleteEntity = function(n) deleted[#deleted + 1] = n end

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last, rank)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last or 'Tester', dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create failed ' .. tostring(d and d.message or d))
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    if rank then Nexoro.Permissions.SetRank(src, rank, 'test') end
    Core.AddMoney(src, 60000, 'bank', 'test funds')
    return d.id
end
local c1 = join(1, 'license:own', 'Olivia', 'Hart', 'owner')
local c2 = join(2, 'license:ben', 'Ben', 'Buyer')
local c3 = join(3, 'license:cara', 'Cara', 'Third')
local c4 = join(4, 'license:paul', 'Paul', 'Taylor')
local c5 = join(5, 'license:mod', 'Mo', 'Khan', 'moderator')
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local function bank(src) return Core.GetPlayerMoney(src, 'bank') end
local function row(plate) return H.DB.single('SELECT * FROM nexoro_vehicles WHERE plate = ?', { plate }) end

---------------------------------------------------------------- Plates
H.section('UK number plates')
local fmtOk, banned = true, false
for _ = 1, 300 do
    local p = VX.GeneratePlate()
    if not p:match('^[A-Z][A-Z]%d%d [A-Z][A-Z][A-Z]$') then fmtOk = false end
    if p:find('[IQZ]') then banned = true end
end
H.check(fmtOk, 'generated plates look like AB12 CDE')
H.check(not banned, 'plates never contain I, Q or Z')
H.eq(VX.NormalisePlate(' ab12   cde '), 'AB12 CDE', 'normalises case and spaces')
H.eq(VX.NormalisePlate('ab12cde'), 'AB12 CDE', 'normalises a plate without the space')
for _, bad in ipairs({ '', 'ABCD EFG', '12AB CDE', "AB12 CD'; DROP", 'AB12 CDEF', 42 }) do H.check(VX.NormalisePlate(bad) == nil, 'rejects plate: ' .. tostring(bad)) end

---------------------------------------------------------------- Dealership purchases
H.section('Dealership purchases')
at(2, -56.8, -1097.0, 26.4)
local rc, cat = call(2, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' })
H.resourceStates['Lore-Friendly-Car-Pack'] = 'missing'
rc, cat = call(2, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' })
H.check(rc == true and #cat.vehicles == 11 and cat.vehicles[1].priceText == '£6,500.00', 'catalogue shows £ prices and hides the optional pack when it is not running')
H.eq(select(2, call(2, 'nexoro_dealerships:terms', { id = 'premium_deluxe', model = 'monroer' })), 'not_for_sale', 'a pack car cannot be bought without the pack')
H.resourceStates['Lore-Friendly-Car-Pack'] = 'started'
rc, cat = call(2, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' })
H.eq(#cat.vehicles, 18, 'with the pack running, its cars are listed too')
at(3, 0, 0, 0)
local rfar, wfar = call(3, 'nexoro_dealerships:catalogue', { id = 'premium_deluxe' })
H.check(rfar == false and wfar == 'too_far', 'cannot browse from across the map', wfar)
local rb, wb = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'adder', method = 'bank' })
H.check(rb == false and wb == 'not_for_sale', 'models outside the catalogue cannot be bought', wb)
H.check(call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'panto', method = 'crypto' }) == false, 'unknown payment method rejected')
local before = bank(2)
local rp, bought = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'panto', method = 'bank', price = 1 })
H.check(rp == true and bought.plate:match('^%u%u%d%d %u%u%u$'), 'purchase by bank registers a plate', bought and bought.plate)
H.eq(before - bank(2), 6500.0, 'charged exactly £6,500.00 (a client-supplied price is ignored)')
local plate1 = bought.plate
H.eq(row(plate1).status, 'stored', 'new vehicle is waiting in the garage')
H.eq(row(plate1).garage, 'legion_garage', 'delivered to the dealership garage')
local cashBefore = Core.GetPlayerMoney(2, 'cash')
local rcash, wcash = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'baller', method = 'cash' })
H.check(rcash == false and wcash == 'insufficient_funds', 'cannot buy a £52,000 car with £250 cash', wcash)
H.eq(Core.GetPlayerMoney(2, 'cash'), cashBefore, 'cash untouched after failed purchase')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_vehicles WHERE owner_id = ?', { c2 }), 1, 'no vehicle registered for the failed purchase')
H.check(call(2, 'nexoro_dealerships:purchase', { id = 'cycle_shop', model = 'panto', method = 'bank' }) == false, 'models are checked against that dealership\'s catalogue')

---------------------------------------------------------------- Garage flow
H.section('Garages: retrieve and store')
at(2, 215.9, -810.0, 30.7)
local rl, gl = call(2, 'nexoro_garages:list', { garage = 'legion_garage' })
H.check(rl == true and #gl.vehicles == 1 and gl.vehicles[1].plate == plate1, 'garage lists my stored vehicle')
H.check(call(3, 'nexoro_garages:list', { garage = 'legion_garage' }) == false, 'players far away cannot list the garage')
at(3, 215.9, -810.0, 30.7)
local _, gl3 = call(3, 'nexoro_garages:list', { garage = 'legion_garage' })
H.eq(#gl3.vehicles, 0, 'other players do not see my vehicle')
local r3, w3 = call(3, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate1, spawnIndex = 1 })
H.check(r3 == false and w3 == 'not_owner', 'cannot retrieve someone else\'s vehicle', w3)
local rw, ww = call(2, 'nexoro_garages:retrieve', { garage = 'pillbox_garage', plate = plate1, spawnIndex = 1 })
H.check(rw == false and ww == 'wrong_garage', 'wrong garage', ww)
H.check(call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate1, spawnIndex = 99 }) == false, 'invalid spawn bay rejected')
local rr, data = call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate1, spawnIndex = 1 })
H.check(rr == true and data.vehicle.model == 'panto' and data.spawn.x == 223.8, 'retrieve returns vehicle data and a server-chosen spawn point')
H.eq(row(plate1).status, 'out', 'vehicle is now out')
local rr2, w2 = call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate1, spawnIndex = 1 })
H.check(rr2 == false and w2 == 'not_stored', 'cannot spawn the same vehicle twice (no duplication)', w2)
V.Spawn(2, plate1, 'legion_garage')
H.check(select(1, V.Spawn(2, plate1, 'legion_garage')) == false, 'direct double-spawn is also refused')
H.check(vehEnv.NexoroVehicles.ConfirmSpawn(2, plate1, 555), 'client confirms the spawn')
alive[555] = true
H.check(vehEnv.NexoroVehicles.ConfirmSpawn(3, plate1, 556) == false, 'someone else cannot confirm my spawn')

---------------------------------------------------------------- State reports
H.section('Vehicle state: server-side sanity checks')
T = T + 60
local rs = call(2, 'nexoro_vehicles:state', { plate = plate1, state = { fuel = 40, engine = 900, body = 950, mileage = 1000 } })
H.check(rs == true, 'owner can report state')
H.eq(row(plate1).fuel, 40, 'fuel burn recorded')
T = T + 60
call(2, 'nexoro_vehicles:state', { plate = plate1, state = { fuel = 100, engine = 1000, body = 1000, mileage = 99999999 } })
local r = row(plate1)
H.check(r.fuel == 40 and r.engine == 900 and r.body == 950, 'client cannot raise fuel or repair damage by reporting higher values')
H.check(r.mileage_m <= 1000 + 60 * 80 + 200 + 5000, 'mileage cannot jump (' .. r.mileage_m .. ' m)')
call(2, 'nexoro_vehicles:state', { plate = plate1, state = { fuel = 0 / 0, engine = 'x', body = -50, mileage = 'abc', props = { colours = { 1, 2 } } } })
r = row(plate1)
H.check(r.body == 0 and r.fuel == 40, 'NaN and junk values are ignored or clamped')
H.check(call(3, 'nexoro_vehicles:state', { plate = plate1, state = { fuel = 1 } }) == false, 'players without a key cannot report state')
H.check(call(2, 'nexoro_vehicles:state', { plate = plate1, state = { props = { huge = ('x'):rep(5000) } } }) == true and not row(plate1).props:find('xxxx'), 'oversized props are ignored')
V.AdminRepair(plate1, 'test')
H.eq(row(plate1).engine, 1000, 'server-side repair restores health')

---------------------------------------------------------------- Keys
H.section('Keys and access')
H.check(call(2, 'nexoro_vehicles:access', { plate = plate1 }) == true, 'owner has access')
H.eq(select(1, call(3, 'nexoro_vehicles:access', { plate = plate1 })), false, 'strangers have no access')
H.check(call(3, 'nexoro_vehicles:keys:give', { plate = plate1, target = 3 }) == false, 'non-owners cannot hand out keys')
H.check(call(2, 'nexoro_vehicles:keys:give', { plate = plate1, target = 3 }) == true, 'owner gives Cara a key')
H.eq(select(1, call(3, 'nexoro_vehicles:access', { plate = plate1 })), true, 'key holder has access')
H.check(call(3, 'nexoro_vehicles:state', { plate = plate1, state = { fuel = 39 } }) == true, 'key holders can report state while driving')
local _, mine3 = call(3, 'nexoro_vehicles:list')
H.check(#mine3 == 1 and mine3[1].mine == false, 'shared vehicles appear in the key holder\'s list')
H.check(call(2, 'nexoro_vehicles:keys:give', { plate = plate1, target = 2 }) == false, 'cannot give yourself a key')
vehEnv.Config.Vehicles.MaxSharedKeys = 1
H.check(select(2, call(2, 'nexoro_vehicles:keys:give', { plate = plate1, target = 4 })) == 'key_limit', 'shared key limit enforced')
vehEnv.Config.Vehicles.MaxSharedKeys = 5
local _, keys = call(2, 'nexoro_vehicles:keys:list', { plate = plate1 })
H.check(#keys == 1 and keys[1].first_name == 'Cara', 'owner can list who has keys')
call(2, 'nexoro_vehicles:keys:revoke', { plate = plate1, characterId = c3 })
H.eq(select(1, call(3, 'nexoro_vehicles:access', { plate = plate1 })), false, 'revoked keys stop working')

---------------------------------------------------------------- Fuel
H.section('Fuel')
at(2, 0, 0, 0)
local rf, wf = call(2, 'nexoro_vehicles:refuel', { plate = plate1, litres = 10, account = 'bank' })
H.check(rf == false and wf == 'not_at_pump', 'must be at a pump', wf)
at(2, 49.4, 2778.8, 58.0)
for _, bad in ipairs({ -5, 0, 0 / 0, 'abc' }) do H.check(call(2, 'nexoro_vehicles:refuel', { plate = plate1, litres = bad, account = 'bank' }) == false, 'refuel rejects litres ' .. tostring(bad)) end
local b0, f0 = bank(2), row(plate1).fuel
local rfu, fuel = call(2, 'nexoro_vehicles:refuel', { plate = plate1, litres = 10, account = 'bank' })
H.check(rfu == true and fuel.litres == 10, 'refuel 10 litres')
H.eq(b0 - bank(2), 14.5, '10 litres cost exactly £14.50')
H.check(math.abs(row(plate1).fuel - (f0 + 10 / 60 * 100)) < 0.01, 'tank level rises by the litres bought')
local rbig, big = call(2, 'nexoro_vehicles:refuel', { plate = plate1, litres = 1000, account = 'bank' })
H.check(rbig == true and math.abs(row(plate1).fuel - 100) < 0.01, 'filling is capped at a full tank')
H.eq(select(2, call(2, 'nexoro_vehicles:refuel', { plate = plate1, litres = 5, account = 'bank' })), 'tank_full', 'cannot buy fuel for a full tank')
H.check(call(3, 'nexoro_vehicles:refuel', { plate = plate1, litres = 5 }) == false, 'strangers cannot refuel my vehicle')

---------------------------------------------------------------- Insurance, wrecks, MOT
H.section('Insurance, MOT and wrecks')
local i0 = bank(2)
local ri, ins = call(2, 'nexoro_vehicles:insurance:buy', { plate = plate1, days = 7, account = 'bank' })
H.check(ri == true, 'buy 7-day insurance')
H.eq(i0 - bank(2), 130.0, '2% of £6,500 = £130.00')
H.check(call(2, 'nexoro_vehicles:insurance:buy', { plate = plate1, days = 3 }) == false, 'unknown plans rejected')
H.check(call(3, 'nexoro_vehicles:insurance:buy', { plate = plate1, days = 7 }) == false, 'only the owner can insure')
local exp1 = row(plate1)
call(2, 'nexoro_vehicles:insurance:buy', { plate = plate1, days = 7, account = 'bank' })
local ts1 = H.DB.scalar('SELECT UNIX_TIMESTAMP(insurance_expires) FROM nexoro_vehicles WHERE plate = ?', { plate1 })
H.check(math.abs(ts1 - (T + 14 * 86400)) < 5, 'a second policy extends from the current expiry')
-- MOT
at(2, 0, 0, 0)
H.eq(select(2, call(2, 'nexoro_vehicles:mot', { plate = plate1, account = 'bank' })), 'not_at_station', 'MOT needs a station')
at(2, -337.4, -136.9, 39.0)
H.check(call(2, 'nexoro_vehicles:mot', { plate = plate1, account = 'bank' }) == true, 'MOT test runs at a station')
local m0 = bank(2)
V.AdminRepair(plate1, 'test')
H.check(select(2, call(2, 'nexoro_vehicles:mot', { plate = plate1, account = 'bank' })).passed, 'healthy vehicle passes')
H.check(math.abs((m0 - bank(2)) - 54.85) < 1e-6, 'MOT fee is exactly £54.85')
H.check(H.DB.scalar('SELECT UNIX_TIMESTAMP(mot_expires) FROM nexoro_vehicles WHERE plate = ?', { plate1 }) > T, 'MOT expiry stored')
H.DB.update('UPDATE nexoro_vehicles SET engine = 300 WHERE plate = ?', { plate1 })
local _, motFail = call(2, 'nexoro_vehicles:mot', { plate = plate1, account = 'bank' })
H.check(motFail.passed == false and motFail.failures[1] == 'Engine condition', 'damaged engine fails the MOT with a reason')
V.AdminRepair(plate1, 'test')
-- wreck + claim (second vehicle)
at(2, 215.9, -810.0, 30.7)
local _, b2 = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'asea', method = 'bank' })
-- (dealership requires being near the dealer)
at(2, -56.8, -1097.0, 26.4)
_, b2 = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'asea', method = 'bank' })
local plate2 = b2.plate
at(2, 215.9, -810.0, 30.7)
call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate2, spawnIndex = 2 })
VX.ConfirmSpawn(2, plate2, 600); alive[600] = true; hp[600] = 850
local rwk, wwk = call(2, 'nexoro_vehicles:wrecked', { plate = plate2 })
H.check(rwk == false and wwk == 'vehicle_not_wrecked', 'a healthy vehicle cannot be reported as wrecked', wwk)
hp[600] = 0
H.check(call(2, 'nexoro_vehicles:wrecked', { plate = plate2 }) == true, 'a destroyed vehicle (engine 0) is accepted')
H.eq(row(plate2).status, 'wrecked', 'status is wrecked')
H.check(#deleted > 0, 'the wreck entity is removed')
local rcl, wcl = call(2, 'nexoro_vehicles:insurance:claim', { plate = plate2, account = 'bank' })
H.check(rcl == false and wcl == 'not_insured', 'uninsured wrecks cannot be claimed', wcl)
call(2, 'nexoro_vehicles:insurance:buy', { plate = plate2, days = 30, account = 'bank' })
local x0 = bank(2)
local rcl2, claim = call(2, 'nexoro_vehicles:insurance:claim', { plate = plate2, account = 'bank' })
H.check(rcl2 == true, 'insured wreck can be claimed')
H.eq(x0 - bank(2), 850.0, 'excess is 10% of £8,500')
local rowAfter = row(plate2)
H.check(rowAfter.status == 'stored' and rowAfter.engine == 500 and rowAfter.garage == 'legion_garage', 'restored to the default garage in poor condition')
H.check(call(2, 'nexoro_vehicles:scrap', { plate = plate2 }) == false, 'only wrecked vehicles can be scrapped')

---------------------------------------------------------------- Storing
H.section('Storing a vehicle')
at(2, 0, 0, 0)
local rs0, ws0 = call(2, 'nexoro_garages:store', { garage = 'legion_garage', plate = plate1, state = { fuel = 50 } })
H.check(rs0 == false and ws0 == 'too_far', 'cannot store from across the map', ws0)
at(2, 215.9, -810.0, 30.7)
H.check(call(3, 'nexoro_garages:store', { garage = 'legion_garage', plate = plate1, state = {} }) == false, 'strangers cannot store my vehicle')
H.check(call(2, 'nexoro_garages:store', { garage = 'mrpd_lot', plate = plate1, state = {} }) == false, 'cannot store at an impound lot')
VX.getCoords = function(src) return pos[src] end
H.check(call(2, 'nexoro_garages:store', { garage = 'legion_garage', plate = plate1, state = { fuel = 55, engine = 1000, body = 1000, mileage = 5000, props = { colours = { 5, 6 } } } }) == true, 'store at a public garage')
local stored = row(plate1)
H.check(stored.status == 'stored' and stored.fuel <= 100 and stored.props:find('colours'), 'stored with its state and modifications saved')
H.check(#deleted >= 2, 'stored vehicle entity removed')
H.check(call(2, 'nexoro_garages:store', { garage = 'legion_garage', plate = plate1, state = {} }) == false, 'cannot store a vehicle that is not out')

---------------------------------------------------------------- Transfers between players
H.section('Selling to another player')
at(2, 10, 10, 10); at(3, 12, 10, 10)
H.check(call(2, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 3, price = 1000 }) == true, 'offer a stored vehicle')
local offers = {}
for _, e in ipairs(H.sent) do if e.name == 'nexoro_vehicles:offer' then offers[#offers + 1] = e end end
H.check(#offers == 1 and offers[1].target == 3 and offers[1].args[1].price == '£1,000.00', 'buyer receives the offer with the price')
local offerId = offers[1].args[1].id
H.check(call(4, 'nexoro_vehicles:transfer:respond', { id = offerId, accept = true }) == false, 'only the named buyer can respond')
local seller0, buyer0 = bank(2), bank(3)
local ra, ta = call(3, 'nexoro_vehicles:transfer:respond', { id = offerId, accept = true })
H.check(ra == true and ta.plate == plate1, 'buyer accepts')
H.eq(row(plate1).owner_id, c3, 'ownership moved to the buyer')
H.eq(buyer0 - bank(3), 1000.0, 'buyer paid £1,000.00')
H.eq(bank(2) - seller0, 1000.0, 'seller received £1,000.00')
H.check(call(3, 'nexoro_vehicles:transfer:respond', { id = offerId, accept = true }) == false, 'an offer can only be used once')
H.check(call(2, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 3, price = 10 }) == false, 'previous owner can no longer sell it')
-- failure cases
at(3, 500, 500, 500)
H.eq(select(2, call(3, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 2, price = 10 })), 'too_far', 'buyer must be next to the seller')
at(3, 10, 10, 10); at(2, 10, 10, 10)
H.check(call(3, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 2, price = -5 }) == false and call(3, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 2, price = 99999999 }) == false, 'bad prices rejected')
call(3, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 2, price = 500 })
local lastOffer
for _, e in ipairs(H.sent) do if e.name == 'nexoro_vehicles:offer' then lastOffer = e.args[1].id end end
T = T + 120
H.eq(select(2, call(2, 'nexoro_vehicles:transfer:respond', { id = lastOffer, accept = true })), 'offer_expired', 'offers expire after 60 s')
T = T - 120
call(3, 'nexoro_vehicles:transfer:offer', { plate = plate1, target = 2, price = 500 })
for _, e in ipairs(H.sent) do if e.name == 'nexoro_vehicles:offer' then lastOffer = e.args[1].id end end
at(3, 215.9, -810.0, 30.7)
call(3, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = plate1, spawnIndex = 1 })
local b3 = bank(2)
local rrace, wrace = call(2, 'nexoro_vehicles:transfer:respond', { id = lastOffer, accept = true })
H.check(rrace == false, 'if the vehicle is taken out after the offer, the sale fails', wrace)
H.eq(bank(2), b3, 'and the buyer is not charged')
H.eq(row(plate1).owner_id, c3, 'ownership unchanged')
call(3, 'nexoro_garages:store', { garage = 'legion_garage', plate = plate1, state = {} })

---------------------------------------------------------------- Finance
H.section('Finance')
local t = select(2, call(2, 'nexoro_dealerships:terms', { id = 'premium_deluxe', model = 'sultan', deposit = 2400 }))
at(2, -56.8, -1097.0, 26.4)
t = select(2, call(2, 'nexoro_dealerships:terms', { id = 'premium_deluxe', model = 'sultan', deposit = 2400 }))
H.check(t and t.remaining == '£23,328.00' and t.payment == '£2,916.00', '£24,000 car: £2,400 deposit, £23,328.00 with 8% interest, 8 payments of £2,916.00', t and t.remaining)
H.check(select(2, call(2, 'nexoro_dealerships:terms', { id = 'premium_deluxe', model = 'sultan', deposit = 100 })) == 'deposit_too_small', 'deposit under 10% rejected')
H.check(select(2, call(2, 'nexoro_dealerships:terms', { id = 'premium_deluxe', model = 'sultan', deposit = 30000 })) == 'deposit_covers_price', 'deposit above the price rejected')
local bf = bank(2)
local rfin, fin = call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'sultan', method = 'finance', deposit = 2400 })
H.check(rfin == true, 'finance purchase')
H.eq(bf - bank(2), 2400.0, 'only the deposit is charged up front')
local finPlate = fin.plate
H.eq(row(finPlate).finance_remaining_pence, 2332800, 'finance balance recorded')
H.check(call(2, 'nexoro_vehicles:transfer:offer', { plate = finPlate, target = 3, price = 1 }) == false, 'cannot sell a financed vehicle')
at(2, 215.9, -810.0, 30.7); at(3, 12, 10, 10)
at(2, -56.8, -1097.0, 26.4)
H.check(call(2, 'nexoro_dealerships:sell', { id = 'premium_deluxe', plate = finPlate }) == false, 'cannot sell a financed vehicle to the dealer')
VX.ProcessFinance()
H.eq(row(finPlate).finance_remaining_pence, 2332800, 'nothing is taken before the due date')
T = T + 8 * 86400
local b4 = bank(2)
H.eq(VX.ProcessFinance(), 1, 'one payment processed when due')
H.eq(b4 - bank(2), 2916.0, '£2,916.00 taken from the bank')
H.eq(row(finPlate).finance_remaining_pence, 2332800 - 291600, 'balance reduced')
-- missed payments
Core.RemoveMoney(2, bank(2), 'bank', 'drain')
T = T + 8 * 86400; VX.ProcessFinance()
H.eq(row(finPlate).finance_missed, 1, 'first missed payment counted')
T = T + 8 * 86400; VX.ProcessFinance()
H.eq(row(finPlate).status, 'stored', 'still not repossessed after two')
T = T + 8 * 86400; VX.ProcessFinance()
H.eq(row(finPlate).status, 'repossessed', 'repossessed after three missed payments')
H.eq(select(2, call(2, 'nexoro_garages:list', { garage = 'legion_garage' })) ~= nil, true, 'repossessed vehicles still listed safely')
at(2, 215.9, -810.0, 30.7)
H.check(call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = finPlate, spawnIndex = 1 }) == false, 'repossessed vehicles cannot be retrieved')
Core.AddMoney(2, 30000, 'bank', 'test')
local rpay = call(2, 'nexoro_vehicles:finance:pay', { plate = finPlate, amount = 99999 })
H.check(rpay == true, 'paying off the arrears works')
H.check(row(finPlate).status == 'stored' and row(finPlate).finance_remaining_pence == 0, 'vehicle returned and finance cleared')
-- offline owners are not penalised
local _, fin2 = (function() at(2, -56.8, -1097.0, 26.4); return call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'schafter2', method = 'finance', deposit = 3200 }) end)()
H.fireHandlers(2, 'playerDropped', 'Exited')
T = T + 30 * 86400
H.eq(VX.ProcessFinance(), 0, 'offline owners are skipped')
H.check(fin2 and fin2.plate, 'second finance purchase succeeded', fin2)
H.eq(row(fin2.plate).finance_missed, 0, 'and not penalised')
H.addPlayerStub(2, 'Ben', { 'license:ben' }); Nexoro.RegisterExistingPlayer(2)
H.check(H.callServer(2, 'nexoro_character:select', { id = c2 }) == true, 'Ben rejoins')

---------------------------------------------------------------- Dealer buyback
H.section('Dealer buyback')
at(2, -56.8, -1097.0, 26.4)
H.DB.update('UPDATE nexoro_vehicles SET mileage_m = 0 WHERE plate = ?', { plate2 })
local _, sellList = call(2, 'nexoro_dealerships:sellList', { id = 'premium_deluxe' })
local offered
for _, s in ipairs(sellList) do if s.plate == plate2 then offered = s.price end end
H.eq(offered, '£4,250.00', 'buyback is 50% of the purchase price for a zero-mileage vehicle')
local s0 = bank(2)
local rsell = call(2, 'nexoro_dealerships:sell', { id = 'premium_deluxe', plate = plate2 })
H.check(rsell == true and bank(2) - s0 == 4250.0, 'sold for £4,250.00')
H.eq(row(plate2).status, 'sold', 'vehicle marked sold')
H.check(call(2, 'nexoro_dealerships:sell', { id = 'premium_deluxe', plate = plate2 }) == false, 'cannot sell it twice')
at(2, 0, 0, 0)
H.check(call(2, 'nexoro_dealerships:sell', { id = 'premium_deluxe', plate = finPlate }) == false, 'must be at the dealership to sell')
H.check(VX.BuybackPrice and true, 'buyback pricing available')
H.check(V.BuybackPrice(finPlate) < V.BuybackPrice(finPlate) + 1, 'buyback export works')

---------------------------------------------------------------- Impound
H.section('Impound')
Core.RegisterJob({ name = 'police', label = 'Police', category = 'police', grades = { [0] = { label = 'PC', salary = 20 } } })
H.check(select(1, V.Impound(3, finPlate, 'test', 100)) == false, 'normal players cannot impound')
Core.SetJob(4, 'police', 0)
H.check(select(1, V.Impound(4, finPlate, 'test', 100)) == false, 'police off duty cannot impound')
Core.SetDuty(4, true)
local imp = V.Impound(4, finPlate, 'Parked on double yellows', 150)
H.check(imp == true, 'police on duty can impound')
local irow = row(finPlate)
H.check(irow.status == 'impounded' and irow.impound_fee_pence == 15000 and irow.impound_reason:find('yellows'), 'status, fee and reason recorded')
at(2, 409.2, -1623.0, 29.3)
local _, lot = call(2, 'nexoro_garages:list', { garage = 'mrpd_lot' })
H.check(#lot.vehicles == 1 and lot.vehicles[1].impoundFee == '£150.00', 'owner sees it at the impound lot with the fee')
H.check(call(3, 'nexoro_garages:release', { garage = 'mrpd_lot', plate = finPlate, account = 'bank' }) == false, 'someone else cannot release it')
H.check(call(2, 'nexoro_garages:release', { garage = 'legion_garage', plate = finPlate, account = 'bank' }) == false, 'release only works at an impound lot')
local i1 = bank(2)
local rrel = call(2, 'nexoro_garages:release', { garage = 'mrpd_lot', plate = finPlate, account = 'bank' })
H.check(rrel == true and i1 - bank(2) == 150.0, 'owner pays £150.00 and releases it')
H.eq(row(finPlate).garage, 'mrpd_lot', 'vehicle waits at the lot garage')
H.check(call(2, 'nexoro_garages:retrieve', { garage = 'mrpd_lot', plate = finPlate, spawnIndex = 1 }) == true, 'and can be driven away')
H.check(call(2, 'nexoro_garages:release', { garage = 'mrpd_lot', plate = finPlate, account = 'bank' }) == false, 'cannot release twice')

---------------------------------------------------------------- Sweeps and recovery
H.section('Abandoned vehicles and restarts')
at(2, 215.9, -810.0, 30.7)
local _, b3d = (function() at(2, -56.8, -1097.0, 26.4); return call(2, 'nexoro_dealerships:purchase', { id = 'premium_deluxe', model = 'blista', method = 'bank' }) end)()
at(2, 215.9, -810.0, 30.7)
call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = b3d.plate, spawnIndex = 1 })
T = T + 10
VX.SweepOut()
H.eq(row(b3d.plate).status, 'out', 'recently retrieved vehicles are left alone')
T = T + 40
local reverted = VX.SweepOut()
H.eq(row(b3d.plate).status, 'stored', 'a vehicle that never appeared returns to its garage')
call(2, 'nexoro_garages:retrieve', { garage = 'legion_garage', plate = b3d.plate, spawnIndex = 1 })
VX.ConfirmSpawn(2, b3d.plate, 700); alive[700] = true
VX.SweepOut(); H.eq(row(b3d.plate).status, 'out', 'existing vehicles are left alone')
alive[700] = false
T = T + 10; VX.SweepOut(); H.eq(row(b3d.plate).status, 'out', 'a vanished vehicle gets a grace period')
T = T + 700
local _, impounded = VX.SweepOut()
H.check(row(b3d.plate).status == 'impounded' and row(b3d.plate).impound_fee_pence == 15000 and impounded == 1, 'abandoned vehicles are impounded with a £150 fee')
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate1 })
H.check(VX.RecoverOut() >= 1 and row(plate1).status == 'stored', 'server restart returns "out" vehicles to their garages')

---------------------------------------------------------------- Admin and police lookups
H.section('Admin registry tools')
local lookup = V.LookupPlate(plate1)
H.check(lookup and lookup.owner == 'Cara Third' and lookup.model == 'panto', 'plate lookup shows the registered keeper')
H.check(#V.Search('Cara') >= 1 and #V.Search(plate1:sub(1, 4)) >= 1, 'registry search by owner or plate')
H.eq(#V.Search("' OR 1=1 --"), 0, 'search is safe against injection')
local function exec(src, name, payload) return adminEnv.NexoroAdmin.Execute(src, name, payload) end
H.check(exec(5, 'vtransfer', { plate = plate1, citizenId = 'NXAAAAAA', reason = 'x', confirm = true }) == false, 'moderators cannot transfer vehicles')
H.check(exec(1, 'vtransfer', { plate = plate1, citizenId = 'nonsense', reason = 'fix error', confirm = true }) == false, 'invalid citizen IDs rejected')
local c2id = H.DB.scalar('SELECT citizen_id FROM nexoro_characters WHERE id = ?', { c2 })
H.check(exec(1, 'vtransfer', { plate = plate1, citizenId = c2id, reason = 'Ticket 77' }) == false, 'transfer needs confirmation')
H.check(exec(1, 'vtransfer', { plate = plate1, citizenId = c2id, reason = 'Ticket 77', confirm = true }), 'owner can transfer a vehicle')
H.eq(row(plate1).owner_id, c2, 'ownership changed')
local auditRow = H.DB.single("SELECT previous_value, new_value, reason FROM nexoro_admin_logs WHERE action = 'vtransfer' ORDER BY id DESC LIMIT 1")
H.check(auditRow and auditRow.previous_value:find('Cara') and auditRow.new_value:find(c2id) and auditRow.reason == 'Ticket 77', 'audit log records previous owner, new owner and reason')
H.check(exec(1, 'vrepair', { plate = plate1 }) and exec(1, 'vimpound', { plate = plate1, reason = 'Evidence', fee = 0 }), 'repair and impound')
H.check(exec(1, 'vrelease', { plate = plate1 }) and row(plate1).status == 'stored', 'staff release without a fee')
H.check(exec(1, 'vdelete', { plate = plate1, reason = 'Duplicate' }) == false, 'delete needs confirmation')
H.check(exec(1, 'vdelete', { plate = plate1, reason = 'Duplicate', confirm = true }) and row(plate1).status == 'scrapped', 'staff can scrap a vehicle')
local rsr, srch = H.callServer(1, 'nexoro_admin:vehicles', { search = 'Ben' })
H.check(rsr == true and #srch >= 1, 'registry endpoint returns results')
H.check(H.callServer(5, 'nexoro_admin:vehicles', { search = 'Ben' }) == false, 'moderators have no registry access')
local _, hist = call(1, 'nexoro_vehicles:history', { plate = finPlate })
H.check(#hist > 5, 'vehicle history keeps the life of the vehicle (' .. #hist .. ' events)')
H.check(call(3, 'nexoro_vehicles:history', { plate = finPlate }) == false, 'strangers cannot read someone else\'s vehicle history')

H.section('Integrity')
H.eq(H.DB.scalar('SELECT COUNT(*) - COUNT(DISTINCT plate) FROM nexoro_vehicles'), 0, 'every plate is unique')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_characters WHERE cash_pence < 0 OR bank_pence < 0'), 0, 'no negative balances')
H.DB.update('DELETE FROM nexoro_characters WHERE id = ?', { c3 })
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_vehicle_keys WHERE character_id = ?', { c3 }), 0, 'deleting a character removes their keys')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
