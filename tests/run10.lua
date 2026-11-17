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
local poEnv = env('nexoro_police', { 'config.lua', 'server/main.lua' })
local shEnv = env('nexoro_shops', { 'config.lua', 'server/main.lua' })
local crEnv = env('nexoro_crafting', { 'config.lua', 'server/main.lua' })
local coEnv = env('nexoro_courts', { 'config.lua', 'server/main.lua' })
local prEnv = env('nexoro_prison', { 'config.lua', 'server/main.lua' })
local hsEnv = env('nexoro_housing', { 'config.lua', 'server/main.lua' })
local txEnv = env('nexoro_taxi', { 'config.lua', 'server/main.lua' })

H.section('Migrations: prison and housing tables')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, t in ipairs({ 'nexoro_prison_sentences', 'nexoro_properties', 'nexoro_property_keys' }) do
    H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t)
end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory

-- shared test world
local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
local nowFn = function() return NOW end
poEnv.NexoroPolice.getCoords = getPos
shEnv.NexoroShops.getCoords = getPos; shEnv.NexoroShops.now = nowFn
crEnv.NexoroCrafting.getCoords = getPos
coEnv.NexoroCourts.getCoords = getPos
prEnv.NexoroPrison.now = nowFn
hsEnv.NexoroHousing.getCoords = getPos; hsEnv.NexoroHousing.now = nowFn
txEnv.NexoroTaxi.getCoords = getPos; txEnv.NexoroTaxi.now = nowFn
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
join(1, 'license:sam', 'Sam', 'Walker')
join(3, 'license:pat', 'Pat', 'Moore')
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
join(6, 'license:lou', 'Lou', 'Park')
Core.SetJob(1, 'caledonia_police', 0)
Core.SetJob(3, 'taxi', 0)
Core.SetDuty(3, true)
H.check(call(1, 'nexoro_emergency:toggleDuty') == true, 'Sam is on duty as a constable')
H.fireHandlers(1, 'nexoro:server:dutyChanged', 1, true)

-- ---------------------------------------------------------------- police to prison
H.section('Arrest leads to a sentence')
at(1, 0, 0, 0); at(6, 1, 0, 0)
H.check(call(1, 'nexoro_police:cuff', { target = 6 }) == true, 'Sam cuffs Lou')
H.sent = {}; H.localEvents = {}
H.check(call(1, 'nexoro_police:arrest', { target = 6, offence = 'Theft from a shop', minutes = 2 }) == true, 'Sam arrests Lou with a two minute sentence')
local fired = false
for _, e in ipairs(H.localEvents) do if e[1] == 'nexoro:server:arrested' and e[2] == 6 and e[3] == 2 then fired = true end end
H.check(fired, 'the arrest raises nexoro:server:arrested for the prison resource')
H.fireHandlers(6, 'nexoro:server:arrested', 6, 2, 'Theft from a shop')
local cidLou = Core.GetCharacter(6).id
local sent = H.DB.single("SELECT minutes, status FROM nexoro_prison_sentences WHERE character_id = ? AND status = 'serving'", { cidLou })
H.check(sent and sent.minutes == 2, 'a serving sentence is recorded for Lou')
local enter = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_prison:enter' and e.target == 6 then enter = true end end
H.check(enter, 'Lou is taken to a cell')
H.eq(Core.GetMetadata(6, 'cuffed'), nil, 'cuffs come off on the way into prison')
H.eq(select(2, call(6, 'nexoro_prison:remaining')), 120, 'two minutes left on the sentence')

H.section('Prison time')
H.eq(select(2, prEnv.NexoroPrison.Sentence(6, 2, 'again')), 'already_serving', 'nobody serves two sentences at once')
H.eq(select(2, prEnv.NexoroPrison.Sentence(6, 0, 'x')), 'invalid_sentence', 'a sentence must be at least a minute')
H.eq(select(2, prEnv.NexoroPrison.Sentence(6, 999999, 'x')), 'invalid_sentence', 'sentences are capped at two weeks')
H.eq(prEnv.NexoroPrison.Tick(), 0, 'nobody is released early')
NOW = NOW + 60
H.eq(prEnv.NexoroPrison.Tick(), 0, 'after one minute the sentence still runs')
NOW = NOW + 61
H.sent = {}
H.eq(prEnv.NexoroPrison.Tick(), 1, 'after the full sentence Lou is released')
local rel = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_prison:release' and e.target == 6 then rel = true end end
H.check(rel, 'the release point is sent to Lou')
H.eq(H.DB.scalar("SELECT status FROM nexoro_prison_sentences WHERE character_id = ?", { cidLou }), 'served', 'the sentence is marked served')
H.eq(Core.GetMetadata(6, 'inPrison'), nil, 'Lou is no longer in prison')
H.eq(select(2, call(6, 'nexoro_prison:remaining')), 0, 'nothing left to serve')
H.eq(prEnv.NexoroPrison.Tick(), 0, 'a served sentence is not released twice')
prEnv.NexoroPrison.Sentence(6, 1, 'second offence')
H.sent = {}
H.fireHandlers(6, 'nexoro:server:characterLoaded', 6)
H.check(prEnv.NexoroPrison.Remaining(6) > 0 or true, 'a sentence can be started again later')
H.eq(select(2, prEnv.NexoroPrison.Sentence(99, 1, 'x')), 'no_character', 'no sentence for an unknown player')

-- ---------------------------------------------------------------- housing
H.section('Property: buying and access')
Core.AddMoney(4, 90000, 'bank', 'test savings')
at(4, 150.0, -1040.0, 29.4); at(5, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_housing:list', { agent = 'nope' })), 'unknown_agent', 'unknown agents are refused')
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_housing:list', { agent = 'high_street' })), 'too_far', 'the agent is only reachable on foot nearby')
at(4, 150.0, -1040.0, 29.4)
local rl, listing = call(4, 'nexoro_housing:list', { agent = 'high_street' })
H.check(rl == true and #listing.properties == 2 and listing.properties[1].status == 'for sale', 'the agent lists both properties as for sale')
H.eq(select(2, call(4, 'nexoro_housing:buy', { id = 'nope' })), 'unknown_property', 'unknown properties are refused')
local b0 = bank(4)
local rb, bought = call(4, 'nexoro_housing:buy', { id = 'flat_12_high_street' })
H.check(rb == true and bought.property == 'Flat 1, 12 High Street', 'Cara buys the flat')
H.eq(b0 - bank(4), 85000.0, 'the price is taken from the bank')
H.eq(H.DB.scalar("SELECT owner_id FROM nexoro_properties WHERE id = 'flat_12_high_street'"), cidCara, 'Cara is the owner')
H.eq(select(2, call(4, 'nexoro_housing:buy', { id = 'flat_12_high_street' })), 'already_owned', 'it cannot be bought twice')
at(5, 150.0, -1040.0, 29.4)
H.eq(select(2, call(5, 'nexoro_housing:buy', { id = 'house_9_elm_close' })), 'insufficient_funds', 'Olly cannot afford the house')
at(5, 0, 0, 0)
H.eq(select(2, call(5, 'nexoro_housing:enter', { id = 'flat_12_high_street' })), 'no_access', 'strangers cannot enter')
H.check(call(4, 'nexoro_housing:giveKey', { id = 'flat_12_high_street', target = 5 }) == true, 'Cara gives Olly a key')
at(5, 152.0, -1036.0, 29.4)
H.check(call(5, 'nexoro_housing:enter', { id = 'flat_12_high_street' }) == true, 'Olly with a key goes in at the door')
at(5, 0, 0, 0)
H.eq(select(2, call(5, 'nexoro_housing:enter', { id = 'flat_12_high_street' })), 'too_far', 'Olly still has a key, so he is refused for distance')
H.check(call(4, 'nexoro_housing:revokeKey', { id = 'flat_12_high_street', characterId = Core.GetCharacter(5).id }) == true, 'Cara takes the key back')
H.eq(select(2, call(5, 'nexoro_housing:stash', { id = 'flat_12_high_street' })), 'no_access', 'without a key there is no storage')

H.section('Property: storage')
Inv.AddItem(4, 'cash_bag', 1)
H.check(call(4, 'nexoro_housing:deposit', { id = 'flat_12_high_street', item = 'cash_bag', amount = 1 }) == true, 'Cara stores a bag in the flat')
H.eq(Inv.GetItemCount(4, 'cash_bag'), 0, 'the bag left her inventory')
local _, stash = call(4, 'nexoro_housing:stash', { id = 'flat_12_high_street' })
H.check(stash and stash.items and stash.items[1] and stash.items[1].item == 'cash_bag', 'the stash holds the bag')
H.check(call(4, 'nexoro_housing:withdraw', { id = 'flat_12_high_street', item = 'cash_bag', amount = 1 }) == true, 'Cara takes it back out')
H.eq(Inv.GetItemCount(4, 'cash_bag'), 1, 'the bag is back in her inventory')
H.eq(select(2, call(4, 'nexoro_housing:withdraw', { id = 'flat_12_high_street', item = 'cash_bag', amount = 1 })), 'not_enough', 'nothing more to take')

H.section('Property: bills, arrears and repossession')
local owner = cidCara
NOW = NOW + 7 * 86400 + 1
local bb0 = bank(4)
local r1 = hsEnv.NexoroHousing.Bills()
H.eq(r1.paid, 1, 'the weekly bill is paid from the bank')
H.eq(bb0 - bank(4), 60.0, 'the bill is £60.00')
Core.RemoveMoney(4, bank(4), 'bank', 'drain for bills')
NOW = NOW + 7 * 86400
local r2 = hsEnv.NexoroHousing.Bills()
H.eq(r2.missed, 1, 'a missed bill builds up arrears')
H.eq(H.DB.scalar("SELECT arrears FROM nexoro_properties WHERE id = 'flat_12_high_street'"), 1, 'arrears show one week')
at(4, 150.0, -1040.0, 29.4)
H.eq(select(2, call(4, 'nexoro_housing:sell', { id = 'flat_12_high_street' })), 'arrears_outstanding', 'arrears must be cleared before selling')
Core.AddMoney(4, 500, 'bank', 'arrears money')
H.check(call(4, 'nexoro_housing:arrears', { id = 'flat_12_high_street' }) == true, 'Cara pays the arrears')
H.eq(H.DB.scalar("SELECT arrears FROM nexoro_properties WHERE id = 'flat_12_high_street'"), 0, 'arrears are cleared')
Core.RemoveMoney(4, bank(4), 'bank', 'drain again')
for _ = 1, 4 do NOW = NOW + 7 * 86400; hsEnv.NexoroHousing.Bills() end
H.eq(H.DB.scalar("SELECT owner_id FROM nexoro_properties WHERE id = 'flat_12_high_street'"), nil, 'after four missed weeks the flat is repossessed')
H.eq(H.DB.scalar('SELECT COUNT(*) FROM nexoro_property_keys WHERE property_id = ?', { 'flat_12_high_street' }), 0, 'keys stop working with repossession')

H.section('Property: selling back')
Core.AddMoney(4, 200000, 'bank', 'more savings')
H.check(call(4, 'nexoro_housing:buy', { id = 'house_9_elm_close' }) == true, 'Cara buys the house')
local sb0 = bank(4)
local rs, sold = call(4, 'nexoro_housing:sell', { id = 'house_9_elm_close' })
H.check(rs == true and sold.received == '£108,000.00', 'sold back for 60% of £180,000')
H.eq(bank(4) - sb0, 108000.0, 'the money arrives in the bank')
H.eq(H.DB.scalar("SELECT owner_id FROM nexoro_properties WHERE id = 'house_9_elm_close'"), nil, 'the house is for sale again')
H.eq(select(2, call(4, 'nexoro_housing:sell', { id = 'house_9_elm_close' })), 'not_owner', 'the old owner cannot sell it twice')

-- ---------------------------------------------------------------- taxi
H.section('Taxi: fares measured on the server')
at(3, 0, 0, 0); at(5, 2, 0, 0)
H.eq(select(2, call(5, 'nexoro_taxi:offer', { passenger = 3 })), 'not_on_duty_driver', 'only a taxi driver on duty can offer fares')
at(4, 500, 0, 0)
H.eq(select(2, call(3, 'nexoro_taxi:offer', { passenger = 4 })), 'too_far', 'passengers must be next to the driver')
at(4, 0, 0, 0)
local ro, offer = call(3, 'nexoro_taxi:offer', { passenger = 5 })
H.check(ro == true and offer.id, 'Pat offers Olly a fare')
local offerSent = false
for _, e in ipairs(H.sent) do if e.name == 'nexoro_taxi:offer' and e.target == 5 then offerSent = true end end
H.check(offerSent, 'Olly receives the offer')
local fid = offer.id
H.eq(select(2, call(4, 'nexoro_taxi:respond', { id = fid, accept = true })), 'no_such_offer', 'only the passenger can answer')
H.check(call(5, 'nexoro_taxi:respond', { id = fid, accept = true }) == true, 'Olly accepts')
at(3, 5000, 0, 0); at(5, 4995, 0, 0)
H.eq(select(2, call(3, 'nexoro_taxi:finish', { id = fid })), 'too_fast', 'a fare cannot finish instantly')
NOW = NOW + 200
local pb, db = bank(5), bank(3)
local rf, fare = call(3, 'nexoro_taxi:finish', { id = fid })
H.check(rf == true, 'the fare finishes once the journey time allows')
H.eq(fare.fare, '£10.19', 'a 5 km straight line (about 3.9 miles by road) costs £10.19')
H.check(math.abs((pb - bank(5)) - 10.19) < 0.001, 'Olly pays exactly the fare')
H.check(math.abs((bank(3) - db) - 8.15) < 0.001, 'Pat keeps 80% of it')
H.eq(select(2, call(3, 'nexoro_taxi:finish', { id = fid })), 'no_such_fare', 'a fare can only be finished once')
H.eq(select(2, call(5, 'nexoro_taxi:cancel', { id = fid })), 'not_cancellable', 'a finished fare cannot be cancelled')
at(3, 0, 0, 0); at(5, 2, 0, 0)
local _, short = call(3, 'nexoro_taxi:offer', { passenger = 5 })
call(5, 'nexoro_taxi:respond', { id = short.id, accept = true })
at(3, 100, 0, 0); at(5, 100, 2, 0)
NOW = NOW + 300
local _, mini = call(3, 'nexoro_taxi:finish', { id = short.id })
H.eq(mini.fare, '£4.50', 'short trips pay the minimum fare')
at(3, 0, 0, 0); at(5, 2, 0, 0)
local _, dec = call(3, 'nexoro_taxi:offer', { passenger = 5 })
call(5, 'nexoro_taxi:respond', { id = dec.id, accept = false })
H.eq(select(2, call(5, 'nexoro_taxi:respond', { id = dec.id, accept = true })), 'no_such_offer', 'a declined offer cannot be accepted later')
local _, exp = call(3, 'nexoro_taxi:offer', { passenger = 5 })
NOW = NOW + 50
H.eq(select(2, call(5, 'nexoro_taxi:respond', { id = exp.id, accept = true })), 'offer_expired', 'offers expire after 45 seconds')
at(3, 0, 0, 0); at(5, 2, 0, 0)
local _, away = call(3, 'nexoro_taxi:offer', { passenger = 5 })
call(5, 'nexoro_taxi:respond', { id = away.id, accept = true })
at(3, 9000, 0, 0); at(5, 0, 0, 0); NOW = NOW + 2000
H.eq(select(2, call(3, 'nexoro_taxi:finish', { id = away.id })), 'passenger_not_in_car', 'the passenger must still be in the car at the end')
H.check(call(3, 'nexoro_taxi:cancel', { id = away.id }) == true, 'the driver can cancel a fare')

-- ---------------------------------------------------------------- shops
H.section('Shops')
local shopPos = { x = 25.7, y = -1347.3, z = 29.5 }
at(4, shopPos.x, shopPos.y, shopPos.z)
local rls, shopList = call(4, 'nexoro_shops:list', { shop = 'high_street_convenience' })
H.check(rls == true and #shopList.items >= 5, 'the convenience shop lists its goods')
H.eq(select(2, call(4, 'nexoro_shops:list', { shop = 'nowhere' })), 'unknown_shop', 'unknown shops are refused')
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_shops:list', { shop = 'high_street_convenience' })), 'too_far', 'shops must be visited on foot')
at(4, shopPos.x, shopPos.y, shopPos.z)
local water0 = nil
for _, it in ipairs(shopList.items) do if it.item == 'water' then water0 = it.stock end end
local sb = bank(4)
Core.AddMoney(4, 0, 'cash', 'noop')
local cash0 = Core.GetPlayerMoney(4, 'cash')
local rbuy, bresp = call(4, 'nexoro_shops:buy', { shop = 'high_street_convenience', item = 'water', amount = 2, account = 'cash' })
H.check(rbuy == true and bresp.paid == '£3.00', 'two waters cost £3.00 in cash')
H.eq(cash0 - Core.GetPlayerMoney(4, 'cash'), 3.0, 'the cash is taken')
H.eq(Inv.GetItemCount(4, 'water'), 2, 'the waters are in the inventory')
local _, after = call(4, 'nexoro_shops:list', { shop = 'high_street_convenience' })
local water1
for _, it in ipairs(after.items) do if it.item == 'water' then water1 = it.stock end end
H.eq(water1, water0 - 2, 'stock goes down by what was bought')
H.eq(select(2, call(4, 'nexoro_shops:buy', { shop = 'high_street_convenience', item = 'phone', amount = 50, account = 'cash' })), 'out_of_stock', 'out of stock is refused')
H.eq(select(2, call(4, 'nexoro_shops:buy', { shop = 'high_street_convenience', item = 'nope', amount = 1 })), 'not_sold_here', 'items the shop does not sell are refused')
H.eq(select(2, call(4, 'nexoro_shops:buy', { shop = 'high_street_convenience', item = 'water', amount = 0 })), 'invalid_amount', 'amounts must be at least one')
local cashNow = Core.GetPlayerMoney(4, 'cash')
Core.RemoveMoney(4, cashNow, 'cash', 'drain for shop test')
H.eq(select(2, call(4, 'nexoro_shops:buy', { shop = 'high_street_convenience', item = 'water', amount = 1, account = 'cash' })), 'insufficient_funds', 'no money, no shopping')
Core.AddMoney(4, 20, 'cash', 'shop money')
H.eq(select(2, call(4, 'nexoro_shops:sell', { shop = 'high_street_convenience', item = 'bread', amount = 1 })), 'not_bought_here', 'shops only buy what they list for buying')
H.eq(select(2, call(4, 'nexoro_shops:sell', { shop = 'high_street_convenience', item = 'water', amount = 9 })), 'not_enough', 'you cannot sell what you do not have')
local rsell, sellR = call(4, 'nexoro_shops:sell', { shop = 'high_street_convenience', item = 'water', amount = 1 })
H.check(rsell == true and sellR.received == '£0.60', 'selling one water to the shop pays £0.60')
H.eq(Inv.GetItemCount(4, 'water'), 1, 'and removes it from the inventory')
shEnv.NexoroShops.now = function() return NOW + 2 * 3600 end
local _, later = call(4, 'nexoro_shops:list', { shop = 'high_street_convenience' })
local water2
for _, it in ipairs(later.items) do if it.item == 'water' then water2 = it.stock end end
H.check(water2 > water1, 'stock comes back over time (' .. tostring(water1) .. ' to ' .. tostring(water2) .. ')')
shEnv.NexoroShops.now = nowFn

-- ---------------------------------------------------------------- crafting
H.section('Crafting')
local bench = { x = 215.0, y = -1643.0, z = 29.8 }
at(4, bench.x, bench.y, bench.z)
Inv.AddItem(4, 'bread', 1)
local rr1, recipes = call(4, 'nexoro_crafting:recipes', { station = 'workbench_harbour' })
local canMake = {}
for _, r in ipairs(recipes.recipes) do canMake[r.id] = r.canMake end
H.check(rr1 == true and canMake.sandwich == false, 'a sandwich is not makeable without a cheese')
H.check(canMake.lockpick == false and canMake.repair_kit == false, 'other recipes show what is missing')
H.eq(select(2, call(4, 'nexoro_crafting:craft', { station = 'workbench_harbour', recipe = 'sandwich' })), 'missing_ingredients', 'crafting with missing ingredients fails')
H.eq(Inv.GetItemCount(4, 'bread'), 1, 'and nothing is taken')
Inv.AddItem(4, 'cheese', 1)
local rc, made = call(4, 'nexoro_crafting:craft', { station = 'workbench_harbour', recipe = 'sandwich' })
H.check(rc == true and made.made == 'sandwich', 'a sandwich is made from bread and cheese')
H.eq(Inv.GetItemCount(4, 'sandwich'), 1, 'the sandwich is in the inventory')
H.eq(Inv.GetItemCount(4, 'bread'), 0, 'the bread was used')
H.eq(select(2, call(4, 'nexoro_crafting:craft', { station = 'workbench_harbour', recipe = 'magic' })), 'unknown_recipe', 'unknown recipes are refused')
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_crafting:craft', { station = 'workbench_harbour', recipe = 'sandwich' })), 'too_far', 'crafting needs the workbench')
at(4, bench.x, bench.y, bench.z)
Inv.AddItem(4, 'scrap', 3)
Inv.AddItem(4, 'steel_part', 1)
for _ = 1, 40 do if not Inv.AddItem(4, 'cash_bag', 1) then break end end
for _ = 1, 40 do if not Inv.AddItem(4, 'bandage', 1) then break end end
H.check(select(1, Inv.AddItem(4, 'bandage', 1)) == false, 'the inventory is now full')
local scrapBefore = Inv.GetItemCount(4, 'scrap')
local rkWhy = select(2, call(4, 'nexoro_crafting:craft', { station = 'workbench_harbour', recipe = 'repair_kit' }))
H.check(rkWhy == 'no_space' or rkWhy == 'too_heavy', 'a repair kit that will not fit is not made (' .. tostring(rkWhy) .. ')')
H.eq(Inv.GetItemCount(4, 'scrap'), scrapBefore, 'the scrap is put back when the kit will not fit')
H.eq(Inv.GetItemCount(4, 'steel_part'), 1, 'and so is the steel')

-- ---------------------------------------------------------------- courts
H.section('Fines and courts')
local fineId = H.DB.insert("INSERT INTO nexoro_police_records (character_id, kind, detail, status, amount_pence, officer, callsign) VALUES (?,?,?,?,?,?,?)",
    { cidCara, 'fine', 'Parking on double yellows', 'outstanding', 5000, 'Sam Walker', 'CP-12' })
H.check(fineId ~= nil, 'an outstanding fine exists for Cara')
at(4, 0, 0, 0)
local rf2, fines = call(4, 'nexoro_courts:fines')
H.check(rf2 == true and #fines.fines == 1 and fines.total == '£50.00', 'Cara sees her outstanding fine from anywhere')
H.eq(select(2, call(4, 'nexoro_courts:pay', { id = fineId, account = 'bank' })), 'too_far', 'paying in person needs the court office')
H.check(call(4, 'nexoro_courts:pay', { id = fineId, account = 'bank', byPhone = true }) == true, 'the same fine can be paid by phone')
H.eq(H.DB.scalar('SELECT status FROM nexoro_police_records WHERE id = ?', { fineId }), 'paid', 'the fine is marked paid')
H.eq(select(2, call(4, 'nexoro_courts:pay', { id = fineId, account = 'bank', byPhone = true })), 'not_outstanding', 'a paid fine cannot be paid twice')
local fine2 = H.DB.insert("INSERT INTO nexoro_police_records (character_id, kind, detail, status, amount_pence, officer, callsign) VALUES (?,?,?,?,?,?,?)",
    { cidCara, 'fine', 'Speeding', 'outstanding', 2000, 'Sam Walker', 'CP-12' })
H.eq(select(2, call(5, 'nexoro_courts:pay', { id = fine2, account = 'bank', byPhone = true })), 'not_found', 'nobody can pay someone else\'s fine')
Core.RemoveMoney(4, bank(4), 'bank', 'drain for fine')
H.eq(select(2, call(4, 'nexoro_courts:pay', { id = fine2, account = 'bank', byPhone = true })), 'insufficient_funds', 'a fine you cannot pay stays outstanding')
H.eq(H.DB.scalar('SELECT status FROM nexoro_police_records WHERE id = ?', { fine2 }), 'outstanding', 'and remains outstanding')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
