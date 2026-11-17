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
local gbEnv = env('nexoro_gambling', { 'config.lua', 'server/main.lua' })
local loEnv = env('nexoro_lottery', { 'config.lua', 'server/main.lua' })
local scEnv = env('nexoro_scratchcards', { 'config.lua', 'server/main.lua' })

H.section('Migrations')
Nexoro.Ready = true
local ok, applied, err = dbEnv.NexoroMigrations.Run()
H.check(ok, 'migrations apply', err)
for _, t in ipairs({ 'nexoro_gambling_daily', 'nexoro_lottery_draws', 'nexoro_lottery_tickets' }) do H.check(H.DB.query('SHOW TABLES LIKE ?', { t })[1] ~= nil, 'table exists: ' .. t) end

for _, fn in ipairs(H.events.handlers['nexoro:core:ready'] or {}) do fn() end
local Core = H.registry.nexoro_core.GetCore()

local pos = {}
local NOW = os.time()
local function at(s, x, y, z) pos[s] = { x = x, y = y, z = z } end
local getPos = function(s) return pos[s] end
loEnv.NexoroLottery.getCoords = getPos
loEnv.NexoroLottery.now = function() return NOW end
scEnv.NexoroScratch.getCoords = getPos
gbEnv.NexoroGambling.now = function() return NOW end
local function call(src, name, payload) H.advance(12000); return H.callServer(src, name, payload) end
local function bank(src) return Core.GetPlayerMoney(src, 'bank') end
local function cash(src) return Core.GetPlayerMoney(src, 'cash') end
local defApp = select(2, chEnv.NexoroAppearance.Default('mp_m_freemode_01'))
local function join(src, license, first, last)
    H.addPlayerStub(src, first, { license }); Nexoro.RegisterExistingPlayer(src)
    local r, d = H.callServer(src, 'nexoro_character:create', { identity = { firstName = first, lastName = last, dob = '1990-05-20', gender = 'male', nationality = 'British', height = 178 }, appearance = defApp })
    assert(r == true, 'create ' .. first)
    assert(H.callServer(src, 'nexoro_character:select', { id = d.id }) == true)
    return d.id
end
local cidCara = join(4, 'license:cara', 'Cara', 'Lane')
join(5, 'license:olly', 'Olly', 'Price')
join(6, 'license:lou', 'Lou', 'Park')
join(3, 'license:pat', 'Pat', 'Moore')
Core.AddMoney(4, 1000, 'bank', 'lottery money')
Core.AddMoney(5, 1000, 'bank', 'lottery money')
Core.AddMoney(6, 1000, 'bank', 'lottery money')
Core.AddMoney(3, 1000, 'bank', 'lottery money')

-- ---------------------------------------------------------------- gambling limit
H.section('Daily gambling limit')
local cid4 = cidCara
H.eq(gbEnv.NexoroGambling.Remaining(cid4), 10000, 'a character can stake £100 a day')
H.check(gbEnv.NexoroGambling.Reserve(cid4, 6000) == true, 'a £60 stake is reserved')
H.eq(select(2, gbEnv.NexoroGambling.Reserve(cid4, 5000)), 'daily_limit', 'going over £100 in a day is refused')
gbEnv.NexoroGambling.Release(cid4, 6000)
H.eq(gbEnv.NexoroGambling.Remaining(cid4), 10000, 'a released stake is given back')
gbEnv.NexoroGambling.Reserve(cid4, 10000)
H.eq(gbEnv.NexoroGambling.Remaining(cid4), 0, 'the whole day can be used up')
NOW = NOW + 86400
H.eq(gbEnv.NexoroGambling.Remaining(cid4), 10000, 'the limit resets the next day')
H.eq(select(2, gbEnv.NexoroGambling.Reserve(cid4, 0)), 'invalid_stake', 'a stake must be positive')

-- ---------------------------------------------------------------- scratchcards
H.section('Scratchcards')
local counter = scEnv.Config.Scratch.Counter
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_scratch:buy')), 'too_far', 'scratchcards are bought at the counter')
at(4, counter.x, counter.y, counter.z)
local expected = 0
for _, p in ipairs(scEnv.Config.Scratch.Prizes) do expected = expected + p.prize * p.weight end
local rtp = expected / 1000 / scEnv.Config.Scratch.PricePounds
H.check(rtp > 0.95 and rtp < 0.99, 'the published odds pay back about 97% (' .. string.format('%.1f%%', rtp * 100) .. ')')
scEnv.NexoroScratch.random = function(n) return 1 end
local c0 = cash(4)
local rl, lose = call(4, 'nexoro_scratch:buy')
H.check(rl == true and lose.prize == 0, 'the first prize band is a loser')
H.eq(c0 - cash(4), 5.0, 'the card costs £5.00')
scEnv.NexoroScratch.random = function(n) return n end
local c1 = cash(4)
local rw, win = call(4, 'nexoro_scratch:buy')
H.check(rw == true and win.prize == 500, 'the top prize is £500')
H.eq(cash(4) - c1, 495.0, 'the win less the stake is paid out in cash')

-- daily limit: 20 cards at £5 = £100
scEnv.NexoroScratch.random = function(n) return 1 end
gbEnv.NexoroGambling.Reserve(cid4, 0)
NOW = NOW + 86400
for _ = 1, 20 do call(4, 'nexoro_scratch:buy') end
H.eq(select(2, call(4, 'nexoro_scratch:buy')), 'daily_limit', 'the 21st card of the day is refused')
local tomorrow = gbEnv.NexoroGambling.Remaining(cid4)
H.eq(tomorrow, 0, 'the day is used up')
NOW = NOW + 86400

-- ---------------------------------------------------------------- lottery
H.section('Lottery: tickets')
local office = loEnv.Config.Lottery.Office
at(4, 900, 900, 30)
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 5, 6 } })), 'too_far', 'tickets are bought at the counter')
at(4, office.x, office.y, office.z)
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 5 } })), 'invalid_numbers', 'a ticket needs six numbers')
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 1, 1, 2, 3, 4, 5 } })), 'invalid_numbers', 'numbers must be different')
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 0, 2, 3, 4, 5, 6 } })), 'invalid_numbers', 'numbers start at 1')
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 5, 50 } })), 'invalid_numbers', 'numbers stop at 49')
loEnv.NexoroLottery.random = function(n) return 1 end
local b0 = bank(4)
local rt, t1 = call(4, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 5, 6 } })
H.check(rt == true and t1.numbers == '1,2,3,4,5,6', 'a valid ticket is bought')
H.eq(b0 - bank(4), 2.0, 'a ticket costs £2.00')
local drawId = H.DB.scalar("SELECT id FROM nexoro_lottery_draws WHERE status = 'open' ORDER BY id DESC LIMIT 1")
H.eq(H.DB.scalar('SELECT pot_pence FROM nexoro_lottery_draws WHERE id = ?', { drawId }), 100, 'half of each ticket goes into the pot')
for i = 1, 9 do call(4, 'nexoro_lottery:buy', { numbers = { 10 + i, 20, 21, 22, 23, 24 } }) end
H.eq(select(2, call(4, 'nexoro_lottery:buy', { numbers = { 30, 31, 32, 33, 34, 35 } })), 'ticket_limit', 'at most ten tickets per person per draw')

-- ---------------------------------------------------------------- lottery: the draw
H.section('Lottery: draw and payouts')
-- winning numbers will be 1,2,3,4,5,6 (the injected random always takes the first remaining number)
at(5, office.x, office.y, office.z); at(6, office.x, office.y, office.z); at(3, office.x, office.y, office.z)
call(5, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 5, 40 } })      -- 5 matches
call(6, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 30, 40 } })     -- 4 matches
call(3, 'nexoro_lottery:buy', { numbers = { 10, 20, 30, 40, 41, 42 } }) -- none
local before = { [4] = bank(4), [5] = bank(5), [6] = bank(6), [3] = bank(3) }
H.check(loEnv.NexoroLottery.Draw(drawId) == true, 'the draw runs')
local dr = H.DB.single('SELECT status, numbers, pot_pence, carried_pence FROM nexoro_lottery_draws WHERE id = ?', { drawId })
H.eq(dr.status, 'drawn', 'the draw is closed')
H.eq(dr.numbers, '1,2,3,4,5,6', 'the winning numbers are recorded')
local pot = dr.pot_pence + dr.carried_pence
local tier4 = math.floor(pot * 0.15)
local got4 = math.floor((bank(6) - before[6]) * 100 + 0.5)
H.eq(got4, tier4, 'the 4-number winner gets 15% of the pot')
H.eq(math.floor((bank(5) - before[5]) * 100 + 0.5), math.floor(pot * 0.25), 'the 5-number winner gets 25% of the pot')
local carryNow = H.DB.scalar("SELECT carried_pence FROM nexoro_lottery_draws WHERE status = 'open' ORDER BY id DESC LIMIT 1")
-- Cara's first ticket was 1,2,3,4,5,6, so the jackpot was won and the whole pot is paid out: nothing carries over.
H.eq(carryNow, pot - math.floor(pot * 0.6) - math.floor(pot * 0.25) - tier4, 'when every tier has a winner, nothing carries over')
H.eq(carryNow, 0, 'the jackpot was won, so the carry is zero')
H.eq(select(2, loEnv.NexoroLottery.Draw(drawId)), 'not_open', 'a draw cannot be run twice')

H.section('Lottery: rollover when the jackpot is not won')
local _, cd = call(4, 'nexoro_lottery:current')
H.check(cd and cd.pot ~= nil, 'the current pot is shown to players')
local nextDraw = H.DB.scalar("SELECT id FROM nexoro_lottery_draws WHERE status = 'open' ORDER BY id DESC LIMIT 1")
local carryIn = H.DB.scalar('SELECT carried_pence FROM nexoro_lottery_draws WHERE id = ?', { nextDraw })
call(5, 'nexoro_lottery:buy', { numbers = { 1, 2, 3, 4, 30, 40 } })
loEnv.NexoroLottery.random = function(n) return 1 end
local pot2 = carryIn + 100
local ok2 = loEnv.NexoroLottery.Draw(nextDraw)
H.check(ok2 == true, 'the next draw runs')
local paid2 = math.floor(pot2 * 0.15)
local newCarry = H.DB.scalar("SELECT carried_pence FROM nexoro_lottery_draws WHERE status = 'open' ORDER BY id DESC LIMIT 1")
H.eq(newCarry, pot2 - paid2, 'rolled over money is kept, nothing is lost')
H.check(newCarry > carryIn, 'the jackpot grows when nobody wins it')

-- ---------------------------------------------------------------- done
io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
