local cfg = Config.Lighting
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroLighting = {}
local L = NexoroLighting
L.now = os.time
-- Injectable for tests: returns the model hash for a vehicle network id, or nil.
L.modelOf = function(net)
    local e = NetworkGetEntityFromNetworkId(net)
    if not e or e == 0 then return nil end
    return GetEntityModel(e)
end
L.entityExists = function(net)
    local e = NetworkGetEntityFromNetworkId(net)
    return e ~= nil and e ~= 0 and DoesEntityExist(e)
end

local allowedHash = {}
for _, name in ipairs(cfg.Models) do allowedHash[GetHashKey(name)] = true end

L.states = {}   -- [net] = { net, preset, siren, setter, since }

local function emergencyOnDuty(src)
    local job = core().GetJob(src)
    return job ~= nil and job.onDuty and (job.category == 'police' or job.category == 'ambulance' or job.category == 'fire')
end

local function toInt(v)
    local n = tonumber(v)
    if not n or n ~= n or n == math.huge or n == -math.huge then return nil end
    return math.tointeger(n)
end

local function list()
    local out = {}
    for _, s in pairs(L.states) do out[#out + 1] = { net = s.net, preset = s.preset, siren = s.siren } end
    table.sort(out, function(a, b) return a.net < b.net end)
    return out
end

local function broadcast()
    TriggerClientEvent('nexoro_lighting:states', -1, list())
end

local function checkVehicle(net)
    local model = L.modelOf(net)
    if not model or not allowedHash[model] then return false, 'not_an_emergency_vehicle' end
    return true
end

-- Sets the lightbar pattern for a vehicle. preset = 'off' clears it.
function L.Set(src, net, preset)
    if not emergencyOnDuty(src) then return false, 'forbidden' end
    local n = toInt(net)
    if not n then return false, 'invalid_vehicle' end
    if preset == 'off' then
        local s = L.states[n]
        if not s then return false, 'lights_off' end
        if s.setter ~= src then return false, 'not_your_lights' end
        L.states[n] = nil
        broadcast()
        return true, { preset = 'off' }
    end
    if type(preset) ~= 'string' or not cfg.Presets[preset] then return false, 'unknown_preset' end
    local ok, why = checkVehicle(n)
    if not ok then return false, why end
    local existing = L.states[n]
    if existing and existing.setter ~= src then return false, 'not_your_lights' end
    L.states[n] = { net = n, preset = preset, siren = existing and existing.siren or false, setter = src, since = L.now() }
    broadcast()
    return true, { preset = preset }
end

function L.Siren(src, net, on)
    if not emergencyOnDuty(src) then return false, 'forbidden' end
    local n = toInt(net)
    local s = n and L.states[n]
    if not s then return false, 'lights_off' end
    if s.setter ~= src then return false, 'not_your_lights' end
    s.siren = on == true
    broadcast()
    return true, { siren = s.siren }
end

-- Clears states for vehicles that no longer exist, and everything set by a player who left.
function L.Sweep()
    local removed = 0
    for net in pairs(L.states) do
        if not L.entityExists(net) then L.states[net] = nil; removed = removed + 1 end
    end
    if removed > 0 then broadcast() end
    return removed
end

function L.ClearBy(src)
    local changed = false
    for net, s in pairs(L.states) do
        if s.setter == src then L.states[net] = nil; changed = true end
    end
    if changed then broadcast() end
end

local function register()
    Core = nil
    local C = core()
    local function cb(name, fn, max, windowMs)
        C.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 30, windowMs = windowMs or 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_lighting:set', function(src, p) return L.Set(src, arg(p, 'net'), arg(p, 'preset')) end, 30)
    cb('nexoro_lighting:siren', function(src, p) return L.Siren(src, arg(p, 'net'), arg(p, 'on')) end, 30)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerReady', function(src) TriggerClientEvent('nexoro_lighting:states', src, list()) end)
AddEventHandler('nexoro:server:playerDropped', function(src) L.ClearBy(src) end)
AddEventHandler('nexoro:server:dutyChanged', function(src, onDuty) if not onDuty then L.ClearBy(src) end end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
    while true do
        Wait(5000)
        L.Sweep()
    end
end)

exports('Set', L.Set)
exports('Siren', L.Siren)
exports('States', list)
