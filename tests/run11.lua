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
local bzEnv = env('nexoro_businesses', { 'config.lua', 'server/main.lua' })
local poEnv = env('nexoro_postal', { 'config.lua', 'server/main.lua' })
local faEnv = env('nexoro_fishing', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, t in ipairs({ 'nexoro_licences', 'nexoro_businesses', 'nexoro_business_staff' }) do H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t) end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()
local Inv = H.registry.nexoro_inventory

local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
liEnv.NexoroLicences.getCoords = getPos
faEnv.NexoroFishing.getCoords = getPos
poEnv.NexoroPostal.getCoords = getPos
local nowFn = function() return NOW end
faEnv.NexoroFishing.now = nowFn
poEnv.NexoroPostal.now = nowFn
bzEnv.NexoroBusinesses.now = nowFn
liEnv.NexoroLicences.now = nowFn
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
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
local cidOlly = join(5, 'license:olly', 'Olly', 'Price')
join(3, 'license:pat', 'Pat', 'Moore')

local lic = liEnv.Config.Licences
local office = lic.Office
local spot = faEnv.Config.Fishing.Spots[1]

-- ---------------------------------------------------------------- licences
H.section('Driving licence')
liEnv.NexoroLicences.random = function(n) return 1 end   -- deterministic question order: bank questions 1 to 5
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_licences:applyDriving')), 'too_far', 'the test is taken at the council office')
at(4, office.x, office.y, office.z)
local b0 = bank(4)
local ra, test = call(4, 'nexoro_licences:applyDriving')
H.check(ra == true and #test.questions == 5, 'the written test has five questions')
H.check(test.questions[1].answer == nil and test.questions[1].options ~= nil, 'answers are not sent to the player')
H.eq(b0 - bank(4), 60.0, 'the test fee of £60.00 is taken')
local wrong = {}
for i = 1, 5 do wrong[i] = (lic.Driving.bank[i].answer % 4) + 1 end
local rw, failed = call(4, 'nexoro_licences:submitDriving', { answers = wrong })
H.check(rw == true and failed.passed == false, 'all wrong answers fail the test')
H.eq(select(2, call(4, 'nexoro_licences:submitDriving', { answers = wrong })), 'no_test', 'a finished test cannot be re-marked')
call(4, 'nexoro_licences:applyDriving')
local right = {}
for i = 1, 5 do right[i] = lic.Driving.bank[i].answer end
local rp, passed = call(4, 'nexoro_licences:submitDriving', { answers = right })
H.check(rp == true and passed.passed == true and passed.score == 5, 'correct answers pass')
H.check(liEnv.NexoroLicences.Has(cidCara, 'driving'), 'the driving licence is recorded')
H.eq(Inv.GetItemCount(4, 'driving_licence'), 1, 'the licence card is issued')
H.eq(select(2, call(4, 'nexoro_licences:applyDriving')), 'already_licensed', 'you cannot sit the test again once licensed')

H.section('Fishing licence')
at(5, office.x, office.y, office.z)
local fb = bank(5)
H.check(call(5, 'nexoro_licences:buyFishing') == true, 'Olly buys a fishing licence')
H.eq(fb - bank(5), 25.0, 'the fishing licence costs £25.00')
H.eq(select(2, call(5, 'nexoro_licences:buyFishing')), 'already_licensed', 'only one fishing licence is needed')
local rm, mine = call(5, 'nexoro_licences:mine')
H.check(rm == true and mine.fishing == true and mine.driving == false, 'Olly holds a fishing licence only')

-- ---------------------------------------------------------------- fishing
H.section('Fishing')
faEnv.NexoroFishing.random = function(n) return 1 end
at(4, spot.x, spot.y, spot.z)
H.eq(select(2, call(4, 'nexoro_fishing:cast', { spot = 'harbour_pier' })), 'no_licence', 'no licence, no fishing')
at(5, spot.x + 500, spot.y, spot.z)
H.eq(select(2, call(5, 'nexoro_fishing:cast', { spot = 'harbour_pier' })), 'too_far', 'you must be at the spot')
at(5, spot.x, spot.y, spot.z)
H.eq(select(2, call(5, 'nexoro_fishing:cast', { spot = 'nowhere' })), 'unknown_spot', 'unknown spots are refused')
local rc, catch = call(5, 'nexoro_fishing:cast', { spot = 'harbour_pier' })
H.check(rc == true and catch.item == 'fish_raw', 'a cast at the pier lands a fresh fish')
H.eq(Inv.GetItemCount(5, 'fish_raw'), 1, 'the fish is in the inventory')
H.eq(select(2, call(5, 'nexoro_fishing:cast', { spot = 'harbour_pier' })), 'cooldown', 'the line needs a rest before the next cast')
NOW = NOW + 21
faEnv.NexoroFishing.random = function(n) return n end
local rs, scrap = call(5, 'nexoro_fishing:cast', { spot = 'harbour_pier' })
H.check(rs == true and scrap.item == 'scrap', 'the roll decides the catch: the top of the table is scrap')
H.eq(Inv.GetItemCount(5, 'scrap'), 1, 'junk goes in the inventory too')
faEnv.NexoroFishing.random = function(n) return 1 end

-- ---------------------------------------------------------------- businesses
H.section('Businesses: registration and accounts')
at(4, 0, 0, 0)
H.eq(select(2, call(4, 'nexoro_businesses:create', { name = 'Cafe' })), nil or select(2, call(4, 'nexoro_businesses:create', { name = 'Cafe' })), 'create path reached')
Core.AddMoney(4, 20000, 'bank', 'business money')
H.eq(select(2, call(4, 'nexoro_businesses:create', { name = 'ab' })), 'invalid_name', 'names need three letters or more')
local cb0 = bank(4)
local rcb, cafe = call(4, 'nexoro_businesses:create', { name = 'Corner Cafe' })
H.check(rcb == true and cafe.id, 'Cara registers Corner Cafe')
H.eq(cb0 - bank(4), 2500.0, 'registration costs £2,500.00')
local rcb2 = call(4, 'nexoro_businesses:create', { name = 'Second Shop' })
H.check(rcb2 == true, 'a second business is allowed')
H.eq(select(2, call(4, 'nexoro_businesses:create', { name = 'Third One' })), 'business_limit', 'two businesses per owner')
local rd, dep = call(4, 'nexoro_businesses:deposit', { id = cafe.id, amount = 500 })
H.check(rd == true and dep.balance == '£500.00', 'Cara puts £500 in the business account')
H.check(call(4, 'nexoro_businesses:withdraw', { id = cafe.id, amount = 100 }) == true, 'Cara takes £100 back out')
H.eq(select(2, call(4, 'nexoro_businesses:withdraw', { id = cafe.id, amount = 99999 })), 'insufficient_funds', 'a business cannot overdraw')
H.eq(select(2, call(5, 'nexoro_businesses:deposit', { id = cafe.id, amount = 10 })), 'not_owner', 'only the owner can use the account')
H.eq(select(2, call(4, 'nexoro_businesses:deposit', { id = cafe.id, amount = 0 })), 'invalid_amount', 'deposits must be positive')

H.section('Businesses: staff and wages')
H.eq(select(2, call(4, 'nexoro_businesses:hire', { id = cafe.id, target = cidOlly and 5, wage = 0 })), 'invalid_wage', 'wages must be positive')
H.eq(select(2, call(4, 'nexoro_businesses:hire', { id = cafe.id, target = 5, wage = 600 })), 'invalid_wage', 'wages are capped')
H.eq(select(2, call(4, 'nexoro_businesses:hire', { id = cafe.id, target = 4, wage = 10 })), 'cannot_target_self', 'owners cannot hire themselves')
H.check(call(4, 'nexoro_businesses:hire', { id = cafe.id, target = 5, wage = 12 }) == true, 'Olly is hired at £12 an hour')
H.eq(select(2, call(4, 'nexoro_businesses:hire', { id = cafe.id, target = 5, wage = 12 })), 'already_staff', 'nobody is hired twice')
local ob = bank(5)
local bal0 = H.DB.scalar('SELECT bank_pence FROM nexoro_businesses WHERE id = ?', { cafe.id })
NOW = NOW + 3601
local pw = bzEnv.NexoroBusinesses.PayWages()
H.eq(pw.paid, 1, 'the hourly wage is paid')
H.eq(bank(5) - ob, 12.0, 'Olly receives £12.00')
H.eq(bal0 - H.DB.scalar('SELECT bank_pence FROM nexoro_businesses WHERE id = ?', { cafe.id }), 1200, 'the wage comes out of the business account')
H.eq(bzEnv.NexoroBusinesses.PayWages().paid, 0, 'nothing is paid again within the hour')
Core.SetMetadata(4, 'x', nil)
call(4, 'nexoro_businesses:withdraw', { id = cafe.id, amount = H.DB.scalar('SELECT bank_pence FROM nexoro_businesses WHERE id = ?', { cafe.id }) / 100 })
NOW = NOW + 3601
local pw2 = bzEnv.NexoroBusinesses.PayWages()
H.eq(pw2.unpaid, 1, 'an empty account pays nobody')
H.eq(select(2, call(5, 'nexoro_businesses:mine')).working[1].name, 'Corner Cafe', 'Olly sees where he works')
H.check(call(4, 'nexoro_businesses:deposit', { id = cafe.id, amount = 200 }) == true, 'Cara refills the account')
H.check(call(4, 'nexoro_businesses:fire', { id = cafe.id, characterId = cidOlly }) == true, 'Cara dismisses Olly')
H.eq(select(2, call(4, 'nexoro_businesses:fire', { id = cafe.id, characterId = cidOlly })), 'not_staff', 'dismissed staff cannot be dismissed again')
call(4, 'nexoro_businesses:hire', { id = cafe.id, target = 5, wage = 12 })
H.check(call(5, 'nexoro_businesses:quit', { id = cafe.id }) == true, 'Olly quits')
H.eq(select(2, call(5, 'nexoro_businesses:quit', { id = cafe.id })), 'not_staff', 'quitting twice is refused')
local _, minfo = call(4, 'nexoro_businesses:mine')
H.check(#minfo.owned == 2, 'Cara owns two businesses')

-- ---------------------------------------------------------------- postal
H.section('Postal rounds')
local job = poEnv.Config.Postal
poEnv.NexoroPostal.random = function(n) return 1 end
at(3, 0, 0, 0)
H.eq(select(2, call(3, 'nexoro_postal:start')), 'not_on_duty_postal', 'a round needs the postal job and duty')
Core.SetJob(3, 'postal', 0)
local rd1, duty = call(3, 'nexoro_postal:duty')
H.check(rd1 == true and duty.onDuty == true, 'Pat clocks on as a postal worker')
H.eq(select(2, call(4, 'nexoro_postal:duty')), 'not_postal', 'other jobs cannot use the postal duty')
local rst, round = call(3, 'nexoro_postal:start')
H.check(rst == true and round.stops == 3, 'a round of three drops starts')
H.eq(select(2, call(3, 'nexoro_postal:start')), 'already_on_round', 'one round at a time')
local s1 = job.Stops[1]
H.eq(select(2, call(3, 'nexoro_postal:deliver')), 'too_far', 'deliveries need you at the door')
at(3, s1.x, s1.y, s1.z)
local rdl, d1 = call(3, 'nexoro_postal:deliver')
H.check(rdl == true and d1.done == false and d1.paid == '£35.00', 'the first drop pays £35.00')
local s2 = job.Stops[2]
at(3, s2.x, s2.y, s2.z)
H.eq(select(2, call(3, 'nexoro_postal:deliver')), 'too_soon', 'drops cannot be cleared too quickly')
NOW = NOW + 20
local rd2, d2 = call(3, 'nexoro_postal:deliver')
H.check(rd2 == true and d2.done == false, 'after a pause the second drop counts')
local s3 = job.Stops[3]
at(3, s3.x, s3.y, s3.z)
NOW = NOW + 20
local pb = bank(3)
local rd3, d3 = call(3, 'nexoro_postal:deliver')
H.check(rd3 == true and d3.done == true, 'the round completes on the last drop')
H.eq(bank(3) - pb, 95.0, 'the last drop pays £35 plus the £60 completion bonus')
H.eq(select(2, call(3, 'nexoro_postal:deliver')), 'no_round', 'a finished round cannot be delivered again')
call(3, 'nexoro_postal:start')
call(3, 'nexoro_postal:duty')
H.eq(select(2, call(3, 'nexoro_postal:deliver')), 'no_round', 'going off duty ends the round')
H.check(call(3, 'nexoro_postal:duty') == true, 'back on duty')
call(3, 'nexoro_postal:start')
H.check(call(3, 'nexoro_postal:stop') == true, 'a round can be stopped early')
H.eq(select(2, call(3, 'nexoro_postal:stop')), 'no_round', 'nothing to stop')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
