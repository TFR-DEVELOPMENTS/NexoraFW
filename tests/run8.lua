package.path = (arg[0]:match('^(.*)/') or '.') .. '/?.lua;' .. package.path
local H = require('harness')
H.resetDatabase()
_G.NexoroDB = H.DB
local function env(name, files) local e = H.newEnv(name); e.NexoroDB = H.DB; H.loadFiles(e, name, files); return e end

local wEnv = env('nexoro_world', { 'config.lua', 'server/main.lua' })
local W = wEnv.NexoroWorld
local cfg = wEnv.Config.World

-- Seconds since 1970 for a UTC calendar time, independent of the machine's timezone.
local function utcSeconds(y, m, d, h, min)
    local days = 0
    for year = 1970, y - 1 do days = days + (((year % 4 == 0 and year % 100 ~= 0) or year % 400 == 0) and 366 or 365) end
    local mdays = { 31, ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    for mo = 1, m - 1 do days = days + mdays[mo] end
    days = days + d - 1
    return days * 86400 + h * 3600 + min * 60
end

H.section('UK clock: GMT and BST')
H.check(W.IsBST(utcSeconds(2026, 7, 1, 12, 0)) == true, 'July is British Summer Time')
H.check(W.IsBST(utcSeconds(2026, 1, 15, 12, 0)) == false, 'January is GMT')
local h1 = W.UKTime(utcSeconds(2026, 7, 1, 12, 0))
H.eq(h1, 13, 'in July the UK clock reads 13:00 when UTC is 12:00')
local h2 = W.UKTime(utcSeconds(2026, 1, 15, 12, 0))
H.eq(h2, 12, 'in January the UK clock reads 12:00 when UTC is 12:00')
H.check(W.IsBST(utcSeconds(2026, 3, 29, 1, 30)) == true, 'BST starts at 01:00 UTC on the last Sunday of March (29 March 2026)')
H.check(W.IsBST(utcSeconds(2026, 3, 29, 0, 30)) == false, 'just before the March change it is still GMT')
H.check(W.IsBST(utcSeconds(2026, 10, 25, 0, 30)) == true, 'BST ends at 01:00 UTC on the last Sunday of October (25 October 2026)')
H.check(W.IsBST(utcSeconds(2026, 10, 25, 1, 30)) == false, 'after the October change it is GMT')
H.eq(W.UKTime(utcSeconds(2026, 10, 25, 1, 30)), 1, 'the hour after the October change reads 01:30 GMT')

H.section('Weather cycle')
H.eq(select(2, W.SetWeather('NOPE')), 'invalid_weather', 'unknown weather is refused')
H.check(W.SetWeather('CLEAR'), 'set clear weather')
-- Each step picks a neighbour explicitly, so the expected path is clear.
local function step(pick, expected, label)
    W.random = function(n) return pick == 'last' and n or 1 end
    H.eq(W.Advance(0), expected, label)
end
step('last', 'CLOUDS', 'from clear the next weather is a neighbour (clouds)')
step('first', 'CLEAR', 'from clouds the first neighbour is clear')
W.SetWeather('CLOUDS')
step('last', 'CLEARING', 'clouds can also break up into clearing skies')
W.SetWeather('CLOUDS')
step('first', 'CLEAR', 'clouds can clear directly')
W.SetWeather('OVERCAST')
step('last', 'FOGGY', 'overcast can turn to fog')
W.SetWeather('OVERCAST')
step('first', 'CLOUDS', 'overcast can thin back to clouds')
W.SetWeather('OVERCAST')
step('last', 'FOGGY', 'overcast can roll into fog (last option)')
W.SetWeather('RAIN')
step('first', 'OVERCAST', 'rain can ease back to overcast')
W.SetWeather('RAIN')
step('last', 'CLEARING', 'rain can clear up (last option)')
local allKnown = true
for _, options in pairs(cfg.Transitions) do
    for _, nx in ipairs(options) do
        if not cfg.Transitions[nx] then allKnown = false end
    end
end
H.check(allKnown, 'every transition leads to a weather with its own rules')
local clearToThunder = false
for _, n in ipairs(cfg.Transitions.CLEAR) do if n == 'THUNDER' then clearToThunder = true end end
H.check(not clearToThunder, 'clear skies never jump straight to thunder')
H.check(cfg.Transitions.RAIN and (function() for _, n in ipairs(cfg.Transitions.RAIN) do if n == 'THUNDER' then return true end end return false end)(), 'rain can build to thunder')
H.check(cfg.WetWeather.RAIN == true and cfg.WetWeather.CLEAR == nil, 'rain makes roads wet; clear does not')

H.section('Admin control and clock')
W.SetWeather('CLEAR')
H.check(W.SetTime(25, 0) == false, 'impossible times are refused')
H.check(W.SetTime(18, 30), 'a manual time is accepted')
H.eq(W.State().hour, 18, 'manual hour applied')
H.eq(W.State().realtime, false, 'setting the time by hand turns real time off')
H.check(W.SetRealTime(true) == true, 'real time can be turned back on')
H.check(W.ToggleFrozen() == true and W.ToggleFrozen() == false, 'the clock can be frozen and unfrozen')
W.SetRealTime(false)
W.SetTime(23, 59)
W.Tick()
H.eq(W.State().hour, 0, 'the game clock rolls past midnight')
H.eq(W.State().minute, 0, 'and resets its minutes')
W.SetTime(10, 0)
W.ToggleFrozen()
W.Tick()
H.eq(W.State().minute, 0, 'a frozen clock does not move')
W.ToggleFrozen()
W.SetRealTime(true)
W.now = function() return utcSeconds(2026, 7, 1, 12, 0) end
W.Tick()
H.eq(W.State().hour, 13, 'real time follows UK time on each tick')
H.eq(W.State().minute, 0, 'real time minute is correct')

H.section('Broadcasts')
H.sent = {}
W.Tick()
local everyone = 0
for _, e in ipairs(H.sent) do if e.name == 'nexoro:world:sync' and e.target == -1 then everyone = everyone + 1 end end
H.check(everyone >= 1, 'every tick sends the world state to everyone')
H.sent = {}
W.SetWeather('OVERCAST')
local bc = 0
for _, e in ipairs(H.sent) do if e.name == 'nexoro:world:sync' and e.target == -1 and e.args[1].weather == 'OVERCAST' then bc = bc + 1 end end
H.check(bc == 1, 'an admin weather change is sent to everyone at once')
H.sent = {}
H.fireHandlers(9, 'nexoro:server:playerReady', 9)
local join = {}
for _, e in ipairs(H.sent) do if e.name == 'nexoro:world:sync' and e.target == 9 then join[#join + 1] = e end end
H.check(#join == 1 and join[1].args[1].weather == 'OVERCAST', 'a player who joins is sent the current weather and time')

H.section('Traffic and density')
H.check(cfg.Traffic.moving >= 0 and cfg.Traffic.moving <= 1 and cfg.Traffic.parked <= 1 and cfg.Traffic.pedestrians <= 1, 'traffic densities are between 0 and 1')

io.write(('\n%d passed, %d failed\n'):format(H.passed, H.failed))
os.exit(H.failed == 0 and 0 or 1)
