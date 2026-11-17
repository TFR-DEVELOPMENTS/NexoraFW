local cfg = Config.Robbery
local Core
local function core()
    if not Core then Core = exports.nexoro_core:GetCore() end
    return Core
end

NexoroRobbery = {}
local R = NexoroRobbery
R.now = os.time
R.random = function(lo, hi) return math.random(lo, hi) end
R.getCoords = function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z }
end

local lastRobbed = {}   -- [targetId] = time

local function targetOf(id)
    for _, t in ipairs(cfg.Targets) do if t.id == id then return t end end
    return nil
end

local function distance(a, b) return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2) end

-- Checks everything before the robbery starts. The client shows the progress bar after this.
function R.Check(src, id)
    local t = targetOf(id)
    if not t then return false, 'unknown_target' end
    local c = core().GetCharacter(src)
    if not c then return false, 'no_character' end
    local p = R.getCoords(src)
    if not p or distance(p, t) > t.radius + 2.0 then return false, 'too_far' end
    local now = R.now()
    if lastRobbed[t.id] and now - lastRobbed[t.id] < t.cooldownMinutes * 60 then
        return false, 'cooldown', math.ceil((lastRobbed[t.id] + t.cooldownMinutes * 60 - now) / 60)
    end
    if (exports.nexoro_inventory:GetItemCount(src, t.requires) or 0) < 1 then return false, 'no_' .. t.requires end
    return true, { seconds = t.seconds }
end

-- Completes the robbery: the lockpick is used up, cash is taken from the till or ATM, and the police are alerted.
function R.Complete(src, id)
    local ok, why, extra = R.Check(src, id)
    if not ok then return false, why, extra end
    local t = targetOf(id)
    local removed, rwhy = exports.nexoro_inventory:RemoveItem(src, t.requires, 1)
    if not removed then return false, rwhy end
    local amount = R.random(t.min, t.max)
    local pence = core().ToPence(amount)
    core().AddMoney(src, pence / 100, 'cash', 'robbery: ' .. t.id)
    lastRobbed[t.id] = R.now()
    local p = R.getCoords(src)
    TriggerEvent('nexoro:server:alarm', { description = ('Robbery reported at %s'):format(t.label), x = p.x, y = p.y, z = p.z, kind = t.kind })
    core().Log('robbery', 'completed', src, { target = t.id, pence = pence })
    return true, { taken = core().FormatGBP(pence) }
end

local function register()
    Core = nil
    local K = core()
    local function cb(name, fn, max)
        K.RegisterCallback(name, fn, { requireCharacter = true, rateLimit = { max = max or 10, windowMs = 10000 } })
    end
    local function arg(p, k) return type(p) == 'table' and p[k] or nil end
    cb('nexoro_robbery:check', function(src, p) return R.Check(src, arg(p, 'target')) end)
    cb('nexoro_robbery:complete', function(src, p) return R.Complete(src, arg(p, 'target')) end)
end

AddEventHandler('nexoro:core:ready', register)
CreateThread(function()
    Wait(0)
    local ok, ready = pcall(function() return exports.nexoro_core:IsReady() end)
    if ok and ready then register() end
end)

exports('Check', R.Check)
exports('Complete', R.Complete)
