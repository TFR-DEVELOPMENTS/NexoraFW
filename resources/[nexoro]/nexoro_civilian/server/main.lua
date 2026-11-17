local cfg = Config.Civilian
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroCivilian = {}
local C = NexoroCivilian
C.now = os.time
C.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local lastPaid = {}   -- [src][jobId .. pointId] = time

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end
local function jobDef(id) return cfg.Jobs[id] end

local function registerJobs()
    for id, def in pairs(cfg.Jobs) do
        core().RegisterJob({ name = id, label = def.label, category = 'civilian', whitelisted = false,
            grades = { [0] = { label = def.label, salary = def.salary, permissions = {} } } })
    end
end

-- Takes a job at the job centre (replaces any job you had).
function C.Hire(src, jobId)
    local p = C.getCoords(src)
    if not p or distance(p, cfg.JobCentre) > cfg.JobCentre.radius + 2.0 then return false, 'too_far' end
    if not jobDef(jobId) then return false, 'unknown_job' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    core().SetJob(src, jobId, 0)
    core().SetDuty(src, false)
    core().Log('civilian', 'hired', src, { job = jobId })
    return true, { job = jobDef(jobId).label }
end

-- Leaves the job (back to unemployed).
function C.Quit(src)
    local job = core().GetJob(src)
    if not job or not jobDef(job.name) then return false, 'no_job' end
    core().SetDuty(src, false)
    core().SetJob(src, 'unemployed', 0)
    return true
end

function C.Duty(src)
    local job = core().GetJob(src)
    if not job or not jobDef(job.name) then return false, 'no_job' end
    local on = not job.onDuty
    core().SetDuty(src, on)
    return true, { onDuty = on }
end

-- Does one task at a point of your job. Pays after the point's cooldown has passed for you.
function C.Task(src, pointId)
    local job = core().GetJob(src)
    if not job or not jobDef(job.name) then return false, 'no_job' end
    if job.onDuty ~= true then return false, 'not_on_duty' end
    local def = jobDef(job.name)
    local point
    for _, pt in ipairs(def.points) do if pt.id == pointId then point = pt end end
    if not point then return false, 'unknown_point' end
    local p = C.getCoords(src)
    if not p or distance(p, point) > cfg.TaskRadius then return false, 'too_far' end
    local now = C.now()
    lastPaid[src] = lastPaid[src] or {}
    local key = job.name .. ':' .. point.id
    if lastPaid[src][key] and now - lastPaid[src][key] < def.cooldown then
        return false, 'cooldown', def.cooldown - (now - lastPaid[src][key])
    end
    lastPaid[src][key] = now
    core().AddMoney(src, def.pay, 'bank', 'job task: ' .. def.label)
    return true, { paid = core().FormatGBP(core().ToPence(def.pay)), point = point.label }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 20, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_civilian:hire', function(src, p) return C.Hire(src, arg(p, 'job')) end, 5)
    cb('nexoro_civilian:quit', function(src) return C.Quit(src) end, 5)
    cb('nexoro_civilian:duty', function(src) return C.Duty(src) end, 10)
    cb('nexoro_civilian:task', function(src, p) return C.Task(src, arg(p, 'point')) end, 30)
end

AddEventHandler('nexoro:core:ready', function() registerJobs(); register() end)
AddEventHandler('nexoro:server:playerDropped', function(src) lastPaid[src] = nil end)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then registerJobs(); register() end
end)

exports('Hire', C.Hire)
exports('Task', C.Task)
