local cfg = Config.Taxi
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroTaxi = {}
local T = NexoroTaxi
T.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end
T.now = os.time

local fares = {}       -- [id] = fare
local nextId = 0

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function activeFareOf(src)
    for _, f in pairs(fares) do
        if (f.driver == src or f.passenger == src) and (f.status == 'offered' or f.status == 'active') then return f end
    end
    return nil
end

local function isDriver(src)
    local job = core().GetJob(src)
    return job ~= nil and job.name == cfg.JobName and job.onDuty == true
end

-- Driver offers a fare to a nearby passenger. The passenger has to accept.
function T.Offer(src, passengerId)
    if not isDriver(src) then return false, 'not_on_duty_driver' end
    local p = toInt(passengerId)
    if not p or p == src then return false, 'invalid_passenger' end
    if not core().GetCharacter(p) then return false, 'passenger_not_found' end
    if activeFareOf(src) then return false, 'already_on_fare' end
    if activeFareOf(p) then return false, 'passenger_busy' end
    local dpos, ppos = T.getCoords(src), T.getCoords(p)
    if not dpos or not ppos or distance(dpos, ppos) > cfg.PickupRadius then return false, 'too_far' end
    nextId = nextId + 1
    fares[nextId] = { id = nextId, driver = src, passenger = p, pickup = dpos, status = 'offered', offeredAt = T.now() }
    TriggerClientEvent('nexoro_taxi:offer', p, { id = nextId, driver = core().GetCharacter(src).firstName, base = core().FormatGBP(core().ToPence(cfg.BaseFarePounds)) })
    return true, { id = nextId }
end

function T.Respond(src, fareId, accept)
    local f = fares[toInt(fareId) or -1]
    if not f or f.passenger ~= src or f.status ~= 'offered' then return false, 'no_such_offer' end
    if T.now() - f.offeredAt > cfg.OfferSeconds then f.status = 'expired'; return false, 'offer_expired' end
    if accept ~= true then
        f.status = 'declined'
        core().Notify(f.driver, 'Your fare offer was declined.', 'info')
        return true, { accepted = false }
    end
    f.status = 'active'
    f.startedAt = T.now()
    core().Notify(f.driver, 'Fare accepted. Drive to the destination.', 'success')
    return true, { accepted = true }
end

-- Works out the fare from the measured route and charges the passenger. Too-fast trips are refused.
function T.Finish(src, fareId)
    local f = fares[toInt(fareId) or -1]
    if not f or f.driver ~= src or f.status ~= 'active' then return false, 'no_such_fare' end
    local dpos, ppos = T.getCoords(src), T.getCoords(f.passenger)
    if not dpos or not ppos or distance(dpos, ppos) > cfg.DropRadius then return false, 'passenger_not_in_car' end
    local straight = distance(f.pickup, dpos)
    if straight < 20.0 then return false, 'no_journey' end
    local miles = straight * cfg.RoadFactor / 1609.344
    local elapsed = T.now() - f.startedAt
    local minSeconds = miles / cfg.MaxMph * 3600
    if elapsed < minSeconds then return false, 'too_fast' end
    local fare = math.max(cfg.MinFarePounds, cfg.BaseFarePounds + cfg.PerMileFarePounds * miles)
    local pence = core().ToPence(math.floor(fare * 100 + 0.5) / 100)
    local ok, why = core().RemoveMoney(f.passenger, pence / 100, 'bank', 'taxi fare')
    if not ok then return false, 'passenger_cannot_pay' end
    local share = math.floor(pence * cfg.DriverShare + 0.5)
    core().AddMoney(src, share / 100, 'bank', 'taxi fare')
    f.status = 'completed'
    core().Notify(f.passenger, ('Fare paid: %s.'):format(core().FormatGBP(pence)), 'banking')
    core().Log('taxi', 'fare', src, { fare = f.id, pence = pence, miles = miles })
    return true, { fare = core().FormatGBP(pence), driverPay = core().FormatGBP(share), miles = math.floor(miles * 10 + 0.5) / 10 }
end

function T.Cancel(src, fareId)
    local f = fares[toInt(fareId) or -1]
    if not f or (f.driver ~= src and f.passenger ~= src) then return false, 'no_such_fare' end
    if f.status ~= 'offered' and f.status ~= 'active' then return false, 'not_cancellable' end
    f.status = 'cancelled'
    core().Notify(f.driver == src and f.passenger or f.driver, 'The fare was cancelled.', 'info')
    return true
end

local function register()
    Core = nil
    local C = core()
    C.RegisterJob({ name = cfg.JobName, label = 'Taxi Driver', category = 'civilian', whitelisted = false,
        grades = { [0] = { label = 'Driver', salary = 12.50, permissions = {} } } })
    local function cb(name, fn, max)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_taxi:offer', function(src, p) return T.Offer(src, arg(p, 'passenger')) end)
    cb('nexoro_taxi:respond', function(src, p) return T.Respond(src, arg(p, 'id'), arg(p, 'accept') == true) end)
    cb('nexoro_taxi:finish', function(src, p) return T.Finish(src, arg(p, 'id')) end)
    cb('nexoro_taxi:cancel', function(src, p) return T.Cancel(src, arg(p, 'id')) end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src)
    for _, f in pairs(fares) do
        if (f.driver == src or f.passenger == src) and (f.status == 'offered' or f.status == 'active') then f.status = 'cancelled' end
    end
end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Offer', T.Offer)
exports('Finish', T.Finish)
