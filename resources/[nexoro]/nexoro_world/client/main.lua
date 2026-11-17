local cfg = Config.World
local current = { weather = 'CLEAR', hour = 12, minute = 0, frozen = false, realtime = true }
local appliedWeather
local wet = false

RegisterNetEvent('nexoro:world:sync', function(s)
    if type(s) ~= 'table' or type(s.weather) ~= 'string' then return end
    current = s
    wet = cfg.WetWeather[s.weather] == true
    if s.weather ~= appliedWeather then
        appliedWeather = s.weather
        -- Blends the sky from the old weather to the new one over several seconds.
        SetWeatherTypeOvertimePersist(s.weather, cfg.TransitionSeconds + 0.0)
    end
end)

-- The clock is re-applied every second so it stays in step with the server.
CreateThread(function()
    while true do
        NetworkOverrideClockTime(current.hour, current.minute, 0)
        Wait(1000)
    end
end)

-- Traffic and pedestrian density.
CreateThread(function()
    while true do
        local h = current.hour or 12
        local night = (h >= cfg.NightHours.from or h < cfg.NightHours.to)
        local t = night and cfg.NightTraffic or cfg.Traffic
        SetRandomVehicleDensityMultiplierThisFrame(t.moving)
        SetParkedVehicleDensityMultiplierThisFrame(t.parked)
        SetPedDensityMultiplierThisFrame(t.pedestrians)
        Wait(0)
    end
end)

exports('GetWeather', function() return current.weather end)
exports('IsWet', function() return wet end)
exports('GetClock', function() return current.hour, current.minute end)
