local cfg = Config.Postal
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroPostal = {}
local P = NexoroPostal
P.now = os.time
P.random = function(n) return math.random(1, n) end
P.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local rounds = {}   -- [src] = { stops = {...}, index = n, lastStopAt = time }

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

local function onRound(src)
    local job = core().GetJob(src)
    return job ~= nil and job.name == cfg.JobName and job.onDuty == true
end

-- Going on and off duty as a postal worker.
function P.ToggleDuty(src)
    local job = core().GetJob(src)
    if not job or job.name ~= cfg.JobName then return false, 'not_postal' end
    local on = not job.onDuty
    core().SetDuty(src, on)
    if not on then rounds[src] = nil end
    return true, { onDuty = on }
end

-- Picks a round: a few different drops, in a random order.
function P.Start(src)
    if not onRound(src) then return false, 'not_on_duty_postal' end
    if rounds[src] then return false, 'already_on_round' end
    local pool = {}
    for i = 1, #cfg.Stops do pool[i] = cfg.Stops[i] end
    local stops = {}
    for _ = 1, math.min(cfg.StopsPerRound, #pool) do
        local k = P.random(#pool)
        stops[#stops + 1] = table.remove(pool, k)
    end
    rounds[src] = { stops = stops, index = 1, lastStopAt = nil }   -- the first drop has no pause
    TriggerClientEvent('nexoro_postal:stop', src, stops[1])
    return true, { stops = #stops, first = stops[1].label }
end

-- Delivers the current drop if the postal worker is standing at it.
function P.Deliver(src)
    local r = rounds[src]
    if not r then return false, 'no_round' end
    local stop = r.stops[r.index]
    local pos = P.getCoords(src)
    if not pos or distance(pos, stop) > cfg.StopRadius then return false, 'too_far' end
    local now = P.now()
    if r.lastStopAt and now - r.lastStopAt < cfg.MinSecondsBetweenStops then return false, 'too_soon' end
    core().AddMoney(src, cfg.PayPerStopPounds, 'bank', 'postal delivery: ' .. stop.id)
    r.index = r.index + 1
    r.lastStopAt = now
    if r.index > #r.stops then
        core().AddMoney(src, cfg.CompletionBonusPounds, 'bank', 'postal round bonus')
        rounds[src] = nil
        core().Log('postal', 'round_completed', src, {})
        return true, { done = true, paid = core().FormatGBP(core().ToPence(cfg.PayPerStopPounds + cfg.CompletionBonusPounds)) }
    end
    local nextStop = r.stops[r.index]
    TriggerClientEvent('nexoro_postal:stop', src, nextStop)
    return true, { done = false, paid = core().FormatGBP(core().ToPence(cfg.PayPerStopPounds)), next = nextStop.label }
end

function P.Stop(src)
    if not rounds[src] then return false, 'no_round' end
    rounds[src] = nil
    return true
end

local function register()
    Core = nil
    local C = core()
    C.RegisterJob({ name = cfg.JobName, label = 'Postal Worker', category = 'civilian', whitelisted = false,
        grades = { [0] = { label = 'Postal Worker', salary = 11.00, permissions = {} } } })
    local function cb(name, fn, max)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    cb('nexoro_postal:duty', function(src) return P.ToggleDuty(src) end, 10)
    cb('nexoro_postal:start', function(src) return P.Start(src) end, 10)
    cb('nexoro_postal:deliver', function(src) return P.Deliver(src) end, 40)
    cb('nexoro_postal:stop', function(src) return P.Stop(src) end, 10)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:dutyChanged', function(src, onDuty) if not onDuty then rounds[src] = nil end end)
AddEventHandler('nexoro:server:playerDropped', function(src) rounds[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Start', P.Start)
exports('Deliver', P.Deliver)
