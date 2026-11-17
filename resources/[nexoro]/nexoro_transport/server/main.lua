local cfg = Config.Transport
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroTransport = {}
local T = NexoroTransport
T.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local onboard = {}   -- [src] = { route = id, from = stop index }

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

local function routeOf(id)
    for _, r in ipairs(cfg.Routes) do if r.id == id then return r end end
    return nil
end

function T.Board(src, routeId, stopIndex)
    local route = routeOf(routeId)
    if not route then return false, 'unknown_route' end
    local i = math.tointeger(tonumber(stopIndex))
    if not i or not route.stops[i] then return false, 'unknown_stop' end
    if onboard[src] then return false, 'already_boarded' end
    local p = T.getCoords(src)
    if not p or distance(p, route.stops[i]) > cfg.StopRadius then return false, 'too_far' end
    onboard[src] = { route = routeId, from = i }
    return true, { stop = route.stops[i].label }
end

-- Fare is the road distance between the stops, with a minimum.
function T.Fare(route, a, b)
    local straight = distance(route.stops[a], route.stops[b])
    local km = straight * cfg.RoadFactor / 1000.0
    return math.max(cfg.MinFarePounds, cfg.BaseFarePounds + cfg.PerKmFarePounds * km)
end

function T.Alight(src, routeId, stopIndex)
    local ride = onboard[src]
    if not ride then return false, 'not_boarded' end
    local route = routeOf(routeId)
    if not route or ride.route ~= routeId then return false, 'not_boarded' end
    local i = math.tointeger(tonumber(stopIndex))
    if not i or not route.stops[i] then return false, 'unknown_stop' end
    if i == ride.from then return false, 'same_stop' end
    local p = T.getCoords(src)
    if not p or distance(p, route.stops[i]) > cfg.StopRadius then return false, 'too_far' end
    local fare = core().ToPence(math.floor(T.Fare(route, ride.from, i) * 100 + 0.5) / 100)
    local ok = core().RemoveMoney(src, fare / 100, 'bank', 'bus fare')
    if not ok then return false, 'cannot_pay' end
    onboard[src] = nil
    core().Log('transport', 'trip', src, { route = routeId, from = ride.from, to = i, pence = fare })
    return true, { fare = core().FormatGBP(fare), stop = route.stops[i].label }
end

function T.Status(src)
    local ride = onboard[src]
    return true, { boarded = ride ~= nil, route = ride and ride.route or nil }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_transport:board', function(src, p) return T.Board(src, arg(p, 'route'), arg(p, 'stop')) end, 30)
    cb('nexoro_transport:alight', function(src, p) return T.Alight(src, arg(p, 'route'), arg(p, 'stop')) end, 30)
    cb('nexoro_transport:status', function(src) return T.Status(src) end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src) onboard[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Board', T.Board)
exports('Alight', T.Alight)
