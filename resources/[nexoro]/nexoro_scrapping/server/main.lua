local cfg = Config.Scrapping
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroScrapping = {}
local S = NexoroScrapping
S.now = os.time
S.random = function(lo, hi) return math.random(lo, hi) end
S.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local lastCollected = {}   -- [src][pointId] = time

local function pointOf(id)
    for _, p in ipairs(cfg.Points) do if p.id == id then return p end end
    return nil
end

local function onShift(src)
    local job = core().GetJob(src)
    return job ~= nil and job.name == cfg.JobName and job.onDuty == true
end

function S.ToggleDuty(src)
    local job = core().GetJob(src)
    if not job or job.name ~= cfg.JobName then return false, 'not_scrapper' end
    local on = not job.onDuty
    core().SetDuty(src, on)
    return true, { onDuty = on }
end

-- Collects scrap at a point. Only on shift, only at the point, and each point rests for a while.
function S.Collect(src, pointId)
    if not onShift(src) then return false, 'not_on_shift' end
    local point = pointOf(pointId)
    if not point then return false, 'unknown_point' end
    local p = S.getCoords(src)
    if not p or math.sqrt((p.x - point.x) ^ 2 + (p.y - point.y) ^ 2 + (p.z - point.z) ^ 2) > cfg.CollectRadius then return false, 'too_far' end
    local now = S.now()
    lastCollected[src] = lastCollected[src] or {}
    local last = lastCollected[src][point.id]
    if last and now - last < cfg.CooldownSeconds then return false, 'cooldown', cfg.CooldownSeconds - (now - last) end
    local amount = S.random(cfg.ScrapMin, cfg.ScrapMax)
    local ok, why = exports.nexoro_inventory:AddItem(src, 'scrap', amount)
    if not ok then return false, why end
    lastCollected[src][point.id] = now
    core().Log('scrapping', 'collected', src, { point = point.id, amount = amount })
    return true, { amount = amount, point = point.label }
end

local function register()
    Core = nil
    local K = core()
    K.RegisterJob({ name = cfg.JobName, label = cfg.JobLabel, category = 'civilian', whitelisted = false,
        grades = { [0] = { label = 'Collector', salary = cfg.Salary, permissions = {} } } })
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_scrapping:duty', function(src) return S.ToggleDuty(src) end, 10)
    cb('nexoro_scrapping:collect', function(src, p) return S.Collect(src, arg(p, 'point')) end, 30)
    cb('nexoro_scrapping:points', function() return true, cfg.Points end)
end

AddEventHandler('nexoro:core:ready', register)
AddEventHandler('nexoro:server:playerDropped', function(src) lastCollected[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Collect', S.Collect)
