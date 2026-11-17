package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

H.resourceStates = { nexoro_vehicles = 'started' }
local dbEnv = env('nexoro_database', { 'config.lua', 'server/migrations.lua' })
local coreEnv = env('nexoro_core', { 'config/framework.lua', 'shared/utils.lua', 'config/staff.lua', 'server/logging.lua', 'server/security.lua', 'server/callbacks.lua', 'server/permissions.lua', 'server/jobs.lua', 'server/players.lua', 'server/api.lua' })
local Nex = coreEnv.Nexoro
env('nexoro_identity', { 'config.lua', 'server/validation.lua', 'server/main.lua' })
local chEnv = env('nexoro_character', { 'config.lua', 'server/appearance.lua' })
H.loadFiles(chEnv, 'nexoro_character', { 'server/main.lua' })
local invEnv = env('nexoro_inventory', { 'config.lua', 'items.lua', 'server/main.lua' })
env('nexoro_emergency', { 'config.lua', 'server/main.lua' })
local veEnv = env('nexoro_vehicles', { 'config.lua', 'server/main.lua' })
env('nexoro_dispatch', { 'config.lua', 'server/main.lua' })
local hsEnv = env('nexoro_housing', { 'config.lua', 'server/main.lua' })
local crEnv = env('nexoro_crime', { 'config.lua', 'server/main.lua' })
local C = crEnv.NexoroCrime

H.section('Migrations')
Nex.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
H.check(H.DB.query('SHOW TABLES LIKE ?', { 'nexoro_vehicle_thefts' })[1] ~= nil, 'theft table exists')

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory
local pos, NOW = {}, os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
C.getCoords = function(s) return pos[s] end
C.now = function() return NOW end
local vehicles = {}
C.vehicleOf = function(netId) return vehicles[netId] end
local online = {}
C.isOnline = function(cid) return online[cid] == true end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end

local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last, job, grade)
    H.addPlayerStub(src, first, { license }); Nex.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    if job then Core.SetJob(src, job, grade or 0); Core.SetDuty(src, true) end
    return d.id
end
local cidSam = join(1, 'license:sam', 'Sam', 'Walker', 'caledonia_police', 0)
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
local cidOlly = join(5, 'license:olly', 'Olly', 'Price')
local cidLou = join(6, 'license:lou', 'Lou', 'Park')
Core.AddMoney(4, 1000, 'bank', 'test money')

H.section('Vehicle theft')
local plate = veEnv.NexoroVehicles.Register(cidOlly, 'panto', { price = 6500, garage = 'legion_garage' })
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate })
vehicles[7] = { x = 10, y = 10, z = 0, plate = plate }
at(4, 900, 900, 30)
Inv.AddItem(4, 'lockpick', 3)
H.eq(select(2, call(4, 'nexoro_crime:steal', { netId = 7 })), 'too_far', 'you must be next to the car')
at(4, 10, 10, 0)
H.eq(select(2, call(4, 'nexoro_crime:steal', { netId = 999 })), 'too_far', 'an unknown vehicle cannot be taken')
Inv.RemoveItem(4, 'lockpick', 3)
H.eq(select(2, call(4, 'nexoro_crime:steal', { netId = 7 })), 'no_lockpick', 'a lockpick is needed')
Inv.AddItem(4, 'lockpick', 3)
at(5, 10, 10, 0)
Inv.AddItem(5, 'lockpick', 1)
H.eq(select(2, call(5, 'nexoro_crime:steal', { netId = 7 })), 'own_vehicle', 'you cannot steal your own car')
H.eq(Inv.GetItemCount(5, 'lockpick'), 1, 'and a refused theft uses no lockpick')
H.DB.update("UPDATE nexoro_vehicles SET status = 'stored' WHERE plate = ?", { plate })
H.eq(select(2, call(4, 'nexoro_crime:steal', { netId = 7 })), 'not_on_street', 'only a car out on the street can be taken')
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate })
C.random = function() return 1 end
local lp0 = Inv.GetItemCount(4, 'lockpick')
local rs, theft = call(4, 'nexoro_crime:steal', { netId = 7 })
H.check(rs == true and theft.plate == plate, 'a successful theft takes the car')
H.eq(lp0 - Inv.GetItemCount(4, 'lockpick'), 1, 'one lockpick is used up')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_vehicle_thefts WHERE plate = ? AND recovered_at IS NULL', { plate }), 1, 'the theft is recorded')
local alarmed = false
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:alarm' then alarmed = true end end
H.check(alarmed, 'the theft raises an alarm to dispatch')
H.eq(select(2, call(4, 'nexoro_crime:steal', { netId = 7 })), 'cooldown', 'the same car cannot be taken again straight away')
local plate2 = veEnv.NexoroVehicles.Register(cidOlly, 'sultan', { price = 9000, garage = 'legion_garage' })
H.DB.update("UPDATE nexoro_vehicles SET status = 'out' WHERE plate = ?", { plate2 })
vehicles[8] = { x = 10, y = 10, z = 0, plate = plate2 }
C.random = function() return 100 end
local rf, why = call(4, 'nexoro_crime:steal', { netId = 8 })
H.eq(why, 'failed', 'a failed attempt is reported')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_vehicle_thefts WHERE plate = ?', { plate2 }), 0, 'a failed attempt leaves no theft record')
H.eq(select(2, call(6, 'nexoro_crime:recover', { plate = plate })), 'not_police', 'only police can recover a stolen car')
H.check(call(1, 'nexoro_crime:recover', { plate = plate }) == true, 'an officer on duty recovers it')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_vehicle_thefts WHERE plate = ? AND recovered_at IS NULL', { plate }), 0, 'and it is marked recovered')

H.section('House robbery')
H.DB.update('UPDATE nexoro_properties SET owner_id = ? WHERE id = ?', { cidLou, 'flat_12_high_street' })
Inv.AddItemToStash('property', 'flat_12_high_street', 'cash_bag', 2, nil, { slots = 40, maxWeight = 60000 })
local house = crEnv.Config.Crime.Robbery.Houses[1]
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_crime:rob', { house = house.id })), 'too_far', 'you must be at the door')
at(4, house.x, house.y, house.z)
Inv.RemoveItem(4, 'lockpick', Inv.GetItemCount(4, 'lockpick'))
H.eq(select(2, call(4, 'nexoro_crime:rob', { house = house.id })), 'no_lockpick', 'a lockpick is needed to break in')
Inv.AddItem(4, 'lockpick', 1)
online[cidLou] = true
H.eq(select(2, call(4, 'nexoro_crime:rob', { house = house.id })), 'occupied', 'nothing is taken while the owner is home')
online[cidLou] = false
local rr, loot = call(4, 'nexoro_crime:rob', { house = house.id })
H.check(rr == true and loot.taken[1].item == 'cash_bag' and loot.taken[1].amount == 2, 'with the owner away, the stash is taken')
H.eq(Inv.GetItemCount(4, 'cash_bag'), 2, 'the goods are in the thief\'s inventory')
H.eq(#Inv.GetStash('property', 'flat_12_high_street', { slots = 40, maxWeight = 60000 }).items, 0, 'the stash is empty now')
Inv.AddItem(4, 'lockpick', 1)
H.eq(select(2, call(4, 'nexoro_crime:rob', { house = house.id })), 'cooldown', 'a house cannot be robbed again straight away')
NOW = NOW + 121 * 60
Inv.AddItem(4, 'lockpick', 1)
H.eq(select(2, call(4, 'nexoro_crime:rob', { house = house.id })), 'empty', 'an empty stash has nothing to take')

H.section('Fence')
local fence = crEnv.Config.Crime.Fence
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_crime:fenceSell', { item = 'cash_bag', amount = 1 })), 'too_far', 'the fence is found in person')
at(4, fence.x, fence.y, fence.z)
H.eq(select(2, call(4, 'nexoro_crime:fenceSell', { item = 'bread', amount = 1 })), 'not_wanted', 'the fence only buys what it wants')
C.random = function() return 100 end
local c0 = Core.GetPlayerMoney(4, 'cash')
local rsl, sale = call(4, 'nexoro_crime:fenceSell', { item = 'cash_bag', amount = 2 })
H.check(rsl == true and sale.received == '£240.00', 'two cash bags sell for 40% of £300 each (£240)')
H.eq(Core.GetPlayerMoney(4, 'cash') - c0, 240.0, 'the cash is paid out')
Inv.AddItem(4, 'cash_bag', 11)
H.eq(select(2, call(4, 'nexoro_crime:fenceSell', { item = 'cash_bag', amount = 11 })), 'daily_cap', 'the fence stops buying at the daily cap of £1,500 (£240 + £1,320 would be over)')
C.random = function() return 1 end
Inv.RemoveItem(4, 'cash_bag', Inv.GetItemCount(4, 'cash_bag'))
Inv.AddItem(4, 'cash_bag', 1)
local _, ra = call(4, 'nexoro_crime:fenceSell', { item = 'cash_bag', amount = 1 })
local alarmSale = false
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:alarm' and e[2] and e[2].description and e[2].description:find('fence') then alarmSale = true end end
H.check(alarmSale, 'a suspicious sale can raise an alarm')
Core.AddMoney(4, 500, 'cash', 'lockpick money')
local rb, bought = call(4, 'nexoro_crime:fenceBuy', { item = 'lockpick', amount = 1 })
H.check(rb == true and bought.paid == '£150.00', 'the fence sells a lockpick for £150')
H.eq(select(2, call(4, 'nexoro_crime:fenceBuy', { item = 'radio', amount = 1 })), 'not_for_sale', 'the fence sells only what it lists')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
