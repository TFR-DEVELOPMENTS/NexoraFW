local cfg = Config.World

NexoroWorld = {}
local W = NexoroWorld
W.now = os.time
W.random = function(n) return math.random(1, n) end

local state = {
    weather = cfg.StartWeather, hour = cfg.StartHour, minute = 0, frozen = false,
    realtime = cfg.RealTime, nextWeatherAt = 0,
}

-- Days from 1970-01-01 to a Gregorian date (Howard Hinnant's civil-date algorithm).
local function daysFromCivil(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = y // 400
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = (153 * mp + 2) // 5 + d - 1
    local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
    return era * 146097 + doe - 719468
end

local MONTH_DAYS = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
local function lastSundayOf(y, m)
    local dim = MONTH_DAYS[m]
    if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then dim = 29 end
    for d = dim, 1, -1 do
        -- 1970-01-01 was a Thursday; (days + 4) % 7 == 0 means Sunday.
        if (daysFromCivil(y, m, d) + 4) % 7 == 0 then return d end
    end
    return dim
end

-- British Summer Time runs from the last Sunday of March to the last Sunday of October,
-- changing at 01:00 UTC on both days.
function W.IsBST(utc)
    local y = os.date('!*t', utc).year
    local start = daysFromCivil(y, 3, lastSundayOf(y, 3)) * 86400 + 3600
    local stop = daysFromCivil(y, 10, lastSundayOf(y, 10)) * 86400 + 3600
    return utc >= start and utc < stop
end

function W.UKTime(utc)
    local offset = W.IsBST(utc) and 3600 or 0
    local t = os.date('!*t', utc + offset)
    return t.hour, t.min
end

function W.State()
    return { weather = state.weather, hour = state.hour, minute = state.minute, frozen = state.frozen, realtime = state.realtime }
end

function W.Broadcast(target)
    TriggerClientEvent('nexoro:world:sync', target or -1, W.State())
end

-- Picks the next weather from the allowed neighbours of the current one.
function W.Advance(now)
    local options = cfg.Transitions[state.weather] or { 'CLEAR' }
    state.weather = options[W.random(#options)]
    state.nextWeatherAt = (now or W.now()) + cfg.WeatherIntervalMinutes * 60
    return state.weather
end

function W.Tick()
    local now = W.now()
    if state.nextWeatherAt == 0 then state.nextWeatherAt = now + cfg.WeatherIntervalMinutes * 60 end
    if state.realtime then
        state.hour, state.minute = W.UKTime(now)
    elseif not state.frozen then
        state.minute = state.minute + cfg.GameMinutesPerTick
        while state.minute >= 60 do
            state.minute = state.minute - 60
            state.hour = (state.hour + 1) % 24
        end
    end
    if now >= state.nextWeatherAt then W.Advance(now) end
    W.Broadcast(-1)
    return W.State()
end

function W.SetWeather(w)
    if type(w) ~= 'string' or not cfg.Transitions[w] then return false, 'invalid_weather' end
    state.weather = w
    state.nextWeatherAt = W.now() + cfg.WeatherIntervalMinutes * 60
    W.Broadcast(-1)
    return true
end

-- Setting the time by hand turns real-time off until it is switched back on.
function W.SetTime(h, m)
    h, m = math.tointeger(tonumber(h)), math.tointeger(tonumber(m or 0))
    if not h or not m or h < 0 or h > 23 or m < 0 or m > 59 then return false, 'invalid_time' end
    state.hour, state.minute = h, m
    state.realtime = false
    W.Broadcast(-1)
    return true
end

function W.SetRealTime(on)
    state.realtime = on == true
    W.Broadcast(-1)
    return state.realtime
end

function W.ToggleFrozen()
    state.frozen = not state.frozen
    W.Broadcast(-1)
    return state.frozen
end

AddEventHandler('nexoro:server:playerReady', function(src) W.Broadcast(src) end)

CreateThread(function()
    while true do
        Wait(cfg.TickMs)
        W.Tick()
    end
end)

exports('GetState', W.State)
exports('SetWeather', W.SetWeather)
exports('SetTime', W.SetTime)
exports('SetRealTime', W.SetRealTime)
exports('ToggleFrozen', W.ToggleFrozen)
